// Tests for tools/lanes-board/access.mjs: who may reach the board (this PC and
// the owner's tailnet), which names it answers to, and which page a phone gets.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  fromTailnetOrLocal, knownHost, pageFor, sameOrigin, tailnetIPv4s, tailscaleSelf, wantsGzip,
} from '../tools/lanes-board/access.mjs';

const IPHONE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';
const ANDROID = 'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36';
const ANDROID_TABLET = 'Mozilla/5.0 (Linux; Android 15; Pixel Tablet) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';
const DESKTOP = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';

const NAMES = new Set(['localhost', '127.0.0.1', '100.120.241.100', 'pc', 'pc.tail1234.ts.net']);

describe('fromTailnetOrLocal', () => {
  it('lets in loopback, in IPv4 and IPv6 forms', () => {
    for (const a of ['127.0.0.1', '::1', '::ffff:127.0.0.1']) assert.equal(fromTailnetOrLocal(a), true);
  });

  it('lets in Tailscale addresses: 100.64.0.0/10 and fd7a:115c:a1e0::/48', () => {
    for (const a of ['100.64.0.1', '100.120.241.100', '100.127.255.254', '::ffff:100.100.1.2', 'fd7a:115c:a1e0::1']) {
      assert.equal(fromTailnetOrLocal(a), true);
    }
  });

  it('refuses the rest of 100.x, the LAN and everything else', () => {
    for (const a of ['100.63.255.255', '100.128.0.1', '192.168.1.20', '10.0.0.5', '8.8.8.8', 'fe80::1', '', undefined]) {
      assert.equal(fromTailnetOrLocal(a), false);
    }
  });
});

describe('knownHost', () => {
  it('answers to its own names, with or without the port, in any case', () => {
    for (const h of ['localhost:5197', '127.0.0.1:5197', '100.120.241.100:5197', 'PC:5197', 'pc.tail1234.ts.net']) {
      assert.equal(knownHost(h, NAMES), true);
    }
  });

  it('refuses any other name, so a DNS-rebinding page gets nothing', () => {
    for (const h of ['evil.example:5197', '192.168.1.20:5197', '', undefined]) assert.equal(knownHost(h, NAMES), false);
  });
});

describe('sameOrigin', () => {
  const post = (origin, host, contentType = 'application/json') => sameOrigin({ origin, host, contentType }, NAMES);

  it('accepts the board posting to itself under any name it answers to', () => {
    assert.equal(post('http://localhost:5197', 'localhost:5197'), true);
    assert.equal(post('http://100.120.241.100:5197', '100.120.241.100:5197'), true);
    assert.equal(post('http://pc:5197', 'pc:5197', 'application/json; charset=utf-8'), true);
  });

  it('refuses a page from anywhere else, a name it does not know, or a form post', () => {
    assert.equal(post('http://evil.example', 'localhost:5197'), false);
    assert.equal(post('http://localhost:5197', 'pc:5197'), false);
    assert.equal(post('http://evil.example:5197', 'evil.example:5197'), false);
    assert.equal(post('https://localhost:5197', 'localhost:5197'), false);
    assert.equal(post(undefined, 'localhost:5197'), false);
    assert.equal(post('null', 'localhost:5197'), false);
    assert.equal(post('http://localhost:5197', 'localhost:5197', 'text/plain'), false);
  });
});

describe('pageFor', () => {
  it('gives phones the mobile page and computers the desktop one', () => {
    assert.equal(pageFor('/', IPHONE).file, 'm.html');
    assert.equal(pageFor('/', ANDROID).file, 'm.html');
    assert.equal(pageFor('/', ANDROID_TABLET).file, 'index.html');
    assert.equal(pageFor('/', DESKTOP).file, 'index.html');
    assert.equal(pageFor('/?x=1', IPHONE).file, 'm.html');
  });

  it('lets /m and /desktop pick a page by hand', () => {
    assert.equal(pageFor('/m', DESKTOP).file, 'm.html');
    assert.equal(pageFor('/desktop', IPHONE).file, 'index.html');
    assert.equal(pageFor('/desktop?from=m', IPHONE).file, 'index.html');
  });

  it('serves the web app manifest and the home-screen icon', () => {
    assert.deepEqual(pageFor('/manifest.webmanifest', IPHONE), { file: 'manifest.webmanifest', type: 'application/manifest+json' });
    assert.deepEqual(pageFor('/icon.png', IPHONE), { file: 'icon.png', type: 'image/png' });
    assert.deepEqual(pageFor('/apple-touch-icon.png', IPHONE), { file: 'icon.png', type: 'image/png' });
    assert.equal(pageFor('/', DESKTOP).type, 'text/html; charset=utf-8');
  });
});

describe('wantsGzip', () => {
  it('gzips only for a client that says it takes gzip', () => {
    assert.equal(wantsGzip('gzip, deflate, br'), true);
    assert.equal(wantsGzip('br'), false);
    assert.equal(wantsGzip('x-gzipped'), false);
    assert.equal(wantsGzip(undefined), false);
  });
});

describe('the PC\'s Tailscale identity', () => {
  it('reads its IPv4 addresses and MagicDNS names from tailscale status --json', () => {
    const status = { Self: { TailscaleIPs: ['100.120.241.100', 'fd7a:115c:a1e0::1'], DNSName: 'PC.tail1234.ts.net.' } };
    assert.deepEqual(tailscaleSelf(status), { ips: ['100.120.241.100'], names: ['pc.tail1234.ts.net', 'pc'] });
    assert.deepEqual(tailscaleSelf({}), { ips: [], names: [] });
  });

  it('finds the Tailscale IPv4 address among the network interfaces, skipping loopback and the LAN', () => {
    const interfaces = {
      Ethernet: [{ family: 'IPv4', address: '192.168.1.20' }, { family: 'IPv6', address: 'fe80::1' }],
      Tailscale: [{ family: 'IPv4', address: '100.120.241.100' }, { family: 'IPv6', address: 'fd7a:115c:a1e0::1' }],
      'Loopback Pseudo-Interface 1': [{ family: 'IPv4', address: '127.0.0.1' }],
    };
    assert.deepEqual(tailnetIPv4s(interfaces), ['100.120.241.100']);
  });
});
