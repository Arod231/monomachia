// The round trip for "ready to merge": the bell is told once when a session's
// pull request turns ready, and the board itself never merges (since Oct 6,
// merges are done on GitHub or by a session told to), against a stand-in gh
// (lanes-board-gh-stub.mjs) and the real server.
import { appendFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { SESSION, startBoard, waitFor } from './lanes-board-harness.mjs';

const STUB = fileURLToPath(new URL('./lanes-board-gh-stub.mjs', import.meta.url));
const run = (name, conclusion) => ({ __typename: 'CheckRun', name, status: 'COMPLETED', conclusion });
const view = (extra = {}) => ({ number: 51, title: 'PM tasks', url: 'https://github.com/o/r/pull/51', state: 'OPEN', isDraft: false,
  mergeable: 'MERGEABLE', mergeStateStatus: 'CLEAN', baseRefName: 'tools/pm', headRefName: 'lane/pm-13', headRefOid: 'abc123',
  statusCheckRollup: [run('test', 'SUCCESS')], ...extra });

describe('the round trip: ready to merge', () => {
  let board, dir, fixture, logFile;
  const setView = (extra) => {
    writeFileSync(fixture, JSON.stringify({ repo: 'o/r',
      prs: [{ number: 51, title: 'PM tasks', headRefName: 'lane/pm-13', baseRefName: 'tools/pm', isDraft: false, url: 'https://github.com/o/r/pull/51' }],
      views: { 51: view(extra) } }));
  };
  const calls = () => readFileSync(logFile, 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l));
  before(async () => {
    dir = mkdtempSync(path.join(os.tmpdir(), 'pm-gh-'));
    fixture = path.join(dir, 'fixture.json');
    logFile = path.join(dir, 'log.jsonl');
    writeFileSync(logFile, '');
    setView({ isDraft: true });
    board = await startBoard({ env: { LANES_GH: STUB, LANES_GH_FIXTURE: fixture, LANES_GH_LOG: logFile, LANES_MERGE_POLL_MS: '300' } });
  });
  after(async () => { await board?.stop(); rmSync(dir, { recursive: true, force: true }); });
  beforeEach(async () => {
    board.addSession(SESSION, 'Fixture session');
    appendFileSync(board.transcriptOf(SESSION), `${JSON.stringify({ sessionId: SESSION, type: 'user', gitBranch: 'lane/pm-13', cwd: board.repo,
      timestamp: new Date().toISOString(), message: { content: 'Next' } })}\n`);
    await board.post('/relay/away', { on: false });
    await board.post('/relay/unqueue', { session: SESSION });
    // The board lists open pull requests once it is up: wait for that first list.
    await waitFor(async () => (await board.get('/sessions')).body.sessions[0]?.pr, 20000, "the session's pull request");
  });

  it('shows the session\'s pull request, and has no route that merges or updates it', async () => {
    setView({});
    assert.equal((await board.get('/sessions')).body.sessions[0].pr.number, 51);
    assert.equal((await board.get(`/merge?session=${SESSION}`)).body, null, 'no JSON: the page itself');
    assert.equal((await board.post('/merge', { session: SESSION, number: 51 })).status, 404);
    assert.equal((await board.post('/merge/update', { session: SESSION, number: 51 })).status, 404);
    assert.ok(!calls().some((c) => c.args[1] === 'merge' || c.args[1] === 'update-branch'), 'nothing was merged or updated');
  });

  it('tells the bell once when a pull request turns ready to merge', async () => {
    setView({ isDraft: true });
    await new Promise((r) => setTimeout(r, 800));
    const merges = async () => (await board.get('/bell')).body.records.filter((x) => x.kind === 'merge');
    const before = new Set((await merges()).map((x) => x.id));
    setView({});
    const rec = await waitFor(async () => (await merges()).find((x) => !before.has(x.id)), 8000, 'a ready-to-merge record');
    assertMatches(rec, { text: 'Fixture session: pull request #51 is ready to merge on GitHub', detail: 'PM tasks into tools/pm', target: { tab: 'sessions', session: SESSION } });
    await new Promise((r) => setTimeout(r, 1000));
    assert.equal((await merges()).length, before.size + 1, 'once while it stays ready');
  });
});
