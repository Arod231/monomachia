import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeRoutes } from '../routes.mjs';

const ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
async function serve(extra = {}) {
  let server;
  const repo = await mkdtemp(path.join(os.tmpdir(), 'repo-'));
  await mkdir(path.join(repo, 'docs/plans'), { recursive: true });
  await mkdir(path.join(repo, 'docs/specs'), { recursive: true });
  await writeFile(path.join(repo, 'docs/plans/godot-rebuild.md'), '- [ ] **7. Swings.**\n  - [ ] **7.1 Helpers.** x\n    - Blocked by: none · Stories: 1\n');
  await writeFile(path.join(repo, 'docs/specs/godot-rebuild.md'), '## User Stories\n\n1. [ ] As a player, I want it.\n');
  const data = { stages: [{ n: 7, name: 'Swings', full: 'Swings', tasks: ['7.1'], done: [], working: ['7.1'], next: [] }],
    lanes: [], blockers: {}, doneIds: [] };
  const handle = makeRoutes({
    here: path.dirname(path.dirname(fileURLToPath(import.meta.url))), repo, port: () => server.address().port,
    getData: async () => data,
    listSessions: async () => [{ id: ID, title: 'Stage 7', cwd: 'C:\\x', folder: 'x', branch: 'godot/stage-7-a', lastActive: 5, live: true }],
    feedbackDir: await mkdtemp(path.join(os.tmpdir(), 'fb-')),
    hookInstalled: async () => false,
    ...extra,
  });
  server = createServer(async (req, res) => { if (!(await handle(req, res))) { res.writeHead(418); res.end(); } });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { base, close: () => server.close() };
}

test('GET /api/sessions, /api/session/:id and /api/stage/:n', async (t) => {
  const s = await serve(); t.after(s.close);
  const list = await (await fetch(`${s.base}/api/sessions`)).json();
  assert.equal(list[0].stage, 7);
  assert.equal((await fetch(`${s.base}/api/session/${ID}`)).status, 200);
  assert.equal((await fetch(`${s.base}/api/session/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb`)).status, 404);
  const stage = await (await fetch(`${s.base}/api/stage/7`)).json();
  assert.equal(stage.tasks[0].state, 'working');
  assert.equal(stage.tasks[0].stories[0].n, 1);
  assert.equal((await fetch(`${s.base}/api/stage/99`)).status, 404);
});

test('session page and the renderer are served; other paths fall through', async (t) => {
  const s = await serve(); t.after(s.close);
  assert.match(await (await fetch(`${s.base}/session/${ID}`)).text(), /<html/);
  assert.match((await fetch(`${s.base}/markdown.mjs`)).headers.get('content-type'), /javascript/);
  assert.equal((await fetch(`${s.base}/data`)).status, 418);
});
