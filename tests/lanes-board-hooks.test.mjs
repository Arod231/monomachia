// The hooks the Project Manager installs in user settings, and whether the
// installed ones are current (tools/lanes-board/hooks.mjs, install-hooks.mjs).
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { HOOKS, hookCommand, hookFiles, hooksStatus, hooksStatusOf, withHooks } from '../tools/lanes-board/hooks.mjs';

const HOME = 'C:/Users/owner/.claude';
const relay = hookCommand(HOME, 'lanes-relay');
const stop = hookCommand(HOME, 'lanes-stop');
const DAY = 86400;

// User settings as they were before the install: the relay hook's 25-minute timeouts.
const before = (home = HOME) => ({
  enabledPlugins: { x: true },
  hooks: {
    PreToolUse: [{ matcher: '*', hooks: [{ type: 'command', command: hookCommand(home, 'lanes-stop'), timeout: 10 }] }],
    Stop: [{ hooks: [{ type: 'command', command: hookCommand(home, 'lanes-stop'), timeout: 10 }, { type: 'command', command: hookCommand(home, 'lanes-relay'), timeout: 1500 }] }],
    PermissionRequest: [{ matcher: '*', hooks: [{ type: 'command', command: hookCommand(home, 'lanes-relay'), timeout: 1500 }] }],
  },
});
const tracked = { 'relay-hook.mjs': 'relay v2\n', 'stop-hook.mjs': 'stop v2\n', 'inbox.mjs': 'inbox v2\n' };
// The installed files, by path, as hookFiles names them.
const installedAs = ({ relayHook = 'relay v2\n', stopHook = 'stop v2\n', inbox = 'inbox v2\n' } = {}) => ({
  [`${HOME}/hooks/lanes-relay/hook.mjs`]: relayHook, [`${HOME}/hooks/lanes-relay/inbox.mjs`]: inbox,
  [`${HOME}/hooks/lanes-stop/hook.mjs`]: stopHook, [`${HOME}/hooks/lanes-stop/inbox.mjs`]: inbox,
});

describe('hookCommand and hookFiles', () => {
  it('runs the installed copy with node, by a forward-slash path', () => {
    assert.equal(hookCommand('C:\\Users\\owner\\.claude', 'lanes-relay'), 'node "C:/Users/owner/.claude/hooks/lanes-relay/hook.mjs"');
  });
  it('installs each hook as hook.mjs with the module it shares beside it', () => {
    assert.deepEqual(HOOKS.map((h) => [h.name, h.file]), [['lanes-relay', 'relay-hook.mjs'], ['lanes-stop', 'stop-hook.mjs']]);
    assert.deepEqual(hookFiles('C:\\Users\\owner\\.claude', HOOKS[0]), [
      { from: 'relay-hook.mjs', to: 'C:/Users/owner/.claude/hooks/lanes-relay/hook.mjs' },
      { from: 'inbox.mjs', to: 'C:/Users/owner/.claude/hooks/lanes-relay/inbox.mjs' },
    ]);
  });
});

describe('withHooks', () => {
  it('raises the relay hook\'s timeouts to 24 hours, leaving everything else as it was', () => {
    const s = withHooks(before(), HOME);
    assert.deepEqual(s.enabledPlugins, { x: true });
    assert.deepEqual(s.hooks.PermissionRequest, [{ matcher: '*', hooks: [{ type: 'command', command: relay, timeout: DAY }] }]);
    assert.deepEqual(s.hooks.Stop, [{ hooks: [{ type: 'command', command: stop, timeout: 10 }, { type: 'command', command: relay, timeout: DAY }] }]);
    assert.deepEqual(s.hooks.PreToolUse, before().hooks.PreToolUse);
  });
  it('adds what is missing, keeps other hooks, and changes nothing the second time', () => {
    const other = { type: 'command', command: 'node other.mjs', timeout: 5 };
    const s = withHooks({ hooks: { Stop: [{ hooks: [other] }] } }, HOME);
    assert.deepEqual(s.hooks.Stop[0].hooks[0], other);
    assert.deepEqual(s.hooks.Stop.flatMap((g) => g.hooks).map((h) => h.command), ['node other.mjs', relay, stop]);
    assert.deepEqual(s.hooks.PreToolUse, [{ matcher: '*', hooks: [{ type: 'command', command: stop, timeout: 10 }] }]);
    assert.deepEqual(s.hooks.PermissionRequest, [{ matcher: '*', hooks: [{ type: 'command', command: relay, timeout: DAY }] }]);
    assert.deepEqual(withHooks(s, HOME), s);
    assert.deepEqual(withHooks({}, HOME), withHooks(withHooks({}, HOME), HOME));
  });
});

describe('hooksStatus', () => {
  const status = (installed, settings) => hooksStatus({ tracked, installed, settings, claudeDir: HOME });

  it('is current when the copies match (whatever their line endings) and every registration is in place', () => {
    assert.deepEqual(status(installedAs({ relayHook: 'relay v2\r\n' }), withHooks(before(), HOME)), { current: true, problems: [] });
  });
  it('says which installed copy is older, or missing, counting the module beside it', () => {
    const s = status(installedAs({ relayHook: 'relay v1\n', stopHook: null }), withHooks(before(), HOME));
    assert.equal(s.current, false);
    assert.deepEqual(s.problems, [
      'The installed relay hook differs from this version\'s.',
      'The stop hook isn\'t installed.',
    ]);
    assert.deepEqual(status(installedAs({ inbox: 'inbox v1\n' }), withHooks(before(), HOME)).problems, [
      'The installed relay hook differs from this version\'s.',
      'The installed stop hook differs from this version\'s.',
    ]);
  });
  it('says when a registration is missing or its timeout is too short for a 24-hour hold', () => {
    const s = status(installedAs(), before());
    assert.deepEqual(s.problems, [
      'The relay hook\'s PermissionRequest timeout is 1500 s, not 24 hours.',
      'The relay hook\'s Stop timeout is 1500 s, not 24 hours.',
    ]);
    const bare = status(installedAs(), {});
    assert.equal(bare.problems.length, 4);
    assert.match(bare.problems[0], /isn't registered for PermissionRequest/);
  });
  it('reads the files and settings it compares through the caller\'s reader', () => {
    const files = { ...installedAs(), 'board/relay-hook.mjs': 'relay v2\n', 'board/stop-hook.mjs': 'stop v2\n', 'board/inbox.mjs': 'inbox v2\n',
      [`${HOME}/settings.json`]: JSON.stringify(withHooks(before(), HOME)) };
    assert.deepEqual(hooksStatusOf({ claudeDir: HOME, boardDir: 'board', read: (p) => files[p] ?? null }), { current: true, problems: [] });
  });
});

describe('install-hooks.mjs', () => {
  const SCRIPT = fileURLToPath(new URL('../tools/lanes-board/install-hooks.mjs', import.meta.url));
  let dir;
  beforeEach(() => { dir = mkdtempSync(path.join(os.tmpdir(), 'pm-hooks-')); });
  afterEach(() => rmSync(dir, { recursive: true, force: true }));
  const run = (...args) => spawnSync(process.execPath, [SCRIPT, ...args], { env: { ...process.env, LANES_CLAUDE_DIR: dir }, encoding: 'utf8' });

  it('says what it would change, and changes nothing, with --dry-run', () => {
    writeFileSync(path.join(dir, 'settings.json'), JSON.stringify(before(dir)));
    const r = run('--dry-run');
    assert.equal(r.status, 0);
    assert.match(r.stdout, /would copy/i);
    assert.deepEqual(JSON.parse(readFileSync(path.join(dir, 'settings.json'), 'utf8')), before(dir));
    assert.deepEqual(readdirSync(dir), ['settings.json']);
  });
  it('copies the hooks and the module beside them, registers them, backs the old settings up, and is then current', () => {
    writeFileSync(path.join(dir, 'settings.json'), JSON.stringify(before(dir)));
    const r = run();
    assert.equal(r.status, 0, r.stderr);
    const board = fileURLToPath(new URL('../tools/lanes-board/', import.meta.url));
    for (const h of HOOKS) {
      assert.equal(readFileSync(path.join(dir, 'hooks', h.name, 'hook.mjs'), 'utf8'), readFileSync(path.join(board, h.file), 'utf8'));
      assert.equal(readFileSync(path.join(dir, 'hooks', h.name, 'inbox.mjs'), 'utf8'), readFileSync(path.join(board, 'inbox.mjs'), 'utf8'));
    }
    const settings = JSON.parse(readFileSync(path.join(dir, 'settings.json'), 'utf8'));
    assert.equal(settings.hooks.PermissionRequest[0].hooks.length, 1);
    assert.equal(settings.hooks.PermissionRequest[0].hooks[0].timeout, DAY);
    assert.ok(readdirSync(dir).some((n) => n.startsWith('settings.json.bak-')));
    assert.match(run('--check').stdout, /current/i);
  });
  it('leaves the settings and no backup behind when settings.json can\'t be written', { skip: process.platform !== 'win32' && 'a read-only file blocks the rename on Windows only' }, () => {
    const file = path.join(dir, 'settings.json');
    writeFileSync(file, JSON.stringify(before(dir)));
    chmodSync(file, 0o444);
    try {
      const r = run();
      assert.equal(r.status, 1);
      assert.match(r.stderr, /Couldn't write .*settings\.json.*unchanged/);
      assert.deepEqual(readdirSync(dir).sort(), ['hooks', 'settings.json']);
      assert.deepEqual(JSON.parse(readFileSync(file, 'utf8')), before(dir));
    } finally { chmodSync(file, 0o666); }
  });
  it('starts settings from nothing when there are none', () => {
    mkdirSync(dir, { recursive: true });
    assert.equal(run().status, 0);
    assert.equal(JSON.parse(readFileSync(path.join(dir, 'settings.json'), 'utf8')).hooks.Stop[0].hooks.length, 2);
  });
});
