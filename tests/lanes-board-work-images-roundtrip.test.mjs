// The round trip for "Images of the work": images in a session's transcript
// show on its page and are served from the transcript itself, and only those.
import { appendFileSync } from 'node:fs';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { SESSION, startBoard } from './lanes-board-harness.mjs';

const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);

describe('the round trip: images of the work', () => {
  let board, base;
  const add = (o) => appendFileSync(board.transcriptOf(SESSION), `${JSON.stringify({ sessionId: SESSION, cwd: board.repo, timestamp: new Date().toISOString(), ...o })}\n`);
  const call = (id, name, input) => add({ type: 'assistant', message: { role: 'assistant', content: [{ type: 'tool_use', id, name, input }] } });
  const result = (id, data, type) => add({ type: 'user', message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: id,
    content: [{ type: 'image', source: { type: 'base64', media_type: type, data: data.toString('base64') } }] }] } });
  before(async () => {
    board = await startBoard();
    base = `http://localhost:${board.port}`;
    call('r1', 'Read', { file_path: path.join(board.repo, 'shots', 'arena.png') });
    result('r1', PNG, 'image/png');
    call('c1', 'mcp__Claude_Browser__computer', { action: 'screenshot' });
    result('c1', JPEG, 'image/jpeg');
    call('b1', 'mcp__blender__look', {});
    result('b1', JPEG, 'image/jpeg');
  });
  after(async () => { await board?.stop(); });

  it("lists them on the session's page, newest first, without the browser screenshot", async () => {
    const d = (await board.get(`/session?id=${SESSION}`)).body;
    assert.deepEqual(d.workImages.map((w) => w.caption), ['Blender viewport', 'arena.png']);
    assertMatches(d.workImages[1], { kind: 'still', source: path.join(board.repo, 'shots', 'arena.png') });
    assert.match(d.workImages[1].url, new RegExp(`^/work/${SESSION}/\\d+-0$`));
  });

  it('serves each from the transcript, and nothing else', async () => {
    const [blender, arena] = (await board.get(`/session?id=${SESSION}`)).body.workImages;
    const r = await fetch(base + arena.url);
    assert.equal(r.status, 200);
    assert.equal(r.headers.get('content-type'), 'image/png');
    assert.deepEqual(Buffer.from(await r.arrayBuffer()), PNG);
    assert.equal((await fetch(base + blender.url)).headers.get('content-type'), 'image/jpeg');
    const browserLine = Number(arena.url.split('/').pop().split('-')[0]) + 2; // the browser screenshot's result
    for (const p of [`/work/${SESSION}/${browserLine}-0`, `/work/${SESSION}/0-0`, '/work/not-a-session/1-0', `/work/${SESSION}/x`]) {
      assert.equal((await fetch(base + p)).status, 404, p);
    }
  });
});
