import { test } from 'node:test';
import assert from 'node:assert/strict';
import { taskBlock, parentBlock, storyIds, parseStories, stageDocs } from '../docs.mjs';

const PLAN = `## Tasks

- [ ] **7. Swing-based hits.**
  - Delivers: swings.
  - Check: tests.
  - [x] **7.1 Helpers.** Vector ops.
    - Check: identities.
      - deeper note
    - Blocked by: none · Stories: 59
  - [ ] **7.2 Swing data.** Keys.

    - Check: loads.
    - Blocked by: 7.1 · Stories: 16, 21–23
- [ ] **8. Fluid rules.**
`;
const SPEC = `## User Stories

### Attacking

16. [ ] As a player, I want arcs.
21. [x] As a player, I want blade hits.
22. [ ] As a player, I want unblockables.
`;

test('taskBlock takes the task line and everything indented under it, dedented', () => {
  assert.equal(taskBlock(PLAN, '7.1'),
    '- [x] **7.1 Helpers.** Vector ops.\n  - Check: identities.\n    - deeper note\n  - Blocked by: none · Stories: 59');
  assert.equal(taskBlock(PLAN, '7.2'),
    '- [ ] **7.2 Swing data.** Keys.\n\n  - Check: loads.\n  - Blocked by: 7.1 · Stories: 16, 21–23');
  assert.equal(taskBlock(PLAN, '9.9'), null);
});

test('parentBlock stops at the first subtask', () => {
  assert.equal(parentBlock(PLAN, '7'), '- [ ] **7. Swing-based hits.**\n  - Delivers: swings.\n  - Check: tests.');
  assert.equal(parentBlock(PLAN, '12'), null);
});

test('storyIds reads lists and ranges; parseStories keeps ticks', () => {
  assert.deepEqual(storyIds(taskBlock(PLAN, '7.2')), [16, 21, 22, 23]);
  assert.deepEqual(storyIds('- [ ] **x** no stories'), []);
  const s = parseStories(SPEC);
  assert.deepEqual(s.get(21), { n: 21, done: true, text: 'As a player, I want blade hits.' });
});

test('stageDocs puts it together, skipping missing stories', () => {
  const stage = { n: 7, name: 'Swing foundations', full: 'Swing foundations', tasks: ['7.1', '7.2'] };
  const states = new Map([['7.1', { state: 'done', blockedBy: [] }], ['7.2', { state: 'next', blockedBy: [] }]]);
  const d = stageDocs(PLAN, SPEC, stage, states);
  assert.deepEqual(d.parents.map((p) => p.id), ['7']);
  assert.equal(d.tasks[1].title, 'Swing data');
  assert.equal(d.tasks[1].state, 'next');
  assert.deepEqual(d.tasks[1].stories.map((s) => s.n), [16, 21, 22]); // 23 isn't in the spec
});
