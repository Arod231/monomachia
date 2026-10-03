// Which build-order stage a Claude Code session works on, and which lane's
// current task belongs to it. See docs/specs/session-tracker.md.
import path from 'node:path';

const MAIN_BRANCH = 'feature/godot-rebuild';
const norm = (p) => (p ? path.resolve(p).toLowerCase() : '');
const stageOfTask = (data, id) => data.stages.find((s) => s.tasks.includes(id))?.n ?? null;
const laneStage = (data, l) => l.stage ?? (l.task ? stageOfTask(data, l.task) : null);

export function sessionStage(session, data) {
  const branch = session.branch ?? '';
  const title = session.title ?? '';
  let n = null;
  const m = branch.match(/^godot\/stage-(\d+)/);
  if (m) n = Number(m[1]);
  else if (branch.startsWith('godot/')) return null; // off-plan work
  else {
    const t = title.match(/\bstage\s+(\d+)\b/i);
    const id = title.match(/\b(\d+b?\.\d+)\b/)?.[1];
    if (t) n = Number(t[1]);
    else if (id) n = stageOfTask(data, id);
    else if (branch === MAIN_BRANCH) {
      const main = data.lanes.find((l) => l.kind === 'main');
      n = main ? laneStage(data, main) : null;
    }
  }
  return data.stages.some((s) => s.n === n) ? n : null;
}

// Sessions newest first in, same order out. Each lane goes to the newest
// session in its folder, or failing that the newest session on its stage.
export function attachStages(sessions, data) {
  const sorted = [...sessions].sort((a, b) => b.lastActive - a.lastActive);
  const views = sorted.map((s) => ({ ...s, stage: sessionStage(s, data), task: null, taskTitle: '', laneState: null }));
  const give = (v, lane) => Object.assign(v, { task: lane.task ?? null, taskTitle: lane.title ?? '', laneState: lane.state });
  const claimed = new Set();
  for (const lane of data.lanes) {
    const v = views.find((x) => norm(x.cwd) === norm(lane.path));
    if (v) { give(v, lane); claimed.add(lane); }
  }
  for (const lane of data.lanes) {
    if (claimed.has(lane) || lane.kind === 'offplan') continue;
    const n = laneStage(data, lane);
    const v = views.find((x) => x.stage === n && x.laneState == null && n != null);
    if (v) give(v, lane);
  }
  return views;
}

export function taskStates(stage, data) {
  const done = new Set(data.doneIds);
  const working = new Set(stage.working);
  const next = new Set(stage.next);
  return new Map(stage.tasks.map((id) => {
    const blockedBy = (data.blockers[id] ?? []).filter((b) => !done.has(b));
    const state = done.has(id) ? 'done' : working.has(id) ? 'working' : next.has(id) ? 'next' : blockedBy.length ? 'blocked' : 'rest';
    return [id, { state, blockedBy }];
  }));
}
