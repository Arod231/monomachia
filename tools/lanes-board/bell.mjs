// The bell's rules: what the owner is told about while elsewhere. Pure, no I/O:
// bell-api.mjs feeds it the relay's held items and the events the relay hook
// noted, and keeps its state in ~/.claude/lanes-board/notifications.json, so
// every device shares one read flag. tests/lanes-board-bell.test.mjs checks it.
//
// A record: { id, kind: question | permission | plan | turn | asked | merge | visuals, session,
// text (who needs what, one line), detail (one line more), target (where a tap
// goes: { tab: 'questions', item?, session } or { tab: 'sessions', session, merge? }),
// time, read }. Owner's rules (PM task 10, Oct 4): answering, handing back or a
// timeout marks a held item's record read; a session's newer finished turn
// replaces its older unread one.

export const BELL_KEEP_MS = 7 * 24 * 60 * 60 * 1000;
// events.jsonl only grows, so once its oldest line is older than this the
// board moves it aside (to events.jsonl.old, replacing the last one) and the
// hook starts a new one: at most about two months are kept.
export const EVENTS_KEEP_MS = 30 * 24 * 60 * 60 * 1000;

// Whether events.jsonl, whose oldest line is from firstTime, is due to start afresh.
export function eventsDue(firstTime, now = Date.now()) {
  return Number.isFinite(firstTime) && firstTime > 0 && now - firstTime > EVENTS_KEEP_MS;
}
const MAX_RECORDS = 500;

const oneLine = (s, n = 200) => String(s ?? '').split(/\r?\n/).map((l) => l.trim()).filter(Boolean).join(' ').slice(0, n);
const lastLine = (s) => oneLine(String(s ?? '').split(/\r?\n/).map((l) => l.trim()).filter(Boolean).at(-1));

// A held item (pending/<id>.json in the relay folder) as a record. Only a relay
// hook installed before Oct 5 holds questions; since then they stay in the app.
function heldRecord(p, title) {
  const base = { id: `held:${p.id}`, item: p.id, session: p.session, time: Number(p.time) || 0, read: false,
    target: { tab: 'questions', item: p.id, session: p.session } };
  if (p.kind === 'question') return { ...base, kind: 'question', text: `${title} asks you a question`, detail: oneLine(p.input?.questions?.[0]?.question) };
  if (p.kind === 'plan') return { ...base, kind: 'plan', text: `${title} asks you to approve its plan`, detail: '' };
  if (p.kind === 'stop') return { ...base, kind: 'turn', text: `${title} finished its turn`, detail: lastLine(p.last) };
  const input = p.input ?? {};
  return { ...base, kind: 'permission', text: `${title} wants to use ${p.tool ?? 'a tool'}`,
    detail: oneLine(input.command ?? input.file_path ?? input.url ?? input.pattern ?? '') };
}

// An event the relay hook noted (events.jsonl) as a record, or null.
function eventRecord(e, n, title) {
  // Named by where the line sits in events.jsonl (bell-api.mjs gives its offset),
  // with its time, since the file starts afresh every 30 days.
  const where = e.offset ?? `n${n}`;
  const base = { id: `event:${Number(e.time) || 0}:${where}`, session: e.session, time: Number(e.time) || 0, read: false };
  if (e.kind === 'asked-in-app') {
    return { ...base, kind: 'asked', text: `${title} is waiting on you to answer questions in the app`, detail: oneLine(e.questions?.[0]),
      target: { tab: 'questions', session: e.session } };
  }
  if (e.kind === 'turn-finished') {
    return { ...base, kind: 'turn', text: `${title} finished its turn`, detail: lastLine(e.last), target: { tab: 'sessions', session: e.session } };
  }
  // Noted by the board itself (merge-api.mjs) when a session's pull request turns ready.
  if (e.kind === 'pr-ready' && Number.isInteger(e.pr?.number)) {
    return { ...base, kind: 'merge', text: `${title}: pull request #${e.pr.number} is ready to merge`,
      detail: oneLine(`${e.pr.title ?? ''} into ${e.pr.base ?? 'its base'}`), target: { tab: 'sessions', session: e.session, merge: e.pr.number } };
  }
  return null;
}

// New visuals (media.mjs entries, { session, id, time, kind, caption }) as
// records: one per session per minute, from its first post in that minute,
// counting every post the minute brought.
export const VISUALS_BATCH_MS = 60 * 1000;
function visualsRecords(posts, titleOf) {
  const out = [];
  const bySession = new Map();
  for (const p of [...posts].sort((a, b) => a.time - b.time)) bySession.set(p.session, [...(bySession.get(p.session) ?? []), p]);
  for (const [session, list] of bySession) {
    let batch = null;
    for (const p of list) {
      if (!batch || p.time - batch.time >= VISUALS_BATCH_MS) { batch = { session, first: p, time: p.time, posts: [] }; out.push(batch); }
      batch.posts.push(p);
    }
  }
  return out.sort((a, b) => a.time - b.time).map(({ session, first, time, posts: ps }) => {
    const what = ps.length > 1 ? `${ps.length} visuals` : ps[0].kind === 'clip' ? 'a clip' : 'a shot';
    return { id: `visuals:${session}:${first.id}`, kind: 'visuals', session, time, count: ps.length, read: false,
      text: `${titleOf(session)} posted ${what}`, detail: oneLine(ps.at(-1).caption), target: { tab: 'sessions', session, visuals: true } };
  });
}

// The bell's state after a look at the relay: { records }. pending: the items
// held now; events: those noted since the last look; posts: the media posted
// in the last 7 days; titleOf(session): its title. Returns state itself when
// nothing changed.
export function bellUpdate(state, { pending = [], events = [], posts = [], now = Date.now(), titleOf = () => '(untitled)' }) {
  let records = state?.records ?? [];
  let changed = !state;
  const add = (r) => {
    if (!r || records.some((x) => x.id === r.id)) return;
    // A newer finished turn replaces the session's older unread one.
    if (r.kind === 'turn') {
      const before = records.length;
      records = records.filter((x) => !(x.kind === 'turn' && x.session === r.session && !x.read && x.time <= r.time));
      if (records.length !== before) changed = true;
    }
    records = [...records, r];
    changed = true;
  };
  events.forEach((e, i) => add(eventRecord(e, i, titleOf(e.session))));
  for (const p of [...pending].sort((a, b) => (a.time ?? 0) - (b.time ?? 0))) add(heldRecord(p, titleOf(p.session)));
  // A minute's batch that grew since the last look is told again, read or not as it was.
  for (const r of visualsRecords(posts.filter((p) => now - p.time <= BELL_KEEP_MS), titleOf)) {
    const i = records.findIndex((x) => x.id === r.id);
    if (i < 0) add(r);
    else if (records[i].count !== r.count) { records = records.map((x, k) => (k === i ? { ...r, read: x.read } : x)); changed = true; }
  }
  // Held items no longer held were answered, handed back or timed out.
  const still = new Set(pending.map((p) => p.id));
  records = records.map((r) => {
    if (!r.item || r.read || still.has(r.item)) return r;
    changed = true;
    return { ...r, read: true };
  });
  const kept = records.filter((r) => now - r.time <= BELL_KEEP_MS).slice(-MAX_RECORDS);
  if (kept.length !== records.length) changed = true;
  return changed ? { ...(state ?? {}), records: kept } : state;
}

// Marks the records named by ids (or 'all') read. Returns state when nothing changed.
export function markRead(state, ids) {
  const all = ids === 'all';
  const want = new Set(all ? [] : ids ?? []);
  let changed = false;
  const records = (state?.records ?? []).map((r) => {
    if (r.read || !(all || want.has(r.id))) return r;
    changed = true;
    return { ...r, read: true };
  });
  return changed ? { ...state, records } : state;
}

// What the pages show: the unread count and the records, newest first.
export function bellView(state) {
  const records = [...(state?.records ?? [])].sort((a, b) => b.time - a.time);
  return { unread: records.filter((r) => !r.read).length, records };
}
