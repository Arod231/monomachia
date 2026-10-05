// The round trip for the pages' "New session" button: the real Project Manager
// server (a dry run, so no link opens and no Send is pressed) queues a session
// with no tasks, starts it, and links it to the app session its first prompt
// started (harness in lanes-board-harness.mjs).

import { writeFileSync } from 'node:fs';
import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { startBoard, waitFor } from './lanes-board-harness.mjs';

const NEW = '99999999-8888-4777-8666-555555555555';

describe('the round trip: a new session', () => {
  let board;
  before(async () => { board = await startBoard(); });
  after(async () => { await board?.stop(); });

  const launchOf = async (id) => ((await board.get('/data')).body.launches ?? []).find((l) => l.id === id);

  it('starts a session in the repository with a first prompt that carries its tag', async () => {
    const r = await board.post('/session/new', {});
    assert.equal(r.status, 200);
    const l = r.body.launched;
    assertMatches(l, { kind: 'session', tasks: [] });
    assert.match(l.tag, /^pm-session-/);
    // The dry run prints the link it would open, then presses Send.
    const link = await waitFor(() => board.log().match(/\[dry run\] (claude:\/\/code\/new\S+)/)?.[1], 8000, 'the link');
    const url = new URL(link);
    assert.equal(url.searchParams.get('folder'), board.repo);
    assert.ok(url.searchParams.get('q').includes(`(${l.tag})`));
    assertMatches(await waitFor(() => launchOf(l.id), 8000, 'the launch on /data'), { kind: 'session', start: { state: 'starting' }, session: null });

    // The app records the session and its transcript starts with that prompt.
    board.appRecord(NEW, 'New session');
    writeFileSync(board.transcriptOf(NEW), `${JSON.stringify({ sessionId: NEW, timestamp: new Date().toISOString(), type: 'user', cwd: board.repo,
      message: { content: url.searchParams.get('q') } })}\n`);
    const linked = await waitFor(async () => { const x = await launchOf(l.id); return x?.session ? x : null; }, 15000, 'the launch linked to its session');
    assertMatches(linked, { session: `local_${NEW}`, start: { state: 'started' } });
  });

  it('refuses to end a new session as if it were a lane', async () => {
    const { body } = await board.post('/session/new', {});
    const r = await board.post('/end', { launch: body.launched.id });
    assert.equal(r.status, 400);
    assert.match(r.body.error, /no tasks/);
  });
});
