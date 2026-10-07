// Tests for tools/lanes-board/restart.mjs: restarting the Project Manager from
// the phone's Launch tab, which only a board under its restart loop may do.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { parentCommandLine, restartApi, restartLoopOf } from '../tools/lanes-board/restart.mjs';
import { restartStatus } from '../tools/lanes-board/ui.mjs';

describe('restartLoopOf', () => {
  it('finds the loop that starts the board again in its parent\'s command line', () => {
    assert.equal(restartLoopOf('C:\\WINDOWS\\system32\\cmd.exe /c ""C:\\Users\\arodr\\.claude\\all-lanes-server\\follow.cmd" "'), 'follow.cmd');
    assert.equal(restartLoopOf('cmd.exe /c C:\\Users\\arodr\\.claude\\all-lanes-server\\run.cmd'), 'run.cmd');
    assert.equal(restartLoopOf('cmd /c "C:/x/FOLLOW.CMD"'), 'follow.cmd');
  });

  it('finds none for a board started by hand, or an unknown parent', () => {
    assert.equal(restartLoopOf('"C:\\Program Files\\nodejs\\node.exe" C:\\x\\npm-cli.js run board'), null);
    assert.equal(restartLoopOf('C:\\WINDOWS\\system32\\cmd.exe /c npm run board'), null);
    assert.equal(restartLoopOf('cmd /c myfollow.cmd.bak'), null);
    assert.equal(restartLoopOf(null), null);
    assert.equal(restartLoopOf(''), null);
  });
});

describe('parentCommandLine', () => {
  it('asks PowerShell for the parent on Windows', async () => {
    const calls = [];
    const run = async (cmd, args) => { calls.push([cmd, args]); return { stdout: 'cmd.exe /c follow.cmd\r\n' }; };
    assert.equal(await parentCommandLine(run, 29388, 'win32'), 'cmd.exe /c follow.cmd');
    assert.equal(calls[0][0], 'powershell.exe');
    assert.match(calls[0][1].at(-1), /ProcessId=29388/);
  });

  it('asks ps elsewhere, and answers null when the parent can\'t be read', async () => {
    assert.equal(await parentCommandLine(async (cmd, args) => ({ stdout: `${cmd} ${args.join(' ')}` }), 7, 'linux'), 'ps -o args= -p 7');
    assert.equal(await parentCommandLine(async () => { throw new Error('gone'); }, 7, 'win32'), null);
    assert.equal(await parentCommandLine(async () => ({ stdout: '  ' }), 7, 'win32'), null);
  });
});

describe('restartApi', () => {
  const quiet = () => {};

  it('says when the board started and whether it can restart', () => {
    assert.deepEqual(restartApi({ loop: () => 'follow.cmd', startedAt: 5, log: quiet }).info(), { startedAt: 5, restartable: true, restarting: false });
    assert.deepEqual(restartApi({ loop: () => null, startedAt: 5, log: quiet }).info(), { startedAt: 5, restartable: false, restarting: false });
  });

  it('answers, then exits so the loop starts the board again', async () => {
    const exits = [];
    const api = restartApi({ loop: () => 'follow.cmd', exit: (code) => exits.push(code), delayMs: 5, startedAt: 1, log: quiet });
    assert.deepEqual(api.post('/restart'), { restarting: true, loop: 'follow.cmd' });
    assert.deepEqual(exits, [], 'the answer goes out before the exit');
    assert.deepEqual(api.info(), { startedAt: 1, restartable: false, restarting: true });
    api.post('/restart');
    await new Promise((r) => setTimeout(r, 30));
    assert.deepEqual(exits, [0], 'a second press while leaving exits once');
  });

  it('refuses a board started by hand, which would only go away', () => {
    const exits = [];
    const api = restartApi({ loop: () => null, exit: (code) => exits.push(code), delayMs: 0, log: quiet });
    assert.throws(() => api.post('/restart'), /restart loop/);
    assert.deepEqual(exits, []);
  });

  it('leaves other routes alone', () => {
    assert.equal(restartApi({ loop: () => 'run.cmd', log: quiet }).post('/launch'), undefined);
  });
});

describe('restartStatus', () => {
  it('lets the button be pressed only on a board under its loop', () => {
    const on = restartStatus({ startedAt: 1, restartable: true, restarting: false }, false);
    assert.equal(on.enabled, true);
    assert.match(on.text, /latest master/);
    const off = restartStatus({ startedAt: 1, restartable: false, restarting: false }, false);
    assert.equal(off.enabled, false);
    assert.match(off.text, /restart it on the PC/);
  });

  it('says it is restarting while this page waits, or the board is leaving', () => {
    for (const st of [restartStatus({ startedAt: 1, restartable: true }, true), restartStatus({ startedAt: 1, restartable: false, restarting: true }, false)]) {
      assert.equal(st.enabled, false);
      assert.match(st.text, /^Restarting/);
    }
  });

  it('waits for a board that has no line yet', () => {
    assert.deepEqual(restartStatus(undefined, false), { enabled: false, text: 'The Project Manager is still starting.' });
  });
});
