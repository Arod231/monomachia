// Tests for the Blender export (scripts/blender/export.mjs, milestone-1 task
// 12): sources.json, the bone list, the record, the copy's budget, and, where
// Blender is installed (local-only, skipped elsewhere, CI included), a
// block-out clip and a box model built by scripts/blender/make_test_sources.py
// exported twice to the same bytes, its keys from 0 s whatever frame its
// source starts on, and a clip without the Iglesias rig refused.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import {
  REFUSED,
  bodyGltf,
  boneMapBones,
  copyRefusal,
  exportBlend,
  exportPath,
  findBlender,
  readSources,
  recordText,
  run,
  sha256,
} from '../scripts/blender/export.mjs';
import { ART_BUDGET_BYTES } from '../scripts/check-sizes.mjs';

const ROOT = resolve(import.meta.dirname, '..');
const MB = 1024 * 1024;
const BONES = boneMapBones(readFileSync(join(ROOT, 'game', 'assets', 'kevin_iglesias', 'iglesias_bone_map.tres'), 'utf8'));
const UAL_BONES = boneMapBones(readFileSync(join(ROOT, 'game', 'assets', 'quaternius', 'ual_bone_map.tres'), 'utf8'));

describe('sources.json', () => {
  it('reads each source with its kind from its folder', () => {
    const { sources, errors } = readSources(
      JSON.stringify({
        sources: {
          katana: { file: 'weapons/katana.blend', licence: 'own', game: 'game/assets/exports/weapons/katana.glb' },
          k_l1_rekey: { file: 'clips/k_l1_rekey.blend', licence: 'iglesias' },
          hunter: { file: 'fighters/hunter.blend', licence: 'cc0' },
        },
      }),
    );
    assert.deepEqual(errors, []);
    assert.equal(sources.katana.kind, 'weapon');
    assert.equal(sources.katana.game, 'game/assets/exports/weapons/katana.glb');
    assert.equal(sources.k_l1_rekey.kind, 'clip');
    assert.equal(sources.k_l1_rekey.game, null);
    assert.equal(sources.hunter.kind, 'fighter');
    assert.equal(exportPath('katana', sources.katana), 'exports/weapons/katana.glb');
  });

  it('names every mistake', () => {
    const { errors } = readSources(
      JSON.stringify({
        sources: {
          'Bad-Id': { file: 'weapons/a.blend', licence: 'own' },
          loose: { file: 'a.blend', licence: 'own' },
          pack: { file: 'weapons/a.blend', licence: 'unity' },
          clip_out: { file: 'clips/a.blend', licence: 'own', game: 'game/assets/exports/clips/a.glb' },
          paid_out: { file: 'fighters/a.blend', licence: 'iglesias', game: 'game/assets/exports/a.glb' },
          elsewhere: { file: 'shrine/a.blend', licence: 'cc0', game: 'game/fighters/a.glb' },
          extra: { file: 'shrine/b.blend', licence: 'cc0', size: 3 },
        },
      }),
    );
    assert.deepEqual(errors, [
      'Bad-Id: an id is lower-case letters, digits and underscores',
      'loose: file must be a .blend in clips/, fighters/, weapons/, shrine/, bodies/',
      'pack: licence must be own, cc0, iglesias',
      'clip_out: a clip export stays in the asset repository (no game path)',
      'paid_out: only self-made and CC0 art is copied into the game',
      'elsewhere: game must be a .glb path under game/assets/',
      'extra: unknown field size',
    ]);
    assert.deepEqual(readSources('{').errors.length, 1);
    assert.deepEqual(readSources('{}').errors, ['sources.json has no "sources" object']);
  });
});

describe('a body part (KE task 3)', () => {
  const part = {
    file: 'bodies/hunter/Male_Ranger_Body.blend',
    licence: 'cc0',
    game: 'game/assets/quaternius/outfits/Male_Ranger_Body_Tall.gltf',
    materials_from: 'game/assets/quaternius/outfits/Male_Ranger_Body.gltf',
  };

  it('is a glTF beside the original part whose materials it keeps', () => {
    const { sources, errors } = readSources(JSON.stringify({ sources: { male_ranger_body: part } }));
    assert.deepEqual(errors, []);
    assert.equal(sources.male_ranger_body.kind, 'body');
    assert.equal(sources.male_ranger_body.materials_from, part.materials_from);
    assert.equal(exportPath('male_ranger_body', sources.male_ranger_body), 'exports/bodies/male_ranger_body.gltf');
  });

  it('names its mistakes', () => {
    const { errors } = readSources(
      JSON.stringify({
        sources: {
          a_glb: { ...part, game: 'game/assets/quaternius/outfits/A.glb' },
          no_materials: { ...part, materials_from: undefined },
          paid: { ...part, licence: 'iglesias' },
          weapon_from: { file: 'weapons/a.blend', licence: 'own', game: 'game/assets/a.glb', materials_from: part.materials_from },
        },
      }),
    );
    assert.deepEqual(errors, [
      'a_glb: a body part goes into the game as a .gltf under game/assets/',
      'no_materials: a body part names the part whose materials it keeps (materials_from, a .gltf under game/assets/)',
      'paid: only self-made and CC0 art is copied into the game',
      "weapon_from: only a body part keeps another part's materials",
    ]);
  });

  it("is rigged on the Quaternius skeleton's bones", () => {
    for (const b of ['root', 'pelvis', 'clavicle_l', 'Head', 'foot_r']) assert.ok(UAL_BONES.includes(b), b);
  });

  it("keeps the original's materials, textures and images, each primitive's by name, and names its buffer", () => {
    const exported = {
      asset: { version: '2.0' },
      materials: [{ name: 'MI_Ranger', pbrMetallicRoughness: {} }, { name: 'MI_Belt' }, { name: 'MI_Ranger.001' }],
      meshes: [{ name: 'Body', primitives: [{ material: 1 }, { material: 0 }, {}, { material: 2 }] }],
      buffers: [{ uri: 'male_ranger_body.bin', byteLength: 8 }],
      extensionsUsed: ['KHR_materials_specular'],
    };
    const original = {
      asset: { version: '2.0' },
      materials: [{ name: 'MI_Belt', extra: 1 }, { name: 'MI_Ranger', extra: 2 }],
      textures: [{ source: 0 }],
      images: [{ uri: 'T_Ranger_3_BaseColor.png' }],
      samplers: [{}],
      extensionsUsed: ['KHR_texture_transform'],
    };
    const out = JSON.parse(bodyGltf(exported, original, 'Male_Ranger_Body_Tall.bin'));
    assert.deepEqual(out.materials, original.materials);
    assert.deepEqual([out.textures, out.images, out.samplers], [original.textures, original.images, original.samplers]);
    assert.deepEqual(out.meshes[0].primitives.map((p) => p.material), [0, 1, undefined, 1], "MI_Belt, MI_Ranger, none, and MI_Ranger again (Blender's .001)");
    assert.equal(out.buffers[0].uri, 'Male_Ranger_Body_Tall.bin');
    assert.deepEqual(out.extensionsUsed, ['KHR_texture_transform']);
    assert.equal(bodyGltf(exported, original, 'Male_Ranger_Body_Tall.bin'), bodyGltf(exported, original, 'Male_Ranger_Body_Tall.bin'), 'the same text twice');
    assert.throws(() => bodyGltf({ ...exported, materials: [{ name: 'MI_Ranger' }, { name: 'MI_Other' }] }, original, 'x.bin'), /MI_Other/);
  });
});

describe('the export', () => {
  it("requires the bone map's Kevin Iglesias bones", () => {
    assert.equal(BONES.length, 52);
    for (const b of ['B-root', 'B-hips', 'B-hand.R', 'B-foot.L']) assert.ok(BONES.includes(b), b);
    assert.ok(BONES.every((b) => b.startsWith('B-')));
  });

  it('records the source, both checksums and the licence beside an export', () => {
    const source = { file: 'weapons/katana.blend', folder: 'weapons', kind: 'weapon', licence: 'own', game: null };
    const text = recordText('katana', source, Buffer.from('blend'), Buffer.from('glb'), 'Blender 5.2.2 LTS');
    assert.deepEqual(JSON.parse(text), {
      id: 'katana',
      source: 'blender/weapons/katana.blend',
      source_sha256: sha256(Buffer.from('blend')),
      export_sha256: sha256(Buffer.from('glb')),
      licence: 'own',
      kind: 'weapon',
      blender: 'Blender 5.2.2 LTS',
    });
    assert.equal(text, recordText('katana', source, Buffer.from('blend'), Buffer.from('glb'), 'Blender 5.2.2 LTS'), 'the same record twice');
  });

  it("copies into the game only inside task 8's budgets", () => {
    const files = [
      { path: 'game/assets/big.glb', bytes: 595 * MB },
      { path: 'game/assets/audio/music/a.wav', bytes: 39 * MB },
    ];
    assert.equal(copyRefusal(files, 'game/assets/exports/weapons/katana.glb', 2 * MB), null, 'fits');
    assert.match(copyRefusal(files, 'game/assets/exports/weapons/katana.glb', 6 * MB), /committed game art to 601\.0 MB, over its budget/);
    assert.match(copyRefusal([], 'game/assets/exports/shrine/hall.glb', 61 * MB), /over the 60 MB a file/);
    assert.equal(copyRefusal([{ path: 'game/assets/exports/a.glb', bytes: 45 * MB }, { path: 'game/assets/big.glb', bytes: 550 * MB }], 'game/assets/exports/a.glb', 48 * MB), null, 'a copy replaces its old file');
  });

  it('finds Blender from BLENDER first', () => {
    assert.equal(findBlender({ BLENDER: 'C:/b/blender.exe', PATH: '' }), 'C:/b/blender.exe');
  });
});

/** Every animation sampler's first and last key time in a GLB, in seconds. */
function keyTimes(glb) {
  const jsonLength = glb.readUInt32LE(12);
  const gltf = JSON.parse(glb.subarray(20, 20 + jsonLength).toString('utf8'));
  return gltf.animations.flatMap((a) => a.samplers.map((s) => {
    const accessor = gltf.accessors[s.input];
    return [accessor.min[0], accessor.max[0]];
  }));
}

const blender = findBlender();

describe('the export in Blender (local-only)', { skip: blender ? false : 'local-only: no Blender (BLENDER, PATH or .blender-path)' }, () => {
  const make = (folder) => {
    const bonesFile = join(folder, 'bones.json');
    writeFileSync(bonesFile, JSON.stringify(BONES));
    const r = spawnSync(blender, ['-b', '--factory-startup', '--python-exit-code', '1', '--python', join(ROOT, 'scripts', 'blender', 'make_test_sources.py'), '--', folder, bonesFile], {
      encoding: 'utf8',
      timeout: 300000,
    });
    assert.equal(r.status, 0, r.stdout + r.stderr);
  };

  it('exports a block-out clip and a box model to the same bytes twice, and refuses a clip without the rig', { timeout: 600000 }, () => {
    const dir = mkdtempSync(join(tmpdir(), 'm1-blend-'));
    try {
      make(dir);
      for (const [name, kind] of [['block_out', 'clip'], ['box', 'weapon']]) {
        const outs = [1, 2].map((n) => join(dir, `${name}_${n}.glb`));
        for (const out of outs) assert.equal(exportBlend(blender, join(dir, `${name}.blend`), kind, out, BONES).code, 0, name);
        assert.ok(readFileSync(outs[0]).length > 0);
        assert.ok(readFileSync(outs[0]).equals(readFileSync(outs[1])), `${name}: two runs, the same bytes`);
        assert.equal(readFileSync(outs[0]).subarray(0, 4).toString(), 'glTF', `${name}: a GLB`);
      }
      // keyed over 10 frames from Blender frame 0, and from frame 1 as
      // rekey_clip.py keys its sources: both play from 0 s for 10/30 s, with
      // no held first frame in front
      for (const name of ['block_out', 'block_out_from_1']) {
        const out = join(dir, `${name}_times.glb`);
        assert.equal(exportBlend(blender, join(dir, `${name}.blend`), 'clip', out, BONES).code, 0, name);
        const times = keyTimes(readFileSync(out));
        assert.ok(times.length > 0, `${name}: animated`);
        for (const [first, last] of times) {
          assert.equal(first, 0, `${name}: the first key at 0 s`);
          assert.ok(Math.abs(last - 10 / 30) < 1e-6, `${name}: the last key at 10/30 s, not ${last}`);
        }
      }
      const none = exportBlend(blender, join(dir, 'no_rig.blend'), 'clip', join(dir, 'no_rig.glb'), BONES);
      assert.equal(none.code, REFUSED);
      assert.match(none.output, /refused: no armature/);
      assert.equal(existsSync(join(dir, 'no_rig.glb')), false);
      const short = exportBlend(blender, join(dir, 'block_out.blend'), 'clip', join(dir, 'short.glb'), [...BONES, 'B-tail']);
      assert.equal(short.code, REFUSED);
      assert.match(short.output, /lacks the Kevin Iglesias rig's bones B-tail/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('runs over sources.json: writes each export and its record, copies the model into the game, and checks', { timeout: 600000 }, () => {
    const dir = mkdtempSync(join(tmpdir(), 'm1-blend-'));
    try {
      const assets = join(dir, 'assets');
      const game = join(dir, 'game-repo');
      for (const f of ['clips', 'weapons']) mkdirSync(join(assets, 'blender', f), { recursive: true });
      make(join(assets, 'blender', 'clips'));
      // a model sits in weapons/: put the box there
      writeFileSync(join(assets, 'blender', 'weapons', 'box.blend'), readFileSync(join(assets, 'blender', 'clips', 'box.blend')));
      writeFileSync(
        join(assets, 'blender', 'sources.json'),
        JSON.stringify({
          sources: {
            block_out: { file: 'clips/block_out.blend', licence: 'own' },
            box: { file: 'weapons/box.blend', licence: 'cc0', game: 'game/assets/exports/weapons/box.glb' },
          },
        }),
      );
      const first = run({ blender, assets, root: game, files: [] });
      assert.equal(first.code, 0, first.lines.join('\n'));
      for (const p of ['exports/clips/block_out.glb', 'exports/weapons/box.glb']) {
        assert.ok(existsSync(join(assets, p)), p);
        const record = JSON.parse(readFileSync(join(assets, `${p}.json`), 'utf8'));
        assert.equal(record.export_sha256, sha256(readFileSync(join(assets, p))));
      }
      assert.ok(readFileSync(join(game, 'game/assets/exports/weapons/box.glb')).equals(readFileSync(join(assets, 'exports/weapons/box.glb'))), 'the model copied');
      assert.equal(existsSync(join(game, 'game/assets/exports/clips')), false, 'the clip stays in the asset repository');
      const check = run({ blender, assets, root: game, check: true, files: [] });
      assert.equal(check.code, 0, check.lines.join('\n'));
      const full = run({ blender, assets, root: join(dir, 'other-game'), files: [{ path: 'game/assets/big.glb', bytes: ART_BUDGET_BYTES }] });
      assert.equal(full.code, 1);
      assert.match(full.lines.join('\n'), /box: not copied into the game: .*over its budget/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
