// The round trip for lock-screen notifications: a phone subscribes through the
// real Project Manager, a session's hook makes a bell record, and a stand-in
// push service on this PC receives the push and decrypts it as the phone would.
import { createServer } from 'node:http';
import { createECDH, createPublicKey, verify } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { SESSION, startBoard, waitFor } from './lanes-board-harness.mjs';
import { decryptPayload } from './lanes-board-push-receiver.mjs';

const ASK = { hook_event_name: 'PermissionRequest', tool_name: 'AskUserQuestion',
  tool_input: { questions: [{ question: 'Which camera?', options: [{ label: 'Close' }, { label: 'Far' }] }] } };
const unb64u = (s) => Buffer.from(s, 'base64url');

describe('the round trip: lock-screen notifications', () => {
  let board, service, received, status;
  // The phone's keys, made as a browser makes them.
  const phone = createECDH('prime256v1');
  phone.generateKeys();
  const auth = Buffer.from('0123456789abcdef').toString('base64url');
  let endpoint;

  before(async () => {
    service = createServer((req, res) => {
      const chunks = [];
      req.on('data', (c) => chunks.push(c));
      req.on('end', () => {
        received.push({ path: req.url, headers: req.headers, body: Buffer.concat(chunks) });
        res.writeHead(status); res.end();
      });
    });
    await new Promise((r) => service.listen(0, '127.0.0.1', r));
    endpoint = `http://127.0.0.1:${service.address().port}/push/phone-1`;
    board = await startBoard({ env: { LANES_PUSH_INSECURE: '1' } });
  });
  after(async () => { await board?.stop(); await new Promise((r) => service?.close(r)); });
  beforeEach(async () => {
    received = [];
    status = 201;
    await board.post('/relay/away', { on: false });
    await board.post('/bell/read', { all: true });
  });
  const subscribe = () => board.post('/push/subscribe', { subscription: { endpoint, keys: { p256dh: phone.getPublicKey().toString('base64url'), auth } } },
    { origin: `http://localhost:${board.port}` });

  it('keeps one key pair in the state folder and counts subscriptions', async () => {
    const first = (await board.get('/push')).body;
    assert.match(first.publicKey, /^[\w-]{87}$/);
    assert.equal((await board.get('/push')).body.publicKey, first.publicKey);
    assertMatches(await subscribe(), { status: 200, body: { ok: true, subscriptions: 1 } });
    assertMatches(await subscribe(), { status: 200, body: { subscriptions: 1 } });
    assert.equal(JSON.parse(readFileSync(path.join(board.state, 'push-keys.json'), 'utf8')).publicKey, first.publicKey);
    assert.equal(JSON.parse(readFileSync(path.join(board.state, 'push-subscriptions.json'), 'utf8')).subscriptions[0].endpoint, endpoint);
    assert.equal((await board.post('/push/subscribe', { subscription: { endpoint: 'nope', keys: {} } })).status, 400);
  });

  it('pushes that a session waits on questions while Away is on, encrypted for the phone and signed', async () => {
    await subscribe();
    const { publicKey } = (await board.get('/push')).body;
    await board.post('/relay/away', { on: true });
    assert.equal(await board.hook(ASK).done, null, 'the question stays in the app');
    const [push] = await waitFor(() => (received.length ? received : null), 12000, 'a push');
    assert.equal(push.path, '/push/phone-1');
    assert.equal(push.headers['content-encoding'], 'aes128gcm');
    const m = push.headers.authorization.match(/^vapid t=([\w-]+)\.([\w-]+)\.([\w-]+), k=([\w-]+)$/);
    assert.equal(m[4], publicKey);
    const pub = unb64u(publicKey);
    const key = createPublicKey({ format: 'jwk', key: { kty: 'EC', crv: 'P-256', x: pub.subarray(1, 33).toString('base64url'), y: pub.subarray(33).toString('base64url') } });
    assert.ok(verify('sha256', Buffer.from(`${m[1]}.${m[2]}`), { key, dsaEncoding: 'ieee-p1363' }, unb64u(m[3])), 'the VAPID signature checks out');
    const message = JSON.parse(decryptPayload(push.body, { uaPrivate: phone.getPrivateKey().toString('base64url'), auth }));
    assertMatches(message, { title: 'Fixture session is waiting on you to answer questions in the app', body: 'Which camera?', tag: `session:${SESSION}` });
    const url = new URL(message.url, 'https://pc');
    assert.equal(url.searchParams.get('go'), 'questions');
    assert.equal(url.searchParams.get('session'), SESSION);
    await new Promise((r) => setTimeout(r, 6000));
    assert.equal(received.length, 1, 'one push per record');
  });

  it('pushes nothing while Away is off', async () => {
    await subscribe();
    await board.hook({ hook_event_name: 'Stop', last_assistant_message: 'Task 11 is built.' }).done;
    await waitFor(async () => (await board.get('/bell')).body.records.some((r) => !r.read && r.kind === 'turn'), 8000, 'the bell record');
    await new Promise((r) => setTimeout(r, 500));
    assert.equal(received.length, 0);
  });

  it('drops a subscription the push service says is gone', async () => {
    await subscribe();
    status = 410;
    await board.post('/relay/away', { on: true });
    await board.hook(ASK).done;
    await waitFor(() => (received.length ? received : null), 12000, 'a push');
    await waitFor(async () => (await board.get('/push')).body.subscriptions === 0, 8000, 'the subscription dropped');
  });

  it('forgets a subscription the phone turns off', async () => {
    await subscribe();
    assertMatches(await board.post('/push/unsubscribe', { endpoint }), { status: 200, body: { subscriptions: 0 } });
  });
});
