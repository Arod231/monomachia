// The round trip's test seam: the real Project Manager server on a spare port,
// with throwaway state, relay, stop, projects and app-session folders and a
// fixture repository, and the real hooks run against the same relay folder
// with fixture events. Nothing here reads or writes the PC's own ~/.claude.
// The tests drive the server's API the way the pages do.

import { execFileSync, spawn } from 'node:child_process';
import { appendFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BOARD = fileURLToPath(new URL('../tools/lanes-board/', import.meta.url));
export const SESSION = '11111111-2222-4333-8444-555555555555';

const freePort = () => new Promise((resolve, reject) => {
  const s = createServer();
  s.on('error', reject);
  s.listen(0, '127.0.0.1', () => { const { port } = s.address(); s.close(() => resolve(port)); });
});

// Polls fn until it returns something truthy, or fails after `ms`.
export async function waitFor(fn, ms = 8000, what = 'the condition') {
  const until = Date.now() + ms;
  while (Date.now() < until) {
    const v = await fn();
    if (v) return v;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error(`Timed out waiting for ${what}`);
}

// Starts a board (with extra environment variables, if given); `stop()` ends
// it and removes every throwaway folder.
export async function startBoard({ env: extraEnv = {} } = {}) {
  const root = mkdtempSync(path.join(os.tmpdir(), 'pm-roundtrip-'));
  const dirs = Object.fromEntries(['state', 'relay', 'projects', 'appdata', 'repo', 'claude'].map((k) => [k, path.join(root, k)]));
  for (const d of Object.values(dirs)) mkdirSync(d, { recursive: true });
  const git = (...args) => execFileSync('git', args, { cwd: dirs.repo, windowsHide: true, stdio: 'ignore' });
  git('init', '-q', '-b', 'main');
  git('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-q', '--allow-empty', '-m', 'Start');

  // A session's transcript, so the board knows its title and folder.
  const folder = path.join(dirs.projects, dirs.repo.replace(/[^A-Za-z0-9]/g, '-'));
  mkdirSync(folder, { recursive: true });
  const transcriptOf = (id) => path.join(folder, `${id}.jsonl`);
  const addSession = (id, title) => {
    const line = (o) => JSON.stringify({ sessionId: id, timestamp: new Date().toISOString(), ...o });
    writeFileSync(transcriptOf(id), [
      line({ type: 'custom-title', customTitle: title }),
      line({ type: 'user', cwd: dirs.repo, message: { content: 'Build the fixture' } }),
    ].join('\n') + '\n');
    return transcriptOf(id);
  };
  addSession(SESSION, 'Fixture session');
  // An assistant reply in a session's transcript, with its line's uuid.
  const say = (id, text, uuid) => appendFileSync(transcriptOf(id), `${JSON.stringify({ sessionId: id, uuid, timestamp: new Date().toISOString(),
    type: 'assistant', message: { role: 'assistant', content: [{ type: 'text', text }] } })}
`);
  // The desktop app's record of a session, as it keeps one per Code session.
  const appRecord = (id, title, extra = {}) => {
    const dir = path.join(dirs.appdata, 'Claude', 'claude-code-sessions', 'fixture');
    mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `local_${id}.json`);
    writeFileSync(file, JSON.stringify({ sessionId: `local_${id}`, cliSessionId: id, title, cwd: dirs.repo, createdAt: Date.now(), lastActivityAt: Date.now(), ...extra }));
    return file;
  };

  const port = await freePort();
  const env = {
    ...process.env, PORT: String(port), LANES_LOCAL_ONLY: '1', LANES_DRY_RUN: '1', REPO: dirs.repo,
    LANES_STATE: dirs.state, LANES_RELAY: dirs.relay, LANES_STOP_FILE: path.join(root, 'stop.json'),
    LANES_PROJECTS: dirs.projects, APPDATA: dirs.appdata, LANES_CLAUDE_DIR: dirs.claude, ...extraEnv,
  };
  const server = spawn(process.execPath, [path.join(BOARD, 'server.mjs')], { env, windowsHide: true });
  let log = '';
  server.stdout.on('data', (c) => { log += c; });
  server.stderr.on('data', (c) => { log += c; });
  await waitFor(() => log.includes('Project Manager on'), 20000, `the board to start:\n${log}`);

  const base = `http://localhost:${port}`;
  const board = {
    port, root, ...dirs, log: () => log, addSession, appRecord, transcriptOf, say,
    async get(p) {
      const r = await fetch(base + p, { headers: { 'accept-encoding': 'identity' } });
      return { status: r.status, body: await r.json().catch(() => null) };
    },
    // As the board's own page posts: JSON, with its origin.
    async post(p, body, headers = {}) {
      const r = await fetch(base + p, { method: 'POST', body: JSON.stringify(body),
        headers: { 'content-type': 'application/json', origin: base, ...headers } });
      return { status: r.status, body: await r.json().catch(() => null) };
    },
    // Runs the relay hook with a fixture event, as Claude Code would.
    hook(event, { session = SESSION } = {}) {
      return runHook('relay-hook.mjs', event, session, {});
    },
    // Runs the stop hook (PreToolUse and Stop) the same way.
    stopHook(event, { session = SESSION } = {}) {
      return runHook('stop-hook.mjs', event, session, {});
    },
    async stop() {
      server.kill();
      await new Promise((r) => { if (server.exitCode !== null) r(); else server.on('exit', r); });
      rmSync(root, { recursive: true, force: true, maxRetries: 5 });
    },
  };
  // A hook run as Claude Code runs it: the event on stdin, its JSON answer (or null) when it exits.
  function runHook(file, event, session, env) {
    const child = spawn(process.execPath, [path.join(BOARD, file)], {
      env: { ...process.env, LANES_RELAY: dirs.relay, LANES_STOP_FILE: path.join(root, 'stop.json'), ...env }, windowsHide: true,
    });
    let out = '';
    child.stdout.on('data', (c) => { out += c; });
    const done = new Promise((resolve, reject) => {
      child.on('error', reject);
      child.on('close', () => resolve(out ? JSON.parse(out) : null));
    });
    child.stdin.end(JSON.stringify({ session_id: session, cwd: dirs.repo, transcript_path: transcriptOf(session), ...event }));
    return { done, child };
  }
  return board;
}
