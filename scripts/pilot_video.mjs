#!/usr/bin/env node
// The pilot's side-by-side video (milestone-1 task 40): today's four Katana
// lights beside Elden Ring's Uchigatana (the style the re-keys of
// docs/plans/katana-elden-ring.md follow), For Honor, Ghost of Tsushima and
// Tekken 8, written to shots/m40/pilot_video.mp4. It stays on this PC:
// shots/ is gitignored and the reference footage, fetched with
// tools/animeref/fetch.py, never leaves it.
//
//   node scripts/pilot_video.mjs --runs=<tools/animeref/runs folder> [--keep-ours]
//
// 1. Records the look test (game/tools/look_test/look_test.tscn, the gameplay
//    camera, the realistic look) under Godot's Movie Maker at 60 fps for one
//    loop of the string, into shots/m40/ours.avi (--keep-ours reuses it).
// 2. For each light, a 3x2 grid (ours and the four references, each cut
//    round its hit, and a caption), at full speed and then at half.
// 3. The whole string in each, then everything joined (ffmpeg on PATH).
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(import.meta.dirname, '..');
const FPS = 60;
// A panel, and the grid of three by two.
const W = 640;
const H = 360;
// Each light's panels from this long before its hit to this long after.
const PRE = 0.7;
const POST = 0.6;
const FONT = "fontfile='C\\:/Windows/Fonts/arial.ttf'";

// Ours: the look test's loop lands its lights on rules steps 42, 73, 109
// and 147 (LookTest._advance(), from its first press on step 12, the hidden
// opponent 3.5 m ahead), shown on movie frames 41, 72, 108 and 146.
export const OURS = {
  name: 'Monomachia',
  label: "Monomachia: today's lights (the pilot)",
  hits: [41, 72, 108, 146].map((f) => f / FPS),
  frames: 270,
  // the middle of the gameplay camera's frame (1280x720), round the fighter
  crop: '960:540:240:180',
};

// The references, each light-string hit timed by eye on its frame sheets
// (about a tenth of a second either way). A hit a string doesn't have is
// null, with the reason.
export const REFERENCES = [
  {
    game: 'Elden Ring',
    label: "Elden Ring: Uchigatana 2H (the re-keys' style)",
    run: '9sJ2B7crfF8',
    // its extracted 60 fps frames (frames/%05d.jpg, 1-based): 1963, 2003, 2040, 2078
    frames: true,
    hits: [1962, 2002, 2039, 2077].map((f) => f / FPS),
  },
  {
    game: 'For Honor',
    label: 'For Honor: Orochi, Crosswind Slashes',
    run: 'wEcPrQJ3jzY',
    // the guide's gameplay inset
    crop: '852:480:180:310',
    hits: [39.5, 40.0, 40.5, null],
    missing: "For Honor's light chain is three hits",
  },
  {
    game: 'Ghost of Tsushima',
    label: 'Ghost of Tsushima: light attacks',
    run: 'x349AuiCrCA',
    hits: [1009.5, 1010.1, 1011.6, 1014.3],
  },
  {
    game: 'Tekken 8',
    label: 'Tekken 8: Yoshimitsu, Heshikiriseibatsu',
    run: 'uzYTjviUrxE',
    hits: [144.12, 144.62, 145.0, 145.25],
  },
];

export const LIGHTS = ['Right Cut', 'Return Cut', 'Kesa Cut', 'Crown Cut'];

// A panel's cut round a hit at `at` seconds.
export function cut(at, pre, post) {
  const from = Math.max(0, +(at - pre).toFixed(3));
  return { from, duration: +(at + post - from).toFixed(3) };
}

// Each light's panels: a cut per source, or its note where it has no hit.
export function plan(sources, pre, post) {
  return [0, 1, 2, 3].map((i) => sources.map((s) =>
    s.hits[i] === null ? { name: s.name, note: s.missing } : { name: s.name, ...cut(s.hits[i], pre, post) }));
}

// A source's whole string: from before its first hit to after its last.
export function stringCut(source, pre, post) {
  const hits = source.hits.filter((t) => t !== null);
  const c = cut(hits[0], pre, post);
  return { from: c.from, duration: +(hits.at(-1) + post - c.from).toFixed(3) };
}

function run(cmd, args, label) {
  const r = spawnSync(cmd, args, { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 3600000,
    env: { ...process.env, MONOMACHIA_DEFAULT_SETTINGS: '1' } });
  if (r.status !== 0) {
    console.log(`${r.stdout ?? ''}${r.stderr ?? ''}`.split('\n').slice(-20).join('\n'));
    throw new Error(`${label} failed (${r.status})`);
  }
  return r;
}

function findGodot() {
  if (process.env.GODOT) return process.env.GODOT;
  for (const dir of [ROOT, resolve(ROOT, '..', '..', '..')]) {
    const file = join(dir, '.godot-path');
    if (existsSync(file)) return readFileSync(file, 'utf8').trim();
  }
  return 'godot';
}

// The ffmpeg input for a cut of `source` (ours, a reference, or a black
// panel `duration` long for a missing hit).
function input(source, c, runs, duration) {
  if (c.note !== undefined) return ['-f', 'lavfi', '-t', String(duration), '-i', `color=c=0x0b0e16:s=${W}x${H}:r=${FPS}`];
  if (source === OURS) return ['-ss', String(c.from), '-t', String(c.duration), '-i', 'shots/m40/ours.avi'];
  const dir = join(runs, source.run);
  if (source.frames) {
    return ['-framerate', String(FPS), '-start_number', String(Math.round(c.from * FPS) + 1), '-t', String(c.duration),
      '-i', join(dir, 'frames', '%05d.jpg')];
  }
  return ['-ss', String(c.from), '-t', String(c.duration), '-i', join(dir, 'video.mp4')];
}

let texts = 0;
// A drawtext filter reading `text` from a file (no escaping), at the top left.
function label(text, size = 22, y = 10) {
  const file = `shots/m40/tmp/t${texts++}.txt`;
  writeFileSync(join(ROOT, file), text);
  return `drawtext=${FONT}:textfile=${file}:x=12:y=${y}:fontsize=${size}:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=6`;
}

// One grid: the five sources' cuts and a caption, at `speed` (1 or 0.5),
// into `out`.
function grid(sources, cuts, caption, speed, out, runs) {
  // the light's length: its longest cut (a missing hit's panel has none)
  const duration = Math.max(...cuts.filter((c) => c.note === undefined).map((c) => c.duration));
  const args = ['-v', 'error', '-y'];
  cuts.forEach((c, i) => args.push(...input(sources[i], c, runs, duration)));
  args.push('-f', 'lavfi', '-t', String(duration), '-i', `color=c=0x101114:s=${W}x${H}:r=${FPS}`);
  const slow = speed === 1 ? '' : `,setpts=${1 / speed}*PTS`;
  const parts = cuts.map((c, i) => {
    const note = c.note !== undefined ? `,${label(c.note, 24, H / 2 - 12)}` : '';
    const crop = sources[i].crop && c.note === undefined ? `crop=${sources[i].crop},` : '';
    return `[${i}:v]fps=${FPS},${crop}scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2,setsar=1,`
      + `tpad=stop_mode=clone:stop_duration=${duration},trim=duration=${duration}${note},${label(sources[i].label)}${slow}[p${i}]`;
  });
  parts.push(`[${cuts.length}:v]${caption.map((line, k) => label(line, k === 0 ? 34 : 24, 40 + k * 46)).join(',')}${slow}[p${cuts.length}]`);
  const inputs = cuts.map((_, i) => `[p${i}]`).join('') + `[p${cuts.length}]`;
  parts.push(`${inputs}xstack=inputs=6:layout=0_0|w0_0|w0+w1_0|0_h0|w0_h0|w0+w1_h0[v]`);
  args.push('-filter_complex', parts.join(';'), '-map', '[v]', '-r', String(FPS), '-c:v', 'libx264', '-crf', '20',
    '-preset', 'medium', '-pix_fmt', 'yuv420p', out);
  run('ffmpeg', args, `grid ${out}`);
}

function main() {
  const args = Object.fromEntries(process.argv.slice(2).map((a) => a.replace(/^--/, '').split('=')));
  const runs = resolve(args.runs ?? join(ROOT, 'tools', 'animeref', 'runs'));
  for (const r of REFERENCES) {
    const want = join(runs, r.run, r.frames ? 'frames' : 'video.mp4');
    if (!existsSync(want)) throw new Error(`no ${r.game} footage at ${want} (tools/animeref/fetch.py; --runs=)`);
  }
  const out = join(ROOT, 'shots', 'm40');
  rmSync(join(out, 'tmp'), { recursive: true, force: true });
  mkdirSync(join(out, 'tmp'), { recursive: true });
  if (!('keep-ours' in args) || !existsSync(join(out, 'ours.avi'))) {
    console.log('recording the look test');
    run(findGodot(), ['--path', join(ROOT, 'game'), '--position', '-3000,-3000', '--resolution', '1280x720',
      '--fixed-fps', String(FPS), '--write-movie', join(out, 'ours.avi'), '--quit-after', String(OURS.frames),
      'res://tools/look_test/look_test.tscn', '--', '--view=gameplay'], 'the look test');
    spawnSync('git', ['checkout', 'game/default_bus_layout.tres'], { cwd: ROOT });
  }
  const sources = [OURS, ...REFERENCES.map((r) => ({ ...r, name: r.game }))];
  const parts = [];
  plan(sources, PRE, POST).forEach((cuts, i) => {
    for (const speed of [1, 0.5]) {
      const file = join(out, 'tmp', `light${i + 1}_${speed === 1 ? 'full' : 'half'}.mp4`);
      console.log(`light ${i + 1} at ${speed}x`);
      grid(sources, cuts, [`Light ${i + 1}: ${LIGHTS[i]}`, speed === 1 ? 'full speed' : 'half speed', 'each lined up on its hit'],
        speed, file, runs);
      parts.push(file);
    }
  });
  console.log('the whole string');
  const whole = join(out, 'tmp', 'string.mp4');
  grid(sources, sources.map((s) => stringCut(s, PRE, 0.8)), ['The whole string', 'full speed', 'from each first hit to its last'],
    1, whole, runs);
  parts.push(whole);
  const list = join(out, 'tmp', 'parts.txt');
  writeFileSync(list, parts.map((p) => `file '${p.replaceAll('\\', '/')}'`).join('\n'));
  run('ffmpeg', ['-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', join(out, 'pilot_video.mp4')], 'joining');
  console.log(`wrote ${join(out, 'pilot_video.mp4')}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
