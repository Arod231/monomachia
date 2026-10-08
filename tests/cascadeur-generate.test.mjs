// Tests for the clips made in Cascadeur by key poses and AI inbetweening
// (scripts/cascadeur/, milestone-1 task 89 on): every spec in
// scripts/cascadeur/clips/ is a well-formed block-out (a re-key spec for
// rekey_clip.py) with key poses inside it, writes its working files beside
// the other Cascadeur files and its clip among the clips, and names a clip
// the clip manifest imports; the driver's helpers build the script Cascadeur
// runs and keep its answer readable; the rig template maps our bones.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { cascadeurCode, shownMessages, SPECS, workFiles } from '../scripts/cascadeur/generate.mjs';

const ROOT = resolve(import.meta.dirname, '..');
// FootLock.LIFT_HEIGHT (game/view/fighter/foot_lock.gd): above it a foot is
// off the ground.
const LIFT_HEIGHT = 0.06;

const specs = readdirSync(SPECS)
  .filter((f) => f.endsWith('.json'))
  .map((f) => ({ id: f.replace(/\.json$/, ''), spec: JSON.parse(readFileSync(join(SPECS, f), 'utf8')) }));
const manifest = JSON.parse(readFileSync(join(ROOT, 'game', 'assets', 'kevin_iglesias', 'clip_manifest.json'), 'utf8'));
const exported = Object.values(manifest.clips ?? manifest).filter((c) => c && typeof c === 'object' && c.export);

describe('the Cascadeur clip specs', () => {
  it('has the clips made in Cascadeur', () => {
    assert.deepEqual(specs.map((s) => s.id).sort(), ['cross', 'hook', 'jab']);
  });

  for (const { id, spec } of specs) {
    describe(id, () => {
      const length = spec.remap.at(-1)[0];

      it('blocks out from a pack clip into the Cascadeur folder, its clip among the clips', () => {
        assert.match(spec.source, /^kevin_iglesias\/.+\.fbx$/);
        assert.equal(spec.out, `blender/cascadeur/${id}_keys.blend`);
        assert.equal(spec.clip, `blender/clips/${id}.blend`);
        assert.deepEqual(workFiles(id, spec), {
          keys: `blender/cascadeur/${id}_keys.blend`,
          keysGlb: `blender/cascadeur/${id}_keys.glb`,
          generated: `blender/cascadeur/${id}.glb`,
          casc: `blender/cascadeur/${id}.casc`,
          clip: `blender/clips/${id}.blend`,
        });
      });

      it('warps time from frame 0, rising in new frames and never falling in source frames', () => {
        assert.deepEqual(spec.remap[0], [0, 0]);
        assert.ok(Number.isInteger(length), 'a whole number of frames');
        for (let i = 1; i < spec.remap.length; i++) {
          assert.ok(spec.remap[i][0] > spec.remap[i - 1][0], `new frames rise at ${i}`);
          assert.ok(spec.remap[i][1] >= spec.remap[i - 1][1], `source frames don't fall at ${i}`);
        }
      });

      it('keeps 5 to 8 key poses on whole frames, the first and the last among them', () => {
        const k = spec.keys;
        assert.ok(k.length >= 5 && k.length <= 8, `${k.length} key poses`);
        assert.equal(k[0], 0);
        assert.equal(k.at(-1), length);
        for (let i = 0; i < k.length; i++) {
          assert.ok(Number.isInteger(k[i]), `key pose ${k[i]} on a whole frame`);
          if (i) assert.ok(k[i] > k[i - 1], 'in order');
        }
      });

      it('steps as far as the body goes, each foot lifted clear of the ground, and ends in its stance', () => {
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
        if (spec.step.hips_keep !== undefined) assert.ok(spec.step.hips_keep >= 0 && spec.step.hips_keep <= 1.5);
      });

      it('is a clip the manifest imports, its markers inside it', () => {
        const clip = exported.find((c) => c.export === `exports/clips/${id}.glb`);
        assert.ok(clip, `the manifest imports exports/clips/${id}.glb`);
        assert.ok(clip.markers.settle <= length);
        assert.ok(clip.foot_contacts?.left && clip.foot_contacts?.right, 'its foot contacts are measured');
      });
    });
  }
});

describe('the Cascadeur driver', () => {
  it('prepends the parameters to the script Cascadeur runs', () => {
    const code = cascadeurCode({ glb: 'a/b.glb', keys: [0, 4, 9] }, 'P = PARAMS\n');
    assert.equal(code, 'PARAMS = {"glb":"a/b.glb","keys":[0,4,9]}\nP = PARAMS\n');
  });

  it("shows the script's prints and errors, not the rig's refit warnings", () => {
    const shown = shownMessages({
      messages: [
        { level: 'Warning', text: 'Local position of B-head has changed after rig generation in frame 3' },
        { level: 'Info', text: 'generate_clip: 19 frames' },
        { level: 'Error', text: 'Traceback' },
        { level: 'Success', text: 'GLB/GLTF: Export: Success' },
      ],
    });
    assert.deepEqual(shown, ['Info: generate_clip: 19 frames', 'Error: Traceback']);
  });

  it('maps every body, arm, leg and finger bone of the rig template to an Iglesias bone with its parents', () => {
    const t = JSON.parse(readFileSync(join(ROOT, 'scripts', 'cascadeur', 'iglesias.qrigcasc'), 'utf8'));
    const names = t.Document.flatMap((d) => d.Sections.flatMap((s) => s.Names));
    assert.equal(names.length, 51, 'body 5, arms 8, legs 8, fingers 30');
    for (const n of names) {
      assert.match(n['Joint name'], /^B-/);
      assert.equal(n['Joint path'][0], 'B-root', `${n['Joint name']}'s path starts at the root`);
    }
    assert.deepEqual(names.filter((n) => n['Bone name'] === 'pelvis').map((n) => n['Joint name']), ['B-hips']);
  });
});
