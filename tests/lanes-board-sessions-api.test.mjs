// The Project Manager's Sessions and relay routes (tools/lanes-board/sessions-api.mjs),
// run against throwaway relay and projects folders.
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { sessionsApi } from '../tools/lanes-board/sessions-api.mjs';

const ID = '11111111-2222-4333-8444-555555555555';
const line = (o) => JSON.stringify({ sessionId: ID, timestamp: '2026-10-04T06:00:00.000Z', ...o });
const pool = (items, n, fn) => Promise.all(items.map((x, i) => fn(x, i)));

describe('sessions api', () => {
  let root, relay, projects, api;
  beforeEach(() => {
    root = mkdtempSync(path.join(os.tmpdir(), 'lanes-sessions-'));
    relay = path.join(root, 'relay');
    projects = path.join(root, 'projects');
    mkdirSync(path.join(projects, 'C--repo'), { recursive: true });
    writeFileSync(path.join(projects, 'C--repo', `${ID}.jsonl`), [
      line({ type: 'custom-title', customTitle: 'Board work' }),
      line({ type: 'user', cwd: 'C:/repo', message: { content: 'Build it' } }),
      line({ type: 'assistant', message: { content: [{ type: 'text', text: 'Done.' }] } }),
    ].join('\n'));
    api = sessionsApi({ relay, projects, activeMs: 60_000, contextOf: async () => null, appSessions: async () => [], pool });
  });
  afterEach(() => rmSync(root, { recursive: true, force: true }));

  const get = (p) => api.get(new URL(p, 'http://board'));

  it('lists recent sessions and shows one', async () => {
    const { sessions } = await get('/sessions');
    assert.equal(sessions.length, 1);
    assertMatches(sessions[0], { id: ID, title: 'Board work', cwd: 'C:/repo', queued: 0, pending: [], lastText: 'Done.' });
    const d = await get(`/session?id=${ID}`);
    assertMatches(d, { id: ID, title: 'Board work', pending: [], queued: [] });
    assert.deepEqual(d.entries.map((e) => e.kind), ['user', 'assistant']);
  });

  it('refuses a bad or unknown session id', async () => {
    await assert.rejects(get('/session?id=../x'), /Bad session id/);
    await assert.rejects(get('/session?id=99999999-2222-4333-8444-555555555555'), /No recent session/);
  });

  it('leaves other routes to the server', () => {
    assert.equal(get('/data'), undefined);
    assert.equal(api.post('/launch', {}), undefined);
  });

  it('queues a reply for a session at work, before its next step, and takes it back', async () => {
    await assert.rejects(api.post('/relay/reply', { session: ID, text: ' ' }), /Type a reply/);
    assert.deepEqual(await api.post('/relay/reply', { session: ID, text: ' Go on ' }), { delivered: false, when: 'next-step' });
    const inbox = path.join(relay, 'inbox', ID);
    const [name] = readdirSync(inbox);
    assertMatches(JSON.parse(readFileSync(path.join(inbox, name), 'utf8')), { text: 'The owner replied from the Project Manager:\n\nGo on' });
    assert.equal((await get('/sessions')).sessions[0].queued, 1);
    await api.post('/relay/unqueue', { session: ID });
    assert.equal(existsSync(inbox), false);
  });

  it('answers a waiting prompt, and refuses one that has gone', async () => {
    mkdirSync(path.join(relay, 'pending'), { recursive: true });
    writeFileSync(path.join(relay, 'pending', 'abcd-efgh.json'), JSON.stringify({ id: 'abcd-efgh', session: ID, kind: 'permission', time: 1 }));
    assert.equal((await get('/sessions')).sessions[0].pending.length, 1);
    assert.deepEqual(await api.post('/relay/answer', { id: 'abcd-efgh', behavior: 'allow' }), { ok: true });
    assert.deepEqual(JSON.parse(readFileSync(path.join(relay, 'answers', 'abcd-efgh.json'), 'utf8')), { behavior: 'allow' });
    await assert.rejects(api.post('/relay/answer', { id: 'gone-gone', behavior: 'allow' }), /already answered, handed back or timed out/);
    await assert.rejects(api.post('/relay/answer', { id: 'abcd-efgh', behavior: 'deny' }), /already answered/);
  });

  it('says which sessions are asking in the app now, for the bell', async () => {
    assert.deepEqual(await api.askingNow(), []);
    writeFileSync(path.join(projects, 'C--repo', `${ID}.jsonl`), [
      line({ type: 'user', cwd: 'C:/repo', message: { content: 'Build it' } }),
      line({ type: 'assistant', message: { content: [{ type: 'tool_use', id: 'toolu_q', name: 'AskUserQuestion', input: { questions: [{ question: 'Which?' }] } }] } }),
    ].join('\n'));
    assert.deepEqual(await api.askingNow(), [ID]);
  });

  describe("a session's branch", () => {
    const PR = { number: 65, title: 'PM task 19', url: 'https://github.com/o/r/pull/65', base: 'tools/pm', draft: true };
    const withBranch = (gitBranch) => {
      writeFileSync(path.join(projects, 'C--repo', `${ID}.jsonl`), [
        line({ type: 'user', cwd: 'C:/repo', gitBranch, message: { content: 'Build it' } }),
        line({ type: 'assistant', gitBranch, message: { content: [{ type: 'text', text: 'Done.' }] } }),
      ].join('\n'));
      api = sessionsApi({ relay, projects, activeMs: 60_000, contextOf: async () => null, appSessions: async () => [], pool,
        branchOf: (dir) => (dir === 'C:/repo' ? 'lane/pm-19' : null), prOf: (b) => (b === 'lane/pm-19' ? PR : b === 'lane/other' ? { ...PR, number: 7 } : null) });
    };

    it("is its folder's when its transcript says HEAD, as for a session started outside git and moved into a worktree", async () => {
      withBranch('HEAD');
      assertMatches((await get('/sessions')).sessions[0], { branch: 'lane/pm-19', pr: { number: 65 } });
      assertMatches(await get(`/session?id=${ID}`), { branch: 'lane/pm-19', pr: { number: 65 } });
      assert.deepEqual(await api.branches(), [{ id: ID, branch: 'lane/pm-19' }]);
      assert.equal(await api.branchOfSession(ID), 'lane/pm-19');
    });

    it("is its transcript's when that names one", async () => {
      withBranch('lane/other');
      assertMatches((await get('/sessions')).sessions[0], { branch: 'lane/other', pr: { number: 7 } });
      assert.deepEqual(await api.branches(), [{ id: ID, branch: 'lane/other' }]);
    });
  });
});
