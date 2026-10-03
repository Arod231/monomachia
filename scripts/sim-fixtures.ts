// Writes the fixtures that check the GDScript port of the rules foundations
// against the TypeScript rules: game/tests/fixtures/{rng,moves,math}.json.
//
// usage: npm run godot:fixtures   (or: npx tsx scripts/sim-fixtures.ts)
//
// Floats that must match bit for bit are stored as their IEEE-754 bits in hex
// ("bits"), because Godot's JSON number parser is not guaranteed to round the
// same way as V8; a readable "value" sits next to them.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Rng } from '../src/sim/rng';
import { WEAPONS, PLAYABLE_WEAPONS, COUNTER_LUNGE, ULT_HITS } from '../src/sim/moves';
import {
  angleBetween,
  clamp,
  dist2,
  easeInOut,
  easeOutCubic,
  fwd,
  len2,
  lerp,
  norm2,
  right,
  sign,
  turnToward,
  v3,
  wrapAngle,
  yawTo,
} from '../src/sim/math';
import { dirIndex, dirVector } from '../src/sim/input';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'game', 'tests', 'fixtures');

const bits = (x: number) => {
  const b = Buffer.alloc(8);
  b.writeDoubleBE(x);
  return b.toString('hex');
};
const exact = (x: number) => ({ value: x, bits: bits(x) });

/** JSON with one line per record: short values and flat records stay on one line. */
function format(x: unknown, ind = ''): string {
  const one = JSON.stringify(x);
  if (x === null || typeof x !== 'object') return one;
  const prim = (v: unknown) => v === null || typeof v !== 'object';
  const values: unknown[] = Array.isArray(x) ? x : Object.values(x);
  const flat = values.every((v) => prim(v) || (Array.isArray(v) && v.every(prim)));
  if (one.length <= 120 || flat) return one;
  const inner = ind + ' ';
  if (Array.isArray(x)) return '[\n' + x.map((v) => inner + format(v, inner)).join(',\n') + '\n' + ind + ']';
  const entries = Object.entries(x).map(([k, v]) => inner + JSON.stringify(k) + ': ' + format(v, inner));
  return '{\n' + entries.join(',\n') + '\n' + ind + '}';
}

function write(name: string, data: unknown) {
  mkdirSync(OUT, { recursive: true });
  const path = join(OUT, name);
  writeFileSync(path, format(data) + '\n');
  console.log(`wrote ${path}`);
}

// --- rng.json ---------------------------------------------------------------
// next(): the first 1,000 draws per seed, as uint32 (next() * 2^32 is exact).
// samples: a mixed sequence of int(), range(), chance() and pick() per seed.
const SEEDS = [1, 7, 99, 1234567];
const PICK_FROM = ['a', 'b', 'c', 'd', 'e'];
const next: Record<string, number[]> = {};
for (const s of SEEDS) {
  const r = new Rng(s);
  next[s] = Array.from({ length: 1000 }, () => r.next() * 4294967296);
}
const samples: Record<string, unknown[]> = {};
for (const s of [...SEEDS, -5, 4294967299]) {
  const r = new Rng(s);
  const out: unknown[] = [];
  for (let i = 0; i < 50; i++) {
    out.push({ int: r.int(-3, 3) });
    out.push({ range: exact(r.range(-2.5, 4)) });
    out.push({ chance: r.chance(0.3) });
    out.push({ pick: r.pick(PICK_FROM) });
    out.push({ int: r.int(1, 7) });
  }
  samples[s] = out;
}
const def = new Rng();
write('rng.json', {
  seeds: SEEDS,
  next,
  pickFrom: PICK_FROM,
  samples,
  defaultSeedFirst: Array.from({ length: 10 }, () => def.next() * 4294967296),
});

// --- moves.json ---------------------------------------------------------------
// Every weapon and every scripted ultimate hit after finalizeMoves, with the TS
// (camelCase) keys. A key that is missing was undefined in the TS.
write('moves.json', { WEAPONS, PLAYABLE_WEAPONS, COUNTER_LUNGE, ULT_HITS });

// --- math.json ----------------------------------------------------------------
const angles = [0, 1, -1, 3, -3, 3.2, -3.2, 7, -7, 100, -100, Math.PI, -Math.PI, Math.PI * 2 + 0.1, 1000];
const turns: [number, number, number][] = [
  [0, 1, 0.2],
  [0, 1, 2],
  [3, -3, 0.5],
  [-3, 3, 0.5],
  [0.5, 0.5 + Math.PI, 0.3],
  [2, -2, 14 / 60],
  [-2.9, 2.9, 3 / 60],
  [1, 1, 0.1],
];
const points: [number, number, number, number][] = [
  [0, 0, 1, 1],
  [0, -1.1, 0, 1.1],
  [2, 3, -4, 5],
  [-1.5, 0.25, -1.5, -7],
  [0.3, 0.3, 0.3, 0.3],
];
const vecs: [number, number][] = [
  [0, 0],
  [3, 4],
  [1e-10, 0],
  [-0.2, 0.9],
  [5, -12],
];
const ts = [0, 0.1, 0.25, 0.5, 0.75, 0.9, 1];
const sticks: [number, number][] = [
  [0, 0],
  [0, 1],
  [0.3, 0.2],
  [1, 0],
  [0.7, 0.7],
  [0, -1],
  [-1, 0],
  [-0.7, 0.7],
  [0.38268343236508984, 0.9238795325112867],
  [-0.5, -0.5],
];
write('math.json', {
  wrapAngle: angles.map((a) => [a, wrapAngle(a)]),
  turnToward: turns.map(([c, t, m]) => [c, t, m, turnToward(c, t, m)]),
  angleBetween: turns.map(([c, t]) => [c, t, angleBetween(c, t)]),
  yawTo: points.map(([ax, az, bx, bz]) => [ax, az, bx, bz, yawTo(v3(ax, 0, az), v3(bx, 0, bz))]),
  dist2: points.map(([ax, az, bx, bz]) => [ax, az, bx, bz, dist2(v3(ax, 5, az), v3(bx, -2, bz))]),
  len2: vecs.map(([x, z]) => [x, z, len2(x, z)]),
  norm2: vecs.map(([x, z]) => {
    const n = norm2(x, z);
    return [x, z, n.x, n.z];
  }),
  fwd: angles.map((a) => {
    const f = fwd(a);
    return [a, f.x, f.z];
  }),
  right: angles.map((a) => {
    const r = right(a);
    return [a, r.x, r.z];
  }),
  easeOutCubic: ts.map((t) => [t, easeOutCubic(t)]),
  easeInOut: ts.map((t) => [t, easeInOut(t)]),
  clamp: [
    [-1, 0, 1, clamp(-1, 0, 1)],
    [0.5, 0, 1, clamp(0.5, 0, 1)],
    [2, 0, 1, clamp(2, 0, 1)],
  ],
  lerp: [
    [2, 6, 0.25, lerp(2, 6, 0.25)],
    [-1, 1, 0.5, lerp(-1, 1, 0.5)],
  ],
  sign: [-2, -0, 0, 3].map((v) => [v, sign(v)]),
  round: [-0.5, 0.5, 2.5, -2.5, 1.5, -1.5, 3.7, -3.7, 0.49999999999999994, -0.49999999999999994].map((v) => [
    v,
    Math.round(v),
  ]),
  dirIndex: sticks.map(([mx, my]) => [mx, my, dirIndex(mx, my)]),
  dirVector: [-1, 0, 1, 2, 3, 4, 5, 6, 7].map((d) => {
    const v = dirVector(d);
    return [d, v.mx, v.my];
  }),
});
