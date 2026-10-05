// Measurements the audio tests make on the committed sounds: the same ones
// the audio verification pass used (its tempo, attack, loudness and DC
// checks), written independently of scripts/audio so the tests do not grade
// the scripts with their own code.

const db = (x) => (x > 0 ? 20 * Math.log10(x) : -Infinity);

function mono(a) {
  const n = a.channels[0].length;
  const out = new Float64Array(n);
  for (const ch of a.channels) for (let i = 0; i < n; i++) out[i] += ch[i] / a.channels.length;
  return out;
}

/** In-place radix-2 FFT. */
function fft(re, im) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      [re[i], re[j]] = [re[j], re[i]];
      [im[i], im[j]] = [im[j], im[i]];
    }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (-2 * Math.PI) / len;
    const wr = Math.cos(ang);
    const wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1;
      let ci = 0;
      for (let k = 0; k < len / 2; k++) {
        const a = i + k;
        const b = a + len / 2;
        const tr = re[b] * cr - im[b] * ci;
        const ti = re[b] * ci + im[b] * cr;
        re[b] = re[a] - tr;
        im[b] = im[a] - ti;
        re[a] += tr;
        im[a] += ti;
        const ncr = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = ncr;
      }
    }
  }
}

/**
 * The strongest beat (BPM) of a seamless loop between 60 and 200 BPM: the
 * biggest peak of the circular autocorrelation of its spectral-flux onset
 * envelope (log magnitudes, 1024-point frames every 128 samples, local mean
 * over 0.5 s removed).
 */
export function strongestBeat(a, { lo = 60, hi = 200 } = {}) {
  const x = mono(a);
  const n = x.length;
  const N = 1024;
  const H = 128;
  const fr = a.sampleRate / H;
  const frames = Math.floor(n / H);
  const hann = Float64Array.from({ length: N }, (_, i) => 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / N));
  const re = new Float64Array(N);
  const im = new Float64Array(N);
  const spectrum = (f) => {
    for (let i = 0; i < N; i++) {
      re[i] = x[(((f * H + i - N / 2) % n) + n) % n] * hann[i];
      im[i] = 0;
    }
    fft(re, im);
    const mag = new Float64Array(N / 2);
    for (let k = 0; k < N / 2; k++) mag[k] = Math.log1p(1000 * Math.hypot(re[k], im[k]));
    return mag;
  };
  const flux = new Float64Array(frames);
  let prev = spectrum(frames - 1);
  for (let f = 0; f < frames; f++) {
    const cur = spectrum(f);
    let s = 0;
    for (let k = 1; k < N / 2; k++) if (cur[k] > prev[k]) s += cur[k] - prev[k];
    flux[f] = s;
    prev = cur;
  }
  const L = Math.round(fr * 0.25);
  const env = new Float64Array(frames);
  for (let f = 0; f < frames; f++) {
    let s = 0;
    for (let k = -L; k <= L; k++) s += flux[(f + k + frames) % frames];
    env[f] = Math.max(0, flux[f] - s / (2 * L + 1));
  }
  const mean = env.reduce((p, q) => p + q, 0) / frames;
  for (let f = 0; f < frames; f++) env[f] -= mean;
  const lagOf = (bpm) => (60 * fr) / bpm;
  const minLag = Math.floor(lagOf(hi)) - 1;
  const maxLag = Math.ceil(lagOf(lo)) + 1;
  const acf = new Float64Array(maxLag + 2);
  for (let lag = minLag; lag <= maxLag + 1; lag++) {
    let s = 0;
    for (let f = 0; f < frames; f++) s += env[f] * env[(f + lag) % frames];
    acf[lag] = s;
  }
  let best = -Infinity;
  let bestLag = 0;
  for (let lag = Math.ceil(lagOf(hi)); lag <= Math.floor(lagOf(lo)); lag++) {
    if (acf[lag] >= acf[lag - 1] && acf[lag] >= acf[lag + 1] && acf[lag] > best) (best = acf[lag]), (bestLag = lag);
  }
  const [y0, y1, y2] = [acf[bestLag - 1], acf[bestLag], acf[bestLag + 1]];
  const d = y0 - 2 * y1 + y2;
  return (60 * fr) / (d === 0 ? bestLag : bestLag + (0.5 * (y0 - y2)) / d);
}

/** RMS level (dBFS) in 5 ms windows every 1 ms, channels together. */
export function envelope(a) {
  const sr = a.sampleRate;
  const hop = Math.round(0.001 * sr);
  const win = Math.round(0.005 * sr);
  const n = a.channels[0].length;
  const out = [];
  for (let s = 0; s + win <= n; s += hop) {
    let e = 0;
    for (const ch of a.channels) for (let i = s; i < s + win; i++) e += ch[i] * ch[i];
    out.push(db(Math.sqrt(e / (win * a.channels.length))));
  }
  return out;
}

/**
 * Where a one-shot hits: the envelope's loudest millisecond, and the loudest
 * later hit (a local maximum rising 9 dB over the 40 ms before it, more than
 * 30 ms after the loudest point) in dB relative to it.
 */
export function attack(a) {
  const env = envelope(a);
  const top = Math.max(...env);
  const peakMs = env.indexOf(top);
  let laterDb = -Infinity;
  for (let i = peakMs + 31; i < env.length - 1; i++) {
    if (!(env[i] >= env[i - 1] && env[i] > env[i + 1]) || env[i] < top - 12) continue;
    const before = Math.min(...env.slice(Math.max(0, i - 40), i));
    if (env[i] - before >= 9) laterDb = Math.max(laterDb, env[i] - top);
  }
  return { peakMs, laterDb };
}

/** Short-term loudness: the RMS level (dBFS) of the loudest 100 ms. */
export function loudness(a) {
  const w = Math.round(0.1 * a.sampleRate);
  const n = a.channels[0].length;
  const sq = new Float64Array(n);
  for (const ch of a.channels) for (let i = 0; i < n; i++) sq[i] += (ch[i] * ch[i]) / a.channels.length;
  let s = 0;
  let best = 0;
  for (let i = 0; i < n; i++) {
    s += sq[i];
    if (i >= w) s -= sq[i - w];
    best = Math.max(best, s);
  }
  return db(Math.sqrt(best / Math.min(w, n)));
}

/** The worse channel's mean, in dBFS. */
export function dcDb(a) {
  return Math.max(...a.channels.map((ch) => db(Math.abs(ch.reduce((p, q) => p + q, 0) / ch.length))));
}

/** Milliseconds after the last sample at or above -60 dBFS. */
export function tailMs(a) {
  const thr = Math.pow(10, -60 / 20);
  const n = a.channels[0].length;
  let last = n - 1;
  while (last >= 0 && a.channels.every((ch) => Math.abs(ch[last]) < thr)) last--;
  return ((n - 1 - last) / a.sampleRate) * 1000;
}

export function peakDb(a) {
  let p = 0;
  for (const ch of a.channels) for (let i = 0; i < ch.length; i++) p = Math.max(p, Math.abs(ch[i]));
  return db(p);
}
