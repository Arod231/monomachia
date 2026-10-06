// The bell's rules (tools/lanes-board/bell.mjs): what makes a notification,
// when it's read, and how long it's kept.
import { appendFileSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ASKED_GRACE_MS, BELL_KEEP_MS, EVENTS_KEEP_MS, bellUpdate, bellView, eventsDue, markRead } from '../tools/lanes-board/bell.mjs';
import { bellApi } from '../tools/lanes-board/bell-api.mjs';

const S1 = '11111111-2222-4333-8444-555555555555';
const S2 = '22222222-2222-4333-8444-555555555555';
const titles = { [S1]: 'Lane <one>', [S2]: 'Lane two' };
const titleOf = (id) => titles[id] ?? '(untitled)';
const update = (state, { events = [], posts = [], now = 5000 } = {}) => bellUpdate(state, { events, posts, now, titleOf });
const turn = (time, session, last, offset) => ({ time, kind: 'turn-finished', session, last, offset });

describe('bellUpdate', () => {
  it('makes one record per event, and none twice', () => {
    const events = [turn(1000, S1, 'Task 6 is done.\nShall I go on?', 0), turn(1100, S2, 'All done.', 80)];
    const s = update(null, { events });
    assert.deepEqual(s.records.map((r) => [r.kind, r.text, r.detail, r.read]), [
      ['turn', 'Lane <one> finished its turn', 'Shall I go on?', false],
      ['turn', 'Lane two finished its turn', 'All done.', false],
    ]);
    assert.equal(update(s, { events }), s);
  });

  it('marks read the records of items an older relay hook held, which nothing holds any more', () => {
    const old = { records: [{ id: 'held:q-1', item: 'q-1', kind: 'question', session: S1, time: 1000, read: false, target: { tab: 'questions', item: 'q-1', session: S1 } }] };
    assert.deepEqual(update(old).records.map((r) => [r.id, r.read]), [['held:q-1', true]]);
  });

  it('marks a question asked in the app read once its session no longer has it open, after a short grace', () => {
    const asked = (session, time, offset) => ({ time, kind: 'asked-in-app', session, questions: ['Which?'], offset });
    const s = bellUpdate(null, { events: [asked(S1, 1000, 0), asked(S2, 1000, 50)], posts: [], now: 2000, titleOf, asking: new Set([S1, S2]) });
    const readOf = (st) => st.records.map((r) => [r.session, r.read]);
    assert.deepEqual(readOf(bellUpdate(s, { now: 60_000, titleOf, asking: new Set([S1, S2]) })), [[S1, false], [S2, false]], 'both still open');
    assert.deepEqual(readOf(bellUpdate(s, { now: 60_000, titleOf, asking: new Set([S2]) })), [[S1, true], [S2, false]], "S1's was answered");
    assert.deepEqual(readOf(bellUpdate(s, { now: 1000 + ASKED_GRACE_MS - 1, titleOf, asking: new Set() })), [[S1, false], [S2, false]], 'inside the grace');
    assert.equal(bellUpdate(s, { now: 60_000, titleOf, asking: null }), s, 'unknown: nothing changes');
    const turn = bellUpdate(null, { events: [{ time: 1000, kind: 'turn-finished', session: S1, offset: 0 }], now: 2000, titleOf });
    assert.deepEqual(readOf(bellUpdate(turn, { now: 60_000, titleOf, asking: new Set() })), readOf(turn), 'other kinds untouched');
  });

  it('records what the hook noted: questions asked in the app and turns finished', () => {
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
    assert.deepEqual(s.records[0].target, { tab: 'sessions', session: S1 });
    assert.deepEqual(s.records[1].target, { tab: 'sessions', session: S2 });
  });

  it('tells of a pull request turning ready to merge on GitHub, opening its session', () => {
    const s = update(null, { events: [{ time: 4000, kind: 'pr-ready', session: S1, pr: { number: 51, title: 'PM <11-14>', base: 'tools/pm' } }] });
    assert.deepEqual(s.records.map((r) => [r.kind, r.text, r.detail]), [['merge', 'Lane <one>: pull request #51 is ready to merge on GitHub', 'PM <11-14> into tools/pm']]);
    assert.deepEqual(s.records[0].target, { tab: 'sessions', session: S1 });
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
    s = update(s, { events: [turn(4000, S1, 'Third.', 300)] });
    assert.deepEqual(s.records.filter((r) => r.session === S1).map((r) => [r.detail, r.read]), [['Second.', true], ['Third.', false]]);
  });

  it('tells of new visuals once per session per minute, counting what each minute brought', () => {
    const p = (id, time, extra = {}) => ({ session: S1, id, time, kind: 'still', caption: `Shot ${id}`, ...extra });
    let s = update(null, { posts: [p('a', 1000)], now: 2000 });
    assert.deepEqual(s.records.map((r) => [r.id, r.kind, r.text, r.detail]), [['visuals:' + S1 + ':0', 'visuals', 'Lane <one> posted a shot', 'Shot a']]);
    assert.deepEqual(s.records[0].target, { tab: 'sessions', session: S1, visuals: true });
    s = markRead(s, 'all');
    s = update(s, { posts: [p('a', 1000), p('b', 30_000, { kind: 'clip' }), p('c', 61_500), p('d', 1500, { session: S2 })], now: 70_000 });
    assert.deepEqual(s.records.map((r) => [r.id.split(':').at(-1), r.session, r.text, r.detail, r.read]), [
      ['0', S1, 'Lane <one> posted 2 visuals', 'Shot b', true],
      ['0', S2, 'Lane two posted a shot', 'Shot d', false],
      ['1', S1, 'Lane <one> posted a shot', 'Shot c', false],
    ]);
    assert.equal(update(s, { posts: [p('a', 1000), p('b', 30_000, { kind: 'clip' }), p('c', 61_500), p('d', 1500, { session: S2 })], now: 70_000 }), s);
  });

  it('never tells of the same visuals twice, as older posts age out or the list drops their record', () => {
    const p = (id, time) => ({ session: S1, id, time, kind: 'still', caption: id });
    const posts = [p('a', 0), p('b', 30_000), p('c', 70_000)];
    let s = markRead(update(null, { posts, now: 80_000 }), 'all');
    const later = BELL_KEEP_MS + 10_000; // a is past the 7 days; b and c are not
    s = update(s, { posts: posts.slice(1), now: later });
    assert.deepEqual(s.records.filter((r) => !r.read).map((r) => r.id), []);
    const dropped = { ...s, records: s.records.filter((r) => !r.id.endsWith(':1')) };
    assert.equal(update(dropped, { posts: posts.slice(1), now: later }).records.some((r) => r.id.endsWith(':1')), false);
  });

  it('drops records older than 7 days', () => {
    const s = update(null, { events: [{ time: 1000, kind: 'turn-finished', session: S1, last: 'Old.' }] });
    assert.equal(update(s, { now: 1000 + BELL_KEEP_MS - 1 }).records.length, 1);
    assert.equal(update(s, { now: 1000 + BELL_KEEP_MS + 1 }).records.length, 0);
    assert.equal(BELL_KEEP_MS, 7 * 24 * 60 * 60 * 1000);
  });

  it('says when nothing changed, so the file is left alone', () => {
    const s = update(null, { events: [turn(1000, S1, 'Done.', 0)] });
    assert.equal(update(s), s);
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
  const api = () => bellApi({ file: path.join(dir, 'notifications.json'), relay: dir, titlesOf: async () => new Map() });
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

  it('asks which sessions are asking in the app on each look, and reads the answered ones', async () => {
    let asking = [S1];
    const a = bellApi({ file: path.join(dir, 'notifications.json'), relay: dir, titlesOf: async () => new Map(), asking: async () => asking });
    writeFileSync(path.join(dir, 'events.jsonl'), line({ time: Date.now() - 60_000, kind: 'asked-in-app', session: S1, questions: ['A?'] }));
    assert.equal((await look(a)).unread, 1);
    asking = [];
    assert.equal((await look(a)).unread, 0);
  });
});

describe('markRead and bellView', () => {
  const s = update(null, { events: [turn(1000, S1, 'One.', 0), turn(2000, S2, 'Two.', 50)] });
  const [first, second] = s.records.map((r) => r.id);
  it('marks some or all records read', () => {
    assert.deepEqual(markRead(s, [first]).records.map((r) => r.read), [true, false]);
    assert.deepEqual(markRead(s, 'all').records.map((r) => r.read), [true, true]);
    assert.equal(markRead(s, ['nope']), s);
  });
  it('shows the unread count and the records newest first', () => {
    const v = bellView(markRead(s, [first]));
    assert.equal(v.unread, 1);
    assert.deepEqual(v.records.map((r) => r.id), [second, first]);
    assert.deepEqual(bellView(null), { unread: 0, records: [] });
  });
});
