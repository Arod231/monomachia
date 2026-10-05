// Offline DSP helpers on planar float audio ({sampleRate, channels}).
// Every function returns new audio and leaves its input untouched.

/** @typedef {{sampleRate: number, channels: Float32Array[]}} Audio */

export const dbToGain = (db) => Math.pow(10, db / 20);
export const gainToDb = (g) => (g > 0 ? 20 * Math.log10(g) : -Infinity);

export const frames = (a) => (a.channels.length ? a.channels[0].length : 0);
export const duration = (a) => frames(a) / a.sampleRate;

/** Silent audio. */
export function silence(sampleRate, seconds, channelCount = 1) {
  const n = Math.max(0, Math.round(seconds * sampleRate));
  return { sampleRate, channels: Array.from({ length: channelCount }, () => new Float32Array(n)) };
}

export function clone(a) {
  return { sampleRate: a.sampleRate, channels: a.channels.map((c) => new Float32Array(c)) };
}

/** Averages all channels into one. */
export function toMono(a) {
  if (a.channels.length === 1) return clone(a);
  const n = frames(a);
  const out = new Float32Array(n);
  const k = 1 / a.channels.length;
  for (const ch of a.channels) for (let i = 0; i < n; i++) out[i] += ch[i] * k;
  return { sampleRate: a.sampleRate, channels: [out] };
}

/**
 * Two channels: mono is duplicated; more than two are folded (even-numbered
 * channels to the left, odd to the right).
 */
export function toStereo(a) {
  if (a.channels.length === 2) return clone(a);
  if (a.channels.length === 1) return { sampleRate: a.sampleRate, channels: [new Float32Array(a.channels[0]), new Float32Array(a.channels[0])] };
  const n = frames(a);
  const l = new Float32Array(n);
  const r = new Float32Array(n);
  const half = 2 / a.channels.length;
  a.channels.forEach((ch, c) => {
    const dst = c % 2 === 0 ? l : r;
    for (let i = 0; i < n; i++) dst[i] += ch[i] * half;
  });
  return { sampleRate: a.sampleRate, channels: [l, r] };
}

/** Narrows (0) or widens (>1) a stereo image with mid/side scaling. */
export function stereoWidth(a, width) {
  if (a.channels.length !== 2) return clone(a);
  const [l, r] = a.channels;
  const n = l.length;
  const L = new Float32Array(n);
  const R = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const m = (l[i] + r[i]) * 0.5;
    const s = (l[i] - r[i]) * 0.5 * width;
    L[i] = m + s;
    R[i] = m - s;
  }
  return { sampleRate: a.sampleRate, channels: [L, R] };
}

// ------------------------------------------------------------------ resampling

function besselI0(x) {
  let sum = 1;
  let term = 1;
  const q = (x * x) / 4;
  for (let k = 1; k < 60; k++) {
    term *= q / (k * k);
    sum += term;
    if (term < 1e-12 * sum) break;
  }
  return sum;
}

const SINC_ZEROS = 24; // zero crossings on each side of the kernel
const SINC_RES = 512; // table entries per zero crossing
const KAISER_BETA = 9.0; // about -90 dB stopband
let sincTable = null;

function kernelTable() {
  if (sincTable) return sincTable;
  const n = SINC_ZEROS * SINC_RES + 2;
  sincTable = new Float64Array(n);
  const i0b = besselI0(KAISER_BETA);
  for (let k = 0; k < n; k++) {
    const x = k / SINC_RES;
    const s = x === 0 ? 1 : Math.sin(Math.PI * x) / (Math.PI * x);
    const r = x / SINC_ZEROS;
    const w = r >= 1 ? 0 : besselI0(KAISER_BETA * Math.sqrt(1 - r * r)) / i0b;
    sincTable[k] = s * w;
  }
  return sincTable;
}

/**
 * Band-limited resampling with a Kaiser-windowed sinc kernel.
 * @param {Audio} a
 * @param {number} outRate
 * @param {{pitch?: number}} [opts] pitch: playback-speed factor applied in the
 *   same pass (2 = an octave up and half as long), for pitch shifting.
 */
export function resample(a, outRate, { pitch = 1 } = {}) {
  const inRate = a.sampleRate * pitch; // the rate the source is "played" at
  if (Math.abs(inRate - outRate) < 1e-9) return { sampleRate: outRate, channels: a.channels.map((c) => new Float32Array(c)) };
  const table = kernelTable();
  const ratio = outRate / inRate;
  // Low-pass just under the lower Nyquist so nothing folds back.
  const cutoff = Math.min(1, ratio) * 0.94;
  const n = frames(a);
  const outN = Math.max(0, Math.floor((n * outRate) / inRate));
  const step = inRate / outRate;
  const reach = SINC_ZEROS / cutoff;
  const channels = a.channels.map((src) => {
    const out = new Float32Array(outN);
    for (let i = 0; i < outN; i++) {
      const t = i * step;
      const j0 = Math.max(0, Math.ceil(t - reach));
      const j1 = Math.min(n - 1, Math.floor(t + reach));
      let acc = 0;
      for (let j = j0; j <= j1; j++) {
        const x = Math.abs(t - j) * cutoff * SINC_RES;
        const k = x | 0;
        const f = x - k;
        const h = table[k] + (table[k + 1] - table[k]) * f;
        acc += src[j] * h;
      }
      out[i] = acc * cutoff;
    }
    return out;
  });
  return { sampleRate: outRate, channels };
}

/** Pitch shift by resampling (changes the length too), keeping the rate. */
export function pitchShift(a, semitones) {
  const r = Math.pow(2, semitones / 12);
  const out = resample(a, a.sampleRate, { pitch: r });
  return out;
}

// ------------------------------------------------------------------ editing

/** Cuts [start, end) in seconds (end defaults to the end of the audio). */
export function slice(a, start, end = Infinity) {
  const n = frames(a);
  const s = Math.max(0, Math.min(n, Math.round(start * a.sampleRate)));
  const e = Math.max(s, Math.min(n, Math.round(end * a.sampleRate)));
  return { sampleRate: a.sampleRate, channels: a.channels.map((c) => c.slice(s, e)) };
}

export function reverse(a) {
  return { sampleRate: a.sampleRate, channels: a.channels.map((c) => new Float32Array(c).reverse()) };
}

/** Mixes channels' absolute value into one short-window peak envelope. */
function peakEnvelope(a, windowSec) {
  const n = frames(a);
  const w = Math.max(1, Math.round(windowSec * a.sampleRate));
  const count = Math.ceil(n / w);
  const env = new Float32Array(count);
  for (const ch of a.channels) {
    for (let i = 0; i < n; i++) {
      const v = Math.abs(ch[i]);
      const k = (i / w) | 0;
      if (v > env[k]) env[k] = v;
    }
  }
  return { env, w };
}

/**
 * Removes leading and trailing audio quieter than thresholdDb (relative to
 * full scale), keeping a little padding either side.
 */
export function trimSilence(a, { thresholdDb = -50, padStart = 0.002, padEnd = 0.03, start = true, end = true } = {}) {
  const thr = dbToGain(thresholdDb);
  const { env, w } = peakEnvelope(a, 0.002);
  let first = 0;
  let last = env.length - 1;
  if (start) while (first < env.length && env[first] < thr) first++;
  if (end) while (last > first && env[last] < thr) last--;
  if (first >= env.length) return silence(a.sampleRate, 0, a.channels.length);
  const s = Math.max(0, first * w - Math.round(padStart * a.sampleRate));
  const e = Math.min(frames(a), (last + 1) * w + Math.round(padEnd * a.sampleRate));
  return { sampleRate: a.sampleRate, channels: a.channels.map((c) => c.slice(s, e)) };
}

/**
 * Fades in and out. curve 'exp' (the default) is perceptually even; 'lin' is
 * linear; 'sine' is equal-power.
 */
export function fade(a, { fadeIn = 0, fadeOut = 0, curve = 'exp' } = {}) {
  const out = clone(a);
  const n = frames(a);
  const shape = (x) => (curve === 'lin' ? x : curve === 'sine' ? Math.sin((x * Math.PI) / 2) : x * x * x);
  const fi = Math.min(n, Math.round(fadeIn * a.sampleRate));
  const fo = Math.min(n, Math.round(fadeOut * a.sampleRate));
  for (const ch of out.channels) {
    for (let i = 0; i < fi; i++) ch[i] *= shape(i / fi);
    for (let i = 0; i < fo; i++) ch[n - 1 - i] *= shape(i / fo);
  }
  return out;
}

/**
 * An exponential decay from the first sample, falling 20 dB every `seconds`:
 * tightens an impact whose recording keeps rumbling, so its first hit stays
 * the loudest.
 */
export function decay(a, seconds) {
  const k = Math.log(10) / (seconds * a.sampleRate);
  return { sampleRate: a.sampleRate, channels: a.channels.map((c) => c.map((v, i) => v * Math.exp(-k * i))) };
}

export function gain(a, db) {
  const g = dbToGain(db);
  return { sampleRate: a.sampleRate, channels: a.channels.map((c) => c.map((v) => v * g)) };
}

export function peak(a) {
  let p = 0;
  for (const ch of a.channels) for (let i = 0; i < ch.length; i++) p = Math.max(p, Math.abs(ch[i]));
  return p;
}

export function rms(a) {
  let s = 0;
  let n = 0;
  for (const ch of a.channels) {
    for (let i = 0; i < ch.length; i++) s += ch[i] * ch[i];
    n += ch.length;
  }
  return n ? Math.sqrt(s / n) : 0;
}

/**
 * Scales to a target peak (dBFS), or to a target RMS (dBFS) without letting
 * the peak exceed ceilingDb.
 */
export function normalize(a, { peakDb, rmsDb, ceilingDb = -0.5 } = {}) {
  const p = peak(a);
  if (p === 0) return clone(a);
  let g;
  if (rmsDb != null) {
    g = dbToGain(rmsDb) / Math.max(1e-9, rms(a));
    g = Math.min(g, dbToGain(ceilingDb) / p);
  } else {
    g = dbToGain(peakDb ?? -1) / p;
  }
  return { sampleRate: a.sampleRate, channels: a.channels.map((c) => c.map((v) => v * g)) };
}

// ------------------------------------------------------------------ filters

/** One-pole low-pass (6 dB per octave); order 2 runs it twice. */
export function lowpass(a, hz, order = 1) {
  const k = 1 - Math.exp((-2 * Math.PI * hz) / a.sampleRate);
  let out = a;
  for (let o = 0; o < order; o++) {
    out = {
      sampleRate: a.sampleRate,
      channels: out.channels.map((src) => {
        const dst = new Float32Array(src.length);
        let y = 0;
        for (let i = 0; i < src.length; i++) dst[i] = y += k * (src[i] - y);
        return dst;
      }),
    };
  }
  return out;
}

/** One-pole high-pass (6 dB per octave); order 2 runs it twice. */
export function highpass(a, hz, order = 1) {
  const k = 1 - Math.exp((-2 * Math.PI * hz) / a.sampleRate);
  let out = a;
  for (let o = 0; o < order; o++) {
    out = {
      sampleRate: a.sampleRate,
      channels: out.channels.map((src) => {
        const dst = new Float32Array(src.length);
        let y = 0;
        for (let i = 0; i < src.length; i++) {
          y += k * (src[i] - y);
          dst[i] = src[i] - y;
        }
        return dst;
      }),
    };
  }
  return out;
}

/**
 * A shelf built from a one-pole split: boosts or cuts everything below (low)
 * or above (high) hz by db.
 */
export function shelf(a, type, hz, db) {
  const g = dbToGain(db) - 1;
  const lo = lowpass(a, hz);
  return {
    sampleRate: a.sampleRate,
    channels: a.channels.map((src, c) => {
      const l = lo.channels[c];
      const dst = new Float32Array(src.length);
      for (let i = 0; i < src.length; i++) dst[i] = src[i] + g * (type === 'low' ? l[i] : src[i] - l[i]);
      return dst;
    }),
  };
}

/** Soft saturation (tanh) with drive in dB, level-compensated. */
export function saturate(a, driveDb) {
  const d = dbToGain(driveDb);
  const comp = 1 / Math.tanh(d);
  return { sampleRate: a.sampleRate, channels: a.channels.map((c) => c.map((v) => Math.tanh(v * d) * comp)) };
}

// ------------------------------------------------------------------ mixing

/**
 * Mixes layers into one clip. Each layer: {audio, offset (s), gainDb, pan
 * (-1..1, only when mixing to stereo)}. All layers must share a sample rate.
 * @param {{audio: Audio, offset?: number, gainDb?: number, pan?: number}[]} layers
 * @param {{channels?: number, length?: number}} [opts]
 */
export function mix(layers, { channels = 1, length } = {}) {
  if (!layers.length) throw new Error('mix: no layers');
  const sr = layers[0].audio.sampleRate;
  for (const l of layers) if (l.audio.sampleRate !== sr) throw new Error('mix: sample rates differ');
  const end = Math.max(...layers.map((l) => Math.round((l.offset ?? 0) * sr) + frames(l.audio)));
  const n = length != null ? Math.round(length * sr) : end;
  const out = Array.from({ length: channels }, () => new Float32Array(n));
  for (const l of layers) {
    const src = channels === 1 ? toMono(l.audio) : l.audio.channels.length === channels ? l.audio : toStereo(l.audio);
    const g = dbToGain(l.gainDb ?? 0);
    const off = Math.round((l.offset ?? 0) * sr);
    const pan = l.pan ?? 0;
    for (let c = 0; c < channels; c++) {
      const pg = channels === 2 ? Math.cos(((c === 0 ? pan + 1 : 1 - pan) * Math.PI) / 4) * Math.SQRT2 : 1;
      const s = src.channels[c];
      const d = out[c];
      for (let i = 0; i < s.length; i++) {
        const k = off + i;
        if (k >= 0 && k < n) d[k] += s[i] * g * pg;
      }
    }
  }
  return { sampleRate: sr, channels: out };
}

/** Appends clips one after another. */
export function concat(clips) {
  return mix(
    clips.reduce(
      (acc, audio) => {
        acc.layers.push({ audio, offset: acc.t });
        acc.t += duration(audio);
        return acc;
      },
      { layers: [], t: 0 },
    ).layers,
    { channels: clips[0].channels.length },
  );
}

/**
 * Makes a seamless loop of `seconds` from a longer recording: the audio just
 * past the loop end is crossfaded (equal power) into the loop start, so the
 * last sample flows into the first.
 */
export function loopCrossfade(a, seconds, fadeSeconds) {
  const sr = a.sampleRate;
  const L = Math.round(seconds * sr);
  const F = Math.round(fadeSeconds * sr);
  if (frames(a) < L + F) throw new Error(`loopCrossfade: need ${((L + F) / sr).toFixed(2)} s, have ${duration(a).toFixed(2)} s`);
  const channels = a.channels.map((src) => {
    const out = src.slice(0, L);
    for (let i = 0; i < F; i++) {
      const x = i / F;
      const fin = Math.sin((x * Math.PI) / 2);
      const fout = Math.cos((x * Math.PI) / 2);
      out[i] = src[i] * fin + src[L + i] * fout;
    }
    return out;
  });
  return { sampleRate: sr, channels };
}

// ------------------------------------------------------------------ analysis

/**
 * Finds the starts of separate hits or takes in a recording: points where a
 * short-term level jumps well above the level just before it.
 * Returns [{time, peakDb}] sorted by time.
 */
export function onsets(a, { hop: hopWanted = 0.005, riseDb = 12, floorDb = -40, minGap = 0.25 } = {}) {
  const m = toMono(a);
  const src = m.channels[0];
  const w = Math.max(1, Math.round(hopWanted * a.sampleRate));
  const hop = w / a.sampleRate;
  const count = Math.floor(src.length / w);
  const lvl = new Float32Array(count);
  for (let k = 0; k < count; k++) {
    let s = 0;
    for (let i = k * w; i < (k + 1) * w; i++) s += src[i] * src[i];
    lvl[k] = gainToDb(Math.sqrt(s / w) + 1e-12);
  }
  const back = Math.max(1, Math.round(0.05 / hop));
  const found = [];
  let lastT = -Infinity;
  for (let k = 0; k < count; k++) {
    let before = -120; // silence before the file starts
    for (let j = Math.max(0, k - back); j < k; j++) before = Math.max(before, lvl[j]);
    const t = k * hop;
    if (lvl[k] > floorDb && lvl[k] - before >= riseDb && t - lastT >= minGap) {
      // Walk back to where the rise begins.
      let s = k;
      while (s > 0 && lvl[s - 1] < lvl[s] && lvl[k] - lvl[s - 1] < riseDb + 20) s--;
      let pk = -Infinity;
      for (let j = k; j < Math.min(count, k + Math.round(0.1 / hop)); j++) pk = Math.max(pk, lvl[j]);
      found.push({ time: s * hop, peakDb: pk });
      lastT = t;
    }
  }
  return found;
}

/**
 * Splits a recording of separate takes at its silences: returns the regions
 * louder than floorDb that are separated by at least minSilence seconds of
 * quiet, each with the time of its loudest moment.
 * Returns [{start, end, peakTime, peakDb}] in seconds.
 */
export function regions(a, { floorDb = -50, minSilence = 0.3, minLength = 0.03, hop: hopWanted = 0.005 } = {}) {
  const lv = levels(a, hopWanted);
  const hop = Math.max(1, Math.round(hopWanted * a.sampleRate)) / a.sampleRate; // the hop actually used
  const quietHops = Math.round(minSilence / hop);
  const out = [];
  let k = 0;
  while (k < lv.length) {
    while (k < lv.length && lv[k] < floorDb) k++;
    if (k >= lv.length) break;
    const start = k;
    let lastLoud = k;
    let pk = -Infinity;
    let pkAt = k;
    while (k < lv.length && k - lastLoud <= quietHops) {
      if (lv[k] >= floorDb) lastLoud = k;
      if (lv[k] > pk) (pk = lv[k]), (pkAt = k);
      k++;
    }
    const end = lastLoud + 1;
    if ((end - start) * hop >= minLength) {
      out.push({ start: start * hop, end: end * hop, peakTime: pkAt * hop, peakDb: +pk.toFixed(1) });
    }
  }
  return out;
}

/** Short-term RMS level in dBFS every `hop` seconds (all channels mixed). */
export function levels(a, hop = 0.01) {
  const src = toMono(a).channels[0];
  const w = Math.max(1, Math.round(hop * a.sampleRate));
  const out = [];
  for (let k = 0; k + w <= src.length; k += w) {
    let s = 0;
    for (let i = k; i < k + w; i++) s += src[i] * src[i];
    out.push(gainToDb(Math.sqrt(s / w) + 1e-12));
  }
  return out;
}

/**
 * The time (s) of the loudest sample between start and end seconds, all
 * channels mixed: where an impact lands, for anchoring a slice to it.
 */
export function peakTime(a, start = 0, end = Infinity) {
  const n = frames(a);
  const s = Math.max(0, Math.round(start * a.sampleRate));
  const e = Math.min(n, Math.round(end * a.sampleRate));
  const k = 1 / a.channels.length;
  let best = -1;
  let at = s;
  for (let i = s; i < e; i++) {
    let v = 0;
    for (const ch of a.channels) v += ch[i];
    v = Math.abs(v * k);
    if (v > best) (best = v), (at = i);
  }
  return at / a.sampleRate;
}

/**
 * Short-term loudness: the RMS level (dBFS) of the loudest `seconds` window,
 * channels averaged. With the default 100 ms it is what the variations of a
 * pool are matched on, because it follows how loud a short effect sounds far
 * better than its sample peak does.
 */
export function shortTermLoudness(a, seconds = 0.1) {
  const n = frames(a);
  if (!n) return -Infinity;
  const w = Math.max(1, Math.round(seconds * a.sampleRate));
  const k = 1 / a.channels.length;
  const sq = new Float64Array(n);
  for (const ch of a.channels) for (let i = 0; i < n; i++) sq[i] += ch[i] * ch[i] * k;
  let s = 0;
  let best = 0;
  for (let i = 0; i < n; i++) {
    s += sq[i];
    if (i >= w) s -= sq[i - w];
    if (s > best) best = s;
  }
  return gainToDb(Math.sqrt(best / Math.min(w, n)));
}

/**
 * A look-ahead peak limiter: no sample comes out above ceilingDb. The gain
 * ramps down over `lookahead` seconds before each peak and recovers over
 * `release` seconds (channels linked).
 */
export function limit(a, ceilingDb, { lookahead = 0.002, release = 0.05 } = {}) {
  const c = dbToGain(ceilingDb);
  const n = frames(a);
  const L = Math.max(1, Math.round(lookahead * a.sampleRate));
  const need = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    let m = 0;
    for (const ch of a.channels) m = Math.max(m, Math.abs(ch[i]));
    need[i] = m > c ? c / m : 1;
  }
  // The lowest gain needed over the next L samples, with a smooth recovery.
  const rel = Math.exp(-1 / (release * a.sampleRate));
  const held = new Float32Array(n);
  let g = 1;
  for (let i = 0; i < n; i++) {
    let m = 1;
    for (let j = i; j < Math.min(n, i + L); j++) if (need[j] < m) m = need[j];
    g = Math.min(m, 1 - (1 - g) * rel);
    held[i] = g;
  }
  // Averaging the last L values ramps the gain down in time and, as each of
  // them already covers sample i, never lets it exceed what sample i needs.
  const gains = new Float32Array(n);
  let sum = 0;
  for (let i = 0; i < n; i++) {
    sum += held[i];
    if (i >= L) sum -= held[i - L];
    gains[i] = sum / Math.min(L, i + 1);
  }
  return { sampleRate: a.sampleRate, channels: a.channels.map((ch) => ch.map((v, i) => v * gains[i])) };
}

/**
 * Sets a clip's short-term loudness (see shortTermLoudness) to loudnessDb.
 * Where that would push a peak over ceilingDb, the peaks are limited instead,
 * and the gain is corrected until the loudness lands on the target.
 * Returns the audio, the gain applied and the most the limiter took off (dB).
 */
export function matchLoudness(a, { loudnessDb, ceilingDb = -1, window = 0.1 }) {
  let g = loudnessDb - shortTermLoudness(a, window);
  let out = a;
  let reduction = 0;
  for (let iter = 0; iter < 8; iter++) {
    out = gain(a, g);
    const over = gainToDb(peak(out)) - ceilingDb;
    reduction = Math.max(0, over);
    // A quick release: what is limited here are short transients.
    if (over > 0) out = limit(out, ceilingDb, { release: 0.01 });
    const err = loudnessDb - shortTermLoudness(out, window);
    if (Math.abs(err) < 0.02) break;
    g += err;
  }
  return { audio: out, gainDb: g, limitedDb: reduction };
}

/**
 * A last small gain toward the pool's loudness after trimming and fading,
 * which shift it a little on clips shorter than the 100 ms window; it never
 * lifts a peak over the ceiling.
 */
export function settleLoudness(a, { loudnessDb, ceilingDb = -1, window = 0.1 }) {
  const g = Math.min(loudnessDb - shortTermLoudness(a, window), ceilingDb - gainToDb(peak(a)));
  return Math.abs(g) < 0.005 ? a : gain(a, g);
}

/**
 * Subtracts each channel's mean. Limiting a one-sided transient, or cutting
 * a high-passed tail short, leaves a small DC offset; on a one-shot effect,
 * before its fades, this takes it out.
 */
export function removeDc(a) {
  return {
    sampleRate: a.sampleRate,
    channels: a.channels.map((c) => {
      let s = 0;
      for (let i = 0; i < c.length; i++) s += c[i];
      const m = c.length ? s / c.length : 0;
      return c.map((v) => v - m);
    }),
  };
}

/** Peak and RMS in dBFS, and length. */
export function stats(a) {
  return {
    seconds: +duration(a).toFixed(3),
    peakDb: +gainToDb(peak(a)).toFixed(1),
    rmsDb: +gainToDb(rms(a)).toFixed(1),
    channels: a.channels.length,
    sampleRate: a.sampleRate,
  };
}
