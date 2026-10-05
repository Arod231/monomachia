// The round trip: a session's hook, the real Project Manager server and the
// owner's answer from a page, end to end (harness in lanes-board-harness.mjs).

import { readdirSync, readFileSync, rmSync } from 'node:fs';
import path from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { SESSION, startBoard, waitFor } from './lanes-board-harness.mjs';

const IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1';
const ASK = (questions) => ({ hook_event_name: 'PermissionRequest', tool_name: 'AskUserQuestion', tool_input: { questions } });
const ONE = [{ header: 'Camera', question: 'Which camera?', options: [{ label: 'Close', description: 'Over the shoulder' }, { label: 'Far' }] }];
const TWO = [
  { question: 'Which weapons?', multiSelect: true, options: [{ label: 'Katana' }, { label: 'Spear' }, { label: 'Fists' }] },
  { question: 'Which arena?', options: [{ label: 'Shrine', preview: '+--+\n|<>|\n+--+' }, { label: 'Bridge' }] },
];

describe('the round trip: Away and the Questions tab', () => {
  let board;
  before(async () => { board = await startBoard(); });
  after(async () => { await board?.stop(); });
  beforeEach(async () => { await board.post('/relay/away', { on: false }); });

  // The held items the Questions tab lists, once the hook has written one.
  const held = () => waitFor(async () => {
    const q = (await board.get('/questions')).body;
    return q.groups.length ? q : null;
  }, 8000, 'a held item in /questions');

  it('switches Away on and off, saying since when and from which device', async () => {
    const on = await board.post('/relay/away', { on: true }, { 'user-agent': IPHONE });
    assertMatches(on, { status: 200, body: { on: true, from: 'phone' } });
    assertMatches((await board.get('/questions')).body, { away: { on: true, from: 'phone' }, count: 0, groups: [] });
    assertMatches(JSON.parse(readFileSync(path.join(board.relay, 'away.json'), 'utf8')), { on: true, from: 'phone' });
    assertMatches((await board.post('/relay/away', { on: false })).body, { on: false, from: 'PC' });
  });

  it('leaves a question to the app while Away is off, and notes it', async () => {
    const { done } = board.hook(ASK(ONE));
    assert.equal(await done, null);
    const events = readFileSync(path.join(board.relay, 'events.jsonl'), 'utf8').trim().split('\n').map((l) => JSON.parse(l));
    assertMatches(events.at(-1), { kind: 'asked-in-app', session: SESSION, questions: ['Which camera?'] });
    assertMatches((await board.get('/questions')).body, { away: { on: false }, groups: [] });
  });

  it('holds a question while Away is on and answers it with one pick', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(ONE));
    const q = await held();
    assert.equal(q.count, 1);
    assertMatches(q.groups[0], { session: SESSION, title: 'Fixture session', cwd: board.repo });
    const item = q.groups[0].items[0];
    assertMatches(item, { kind: 'question', tool: 'AskUserQuestion', input: { questions: ONE } });
    assert.equal(typeof q.groups[0].since, 'number');
    assertMatches(await board.post('/relay/answer', { id: item.id, picks: ['Close'] }), { status: 200, body: { ok: true } });
    assert.deepEqual(await done, { hookSpecificOutput: { hookEventName: 'PermissionRequest',
      decision: { behavior: 'allow', updatedInput: { questions: ONE, answers: { 'Which camera?': 'Close' } } } } });
    assert.deepEqual((await board.get('/questions')).body.groups, []);
  });

  it('answers several questions at once: a multi-select with Other, and a single pick', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(TWO));
    const item = (await held()).groups[0].items[0];
    await board.post('/relay/answer', { id: item.id, picks: [['Katana', 'Spear', 'A whip'], ['Shrine']] });
    assert.deepEqual((await done).hookSpecificOutput.decision.updatedInput.answers,
      { 'Which weapons?': 'Katana, Spear, A whip', 'Which arena?': 'Shrine' });
  });

  it('takes a free-form reply instead of picks, as a decline with the owner\'s words', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(ONE));
    const item = (await held()).groups[0].items[0];
    await board.post('/relay/answer', { id: item.id, reply: 'Neither: try a low angle' });
    assert.deepEqual((await done).hookSpecificOutput.decision, { behavior: 'deny',
      message: 'The owner answered from the Project Manager instead of picking an option:\n\nNeither: try a low angle' });
  });

  it('refuses a late answer, and a second one', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(ONE));
    const item = (await held()).groups[0].items[0];
    assert.equal((await board.post('/relay/answer', { id: item.id, picks: ['Far'] })).status, 200);
    const again = await board.post('/relay/answer', { id: item.id, picks: ['Close'] });
    assert.equal(again.status, 400);
    assert.match(again.body.error, /already answered, handed back or timed out/);
    await done;
    const late = await board.post('/relay/answer', { id: item.id, picks: ['Close'] });
    assert.equal(late.status, 400);
    assert.match(late.body.error, /already answered, handed back or timed out/);
  });

  it('refuses an answer that doesn\'t fit the question', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(ONE));
    const item = (await held()).groups[0].items[0];
    const bad = await board.post('/relay/answer', { id: item.id, picks: [['Close', 'Far']] });
    assert.equal(bad.status, 400);
    assert.match(bad.body.error, /takes one answer/);
    await board.post('/relay/answer', { id: item.id, release: true });
    assert.equal(await done, null);
  });

  it('hands every held question back to the app when Away goes off', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(ONE));
    await held();
    await board.post('/relay/away', { on: false });
    assert.equal(await done, null);
    assert.deepEqual((await board.get('/questions')).body.groups, []);
    assert.deepEqual(readdirSync(path.join(board.relay, 'pending')), []);
  });

  // The spike found that a hook keeps holding after its session is deleted. The
  // holds here could wait two minutes, so ending within 15 s is the board's doing.
  const released = (done) => Promise.race([done,
    new Promise((_, no) => setTimeout(() => no(new Error('the hook was not released')), 15000))]);
  it('drops an item whose session\'s transcript is gone, releasing its hook', async () => {
    const id = '22222222-2222-4333-8444-555555555555';
    const transcript = board.addSession(id, 'Deleted by transcript');
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(ONE), { session: id, waitMs: 120000 });
    assert.equal((await held()).groups[0].session, id);
    rmSync(transcript);
    assert.equal(await released(done), null);
    assertMatches((await board.get('/questions')).body, { count: 0, groups: [] });
  });

  it('drops an item whose session\'s app record is gone, releasing its hook', async () => {
    const id = '33333333-2222-4333-8444-555555555555';
    board.addSession(id, 'Deleted in the app');
    const record = board.appRecord(id, 'Deleted in the app');
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(ONE), { session: id, waitMs: 120000 });
    assertMatches((await held()).groups[0], { session: id, app: `local_${id}` });
    rmSync(record);
    assert.equal(await released(done), null);
    assertMatches((await board.get('/questions')).body, { count: 0, groups: [] });
  });

  it('keeps an item whose session never had an app record (a CLI session)', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(ASK(ONE));
    const item = (await held()).groups[0].items[0];
    await new Promise((r) => setTimeout(r, 300));
    assert.equal((await board.get('/questions')).body.groups[0].items[0].id, item.id);
    await board.post('/relay/answer', { id: item.id, release: true });
    assert.equal(await done, null);
  });

  it('refuses the old per-session switch', async () => {
    assert.equal((await board.post('/relay/on', { session: SESSION, on: true })).status, 404);
  });

  // Task 7: permission prompts and plans.
  const RULE = [{ type: 'addRules', rules: [{ toolName: 'Bash', ruleContent: 'npm test:*' }], behavior: 'allow', destination: 'localSettings' }];
  const PERMIT = { hook_event_name: 'PermissionRequest', tool_name: 'Bash', tool_input: { command: 'npm test', description: 'Run the tests' },
    permission_suggestions: RULE };
  const MODES = [{ type: 'setMode', mode: 'acceptEdits', destination: 'session' }, { type: 'setMode', mode: 'default', destination: 'session' }];
  const PLAN = { hook_event_name: 'PermissionRequest', tool_name: 'ExitPlanMode', tool_input: { plan: '# Plan\n- Build it' },
    permission_suggestions: MODES, permission_mode: 'plan' };
  const decision = async (done) => (await done).hookSpecificOutput.decision;

  it('holds a permission prompt showing the command, and allows it once', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(PERMIT);
    const item = (await held()).groups[0].items[0];
    assertMatches(item, { kind: 'permission', tool: 'Bash', input: { command: 'npm test' }, suggestions: RULE });
    await board.post('/relay/answer', { id: item.id, behavior: 'allow' });
    assert.deepEqual(await decision(done), { behavior: 'allow' });
  });

  it('allows a permission always, passing the suggested rule back', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(PERMIT);
    const item = (await held()).groups[0].items[0];
    await board.post('/relay/answer', { id: item.id, behavior: 'allow', always: true });
    assert.deepEqual(await decision(done), { behavior: 'allow', updatedPermissions: RULE });
  });

  it('denies a permission with the owner\'s reason', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(PERMIT);
    const item = (await held()).groups[0].items[0];
    await board.post('/relay/answer', { id: item.id, behavior: 'deny', message: 'Run only the board tests' });
    assert.deepEqual(await decision(done), { behavior: 'deny', message: 'The owner declined from the Project Manager: Run only the board tests' });
  });

  it('holds a plan for approval and approves it, plainly or into a mode the prompt offered', async () => {
    await board.post('/relay/away', { on: true });
    let { done } = board.hook(PLAN);
    let item = (await held()).groups[0].items[0];
    assertMatches(item, { kind: 'plan', tool: 'ExitPlanMode', input: { plan: '# Plan\n- Build it' }, suggestions: MODES });
    await board.post('/relay/answer', { id: item.id, behavior: 'allow' });
    assert.deepEqual(await decision(done), { behavior: 'allow' });

    ({ done } = board.hook(PLAN));
    item = (await held()).groups[0].items[0];
    await board.post('/relay/answer', { id: item.id, behavior: 'allow', suggestion: 0 });
    assert.deepEqual(await decision(done), { behavior: 'allow', updatedPermissions: [MODES[0]] });
  });

  it('rejects a plan with the owner\'s reason, so the session keeps planning', async () => {
    await board.post('/relay/away', { on: true });
    const { done } = board.hook(PLAN);
    const item = (await held()).groups[0].items[0];
    await board.post('/relay/answer', { id: item.id, behavior: 'deny', message: 'Do the tests first' });
    assert.deepEqual(await decision(done), { behavior: 'deny',
      message: 'The owner rejected this plan from the Project Manager. Keep planning: Do the tests first' });
  });

  it('only takes actions from its own pages', async () => {
    const r = await board.post('/relay/away', { on: true }, { origin: 'http://evil.example' });
    assert.equal(r.status, 403);
    assert.equal((await board.get('/questions')).body.away.on, false);
  });
});
