// `npm run post` (tools/lanes-board/post.mjs) on fixture files: what lands in
// the media store, run as a session runs it, with its session id in the shell.
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';

const POST = fileURLToPath(new URL('../tools/lanes-board/post.mjs', import.meta.url));
const S1 = '11111111-2222-4333-8444-555555555555';
// A 1×1 PNG.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const hasFfmpeg = spawnSync('ffmpeg', ['-version'], { windowsHide: true }).status === 0;

describe('npm run post', () => {
  let dir, state, work;
  const post = (args, env = { CLAUDE_CODE_SESSION_ID: S1 }) => {
    const base = { ...process.env };
    delete base.CLAUDE_CODE_SESSION_ID;
    return spawnSync(process.execPath, [POST, ...args], { cwd: work, env: { ...base, LANES_STATE: state, ...env }, encoding: 'utf8', windowsHide: true });
  };
  const index = () => JSON.parse(readFileSync(path.join(state, 'media', S1, 'index.json'), 'utf8'));
  beforeEach(() => {
    dir = mkdtempSync(path.join(os.tmpdir(), 'pm-post-'));
    state = path.join(dir, 'state');
    work = path.join(dir, 'work');
    mkdirSync(path.join(work, 'shots'), { recursive: true });
    writeFileSync(path.join(work, 'shots', 'arena.png'), PNG);
  });
  afterEach(() => rmSync(dir, { recursive: true, force: true }));

  it('copies a still into the session\'s folder with its caption, task and time', () => {
    const r = post(['shots/arena.png', '--caption', 'The moonlit shrine', '--task', 'M1 7']);
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /Posted 1 visual to the session's page/);
    const { entries, cwd } = index();
    assert.equal(cwd, work);
    assert.equal(entries.length, 1);
    assertMatches(entries[0], { kind: 'still', caption: 'The moonlit shrine', task: 'M1 7', source: path.join(work, 'shots', 'arena.png'), bytes: PNG.length, poster: null });
    assert.match(entries[0].file, /^\d{13}-0\.png$/);
    assert.ok(Math.abs(entries[0].time - Date.now()) < 60_000);
    assert.deepEqual(readFileSync(path.join(state, 'media', S1, entries[0].file)), PNG);
  });

  it('posts to --session when the shell has no session id', () => {
    const r = post(['shots/arena.png', '--session', S1], {});
    assert.equal(r.status, 0, r.stderr);
    assert.equal(index().entries.length, 1);
  });

  it('refuses with no session, an unknown kind or a missing file, storing nothing', () => {
    writeFileSync(path.join(work, 'notes.md'), '# x');
    for (const [args, env, says] of [
      [['shots/arena.png'], {}, /--session/],
      [['notes.md'], undefined, /Can't post notes\.md/],
      [['shots/gone.png'], undefined, /No such file: shots[\\/]gone\.png/],
    ]) {
      const r = post(args, env);
      assert.equal(r.status, 1);
      assert.match(r.stderr, says);
    }
    assert.equal(existsSync(path.join(state, 'media', S1)), false);
  });

  it('sweeps media older than 30 days when it posts', () => {
    assert.equal(post(['shots/arena.png']).status, 0);
    const i = index();
    const old = { ...i.entries[0], id: '1000000000000-0', file: '1000000000000-0.png', time: Date.now() - 31 * 24 * 60 * 60 * 1000 };
    writeFileSync(path.join(state, 'media', S1, old.file), PNG);
    writeFileSync(path.join(state, 'media', S1, 'index.json'), JSON.stringify({ ...i, entries: [old, ...i.entries] }));
    assert.equal(post(['shots/arena.png']).status, 0);
    assert.deepEqual(index().entries.map((e) => e.id === old.id), [false, false]);
    assert.equal(existsSync(path.join(state, 'media', S1, old.file)), false);
  });

  it('converts an AVI to an H.264 MP4 with a poster still', { skip: hasFfmpeg ? false : 'ffmpeg is not on the PATH' }, () => {
    execFileSync('ffmpeg', ['-v', 'error', '-f', 'lavfi', '-i', 'testsrc=duration=1:size=64x48:rate=10', '-c:v', 'mjpeg', path.join(work, 'shots', 'run.avi')],
      { windowsHide: true });
    const r = post(['shots/run.avi', '--caption', 'A run']);
    assert.equal(r.status, 0, r.stderr);
    const [e] = index().entries;
    assertMatches(e, { kind: 'clip', caption: 'A run' });
    assert.match(e.file, /\.mp4$/);
    assert.match(e.poster, /\.poster\.jpg$/);
    const probe = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,pix_fmt', '-of', 'csv=p=0',
      path.join(state, 'media', S1, e.file)], { encoding: 'utf8', windowsHide: true }).trim();
    assert.equal(probe, 'h264,yuv420p');
    assert.equal(e.bytes, statSync(path.join(state, 'media', S1, e.file)).size);
    assert.ok(existsSync(path.join(state, 'media', S1, e.poster)));
    assert.deepEqual(readdirSync(path.join(state, 'media', S1)).sort(), [e.file, e.poster, 'index.json'].sort());
  });
});
