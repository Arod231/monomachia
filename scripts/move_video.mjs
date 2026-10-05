#!/usr/bin/env node
// The before-and-after video of a weapon's moves (authored-animation task 14):
// the procedural animation from feature/godot-rebuild beside the clips from
// this branch, side by side, written under shots/ (it stays local).
//
//   node scripts/move_video.mjs [--weapon=katana] [--fighter=hunter] [--moves=k_l1,k_l2] [--ref=origin/feature/godot-rebuild]
//
// 1. Exports the reference branch's game/ folder (git archive, no checkout)
//    to shots/<weapon>_video/before_project and imports it once.
// 2. Renders every move's frames in both projects with game/tools/move_video.gd
//    (the same file, run by its absolute path in the other project).
// 3. Composes them under Godot's Movie Maker into shots/<weapon>_video.avi
//    (game/tools/move_video_compose.gd).
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '..');
const args = Object.fromEntries(process.argv.slice(2).map((a) => a.replace(/^--/, '').split('=')));
const weapon = args.weapon ?? 'katana';
const fighter = args.fighter ?? 'hunter';
const ref = args.ref ?? 'origin/feature/godot-rebuild';
const out = join(ROOT, 'shots', `${weapon}_video`);
const project = join(out, 'before_project');
// as scripts/godot.mjs finds it: godot4 on PATH, else the .godot-path file
// (importing godot.mjs would run its command line)
function findGodot() {
  if (spawnSync('godot4', ['--version'], { encoding: 'utf8' }).status === 0) return 'godot4';
  for (const dir of [ROOT, resolve(ROOT, '..', '..', '..')]) {
    const file = join(dir, '.godot-path');
    if (existsSync(file)) return readFileSync(file, 'utf8').trim();
  }
  throw new Error('no Godot: put godot4 on PATH or its path in .godot-path');
}
const godot = findGodot();

function run(argv, label) {
  const r = spawnSync(godot, argv, { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8', timeout: 3600000 });
  const text = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  for (const line of text.split('\n')) if (/move_video|SCRIPT ERROR|ERROR: Failed/.test(line)) console.log(`  ${label}: ${line.trim()}`);
  if (r.status !== 0) throw new Error(`${label} failed (${r.status})`);
}

mkdirSync(out, { recursive: true });
if (!existsSync(join(project, 'game', 'project.godot'))) {
  console.log(`exporting ${ref}'s game/ to ${project}`);
  mkdirSync(project, { recursive: true });
  const tar = execFileSync('git', ['archive', ref, 'game'], { cwd: ROOT, maxBuffer: 1 << 30 });
  // run from inside the folder: tar reads a drive letter in -C as a remote host
  execFileSync('tar', ['-x'], { cwd: project, input: tar, maxBuffer: 1 << 30 });
  run(['--headless', '--path', join(project, 'game'), '--import'], 'import');
}
const window = ['--position', '-3000,-3000', '--fixed-fps', '60'];
const pick = [`--weapon=${weapon}`, `--fighter=${fighter}`, ...(args.moves ? [`--moves=${args.moves}`] : [])];
const tool = join(ROOT, 'game', 'tools', 'move_video.gd');
for (const [side, path] of [['after', join(ROOT, 'game')], ['before', join(project, 'game')]]) {
  rmSync(join(out, side), { recursive: true, force: true });
  console.log(`rendering ${side}`);
  run(['--path', path, ...window, '--resolution', '800x900', '--script', tool, '--', ...pick, `--out=${join(out, side)}`], side);
}
const avi = `${out}.avi`;
console.log(`composing ${avi}`);
run(['--path', join(ROOT, 'game'), ...window, '--resolution', '1600x900', '--write-movie', avi,
  '--script', 'res://tools/move_video_compose.gd', '--', `--before=${join(out, 'before')}`, `--after=${join(out, 'after')}`], 'compose');
// a run in this checkout can rewrite the bus layout; put it back
spawnSync('git', ['checkout', 'game/default_bus_layout.tres'], { cwd: ROOT });
console.log(`wrote ${avi}`);
