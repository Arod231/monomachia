// The round trip for a session started outside git and then moved into a
// worktree (as lane sessions launched from a scratch folder are): its
// transcript records the branch as "HEAD", so the board takes the branch
// checked out in its worktree, and its page, Merge and Docs find its pull request.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';
import { assertMatches } from './assert-matches.mjs';
import { startBoard, waitFor } from './lanes-board-harness.mjs';

const STUB = fileURLToPath(new URL('./lanes-board-gh-stub.mjs', import.meta.url));
const MOVED = '66666666-2222-4333-8444-555555555555';

describe('the round trip: a session moved into a worktree', () => {
  let board, dir;
  before(async () => {
    dir = mkdtempSync(path.join(os.tmpdir(), 'pm-branch-'));
    const fixture = path.join(dir, 'fixture.json');
    const log = path.join(dir, 'log.jsonl');
    writeFileSync(log, '');
    const view = { number: 9, title: 'Moved lane', url: 'https://github.com/o/r/pull/9', state: 'OPEN', isDraft: true, mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN', baseRefName: 'main', headRefName: 'lane/moved', headRefOid: 'abc', statusCheckRollup: [], body: '', files: [] };
    writeFileSync(fixture, JSON.stringify({ repo: 'o/r',
      prs: [{ number: 9, title: 'Moved lane', headRefName: 'lane/moved', baseRefName: 'main', isDraft: true, url: 'https://github.com/o/r/pull/9' }],
      views: { 9: view } }));
    board = await startBoard({ env: { LANES_GH: STUB, LANES_GH_FIXTURE: fixture, LANES_GH_LOG: log } });
    const tree = path.join(board.root, 'wt');
    execFileSync('git', ['worktree', 'add', '-q', '-b', 'lane/moved', tree], { cwd: board.repo, windowsHide: true, stdio: 'ignore' });
    const line = (o) => JSON.stringify({ sessionId: MOVED, cwd: tree, gitBranch: 'HEAD', timestamp: new Date().toISOString(), ...o });
    writeFileSync(board.transcriptOf(MOVED), [
      line({ type: 'custom-title', customTitle: 'Moved session' }),
      line({ type: 'user', message: { content: 'Build it' } }),
    ].join('\n') + '\n');
  });
  after(async () => { await board?.stop(); rmSync(dir, { recursive: true, force: true }); });

  it("takes its worktree's branch, so its card and page show its pull request", async () => {
    const s = await waitFor(async () => (await board.get('/sessions')).body.sessions.find((x) => x.id === MOVED && x.pr), 20000, 'the moved session\'s pull request');
    assertMatches(s, { branch: 'lane/moved', pr: { number: 9 } });
    assertMatches((await board.get(`/session?id=${MOVED}`)).body, { branch: 'lane/moved', pr: { number: 9 } });
  });

  it('lets Docs find that pull request too', async () => {
    assertMatches((await board.get(`/docs?session=${MOVED}`)).body, { branch: 'lane/moved', pr: { number: 9 } });
  });
});
