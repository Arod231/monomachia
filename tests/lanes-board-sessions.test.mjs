// Tests for the lanes board's Graph and Sessions tabs: the graph layout
// (tools/lanes-board/graph.mjs), the transcript reader and relay answers
// (sessions.mjs), each session's context gauge (sessions.mjs), and the relay
// hook a session runs (relay-hook.mjs).

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
  PENDING_ID, QUESTION_ANSWER, SESSION_ID, autoCompactAt, awayOf, awaySwitch, contextTracker, contextWindowFor, downsample, heldOrphaned,
  parseTranscript, questionAnswers, relayAnswer, toolSummary,
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

describe('relay answers', () => {
  const questions = [{ question: 'One?', options: [] }, { question: 'Many?', multiSelect: true, options: [] }];

  it('answers AskUserQuestion with each question\'s label, several joined by commas', () => {
    assert.deepEqual(questionAnswers(questions, ['A', ['B', 'C']]), { 'One?': 'A', 'Many?': 'B, C' });
    assert.throws(() => questionAnswers(questions, ['A', []]), /No answer/);
    assert.throws(() => questionAnswers(questions, [['A', 'B'], ['C']]), /one answer/);
  });

  it('passes the question back with its answers, as the tool takes them', () => {
    const pending = { kind: 'question', input: { questions } };
    assert.equal(QUESTION_ANSWER, 'allow');
    assert.deepEqual(relayAnswer(pending, { picks: ['A', ['B']] }), {
      behavior: 'allow', updatedInput: { questions, answers: { 'One?': 'A', 'Many?': 'B' } },
    });
  });

  it('takes "Other" as the free text it is', () => {
    const pending = { kind: 'question', input: { questions } };
    assert.deepEqual(relayAnswer(pending, { picks: ['My own words', ['B', 'Also this']] }).updatedInput.answers,
      { 'One?': 'My own words', 'Many?': 'B, Also this' });
  });

  it('can answer by declining instead, carrying the answers as the reason (the fallback)', () => {
    const pending = { kind: 'question', input: { questions } };
    const out = relayAnswer(pending, { picks: ['A', ['B', 'C']] }, { questionAnswer: 'decline' });
    assert.equal(out.behavior, 'deny');
    assert.match(out.message, /^The owner answered from the Project Manager:/);
    assert.match(out.message, /One\? → A/);
    assert.match(out.message, /Many\? → B, C/);
  });

  it('sends a free-form reply to a question as a decline with the owner\'s words', () => {
    const out = relayAnswer({ kind: 'question', input: { questions } }, { reply: '  Ask me about the camera instead ' });
    assert.deepEqual(out, { behavior: 'deny',
      message: 'The owner answered from the Project Manager instead of picking an option:\n\nAsk me about the camera instead' });
  });

  it('allows (adding the suggested rule only when asked), denies with a reason, or hands back', () => {
    const sug = [{ type: 'addRules', rules: [{ toolName: 'Bash', ruleContent: 'ls:*' }] }];
    const pending = { kind: 'permission', suggestions: sug };
    assert.deepEqual(relayAnswer(pending, { behavior: 'allow' }), { behavior: 'allow' });
    assert.deepEqual(relayAnswer(pending, { behavior: 'allow', always: true }), { behavior: 'allow', updatedPermissions: sug });
    assert.match(relayAnswer(pending, { behavior: 'deny', message: 'not now' }).message, /not now$/);
    assert.deepEqual(relayAnswer(pending, { release: true }), { release: true });
    assert.deepEqual(relayAnswer({ kind: 'question', input: { questions } }, { release: true }), { release: true });
    assert.throws(() => relayAnswer(pending, {}));
  });

  it('takes a reply at a turn\'s end, but not an empty one', () => {
    assert.deepEqual(relayAnswer({ kind: 'stop' }, { reply: ' Go on ' }), { reply: 'Go on' });
    assert.throws(() => relayAnswer({ kind: 'stop' }, { reply: ' ' }));
  });

  it('checks ids before they name a file', () => {
    assert.equal(SESSION_ID.test('11111111-2222-4333-8444-555555555555'), true);
    assert.equal(SESSION_ID.test('../../etc'), false);
    assert.equal(PENDING_ID.test('muteg88c-076glmmy'), true);
    assert.equal(PENDING_ID.test('../x'), false);
  });
});

describe('heldOrphaned', () => {
  const p = { id: 'ab12-cd34', session: 's', transcript: 'C:/t/s.jsonl' };
  it('drops an item whose transcript was deleted', () => {
    assert.equal(heldOrphaned(p, { transcriptExists: false, hasRecord: true, sawRecord: true }), true);
    assert.equal(heldOrphaned(p, { transcriptExists: true, hasRecord: true, sawRecord: true }), false);
  });
  it('drops an item whose app record was deleted, once the board had seen it', () => {
    assert.equal(heldOrphaned(p, { transcriptExists: true, hasRecord: false, sawRecord: true }), true);
    assert.equal(heldOrphaned(p, { transcriptExists: true, hasRecord: false, sawRecord: false }), false);
  });
  it('keeps an item that names no transcript', () => {
    assert.equal(heldOrphaned({ ...p, transcript: null }, { transcriptExists: false, hasRecord: false, sawRecord: false }), false);
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
  // Runs the hook; when it writes a pending item, `answer` decides what the board does.
  const run = (input, answer = null, waitMs = 8000, relay = dir) => new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [HOOK], { env: { ...process.env, LANES_RELAY: relay, LANES_RELAY_WAIT_MS: String(waitMs) } });
    let out = '';
    child.stdout.on('data', (c) => { out += c; });
    child.on('error', reject);
    let seen = null;
    const timer = setInterval(() => {
      const p = path.join(dir, 'pending');
      const names = existsSync(p) ? readdirSync(p) : [];
      if (!seen && names.length) {
        seen = JSON.parse(readFileSync(path.join(p, names[0]), 'utf8'));
        if (answer) answer(seen);
      }
    }, 50);
    child.on('close', () => { clearInterval(timer); resolve({ out, pending: seen }); });
    child.stdin.end(JSON.stringify({ session_id: ID, cwd: 'C:/repo', ...input }));
  });
  const reply = (p, body) => {
    mkdirSync(path.join(dir, 'answers'), { recursive: true });
    writeFileSync(path.join(dir, 'answers', `${p.id}.json`), JSON.stringify(body));
  };
  const events = () => (existsSync(path.join(dir, 'events.jsonl'))
    ? readFileSync(path.join(dir, 'events.jsonl'), 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)) : []);
  const ASK = { hook_event_name: 'PermissionRequest', tool_name: 'AskUserQuestion', tool_input: { questions: [{ question: 'Which?', options: [{ label: 'A' }] }] } };

  it('does nothing with no relay folder at all', async () => {
    const r = await run(ASK, null, 8000, path.join(dir, 'missing'));
    assert.equal(r.out, '');
    assert.equal(existsSync(path.join(dir, 'missing')), false);
  });

  it('leaves everything to the app while Away is off, noting a question asked in the app', async () => {
    assert.equal((await run({ hook_event_name: 'PermissionRequest', tool_name: 'Bash' })).out, '');
    setAway(false);
    const asked = await run(ASK);
    assert.equal(asked.out, '');
    assert.equal(asked.pending, null);
    assert.equal((await run({ hook_event_name: 'Stop' })).out, '');
    const ev = events();
    assert.equal(ev.length, 1);
    assertMatches(ev[0], { kind: 'asked-in-app', session: ID, cwd: 'C:/repo', questions: ['Which?'] });
    assert.equal(typeof ev[0].time, 'number');
  });

  it('hands a permission prompt to the board while Away is on and returns its decision', async () => {
    setAway();
    const { out, pending } = await run({ hook_event_name: 'PermissionRequest', tool_name: 'Bash', tool_input: { command: 'ls' } },
      (p) => reply(p, { behavior: 'deny', message: 'no' }));
    assertMatches(pending, { kind: 'permission', tool: 'Bash', session: ID, input: { command: 'ls' } });
    assert.equal(PENDING_ID.test(pending.id), true);
    assert.deepEqual(JSON.parse(out), { hookSpecificOutput: { hookEventName: 'PermissionRequest', decision: { behavior: 'deny', message: 'no' } } });
    assert.deepEqual(readdirSync(path.join(dir, 'pending')), []);
  });

  it('answers a question with the board\'s picks', async () => {
    setAway();
    const { out, pending } = await run(ASK, (p) => reply(p, relayAnswer(p, { picks: ['A'] })));
    assert.equal(pending.kind, 'question');
    assert.deepEqual(JSON.parse(out).hookSpecificOutput.decision, { behavior: 'allow', updatedInput: { ...ASK.tool_input, answers: { 'Which?': 'A' } } });
  });

  it('falls back to the app\'s dialog when handed back, when Away goes off, or out of time', async () => {
    setAway();
    assert.equal((await run({ hook_event_name: 'PermissionRequest', tool_name: 'Bash' }, (p) => reply(p, { release: true }))).out, '');
    assert.equal((await run({ hook_event_name: 'PermissionRequest', tool_name: 'Bash' }, () => setAway(false))).out, '');
    setAway();
    const late = await run({ hook_event_name: 'PermissionRequest', tool_name: 'Bash' }, null, 300);
    assert.equal(late.out, '');
    assert.notEqual(late.pending, null);
    assert.deepEqual(readdirSync(path.join(dir, 'pending')), []);
  });

  it('carries on with the owner\'s reply when a turn ends while Away is on', async () => {
    setAway();
    const { out, pending } = await run({ hook_event_name: 'Stop', last_assistant_message: 'Done.' }, (p) => reply(p, { reply: 'Now test it' }));
    assertMatches(pending, { kind: 'stop', last: 'Done.' });
    const decision = JSON.parse(out);
    assert.deepEqual(Object.keys(decision).sort(), ['decision', 'reason']);
    assert.equal(decision.decision, 'block');
    assert.match(decision.reason, /Now test it$/);
  });

  it('hands over a queued reply when a turn ends, without waiting, Away on or off', async () => {
    for (const on of [true, false]) {
      setAway(on);
      mkdirSync(path.join(dir, 'replies'), { recursive: true });
      writeFileSync(path.join(dir, 'replies', `${ID}.json`), JSON.stringify({ text: 'Queued words' }));
      const { out, pending } = await run({ hook_event_name: 'Stop' });
      assert.equal(pending, null);
      assert.match(JSON.parse(out).reason, /Queued words$/);
      assert.equal(existsSync(path.join(dir, 'replies', `${ID}.json`)), false);
    }
  });

  it('never blocks on a broken Away file', async () => {
    writeFileSync(path.join(dir, 'away.json'), '{not json');
    assert.equal((await run({ hook_event_name: 'Stop' })).out, '');
    assert.equal((await run(ASK)).out, '');
  });
});
