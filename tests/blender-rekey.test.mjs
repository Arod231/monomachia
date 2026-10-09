// Tests for Claude's scripted re-keys (scripts/blender/rekey_clip.py,
// milestone-1 task 31): every spec in scripts/blender/rekeys/ is well formed
// and names a clip the clip manifest imports (the light string's cuts, its
// guard, task 33's transitions: the bridges between its hits and each
// light's return to guard, and task 34's deflect pairs: each light's recoil
// and the deflect aimed at it, and task 35's light hit reactions, turned
// for their side and lowered for low, and its light block; task 98's
// Moonsplitter: its sheathe and stance and its two draws, one-handed, each
// draw starting partway into its source as it blends in from the stance;
// KE task 16's Crescent Coil, led in by another pack clip's coil, and the
// loop its held charge plays, there and back over its own clip),
// and, where Blender is
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
    assert.deepEqual(specs.map((s) => s.id).sort(), [
      'backhand_rise', 'backhand_rise_to_katana_guard_1h', 'backhand_rise_to_twisting_rise', 'blasted_fall',
      'block_light', 'breaker_palm', 'crescent_coil', 'crescent_coil_hold', 'crouching_crown',
      'crouching_crown_to_katana_guard_1h', 'crown_cut', 'crown_cut_deflect', 'crown_cut_recoil',
      'crown_cut_to_guard', 'heaven_splitter', 'heaven_splitter_hold', 'heavy_slant', 'heavy_slant_to_guard',
      'hit_high_back', 'hit_high_front', 'hit_high_right', 'hit_low_back', 'hit_low_front', 'hit_low_right',
      'iai_draw_horizontal', 'iai_draw_horizontal_to_right_rise', 'iai_draw_horizontal_to_twisting_rise',
      'iai_draw_vertical', 'iai_resheathe_horizontal', 'iai_resheathe_horizontal_to_guard',
      'iai_resheathe_vertical', 'iai_resheathe_vertical_to_guard', 'iai_stance', 'iai_stance_hold',
      'katana_block_hit', 'katana_block_loop', 'katana_guard', 'katana_guard_1h', 'katana_guard_1h_to_katana_guard',
      'katana_guard_to_katana_guard_1h', 'kesa_cut', 'kesa_cut_deflect', 'kesa_cut_recoil', 'kesa_cut_to_crown_cut',
      'kesa_cut_to_guard', 'kneeling_crown', 'kneeling_crown_to_guard', 'leaping_cleave', 'left_rise',
      'left_rise_to_guard', 'left_rise_to_right_rise', 'level_cut', 'level_cut_to_crouching_crown',
      'level_cut_to_katana_guard_1h', 'lunging_cut', 'moonsplitter_draw_horizontal', 'moonsplitter_draw_vertical',
      'moonsplitter_stance', 'recall', 'return_cut', 'return_cut_deflect', 'return_cut_recoil',
      'return_cut_to_guard', 'return_cut_to_kesa_cut', 'returning_draw', 'right_cut', 'right_cut_deflect',
      'right_cut_recoil', 'right_cut_to_guard', 'right_cut_to_return_cut', 'right_rise', 'right_rise_to_guard',
      'right_rise_to_second_slant', 'rising_cut', 'rising_heaven', 'running_draw', 'second_slant',
      'second_slant_to_guard', 'second_slant_to_kneeling_crown', 'slanting_cut', 'slanting_cut_to_backhand_rise',
      'slanting_cut_to_katana_guard_1h', 'twisting_rise', 'twisting_rise_to_katana_guard_1h', 'ult_choice',
      'whirl_cut', 'wind_cut',
    ]);
  });

  for (const { id, spec } of specs) {
    describe(id, () => {
      const length = spec.remap.at(-1)[0];
      const transition = id.includes('_to_');
      const recoil = id.endsWith('_recoil');
      const deflect = id.endsWith('_deflect');
      // a held charge's loop, there and back over its move's own clip (KE task 16)
      const loop = Boolean(spec.loop);
      // an iai's sheathe and draws hold the sword in one hand (task 98; the Iai's own, KE task 18)
      const oneHanded = id.startsWith('moonsplitter_') || id.startsWith('iai_') || id.endsWith('_1h') || Boolean(spec.one_hand);
      // bare hands' ultimate and the burst's blasted fall hold nothing (task 99)
      const bare = ['ult_choice', 'recall', 'breaker_palm', 'blasted_fall'].includes(id);

      it('re-keys a pack clip, or for a transition a re-keyed clip, into its own Blender source', () => {
        if (transition) {
          const [from, to] = id.split('_to_');
          const into = to === 'guard' ? 'katana_guard' : to;
          assert.equal(spec.source, `blender/clips/${into}.blend`, 'carried into the clip it hands on to');
          assert.equal(spec.blend_from.source, `blender/clips/${from}.blend`, 'from the clip it follows');
          assert.ok(spec.blend_from.frames > 0 && spec.blend_from.frames <= length, 'blended in within the clip');
          assert.deepEqual(spec.remap, [[0, 0], [length, length]], 'its target at its own speed from its start');
        } else if (recoil) {
          const light = id.replace(/_recoil$/, '');
          assert.equal(spec.source, `blender/clips/${light}.blend`, 'its light up to the contact');
          const c = spec.knock.from;
          assert.deepEqual(spec.remap.at(-2), [c, c], 'the light as it is up to the contact');
          assert.equal(spec.remap.at(-1)[1], c, 'then held there, knocked back');
          assert.ok(spec.knock.toward < c, 'toward its cocked wind-up');
        } else if (loop) {
          assert.ok(id.endsWith('_hold'), 'a held charge\'s loop is named for its move');
          assert.equal(spec.source, `blender/clips/${id.replace(/_hold$/, '')}.blend`, 'over its move\'s own clip');
        } else {
          assert.match(spec.source, /^kevin_iglesias\/.+\.fbx$/);
          if (deflect) {
            const light = id.replace(/_deflect$/, '');
            assert.match(spec.source, /Parry1H01_[LR] - Hit\.fbx$/, 'a Parry1H01 hit');
            assert.equal(spec.two_hands.aim.at.source, `blender/clips/${light}_recoil.blend`, 'aimed at its light\'s recoil');
          }
        }
        assert.equal(spec.out, `blender/clips/${id}.blend`);
      });

      it('warps time from frame 0 (a lead\'s, for a led clip), rising in new frames and never falling in source frames', { skip: loop && 'a loop goes there and back' }, () => {
        // a clip blended in from another may start partway into its source,
        // and one that goes on from another's clip where that one ends in it;
        // a led clip starts its own source as the lead fades out
        if (spec.lead) {
          const lead = spec.lead.remap;
          assert.deepEqual(lead[0], [0, 0], 'the lead from its start');
          for (let i = 1; i < lead.length; i++) {
            assert.ok(lead[i][0] > lead[i - 1][0] && lead[i][1] >= lead[i - 1][1], `the lead rises at ${i}`);
          }
          assert.ok(spec.remap[0][0] > 0 && spec.remap[0][0] < lead.at(-1)[0], 'its own source fades in under the lead\'s end');
          assert.match(spec.lead.source, /^kevin_iglesias\/.+\.fbx$/, 'a pack clip leads');
        } else if (spec.blend_from && !transition) assert.equal(spec.remap[0][0], 0);
        else if (spec.goes_on_from) {
          const before = specs.find((s) => s.id === spec.goes_on_from)?.spec;
          assert.ok(before, `${spec.goes_on_from} is a spec`);
          assert.equal(before.source, spec.source, "the same source");
          assert.deepEqual(spec.remap[0], [0, before.remap.at(-1)[1]], "starting where it ends");
        } else if (spec.follows) {
          // one that only plays after another's clip may start partway into
          // its own source (KE task 14)
          assert.ok(specs.some((s) => s.id === spec.follows), `${spec.follows} is a spec`);
          assert.equal(spec.remap[0][0], 0);
        } else assert.deepEqual(spec.remap[0], [0, 0]);
        for (let i = 1; i < spec.remap.length; i++) {
          assert.ok(spec.remap[i][0] > spec.remap[i - 1][0], `new frames rise at ${i}`);
          assert.ok(spec.remap[i][1] >= spec.remap[i - 1][1], `source frames don't fall at ${i}`);
        }
      });

      it('loops: there and back from the frame its charge holds on to the same frame', { skip: !loop && 'not a loop' }, () => {
        assert.equal(spec.remap[0][0], 0);
        assert.equal(spec.remap.at(-1)[1], spec.remap[0][1], 'ends where it starts, so it loops without a pop');
        assert.ok(spec.remap.some(([, s]) => s !== spec.remap[0][1]), 'and moves in between');
        for (let i = 1; i < spec.remap.length; i++) assert.ok(spec.remap[i][0] > spec.remap[i - 1][0], `new frames rise at ${i}`);
      });

      it('puts both hands on the grip, clear of the body (a transition or a recoil carries its clips\' hands)', { skip: transition || recoil || loop || (oneHanded && 'one-handed: an iai or the one-handed grip') || (bare && 'bare hands') }, () => {
        assert.ok(spec.two_hands.grip > 0 && spec.two_hands.grip < 0.3);
        assert.equal(spec.two_hands.hold.length, 2);
        assert.ok(spec.two_hands.clearance >= 0.05, 'at least PoseCheck.BLADE_CLEARANCE');
      });

      it('steps forward and ends in the stance it started in', { skip: !spec.step && 'no step: the guard and the transitions keep their clips\' feet' }, () => {
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

      it('spins the body round from where it faces, never turning back (milestone-1 task 75)', { skip: !spec.spin && 'no spin' }, () => {
        assert.deepEqual(spec.spin[0], [0, 0], 'from where it faces at frame 0');
        for (let i = 1; i < spec.spin.length; i++) {
          assert.ok(spec.spin[i][0] > spec.spin[i - 1][0] && spec.spin[i][1] >= spec.spin[i - 1][1], `round one way at ${i}`);
        }
        assert.equal(spec.spin.at(-1)[0], length, 'the spin runs the whole clip');
        assert.equal(spec.spin.at(-1)[1] % 360, 0, 'facing as it started');
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

  it('fades a lead into its clip on a smootherstep, from all the lead to all the clip', { timeout: 300000 }, () => {
    const out = inBlender(`print(json.dumps([rk.lead_weight(i / 4.0, 10, 18) for i in range(0, 101)]))`);
    for (let i = 0; i <= 40; i++) assert.equal(out[i], 1, `all the lead to the clip's start (${i / 4})`);
    for (let i = 72; i <= 100; i++) assert.equal(out[i], 0, `none after the lead's end (${i / 4})`);
    assert.ok(Math.abs(out[56] - 0.5) < 1e-9, 'half way between');
    for (let i = 41; i <= 72; i++) assert.ok(out[i] <= out[i - 1], `never rising (${i / 4})`);
  });

  it('warps a loop there and back through its pairs', { timeout: 300000 }, () => {
    const pairs = [[0, 20], [12, 23], [24, 20]];
    const out = inBlender(`rk.check_remap(${JSON.stringify(pairs)}, loop=True)
f = rk.monotone(${JSON.stringify(pairs.map((p) => p[0]))}, ${JSON.stringify(pairs.map((p) => p[1]))})
print(json.dumps([f(i / 2.0) for i in range(49)]))`);
    for (const [x, y] of pairs) assert.ok(Math.abs(out[x * 2] - y) < 1e-9, `through (${x}, ${y})`);
    for (const v of out) assert.ok(v >= 20 - 1e-9 && v <= 23 + 1e-9, `inside the pairs (${v})`);
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

  it('steps a foot off the line by a step\'s fifth number, only while it is off the ground (milestone-1 task 90)', { timeout: 300000 }, () => {
    const out = inBlender(`print(json.dumps([[rk.foot_path([[2, 8, 0.1, 0.12, -0.2]], i / 20.0), rk.foot_path([[2, 8, 0.1, 0.12]], i / 20.0)] for i in range(201)]))`);
    assert.ok(Math.abs(out[0][0][2]) < 1e-9 && Math.abs(out.at(-1)[0][2] + 0.2) < 1e-9, '0.2 m to the left by the end');
    assert.ok(Math.abs(out.at(-1)[0][0] - 0.1) < 1e-9, 'and 0.1 m forward');
    for (let i = 1; i < out.length; i++) {
      if (Math.abs(out[i][0][2] - out[i - 1][0][2]) > 1e-9) assert.ok(out[i][0][1] > LIFT_HEIGHT, `off the ground while it moves at ${i / 20}`);
      assert.equal(out[i][1][2], 0, 'a four-number step stays on the line');
    }
  });

  it('moves a hand-shaped bone that many metres in the world, on the pack\'s armature scaled 0.01', { timeout: 300000 }, () => {
    const out = inBlender(`import bpy
arm = bpy.data.objects.new("a", bpy.data.armatures.new("a"))
bpy.context.scene.collection.objects.link(arm)
arm.scale = (0.01, 0.01, 0.01)
arm.rotation_euler = (1.5707963, 0, 0)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
b = arm.data.edit_bones.new("B-hips")
b.head, b.tail = (0, 0, 0), (0, 10, 0)
bpy.ops.object.mode_set(mode="POSE")
bpy.context.view_layer.update()
before = arm.matrix_world @ arm.pose.bones["B-hips"].head
rk.pose(arm, bpy.context.scene, [{"frame": 0, "move": {"B-hips": [0.1, 0.35, 0.2]}}])
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()
after = arm.matrix_world @ arm.pose.bones["B-hips"].head
print(json.dumps(list(after - before)))`);
    // the fighter faces -Y: right is -X, forward -Y
    assert.deepEqual(out.map((v) => +v.toFixed(4)), [-0.1, -0.2, 0.35]);
  });

  it('spins the hips about their own head, by its pairs on each frame (milestone-1 task 75)', { timeout: 300000 }, () => {
    const out = inBlender(`import bpy
arm = bpy.data.objects.new("a", bpy.data.armatures.new("a"))
bpy.context.scene.collection.objects.link(arm)
arm.scale = (0.01, 0.01, 0.01)
arm.rotation_euler = (1.5707963, 0, 0)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
b = arm.data.edit_bones.new("B-hips")
b.head, b.tail = (0, 90, 0), (0, 90, 20)
bpy.ops.object.mode_set(mode="POSE")
bpy.context.view_layer.update()
# keyed on every frame, as the time warp leaves a clip
for n in range(5):
    arm.pose.bones["B-hips"].keyframe_insert("rotation_quaternion", frame=1 + n)
    arm.pose.bones["B-hips"].keyframe_insert("location", frame=1 + n)
rk.spin(arm, bpy.context.scene, 4, [[0, 0], [2, 90], [4, 180]])
out = []
for n in range(5):
    bpy.context.scene.frame_set(1 + n)
    bpy.context.view_layer.update()
    pb = arm.pose.bones["B-hips"]
    h, t = arm.matrix_world @ pb.head, arm.matrix_world @ pb.tail
    out.append([list(h), list(t - h)])
print(json.dumps(out))`);
    const at = (v) => v.map((x) => +x.toFixed(4) + 0);
    for (const [h] of out) assert.deepEqual(at(h), at(out[0][0]), 'the hips stay where they stand');
    // the angle the hips have turned through from frame 0, about the vertical (world Z)
    const turned = (d) => Math.round(Math.acos((d[0] * out[0][1][0] + d[1] * out[0][1][1]) / Math.hypot(d[0], d[1]) / Math.hypot(out[0][1][0], out[0][1][1])) * 180 / Math.PI);
    assert.deepEqual(out.map(([, d]) => turned(d)).filter((_, n) => n % 2 === 0), [0, 90, 180], 'a quarter turn by frame 2, a half by frame 4');
    for (const [, d] of out) assert.ok(Math.abs(d[2] - out[0][1][2]) < 1e-6, 'about the vertical');
  });

  it('eases a hand-shaped pose in and out over its frames, held between', { timeout: 300000 }, () => {
    const out = inBlender(`import bpy
arm = bpy.data.objects.new("a", bpy.data.armatures.new("a"))
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
b = arm.data.edit_bones.new("B-hips")
b.head, b.tail = (0, 0, 0), (0, 1, 0)
bpy.ops.object.mode_set(mode="POSE")
rk.pose(arm, bpy.context.scene, [{"frames": [2, 6, 10, 14], "move": {"B-hips": [0.0, 1.0, 0.0]}}])
got = []
for n in range(17):
    bpy.context.scene.frame_set(1 + n)
    bpy.context.view_layer.update()
    got.append((arm.matrix_world @ arm.pose.bones["B-hips"].head).z)
print(json.dumps(got))`);
    for (const n of [0, 1, 2, 14, 15, 16]) assert.ok(Math.abs(out[n]) < 1e-6, `none outside its frames (${n}: ${out[n]})`);
    for (const n of [6, 8, 10]) assert.ok(Math.abs(out[n] - 1) < 1e-6, `all of it between (${n}: ${out[n]})`);
    assert.ok(Math.abs(out[4] - 0.5) < 1e-6 && Math.abs(out[12] - 0.5) < 1e-6, `half way in and out (${out[4]}, ${out[12]})`);
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
      if (spec.step) assert.match(r.stdout, /the body steps \d\.\d\d m forward/, id);
      if (spec.blend_from) assert.match(r.stdout, /blended in from the start pose over \d+ frames/, id);
      if (spec.knock) assert.match(r.stdout, /knocked back from frame/, id);
      if (spec.turn) assert.match(r.stdout, new RegExp(`turned the motion ${spec.turn} degrees`), id);
      if (spec.spin) assert.match(r.stdout, new RegExp(`spun the body ${spec.spin.at(-1)[1]} degrees`), id);
      if (spec.lower) assert.match(r.stdout, /lowered \d\.\d\d m/, id);
      if (spec.lead) assert.match(r.stdout, /led in by .+ over frames \d+-\d+/, id);
      if (spec.loop) assert.match(r.stdout, /looped there and back/, id);
      if (spec.carry) assert.match(r.stdout, /carried the body -?\d\.\d\d m forward/, id);
      if (spec.two_hands?.aim?.at) assert.match(r.stdout, /aimed at \d+% of the attacker's blade/, id);
      assert.doesNotMatch(r.stdout, /out of the leg's reach/, id);
    }
  });
});
