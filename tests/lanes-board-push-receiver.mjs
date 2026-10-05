// A phone's side of Web Push, written apart from tools/lanes-board/push.mjs so
// the tests check it independently: decrypts an aes128gcm body (RFC 8291).
import { createDecipheriv, createECDH, createHmac } from 'node:crypto';

const unb64u = (s) => Buffer.from(s, 'base64url');

// Decrypts a body with the subscription's private key and secret.
export function decryptPayload(body, { uaPrivate, auth }) {
  const salt = body.subarray(0, 16);
  const idlen = body[20];
  const asPublic = body.subarray(21, 21 + idlen);
  const ua = createECDH('prime256v1');
  ua.setPrivateKey(unb64u(uaPrivate));
  const h = (k, d) => createHmac('sha256', k).update(d).digest();
  const prkKey = h(unb64u(auth), ua.computeSecret(asPublic));
  const ikm = h(prkKey, Buffer.concat([Buffer.from('WebPush: info\0'), ua.getPublicKey(), asPublic, Buffer.from([1])]));
  const prk = h(salt, ikm);
  const cek = h(prk, Buffer.from('Content-Encoding: aes128gcm\0\x01')).subarray(0, 16);
  const nonce = h(prk, Buffer.from('Content-Encoding: nonce\0\x01')).subarray(0, 12);
  const sealed = body.subarray(21 + idlen);
  const d = createDecipheriv('aes-128-gcm', cek, nonce);
  d.setAuthTag(sealed.subarray(-16));
  const padded = Buffer.concat([d.update(sealed.subarray(0, -16)), d.final()]);
  return padded.subarray(0, padded.lastIndexOf(2)).toString('utf8');
}

