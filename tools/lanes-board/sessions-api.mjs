// The Project Manager's Sessions and relay routes, mounted by server.mjs: every
// Claude Code session whose transcript was written in the last three days,
// desktop-app or not, with its turns (rules in sessions.mjs), the Away switch
// (lock-screen notifications only), and the replies and commands the owner
// sends sessions through the relay folder's inboxes (relay-hook.mjs and
// stop-hook.mjs, installed in user settings, hand them over). Nothing here
// answers a session's prompts: since Oct 6 they are answered in the Claude app.
//   GET  /sessions (with older: sessions past the list's 3 days known by their
//        posted media; hooks: whether the installed hooks are current),
//        /session?id=&limit= (with its visuals and images of the work), /away,
//        /work/<session>/<line>-<n> (an image of the work, served from its
//        transcript: workImage)
//   POST /relay/away, /relay/reply, /relay/unqueue,
//        /session/command { session, command: show | stop | end }
import { readFile, readdir, stat, open, rm } from 'node:fs/promises';
import path from 'node:path';
import { inboxDir, postToInbox, writeJsonAtomic } from './inbox.mjs';
import { workImageAt, workImagesOf } from './work-images.mjs';
import {
  SESSION_ID, STOP_NOW, awayOf, awaySwitch, deliveryOf, endedAtOf, ownerMessage, parseTranscript, sessionState, turnSummary,
} from './sessions.mjs';

const SESSION_WINDOW_MS = 3 * 24 * 60 * 60 * 1000;
const TAIL_BYTES = 768 * 1024;
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
// Whole files only, so a hook never reads one half written.
const writeJsonFile = async (file, value) => writeJsonAtomic(file, value);

// relay: the relay folder; projects: ~/.claude/projects; activeMs: how recently a
// transcript was written for its session to count as at work. The server lends
// its context gauges (contextOf), the app's session records (appSessions), the
// plan task a folder's lane is on (taskOf: dir -> { ref, label, title } | null)
// and its worker pool, and says whether the installed hooks are current (hooks:
// () => { current, problems }). stopFile: the stop list
// End work writes (stop-hook.mjs reads it); prOf(branch): the open pull request
// of a branch ({ number, title, url, base, draft }) or null; branchOf(dir): the
// branch checked out in a folder, or null, for a session whose transcript names
// none (one started outside git, then moved into a worktree, records "HEAD").
// media: the posted shots and clips (media-api.mjs: of(session), sessions()), or null.
export function sessionsApi({ relay, projects, activeMs, contextOf, appSessions, pool, taskOf = () => null, hooks = async () => null,
  stopFile = null, prOf = () => null, branchOf = () => null, media = null }) {
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

  const readAway = async () => awayOf(await readJsonFile(path.join(relay, 'away.json')));

  // ---------- the inbox ----------
  // What the owner sent sessions that they haven't taken yet: inbox/<session>/,
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
  // A session's branch: its transcript's, else the one checked out where it works.
  const branchIn = (t, dir) => t.branch ?? (dir ? branchOf(dir) : null) ?? null;
  // s: the session as listed; t: its transcript; a: its app record; stops: the stop list.
  async function facts(s, t, a, stops) {
    const endedAt = endedAtOf(stops, { id: s.id, cwd: s.cwd });
    const branch = branchIn(t, s.cwd);
    return {
      state: sessionState({ ...s, endedAt }), endedAt, stopping: await stopping(s.id),
      summary: turnSummary(a?.summary, t.lastReply), branch, task: s.cwd ? taskOf(s.cwd) : null, pr: branch ? prOf(branch) : null,
    };
  }

  async function sessionList() {
    const [found, app, inbox, stops] = await Promise.all([findTranscripts(), appSessions(), inboxes(), readStops()]);
    const byCli = new Map(app.filter((a) => a.cli).map((a) => [a.cli, a]));
    const now = Date.now();
    const list = await pool(found, 8, async (f) => {
      const a = byCli.get(f.id);
      if (a?.archived) return null;
      let t;
      try { t = await transcript(f.file, 1); } catch { return null; }
      const context = await contextOf(f.file);
      const last = t.entries.at(-1);
      const s = {
        id: f.id, app: a?.id ?? null, remote: a?.remote ?? null, title: a?.title || t.title || '(untitled)', cwd: t.cwd ?? a?.dir ?? null,
        activity: f.mtime, active: now - f.mtime < activeMs, queued: inbox[f.id]?.length ?? 0,
        asking: t.open?.name === 'AskUserQuestion' ? t.open.questions.map((q) => q.question) : null,
        openTool: t.open && t.open.name !== 'AskUserQuestion' ? { name: t.open.name, summary: t.open.summary, time: t.open.time } : null,
        lastText: last ? String(last.text ?? last.summary ?? '').slice(0, 200) : '',
        context,
      };
      return { ...s, ...await facts(s, t, a, stops) };
    });
    return list.filter(Boolean).sort((x, y) => y.activity - x.activity);
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
        cwd: posted.cwd, branch: posted.branch, activity: posted.visuals[0].time, active: false, entries: [], more: 0, open: null, away: null, queued: [],
        asking: null, context: null, state: 'ended', endedAt: null, stopping: false, summary: null, task: posted.cwd ? taskOf(posted.cwd) : null,
        pr: posted.branch ? prOf(posted.branch) : null, visuals: posted.visuals, workImages: [] };
    }
    const [t, away, queued, app, context, stops] = await Promise.all([transcript(f.file, limit), readAway(), inboxOf(id), appSessions(), contextOf(f.file), readStops()]);
    const a = app.find((x) => x.cli === id);
    const d = {
      id, app: a?.id ?? null, remote: a?.remote ?? null, title: a?.title || t.title || '(untitled)', cwd: t.cwd ?? a?.dir ?? null,
      activity: f.mtime, active: Date.now() - f.mtime < activeMs, entries: t.entries, more: t.more || (t.cut ? 1 : 0),
      open: t.open, away, queued,
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

  // A reply waits in the session's inbox. `when` says when it arrives
  // (deliveryOf in sessions.mjs).
  async function relayReply(body) {
    if (!SESSION_ID.test(body?.session ?? '')) throw new Error('Bad session id');
    postToInbox(relay, body.session, ownerMessage(body.command != null ? { command: body.command } : { text: body.text }));
    const f = (await findTranscripts()).find((x) => x.id === body.session);
    return { delivered: false, when: deliveryOf({ active: !!f && Date.now() - f.mtime < activeMs }) };
  }

  // The session page's commands. Show me goes as a reply would. Stop now has
  // the stop hook refuse the session's tools until its turn ends (relay-hook.mjs
  // clears it then). End work puts it on the stop list, as ending a launched
  // lane does.
  async function sessionCommand(body) {
    const session = body?.session;
    if (!SESSION_ID.test(session ?? '')) throw new Error('Bad session id');
    if (body.command === 'show') return relayReply({ session, command: body.command });
    const f = (await findTranscripts()).find((x) => x.id === session);
    const active = !!f && Date.now() - f.mtime < activeMs;
    if (body.command === 'stop') {
      if (!active) return { delivered: false, when: 'idle' };
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
      return { delivered: true, when: active ? 'next-step' : 'turn-end' };
    }
    throw new Error('No such command');
  }

  async function relayUnqueue(body) {
    if (!SESSION_ID.test(body?.session ?? '')) throw new Error('Bad session id');
    await rm(inboxDir(relay, body.session), { recursive: true, force: true });
    return { ok: true };
  }

  // A session asking in the app: its transcript's open call is AskUserQuestion,
  // and the app hasn't archived it.
  const isAsking = (t, archived) => !archived && t?.open?.name === 'AskUserQuestion';

  const POSTS = { '/relay/away': awaySet, '/relay/reply': relayReply, '/relay/unqueue': relayUnqueue, '/session/command': sessionCommand };
  return {
    // The JSON a GET route answers (url: a URL), or undefined when the route isn't one of these.
    get(url) {
      if (url.pathname === '/away') return readAway();
      if (url.pathname === '/sessions') {
        return sessionList().then(async (sessions) => ({ updated: Date.now(), sessions, older: await older(sessions), hooks: await hooks().catch(() => null) }));
      }
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
    // For "ready to merge" (merge-api.mjs): the recent sessions with their branches.
    async branches() {
      const found = await findTranscripts();
      return (await pool(found, 8, async (f) => {
        try { const t = await transcript(f.file, 1); return { id: f.id, branch: branchIn(t, t.cwd) }; } catch { return null; }
      })).filter((x) => x?.branch);
    },
    // For the bell (bell-api.mjs): the ids of sessions asking in the app now.
    async askingNow() {
      const [found, app] = await Promise.all([findTranscripts(), appSessions()]);
      const archived = new Set(app.filter((a) => a.cli && a.archived).map((a) => a.cli));
      const ids = await pool(found, 8, async (f) => {
        try { return isAsking(await transcript(f.file, 1), archived.has(f.id)) ? f.id : null; } catch { return null; }
      });
      return ids.filter(Boolean);
    },
    // For Docs (docs-api.mjs): a session's branch, or null.
    async branchOfSession(session) {
      if (!SESSION_ID.test(session ?? '')) return null;
      const f = (await findTranscripts()).find((x) => x.id === session) ?? await findTranscript(session);
      if (!f) return null;
      try { const t = await transcript(f.file, 1); return branchIn(t, t.cwd); } catch { return null; }
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
