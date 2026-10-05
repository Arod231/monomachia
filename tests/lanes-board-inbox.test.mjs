// A session's inbox in the relay folder (tools/lanes-board/inbox.mjs), shared
// by the board, which writes it, and both hooks, which take from it.
import { mkdirSync, mkdtempSync, readdirSync, rmSync, utimesSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BROKEN_AFTER_MS, inboxDir, postToInbox, takeFromInbox, writeJsonAtomic } from '../tools/lanes-board/inbox.mjs';

const ID = '11111111-2222-4333-8444-555555555555';

describe('the inbox', () => {
  let relay;
  beforeEach(() => { relay = mkdtempSync(path.join(os.tmpdir(), 'pm-inbox-')); });
  afterEach(() => rmSync(relay, { recursive: true, force: true }));
  const names = () => readdirSync(inboxDir(relay, ID)).sort();

  it('keeps messages oldest first, and takes one or all of them', () => {
    for (const text of ['One', 'Two', 'Three']) postToInbox(relay, ID, text);
    assert.equal(names().length, 3);
    assert.deepEqual(takeFromInbox(relay, ID), ['One']);
    assert.deepEqual(takeFromInbox(relay, ID, { all: true }), ['Two', 'Three']);
    assert.deepEqual(names(), []);
    assert.deepEqual(takeFromInbox(relay, ID, { all: true }), []);
    assert.deepEqual(takeFromInbox(relay, '22222222-2222-4333-8444-555555555555'), []);
  });

  it('never drops a message that is still being written, nor skips past it', () => {
    postToInbox(relay, ID, 'First');
    const [first] = names();
    // A half-written older file, as an in-place write would leave it.
    writeFileSync(path.join(inboxDir(relay, ID), '000000000000001-000000.json'), '{"text": "Ear');
    assert.deepEqual(takeFromInbox(relay, ID), []);
    assert.deepEqual(takeFromInbox(relay, ID, { all: true }), []);
    assert.equal(names().length, 2);
    writeFileSync(path.join(inboxDir(relay, ID), '000000000000001-000000.json'), '{"text": "Earliest"}');
    assert.deepEqual(takeFromInbox(relay, ID, { all: true }), ['Earliest', 'First']);
    assert.ok(!names().includes(first));
  });

  it('sets aside a file that stays unreadable, so the rest still arrive', () => {
    postToInbox(relay, ID, 'Later');
    const broken = path.join(inboxDir(relay, ID), '000000000000001-000000.json');
    writeFileSync(broken, 'not json');
    const old = new Date(Date.now() - BROKEN_AFTER_MS - 1000);
    utimesSync(broken, old, old);
    assert.deepEqual(takeFromInbox(relay, ID, { all: true }), ['Later']);
    assert.deepEqual(names(), ['000000000000001-000000.json.broken']);
  });

  it('writes whole files only: a temp file renamed over the target, never seen as a message', () => {
    const file = path.join(relay, 'x', 'y.json');
    writeJsonAtomic(file, { a: 1 });
    assert.deepEqual(readdirSync(path.dirname(file)), ['y.json']);
    mkdirSync(inboxDir(relay, ID), { recursive: true });
    writeFileSync(path.join(inboxDir(relay, ID), '000000000000009-000000.json.tmp-123'), '{"text":"half');
    assert.deepEqual(takeFromInbox(relay, ID, { all: true }), []);
  });

  it('refuses a session id that would name another folder', () => {
    assert.throws(() => postToInbox(relay, '../x', 'Hi'), /Bad session id/);
    assert.deepEqual(takeFromInbox(relay, '../x'), []);
  });
});
