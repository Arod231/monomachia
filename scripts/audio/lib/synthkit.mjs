// Offline synthesis building blocks shared by synth.mjs (sound effects) and
// music.mjs. They follow the Web Audio recipes of the web demo
// (src/audio/audio.ts): oscillators and filtered noise with exponential
// envelopes and pitch ramps, metallic partials and Karplus-Strong plucks, but
// render sample by sample into Float32Arrays so the result is repeatable.
// Everything random takes a seeded generator.

export const SR = 44100;
const TAU = Math.PI * 2;

/** An empty mono buffer. */
export const buffer = (seconds) => new Float32Array(Math.max(1, Math.ceil(seconds * SR)));

/**
 * The demo's envelope: exponential rise from silence to `peak` over `attack`,
 * then exponential fall to silence over `decay` (both in seconds).
 */
export function expEnv(t, peak, attack, decay) {
  const floor = 0.0001;
  if (t < 0) return 0;
  const p = Math.max(0.0002, peak);
  if (t < attack) return floor * Math.pow(p / floor, t / attack);
  const u = t - attack;
  if (u < decay) return p * Math.pow(floor / p, u / decay);
  return 0;
}

/** Adds `src` into `dst` starting at t0 seconds, scaled by gain. */
export function addInto(dst, src, t0 = 0, gain = 1) {
  const off = Math.round(t0 * SR);
  const n = Math.min(src.length, dst.length - off);
  for (let i = Math.max(0, -off); i < n; i++) dst[off + i] += src[i] * gain;
  return dst;
}

// ------------------------------------------------------------------ oscillators

/** PolyBLEP step correction, for saw and square waves without harsh aliasing. */
function polyBlep(t, dt) {
  if (t < dt) {
    t /= dt;
    return t + t - t * t - 1;
  }
  if (t > 1 - dt) {
    t = (t - 1) / dt;
    return t * t + t + t + 1;
  }
  return 0;
}

/** One sample of a waveform at phase ph (0..1) with phase increment dt. */
export function wave(type, ph, dt) {
  switch (type) {
    case 'sine':
      return Math.sin(TAU * ph);
    case 'triangle':
      return 1 - 4 * Math.abs(((ph + 0.25) % 1) - 0.5);
    case 'sawtooth':
      return 2 * ph - 1 - polyBlep(ph, dt);
    case 'square': {
      let v = ph < 0.5 ? 1 : -1;
      v += polyBlep(ph, dt);
      v -= polyBlep((ph + 0.5) % 1, dt);
      return v;
    }
    default:
      throw new Error(`unknown wave ${type}`);
  }
}

/**
 * The demo's tone(): an oscillator with the exponential envelope and an
 * optional exponential glide to freqEnd over attack + decay.
 */
export function tone(dst, { freq, freqEnd, type = 'sine', peak = 0.5, attack = 0.002, decay = 0.2, t0 = 0, phase = 0 }) {
  const total = attack + decay;
  const n = Math.ceil((total + 0.01) * SR);
  const off = Math.round(t0 * SR);
  let ph = phase;
  for (let i = 0; i < n && off + i < dst.length; i++) {
    const t = i / SR;
    const f = freqEnd ? freq * Math.pow(freqEnd / freq, Math.min(1, t / total)) : freq;
    const dt = f / SR;
    if (off + i >= 0) dst[off + i] += wave(type, ph, dt) * expEnv(t, peak, attack, decay);
    ph += dt;
    ph -= Math.floor(ph);
  }
  return dst;
}

/**
 * The demo's metal(): inharmonic partials, the first a triangle and the rest
 * sines, each quieter and shorter than the one before. `rand` detunes them by
 * up to +/-1% as the demo did with Math.random.
 */
export function metal(dst, { f0, partials, peak, decay, t0 = 0, rand }) {
  partials.forEach((p, i) => {
    const detune = rand ? 0.99 + rand() * 0.02 : 1;
    tone(dst, {
      freq: f0 * p * detune,
      type: i === 0 ? 'triangle' : 'sine',
      peak: peak / (1 + i * 0.7),
      attack: 0.002,
      decay: decay * (1 - i * 0.12),
      t0,
      phase: rand ? rand() : 0,
    });
  });
  return dst;
}

/**
 * A bank of decaying sine modes, each {f, amp, decay (s to -60 dB)}, with an
 * optional beat partner (a quieter second sine `beat` Hz away, at `beatMix` of
 * the level) for a shimmering ring rather than a full tremolo.
 */
export function modes(dst, list, { t0 = 0, attack = 0.001, rand } = {}) {
  const off = Math.round(t0 * SR);
  for (const m of list) {
    const n = Math.min(dst.length - off, Math.ceil(m.decay * SR * 1.05));
    const k = Math.log(1000) / m.decay; // -60 dB over `decay`
    const ph1 = rand ? rand() : 0;
    const ph2 = rand ? rand() : 0.25;
    const glide = m.glide ?? 0; // relative pitch change over the decay (gongs rise or fall)
    let p1 = ph1;
    let p2 = ph2;
    for (let i = 0; i < n; i++) {
      const t = i / SR;
      const f = m.f * (1 + glide * Math.min(1, t / m.decay));
      const a = m.amp * Math.exp(-k * t) * Math.min(1, t / attack) * (m.swell ? 1 - Math.exp(-t / m.swell) : 1);
      let v = Math.sin(TAU * p1);
      p1 += f / SR;
      if (m.beat) {
        const mixB = m.beatMix ?? 0.45;
        v = (v + Math.sin(TAU * p2) * mixB) / (1 + mixB);
        p2 += (f + m.beat) / SR;
      }
      if (off + i >= 0) dst[off + i] += v * a;
    }
  }
  return dst;
}

// ------------------------------------------------------------------ noise and filters

/** Seeded white noise in [-1, 1). */
export function whiteNoise(seconds, rand) {
  const b = buffer(seconds);
  for (let i = 0; i < b.length; i++) b[i] = rand() * 2 - 1;
  return b;
}

/**
 * RBJ biquad, with the same meaning of frequency and Q as Web Audio's
 * BiquadFilterNode (lowpass, highpass, bandpass, peaking, lowshelf, highshelf).
 */
export class Biquad {
  constructor(type, freq, q = 0.7071, gainDb = 0) {
    this.type = type;
    this.q = q;
    this.gainDb = gainDb;
    this.x1 = this.x2 = this.y1 = this.y2 = 0;
    this.set(freq);
  }

  set(freq) {
    const f = Math.min(Math.max(freq, 10), SR * 0.49);
    const w = (TAU * f) / SR;
    const cw = Math.cos(w);
    const sw = Math.sin(w);
    const alpha = sw / (2 * this.q);
    const A = Math.pow(10, this.gainDb / 40);
    let b0, b1, b2, a0, a1, a2;
    switch (this.type) {
      case 'lowpass':
        b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = b0; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
        break;
      case 'highpass':
        b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = b0; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
        break;
      case 'bandpass':
        b0 = alpha; b1 = 0; b2 = -alpha; a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
        break;
      case 'peaking':
        b0 = 1 + alpha * A; b1 = -2 * cw; b2 = 1 - alpha * A; a0 = 1 + alpha / A; a1 = -2 * cw; a2 = 1 - alpha / A;
        break;
      case 'lowshelf': {
        const s = 2 * Math.sqrt(A) * alpha;
        b0 = A * (A + 1 - (A - 1) * cw + s); b1 = 2 * A * (A - 1 - (A + 1) * cw); b2 = A * (A + 1 - (A - 1) * cw - s);
        a0 = A + 1 + (A - 1) * cw + s; a1 = -2 * (A - 1 + (A + 1) * cw); a2 = A + 1 + (A - 1) * cw - s;
        break;
      }
      case 'highshelf': {
        const s = 2 * Math.sqrt(A) * alpha;
        b0 = A * (A + 1 + (A - 1) * cw + s); b1 = -2 * A * (A - 1 + (A + 1) * cw); b2 = A * (A + 1 + (A - 1) * cw - s);
        a0 = A + 1 - (A - 1) * cw + s; a1 = 2 * (A - 1 - (A + 1) * cw); a2 = A + 1 - (A - 1) * cw - s;
        break;
      }
      default:
        throw new Error(`unknown filter ${this.type}`);
    }
    this.b0 = b0 / a0; this.b1 = b1 / a0; this.b2 = b2 / a0; this.a1 = a1 / a0; this.a2 = a2 / a0;
  }

  step(x) {
    const y = this.b0 * x + this.b1 * this.x1 + this.b2 * this.x2 - this.a1 * this.y1 - this.a2 * this.y2;
    this.x2 = this.x1; this.x1 = x; this.y2 = this.y1; this.y1 = y;
    return y;
  }
}

/** Filters a buffer in place, optionally sweeping the frequency exponentially. */
export function filter(buf, type, f0, { f1, q = 0.7071, gainDb = 0, sweep } = {}) {
  const bq = new Biquad(type, f0, q, gainDb);
  const n = buf.length;
  const span = sweep ?? n / SR;
  for (let i = 0; i < n; i++) {
    if (f1 && (i & 15) === 0) bq.set(f0 * Math.pow(f1 / f0, Math.min(1, i / SR / span)));
    buf[i] = bq.step(buf[i]);
  }
  return buf;
}

/**
 * The demo's noiseBurst(): filtered noise with the exponential envelope, the
 * filter optionally gliding from f0 to f1 over the burst.
 */
export function noiseBurst(dst, { peak = 0.3, attack = 0.002, decay = 0.1, type = 'lowpass', f0 = 1000, f1, q = 1, t0 = 0, rand }) {
  const total = attack + decay;
  const src = whiteNoise(total + 0.01, rand);
  const bq = new Biquad(type, f0, q);
  for (let i = 0; i < src.length; i++) {
    const t = i / SR;
    if (f1 && (i & 15) === 0) bq.set(f0 * Math.pow(f1 / f0, Math.min(1, t / total)));
    src[i] = bq.step(src[i]) * expEnv(t, peak, attack, decay);
  }
  return addInto(dst, src, t0);
}

/** tanh saturation with drive (linear gain before the curve). */
export function drive(buf, amount) {
  const k = 1 / Math.tanh(amount);
  for (let i = 0; i < buf.length; i++) buf[i] = Math.tanh(buf[i] * amount) * k;
  return buf;
}

/** Scales a buffer so its peak is at peakDb dBFS. */
export function normalizeBuf(buf, peakDb = -1) {
  let p = 0;
  for (let i = 0; i < buf.length; i++) p = Math.max(p, Math.abs(buf[i]));
  if (p === 0) return buf;
  const g = Math.pow(10, peakDb / 20) / p;
  for (let i = 0; i < buf.length; i++) buf[i] *= g;
  return buf;
}

/**
 * Cuts the tail where it falls under thresholdDb (dBFS), keeping 5 ms, then
 * fades the last few milliseconds.
 */
export function tidy(buf, { thresholdDb = -60, fade = 0.01 } = {}) {
  const thr = Math.pow(10, thresholdDb / 20);
  let end = buf.length;
  while (end > 1 && Math.abs(buf[end - 1]) < thr) end--;
  const out = buf.slice(0, Math.min(buf.length, end + Math.round(0.005 * SR)));
  const f = Math.min(out.length, Math.round(fade * SR));
  for (let i = 0; i < f; i++) out[out.length - 1 - i] *= i / f;
  // A tiny fade-in avoids a click when the first sample is not zero.
  const fi = Math.min(out.length, 16);
  for (let i = 0; i < fi; i++) out[i] *= i / fi;
  return out;
}

// ------------------------------------------------------------------ plucked strings

/**
 * Karplus-Strong plucked string (the demo's makePluck, extended): a noise
 * burst in a delay line with an averaging filter. `decay` is the feedback
 * (0.99..0.999), `bright` the filter mix (1 = demo's plain average), `mute`
 * damps it like a palm-muted string, and `buzz` adds the shamisen's sawari
 * buzz (a soft clip in the loop).
 */
export function pluck(freq, seconds, rand, { decay = 0.994, bright = 0.5, attackBoost = 0.8, mute = 0, buzz = 0, pickPos = 0 } = {}) {
  const out = buffer(seconds);
  // Muting shortens the ring and darkens it.
  const lpA = Math.min(0.95, Math.max(0.05, bright * (1 - mute * 0.5)));
  const fb = Math.max(0.5, decay - mute * 0.08);
  // Loop delay = line length + the damping filter's delay + a fractional
  // allpass delay, which keeps the pitch in tune.
  const exact = SR / freq - (1 - lpA);
  let N = Math.max(2, Math.floor(exact));
  let frac = exact - N;
  if (frac < 0.1 && N > 2) (N -= 1), (frac += 1);
  const ap = (1 - frac) / (1 + frac);
  const ring = new Float32Array(N);
  for (let i = 0; i < ring.length; i++) ring[i] = rand() * 2 - 1;
  if (pickPos > 0) {
    // Comb the excitation: plucking away from the end removes some harmonics.
    const d = Math.max(1, Math.round(pickPos * N));
    for (let i = ring.length - 1; i >= d; i--) ring[i] -= ring[i - d];
  }
  let idx = 0;
  let apX1 = 0;
  let apY1 = 0;
  let last = 0;
  for (let i = 0; i < out.length; i++) {
    const cur = ring[idx];
    out[i] = cur;
    // averaging low-pass (the classic string damping), weighted by brightness
    let v = (lpA * cur + (1 - lpA) * last) * fb;
    last = cur;
    if (buzz) v = Math.tanh(v * (1 + buzz * 4)) / (1 + buzz * 0.5);
    // fractional delay
    const y = ap * v + apX1 - ap * apY1;
    apX1 = v;
    apY1 = y;
    ring[idx] = y;
    if (++idx >= N) idx = 0;
  }
  const boostN = Math.min(out.length, 300);
  for (let i = 0; i < boostN; i++) out[i] *= 1 + (1 - i / boostN) * attackBoost;
  return out;
}

// ------------------------------------------------------------------ effects (stereo)

/**
 * A Freeverb-style stereo reverb (8 damped combs and 4 allpasses per side).
 * Returns the wet signal only. With `loop`, the input is treated as circular:
 * the reverb is run over it twice and the second pass kept, so the tail of the
 * end wraps into the start of a seamless loop.
 */
export function reverb([inL, inR], { room = 0.84, damp = 0.3, width = 1, loop = false } = {}) {
  const combTuning = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
  const apTuning = [556, 441, 341, 225];
  const spread = 23;
  const scale = SR / 44100;
  const makeSide = (off) => ({
    combs: combTuning.map((t) => ({ buf: new Float32Array(Math.round((t + off) * scale)), i: 0, store: 0 })),
    aps: apTuning.map((t) => ({ buf: new Float32Array(Math.round((t + off) * scale)), i: 0 })),
  });
  const sides = [makeSide(0), makeSide(spread)];
  const n = inL.length;
  const outs = [new Float32Array(n), new Float32Array(n)];
  const passes = loop ? 2 : 1;
  for (let pass = 0; pass < passes; pass++) {
    for (let i = 0; i < n; i++) {
      const input = (inL[i] + inR[i]) * 0.015;
      for (let s = 0; s < 2; s++) {
        const side = sides[s];
        let acc = 0;
        for (const c of side.combs) {
          const y = c.buf[c.i];
          c.store = y * (1 - damp) + c.store * damp;
          c.buf[c.i] = input + c.store * room;
          if (++c.i >= c.buf.length) c.i = 0;
          acc += y;
        }
        for (const a of side.aps) {
          const b = a.buf[a.i];
          a.buf[a.i] = acc + b * 0.5;
          if (++a.i >= a.buf.length) a.i = 0;
          acc = b - acc;
        }
        if (pass === passes - 1) outs[s][i] = acc;
      }
    }
  }
  const w1 = width / 2 + 0.5;
  const w2 = (1 - width) / 2;
  const L = new Float32Array(n);
  const R = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    L[i] = outs[0][i] * w1 + outs[1][i] * w2;
    R[i] = outs[1][i] * w1 + outs[0][i] * w2;
  }
  return [L, R];
}

/** A stereo ping-pong echo, circular when loop is set (wet only). */
export function pingPong([inL, inR], { time, feedback = 0.35, lowpass = 3000, loop = false }) {
  const n = inL.length;
  const d = Math.round(time * SR);
  const L = new Float32Array(n);
  const R = new Float32Array(n);
  const k = 1 - Math.exp((-TAU * lowpass) / SR);
  let zl = 0;
  let zr = 0;
  const passes = loop ? 3 : 1;
  const bufL = new Float32Array(d);
  const bufR = new Float32Array(d);
  let w = 0;
  for (let pass = 0; pass < passes; pass++) {
    for (let i = 0; i < n; i++) {
      const outL = bufL[w];
      const outR = bufR[w];
      zl += k * (outL - zl);
      zr += k * (outR - zr);
      // left echo feeds the right line and vice versa
      bufL[w] = (inL[i] + inR[i]) * 0.5 + zr * feedback;
      bufR[w] = zl * feedback;
      if (++w >= d) w = 0;
      if (pass === passes - 1) {
        L[i] = zl;
        R[i] = zr;
      }
    }
  }
  return [L, R];
}

/**
 * A simple feed-forward compressor on a stereo pair (linked), in place.
 * With `loop`, the detector is primed over the buffer first so the start of a
 * loop is treated like the middle.
 */
export function compress([L, R], { thresholdDb = -12, ratio = 3, attack = 0.005, release = 0.12, makeupDb = 0, loop = false }) {
  const thr = Math.pow(10, thresholdDb / 20);
  const ga = Math.exp(-1 / (attack * SR));
  const gr = Math.exp(-1 / (release * SR));
  const makeup = Math.pow(10, makeupDb / 20);
  let env = 0;
  const n = L.length;
  if (loop) {
    for (let i = 0; i < n; i++) {
      const x = Math.max(Math.abs(L[i]), Math.abs(R[i]));
      env = x > env ? ga * env + (1 - ga) * x : gr * env + (1 - gr) * x;
    }
  }
  for (let i = 0; i < n; i++) {
    const x = Math.max(Math.abs(L[i]), Math.abs(R[i]));
    env = x > env ? ga * env + (1 - ga) * x : gr * env + (1 - gr) * x;
    let g = 1;
    if (env > thr) g = Math.pow(env / thr, 1 / ratio - 1);
    L[i] *= g * makeup;
    R[i] *= g * makeup;
  }
  return [L, R];
}

/**
 * A second-order (Butterworth) high-pass on a seamless loop, in place: it
 * blocks DC and sub-sonic drift. The filter runs over the loop twice and
 * keeps the second pass, so its state at the start is the state the end
 * leaves and the loop stays seamless.
 */
export function highpassLoop(channels, hz) {
  for (const ch of channels) {
    const bq = new Biquad('highpass', hz, Math.SQRT1_2);
    for (let i = 0; i < ch.length; i++) bq.step(ch[i]);
    for (let i = 0; i < ch.length; i++) ch[i] = bq.step(ch[i]);
  }
  return channels;
}

/** Equal-power pan gains for p in [-1, 1]. */
export function panGains(p) {
  const a = ((p + 1) * Math.PI) / 4;
  return [Math.cos(a), Math.sin(a)];
}
