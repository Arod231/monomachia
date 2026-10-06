// The lanes board's view of the plans: which plans it follows, how it reads
// their tasks, blockers and build order, how it merges the copies on different
// branches, the roadmap's phases, and the prompt a launched session starts with.
// Pure functions, no git or disk, so tests/lanes-board.test.mjs can run them on
// fixtures.
import path from 'node:path';

// A plan's header may name another branch (``branch `master` ``); the board then
// uses that one. Authored animation is closed: it shows as history. The Godot
// rebuild branch merged into master for good on Oct 5 (PR #68), and milestone 1's
// branch was folded into master on Oct 6, so the roadmap, the Godot rebuild plan
// and milestone 1 follow master: their lanes branch from it and PR into it.
export const PLANS = [
  { key: 'rm', short: 'RM', name: 'Roadmap', file: 'docs/plans/roadmap.md', kind: 'roadmap', branch: 'master' },
  { key: 'm1', short: 'M1', name: 'Milestone 1', file: 'docs/plans/milestone-1.md', kind: 'flat', branch: 'master' },
  { key: 'gr', short: 'GR', name: 'Godot rebuild', file: 'docs/plans/godot-rebuild.md', kind: 'nested', branch: 'master',
    names: { 1: 'Resume and safety nets', 2: 'The look, real fighters', 3: 'The shrine', 4: 'Fluid rules', 5: 'Sound and music',
      6: 'The new strings', 7: 'Swing foundations', 8: 'Fighter animation core', 9: 'Katana swings, anim review',
      10: 'Editor, HUD, effects, menus', 11: "Other weapons' swings", 12: 'Computer and balance', 13: 'Full animation', 14: 'Consolidate and ship' } },
  { key: 'aa', short: 'AA', name: 'Authored animation', file: 'docs/plans/authored-animation.md', kind: 'flat', branch: 'feature/authored-animation',
    into: 'master', closed: true },
  { key: 'pm', short: 'PM', name: 'Project Manager remote control', file: 'docs/plans/project-manager-remote.md', kind: 'flat',
    branch: 'tools/project-manager-remote', into: 'master' },
];
export const PLAN_BY_KEY = Object.fromEntries(PLANS.map((p) => [p.key, p]));

// How a commit subject names the plan task it finishes: "(task 7.1)" in the
// rebuild, "(task 12)" or "(milestone-1 task 12)", "(roadmap task R3)", "(PM task 6)".
export const SUBJECT_TASK = {
  gr: /\(task (\d+b?\.\d+)\)/, aa: /\((?:authored animation )?task (\d+[a-z]?)\)/,
  m1: /\((?:milestone[- ]1 )?task (\d+)\)/, rm: /\((?:roadmap )?task (R\d+)\)/,
  pm: /\(PM task (\d+)\)/,
};
const KEY_BY_FILE = Object.fromEntries(PLANS.map((p) => [path.posix.basename(p.file), p.key]));

// "8.4–8.9", "14b.1–14b.6", "13.1" -> ids.
export function expandIds(text) {
  const out = [];
  const re = /(\d+b?)\.(\d+)(?:\s*[–-]\s*(?:(\d+b?)\.)?(\d+))?/g;
  for (const [, major, from, , to] of text.matchAll(re)) {
    if (to === undefined) { out.push(`${major}.${from}`); continue; }
    for (let i = Number(from); i <= Number(to); i++) out.push(`${major}.${i}`);
  }
  return out;
}
const section = (text, heading) => text.split(new RegExp(`^## ${heading}`, 'm'))[1]?.split(/^## /m)[0] ?? '';

// Task ids: "12.4" in the nested plan, "12" or "30b" in a flat one, "R3" in the
// roadmap; ANY is any of them (another plan's task). A range's end may drop its
// prefix ("8.4–9", "R4–6").
const ID = { nested: String.raw`\d+b?\.\d+`, flat: String.raw`(?<![\w.])\d+[a-z]?(?!\w|\.\d)`, roadmap: String.raw`(?<!\w)R\d+(?!\w)` };
const ANY = String.raw`R\d+|\d+b?\.\d+|\d+[a-z]?`;
const END = String.raw`(?:R|\d+b?\.)?\d+`;
const RANGE = (id) => String.raw`(${id})(?:\s*[–-]\s*(${END}))?`;
// `docs/plans/<file>.md` task <id>, or tasks <id>, <id> and <id>. The ids take
// the shape of that plan's kind (any shape for a plan the board doesn't follow)
// and a list ends at its "and <id>", so local ids written after it stay local.
const CROSS = /`docs\/plans\/([\w.-]+\.md)`\s+(tasks?)\s+/g;
function crossList(kind, many) {
  const one = String.raw`(?:${ID[kind] ?? ANY})(?:\s*[–-]\s*${END})?`;
  return new RegExp(many ? String.raw`${one}(?:\s*,\s*${one})*(?:,?\s+and\s+${one})?` : one, 'y');
}
const ITEM = new RegExp(RANGE(ANY), 'g');

// One id, or a range's ids ("23.4", "23.7" -> 23.4 … 23.7).
function expand(from, to) {
  if (!to) return [from];
  const [, pre = '', a] = from.match(/^(R|\d+b?\.)?(\d+)/);
  const [, preTo, b] = to.match(/^(R|\d+b?\.)?(\d+)/);
  if ((preTo && preTo !== pre) || Number(b) < Number(a) || Number(b) - Number(a) > 200) return [from, to];
  return Array.from({ length: Number(b) - Number(a) + 1 }, (_, i) => `${pre}${Number(a) + i}`);
}
const idList = (text) => [...text.matchAll(ITEM)].flatMap((m) => expand(m[1], m[2]));

// A Blocked by or Replaces list -> refs ('gr:26.4') in reading order, and those
// gated on the owner's OK ("12 (and the owner's OK)"). Other plans' tasks are
// in the backticked file form; a file the board doesn't follow is dropped, and
// so are notes in brackets. Replaces lists take other plans' tasks only.
function readRefs(text, plan, local = true) {
  const found = [];
  const blank = (m) => ' '.repeat(m.length);
  let rest = text;
  for (const head of text.matchAll(CROSS)) {
    const key = KEY_BY_FILE[head[1]];
    const list = crossList(PLAN_BY_KEY[key]?.kind, head[2] === 'tasks');
    list.lastIndex = head.index + head[0].length;
    const m = list.exec(text);
    const end = m ? list.lastIndex : head.index + head[0].length;
    if (key && m) found.push({ at: head.index, end, refs: idList(m[0]).map((id) => `${key}:${id}`) });
    rest = rest.slice(0, head.index) + blank(text.slice(head.index, end)) + rest.slice(end);
  }
  rest = rest.replace(/\([^)]*\)/g, blank);
  if (local) {
    for (const m of rest.matchAll(new RegExp(RANGE(ID[plan.kind]), 'g'))) {
      found.push({ at: m.index, end: m.index + m[0].length, refs: expand(m[1], m[2]).map((id) => `${plan.key}:${id}`) });
    }
  }
  found.sort((a, b) => a.at - b.at);
  return {
    refs: found.flatMap((f) => f.refs),
    gates: found.filter((f) => /^\s*\(and the owner's OK\)/.test(text.slice(f.end))).map((f) => f.refs.at(-1)),
  };
}

// ``branch `name` `` in the lines before the plan's first section.
const headerBranch = (text) => text.split(/^## /m)[0].match(/\bbranch `([^`\s]+)`/)?.[1] ?? null;

const TASK_LINE = {
  nested: /^\s*- \[([ x-])\] (?:~~)?\*\*(\d+b?\.\d+)\s+(.*?)\*\*/,
  flat: /^- \[([ x-])\] (?:~~)?\*\*(\d+[a-z]?)\.\s+(.*?)\*\*/,
  roadmap: /^- \[([ x-])\] (?:~~)?\*\*(R\d+)\.\s+(.*?)\*\*/,
};
const OTHER_LINE = { nested: /^\s*- \[[ x-]\] /, flat: /^- \[/, roadmap: /^- \[/ };

// Every task and the sub-bullets under it: its blockers (the first "Blocked
// by:" line, up to " · "; "none" for none), Replaces, an **Owner:** gate, and,
// on a retired task, a "Moved to milestone 1" (or 2) note that makes it moved.
function readTasks(text, plan) {
  const tasks = new Map();
  const gates = new Set();
  const seen = new Set();
  let cur = null;
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(TASK_LINE[plan.kind]);
    if (m) {
      cur = { id: m[2], title: m[3].replace(/[.;:]\s*$/, ''), mark: m[1], blockers: [], gatedBy: [], replaces: [], gate: false, moved: null };
      tasks.set(cur.id, cur);
      continue;
    }
    if (OTHER_LINE[plan.kind].test(line) || line.startsWith('#')) { cur = null; continue; }
    if (!cur) continue;
    if (/\*\*Owner:\*\*/.test(line)) cur.gate = true;
    const moved = cur.mark === '-' && line.match(/^\s+- Moved to milestone ([12])\b/);
    if (moved) cur.moved = `m${moved[1]}`;
    const r = line.match(/^\s+- Replaces:\s*(.*)/);
    if (r) cur.replaces.push(...readRefs(r[1], plan, false).refs);
    const b = !seen.has(cur.id) && line.match(/Blocked by:\s*(.*)/);
    if (b) {
      seen.add(cur.id);
      const frag = b[1].split(' · ')[0];
      if (/^\s*none/i.test(frag)) continue;
      const { refs, gates: gated } = readRefs(frag, plan);
      cur.blockers = refs;
      cur.gatedBy = gated;
      for (const g of gated) if (g.startsWith(`${plan.key}:`)) gates.add(g.slice(plan.key.length + 1));
    }
  }
  for (const id of gates) if (tasks.has(id)) tasks.get(id).gate = true;
  return tasks;
}

// "N. **Name:** list" lines of a section; a note in brackets after the name is
// skipped (kept in `note` for "(alongside phase N)").
function readOrder(text, heading) {
  return section(text, heading).split(/\r?\n/).flatMap((line) => {
    const m = line.match(/^(\d+)\.\s+\*\*(.+?)\*\*(.*)$/);
    if (!m) return [];
    const rest = m[3].replace(/\([^)]*\)/g, '');
    return [{ n: Number(m[1]), name: m[2].replace(/:$/, ''), note: m[3], list: rest.includes(':') ? rest.slice(rest.indexOf(':') + 1) : rest }];
  });
}

// The godot-rebuild plan: nested "- [x] **7.1 Title.**" tasks, "- [-] ~~**7.16 …**~~"
// when retired, and a "## Build order" list of stages.
export function parseNested(text, plan) {
  const tasks = readTasks(text, plan);
  const stages = readOrder(text, 'Build order').map((s) => ({
    n: s.n, name: plan.names?.[s.n] ?? s.name, ids: expandIds(s.list).filter((id) => tasks.has(id)),
  }));
  return { tasks, stages, branch: headerBranch(text) };
}

// The flat plans (milestone 1, authored animation): top-level "- [x] **9. Title.**"
// tasks; a blocker written "14 (and the owner's OK)" makes 14 a review gate.
export function parseFlat(text, plan) {
  const tasks = readTasks(text, plan);
  const local = new RegExp(RANGE(ID.flat), 'g');
  const stages = readOrder(text, 'Build order').map((s) => ({
    n: s.n, name: s.name, ids: [...s.list.matchAll(local)].flatMap((m) => expand(m[1], m[2])).filter((id) => tasks.has(id)),
  }));
  return { tasks, stages, branch: headerBranch(text) };
}

// A phase's refs: "R1", "gr 25.4", "gr 23.4–23.7", "m1 *" (every task in that
// plan that isn't retired or moved). One that can't be read goes in `bad`.
const PHASE_REF = new RegExp(String.raw`^(?:([a-z][a-z0-9]*)\s+)?(\*|${ANY})(?:\s*[–-]\s*(${END}))?$`);

// The roadmap: "- [ ] **R1. Title.**" tasks as in a flat plan, and a "## Phases"
// list ("3. **Master follow-ups** (alongside phase 2): gr 18.11, …"). The
// phases double as stages of the roadmap's own tasks, so the other views work.
export function parseRoadmap(text, plan) {
  const tasks = readTasks(text, plan);
  const phases = readOrder(text, 'Phases').map((s) => {
    const refs = [];
    const bad = [];
    for (const item of s.list.split(',').map((x) => x.trim().replace(/[.…]+$/, '').trim()).filter(Boolean)) {
      const m = item.match(PHASE_REF);
      if (!m || (!m[1] && !/^R\d+$/.test(m[2]))) { bad.push(item); continue; }
      const key = m[1] ?? plan.key;
      refs.push(...(m[2] === '*' ? ['*'] : expand(m[2], m[3])).map((id) => `${key}:${id}`));
    }
    return { n: s.n, name: s.name, alongside: Number(s.note.match(/\([^)]*\balongside phase (\d+)\b[^)]*\)/)?.[1]) || null, refs, bad };
  });
  // A phase of other plans' tasks only would be an empty stage, which reads as finished.
  const stages = phases.map((p) => ({
    n: p.n, name: p.name, ids: p.refs.filter((r) => r.startsWith(`${plan.key}:`)).map((r) => r.slice(plan.key.length + 1)).filter((id) => tasks.has(id)),
  })).filter((s) => s.ids.length);
  return { tasks, stages, phases, branch: headerBranch(text) };
}

const PARSERS = { nested: parseNested, flat: parseFlat, roadmap: parseRoadmap };
export const parsePlan = (plan, text) => PARSERS[plan.kind](text, plan);

/**
 * One plan from its copies on every branch, each { time, p } (p from parsePlan,
 * time when that branch last changed the file). Stages, phases and the header
 * branch come from the newest copy. Branches change different tasks (one
 * re-points 12.2's blockers while another ticks 22.2), so each task's text comes
 * from the newest copy that changed it from the oldest copy, and from the newest
 * copy otherwise. A task is done or retired when any copy says so, and moved
 * (to milestone 1 or 2, neither done nor retired) when any copy says that.
 */
export function mergeCopies(copies) {
  const newest = copies.reduce((a, b) => (b.time > a.time ? b : a));
  const oldest = copies.reduce((a, b) => (b.time < a.time ? b : a));
  const sig = (t) => JSON.stringify([t.title, t.blockers, t.gatedBy ?? [], t.replaces ?? []]);
  const tasks = new Map();
  for (const t of newest.p.tasks.values()) {
    const o = oldest.p.tasks.get(t.id);
    let best = null;
    for (const c of copies) {
      const v = c.p.tasks.get(t.id);
      if (v && o && sig(v) !== sig(o) && (!best || c.time > best.time)) best = { time: c.time, v };
    }
    tasks.set(t.id, best
      ? { ...t, title: best.v.title, blockers: best.v.blockers, gatedBy: best.v.gatedBy, replaces: best.v.replaces, gate: t.gate || best.v.gate }
      : t);
  }
  const done = new Set();
  const retired = new Set();
  const moved = new Map();
  for (const { p } of [...copies].sort((a, b) => a.time - b.time)) {
    for (const t of p.tasks.values()) {
      if (t.mark === 'x') done.add(t.id);
      if (t.mark === '-') retired.add(t.id);
      if (t.moved) moved.set(t.id, t.moved);
    }
  }
  for (const id of moved.keys()) { done.delete(id); retired.delete(id); }
  for (const [id, t] of tasks) tasks.set(id, { ...t, moved: moved.get(id) ?? null });
  return { tasks, stages: newest.p.stages, phases: newest.p.phases, branch: newest.p.branch ?? null, done, retired, moved };
}

/**
 * Each moved task's ref -> the task whose Replaces names it ('gr:18.4' ->
 * 'm1:12'), preferring one in the milestone it moved to. plans: [{ key, tasks }]
 * with tasks as parsed.
 */
export function linkMoved(plans) {
  const by = new Map(); // replaced ref -> replacing refs
  for (const p of plans) {
    for (const t of p.tasks.values()) for (const r of t.replaces ?? []) (by.get(r) ?? by.set(r, []).get(r)).push(`${p.key}:${t.id}`);
  }
  const links = new Map();
  for (const p of plans) {
    for (const t of p.tasks.values()) {
      const ref = `${p.key}:${t.id}`;
      const found = t.moved ? by.get(ref) : null;
      if (found?.length) links.set(ref, found.find((r) => r.startsWith(`${t.moved}:`)) ?? found[0]);
    }
  }
  return links;
}

// Which plan a worktree's branch works on, and a launched lane's tasks: the lane
// branch names both (lane/gr-22.2-22.3, lane/rm-R3-R4). Otherwise a plan's own
// branch (branches: key -> the branch it uses now), godot/* or *authored-animation*
// claims that plan; the rebuild comes before the roadmap that shares its branch.
const LANE = new RegExp(`^lane/(${PLANS.map((p) => p.key).join('|')})-(.+)$`);
const CLAIM_ORDER = ['gr', 'm1', 'rm', 'aa', 'pm'];
export function planOfBranch(branch, branches) {
  const b = branch ?? '';
  const lane = b.match(LANE);
  if (lane) return { key: lane[1], scope: lane[2].split('-').filter(Boolean) };
  const own = b && CLAIM_ORDER.find((k) => branches[k] === b);
  if (own) return { key: own, scope: null };
  if (/^godot\//.test(b)) return { key: 'gr', scope: null };
  if (/authored-animation/.test(b)) return { key: 'aa', scope: null };
  return null;
}

const OPEN = ['working', 'launched', 'ready', 'owner', 'blocked'];

/**
 * The roadmap's phases against the /data plans ({ key, stages, tasks: { id:
 * { title, status } } }) and lanes. Each phase gets its live tasks (moved and
 * retired ones left out; "m1 *" is every live milestone-1 task in plan order),
 * the refs it can't find (`unknown`) or whose plan has no copy yet (`waiting`),
 * counts, up to five ready tasks next, the lanes on its tasks, and `current`:
 * the first phase with open tasks, and any phase alongside it.
 */
export function roadmapView(phases, plans, lanes) {
  const byKey = new Map(plans.map((p) => [p.key, p]));
  const live = (t) => !!t && t.status !== 'moved' && t.status !== 'retired';
  const task = (ref) => { const [k, id] = ref.split(':'); return byKey.get(k)?.tasks[id]; };
  const view = phases.map((ph) => {
    const refs = [];
    const unknown = [];
    const waiting = [];
    for (const ref of ph.refs) {
      const [k, id] = ref.split(':');
      const p = byKey.get(k);
      if (!p) (PLAN_BY_KEY[k] ? waiting : unknown).push(ref);
      else if (id === '*') {
        const order = new Set([...p.stages.flatMap((s) => s.ids), ...Object.keys(p.tasks)]);
        refs.push(...[...order].filter((x) => live(p.tasks[x])).map((x) => `${k}:${x}`));
      } else if (!p.tasks[id]) unknown.push(ref);
      else if (live(p.tasks[id])) refs.push(ref);
    }
    const ids = [...new Set(refs)];
    const counts = { done: 0, open: 0, ...Object.fromEntries(OPEN.map((s) => [s, 0])) };
    for (const ref of ids) {
      const s = task(ref).status;
      if (s in counts) counts[s]++;
      if (s !== 'done') counts.open++;
    }
    const mine = new Set(ids);
    const on = lanes.filter((l) => !l.ended && l.plan
      && (l.scope?.some((id) => mine.has(`${l.plan}:${id}`)) || (l.working && mine.has(`${l.plan}:${l.task}`))));
    return {
      n: ph.n, name: ph.name, alongside: ph.alongside, current: false, refs: ids, unknown: [...unknown, ...ph.bad], waiting,
      total: ids.length, counts,
      next: ids.filter((r) => task(r).status === 'ready').slice(0, 5).map((ref) => ({ ref, title: task(ref).title, status: 'ready' })),
      lanes: on.map((l) => ({ folder: l.folder, branch: l.branch, task: l.task ? `${l.plan}:${l.task}` : null, working: !!l.working })),
    };
  });
  const first = view.find((v) => v.counts.open > 0);
  for (const v of view) {
    v.current = !!first && (v === first || (v.counts.open > 0 && (v.alongside === first.n || first.alongside === v.n)));
  }
  return view;
}

/**
 * The batches a plan can run side by side now (docs/agents/issue-tracker.md,
 * "Blockers"): each starts on a task that can start (ready, or waiting only on
 * the owner's OK, which launching it gives), and takes, one after another, the
 * tasks whose every blocker is done or earlier in the batch and that use at
 * least one task in it, so a session working through it never waits. The next
 * task is the first in build order that uses the batch's newest task, else any
 * task in it. A task gated on the owner's OK of a task in the batch, or already
 * started or launched, is never taken. Heads are tried in build order and each
 * task goes to one batch only; a head with nothing to chain makes no batch.
 * plan: a /data plan ({ key, stages, tasks }). Returns lists of task ids, in order.
 */
export function findBatches(plan) {
  const order = [...new Set(plan.stages.flatMap((s) => s.ids))].filter((id) => plan.tasks[id]);
  const local = `${plan.key}:`;
  const taken = new Set();
  const batches = [];
  for (const head of order.filter((id) => ['ready', 'owner'].includes(plan.tasks[id].status))) {
    const batch = [head];
    const uses = (id, ids) => plan.tasks[id].blockers.some((b) => b.ref.startsWith(local) && ids.includes(b.ref.slice(local.length)));
    const fits = (id) => {
      const t = plan.tasks[id];
      if (t.status !== 'blocked' || taken.has(id) || batch.includes(id) || (t.ownerOk ?? []).some((g) => batch.includes(g))) return false;
      return t.blockers.every((b) => b.done || (b.ref.startsWith(local) && batch.includes(b.ref.slice(local.length))));
    };
    for (;;) {
      const open = order.filter((id) => fits(id) && uses(id, batch));
      const next = open.find((id) => uses(id, [batch.at(-1)])) ?? open[0];
      if (!next) break;
      batch.push(next);
    }
    if (batch.length < 2) continue;
    for (const id of batch) taken.add(id);
    batches.push(batch);
  }
  return batches;
}

/**
 * Launching a lane's tasks again is the owner taking the work back up, so any
 * stop entry left from ending that lane (same branch) is cancelled; the stop
 * hook skips cancelled entries. Returns the entries and how many it cancelled.
 */
export function cancelStops(entries, branch, now) {
  let cancelled = 0;
  const out = entries.map((e) => {
    if (e.branch !== branch || e.cancelledAt) return e;
    cancelled++;
    return { ...e, cancelledAt: now };
  });
  return { entries: out, cancelled };
}

/**
 * A launch's tasks in a session title, in the order given: "Task 12", "Tasks
 * 1-4", "Tasks 4-6, 13", "Tasks 8.4-8.6, 9.1". A run is ids with the same
 * prefix ("8.", "R" or none) and numbers one after another; a lettered id
 * ("30b") stands alone.
 */
export function taskRange(ids) {
  const parts = ids.map((id) => {
    const m = /^(.*?)(\d+)$/.exec(id);
    return m ? { id, prefix: m[1], n: Number(m[2]) } : { id };
  });
  const runs = [];
  for (const p of parts) {
    const run = runs.at(-1);
    const last = run?.at(-1);
    if (last && p.n !== undefined && last.n !== undefined && p.prefix === last.prefix && p.n === last.n + 1) run.push(p);
    else runs.push([p]);
  }
  const text = runs.map((r) => (r.length > 1 ? `${r[0].id}-${r.at(-1).id}` : r[0].id)).join(', ');
  return `${ids.length > 1 ? 'Tasks' : 'Task'} ${text}`;
}

/**
 * A launched session's title, which the session sets itself right after setup (goalFor): its
 * task range, then "<plan short> PR #<pr> <task range>" once its lane has a
 * pull request.
 */
export function sessionTitle({ plan, ids, pr }) {
  const range = taskRange(ids);
  return pr === undefined ? range : `${plan.short} PR #${pr} ${range}`;
}

export const GOAL_LIMIT = 4000; // launch prompts stay this short (the app cuts a link's prompt at 14,336 characters)

/**
 * The prompt a launched session starts with; the board sends it for the owner
 * (launcher.mjs). Plain words, not /goal: the app turns a link prompt's leading
 * "/" into a full-width "／", so a slash command in a link never runs. If the
 * app's "Trust this workspace?" is cancelled (Enter on it does that), the app
 * drops the link's folder and opens the session in a scratch folder, so the
 * prompt itself brings the session into the repository. Work stays on a lane branch
 * with a pull request into the plan's branch (the owner chose to keep the PRs);
 * plan.branch is the one the plan's header names. When the board sees no such
 * branch on origin (baseExists false; milestone 1's comes with the
 * consolidation), the session checks again and stops to tell the owner rather
 * than invent a base.
 */
export function goalFor({ plan, ids, tasks, branch, repo, baseExists = true }) {
  const list = (n) => ids.map((id) => `${id} ${tasks[id].title.slice(0, n)}`).join('; ');
  const worktree = path.win32.join(repo, '.claude', 'worktrees', branch.replace(/[^A-Za-z0-9-]/g, '-'));
  const base = `origin/${plan.branch}`;
  const target = plan.into ? `${plan.branch} (which merges into ${plan.into})` : plan.branch;
  // A lane of a plan on master opens its pull request into master; any other stays off it.
  const notMaster = plan.branch === 'master' ? '' : ', never master';
  const body = (n) => [
    ...(baseExists ? [] : [`First: ${base} does not exist yet (the board saw no such branch). Run git -C "${repo}" fetch origin; if ${base} is still missing, stop and tell me, and do not create it or build on another branch.`]),
    `Finish implementation of the queued ${plan.name} tasks: ${list(n)} (${plan.file}), in the Monomachia repository at ${repo}, with every change built on and merged into ${target}.`,
    `Done when each queued task is built with its checks passing, ticked in ${plan.file}, committed and pushed on ${branch}, with a pull request into ${plan.branch}${notMaster}${baseExists ? '' : `; or, if ${base} is still missing, when you have told me so and stopped`}.`,
    `Setup, before anything else: work only in a worktree of ${repo}, never in a scratch or other folder. If your working directory is not inside ${repo}, run git -C "${repo}" fetch origin, then git -C "${repo}" worktree add "${worktree}" -b ${branch} ${base} (or check out ${branch} there if it exists), and move this session into it with the change_directory tool (find it with ToolSearch). Otherwise run git fetch origin and git switch -c ${branch} ${base} in this worktree.`,
    `Then name this session: set this session's title to "${sessionTitle({ plan, ids })}" with the set_session_title tool (session_id "self"; find it with ToolSearch). As soon as ${branch} has a pull request (yours, or one already open), set it to "${sessionTitle({ plan, ids, pr: '<number>' })}" with the pull request's number in place of <number>.`,
    `Before any edit, check that git branch --show-current prints ${branch} and that git merge-base --is-ancestor ${base} HEAD succeeds. If missing, copy .godot-path and .assets-src-path from ${repo} and junction its node_modules.`,
    'Before implementing, run wayfinder for questions only: read ~/.claude/skills/wayfinder/SKILL.md (it cannot be called as a tool) and follow its questioning to find every open decision these tasks need, but write no map or ticket files.',
    'Ask each decision with the AskUserQuestion tool as clickable multiple choice, recommended option first, and wait for my answers. Record the answers in the tasks\' blocks in the plan.',
    `Then implement the tasks one at a time in plan order, per CLAUDE.md (tests first; npm test and npm run typecheck before each commit; push after each; a draft PR into ${plan.branch}), ticking each in the plan as it lands. Follow the plan's Notes and the side-lane rules in memory, and stop to ask me at any owner gate.`,
    'Go on from one task to the next without waiting for my OK; stop only for a question that needs my answer, at an owner gate, or when every queued task is done.',
  ].join(' ');
  for (const n of [120, 60, 30, 0]) {
    const text = body(n);
    if (text.length <= GOAL_LIMIT) return text;
  }
  return body(0).slice(0, GOAL_LIMIT);
}
