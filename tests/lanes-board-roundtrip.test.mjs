// The round trip: a session's hook, the real Project Manager server and what
// the owner does from a page, end to end (harness in lanes-board-harness.mjs).
// Since Oct 6 nothing is held for the board: every prompt, plan and question
// is answered in the Claude app.

import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, utimesSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { SESSION, startBoard, waitFor } from './lanes-board-harness.mjs';

const IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1';
const ASK = (questions) => ({ hook_event_name: 'PermissionRequest', tool_name: 'AskUserQuestion', tool_input: { questions } });
const ONE = [{ header: 'Camera', question: 'Which camera?', options: [{ label: 'Close', description: 'Over the shoulder' }, { label: 'Far' }] }];
const BASH = { hook_event_name: 'PermissionRequest', tool_name: 'Bash', tool_input: { command: 'ls' } };
const PLAN = { hook_event_name: 'PermissionRequest', tool_name: 'ExitPlanMode', tool_input: { plan: '# Plan\n- Build it' },
  permission_suggestions: [{ type: 'setMode', mode: 'acceptEdits', destination: 'session' }], permission_mode: 'plan' };

describe('the round trip: Away, prompts and the hooks', () => {
  let board;
  before(async () => { board = await startBoard(); });
  after(async () => { await board?.stop(); });
  beforeEach(async () => { await board.post('/relay/away', { on: false }); });

  it('switches Away on and off, saying since when and from which device', async () => {
    const on = await board.post('/relay/away', { on: true }, { 'user-agent': IPHONE });
    assertMatches(on, { status: 200, body: { on: true, from: 'phone' } });
    assertMatches((await board.get('/away')).body, { on: true, from: 'phone' });
    assertMatches(JSON.parse(readFileSync(path.join(board.relay, 'away.json'), 'utf8')), { on: true, from: 'phone' });
    assertMatches((await board.post('/relay/away', { on: false })).body, { on: false, from: 'PC' });
    assertMatches((await board.get('/away')).body, { on: false });
  });

  it('leaves every permission prompt, plan and question to the app, Away on or off, holding nothing', async () => {
    const events = () => readFileSync(path.join(board.relay, 'events.jsonl'), 'utf8').trim().split('\n').map((l) => JSON.parse(l));
    for (const on of [false, true]) {
      await board.post('/relay/away', { on });
      for (const prompt of [BASH, PLAN]) {
        const started = Date.now();
        assert.equal(await board.hook(prompt).done, null);
        assert.ok(Date.now() - started < 5000, 'the hook answers at once');
      }
      assert.equal(await board.hook(ASK(ONE)).done, null);
      assertMatches(events().at(-1), { kind: 'asked-in-app', session: SESSION, questions: ['Which camera?'] });
    }
    assert.equal(existsSync(path.join(board.relay, 'pending')), false, 'nothing held for the board');
  });

  it('has no Questions tab and takes no answers', async () => {
    assert.equal((await board.get('/questions')).body, null, 'no JSON: the page itself');
    assert.equal((await board.post('/relay/answer', { id: 'ab12-cd34', behavior: 'allow' })).status, 404);
    assert.equal((await board.post('/relay/on', { session: SESSION, on: true })).status, 404);
  });

  it('says whether the installed hooks are this version\'s, before and after an install', async () => {
    const hooks = async () => (await board.get('/sessions')).body.hooks;
    const before = await hooks();
    assert.equal(before.current, false);
    assert.match(before.problems.join(' '), /relay hook isn't installed/);
    const r = spawnSync(process.execPath, [fileURLToPath(new URL('../tools/lanes-board/install-hooks.mjs', import.meta.url))],
      { env: { ...process.env, LANES_CLAUDE_DIR: board.claude }, encoding: 'utf8' });
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(await hooks(), { current: true, problems: [] });
  });

  it('only takes actions from its own pages', async () => {
    const r = await board.post('/relay/away', { on: true }, { origin: 'http://evil.example' });
    assert.equal(r.status, 403);
    assert.equal((await board.get('/away')).body.on, false);
  });
});

describe('the round trip: turn ends, replies and the inbox', () => {
  let board;
  before(async () => { board = await startBoard(); });
  after(async () => { await board?.stop(); });
  beforeEach(async () => {
    await board.post('/relay/away', { on: false });
    await board.post('/relay/unqueue', { session: SESSION });
  });

  const STOP = (last = 'Task 6 is done. Shall I go on to task 7?') => ({ hook_event_name: 'Stop', last_assistant_message: last, stop_hook_active: false });
  const TOOL = { hook_event_name: 'PreToolUse', tool_name: 'Bash', tool_input: { command: 'ls' } };
  const inbox = () => { try { return readdirSync(path.join(board.relay, 'inbox', SESSION)); } catch { return []; } };
  // How long ago the session last wrote its transcript: recent means at work.
  const lastWrote = (msAgo) => { const t = new Date(Date.now() - msAgo); utimesSync(board.transcriptOf(SESSION), t, t); };

  it('lets a turn end at once, Away on or off, noting it for the bell', async () => {
    for (const on of [false, true]) {
      await board.post('/relay/away', { on });
      assert.equal(await board.hook(STOP('All done.')).done, null);
      const events = readFileSync(path.join(board.relay, 'events.jsonl'), 'utf8').trim().split('\n').map((l) => JSON.parse(l));
      assertMatches(events.at(-1), { kind: 'turn-finished', session: SESSION, last: 'All done.' });
    }
  });

  it('queues a reply, and the session\'s next turn end takes it, Away or not', async () => {
    lastWrote(60 * 60 * 1000);
    assertMatches((await board.post('/relay/reply', { session: SESSION, text: 'Then rename it' })).body, { delivered: false, when: 'turn-end' });
    assertMatches((await board.get('/sessions')).body.sessions.find((s) => s.id === SESSION), { queued: 1 });
    assert.deepEqual((await board.get(`/session?id=${SESSION}`)).body.queued.map((m) => m.text), ['The owner replied from the Project Manager:\n\nThen rename it']);
    assert.deepEqual(await board.hook(STOP()).done, { decision: 'block', reason: 'The owner replied from the Project Manager:\n\nThen rename it' });
    assert.deepEqual(inbox(), []);
  });

  it('gives a working session the oldest message before its next tool, one per call, and the turn end the rest', async () => {
    lastWrote(0);
    assertMatches((await board.post('/relay/reply', { session: SESSION, text: 'First' })).body, { delivered: false, when: 'next-step' });
    await board.post('/relay/reply', { session: SESSION, text: 'Second' });
    await board.post('/relay/reply', { session: SESSION, text: 'Third' });
    assert.deepEqual(await board.stopHook(TOOL).done,
      { hookSpecificOutput: { hookEventName: 'PreToolUse', additionalContext: 'The owner replied from the Project Manager:\n\nFirst' } });
    assert.equal(inbox().length, 2);
    assert.deepEqual(await board.hook(STOP()).done, { decision: 'block',
      reason: 'The owner replied from the Project Manager:\n\nSecond\n\nThe owner replied from the Project Manager:\n\nThird' });
    assert.equal(await board.stopHook(TOOL).done, null);
  });

  it('clears what was queued', async () => {
    await board.post('/relay/reply', { session: SESSION, text: 'Never mind' });
    assert.equal(inbox().length, 1);
    await board.post('/relay/unqueue', { session: SESSION });
    assert.deepEqual(inbox(), []);
    assertMatches((await board.get('/sessions')).body.sessions.find((s) => s.id === SESSION), { queued: 0 });
  });
});

describe('the round trip: the bell', () => {
  let board;
  before(async () => { board = await startBoard(); });
  after(async () => { await board?.stop(); });
  beforeEach(async () => {
    await board.post('/relay/away', { on: false });
    await board.post('/bell/read', { all: true });
  });
  const unread = async () => (await board.get('/bell')).body.records.filter((r) => !r.read);

  it('tells that a session waits on questions in the app, Away on or off, pointing at its session', async () => {
    for (const on of [false, true]) {
      await board.post('/relay/away', { on });
      assert.equal(await board.hook(ASK(ONE)).done, null);
      const [rec] = await waitFor(async () => { const u = await unread(); return u.length ? u : null; }, 8000, 'a notification');
      assertMatches(rec, { kind: 'asked', session: SESSION, text: 'Fixture session is waiting on you to answer questions in the app',
        detail: 'Which camera?', target: { tab: 'sessions', session: SESSION } });
      await board.post('/bell/read', { all: true });
    }
  });

  it('tells of a finished turn, pointing at its session, read on every device once one marks it', async () => {
    await board.hook({ hook_event_name: 'Stop', last_assistant_message: 'Task 9 is built.' }).done;
    const [rec] = await waitFor(async () => { const u = await unread(); return u.length ? u : null; }, 8000, 'a notification');
    assertMatches(rec, { kind: 'turn', text: 'Fixture session finished its turn', detail: 'Task 9 is built.', target: { tab: 'sessions', session: SESSION } });
    assert.equal((await unread()).length, 1, 'one record, however often the bell is read');
    const marked = await board.post('/bell/read', { ids: [rec.id] }, { 'user-agent': IPHONE });
    assertMatches(marked, { status: 200, body: { unread: 0 } });
    const onPc = (await board.get('/bell')).body;
    assert.equal(onPc.unread, 0);
    assert.equal(onPc.records.find((r) => r.id === rec.id).read, true);
    assert.match(readFileSync(path.join(board.state, 'notifications.json'), 'utf8'), new RegExp(rec.id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  });

  it('never tells of a permission prompt or a plan: those are answered in the app', async () => {
    await board.post('/relay/away', { on: true });
    assert.equal(await board.hook(BASH).done, null);
    assert.equal(await board.hook(PLAN).done, null);
    await new Promise((r) => setTimeout(r, 300));
    assert.deepEqual(await unread(), []);
  });

  it('refuses a mark with nothing named', async () => {
    assert.equal((await board.post('/bell/read', {})).status, 400);
  });
});
