// Claude Code sessions for this project, read from their transcript files
// (~/.claude/projects/<prefix>*/<id>.jsonl). Only the head and tail of each
// file are read, and results are cached by size and modified time.
import { open, readdir, stat } from 'node:fs/promises';
import path from 'node:path';

export const LIVE_MS = 3 * 60 * 1000;
const HEAD = 64 << 10;
const CHUNK = 256 << 10;
const MAX_BACK = 4 << 20;

function records(text) {
  const out = [];
  for (const raw of text.split('\n')) {
    const t = raw.trim();
    if (!t) continue;
    try { out.push(JSON.parse(t)); } catch { /* a line cut by a chunk edge or mid-write */ }
  }
  return out;
}

function promptText(r) {
  if (r.type !== 'user' || r.isMeta) return null;
  const c = r.message?.content;
  const text = typeof c === 'string' ? c : Array.isArray(c) ? c.find((p) => p?.type === 'text')?.text : null;
  if (!text || text.trimStart().startsWith('<')) return null;
  return text.trim();
}

// Later records win for title, cwd and branch; the first prompt is the earliest.
export function summarize(recs, into = {}) {
  for (const r of recs) {
    if (r.type === 'custom-title' && r.customTitle) into.title = r.customTitle;
    if (typeof r.cwd === 'string') into.cwd = r.cwd;
    if (typeof r.gitBranch === 'string') into.branch = r.gitBranch;
    if (into.firstPrompt == null) { const p = promptText(r); if (p) into.firstPrompt = p; }
  }
  return into;
}

export async function readSession(file, now = Date.now()) {
  const st = await stat(file);
  const fh = await open(file, 'r');
  try {
    const read = async (pos, len) => {
      const buf = Buffer.alloc(len);
      const { bytesRead } = await fh.read(buf, 0, len, pos);
      return buf.toString('utf8', 0, bytesRead);
    };
    const head = summarize(records(await read(0, Math.min(HEAD, st.size))));
    const found = {};
    let end = st.size;
    while (end > 0 && st.size - end < MAX_BACK && !(found.title && found.cwd && found.branch)) {
      const start = Math.max(0, end - CHUNK);
      let text = await read(start, end - start);
      if (start > 0) text = text.slice(text.indexOf('\n') + 1);
      const s = summarize(records(text));
      for (const k of ['title', 'cwd', 'branch']) if (found[k] == null && s[k] != null) found[k] = s[k];
      end = start;
    }
    const id = path.basename(file, '.jsonl');
    const cwd = found.cwd ?? head.cwd ?? null;
    return {
      id, file,
      title: found.title ?? head.title ?? head.firstPrompt?.slice(0, 80) ?? id.slice(0, 8),
      cwd,
      folder: cwd ? path.win32.basename(cwd.replaceAll('/', '\\')) : '',
      branch: found.branch ?? head.branch ?? null,
      lastActive: st.mtimeMs,
      live: now - st.mtimeMs < LIVE_MS,
    };
  } finally {
    await fh.close();
  }
}

const cache = new Map(); // file -> { size, mtimeMs, session }

export async function listSessions({ projectsDir, prefix, now = Date.now() }) {
  let dirs;
  try { dirs = await readdir(projectsDir, { withFileTypes: true }); } catch { return []; }
  const out = [];
  for (const d of dirs) {
    if (!d.isDirectory() || !d.name.startsWith(prefix)) continue;
    const dir = path.join(projectsDir, d.name);
    for (const f of await readdir(dir, { withFileTypes: true })) {
      if (!f.isFile() || !f.name.endsWith('.jsonl')) continue;
      const file = path.join(dir, f.name);
      try {
        const st = await stat(file);
        let hit = cache.get(file);
        if (!hit || hit.size !== st.size || hit.mtimeMs !== st.mtimeMs) {
          hit = { size: st.size, mtimeMs: st.mtimeMs, session: await readSession(file, now) };
          cache.set(file, hit);
        }
        out.push({ ...hit.session, live: now - hit.session.lastActive < LIVE_MS });
      } catch { /* removed while listing */ }
    }
  }
  return out.sort((a, b) => b.lastActive - a.lastActive);
}
