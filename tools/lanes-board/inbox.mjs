// A session's inbox in the relay folder: what the owner sent it from the
// Project Manager while no turn end was held, one file per message under
// inbox/<session>/, named so they sort oldest first. The board posts to it
// (sessions-api.mjs); the stop hook takes the oldest before the session's next
// tool and the relay hook the rest at its turn end. Installed beside both hooks
// (install-hooks.mjs), so it uses node's own modules only.
import { mkdirSync, readdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';

// A file that still doesn't parse after this long is broken, not half written.
export const BROKEN_AFTER_MS = 60 * 1000;
const SESSION = /^[\w-]+$/;
let posted = 0;

export const inboxDir = (relay, session) => path.join(relay, 'inbox', session);

// Writes value as JSON to a temp file beside file, then renames it over file,
// so a reader sees the whole file or none of it.
export function writeJsonAtomic(file, value) {
  mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.tmp-${process.pid}-${posted++}`;
  writeFileSync(tmp, JSON.stringify(value));
  renameSync(tmp, file);
}

// Adds a message (the text the session reads, already worded) to the inbox.
export function postToInbox(relay, session, text, now = Date.now()) {
  if (!SESSION.test(session ?? '')) throw new Error('Bad session id');
  const name = `${String(now).padStart(15, '0')}-${String(posted++ % 1e6).padStart(6, '0')}.json`;
  writeJsonAtomic(path.join(inboxDir(relay, session), name), { text, time: now });
}

// Takes the oldest message (or, with all, every one), oldest first, removing
// each as it's taken. A file that doesn't parse yet stops the take there, so
// nothing is lost or delivered out of order; after BROKEN_AFTER_MS it is set
// aside as <name>.broken. Returns the texts.
export function takeFromInbox(relay, session, { all = false, now = Date.now() } = {}) {
  if (!SESSION.test(session ?? '')) return [];
  const dir = inboxDir(relay, session);
  let names = [];
  try { names = readdirSync(dir).filter((n) => n.endsWith('.json')).sort(); } catch { return []; }
  const texts = [];
  for (const n of names) {
    const file = path.join(dir, n);
    let m;
    try { m = JSON.parse(readFileSync(file, 'utf8')); } catch (err) {
      if (err.code === 'ENOENT') continue; // taken meanwhile
      let age = 0;
      try { age = now - statSync(file).mtimeMs; } catch { continue; }
      if (age < BROKEN_AFTER_MS) break; // still being written: wait for it
      try { renameSync(file, `${file}.broken`); } catch { /* next time */ }
      continue;
    }
    try { rmSync(file); } catch { continue; } // taken meanwhile
    if (m?.text) texts.push(String(m.text));
    if (!all && texts.length) break;
  }
  return texts;
}
