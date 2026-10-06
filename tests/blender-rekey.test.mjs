// Tests for Claude's scripted re-keys (scripts/blender/rekey_clip.py,
// milestone-1 task 31): every spec in scripts/blender/rekeys/ is well formed
// and names a clip the clip manifest imports, and, where Blender is
// installed (local-only, skipped elsewhere, CI included), the script's time
// warp and steps behave: the warp passes through its pairs without falling or
// overshooting, a stepping foot moves only while it is off the ground, and
// each spec re-keys from the asset repository to its length.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { findBlender } from '../scripts/blender/export.mjs';

const ROOT = resolve(import.meta.dirname, '..');
const SCRIPT = join(ROOT, 'scripts', 'blender', 'rekey_clip.py');
const SPECS = join(ROOT, 'scripts', 'blender', 'rekeys');
// FootLock.LIFT_HEIGHT (game/view/fighter/foot_lock.gd): above it a foot is
// off the ground.
const LIFT_HEIGHT = 0.06;

const specs = readdirSync(SPECS)
  .filter((f) => f.endsWith('.json'))
  .map((f) => ({ id: f.replace(/\.json$/, ''), spec: JSON.parse(readFileSync(join(SPECS, f), 'utf8')) }));
const manifest = JSON.parse(readFileSync(join(ROOT, 'game', 'assets', 'kevin_iglesias', 'clip_manifest.json'), 'utf8'));
const exported = Object.values(manifest.clips ?? manifest).filter((c) => c && typeof c === 'object' && c.export);

describe('the re-key specs', () => {
  it('has the re-keyed clips', () => {
    assert.deepEqual(specs.map((s) => s.id).sort(), ['return_cut', 'right_cut']);
  });

  for (const { id, spec } of specs) {
    describe(id, () => {
      const length = spec.remap.at(-1)[0];

      it('re-keys a pack clip into its own Blender source', () => {
        assert.match(spec.source, /^kevin_iglesias\/.+\.fbx$/);
        assert.equal(spec.out, `blender/clips/${id}.blend`);
      });

      it('warps time from frame 0, rising in new frames and never falling in source frames', () => {
        assert.deepEqual(spec.remap[0], [0, 0]);
        for (let i = 1; i < spec.remap.length; i++) {
          assert.ok(spec.remap[i][0] > spec.remap[i - 1][0], `new frames rise at ${i}`);
          assert.ok(spec.remap[i][1] >= spec.remap[i - 1][1], `source frames don't fall at ${i}`);
        }
      });

      it('puts both hands on the grip, clear of the body', () => {
        assert.ok(spec.two_hands.grip > 0 && spec.two_hands.grip < 0.3);
        assert.equal(spec.two_hands.hold.length, 2);
        assert.ok(spec.two_hands.clearance >= 0.05, 'at least PoseCheck.BLADE_CLEARANCE');
      });

      it('steps forward and ends in the stance it started in', () => {
        const { body, feet } = spec.step;
        assert.deepEqual(body[0], [0, 0]);
        for (let i = 1; i < body.length; i++) {
          assert.ok(body[i][0] > body[i - 1][0] && body[i][1] >= body[i - 1][1], `the body goes forward at ${i}`);
        }
        assert.equal(body.at(-1)[0], length, 'the body path runs the whole clip');
        const went = body.at(-1)[1];
        for (const side of ['L', 'R']) {
          let sum = 0;
          for (const [from, to, metres, lift] of feet[side]) {
            assert.ok(from >= 0 && to > from && to <= length, `${side} steps inside the clip`);
            assert.ok(lift > LIFT_HEIGHT, `${side} lifts clear of the ground`);
            sum += metres;
          }
          assert.ok(Math.abs(sum - went) < 1e-9, `${side} foot steps as far as the body goes (${sum} vs ${went})`);
        }
      });

      it('is a clip the manifest imports, its markers inside it', () => {
        const clip = exported.find((c) => c.export === `exports/clips/${id}.glb`);
        assert.ok(clip, `the manifest imports exports/clips/${id}.glb`);
        assert.ok(clip.markers.settle <= length);
        assert.ok(clip.foot_contacts, 'its foot contacts are measured');
      });
    });
  }
});

const blender = findBlender();

// Runs `code` in Blender with the script loaded as a module (so it doesn't
// re-key) as `rk`; returns what it prints as JSON on its last line.
const inBlender = (code) => {
  const expr = [
    'import importlib.util, json, sys',
    'sys.dont_write_bytecode = True',
    `s = importlib.util.spec_from_file_location("rekey_clip", ${JSON.stringify(SCRIPT)})`,
    'rk = importlib.util.module_from_spec(s)',
    's.loader.exec_module(rk)',
    code,
  ].join('\n');
  const r = spawnSync(blender, ['-b', '--factory-startup', '--python-exit-code', '1', '--python-expr', expr], { encoding: 'utf8', timeout: 300000 });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  const last = r.stdout.trim().split('\n').filter((l) => l.startsWith('{') || l.startsWith('[')).at(-1);
  return JSON.parse(last);
};

describe('the re-key in Blender (local-only)', { skip: blender ? false : 'local-only: no Blender (BLENDER, PATH or .blender-path)' }, () => {
  it('warps time through its pairs, holding where a source frame repeats, never falling or overshooting', { timeout: 300000 }, () => {
    const pairs = [[0, 0], [9, 4], [10.5, 4], [14, 8], [16, 9.5], [30, 20], [43, 33]];
    const out = inBlender(`f = rk.monotone(${JSON.stringify(pairs.map((p) => p[0]))}, ${JSON.stringify(pairs.map((p) => p[1]))})
print(json.dumps([f(i / 10.0) for i in range(431)]))`);
    for (const [x, y] of pairs) assert.ok(Math.abs(out[x * 10] - y) < 1e-9, `through (${x}, ${y})`);
    for (let i = 1; i < out.length; i++) assert.ok(out[i] >= out[i - 1] - 1e-12, `never falls at ${i / 10}`);
    for (let i = 90; i <= 105; i++) assert.ok(Math.abs(out[i] - 4) < 1e-9, `holds at ${i / 10}`);
  });

  it('moves a stepping foot only while it is off the ground, and sets it down as far as it steps', { timeout: 300000 }, () => {
    for (const steps of [[[10, 15, 1.35, 0.2]], [[1, 5, 0.3, 0.16], [6, 14, 0.775, 0.24]]]) {
      const out = inBlender(`print(json.dumps([rk.foot_path(${JSON.stringify(steps)}, i / 20.0) for i in range(401)]))`);
      const total = steps.reduce((a, s) => a + s[2], 0);
      assert.ok(Math.abs(out[0][0]) < 1e-9 && Math.abs(out.at(-1)[0] - total) < 1e-9, 'from where it stands to where it lands');
      assert.equal(out.at(-1)[1], 0, 'down at the end');
      for (let i = 1; i < out.length; i++) {
        if (Math.abs(out[i][0] - out[i - 1][0]) > 1e-9) {
          assert.ok(out[i - 1][1] > LIFT_HEIGHT && out[i][1] > LIFT_HEIGHT, `off the ground while it moves at ${i / 20} (${out[i][1]})`);
        }
      }
    }
  });

  const assets = existsSync(join(ROOT, '.assets-src-path')) ? readFileSync(join(ROOT, '.assets-src-path'), 'utf8').trim() : '';
  it('re-keys each spec from the asset repository to its length', { skip: assets && existsSync(assets) ? false : 'local-only: no asset repository (.assets-src-path)', timeout: 900000 }, () => {
    for (const { id, spec } of specs) {
      const r = spawnSync(blender, ['-b', '--factory-startup', '--python-exit-code', '1', '--python', SCRIPT, '--', '--spec', join(SPECS, `${id}.json`), '--assets', assets, '--check'], {
        encoding: 'utf8',
        timeout: 600000,
      });
      assert.equal(r.status, 0, r.stdout + r.stderr);
      const length = spec.remap.at(-1)[0];
      assert.match(r.stdout, new RegExp(`-> ${length + 1} frames \\(${length} long\\)`), id);
      assert.match(r.stdout, /the body steps \d\.\d\d m forward/, id);
    }
  });
});
