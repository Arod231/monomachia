// Writes game/tests/fixtures/port.json: TypeScript reference values for
// game/tests/sim/test_port_regressions.gd, which checks the fixes made after
// the line-by-line review of the GDScript port: the math as V8 computes it and
// the tools' number formatting. The arena clamp, the whole-run hashes and the
// sentinel traces it also wrote retired in plan task 8.2, just before the
// first deliberate rule change made the Godot rules differ from the TypeScript.
//
// usage: npm run godot:fixtures   (or: npx tsx scripts/port-fixtures.ts)
//
// Every float is stored as its IEEE-754 bits in hex (big-endian, 16 digits),
// because Godot's JSON and float-literal parsers are not correctly rounded.
// The file is deterministic: random cases come from the sim's own Rng.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Rng } from '../src/sim/rng';
import { dirIndex } from '../src/sim/input';
import { DIR_DEADZONE } from '../src/sim/constants';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'game', 'tests', 'fixtures', 'port.json');

const dv = new DataView(new ArrayBuffer(8));
const bits = (x: number) => {
  dv.setFloat64(0, x);
  return dv.getBigUint64(0).toString(16).padStart(16, '0');
};
const fromBits = (b: bigint) => {
  dv.setBigUint64(0, BigInt.asUintN(64, b));
  return dv.getFloat64(0);
};
/** The neighbouring double k ulps away (k may be negative), for x > 0. */
const ulps = (x: number, k: number) => {
  dv.setFloat64(0, x);
  return fromBits(dv.getBigUint64(0) + BigInt(k));
};
const naiveHypot = (x: number, z: number) => Math.sqrt(x * x + z * z);

const rng = new Rng(20260930);
const uni = (lo: number, hi: number) => rng.range(lo, hi);

// --- Math.hypot -----------------------------------------------------------------
// Pairs where V8's Math.hypot differs from sqrt(x*x + z*z), plus special values.
const hypot: string[][] = [];
const hypotSpecial: [number, number][] = [
  [0, 0], [-0, -0], [3, 4], [-3, -4], [0, -5], [1e-320, 1e-320], [1e300, 1e300], [1e-300, 1e300],
  [Infinity, NaN], [NaN, -Infinity], [NaN, 1], [-Infinity, 2], [5e-324, 0],
];
for (const [x, z] of hypotSpecial) hypot.push([bits(x), bits(z), bits(Math.hypot(x, z))]);
while (hypot.length < hypotSpecial.length + 120) {
  const s = [0.01, 0.4, 1, 11.08, 30][hypot.length % 5];
  const x = uni(-s, s);
  const z = uni(-s, s);
  if (Math.hypot(x, z) !== naiveHypot(x, z)) hypot.push([bits(x), bits(z), bits(Math.hypot(x, z))]);
}

// --- Math.sin, Math.cos, Math.atan2 ---------------------------------------------
// V8 computes these with its fdlibm port. Arguments cover the sim's ranges, the
// medium (|x| < 2^19 pi/2) and large argument reductions, and special values.
const trigArgs: number[] = [
  0, -0, 1e-9, -1e-9, 1e-300, Math.PI / 4, Math.PI / 2, -Math.PI / 2, Math.PI, -Math.PI, 3 * Math.PI / 4,
  1.5707963267948966, 1.5707963267948963, 2.356194490192345, 7.0685834705770345, 1e6, -1e6, 823549.6,
  1e9, 1e15, 1e22, 1e100, -1e200, 1.7976931348623157e308, NaN, Infinity, -Infinity,
];
for (let i = 0; i < 400; i++) trigArgs.push(uni(-Math.PI, Math.PI));
for (let i = 0; i < 200; i++) trigArgs.push(uni(-2 * Math.PI, 2 * Math.PI));
for (let i = 0; i < 100; i++) trigArgs.push(uni(-60, 60));
for (let i = 0; i < 100; i++) trigArgs.push(uni(-1e5, 1e5));
for (let i = 0; i < 100; i++) trigArgs.push((rng.chance(0.5) ? 1 : -1) * Math.pow(10, uni(6, 300)));
const sincos = trigArgs.map((a) => [bits(a), bits(Math.sin(a)), bits(Math.cos(a))]);

const atanArgs: [number, number][] = [
  [0, 0], [-0, 0], [0, -0], [-0, -0], [0, 3], [-0, 3], [0, -3], [-0, -3], [2, 0], [-2, 0], [2, -0], [-2, -0],
  [Infinity, Infinity], [-Infinity, Infinity], [Infinity, -Infinity], [-Infinity, -Infinity],
  [1, Infinity], [-1, Infinity], [1, -Infinity], [-1, -Infinity], [Infinity, 1], [-Infinity, -1],
  [NaN, 1], [1, NaN], [0.3, 1], [-7, 1], [1e300, 1e-300], [-1e300, 1e-300], [1e-300, -1e300], [-1e-300, -1e300],
  [1e-20, 1], [1e-10, 1e-10], [0.4375, 1], [0.6875, 1], [1.1875, 1], [2.4375, 1], [1e20, 1],
];
for (let i = 0; i < 800; i++) {
  const s = [1e-6, 0.05, 1, 3, 12, 25, 1e4][i % 7];
  atanArgs.push([uni(-s, s), uni(-s, s) * (i % 13 === 0 ? 1e-9 : 1)]);
}
const atan2 = atanArgs.map(([y, x]) => [bits(y), bits(x), bits(Math.atan2(y, x))]);

// --- Thresholds that Math.hypot decides -----------------------------------------
// Sticks where Math.hypot and sqrt(x*x + z*z) fall on different sides of
// dirIndex's deadzone.
function straddle(r: number, n: number, below: (v: number) => boolean) {
  const out: [number, number][] = [];
  while (out.length < n) {
    const t = uni(0, Math.PI * 2);
    const x0 = Math.sin(t) * r;
    const z0 = Math.cos(t) * r;
    for (let i = -3; i <= 3 && out.length < n; i++) {
      for (let j = -3; j <= 3 && out.length < n; j++) {
        const x = x0 > 0 ? ulps(x0, i) : -ulps(-x0, i);
        const z = z0 > 0 ? ulps(z0, j) : -ulps(-z0, j);
        if (below(Math.hypot(x, z)) !== below(naiveHypot(x, z))) out.push([x, z]);
      }
    }
  }
  return out;
}
const deadzone = straddle(DIR_DEADZONE, 8, (m) => m < DIR_DEADZONE).map(([mx, my]) => [bits(mx), bits(my), dirIndex(mx, my)]);

// --- JS number formatting and parsing for the tools -----------------------------
const toFixedCases: number[] = [
  0, -0, 0.001, 0.0015, 0.0038, 0.0005, 0.00049, 0.0025, 0.0035, 0.0036, 0.0037, 0.00375, 0.0076, 0.0155, 0.01555,
  1.005, 2.5, 0.5, 1.5, -0.0001, -0.0005, 1e-10, 123.456, 0.0625, 0.125, 44.5, 121.8, 281.125, 12.345, 9.995,
  -2.5, -1.005, 1e15, 4503599627370495.5, 4503599627370496, 9007199254740991,
];
for (let i = 0; i < 150; i++) toFixedCases.push(uni(0, 0.02));
for (let i = 0; i < 150; i++) toFixedCases.push(uni(-500, 500));
for (let i = 0; i < 60; i++) toFixedCases.push(Math.pow(2, -Math.floor(uni(1, 70))) * uni(1, 2));
const toFixed: unknown[] = [];
for (const x of toFixedCases) for (const d of [0, 1, 2, 3]) toFixed.push([bits(x), d, x.toFixed(d)]);

const numberArgs = [
  '40', '30', '40.5', '1.5', 'abc', '', ' ', ' 12 ', '\t7\n', '1e1', '1E+2', '2e-1', '.5', '5.', '-5', '+5', '-0',
  '0x10', '0X1f', '0b101', '0o17', '-0x10', '0x', '1_000', 'Infinity', '-Infinity', '+Infinity', 'infinity', 'NaN',
  '12abc', '1.2.3', '00012', '1e400', '-1e400', '1e-400', '0.1', '0.30000000000000004', '123456789012345678901234567890',
];
const numberCases = numberArgs.map((s) => [s, bits(Number(s)), String(Number(s))]);
// Math.fround(0.1) is a double a float32 holds exactly: Godot's var_to_str
// prints such doubles with too few digits (plan task 8.2).
const strCases: number[] = [Math.fround(0.1), 0.1, 0.1 + 0.2, 1 / 3, 40.5, 1e21, 1e20, 1e-7, 1e-6, 123456789.123, 2 / 3, 100, 1e15, 1e16, -0, -1.5, 5e-324, 1.7976931348623157e308, 0.000001234, 12345678901234567890];
for (let i = 0; i < 100; i++) strCases.push(uni(-1, 1) * Math.pow(10, Math.floor(uni(-12, 25))));
const numToString = strCases.map((x) => [bits(x), String(x)]);

const data = {
  hypot,
  sincos,
  atan2,
  deadzone,
  toFixed,
  number: numberCases,
  numToString,
};

mkdirSync(dirname(OUT), { recursive: true });
const lines = Object.entries(data).map(([k, v]) => {
  if (Array.isArray(v)) return `  ${JSON.stringify(k)}: [\n${v.map((r) => '    ' + JSON.stringify(r)).join(',\n')}\n  ]`;
  return `  ${JSON.stringify(k)}: ${JSON.stringify(v)}`;
});
writeFileSync(OUT, '{\n' + lines.join(',\n') + '\n}\n');
console.log(`wrote ${OUT}`);
