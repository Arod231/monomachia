// The Project Manager (the lanes board): a live page of every plan and every worktree in the
// Monomachia repo. It reads the plans it follows (the roadmap, milestone 1, the
// Godot rebuild, and authored animation as closed history; PLANS in plans.mjs)
// from every branch and worktree, each worktree's git state and its Claude Code
// session's last activity, so it follows the other sessions without anyone
// asking. Its default view, the Roadmap tab, shows the roadmap's phases with the
// current one first; Progress has every plan's tasks (tasks the Oct 4 triage
// moved show "moved → M1/M2" and no longer count as open), Graph what waits on
// what, and Sessions every recent Claude session. From the page you can queue
// tasks and launch a desktop-app session to build them, which the board starts
// itself so a launch from the phone needs nobody at the PC (rules in
// launcher.mjs, the press in press-send.ps1), start a new session with no tasks
// on the latest master for the owner to prompt from the Claude app ("New
// session"), end a launched session's work, answer a session (through
// relay-hook.mjs), see how full each session's context is (a gauge and a
// turn-by-turn chart, rules in sessions.mjs), and open the second brain. It never fetches or takes git locks.
//   npm run board   ->   http://localhost:5197
// It also listens on this PC's Tailscale addresses, so the owner's phone can open
// it (http://<tailscale ip>:5197 or http://<pc name>:5197); a phone gets the
// mobile page, m.html. LANES_LOCAL_ONLY=1 keeps it to this PC.
// State shared by every checkout (launch records, the stop list, the relay) lives
// outside the repo: ~/.claude/lanes-board/, ~/.claude/lanes-stop.json and
// ~/.claude/lanes-relay/.
import { createServer } from 'node:http';
import { execFile } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { promisify } from 'node:util';
import { readFile, readdir, stat, access, writeFile, open, mkdir, rename } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { gzipSync } from 'node:zlib';
import { StringDecoder } from 'node:string_decoder';
import os from 'node:os';
import path from 'node:path';
import { PLANS, PLAN_BY_KEY, SUBJECT_TASK, parsePlan, mergeCopies, goalFor, cancelStops, linkMoved, planOfBranch, roadmapView } from './plans.mjs';
import { fromTailnetOrLocal, knownHost, pageFor, sameOrigin, tailnetIPv4s, tailscaleSelf, wantsGzip } from './access.mjs';
import { awayOf, contextTracker, remoteLinkOf } from './sessions.mjs';
import { sessionsApi } from './sessions-api.mjs';
import { hooksStatusOf } from './hooks.mjs';
import { bellApi } from './bell-api.mjs';
import { pushApi } from './push-api.mjs';
import { ghRunner, mergeApi } from './merge-api.mjs';
import { mediaApi } from './media-api.mjs';
import { docsApi } from './docs-api.mjs';
import { LAUNCH_FRESH_MS, createStarter, firstPrompt, linkCandidates, linkLaunches, newSessionLaunch, pressResult, startView } from './launcher.mjs';

const run = promisify(execFile);
const HERE = path.dirname(fileURLToPath(import.meta.url));
const STATE = process.env.LANES_STATE ?? path.join(os.homedir(), '.claude', 'lanes-board');
const PORT = Number(process.env.PORT || 5197);
const CACHE_MS = 4000;
const ACTIVE_MS = 3 * 60 * 1000; // a session that wrote its transcript this recently is at work
const RECENT_MS = 60 * 60 * 1000;
const PROJECTS = process.env.LANES_PROJECTS ?? path.join(os.homedir(), '.claude', 'projects');
// Files that don't mean a worktree is mid-task: local tooling, and Godot's
// re-save of the bus layout on a test run.
const IGNORED_DIRTY = [/^\.claude\//, /^game\/default_bus_layout\.tres$/];

async function git(cwd, ...args) {
  const { stdout } = await run('git', ['--no-optional-locks', ...args], { cwd, maxBuffer: 64 << 20, windowsHide: true });
  return stdout;
}
async function tryGit(cwd, ...args) {
  try { return await git(cwd, ...args); } catch { return null; }
}
async function pool(items, n, fn) {
  const out = new Array(items.length);
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(n, items.length) }, async () => {
    while (i < items.length) { const k = i++; out[k] = await fn(items[k], k); }
  }));
  return out;
}

// The main checkout is the parent of the shared .git folder, wherever this runs from.
const REPO = process.env.REPO
  ?? path.dirname(path.resolve(HERE, (await git(HERE, 'rev-parse', '--git-common-dir')).trim()));

// ---------- plan parsing (rules in plans.mjs) ----------

const parseCache = new Map(); // `${plan}:${blob sha}` -> parsed
function parse(plan, text, blob) {
  const key = blob && `${plan.key}:${blob}`;
  if (key && parseCache.has(key)) return parseCache.get(key);
  const parsed = parsePlan(plan, text);
  if (key) parseCache.set(key, parsed);
  return parsed;
}

// ---------- git state ----------

async function worktrees() {
  const out = await git(REPO, 'worktree', 'list', '--porcelain');
  const list = [];
  let cur = null;
  for (const line of out.split(/\r?\n/)) {
    if (line.startsWith('worktree ')) list.push(cur = { path: path.normalize(line.slice(9)), branch: null, head: null, locked: false });
    else if (!cur) continue;
    else if (line.startsWith('HEAD ')) cur.head = line.slice(5);
    else if (line.startsWith('branch ')) cur.branch = line.slice(7).replace('refs/heads/', '');
    else if (line.startsWith('locked')) cur.locked = true;
  }
  return list;
}

const blobCache = new Map(); // `${commit}:${file}` -> { blob, time } | null
async function planAt(commit, file) {
  const key = `${commit}:${file}`;
  if (!blobCache.has(key)) {
    const blob = (await tryGit(REPO, 'rev-parse', '-q', '--verify', `${commit}:${file}`))?.trim() || null;
    const time = blob ? Number((await tryGit(REPO, 'log', '-1', '--format=%ct', commit, '--', file))?.trim()) || 0 : 0;
    blobCache.set(key, blob ? { blob, time } : null);
  }
  return blobCache.get(key);
}
const textCache = new Map();
async function blobText(blob) {
  if (!textCache.has(blob)) textCache.set(blob, (await tryGit(REPO, 'cat-file', 'blob', blob)) ?? '');
  return textCache.get(blob);
}

// Things that only change when HEAD moves are cached by commit.
const historyCache = new Map();
async function history(dir, head) {
  const key = `${dir}:${head}`;
  if (!historyCache.has(key)) {
    const out = (await tryGit(dir, 'log', '--first-parent', '-40', '--format=%x1e%ct%x09%s', '--name-only')) ?? '';
    historyCache.set(key, out.split('\x1e').filter(Boolean).map((chunk) => {
      const [line, ...files] = chunk.split(/\r?\n/).filter(Boolean);
      const [time, ...subj] = line.split('\t');
      return { time: Number(time), subject: subj.join('\t'), files };
    }));
  }
  return historyCache.get(key);
}
let refTips = new Map();
const countCache = new Map();
async function aheadBehind(head, target) {
  const tip = refTips.get(target);
  if (!head || !tip) return [null, null];
  const key = `${head}:${tip}`;
  if (!countCache.has(key)) {
    const c = (await tryGit(REPO, 'rev-list', '--left-right', '--count', `${head}...${tip}`))?.trim().split(/\s+/).map(Number);
    countCache.set(key, c?.length === 2 ? c : [null, null]);
  }
  return countCache.get(key);
}
// A worktree's .git is a file naming its git folder; the main checkout's is the folder.
async function isMerging(dir) {
  let gitDir = path.join(dir, '.git');
  try {
    const m = (await readFile(gitDir, 'utf8')).match(/^gitdir:\s*(.+)$/m);
    if (m) gitDir = path.resolve(dir, m[1].trim());
  } catch { /* a folder, not a file */ }
  return access(path.join(gitDir, 'MERGE_HEAD')).then(() => true, () => false);
}

// A Claude Code session's transcripts live in a folder named after its working directory.
const transcriptDir = (dir) => path.join(PROJECTS, dir.replace(/[^A-Za-z0-9]/g, '-'));
// The worktree's newest transcript: { time, file }, or null.
async function newestTranscript(dir) {
  const folder = transcriptDir(dir);
  try {
    const names = (await readdir(folder)).filter((n) => n.endsWith('.jsonl'));
    const times = await Promise.all(names.map((n) => stat(path.join(folder, n)).then((s) => s.mtimeMs, () => 0)));
    const i = times.indexOf(Math.max(0, ...times));
    return times[i] ? { time: times[i], file: path.join(folder, names[i]) } : null;
  } catch { return null; }
}

// Every transcript by its session id, wherever its folder is (a launched session
// sometimes opens in a scratch folder). Folder listings only, no stats.
async function transcriptIndex() {
  const out = new Map();
  let dirs = [];
  try { dirs = await readdir(PROJECTS, { withFileTypes: true }); } catch { return out; }
  await pool(dirs.filter((d) => d.isDirectory()), 8, async (d) => {
    let names = [];
    try { names = await readdir(path.join(PROJECTS, d.name)); } catch { return; }
    for (const n of names) if (n.endsWith('.jsonl')) out.set(n.slice(0, -6), path.join(PROJECTS, d.name, n));
  });
  return out;
}

// Each transcript's context gauge (rules in sessions.mjs), fed only the bytes
// written since the last look. A file that shrank or was made again starts
// over; a first look at a huge one starts near its end. Entries not looked at
// for a day are dropped.
const CONTEXT_FIRST_BYTES = 32 << 20;
const CONTEXT_CHUNK = 4 << 20;
const CONTEXT_FORGET_MS = 24 * 60 * 60 * 1000;
const contexts = new Map(); // file -> { birth, offset, cut, decoder, tracker, seen }
const contextQueue = new Map(); // file -> the read in progress, so reads of one file take turns

async function readContext(file) {
  let s;
  try { s = await stat(file); } catch { contexts.delete(file); return null; }
  let c = contexts.get(file);
  if (!c || s.size < c.offset || s.birthtimeMs !== c.birth) {
    const offset = Math.max(0, s.size - CONTEXT_FIRST_BYTES);
    c = { birth: s.birthtimeMs, offset, cut: offset > 0, decoder: new StringDecoder('utf8'), tracker: contextTracker(process.env), seen: 0 };
    contexts.set(file, c);
  }
  c.seen = Date.now();
  if (s.size > c.offset) {
    const fh = await open(file, 'r');
    try {
      while (c.offset < s.size) {
        const buf = Buffer.alloc(Math.min(CONTEXT_CHUNK, s.size - c.offset));
        const { bytesRead } = await fh.read(buf, 0, buf.length, c.offset);
        if (!bytesRead) break;
        c.tracker.feed(c.decoder.write(buf.subarray(0, bytesRead)), { cut: c.cut });
        c.cut = false;
        c.offset += bytesRead;
      }
    } finally { await fh.close(); }
  }
  return c.tracker.view();
}
function contextOf(file) {
  const read = (contextQueue.get(file) ?? Promise.resolve()).then(() => readContext(file)).catch(() => null);
  contextQueue.set(file, read);
  read.then(() => { if (contextQueue.get(file) === read) contextQueue.delete(file); });
  return read;
}
function forgetContexts() {
  const cutoff = Date.now() - CONTEXT_FORGET_MS;
  for (const [file, c] of contexts) if (c.seen < cutoff) contexts.delete(file);
}

// The desktop app keeps one record per Code session, naming its worktree.
const APP_SESSIONS = path.join(process.env.APPDATA ?? path.join(os.homedir(), 'AppData', 'Roaming'), 'Claude', 'claude-code-sessions');
async function appSessions() {
  const out = [];
  const walk = async (dir, depth) => {
    let entries;
    try { entries = await readdir(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const p = path.join(dir, e.name);
      if (e.isDirectory() && depth < 2) await walk(p, depth + 1);
      else if (e.isFile() && /^local_.*\.json$/.test(e.name)) {
        try {
          const r = JSON.parse(await readFile(p, 'utf8'));
          out.push({ id: r.sessionId, cli: r.cliSessionId, title: r.title ?? '', archived: !!r.isArchived,
            dir: path.normalize(r.worktreePath ?? r.cwd ?? '').toLowerCase(), activity: r.lastActivityAt ?? 0, created: r.createdAt ?? 0,
            summary: r.postTurnSummary ?? null, // the app's turn summary (sessions.mjs turnSummary)
            remote: remoteLinkOf(r) }); // its Remote Control address, if it has one
        } catch { /* being written */ }
      }
    }
  };
  await walk(APP_SESSIONS, 0);
  return out;
}

// A session is waiting on you when its transcript ends on a question with no answer yet.
async function waitingQuestion(dir, cli) {
  if (!cli) return null;
  const file = path.join(transcriptDir(dir), `${cli}.jsonl`);
  try {
    const { size } = await stat(file);
    const fh = await open(file, 'r');
    const len = Math.min(size, 256 * 1024);
    const buf = Buffer.alloc(len);
    await fh.read(buf, 0, len, size - len);
    await fh.close();
    const text = buf.toString('utf8');
    const asks = [...text.matchAll(/"type":"tool_use","id":"(toolu_[A-Za-z0-9]+)","name":"AskUserQuestion","input":\{"questions":\[\{"question":"((?:[^"\\]|\\.)*)"/g)];
    const ask = asks.at(-1);
    if (!ask) return null;
    if (text.includes(`"tool_use_id":"${ask[1]}"`)) return null;
    return JSON.parse(`"${ask[2]}"`);
  } catch { return null; }
}

// Launches the board started, kept in the state folder so every checkout's board shares them.
const LAUNCHES = path.join(STATE, 'launches.json');
await mkdir(STATE, { recursive: true });
let launches = [];
try { launches = JSON.parse(await readFile(LAUNCHES, 'utf8')); } catch (err) {
  launches = [];
  // A file that won't read is kept aside for a look, not overwritten.
  if (err.code !== 'ENOENT') await rename(LAUNCHES, `${LAUNCHES}.bad-${Date.now()}`).catch(() => {});
}
// The starter, the passes and the page's requests all save the launches: one
// write at a time, each to a new file renamed over the old, so overlapping saves
// can never leave half a file.
let saving = Promise.resolve();
function saveLaunches() {
  const write = saving.then(async () => {
    const tmp = `${LAUNCHES}.${process.pid}.tmp`;
    await writeFile(tmp, JSON.stringify(launches, null, 2));
    await rename(tmp, LAUNCHES);
  });
  saving = write.catch((err) => console.error(err));
  return write;
}
// The board starts each launch itself (launcher.mjs): it opens the launch's link
// and press-send.ps1 presses Send in the app, one launch at a time. A launch made
// while the PC is locked starts once it's unlocked (tick, on each pass).
const starter = createStarter({ list: () => launches, folder: REPO, open: openInApp, press: pressSend, locked: pcLocked, save: saveLaunches });
if (starter.recover()) await saveLaunches();
starter.kick();

// A launch's session is the app session whose first prompt names the launch's
// lane branch (launcher.mjs linkLaunches). First prompts never change, so each
// is read once, from the head of the session's transcript.
const firstPrompts = new Map(); // cli session id -> its first prompt
async function promptOfSession(cli, file) {
  if (firstPrompts.has(cli)) return firstPrompts.get(cli);
  let fh = null;
  try {
    fh = await open(file, 'r');
    const buf = Buffer.alloc(1 << 20);
    const { bytesRead } = await fh.read(buf, 0, buf.length, 0);
    const p = firstPrompt(buf.toString('utf8', 0, bytesRead));
    // A transcript with no prompt yet is read again next time, unless it's huge.
    if (p !== null || bytesRead === buf.length) firstPrompts.set(cli, p ?? '');
    return p;
  } catch { return null; } finally { await fh?.close(); }
}
async function linkSessions(sessions, transcripts) {
  const now = Date.now();
  const candidates = linkCandidates(launches, sessions, now).filter((s) => transcripts.has(s.cli));
  if (!candidates.length) return false;
  const prompts = new Map();
  await pool(candidates, 4, async (s) => {
    const p = await promptOfSession(s.cli, transcripts.get(s.cli));
    if (p) prompts.set(s.cli, p);
  });
  return linkLaunches(launches, candidates, prompts, now);
}

// gh, or LANES_GH (a script run with node, standing in for gh in tests).
const gh = ghRunner();
let prs = [];
let prsAt = 0;
let prsBusy = false;
function refreshPrs() {
  if (prsBusy || Date.now() - prsAt < 60_000) return;
  prsBusy = true;
  gh(['pr', 'list', '--state', 'open', '--json', 'number,title,headRefName,baseRefName,isDraft,url'], { cwd: REPO, timeout: 20_000 })
    .then((stdout) => { prs = JSON.parse(stdout); }, () => {})
    .finally(() => { prsAt = Date.now(); prsBusy = false; });
}

// ---------- the board ----------

async function collect() {
  refreshPrs();
  const refsOut = (await tryGit(REPO, 'for-each-ref', '--format=%(objectname) %(refname:short)', 'refs/heads', 'refs/remotes/origin')) ?? '';
  const refs = refsOut.split(/\r?\n/).filter(Boolean).map((l) => { const [sha, name] = l.split(' '); return { sha, name }; })
    .filter((r) => r.name !== 'origin/HEAD' && r.name !== 'origin');
  refTips = new Map(refs.map((r) => [r.name, r.sha]));
  const trees = await worktrees();

  // Every committed copy of every plan, on every branch.
  const shas = [...new Set(refs.map((r) => r.sha))];
  const copies = {};
  for (const plan of PLANS) {
    const found = await pool(shas, 8, async (sha) => ({ sha, at: await planAt(sha, plan.file) }));
    copies[plan.key] = found.filter((f) => f.at);
  }

  // Worktree files, for ticks not committed yet.
  const treeFiles = await pool(trees, 6, async (w) => {
    const files = {};
    for (const plan of PLANS) {
      try { files[plan.key] = await readFile(path.join(w.path, plan.file), 'utf8'); } catch { /* not on this branch */ }
    }
    return files;
  });

  const plans = [];
  const status = new Map(); // 'gr:12.2' -> status
  for (const plan of PLANS) {
    const list = copies[plan.key];
    if (!list.length) continue;
    const parsed = await Promise.all(list.map(async (c) => ({ time: c.at.time, p: parse(plan, await blobText(c.at.blob), c.at.blob) })));
    const { tasks, stages, phases, branch, done, retired, moved } = mergeCopies(parsed);
    const base = { tasks, stages, phases };
    const working = new Set();
    for (const files of treeFiles) {
      if (!files[plan.key]) continue;
      for (const t of parse(plan, files[plan.key]).tasks.values()) {
        if (t.mark === 'x' && !done.has(t.id) && !moved.has(t.id)) working.add(t.id);
      }
    }
    // The branch the plan's header names, if any, is where its work goes now.
    plans.push({ plan, branch: branch ?? plan.branch, base, done, retired, moved, working });
  }
  const branchOf = Object.fromEntries(PLANS.map((p) => [p.key, plans.find((x) => x.plan === p)?.branch ?? p.branch]));

  // A moved task has left its plan, so it no longer blocks anything there.
  const isDone = (ref) => {
    const [k, id] = ref.split(':');
    const p = plans.find((x) => x.plan.key === k);
    return !!p && (p.done.has(id) || p.retired.has(id) || p.moved.has(id));
  };
  const movedTo = linkMoved(plans.map((p) => ({ key: p.plan.key, tasks: p.base.tasks })));

  // Lanes: every worktree.
  const now = Date.now();
  const sessions = await appSessions();
  const transcripts = await transcriptIndex();
  forgetContexts();

  // Each launch's session: the app session its prompt started, wherever it opened.
  if (await linkSessions(sessions, transcripts)) await saveLaunches();
  const stops = await readStops();
  const lanes = await pool(trees, 10, async (w, i) => {
    const st = (await tryGit(w.path, 'status', '--porcelain')) ?? '';
    const dirty = st.split(/\r?\n/).filter(Boolean).map((l) => l.slice(3).replace(/^"|"$/g, ''))
      .filter((f) => !IGNORED_DIRTY.some((r) => r.test(f)));
    const merging = await isMerging(w.path);
    const log = await history(w.path, w.head);
    const last = log[0] ?? { time: null, subject: '' };

    // Which plan the worktree works on: its branch name, else the newest own
    // commit that touched a plan or named a task.
    // A launched lane names its plan and tasks in its branch (lane/gr-22.2-22.3,
    // lane/rm-R3); only worktrees on a plan's own branches take its tasks.
    const claimed = planOfBranch(w.branch, branchOf);
    let planKey = claimed?.key ?? null;
    const scope = claimed?.scope ?? null;
    let claims = true;
    if (!planKey) {
      claims = false;
      for (const c of log) {
        const hit = PLANS.find((p) => c.files.includes(p.file)) ?? (SUBJECT_TASK.gr.test(c.subject) ? PLAN_BY_KEY.gr : null);
        if (hit) { planKey = hit.key; break; }
      }
    }
    let lastTask = null;
    if (planKey && SUBJECT_TASK[planKey]) {
      for (const c of log) { const m = c.subject.match(SUBJECT_TASK[planKey]); if (m) { lastTask = m[1]; break; } }
    }

    // Commits not yet on the plan's branch on GitHub (or master for other work).
    const target = planKey ? `origin/${branchOf[planKey]}` : 'origin/master';
    const [ahead, behind] = await aheadBehind(w.head, target);
    const newest = await newestTranscript(w.path);
    const session = newest?.time ?? null;
    const pr = prs.find((p) => p.headRefName === w.branch) ?? null;
    const app = sessions.filter((s) => s.dir === path.normalize(w.path).toLowerCase())
      .sort((x, y) => (x.archived - y.archived) || (y.activity - x.activity))[0] ?? null;
    // The context gauge follows the lane's app session (or its launch's), else
    // the newest transcript in the worktree's folder.
    const cli = app?.cli ?? launches.find((l) => l.branch && l.branch === w.branch && l.session?.cli)?.session.cli;
    const gaugeFile = (cli && transcripts.get(cli)) ?? newest?.file ?? null;
    const question = app && !app.archived ? await waitingQuestion(w.path, app.cli) : null;
    const own = treeFiles[i];

    let activity = 'idle';
    if (session && now - session < ACTIVE_MS) activity = 'active';
    else if ((session && now - session < RECENT_MS) || (last.time && now - last.time * 1000 < RECENT_MS)) activity = 'recent';

    let state;
    if (merging) state = 'merging';
    else if (dirty.length) state = 'dirty';
    else if (ahead) state = 'ahead';
    else state = 'clean';

    return {
      folder: path.relative(REPO, w.path) || path.basename(w.path),
      path: w.path, main: w.path === path.normalize(REPO), branch: w.branch, head: w.head?.slice(0, 7), locked: w.locked,
      plan: planKey, claims, scope, lastTask,
      app: app && { id: app.id, title: app.title, archived: app.archived }, question, target, ahead, behind, dirty: dirty.length, merging, state, activity,
      session, last: { time: last.time, subject: last.subject },
      context: gaugeFile ? await contextOf(gaugeFile) : null,
      contextSession: gaugeFile ? path.basename(gaugeFile, '.jsonl') : null,
      pr: pr && { number: pr.number, url: pr.url, draft: pr.isDraft, base: pr.baseRefName },
      // Plan ticks in this worktree's file that no branch has committed yet.
      uncommittedTicks: planKey && own[planKey]
        ? [...parse(PLAN_BY_KEY[planKey], own[planKey]).tasks.values()].filter((t) => t.mark === 'x').map((t) => t.id)
        : [],
    };
  });

  // Each plan lane's current or next task.
  for (const lane of lanes) {
    const p = plans.find((x) => x.plan.key === lane.plan);
    if (!p) continue;
    lane.uncommittedTicks = lane.uncommittedTicks.filter((id) => !p.done.has(id));
    const order = p.base.stages.flatMap((s) => s.ids).filter((id) => !lane.scope || lane.scope.includes(id));
    const open = (id) => !p.done.has(id) && !p.retired.has(id) && !p.moved.has(id);
    const ready = (id) => (p.base.tasks.get(id)?.blockers ?? []).every(isDone);
    const from = lane.lastTask ? order.indexOf(lane.lastTask) : -1;
    const pick = (from >= 0 ? order.slice(from + 1) : order).find((id) => open(id) && ready(id))
      ?? order.find((id) => open(id) && ready(id)) ?? order.find(open) ?? null;
    lane.task = pick;
    lane.taskTitle = pick ? p.base.tasks.get(pick)?.title ?? '' : '';
    const t = pick && p.base.tasks.get(pick);
    lane.taskWaits = t ? (t.gatedBy ?? []).filter((g) => isDone(g)).map((g) => g.split(':')[1]) : [];
    lane.taskBlocked = t ? t.blockers.filter((x) => !isDone(x)) : [];
    // A lane with uncommitted work, or a live session with commits of its own,
    // is taken to be on its next task. (A session that only reads, like a
    // chart, has neither.)
    // A launched lane's session counts from its first answer to wayfinder's questions.
    const busy = lane.uncommittedTicks.length > 0 || (lane.claims
      && (lane.state === 'dirty' || lane.state === 'merging' || (lane.activity === 'active' && (lane.ahead > 0 || !!lane.scope))));
    // Launching a task is the owner's OK, so a launched lane doesn't wait on it.
    // A lane whose launch was ended from the board takes no task.
    lane.ended = launches.find((l) => l.endedAt && l.branch && l.branch === lane.branch) ? true : false;
    lane.working = !lane.ended && !!(pick && busy && ready(pick) && (!lane.taskWaits.length || lane.scope));
    if (lane.working) p.working.add(pick);
  }

  // A launched task stays marked until a lane starts it, for two days at most.
  const launchOf = (ref) => launches.find((l) => !l.endedAt && now - l.time < LAUNCH_FRESH_MS && l.tasks.includes(ref)) ?? null;
  // The launch a task belongs to, ended or not, for the board's End menu.
  const launchView = (l) => {
    const stop = stops.find((s) => s.id === l.id);
    return { id: l.id, kind: l.kind ?? 'tasks', time: l.time, branch: l.branch ?? null, tasks: l.tasks, session: l.session?.id ?? null,
      endedAt: l.endedAt ?? null, stoppedAt: stop?.firedAt ?? null, start: startView(l, now) };
  };

  // Task statuses.
  const out = [];
  for (const p of plans) {
    const tasks = {};
    for (const t of p.base.tasks.values()) {
      const ref = `${p.plan.key}:${t.id}`;
      let s;
      if (p.moved.has(t.id)) s = 'moved';
      else if (p.retired.has(t.id)) s = 'retired';
      else if (p.done.has(t.id)) s = 'done';
      else if (p.working.has(t.id)) s = 'working';
      else if (launchOf(ref)) s = 'launched';
      else if (!t.blockers.every(isDone)) s = 'blocked';
      else if ((t.gatedBy ?? []).length) s = 'owner';
      else s = 'ready';
      status.set(ref, s);
      tasks[t.id] = {
        title: t.title, status: s, gate: t.gate,
        blockers: t.blockers.map((x) => ({ ref: x, label: x.startsWith(`${p.plan.key}:`) ? x.split(':')[1] : `${PLAN_BY_KEY[x.split(':')[0]]?.name ?? x.split(':')[0]} ${x.split(':')[1]}`, done: isDone(x) })),
        ownerOk: (t.gatedBy ?? []).map((g) => g.split(':')[1]),
        launchedAt: s === 'launched' ? launchOf(ref).time : null,
        // Moved by the Oct 4 triage to milestone 1 or 2, and the task that took it over.
        moved: t.moved ?? null, movedTo: movedTo.get(ref) ?? null, replaces: t.replaces ?? [],
      };
    }
    const inStages = new Set(p.base.stages.flatMap((s) => s.ids));
    const stages = p.base.stages.map((s) => ({ n: s.n, name: s.name, ids: s.ids }));
    const extra = [...p.base.tasks.keys()].filter((id) => !inStages.has(id));
    if (extra.length) stages.push({ n: null, name: 'Not in the build order', ids: extra });
    const counts = { done: 0, working: 0, launched: 0, ready: 0, owner: 0, blocked: 0, retired: 0, moved: 0 };
    for (const t of Object.values(tasks)) counts[t.status]++;
    out.push({ key: p.plan.key, short: p.plan.short, name: p.plan.name, kind: p.plan.kind, closed: !!p.plan.closed,
      branch: p.branch, file: p.plan.file, stages, tasks, counts,
      total: Object.keys(tasks).length - counts.retired - counts.moved });
  }

  // The roadmap's phases, once the roadmap has a copy on some branch.
  const rm = plans.find((p) => p.plan.key === 'rm');
  const roadmap = rm?.base.phases ? { key: 'rm', phases: roadmapView(rm.base.phases, out, lanes) } : null;

  return { updated: Date.now(), repo: REPO, plans: out, roadmap, lanes, prs, launches: launches.map(launchView) };
}

// Collect in a loop, so a page's request is answered at once from the last pass.
let cached = null;
let lastError = null;
async function loop() {
  const started = Date.now();
  try { cached = { ...(await collect()), took: Date.now() - started }; lastError = null; }
  catch (err) { lastError = String(err?.stack ?? err); console.error(lastError); }
  starter.tick().catch((err) => console.error(err));
  setTimeout(loop, Math.max(500, CACHE_MS - (Date.now() - started)));
}
const first = loop();
async function data() {
  if (!cached) await first;
  return cached ? { ...cached, error: lastError } : { error: lastError ?? 'no data yet' };
}

// ---------- launching sessions ----------

// The desktop app opens claude:// links: code/new starts a Code session in a
// folder (the app makes its worktree) with the prompt in its box, and asks to
// trust the folder; it never sends the prompt itself.
function openInApp(url) {
  // LANES_DRY_RUN=1 prints the link instead, for testing the board.
  if (process.env.LANES_DRY_RUN) { console.log(`[dry run] ${url}`); return Promise.resolve(); }
  return run('rundll32.exe', ['url.dll,FileProtocolHandler', url], { windowsHide: true });
}

// press-send.ps1 (Windows UI Automation) confirms the app's trust dialog for the
// repository and presses Send on the box holding the prompt; -LockOnly only
// says whether the PC is locked. It answers in one line of JSON.
function pressScript(args, env = {}) {
  return run('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', path.join(HERE, 'press-send.ps1'), ...args],
    { windowsHide: true, timeout: 150_000, env: { ...process.env, ...env } })
    .then(({ stdout }) => pressResult(stdout), (err) => pressResult(err?.stdout));
}
async function pressSend({ prompt, folder }) {
  if (process.env.LANES_DRY_RUN) { console.log('[dry run] would press Send'); return { result: 'pressed' }; }
  const r = await pressScript([], { LANES_PROMPT: prompt, LANES_FOLDER: folder });
  console.log(`[${new Date().toISOString()}] pressing Send for a launch: ${r.result}${r.trusted ? ', trusted the folder' : ''}${r.ms != null ? `, ${r.ms} ms` : ''}${r.error ? ` (${r.error})` : ''}`);
  return r;
}
async function pcLocked() {
  if (process.env.LANES_DRY_RUN) return false;
  return (await pressScript(['-LockOnly'])).result === 'locked';
}

async function launch(body) {
  const d = cached;
  if (!d) throw new Error('The board has no data yet');
  const refs = [...new Set((body?.tasks ?? []).map(String))];
  if (!refs.length) throw new Error('Nothing queued');
  const groups = new Map();
  for (const ref of refs) {
    const [key, id] = ref.split(':');
    const plan = d.plans.find((p) => p.key === key);
    const t = plan?.tasks[id];
    if (!t) throw new Error(`Unknown task ${ref}`);
    if (!['ready', 'blocked', 'owner'].includes(t.status)) throw new Error(`${ref} has already started (${t.status})`);
    if (!groups.has(key)) groups.set(key, { plan, ids: [] });
    groups.get(key).ids.push(id);
  }
  const done = [];
  for (const [key, { plan, ids }] of groups) {
    // Plan order, so the session works them in the order the plan builds them.
    const order = plan.stages.flatMap((s) => s.ids);
    ids.sort((a, b) => order.indexOf(a) - order.indexOf(b));
    const branch = `lane/${key}-${ids.join('-')}`.slice(0, 120);
    // The session's first prompt, in plain words: a link can't run /goal.
    const goal = goalFor({ plan: { ...PLAN_BY_KEY[key], branch: plan.branch }, ids, tasks: plan.tasks, branch, repo: REPO,
      baseExists: refTips.has(`origin/${plan.branch}`) });
    const now = Date.now();
    const record = { id: `${now.toString(36)}-${key}`, time: now, plan: key, tasks: ids.map((id) => `${key}:${id}`), branch, goal,
      start: { state: 'queued', at: now, attempts: 0 } };
    launches.push(record);
    done.push(record);
    // Taking the lane back up: an earlier "End work" on it must not stop this one.
    const stops = cancelStops(await readStops(), branch, Date.now());
    if (stops.cancelled) await writeFile(STOPS, JSON.stringify({ entries: stops.entries }, null, 2));
  }
  launches = launches.filter((l) => Date.now() - l.time < 14 * 24 * 60 * 60 * 1000);
  await saveLaunches();
  // The starter opens each link and presses Send, one launch at a time; the
  // pages follow each launch's start on /data.
  starter.kick();
  // Mark them at once rather than on the next pass.
  try { cached = { ...(await collect()), took: 0 }; } catch { /* the loop will */ }
  return done;
}

// The pages' "New session" button: a session with no tasks, started like a
// launch (the same queue, lock wait and Try again), which the owner then
// prompts from the Claude app over Remote Control (launcher.mjs newSessionLaunch).
async function newSession() {
  const record = newSessionLaunch({ now: Date.now(), repo: REPO });
  launches.push(record);
  launches = launches.filter((l) => Date.now() - l.time < 14 * 24 * 60 * 60 * 1000);
  await saveLaunches();
  starter.kick();
  try { cached = { ...(await collect()), took: 0 }; } catch { /* the loop will */ }
  return record;
}

// "Try again" for a launch that couldn't start: refused at once (started, ended,
// starting or just sent), else the starter opens its link and presses Send again.
async function retryLaunch(body) {
  starter.retry(String(body?.launch ?? ''));
  try { cached = { ...(await collect()), took: 0 }; } catch { /* the loop will */ }
  return { retried: true };
}

// Ending a lane: the stop list that ~/.claude/hooks/lanes-stop/hook.mjs reads
// before every tool call and when a turn ends. A matching session (by its
// session id, or by working inside the lane's worktree) stops at its next step.
const STOPS = process.env.LANES_STOP_FILE ?? path.join(os.homedir(), '.claude', 'lanes-stop.json');
async function readStops() {
  try { return JSON.parse(await readFile(STOPS, 'utf8')).entries ?? []; } catch { return []; }
}
async function endLaunch(body) {
  const l = launches.find((x) => x.id === body?.launch);
  if (!l) throw new Error('Unknown launch');
  if (l.endedAt) throw new Error('That lane was already ended');
  if (!l.tasks.length) throw new Error('A new session has no tasks to end: stop it in the Claude app');
  const trees = await worktrees();
  const tree = trees.find((t) => t.branch === l.branch);
  const sessions = await appSessions();
  const ids = new Set();
  if (l.session?.cli) ids.add(l.session.cli);
  if (tree) for (const s of sessions) if (s.dir === path.normalize(tree.path).toLowerCase() && s.cli) ids.add(s.cli);
  const [k] = l.plan ? [l.plan] : l.tasks[0].split(':');
  const label = `${PLAN_BY_KEY[k]?.short ?? k} ${l.tasks.map((t) => t.split(':')[1]).join(', ')}`;
  const entries = (await readStops()).filter((e) => Date.now() - e.requestedAt < 14 * 24 * 60 * 60 * 1000);
  entries.push({ id: l.id, label, branch: l.branch, worktree: tree?.path ?? null, sessions: [...ids], requestedAt: Date.now(), firedAt: null });
  await writeFile(STOPS, JSON.stringify({ entries }, null, 2));
  l.endedAt = Date.now();
  await saveLaunches();
  try { cached = { ...(await collect()), took: 0 }; } catch { /* the loop will */ }
  return { label, worktree: tree?.path ?? null, sessions: ids.size };
}

// ---------- sessions (the Sessions tab) ----------
// Every recent Claude Code session, the Away switch and the relay's answers,
// in sessions-api.mjs. A session's plan task is its folder's lane's.
const RELAY = process.env.LANES_RELAY ?? path.join(os.homedir(), '.claude', 'lanes-relay');
function taskOfDir(dir) {
  const d = path.normalize(dir).toLowerCase();
  const l = cached?.lanes?.find((x) => path.normalize(x.path).toLowerCase() === d);
  if (!l?.plan || !l.task) return null;
  return { ref: `${l.plan}:${l.task}`, label: `${PLAN_BY_KEY[l.plan]?.short ?? l.plan} ${l.task}`, title: l.taskTitle ?? '' };
}
// The branch checked out in a folder, from the worktree list, for a session
// whose transcript records none ("HEAD": started outside git, then moved in).
function branchOfDir(dir) {
  const d = path.normalize(dir).toLowerCase();
  return cached?.lanes?.find((x) => path.normalize(x.path).toLowerCase() === d)?.branch ?? null;
}
// Whether the hooks installed in user settings are this checkout's (hooks.mjs);
// both pages say so when they aren't. LANES_CLAUDE_DIR overrides ~/.claude.
const CLAUDE_DIR = process.env.LANES_CLAUDE_DIR ?? path.join(os.homedir(), '.claude');
// A handful of small files, read in place each time the Questions tab asks.
async function hooksState() {
  return hooksStatusOf({ claudeDir: CLAUDE_DIR, boardDir: HERE, read: (file) => { try { return readFileSync(file, 'utf8'); } catch { return null; } } });
}
// A branch's open pull request, from the list refreshed each minute (refreshPrs).
function prOfBranch(branch) {
  const p = prs.find((x) => x.headRefName === branch);
  return p ? { number: p.number, title: p.title, url: p.url, base: p.baseRefName, draft: !!p.isDraft } : null;
}
// What sessions post with `npm run post` (media.mjs, media-api.mjs), swept hourly.
const mediaRoutes = mediaApi({ state: STATE, sweepMs: 60 * 60 * 1000 });
const sessionRoutes = sessionsApi({ relay: RELAY, projects: PROJECTS, activeMs: ACTIVE_MS, contextOf, appSessions, pool, taskOf: taskOfDir,
  hooks: hooksState, sweepMs: 5000, stopFile: STOPS, prOf: prOfBranch, branchOf: branchOfDir, media: mediaRoutes });
// Merge from a session's page (merge-api.mjs), and "ready to merge" for the
// bell, looked for every minute (LANES_MERGE_POLL_MS overrides it, for tests).
const mergeRoutes = mergeApi({ repoDir: REPO, relay: RELAY, gh, prOf: prOfBranch, sessions: sessionRoutes,
  stateFile: path.join(STATE, 'merge-ready.json'), pollMs: Number(process.env.LANES_MERGE_POLL_MS) || 60_000 });
// A session's Docs: what it wrote, its pull request and its artifacts (docs-api.mjs).
const docsRoutes = docsApi({ repoDir: REPO, worktrees, gh, prOf: prOfBranch, fileOf: sessionRoutes.fileOf, branchOf: sessionRoutes.branchOfSession });
// Lock-screen notifications (push-api.mjs): the bell's new records, pushed while
// Away is on to every phone that turned them on. LANES_PUSH_INSECURE=1 lets a
// test's stand-in push service on http through.
const pushRoutes = pushApi({ state: STATE, insecure: !!process.env.LANES_PUSH_INSECURE,
  away: async () => awayOf(JSON.parse(await readFile(path.join(RELAY, 'away.json'), 'utf8').catch(() => 'null'))),
  httpsUrl: () => { const n = [...hostNames].find((h) => h.endsWith('.ts.net')); return n ? `https://${n}` : null; } });
// The bell: notifications from held items, the relay hook's events and posted media (bell-api.mjs).
const bellRoutes = bellApi({ file: path.join(STATE, 'notifications.json'), relay: RELAY, held: sessionRoutes.held,
  titlesOf: sessionRoutes.titlesOf, posts: mediaRoutes.posts, asking: sessionRoutes.askingNow, onNew: pushRoutes.notify, sweepMs: 5000 });

// ---------- the second brain ----------
// The board's "Second brain" button opens /brain/: the viewer and vault from
// tools/second-brain (docs/specs/second-brain.md), imported from this checkout.
// The notes are built from git, never a working tree: the newest master tip
// that has the vault (brain/Home.md), so plan ticks show once they're pushed.
const BRAIN_REFS = ['origin/master', 'master'];
let brain = null; // { handle, gitSource, set }

async function newestRef(refs, needs) {
  let best = null;
  for (const ref of refs) {
    const line = (await tryGit(REPO, 'log', '-1', '--format=%H %ct', ref, '--'))?.trim();
    if (!line) continue;
    const [commit, t] = line.split(' ');
    if (needs && (await tryGit(REPO, 'cat-file', '-e', `${commit}:${needs}`)) === null) continue;
    if (!best || Number(t) > best.t) best = { ref, commit, t: Number(t) };
  }
  return best;
}

async function brainTool() {
  if (brain) return brain;
  const dir = path.join(HERE, '..', 'second-brain');
  const { brainHandler } = await import(pathToFileURL(path.join(dir, 'serve.mjs')).href);
  const { gitSource } = await import(pathToFileURL(path.join(dir, 'sources.mjs')).href);
  let current = null; // { key, source, label }, set before each notes.json
  brain = { gitSource, handle: brainHandler({ getSource: () => current, viewerDir: dir }), set: (c) => { current = c; } };
  return brain;
}

async function serveBrain(req, res, sub) {
  const ref = await newestRef(BRAIN_REFS, 'brain/Home.md');
  let tool = null;
  try { tool = ref && await brainTool(); } catch { /* this checkout has no tools/second-brain */ }
  if (!tool) { res.writeHead(404, { 'content-type': 'text/plain' }); res.end('No second brain here yet (tools/second-brain).'); return; }
  if (sub.split('?')[0] === 'notes.json') tool.set({ key: ref.commit.slice(0, 7), source: tool.gitSource(REPO, ref.commit), label: ref.ref });
  await tool.handle(req, res, sub);
}

// ---------- who may connect (rules in access.mjs) ----------
// The names the board answers to: localhost, and this PC's Tailscale addresses
// and MagicDNS names, learned from the interfaces and `tailscale status --json`.
const LOCAL_ONLY = !!process.env.LANES_LOCAL_ONLY;
const TAILSCALE = process.env.TAILSCALE_EXE
  ?? (process.platform === 'win32' ? 'C:\\Program Files\\Tailscale\\tailscale.exe' : 'tailscale');
const hostNames = new Set(['localhost', '127.0.0.1']);
const tailnetIps = new Set();
let learnedDns = false;
async function learnTailscale() {
  for (const ip of tailnetIPv4s(os.networkInterfaces())) tailnetIps.add(ip);
  if (!learnedDns) {
    try {
      const { stdout } = await run(TAILSCALE, ['status', '--json'], { windowsHide: true, timeout: 10_000 });
      const { ips, names } = tailscaleSelf(JSON.parse(stdout));
      for (const ip of ips) tailnetIps.add(ip);
      for (const n of names) hostNames.add(n);
      learnedDns = names.length > 0;
    } catch { /* Tailscale not up yet; the interface scan still finds its address */ }
  }
  for (const ip of tailnetIps) hostNames.add(ip);
}

async function sendFile(res, { file, type }) {
  const body = await readFile(path.join(HERE, file));
  res.writeHead(200, { 'content-type': type, 'cache-control': 'no-store' });
  res.end(body);
}
async function readJson(req) {
  let s = '';
  for await (const chunk of req) { s += chunk; if (s.length > 64 * 1024) throw new Error('Too large'); }
  return JSON.parse(s || '{}');
}

async function handle(req, res) {
  try {
    // The binds already keep to loopback and Tailscale; this is the second lock.
    if (!fromTailnetOrLocal(req.socket.remoteAddress) || !knownHost(req.headers.host, hostNames)) {
      res.writeHead(403, { 'content-type': 'text/plain' }); res.end('Not on this tailnet'); return;
    }
    if (req.method === 'POST') {
      const from = { origin: req.headers.origin, host: req.headers.host, contentType: req.headers['content-type'] };
      if (!sameOrigin(from, hostNames)) { res.writeHead(403); res.end('{"error":"Refused: not from the board"}'); return; }
      const body = await readJson(req);
      let result;
      if (req.url === '/launch') result = { launched: await launch(body) };
      else if (req.url === '/launch/retry') result = await retryLaunch(body);
      else if (req.url === '/session/new') result = { launched: await newSession() };
      else if (req.url === '/end') result = { ended: await endLaunch(body) };
      else if (req.url === '/open') {
        if (!/^local_[0-9a-f-]{36}$/.test(body.session ?? '')) throw new Error('Bad session id');
        await openInApp(`claude://code/needs-input?session=${body.session}`);
        result = { ok: true };
      } else if ((result = await (bellRoutes.post(req.url, body) ?? mergeRoutes.post(req.url, body)
        ?? pushRoutes.post(req.url, body, { origin: req.headers.origin, ua: req.headers['user-agent'] })
        ?? sessionRoutes.post(req.url, body, { ua: req.headers['user-agent'] }))) === undefined) { res.writeHead(404); res.end('{}'); return; }
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify(result));
      return;
    }
    if (req.url === '/brain') { res.writeHead(302, { location: '/brain/' }); res.end(); return; }
    if (req.url.startsWith('/brain/')) { await serveBrain(req, res, req.url.slice('/brain/'.length)); return; }
    const url = new URL(req.url, 'http://board');
    if (await mediaRoutes.serve(req, res, url)) return;
    if (await docsRoutes.serve(req, res, url)) return;
    const work = await sessionRoutes.workImage(url);
    if (work !== undefined) {
      if (!work) { res.writeHead(404, { 'content-type': 'text/plain' }); res.end('No such image'); return; }
      res.writeHead(200, { 'content-type': work.type, 'content-length': work.bytes.length, 'cache-control': 'private, max-age=86400' });
      res.end(work.bytes);
      return;
    }
    const routed = url.pathname === '/data' ? data() : bellRoutes.get(url) ?? pushRoutes.get(url) ?? mergeRoutes.get(url) ?? docsRoutes.get(url) ?? sessionRoutes.get(url);
    if (routed) {
      const body = JSON.stringify(await routed);
      // About 75 KB every 4 s; gzip makes it a few KB for the phone.
      if (wantsGzip(req.headers['accept-encoding'])) {
        res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store', 'content-encoding': 'gzip', vary: 'accept-encoding' });
        res.end(gzipSync(body));
      } else {
        res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' });
        res.end(body);
      }
      return;
    }
    await sendFile(res, pageFor(req.url, req.headers['user-agent']));
  } catch (err) {
    console.error(err);
    res.writeHead(req.method === 'POST' ? 400 : 500, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: String(err?.message ?? err) }));
  }
}

// Loopback always, and each Tailscale IPv4 address as soon as it exists (at logon
// Tailscale can come up after the board), checked again every 30 s. Never 0.0.0.0.
const bound = new Set();
function bind(addr) {
  if (bound.has(addr)) return;
  bound.add(addr);
  const server = createServer(handle);
  server.on('error', (err) => {
    bound.delete(addr);
    if (addr === '127.0.0.1') { console.error(`Can't listen on ${addr}:${PORT}: ${err.message}`); process.exit(1); }
    console.error(`Can't listen on ${addr}:${PORT} yet (${err.code}); trying again shortly`);
  });
  server.listen(PORT, addr, () => console.log(`Project Manager on http://${addr === '127.0.0.1' ? 'localhost' : addr}:${PORT} (repo ${REPO})`));
}
bind('127.0.0.1');
if (!LOCAL_ONLY) {
  const bindTailnet = async () => { await learnTailscale(); for (const ip of tailnetIps) bind(ip); };
  await bindTailnet();
  setInterval(bindTailnet, 30_000);
}
