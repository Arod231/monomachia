// Who may reach the lanes board, by which names, and which page they get.
// The board answers this PC and the owner's tailnet only, so the owner's phone
// can open it over Tailscale; a phone gets the mobile page (m.html). Pure rules,
// no I/O: server.mjs learns the PC's Tailscale addresses and applies them.

// Loopback, Tailscale's 100.64.0.0/10 and its fd7a:115c:a1e0::/48.
export function fromTailnetOrLocal(addr) {
  const a = String(addr ?? '').replace(/^::ffff:/, '');
  if (a === '127.0.0.1' || a === '::1') return true;
  const m = a.match(/^100\.(\d+)\.\d+\.\d+$/);
  if (m) return Number(m[1]) >= 64 && Number(m[1]) <= 127;
  return /^fd7a:115c:a1e0:/i.test(a);
}

const hostOf = (h) => String(h ?? '').toLowerCase().replace(/:\d+$/, '');

// Is the request's Host one of the names the board answers to?
export const knownHost = (host, names) => names.has(hostOf(host));

// Only the board's own pages may launch or end work: the Origin must be the
// board itself, under a name it answers to (so no DNS-rebinding page can), and
// the body JSON (which a plain form can't send). Over https only the PC's
// tailnet name (pc.<tailnet>.ts.net) counts: Tailscale Serve answers it with
// the tailnet's certificate and hands the request on from loopback, Host unchanged.
export function sameOrigin({ origin, host, contentType }, names) {
  let o;
  try { o = new URL(origin); } catch { return false; }
  const secure = o.protocol === 'https:' && hostOf(host).endsWith('.ts.net');
  return (o.protocol === 'http:' || secure) && o.host === host && knownHost(host, names)
    && String(contentType ?? '').startsWith('application/json');
}

export const isPhone = (ua) => /iPhone|iPod|Android.+Mobile/.test(ua ?? '');

const HTML = 'text/html; charset=utf-8';
const FILES = {
  '/manifest.webmanifest': { file: 'manifest.webmanifest', type: 'application/manifest+json' },
  '/icon.png': { file: 'icon.png', type: 'image/png' },
  '/apple-touch-icon.png': { file: 'icon.png', type: 'image/png' },
  '/graph.mjs': { file: 'graph.mjs', type: 'text/javascript; charset=utf-8' },
  '/ui.mjs': { file: 'ui.mjs', type: 'text/javascript; charset=utf-8' },
  '/sessions-ui.mjs': { file: 'sessions-ui.mjs', type: 'text/javascript; charset=utf-8' },
};

// The file for a GET that isn't /data or /brain: phones get m.html, computers
// index.html, and /m or /desktop pick one by hand.
export function pageFor(url, ua) {
  const p = String(url).split('?')[0];
  if (FILES[p]) return FILES[p];
  const mobile = p === '/m' || (p !== '/desktop' && isPhone(ua));
  return { file: mobile ? 'm.html' : 'index.html', type: HTML };
}

export const wantsGzip = (acceptEncoding) => /(^|[\s,])gzip\b/.test(acceptEncoding ?? '');

// This PC's Tailscale IPv4 addresses and MagicDNS names (pc.<tailnet>.ts.net
// and the short pc), from `tailscale status --json`.
export function tailscaleSelf(status) {
  const self = status?.Self ?? {};
  const ips = (self.TailscaleIPs ?? []).filter((ip) => ip.includes('.'));
  const dns = String(self.DNSName ?? '').replace(/\.$/, '').toLowerCase();
  return { ips, names: dns ? [dns, dns.split('.')[0]] : [] };
}

// The Tailscale IPv4 addresses among os.networkInterfaces(), so the board finds
// its address even before the tailscale command answers.
export function tailnetIPv4s(interfaces) {
  return Object.values(interfaces).flat()
    .filter((i) => i && i.family === 'IPv4' && i.address !== '127.0.0.1' && fromTailnetOrLocal(i.address))
    .map((i) => i.address);
}
