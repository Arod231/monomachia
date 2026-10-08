// Keeps large files out of the repo, which uses plain Git without LFS: fails
// when a tracked file is over 60 MB unless it is allow-listed below, or when
// a place goes over its budget in the spec's size budget table (milestone-1
// task 8): the committed game art under 600 MB and the committed audio under
// 40 MB. The owner raised the file limit from 10 MB and the art's budget from
// 150 MB on Oct 8, 2026, for the Shrine's modelled buildings and their
// lossless baked maps (milestone-1 task 132); GitHub warns on files past
// 50 MB and refuses them past 100 MB. It prints how big the art, the audio and the whole working copy
// are. Sizes are in binary megabytes (1 MB = 1024 × 1024 bytes), as in the
// Godot asset budget test. The asset repository checks its own budgets
// (its tools/check-budgets.mjs).
//
// usage: node scripts/check-sizes.mjs [--include <file>]...
//   --include  also check a file that isn't tracked yet (before adding it);
//              repeat it for several files

import { execFileSync } from 'node:child_process';
import { statSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const MB = 1024 * 1024;

export const LIMIT_BYTES = 60 * MB;

// Tracked files allowed over the limit, each with its reason. Empty since the
// limit went to 60 MB (Oct 8, 2026): the shrine's ambience loop (10.1 MB)
// and Quaternius's UAL2 clip libraries (about 20 MB each) it held fit now.
export const ALLOWED = new Set([]);

// The folders whose sizes are printed.
const FOLDERS = ['game/assets', 'game/assets/audio', 'game/fighters', 'game/weapons'];

// The public repository's budgets (the spec's size budget table, P23).
// The committed game art: CC0 and self-made models and materials, the
// exports copied from the asset repository and the labelled stand-ins,
// which is everything in game/assets but the audio, and the baked binary
// art beside it in game/fighters and game/weapons (their scenes and scripts
// aren't art). The audio is everything in game/assets/audio.
export const ART_BUDGET_BYTES = 600 * MB;
export const AUDIO_BUDGET_BYTES = 40 * MB;
const ASSETS = 'game/assets/';
const AUDIO = 'game/assets/audio/';
const BAKED = ['game/fighters/', 'game/weapons/'];
const BAKED_EXTENSIONS = ['.png', '.res', '.exr'];

// Whether a repo-relative path is committed game art.
export function isArt(path) {
  if (path.startsWith(ASSETS)) return !path.startsWith(AUDIO);
  const lower = path.toLowerCase();
  return BAKED.some((b) => path.startsWith(b)) && BAKED_EXTENSIONS.some((e) => lower.endsWith(e));
}

// Whether a repo-relative path is committed audio.
export function isAudio(path) {
  return path.startsWith(AUDIO);
}

// Each place's size against its budget: [{ name, bytes, limit }].
export function budgets(files) {
  const sum = (keep) => files.filter((f) => keep(f.path)).reduce((s, f) => s + f.bytes, 0);
  return [
    { name: 'committed game art', bytes: sum(isArt), limit: ART_BUDGET_BYTES },
    { name: 'committed audio', bytes: sum(isAudio), limit: AUDIO_BUDGET_BYTES },
  ];
}

// The places over their budgets.
export function findOverBudget(files) {
  return budgets(files).filter((b) => b.bytes > b.limit);
}

// The files over the limit that aren't allow-listed.
export function findOversize(files) {
  return files.filter((f) => f.bytes > LIMIT_BYTES && !ALLOWED.has(f.path));
}

// The total size of the files under `folder` (a repo-relative path), or of
// all of them.
export function totalBytes(files, folder = '') {
  const prefix = folder === '' ? '' : folder.replace(/\/$/, '') + '/';
  return files.filter((f) => f.path.startsWith(prefix)).reduce((sum, f) => sum + f.bytes, 0);
}

// A path as the repo writes it: relative to the root, with forward slashes
// (a file outside the repo keeps its absolute path).
export function repoPath(path, root = ROOT) {
  const abs = isAbsolute(path) ? path : resolve(path);
  const rel = relative(root, abs);
  if (rel === '' || rel.startsWith('..') || isAbsolute(rel)) return abs.split(sep).join('/');
  return rel.split(sep).join('/');
}

function fail(message, code) {
  console.error(`check-sizes: ${message}`);
  process.exit(code);
}

// Every tracked file and its size: [{ path, bytes }]. The Blender export
// (scripts/blender/export.mjs) weighs a copy into the game against these.
export function trackedFiles() {
  let out;
  try {
    out = execFileSync('git', ['ls-files', '-z'], { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * MB });
  } catch (err) {
    fail(`could not list the tracked files with git (${err.message.split('\n')[0]})`, 2);
  }
  const files = [];
  for (const path of out.split('\0')) {
    if (path === '') continue;
    try {
      files.push({ path, bytes: statSync(resolve(ROOT, path)).size });
    } catch (err) {
      // Deleted in the working copy but still in the index: nothing to weigh.
      if (err.code !== 'ENOENT') throw err;
    }
  }
  return files;
}

function main(argv) {
  const files = trackedFiles();
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] !== '--include') fail(`unknown argument ${argv[i]} (usage: [--include <file>]...)`, 2);
    if (i + 1 >= argv.length) fail('--include needs a file', 2);
    const given = argv[++i];
    let bytes;
    try {
      bytes = statSync(given).size;
    } catch {
      fail(`--include: no such file ${given}`, 2);
    }
    const path = repoPath(given);
    const known = files.find((f) => f.path === path);
    if (known) known.bytes = bytes;
    else files.push({ path, bytes });
  }
  const mb = (bytes) => (bytes / MB).toFixed(1);
  for (const folder of FOLDERS) console.log(`${folder}: ${mb(totalBytes(files, folder))} MB`);
  console.log(`all tracked files: ${mb(totalBytes(files))} MB in ${files.length} files`);
  for (const path of ALLOWED) {
    const f = files.find((x) => x.path === path);
    if (f === undefined || f.bytes <= LIMIT_BYTES) {
      console.log(`note: ${path} no longer needs its place on the allow-list`);
    }
  }
  for (const b of budgets(files)) console.log(`${b.name}: ${mb(b.bytes)} MB of a ${mb(b.limit)} MB budget`);
  const over = findOversize(files);
  for (const f of over) console.error(`too large: ${f.path} is ${mb(f.bytes)} MB (limit ${mb(LIMIT_BYTES)} MB)`);
  const overBudget = findOverBudget(files);
  for (const b of overBudget) console.error(`over budget: ${b.name} comes to ${mb(b.bytes)} MB (budget ${mb(b.limit)} MB)`);
  if (over.length > 0) fail('shrink these files, or allow-list one in scripts/check-sizes.mjs with its reason.', 1);
  if (overBudget.length > 0) fail('bring these places under their budgets (docs/specs/milestone-1.md, the size budget table).', 1);
  console.log(`no file over ${mb(LIMIT_BYTES)} MB outside the allow-list, and every place inside its budget`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2));
}
