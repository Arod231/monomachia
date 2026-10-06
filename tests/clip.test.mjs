// `npm run clip` (scripts/clip.mjs, run by scripts/godot.mjs clip): what it
// takes, where it writes, and how ffmpeg turns Movie Maker's AVI into the
// looping MP4 the session posts.
import path from 'node:path';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { CLIP_FPS, clipArgs, clipFfmpegArgs, clipPaths } from '../scripts/clip.mjs';

describe('clipArgs', () => {
  it('records a shot scene for 6 seconds by default, passing other flags to the scene', () => {
    assert.deepEqual(clipArgs(['arena_gameplay']), { scene: 'res://tools/shot_scenes/arena_gameplay.tscn', seconds: 6, out: null, sceneArgs: [] });
    assert.deepEqual(clipArgs(['res://tools/shot_scenes/look_bench.tscn', '--seconds', '12', '--mode=sheet']),
      { scene: 'res://tools/shot_scenes/look_bench.tscn', seconds: 12, out: null, sceneArgs: ['--mode=sheet'] });
    assert.deepEqual(clipArgs(['x', '--seconds=2.5', '--out', 'shots/run.mp4']), { scene: 'res://tools/shot_scenes/x.tscn', seconds: 2.5, out: 'shots/run.mp4', sceneArgs: [] });
  });
  it('needs a scene, at most 20 seconds, and an MP4 to write', () => {
    assert.throws(() => clipArgs([]), /Name a scene/);
    assert.throws(() => clipArgs(['x', '--seconds', '21']), /at most 20/);
    assert.throws(() => clipArgs(['x', '--seconds', '0']), /at most 20/);
    assert.throws(() => clipArgs(['x', '--seconds', 'lots']), /at most 20/);
    assert.throws(() => clipArgs(['x', '--out', 'a.avi']), /\.mp4/);
  });
});

describe('clipPaths', () => {
  it("writes into the worktree's shots folder, named for the scene, with the still beside the clip", () => {
    const root = path.resolve('/w');
    assert.deepEqual(clipPaths({ scene: 'res://tools/shot_scenes/arena_gameplay.tscn', out: null }, root),
      { mp4: path.join(root, 'shots', 'arena_gameplay.mp4'), still: path.join(root, 'shots', 'arena_gameplay.png') });
    assert.deepEqual(clipPaths({ scene: 'res://x.tscn', out: 'shots/run.mp4' }, root),
      { mp4: path.join(root, 'shots', 'run.mp4'), still: path.join(root, 'shots', 'run.png') });
  });
});

describe('clipFfmpegArgs', () => {
  it("keeps the movie's last seconds as an H.264 MP4 at 1280x720 that plays on a phone, with no sound", () => {
    assert.equal(CLIP_FPS, 30);
    const a = clipFfmpegArgs({ avi: 'm.avi', seconds: 6, mp4: 'c.mp4' });
    assert.deepEqual(a.slice(a.indexOf('-sseof'), a.indexOf('-sseof') + 4), ['-sseof', '-6', '-i', 'm.avi']);
    for (const pair of [['-t', '6'], ['-c:v', 'libx264'], ['-pix_fmt', 'yuv420p'], ['-movflags', '+faststart'], ['-r', '30']]) {
      assert.deepEqual(a.slice(a.indexOf(pair[0]), a.indexOf(pair[0]) + 2), pair);
    }
    assert.ok(a.includes('-an'));
    assert.match(a[a.indexOf('-vf') + 1], /^scale=1280:720/);
    assert.equal(a.at(-1), 'c.mp4');
  });
});
