// The bell's routes, mounted by server.mjs: every sweepMs (and on each look) it
// turns the relay's held items and the events the relay hook noted
// (events.jsonl, read on from where it left off) into notification records
// (rules in bell.mjs), kept in one file so every device shares the read flags.
//   GET  /bell        { unread, records } newest first
//   POST /bell/read   { ids: [...] } or { all: true }
import { mkdir, open, readFile, rename, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { bellUpdate, bellView, eventsDue, markRead } from './bell.mjs';

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

  // Events noted since the last look: whole lines from eventsAt on, each with
  // its byte offset (which, with its time, names its record). A file that
  // shrank was started again, so it's read from the top.
  const eventsFile = path.join(relay, 'events.jsonl');
  async function newEvents(from) {
    const size = await stat(eventsFile).then((s) => s.size, () => 0);
    const at = from > size ? 0 : from;
    if (size === at) return { events: [], at, size };
    const fh = await open(eventsFile, 'r');
    try {
      const buf = Buffer.alloc(size - at);
      await fh.read(buf, 0, buf.length, at);
      const out = [];
      let start = 0;
      for (let nl = buf.indexOf(10); nl >= 0; start = nl + 1, nl = buf.indexOf(10, start)) {
        const line = buf.toString('utf8', start, nl);
        try { if (line.trim()) out.push({ ...JSON.parse(line), offset: at + start }); } catch { /* a broken line is skipped */ }
      }
      return { events: out, at: at + start, size }; // a half-written last line waits
    } finally { await fh.close(); }
  }

  // When the file has been read to its end and its oldest line is over 30 days
  // old (bell.mjs eventsDue), it moves aside and the hook starts a new one. A
  // line the hook appends in the instant between the read and the move goes
  // with the old file unread: a missed notification at worst.
  async function rotateIfDue() {
    let first = null;
    try {
      const fh = await open(eventsFile, 'r');
      try {
        const buf = Buffer.alloc(4096);
        const { bytesRead } = await fh.read(buf, 0, buf.length, 0);
        const nl = buf.subarray(0, bytesRead).indexOf(10);
        first = JSON.parse(buf.toString('utf8', 0, nl < 0 ? bytesRead : nl)).time;
      } finally { await fh.close(); }
    } catch { return false; }
    if (!eventsDue(Number(first))) return false;
    await rename(eventsFile, `${eventsFile}.old`);
    return true;
  }

  const sweep = () => serial(async () => {
    const before = await load();
    let { events, at, size } = await newEvents(before?.eventsAt ?? 0);
    if (at === size && await rotateIfDue().catch(() => false)) at = 0;
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
