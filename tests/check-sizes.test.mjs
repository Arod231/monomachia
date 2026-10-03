// Tests for scripts/check-sizes.mjs, the guard that keeps large files out of
// the repo (no tracked file over 10 MB unless it is allow-listed).

import { describe, expect, it } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { ALLOWED, LIMIT_BYTES, findOversize, repoPath, totalBytes } from '../scripts/check-sizes.mjs';

const ROOT = resolve(import.meta.dirname, '..');
const MB = 1024 * 1024;
const AMBIENCE = 'game/assets/audio/sfx/amb_shrine_loop.wav';

function runCli(args = []) {
  return spawnSync(process.execPath, ['scripts/check-sizes.mjs', ...args], { cwd: ROOT, encoding: 'utf8' });
}

function withScratchFile(bytes, body) {
  const dir = mkdtempSync(join(tmpdir(), 'check-sizes-'));
  try {
    const file = join(dir, 'scratch.bin');
    writeFileSync(file, Buffer.alloc(bytes));
    body(file);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

describe('findOversize', () => {
  it('passes files up to the 10 MB limit', () => {
    expect(LIMIT_BYTES).toBe(10 * MB);
    expect(findOversize([{ path: 'a.png', bytes: 10 * MB }, { path: 'b.wav', bytes: 1 }])).toEqual([]);
  });

  it('reports a file over the limit', () => {
    const files = [{ path: 'game/assets/big.wav', bytes: 11 * MB }, { path: 'small.png', bytes: 5 }];
    expect(findOversize(files)).toEqual([{ path: 'game/assets/big.wav', bytes: 11 * MB }]);
  });

  it('lets every allow-listed file through', () => {
    for (const path of ALLOWED) expect(findOversize([{ path, bytes: 11 * MB }])).toEqual([]);
  });
});

describe('totalBytes', () => {
  it('adds up the files under a folder, or all of them', () => {
    const files = [
      { path: 'game/assets/a.png', bytes: 3 },
      { path: 'game/assets/audio/b.wav', bytes: 4 },
      { path: 'game/fighters/c.png', bytes: 5 },
    ];
    expect(totalBytes(files, 'game/assets')).toBe(7);
    expect(totalBytes(files)).toBe(12);
  });
});

describe('repoPath', () => {
  it('writes paths inside the repo relative, with forward slashes', () => {
    expect(repoPath(join(ROOT, 'game', 'assets', 'x.wav'), ROOT)).toBe('game/assets/x.wav');
  });
});

describe('the command', () => {
  it('passes on the repo, allowing the ambience loop, and prints the sizes', () => {
    const r = runCli();
    expect(r.status, r.stderr).toBe(0);
    for (const folder of ['game/assets', 'game/assets/audio', 'game/fighters', 'game/weapons']) {
      expect(r.stdout).toMatch(new RegExp(`${folder}: \\d+\\.\\d MB`));
    }
    expect(r.stdout).toMatch(/all tracked files: \d+\.\d MB/);
    expect(r.stdout).not.toContain(AMBIENCE);
  });

  it('fails on an 11 MB file passed with --include', () => {
    withScratchFile(11 * MB, (file) => {
      const r = runCli(['--include', file]);
      expect(r.status).toBe(1);
      expect(r.stderr).toContain('scratch.bin');
    });
  });

  it('matches an included tracked file to its tracked path, however it is written', () => {
    const before = runCli();
    const r = runCli(['--include', join(ROOT, ...AMBIENCE.split('/'))]);
    expect(r.status, r.stderr).toBe(0);
    const count = (out) => out.match(/in (\d+) files/)[1];
    expect(count(r.stdout)).toBe(count(before.stdout));
  });

  it('explains a bad argument', () => {
    expect(runCli(['--include']).stderr).toContain('--include needs a file');
    expect(runCli(['--include', 'no/such/file.bin']).stderr).toContain('no such file');
    expect(runCli(['--bogus']).status).toBe(2);
  });
});
