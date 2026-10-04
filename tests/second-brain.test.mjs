// Tests for tools/second-brain/vault.mjs, the builder of the second brain
// (docs/specs/second-brain.md): its parsers, and the vault it builds.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import {
  buildVault, linksIn, parseGlossary, parsePlan, parseScriptSummary, resolveLinks, safeName, splitSections, taskIdsInSubject,
} from '../tools/second-brain/vault.mjs';

/** A source over in-memory files and commit subjects. */
function memorySource(files, subjects = []) {
  return { list: () => Object.keys(files), read: (p) => files[p], subjects: () => subjects };
}

const GLOSSARY = `# Monomachia

Intro.

## Attacking

**Light attack** / **Heavy attack**:
The two attack buttons' moves.

**String**:
A sequence of attacks.
_Avoid_: Combo, chain

## Defending

**Parry**:
Tapping block just before an attack lands,
so the weapons bounce.
`;

const PLAN = `# Plan: test

## Build order

1. **Foundations:** 1.1–1.3, 2.1.
2. **Later** (after the owner's OK): 2.2, then 2.3.

## Tasks

### Phase A: start

- [x] **1. Group one.** Lead text.
  - [x] **1.1 First thing.** Does a thing.
    - Check: it works.
    - Blocked by: none (built after 9.9 in the build order) · Stories: 4
  - [x] **1.2 Second thing.**
    - Blocked by: 1.1 · Stories: 5
  - [ ] **1.3 Third thing.**
    - Blocked by: 1.1, 1.2 (and the owner's OK)

### Phase B: more

- [ ] **2. Group two.**
  - [ ] **2.1 A.**
    - Blocked by: 1.1–1.3
  - [ ] **2.2 B.**
  - [ ] **2.3 C.**
  - [-] ~~**2.4 D.**~~ Retired.

## Out of scope

- [ ] **9.9 Not a task here.**
`;

describe('safeName', () => {
  it('keeps names Obsidian accepts as files and link targets', () => {
    assert.equal(safeName('Spec: Monomachia rebuilt in Godot'), 'Spec - Monomachia rebuilt in Godot');
    assert.equal(safeName('Game Design Document: *Monomachia*'), 'Game Design Document - Monomachia');
    assert.equal(safeName('a/b [c] #d | e?'), 'a-b -c- -d - e');
    assert.equal(safeName('Ends with a dot.'), 'Ends with a dot');
  });
});

describe('taskIdsInSubject', () => {
  it('reads task ids, lists and ranges from commit subjects', () => {
    assert.deepEqual(taskIdsInSubject('Step the feet in time with a lunge (task 14.13)'), ['14.13']);
    assert.deepEqual(taskIdsInSubject('Build screens (godot-rebuild 22.6, 22.8-22.10, first step)'), ['22.6', '22.8', '22.9', '22.10']);
    assert.deepEqual(taskIdsInSubject('Open Settings (godot-rebuild 22.9, 22.10)'), ['22.9', '22.10']);
    assert.deepEqual(taskIdsInSubject('Port the swing editor (task 14b.2)'), ['14b.2']);
  });

  it('ignores other parentheses and untagged subjects', () => {
    assert.deepEqual(taskIdsInSubject('Merge pull request #16 from Arod231/godot/menus-22.6-22.10'), []);
    assert.deepEqual(taskIdsInSubject('Add UAL2 clips (v1.2 files)'), []);
  });
});

describe('parseGlossary', () => {
  it('gives an entry per term with its section, definition and avoid words', () => {
    const g = parseGlossary(GLOSSARY);
    assert.deepEqual(g.map((e) => e.term), ['Light attack', 'Heavy attack', 'String', 'Parry']);
    assertMatches(g[0], { section: 'Attacking', definition: "The two attack buttons' moves.", also: ['Heavy attack'] });
    assertMatches(g[2], { avoid: 'Combo, chain', also: [] });
    assertMatches(g[3], { section: 'Defending', definition: 'Tapping block just before an attack lands, so the weapons bounce.' });
  });
});

describe('splitSections', () => {
  it('splits at ## below the title and keeps the intro', () => {
    const s = splitSections('# Title *here*\n\nIntro line.\n\n## One\n\nA\n\n### Sub\n\nB\n\n## Two\n\nC\n');
    assert.equal(s.title, 'Title here');
    assert.equal(s.intro, 'Intro line.');
    assert.deepEqual(s.sections.map((x) => x.heading), ['One', 'Two']);
    assert.equal(s.sections[0].body, 'A\n\n### Sub\n\nB');
  });

  it('splits at ### in a doc with no ## headings, and ignores headings in code fences', () => {
    const s = splitSections('# T\n\n### A\n\n```\n## not a heading\n```\n\n### B\n\nx\n');
    assert.deepEqual(s.sections.map((x) => x.heading), ['A', 'B']);
  });
});

describe('parseScriptSummary', () => {
  it('reads the class, base and the first sentence of the doc comment', () => {
    const s = parseScriptSummary('class_name PadStyle\nextends RefCounted\n## Which button names a controller gets. More text\n## here.\n\nconst A = 1\n');
    assertMatches(s, { className: 'PadStyle', base: 'RefCounted', summary: 'Which button names a controller gets.' });
  });

  it('skips a leading "Port of" line and notes the port', () => {
    const s = parseScriptSummary('class_name Fighter\nextends RefCounted\n## Port of v0.1-web-mvp:src/sim/fighter.ts.\n##\n## A fighter: position, health. Pure.\n');
    assert.equal(s.summary, 'A fighter: position, health. (port of v0.1-web-mvp:src/sim/fighter.ts)');
  });

  it('falls back to plain # comments, and to nothing', () => {
    assert.equal(parseScriptSummary('extends Node\n# Plays swings on a fighter.\nvar f\n').summary, 'Plays swings on a fighter.');
    assert.equal(parseScriptSummary('extends Node\nvar f\n# late comment\n').summary, '');
  });
});

describe('parsePlan', () => {
  const plan = parsePlan(PLAN);

  it('reads every task under Tasks with its done mark, parent and phase', () => {
    assert.deepEqual(plan.tasks.map((t) => t.id), ['1', '1.1', '1.2', '1.3', '2', '2.1', '2.2', '2.3', '2.4']);
    assertMatches(plan.tasks[8], { title: 'D', lead: 'Retired.', done: false, retired: true, parent: '2' });
    assertMatches(plan.tasks[0], { title: 'Group one', lead: 'Lead text.', done: true, parent: null, phase: 'Phase A: start' });
    assertMatches(plan.tasks[1], { title: 'First thing', done: true, parent: '1' });
    assert.ok(plan.tasks[1].text.includes('- Check: it works.'));
    assertMatches(plan.tasks[3], { done: false, phase: 'Phase A: start' });
    assertMatches(plan.tasks[5], { parent: '2', phase: 'Phase B: more' });
  });

  it('reads blockers, leaving out notes in parentheses, and the owner gate', () => {
    assert.deepEqual(plan.tasks[1].blockedBy, []);
    assert.deepEqual(plan.tasks[2].blockedBy, ['1.1']);
    assertMatches(plan.tasks[3], { blockedBy: ['1.1', '1.2'], waitsOnOwner: true });
    assert.deepEqual(plan.tasks[5].blockedBy, ['1.1', '1.2', '1.3']);
  });

  it('reads the build order with en-dash ranges expanded in plan order', () => {
    assert.deepEqual(plan.stages, [
      { n: 1, name: 'Foundations', ids: ['1.1', '1.2', '1.3', '2.1'] },
      { n: 2, name: 'Later', ids: ['2.2', '2.3'] },
    ]);
  });
});

describe('linksIn and resolveLinks', () => {
  it('finds wikilinks with labels and headings, not embeds or code', () => {
    assert.deepEqual(linksIn('See [[A]], [[B|label]], [[C#Part]], [[dir/D]] and ![[E]] or `[[F]]`.'), ['A', 'B', 'C', 'dir/D']);
  });

  it('resolves by name, ignoring case and folders, and reports misses', () => {
    const notes = [{ name: 'Alpha', text: '[[beta]] [[x/Beta]] [[Gamma]]' }, { name: 'Beta', text: '' }];
    assert.deepEqual(resolveLinks(notes).map((l) => l.to), ['Beta', 'Beta', null]);
  });
});

describe('buildVault', () => {
  const source = memorySource({
    'GLOSSARY.md': GLOSSARY,
    'docs/plans/godot-rebuild.md': PLAN,
    'docs/design.md': '# Game Design Document: *Monomachia*\n\nIntro, see [the plan](plans/godot-rebuild.md).\n\n## Combat\n\nA **parry** or a string.\n\n## Look\n\nArt.\n',
    'brain/Home.md': '# Home\n\n[[Glossary]] · [[Design doc]] · [[Code map]] · [[Rebuild plan]]\n',
    'brain/.obsidian/app.json': '{}',
    'brain/generated/stale.md': 'old',
    'game/sim/fighter.gd': 'class_name Fighter\nextends RefCounted\n## A fighter: position and posture (task 2.2).\n',
    'game/sim/moves/katana.gd': 'extends RefCounted\n## The Katana\'s moves.\n',
    'game/addons/gut/gut.gd': '## Not ours.\n',
    'scripts/old.mjs': 'x',
  }, [
    { subject: 'Add the fighter (task 1.2)', files: ['game/sim/fighter.gd', 'docs/plans/godot-rebuild.md'] },
    { subject: 'Tidy (godot-rebuild 2.1, 77.1)', files: ['game/sim/moves/katana.gd'] },
    { subject: 'Untagged change', files: ['game/sim/fighter.gd'] },
  ]);
  const { notes } = buildVault(source);
  const note = (name) => notes.find((n) => n.name === name);

  it('keeps hand-written notes and leaves out stale generated files and settings', () => {
    assert.equal(note('Home').path, 'brain/Home.md');
    assert.equal(notes.some((n) => n.path === 'brain/generated/stale.md' || n.path.includes('.obsidian')), false);
  });

  it('gives every note a unique name and every link a target', () => {
    const names = notes.map((n) => n.name.toLowerCase());
    assert.equal(new Set(names).size, names.length);
    assert.deepEqual(resolveLinks(notes).filter((l) => !l.to), []);
  });

  it('writes a note per glossary term, linking the terms it names', () => {
    assert.ok(note('Heavy attack').text.includes('**See also:** [[Light attack]]'));
    assert.ok(note('String').text.includes('**Avoid:** Combo, chain'));
    assert.ok(note('Glossary').text.includes('- [[Parry]]: Tapping block just before an attack lands, so the weapons bounce.'));
  });

  it('writes doc hubs and section notes with doc links rewritten and terms mentioned', () => {
    assert.ok(note('Design doc').text.includes('Intro, see [[Rebuild plan|the plan]].'));
    assert.ok(note('Design doc').text.includes('- [[Design doc - Combat|Combat]]'));
    const combat = note('Design doc - Combat');
    assert.equal(combat.path, 'brain/generated/docs/Design doc/Design doc - Combat.md');
    assert.ok(combat.text.includes('**Next:** [[Design doc - Look]]'));
    assert.ok(combat.text.includes('**Mentions:** [[String]] · [[Parry]]'));
  });

  it('writes stage and task notes with blockers, what they block, and their code', () => {
    assert.ok(note('Stage 1 - Foundations').text.includes('2 of 4 tasks done'));
    const t12 = note('Task 1.2');
    assert.equal(t12.path, 'brain/generated/plan/Rebuild plan/tasks/Task 1.2.md');
    assert.ok(t12.text.includes('**Status:** done ✓ · **Stage:** [[Stage 1 - Foundations]] · **Part of:** [[Task 1]]'));
    assert.ok(t12.text.includes('**Blocked by:** [[Task 1.1]]'));
    assert.ok(t12.text.includes('**Blocks:** [[Task 1.3]] · [[Task 2.1]]'));
    assert.ok(t12.text.includes('**Code:** [[game.sim]]'));
    assert.ok(note('Task 1.3').text.includes("**Blocked by:** [[Task 1.1]] · [[Task 1.2]] · the owner's OK"));
    assert.ok(note('Task 1').text.includes('**Subtasks:** ✓ [[Task 1.1]] · ✓ [[Task 1.2]] · ○ [[Task 1.3]]'));
    assert.ok(note('Rebuild plan').text.includes('- ✓ [[Task 1]]: Group one'));
    assert.ok(!note('Rebuild plan').text.includes('[[Rebuild plan - Tasks'));
  });

  it('writes a code note per folder with script summaries and the tasks that touched it', () => {
    const sim = note('game.sim');
    assert.ok(sim.text.includes('- `fighter.gd` (Fighter): A fighter: position and posture (task 2.2).'));
    assert.ok(sim.text.includes('**Tasks:** [[Task 1.2]] · [[Task 2.2]]'));
    assert.ok(sim.text.includes('**In:** [[game]] · **Folders:** [[game.sim.moves]]'));
    assert.ok(note('game.sim.moves').text.includes('**Tasks:** [[Task 2.1]]'));
    assert.equal(notes.some((n) => n.name.includes('addons')), false);
    assert.ok(note('Code map').text.includes('  - [[game.sim]] (2 scripts)'));
  });

  it('is deterministic', () => {
    assert.deepEqual(buildVault(source), { notes });
  });
});

describe('safeName length', () => {
  it('cuts long names at a parenthesis, then at a word, and keeps raw names raw', () => {
    assert.equal(safeName('Plan task 8 - Fluid combat rules and more words (arena radius 15 m and the values tied to it, and so on)'), 'Plan task 8 - Fluid combat rules and more words');
    assert.ok(safeName('word '.repeat(30)).length <= 80);
    assert.equal(safeName('game.arenas.moonlit_shrine', true), 'game.arenas.moonlit_shrine');
  });
});

describe('parseScriptSummary ports', () => {
  it('keeps a "Port of" sentence that says what the script is', () => {
    assert.equal(parseScriptSummary('## Port of the AttackState interface in v0.1-web-mvp:src/sim/fighter.ts: the attack in progress.\n').summary, 'Port of the AttackState interface in v0.1-web-mvp:src/sim/fighter.ts: the attack in progress.');
    assert.equal(parseScriptSummary('## Port of v0.1-web-mvp:src/sim/match.ts. Round and match flow.\n').summary, 'Round and match flow. (port of v0.1-web-mvp:src/sim/match.ts)');
  });
});

describe('sources', async () => {
  const { fsSource, gitSource } = await import('../tools/second-brain/sources.mjs');
  const ROOT = new URL('..', import.meta.url).pathname.replace(/^\/(\w:)/, '$1');
  // These spawn git and read the whole repo. Alone they take 1-3 s, but in a full
  // run, under load from the other test files, they have taken over 5 s; the
  // limit only stops a hung git.
  const SLOW = 30_000;

  it('reads the same tracked doc from the working tree and from HEAD', { timeout: SLOW }, () => {
    const fs = fsSource(ROOT);
    const head = gitSource(ROOT, 'HEAD');
    assert.ok(fs.list().includes('GLOSSARY.md'));
    assert.ok(head.list().includes('GLOSSARY.md'));
    assert.equal(head.read('GLOSSARY.md').replace(/\r\n/g, '\n'), fs.read('GLOSSARY.md').replace(/\r\n/g, '\n'));
    assert.ok(head.read('README.md').length > 0);
    assert.equal(JSON.parse(head.read('package.json')).name, JSON.parse(fs.read('package.json')).name);
    const latest = head.subjects()[0];
    assert.deepEqual(Object.keys(latest).sort(), ['files', 'subject']);
    assert.equal(typeof latest.subject, 'string');
    assert.ok(Array.isArray(latest.files));
  });

  it('builds the real vault with no broken links and no duplicate names', { timeout: SLOW }, () => {
    const { notes } = buildVault(fsSource(ROOT));
    const names = notes.map((n) => n.name.toLowerCase());
    assert.deepEqual(names.filter((n, i) => names.indexOf(n) !== i), []);
    assert.deepEqual(resolveLinks(notes).filter((l) => !l.to).map((l) => `${l.from} -> ${l.target}`), []);
    assert.ok(notes.find((n) => n.name === 'Rebuild plan'));
  });
});

describe('brainHandler', async () => {
  const { brainHandler } = await import('../tools/second-brain/serve.mjs');
  const call = async (handle, path, method = 'GET') => {
    let status = 0, headers = {}, body = '';
    const res = { writeHead: (s, h = {}) => { status = s; headers = h; }, end: (b = '') => { body = String(b); } };
    await handle({ method }, res, path);
    return { status, headers, body };
  };
  const source = memorySource({ 'brain/Home.md': '# Home\n\n[[Glossary]]\n', 'GLOSSARY.md': GLOSSARY });

  it('serves the viewer page, its script and the notes', async () => {
    let asked = 0;
    const handle = brainHandler({ getSource: () => { asked++; return { key: 'abc', source }; }, label: 'test' });
    const page = await call(handle, '/');
    assert.equal(page.status, 200);
    assert.ok(page.body.includes('<title>Second brain</title>'));
    assert.ok((await call(handle, 'vendor/marked.umd.js')).body.includes('marked'));
    const notes = await call(handle, 'notes.json?x=1');
    const data = JSON.parse(notes.body);
    assertMatches(data, { label: 'test', key: 'abc' });
    assert.ok(data.notes.map((n) => n.name).includes('Parry'));
    await call(handle, 'notes.json');
    assert.equal(asked, 2);
  });

  it('refuses unknown paths and other methods', async () => {
    const handle = brainHandler({ getSource: () => ({ key: null, source }) });
    assert.equal((await call(handle, '../package.json')).status, 404);
    assert.equal((await call(handle, 'notes.json', 'POST')).status, 405);
  });
});
