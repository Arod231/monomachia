// Tests for starting a launched session with nobody at the PC
// (tools/lanes-board/launcher.mjs): the start queue that opens each launch's
// link and presses Send in the Claude app, the wait for a locked PC, retries,
// linking a launch to the session it started, and what the pages show. The
// queue runs here with fakes for the link, the press and the lock check; the
// real press (press-send.ps1) runs on Windows against a stand-in window.

import { execFile, spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import {
  LOCK_CHECK_MS, LOST_MS, createStarter, firstPrompt, launchLink, linkLaunches, pressResult, startView,
} from '../tools/lanes-board/launcher.mjs';
import { launchStartText } from '../tools/lanes-board/ui.mjs';

const REPO = 'C:\\Users\\me\\Monomachia';
const launch = (id, time, extra = {}) => ({
  id, time, plan: 'gr', tasks: [`gr:${id}`], branch: `lane/gr-${id}`, goal: `Finish ${id} on lane/gr-${id}.`,
  start: { state: 'queued', at: time, attempts: 0 }, ...extra,
});

// A starter on fakes. press answers from `results` in turn ('pressed' when
// they run out); locked follows `lock.on`. Everything it does lands in `log`.
function harness(launches, { results = [], lock = { on: false }, clock = { t: 10_000 } } = {}) {
  const log = [];
  const starter = createStarter({
    list: () => launches,
    folder: REPO,
    now: () => clock.t,
    open: async (url) => { log.push(['open', url]); },
    press: async ({ prompt, folder }) => { log.push(['press', prompt, folder]); return { result: results.shift() ?? 'pressed' }; },
    locked: async () => { log.push(['locked?']); return lock.on; },
    save: async () => { log.push(['save']); },
  });
  return { starter, log, lock, clock };
}
const acts = (log) => log.filter(([a]) => a === 'open' || a === 'press').map(([a, x]) => `${a} ${a === 'open' ? new URL(x).searchParams.get('q') : x}`);

describe('launchLink', () => {
  it('opens a new Code session in the folder with the prompt in its box', () => {
    const url = new URL(launchLink(REPO, 'Finish 1.1 & 1.2'));
    assert.equal(url.protocol, 'claude:');
    assert.equal(url.host + url.pathname, 'code/new');
    assert.equal(url.searchParams.get('folder'), REPO);
    assert.equal(url.searchParams.get('q'), 'Finish 1.1 & 1.2');
  });
});

describe('createStarter', () => {
  it('presses Send after opening a launch\'s link, so the session starts with nobody at the PC', async () => {
    const l = launch('1.1', 1000);
    const { starter, log } = harness([l]);
    await starter.kick();
    assert.deepEqual(acts(log), ['open Finish 1.1 on lane/gr-1.1.', 'press Finish 1.1 on lane/gr-1.1.']);
    assert.equal(log.find(([a]) => a === 'press')[2], REPO);
    assertMatches(l.start, { state: 'pressed', attempts: 1, pressedAt: 10_000 });
  });

  it('starts launches one at a time in launch order, since each link replaces the draft in the app\'s box', async () => {
    const a = launch('1.1', 2000);
    const b = launch('2.1', 1000);
    const { starter, log } = harness([a, b]);
    starter.kick();
    await starter.kick(); // a second kick joins the run in progress
    assert.deepEqual(acts(log), [
      'open Finish 2.1 on lane/gr-2.1.', 'press Finish 2.1 on lane/gr-2.1.',
      'open Finish 1.1 on lane/gr-1.1.', 'press Finish 1.1 on lane/gr-1.1.',
    ]);
  });

  it('still starts a launch after a kick that had nothing to start, like the board\'s at start-up', async () => {
    const launches = [];
    const { starter, log } = harness(launches);
    await starter.kick();
    launches.push(launch('1.1', 1000));
    await starter.kick();
    assert.deepEqual(acts(log), ['open Finish 1.1 on lane/gr-1.1.', 'press Finish 1.1 on lane/gr-1.1.']);
  });

  it('leaves the link unopened while the PC is locked, and starts the launch once the PC is unlocked', async () => {
    const l = launch('1.1', 1000);
    const { starter, log, lock, clock } = harness([l], { lock: { on: true } });
    await starter.kick();
    assert.deepEqual(acts(log), []);
    assertMatches(l.start, { state: 'waiting', reason: 'locked' });

    await starter.tick(); // still locked
    assert.deepEqual(acts(log), []);
    lock.on = false;
    await starter.tick(); // too soon after the last look at the lock
    assert.deepEqual(acts(log), []);
    clock.t += LOCK_CHECK_MS;
    await starter.tick();
    assert.deepEqual(acts(log), ['open Finish 1.1 on lane/gr-1.1.', 'press Finish 1.1 on lane/gr-1.1.']);
    assertMatches(l.start, { state: 'pressed', attempts: 1 });
  });

  it('waits on the lock again when the PC locks between the check and the press', async () => {
    const l = launch('1.1', 1000);
    const { starter } = harness([l], { results: ['locked'] });
    await starter.kick();
    assertMatches(l.start, { state: 'waiting', reason: 'locked', attempts: 1 });
  });

  it('records why Send couldn\'t be pressed, and tries no more on its own', async () => {
    const l = launch('1.1', 1000);
    const { starter, log, clock } = harness([l], { results: ['no-draft'] });
    await starter.kick();
    assertMatches(l.start, { state: 'waiting', reason: 'no-draft', attempts: 1 });
    clock.t += LOCK_CHECK_MS * 4;
    await starter.tick();
    assert.equal(acts(log).length, 2);
  });

  it('counts a press that answered nonsense, or a link that wouldn\'t open, as an error', async () => {
    const a = launch('1.1', 1000);
    const { starter } = harness([a], { results: ['what?'] });
    await starter.kick();
    assertMatches(a.start, { state: 'waiting', reason: 'error' });
    const c = launch('1.3', 1000);
    const broken = createStarter({
      list: () => [c], folder: REPO, now: () => 5, open: async () => { throw new Error('rundll32 failed'); },
      press: async () => ({ result: 'pressed' }), locked: async () => false, save: async () => {},
    });
    await broken.kick();
    assertMatches(c.start, { state: 'waiting', reason: 'error' });
  });

  it('tries again on request, but not for a launch that started, ended, or is starting now', async () => {
    const l = launch('1.1', 1000);
    const { starter, log } = harness([l], { results: ['no-send'] });
    await starter.kick();
    await starter.retry('1.1'); // refuses at once, else hands back the run it started
    assert.equal(acts(log).length, 4);
    assertMatches(l.start, { state: 'pressed', attempts: 2 });

    assert.throws(() => starter.retry('nope'), /Unknown launch/);
    assert.throws(() => starter.retry('1.1'), /just sent/);
    l.start = { state: 'queued', at: 1, attempts: 2 };
    assert.throws(() => starter.retry('1.1'), /starting now/);
    l.session = { id: 'local_x', cli: 'c' };
    assert.throws(() => starter.retry('1.1'), /already started/);
    delete l.session;
    l.endedAt = 5;
    assert.throws(() => starter.retry('1.1'), /ended/);
  });

  it('allows a retry once a pressed launch has shown no session for a while', async () => {
    const l = launch('1.1', 1000, { start: { state: 'pressed', at: 1000, pressedAt: 1000, attempts: 1 } });
    const { starter, clock } = harness([l]);
    clock.t = 1000 + LOST_MS;
    await starter.retry('1.1');
    assert.equal(l.start.attempts, 2);
  });

  it('skips launches already started, ended or made before launches started themselves', async () => {
    const started = launch('1.1', 1000, { session: { id: 'local_a', cli: 'a' } });
    const ended = launch('1.2', 1000, { endedAt: 2000 });
    const old = { id: '1.3', time: 1000, tasks: ['gr:1.3'], branch: 'lane/gr-1.3', goal: 'g' };
    const { starter, log } = harness([started, ended, old]);
    await starter.kick();
    assert.deepEqual(acts(log), []);
  });

  it('lets a launch older than two days lapse rather than start it, since its tasks no longer show as launched', async () => {
    const old = launch('1.1', 0, { start: { state: 'waiting', reason: 'locked', at: 0, attempts: 0 } });
    const queued = launch('1.2', 0);
    const { starter, log, clock } = harness([old, queued]);
    clock.t = 2 * 24 * 3600_000 + 1;
    await starter.kick();
    await starter.tick();
    assert.deepEqual(acts(log), []);
    assert.throws(() => starter.retry('1.2'), /two days/);
  });

  it('takes up a press the board was killed in the middle of as an error, so it can be retried', () => {
    const l = launch('1.1', 1000, { start: { state: 'pressing', at: 1000, attempts: 1 } });
    const { starter } = harness([l]);
    assert.equal(starter.recover(), 1);
    assertMatches(l.start, { state: 'waiting', reason: 'error' });
  });
});

describe('startView', () => {
  const now = 100_000;
  it('says nothing for launches made before launches started themselves, or ended ones', () => {
    assert.equal(startView({ id: 'x', time: 1, tasks: [] }, now), null);
    assert.equal(startView(launch('1.1', 1, { endedAt: 5 }), now), null);
  });
  it('is started once a session is linked, whatever the queue said', () => {
    assert.deepEqual(startView(launch('1.1', 1, { session: { id: 'local_a' }, start: { state: 'waiting', reason: 'no-draft', at: 1 } }), now), { state: 'started' });
  });
  it('is starting while queued, being pressed, or just sent', () => {
    assert.equal(startView(launch('1.1', 1), now).state, 'starting');
    assert.equal(startView(launch('1.1', 1, { start: { state: 'pressing', at: 1 } }), now).state, 'starting');
    assert.equal(startView(launch('1.1', 1, { start: { state: 'pressed', at: now - 1000, pressedAt: now - 1000 } }), now).state, 'starting');
  });
  it('is waiting, lost, when Send was pressed a while ago and no session appeared', () => {
    assert.deepEqual(startView(launch('1.1', 1, { start: { state: 'pressed', at: 1, pressedAt: now - LOST_MS } }), now),
      { state: 'waiting', reason: 'lost', retry: true, since: 1 });
  });
  it('is waiting with its reason, and offers a retry except while the PC is locked', () => {
    assert.deepEqual(startView(launch('1.1', 1, { start: { state: 'waiting', reason: 'no-send', at: 7 } }), now),
      { state: 'waiting', reason: 'no-send', retry: true, since: 7 });
    assert.deepEqual(startView(launch('1.1', 1, { start: { state: 'waiting', reason: 'locked', at: 7 } }), now),
      { state: 'waiting', reason: 'locked', retry: false, since: 7 });
  });
});

describe('firstPrompt', () => {
  const line = (o) => JSON.stringify(o);
  it('reads the first message the session was sent, past the start-up lines', () => {
    const text = [
      line({ type: 'queue-operation', operation: 'enqueue' }),
      line({ type: 'attachment', attachment: { type: 'hook_additional_context', content: ['lane/gr-1.1 in a hook'] } }),
      line({ type: 'user', message: { role: 'user', content: [
        { type: 'text', text: '<system-reminder>\nYou are operating in a git worktree.\n</system-reminder>\n\n' },
        { type: 'text', text: 'Finish 1.1 on lane/gr-1.1.' },
      ] } }),
      line({ type: 'user', message: { role: 'user', content: 'a later message about lane/gr-2.1' } }),
    ].join('\n');
    assert.equal(firstPrompt(text), '<system-reminder>\nYou are operating in a git worktree.\n</system-reminder>\n\n\nFinish 1.1 on lane/gr-1.1.');
  });
  it('takes a plain string message, and is null before the first message or on a cut-off line', () => {
    assert.equal(firstPrompt(line({ type: 'user', message: { content: 'hello' } })), 'hello');
    assert.equal(firstPrompt(line({ type: 'attachment' })), null);
    assert.equal(firstPrompt('{"type":"user","message":{"content":"cut of'), null);
  });
  it('skips tool results and meta lines, which are not prompts', () => {
    const text = [
      line({ type: 'user', isMeta: true, message: { content: 'caveat' } }),
      line({ type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: 't', content: 'x' }] } }),
      line({ type: 'user', message: { content: 'the prompt' } }),
    ].join('\n');
    assert.equal(firstPrompt(text), 'the prompt');
  });
});

describe('linkLaunches', () => {
  const sess = (id, created, cli = `cli-${id}`) => ({ id, cli, created });
  it('links each launch to the earliest session made since it whose first prompt names its branch', () => {
    const a = launch('1.1', 1000);
    const b = launch('2.1', 1000);
    const sessions = [sess('local_other', 1500), sess('local_b', 2000), sess('local_a', 3000), sess('local_a2', 4000)];
    const prompts = new Map([
      ['cli-local_other', 'something else entirely'],
      ['cli-local_b', 'Finish 2.1 on lane/gr-2.1.'],
      ['cli-local_a', 'Finish 1.1 on lane/gr-1.1.'],
      ['cli-local_a2', 'Finish 1.1 on lane/gr-1.1.'],
    ]);
    assert.equal(linkLaunches([a, b], sessions, prompts), true);
    assert.deepEqual(a.session, { id: 'local_a', cli: 'cli-local_a' });
    assert.deepEqual(b.session, { id: 'local_b', cli: 'cli-local_b' });
    assert.equal(linkLaunches([a, b], sessions, prompts), false);
  });

  it('links a session started by hand from the draft hours later, but none made before the launch', () => {
    const l = launch('1.1', 1_000_000);
    assert.equal(linkLaunches([l], [sess('local_early', 900_000)], new Map([['cli-local_early', 'lane/gr-1.1']])), false);
    assert.equal(linkLaunches([l], [sess('local_late', 1_000_000 + 5 * 3600_000)], new Map([['cli-local_late', 'lane/gr-1.1']])), true);
    assert.equal(l.session.id, 'local_late');
  });

  it('waits for a session whose first prompt isn\'t known yet, and doesn\'t mistake lane/gr-1.1 for lane/gr-1.10', () => {
    const l = launch('1.1', 1000);
    assert.equal(linkLaunches([l], [sess('local_new', 2000, null), sess('local_x', 2000)], new Map([['cli-local_x', 'Finish lane/gr-1.10 now']])), false);
    assert.equal(l.session, undefined);
  });

  it('leaves ended launches and sessions another launch took alone', () => {
    const a = launch('1.1', 1000, { session: { id: 'local_a', cli: 'cli-local_a' } });
    const b = launch('1.1', 1000, { id: 'again' });
    const ended = launch('1.2', 1000, { endedAt: 3000 });
    const prompts = new Map([['cli-local_a', 'lane/gr-1.1'], ['cli-local_c', 'lane/gr-1.2']]);
    assert.equal(linkLaunches([a, b, ended], [sess('local_a', 2000), sess('local_c', 2500)], prompts), false);
    assert.equal(b.session, undefined);
    assert.equal(ended.session, undefined);
  });
});

describe('pressResult', () => {
  it('reads the press script\'s last line of JSON', () => {
    assert.deepEqual(pressResult('noise\r\n{"result":"pressed","ms":812,"trusted":true}\r\n'), { result: 'pressed', ms: 812, trusted: true });
  });
  it('is an error for anything else', () => {
    assert.deepEqual(pressResult(''), { result: 'error' });
    assert.deepEqual(pressResult('Exception calling "Invoke"'), { result: 'error' });
    assert.deepEqual(pressResult('{"ms":1}'), { result: 'error' });
  });
});

describe('launchStartText', () => {
  it('says how a launch is getting on, and why it waits', () => {
    assert.equal(launchStartText(null), null);
    assert.equal(launchStartText({ state: 'started' }), 'Started on the PC');
    assert.equal(launchStartText({ state: 'starting' }), 'Starting on the PC: the board presses Send in the Claude app');
    assert.equal(launchStartText({ state: 'waiting', reason: 'locked' }), 'Waiting: the PC is locked. It starts when the PC is unlocked.');
    assert.match(launchStartText({ state: 'waiting', reason: 'no-draft' }), /^Couldn't start: .*prompt.*\. Try again, or send it from the Claude app on the PC\.$/);
    assert.match(launchStartText({ state: 'waiting', reason: 'surprise' }), /^Couldn't start: .*\. Try again/);
  });
});

// The real press, on Windows only: first with a prompt no app shows, then against
// a stand-in for the app.
const run = promisify(execFile);
const SCRIPT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'tools', 'lanes-board', 'press-send.ps1');
const POWERSHELL = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', SCRIPT];
describe('press-send.ps1', { skip: process.platform !== 'win32' && 'needs Windows UI Automation' }, () => {
  it('reports a prompt it can\'t find without pressing anything', async () => {
    const { stdout } = await run('powershell.exe', [...POWERSHELL, '-WaitMs', '1500'], {
      windowsHide: true, timeout: 60_000,
      env: { ...process.env, LANES_PROMPT: `no such draft ${Math.random()}`, LANES_FOLDER: 'C:\\no\\such\\folder' },
    });
    // 'trust' if the app happens to be asking about another folder right now.
    assert.ok(['no-draft', 'no-app', 'locked', 'trust'].includes(pressResult(stdout).result));
  });

  it('answers the lock check', async () => {
    const { stdout } = await run('powershell.exe', [...POWERSHELL, '-LockOnly'], { windowsHide: true, timeout: 60_000 });
    assert.ok(['locked', 'unlocked'].includes(pressResult(stdout).result));
  });

  // A stand-in for the app: a see-through, off-screen window with the prompt in a
  // box and, unless told otherwise, a Send button that empties the box and notes
  // the press. WPF, because like the app it exposes its controls to UI Automation
  // itself (WinForms controls show up as plain panes).
  const FAKE = `param([switch]$NoSend)
Add-Type -AssemblyName PresentationFramework
$w = New-Object System.Windows.Window
$w.Title = 'Lanes press test'; $w.WindowStartupLocation = 'Manual'; $w.Left = -4000; $w.Top = -4000
$w.Width = 420; $w.Height = 120; $w.ShowInTaskbar = $false; $w.ShowActivated = $false
$w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Opacity = 0.01
$panel = New-Object System.Windows.Controls.StackPanel
$box = New-Object System.Windows.Controls.TextBox; $box.Text = $env:LANES_PROMPT
$panel.Children.Add($box) | Out-Null
if (-not $NoSend) {
  $b = New-Object System.Windows.Controls.Button; $b.Content = 'Send'
  $b.Add_Click({ $box.Text = ''; Add-Content -Path $env:FAKE_LOG -Value 'sent' })
  $panel.Children.Add($b) | Out-Null
}
$w.Content = $panel
$w.Add_ContentRendered({ Add-Content -Path $env:FAKE_LOG -Value 'shown' })
$t = New-Object System.Windows.Threading.DispatcherTimer; $t.Interval = [TimeSpan]::FromSeconds(30); $t.Add_Tick({ $w.Close() }); $t.Start()
$w.ShowDialog() | Out-Null
`;
  async function withFakeApp(args, fn) {
    const dir = mkdtempSync(path.join(os.tmpdir(), 'lanes-press-'));
    const log = path.join(dir, 'log.txt');
    writeFileSync(path.join(dir, 'fake.ps1'), FAKE);
    const env = { ...process.env, LANES_PROMPT: `Press test ${Math.random()}: lane/gr-0.0`, FAKE_LOG: log };
    const app = spawn('powershell.exe', ['-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(dir, 'fake.ps1'), ...args], { env, windowsHide: true });
    try {
      for (let i = 0; i < 100 && !(existsSync(log) && readFileSync(log, 'utf8').includes('shown')); i++) await new Promise((r) => setTimeout(r, 100));
      return await fn({ env, sent: () => existsSync(log) && readFileSync(log, 'utf8').includes('sent') });
    } finally {
      app.kill();
      rmSync(dir, { recursive: true, force: true });
    }
  }
  const press = async (env, extra) => pressResult((await run('powershell.exe', [...POWERSHELL, '-App', 'powershell', ...extra],
    { windowsHide: true, timeout: 60_000, env })).stdout);

  it('presses the Send button beside the box holding the prompt, once the box has settled', () => withFakeApp([], async ({ env, sent }) => {
    const r = await press(env, ['-WaitMs', '20000', '-SettleMs', '1200', '-TakeMs', '5000']);
    assert.equal(r.result, 'pressed');
    assert.ok(r.ms >= 1200, `pressed after ${r.ms} ms`);
    assert.equal(sent(), true);
  }));

  it('says no-send for a box with no Send button, and presses nothing', () => withFakeApp(['-NoSend'], async ({ env, sent }) => {
    const r = await press(env, ['-WaitMs', '3000', '-SettleMs', '200']);
    assert.equal(r.result, 'no-send');
    assert.equal(sent(), false);
  }));
});
