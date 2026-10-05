// Tests for scripts/checklist.mjs, which fills the per-move checklist's
// CI-checked columns (docs/reviews/milestone-1-checklist.md, milestone-1
// task 10) from a test run's results, leaving the owner's columns alone.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { OWNER_ITEMS, fill, rows } from '../scripts/checklist.mjs';

const ROOT = resolve(import.meta.dirname, '..');
const CHECKLIST = join(ROOT, 'docs', 'reviews', 'milestone-1-checklist.md');

const HEADER = '| Move or clip | Status | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |\n'
  + '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n';
const ROW = (name, id, cells) => `| ${name} \`${id}\` | move | ${cells.join(' | ')} |\n`;
const BLANK = ['·', '·', '–', '·', '·', '☐', '☐', '·', '·', '·', '·', '·', '·', '·', '·', '·', '☐'];
const DOC = '# Checklist\n\n## 1. The pilot\n\n' + HEADER + ROW('Right Cut', 'k_l1', BLANK) + ROW('Return Cut', 'k_l2', BLANK) + '\nAfter.\n';

// The cells of row `id` in `doc`, items 1-17.
const cellsOf = (doc, id) => rows(doc).find((r) => r.id === id).cells;

describe('rows', () => {
  it('reads each row\'s id and its 17 cells', () => {
    const r = rows(DOC);
    assert.deepEqual(r.map((x) => x.id), ['k_l1', 'k_l2']);
    assert.deepEqual(r[0].cells, BLANK);
    assert.equal(r[0].status, 'move');
  });
});

describe('fill', () => {
  it('fills a row\'s CI-checked cells from a test run, pass or fail', () => {
    const { doc, problems } = fill(DOC, [
      { item: 8, row: 'k_l1', passed: true },
      { item: 9, row: 'k_l1', passed: false },
    ]);
    assert.deepEqual(problems, []);
    const want = [...BLANK];
    want[7] = '✓';
    want[8] = '✗';
    assert.deepEqual(cellsOf(doc, 'k_l1'), want);
    assert.deepEqual(cellsOf(doc, 'k_l2'), BLANK, 'the other row is untouched');
    assert.ok(doc.endsWith('\nAfter.\n'), 'the rest of the file is kept');
  });

  it('turns a pass into a fail and back on later runs', () => {
    let doc = fill(DOC, [{ item: 1, row: 'k_l2', passed: true }]).doc;
    doc = fill(doc, [{ item: 1, row: 'k_l2', passed: false }]).doc;
    assert.equal(cellsOf(doc, 'k_l2')[0], '✗');
  });

  it('never writes the owner\'s columns', () => {
    assert.deepEqual(OWNER_ITEMS, [6, 7, 17]);
    const ticked = DOC.replace(ROW('Right Cut', 'k_l1', BLANK), ROW('Right Cut', 'k_l1', BLANK.map((c, i) => (i === 5 ? '☑' : c))));
    const { doc, problems } = fill(ticked, [{ item: 6, row: 'k_l1', passed: false }, { item: 7, row: 'k_l1', passed: true }]);
    assert.equal(cellsOf(doc, 'k_l1')[5], '☑');
    assert.equal(cellsOf(doc, 'k_l1')[6], '☐');
    assert.equal(problems.length, 2);
    assert.match(problems[0], /item 6 is the owner's/);
  });

  it('leaves a cell that doesn\'t apply, and names it', () => {
    const { doc, problems } = fill(DOC, [{ item: 3, row: 'k_l1', passed: true }]);
    assert.equal(cellsOf(doc, 'k_l1')[2], '–');
    assert.deepEqual(problems, ['k_l1: item 3 doesn\'t apply to it; left as –']);
  });

  it('passes over a row waiting for milestone 2 without complaint', () => {
    const m2 = DOC.replace(ROW('Return Cut', 'k_l2', BLANK), ROW('Return Cut', 'k_l2', BLANK.map(() => '–')).replace('| move |', '| milestone 2 |'));
    const { doc, problems } = fill(m2, [{ item: 8, row: 'k_l2', passed: false }]);
    assert.deepEqual(problems, []);
    assert.equal(cellsOf(doc, 'k_l2')[7], '–');
  });

  it('names a result for a row the checklist hasn\'t got', () => {
    const { problems } = fill(DOC, [{ item: 8, row: 'k_l9', passed: true }]);
    assert.deepEqual(problems, ['k_l9: no such row in the checklist']);
  });
});

describe('the committed checklist', () => {
  const doc = readFileSync(CHECKLIST, 'utf8');

  it('has one row per id, each with 17 items', () => {
    const r = rows(doc);
    assert.ok(r.length > 50, `${r.length} rows`);
    assert.equal(new Set(r.map((x) => x.id)).size, r.length, 'no id twice');
    for (const x of r) assert.equal(x.cells.length, 17, x.id);
  });

  it('marks only with the key\'s marks, and the owner\'s columns only with the owner\'s', () => {
    for (const x of rows(doc)) {
      x.cells.forEach((c, i) => {
        const item = i + 1;
        const allowed = OWNER_ITEMS.includes(item) ? ['☐', '☑', '–'] : ['✓', '✗', '·', '–'];
        assert.ok(allowed.includes(c), `${x.id} item ${item}: ${c}`);
      });
    }
  });
});

describe('the command', () => {
  it('fills the checklist from a results file and says what it did', () => {
    const dir = mkdtempSync(join(tmpdir(), 'checklist-'));
    try {
      const file = join(dir, 'checklist.md');
      const results = join(dir, 'results.json');
      writeFileSync(file, DOC);
      writeFileSync(results, JSON.stringify({ results: [{ item: 8, row: 'k_l2', passed: true, note: 'worst 0.4 cm' }] }));
      const r = spawnSync(process.execPath, ['scripts/checklist.mjs', '--file', file, '--results', results], { cwd: ROOT, encoding: 'utf8' });
      assert.equal(r.status, 0, r.stderr);
      assert.match(r.stdout, /1 result/);
      assert.equal(cellsOf(readFileSync(file, 'utf8'), 'k_l2')[7], '✓');
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('fails on a result it can\'t place, writing the rest', () => {
    const dir = mkdtempSync(join(tmpdir(), 'checklist-'));
    try {
      const file = join(dir, 'checklist.md');
      const results = join(dir, 'results.json');
      writeFileSync(file, DOC);
      writeFileSync(results, JSON.stringify({ results: [{ item: 9, row: 'k_l1', passed: true }, { item: 9, row: 'nope', passed: true }] }));
      const r = spawnSync(process.execPath, ['scripts/checklist.mjs', '--file', file, '--results', results], { cwd: ROOT, encoding: 'utf8' });
      assert.equal(r.status, 1);
      assert.match(r.stderr, /nope: no such row/);
      assert.equal(cellsOf(readFileSync(file, 'utf8'), 'k_l1')[8], '✓');
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('explains a missing results file', () => {
    const r = spawnSync(process.execPath, ['scripts/checklist.mjs', '--results', join(tmpdir(), 'no-such-results.json')], { cwd: ROOT, encoding: 'utf8' });
    assert.equal(r.status, 2);
    assert.match(r.stderr, /no results/);
  });
});
