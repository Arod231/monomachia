// Lock-screen notifications (Web Push) with node:crypto alone: the payload
// encrypted for the phone (RFC 8291, aes128gcm), the request signed for the push
// service (VAPID, RFC 8292), and which bell records go out and how they read.
// No I/O: push-api.mjs keeps the keys and subscriptions in the state folder and
// sends. tests/lanes-board-push.test.mjs checks the encryption against RFC
// 8291's worked example.
import { createCipheriv, createECDH, createHmac, createPrivateKey, randomBytes, sign } from 'node:crypto';

const b64u = (buf) => Buffer.from(buf).toString('base64url');
const unb64u = (s) => Buffer.from(String(s ?? ''), 'base64url');
const hmac = (key, data) => createHmac('sha256', key).update(data).digest();
const RECORD_SIZE = 4096;

// A new VAPID key pair: { publicKey, privateKey }, base64url (uncompressed point, raw d).
export function vapidKeys() {
  const ecdh = createECDH('prime256v1');
  ecdh.generateKeys();
  return { publicKey: b64u(ecdh.getPublicKey()), privateKey: b64u(ecdh.getPrivateKey()) };
}

// The body of a push message: plaintext (a string or Buffer) encrypted for the
// subscription's keys ({ p256dh, auth }, base64url). salt and asPrivate (the
// sender's one-off key) are random unless given, as the RFC's example gives them.
export function encryptPayload(plaintext, { p256dh, auth }, { salt = randomBytes(16), asPrivate } = {}) {
  const uaPublic = unb64u(p256dh);
  const authSecret = unb64u(auth);
  if (uaPublic.length !== 65 || uaPublic[0] !== 4) throw new Error('Bad subscription key');
  if (authSecret.length !== 16) throw new Error('Bad subscription secret');
  const as = createECDH('prime256v1');
  if (asPrivate) as.setPrivateKey(unb64u(asPrivate)); else as.generateKeys();
  const asPublic = as.getPublicKey();
  const ecdhSecret = as.computeSecret(uaPublic);
  const prkKey = hmac(authSecret, ecdhSecret);
  const keyInfo = Buffer.concat([Buffer.from('WebPush: info\0'), uaPublic, asPublic]);
  const ikm = hmac(prkKey, Buffer.concat([keyInfo, Buffer.from([1])]));
  const prk = hmac(salt, ikm);
  const cek = hmac(prk, Buffer.from('Content-Encoding: aes128gcm\0\x01')).subarray(0, 16);
  const nonce = hmac(prk, Buffer.from('Content-Encoding: nonce\0\x01')).subarray(0, 12);
  // One record: the plaintext, then the last-record delimiter 0x02.
  const padded = Buffer.concat([Buffer.from(plaintext), Buffer.from([2])]);
  if (padded.length + 16 > RECORD_SIZE) throw new Error('Push message too long');
  const cipher = createCipheriv('aes-128-gcm', cek, nonce);
  const sealed = Buffer.concat([cipher.update(padded), cipher.final(), cipher.getAuthTag()]);
  const header = Buffer.alloc(16 + 4 + 1);
  Buffer.from(salt).copy(header, 0);
  header.writeUInt32BE(RECORD_SIZE, 16);
  header[20] = asPublic.length;
  return Buffer.concat([header, asPublic, sealed]);
}

// The Authorization header for a push to endpoint, signed with the VAPID keys:
// a JWT (ES256) for the push service's origin, valid for an hour, naming sub
// (an https: or mailto: contact; Apple requires one).
export function vapidAuth(endpoint, { publicKey, privateKey }, { sub, now = Date.now() }) {
  const pub = unb64u(publicKey);
  const key = createPrivateKey({ format: 'jwk', key: { kty: 'EC', crv: 'P-256', d: privateKey, x: b64u(pub.subarray(1, 33)), y: b64u(pub.subarray(33, 65)) } });
  const head = b64u(JSON.stringify({ typ: 'JWT', alg: 'ES256' }));
  const claims = b64u(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(now / 1000) + 60 * 60, sub }));
  const signature = sign('sha256', Buffer.from(`${head}.${claims}`), { key, dsaEncoding: 'ieee-p1363' });
  return `vapid t=${head}.${claims}.${b64u(signature)}, k=${publicKey}`;
}

// The request that delivers message (an object, sent as JSON) to a subscription.
export function pushRequest(subscription, message, vapid, { sub, now, salt, asPrivate } = {}) {
  return {
    url: subscription.endpoint,
    headers: {
      authorization: vapidAuth(subscription.endpoint, vapid, { sub, now }),
      'content-encoding': 'aes128gcm',
      'content-type': 'application/octet-stream',
      ttl: String(24 * 60 * 60),
      urgency: 'high',
    },
    body: encryptPayload(JSON.stringify(message), subscription.keys ?? {}, { salt, asPrivate }),
  };
}

// A subscription as the page sends it (PushSubscription.toJSON()), checked:
// { endpoint, keys: { p256dh, auth } }, or null. Push services are https;
// insecure lets a test's stand-in service on http through.
export function cleanSubscription(s, { insecure = false } = {}) {
  let url;
  try { url = new URL(s?.endpoint); } catch { return null; }
  if (url.protocol !== 'https:' && !(insecure && url.protocol === 'http:')) return null;
  const p256dh = String(s?.keys?.p256dh ?? '');
  const auth = String(s?.keys?.auth ?? '');
  if (unb64u(p256dh).length !== 65 || unb64u(auth).length !== 16) return null;
  return { endpoint: url.href, keys: { p256dh, auth } };
}

// Where a tap on a record's notification goes: the phone page, told which
// record to mark read and what to open.
export function targetUrl(record) {
  const q = new URLSearchParams({ bell: record.id, go: record.target?.tab ?? 'questions' });
  if (record.target?.item) q.set('item', record.target.item);
  if (record.target?.session ?? record.session) q.set('session', record.target?.session ?? record.session);
  return `/m?${q}`;
}

// The notification a bell record makes: who and what in one line, the detail
// under it, and the session as its tag, so a session's newer notification
// replaces its older one on the lock screen (the owner's choice, PM task 11).
export function pushMessage(record) {
  return {
    title: String(record.text ?? 'Project Manager').slice(0, 120),
    body: String(record.detail ?? '').slice(0, 240),
    tag: record.session ? `session:${record.session}` : `record:${record.id}`,
    url: targetUrl(record),
  };
}

// Which of the bell's new records go to the lock screen: only while Away is
// on, and only unread ones.
export const toPush = (records, away) => (away?.on ? records.filter((r) => !r.read) : []);
