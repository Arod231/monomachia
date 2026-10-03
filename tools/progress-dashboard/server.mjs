// Live progress dashboard for the Godot rebuild's build order.
// Reads docs/plans/godot-rebuild.md from every lane's worktree and branch, so it
// follows the other sessions without anyone asking. Run from any checkout: it reads the main checkout.
//   npm run dashboard   ->   http://localhost:5199
import { createServer } from 'node:http';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const run = promisify(execFile);
const HERE = path.dirname(fileURLToPath(import.meta.url));
import os from 'node:os';
import { findRepo, projectPrefix } from './repo.mjs';
import { makeRoutes } from './routes.mjs';
import { listSessions } from './sessions.mjs';
const REPO = await findRepo();
const PLAN = 'docs/plans/godot-rebuild.md';
const MAIN_BRANCH = 'feature/godot-rebuild';
const PORT = Number(process.env.PORT || 5199);
const CACHE_MS = 4000;
// Files that don't mean a lane is mid-task: local tooling, and Godot's re-save
// of the bus layout on a fresh checkout's first run.
const IGNORED_DIRTY = [/^\.claude\//, /^game\/default_bus_layout\.tres$/];

const SHORT_NAMES = {
  1: 'Resume and safety nets', 2: 'The look, real fighters', 3: 'The shrine',
  4: 'Fluid rules', 5: 'Sound and music', 6: 'The new strings', 7: 'Swing foundations',
  8: 'Fighter animation core', 9: 'Katana swings, anim review',
  10: 'Editor, HUD, effects, menus', 11: "Other weapons' swings",
  12: 'Computer and balance', 13: 'Full animation', 14: 'Ship',
};

// --no-optional-locks keeps `git status` from taking index.lock, so polling
// never trips up a commit in another session.
async function git(cwd, ...args) {
  const { stdout } = await run('git', ['--no-optional-locks', ...args], {
    cwd, maxBuffer: 32 << 20, windowsHide: true,
  });
  return stdout;
}
async function tryGit(cwd, ...args) {
  try { return await git(cwd, ...args); } catch { return null; }
}

// "8.4–8.9", "14b.1–14b.6", "16.1–16.7", "13.1" -> task ids.
function expandIds(text) {
  const out = [];
  const re = /(\d+b?)\.(\d+)(?:\s*[–-]\s*(?:(\d+b?)\.)?(\d+))?/g;
  for (const [, major, from, , to] of text.matchAll(re)) {
    if (to === undefined) { out.push(`${major}.${from}`); continue; }
    for (let i = Number(from); i <= Number(to); i++) out.push(`${major}.${i}`);
  }
  return out;
}

function parseTasks(text) {
  const ticked = new Set();
  const all = [];
  const titles = {};
  const blockers = {};
  let current = null;
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*- \[([ x])\] \*\*(\d+b?\.\d+)\s+(.*?)\*\*/);
    if (m) {
      current = m[2];
      all.push(current);
      titles[current] = m[3].replace(/[.;]\s*$/, '');
      if (m[1] === 'x') ticked.add(current);
      continue;
    }
    if (/^\s*- \[[ x]\] \*\*/.test(line) || line.startsWith('#')) { current = null; continue; }
    const b = current && !(current in blockers) && line.match(/Blocked by:\s*(.*)/);
    if (b) {
      const frag = b[1].split(' · ')[0].replace(/\([^)]*\)/g, '');
      blockers[current] = /^\s*none/i.test(frag) ? [] : expandIds(frag);
    }
  }
  return { ticked, all, titles, blockers };
}

function parseBuildOrder(text) {
  const section = text.split(/^## Build order/m)[1]?.split(/^## /m)[0] ?? '';
  const stages = [];
  for (const line of section.split(/\r?\n/)) {
    const m = line.match(/^(\d+)\.\s+\*\*(.+?)\*\*(.*)$/);
    if (!m) continue;
    const n = Number(m[1]);
    const full = m[2].replace(/:$/, '');
    const rest = m[3].replace(/\([^)]*\)/g, '');
    const list = rest.includes(':') ? rest.slice(rest.indexOf(':') + 1) : rest;
    stages.push({ n, name: SHORT_NAMES[n] ?? full, full, tasks: expandIds(list) });
  }
  return stages;
}

const tickCache = new Map(); // commit sha -> ticked ids in that commit's plan
async function tickedAt(sha) {
  if (!tickCache.has(sha)) {
    const text = await tryGit(REPO, 'show', `${sha}:${PLAN}`);
    tickCache.set(sha, text ? parseTasks(text).ticked : new Set());
  }
  return tickCache.get(sha);
}

async function worktrees() {
  const out = await git(REPO, 'worktree', 'list', '--porcelain');
  const list = [];
  let cur = null;
  for (const line of out.split(/\r?\n/)) {
    if (line.startsWith('worktree ')) list.push(cur = { path: path.normalize(line.slice(9)), branch: null });
    else if (line.startsWith('branch ') && cur) cur.branch = line.slice(7).replace('refs/heads/', '');
  }
  return list;
}

async function collect() {
  const planText = await readFile(path.join(REPO, PLAN), 'utf8');
  const stages = parseBuildOrder(planText);
  const { all, titles, blockers } = parseTasks(planText);
  const order = stages.flatMap((s) => s.tasks);

  // Done = ticked in a committed plan on any lane branch or its GitHub copy,
  // so merged-and-deleted lanes still count through origin's feature branch.
  const refs = (await tryGit(REPO, 'for-each-ref', '--format=%(objectname)',
    'refs/heads/godot', `refs/heads/${MAIN_BRANCH}`,
    'refs/remotes/origin/godot', `refs/remotes/origin/${MAIN_BRANCH}`)) ?? '';
  const done = new Set();
  for (const sha of new Set(refs.split(/\r?\n/).filter(Boolean))) {
    for (const id of await tickedAt(sha)) done.add(id);
  }

  const trees = await worktrees();
  const isLane = (b) => b === MAIN_BRANCH || /^godot\//.test(b ?? '');
  const lanes = [];
  for (const w of trees.filter((t) => isLane(t.branch))) {
    // A side lane names its stage in its branch (godot/stage-7-swings); any
    // other godot/* branch is off-plan work, such as a follow-up the owner asked for.
    const stage = Number(w.branch.match(/stage-(\d+)/)?.[1]) || null;
    const kind = w.branch === MAIN_BRANCH ? 'main' : stage ? 'stage' : 'offplan';
    const status = (await tryGit(w.path, 'status', '--porcelain')) ?? '';
    const dirty = status.split(/\r?\n/).filter(Boolean)
      .map((l) => l.slice(3).replace(/^"|"$/g, ''))
      .filter((f) => !IGNORED_DIRTY.some((r) => r.test(f)));
    const merging = (await tryGit(w.path, 'rev-parse', '-q', '--verify', 'MERGE_HEAD')) !== null;
    const last = ((await tryGit(w.path, 'log', '-1', '--format=%ct%x09%s')) ?? '').trim().split('\t');
    let working = [];
    try {
      const wt = parseTasks(await readFile(path.join(w.path, PLAN), 'utf8')).ticked;
      working = [...wt].filter((id) => !done.has(id));
    } catch { /* plan missing mid-checkout */ }
    lanes.push({
      label: kind === 'main' ? 'Main lane' : kind === 'stage' ? `Stage ${stage} lane` : `${w.branch.replace(/^godot\//, '')} lane`,
      folder: path.basename(w.path), path: w.path, branch: w.branch, stage, kind,
      dirty: dirty.length, merging, working,
      last: { time: Number(last[0]) || null, subject: last[1] ?? '' },
    });
  }

  const sideStages = new Set(lanes.filter((l) => l.stage).map((l) => l.stage));
  const sideTasks = new Set(stages.filter((s) => sideStages.has(s.n)).flatMap((s) => s.tasks));
  const ready = (id) => (blockers[id] ?? []).every((b) => done.has(b));
  for (const lane of lanes) {
    if (lane.kind === 'offplan') {
      lane.task = lane.working[0] ?? null;
      lane.state = lane.task ? 'working' : lane.dirty || lane.merging ? 'offplan' : 'idle';
      lane.title = lane.task ? titles[lane.task] ?? '' : '';
      continue;
    }
    const scope = lane.stage
      ? stages.find((s) => s.n === lane.stage)?.tasks ?? []
      : order.filter((id) => !sideTasks.has(id));
    const left = scope.filter((id) => !done.has(id));
    const nextReady = left.find(ready);
    if (lane.working.length) {
      lane.state = 'working'; lane.task = lane.working[0];
    } else if (lane.dirty || lane.merging) {
      lane.state = 'working'; lane.task = nextReady ?? left[0] ?? null;
    } else if (nextReady) {
      lane.state = 'next'; lane.task = nextReady;
    } else if (left.length) {
      lane.state = 'blocked'; lane.task = left[0];
      lane.blockedBy = (blockers[left[0]] ?? []).filter((b) => !done.has(b));
    } else {
      lane.state = 'finished'; lane.task = null;
    }
    lane.title = lane.task ? titles[lane.task] ?? '' : '';
  }

  const working = new Set(lanes.filter((l) => l.state === 'working' && l.task).map((l) => l.task));
  for (const l of lanes) for (const id of l.working) working.add(id);
  const next = new Set(lanes.filter((l) => l.state === 'next').map((l) => l.task));

  return {
    updated: Date.now(),
    total: all.length,
    done: [...done].filter((id) => all.includes(id)).length,
    stages: stages.map((s) => ({
      ...s,
      done: s.tasks.filter((id) => done.has(id)),
      working: s.tasks.filter((id) => working.has(id)),
      next: s.tasks.filter((id) => next.has(id)),
      lanes: lanes.filter((l) => (l.stage ? l.stage === s.n : s.tasks.includes(l.task))).map((l) => l.label),
      waiting: (() => {
        const first = s.tasks.find((id) => !done.has(id) && !working.has(id) && !next.has(id));
        const on = first ? (blockers[first] ?? []).filter((b) => !done.has(b)) : [];
        return on.length ? { task: first, on } : null;
      })(),
    })),
    lanes,
    others: trees.filter((t) => !isLane(t.branch)).map((t) => ({ folder: path.relative(REPO, t.path) || t.path, branch: t.branch })),
    titles,
    blockers,
    doneIds: [...done].filter((id) => all.includes(id)),
  };
}

let cached = null;
let cachedAt = 0;
let inflight = null;
async function data() {
  if (cached && Date.now() - cachedAt < CACHE_MS) return cached;
  inflight ??= collect().then((d) => { cached = d; cachedAt = Date.now(); return d; })
    .finally(() => { inflight = null; });
  return inflight;
}

const routes = makeRoutes({
  here: HERE, repo: REPO, port: PORT, getData: data,
  listSessions: () => listSessions({ projectsDir: path.join(os.homedir(), '.claude', 'projects'), prefix: projectPrefix(REPO) }),
});

createServer(async (req, res) => {
  try {
    if (await routes(req, res)) return;
    if (req.url.startsWith('/data')) {
      const body = JSON.stringify(await data());
      res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' });
      res.end(body);
      return;
    }
    const html = await readFile(path.join(HERE, 'index.html'));
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    res.end(html);
  } catch (err) {
    res.writeHead(500, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: String(err?.message ?? err) }));
  }
}).listen(PORT, '127.0.0.1', () => {
  console.log(`Progress dashboard on http://localhost:${PORT} (repo ${REPO})`);
});
