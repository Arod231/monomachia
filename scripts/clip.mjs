// The rules of `npm run clip -- <scene> [--seconds N] [--out shots/<name>.mp4] [scene args]`
// (scripts/godot.mjs clip runs it): a scene the shots tool can run, recorded by
// Godot's Movie Maker at 30 fps, kept as a looping MP4 (H.264, yuv420p,
// +faststart, no sound, 1280x720; 6 seconds unless asked, 20 at most) with a
// still of its first frame, in the worktree's shots/ folder (never committed).
// The session then posts them with `npm run post`. tests/clip.test.mjs checks
// these rules.
import path from 'node:path';

export const CLIP_FPS = 30;
export const CLIP_SIZE = '1280x720';
const DEFAULT_SECONDS = 6;
const MAX_SECONDS = 20;

export function clipArgs(argv) {
  const out = { scene: null, seconds: DEFAULT_SECONDS, out: null, sceneArgs: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const m = a.match(/^--(seconds|out)(?:=(.*))?$/);
    if (m) {
      const value = m[2] ?? argv[++i];
      if (m[1] === 'seconds') out.seconds = Number(value);
      else out.out = value ?? null;
    } else if (!out.scene && !a.startsWith('--')) out.scene = a;
    else out.sceneArgs.push(a);
  }
  if (!out.scene) throw new Error('Name a scene to record, such as res://tools/shot_scenes/arena_gameplay.tscn (or just arena_gameplay)');
  if (!out.scene.startsWith('res://')) out.scene = `res://tools/shot_scenes/${out.scene.replace(/\.tscn$/, '')}.tscn`;
  if (!(out.seconds > 0 && out.seconds <= MAX_SECONDS)) throw new Error(`--seconds takes more than 0 and at most ${MAX_SECONDS}`);
  if (out.out != null && !/\.mp4$/i.test(out.out)) throw new Error('--out names the .mp4 to write');
  return out;
}

// Where the clip and its still go: --out, else shots/<scene name>.mp4 in root.
export function clipPaths({ scene, out }, root) {
  const mp4 = out ? path.resolve(root, out) : path.join(root, 'shots', `${path.posix.basename(scene, '.tscn')}.mp4`);
  return { mp4, still: mp4.replace(/\.mp4$/i, '.png') };
}

// ffmpeg's arguments: the movie's last `seconds` (the recorded part, which
// shot.gd's --record ends it with), scaled to 1280x720 (Movie Maker writes the
// project's own window size), as an MP4 that plays inline on an iPhone.
export function clipFfmpegArgs({ avi, seconds, mp4 }) {
  const [w, h] = CLIP_SIZE.split('x');
  return ['-v', 'error', '-y', '-sseof', `-${seconds}`, '-i', avi, '-t', String(seconds), '-an', '-r', String(CLIP_FPS),
    '-vf', `scale=${w}:${h}:out_range=tv,format=yuv420p`, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-movflags', '+faststart', mp4];
}
