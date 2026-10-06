// Tests for tools/lanes-board: how the board reads the plans (plans.mjs), the
// roadmap's phases, the goal a launched session starts with, and the stop hook
// that ends a lane's work.

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import {
  GOAL_LIMIT, PLANS, PLAN_BY_KEY, cancelStops, expandIds, goalFor, linkMoved, mergeCopies, parseFlat, parseNested,
  SUBJECT_TASK, findBatches, parsePlan, parseRoadmap, planOfBranch, roadmapView, sessionTitle, taskRange,
} from '../tools/lanes-board/plans.mjs';

const GR = PLAN_BY_KEY.gr;
const AA = PLAN_BY_KEY.aa;
const M1 = PLAN_BY_KEY.m1;
const RM = PLAN_BY_KEY.rm;

const REBUILD = `# Plan

## Build order

1. **Resume:** 13.1, 25.1–25.2.
2. **Effects** (begun early: on the owner's word): 18.1, 18.2.

## Tasks

- [ ] **18. Effects.**
  - [x] **13.1 Merge the fighters.** Text.
    - Blocked by: none · Stories: 1
  - [-] ~~**25.1 Size guard.**~~
    - Retired on Oct 3.
  - [ ] **25.2 Export preset.** Text.
    - Blocked by: 13.1, 25.1 (when it lands) · Stories: 2
  - [ ] **18.1 The effects layer.** Text.
    - Blocked by: \`docs/plans/authored-animation.md\` task 36, 25.2 · Stories: 3
  - [ ] **18.2 Trail rules;** Text.
    - Blocked by: 18.1
`;

describe('expandIds', () => {
  it('reads single ids, ranges and lettered majors', () => {
    assert.deepEqual(expandIds('13.1, 8.4–8.6, 14b.1-14b.2'), ['13.1', '8.4', '8.5', '8.6', '14b.1', '14b.2']);
  });
});

describe('parseNested', () => {
  const { tasks, stages } = parseNested(REBUILD, GR);

  it('reads ticks, open tasks and retired ones, but not the parent heading', () => {
    assert.deepEqual([...tasks.keys()], ['13.1', '25.1', '25.2', '18.1', '18.2']);
    assert.equal(tasks.get('13.1').mark, 'x');
    assert.equal(tasks.get('25.1').mark, '-');
    assert.equal(tasks.get('25.2').mark, ' ');
    assert.equal(tasks.get('18.2').title, 'Trail rules');
  });

  it('reads blockers, dropping notes in brackets and naming other plans', () => {
    assert.deepEqual(tasks.get('13.1').blockers, []);
    assert.deepEqual(tasks.get('25.2').blockers, ['gr:13.1', 'gr:25.1']);
    assert.deepEqual(tasks.get('18.1').blockers, ['aa:36', 'gr:25.2']);
  });

  it('reads the build order, with the plan\'s short stage names', () => {
    assert.deepEqual(stages, [
      { n: 1, name: 'Resume and safety nets', ids: ['13.1', '25.1', '25.2'] },
      { n: 2, name: 'The look, real fighters', ids: ['18.1', '18.2'] },
    ]);
  });
});

describe('parseFlat', () => {
  const PLAN = `# Plan

## Build order

1. **The Katana** (after the catalogue's OK): 9, 14.
2. **The Greatsword:** 18.

## Tasks

- [x] **9. Right Cut.** Text.
  - Blocked by: 5 (and the owner's OK), 7 · Stories: 1
- [ ] **14. The Katana's review.**
  - **Owner:** OKs the Katana.
  - Blocked by: 9
- [ ] **18. The Greatsword's string.**
  - Blocked by: 14 (and the owner's OK), 15
`;
  const { tasks, stages } = parseFlat(PLAN, AA);

  it('reads tasks, blockers and the owner gates', () => {
    assert.equal(tasks.get('9').mark, 'x');
    assert.deepEqual(tasks.get('9').blockers, ['aa:5', 'aa:7']);
    assert.deepEqual(tasks.get('18').blockers, ['aa:14', 'aa:15']);
    assert.deepEqual(tasks.get('18').gatedBy, ['aa:14']);
    assert.equal(tasks.get('14').gate, true);
    assert.equal(tasks.get('9').gate, false);
  });

  it('reads the build order past a note in brackets', () => {
    assert.deepEqual(stages.map((s) => s.ids), [['9', '14'], ['18']]);
  });
});

describe('PLANS', () => {
  it('follows the roadmap, milestone 1, the Godot rebuild, authored animation (closed) and the Project Manager\'s remote control, not the session tracker', () => {
    assert.deepEqual(PLANS.map((p) => [p.key, p.kind, p.branch, !!p.closed]), [
      ['rm', 'roadmap', 'master', false],
      ['m1', 'flat', 'master', false],
      ['gr', 'nested', 'master', false],
      ['aa', 'flat', 'feature/authored-animation', true],
      ['pm', 'flat', 'tools/project-manager-remote', false],
    ]);
    assert.equal(RM.file, 'docs/plans/roadmap.md');
    assert.equal(M1.file, 'docs/plans/milestone-1.md');
    assert.equal(PLAN_BY_KEY.pm.file, 'docs/plans/project-manager-remote.md');
    assert.equal(PLAN_BY_KEY.pm.into, 'master');
  });
});

describe('the Project Manager plan (PM)', () => {
  const branches = Object.fromEntries(PLANS.map((p) => [p.key, p.branch]));

  it('is claimed by its own branch and by launched pm lanes', () => {
    assert.deepEqual(planOfBranch('tools/project-manager-remote', branches), { key: 'pm', scope: null });
    assert.deepEqual(planOfBranch('lane/pm-6-7', branches), { key: 'pm', scope: ['6', '7'] });
  });

  it('names its tasks in commit subjects as "(PM task N)" only', () => {
    assert.equal('Hold questions while Away is on (PM task 6)'.match(SUBJECT_TASK.pm)?.[1], '6');
    assert.doesNotMatch('The frame-data table (task 6)', SUBJECT_TASK.pm);
    assert.doesNotMatch('Swing sampler (task 7.3)', SUBJECT_TASK.pm);
  });

  it('launches lanes into its branch, which merges into master', () => {
    const goal = goalFor({ plan: PLAN_BY_KEY.pm, ids: ['6'], tasks: { 6: { title: 'Away, and questions answered' } },
      branch: 'lane/pm-6', repo: 'C:\\Repo' });
    assert.ok(goal.includes('tools/project-manager-remote (which merges into master)'));
    assert.ok(goal.includes('origin/tools/project-manager-remote'));
  });
});

// Milestone 1's plan, as the contract writes it.
const MILESTONE = `# Plan: Milestone 1

Spec: \`docs/specs/milestone-1.md\` · branch \`feature/milestone-1\` · pull request #31

## Build order

1. **Foundations:** 3, 7.
2. **Effects** (after the consolidation): 12, 13–14.

## Tasks

- [ ] **3. The frame-data table.** Generated from the clips.
  - Blocked by: \`docs/plans/godot-rebuild.md\` task 26.4 · Stories: 1
- [x] **7. The Blood setting.** On, Reduced or Off.
  - Blocked by: none
- [ ] **12. Title in sentence case.** One-sentence summary of what it delivers.
  - Delivers: the end-to-end behaviour, from the owner's or player's side.
  - Check: how it is verified (tests, sheets, soak, owner look).
  - Blocked by: 3, 7, \`docs/plans/godot-rebuild.md\` task 26.4 · Stories: 4, 5, 18
  - Replaces: \`docs/plans/godot-rebuild.md\` tasks 18.4, 18.5 and 18.6; \`docs/plans/authored-animation.md\` task 32
  - **Owner:** what the owner reviews or decides (only on owner-gate tasks).
- [ ] **13. Sparks and the ultimates.**
  - Blocked by: 12 (and the owner's OK), \`docs/plans/godot-rebuild.md\` tasks 18.8–18.10 and 22.7, \`docs/plans/animation-studio.md\` task 4
- [ ] **14. Tuning.**
  - Blocked by: 12
  - Replaces: \`docs/plans/godot-rebuild.md\` task 12.8
`;

describe('parseFlat on milestone 1', () => {
  const { tasks, stages, branch } = parseFlat(MILESTONE, M1);

  it('takes the branch from the plan header', () => {
    assert.equal(branch, 'feature/milestone-1');
    assert.equal(parseFlat('# Plan\n\n## Tasks\n', M1).branch, null);
  });

  it('reads local blockers and other plans\' tasks in the backticked file form', () => {
    assert.deepEqual(tasks.get('3').blockers, ['gr:26.4']);
    assert.deepEqual(tasks.get('7').blockers, []);
    assert.deepEqual(tasks.get('12').blockers, ['m1:3', 'm1:7', 'gr:26.4']);
  });

  it('expands lists and ranges of another plan\'s tasks, and ignores plans the board does not follow', () => {
    assert.deepEqual(tasks.get('13').blockers, ['m1:12', 'gr:18.8', 'gr:18.9', 'gr:18.10', 'gr:22.7']);
    assert.deepEqual(tasks.get('13').gatedBy, ['m1:12']);
  });

  it('reads the tasks a task replaces', () => {
    assert.deepEqual(tasks.get('12').replaces, ['gr:18.4', 'gr:18.5', 'gr:18.6', 'aa:32']);
    assert.deepEqual(tasks.get('14').replaces, ['gr:12.8']);
    assert.deepEqual(tasks.get('3').replaces, []);
  });

  it('makes owner tasks and gated blockers gates', () => {
    assert.equal(tasks.get('12').gate, true);
    assert.equal(tasks.get('3').gate, false);
  });

  it('tolerates a range in the build order', () => {
    assert.deepEqual(stages.map((s) => s.ids), [['3', '7'], ['12', '13', '14']]);
  });
});

describe('blockers in another plan', () => {
  const blockersOf = (parse, plan, id, line) => parse(`# P\n\n## Tasks\n- [ ] **${id}. T.** x\n  - Blocked by: ${line}\n`, plan).tasks.get(id).blockers;

  it('ends a list of another plan\'s tasks at its "and <id>", so local ids after it stay local', () => {
    assert.deepEqual(blockersOf(parseRoadmap, RM, 'R3', '`docs/plans/milestone-1.md` tasks 12 and 13, R2'), ['m1:12', 'm1:13', 'rm:R2']);
    assert.deepEqual(blockersOf(parseFlat, M1, '12', '`docs/plans/godot-rebuild.md` tasks 25.4 and 26.4, 3'), ['gr:25.4', 'gr:26.4', 'm1:3']);
    assert.deepEqual(blockersOf(parseFlat, M1, '12', '`docs/plans/godot-rebuild.md` tasks 25.4, 25.5, and 26.4; 3'), ['gr:25.4', 'gr:25.5', 'gr:26.4', 'm1:3']);
  });

  it('takes only ids shaped like the other plan\'s tasks', () => {
    assert.deepEqual(blockersOf(parseFlat, M1, '13', '`docs/plans/godot-rebuild.md` tasks 26.3, 26.4, 3 · Stories: 1'), ['gr:26.3', 'gr:26.4', 'm1:3']);
    assert.deepEqual(blockersOf(parseFlat, M1, '12', '`docs/plans/godot-rebuild.md` task 26.4, 3'), ['gr:26.4', 'm1:3']);
    assert.deepEqual(blockersOf(parseRoadmap, RM, 'R4', '`docs/plans/milestone-1.md` task 12, R2'), ['m1:12', 'rm:R2']);
    assert.deepEqual(blockersOf(parseFlat, M1, '14', '`docs/plans/roadmap.md` tasks R1 and R2, 3'), ['rm:R1', 'rm:R2', 'm1:3']);
  });
});

describe('moved tasks', () => {
  // Excerpts of the Oct 4 triage in docs/plans/godot-rebuild.md.
  const TRIAGED = `# Plan

## Tasks

- [ ] **12. Computer opponent.**
  - [-] ~~**12.6 The computer uses and answers Low Sweep and Skewer.**~~ Through the shared routes.
    - Check: seeded tests.
    - Blocked by: 12.3 · Stories: 5, 32, 33, 41
    - Moved to milestone 2 (Oct 4), with the Greatsword. Jump arcs stay a rules number.
  - [-] ~~**12.8 Tuning round 1: round length and disarms.**~~ 300-match runs.
    - Blocked by: 12.1, 12.4, 12.5, 12.6, 12.7 · Stories: 62
    - Superseded by ADR 0001 (Oct 4): moves into the slice plan.
    - Moved to milestone 1 (Oct 4). Becomes milestone 1's tuning of round length and disarms.
  - [-] ~~**12.9 Tuning round 2: weapon win rates; task 12 ticked.**~~ Per-weapon numbers.
    - Superseded by ADR 0001 (Oct 4): moves into the slice plan.
    - Moved (Oct 4). Becomes the per-weapon rebalance around each weapon's clips: the Katana in milestone 1.
- [ ] **18. Combat effects and game feel.**
  - [-] ~~**18.4 Sparks and ink splashes.**~~ Hits give warm sparks.
    - Blocked by: 18.1 · Stories: 19, 48
    - Superseded by ADR 0001 (Oct 4): moves into the slice plan as realistic effects.
    - Moved to milestone 1 (Oct 4). Becomes realistic sparks at the contact point.
  - [-] ~~**18.3 Retired effect.**~~
    - Retired on Oct 3.
  - [ ] **18.11 Reduce flashes and shaking.** A setting.
    - Blocked by: 18.5, \`docs/plans/milestone-1.md\` task 12 · Stories: 57
    - Replaces: \`docs/plans/authored-animation.md\` tasks 33 and 35
`;
  const { tasks } = parseNested(TRIAGED, GR);

  it('marks a retired task moved to milestone 1 or 2 in the nested plan', () => {
    assert.equal(tasks.get('12.6').moved, 'm2');
    assert.equal(tasks.get('12.8').moved, 'm1');
    assert.equal(tasks.get('18.4').moved, 'm1');
  });

  it('keeps a plain retirement, and a "Moved" note that names no milestone, retired', () => {
    assert.equal(tasks.get('12.9').moved, null);
    assert.equal(tasks.get('18.3').moved, null);
    assert.equal(tasks.get('18.11').moved, null);
  });

  it('reads other plans\' blockers and Replaces lines in the nested plan too', () => {
    assert.deepEqual(tasks.get('18.11').blockers, ['gr:18.5', 'm1:12']);
    assert.deepEqual(tasks.get('18.11').replaces, ['aa:33', 'aa:35']);
  });

  it('marks moved tasks in the flat plan, and reads lettered task ids', () => {
    const { tasks: aa } = parseFlat(`# Plan

## Tasks

- [x] **30b. The recall's power-up burst.** Added by the owner.
  - Blocked by: 30
- [-] ~~**32. The weapon draws.**~~ The Katana from its saya.
  - Blocked by: 31 (and the owner's OK) · Stories: 31
  - Superseded by ADR 0001 (Oct 4): moves into the slice spec.
  - Moved to milestone 1 (Oct 4): the Hunter draws the Katana from its saya.
- [-] ~~**34. Victory clips.**~~
  - Moved to milestone 2 (Oct 4), with the Greatsword and the Daggers.
- [-] ~~**36. The final review.**~~
  - Retired (Oct 4).
`, AA);
    assertMatches(aa.get('30b'), { mark: 'x', blockers: ['aa:30'], moved: null });
    assert.equal(aa.get('32').moved, 'm1');
    assert.equal(aa.get('34').moved, 'm2');
    assert.equal(aa.get('36').moved, null);
  });
});

// The roadmap, as the contract writes it.
const ROADMAP = `# Roadmap: from the consolidation to online play

Spec: \`docs/design.md\` (Order of work) and \`docs/specs/milestone-1.md\` · branch \`feature/godot-rebuild\`

## Destination

Online play.

## Notes

The short keys: gr, m1, aa.

## Phases

1. **Consolidation:** gr 25.4, gr 25.5, gr 26.1, R1, gr 26.4
2. **Milestone 1:** R2, m1 *, R3
3. **Master follow-ups** (alongside phase 2): gr 18.11, gr 23.4–23.7, xx 4, R9, gr ??, …
4. **Milestone 2:** R4

## Tasks

### Phase 1: Consolidation

- [ ] **R1. CI green on clones without the Kevin Iglesias clips.** Text.
  - Delivers: CI passes.
  - Check: a clean clone.
  - Blocked by: \`docs/plans/godot-rebuild.md\` task 26.3
- [x] **R2. Milestone 1's branch.**
  - Blocked by: R1, \`docs/plans/godot-rebuild.md\` task 26.4

### Phase 2: Milestone 1

- [ ] **R3. Milestone 1 sign-off.**
  - **Owner:** plays the build.
  - Blocked by: R2 (and the owner's OK), \`docs/plans/milestone-1.md\` tasks 12 and 14
- [ ] **R4. Milestone 2.**
  - Blocked by: R3
  - Replaces: \`docs/plans/godot-rebuild.md\` tasks 12.6 and 12.7; \`docs/plans/authored-animation.md\` task 34
`;

describe('parseRoadmap', () => {
  const { tasks, phases, stages, branch } = parseRoadmap(ROADMAP, RM);

  it('reads R tasks with their blockers, gates and replacements', () => {
    assert.deepEqual([...tasks.keys()], ['R1', 'R2', 'R3', 'R4']);
    assertMatches(tasks.get('R1'), { title: 'CI green on clones without the Kevin Iglesias clips', mark: ' ', blockers: ['gr:26.3'] });
    assertMatches(tasks.get('R2'), { mark: 'x', blockers: ['rm:R1', 'gr:26.4'] });
    assertMatches(tasks.get('R3'), { blockers: ['rm:R2', 'm1:12', 'm1:14'], gatedBy: ['rm:R2'], gate: true });
    assert.deepEqual(tasks.get('R4').replaces, ['gr:12.6', 'gr:12.7', 'aa:34']);
    assert.equal(branch, 'feature/godot-rebuild');
  });

  it('reads the phases, expanding ranges and flagging what it cannot read', () => {
    assert.deepEqual(phases, [
      { n: 1, name: 'Consolidation', alongside: null, refs: ['gr:25.4', 'gr:25.5', 'gr:26.1', 'rm:R1', 'gr:26.4'], bad: [] },
      { n: 2, name: 'Milestone 1', alongside: null, refs: ['rm:R2', 'm1:*', 'rm:R3'], bad: [] },
      { n: 3, name: 'Master follow-ups', alongside: 2, refs: ['gr:18.11', 'gr:23.4', 'gr:23.5', 'gr:23.6', 'gr:23.7', 'xx:4', 'rm:R9'], bad: ['gr ??'] },
      { n: 4, name: 'Milestone 2', alongside: null, refs: ['rm:R4'], bad: [] },
    ]);
  });

  it('reads "alongside phase N" anywhere in the bracketed note', () => {
    const text = '# R\n\n## Phases\n1. **A:** R1\n2. **B:** R2\n3. **Master follow-ups** (on master, alongside phase 2): gr 18.11\n'
      + '4. **C** (alongside phase 2, after the consolidation): R3\n5. **D** (not alongside anything): R4\n';
    assert.deepEqual(parseRoadmap(text, RM).phases.map((p) => p.alongside), [null, null, 2, 2, null]);
  });

  it('gives the phases with roadmap tasks as stages of its own tasks, so the other views work', () => {
    // Master follow-ups has only other plans' tasks: as a stage it would be empty, and read as finished.
    assert.deepEqual(stages, [
      { n: 1, name: 'Consolidation', ids: ['R1'] },
      { n: 2, name: 'Milestone 1', ids: ['R2', 'R3'] },
      { n: 4, name: 'Milestone 2', ids: ['R4'] },
    ]);
  });

  it('is the parser for the roadmap kind', () => {
    assert.equal(parsePlan(RM, ROADMAP).phases.length, 4);
  });
});

describe('linkMoved', () => {
  const plans = [
    { key: 'rm', tasks: new Map([['R4', { id: 'R4', replaces: ['gr:12.6', 'gr:18.4'] }]]) },
    { key: 'm1', tasks: new Map([['12', { id: '12', replaces: ['gr:18.4', 'aa:32'] }]]) },
    { key: 'gr', tasks: new Map([['18.4', { id: '18.4', moved: 'm1' }], ['12.6', { id: '12.6', moved: 'm2' }], ['18.5', { id: '18.5', moved: 'm1' }]]) },
    { key: 'aa', tasks: new Map([['32', { id: '32', moved: 'm1' }], ['36', { id: '36', moved: null }]]) },
  ];
  const links = linkMoved(plans);

  it('links each moved task to the task whose Replaces names it, preferring the milestone it moved to', () => {
    assert.equal(links.get('gr:18.4'), 'm1:12');
    assert.equal(links.get('gr:12.6'), 'rm:R4');
    assert.equal(links.get('aa:32'), 'm1:12');
  });

  it('leaves a moved task nobody replaces unlinked', () => {
    assert.equal(links.has('gr:18.5'), false);
    assert.equal(links.has('aa:36'), false);
  });
});

describe('planOfBranch', () => {
  const branches = { rm: 'feature/godot-rebuild', m1: 'feature/milestone-1', gr: 'feature/godot-rebuild', aa: 'feature/authored-animation' };

  it('reads a launched lane\'s plan and tasks from its branch, R ids too', () => {
    assert.deepEqual(planOfBranch('lane/rm-R3-R4', branches), { key: 'rm', scope: ['R3', 'R4'] });
    assert.deepEqual(planOfBranch('lane/m1-12-13', branches), { key: 'm1', scope: ['12', '13'] });
    assert.deepEqual(planOfBranch('lane/gr-22.15-23.1', branches), { key: 'gr', scope: ['22.15', '23.1'] });
    assert.equal(planOfBranch('lane/st-1', branches), null);
  });

  it('gives a plan\'s own branch to that plan, the rebuild before the roadmap that shares it', () => {
    assert.deepEqual(planOfBranch('feature/milestone-1', branches), { key: 'm1', scope: null });
    assert.deepEqual(planOfBranch('feature/godot-rebuild', branches), { key: 'gr', scope: null });
    assert.deepEqual(planOfBranch('godot/stage-3', branches), { key: 'gr', scope: null });
    assert.deepEqual(planOfBranch('lane/aa-29-30-31', branches), { key: 'aa', scope: ['29', '30', '31'] });
    assert.deepEqual(planOfBranch('feature/authored-animation-fixes', branches), { key: 'aa', scope: null });
  });

  it('follows a plan whose header moved it to another branch', () => {
    assert.deepEqual(planOfBranch('master', { ...branches, m1: 'master' }), { key: 'm1', scope: null });
  });

  it('claims nothing for other branches, like the docs branch that writes the plans', () => {
    assert.equal(planOfBranch('docs/milestone-1-spec', branches), null);
    assert.equal(planOfBranch('tools/lanes-board-roadmap', branches), null);
    assert.equal(planOfBranch('', branches), null);
  });
});

describe('roadmapView', () => {
  const phases = [
    { n: 1, name: 'Consolidation', alongside: null, refs: ['gr:25.4', 'rm:R1', 'gr:26.4', 'gr:18.4', 'gr:99.9', 'xx:1'], bad: ['gr ??'] },
    { n: 2, name: 'Milestone 1', alongside: null, refs: ['rm:R2', 'm1:*', 'rm:R3'], bad: [] },
    { n: 3, name: 'Master follow-ups', alongside: 2, refs: ['gr:18.11'], bad: [] },
    { n: 4, name: 'Milestone 2', alongside: null, refs: ['rm:R4'], bad: [] },
  ];
  const plan = (key, stages, tasks) => ({ key, stages, tasks: Object.fromEntries(Object.entries(tasks).map(([id, status]) => [id, { title: `T ${id}`, status }])) });
  const plansWith = (gr) => [
    plan('rm', [{ ids: ['R1', 'R2', 'R3', 'R4'] }], { R1: 'ready', R2: 'blocked', R3: 'blocked', R4: 'blocked' }),
    plan('gr', [{ ids: ['25.4', '26.4', '18.4', '18.11'] }], { '25.4': 'done', '26.4': 'blocked', '18.4': 'moved', '18.11': 'ready', ...gr }),
    plan('m1', [{ ids: ['3', '12', '5'] }, { n: null, ids: ['6', '9'] }], { 3: 'blocked', 12: 'working', 5: 'retired', 6: 'moved', 9: 'owner' }),
  ];
  const lanes = [
    { folder: 'lane-m1-12', branch: 'lane/m1-12', plan: 'm1', scope: ['12'], task: '12', working: true, ended: false },
    { folder: 'main', branch: 'feature/godot-rebuild', plan: 'gr', scope: null, task: '26.4', working: false, ended: false },
    { folder: 'old', branch: 'lane/rm-R1', plan: 'rm', scope: ['R1'], task: 'R1', working: false, ended: true },
  ];
  const view = roadmapView(phases, plansWith({}), lanes);

  it('resolves each phase\'s tasks, leaving out moved and retired ones and flagging unknown refs', () => {
    assert.deepEqual(view[0].refs, ['gr:25.4', 'rm:R1', 'gr:26.4']);
    assert.deepEqual(view[0].unknown, ['gr:99.9', 'xx:1', 'gr ??']);
    assert.deepEqual(view[1].refs, ['rm:R2', 'm1:3', 'm1:12', 'm1:9', 'rm:R3']);
  });

  it('counts each phase\'s tasks by status', () => {
    assertMatches(view[0], { total: 3, counts: { done: 1, open: 2, blocked: 1, ready: 1, working: 0, owner: 0, launched: 0 } });
    assertMatches(view[1], { total: 5, counts: { done: 0, open: 5, blocked: 3, ready: 0, working: 1, owner: 1 } });
  });

  it('lists up to five ready tasks next, with titles', () => {
    assert.deepEqual(view[0].next, [{ ref: 'rm:R1', title: 'T R1', status: 'ready' }]);
    assert.deepEqual(view[1].next, []);
  });

  it('names the live lanes working on a phase\'s tasks', () => {
    assert.deepEqual(view[1].lanes, [{ folder: 'lane-m1-12', branch: 'lane/m1-12', task: 'm1:12', working: true }]);
    assert.deepEqual(view[0].lanes, []);
  });

  it('makes the first phase with open tasks current, and an alongside phase current with its partner', () => {
    assert.deepEqual(view.map((p) => p.current), [true, false, false, false]);
    const later = roadmapView(phases, plansWith({ '26.4': 'done' }).map((p) => (p.key === 'rm' ? plan('rm', p.stages, { R1: 'done', R2: 'ready', R3: 'blocked', R4: 'blocked' }) : p)), lanes);
    assert.deepEqual(later.map((p) => p.current), [false, true, true, false]);
  });

  it('waits quietly on a followed plan that has no copy on any branch yet', () => {
    const early = roadmapView(phases, plansWith({}).filter((p) => p.key !== 'm1'), lanes);
    assert.deepEqual(early[1].refs, ['rm:R2', 'rm:R3']);
    assert.deepEqual(early[1].waiting, ['m1:*']);
    assert.deepEqual(early[1].unknown, []);
  });
});

describe('mergeCopies', () => {
  // The main branch's copy is newest (it ticked 25.2); the animation branch's is
  // older but re-pointed 18.2's blockers. Both changes must survive.
  const original = parseNested(REBUILD, GR);
  const repointed = parseNested(REBUILD.replace('    - Blocked by: 18.1\n', '    - Blocked by: `docs/plans/authored-animation.md` task 25\n'), GR);
  const ticked = parseNested(REBUILD.replace('- [ ] **25.2', '- [x] **25.2'), GR);
  const merged = mergeCopies([{ time: 1, p: original }, { time: 2, p: repointed }, { time: 3, p: ticked }]);

  it('takes each task from the newest copy that changed it', () => {
    assert.deepEqual(merged.tasks.get('18.2').blockers, ['aa:25']);
    assert.deepEqual(merged.tasks.get('18.1').blockers, ['aa:36', 'gr:25.2']);
  });

  it('counts a task done or retired when any copy says so', () => {
    assert.deepEqual([...merged.done].sort(), ['13.1', '25.2']);
    assert.deepEqual([...merged.retired], ['25.1']);
  });

  it('takes the stages from the newest copy', () => {
    assert.equal(merged.stages, ticked.stages);
  });

  // The triage moved 18.2 to milestone 1 on one branch; milestone 1's plan
  // gained a Replaces line on another.
  const moved = parseNested(REBUILD.replace('  - [ ] **18.2 Trail rules;** Text.\n    - Blocked by: 18.1\n',
    '  - [-] ~~**18.2 Trail rules;**~~ Text.\n    - Blocked by: 18.1\n    - Moved to milestone 1 (Oct 4).\n'), GR);
  const withMove = mergeCopies([{ time: 1, p: original }, { time: 3, p: moved }]);

  it('keeps a moved task out of the done and retired sets, and marks it moved', () => {
    assert.deepEqual(withMove.moved, new Map([['18.2', 'm1']]));
    assert.equal(withMove.tasks.get('18.2').moved, 'm1');
    assert.deepEqual([...withMove.retired], ['25.1']);
    assert.equal(withMove.done.has('18.2'), false);
    assert.equal(withMove.tasks.get('18.1').moved, null);
  });

  it('keeps the Replaces line from the copy that added it, and the header branch from the newest copy', () => {
    const plain = parseFlat(MILESTONE.replace(/ {2}- Replaces: .*task 12\.8\n/, ''), M1);
    const headed = parseFlat(MILESTONE.replace('branch `feature/milestone-1`', 'branch `master`'), M1);
    const m = mergeCopies([{ time: 1, p: plain }, { time: 2, p: parseFlat(MILESTONE, M1) }, { time: 3, p: headed }]);
    assert.deepEqual(m.tasks.get('14').replaces, ['gr:12.8']);
    assert.equal(m.branch, 'master');
  });

  it('keeps the roadmap\'s phases from the newest copy', () => {
    const p = parseRoadmap(ROADMAP, RM);
    assert.equal(mergeCopies([{ time: 1, p }]).phases, p.phases);
  });
});

describe('cancelStops', () => {
  it('cancels every stop left on the relaunched lane\'s branch, and only those', () => {
    const entries = [
      { id: 'a', branch: 'lane/gr-1.1' },
      { id: 'b', branch: 'lane/gr-1.1', firedAt: 5 },
      { id: 'c', branch: 'lane/gr-2.1' },
      { id: 'd', branch: 'lane/gr-1.1', cancelledAt: 1 },
    ];
    const { entries: out, cancelled } = cancelStops(entries, 'lane/gr-1.1', 99);
    assert.equal(cancelled, 2);
    assert.deepEqual(out.map((e) => e.cancelledAt ?? null), [99, 99, null, 1]);
  });
});

describe('goalFor', () => {
  const repo = 'C:\\Users\\me\\Monomachia';
  const tasks = { '22.15': { title: 'Pause menu' }, '23.1': { title: 'Training upkeep in the rules' } };
  const goal = goalFor({ plan: GR, ids: ['22.15', '23.1'], tasks, branch: 'lane/gr-22.15-23.1', repo });

  it('names the tasks, the repository and the plan branch, master since the Godot rebuild merged', () => {
    assert.ok(goal.includes('22.15 Pause menu; 23.1 Training upkeep in the rules'));
    assert.ok(goal.includes(`in the Monomachia repository at ${repo}`));
    assert.ok(goal.includes('with every change built on and merged into master.'));
  });

  it('keeps the work on a lane branch with a pull request into the plan branch', () => {
    assert.ok(goal.includes('pushed on lane/gr-22.15-23.1, with a pull request into master.'));
    assert.ok(!goal.includes('never master'));
    assert.ok(goal.includes('git switch -c lane/gr-22.15-23.1 origin/master'));
  });

  it('brings a session that opened elsewhere into a worktree of the repository', () => {
    assert.ok(goal.includes('never in a scratch or other folder'));
    assert.ok(goal.includes(`worktree add "${repo}\\.claude\\worktrees\\lane-gr-22-15-23-1" -b lane/gr-22.15-23.1 origin/master`));
  });

  it('asks wayfinder\'s questions before implementing', () => {
    assert.match(goal, /wayfinder for questions only.*AskUserQuestion.*Then implement/);
  });

  it('builds milestone 1 and roadmap lanes on master, with their pull requests into master', () => {
    const m1 = goalFor({ plan: M1, ids: ['12'], tasks: { 12: { title: 'Sparks' } }, branch: 'lane/m1-12', repo });
    assert.ok(m1.includes('12 Sparks (docs/plans/milestone-1.md)'));
    assert.ok(m1.includes('pushed on lane/m1-12, with a pull request into master.'));
    assert.ok(m1.includes('git switch -c lane/m1-12 origin/master'));
    assert.ok(!m1.includes('never master'));
    assert.ok(!m1.includes('which merges into'));
    const rm = goalFor({ plan: RM, ids: ['R3'], tasks: { R3: { title: 'Sign-off' } }, branch: 'lane/rm-R3', repo });
    assert.ok(rm.includes('with a pull request into master.'));
    assert.ok(rm.includes('git switch -c lane/rm-R3 origin/master'));
  });

  it('follows a branch named in the plan header, keeping a feature branch\'s lanes off master', () => {
    const goal = goalFor({ plan: { ...M1, branch: 'feature/x' }, ids: ['12'], tasks: { 12: { title: 'Sparks' } }, branch: 'lane/m1-12', repo });
    assert.ok(goal.includes('with a pull request into feature/x, never master'));
    assert.ok(goal.includes('git switch -c lane/m1-12 origin/feature/x'));
  });

  it('tells the session to stop and tell the owner when the plan\'s branch is not on origin yet', () => {
    const plan = { ...M1, branch: 'feature/milestone-1' };
    const goal = goalFor({ plan, ids: ['12'], tasks: { 12: { title: 'Sparks' } }, branch: 'lane/m1-12', repo, baseExists: false });
    assert.ok(goal.includes('origin/feature/milestone-1 does not exist yet'));
    assert.match(goal, /stop and tell me.*do not create it or build on another branch/);
    assert.ok(goal.includes('or, if origin/feature/milestone-1 is still missing, when you have told me so and stopped'));
    assert.ok(!goalFor({ plan, ids: ['12'], tasks: { 12: { title: 'Sparks' } }, branch: 'lane/m1-12', repo }).includes('does not exist yet'));
  });

  it('is plain words, since the app turns a link\'s leading slash into a full-width one and never runs it as a command', () => {
    assert.doesNotMatch(goal, /^\s*[/／]/);
    assert.ok(!goal.includes('/goal'));
  });

  it('keeps going from task to task without waiting for an OK, except for questions and owner gates', () => {
    assert.ok(goal.includes('Go on from one task to the next without waiting for my OK; stop only for a question that needs my answer, at an owner gate, or when every queued task is done.'));
  });

  it('has the session title itself with the task range, then with the plan and pull request once there is one', () => {
    assert.ok(goal.includes('set this session\'s title to "Tasks 22.15, 23.1" with the set_session_title tool (session_id "self"; find it with ToolSearch)'));
    assert.ok(goal.includes('set it to "GR PR #<number> Tasks 22.15, 23.1"'));
    const tasks4 = { 1: { title: 'a' }, 2: { title: 'b' }, 3: { title: 'c' }, 4: { title: 'd' } };
    const m1 = goalFor({ plan: M1, ids: ['1', '2', '3', '4'], tasks: tasks4, branch: 'lane/m1-1-2-3-4', repo });
    assert.ok(m1.includes('"Tasks 1-4"'));
    assert.ok(m1.includes('"M1 PR #<number> Tasks 1-4"'));
  });

  it('stays within the launch prompt\'s limit by shortening the titles', () => {
    const many = Object.fromEntries(Array.from({ length: 40 }, (_, i) => [`18.${i}`, { title: 'x'.repeat(200) }]));
    const long = goalFor({ plan: GR, ids: Object.keys(many), tasks: many, branch: 'lane/gr-many', repo });
    assert.ok(long.length <= GOAL_LIMIT);
    assert.ok(long.includes('18.39'));
  });
});

describe('taskRange', () => {
  it('joins runs of consecutive tasks with a hyphen', () => {
    assert.equal(taskRange(['1', '2', '3', '4']), 'Tasks 1-4');
    assert.equal(taskRange(['4', '5', '6', '13']), 'Tasks 4-6, 13');
    assert.equal(taskRange(['8.4', '8.5', '8.6', '9.1']), 'Tasks 8.4-8.6, 9.1');
    assert.equal(taskRange(['R3', 'R4']), 'Tasks R3-R4');
  });

  it('keeps tasks apart that are not one after another', () => {
    assert.equal(taskRange(['22.15', '23.1']), 'Tasks 22.15, 23.1');
    assert.equal(taskRange(['29', '30', '30b', '31']), 'Tasks 29-30, 30b, 31');
    assert.equal(taskRange(['1', '3']), 'Tasks 1, 3');
  });

  it('says Task for one', () => {
    assert.equal(taskRange(['12']), 'Task 12');
  });
});

describe('sessionTitle', () => {
  it('is the task range until the lane has a pull request', () => {
    assert.equal(sessionTitle({ plan: M1, ids: ['1', '2', '3', '4'] }), 'Tasks 1-4');
  });

  it('names the plan, the pull request and the task range once it has one', () => {
    assert.equal(sessionTitle({ plan: M1, ids: ['1', '2', '3', '4'], pr: 46 }), 'M1 PR #46 Tasks 1-4');
    assert.equal(sessionTitle({ plan: GR, ids: ['22.15', '23.1'], pr: '<number>' }), 'GR PR #<number> Tasks 22.15, 23.1');
  });
});

describe('stop hook', () => {
  const HOOK = fileURLToPath(new URL('../tools/lanes-board/stop-hook.mjs', import.meta.url));
  const dir = mkdtempSync(path.join(os.tmpdir(), 'lanes-stop-'));
  const file = path.join(dir, 'lanes-stop.json');
  const worktree = path.join(dir, 'worktrees', 'lane-gr-1');
  const run = (input) => execFileSync(process.execPath, [HOOK], {
    input: JSON.stringify(input), env: { ...process.env, LANES_STOP_FILE: file, LANES_RELAY: path.join(dir, 'relay') },
  }).toString();
  const stopList = (entry) => writeFileSync(file, JSON.stringify({ entries: [{
    id: 't', label: 'GR 1.1', worktree, sessions: ['listed'], requestedAt: Date.now(), firedAt: null, ...entry,
  }] }));

  afterEach(() => rmSync(file, { force: true }));

  it('does nothing without a stop list, or for a session it does not name', () => {
    assert.equal(run({ session_id: 'listed', cwd: worktree, hook_event_name: 'PreToolUse' }), '');
    stopList();
    assert.equal(run({ session_id: 'other', cwd: dir, hook_event_name: 'PreToolUse' }), '');
    assert.equal(run({ session_id: 'other', cwd: `${worktree}-2`, hook_event_name: 'PreToolUse' }), '');
  });

  it('stops a listed session before its next tool, wherever it runs', () => {
    stopList();
    const out = JSON.parse(run({ session_id: 'listed', cwd: os.tmpdir(), hook_event_name: 'PreToolUse' }));
    assert.equal(out.continue, false);
    assert.equal(out.hookSpecificOutput.permissionDecision, 'deny');
    assert.ok(out.stopReason.includes('GR 1.1'));
    assert.equal(JSON.parse(readFileSync(file, 'utf8')).entries[0].firedBy, 'listed');
  });

  it('stops any session working inside the lane\'s worktree when its turn ends', () => {
    stopList();
    const out = JSON.parse(run({ session_id: 'other', cwd: path.join(worktree, 'game'), hook_event_name: 'Stop' }));
    assert.equal(out.continue, false);
    assert.equal(out.hookSpecificOutput, undefined);
  });

  it('lets the session go on two minutes after it first stopped it', () => {
    stopList({ firedAt: Date.now() - 3 * 60 * 1000 });
    assert.equal(run({ session_id: 'listed', cwd: worktree, hook_event_name: 'PreToolUse' }), '');
  });

  // A relaunch of the same tasks reuses the lane's branch and worktree. Its new
  // session (a transcript written after the lane was ended) must not inherit the
  // old stop; the sessions running when it was ended still stop.
  const transcript = (name, ageMs) => {
    const f = path.join(dir, `${name}.jsonl`);
    writeFileSync(f, '{}\n');
    return { f, before: Date.now() - ageMs };
  };

  it('leaves a new session in the lane\'s worktree alone after the lane was ended', () => {
    const { f } = transcript('new-session', 0);
    stopList({ requestedAt: Date.now() - 60 * 1000 });
    assert.equal(run({ session_id: 'new', transcript_path: f, cwd: worktree, hook_event_name: 'PreToolUse' }), '');
    assert.equal(JSON.parse(readFileSync(file, 'utf8')).entries[0].firedAt, null);
  });

  it('still stops a session in the worktree that was running when the lane was ended', () => {
    const { f } = transcript('old-session', 0);
    stopList({ requestedAt: Date.now() + 60 * 1000 });
    const out = JSON.parse(run({ session_id: 'old', transcript_path: f, cwd: worktree, hook_event_name: 'PreToolUse' }));
    assert.equal(out.continue, false);
  });

  it('ignores a stop the board cancelled by launching the lane again', () => {
    stopList({ cancelledAt: Date.now() });
    assert.equal(run({ session_id: 'listed', cwd: worktree, hook_event_name: 'PreToolUse' }), '');
  });

  it('never blocks on a broken stop list', () => {
    writeFileSync(file, '{not json');
    assert.equal(run({ session_id: 'listed', cwd: worktree, hook_event_name: 'PreToolUse' }), '');
  });
});

describe('findBatches', () => {
  // tasks: id -> [status, blockers ('id' local, or 'gr:1.1'; a trailing '*' means done), ownerOk?]
  const plan = (order, tasks, key = 'm1') => ({
    key, stages: [{ n: 1, name: 'All', ids: order }],
    tasks: Object.fromEntries(Object.entries(tasks).map(([id, [status, blockers = [], ownerOk = []]]) => [id, {
      title: `T ${id}`, status, ownerOk,
      blockers: blockers.map((b) => ({ ref: b.replace('*', '').includes(':') ? b.replace('*', '') : `${key}:${b.replace('*', '')}`, done: b.endsWith('*') })),
    }])),
  });

  it('chains a ready task with the tasks that wait only on it, in order', () => {
    const p = plan(['1', '2', '3', '4'], { 1: ['done'], 2: ['ready', ['1*']], 3: ['blocked', ['2']], 4: ['blocked', ['3', '1*']] });
    assert.deepEqual(findBatches(p), [['2', '3', '4']]);
  });

  it('leaves a ready task with nothing to chain out', () => {
    const p = plan(['1', '2'], { 1: ['ready'], 2: ['blocked', ['gr:9.9']] });
    assert.deepEqual(findBatches(p), []);
  });

  it('stops before a task that also waits on unfinished work outside the batch', () => {
    const p = plan(['1', '2', '3', '4'], { 1: ['ready'], 2: ['blocked', ['1']], 3: ['working'], 4: ['blocked', ['2', '3']] });
    assert.deepEqual(findBatches(p), [['1', '2']]);
  });

  it('stops before a task that waits on the owner\'s OK of a task in the batch', () => {
    const p = plan(['1', '2', '3'], { 1: ['ready'], 2: ['blocked', ['1']], 3: ['blocked', ['2'], ['2']] });
    assert.deepEqual(findBatches(p), [['1', '2']]);
  });

  it('is a chain: each task uses the one before, and tasks that only share an earlier one fan out', () => {
    const p = plan(['1', '2', '3', '4'], { 1: ['ready'], 2: ['blocked', ['1']], 3: ['blocked', ['1']], 4: ['blocked', ['2']] });
    assert.deepEqual(findBatches(p), [['1', '2', '4']]);
  });

  it('gives each task to one batch, so batches can run side by side', () => {
    const p = plan(['1', '2', '3', '4', '5'], { 1: ['ready'], 2: ['ready'], 3: ['blocked', ['1']], 4: ['blocked', ['2']], 5: ['blocked', ['1', '2']] });
    assert.deepEqual(findBatches(p), [['1', '3'], ['2', '4']]);
  });

  it('never starts on or takes a task already started or launched', () => {
    const p = plan(['1', '2', '3', '4'], { 1: ['working'], 2: ['blocked', ['1']], 3: ['launched'], 4: ['blocked', ['3']] });
    assert.deepEqual(findBatches(p), []);
  });

  it('starts on a task waiting only on the owner\'s OK, since launching it gives the OK', () => {
    const p = plan(['9', '1', '2'], { 9: ['done'], 1: ['owner', ['9*'], ['9']], 2: ['blocked', ['1']] });
    assert.deepEqual(findBatches(p), [['1', '2']]);
  });

  it('takes a task gated on the owner\'s OK of a task done before the batch', () => {
    const p = plan(['9', '1', '2'], { 9: ['done'], 1: ['ready'], 2: ['blocked', ['1', '9*'], ['9']] });
    assert.deepEqual(findBatches(p), [['1', '2']]);
  });

  it('stops before a review gate or other owner task, which a session can\'t do', () => {
    const p = plan(['1', '2', '3', '4'], { 1: ['ready'], 2: ['blocked', ['1']], 3: ['blocked', ['2']], 4: ['blocked', ['2']] });
    p.tasks[3].gate = true;
    assert.deepEqual(findBatches(p), [['1', '2', '4']]);
  });

  it('reads tasks outside the build order too', () => {
    const p = plan(['1'], { 1: ['ready'], 2: ['blocked', ['1']] });
    p.stages.push({ n: null, name: 'Not in the build order', ids: ['2'] });
    assert.deepEqual(findBatches(p), [['1', '2']]);
  });
});
