// The media store: the shots and clips sessions post to their pages with
// `npm run post` (post.mjs), kept outside the repo in ~/.claude/lanes-board/media/
// so renders made from paid assets are never committed, and kept after a lane's
// worktree goes. One folder per session, holding the files and index.json:
//   { session, cwd, branch, entries: [{ id, kind: still | clip, file, poster,
//     caption, task, time, source, bytes }] }
// The rules (which files, which session, what the sweep removes) are pure and
// tested in tests/lanes-board-media.test.mjs; the store's reads and writes are
// below them, shared by post.mjs and the board (media-api.mjs).
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { SESSION_ID } from './sessions.mjs';

export const MEDIA_KEEP_MS = 30 * 24 * 60 * 60 * 1000;
export const MEDIA_CAP_BYTES = 5 * 1024 ** 3;

const STILLS = new Set(['.png', '.jpg', '.jpeg', '.webp', '.gif']);
const VIDEO = new Set(['.avi', '.mov', '.webm', '.mkv', '.m4v']);
// still: copied; clip: an MP4, copied; video: converted to an MP4 by ffmpeg.
export function mediaKind(file) {
  const ext = path.extname(String(file ?? '')).toLowerCase();
  if (STILLS.has(ext)) return 'still';
  if (ext === '.mp4') return 'clip';
  if (VIDEO.has(ext)) return 'video';
  return null;
}

// The command line of `npm run post -- <files> [--caption …] [--task …] [--session …]`.
export function postArgs(argv) {
  const out = { files: [], caption: null, task: null, session: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const m = a.match(/^--([a-z]+)(?:=(.*))?$/s);
    if (!m) { out.files.push(a); continue; }
    if (!['caption', 'task', 'session'].includes(m[1])) throw new Error(`Unknown option --${m[1]}`);
    const value = m[2] ?? argv[++i];
    if (value == null || value === '') throw new Error(`--${m[1]} needs a value`);
    out[m[1]] = value;
  }
  if (!out.files.length) throw new Error('Name at least one file to post');
  return out;
}

// The session a post goes to: --session, else the one whose shell runs it.
export function sessionOf({ flag, env }) {
  const id = flag ?? env.CLAUDE_CODE_SESSION_ID ?? null;
  if (id == null) throw new Error("Couldn't tell which session this is: run it from a Claude session's shell, or add --session <id>");
  if (!SESSION_ID.test(id)) throw new Error('Bad session id');
  return id;
}

// What the sweep removes from entries ({ time, bytes }, any sessions): those
// older than keepMs, then the oldest until the rest fit in capBytes.
export function mediaToSweep(entries, { now = Date.now(), keepMs = MEDIA_KEEP_MS, capBytes = MEDIA_CAP_BYTES } = {}) {
  const old = entries.filter((e) => now - e.time > keepMs);
  const kept = entries.filter((e) => now - e.time <= keepMs).sort((a, b) => b.time - a.time);
  let total = 0;
  const over = [];
  for (const e of kept) {
    total += e.bytes ?? 0;
    if (total > capBytes) over.push(e);
  }
  return [...old, ...over];
}

// ---------- the store ----------
// A stored file's name: <entry id>[.poster].<ext>, the entry id being <time>-<n>.
export const MEDIA_FILE = /^\d{13}-\d{1,4}(\.poster)?\.(png|jpe?g|webp|gif|mp4)$/;
export const mediaRoot = (state) => path.join(state, 'media');

export function readIndex(root, session) {
  if (!SESSION_ID.test(session ?? '')) return null;
  try {
    const index = JSON.parse(readFileSync(path.join(root, session, 'index.json'), 'utf8'));
    return { ...index, entries: Array.isArray(index.entries) ? index.entries : [] };
  } catch { return null; }
}

// Whole files only, so the board never reads one half written.
function writeIndex(root, session, index) {
  const file = path.join(root, session, 'index.json');
  const tmp = `${file}.tmp-${process.pid}`;
  writeFileSync(tmp, JSON.stringify(index));
  renameSync(tmp, file);
}

// Adds entries (their files already in the session's folder) to its index;
// meta ({ cwd, branch }) is the newest post's.
export function addEntries(root, session, meta, entries) {
  mkdirSync(path.join(root, session), { recursive: true });
  const index = readIndex(root, session) ?? { session, entries: [] };
  writeIndex(root, session, { ...index, ...meta, session, entries: [...index.entries, ...entries] });
}

// Every session with media: { session, cwd, branch, entries }.
export function storeSessions(root) {
  let names = [];
  try { names = readdirSync(root).filter((n) => SESSION_ID.test(n)); } catch { return []; }
  return names.map((n) => readIndex(root, n)).filter((x) => x?.entries.length);
}

// Removes what mediaToSweep picks, files and index entries; returns how many.
export function sweepStore(root, opts = {}) {
  const all = storeSessions(root).flatMap((s) => s.entries.map((e) => ({ ...e, session: s.session })));
  const gone = mediaToSweep(all, opts);
  if (!gone.length) return 0;
  const bySession = new Map();
  for (const e of gone) bySession.set(e.session, [...(bySession.get(e.session) ?? []), e.id]);
  for (const [session, ids] of bySession) {
    const index = readIndex(root, session);
    for (const e of index.entries.filter((x) => ids.includes(x.id))) {
      for (const f of [e.file, e.poster]) if (f && MEDIA_FILE.test(f)) rmSync(path.join(root, session, f), { force: true });
    }
    const left = index.entries.filter((x) => !ids.includes(x.id));
    if (left.length) writeIndex(root, session, { ...index, entries: left });
    else if (existsSync(path.join(root, session))) rmSync(path.join(root, session), { recursive: true, force: true });
  }
  return gone.length;
}
