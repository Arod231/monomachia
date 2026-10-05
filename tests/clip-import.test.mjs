// The clip import's round trip (milestone-1 task 13): a block-out clip keyed
// in Blender (scripts/blender/make_test_sources.py) goes through task 12's
// export and `node scripts/godot.mjs clips` into the clip libraries with no
// hand step, and two runs write the same bytes (the Godot check's item 3).
// Local-only: it needs Blender (and Godot), so it skips itself elsewhere, CI
// included. It works in a temporary asset repository and library, with a
// manifest of its own, so the real libraries are never touched.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { boneMapBones, exportBlend, findBlender } from '../scripts/blender/export.mjs';

const ROOT = resolve(import.meta.dirname, '..');
const BONES = boneMapBones(readFileSync(join(ROOT, 'game', 'assets', 'kevin_iglesias', 'iglesias_bone_map.tres'), 'utf8'));
// inside the gitignored staging folder, so Godot imports it like the real ones
const STAGING = 'res://assets/kevin_iglesias/staging/test_round_trip';
const MARKERS = { windup: 0, contact: 3, contact_end: 5, settle: 10 };

const blender = findBlender();

describe('an exported clip imported (local-only)', { skip: blender ? false : 'local-only: no Blender (BLENDER, PATH or .blender-path)' }, () => {
  it('round-trips the block-out clip from Blender into both libraries, the same bytes twice', { timeout: 900000 }, () => {
    const dir = mkdtempSync(join(tmpdir(), 'm1-clip-'));
    const staged = join(ROOT, 'game', 'assets', 'kevin_iglesias', 'staging', 'test_round_trip');
    try {
      const bonesFile = join(dir, 'bones.json');
      writeFileSync(bonesFile, JSON.stringify(BONES));
      const made = spawnSync(blender, ['-b', '--factory-startup', '--python-exit-code', '1', '--python', join(ROOT, 'scripts', 'blender', 'make_test_sources.py'), '--', dir, bonesFile], {
        encoding: 'utf8',
        timeout: 300000,
      });
      assert.equal(made.status, 0, made.stdout + made.stderr);
      const assets = join(dir, 'assets');
      mkdirSync(join(assets, 'exports', 'clips'), { recursive: true });
      const exported = exportBlend(blender, join(dir, 'block_out.blend'), 'clip', join(assets, 'exports', 'clips', 'block_out.glb'), BONES);
      assert.equal(exported.code, 0, exported.output);
      const manifest = join(dir, 'clip_manifest.json');
      const entry = { export: 'exports/clips/block_out.glb', groups: ['states'], markers: MARKERS, props: true };
      writeFileSync(
        manifest,
        JSON.stringify({
          sets: { HumanM: 'Male', HumanF: 'Female' },
          clips: {
            // a clip keyed from scratch: no pack clip behind it
            BlockOut: entry,
            // one replacing a pack clip, which stays its recorded origin
            BlockOutMirrored: { ...entry, pack: 'Human Basic Motions', dir: 'Movement', source: 'Idle01', mirror: true },
          },
        }),
      );
      const library = join(dir, 'library');
      const build = () => {
        const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'godot.mjs'), 'clips', `--manifest=${manifest}`, `--staging=${STAGING}`, `--library=${library}`], {
          cwd: ROOT,
          encoding: 'utf8',
          timeout: 600000,
          env: { ...process.env, MONOMACHIA_ASSETS_SRC: assets },
        });
        const output = r.stdout + r.stderr;
        assert.equal(r.status, 0, output);
        for (const set of ['HumanM', 'HumanF']) assert.match(output, new RegExp(`${set}: 2 clips`), output);
        return ['humanm', 'humanf'].map((s) => readFileSync(join(library, `iglesias_${s}.res`)));
      };
      const first = build();
      const second = build();
      for (const [i, bytes] of first.entries()) assert.ok(bytes.equals(second[i]), `library ${i}: two runs, the same bytes`);
      // each clip's tracks, as Godot reads the library
      const dump = join(dir, 'dump.gd');
      writeFileSync(
        dump,
        'extends SceneTree\nfunc _initialize() -> void:\n\tvar lib: AnimationLibrary = load(OS.get_cmdline_user_args()[0])\n' +
          '\tfor a: StringName in lib.get_animation_list():\n\t\tvar anim: Animation = lib.get_animation(a)\n' +
          '\t\tfor t: int in anim.get_track_count():\n\t\t\tprint("track %s %s" % [a, anim.track_get_path(t)])\n\tquit(0)\n',
      );
      const listed = spawnSync(process.execPath, [join(ROOT, 'scripts', 'godot.mjs'), 'script', dump, '--', join(library, 'iglesias_humanm.res')], { cwd: ROOT, encoding: 'utf8', timeout: 300000 });
      assert.equal(listed.status, 0, listed.stdout + listed.stderr);
      const tracks = (clip) => [...listed.stdout.matchAll(new RegExp(`^track ${clip} (\\S+)`, 'gm'))].map((m) => m[1]);
      assert.deepEqual(tracks('BlockOut').filter((p) => !p.includes('Prop')), ['%GeneralSkeleton:Hips', '%GeneralSkeleton:RightUpperArm'], 'retargeted onto the profile bones');
      assert.ok(tracks('BlockOut').includes('%GeneralSkeleton:B-handProp.R'), 'the prop kept');
      assert.ok(tracks('BlockOutMirrored').includes('%GeneralSkeleton:LeftUpperArm'), 'mirrored');
      assert.ok(tracks('BlockOutMirrored').includes('%GeneralSkeleton:B-handProp.L'), 'the prop mirrored onto the other hand');
    } finally {
      rmSync(dir, { recursive: true, force: true });
      rmSync(staged, { recursive: true, force: true });
    }
  });
});
