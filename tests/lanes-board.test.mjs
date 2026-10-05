// Tests for tools/lanes-board: how the board reads the plans (plans.mjs), the
// roadmap's phases, the goal a launched session starts with, and the stop hook
// that ends a lane's work.

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, describe, expect, it } from 'vitest';
import {
  GOAL_LIMIT, PLANS, PLAN_BY_KEY, cancelStops, expandIds, goalFor, linkMoved, mergeCopies, parseFlat, parseNested,
  SUBJECT_TASK, parsePlan, parseRoadmap, planOfBranch, roadmapView,
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
    expect(expandIds('13.1, 8.4–8.6, 14b.1-14b.2')).toEqual(['13.1', '8.4', '8.5', '8.6', '14b.1', '14b.2']);
  });
});

describe('parseNested', () => {
  const { tasks, stages } = parseNested(REBUILD, GR);

  it('reads ticks, open tasks and retired ones, but not the parent heading', () => {
    expect([...tasks.keys()]).toEqual(['13.1', '25.1', '25.2', '18.1', '18.2']);
    expect(tasks.get('13.1').mark).toBe('x');
    expect(tasks.get('25.1').mark).toBe('-');
    expect(tasks.get('25.2').mark).toBe(' ');
    expect(tasks.get('18.2').title).toBe('Trail rules');
  });

  it('reads blockers, dropping notes in brackets and naming other plans', () => {
    expect(tasks.get('13.1').blockers).toEqual([]);
    expect(tasks.get('25.2').blockers).toEqual(['gr:13.1', 'gr:25.1']);
    expect(tasks.get('18.1').blockers).toEqual(['aa:36', 'gr:25.2']);
  });

  it('reads the build order, with the plan\'s short stage names', () => {
    expect(stages).toEqual([
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
    expect(tasks.get('9').mark).toBe('x');
    expect(tasks.get('9').blockers).toEqual(['aa:5', 'aa:7']);
    expect(tasks.get('18').blockers).toEqual(['aa:14', 'aa:15']);
    expect(tasks.get('18').gatedBy).toEqual(['aa:14']);
    expect(tasks.get('14').gate).toBe(true);
    expect(tasks.get('9').gate).toBe(false);
  });

  it('reads the build order past a note in brackets', () => {
    expect(stages.map((s) => s.ids)).toEqual([['9', '14'], ['18']]);
  });
});

describe('PLANS', () => {
  it('follows the roadmap, milestone 1, the Godot rebuild, authored animation (closed) and the Project Manager\'s remote control, not the session tracker', () => {
    expect(PLANS.map((p) => [p.key, p.kind, p.branch, !!p.closed])).toEqual([
      ['rm', 'roadmap', 'feature/godot-rebuild', false],
      ['m1', 'flat', 'feature/milestone-1', false],
      ['gr', 'nested', 'feature/godot-rebuild', false],
      ['aa', 'flat', 'feature/authored-animation', true],
      ['pm', 'flat', 'tools/project-manager-remote', false],
    ]);
    expect(RM.file).toBe('docs/plans/roadmap.md');
    expect(M1.file).toBe('docs/plans/milestone-1.md');
    expect(PLAN_BY_KEY.pm.file).toBe('docs/plans/project-manager-remote.md');
    expect(PLAN_BY_KEY.pm.into).toBe('feature/godot-rebuild');
  });
});

describe('the Project Manager plan (PM)', () => {
  const branches = Object.fromEntries(PLANS.map((p) => [p.key, p.branch]));

  it('is claimed by its own branch and by launched pm lanes', () => {
    expect(planOfBranch('tools/project-manager-remote', branches)).toEqual({ key: 'pm', scope: null });
    expect(planOfBranch('lane/pm-6-7', branches)).toEqual({ key: 'pm', scope: ['6', '7'] });
  });

  it('names its tasks in commit subjects as "(PM task N)" only', () => {
    expect('Hold questions while Away is on (PM task 6)'.match(SUBJECT_TASK.pm)?.[1]).toBe('6');
    expect('The frame-data table (task 6)').not.toMatch(SUBJECT_TASK.pm);
    expect('Swing sampler (task 7.3)').not.toMatch(SUBJECT_TASK.pm);
  });

  it('launches lanes into its branch, which merges into the Godot rebuild branch', () => {
    const goal = goalFor({ plan: PLAN_BY_KEY.pm, ids: ['6'], tasks: { 6: { title: 'Away, and questions answered' } },
      branch: 'lane/pm-6', repo: 'C:\\Repo' });
    expect(goal).toContain('tools/project-manager-remote (which merges into feature/godot-rebuild)');
    expect(goal).toContain('origin/tools/project-manager-remote');
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
    expect(branch).toBe('feature/milestone-1');
    expect(parseFlat('# Plan\n\n## Tasks\n', M1).branch).toBeNull();
  });

  it('reads local blockers and other plans\' tasks in the backticked file form', () => {
    expect(tasks.get('3').blockers).toEqual(['gr:26.4']);
    expect(tasks.get('7').blockers).toEqual([]);
    expect(tasks.get('12').blockers).toEqual(['m1:3', 'm1:7', 'gr:26.4']);
  });

  it('expands lists and ranges of another plan\'s tasks, and ignores plans the board does not follow', () => {
    expect(tasks.get('13').blockers).toEqual(['m1:12', 'gr:18.8', 'gr:18.9', 'gr:18.10', 'gr:22.7']);
    expect(tasks.get('13').gatedBy).toEqual(['m1:12']);
  });

  it('reads the tasks a task replaces', () => {
    expect(tasks.get('12').replaces).toEqual(['gr:18.4', 'gr:18.5', 'gr:18.6', 'aa:32']);
    expect(tasks.get('14').replaces).toEqual(['gr:12.8']);
    expect(tasks.get('3').replaces).toEqual([]);
  });

  it('makes owner tasks and gated blockers gates', () => {
    expect(tasks.get('12').gate).toBe(true);
    expect(tasks.get('3').gate).toBe(false);
  });

  it('tolerates a range in the build order', () => {
    expect(stages.map((s) => s.ids)).toEqual([['3', '7'], ['12', '13', '14']]);
  });
});

describe('blockers in another plan', () => {
  const blockersOf = (parse, plan, id, line) => parse(`# P\n\n## Tasks\n- [ ] **${id}. T.** x\n  - Blocked by: ${line}\n`, plan).tasks.get(id).blockers;

  it('ends a list of another plan\'s tasks at its "and <id>", so local ids after it stay local', () => {
    expect(blockersOf(parseRoadmap, RM, 'R3', '`docs/plans/milestone-1.md` tasks 12 and 13, R2')).toEqual(['m1:12', 'm1:13', 'rm:R2']);
    expect(blockersOf(parseFlat, M1, '12', '`docs/plans/godot-rebuild.md` tasks 25.4 and 26.4, 3')).toEqual(['gr:25.4', 'gr:26.4', 'm1:3']);
    expect(blockersOf(parseFlat, M1, '12', '`docs/plans/godot-rebuild.md` tasks 25.4, 25.5, and 26.4; 3')).toEqual(['gr:25.4', 'gr:25.5', 'gr:26.4', 'm1:3']);
  });

  it('takes only ids shaped like the other plan\'s tasks', () => {
    expect(blockersOf(parseFlat, M1, '13', '`docs/plans/godot-rebuild.md` tasks 26.3, 26.4, 3 · Stories: 1')).toEqual(['gr:26.3', 'gr:26.4', 'm1:3']);
    expect(blockersOf(parseFlat, M1, '12', '`docs/plans/godot-rebuild.md` task 26.4, 3')).toEqual(['gr:26.4', 'm1:3']);
    expect(blockersOf(parseRoadmap, RM, 'R4', '`docs/plans/milestone-1.md` task 12, R2')).toEqual(['m1:12', 'rm:R2']);
    expect(blockersOf(parseFlat, M1, '14', '`docs/plans/roadmap.md` tasks R1 and R2, 3')).toEqual(['rm:R1', 'rm:R2', 'm1:3']);
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
    expect(tasks.get('12.6').moved).toBe('m2');
    expect(tasks.get('12.8').moved).toBe('m1');
    expect(tasks.get('18.4').moved).toBe('m1');
  });

  it('keeps a plain retirement, and a "Moved" note that names no milestone, retired', () => {
    expect(tasks.get('12.9').moved).toBeNull();
    expect(tasks.get('18.3').moved).toBeNull();
    expect(tasks.get('18.11').moved).toBeNull();
  });

  it('reads other plans\' blockers and Replaces lines in the nested plan too', () => {
    expect(tasks.get('18.11').blockers).toEqual(['gr:18.5', 'm1:12']);
    expect(tasks.get('18.11').replaces).toEqual(['aa:33', 'aa:35']);
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
    expect(aa.get('30b')).toMatchObject({ mark: 'x', blockers: ['aa:30'], moved: null });
    expect(aa.get('32').moved).toBe('m1');
    expect(aa.get('34').moved).toBe('m2');
    expect(aa.get('36').moved).toBeNull();
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
    expect([...tasks.keys()]).toEqual(['R1', 'R2', 'R3', 'R4']);
    expect(tasks.get('R1')).toMatchObject({ title: 'CI green on clones without the Kevin Iglesias clips', mark: ' ', blockers: ['gr:26.3'] });
    expect(tasks.get('R2')).toMatchObject({ mark: 'x', blockers: ['rm:R1', 'gr:26.4'] });
    expect(tasks.get('R3')).toMatchObject({ blockers: ['rm:R2', 'm1:12', 'm1:14'], gatedBy: ['rm:R2'], gate: true });
    expect(tasks.get('R4').replaces).toEqual(['gr:12.6', 'gr:12.7', 'aa:34']);
    expect(branch).toBe('feature/godot-rebuild');
  });

  it('reads the phases, expanding ranges and flagging what it cannot read', () => {
    expect(phases).toEqual([
      { n: 1, name: 'Consolidation', alongside: null, refs: ['gr:25.4', 'gr:25.5', 'gr:26.1', 'rm:R1', 'gr:26.4'], bad: [] },
      { n: 2, name: 'Milestone 1', alongside: null, refs: ['rm:R2', 'm1:*', 'rm:R3'], bad: [] },
      { n: 3, name: 'Master follow-ups', alongside: 2, refs: ['gr:18.11', 'gr:23.4', 'gr:23.5', 'gr:23.6', 'gr:23.7', 'xx:4', 'rm:R9'], bad: ['gr ??'] },
      { n: 4, name: 'Milestone 2', alongside: null, refs: ['rm:R4'], bad: [] },
    ]);
  });

  it('reads "alongside phase N" anywhere in the bracketed note', () => {
    const text = '# R\n\n## Phases\n1. **A:** R1\n2. **B:** R2\n3. **Master follow-ups** (on master, alongside phase 2): gr 18.11\n'
      + '4. **C** (alongside phase 2, after the consolidation): R3\n5. **D** (not alongside anything): R4\n';
    expect(parseRoadmap(text, RM).phases.map((p) => p.alongside)).toEqual([null, null, 2, 2, null]);
  });

  it('gives the phases with roadmap tasks as stages of its own tasks, so the other views work', () => {
    // Master follow-ups has only other plans' tasks: as a stage it would be empty, and read as finished.
    expect(stages).toEqual([
      { n: 1, name: 'Consolidation', ids: ['R1'] },
      { n: 2, name: 'Milestone 1', ids: ['R2', 'R3'] },
      { n: 4, name: 'Milestone 2', ids: ['R4'] },
    ]);
  });

  it('is the parser for the roadmap kind', () => {
    expect(parsePlan(RM, ROADMAP).phases).toHaveLength(4);
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
    expect(links.get('gr:18.4')).toBe('m1:12');
    expect(links.get('gr:12.6')).toBe('rm:R4');
    expect(links.get('aa:32')).toBe('m1:12');
  });

  it('leaves a moved task nobody replaces unlinked', () => {
    expect(links.has('gr:18.5')).toBe(false);
    expect(links.has('aa:36')).toBe(false);
  });
});

describe('planOfBranch', () => {
  const branches = { rm: 'feature/godot-rebuild', m1: 'feature/milestone-1', gr: 'feature/godot-rebuild', aa: 'feature/authored-animation' };

  it('reads a launched lane\'s plan and tasks from its branch, R ids too', () => {
    expect(planOfBranch('lane/rm-R3-R4', branches)).toEqual({ key: 'rm', scope: ['R3', 'R4'] });
    expect(planOfBranch('lane/m1-12-13', branches)).toEqual({ key: 'm1', scope: ['12', '13'] });
    expect(planOfBranch('lane/gr-22.15-23.1', branches)).toEqual({ key: 'gr', scope: ['22.15', '23.1'] });
    expect(planOfBranch('lane/st-1', branches)).toBeNull();
  });

  it('gives a plan\'s own branch to that plan, the rebuild before the roadmap that shares it', () => {
    expect(planOfBranch('feature/milestone-1', branches)).toEqual({ key: 'm1', scope: null });
    expect(planOfBranch('feature/godot-rebuild', branches)).toEqual({ key: 'gr', scope: null });
    expect(planOfBranch('godot/stage-3', branches)).toEqual({ key: 'gr', scope: null });
    expect(planOfBranch('lane/aa-29-30-31', branches)).toEqual({ key: 'aa', scope: ['29', '30', '31'] });
    expect(planOfBranch('feature/authored-animation-fixes', branches)).toEqual({ key: 'aa', scope: null });
  });

  it('follows a plan whose header moved it to another branch', () => {
    expect(planOfBranch('master', { ...branches, m1: 'master' })).toEqual({ key: 'm1', scope: null });
  });

  it('claims nothing for other branches, like the docs branch that writes the plans', () => {
    expect(planOfBranch('docs/milestone-1-spec', branches)).toBeNull();
    expect(planOfBranch('tools/lanes-board-roadmap', branches)).toBeNull();
    expect(planOfBranch('', branches)).toBeNull();
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
    expect(view[0].refs).toEqual(['gr:25.4', 'rm:R1', 'gr:26.4']);
    expect(view[0].unknown).toEqual(['gr:99.9', 'xx:1', 'gr ??']);
    expect(view[1].refs).toEqual(['rm:R2', 'm1:3', 'm1:12', 'm1:9', 'rm:R3']);
  });

  it('counts each phase\'s tasks by status', () => {
    expect(view[0]).toMatchObject({ total: 3, counts: { done: 1, open: 2, blocked: 1, ready: 1, working: 0, owner: 0, launched: 0 } });
    expect(view[1]).toMatchObject({ total: 5, counts: { done: 0, open: 5, blocked: 3, ready: 0, working: 1, owner: 1 } });
  });

  it('lists up to five ready tasks next, with titles', () => {
    expect(view[0].next).toEqual([{ ref: 'rm:R1', title: 'T R1', status: 'ready' }]);
    expect(view[1].next).toEqual([]);
  });

  it('names the live lanes working on a phase\'s tasks', () => {
    expect(view[1].lanes).toEqual([{ folder: 'lane-m1-12', branch: 'lane/m1-12', task: 'm1:12', working: true }]);
    expect(view[0].lanes).toEqual([]);
  });

  it('makes the first phase with open tasks current, and an alongside phase current with its partner', () => {
    expect(view.map((p) => p.current)).toEqual([true, false, false, false]);
    const later = roadmapView(phases, plansWith({ '26.4': 'done' }).map((p) => (p.key === 'rm' ? plan('rm', p.stages, { R1: 'done', R2: 'ready', R3: 'blocked', R4: 'blocked' }) : p)), lanes);
    expect(later.map((p) => p.current)).toEqual([false, true, true, false]);
  });

  it('waits quietly on a followed plan that has no copy on any branch yet', () => {
    const early = roadmapView(phases, plansWith({}).filter((p) => p.key !== 'm1'), lanes);
    expect(early[1].refs).toEqual(['rm:R2', 'rm:R3']);
    expect(early[1].waiting).toEqual(['m1:*']);
    expect(early[1].unknown).toEqual([]);
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
    expect(merged.tasks.get('18.2').blockers).toEqual(['aa:25']);
    expect(merged.tasks.get('18.1').blockers).toEqual(['aa:36', 'gr:25.2']);
  });

  it('counts a task done or retired when any copy says so', () => {
    expect([...merged.done].sort()).toEqual(['13.1', '25.2']);
    expect([...merged.retired]).toEqual(['25.1']);
  });

  it('takes the stages from the newest copy', () => {
    expect(merged.stages).toBe(ticked.stages);
  });

  // The triage moved 18.2 to milestone 1 on one branch; milestone 1's plan
  // gained a Replaces line on another.
  const moved = parseNested(REBUILD.replace('  - [ ] **18.2 Trail rules;** Text.\n    - Blocked by: 18.1\n',
    '  - [-] ~~**18.2 Trail rules;**~~ Text.\n    - Blocked by: 18.1\n    - Moved to milestone 1 (Oct 4).\n'), GR);
  const withMove = mergeCopies([{ time: 1, p: original }, { time: 3, p: moved }]);

  it('keeps a moved task out of the done and retired sets, and marks it moved', () => {
    expect(withMove.moved).toEqual(new Map([['18.2', 'm1']]));
    expect(withMove.tasks.get('18.2').moved).toBe('m1');
    expect([...withMove.retired]).toEqual(['25.1']);
    expect(withMove.done.has('18.2')).toBe(false);
    expect(withMove.tasks.get('18.1').moved).toBeNull();
  });

  it('keeps the Replaces line from the copy that added it, and the header branch from the newest copy', () => {
    const plain = parseFlat(MILESTONE.replace(/ {2}- Replaces: .*task 12\.8\n/, ''), M1);
    const headed = parseFlat(MILESTONE.replace('branch `feature/milestone-1`', 'branch `master`'), M1);
    const m = mergeCopies([{ time: 1, p: plain }, { time: 2, p: parseFlat(MILESTONE, M1) }, { time: 3, p: headed }]);
    expect(m.tasks.get('14').replaces).toEqual(['gr:12.8']);
    expect(m.branch).toBe('master');
  });

  it('keeps the roadmap\'s phases from the newest copy', () => {
    const p = parseRoadmap(ROADMAP, RM);
    expect(mergeCopies([{ time: 1, p }]).phases).toBe(p.phases);
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
    expect(cancelled).toBe(2);
    expect(out.map((e) => e.cancelledAt ?? null)).toEqual([99, 99, null, 1]);
  });
});

describe('goalFor', () => {
  const repo = 'C:\\Users\\me\\Monomachia';
  const tasks = { '22.15': { title: 'Pause menu' }, '23.1': { title: 'Training upkeep in the rules' } };
  const goal = goalFor({ plan: GR, ids: ['22.15', '23.1'], tasks, branch: 'lane/gr-22.15-23.1', repo });

  it('names the tasks, the repository and the Godot rebuild branch', () => {
    expect(goal).toContain('22.15 Pause menu; 23.1 Training upkeep in the rules');
    expect(goal).toContain(`in the Monomachia repository at ${repo}`);
    expect(goal).toContain('the Godot rebuild branch, feature/godot-rebuild');
  });

  it('keeps the work on a lane branch with a pull request into the plan branch, never master', () => {
    expect(goal).toContain('pushed on lane/gr-22.15-23.1, with a pull request into feature/godot-rebuild, never master');
    expect(goal).toContain('git switch -c lane/gr-22.15-23.1 origin/feature/godot-rebuild');
  });

  it('brings a session that opened elsewhere into a worktree of the repository', () => {
    expect(goal).toContain('never in a scratch or other folder');
    expect(goal).toContain(`worktree add "${repo}\\.claude\\worktrees\\lane-gr-22-15-23-1" -b lane/gr-22.15-23.1 origin/feature/godot-rebuild`);
  });

  it('asks wayfinder\'s questions before implementing', () => {
    expect(goal).toMatch(/wayfinder for questions only.*AskUserQuestion.*Then implement/);
  });

  it('builds milestone 1 and roadmap lanes on their plan\'s branch', () => {
    const m1 = goalFor({ plan: M1, ids: ['12'], tasks: { 12: { title: 'Sparks' } }, branch: 'lane/m1-12', repo });
    expect(m1).toContain('12 Sparks (docs/plans/milestone-1.md)');
    expect(m1).toContain('pushed on lane/m1-12, with a pull request into feature/milestone-1, never master');
    expect(m1).toContain('git switch -c lane/m1-12 origin/feature/milestone-1');
    expect(m1).not.toContain('which merges into');
    const rm = goalFor({ plan: RM, ids: ['R3'], tasks: { R3: { title: 'Sign-off' } }, branch: 'lane/rm-R3', repo });
    expect(rm).toContain('the Godot rebuild branch, feature/godot-rebuild');
    expect(rm).toContain('git switch -c lane/rm-R3 origin/feature/godot-rebuild');
  });

  it('follows a branch named in the plan header', () => {
    const goal = goalFor({ plan: { ...M1, branch: 'master' }, ids: ['12'], tasks: { 12: { title: 'Sparks' } }, branch: 'lane/m1-12', repo });
    expect(goal).toContain('with a pull request into master');
    expect(goal).toContain('origin/master');
  });

  it('tells the session to stop and tell the owner when the plan\'s branch is not on origin yet', () => {
    const goal = goalFor({ plan: M1, ids: ['12'], tasks: { 12: { title: 'Sparks' } }, branch: 'lane/m1-12', repo, baseExists: false });
    expect(goal).toContain('origin/feature/milestone-1 does not exist yet');
    expect(goal).toMatch(/stop and tell me.*do not create it or build on another branch/);
    expect(goal).toContain('or, if origin/feature/milestone-1 is still missing, when you have told me so and stopped');
    expect(goalFor({ plan: M1, ids: ['12'], tasks: { 12: { title: 'Sparks' } }, branch: 'lane/m1-12', repo })).not.toContain('does not exist yet');
  });

  it('is plain words, since the app turns a link\'s leading slash into a full-width one and never runs it as a command', () => {
    expect(goal).not.toMatch(/^\s*[/／]/);
    expect(goal).not.toContain('/goal');
  });

  it('keeps going from task to task without waiting for an OK, except for questions and owner gates', () => {
    expect(goal).toContain('Go on from one task to the next without waiting for my OK; stop only for a question that needs my answer, at an owner gate, or when every queued task is done.');
  });

  it('stays within the launch prompt\'s limit by shortening the titles', () => {
    const many = Object.fromEntries(Array.from({ length: 40 }, (_, i) => [`18.${i}`, { title: 'x'.repeat(200) }]));
    const long = goalFor({ plan: GR, ids: Object.keys(many), tasks: many, branch: 'lane/gr-many', repo });
    expect(long.length).toBeLessThanOrEqual(GOAL_LIMIT);
    expect(long).toContain('18.39');
  });
});

describe('stop hook', () => {
  const HOOK = fileURLToPath(new URL('../tools/lanes-board/stop-hook.mjs', import.meta.url));
  const dir = mkdtempSync(path.join(os.tmpdir(), 'lanes-stop-'));
  const file = path.join(dir, 'lanes-stop.json');
  const worktree = path.join(dir, 'worktrees', 'lane-gr-1');
  const run = (input) => execFileSync(process.execPath, [HOOK], {
    input: JSON.stringify(input), env: { ...process.env, LANES_STOP_FILE: file },
  }).toString();
  const stopList = (entry) => writeFileSync(file, JSON.stringify({ entries: [{
    id: 't', label: 'GR 1.1', worktree, sessions: ['listed'], requestedAt: Date.now(), firedAt: null, ...entry,
  }] }));

  afterEach(() => rmSync(file, { force: true }));

  it('does nothing without a stop list, or for a session it does not name', () => {
    expect(run({ session_id: 'listed', cwd: worktree, hook_event_name: 'PreToolUse' })).toBe('');
    stopList();
    expect(run({ session_id: 'other', cwd: dir, hook_event_name: 'PreToolUse' })).toBe('');
    expect(run({ session_id: 'other', cwd: `${worktree}-2`, hook_event_name: 'PreToolUse' })).toBe('');
  });

  it('stops a listed session before its next tool, wherever it runs', () => {
    stopList();
    const out = JSON.parse(run({ session_id: 'listed', cwd: os.tmpdir(), hook_event_name: 'PreToolUse' }));
    expect(out.continue).toBe(false);
    expect(out.hookSpecificOutput.permissionDecision).toBe('deny');
    expect(out.stopReason).toContain('GR 1.1');
    expect(JSON.parse(readFileSync(file, 'utf8')).entries[0].firedBy).toBe('listed');
  });

  it('stops any session working inside the lane\'s worktree when its turn ends', () => {
    stopList();
    const out = JSON.parse(run({ session_id: 'other', cwd: path.join(worktree, 'game'), hook_event_name: 'Stop' }));
    expect(out.continue).toBe(false);
    expect(out.hookSpecificOutput).toBeUndefined();
  });

  it('lets the session go on two minutes after it first stopped it', () => {
    stopList({ firedAt: Date.now() - 3 * 60 * 1000 });
    expect(run({ session_id: 'listed', cwd: worktree, hook_event_name: 'PreToolUse' })).toBe('');
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
    expect(run({ session_id: 'new', transcript_path: f, cwd: worktree, hook_event_name: 'PreToolUse' })).toBe('');
    expect(JSON.parse(readFileSync(file, 'utf8')).entries[0].firedAt).toBeNull();
  });

  it('still stops a session in the worktree that was running when the lane was ended', () => {
    const { f } = transcript('old-session', 0);
    stopList({ requestedAt: Date.now() + 60 * 1000 });
    const out = JSON.parse(run({ session_id: 'old', transcript_path: f, cwd: worktree, hook_event_name: 'PreToolUse' }));
    expect(out.continue).toBe(false);
  });

  it('ignores a stop the board cancelled by launching the lane again', () => {
    stopList({ cancelledAt: Date.now() });
    expect(run({ session_id: 'listed', cwd: worktree, hook_event_name: 'PreToolUse' })).toBe('');
  });

  it('never blocks on a broken stop list', () => {
    writeFileSync(file, '{not json');
    expect(run({ session_id: 'listed', cwd: worktree, hook_event_name: 'PreToolUse' })).toBe('');
  });
});
