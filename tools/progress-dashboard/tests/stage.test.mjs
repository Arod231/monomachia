import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sessionStage, attachStages, taskStates } from '../stage.mjs';

const data = {
  stages: [
    { n: 3, name: 'The shrine', tasks: ['17.1'], done: ['17.1'], working: [], next: [] },
    { n: 6, name: 'Strings', tasks: ['9.1', '9.2'], done: ['9.1'], working: [], next: ['9.2'] },
    { n: 7, name: 'Swings', tasks: ['7.1', '7.2', '7.3'], done: ['7.1'], working: ['7.2'], next: [] },
    { n: 8, name: 'Animation', tasks: ['14.3', '14.4'], done: [], working: [], next: [] },
  ],
  lanes: [
    { path: 'C:\\m', branch: 'feature/godot-rebuild', kind: 'main', stage: null, task: '9.2', title: 'Iai', state: 'next' },
    { path: 'C:\\s7', branch: 'godot/stage-7-swings', kind: 'stage', stage: 7, task: '7.2', title: 'Swing data', state: 'working' },
  ],
  blockers: { '7.3': ['7.2'], '14.4': ['14.3'] },
  doneIds: ['17.1', '9.1', '7.1'],
};
const s = (o) => ({ id: o.id ?? 'x', title: '', cwd: null, branch: null, lastActive: 0, ...o });

test('stage from the branch, the title, or the main lane', () => {
  assert.equal(sessionStage(s({ branch: 'godot/stage-7-swings' }), data), 7);
  assert.equal(sessionStage(s({ branch: 'godot/shuffle-footsteps', title: 'Stage 8 work' }), data), null);
  assert.equal(sessionStage(s({ branch: 'claude/x', title: 'Stage 3 completion' }), data), 3);
  assert.equal(sessionStage(s({ branch: 'HEAD', title: 'Fighter animation core tasks 14.3–14.9' }), data), 8);
  assert.equal(sessionStage(s({ branch: 'feature/godot-rebuild', title: 'Stage 3 completion' }), data), 3);
  assert.equal(sessionStage(s({ branch: 'feature/godot-rebuild', title: 'Godot Rebuild' }), data), 6);
  assert.equal(sessionStage(s({ branch: 'master', title: 'CLAUDE.md commit' }), data), null);
  assert.equal(sessionStage(s({ branch: 'claude/x', title: 'Stage 99' }), data), null);
});

test('a lane goes only to its newest session, by cwd first, then by stage', () => {
  const list = attachStages([
    s({ id: 'new-main', cwd: 'C:\\m', branch: 'feature/godot-rebuild', title: 'Godot Rebuild', lastActive: 9 }),
    s({ id: 'app-wt', cwd: 'C:\\wt', branch: 'godot/stage-7-swings', lastActive: 8 }),
    s({ id: 'old-main', cwd: 'C:\\m', branch: 'feature/godot-rebuild', title: 'Stage 3 completion', lastActive: 1 }),
  ], data);
  assert.deepEqual(list.map((x) => [x.id, x.stage, x.task, x.laneState]), [
    ['new-main', 6, '9.2', 'next'],
    ['app-wt', 7, '7.2', 'working'],
    ['old-main', 3, null, null],
  ]);
});

test('task states: done, working, next, blocked, rest', () => {
  const st = taskStates(data.stages[2], data);
  assert.deepEqual(Object.fromEntries([...st].map(([k, v]) => [k, v.state])), { '7.1': 'done', '7.2': 'working', '7.3': 'blocked' });
  assert.deepEqual(st.get('7.3').blockedBy, ['7.2']);
  assert.equal(taskStates(data.stages[3], data).get('14.3').state, 'rest');
});
