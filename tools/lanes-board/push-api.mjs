// Lock-screen notifications' routes, mounted by server.mjs, and the sending:
// the bell (bell-api.mjs) hands over each new record, and while Away is on it
// goes to every phone that turned notifications on (rules and crypto in
// push.mjs). The VAPID key pair (push-keys.json) and the subscriptions
// (push-subscriptions.json) live in the state folder, never in the repo; a
// subscription the push service says is gone is dropped.
//   GET  /push         { publicKey, subscriptions, https } for the page
//   POST /push/subscribe   { subscription }  (PushSubscription.toJSON())
//   POST /push/unsubscribe { endpoint }
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { cleanSubscription, pushMessage, pushRequest, toPush, vapidKeys } from './push.mjs';

const MAX_SUBSCRIPTIONS = 20;

// state: the state folder; away(): the Away switch (sessions.mjs awayOf); httpsUrl(): the
// Project Manager's HTTPS address (https://<pc>.<tailnet>.ts.net) or null;
// insecure: lets http endpoints through (tests' stand-in push service).
export function pushApi({ state, away, httpsUrl = () => null, insecure = false, log = console.error }) {
  const keysFile = path.join(state, 'push-keys.json');
  const subsFile = path.join(state, 'push-subscriptions.json');
  let keys = null;
  let busy = Promise.resolve();
  const serial = (fn) => { const run = busy.then(fn, fn); busy = run.catch(() => {}); return run; };

  async function write(file, value) {
    await mkdir(path.dirname(file), { recursive: true });
    const tmp = `${file}.${process.pid}.tmp`;
    await writeFile(tmp, JSON.stringify(value, null, 2));
    await rename(tmp, file);
  }
  const read = async (file) => { try { return JSON.parse(await readFile(file, 'utf8')); } catch { return null; } };

  // The key pair, made once and kept: a new one would orphan every subscription.
  async function vapid() {
    if (keys) return keys;
    const k = await read(keysFile);
    if (k?.publicKey && k?.privateKey) return (keys = k);
    keys = vapidKeys();
    await write(keysFile, keys);
    return keys;
  }
  const subscriptions = async () => (await read(subsFile))?.subscriptions ?? [];
  const saveSubs = (list) => write(subsFile, { subscriptions: list });

  async function info() {
    return { publicKey: (await vapid()).publicKey, subscriptions: (await subscriptions()).length, https: httpsUrl() };
  }

  const subscribe = (body, { origin, ua } = {}) => serial(async () => {
    const s = cleanSubscription(body?.subscription, { insecure });
    if (!s) throw new Error('Not a push subscription');
    const list = (await subscriptions()).filter((x) => x.endpoint !== s.endpoint);
    list.push({ ...s, origin: origin ?? null, ua: String(ua ?? '').slice(0, 200), time: Date.now() });
    await saveSubs(list.slice(-MAX_SUBSCRIPTIONS));
    return { ok: true, subscriptions: Math.min(list.length, MAX_SUBSCRIPTIONS) };
  });

  const unsubscribe = (body) => serial(async () => {
    const list = await subscriptions();
    const kept = list.filter((x) => x.endpoint !== String(body?.endpoint ?? ''));
    if (kept.length !== list.length) await saveSubs(kept);
    return { ok: true, subscriptions: kept.length };
  });

  // Sends one message to every subscription; drops those the service says are gone.
  async function send(message) {
    const list = await subscriptions();
    if (!list.length) return [];
    const k = await vapid();
    const gone = new Set();
    const results = await Promise.all(list.map(async (s) => {
      // Apple wants a contact: the https address the phone subscribed from.
      const sub = s.origin?.startsWith('https:') ? s.origin : (httpsUrl() ?? 'https://localhost');
      try {
        const r = pushRequest(s, message, k, { sub });
        const res = await fetch(r.url, { method: 'POST', headers: r.headers, body: r.body, signal: AbortSignal.timeout(15_000) });
        if (res.status === 404 || res.status === 410) gone.add(s.endpoint);
        else if (!res.ok) log(`push to ${new URL(s.endpoint).host} refused: ${res.status} ${(await res.text().catch(() => '')).slice(0, 200)}`);
        return res.status;
      } catch (err) {
        log(`push to ${new URL(s.endpoint).host} failed: ${err.message}`);
        return null;
      }
    }));
    if (gone.size) await serial(async () => saveSubs((await subscriptions()).filter((x) => !gone.has(x.endpoint))));
    return results;
  }

  // The bell's new records: pushed while Away is on.
  async function notify(records) {
    const out = toPush(records, await away());
    for (const r of out) await send(pushMessage(r));
    return out.length;
  }

  return {
    notify,
    get(url) {
      if (url.pathname === '/push') return info();
      return undefined;
    },
    post(route, body, ctx) {
      if (route === '/push/subscribe') return subscribe(body, ctx);
      if (route === '/push/unsubscribe') return unsubscribe(body);
      return undefined;
    },
  };
}
