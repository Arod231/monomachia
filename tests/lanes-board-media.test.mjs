// The media store's rules (tools/lanes-board/media.mjs): what `npm run post`
// takes, which session it posts to, and what the sweep removes.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { MEDIA_CAP_BYTES, MEDIA_KEEP_MS, mediaKind, mediaToSweep, postArgs, sessionOf } from '../tools/lanes-board/media.mjs';

const S1 = '11111111-2222-4333-8444-555555555555';
const DAY = 24 * 60 * 60 * 1000;

describe('mediaKind', () => {
  it('copies stills and MP4 clips, and converts other video', () => {
    assert.deepEqual(['a.PNG', 'b.jpg', 'c.jpeg', 'd.webp', 'e.gif'].map(mediaKind), ['still', 'still', 'still', 'still', 'still']);
    assert.equal(mediaKind('shots/run.mp4'), 'clip');
    assert.deepEqual(['a.avi', 'b.MOV', 'c.webm', 'd.mkv', 'e.m4v'].map(mediaKind), ['video', 'video', 'video', 'video', 'video']);
  });
  it('refuses anything else', () => {
    assert.equal(mediaKind('notes.md'), null);
    assert.equal(mediaKind('noext'), null);
  });
});

describe('postArgs', () => {
  it('reads files, a caption, a task and a session in any order', () => {
    assert.deepEqual(postArgs(['a.png', '--caption', 'The new arena', 'b.avi', '--task', 'M1 7', '--session', S1]),
      { files: ['a.png', 'b.avi'], caption: 'The new arena', task: 'M1 7', session: S1 });
    assert.deepEqual(postArgs(['--caption=Two words', 'a.png']), { files: ['a.png'], caption: 'Two words', task: null, session: null });
  });
  it('needs at least one file, and a value after each flag', () => {
    assert.throws(() => postArgs(['--caption', 'x']), /Name at least one file/);
    assert.throws(() => postArgs(['a.png', '--caption']), /--caption needs a value/);
    assert.throws(() => postArgs(['a.png', '--colour', 'red']), /Unknown option --colour/);
  });
});

describe('sessionOf', () => {
  it("takes --session, else the shell's own session id", () => {
    assert.equal(sessionOf({ flag: S1, env: {} }), S1);
    assert.equal(sessionOf({ flag: null, env: { CLAUDE_CODE_SESSION_ID: S1 } }), S1);
  });
  it('says how to name one when neither is there, and refuses a bad id', () => {
    assert.throws(() => sessionOf({ flag: null, env: {} }), /--session/);
    assert.throws(() => sessionOf({ flag: '../x', env: {} }), /Bad session id/);
  });
});

describe('mediaToSweep', () => {
  const now = 100 * DAY;
  const e = (id, ageDays, bytes) => ({ session: S1, id, time: now - ageDays * DAY, bytes });
  it('removes media older than 30 days', () => {
    assert.equal(MEDIA_KEEP_MS, 30 * DAY);
    const gone = mediaToSweep([e('old', 31, 10), e('new', 29, 10)], { now });
    assert.deepEqual(gone.map((x) => x.id), ['old']);
  });
  it('then the oldest beyond the cap, keeping the newest', () => {
    assert.equal(MEDIA_CAP_BYTES, 5 * 1024 ** 3);
    const gone = mediaToSweep([e('a', 3, 40), e('b', 1, 40), e('c', 2, 40), e('d', 40, 1)], { now, capBytes: 100 });
    assert.deepEqual(gone.map((x) => x.id).sort(), ['a', 'd']);
  });
  it('keeps everything under both limits', () => {
    assert.deepEqual(mediaToSweep([e('a', 1, 10)], { now, capBytes: 100 }), []);
  });
});
