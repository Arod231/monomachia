#!/usr/bin/env node
// The reactions and movement review's video (authored-animation task 31):
// game/tools/review_video.tscn under Godot's Movie Maker, into
// shots/task31/review_video.avi (it stays local). With ffmpeg on PATH the
// AVI (Movie Maker's MJPEG, about 10 MB a second) becomes review_video.mp4.
//
//   node scripts/review_video.mjs [--seconds=75] [--seed=3]

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '..');
const args = process.argv.slice(2);
// as scripts/godot.mjs finds it: godot4 on PATH, else the .godot-path file
function findGodot() {
  if (spawnSync('godot4', ['--version'], { encoding: 'utf8' }).status === 0) return 'godot4';
  for (const dir of [ROOT, resolve(ROOT, '..', '..', '..')]) {
    const file = join(dir, '.godot-path');
    if (existsSync(file)) return readFileSync(file, 'utf8').trim();
  }
  throw new Error('no Godot: put godot4 on PATH or its path in .godot-path');
}
const out = join(ROOT, 'shots', 'task31');
mkdirSync(out, { recursive: true });
const avi = join(out, 'review_video.avi');
// the main scene, not --script, so the autoloads load
const r = spawnSync(findGodot(), ['--path', join(ROOT, 'game'), '--position', '-3000,-3000', '--resolution', '1600x900',
  '--fixed-fps', '60', '--write-movie', avi, 'res://tools/review_video.tscn', '--', ...args],
  { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8', timeout: 3600000, env: { ...process.env, MONOMACHIA_DEFAULT_SETTINGS: '1' } });
const errors = `${r.stdout ?? ''}${r.stderr ?? ''}`.split('\n').filter((l) => /SCRIPT ERROR|ERROR: Failed/.test(l));
for (const line of errors) console.log(line.trim());
// a run in this checkout can rewrite the bus layout; put it back
spawnSync('git', ['checkout', 'game/default_bus_layout.tres'], { cwd: ROOT });
if (r.status !== 0 || errors.length) throw new Error(`review_video failed (${r.status})`);
const mp4 = join(out, 'review_video.mp4');
const ff = spawnSync('ffmpeg', ['-v', 'error', '-y', '-i', avi, '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
  '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k', mp4], { stdio: 'inherit' });
if (ff.status === 0) {
  rmSync(avi);
  console.log(`wrote ${mp4}`);
} else {
  console.log(`wrote ${avi}`);
}
