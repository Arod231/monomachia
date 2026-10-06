// Tests for the lanes board's Graph and Sessions tabs: the graph layout
// (tools/lanes-board/graph.mjs), the transcript reader and what the owner sends
// sessions (sessions.mjs), each session's context gauge (sessions.mjs), and the
// relay hook a session runs (relay-hook.mjs).

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { isDeepStrictEqual } from 'node:util';
import { assertMatches } from './assert-matches.mjs';
import { edgePath, layoutPlan, related } from '../tools/lanes-board/graph.mjs';
import {
  COMMANDS, SESSION_ID, autoCompactAt, awayOf, awaySwitch, contextTracker, contextWindowFor, downsample,
  STOP_NOW, deliveryOf, remoteLinkOf, endedAtOf, ownerMessage, parseTranscript, sessionState, toolSummary, turnSummary,
} from '../tools/lanes-board/sessions.mjs';
import { pageFor } from '../tools/lanes-board/access.mjs';

// A plan as /data serves it.
const task = (title, status, blockers = []) => ({
  title, status, gate: false, ownerOk: [], blockers: blockers.map((ref) => ({ ref, label: ref.split(':')[1], done: ref.endsWith('.1') })),
});
const PLAN = {
  key: 'gr',
  stages: [{ n: 1, name: 'One', ids: ['1.1', '1.2', '1.3', '1.4'] }, { n: 2, name: 'Two', ids: ['2.1', '2.2'] }],
  tasks: {
    '1.1': task('Root', 'done'),
    '1.2': task('After root', 'ready', ['gr:1.1']),
    '1.3': task('After that', 'blocked', ['gr:1.2', 'aa:9']),
    '1.4': task('Old idea', 'retired'),
    '2.1': task('Next stage', 'blocked', ['gr:1.3']),
    '2.2': task('Also next', 'blocked', ['gr:2.1']),
  },
};

describe('layoutPlan', () => {
  const L = layoutPlan(PLAN, { hide: ['retired'] });
  const node = (id) => L.nodes.find((n) => n.id === id);

  it('gives each stage a band, other plans\' blockers a band on top, and leaves hidden tasks out', () => {
    assert.deepEqual(L.bands.map((b) => b.name), ['From other plans', 'One', 'Two']);
    assertMatches(node('aa:9'), { external: true, label: '9' });
    assert.equal(node('1.4'), undefined);
    assert.ok(L.width > 0);
    assert.ok(L.height > L.bands.at(-1).y);
  });

  it('puts a task one column right of its latest blocker in the same stage', () => {
    assert.ok(node('1.1').x < node('1.2').x);
    assert.ok(node('1.2').x < node('1.3').x);
    assert.equal(node('2.1').x, node('1.1').x); // its blocker is in another stage
    assert.ok(node('2.2').x > node('2.1').x);
  });

  it('draws an edge per blocker shown, and drops done ones when done tasks are hidden', () => {
    assert.ok(L.edges.some((e) => isDeepStrictEqual(e, { from: '1.1', to: '1.2', done: true })));
    assert.ok(L.edges.some((e) => isDeepStrictEqual(e, { from: 'aa:9', to: '1.3', done: false })));
    const open = layoutPlan(PLAN, { hide: ['retired', 'done'] });
    assert.equal(open.nodes.find((n) => n.id === '1.1'), undefined);
    assert.equal(open.edges.some((e) => e.from === '1.1'), false);
  });

  it('survives a loop in the plan', () => {
    const loop = { key: 'gr', stages: [{ n: 1, name: 'L', ids: ['1.1', '1.2'] }],
      tasks: { '1.1': task('A', 'blocked', ['gr:1.2']), '1.2': task('B', 'blocked', ['gr:1.1']) } };
    assert.equal(layoutPlan(loop).nodes.length, 2);
  });
});

describe('related', () => {
  it('finds everything a task waits on and everything that waits on it, however far', () => {
    const { edges } = layoutPlan(PLAN, { hide: ['retired'] });
    const { up, down } = related(edges, '1.3');
    assert.deepEqual([...up].sort(), ['1.1', '1.2', 'aa:9']);
    assert.deepEqual([...down].sort(), ['2.1', '2.2']);
  });
});

describe('edgePath', () => {
  it('runs left to right within a band and top to bottom between bands', () => {
    const a = { x: 0, y: 0, w: 100, h: 40 };
    assert.match(edgePath(a, { x: 200, y: 0, w: 100, h: 40 }), /^M100,20 C/);
    assert.match(edgePath(a, { x: 0, y: 200, w: 100, h: 40 }), /^M50,40 C.* 50,200$/);
  });
});

describe('the board serves graph.mjs to the page', () => {
  it('as JavaScript', () => {
    assert.deepEqual(pageFor('/graph.mjs', ''), { file: 'graph.mjs', type: 'text/javascript; charset=utf-8' });
  });
});

// ---------- transcripts ----------

const line = (o) => JSON.stringify({ sessionId: 's', timestamp: '2026-10-04T06:00:00.000Z', ...o });
const TRANSCRIPT = [
  '{"cut off mid-li', // the tail read starts mid-line
  line({ type: 'custom-title', customTitle: 'Board work' }),
  line({ type: 'user', cwd: 'C:/repo', message: { content: 'Build the graph' } }),
  line({ type: 'user', isMeta: true, message: { content: 'meta' } }),
  line({ type: 'user', message: { content: '<command-name>/goal</command-name>\n<command-args>finish it</command-args>' } }),
  line({ type: 'user', message: { content: '<local-command-stdout>noise</local-command-stdout>' } }),
  line({ type: 'assistant', message: { content: [{ type: 'thinking', thinking: 'hm' }, { type: 'text', text: 'On it.' },
    { type: 'tool_use', id: 't1', name: 'Bash', input: { command: 'npm test\nmore', description: 'Run tests' } }] } }),
  line({ type: 'user', message: { content: [{ type: 'tool_result', tool_use_id: 't1', content: [{ type: 'text', text: 'ok' }] }] } }),
  line({ type: 'assistant', isSidechain: true, message: { content: [{ type: 'text', text: 'subagent' }] } }),
  line({ type: 'assistant', message: { content: [{ type: 'tool_use', id: 't2', name: 'AskUserQuestion',
    input: { questions: [{ question: 'Which?', options: [{ label: 'A' }, { label: 'B' }] }] } }] } }),
];

describe('parseTranscript', () => {
  const t = parseTranscript(TRANSCRIPT);

  it('reads the title, the folder and the turns, skipping meta, side chains, app noise and thinking', () => {
    assert.equal(t.title, 'Board work');
    assert.equal(t.cwd, 'C:/repo');
    assert.deepEqual(t.entries.map((e) => e.kind), ['user', 'user', 'assistant', 'tool', 'result', 'tool']);
    assert.equal(t.entries[1].text, '/goal finish it');
    assertMatches(t.entries[3], { name: 'Bash', summary: 'npm test' });
    assertMatches(t.entries[4], { tool: 't1', text: 'ok', error: false });
  });

  it('finds the tool call still waiting, with a question\'s choices', () => {
    assertMatches(t.open, { id: 't2', name: 'AskUserQuestion' });
    assert.deepEqual(t.open.questions[0].options.map((o) => o.label), ['A', 'B']);
    assert.equal(parseTranscript(TRANSCRIPT.slice(0, 8)).open, null);
  });

  it('keeps the newest turns and says how many it left out', () => {
    const short = parseTranscript(TRANSCRIPT, { limit: 2 });
    assert.deepEqual(short.entries.map((e) => e.kind), ['result', 'tool']);
    assert.equal(short.more, 4);
  });

  it('falls back to the first prompt for a title', () => {
    assert.equal(parseTranscript(TRANSCRIPT.slice(2)).title, 'Build the graph');
  });

  it('names the newest main-chain reply\'s line, which the app\'s turn summary points at', () => {
    const line = (o) => JSON.stringify(o);
    const lines = [
      line({ type: 'assistant', uuid: 'u1', message: { content: [{ type: 'text', text: 'One' }] } }),
      line({ type: 'assistant', uuid: 'u2', message: { content: [{ type: 'text', text: 'Two' }] } }),
      line({ type: 'assistant', uuid: 'side', isSidechain: true, message: { content: [{ type: 'text', text: 'Agent' }] } }),
      line({ type: 'system', uuid: 'sys', subtype: 'stop_hook_summary' }),
    ];
    assert.equal(parseTranscript(lines).lastReply, 'u2');
    assert.equal(parseTranscript([]).lastReply, null);
  });
});

describe('toolSummary', () => {
  it('names what a call does in one line', () => {
    assert.equal(toolSummary('Read', { file_path: 'a.ts' }), 'a.ts');
    assert.equal(toolSummary('AskUserQuestion', { questions: [{ question: 'X?' }, { question: 'Y?' }] }), 'X? · Y?');
    assert.equal(toolSummary('Mystery', { n: 1, what: 'thing' }), 'thing');
  });
});

// ---------- the context gauge ----------

const T0 = Date.parse('2026-10-04T12:00:00Z');
const at = (min) => new Date(T0 + min * 60_000).toISOString();
// One main-chain API response: its context is input + cache writes + cache reads.
const turn = (min, tokens, { id = `msg_${min}`, side = false, model = 'claude-opus-5-5' } = {}) => JSON.stringify({
  type: 'assistant', isSidechain: side, timestamp: at(min),
  message: { id, model, role: 'assistant', content: [{ type: 'text', text: 'ok' }],
    usage: { input_tokens: 2, cache_creation_input_tokens: 100, cache_read_input_tokens: tokens - 102, output_tokens: 900 } },
});
const boundary = (min) => JSON.stringify({ type: 'system', subtype: 'compact_boundary', isSidechain: false, timestamp: at(min),
  content: 'Conversation compacted', compactMetadata: { trigger: 'auto', preTokens: 966_000 } });
const summary = (min) => JSON.stringify({ type: 'user', isSidechain: false, isCompactSummary: true, timestamp: at(min),
  message: { role: 'user', content: 'This session is being continued from a previous conversation…' } });
const track = (lines, env) => { const c = contextTracker(env); c.feed(lines.map((l) => `${l}\n`).join('')); return c.view(); };

describe('contextWindowFor', () => {
  it('knows each model\'s window, 1M on the current ones and 200K on Haiku and the older ones', () => {
    for (const m of ['claude-opus-5-5', 'claude-sonnet-5-5', 'claude-fable-5-1', 'claude-fable-5', 'claude-opus-5',
      'claude-sonnet-5', 'claude-opus-4-8', 'claude-opus-4-7', 'claude-mythos-5-1']) assert.equal(contextWindowFor(m), 1_000_000);
    for (const m of ['claude-haiku-4-5-20251001', 'claude-haiku-4-5', 'claude-opus-4-6', 'claude-sonnet-4-6',
      'claude-sonnet-4-5-20250929', 'claude-opus-4-1-20250805', 'claude-3-7-sonnet-20250219']) assert.equal(contextWindowFor(m), 200_000);
  });

  it('takes a [1m] suffix, then LANES_CONTEXT_WINDOW over everything, and falls back for an unknown model', () => {
    assert.equal(contextWindowFor('claude-opus-4-6[1m]'), 1_000_000);
    assert.equal(contextWindowFor('claude-sonnet-4-6[1M]'), 1_000_000);
    assert.equal(contextWindowFor('claude-opus-5-5', { LANES_CONTEXT_WINDOW: '500000' }), 500_000);
    assert.equal(contextWindowFor('claude-opus-4-6[1m]', { LANES_CONTEXT_WINDOW: '300000' }), 300_000);
    assert.equal(contextWindowFor('claude-opus-5-5', { LANES_CONTEXT_WINDOW: 'lots' }), 1_000_000);
    assert.equal(contextWindowFor('some-gateway-alias'), 200_000);
    assert.equal(contextWindowFor(null), 200_000);
  });
});

describe('autoCompactAt', () => {
  it('is about 967K on a 1M window and the window itself on a 200K one, unless LANES_AUTOCOMPACT_PCT says', () => {
    assert.equal(autoCompactAt(1_000_000), 967_000);
    assert.equal(autoCompactAt(200_000), 200_000);
    assert.equal(autoCompactAt(1_000_000, { LANES_AUTOCOMPACT_PCT: '80' }), 800_000);
    assert.equal(autoCompactAt(200_000, { LANES_AUTOCOMPACT_PCT: '50' }), 100_000);
    assert.equal(autoCompactAt(200_000, { LANES_AUTOCOMPACT_PCT: '0' }), 200_000);
  });
});

describe('contextTracker', () => {
  it('has nothing to show before the first reply with usage', () => {
    assert.equal(track([summary(0)]), null);
    assert.equal(contextTracker().view(), null);
  });

  it('takes the newest main-chain reply\'s input, cache writes and cache reads as the context', () => {
    const v = track([turn(0, 30_000), turn(1, 45_000), turn(2, 250_000)]);
    assertMatches(v, { model: 'claude-opus-5-5', tokens: 250_000, window: 1_000_000, pct: 25, autoCompactAt: 967_000,
      updated: T0 + 2 * 60_000, compactions: [] });
    assert.deepEqual(v.series, [{ t: T0, tokens: 30_000 }, { t: T0 + 60_000, tokens: 45_000 }, { t: T0 + 120_000, tokens: 250_000 }]);
  });

  it('ignores side chains, synthetic replies and broken lines, and counts a reply split over lines once', () => {
    const v = track([turn(0, 30_000), turn(1, 900_000, { side: true }), '{oops', turn(2, 0, { model: '<synthetic>' }),
      turn(3, 40_000, { id: 'msg_x' }), turn(3, 40_000, { id: 'msg_x' })]);
    assert.equal(v.tokens, 40_000);
    assert.deepEqual(v.series.map((p) => p.tokens), [30_000, 40_000]);
  });

  it('marks a compaction once for its boundary and summary pair, and the series drops after it', () => {
    const v = track([turn(0, 900_000), turn(1, 960_000), boundary(2), summary(2), turn(3, 60_000), turn(4, 70_000)]);
    assert.deepEqual(v.compactions, [T0 + 120_000]);
    assert.deepEqual(v.series.map((p) => p.tokens), [900_000, 960_000, 60_000, 70_000]);
    assert.equal(v.tokens, 70_000);
    // A summary with no boundary line still counts.
    assert.deepEqual(track([turn(0, 900_000), summary(1), turn(2, 50_000)]).compactions, [T0 + 60_000]);
    // Compactions inside a side chain don't.
    assert.deepEqual(track([turn(0, 1000), JSON.stringify({ ...JSON.parse(boundary(1)), isSidechain: true })]).compactions, []);
  });

  it('shows a session compacted since its last reply as just compacted, not at its old fill', () => {
    const v = track([turn(0, 150_000, { model: 'claude-haiku-4-5' }), turn(1, 190_000, { model: 'claude-haiku-4-5' }), boundary(2), summary(2)]);
    assertMatches(v, { compacted: true, tokens: null, pct: null, before: 190_000, window: 200_000, updated: T0 + 120_000,
      compactions: [T0 + 120_000] });
    assert.deepEqual(v.series.map((p) => p.tokens), [150_000, 190_000]);
    // The next reply gives the new fill.
    const after = track([turn(0, 190_000), boundary(1), summary(1), turn(2, 20_000)]);
    assertMatches(after, { compacted: false, tokens: 20_000, before: null });
  });

  it('reads the same whatever the chunks, carrying a cut line over to the next chunk', () => {
    const text = [turn(0, 30_000), turn(1, 40_000), boundary(2), summary(2), turn(3, 5_000)].map((l) => `${l}\n`).join('');
    const whole = contextTracker();
    whole.feed(text);
    for (const step of [1, 7, 50, 333]) {
      const c = contextTracker();
      for (let i = 0; i < text.length; i += step) c.feed(text.slice(i, i + step));
      assert.deepEqual(c.view(), whole.view());
    }
    // An unfinished last line waits for the rest.
    const c = contextTracker();
    c.feed(`${turn(0, 30_000)}\n${turn(1, 40_000).slice(0, 40)}`);
    assert.equal(c.view().tokens, 30_000);
    c.feed(`${turn(1, 40_000).slice(40)}\n`);
    assert.equal(c.view().tokens, 40_000);
  });

  it('skips the cut first line when it starts reading mid-file', () => {
    const c = contextTracker();
    c.feed(`${turn(0, 30_000).slice(20)}\n${turn(1, 40_000)}\n`, { cut: true });
    assert.deepEqual(c.view().series, [{ t: T0 + 60_000, tokens: 40_000 }]);
  });

  it('gives a 200K model that has gone past 200K its 1M variant\'s window', () => {
    const v = track([turn(0, 150_000, { model: 'claude-opus-4-6' }), turn(1, 260_000, { model: 'claude-opus-4-6' })]);
    assert.equal(v.window, 1_000_000);
    assertMatches(track([turn(0, 150_000, { model: 'claude-haiku-4-5-20251001' })]), { window: 200_000, pct: 75, autoCompactAt: 200_000 });
  });

  it('applies the env overrides', () => {
    assertMatches(track([turn(0, 100_000)], { LANES_CONTEXT_WINDOW: '400000', LANES_AUTOCOMPACT_PCT: '90' }), { window: 400_000, pct: 25, autoCompactAt: 360_000 });
  });

  it('keeps its memory bounded over a very long session', () => {
    const c = contextTracker();
    let text = '';
    for (let i = 0; i < 5000; i++) text += `${turn(i, 10_000 + (i % 400) * 2000)}\n`;
    c.feed(text);
    const v = c.view();
    assert.ok(c.size() <= 1000);
    assert.ok(v.series.length <= 120);
    assert.deepEqual(v.series.at(-1), { t: T0 + 4999 * 60_000, tokens: 10_000 + (4999 % 400) * 2000 });
    assert.equal(v.tokens, 10_000 + (4999 % 400) * 2000);
  });
});

describe('downsample', () => {
  // A sawtooth: climbs 1K a turn and compacts every 300 turns.
  const series = Array.from({ length: 1000 }, (_, i) => ({ t: i, tokens: 1000 * ((i % 300) + 1) }));
  const compactions = [299.5, 599.5, 899.5];

  it('leaves a short series alone', () => {
    assert.deepEqual(downsample(series.slice(0, 50), [], 120), series.slice(0, 50));
  });

  it('caps the points, keeping the newest, both sides of every compaction and the peaks', () => {
    const d = downsample(series, compactions, 120);
    assert.ok(d.length <= 120);
    assert.deepEqual(d.at(-1), series.at(-1));
    assert.deepEqual(d[0], series[0]);
    for (const c of compactions) {
      assert.ok(d.some((e) => isDeepStrictEqual(e, series[Math.floor(c)])));
      assert.ok(d.some((e) => isDeepStrictEqual(e, series[Math.ceil(c)])));
    }
    assert.equal(Math.max(...d.map((p) => p.tokens)), 300_000);
    assert.deepEqual(d.map((p) => p.t), [...d.map((p) => p.t)].sort((a, b) => a - b));
  });
});

describe('what the owner sends a session', () => {
  it('has Show me among its commands, and no Approve: approvals are given in the app', () => {
    assert.deepEqual(Object.keys(COMMANDS), ['show']);
    assert.match(ownerMessage({ command: 'show' }), /^The owner asks from the Project Manager: show me what you're working on\. .*`npm run post -- <file> --caption .*nothing to show yet\.$/);
    assert.throws(() => ownerMessage({ command: 'approve' }), /No such command/);
    assert.throws(() => ownerMessage({ command: 'merge' }), /No such command/);
  });

  it('words what the owner sends a session, ready to deliver', () => {
    assert.equal(ownerMessage({ text: ' Rename it ' }), 'The owner replied from the Project Manager:\n\nRename it');
    assert.equal(ownerMessage({ text: 'x'.repeat(30000) }).length, 'The owner replied from the Project Manager:\n\n'.length + 20000);
    assert.throws(() => ownerMessage({}), /Type a reply first/);
  });

  it('says when a message reaches its session: before its next step, or at its next turn end', () => {
    assert.equal(deliveryOf({ active: true }), 'next-step');
    assert.equal(deliveryOf({ active: false }), 'turn-end');
  });

  it('reads the app\'s turn summary only when it is about the turn that just ended', () => {
    const raw = { status_category: 'needs_input', status_detail: 'Asked about the camera', needs_action: 'pick one', summarizes_uuid: 'u2' };
    assert.deepEqual(turnSummary(raw, 'u2'), { status: 'needs_input', label: 'Needs input', detail: 'Asked about the camera', action: 'pick one' });
    assert.equal(turnSummary(raw, 'u1'), null);
    assert.equal(turnSummary(null, 'u2'), null);
    assert.equal(turnSummary({ ...raw, status_category: 'odd_new_kind', needs_action: '' }, 'u2').label, 'odd new kind');
    assert.deepEqual(['completed', 'review_ready', 'blocked', 'failed'].map((c) => turnSummary({ ...raw, status_category: c }, 'u2').label),
      ['Done', 'Ready for review', 'Blocked', 'Failed']);
  });

  it('checks ids before they name a file', () => {
    assert.equal(SESSION_ID.test('11111111-2222-4333-8444-555555555555'), true);
    assert.equal(SESSION_ID.test('../../etc'), false);
  });
});

describe('the Away switch', () => {
  const IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1';
  it('records on or off, since when and from which device', () => {
    assert.deepEqual(awaySwitch({ on: true }, IPHONE, 5), { on: true, since: 5, from: 'phone' });
    assert.deepEqual(awaySwitch({ on: false }, 'Mozilla/5.0 (Windows NT 10.0)', 6), { on: false, since: 6, from: 'PC' });
  });
  it('reads a missing or broken Away file as off', () => {
    assert.deepEqual(awayOf(null), { on: false, since: null, from: null });
    assert.deepEqual(awayOf({ on: 'yes' }), { on: false, since: null, from: null });
    assert.deepEqual(awayOf({ on: true, since: 3, from: 'phone' }), { on: true, since: 3, from: 'phone' });
  });
});

// ---------- the relay hook ----------

describe('relay hook', () => {
  const HOOK = fileURLToPath(new URL('../tools/lanes-board/relay-hook.mjs', import.meta.url));
  const ID = '11111111-2222-4333-8444-555555555555';
  let dir;
  beforeEach(() => { dir = mkdtempSync(path.join(os.tmpdir(), 'lanes-relay-')); });
  afterEach(() => rmSync(dir, { recursive: true, force: true }));

  const setAway = (on = true) => writeFileSync(path.join(dir, 'away.json'), JSON.stringify({ on, since: 1, from: 'PC' }));
  // Runs the hook, which must answer at once: it never holds a session.
  const run = (input, relay = dir) => new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [HOOK], { env: { ...process.env, LANES_RELAY: relay } });
    let out = '';
    child.stdout.on('data', (c) => { out += c; });
    child.on('error', reject);
    const timer = setTimeout(() => { child.kill(); reject(new Error('the hook held the session')); }, 5000);
    child.on('close', () => { clearTimeout(timer); resolve({ out }); });
    child.stdin.end(JSON.stringify({ session_id: ID, cwd: 'C:/repo', ...input }));
  });
  const events = () => (existsSync(path.join(dir, 'events.jsonl'))
    ? readFileSync(path.join(dir, 'events.jsonl'), 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)) : []);
  const ASK = { hook_event_name: 'PermissionRequest', tool_name: 'AskUserQuestion', tool_input: { questions: [{ question: 'Which?', options: [{ label: 'A' }] }] } };

  it('does nothing with no relay folder at all', async () => {
    const r = await run(ASK, path.join(dir, 'missing'));
    assert.equal(r.out, '');
    assert.equal(existsSync(path.join(dir, 'missing')), false);
  });

  it('leaves every prompt, plan and question to the app, Away on or off, noting a question asked there and a turn finished', async () => {
    for (const on of [false, true]) {
      setAway(on);
      assert.equal((await run({ hook_event_name: 'PermissionRequest', tool_name: 'Bash', tool_input: { command: 'ls' } })).out, '');
      assert.equal((await run({ hook_event_name: 'PermissionRequest', tool_name: 'ExitPlanMode', tool_input: { plan: '# Plan' } })).out, '');
      assert.equal((await run(ASK)).out, '');
      assert.equal((await run({ hook_event_name: 'Stop', last_assistant_message: 'Done.' })).out, '');
    }
    assert.equal(existsSync(path.join(dir, 'pending')), false, 'nothing is held for the board');
    const ev = events();
    assert.equal(ev.length, 4);
    assertMatches(ev[0], { kind: 'asked-in-app', session: ID, cwd: 'C:/repo', questions: ['Which?'] });
    assert.equal(typeof ev[0].time, 'number');
    assertMatches(ev[1], { kind: 'turn-finished', session: ID, cwd: 'C:/repo', last: 'Done.' });
  });

  it('hands over everything in its inbox when a turn ends, oldest first, without waiting, Away on or off', async () => {
    for (const on of [true, false]) {
      setAway(on);
      const inbox = path.join(dir, 'inbox', ID);
      mkdirSync(inbox, { recursive: true });
      writeFileSync(path.join(inbox, '000000000000002-000001.json'), JSON.stringify({ text: 'Newer words' }));
      writeFileSync(path.join(inbox, '000000000000001-000000.json'), JSON.stringify({ text: 'Queued words' }));
      const { out } = await run({ hook_event_name: 'Stop' });
      assert.deepEqual(JSON.parse(out), { decision: 'block', reason: 'Queued words\n\nNewer words' });
      assert.deepEqual(readdirSync(inbox), []);
    }
  });

  it('clears a Stop now once the turn ends', async () => {
    mkdirSync(path.join(dir, 'stopnow'), { recursive: true });
    writeFileSync(path.join(dir, 'stopnow', `${ID}.json`), JSON.stringify({ text: STOP_NOW, time: 1 }));
    assert.equal((await run({ hook_event_name: 'Stop' })).out, '');
    assert.deepEqual(readdirSync(path.join(dir, 'stopnow')), []);
  });

  it('never blocks on a broken Away file', async () => {
    writeFileSync(path.join(dir, 'away.json'), '{not json');
    assert.equal((await run({ hook_event_name: 'Stop' })).out, '');
    assert.equal((await run(ASK)).out, '');
  });
});

describe('the session page\'s rules', () => {
  it('reads the branch the session is on from its newest line', () => {
    const line = (o) => JSON.stringify(o);
    const lines = [
      line({ type: 'user', gitBranch: 'lane/pm-1', message: { content: 'Go' } }),
      line({ type: 'assistant', gitBranch: 'lane/pm-11-12', message: { content: [{ type: 'text', text: 'On it.' }] } }),
      line({ type: 'assistant', isSidechain: true, gitBranch: 'other', message: { content: [{ type: 'text', text: 'Agent' }] } }),
    ];
    assert.equal(parseTranscript(lines).branch, 'lane/pm-11-12');
    assert.equal(parseTranscript([]).branch, null);
    assert.equal(parseTranscript([line({ type: 'user', gitBranch: 'HEAD', message: { content: 'x' } })]).branch, null, 'a detached head names no branch');
  });

  it('gives a session one state: asked in the app, ended, at work or idle', () => {
    const base = { asking: null, active: false, activity: 1000, endedAt: null };
    assert.equal(sessionState({ ...base, asking: ['Which?'], active: true }), 'asked');
    assert.equal(sessionState({ ...base, active: true }), 'working');
    assert.equal(sessionState(base), 'idle');
    assert.equal(sessionState({ ...base, endedAt: 900 }), 'ended');
    assert.equal(sessionState({ ...base, active: true, activity: 1000, endedAt: 900 }), 'ended', 'still finishing its last step');
    assert.equal(sessionState({ ...base, active: true, activity: 900 + 3 * 60 * 1000, endedAt: 900 }), 'working', 'woken again since');
  });

  it('finds when a session\'s work was last ended: by its id, or inside an ended lane\'s worktree', () => {
    const stops = [
      { requestedAt: 100, sessions: ['s1'], worktree: null },
      { requestedAt: 200, sessions: [], worktree: 'C:\\repo\\.claude\\worktrees\\lane-a' },
      { requestedAt: 300, sessions: ['s1'], cancelledAt: 310 },
    ];
    assert.equal(endedAtOf(stops, { id: 's1', cwd: 'C:\\other' }), 100);
    assert.equal(endedAtOf(stops, { id: 's2', cwd: 'c:\\repo\\.claude\\worktrees\\lane-a\\tools' }), 200);
    assert.equal(endedAtOf(stops, { id: 's2', cwd: 'C:/repo/.claude/worktrees/lane-a' }), 200);
    assert.equal(endedAtOf(stops, { id: 's2', cwd: 'C:\\repo\\.claude\\worktrees\\lane-ab' }), null);
    assert.equal(endedAtOf([], { id: 's1', cwd: null }), null);
  });

  it('words Stop now for the session: stop at once and end the turn', () => {
    assert.match(STOP_NOW, /Stop now/);
    assert.match(STOP_NOW, /end your turn/);
  });
});

describe('remoteLinkOf', () => {
  it('reads the Remote Control link from the app\'s session record: its newest bridge session', () => {
    assert.equal(remoteLinkOf({ bridgeSessionIds: ['session_01Old', 'session_01D7VSLCnQpmX45bMfUkX9ny'] }), 'https://claude.ai/code/session_01D7VSLCnQpmX45bMfUkX9ny');
  });
  it('has none without Remote Control, or with an id that isn\'t one', () => {
    assert.equal(remoteLinkOf({ bridgeSessionIds: [] }), null);
    assert.equal(remoteLinkOf({}), null);
    assert.equal(remoteLinkOf(null), null);
    assert.equal(remoteLinkOf({ bridgeSessionIds: ['../../evil?x=1'] }), null);
  });
});
