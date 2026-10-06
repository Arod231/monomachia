// The lanes board's Sessions view: reads a Claude Code transcript (one JSON
// object per line, ~/.claude/projects/<folder>/<session id>.jsonl) into the
// turns the board shows, and finds what the session is waiting on. Pure, no
// I/O: server.mjs reads the files, tests/lanes-board.test.mjs checks this.
import { isPhone } from './access.mjs';

const CLIP = 4000;
const clip = (s, n = CLIP) => (s.length > n ? `${s.slice(0, n)}\n… (${s.length - n} more characters)` : s);

// What a tool call does, in one line.
export function toolSummary(name, input = {}) {
  const pick = input.command ?? input.file_path ?? input.notebook_path ?? input.pattern ?? input.url ?? input.query
    ?? input.description ?? input.prompt ?? input.skill ?? input.message;
  if (name === 'AskUserQuestion') return (input.questions ?? []).map((q) => q.question).join(' · ');
  if (name === 'TodoWrite') return `${(input.todos ?? []).length} todos`;
  if (typeof pick === 'string') return pick.split(/\r?\n/)[0].slice(0, 300);
  const first = Object.values(input).find((v) => typeof v === 'string');
  return first ? first.split(/\r?\n/)[0].slice(0, 300) : '';
}

const textOf = (content) => (typeof content === 'string' ? content
  : (content ?? []).map((c) => (c.type === 'text' ? c.text : c.type === 'image' ? '[image]' : '')).filter(Boolean).join('\n'));

// A user turn the app wrote rather than the owner: slash-command echoes and the like.
function userText(raw) {
  const cmd = raw.match(/<command-name>([^<]*)<\/command-name>/);
  if (cmd) return `${cmd[1].trim()} ${raw.match(/<command-args>([^<]*)<\/command-args>/)?.[1] ?? ''}`.trim();
  if (/^\s*<(local-command-stdout|local-command-caveat|system-reminder|task-notification)/.test(raw)) return null;
  return raw.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, '').trim() || null;
}

// lines: the transcript's lines (the first may be cut off, when only its tail
// was read). Returns the turns, newest last, plus the session's title and folder
// when the transcript names them, the tool call still waiting on a result, and
// lastReply: the uuid of the newest main-chain reply's line, which the app's
// turn summary names when it is about that turn (turnSummary), and branch: the
// git branch its newest line was written on (null when detached).
export function parseTranscript(lines, { limit = 400 } = {}) {
  const entries = [];
  const results = new Map(); // tool_use id -> result entry
  let title = null;
  let cwd = null;
  let firstPrompt = null;
  let lastReply = null;
  let branch = null;
  for (const line of lines) {
    let o;
    try { o = JSON.parse(line); } catch { continue; }
    if (o.type === 'custom-title' && o.customTitle) title = o.customTitle;
    if (o.cwd) cwd = o.cwd;
    if (o.isSidechain || o.isMeta) continue;
    if (typeof o.gitBranch === 'string') branch = o.gitBranch && o.gitBranch !== 'HEAD' ? o.gitBranch : null;
    if (o.type === 'assistant' && o.uuid) lastReply = o.uuid;
    const time = o.timestamp ? Date.parse(o.timestamp) : null;
    if (o.type === 'user' && o.message) {
      const c = o.message.content;
      if (Array.isArray(c) && c.some((x) => x.type === 'tool_result')) {
        for (const r of c.filter((x) => x.type === 'tool_result')) {
          const e = { kind: 'result', time, tool: r.tool_use_id, error: !!r.is_error, text: clip(textOf(r.content)) };
          results.set(r.tool_use_id, e);
          entries.push(e);
        }
        continue;
      }
      const text = userText(textOf(c));
      if (text) { entries.push({ kind: 'user', time, text: clip(text) }); firstPrompt ??= text; }
    } else if (o.type === 'assistant' && o.message) {
      for (const c of o.message.content ?? []) {
        if (c.type === 'text' && c.text.trim()) entries.push({ kind: 'assistant', time, text: clip(c.text, 20000) });
        else if (c.type === 'tool_use') {
          entries.push({ kind: 'tool', time, id: c.id, name: c.name, summary: toolSummary(c.name, c.input),
            input: c.name === 'AskUserQuestion' ? c.input : clip(JSON.stringify(c.input, null, 2), 3000) });
        }
      }
    } else if (o.type === 'system' && o.stopReason) {
      entries.push({ kind: 'system', time, text: clip(String(o.stopReason), 1000) });
    }
  }
  // The newest tool call with no result yet: running, or waiting on a dialog.
  const open = [...entries].reverse().find((e) => e.kind === 'tool' && !results.has(e.id)) ?? null;
  const shown = entries.slice(-limit);
  return {
    entries: shown,
    more: entries.length - shown.length,
    title: title ?? (firstPrompt ? firstPrompt.split(/\r?\n/)[0].slice(0, 80) : null),
    cwd,
    lastReply,
    branch,
    open: open && { id: open.id, name: open.name, summary: open.summary, time: open.time,
      questions: open.name === 'AskUserQuestion' ? open.input.questions ?? [] : null },
  };
}

// ---------- the context gauge ----------
// How full a session's context is, turn by turn. Sources (checked Oct 4 2026):
// - Windows: the claude-api skill's model table (cached 2026-09-25) gives 1M for
//   Fable 5/5.1, Mythos 5/5.1, Opus 5.5/5/4.8/4.7/4.6, Sonnet 5.5/5/4.6, and 200K
//   for Haiku 4.5 and the older models. Claude Code's docs (code.claude.com/docs/
//   en/model-config, "Extended context") say Opus 4.6 and Sonnet 4.6 reach 1M
//   only through their `[1m]` variant, so in Claude Code they are 200K without it.
// - Transcripts record the API id in message.model (claude-opus-5-5, never the
//   `[1m]` suffix), so a 4.6 model past 200K is taken to be on its 1M variant.
//   Replies Claude Code makes up itself (errors) say model "<synthetic>".
// - Auto-compact (same page, "Default auto-compact thresholds"): a native 1M
//   window compacts "at about 967K tokens by default"; other sessions compact when
//   the conversation reaches the model's limit. CLAUDE_CODE_AUTO_COMPACT_WINDOW
//   and CLAUDE_AUTOCOMPACT_PCT_OVERRIDE (docs/en/env-vars) change that inside the
//   session, which the board can't see, so LANES_AUTOCOMPACT_PCT sets the marker
//   here instead, as a percentage of the window.
// - Compaction lines: a `system` entry with subtype "compact_boundary"
//   (compactMetadata { trigger, preTokens }), then a `user` entry with
//   isCompactSummary. No compaction has happened in this PC's transcripts yet, so
//   both are taken as markers and a pair counts once.
// - One API reply is written as one line per content block, all with the same
//   message.id and usage, so a reply is one point.

export const ONE_M = 1_000_000;
export const DEFAULT_WINDOW = 200_000;
export const NATIVE_1M_COMPACT_PCT = 96.7;
const WINDOWS = [
  [/claude-(fable|mythos)-/, ONE_M],
  [/claude-opus-(5|4-[78])\b/, ONE_M],
  [/claude-sonnet-5\b/, ONE_M],
];
const envNumber = (v) => (Number(v) > 0 ? Number(v) : null);

// The context window a model id runs with: LANES_CONTEXT_WINDOW, then a `[1m]`
// suffix, then the table, then 200K.
export function contextWindowFor(model, env = {}) {
  const forced = envNumber(env.LANES_CONTEXT_WINDOW);
  if (forced) return forced;
  const m = String(model ?? '').toLowerCase();
  if (m.endsWith('[1m]')) return ONE_M;
  return WINDOWS.find(([re]) => re.test(m))?.[1] ?? DEFAULT_WINDOW;
}

// Where Claude Code compacts on its own, in tokens.
export function autoCompactAt(window, env = {}) {
  const pct = envNumber(env.LANES_AUTOCOMPACT_PCT);
  if (pct && pct <= 100) return Math.round((window * pct) / 100);
  return window >= ONE_M ? Math.round((window * NATIVE_1M_COMPACT_PCT) / 100) : window;
}

// At most `max` points of a { t, tokens } series: the first and newest, the
// points either side of every compaction (times), and the highest point of each
// equal slice of the rest.
export function downsample(series, compactions = [], max = 120) {
  if (series.length <= max) return series.slice();
  const must = new Set([0, series.length - 1]);
  for (const c of compactions) {
    const after = series.findIndex((p) => p.t > c);
    if (after > 0) { must.add(after - 1); must.add(after); }
  }
  const picked = new Set([...must].sort((a, b) => a - b).slice(-max));
  const slices = max - picked.size;
  for (let s = 0; s < slices; s++) {
    let best = -1;
    for (let i = Math.floor((s * series.length) / slices); i < Math.floor(((s + 1) * series.length) / slices); i++) {
      if (!picked.has(i) && (best < 0 || series[i].tokens > series[best].tokens)) best = i;
    }
    if (best >= 0) picked.add(best);
  }
  return [...picked].sort((a, b) => a - b).map((i) => series[i]);
}

const KEEP = 1000; // points a tracker holds before it thins them to half
const SHOWN = 120;

// Fed a transcript's text in order, in chunks of any size (the last line of a
// chunk may be cut off and finished by the next; with { cut: true } the chunk
// starts mid-line and its first line is skipped). view() is the gauge, or null
// before the first reply with usage.
export function contextTracker(env = {}) {
  let carry = '';
  let skipping = false;
  let model = null;
  let lastId = null;
  let compactedSinceTurn = false;
  let shown = null;
  let series = [];
  let compactions = [];
  const bigger = new Set(); // models seen past their table window

  const line = (text) => {
    if (!text.includes('"usage"') && !text.includes('compact_boundary') && !text.includes('isCompactSummary')) return;
    let o;
    try { o = JSON.parse(text); } catch { return; }
    if (o.isSidechain) return;
    const t = Date.parse(o.timestamp) || null;
    if ((o.type === 'system' && o.subtype === 'compact_boundary') || (o.type === 'user' && o.isCompactSummary)) {
      if (!compactedSinceTurn) compactions = [...compactions.slice(-199), t];
      compactedSinceTurn = true;
      shown = null;
      return;
    }
    const u = o.type === 'assistant' ? o.message?.usage : null;
    if (!u || o.message.model === '<synthetic>') return;
    const tokens = (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0);
    model = o.message.model ?? model;
    if (tokens > contextWindowFor(model)) bigger.add(model);
    if (o.message.id && o.message.id === lastId) series[series.length - 1] = { t: series.at(-1).t, tokens };
    else series.push({ t, tokens });
    lastId = o.message.id ?? null;
    compactedSinceTurn = false;
    if (series.length > KEEP) series = downsample(series, compactions, KEEP / 2);
    shown = null;
  };

  return {
    feed(text, { cut = false } = {}) {
      if (cut) { carry = ''; skipping = true; }
      if (skipping) {
        const nl = text.indexOf('\n');
        if (nl < 0) return;
        text = text.slice(nl + 1);
        skipping = false;
      }
      const lines = (carry + text).split('\n');
      carry = lines.pop();
      for (const l of lines) if (l.trim()) line(l);
    },
    size: () => series.length,
    view() {
      if (!series.length) return null;
      if (shown) return shown;
      let window = contextWindowFor(model, env);
      if (window < ONE_M && !envNumber(env.LANES_CONTEXT_WINDOW) && bigger.has(model)) window = ONE_M;
      const { t, tokens } = series.at(-1);
      // Compacted since the last reply: the old fill is gone and the new one
      // comes with the next reply, so tokens and pct are null until then.
      const fill = compactedSinceTurn
        ? { compacted: true, tokens: null, pct: null, before: tokens, updated: compactions.at(-1) ?? t }
        : { compacted: false, tokens, pct: Math.round((tokens / window) * 1000) / 10, before: null, updated: t };
      shown = {
        model, window, autoCompactAt: autoCompactAt(window, env), ...fill,
        series: downsample(series, compactions, SHOWN), compactions: compactions.slice(),
      };
      return shown;
    },
  };
}

// ---------- the relay (relay-hook.mjs on the session's side) ----------

export const SESSION_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
// ---------- turn ends and the inbox ----------
// What the owner sends a session (a reply, or a command's fixed words) reaches
// it whole: the hooks pass it on as it is, so they stay free of the wording.
// It waits in the session's inbox (inbox/<session>/ in the relay folder), where
// the stop hook hands the oldest over before the session's next tool and the
// relay hook the rest at its next turn end. Approvals aren't among the
// commands: since Oct 6 the owner gives them in the Claude app.

export const COMMANDS = {
  // The shot lands on the session's page through `npm run post` (post.mjs).
  show: "The owner asks from the Project Manager: show me what you're working on. Capture a shot or a short clip of it and post it to your page "
    + 'with `npm run post -- <file> --caption "<one line>"`, or say in one line that there\'s nothing to show yet.',
};

// { text } (the owner's own words) or { command } (a key of COMMANDS), worded for the session.
export function ownerMessage({ text, command } = {}) {
  if (command != null) {
    if (!Object.hasOwn(COMMANDS, command)) throw new Error('No such command');
    return COMMANDS[command];
  }
  const t = String(text ?? '').trim();
  if (!t) throw new Error('Type a reply first');
  return `The owner replied from the Project Manager:\n\n${t.slice(0, 20000)}`;
}

// When a message reaches its session: before its next step (it is at work, so
// the stop hook sees its next tool call), or at its next turn end (it is idle,
// or asleep in the app).
export function deliveryOf({ active }) {
  return active ? 'next-step' : 'turn-end';
}

// The app's turn summary (a session record's postTurnSummary), when it is about
// the turn that just ended: it names that turn's last reply (lastReply from
// parseTranscript). The app writes it a moment after the turn ends, so until
// then the record still holds the turn before's.
const SUMMARY_LABELS = { completed: 'Done', review_ready: 'Ready for review', blocked: 'Blocked', needs_input: 'Needs input', failed: 'Failed' };
export function turnSummary(raw, lastReply) {
  if (!raw?.summarizes_uuid || raw.summarizes_uuid !== lastReply) return null;
  const status = String(raw.status_category ?? '');
  return { status, label: SUMMARY_LABELS[status] ?? status.replace(/_/g, ' '), detail: String(raw.status_detail ?? ''), action: raw.needs_action || null };
}

// ---------- the Away switch ----------
// While Away is on, the bell's news goes to the lock screen of every phone that
// turned notifications on (push-api.mjs); while it's off, it stays on the
// pages. It lives in the relay folder's away.json: { on, since, from }. It
// holds nothing for the owner: since Oct 6 sessions always ask in the app.

// The Away file as written when the owner flips the switch from a page.
export function awaySwitch(body, ua, now = Date.now()) {
  return { on: body?.on === true, since: now, from: isPhone(ua) ? 'phone' : 'PC' };
}

// The Away file as read: anything but a clear "on" is off.
export function awayOf(raw) {
  if (raw?.on !== true) return { on: false, since: Number(raw?.since) || null, from: raw?.from ?? null };
  return { on: true, since: Number(raw.since) || null, from: raw.from ?? null };
}

// ---------- the session page ----------

// What a session is doing, for its card and page: asked in the app (a question
// in the app's own dialog), ended (End work, until it is woken again: at work
// more than two minutes after), at work, or idle. s: { asking, active, activity, endedAt }.
// The pages word them (sessions-ui.mjs STATE_LABELS).
const ENDED_GRACE_MS = 2 * 60 * 1000;
export function sessionState(s) {
  if (s.asking) return 'asked';
  if (s.endedAt && !(s.active && s.activity > s.endedAt + ENDED_GRACE_MS)) return 'ended';
  return s.active ? 'working' : 'idle';
}

// When the session's work was last ended (the stop list's entries, as End work
// writes them): an entry naming it, or one whose lane worktree it works in.
// A relaunch cancels an entry. Null when never.
export function endedAtOf(entries, { id, cwd }) {
  const norm = (p) => String(p ?? '').replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
  const dir = norm(cwd);
  let at = null;
  for (const e of entries ?? []) {
    if (e.cancelledAt) continue;
    const named = (e.sessions ?? []).includes(id);
    const tree = e.worktree ? norm(e.worktree) : null;
    const inside = !!tree && !!dir && (dir === tree || dir.startsWith(`${tree}/`));
    if ((named || inside) && (at === null || e.requestedAt > at)) at = e.requestedAt;
  }
  return at;
}

// What the stop hook tells a session after the owner pressed Stop now: each tool
// call it tries is refused with this, until its turn ends.
export const STOP_NOW = 'The owner pressed Stop now in the Project Manager. Stop here: run nothing more, '
  + 'and end your turn with one line saying where you stopped. The owner will tell you what to do next.';

// The session's Remote Control address, from the app's session record (the
// spike, plan task 3): its newest bridge session, opened at claude.ai/code,
// which the Claude app on the phone takes over. Null when Remote Control was
// never on for it.
export function remoteLinkOf(record) {
  const id = (record?.bridgeSessionIds ?? []).at(-1);
  return typeof id === 'string' && /^[\w-]+$/.test(id) ? `https://claude.ai/code/${id}` : null;
}
