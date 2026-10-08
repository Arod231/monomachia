// Tests for the Cascadeur keying tools (scripts/cascadeur/, milestone-1 task
// 59): the committed rig template is the one make-template.mjs writes and
// maps every bone of the clips' skeleton but the props, the root, the spine
// proxy and the jaw; each clip spec in scripts/cascadeur/clips/ is well
// formed and names a clip the manifest imports; and the GLB pose reader
// places a bone by its parents and finds the gap between two clips.
// Cascadeur itself only runs on the owner's PC with its script server on, so
// nothing here talks to it.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { PARENTS, TEMPLATE, pathOf, template } from '../scripts/cascadeur/make-template.mjs';
import { gaps, poses } from '../scripts/cascadeur/glb-pose.mjs';

const ROOT = resolve(import.meta.dirname, '..');
const CLIPS = join(ROOT, 'scripts', 'cascadeur', 'clips');

describe('the rig template', () => {
  it('is the committed humanm.qrigcasc', () => {
    assert.equal(readFileSync(TEMPLATE, 'utf8'), JSON.stringify(template(), null, '\t') + '\n');
  });

  it('maps 51 bones: the body, arms, legs and three joints of each finger', () => {
    const names = template().Document.flatMap((d) => d.Sections.flatMap((s) => s.Names.map((n) => n['Joint name'])));
    assert.equal(names.length, 51);
    assert.equal(new Set(names).size, 51);
    for (const left of ['B-root', 'B-spineProxy', 'B-jaw', 'B-handProp.L', 'B-handProp.R']) assert.ok(!names.includes(left), left);
  });

  it('gives each joint its path from the root', () => {
    assert.deepEqual(pathOf('B-hand.R'), ['B-root', 'B-hips', 'B-spine', 'B-chest', 'B-shoulder.R', 'B-upperArm.R', 'B-forearm.R']);
    assert.deepEqual(pathOf('B-hips'), ['B-root']);
    assert.equal(PARENTS['B-thumb01.L'], 'B-hand.L');
  });
});

describe('the clip specs', () => {
  const manifest = JSON.parse(readFileSync(join(ROOT, 'game/assets/kevin_iglesias/clip_manifest.json'), 'utf8')).clips;
  const exports = new Set(Object.values(manifest).map((c) => c.export).filter(Boolean));
  for (const file of readdirSync(CLIPS).filter((f) => f.endsWith('.json'))) {
    it(`${file} is well formed and imported`, () => {
      const spec = JSON.parse(readFileSync(join(CLIPS, file), 'utf8'));
      const id = file.replace(/\.json$/, '');
      assert.equal(spec.out, `blender/clips/${id}.blend`);
      assert.ok(spec.about.length > 40, 'says what it is');
      assert.ok(spec.blockout.source && Array.isArray(spec.blockout.remap), 'a block-out to key from');
      assert.ok(!('out' in spec.blockout), 'the driver sets the block-out\'s out');
      const last = spec.blockout.remap.at(-1)[0];
      assert.equal(spec.keys[0], 0, 'keys its first frame');
      assert.equal(spec.keys.at(-1), last, 'and its last');
      assert.deepEqual([...spec.keys].sort((a, b) => a - b), spec.keys, 'in order');
      assert.ok(exports.has(`exports/clips/${id}.glb`), `the manifest imports exports/clips/${id}.glb`);
    });
  }
});

// A three-node GLB: an armature, a root bone and a child 1 m up the root's
// local Y, the root turning 90 degrees about Z over two frames at 30 fps.
function glb(turned) {
  const times = new Float32Array([0, 1 / 30]);
  const s = Math.SQRT1_2;
  const rot = new Float32Array(turned ? [0, 0, 0, 1, 0, 0, s, s] : [0, 0, 0, 1, 0, 0, 0, 1]);
  const bin = Buffer.concat([Buffer.from(times.buffer), Buffer.from(rot.buffer)]);
  const json = {
    asset: { version: '2.0' },
    nodes: [{ name: 'Armature', children: [1] }, { name: 'root', children: [2] }, { name: 'tip', translation: [0, 1, 0] }],
    buffers: [{ byteLength: bin.length }],
    bufferViews: [{ buffer: 0, byteOffset: 0, byteLength: 8 }, { buffer: 0, byteOffset: 8, byteLength: 32 }],
    accessors: [
      { bufferView: 0, componentType: 5126, count: 2, type: 'SCALAR', min: [0], max: [1 / 30] },
      { bufferView: 1, componentType: 5126, count: 2, type: 'VEC4' },
    ],
    animations: [{ channels: [{ sampler: 0, target: { node: 1, path: 'rotation' } }], samplers: [{ input: 0, output: 1, interpolation: 'LINEAR' }] }],
  };
  let text = JSON.stringify(json);
  while (text.length % 4) text += ' ';
  const head = Buffer.alloc(20);
  const total = 12 + 8 + text.length + 8 + bin.length;
  head.writeUInt32LE(0x46546c67, 0);
  head.writeUInt32LE(2, 4);
  head.writeUInt32LE(total, 8);
  head.writeUInt32LE(text.length, 12);
  head.writeUInt32LE(0x4e4f534a, 16);
  const binHead = Buffer.alloc(8);
  binHead.writeUInt32LE(bin.length, 0);
  binHead.writeUInt32LE(0x004e4942, 4);
  const dir = mkdtempSync(join(tmpdir(), 'glb-pose-'));
  const path = join(dir, turned ? 'turned.glb' : 'still.glb');
  writeFileSync(path, Buffer.concat([head, Buffer.from(text), binHead, bin]));
  return path;
}

describe('the GLB pose reader', () => {
  it('places a bone by its parents on each frame', () => {
    const p = poses(glb(true));
    assert.equal(p.frames, 2);
    assert.deepEqual(p.poses[0].tip.map((v) => +v.toFixed(6)), [0, 1, 0]);
    assert.deepEqual(p.poses[1].tip.map((v) => +v.toFixed(6)), [-1, 0, 0], 'turned 90 degrees about Z');
  });

  it('finds the largest gap per bone and its frame', () => {
    const g = gaps(poses(glb(false)), poses(glb(true)));
    assert.ok(Math.abs(g.tip.gap - Math.SQRT2) < 1e-6);
    assert.equal(g.tip.frame, 1);
    assert.equal(g.root.gap, 0);
  });
});
