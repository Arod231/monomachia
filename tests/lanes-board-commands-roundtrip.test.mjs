// The round trip for the session page's commands: Show me, Stop now and End
// work, from the page through the real server to the real hooks (harness in
// lanes-board-harness.mjs). There is no Approve: since Oct 6 approvals are
// given in the Claude app.
import { appendFileSync, existsSync, readFileSync, utimesSync } from 'node:fs';
import path from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { SESSION, startBoard } from './lanes-board-harness.mjs';
import { COMMANDS, STOP_NOW } from '../tools/lanes-board/sessions.mjs';

const OTHER = '22222222-2222-4333-8444-555555555555';
const TOOL = { hook_event_name: 'PreToolUse', tool_name: 'Bash', tool_input: { command: 'npm test' } };
const STOP = { hook_event_name: 'Stop', last_assistant_message: 'Task 12 is built.' };

describe('the round trip: the session page and its commands', () => {
  let board;
  before(async () => { board = await startBoard(); });
  after(async () => { await board?.stop(); });
  beforeEach(async () => {
    await board.post('/relay/away', { on: false });
    await board.post('/relay/unqueue', { session: SESSION });
    board.addSession(SESSION, 'Fixture session');
  });
  const command = (c, session = SESSION) => board.post('/session/command', { session, command: c });
  const idle = (id = SESSION) => { const old = new Date(Date.now() - 60 * 60 * 1000); utimesSync(board.transcriptOf(id), old, old); };

  it('lists each session with its state, branch, task and pull request, and opens its page', async () => {
    appendFileSync(board.transcriptOf(SESSION), `${JSON.stringify({ sessionId: SESSION, type: 'user', gitBranch: 'lane/pm-12', cwd: board.repo,
      timestamp: new Date().toISOString(), message: { content: 'Next task' } })}\n`);
    const [s] = (await board.get('/sessions')).body.sessions;
    assertMatches(s, { id: SESSION, title: 'Fixture session', state: 'working', branch: 'lane/pm-12', task: null, pr: null, summary: null, stopping: false });
    const d = (await board.get(`/session?id=${SESSION}`)).body;
    assertMatches(d, { id: SESSION, state: 'working', branch: 'lane/pm-12', endedAt: null });
    idle();
    assert.equal((await board.get(`/session?id=${SESSION}`)).body.state, 'idle');
  });

  it('refuses Approve: approvals are given in the Claude app', async () => {
    const r = await command('approve');
    assert.equal(r.status, 400);
    assert.match(r.body.error, /No such command/);
    assert.equal(COMMANDS.approve, undefined);
  });

  it('Show me reaches a working session before its next step', async () => {
    assertMatches(await command('show'), { status: 200, body: { delivered: false, when: 'next-step' } });
    const out = await board.stopHook(TOOL).done;
    assert.equal(out.hookSpecificOutput.additionalContext, COMMANDS.show);
  });

  it('a command to an idle session is queued for its next turn end', async () => {
    idle();
    assertMatches(await command('show'), { status: 200, body: { delivered: false, when: 'turn-end' } });
    assert.deepEqual(await board.hook(STOP).done, { decision: 'block', reason: COMMANDS.show });
  });

  it('Stop now refuses the session\'s tools until its turn ends, Away on or off, and the turn then simply ends', async () => {
    await board.post('/relay/away', { on: true });
    assertMatches(await command('stop'), { status: 200, body: { delivered: true, when: 'next-step' } });
    assert.equal((await board.get(`/session?id=${SESSION}`)).body.stopping, true);
    await board.post('/relay/reply', { session: SESSION, text: 'After the stop' });
    for (let i = 0; i < 2; i++) {
      const out = await board.stopHook(TOOL).done;
      assert.deepEqual(out, { hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: STOP_NOW } });
    }
    await board.post('/relay/unqueue', { session: SESSION });
    assert.equal(await board.hook(STOP).done, null, 'its turn ends: nothing holds it');
    assertMatches((await board.get(`/session?id=${SESSION}`)).body, { stopping: false });
    assert.equal(await board.stopHook(TOOL).done, null, 'its tools run again once the turn has ended');
  });

  it('Stop now has nothing to stop on an idle session', async () => {
    idle();
    assertMatches(await command('stop'), { status: 200, body: { delivered: false, when: 'idle' } });
    assert.equal(existsSync(path.join(board.relay, 'stopnow', `${SESSION}.json`)), false);
  });

  it('End work stops any session at its next step', async () => {
    board.addSession(OTHER, 'Not launched');
    assertMatches(await command('end', OTHER), { status: 200, body: { delivered: true, when: 'next-step' } });
    const stops = JSON.parse(readFileSync(path.join(board.root, 'stop.json'), 'utf8')).entries;
    assertMatches(stops.at(-1), { label: 'Not launched', sessions: [OTHER], worktree: null });
    const out = await board.stopHook(TOOL, { session: OTHER }).done;
    assertMatches(out, { continue: false, hookSpecificOutput: { permissionDecision: 'deny' } });
    assert.match(out.stopReason, /Work on Not launched was ended from the Project Manager/);
    assert.equal((await board.get(`/session?id=${OTHER}`)).body.state, 'ended');
    assert.equal(await board.stopHook(TOOL).done, null, 'other sessions carry on');
  });

  it('gives each session its Remote Control link from the app\'s record', async () => {
    board.appRecord(SESSION, 'Fixture session', { bridgeSessionIds: ['session_01Abc'] });
    assert.equal((await board.get('/sessions')).body.sessions.find((x) => x.id === SESSION).remote, 'https://claude.ai/code/session_01Abc');
    assert.equal((await board.get(`/session?id=${SESSION}`)).body.remote, 'https://claude.ai/code/session_01Abc');
  });

  it('refuses an unknown command or session', async () => {
    assert.equal((await command('dance')).status, 400);
    assert.equal((await command('stop', '../x')).status, 400);
  });
});
