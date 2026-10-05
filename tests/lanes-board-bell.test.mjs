// The bell's rules (tools/lanes-board/bell.mjs): what makes a notification,
// when it's read, and how long it's kept.
import { appendFileSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BELL_KEEP_MS, EVENTS_KEEP_MS, bellUpdate, bellView, eventsDue, markRead } from '../tools/lanes-board/bell.mjs';
import { bellApi } from '../tools/lanes-board/bell-api.mjs';

const S1 = '11111111-2222-4333-8444-555555555555';
const S2 = '22222222-2222-4333-8444-555555555555';
const titles = { [S1]: 'Lane <one>', [S2]: 'Lane two' };
const titleOf = (id) => titles[id] ?? '(untitled)';
const held = (id, kind, extra = {}) => ({ id, kind, session: S1, time: 1000, ...extra });
const update = (state, { pending = [], events = [], now = 5000 } = {}) => bellUpdate(state, { pending, events, now, titleOf });

describe('bellUpdate', () => {
  it('makes one record per held item, saying who needs what, and none twice', () => {
    const pending = [
      held('q-1', 'question', { input: { questions: [{ question: 'Which camera?' }] } }),
      held('p-1', 'permission', { tool: 'Bash', input: { command: 'npm test' } }),
      held('l-1', 'plan', { tool: 'ExitPlanMode' }),
      held('t-1', 'stop', { session: S2, last: 'Task 6 is done.\nShall I go on?' }),
    ];
    const s = update(null, { pending });
    assert.deepEqual(s.records.map((r) => [r.id, r.kind, r.text, r.detail, r.read]), [
      ['held:q-1', 'question', 'Lane <one> asks you a question', 'Which camera?', false],
      ['held:p-1', 'permission', 'Lane <one> wants to use Bash', 'npm test', false],
      ['held:l-1', 'plan', 'Lane <one> asks you to approve its plan', '', false],
      ['held:t-1', 'turn', 'Lane two finished its turn', 'Shall I go on?', false],
    ]);
    assert.deepEqual(s.records[0].target, { tab: 'questions', item: 'q-1', session: S1 });
    assert.equal(update(s, { pending }).records.length, 4);
  });

  it('marks a held item\'s record read once it is answered, handed back or timed out', () => {
    const s = update(null, { pending: [held('q-1', 'question'), held('p-1', 'permission', { tool: 'Bash' })] });
    const after = update(s, { pending: [held('p-1', 'permission', { tool: 'Bash' })] });
    assert.deepEqual(after.records.map((r) => [r.id, r.read]), [['held:q-1', true], ['held:p-1', false]]);
  });

  it('records what the hook noted: questions asked in the app and turns finished while Away was off', () => {
    const events = [
      { time: 2000, kind: 'asked-in-app', session: S1, questions: ['Which arena?'] },
      { time: 3000, kind: 'turn-finished', session: S2, last: 'All done.' },
      { time: 3500, kind: 'something-new', session: S2 },
    ];
    const s = update(null, { events });
    assert.deepEqual(s.records.map((r) => [r.kind, r.text, r.detail, r.time]), [
      ['asked', 'Lane <one> is waiting on you to answer questions in the app', 'Which arena?', 2000],
      ['turn', 'Lane two finished its turn', 'All done.', 3000],
    ]);
    assert.deepEqual(s.records[0].target, { tab: 'questions', session: S1 });
    assert.deepEqual(s.records[1].target, { tab: 'sessions', session: S2 });
  });

  it('tells of a pull request turning ready to merge, opening its session\'s merge', () => {
    const s = update(null, { events: [{ time: 4000, kind: 'pr-ready', session: S1, pr: { number: 51, title: 'PM <11-14>', base: 'tools/pm' } }] });
    assert.deepEqual(s.records.map((r) => [r.kind, r.text, r.detail]), [['merge', 'Lane <one>: pull request #51 is ready to merge', 'PM <11-14> into tools/pm']]);
    assert.deepEqual(s.records[0].target, { tab: 'sessions', session: S1, merge: 51 });
  });

  it('tells apart events from the same millisecond read in different looks, by where each sits in the file', () => {
    let s = update(null, { events: [{ time: 2000, kind: 'asked-in-app', session: S1, questions: ['A?'], offset: 0 }] });
    s = update(s, { events: [{ time: 2000, kind: 'asked-in-app', session: S2, questions: ['B?'], offset: 120 }] });
    assert.deepEqual(s.records.map((r) => r.detail), ['A?', 'B?']);
    assert.notEqual(s.records[0].id, s.records[1].id);
  });

  it('keeps one unread finished turn per session: a newer one replaces the older unread one', () => {
    let s = update(null, { events: [{ time: 2000, kind: 'turn-finished', session: S1, last: 'First.' }] });
    s = update(s, { events: [{ time: 3000, kind: 'turn-finished', session: S1, last: 'Second.' }, { time: 3100, kind: 'turn-finished', session: S2, last: 'Other.' }] });
    assert.deepEqual(s.records.map((r) => [r.session, r.detail]), [[S1, 'Second.'], [S2, 'Other.']]);
    s = markRead(s, [s.records[0].id]);
    s = update(s, { pending: [held('t-9', 'stop', { time: 4000, last: 'Third.' })] });
    assert.deepEqual(s.records.filter((r) => r.session === S1).map((r) => [r.detail, r.read]), [['Second.', true], ['Third.', false]]);
  });

  it('drops records older than 7 days', () => {
    const s = update(null, { events: [{ time: 1000, kind: 'turn-finished', session: S1, last: 'Old.' }] });
    assert.equal(update(s, { now: 1000 + BELL_KEEP_MS - 1 }).records.length, 1);
    assert.equal(update(s, { now: 1000 + BELL_KEEP_MS + 1 }).records.length, 0);
    assert.equal(BELL_KEEP_MS, 7 * 24 * 60 * 60 * 1000);
  });

  it('says when nothing changed, so the file is left alone', () => {
    const s = update(null, { pending: [held('q-1', 'question')] });
    assert.equal(update(s, { pending: [held('q-1', 'question')] }), s);
  });
});

describe('eventsDue', () => {
  it('starts events.jsonl afresh once its oldest line is over 30 days old', () => {
    const now = 100 * 24 * 60 * 60 * 1000;
    assert.equal(eventsDue(null, now), false);
    assert.equal(eventsDue(now - EVENTS_KEEP_MS + 1000, now), false);
    assert.equal(eventsDue(now - EVENTS_KEEP_MS - 1000, now), true);
    assert.equal(EVENTS_KEEP_MS, 30 * 24 * 60 * 60 * 1000);
  });
});

describe('bellApi', () => {
  let dir;
  beforeEach(() => { dir = mkdtempSync(path.join(os.tmpdir(), 'pm-bell-')); });
  afterEach(() => rmSync(dir, { recursive: true, force: true }));
  const api = () => bellApi({ file: path.join(dir, 'notifications.json'), relay: dir, held: async () => [], titlesOf: async () => new Map() });
  const line = (o) => `${JSON.stringify(o)}\n`;
  const look = (a) => a.get(new URL('http://board/bell'));

  it('reads each event once, however many looks, and two in the same millisecond both count', async () => {
    const a = api();
    const t = Date.now();
    writeFileSync(path.join(dir, 'events.jsonl'), line({ time: t, kind: 'asked-in-app', session: S1, questions: ['A?'] }));
    assert.equal((await look(a)).records.length, 1);
    appendFileSync(path.join(dir, 'events.jsonl'), line({ time: t, kind: 'asked-in-app', session: S2, questions: ['B?'] }));
    assert.equal((await look(a)).records.length, 2);
    assert.equal((await look(a)).records.length, 2);
  });

  it('moves an events.jsonl whose oldest line is over 30 days old aside, once it has read it', async () => {
    const old = Date.now() - EVENTS_KEEP_MS - 60000;
    writeFileSync(path.join(dir, 'events.jsonl'), line({ time: old, kind: 'turn-finished', session: S1, last: 'Old.' })
      + line({ time: Date.now(), kind: 'turn-finished', session: S2, last: 'New.' }));
    const a = api();
    assert.deepEqual((await look(a)).records.map((r) => r.detail), ['New.']);
    assert.deepEqual(readdirSync(dir).sort(), ['events.jsonl.old', 'notifications.json']);
    appendFileSync(path.join(dir, 'events.jsonl'), line({ time: Date.now() + 1, kind: 'asked-in-app', session: S1, questions: ['After?'] }));
    assert.deepEqual((await look(a)).records.map((r) => r.detail), ['After?', 'New.']);
  });
});

describe('markRead and bellView', () => {
  const s = update(null, { pending: [held('q-1', 'question', { time: 1000 }), held('p-1', 'permission', { tool: 'Bash', time: 2000 })] });
  it('marks some or all records read', () => {
    assert.deepEqual(markRead(s, ['held:q-1']).records.map((r) => r.read), [true, false]);
    assert.deepEqual(markRead(s, 'all').records.map((r) => r.read), [true, true]);
    assert.equal(markRead(s, ['nope']), s);
  });
  it('shows the unread count and the records newest first', () => {
    const v = bellView(markRead(s, ['held:q-1']));
    assert.equal(v.unread, 1);
    assert.deepEqual(v.records.map((r) => r.id), ['held:p-1', 'held:q-1']);
    assert.deepEqual(bellView(null), { unread: 0, records: [] });
  });
});
