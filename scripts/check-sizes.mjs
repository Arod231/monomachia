// Keeps large files out of the repo, which uses plain Git without LFS: fails
// when a tracked file is over 10 MB unless it is allow-listed below, and
// prints how big the art, the audio and the whole working copy are. Sizes
// are in binary megabytes (1 MB = 1024 × 1024 bytes), as in the Godot asset
// budget test.
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

export const LIMIT_BYTES = 10 * MB;

// Tracked files allowed over the limit, each with its reason.
export const ALLOWED = new Set([
  // The shrine's 60 s stereo ambience loop (10,584,112 bytes of 16-bit WAV,
  // as the spec's sound section asks for); re-encoding it would change the
  // extractor and the sound bank's checks.
  'game/assets/audio/sfx/amb_shrine_loop.wav',
  // Quaternius's full UAL2 clip libraries (Source tier), about 20 MB each,
  // with and without root motion; the art budget test allows up to 25 MB.
  'game/assets/quaternius/animations/UAL2_Source.glb',
  'game/assets/quaternius/animations/UAL2_Source_RM.glb',
]);

// The folders whose sizes are printed.
const FOLDERS = ['game/assets', 'game/assets/audio', 'game/fighters', 'game/weapons'];

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

function trackedFiles() {
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
  const over = findOversize(files);
  if (over.length > 0) {
    for (const f of over) console.error(`too large: ${f.path} is ${mb(f.bytes)} MB (limit ${mb(LIMIT_BYTES)} MB)`);
    fail('shrink these files, or allow-list one in scripts/check-sizes.mjs with its reason.', 1);
  }
  console.log(`no file over ${mb(LIMIT_BYTES)} MB outside the allow-list`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2));
}
