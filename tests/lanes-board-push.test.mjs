// Lock-screen push (tools/lanes-board/push.mjs): RFC 8291's worked example,
// the VAPID token, and which records go out and how they read.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createPublicKey, verify } from 'node:crypto';
import { decryptPayload } from './lanes-board-push-receiver.mjs';
import { cleanSubscription, encryptPayload, pushMessage, pushRequest, toPush, vapidAuth, vapidKeys } from '../tools/lanes-board/push.mjs';

const unb64u = (s) => Buffer.from(s, 'base64url');

// RFC 8291, section 5 and appendix A.
const RFC = {
  plaintext: 'When I grow up, I want to be a watermelon',
  auth: 'BTBZMqHH6r4Tts7J_aSIgg',
  uaPublic: 'BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4',
  uaPrivate: 'q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94',
  asPrivate: 'yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw',
  salt: 'DGv6ra1nlYgDCS1FRnbzlw',
  body: 'DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27ml'
    + 'mlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPT'
    + 'pK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN',
};

describe('encryptPayload', () => {
  it("reproduces RFC 8291's worked example byte for byte", () => {
    const body = encryptPayload(RFC.plaintext, { p256dh: RFC.uaPublic, auth: RFC.auth }, { salt: unb64u(RFC.salt), asPrivate: RFC.asPrivate });
    assert.equal(body.toString('base64url'), RFC.body);
  });

  it('makes a fresh salt and key each time, which the phone decrypts', () => {
    const keys = { p256dh: RFC.uaPublic, auth: RFC.auth };
    const a = encryptPayload('hello', keys);
    const b = encryptPayload('hello', keys);
    assert.notEqual(a.toString('hex'), b.toString('hex'));
    assert.equal(decryptPayload(a, { uaPrivate: RFC.uaPrivate, auth: RFC.auth }), 'hello');
  });

  it('refuses bad keys and a message too long for one record', () => {
    assert.throws(() => encryptPayload('x', { p256dh: 'AAAA', auth: RFC.auth }), /key/);
    assert.throws(() => encryptPayload('x', { p256dh: RFC.uaPublic, auth: 'AAAA' }), /secret/);
    assert.throws(() => encryptPayload('x'.repeat(5000), { p256dh: RFC.uaPublic, auth: RFC.auth }), /too long/);
  });
});

describe('vapidAuth', () => {
  it('signs an ES256 token for the push service origin, an hour long, naming the contact', () => {
    const keys = vapidKeys();
    const now = Date.UTC(2026, 9, 5, 12);
    const header = vapidAuth('https://web.push.apple.com/QXBwbGU/abc', keys, { sub: 'https://pc.tail.ts.net', now });
    const m = header.match(/^vapid t=([\w-]+)\.([\w-]+)\.([\w-]+), k=([\w-]+)$/);
    assert.ok(m, header);
    assert.equal(m[4], keys.publicKey);
    assert.deepEqual(JSON.parse(unb64u(m[1])), { typ: 'JWT', alg: 'ES256' });
    assert.deepEqual(JSON.parse(unb64u(m[2])), { aud: 'https://web.push.apple.com', exp: now / 1000 + 3600, sub: 'https://pc.tail.ts.net' });
    const pub = unb64u(keys.publicKey);
    const key = createPublicKey({ format: 'jwk', key: { kty: 'EC', crv: 'P-256', x: pub.subarray(1, 33).toString('base64url'), y: pub.subarray(33).toString('base64url') } });
    assert.ok(verify('sha256', Buffer.from(`${m[1]}.${m[2]}`), { key, dsaEncoding: 'ieee-p1363' }, unb64u(m[3])));
  });
});

describe('pushRequest', () => {
  it('posts the encrypted JSON with the aes128gcm headers', () => {
    const r = pushRequest({ endpoint: 'https://push.example.net/x', keys: { p256dh: RFC.uaPublic, auth: RFC.auth } },
      { title: 'Hi' }, vapidKeys(), { sub: 'https://pc.tail.ts.net' });
    assert.equal(r.url, 'https://push.example.net/x');
    assert.equal(r.headers['content-encoding'], 'aes128gcm');
    assert.ok(Number(r.headers.ttl) > 0);
    assert.match(r.headers.authorization, /^vapid t=/);
    assert.deepEqual(JSON.parse(decryptPayload(r.body, { uaPrivate: RFC.uaPrivate, auth: RFC.auth })), { title: 'Hi' });
  });
});

describe('cleanSubscription', () => {
  const keys = { p256dh: RFC.uaPublic, auth: RFC.auth };
  it('keeps an https endpoint with good keys, and nothing else from the page', () => {
    assert.deepEqual(cleanSubscription({ endpoint: 'https://web.push.apple.com/abc', keys, extra: 1 }), { endpoint: 'https://web.push.apple.com/abc', keys });
  });
  it('refuses http (unless a test allows it), a bad URL and bad keys', () => {
    assert.equal(cleanSubscription({ endpoint: 'http://127.0.0.1:9/x', keys }), null);
    assert.ok(cleanSubscription({ endpoint: 'http://127.0.0.1:9/x', keys }, { insecure: true }));
    assert.equal(cleanSubscription({ endpoint: 'not a url', keys }), null);
    assert.equal(cleanSubscription({ endpoint: 'https://a.example/x', keys: { p256dh: 'AAAA', auth: RFC.auth } }), null);
    assert.equal(cleanSubscription(null), null);
  });
});

describe('the rules', () => {
  const S = '11111111-2222-4333-8444-555555555555';
  const rec = { id: 'event:5:0', kind: 'asked', session: S, text: 'Lane 7 is waiting on you to answer questions in the app', detail: 'Which camera?', read: false,
    target: { tab: 'sessions', session: S } };

  it('pushes only while Away is on, and only unread records', () => {
    assert.deepEqual(toPush([rec, { ...rec, id: 'x', read: true }], { on: true }), [rec]);
    assert.deepEqual(toPush([rec], { on: false }), []);
    assert.deepEqual(toPush([rec], null), []);
  });

  it('says who needs what in one line, tags by session and opens the record\'s session', () => {
    const m = pushMessage(rec);
    assert.equal(m.title, 'Lane 7 is waiting on you to answer questions in the app');
    assert.equal(m.body, 'Which camera?');
    assert.equal(m.tag, `session:${S}`);
    const u = new URL(m.url, 'https://pc');
    assert.equal(u.pathname, '/m');
    assert.deepEqual(Object.fromEntries(u.searchParams), { bell: 'event:5:0', go: 'sessions', session: S });
    const old = pushMessage({ ...rec, id: 'held:q-1', target: { tab: 'questions', item: 'q-1', session: S } });
    assert.deepEqual(Object.fromEntries(new URL(old.url, 'https://pc').searchParams), { bell: 'held:q-1', go: 'sessions', session: S }, 'an older record too');
    const turn = pushMessage({ ...rec, id: 'event:9-0', kind: 'turn', target: { tab: 'sessions', session: S } });
    assert.equal(turn.tag, `session:${S}`);
    assert.deepEqual(Object.fromEntries(new URL(turn.url, 'https://pc').searchParams), { bell: 'event:9-0', go: 'sessions', session: S });
    const ready = pushMessage({ ...rec, id: 'event:9:10', kind: 'merge', target: { tab: 'sessions', session: S } });
    assert.deepEqual(Object.fromEntries(new URL(ready.url, 'https://pc').searchParams), { bell: 'event:9:10', go: 'sessions', session: S });
    const vis = pushMessage({ ...rec, id: `visuals:${S}:1-0`, kind: 'visuals', target: { tab: 'sessions', session: S, visuals: true } });
    assert.deepEqual(Object.fromEntries(new URL(vis.url, 'https://pc').searchParams), { bell: `visuals:${S}:1-0`, go: 'sessions', visuals: '1', session: S });
  });
});
