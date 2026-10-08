// Reads a clip GLB's skeleton pose frame by frame (milestone-1 task 59): the
// world position of every node at each 30 fps frame, from its animation's
// translation, rotation and scale channels (linear, or a step's held value).
// Used to fit-check a clip that went through Cascadeur against its source.
//
//   node scripts/cascadeur/glb-pose.mjs <a.glb> <b.glb> [--shift N]
//
// prints the frames compared and, per bone, the largest gap (cm) between the
// two and its frame, worst first; --shift N compares a's frame k with b's
// frame k + N.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const FPS = 30;

function readGlb(path) {
  const buf = readFileSync(path);
  const jsonLen = buf.readUInt32LE(12);
  const json = JSON.parse(buf.subarray(20, 20 + jsonLen).toString('utf8'));
  const binStart = 20 + jsonLen + 8;
  const bin = buf.subarray(binStart);
  return { json, bin };
}

const COMPONENTS = { SCALAR: 1, VEC3: 3, VEC4: 4 };

function accessor({ json, bin }, i) {
  const a = json.accessors[i];
  const view = json.bufferViews[a.bufferView];
  const n = COMPONENTS[a.type];
  const stride = view.byteStride ?? n * 4;
  const base = (view.byteOffset ?? 0) + (a.byteOffset ?? 0);
  const out = [];
  for (let k = 0; k < a.count; k++) {
    const v = [];
    for (let c = 0; c < n; c++) v.push(bin.readFloatLE(base + k * stride + c * 4));
    out.push(n === 1 ? v[0] : v);
  }
  return out;
}

function lerp(a, b, t) {
  return a.map((x, i) => x + (b[i] - x) * t);
}

function slerp(a, b, t) {
  let d = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3];
  if (d < 0) {
    b = b.map((x) => -x);
    d = -d;
  }
  if (d > 0.9995) {
    const q = lerp(a, b, t);
    const l = Math.hypot(...q);
    return q.map((x) => x / l);
  }
  const th = Math.acos(d);
  const s = Math.sin(th);
  const wa = Math.sin((1 - t) * th) / s;
  const wb = Math.sin(t * th) / s;
  return a.map((x, i) => x * wa + b[i] * wb);
}

function sample(times, values, interp, t, path) {
  if (t <= times[0]) return values[0];
  if (t >= times[times.length - 1]) return values[values.length - 1];
  let k = 0;
  while (times[k + 1] < t) k++;
  if (interp === 'STEP') return values[k];
  const u = (t - times[k]) / (times[k + 1] - times[k]);
  return path === 'rotation' ? slerp(values[k], values[k + 1], u) : lerp(values[k], values[k + 1], u);
}

function rotate(q, v) {
  const [x, y, z, w] = q;
  const ix = w * v[0] + y * v[2] - z * v[1];
  const iy = w * v[1] + z * v[0] - x * v[2];
  const iz = w * v[2] + x * v[1] - y * v[0];
  const iw = -x * v[0] - y * v[1] - z * v[2];
  return [ix * w + iw * -x + iy * -z - iz * -y, iy * w + iw * -y + iz * -x - ix * -z, iz * w + iw * -z + ix * -y - iy * -x];
}

function mulQ(a, b) {
  return [
    a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
    a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
    a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
    a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
  ];
}

/** { frames, poses: [{ name: [x, y, z] world }] }, one pose per 30 fps frame. */
export function poses(path) {
  const glb = readGlb(path);
  const { json } = glb;
  const anim = json.animations[0];
  const tracks = new Map();
  let end = 0;
  for (const ch of anim.channels) {
    const s = anim.samplers[ch.sampler];
    const times = accessor(glb, s.input);
    end = Math.max(end, times[times.length - 1]);
    const key = `${ch.target.node}:${ch.target.path}`;
    tracks.set(key, { times, values: accessor(glb, s.output), interp: s.interpolation ?? 'LINEAR', path: ch.target.path });
  }
  const parent = new Map();
  json.nodes.forEach((n, i) => (n.children ?? []).forEach((c) => parent.set(c, i)));
  const frames = Math.round(end * FPS) + 1;
  const out = [];
  for (let f = 0; f < frames; f++) {
    const t = f / FPS;
    const local = json.nodes.map((n, i) => {
      const get = (p, d) => {
        const tr = tracks.get(`${i}:${p}`);
        return tr ? sample(tr.times, tr.values, tr.interp, t, p) : (n[p] ?? d);
      };
      return { t: get('translation', [0, 0, 0]), r: get('rotation', [0, 0, 0, 1]), s: get('scale', [1, 1, 1]) };
    });
    const world = new Map();
    const resolve = (i) => {
      if (world.has(i)) return world.get(i);
      const l = local[i];
      let w;
      if (!parent.has(i)) w = { p: l.t, r: l.r, s: l.s };
      else {
        const pw = resolve(parent.get(i));
        const scaled = [l.t[0] * pw.s[0], l.t[1] * pw.s[1], l.t[2] * pw.s[2]];
        const rp = rotate(pw.r, scaled);
        w = { p: [pw.p[0] + rp[0], pw.p[1] + rp[1], pw.p[2] + rp[2]], r: mulQ(pw.r, l.r), s: [pw.s[0] * l.s[0], pw.s[1] * l.s[1], pw.s[2] * l.s[2]] };
      }
      world.set(i, w);
      return w;
    };
    const pose = {};
    json.nodes.forEach((n, i) => (pose[n.name] = resolve(i).p));
    out.push(pose);
  }
  return { frames, poses: out };
}

/** Per bone of both, the largest gap (m) and its frame (a's), a's frame k against b's k + shift. */
export function gaps(a, b, shift = 0) {
  const worst = {};
  for (let k = 0; k < a.frames; k++) {
    const j = k + shift;
    if (j < 0 || j >= b.frames) continue;
    for (const [name, p] of Object.entries(a.poses[k])) {
      const q = b.poses[j][name];
      if (!q) continue;
      const d = Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]);
      if (!worst[name] || d > worst[name].gap) worst[name] = { gap: d, frame: k };
    }
  }
  return worst;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const i = args.indexOf('--shift');
  const shift = i >= 0 ? Number(args[i + 1]) : 0;
  const a = poses(args[0]);
  const b = poses(args[1]);
  console.log(`frames: ${a.frames} and ${b.frames}, shift ${shift}`);
  const rows = Object.entries(gaps(a, b, shift)).sort((x, y) => y[1].gap - x[1].gap);
  for (const [name, { gap, frame }] of rows.slice(0, 15)) console.log(`${name.padEnd(22)} ${(gap * 100).toFixed(2)} cm  frame ${frame}`);
}
