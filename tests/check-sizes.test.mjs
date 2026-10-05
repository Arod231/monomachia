// Tests for scripts/check-sizes.mjs, the guard that keeps large files out of
// the repo (no tracked file over 10 MB unless it is allow-listed) and holds
// the public repository to its budgets (milestone-1 task 8): the committed
// game art under 150 MB, the committed audio under 40 MB.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import {
  ALLOWED, ART_BUDGET_BYTES, AUDIO_BUDGET_BYTES, LIMIT_BYTES, budgets, findOverBudget, findOversize, isArt, isAudio, repoPath, totalBytes,
} from '../scripts/check-sizes.mjs';

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

describe('the budgets', () => {
  it("are the spec's size budget table: 150 MB of art and 40 MB of audio", () => {
    assert.equal(ART_BUDGET_BYTES, 150 * MB);
    assert.equal(AUDIO_BUDGET_BYTES, 40 * MB);
  });

  it('count as art what game/assets holds but the audio, and the baked art beside it', () => {
    for (const path of [
      'game/assets/quaternius/characters/body.gltf',
      'game/assets/weapons/katana.glb',
      'game/assets/authored/keys/stomp.json',
      'game/fighters/hunter/palette_0.png',
      'game/weapons/katana/blade.res',
      'game/fighters/rogue/skin.exr',
    ]) assert.equal(isArt(path), true, path);
    for (const path of [
      'game/assets/audio/sfx/hit.wav',
      'game/fighters/hunter/hunter.tscn',
      'game/weapons/katana/katana.gd',
      'game/sim/moves/katana.gd',
      'docs/screenshots/select.png',
      'C:/elsewhere/game/assets/x.png',
    ]) assert.equal(isArt(path), false, path);
  });

  it('count as audio everything under game/assets/audio', () => {
    assert.equal(isAudio('game/assets/audio/music/shrine.wav'), true);
    assert.equal(isAudio('game/assets/audio/SOURCES.md'), true);
    assert.equal(isAudio('game/assets/audiobook.png'), false);
  });

  it('add up each place', () => {
    const files = [
      { path: 'game/assets/a.png', bytes: 3 },
      { path: 'game/fighters/h/p.png', bytes: 4 },
      { path: 'game/fighters/h/h.tscn', bytes: 100 },
      { path: 'game/assets/audio/sfx/b.wav', bytes: 5 },
      { path: 'README.md', bytes: 1000 },
    ];
    assert.deepEqual(budgets(files), [
      { name: 'committed game art', bytes: 7, limit: ART_BUDGET_BYTES },
      { name: 'committed audio', bytes: 5, limit: AUDIO_BUDGET_BYTES },
    ]);
  });

  it('pass a place up to its budget and fail it one byte over', () => {
    const at = [{ path: 'game/assets/art.bin', bytes: 150 * MB }, { path: 'game/assets/audio/a.wav', bytes: 40 * MB }];
    assert.deepEqual(findOverBudget(at), []);
    const artOver = [{ path: 'game/assets/art.bin', bytes: 150 * MB }, { path: 'game/weapons/k/m.res', bytes: 1 }];
    assert.deepEqual(findOverBudget(artOver).map((b) => b.name), ['committed game art']);
    const audioOver = [{ path: 'game/assets/audio/a.wav', bytes: 40 * MB + 1 }];
    assert.deepEqual(findOverBudget(audioOver).map((b) => b.name), ['committed audio']);
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
    assert.match(r.stdout, /committed game art: \d+\.\d MB of a 150\.0 MB budget/);
    assert.match(r.stdout, /committed audio: \d+\.\d MB of a 40\.0 MB budget/);
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
