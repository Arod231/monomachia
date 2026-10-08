// Keys a clip through Cascadeur (milestone-1 task 59 on, the owner's answer
// of Oct 7: Claude scripts the key poses, Cascadeur's AI inbetweening makes
// the motion between them). One spec, scripts/cascadeur/clips/<id>.json:
//
//   { "about": "...",
//     "out": "blender/clips/<id>.blend",       the clip's source, in the asset repository
//     "blockout": { rekey_clip.py's spec but its out: source, remap, step, pose, ... },
//     "keys": [0, 6, 12],                       the block-out's frames kept as key poses
//     "ai": "optional words for the AI inbetweening",
//     "fit": 2.0 }                              the rig's largest allowed refit, cm (2)
//
//   node scripts/cascadeur/key-clip.mjs scripts/cascadeur/clips/<id>.json [--blockout] [--sheet 0,6,12]
//
// 1. Blender: rekey_clip.py makes the block-out (to a scratch folder), and
//    casc_roundtrip.py exports it keyed on every frame.
// 2. Cascadeur (the owner's running app, its script server on): a fresh tab of
//    our own, the block-out imported at x100, rigged from humanm.qrigcasc; the
//    rig's refit checked against the block-out (every bone, every frame); every
//    key but the spec's unset and the gaps set to AI inbetweening; the result
//    exported, and the scene saved beside the source as <id>.casc.
// 3. Blender: casc_roundtrip.py puts Cascadeur's body motion onto the block-out
//    and saves the clip's source (the spec's out), which `npm run export`
//    then turns into the game's GLB.
//
// --blockout stops after step 1 (to judge the poses); --sheet renders those
// frames of the result (or of the block-out with --blockout) as a pose sheet.

import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { findAssets, findBlender } from '../blender/export.mjs';
import { run } from './run.mjs';
import { poses, gaps } from './glb-pose.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(here, '..', '..');
const fwd = (p) => p.replaceAll('\\', '/');

function blender(bin, args) {
  const out = execFileSync(bin, ['--factory-startup', '--python-exit-code', '1', ...args], { encoding: 'utf8', maxBuffer: 64 << 20 });
  for (const line of out.split(/\r?\n/)) if (/^(rekey_clip|casc_roundtrip|pose_sheet):/.test(line)) console.log(line);
}

/** Waits (up to 20 minutes) until this lane holds Cascadeur (mono_csc.lock()). */
async function takeCascadeur() {
  for (let i = 0; i < 120; i++) {
    const r = await run('print(m.lock())');
    const holder = (r.lines[0] ?? '').trim();
    if (r.ok && holder === '') return;
    if (i === 0) console.log(`key-clip: waiting for ${holder} to finish with Cascadeur`);
    await new Promise((res) => setTimeout(res, 10000));
  }
  throw new Error('key-clip: Cascadeur stayed busy with another lane for 20 minutes');
}

async function cascadeur(code) {
  const r = await run(code);
  for (const l of r.lines) console.log(`  cascadeur: ${l}`);
  if (!r.ok) throw new Error(`Cascadeur: ${r.error}`);
  return r;
}

export async function keyClip(specPath, { blockoutOnly = false, sheet = null } = {}) {
  const spec = JSON.parse(readFileSync(specPath, 'utf8'));
  const id = spec.out.replace(/^.*\//, '').replace(/\.blend$/, '');
  const assets = findAssets();
  const bin = findBlender();
  const work = join(tmpdir(), 'monomachia-casc', id);
  mkdirSync(work, { recursive: true });
  const blockBlend = fwd(join(work, `${id}_blockout.blend`));
  const blockGlb = fwd(join(work, `${id}_blockout.glb`));
  const rigGlb = fwd(join(work, `${id}_rigged.glb`));
  const cascGlb = fwd(join(work, `${id}_casc.glb`));
  const rekeySpec = join(work, `${id}_rekey.json`);
  writeFileSync(rekeySpec, JSON.stringify({ ...spec.blockout, out: blockBlend }, null, '\t'));

  console.log(`key-clip: ${id}: the block-out`);
  blender(bin, ['-b', '--python', join(ROOT, 'scripts/blender/rekey_clip.py'), '--', '--spec', rekeySpec, '--assets', assets]);
  if (blockoutOnly) {
    if (sheet) renderSheet(bin, blockBlend, sheet, join(work, 'sheet_blockout'));
    return { id, work };
  }
  blender(bin, ['-b', blockBlend, '--python', join(ROOT, 'scripts/blender/casc_roundtrip.py'), '--', '--out', blockGlb]);

  console.log(`key-clip: ${id}: Cascadeur`);
  await takeCascadeur();
  try {
  const last = poses(blockGlb).frames - 1;
  const keep = [0, ...spec.keys.map((k) => k + 1)];
  const template = fwd(join(here, 'humanm.qrigcasc'));
  const casc = fwd(join(assets, spec.out.replace(/\.blend$/, '.casc')));
  await cascadeur(`
m.close()
m.tab(fresh=True)
m.import_glb(r'${blockGlb}')
m.build_rig(r'${template}')
m.export_glb(r'${rigGlb}', 1, ${last})
print('rigged', m.info())`);
  const fit = Object.entries(gaps(poses(blockGlb), poses(rigGlb), -1)).sort((a, b) => b[1].gap - a[1].gap)[0];
  const limit = (spec.fit ?? 2.0) / 100;
  console.log(`key-clip: the rig's refit: at most ${(fit[1].gap * 100).toFixed(2)} cm (${fit[0]}, frame ${fit[1].frame})`);
  if (fit[1].gap > limit) throw new Error(`key-clip: the rig moves ${fit[0]} ${(fit[1].gap * 100).toFixed(1)} cm off the block-out (over ${spec.fit ?? 2} cm)`);
  await cascadeur(`
print('kept', m.keep_keys(${JSON.stringify(keep)}, True, ${JSON.stringify(spec.ai ?? '')}))
print('keys', m.key_frames())`);
  // the AI inbetweens are computed at Cascadeur's next idle, so the export
  // goes in a later call (the PR #105 lane found a same-call export misses them)
  await cascadeur(`
m.export_glb(r'${cascGlb}', 1, ${last})
m.save(r'${casc}')
print('saved')`);
  } finally {
    await run('m.unlock()').catch(() => {});
  }

  console.log(`key-clip: ${id}: back into Blender`);
  const out = fwd(join(assets, spec.out));
  blender(bin, ['-b', blockBlend, '--python', join(ROOT, 'scripts/blender/casc_roundtrip.py'), '--', '--casc', cascGlb, '--save', out]);
  if (sheet) renderSheet(bin, out, sheet, join(work, 'sheet'));
  return { id, work, out };
}

function renderSheet(bin, blend, frames, dir) {
  blender(bin, ['-b', blend, '--python', join(ROOT, 'scripts/blender/pose_sheet.py'), '--', '--frames', frames, '--out', fwd(dir)]);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const i = args.indexOf('--sheet');
  const sheet = i >= 0 ? args[i + 1] : null;
  try {
    const r = await keyClip(args[0], { blockoutOnly: args.includes('--blockout'), sheet });
    console.log(`key-clip: done; scratch files in ${r.work}`);
    if (!existsSync(r.work)) process.exit(1);
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
}
