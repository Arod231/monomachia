#!/usr/bin/env node
// The Blender export (milestone-1 task 12): the only way art reaches the game.
// Runs Blender headless over each source the asset repository's
// blender/sources.json lists, writing one GLB per source into its exports/
// folder (exports/<folder>/<id>.glb, the folder the source sits in) with a
// record beside it (<id>.glb.json: the source file, both files' SHA-256, the
// licence, the Blender version). A self-made or CC0 model whose sources.json
// entry names a path in the game is also copied there, if the public
// repository's art budget (scripts/check-sizes.mjs, task 8) still holds with
// it; clip exports never leave the asset repository (most derive from the
// Kevin Iglesias packs).
//
// Clip and fighter sources must hold an armature with every bone the Kevin
// Iglesias bone map names, so task 13's import retargets and mirrors them
// like the pack clips; the export refuses one without (export_blend.py).
//
// A body part (KE task 3: a fighter's Quaternius part re-proportioned by
// reproportion_fighter.py, in bodies/<fighter>/) is rigged on the Quaternius
// skeleton (every bone ual_bone_map.tres names) and exported as a .gltf and
// its .bin, not a GLB: in the game it sits beside the original part
// (`materials_from`), whose materials, textures and images it keeps
// verbatim, so it shares the original's texture files and reads as the
// original did; Blender gives it only its meshes, skin and skeleton.
//
// A material (milestone-1 task 45: a palette's dyed maps, made by
// dye_outfit.py in materials/) is a GLB of small planes, each in one material
// holding its maps; the game takes the maps from it and puts them on the
// parts that use them. Headwear (task 46: the Hunter's tricorn and scarf, made
// by build_headwear.py in headwear/) is a GLB in its bone's space, on a rig
// of its own when it moves (the scarf's tails), not the fighter's.
//
//   node scripts/blender/export.mjs [--only=<id>] [--check]
//
// --only exports one source; --check writes nothing and exits 1 when an
// export or a copy in the game would change. Finds Blender from the BLENDER
// environment variable, `blender` on the PATH, a one-line `.blender-path`
// file at the repo root (or the main checkout's, in a worktree), or the
// newest Blender under Program Files on Windows; the asset repository from
// MONOMACHIA_ASSETS_SRC or `.assets-src-path`, as scripts/godot.mjs does.
//
// sources.json:
//   {"sources": {"<id>": {"file": "weapons/katana.blend", "licence": "own",
//                         "game": "game/assets/exports/weapons/katana.glb"}}}
// `file` is relative to blender/ and sits in clips/, fighters/, weapons/,
// shrine/, bodies/, materials/ or headwear/; `licence` is own, cc0 or iglesias; `game` only for own
// and cc0 models (not clips), under game/assets/ (a .gltf for a body part,
// with `materials_from`, else a .glb).

import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LIMIT_BYTES, findOverBudget, isArt, trackedFiles } from '../check-sizes.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..', '..');
const BONE_MAP = join(ROOT, 'game', 'assets', 'kevin_iglesias', 'iglesias_bone_map.tres');
const UAL_BONE_MAP = join(ROOT, 'game', 'assets', 'quaternius', 'ual_bone_map.tres');

/** The folders a source may sit in, each its export's kind. */
export const KINDS = { clips: 'clip', fighters: 'fighter', weapons: 'weapon', shrine: 'shrine', bodies: 'body', materials: 'material', headwear: 'headwear' };
export const LICENCES = ['own', 'cc0', 'iglesias'];
/** export_blend.py's exit code for a source it refuses. */
export const REFUSED = 3;

/** The Kevin Iglesias bones the bone map names (its non-empty targets), in its order. */
export function boneMapBones(text) {
  return [...text.matchAll(/^bone_map\/\w+ = &"([^"]+)"/gm)].map((m) => m[1]);
}

/** sources.json read and checked: {sources: {id: {file, folder, kind, licence, game}}, errors: [...]}. */
export function readSources(text) {
  const errors = [];
  let data;
  try {
    data = JSON.parse(text);
  } catch (err) {
    return { sources: {}, errors: [`sources.json is not JSON (${err.message})`] };
  }
  const listed = data?.sources;
  if (listed === null || typeof listed !== 'object' || Array.isArray(listed)) return { sources: {}, errors: ['sources.json has no "sources" object'] };
  const sources = {};
  for (const [id, s] of Object.entries(listed)) {
    const bad = (why) => errors.push(`${id}: ${why}`);
    if (!/^[a-z0-9_]+$/.test(id)) {
      bad('an id is lower-case letters, digits and underscores');
      continue;
    }
    if (s === null || typeof s !== 'object') {
      bad('not an object');
      continue;
    }
    const unknown = Object.keys(s).filter((k) => !['file', 'licence', 'game', 'about', 'materials_from'].includes(k));
    if (unknown.length) bad(`unknown field ${unknown.join(', ')}`);
    const folder = typeof s.file === 'string' ? s.file.split('/')[0] : '';
    if (typeof s.file !== 'string' || !s.file.endsWith('.blend') || s.file.includes('..') || !(folder in KINDS)) {
      bad(`file must be a .blend in ${Object.keys(KINDS).join('/, ')}/`);
      continue;
    }
    if (!LICENCES.includes(s.licence)) {
      bad(`licence must be ${LICENCES.join(', ')}`);
      continue;
    }
    const kind = KINDS[folder];
    const underAssets = (p, ext) => typeof p === 'string' && p.startsWith('game/assets/') && p.endsWith(ext) && !p.includes('..');
    if (s.game !== undefined) {
      if (kind === 'clip') bad('a clip export stays in the asset repository (no game path)');
      else if (s.licence === 'iglesias') bad('only self-made and CC0 art is copied into the game');
      else if (kind === 'body' && !underAssets(s.game, '.gltf')) bad('a body part goes into the game as a .gltf under game/assets/');
      else if (kind !== 'body' && !underAssets(s.game, '.glb')) bad('game must be a .glb path under game/assets/');
    }
    if (kind === 'body' && s.licence !== 'iglesias' && !underAssets(s.materials_from, '.gltf')) {
      bad('a body part names the part whose materials it keeps (materials_from, a .gltf under game/assets/)');
    }
    if (kind !== 'body' && s.materials_from !== undefined) bad("only a body part keeps another part's materials");
    sources[id] = { file: s.file, folder, kind, licence: s.licence, game: s.game ?? null, materials_from: s.materials_from ?? null };
  }
  return { sources, errors };
}

/** Where a source's export and its record go, relative to the asset repository. */
export function exportPath(id, source) {
  return `exports/${source.folder}/${id}.${source.kind === 'body' ? 'gltf' : 'glb'}`;
}

/**
 * A body part's glTF as text: Blender's export `exported` (its meshes, skin
 * and skeleton) with the materials, textures, images, samplers and
 * extensions of the `original` part, each primitive's material found by
 * name (less Blender's .001 suffixes), and its buffer named `binName`.
 * Throws on a material the original lacks.
 */
export function bodyGltf(exported, original, binName) {
  const out = structuredClone(exported);
  const byName = new Map((original.materials ?? []).map((m, i) => [m.name, i]));
  for (const mesh of out.meshes ?? []) {
    for (const prim of mesh.primitives ?? []) {
      if (prim.material === undefined) continue;
      // Blender suffixes a repeated name (MI_Ranger.001)
      const name = exported.materials[prim.material]?.name?.replace(/\.\d{3}$/, '');
      if (!byName.has(name)) throw new Error(`body part: the original part has no material ${name}`);
      prim.material = byName.get(name);
    }
  }
  for (const key of ['materials', 'textures', 'images', 'samplers', 'extensionsUsed', 'extensionsRequired']) {
    if (original[key] !== undefined) out[key] = structuredClone(original[key]);
    else delete out[key];
  }
  out.buffers[0].uri = binName;
  return JSON.stringify(out, null, 1) + '\n';
}

export const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

/** The record written beside an export, as text (stable key order, one trailing newline). */
export function recordText(id, source, sourceBytes, exportBytes, blenderVersion) {
  const record = {
    id,
    source: `blender/${source.file}`,
    source_sha256: sha256(sourceBytes),
    export_sha256: sha256(exportBytes),
    licence: source.licence,
    kind: source.kind,
    blender: blenderVersion,
  };
  return JSON.stringify(record, null, 2) + '\n';
}

/**
 * Whether a copy of `bytes` bytes to `path` (repo-relative) keeps the public
 * repository inside its budgets, given its tracked `files` ([{path, bytes}]):
 * null when it does, else why not.
 */
export function copyRefusal(files, path, bytes) {
  if (bytes > LIMIT_BYTES) return `${path} would be ${(bytes / 1048576).toFixed(1)} MB, over the ${LIMIT_BYTES / 1048576} MB a file`;
  if (!isArt(path)) return `${path} is not under game/assets/`;
  const after = files.filter((f) => f.path !== path).concat([{ path, bytes }]);
  const over = findOverBudget(after);
  return over.length ? `${path} would take ${over[0].name} to ${(over[0].bytes / 1048576).toFixed(1)} MB, over its budget` : null;
}

/** Roots to look in for an untracked path file: the repo, then the main checkout of a worktree. */
function roots() {
  const out = [ROOT];
  const common = spawnSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { cwd: ROOT, encoding: 'utf8' });
  if (common.status === 0 && common.stdout.trim()) out.push(dirname(common.stdout.trim()));
  return out;
}

function fromPathFile(name) {
  for (const root of roots()) {
    const file = join(root, name);
    if (!existsSync(file)) continue;
    const p = readFileSync(file, 'utf8').trim();
    if (p) return p;
  }
  return null;
}

/** The Blender executable, or null. */
export function findBlender(env = process.env) {
  if (env.BLENDER) return env.BLENDER;
  const exe = process.platform === 'win32' ? 'blender.exe' : 'blender';
  for (const dir of (env.PATH ?? '').split(delimiter)) {
    if (dir && existsSync(join(dir, exe))) return join(dir, exe);
  }
  const local = fromPathFile('.blender-path');
  if (local && existsSync(local)) return local;
  if (process.platform === 'win32') {
    const base = join(env.ProgramFiles ?? 'C:\\Program Files', 'Blender Foundation');
    if (existsSync(base)) {
      const found = readdirSync(base)
        .filter((d) => existsSync(join(base, d, exe)))
        .sort((a, b) => b.localeCompare(a, 'en', { numeric: true }));
      if (found.length) return join(base, found[0], exe);
    }
  }
  return null;
}

/** The asset repository's folder, or null. */
export function findAssets(env = process.env) {
  return env.MONOMACHIA_ASSETS_SRC || fromPathFile('.assets-src-path');
}

/** Blender's version line ("Blender 5.2.2 LTS"). */
export function blenderVersion(blender) {
  const r = spawnSync(blender, ['--version'], { encoding: 'utf8' });
  return (r.stdout ?? '').split('\n')[0].trim();
}

/**
 * Runs export_blend.py over one .blend: {code, output}. `bones` is the
 * rigged kinds' required bone list.
 */
export function exportBlend(blender, blendFile, kind, outFile, bones) {
  const tmp = mkdtempSync(join(tmpdir(), 'm1-export-'));
  try {
    const bonesFile = join(tmp, 'bones.json');
    writeFileSync(bonesFile, JSON.stringify(bones));
    const r = spawnSync(
      blender,
      ['-b', blendFile, '--factory-startup', '--python-exit-code', '1', '--python', join(HERE, 'export_blend.py'), '--', '--kind', kind, '--out', outFile, '--bones', bonesFile],
      { encoding: 'utf8', timeout: 600000 },
    );
    return { code: r.status ?? 1, output: `${r.stdout ?? ''}${r.stderr ?? ''}` };
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

/**
 * Exports the sources (or only `only`) of the asset repository at `assets`
 * and copies the game's models into the repository at `root`. With `check`
 * nothing is written. Returns {code, lines}: 0 done (or nothing would
 * change), 1 a refusal, a failure or (with check) a change.
 */
export function run({ blender, assets, root = ROOT, only = null, check = false, files = null }) {
  const lines = [];
  const say = (s) => lines.push(s);
  const listFile = join(assets, 'blender', 'sources.json');
  if (!existsSync(listFile)) return { code: 1, lines: [`export: no ${listFile}`] };
  const { sources, errors } = readSources(readFileSync(listFile, 'utf8'));
  if (errors.length) return { code: 1, lines: errors.map((e) => `export: sources.json: ${e}`) };
  if (only && !(only in sources)) return { code: 1, lines: [`export: ${only} is not in sources.json`] };
  const bones = boneMapBones(readFileSync(BONE_MAP, 'utf8'));
  const ualBones = boneMapBones(readFileSync(UAL_BONE_MAP, 'utf8'));
  const version = blenderVersion(blender);
  let code = 0;
  const tmp = mkdtempSync(join(tmpdir(), 'm1-export-'));
  try {
    for (const [id, source] of Object.entries(sources)) {
      if (only && id !== only) continue;
      const blend = join(assets, 'blender', source.file);
      if (!existsSync(blend)) {
        say(`export: ${id}: no blender/${source.file}`);
        code = 1;
        continue;
      }
      const body = source.kind === 'body';
      const fresh = join(tmp, `${id}.${body ? 'gltf' : 'glb'}`);
      const r = exportBlend(blender, blend, source.kind, fresh, body ? ualBones : bones);
      if (r.code !== 0 || !existsSync(fresh)) {
        const why = r.output.split('\n').find((l) => l.startsWith('export_blend: refused:')) ?? r.output.trim().split('\n').slice(-3).join(' / ');
        say(`export: ${id}: ${r.code === REFUSED ? why.replace('export_blend: ', '') : `Blender failed: ${why}`}`);
        code = 1;
        continue;
      }
      if (body) {
        code = Math.max(code, exportBody({ id, source, fresh, blend, assets, root, check, files, version, say }));
        continue;
      }
      const bytes = readFileSync(fresh);
      const out = join(assets, exportPath(id, source));
      const record = recordText(id, source, readFileSync(blend), bytes, version);
      const same = existsSync(out) && readFileSync(out).equals(bytes) && existsSync(`${out}.json`) && readFileSync(`${out}.json`, 'utf8') === record;
      if (check) {
        if (!same) {
          say(`export: ${id}: ${exportPath(id, source)} would change`);
          code = 1;
        }
      } else if (!same) {
        mkdirSync(dirname(out), { recursive: true });
        writeFileSync(out, bytes);
        writeFileSync(`${out}.json`, record);
        say(`export: ${id}: wrote ${exportPath(id, source)} (${bytes.length} bytes)`);
      } else say(`export: ${id}: ${exportPath(id, source)} unchanged`);
      if (!source.game) continue;
      const target = join(root, source.game);
      const copied = existsSync(target) && readFileSync(target).equals(bytes);
      if (copied) continue;
      if (check) {
        say(`export: ${id}: ${source.game} would change`);
        code = 1;
        continue;
      }
      const why = copyRefusal(files ?? trackedFiles(), source.game, bytes.length);
      if (why) {
        say(`export: ${id}: not copied into the game: ${why}; it stays in the asset repository`);
        code = 1;
        continue;
      }
      mkdirSync(dirname(target), { recursive: true });
      copyFileSync(fresh, target);
      say(`export: ${id}: copied into ${source.game}`);
    }
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
  return { code, lines };
}

/**
 * Writes a body part's export (its .gltf, keeping the original part's
 * materials, and its .bin) and record into the asset repository and copies
 * both into the game beside the original, as run() does a model: 0 done, 1 a
 * refusal or (with check) a change.
 */
function exportBody({ id, source, fresh, blend, assets, root, check, files, version, say }) {
  const originalPath = join(root, source.materials_from);
  if (!existsSync(originalPath)) {
    say(`export: ${id}: no ${source.materials_from} to take the materials from`);
    return 1;
  }
  const exported = JSON.parse(readFileSync(fresh, 'utf8'));
  const original = JSON.parse(readFileSync(originalPath, 'utf8'));
  const bin = readFileSync(join(dirname(fresh), exported.buffers[0].uri));
  const out = join(assets, exportPath(id, source));
  const outBin = out.replace(/\.gltf$/, '.bin');
  let text;
  try {
    text = bodyGltf(exported, original, `${id}.bin`);
  } catch (err) {
    say(`export: ${id}: ${err.message}`);
    return 1;
  }
  const record = recordText(id, source, readFileSync(blend), Buffer.concat([Buffer.from(text), bin]), version);
  const wants = [
    [out, Buffer.from(text)],
    [outBin, bin],
    [`${out}.json`, Buffer.from(record)],
  ];
  const same = wants.every(([p, want]) => existsSync(p) && readFileSync(p).equals(want));
  let code = 0;
  if (!same && check) {
    say(`export: ${id}: ${exportPath(id, source)} would change`);
    code = 1;
  } else if (!same) {
    mkdirSync(dirname(out), { recursive: true });
    for (const [p, want] of wants) writeFileSync(p, want);
    say(`export: ${id}: wrote ${exportPath(id, source)} (${text.length + bin.length} bytes)`);
  } else if (!check) say(`export: ${id}: ${exportPath(id, source)} unchanged`);
  if (!source.game) return code;
  const gameBin = source.game.replace(/\.gltf$/, '.bin');
  const gameText = bodyGltf(exported, original, gameBin.split('/').pop());
  const target = join(root, source.game);
  const binTarget = join(root, gameBin);
  if (existsSync(target) && readFileSync(target, 'utf8') === gameText && existsSync(binTarget) && readFileSync(binTarget).equals(bin)) return code;
  if (check) {
    say(`export: ${id}: ${source.game} would change`);
    return 1;
  }
  const tracked = (files ?? trackedFiles()).filter((t) => t.path !== source.game).concat([{ path: source.game, bytes: gameText.length }]);
  const why = copyRefusal(tracked, gameBin, bin.length);
  if (why) {
    say(`export: ${id}: not copied into the game: ${why}; it stays in the asset repository`);
    return 1;
  }
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, gameText);
  writeFileSync(binTarget, bin);
  say(`export: ${id}: copied into ${source.game}`);
  return code;
}

function main(argv) {
  const onlyArg = argv.find((a) => a.startsWith('--only='));
  const unknown = argv.filter((a) => a !== '--check' && !a.startsWith('--only='));
  if (unknown.length) {
    console.error(`export: unknown argument ${unknown[0]} (usage: [--only=<id>] [--check])`);
    process.exit(2);
  }
  const blender = findBlender();
  if (!blender) {
    console.error('export: no Blender; set BLENDER, put blender on the PATH or its path in .blender-path');
    process.exit(2);
  }
  const assets = findAssets();
  if (!assets) {
    console.error('export: no asset repository; put its path in .assets-src-path (see CLAUDE.md, Setup)');
    process.exit(2);
  }
  const { code, lines } = run({ blender, assets, only: onlyArg ? onlyArg.slice(7) : null, check: argv.includes('--check') });
  for (const l of lines) (code ? console.error : console.log)(l);
  if (code === 0) console.log(argv.includes('--check') ? 'export: nothing would change' : 'export: done');
  process.exit(code);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2));
}
