#!/usr/bin/env node
// Clips made in Cascadeur by key poses and AI inbetweening (milestone-1 task 89
// on, the owner's call on Oct 7, 2026). For each spec in scripts/cascadeur/clips/
// (all of them, or the ids given):
//
//   1. Blender: rekey_clip.py makes the key poses' block-out from a pack clip
//      (the spec's source, remap and step, as a re-key spec) into the asset
//      repository's blender/cascadeur/<id>_keys.blend;
//   2. Blender: cascadeur_io.py --to exports it as <id>_keys.glb, every channel
//      on every frame;
//   3. Cascadeur (open, with its script server started: Scripts > MCP > Start
//      script server): generate_clip.py imports it into a tab of its own, rigs
//      it from iglesias.qrigcasc, keeps the keys only on the spec's key-pose
//      frames with AI interpolation between, exports <id>.glb and saves
//      <id>.casc (the editable source for a later polish);
//   4. Blender: cascadeur_io.py --from brings the generated clip back onto the
//      block-out's armature, its feet held to the block-out's, and saves the
//      spec's clip (blender/clips/<id>.blend), which sources.json lists and
//      `npm run export` turns into the game's GLB.
//
//   node scripts/cascadeur/generate.mjs [<id>...] [--url=http://127.0.0.1:8765]
//
// Finds Blender and the asset repository as scripts/blender/export.mjs does.
// Everything it writes lives in the asset repository (the clips derive from
// the Kevin Iglesias packs).

import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { findAssets, findBlender } from '../blender/export.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..', '..');
export const SPECS = join(HERE, 'clips');
const TEMPLATE = join(HERE, 'iglesias.qrigcasc');
const GENERATE = join(HERE, 'generate_clip.py');
const REKEY = join(ROOT, 'scripts', 'blender', 'rekey_clip.py');
const IO = join(ROOT, 'scripts', 'blender', 'cascadeur_io.py');

/** The working files of spec `id`, relative to the asset repository. */
export function workFiles(id, spec) {
  return {
    keys: spec.out,
    keysGlb: spec.out.replace(/\.blend$/, '.glb'),
    generated: `blender/cascadeur/${id}.glb`,
    casc: `blender/cascadeur/${id}.casc`,
    clip: spec.clip,
  };
}

/** The script generate_clip.py runs with, its PARAMS prepended. */
export function cascadeurCode(params, script = readFileSync(GENERATE, 'utf8')) {
  return `PARAMS = ${JSON.stringify(params)}\n${script}`;
}

/** The lines worth showing from a /run answer: its prints and its errors. */
export function shownMessages(answer) {
  return (answer.messages ?? [])
    .filter((m) => m.level === 'Error' || (m.level === 'Info' && !/^Local (position|rotation) of /.test(m.text)))
    .map((m) => `${m.level}: ${m.text}`);
}

function blender(args) {
  const exe = findBlender();
  if (!exe) throw new Error('no Blender (BLENDER, PATH, .blender-path or Program Files)');
  const r = spawnSync(exe, ['-b', ...args], { encoding: 'utf8', timeout: 600000 });
  const out = (r.stdout ?? '') + (r.stderr ?? '');
  for (const line of out.split('\n')) if (/^(rekey_clip|cascadeur_io): /.test(line)) console.log(`  ${line.trim()}`);
  if (r.status !== 0) throw new Error(`Blender failed (${r.status}):\n${out.slice(-3000)}`);
  return out;
}

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

/** Waits for Cascadeur's script server to have nothing queued (at most `ms`). */
async function settled(url, ms = 120000) {
  for (const end = Date.now() + ms; Date.now() < end; await sleep(500)) {
    const health = await fetch(`${url}/health`).then((r) => r.json()).catch(() => null);
    if (health && health.queued === 0) return;
  }
  throw new Error('Cascadeur stayed busy');
}

/**
 * Runs one stage of generate_clip.py in Cascadeur; answers its printed
 * line. A call that outlasts the server's 30-second wait still runs (the
 * server only stops waiting): wait for it, and the next stage checks it did.
 */
async function stage(url, params) {
  const health = await fetch(`${url}/health`).catch(() => null);
  if (!health?.ok) throw new Error(`Cascadeur's script server isn't answering at ${url} (open Cascadeur, Scripts > MCP > Start script server)`);
  const res = await fetch(`${url}/run`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ code: cascadeurCode(params) }) });
  const answer = await res.json();
  for (const line of shownMessages(answer)) console.log(`  cascadeur: ${line}`);
  if (!answer.ok && /Timed out waiting/.test(answer.error ?? '')) {
    console.log(`  cascadeur: the ${params.stage} stage outlasted the wait; waiting for it`);
    await settled(url);
    return '';
  }
  const printed = (answer.messages ?? []).find((m) => /^generate_clip: /.test(m.text));
  if (!answer.ok || !printed) throw new Error(`Cascadeur's ${params.stage} stage failed: ${JSON.stringify(answer).slice(0, 2000)}`);
  return printed.text;
}

/** This lane's name for the shared lock, from the checkout's branch. */
function laneName() {
  const r = spawnSync('git', ['branch', '--show-current'], { cwd: ROOT, encoding: 'utf8' });
  return (r.stdout ?? '').trim() || 'scripts/cascadeur/generate.mjs';
}

/**
 * Runs `code` in Cascadeur and answers its printed lines (for the lock's
 * small calls, which never outlast the wait).
 */
async function printed(url, code) {
  const res = await fetch(`${url}/run`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ code }) });
  const answer = await res.json();
  return (answer.messages ?? []).map((m) => m.text).join('\n');
}

/**
 * The lock the sessions sharing the owner's one Cascadeur agreed on (Oct 7,
 * 2026, after two lanes' interleaved scripts crashed it): `builtins._lane_lock`
 * inside Cascadeur holds the name of the lane running scripts; take it when
 * it's unset or ours, wait while another lane holds it (at most `ms`).
 */
export const LOCK_CODE = (lane, take) => (take
  ? `import builtins\nv = getattr(builtins, "_lane_lock", None)\nif v in (None, ${JSON.stringify(lane)}):\n    builtins._lane_lock = ${JSON.stringify(lane)}\nprint("lane_lock:", getattr(builtins, "_lane_lock", None))\n`
  : `import builtins\nif getattr(builtins, "_lane_lock", None) == ${JSON.stringify(lane)}:\n    builtins._lane_lock = None\nprint("lane_lock:", getattr(builtins, "_lane_lock", None))\n`);

async function lock(url, lane, ms = 1800000) {
  let told = false;
  for (const end = Date.now() + ms; Date.now() < end; await sleep(5000)) {
    await settled(url);
    const held = ((await printed(url, LOCK_CODE(lane, true))).match(/lane_lock: (.*)/)?.[1] ?? '').trim();
    if (held === lane) return;
    if (!told) console.log(`  cascadeur: ${held} holds the lane lock; waiting`);
    told = true;
  }
  throw new Error('another lane held the Cascadeur lock for 30 minutes');
}

/** The Cascadeur half: rig, key poses, exports until the inbetweens settle, save and close. */
async function inCascadeur(url, params) {
  const lane = laneName();
  await lock(url, lane);
  try {
    await cascadeurStages(url, params);
  } finally {
    await settled(url).catch(() => {});
    await printed(url, LOCK_CODE(lane, false)).catch(() => {});
  }
}

async function cascadeurStages(url, params) {
  await settled(url);
  await stage(url, { ...params, stage: 'rig' });
  try {
    await stage(url, { ...params, stage: 'keys' });
    let last = null;
    for (let i = 0; i < 20; i++) {
      await sleep(1500);
      const sha = (await stage(url, { ...params, stage: 'export' })).match(/sha256 (\w+)/)?.[1] ?? null;
      if (sha && sha === last) return;
      last = sha;
    }
    throw new Error("the AI inbetweens didn't settle over 20 exports");
  } finally {
    await stage(url, { ...params, stage: 'close' });
  }
}

async function generate(id, spec, assets, url) {
  const f = workFiles(id, spec);
  const at = (p) => join(assets, p).replaceAll('\\', '/');
  console.log(`${id}: the key poses' block-out`);
  blender(['--factory-startup', '--python-exit-code', '1', '--python', REKEY, '--', '--spec', join(SPECS, `${id}.json`), '--assets', assets]);
  blender([at(f.keys), '--factory-startup', '--python-exit-code', '1', '--python', IO, '--', '--to', at(f.keysGlb)]);
  console.log(`${id}: Cascadeur's AI inbetweening over key poses ${spec.keys.join(', ')}`);
  await inCascadeur(url, { id, glb: at(f.keysGlb), template: TEMPLATE.replaceAll('\\', '/'), keys: spec.keys, out: at(f.generated), casc: at(f.casc) });
  console.log(`${id}: back into ${f.clip}`);
  blender([at(f.keys), '--factory-startup', '--python-exit-code', '1', '--python', IO, '--', '--from', at(f.generated), '--out', at(f.clip)]);
}

async function main() {
  const args = process.argv.slice(2);
  const url = (args.find((a) => a.startsWith('--url=')) ?? '--url=http://127.0.0.1:8765').slice(6);
  const all = readdirSync(SPECS).filter((n) => n.endsWith('.json')).map((n) => n.replace(/\.json$/, ''));
  const ids = args.filter((a) => !a.startsWith('--'));
  const unknown = ids.filter((id) => !all.includes(id));
  if (unknown.length) throw new Error(`no spec for ${unknown.join(', ')} in scripts/cascadeur/clips/`);
  const assets = findAssets();
  if (!assets || !existsSync(assets)) throw new Error('no asset repository (MONOMACHIA_ASSETS_SRC or .assets-src-path)');
  for (const id of ids.length ? ids : all) {
    await generate(id, JSON.parse(readFileSync(join(SPECS, `${id}.json`), 'utf8')), assets, url);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error(`generate: ${err.message}`);
    process.exit(1);
  });
}
