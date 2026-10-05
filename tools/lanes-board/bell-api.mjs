// The bell's routes, mounted by server.mjs: every sweepMs (and on each look) it
// turns the relay's held items and the events the relay hook noted
// (events.jsonl, read on from where it left off) into notification records
// (rules in bell.mjs), kept in one file so every device shares the read flags.
//   GET  /bell        { unread, records } newest first
//   POST /bell/read   { ids: [...] } or { all: true }
import { mkdir, open, readFile, rename, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { bellUpdate, bellView, markRead } from './bell.mjs';

// file: notifications.json; relay: the relay folder; held(): the items held
// now; titlesOf(ids): Map of session id -> title; onNew(records): told of each
// look's new records (lock-screen push, push-api.mjs), after they are saved.
export function bellApi({ file, relay, held, titlesOf, onNew = () => {}, sweepMs = 0 }) {
  let state;
  let busy = Promise.resolve();
  // One look at a time: a sweep, a read and a mark never overlap.
  const serial = (fn) => { const run = busy.then(fn, fn); busy = run.catch(() => {}); return run; };

  async function load() {
    if (state !== undefined) return state;
    try { state = JSON.parse(await readFile(file, 'utf8')); } catch { state = null; }
    return state;
  }
  async function save(next) {
    if (next === state) return;
    state = next;
    await mkdir(path.dirname(file), { recursive: true });
    const tmp = `${file}.${process.pid}.tmp`;
    await writeFile(tmp, JSON.stringify(state));
    await rename(tmp, file);
  }

  // Events noted since the last look: whole lines from eventsAt on. A file
  // that shrank was started again, so it's read from the top.
  async function newEvents(from) {
    const events = path.join(relay, 'events.jsonl');
    const size = await stat(events).then((s) => s.size, () => 0);
    let at = from > size ? 0 : from;
    if (size === at) return { events: [], at };
    const fh = await open(events, 'r');
    try {
      const buf = Buffer.alloc(size - at);
      await fh.read(buf, 0, buf.length, at);
      const text = buf.toString('utf8');
      const end = text.lastIndexOf('\n') + 1; // a half-written last line waits
      const out = [];
      for (const line of text.slice(0, end).split('\n')) {
        try { if (line.trim()) out.push(JSON.parse(line)); } catch { /* a broken line is skipped */ }
      }
      return { events: out, at: at + Buffer.byteLength(text.slice(0, end)) };
    } finally { await fh.close(); }
  }

  const sweep = () => serial(async () => {
    const before = await load();
    const { events, at } = await newEvents(before?.eventsAt ?? 0);
    const pending = await held();
    const titles = await titlesOf([...new Set([...pending, ...events].map((x) => x.session).filter(Boolean))]);
    let next = bellUpdate(before, { pending, events, titleOf: (id) => titles.get(id) ?? '(untitled)' });
    if (at !== (before?.eventsAt ?? 0)) next = { ...next, eventsAt: at };
    await save(next);
    const had = new Set((before?.records ?? []).map((r) => r.id));
    const fresh = (state?.records ?? []).filter((r) => !had.has(r.id));
    if (fresh.length) Promise.resolve().then(() => onNew(fresh)).catch((err) => console.error(err));
    return state;
  });

  async function read(body) {
    const ids = body?.all === true ? 'all' : Array.isArray(body?.ids) ? body.ids.map(String) : null;
    if (!ids) throw new Error('Which notifications?');
    return serial(async () => {
      await save(markRead(await load(), ids));
      return bellView(state);
    });
  }

  if (sweepMs > 0) setInterval(() => { sweep().catch(() => {}); }, sweepMs).unref();

  return {
    get(url) {
      if (url.pathname === '/bell') return sweep().then(bellView);
      return undefined;
    },
    post(route, body) {
      if (route === '/bell/read') return read(body);
      return undefined;
    },
  };
}
