// The round trip for batches: the real Project Manager server reads a plan from
// a fixture repository, and as a task is ticked done and committed, /data shows
// its new status and the batch it opens up (harness in lanes-board-harness.mjs).

import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { startBoard, waitFor } from './lanes-board-harness.mjs';

// Task 3 uses both 1 and 2, and 4 uses 3: while 1 is open no batch can start
// (3 waits on whichever of 1 and 2 a batch doesn't hold).
const planText = (oneDone) => `# Plan: Milestone 1

## Build order

1. **All:** 1, 2, 3, 4.

## Tasks

- [${oneDone ? 'x' : ' '}] **1. First.** Text.
  - Blocked by: none
- [ ] **2. Second.** Text.
  - Blocked by: none
- [ ] **3. Third.** Text.
  - Blocked by: 1, 2
- [ ] **4. Fourth.** Text.
  - Blocked by: 3
`;

describe('the round trip: batches as tasks clear', () => {
  let board;
  before(async () => { board = await startBoard(); });
  after(async () => { await board?.stop(); });

  const commitPlan = (oneDone) => {
    const file = path.join(board.repo, 'docs', 'plans', 'milestone-1.md');
    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, planText(oneDone));
    const git = (...args) => execFileSync('git', args, { cwd: board.repo, windowsHide: true, stdio: 'ignore' });
    git('add', '-A');
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-q', '-m', oneDone ? 'Tick task 1' : 'Add the plan');
  };
  const m1 = async () => (await board.get('/data')).body?.plans?.find((p) => p.key === 'm1');

  it('shows a task done and the batch it opens up once its tick is committed', async () => {
    commitPlan(false);
    const before = await waitFor(m1, 15000, 'the plan on /data');
    assert.deepEqual(Object.fromEntries(Object.entries(before.tasks).map(([id, t]) => [id, t.status])), { 1: 'ready', 2: 'ready', 3: 'blocked', 4: 'blocked' });
    assert.deepEqual(before.batches, []);

    commitPlan(true);
    const now = await waitFor(async () => { const p = await m1(); return p?.tasks[1].status === 'done' ? p : null; }, 15000, 'task 1 done on /data');
    assert.deepEqual(Object.fromEntries(Object.entries(now.tasks).map(([id, t]) => [id, t.status])), { 1: 'done', 2: 'ready', 3: 'blocked', 4: 'blocked' });
    assert.deepEqual(now.batches.map((b) => b.ids), [['2', '3', '4']]);
    assert.deepEqual(now.tasks[2].batch, { n: now.batches[0].n, at: 0, of: 3 });
    assert.deepEqual(now.tasks[4].batch, { n: now.batches[0].n, at: 2, of: 3 });
    assert.equal(now.tasks[1].batch, undefined);
  });

  it('stops a task waiting on the owner\'s OK once the gate\'s Done note records it', async () => {
    const gated = (okd) => `# Plan: Milestone 1

## Build order

1. **All:** 7, 8.

## Tasks

- [x] **7. The look test.** Text.
  - Blocked by: none
  - **Owner:** approves the scene.
  - Done Oct 6${okd ? ', approved by the owner as built' : ': built'}.
- [ ] **8. Blood.** Text.
  - Blocked by: 7 (and the owner's OK)
`;
    const commit = (text, msg) => {
      writeFileSync(path.join(board.repo, 'docs', 'plans', 'milestone-1.md'), text);
      const git = (...args) => execFileSync('git', args, { cwd: board.repo, windowsHide: true, stdio: 'ignore' });
      git('add', '-A');
      git('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-q', '-m', msg);
    };
    commit(gated(false), 'Build the look test');
    const waiting = await waitFor(async () => { const p = await m1(); return p?.tasks[8] ? p : null; }, 15000, 'task 8 on /data');
    assert.equal(waiting.tasks[8].status, 'owner');
    assert.deepEqual(waiting.tasks[8].ownerOk, ['7']);

    commit(gated(true), 'Record the owner\'s OK of the look test');
    const ready = await waitFor(async () => { const p = await m1(); return p?.tasks[8]?.status === 'ready' ? p : null; }, 15000, 'task 8 ready on /data');
    assert.deepEqual(ready.tasks[8].ownerOk, []);
  });
});
