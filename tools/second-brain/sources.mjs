// Sources the vault builder (vault.mjs) reads from: a git ref, read without
// touching any working tree, or a working tree on disk. Both give list(),
// read(path) and subjects() (commit subjects with the files they touched).
// Git runs with --no-optional-locks, so reading never collides with a
// session's own git commands.

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const MAX = 256 * 1024 * 1024;

function git(repo, args, input) {
  return execFileSync('git', ['--no-optional-locks', '-C', repo, ...args], { input, maxBuffer: MAX });
}

function subjectsOf(repo, ref) {
  let out;
  try {
    out = git(repo, ['log', '--format=%x00%s', '--name-only', ref]).toString('utf8');
  } catch {
    return []; // not a git repo, or no commits yet
  }
  return out.split('\0').slice(1).map((chunk) => {
    const [subject, ...files] = chunk.split('\n');
    return { subject, files: files.filter(Boolean) };
  });
}

/**
 * The files at a git ref. Text the builder reads (Markdown and GDScript) is loaded in one batch.
 * Blobs are read by object id from one ls-tree: asking cat-file for "ref:path" makes git resolve
 * the ref and walk the tree again for every file, about 3x slower on this repo.
 */
export function gitSource(repo, ref) {
  const ids = new Map(); // path -> object id
  for (const entry of git(repo, ['ls-tree', '-r', '-z', ref]).toString('utf8').split('\0')) {
    const tab = entry.indexOf('\t');
    if (tab > 0) ids.set(entry.slice(tab + 1), entry.slice(0, tab).split(' ')[2]);
  }
  const paths = [...ids.keys()];
  let texts = null;
  const load = () => {
    const wanted = paths.filter((p) => /\.(md|gd)$/.test(p));
    const out = git(repo, ['cat-file', '--batch'], wanted.map((p) => ids.get(p)).join('\n') + '\n');
    texts = new Map();
    let at = 0;
    for (const p of wanted) {
      const nl = out.indexOf(10, at);
      const size = Number(out.toString('utf8', at, nl).split(' ')[2]);
      texts.set(p, out.toString('utf8', nl + 1, nl + 1 + size));
      at = nl + 1 + size + 1;
    }
  };
  return {
    ref,
    list: () => paths,
    read: (p) => {
      if (!texts) load();
      if (texts.has(p)) return texts.get(p);
      return git(repo, ['cat-file', 'blob', ids.get(p) ?? `${ref}:${p}`]).toString('utf8');
    },
    subjects: () => subjectsOf(repo, ref),
  };
}

/** A working tree: tracked files plus new ones git doesn't ignore, so fresh notes show before they're committed. */
export function fsSource(dir) {
  const paths = git(dir, ['ls-files', '-z', '--cached', '--others', '--exclude-standard']).toString('utf8')
    .split('\0').filter((p) => p && existsSync(join(dir, p)));
  return {
    list: () => [...new Set(paths)],
    read: (p) => readFileSync(join(dir, p), 'utf8'),
    subjects: () => subjectsOf(dir, 'HEAD'),
  };
}
