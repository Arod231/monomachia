// The lanes board's Graph view: lays out one plan's tasks as nodes joined by
// their "Blocked by" lines. Pure, no DOM: index.html draws the result as SVG,
// and tests/lanes-board.test.mjs checks it.
//
// One band per stage, in build order, top to bottom. Inside a band a task sits
// one column right of its latest blocker in the same stage, so a stage's chain
// reads left to right; tasks in a column are ordered by where their blockers
// sit, so edges cross as little as cheaply possible. Blockers from other plans
// get a band of their own at the top.

export const NODE_W = 184;
export const NODE_H = 44;
const COL_GAP = 46;
const ROW_GAP = 10;
const BAND_GAP = 30;
const BAND_HEAD = 28;
const PAD = 16;

// plan: a /data plan ({ key, stages, tasks }); hide: statuses left out (say
// 'retired', 'done'). A hidden blocker's edge is dropped: a done one no longer
// blocks anything.
export function layoutPlan(plan, { hide = [] } = {}) {
  const hidden = new Set(hide);
  const shown = (id) => !!plan.tasks[id] && !hidden.has(plan.tasks[id].status);
  const order = new Map(plan.stages.flatMap((s) => s.ids).map((id, i) => [id, i]));
  const stageOf = new Map();
  plan.stages.forEach((s, i) => s.ids.forEach((id) => { if (!stageOf.has(id)) stageOf.set(id, i); }));

  // Edges, and the other plans' tasks they need.
  const edges = [];
  const external = new Map(); // ref -> { label, done }
  for (const [id, t] of Object.entries(plan.tasks)) {
    if (!shown(id) || !stageOf.has(id)) continue;
    for (const b of t.blockers) {
      const [k, bid] = b.ref.split(':');
      if (k === plan.key) {
        if (shown(bid) && stageOf.has(bid)) edges.push({ from: bid, to: id, done: b.done });
      } else if (!(b.done && hidden.has('done'))) {
        external.set(b.ref, { label: b.label, done: b.done });
        edges.push({ from: b.ref, to: id, done: b.done });
      }
    }
  }

  const bands = [];
  if (external.size) bands.push({ n: null, name: 'From other plans', ids: [...external.keys()] });
  for (const s of plan.stages) {
    const ids = s.ids.filter((id) => shown(id) && stageOf.get(id) === plan.stages.indexOf(s));
    if (ids.length) bands.push({ n: s.n, name: s.name, ids });
  }

  const into = new Map(); // id -> blockers shown
  for (const e of edges) (into.get(e.to) ?? into.set(e.to, []).get(e.to)).push(e.from);

  const nodes = new Map();
  let y = PAD;
  let width = 0;
  for (const band of bands) {
    const inBand = new Set(band.ids);
    // Column: the longest chain of same-band blockers before it.
    const col = new Map();
    const colOf = (id, seen = new Set()) => {
      if (col.has(id)) return col.get(id);
      if (seen.has(id)) return 0; // a loop in the plan: don't hang on it
      seen.add(id);
      const before = (into.get(id) ?? []).filter((b) => inBand.has(b));
      const c = before.length ? 1 + Math.max(...before.map((b) => colOf(b, seen))) : 0;
      col.set(id, c);
      return c;
    };
    const columns = [];
    for (const id of band.ids) (columns[colOf(id)] ??= []).push(id);

    const top = y + BAND_HEAD;
    let rows = 0;
    columns.forEach((ids = [], c) => {
      // Nearest the blockers already placed, else plan order.
      const pull = (id) => {
        const ys = (into.get(id) ?? []).map((b) => nodes.get(b)?.y).filter((v) => v !== undefined);
        return ys.length ? ys.reduce((a, b) => a + b, 0) / ys.length : Infinity;
      };
      const sorted = [...ids].sort((a, b) => (pull(a) - pull(b)) || ((order.get(a) ?? 0) - (order.get(b) ?? 0)) || (a < b ? -1 : 1));
      sorted.forEach((id, r) => {
        const ext = external.get(id);
        nodes.set(id, {
          id, x: PAD + c * (NODE_W + COL_GAP), y: top + r * (NODE_H + ROW_GAP), w: NODE_W, h: NODE_H,
          band: bands.indexOf(band), external: !!ext, label: ext?.label ?? id, done: ext?.done ?? null,
        });
      });
      rows = Math.max(rows, sorted.length);
      width = Math.max(width, PAD + (c + 1) * (NODE_W + COL_GAP) - COL_GAP + PAD);
    });
    band.y = y;
    band.h = BAND_HEAD + rows * (NODE_H + ROW_GAP) - ROW_GAP + 8;
    y += band.h + BAND_GAP;
  }

  return {
    nodes: [...nodes.values()],
    edges,
    bands: bands.map(({ n, name, y: by, h }) => ({ n, name, y: by, h })),
    width: Math.max(width, NODE_W + 2 * PAD),
    height: y - BAND_GAP + PAD,
  };
}

// Everything a task waits on (up) and everything waiting on it (down), however far.
export function related(edges, id) {
  const walk = (start, next) => {
    const seen = new Set();
    const stack = [start];
    while (stack.length) {
      for (const n of next(stack.pop())) if (!seen.has(n) && n !== start) { seen.add(n); stack.push(n); }
    }
    return seen;
  };
  const ups = new Map();
  const downs = new Map();
  for (const e of edges) {
    (ups.get(e.to) ?? ups.set(e.to, []).get(e.to)).push(e.from);
    (downs.get(e.from) ?? downs.set(e.from, []).get(e.from)).push(e.to);
  }
  return { up: walk(id, (n) => ups.get(n) ?? []), down: walk(id, (n) => downs.get(n) ?? []) };
}

// An edge's SVG path: left to right within a band, else top to bottom (or up,
// for the odd blocker in a later stage).
export function edgePath(a, b) {
  if (b.x > a.x + a.w / 2) {
    const x1 = a.x + a.w, y1 = a.y + a.h / 2, x2 = b.x, y2 = b.y + b.h / 2;
    const dx = Math.max(24, (x2 - x1) / 2);
    return `M${x1},${y1} C${x1 + dx},${y1} ${x2 - dx},${y2} ${x2},${y2}`;
  }
  const down = b.y > a.y;
  const x1 = a.x + a.w / 2, y1 = down ? a.y + a.h : a.y, x2 = b.x + b.w / 2, y2 = down ? b.y : b.y + b.h;
  const dy = Math.max(24, Math.abs(y2 - y1) / 2) * (down ? 1 : -1);
  return `M${x1},${y1} C${x1},${y1 + dy} ${x2},${y2 - dy} ${x2},${y2}`;
}
