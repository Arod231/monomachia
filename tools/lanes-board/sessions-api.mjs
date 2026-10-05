// The Project Manager's Sessions and relay routes, mounted by server.mjs: every
// Claude Code session whose transcript was written in the last three days,
// desktop-app or not, with its turns (rules in sessions.mjs), the Away switch,
// and the answers the owner sends sessions through the relay hook
// (relay-hook.mjs, installed in user settings), which hands their prompts over
// as files in the relay folder while Away is on.
//   GET  /sessions (with older: sessions past the list's 3 days known by their
//        posted media), /session?id=&limit= (with its visuals and images of the
//        work), /questions, /work/<session>/<line>-<n> (an image of the work,
//        served from its transcript: workImage)
//   POST /relay/away, /relay/answer, /relay/reply, /relay/unqueue,
//        /session/command { session, command: approve | show | stop | end }
import { readFile, readdir, stat, open, rm } from 'node:fs/promises';
import path from 'node:path';
import { inboxDir, postToInbox, writeJsonAtomic } from './inbox.mjs';
import { workImageAt, workImagesOf } from './work-images.mjs';
import {
  PENDING_ID, SESSION_ID, STOP_NOW, awayOf, awaySwitch, deliveryOf, endedAtOf, heldAnsweredElsewhere, heldOrphaned, ownerMessage, parseTranscript, relayAnswer,
  sessionState, turnSummary,
} from './sessions.mjs';

const SESSION_WINDOW_MS = 3 * 24 * 60 * 60 * 1000;
const TAIL_BYTES = 768 * 1024;
const GONE = 'That was already answered, handed back or timed out';
const STOP_NOW_MS = 6 * 60 * 60 * 1000; // a Stop now whose turn never ended is let go after this

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
// Whole files only, so a hook polling for one never reads it half written.
const writeJsonFile = async (file, value) => writeJsonAtomic(file, value);

// relay: the relay folder; projects: ~/.claude/projects; activeMs: how recently a
// transcript was written for its session to count as at work. The server lends
// its context gauges (contextOf), the app's session records (appSessions), the
// plan task a folder's lane is on (taskOf: dir -> { ref, label, title } | null)
// and its worker pool, and says whether the installed hooks are current (hooks:
// () => { current, problems }). Every sweepMs it also looks over the held items, so a
// deleted session's hook is released with no page open. stopFile: the stop list
// End work writes (stop-hook.mjs reads it); prOf(branch): the open pull request
// of a branch ({ number, title, url, base, draft }) or null. media: the posted
// shots and clips (media-api.mjs: of(session), sessions()), or null.
export function sessionsApi({ relay, projects, activeMs, contextOf, appSessions, pool, taskOf = () => null, hooks = async () => null, sweepMs = 0,
  stopFile = null, prOf = () => null, media = null }) {
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
      // A prompt answered in the app or over Remote Control: its hook still
      // waits, so hand it back, which ends the hook with no answer of its own.
      if (p.kind !== 'stop' && transcriptExists) {
        let entries = [];
        try { ({ entries } = await transcript(p.transcript, 60)); } catch { /* being written */ }
        if (heldAnsweredElsewhere(p, entries)) {
          const answer = path.join(relay, 'answers', `${p.id}.json`);
          if (PENDING_ID.test(p.id ?? '') && !await stat(answer).then(() => true, () => false)) await writeJsonFile(answer, { release: true });
          continue;
        }
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
  // turn ends (inbox.mjs, shared with both hooks).
  async function inboxOf(session) {
    let names = [];
    try { names = (await readdir(inboxDir(relay, session))).filter((n) => n.endsWith('.json')).sort(); } catch { return []; }
    const out = [];
    for (const n of names) {
      const m = await readJsonFile(path.join(inboxDir(relay, session), n));
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

  // A session's transcript however old, for a page opened from its media.
  async function findTranscript(id) {
    let dirs = [];
    try { dirs = await readdir(projects, { withFileTypes: true }); } catch { return null; }
    for (const d of dirs.filter((x) => x.isDirectory())) {
      const file = path.join(projects, d.name, `${id}.jsonl`);
      const s = await stat(file).catch(() => null);
      if (s) return { id, file, mtime: s.mtimeMs };
    }
    return null;
  }
  const mediaOf = (id) => media?.of(id) ?? { visuals: [], cwd: null, branch: null };
  // Its images of the work (work-images.mjs), newest first, as the viewer shows them.
  async function workList(id, file) {
    let found = [];
    try { found = await workImagesOf(file); } catch { /* being written */ }
    return [...found].reverse().map((w) => ({ id: `${w.line}-${w.n}`, kind: 'still', url: `/work/${id}/${w.line}-${w.n}`, poster: null, task: null,
      caption: w.tool === 'Read' ? w.source.split(/[\\/]/).pop() : w.source, source: w.source, time: w.time }));
  }
  const IMAGE_TYPES = new Set(['image/png', 'image/jpeg', 'image/webp', 'image/gif']);
  // GET /work/<session>/<line>-<n>: { type, bytes }, null when it isn't one of
  // the session's images of the work, or undefined for another route.
  async function workImage(url) {
    if (!url.pathname.startsWith('/work/')) return undefined;
    const m = /^\/work\/([^/]+)\/(\d+)-(\d+)$/.exec(url.pathname);
    if (!m || !SESSION_ID.test(m[1])) return null;
    const f = (await findTranscripts()).find((x) => x.id === m[1]) ?? await findTranscript(m[1]);
    const img = f && await workImageAt(f.file, Number(m[2]), Number(m[3]));
    return img && IMAGE_TYPES.has(img.type) ? img : null;
  }

  // ---------- what a session's card and page say about it ----------
  async function readStops() {
    if (!stopFile) return [];
    try { return JSON.parse(await readFile(stopFile, 'utf8')).entries ?? []; } catch { return []; }
  }
  const stopNowFile = (session) => path.join(relay, 'stopnow', `${session}.json`);
  async function stopping(session) {
    const m = await readJsonFile(stopNowFile(session));
    return !!m && Date.now() - (m.time ?? 0) < STOP_NOW_MS;
  }
  // s: the session as listed; t: its transcript; a: its app record; stops: the stop list.
  async function facts(s, t, a, stops) {
    const endedAt = endedAtOf(stops, { id: s.id, cwd: s.cwd });
    const branch = t.branch ?? null;
    return {
      state: sessionState({ ...s, endedAt }), endedAt, stopping: await stopping(s.id),
      summary: turnSummary(a?.summary, t.lastReply), branch, task: s.cwd ? taskOf(s.cwd) : null, pr: branch ? prOf(branch) : null,
    };
  }

  async function sessionList() {
    const [found, app, state, stops] = await Promise.all([findTranscripts(), appSessions(), relayState(), readStops()]);
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
      const s = {
        id: f.id, app: a?.id ?? null, remote: a?.remote ?? null, title: a?.title || t.title || '(untitled)', cwd: t.cwd ?? a?.dir ?? null,
        activity: f.mtime, active: now - f.mtime < activeMs, queued: state.inbox[f.id]?.length ?? 0,
        pending: pending.map((p) => ({ id: p.id, kind: p.kind, tool: p.tool ?? null, time: p.time })),
        asking: t.open?.name === 'AskUserQuestion' ? t.open.questions.map((q) => q.question) : null,
        openTool: t.open && t.open.name !== 'AskUserQuestion' ? { name: t.open.name, summary: t.open.summary, time: t.open.time } : null,
        lastText: last ? String(last.text ?? last.summary ?? '').slice(0, 200) : '',
        context,
      };
      return { ...s, ...await facts(s, t, a, stops) };
    });
    return list.filter(Boolean).sort((x, y) => (y.pending.length > 0) - (x.pending.length > 0) || y.activity - x.activity);
  }

  async function sessionDetail(id, limit) {
    if (!SESSION_ID.test(id ?? '')) throw new Error('Bad session id');
    const f = (await findTranscripts()).find((x) => x.id === id) ?? await findTranscript(id);
    const posted = mediaOf(id);
    if (!f) {
      // Its transcript is gone (the session was deleted) but what it posted stays.
      if (!posted.visuals.length) throw new Error('No recent session with that id');
      const a = (await appSessions()).find((x) => x.cli === id);
      return { id, gone: true, app: a?.id ?? null, remote: a?.remote ?? null, title: a?.title || (posted.cwd ? `A session in ${path.basename(posted.cwd)}` : '(untitled)'),
        cwd: posted.cwd, branch: posted.branch, activity: posted.visuals[0].time, active: false, entries: [], more: 0, open: null, away: null, queued: [], pending: [],
        asking: null, context: null, state: 'ended', endedAt: null, stopping: false, summary: null, task: posted.cwd ? taskOf(posted.cwd) : null,
        pr: posted.branch ? prOf(posted.branch) : null, visuals: posted.visuals, workImages: [] };
    }
    const [t, state, app, context, stops] = await Promise.all([transcript(f.file, limit), relayState(), appSessions(), contextOf(f.file), readStops()]);
    const a = app.find((x) => x.cli === id);
    const d = {
      id, app: a?.id ?? null, remote: a?.remote ?? null, title: a?.title || t.title || '(untitled)', cwd: t.cwd ?? a?.dir ?? null,
      activity: f.mtime, active: Date.now() - f.mtime < activeMs, entries: t.entries, more: t.more || (t.cut ? 1 : 0),
      open: t.open, away: state.away, queued: state.inbox[id] ?? [],
      pending: state.pending.filter((p) => p.session === id).sort((x, y) => x.time - y.time),
      asking: t.open?.name === 'AskUserQuestion' ? t.open.questions.map((q) => q.question) : null,
      context, visuals: posted.visuals, workImages: await workList(id, f.file),
    };
    return { ...d, ...await facts(d, t, a, stops) };
  }

  // The Sessions list's Older filter: sessions with posted media that the
  // list's 3 days leave out, newest post first.
  async function older(sessions) {
    if (!media) return [];
    const listed = new Set(sessions.map((s) => s.id));
    const rest = media.sessions().filter((m) => !listed.has(m.id));
    if (!rest.length) return [];
    const app = await appSessions();
    return rest.map((m) => {
      const a = app.find((x) => x.cli === m.id);
      if (a?.archived) return null;
      return { ...m, app: a?.id ?? null, title: a?.title || (m.cwd ? `A session in ${path.basename(m.cwd)}` : '(untitled)') };
    }).filter(Boolean).sort((x, y) => y.latest - x.latest);
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
    return send(body.session, ownerMessage(body.command != null ? { command: body.command } : { text: body.text }));
  }
  // text, worded already, to a session wherever it is.
  async function send(session, text) {
    const body = { session };
    const { pending } = await relayState();
    const waiting = pending.find((p) => p.session === body.session && p.kind === 'stop');
    const answered = waiting && await stat(path.join(relay, 'answers', `${waiting.id}.json`)).then(() => true, () => false);
    if (waiting && !answered) {
      await writeJsonFile(path.join(relay, 'answers', `${waiting.id}.json`), { reply: text });
      return { delivered: true, when: deliveryOf({ held: true }) };
    }
    postToInbox(relay, body.session, text);
    const f = (await findTranscripts()).find((x) => x.id === body.session);
    return { delivered: false, when: deliveryOf({ held: false, active: !!f && Date.now() - f.mtime < activeMs }) };
  }

  // The session page's commands. Approve & continue and Show me go as a reply
  // would. Stop now has the stop hook refuse the session's tools until its turn
  // ends (relay-hook.mjs clears it then), so with Away on it waits for the owner.
  // End work puts it on the stop list, as ending a launched lane does, and hands
  // back anything it holds so its turn can end.
  async function sessionCommand(body) {
    const session = body?.session;
    if (!SESSION_ID.test(session ?? '')) throw new Error('Bad session id');
    if (body.command === 'approve' || body.command === 'show') return relayReply({ session, command: body.command });
    const { pending } = await relayState();
    const held = pending.filter((p) => p.session === session);
    const f = (await findTranscripts()).find((x) => x.id === session);
    const active = !!f && Date.now() - f.mtime < activeMs;
    if (body.command === 'stop') {
      if (held.some((p) => p.kind === 'stop')) return { delivered: false, when: 'stopped' };
      if (!active && !held.length) return { delivered: false, when: 'idle' };
      await writeJsonFile(stopNowFile(session), { text: STOP_NOW, time: Date.now() });
      return { delivered: true, when: 'next-step' };
    }
    if (body.command === 'end') {
      if (!stopFile) throw new Error('End work is off here');
      const [app, stops] = await Promise.all([appSessions(), readStops()]);
      let title = app.find((x) => x.cli === session)?.title ?? null;
      if (!title && f) { try { title = (await transcript(f.file, 1)).title; } catch { /* being written */ } }
      const entries = stops.filter((e) => Date.now() - e.requestedAt < 14 * 24 * 60 * 60 * 1000);
      entries.push({ id: `session-${session}-${Date.now()}`, label: title || 'this session', branch: null, worktree: null,
        sessions: [session], requestedAt: Date.now(), firedAt: null });
      await writeJsonFile(stopFile, { entries });
      for (const p of held) {
        const answer = path.join(relay, 'answers', `${p.id}.json`);
        if (!await stat(answer).then(() => true, () => false)) await writeJsonFile(answer, { release: true });
      }
      return { delivered: true, when: active || held.length ? 'next-step' : 'turn-end' };
    }
    throw new Error('No such command');
  }

  async function relayUnqueue(body) {
    if (!SESSION_ID.test(body?.session ?? '')) throw new Error('Bad session id');
    await rm(inboxDir(relay, body.session), { recursive: true, force: true });
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
      return { session: id, app: a?.id ?? null, remote: a?.remote ?? null, title: a?.title || t?.title || '(untitled)', cwd: dir, task: dir ? taskOf(dir) : null, t,
        archived: !!a?.archived };
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

  const POSTS = { '/relay/away': awaySet, '/relay/answer': relayAnswerTo, '/relay/reply': relayReply, '/relay/unqueue': relayUnqueue,
    '/session/command': sessionCommand };
  return {
    // The JSON a GET route answers (url: a URL), or undefined when the route isn't one of these.
    get(url) {
      if (url.pathname === '/questions') return questions();
      if (url.pathname === '/sessions') return sessionList().then(async (sessions) => ({ updated: Date.now(), sessions, older: await older(sessions) }));
      if (url.pathname === '/session') return sessionDetail(url.searchParams.get('id'), Math.min(2000, Number(url.searchParams.get('limit')) || 300));
      return undefined;
    },
    // The result of a POST route, or undefined when the route isn't one of these.
    // ctx: { ua }, the page's user agent.
    post(route, body, ctx = {}) {
      return POSTS[route]?.(body, ctx);
    },
    workImage,
    // For Docs (docs-api.mjs): a session's transcript, however old, or null.
    fileOf: async (id) => (SESSION_ID.test(id ?? '') ? ((await findTranscripts()).find((x) => x.id === id) ?? await findTranscript(id))?.file ?? null : null),
    // For the bell (bell-api.mjs): the items held now, and sessions' titles.
    held: async () => (await relayState()).pending,
    // For Merge (merge-api.mjs): a worded message to a session, delivered as a
    // reply would be, and the recent sessions with their branches.
    async deliver(session, text) {
      if (!SESSION_ID.test(session ?? '')) throw new Error('Bad session id');
      return send(session, text);
    },
    async branches() {
      const found = await findTranscripts();
      return (await pool(found, 8, async (f) => {
        try { return { id: f.id, branch: (await transcript(f.file, 1)).branch ?? null }; } catch { return null; }
      })).filter((x) => x?.branch);
    },
    async titlesOf(ids) {
      const [found, app] = await Promise.all([findTranscripts(), appSessions()]);
      const titles = new Map();
      for (const id of ids) {
        const a = app.find((x) => x.cli === id);
        const f = found.find((x) => x.id === id);
        let t = null;
        if (f && !a?.title) { try { t = await transcript(f.file, 1); } catch { /* being written */ } }
        titles.set(id, a?.title || t?.title || '(untitled)');
      }
      return titles;
    },
  };
}
