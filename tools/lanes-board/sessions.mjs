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
// when the transcript names them, and the tool call still waiting on a result.
export function parseTranscript(lines, { limit = 400 } = {}) {
  const entries = [];
  const results = new Map(); // tool_use id -> result entry
  let title = null;
  let cwd = null;
  let firstPrompt = null;
  for (const line of lines) {
    let o;
    try { o = JSON.parse(line); } catch { continue; }
    if (o.type === 'custom-title' && o.customTitle) title = o.customTitle;
    if (o.cwd) cwd = o.cwd;
    if (o.isSidechain || o.isMeta) continue;
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
export const PENDING_ID = /^[a-z0-9]{4,16}-[a-z0-9]{4,16}$/;

// AskUserQuestion's answers, as the tool takes them: question text -> the
// chosen label, several labels joined with ", ".
export function questionAnswers(questions, picks) {
  const answers = {};
  questions.forEach((q, i) => {
    const p = picks?.[i];
    const labels = (Array.isArray(p) ? p : p == null ? [] : [p]).map((s) => String(s).trim()).filter(Boolean);
    if (!labels.length) throw new Error(`No answer for "${q.question}"`);
    if (!q.multiSelect && labels.length > 1) throw new Error(`"${q.question}" takes one answer`);
    answers[q.question] = labels.join(', ');
  });
  return answers;
}

// How a question is answered: 'allow' passes the tool its input back with an
// `answers` map, as Claude Code's own hosts answer it; 'decline' (the spec's
// fallback, should the spike show a hook can't answer that way) refuses the
// tool with the answers as the reason, which Claude reads and follows.
export const QUESTION_ANSWER = 'allow';

// The board's answer to a pending item, checked, in the shape the hook reads.
// body: { picks: [label | [labels]] } for a question (an Other's free text is a
// label like any other), or { reply } to answer it in the owner's own words.
export function relayAnswer(pending, body, { questionAnswer = QUESTION_ANSWER } = {}) {
  if (pending.kind === 'stop') {
    const text = String(body.reply ?? '').trim();
    if (body.release) return { release: true };
    if (!text) throw new Error('Type a reply first');
    return { reply: text.slice(0, 20000) };
  }
  if (body.release) return { release: true };
  if (pending.kind === 'question') {
    const reply = String(body.reply ?? '').trim();
    if (reply) {
      return { behavior: 'deny', message: `The owner answered from the Project Manager instead of picking an option:\n\n${reply.slice(0, 20000)}` };
    }
    const questions = pending.input?.questions ?? [];
    const answers = questionAnswers(questions, body.picks);
    if (questionAnswer === 'decline') {
      const lines = Object.entries(answers).map(([q, a]) => `- ${q} → ${a}`);
      return { behavior: 'deny', message: `The owner answered from the Project Manager:\n${lines.join('\n')}` };
    }
    return { behavior: 'allow', updatedInput: { ...pending.input, answers } };
  }
  if (body.behavior === 'allow') {
    const out = { behavior: 'allow' };
    if (body.always && Array.isArray(pending.suggestions) && pending.suggestions.length) out.updatedPermissions = pending.suggestions;
    return out;
  }
  if (body.behavior === 'deny') {
    const why = String(body.message ?? '').trim();
    return { behavior: 'deny', message: why ? `The owner declined from the Project Manager: ${why.slice(0, 4000)}` : 'The owner declined this from the Project Manager.' };
  }
  throw new Error('Allow or deny?');
}

// ---------- the Away switch ----------
// While Away is on, the relay hook holds every session's questions, permission
// prompts and turn ends for the Project Manager; while it's off they stay in
// the app. It lives in the relay folder's away.json: { on, since, from }.

// The Away file as written when the owner flips the switch from a page.
export function awaySwitch(body, ua, now = Date.now()) {
  return { on: body?.on === true, since: now, from: isPhone(ua) ? 'phone' : 'PC' };
}

// The Away file as read: anything but a clear "on" is off.
export function awayOf(raw) {
  if (raw?.on !== true) return { on: false, since: Number(raw?.since) || null, from: raw?.from ?? null };
  return { on: true, since: Number(raw.since) || null, from: raw.from ?? null };
}

// A held item whose session is gone. The spike (plan task 3) found that a
// deleted session's hook keeps holding, so a live hook doesn't mean a live
// session: the item goes once its transcript is deleted, or its app record is
// deleted after the board had seen one (sessions run outside the app have none).
export function heldOrphaned(p, { transcriptExists, hasRecord, sawRecord }) {
  if (p.transcript && !transcriptExists) return true;
  return !!sawRecord && !hasRecord;
}
