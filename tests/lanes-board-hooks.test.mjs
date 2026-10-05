// The hooks the Project Manager installs in user settings, and whether the
// installed ones are current (tools/lanes-board/hooks.mjs, install-hooks.mjs).
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { HOOKS, hookCommand, hooksStatus, withHooks } from '../tools/lanes-board/hooks.mjs';

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
const tracked = { 'lanes-relay': 'relay v2\n', 'lanes-stop': 'stop v2\n' };

describe('hookCommand', () => {
  it('runs the installed copy with node, by a forward-slash path', () => {
    assert.equal(hookCommand('C:\\Users\\owner\\.claude', 'lanes-relay'), 'node "C:/Users/owner/.claude/hooks/lanes-relay/hook.mjs"');
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
  it('lists every hook it installs, with where it comes from', () => {
    assert.deepEqual(HOOKS.map((h) => [h.name, h.file]), [['lanes-relay', 'relay-hook.mjs'], ['lanes-stop', 'stop-hook.mjs']]);
  });
});

describe('hooksStatus', () => {
  const status = (installed, settings) => hooksStatus({ tracked, installed, settings, home: HOME });

  it('is current when the copies match (whatever their line endings) and every registration is in place', () => {
    assert.deepEqual(status({ 'lanes-relay': 'relay v2\r\n', 'lanes-stop': 'stop v2\n' }, withHooks(before(), HOME)), { current: true, problems: [] });
  });
  it('says which installed copy is older, or missing', () => {
    const s = status({ 'lanes-relay': 'relay v1\n', 'lanes-stop': null }, withHooks(before(), HOME));
    assert.equal(s.current, false);
    assert.deepEqual(s.problems, [
      'The installed relay hook differs from this version\'s.',
      'The stop hook isn\'t installed.',
    ]);
  });
  it('says when a registration is missing or its timeout is too short for a 24-hour hold', () => {
    const s = status(tracked, before());
    assert.deepEqual(s.problems, [
      'The relay hook\'s PermissionRequest timeout is 1500 s, not 24 hours.',
      'The relay hook\'s Stop timeout is 1500 s, not 24 hours.',
    ]);
    const bare = status(tracked, {});
    assert.equal(bare.problems.length, 4);
    assert.match(bare.problems[0], /isn't registered for PermissionRequest/);
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
  it('copies the hooks, registers them, backs the old settings up, and is then current', () => {
    writeFileSync(path.join(dir, 'settings.json'), JSON.stringify(before(dir)));
    const r = run();
    assert.equal(r.status, 0, r.stderr);
    const board = fileURLToPath(new URL('../tools/lanes-board/', import.meta.url));
    for (const h of HOOKS) {
      assert.equal(readFileSync(path.join(dir, 'hooks', h.name, 'hook.mjs'), 'utf8'), readFileSync(path.join(board, h.file), 'utf8'));
    }
    const settings = JSON.parse(readFileSync(path.join(dir, 'settings.json'), 'utf8'));
    assert.equal(settings.hooks.PermissionRequest[0].hooks.length, 1);
    assert.equal(settings.hooks.PermissionRequest[0].hooks[0].timeout, DAY);
    assert.ok(readdirSync(dir).some((n) => n.startsWith('settings.json.bak-')));
    assert.match(run('--check').stdout, /current/i);
  });
  it('starts settings from nothing when there are none', () => {
    mkdirSync(dir, { recursive: true });
    assert.equal(run().status, 0);
    assert.equal(JSON.parse(readFileSync(path.join(dir, 'settings.json'), 'utf8')).hooks.Stop[0].hooks.length, 2);
  });
});
