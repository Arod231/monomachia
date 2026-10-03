import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, utimes } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { readSession, listSessions, LIVE_MS } from '../sessions.mjs';

const ID1 = '11111111-1111-1111-1111-111111111111';
const ID2 = '22222222-2222-2222-2222-222222222222';
const line = (o) => JSON.stringify(o) + '\n';
const user = (text) => line({ type: 'user', message: { role: 'user', content: text }, cwd: 'C:\\r', gitBranch: 'b0' });

async function tmp() { return mkdtemp(path.join(os.tmpdir(), 'sessions-')); }

test('title, cwd and branch come from the last records; a half-written last line is skipped', async () => {
  const dir = await tmp();
  const f = path.join(dir, `${ID1}.jsonl`);
  await writeFile(f, user('hello') +
    line({ type: 'custom-title', customTitle: 'Old title' }) +
    line({ type: 'assistant', cwd: 'C:\\w\\lane', gitBranch: 'godot/stage-7-swings' }) +
    line({ type: 'custom-title', customTitle: 'Stage 7 swing foundations' }) +
    '{"type":"custom-title","customTi');
  const s = await readSession(f);
  assert.equal(s.id, ID1);
  assert.equal(s.title, 'Stage 7 swing foundations');
  assert.equal(s.cwd, 'C:\\w\\lane');
  assert.equal(s.folder, 'lane');
  assert.equal(s.branch, 'godot/stage-7-swings');
});

test('without a custom title, the first real prompt cut to 80 characters; then the short id', async () => {
  const dir = await tmp();
  const a = path.join(dir, `${ID1}.jsonl`);
  await writeFile(a, line({ type: 'user', message: { content: '<command-name>/x</command-name>' } }) + user('y'.repeat(100)));
  assert.equal((await readSession(a)).title, 'y'.repeat(80));
  const b = path.join(dir, `${ID2}.jsonl`);
  await writeFile(b, line({ type: 'assistant', cwd: 'C:\\r' }));
  assert.equal((await readSession(b)).title, '22222222');
});

test('array content parts count as a prompt', async () => {
  const dir = await tmp();
  const f = path.join(dir, `${ID1}.jsonl`);
  await writeFile(f, line({ type: 'user', message: { content: [{ type: 'text', text: 'Begin stage 6' }] } }));
  assert.equal((await readSession(f)).title, 'Begin stage 6');
});

test('steps back past a long tail to find the title', async () => {
  const dir = await tmp();
  const f = path.join(dir, `${ID1}.jsonl`);
  const filler = (n) => line({ type: 'assistant', message: { content: 'z'.repeat(1000) } }).repeat(n);
  // The title sits past the 64 KB head and 600 KB before the end: only stepping back finds it.
  await writeFile(f, user('first') + filler(100) + line({ type: 'custom-title', customTitle: 'Deep title' }) + filler(600));
  assert.equal((await readSession(f)).title, 'Deep title');
});

test('live within 3 minutes; listSessions keeps only the project prefix, newest first', async () => {
  const root = await tmp();
  const mine = path.join(root, 'C--Mono'); const worktree = path.join(root, 'C--Mono--claude-worktrees-x');
  const other = path.join(root, 'C--Other');
  for (const d of [mine, worktree, other]) await mkdir(d);
  await writeFile(path.join(mine, `${ID1}.jsonl`), user('old'));
  await writeFile(path.join(worktree, `${ID2}.jsonl`), user('new'));
  await writeFile(path.join(other, '33333333-3333-3333-3333-333333333333.jsonl'), user('other'));
  await mkdir(path.join(mine, ID1)); // the per-session folder Claude Code makes is ignored
  const now = Date.now();
  await utimes(path.join(mine, `${ID1}.jsonl`), new Date(now - 3600e3), new Date(now - 3600e3));
  await utimes(path.join(worktree, `${ID2}.jsonl`), new Date(now - 1000), new Date(now - 1000));
  const list = await listSessions({ projectsDir: root, prefix: 'C--Mono', now });
  assert.deepEqual(list.map((s) => s.id), [ID2, ID1]);
  assert.equal(list[0].live, true);
  assert.equal(list[1].live, false);
  assert.ok(LIVE_MS === 180000);
});

test('a missing projects folder gives an empty list', async () => {
  assert.deepEqual(await listSessions({ projectsDir: path.join(os.tmpdir(), 'nope-' + Date.now()), prefix: 'x' }), []);
});
