// The round trip for posted visuals: a session runs `npm run post`, and the
// real server shows the shot on its page, serves the file (video in ranges, as
// the iPhone asks for it), tells the bell once per minute, and keeps a page for
// a session known only by its media.
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { SESSION, startBoard, waitFor } from './lanes-board-harness.mjs';

const POST = fileURLToPath(new URL('../tools/lanes-board/post.mjs', import.meta.url));
const OTHER = '99999999-2222-4333-8444-555555555555';
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const CLIP = Buffer.alloc(1000, 7); // stands in for an MP4: post copies MP4s as they are

describe('the round trip: posted visuals', () => {
  let board, base, work;
  const post = (args, session = SESSION) => {
    const r = spawnSync(process.execPath, [POST, ...args], { cwd: work, encoding: 'utf8', windowsHide: true,
      env: { ...process.env, LANES_STATE: board.state, CLAUDE_CODE_SESSION_ID: session } });
    assert.equal(r.status, 0, r.stderr);
  };
  before(async () => {
    board = await startBoard();
    base = `http://localhost:${board.port}`;
    work = path.join(board.root, 'work');
    mkdirSync(work, { recursive: true });
    writeFileSync(path.join(work, 'arena.png'), PNG);
    writeFileSync(path.join(work, 'run.mp4'), CLIP);
    post(['arena.png', '--caption', 'The shrine <at night>', '--task', 'M1 7']);
    post(['run.mp4', '--caption', 'A run']);
  });
  after(async () => { await board?.stop(); });

  it("lists the posts on the session's page, newest first, with where to fetch each", async () => {
    const d = (await board.get(`/session?id=${SESSION}`)).body;
    assert.equal(d.visuals.length, 2);
    assertMatches(d.visuals[0], { kind: 'clip', caption: 'A run', task: null });
    assertMatches(d.visuals[1], { kind: 'still', caption: 'The shrine <at night>', task: 'M1 7', poster: null });
    assert.match(d.visuals[1].url, new RegExp(`^/media/${SESSION}/\\d{13}-0\\.png$`));
    const r = await fetch(base + d.visuals[1].url);
    assert.equal(r.status, 200);
    assert.equal(r.headers.get('content-type'), 'image/png');
    assert.deepEqual(Buffer.from(await r.arrayBuffer()), PNG);
  });

  it('serves a clip in byte ranges', async () => {
    const clip = (await board.get(`/session?id=${SESSION}`)).body.visuals[0];
    const whole = await fetch(base + clip.url);
    assert.equal(whole.headers.get('content-type'), 'video/mp4');
    assert.equal(whole.headers.get('accept-ranges'), 'bytes');
    assert.equal((await whole.arrayBuffer()).byteLength, 1000);
    const part = await fetch(base + clip.url, { headers: { range: 'bytes=10-19' } });
    assert.equal(part.status, 206);
    assert.equal(part.headers.get('content-range'), 'bytes 10-19/1000');
    assert.equal((await part.arrayBuffer()).byteLength, 10);
    assert.equal((await fetch(base + clip.url, { headers: { range: 'bytes=5000-' } })).status, 416);
  });

  it('serves nothing but the store\'s media files', async () => {
    for (const p of [`/media/${SESSION}/index.json`, `/media/${SESSION}/..%2F..%2Fnotifications.json`, '/media/not-a-session/x.png', `/media/${SESSION}/1234.png`]) {
      assert.equal((await fetch(base + p)).status, 404, p);
    }
  });

  it('tells the bell once for both posts of the same minute', async () => {
    const records = await waitFor(async () => {
      const b = (await board.get('/bell')).body;
      return b.records.some((r) => r.kind === 'visuals' && r.count === 2) && b.records;
    }, 8000, 'a visuals record');
    const v = records.filter((r) => r.kind === 'visuals');
    assert.equal(v.length, 1);
    assertMatches(v[0], { session: SESSION, text: 'Fixture session posted 2 visuals', detail: 'A run', target: { tab: 'sessions', session: SESSION, visuals: true } });
  });

  it('opens a page for a session known only by its media, and lists it under Older', async () => {
    post(['arena.png', '--caption', 'From a deleted session'], OTHER);
    const d = (await board.get(`/session?id=${OTHER}`)).body;
    assertMatches(d, { id: OTHER, gone: true, cwd: work, entries: [], queued: [] });
    assert.deepEqual(d.visuals.map((v) => v.caption), ['From a deleted session']);
    const list = (await board.get('/sessions')).body;
    assert.equal(list.sessions.some((s) => s.id === OTHER), false);
    assertMatches(list.older.find((s) => s.id === OTHER), { id: OTHER, count: 1, cwd: work });
    assert.equal(list.older.some((s) => s.id === SESSION), false);
  });
});
