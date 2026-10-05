// Tests for scripts/check-sizes.mjs, the guard that keeps large files out of
// the repo (no tracked file over 10 MB unless it is allow-listed).

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
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
    assert.equal(LIMIT_BYTES, 10 * MB);
    assert.deepEqual(findOversize([{ path: 'a.png', bytes: 10 * MB }, { path: 'b.wav', bytes: 1 }]), []);
  });

  it('reports a file over the limit', () => {
    const files = [{ path: 'game/assets/big.wav', bytes: 11 * MB }, { path: 'small.png', bytes: 5 }];
    assert.deepEqual(findOversize(files), [{ path: 'game/assets/big.wav', bytes: 11 * MB }]);
  });

  it('lets every allow-listed file through', () => {
    for (const path of ALLOWED) assert.deepEqual(findOversize([{ path, bytes: 11 * MB }]), []);
  });
});

describe('totalBytes', () => {
  it('adds up the files under a folder, or all of them', () => {
    const files = [
      { path: 'game/assets/a.png', bytes: 3 },
      { path: 'game/assets/audio/b.wav', bytes: 4 },
      { path: 'game/fighters/c.png', bytes: 5 },
    ];
    assert.equal(totalBytes(files, 'game/assets'), 7);
    assert.equal(totalBytes(files), 12);
  });
});

describe('repoPath', () => {
  it('writes paths inside the repo relative, with forward slashes', () => {
    assert.equal(repoPath(join(ROOT, 'game', 'assets', 'x.wav'), ROOT), 'game/assets/x.wav');
  });
});

describe('the command', () => {
  it('passes on the repo, allowing the ambience loop, and prints the sizes', () => {
    const r = runCli();
    assert.equal(r.status, 0, r.stderr);
    for (const folder of ['game/assets', 'game/assets/audio', 'game/fighters', 'game/weapons']) {
      assert.match(r.stdout, new RegExp(`${folder}: \\d+\\.\\d MB`));
    }
    assert.match(r.stdout, /all tracked files: \d+\.\d MB/);
    assert.ok(!r.stdout.includes(AMBIENCE));
  });

  it('fails on an 11 MB file passed with --include', () => {
    withScratchFile(11 * MB, (file) => {
      const r = runCli(['--include', file]);
      assert.equal(r.status, 1);
      assert.ok(r.stderr.includes('scratch.bin'));
    });
  });

  it('matches an included tracked file to its tracked path, however it is written', () => {
    const before = runCli();
    const r = runCli(['--include', join(ROOT, ...AMBIENCE.split('/'))]);
    assert.equal(r.status, 0, r.stderr);
    const count = (out) => out.match(/in (\d+) files/)[1];
    assert.equal(count(r.stdout), count(before.stdout));
  });

  it('explains a bad argument', () => {
    assert.ok(runCli(['--include']).stderr.includes('--include needs a file'));
    assert.ok(runCli(['--include', 'no/such/file.bin']).stderr.includes('no such file'));
    assert.equal(runCli(['--bogus']).status, 2);
  });
});
