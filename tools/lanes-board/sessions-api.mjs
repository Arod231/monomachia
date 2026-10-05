// The Project Manager's Sessions and relay routes, mounted by server.mjs: every
// Claude Code session whose transcript was written in the last three days,
// desktop-app or not, with its turns (rules in sessions.mjs), the Away switch,
// and the answers the owner sends sessions through the relay hook
// (relay-hook.mjs, installed in user settings), which hands their prompts over
// as files in the relay folder while Away is on.
//   GET  /sessions, /session?id=&limit=, /questions
//   POST /relay/away, /relay/answer, /relay/reply, /relay/unqueue
import { readFile, readdir, stat, open, writeFile, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import {
  PENDING_ID, SESSION_ID, awayOf, awaySwitch, deliveryOf, heldOrphaned, ownerMessage, parseTranscript, relayAnswer, turnSummary,
} from './sessions.mjs';

const SESSION_WINDOW_MS = 3 * 24 * 60 * 60 * 1000;
const TAIL_BYTES = 768 * 1024;
const GONE = 'That was already answered, handed back or timed out';

async function readTail(file, bytes) {
  const { size, mtimeMs } = await stat(file);
  const fh = await open(file, 'r');
  try {
    const len = Math.min(size, bytes);
    const buf = Buffer.alloc(len);
    await fh.read(buf, 0, len, size - len);
    const lines = buf.toString('utf8').split(/\r?\n/);
    if (len < size) lines.shift(); // cut off mid-line
    return { lines, size, mtimeMs, cut: len < size };
  } finally { await fh.close(); }
}

const readJsonFile = async (file) => { try { return JSON.parse(await readFile(file, 'utf8')); } catch { return null; } };
const alive = (pid) => { try { process.kill(pid, 0); return true; } catch (err) { return err.code === 'EPERM'; } };
async function writeJsonFile(file, value) {
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, JSON.stringify(value, null, 2));
}

// relay: the relay folder; projects: ~/.claude/projects; activeMs: how recently a
// transcript was written for its session to count as at work. The server lends
// its context gauges (contextOf), the app's session records (appSessions), the
// plan task a folder's lane is on (taskOf: dir -> { ref, label, title } | null)
// and its worker pool, and says whether the installed hooks are current (hooks:
// () => { current, problems }). Every sweepMs it also looks over the held items, so a
// deleted session's hook is released with no page open.
export function sessionsApi({ relay, projects, activeMs, contextOf, appSessions, pool, taskOf = () => null, hooks = async () => null, sweepMs = 0 }) {
  const transcriptCache = new Map(); // file -> { key, parsed }
  async function transcript(file, limit) {
    const { size, mtimeMs } = await stat(file);
    const key = `${size}:${mtimeMs}:${limit}`;
    const hit = transcriptCache.get(file);
    if (hit?.key === key) return hit.parsed;
    const { lines, cut } = await readTail(file, TAIL_BYTES);
    const parsed = { ...parseTranscript(lines, { limit }), cut, size, mtimeMs };
    transcriptCache.set(file, { key, parsed });
    return parsed;
  }

  // Sessions held items belong to whose app record the board has seen; an item
  // goes when that record is deleted (heldOrphaned in sessions.mjs).
  const sawRecord = new Set();

  async function relayState() {
    const away = awayOf(await readJsonFile(path.join(relay, 'away.json')));
    const byCli = new Map((await appSessions()).filter((a) => a.cli).map((a) => [a.cli, a]));
    const pending = [];
    let names = [];
    try { names = (await readdir(path.join(relay, 'pending'))).filter((n) => n.endsWith('.json')); } catch { /* none yet */ }
    for (const n of names) {
      const p = await readJsonFile(path.join(relay, 'pending', n));
      if (!p) continue;
      // A hook that was killed (its session closed, or it timed out) leaves its file.
      if (p.pid && !alive(p.pid)) { await rm(path.join(relay, 'pending', n), { force: true }); continue; }
      // A deleted session's hook still holds: hand it back, which ends the hook.
      const hasRecord = byCli.has(p.session);
      if (hasRecord) sawRecord.add(p.session);
      const transcriptExists = !!p.transcript && await stat(p.transcript).then(() => true, () => false);
      if (heldOrphaned(p, { transcriptExists, hasRecord, sawRecord: sawRecord.has(p.session) })) {
        const answer = path.join(relay, 'answers', `${p.id}.json`);
        if (PENDING_ID.test(p.id ?? '') && !await stat(answer).then(() => true, () => false)) await writeJsonFile(answer, { release: true });
        continue;
      }
      // A held turn end shows the app's summary of it, once the app has written it.
      if (p.kind === 'stop') {
        let lastReply = null;
        if (transcriptExists) { try { ({ lastReply } = await transcript(p.transcript, 1)); } catch { /* being written */ } }
        p.summary = turnSummary(byCli.get(p.session)?.summary, lastReply);
      }
      pending.push(p);
    }
    for (const id of sawRecord) if (!pending.some((p) => p.session === id)) sawRecord.delete(id);
    return { away, pending, inbox: await inboxes() };
  }

  // ---------- the inbox ----------
  // What the owner sent sessions that no held turn end took: inbox/<session>/,
  // one file per message, named so they sort oldest first. The stop hook takes
  // the oldest before the session's next tool, the relay hook the rest when its
  // turn ends (both in relay-hook.mjs's notes).
  let sent = 0;
  const inboxDir = (session) => path.join(relay, 'inbox', session);
  async function inboxOf(session) {
    let names = [];
    try { names = (await readdir(inboxDir(session))).filter((n) => n.endsWith('.json')).sort(); } catch { return []; }
    const out = [];
    for (const n of names) {
      const m = await readJsonFile(path.join(inboxDir(session), n));
      if (m?.text) out.push({ id: n.slice(0, -5), text: m.text, time: m.time ?? null });
    }
    return out;
  }
  async function inboxes() {
    const all = {};
    let ids = [];
    try { ids = (await readdir(path.join(relay, 'inbox'))).filter((n) => SESSION_ID.test(n)); } catch { return all; }
    for (const id of ids) {
      const list = await inboxOf(id);
      if (list.length) all[id] = list;
    }
    return all;
  }
  async function toInbox(session, text) {
    const name = `${String(Date.now()).padStart(15, '0')}-${String(sent++ % 1e6).padStart(6, '0')}`;
    await writeJsonFile(path.join(inboxDir(session), `${name}.json`), { text, time: Date.now() });
  }

  async function findTranscripts() {
    const out = [];
    let dirs = [];
    try { dirs = await readdir(projects, { withFileTypes: true }); } catch { return out; }
    const cutoff = Date.now() - SESSION_WINDOW_MS;
    for (const d of dirs.filter((x) => x.isDirectory())) {
      let names = [];
      try { names = (await readdir(path.join(projects, d.name))).filter((n) => n.endsWith('.jsonl')); } catch { continue; }
      for (const n of names) {
        const file = path.join(projects, d.name, n);
        const s = await stat(file).catch(() => null);
        if (s && s.mtimeMs >= cutoff) out.push({ id: n.slice(0, -6), file, mtime: s.mtimeMs });
      }
    }
    return out;
  }

  async function sessionList() {
    const [found, app, state] = await Promise.all([findTranscripts(), appSessions(), relayState()]);
    const byCli = new Map(app.filter((a) => a.cli).map((a) => [a.cli, a]));
    const now = Date.now();
    const list = await pool(found, 8, async (f) => {
      const a = byCli.get(f.id);
      if (a?.archived) return null;
      let t;
      try { t = await transcript(f.file, 1); } catch { return null; }
      const context = await contextOf(f.file);
      const pending = state.pending.filter((p) => p.session === f.id).sort((x, y) => x.time - y.time);
      const last = t.entries.at(-1);
      return {
        id: f.id, app: a?.id ?? null, title: a?.title || t.title || '(untitled)', cwd: t.cwd ?? a?.dir ?? null,
        activity: f.mtime, active: now - f.mtime < activeMs, queued: state.inbox[f.id]?.length ?? 0,
        pending: pending.map((p) => ({ id: p.id, kind: p.kind, tool: p.tool ?? null, time: p.time })),
        asking: t.open?.name === 'AskUserQuestion' ? t.open.questions.map((q) => q.question) : null,
        openTool: t.open && t.open.name !== 'AskUserQuestion' ? { name: t.open.name, summary: t.open.summary, time: t.open.time } : null,
        lastText: last ? String(last.text ?? last.summary ?? '').slice(0, 200) : '',
        context,
      };
    });
    return list.filter(Boolean).sort((x, y) => (y.pending.length > 0) - (x.pending.length > 0) || y.activity - x.activity);
  }

  async function sessionDetail(id, limit) {
    if (!SESSION_ID.test(id ?? '')) throw new Error('Bad session id');
    const f = (await findTranscripts()).find((x) => x.id === id);
    if (!f) throw new Error('No recent session with that id');
    const [t, state, app, context] = await Promise.all([transcript(f.file, limit), relayState(), appSessions(), contextOf(f.file)]);
    const a = app.find((x) => x.cli === id);
    return {
      id, app: a?.id ?? null, title: a?.title || t.title || '(untitled)', cwd: t.cwd ?? a?.dir ?? null,
      activity: f.mtime, active: Date.now() - f.mtime < activeMs, entries: t.entries, more: t.more || (t.cut ? 1 : 0),
      open: t.open, away: state.away, queued: state.inbox[id] ?? [],
      pending: state.pending.filter((p) => p.session === id).sort((x, y) => x.time - y.time),
      context,
    };
  }

  async function awaySet(body, { ua } = {}) {
    if (typeof body?.on !== 'boolean') throw new Error('On or off?');
    const away = awaySwitch(body, ua);
    await writeJsonFile(path.join(relay, 'away.json'), away);
    return away;
  }

  // An answer reaches only an item still held: its hook still waiting, and no
  // answer given yet.
  async function relayAnswerTo(body) {
    if (!PENDING_ID.test(body?.id ?? '')) throw new Error('Bad prompt id');
    const pending = await readJsonFile(path.join(relay, 'pending', `${body.id}.json`));
    const answered = await stat(path.join(relay, 'answers', `${body.id}.json`)).then(() => true, () => false);
    if (!pending || answered || (pending.pid && !alive(pending.pid))) throw new Error(GONE);
    await writeJsonFile(path.join(relay, 'answers', `${body.id}.json`), relayAnswer(pending, body));
    return { ok: true };
  }

  // A reply goes straight to a session waiting at its turn's end, else to its
  // inbox. `when` says when it arrives (deliveryOf in sessions.mjs).
  async function relayReply(body) {
    if (!SESSION_ID.test(body?.session ?? '')) throw new Error('Bad session id');
    const text = ownerMessage({ text: body.text });
    const { pending } = await relayState();
    const waiting = pending.find((p) => p.session === body.session && p.kind === 'stop');
    const answered = waiting && await stat(path.join(relay, 'answers', `${waiting.id}.json`)).then(() => true, () => false);
    if (waiting && !answered) {
      await writeJsonFile(path.join(relay, 'answers', `${waiting.id}.json`), { reply: text });
      return { delivered: true, when: deliveryOf({ held: true }) };
    }
    await toInbox(body.session, text);
    const f = (await findTranscripts()).find((x) => x.id === body.session);
    return { delivered: false, when: deliveryOf({ held: false, active: !!f && Date.now() - f.mtime < activeMs }) };
  }

  async function relayUnqueue(body) {
    if (!SESSION_ID.test(body?.session ?? '')) throw new Error('Bad session id');
    await rm(inboxDir(body.session), { recursive: true, force: true });
    return { ok: true };
  }

  // The Questions tab: every held item grouped by session, oldest first, with
  // the session's title, folder and plan task, and the questions sessions are
  // asking in the app's own dialogs (read-only here). count is everything waiting.
  async function questions() {
    const [found, app, state] = await Promise.all([findTranscripts(), appSessions(), relayState()]);
    const byCli = new Map(app.filter((x) => x.cli).map((x) => [x.cli, x]));
    const files = new Map(found.map((f) => [f.id, f.file]));
    const about = async (id, cwd) => {
      const a = byCli.get(id);
      let t = null;
      if (files.has(id)) { try { t = await transcript(files.get(id), 1); } catch { /* being written */ } }
      const dir = t?.cwd ?? cwd ?? a?.dir ?? null;
      return { session: id, app: a?.id ?? null, title: a?.title || t?.title || '(untitled)', cwd: dir, task: dir ? taskOf(dir) : null, t, archived: !!a?.archived };
    };
    const bySession = new Map();
    for (const p of [...state.pending].sort((x, y) => x.time - y.time)) {
      if (!bySession.has(p.session)) bySession.set(p.session, []);
      bySession.get(p.session).push(p);
    }
    const groups = [];
    for (const [id, items] of bySession) {
      const { t, archived, ...who } = await about(id, items[0].cwd);
      groups.push({ ...who, since: items[0].time, items });
    }
    const asked = [];
    for (const f of found) {
      if (bySession.get(f.id)?.some((p) => p.kind === 'question')) continue;
      const { t, archived, ...who } = await about(f.id, null);
      if (archived || t?.open?.name !== 'AskUserQuestion') continue;
      asked.push({ ...who, time: t.open.time, questions: t.open.questions ?? [] });
    }
    asked.sort((x, y) => (x.time ?? 0) - (y.time ?? 0));
    return { updated: Date.now(), away: state.away, count: state.pending.length + asked.length, groups, asked, hooks: await hooks().catch(() => null) };
  }

  if (sweepMs > 0) setInterval(() => { relayState().catch(() => {}); }, sweepMs).unref();

  const POSTS = { '/relay/away': awaySet, '/relay/answer': relayAnswerTo, '/relay/reply': relayReply, '/relay/unqueue': relayUnqueue };
  return {
    // The JSON a GET route answers (url: a URL), or undefined when the route isn't one of these.
    get(url) {
      if (url.pathname === '/questions') return questions();
      if (url.pathname === '/sessions') return sessionList().then((sessions) => ({ updated: Date.now(), sessions }));
      if (url.pathname === '/session') return sessionDetail(url.searchParams.get('id'), Math.min(2000, Number(url.searchParams.get('limit')) || 300));
      return undefined;
    },
    // The result of a POST route, or undefined when the route isn't one of these.
    // ctx: { ua }, the page's user agent.
    post(route, body, ctx = {}) {
      return POSTS[route]?.(body, ctx);
    },
  };
}
