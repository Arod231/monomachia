// Pure pieces both board pages draw with (index.html and m.html load it from
// /ui.mjs): the context gauge and its chart, and the roadmap's summary
// (tests/lanes-board-ui.test.mjs checks them), and how a launch is getting on
// (tests/lanes-board-launcher.test.mjs). No DOM: everything returns data or HTML.

const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const trim = (n) => String(Number(n.toFixed(1)));

// ---------- the context gauge ----------
// ctx is a session's context from /data or /sessions (sessions.mjs):
// { model, tokens, window, pct, autoCompactAt, series: [{ t, tokens }], compactions: [t] };
// compacted since its last reply, it has compacted: true, tokens and pct null
// and `before`, the fill it had.

// 143210 -> '143k', 1250000 -> '1.3M'.
export function fmtTokens(n) {
  if (n < 1000) return String(Math.round(n));
  if (n < 10_000) return `${trim(n / 1000)}k`;
  if (n < 999_500) return `${Math.round(n / 1000)}k`;
  return `${trim(n / 1_000_000)}M`;
}

// Calm under 60% of the window, amber to 85%, red above that or past the
// auto-compact line.
export function gaugeLevel(ctx) {
  if (!ctx) return null;
  if (ctx.compacted) return 'calm';
  if (ctx.pct > 85 || ctx.tokens >= ctx.autoCompactAt) return 'high';
  return ctx.pct >= 60 ? 'warn' : 'calm';
}

const gaugeTitle = (ctx) => (ctx.compacted
  ? `Context: compacted from ${fmtTokens(ctx.before ?? 0)} of ${fmtTokens(ctx.window)} tokens; the next reply shows the new fill`
  : `Context: ${fmtTokens(ctx.tokens)} of ${fmtTokens(ctx.window)} tokens (${ctx.pct}%)`)
  + `, auto-compacts at ${fmtTokens(ctx.autoCompactAt)}${ctx.model ? ` · ${ctx.model}` : ''}`;
// The compact meter's percent: 100% only once the window is full.
const shortPct = (ctx) => (ctx.tokens < ctx.window ? Math.min(99, Math.round(ctx.pct)) : Math.round(ctx.pct));

// A meter and its percent. live: the session is at work now (drawn 'fresh',
// else 'stale': muted, its last value). full: also the tokens, the exact
// percent and a tick where Claude Code compacts. Just compacted: an empty
// meter that says so. The pages style .gauge with their own colours.
export function gaugeHtml(ctx, { live = false, full = false } = {}) {
  if (!ctx) return '';
  const fill = ctx.compacted ? 0 : Math.min(100, Math.max(0, ctx.pct));
  const tick = Math.min(100, (ctx.autoCompactAt / ctx.window) * 100);
  const cls = `gauge${full ? ' full' : ''} ${gaugeLevel(ctx)} ${live ? 'fresh' : 'stale'}`;
  const meter = `<span class="gm"><i style="width:${trim(fill)}%"></i>${full && tick < 100 ? `<b class="gt" style="left:${trim(tick)}%"></b>` : ''}</span>`;
  if (!full) return `<span class="${cls}" title="${esc(gaugeTitle(ctx))}">${meter}<span class="gp">${ctx.compacted ? 'compacted' : `${shortPct(ctx)}%`}</span></span>`;
  const fig = ctx.compacted ? `<b>Compacted</b> from ${fmtTokens(ctx.before ?? 0)} / ${fmtTokens(ctx.window)}`
    : `<b>${ctx.pct}%</b> ${fmtTokens(ctx.tokens)} / ${fmtTokens(ctx.window)}`;
  return `<span class="${cls}" title="${esc(gaugeTitle(ctx))}">${meter}<span class="gp">${fig}</span>`
    + `<span class="gx">auto-compacts at ${fmtTokens(ctx.autoCompactAt)}${ctx.model ? ` · ${esc(ctx.model)}` : ''}</span></span>`;
}

// The series as points on a w x h chart: x by time (evenly when the turns share
// one time), y by the share of the window filled, clamped to the chart.
export function sparkPoints(ctx, w, h) {
  const s = ctx?.series ?? [];
  if (!s.length) return [];
  const t0 = s[0].t, span = s.at(-1).t - t0;
  return s.map((p, i) => ({
    x: span > 0 ? ((p.t - t0) / span) * w : s.length > 1 ? (i / (s.length - 1)) * w : w,
    y: h - Math.min(1, p.tokens / ctx.window) * h,
    t: p.t, tokens: p.tokens,
  }));
}

const clock = (t) => { try { return new Date(t).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); } catch { return ''; } };

// The context turn by turn as an SVG that stretches to its container: the line
// and its fill, a dashed auto-compact line, a small tick at each compaction and
// a hover title on each turn.
export function sparkSvg(ctx, { width = 300, height = 44 } = {}) {
  const pts = sparkPoints(ctx, width, height);
  if (!pts.length) return '';
  const f = (n) => Number(n.toFixed(1));
  const line = pts.map((p, i) => `${i ? 'L' : 'M'}${f(p.x)},${f(p.y)}`).join(' ');
  const area = `${line} L${f(pts.at(-1).x)},${height} L${f(pts[0].x)},${height} Z`;
  const t0 = pts[0].t, span = pts.at(-1).t - t0;
  const ticks = span > 0 ? (ctx.compactions ?? []).filter((t) => t >= t0 && t <= pts.at(-1).t)
    .map((t) => { const x = f(((t - t0) / span) * width); return `<line class="sc" x1="${x}" x2="${x}" y1="${height - 9}" y2="${height}"/>`; }) : [];
  const ay = f(height - Math.min(1, ctx.autoCompactAt / ctx.window) * height);
  const auto = ay > 0.5 ? `<line class="sa" x1="0" x2="${width}" y1="${ay}" y2="${ay}"/>` : '';
  // Hover columns: each turn owns the width halfway to its neighbours.
  const cols = pts.map((p, i) => {
    const a = i ? (pts[i - 1].x + p.x) / 2 : 0;
    const b = i < pts.length - 1 ? (p.x + pts[i + 1].x) / 2 : width;
    return `<rect class="sh" x="${f(a)}" y="0" width="${Math.max(0.5, f(b - a))}" height="${height}"><title>${esc(`${clock(p.t)} · ${fmtTokens(p.tokens)} (${trim((p.tokens / ctx.window) * 100)}%)`)}</title></rect>`;
  });
  return `<svg class="spark" viewBox="0 0 ${width} ${height}" preserveAspectRatio="none" width="100%" height="${height}" role="img" aria-label="${esc(`Context turn by turn, ${ctx.compacted ? 'just compacted' : `now ${fmtTokens(ctx.tokens)}`}`)}">`
    + `<path class="sf" d="${area}"/>${auto}<path class="sl" d="${line}"/>${ticks.join('')}${cols.join('')}</svg>`;
}

// ---------- the roadmap ----------

const OPEN = ['working', 'launched', 'ready', 'owner', 'blocked'];
const live = (t) => !!t && t.status !== 'moved' && t.status !== 'retired';

function countRefs(refs, statusOf) {
  const counts = { done: 0, open: 0, ...Object.fromEntries(OPEN.map((s) => [s, 0])) };
  for (const ref of refs) {
    const s = statusOf(ref);
    if (s in counts) counts[s]++;
    if (s !== 'done') counts.open++;
  }
  return counts;
}

// A plan shown the way roadmapView (plans.mjs) shows a phase, for the open plans
// while the roadmap has no copy: its live tasks in build order, counts, five
// ready tasks next and the lanes on it.
export function planAsPhase(p, lanes) {
  const order = [...new Set([...p.stages.flatMap((s) => s.ids), ...Object.keys(p.tasks)])];
  const refs = order.filter((id) => live(p.tasks[id])).map((id) => `${p.key}:${id}`);
  const statusOf = (ref) => p.tasks[ref.slice(p.key.length + 1)].status;
  const counts = countRefs(refs, statusOf);
  const on = lanes.filter((l) => !l.ended && l.plan === p.key && (l.working || l.scope?.length));
  return {
    n: null, name: p.name, plan: p.key, alongside: null, current: false, refs, unknown: [], waiting: [], total: refs.length, counts,
    next: refs.filter((r) => statusOf(r) === 'ready').slice(0, 5).map((ref) => ({ ref, title: p.tasks[ref.slice(p.key.length + 1)].title, status: 'ready' })),
    lanes: on.map((l) => ({ folder: l.folder, branch: l.branch, task: l.task ? `${l.plan}:${l.task}` : null, working: !!l.working })),
  };
}

// Until the roadmap is committed: each open plan as a phase, the first with
// open tasks current.
export function fallbackPhases(data) {
  const phases = data.plans.filter((p) => !p.closed).map((p) => planAsPhase(p, data.lanes ?? []));
  const first = phases.find((ph) => ph.counts.open > 0);
  if (first) first.current = true;
  return phases;
}

// done: no open task left (and no plan still to write); unwritten: nothing
// but tasks in plans with no copy yet; empty: nothing at all.
export function phaseState(ph) {
  if (ph.current) return 'current';
  if (!ph.total) return ph.waiting?.length ? 'unwritten' : 'empty';
  return ph.counts.open || ph.waiting?.length ? 'later' : 'done';
}

// The summary tiles: the current phase(s) (an alongside phase with its partner,
// each task once), milestone 1, what's ready now, and the lanes at work.
export function roadmapKpis(data) {
  const fallback = !data.roadmap;
  const phases = data.roadmap?.phases ?? fallbackPhases(data);
  const current = phases.filter((ph) => ph.current);
  const byKey = new Map(data.plans.map((p) => [p.key, p]));
  const statusOf = (ref) => { const i = ref.indexOf(':'); return byKey.get(ref.slice(0, i))?.tasks[ref.slice(i + 1)]?.status; };
  const refs = [...new Set(current.flatMap((ph) => ph.refs))].filter((r) => statusOf(r));
  const counts = countRefs(refs, statusOf);
  const m1 = byKey.get('m1');
  const lanes = data.lanes ?? [];
  return {
    current: { names: current.map((ph) => ph.name), fallback, total: refs.length, done: counts.done, open: counts.open,
      ready: counts.ready, blocked: counts.blocked, owner: counts.owner, working: counts.working },
    readyRefs: refs.filter((r) => statusOf(r) === 'ready'),
    m1: m1 ? { done: m1.counts.done ?? 0, total: m1.total, ready: m1.counts.ready ?? 0 } : null,
    activeLanes: lanes.filter((l) => l.activity === 'active').length,
    onTask: lanes.filter((l) => l.working).length,
  };
}

// ---------- a launch's start ----------
// How a launched session is getting on, from its launch's `start` in /data
// (launcher.mjs startView): null when there's nothing to say, else one line for
// the pages. Every reason launcher.mjs REASONS lists has its own wording.
const WHY_WAITING = {
  'no-app': "the Claude app didn't open",
  'no-draft': "the prompt didn't show up in the Claude app",
  'no-send': "the Claude app's Send button couldn't be pressed",
  'not-taken': "the Claude app didn't take the prompt",
  trust: 'the Claude app is asking to trust a different folder',
  error: "pressing Send went wrong (the Project Manager's log says why)",
  lost: 'Send was pressed, but no session appeared',
};
export function launchStartText(start) {
  if (!start) return null;
  if (start.state === 'started') return 'Started on the PC';
  if (start.state === 'starting') return 'Starting on the PC: the Project Manager presses Send in the Claude app';
  if (start.reason === 'locked') return 'Waiting: the PC is locked. It starts when the PC is unlocked.';
  return `Couldn't start: ${WHY_WAITING[start.reason] ?? 'something unexpected happened'}. Try again, or send it from the Claude app on the PC.`;
}

// ---------- a new session ----------
// The "New session" button's line: how the newest session it started (a launch
// with kind 'session' in /data) is getting on, until it has been started this
// long; null when there's nothing to say.
export const NEW_SESSION_SHOW_MS = 15 * 60 * 1000;
export function newSessionStatus(launches, now) {
  const l = (launches ?? []).filter((x) => x.kind === 'session').at(-1);
  if (!l?.start || l.endedAt) return null;
  const s = l.start;
  if (s.state === 'started') {
    if (now - l.time >= NEW_SESSION_SHOW_MS) return null;
    return { id: l.id, state: 'started', session: l.session, retry: false, text: 'Started: send it your prompts from the Claude app' };
  }
  return { id: l.id, state: s.state, session: l.session, retry: !!s.retry, text: launchStartText(s) };
}
