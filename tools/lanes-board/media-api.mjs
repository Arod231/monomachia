// The media store's side of the board (the store and its rules are media.mjs,
// filled by `npm run post`): each session's posted shots and clips for its page,
// every recent post for the bell, the sessions known by their media for the
// Sessions list's Older filter, and the files themselves:
//   GET /media/<session>/<file>   a stored still, clip or poster, nothing else;
//                                 clips in byte ranges, as the iPhone asks for them
// An hourly sweep keeps the store to 30 days and 5 GB.
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { MEDIA_FILE, mediaRoot, readIndex, storeSessions, sweepStore } from './media.mjs';
import { SESSION_ID } from './sessions.mjs';

const TYPES = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.gif': 'image/gif', '.mp4': 'video/mp4' };

// An index entry as the pages use it, with the addresses of its file and poster.
const view = (session) => (e) => ({
  id: e.id, kind: e.kind, caption: e.caption ?? null, task: e.task ?? null, time: e.time, bytes: e.bytes ?? 0,
  url: `/media/${session}/${e.file}`, poster: e.poster ? `/media/${session}/${e.poster}` : null,
});

// The byte range a Range header asks of a file of size bytes: { start, end },
// null for the whole file, or 'bad' when it can't be met.
export function rangeOf(header, size) {
  const m = /^bytes=(\d*)-(\d*)$/.exec(String(header ?? '').trim());
  if (!m || (m[1] === '' && m[2] === '')) return null;
  let start;
  let end;
  if (m[1] === '') { start = Math.max(0, size - Number(m[2])); end = size - 1; } // the last N bytes
  else { start = Number(m[1]); end = m[2] === '' ? size - 1 : Math.min(Number(m[2]), size - 1); }
  return start > end || start >= size ? 'bad' : { start, end };
}

export function mediaApi({ state, sweepMs = 0 }) {
  const root = mediaRoot(state);

  async function serve(req, res, url) {
    const m = /^\/media\/([^/]+)\/([^/]+)$/.exec(url.pathname);
    if (!m) return false;
    const [, session, file] = m;
    const size = SESSION_ID.test(session) && MEDIA_FILE.test(file)
      ? await stat(path.join(root, session, file)).then((s) => (s.isFile() ? s.size : null), () => null) : null;
    if (size == null) { res.writeHead(404, { 'content-type': 'text/plain' }); res.end('No such media'); return true; }
    const headers = { 'content-type': TYPES[path.extname(file).toLowerCase()], 'accept-ranges': 'bytes', 'cache-control': 'private, max-age=86400' };
    const range = rangeOf(req.headers.range, size);
    if (range === 'bad') { res.writeHead(416, { 'content-range': `bytes */${size}` }); res.end(); return true; }
    const { start, end } = range ?? { start: 0, end: size - 1 };
    res.writeHead(range ? 206 : 200, { ...headers, 'content-length': end - start + 1, ...(range ? { 'content-range': `bytes ${start}-${end}/${size}` } : {}) });
    if (req.method === 'HEAD' || size === 0) { res.end(); return true; }
    createReadStream(path.join(root, session, file), { start, end }).pipe(res);
    return true;
  }

  if (sweepMs > 0) setInterval(() => { try { sweepStore(root); } catch (err) { console.error(err); } }, sweepMs).unref();

  return {
    serve,
    // A session's posts for its page, newest first, and where it posted from.
    of(session) {
      const index = readIndex(root, session);
      if (!index) return { visuals: [], cwd: null, branch: null };
      return { visuals: [...index.entries].sort((a, b) => b.time - a.time).map(view(session)), cwd: index.cwd ?? null, branch: index.branch ?? null };
    },
    // Every post, for the bell: { session, id, time, kind, caption }.
    posts: () => storeSessions(root).flatMap((s) => s.entries.map((e) => ({ session: s.session, id: e.id, time: e.time, kind: e.kind, caption: e.caption }))),
    // The sessions with media: { id, cwd, branch, count, latest }.
    sessions: () => storeSessions(root).map((s) => ({ id: s.session, cwd: s.cwd ?? null, branch: s.branch ?? null, count: s.entries.length,
      latest: Math.max(...s.entries.map((e) => e.time)) })),
  };
}
