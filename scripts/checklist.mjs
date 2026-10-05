// Fills the per-move checklist's CI-checked columns
// (docs/reviews/milestone-1-checklist.md, milestone-1 task 10) from a test
// run's results. The tests that check an item move by move record each
// result in build/checklist-results.json (ChecklistResults in
// game/tools/checklist_results.gd): { "results": [{ "item": 8, "row":
// "k_l1", "passed": true, "note": "..." }] }. A result marks its row's cell
// ✓ or ✗. The owner's columns (6, 7 and 17) are never written, nor a cell
// marked – (the item doesn't apply); a result for either, or for a row the
// checklist hasn't got, is reported and the command fails after writing
// the rest. A row waiting for milestone 2 takes no results, quietly.
//
// usage: node scripts/checklist.mjs [--results <json>] [--file <md>]
//        (npm run checklist, after a test run)

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const CHECKLIST = resolve(ROOT, 'docs/reviews/milestone-1-checklist.md');
export const RESULTS = resolve(ROOT, 'build/checklist-results.json');

// The items only the owner ticks.
export const OWNER_ITEMS = [6, 7, 17];
const ITEMS = 17;
const PASS = '✓';
const FAIL = '✗';
const NOT_APPLIED = '–';
const MILESTONE_2 = 'milestone 2';

// A table row's cells, without the outer pipes.
const split = (line) => line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());

// A checklist row in line `line`: its id (the backticked id ending the
// first cell), status and 17 item cells; null for any other line.
function parse(line) {
  if (!line.startsWith('|')) return null;
  const cells = split(line);
  const m = cells[0].match(/`([^`]+)`\s*$/);
  if (!m || cells.length !== ITEMS + 2) return null;
  return { id: m[1], status: cells[1], cells: cells.slice(2) };
}

// Every row of a checklist document, in order.
export function rows(doc) {
  return doc.split('\n').map(parse).filter((r) => r !== null);
}

// `doc` with `results` filled in: { doc, problems }.
export function fill(doc, results) {
  const lines = doc.split('\n');
  const at = new Map();
  lines.forEach((line, i) => {
    const r = parse(line);
    if (r) at.set(r.id, i);
  });
  const problems = [];
  for (const res of results) {
    const i = at.get(res.row);
    if (i === undefined) {
      problems.push(`${res.row}: no such row in the checklist`);
      continue;
    }
    if (!Number.isInteger(res.item) || res.item < 1 || res.item > ITEMS) {
      problems.push(`${res.row}: no item ${res.item}`);
      continue;
    }
    if (OWNER_ITEMS.includes(res.item)) {
      problems.push(`${res.row}: item ${res.item} is the owner's; left as it was`);
      continue;
    }
    const cells = split(lines[i]);
    if (cells[1] === MILESTONE_2) continue;
    const col = res.item + 1;
    if (cells[col] === NOT_APPLIED) {
      problems.push(`${res.row}: item ${res.item} doesn't apply to it; left as ${NOT_APPLIED}`);
      continue;
    }
    cells[col] = res.passed ? PASS : FAIL;
    lines[i] = `| ${cells.join(' | ')} |`;
  }
  return { doc: lines.join('\n'), problems };
}

function main(argv) {
  let file = CHECKLIST;
  let resultsFile = RESULTS;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--file' && i + 1 < argv.length) file = resolve(argv[++i]);
    else if (argv[i] === '--results' && i + 1 < argv.length) resultsFile = resolve(argv[++i]);
    else {
      console.error(`checklist: unknown argument ${argv[i]} (usage: [--results <json>] [--file <md>])`);
      process.exit(2);
    }
  }
  let results;
  try {
    results = JSON.parse(readFileSync(resultsFile, 'utf8')).results ?? [];
  } catch {
    console.error(`checklist: no results at ${resultsFile}; run the tests first (npm test, with the clip libraries for the local-only checks)`);
    process.exit(2);
  }
  const { doc, problems } = fill(readFileSync(file, 'utf8'), results);
  writeFileSync(file, doc);
  const failed = results.filter((r) => r.passed === false).length;
  console.log(`checklist: ${results.length} result${results.length === 1 ? '' : 's'} (${failed} failed) written into ${file}`);
  for (const p of problems) console.error(`checklist: ${p}`);
  if (problems.length > 0) process.exit(1);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2));
}
