// The Project Manager's Sessions and relay routes, mounted by server.mjs: every
// Claude Code session whose transcript was written in the last three days,
// desktop-app or not, with its turns (rules in sessions.mjs), and the answers the
// owner sends a session through the relay hook (relay-hook.mjs, installed in
// user settings), which hands its prompts over as files in the relay folder;
// only sessions switched on in on.json wait for the board.
//   GET  /sessions, /session?id=&limit=
//   POST /relay/on, /relay/answer, /relay/reply, /relay/unqueue
import { readFile, readdir, stat, open, writeFile, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { PENDING_ID, SESSION_ID, parseTranscript, relayAnswer } from './sessions.mjs';

const SESSION_WINDOW_MS = 3 * 24 * 60 * 60 * 1000;
const TAIL_BYTES = 768 * 1024;

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
// its context gauges (contextOf), the app's session records (appSessions) and
// its worker pool.
export function sessionsApi({ relay, projects, activeMs, contextOf, appSessions, pool }) {
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

  async function relayState() {
    const on = (await readJsonFile(path.join(relay, 'on.json')))?.sessions ?? {};
    const pending = [];
    let names = [];
    try { names = (await readdir(path.join(relay, 'pending'))).filter((n) => n.endsWith('.json')); } catch { /* none yet */ }
    for (const n of names) {
      const p = await readJsonFile(path.join(relay, 'pending', n));
      if (!p) continue;
      // A hook that was killed (its session closed, or it timed out) leaves its file.
      if (p.pid && !alive(p.pid)) { await rm(path.join(relay, 'pending', n), { force: true }); continue; }
      pending.push(p);
    }
    const replies = {};
    try {
      for (const n of await readdir(path.join(relay, 'replies'))) {
        const r = await readJsonFile(path.join(relay, 'replies', n));
        if (r?.text) replies[n.replace(/\.json$/, '')] = r;
      }
    } catch { /* none yet */ }
    return { on, pending, replies };
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
        activity: f.mtime, active: now - f.mtime < activeMs, on: !!state.on[f.id], queued: !!state.replies[f.id],
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
      open: t.open, on: !!state.on[id], queued: state.replies[id] ?? null,
      pending: state.pending.filter((p) => p.session === id).sort((x, y) => x.time - y.time),
      context,
    };
  }

  async function relaySwitch(body) {
    if (!SESSION_ID.test(body?.session ?? '')) throw new Error('Bad session id');
    const file = path.join(relay, 'on.json');
    const cur = (await readJsonFile(file)) ?? { sessions: {} };
    cur.sessions ??= {};
    if (body.on) cur.sessions[body.session] = { since: Date.now() };
    else delete cur.sessions[body.session];
    await writeJsonFile(file, cur);
    return { on: !!body.on };
  }

  async function relayAnswerTo(body) {
    if (!PENDING_ID.test(body?.id ?? '')) throw new Error('Bad prompt id');
    const pending = await readJsonFile(path.join(relay, 'pending', `${body.id}.json`));
    if (!pending) throw new Error('That prompt is no longer waiting (answered, timed out, or handed back to the app)');
    await writeJsonFile(path.join(relay, 'answers', `${body.id}.json`), relayAnswer(pending, body));
    return { ok: true };
  }

  // A reply goes straight to a session waiting at its turn's end, else waits for
  // that turn's end in replies/.
  async function relayReply(body) {
    if (!SESSION_ID.test(body?.session ?? '')) throw new Error('Bad session id');
    const text = String(body.text ?? '').trim();
    if (!text) throw new Error('Type a reply first');
    const { on, pending } = await relayState();
    if (!on[body.session]) throw new Error('Switch on "Answer from board" for this session first');
    const waiting = pending.find((p) => p.session === body.session && p.kind === 'stop');
    if (waiting) {
      await writeJsonFile(path.join(relay, 'answers', `${waiting.id}.json`), { reply: text.slice(0, 20000) });
      return { delivered: true };
    }
    await writeJsonFile(path.join(relay, 'replies', `${body.session}.json`), { text: text.slice(0, 20000), time: Date.now() });
    return { delivered: false };
  }

  async function relayUnqueue(body) {
    if (!SESSION_ID.test(body?.session ?? '')) throw new Error('Bad session id');
    await rm(path.join(relay, 'replies', `${body.session}.json`), { force: true });
    return { ok: true };
  }

  const POSTS = { '/relay/on': relaySwitch, '/relay/answer': relayAnswerTo, '/relay/reply': relayReply, '/relay/unqueue': relayUnqueue };
  return {
    // The JSON a GET route answers (url: a URL), or undefined when the route isn't one of these.
    get(url) {
      if (url.pathname === '/sessions') return sessionList().then((sessions) => ({ updated: Date.now(), sessions }));
      if (url.pathname === '/session') return sessionDetail(url.searchParams.get('id'), Math.min(2000, Number(url.searchParams.get('limit')) || 300));
      return undefined;
    },
    // The result of a POST route, or undefined when the route isn't one of these.
    post(route, body) {
      return POSTS[route]?.(body);
    },
  };
}
