// Instruments shared by the generated sound effects (synth.mjs) and the
// placeholder music (music.mjs). Each one renders a single stroke or note into
// a mono Float32Array; `r` is a seeded random helper from rng.mjs.

import {
  SR,
  addInto,
  buffer,
  drive,
  expEnv,
  filter,
  modes,
  noiseBurst,
  pluck,
  tone,
  wave,
  whiteNoise,
  Biquad,
} from './synthkit.mjs';

export const midiToHz = (m) => 440 * Math.pow(2, (m - 69) / 12);

// ------------------------------------------------------------------ percussion

/**
 * Taiko: the demo's pitched-down sine thump, triangle overtone and noise, plus
 * the drum head's higher membrane modes and the slap of the bachi.
 * weight 0 = light (a higher, shorter shime-like stroke), 1 = heavy (odaiko).
 */
export function taiko(dst, r, { weight = 0.5, accent = 1, t0 = 0 } = {}) {
  const f = 110 - weight * 45 + r.range(-3, 3); // heavy ~65 Hz, light ~110 Hz
  const len = 0.35 + weight * 0.7;
  tone(dst, { freq: f * 1.9, freqEnd: f, peak: 0.95 * accent, attack: 0.002, decay: len, t0 });
  tone(dst, { freq: f * 2 * 1.9, freqEnd: f * 2, type: 'triangle', peak: 0.15 * accent, attack: 0.002, decay: 0.12, t0 });
  // membrane modes (circular drum head ratios), decaying faster than the fundamental
  modes(
    dst,
    [
      { f: f * 1.59, amp: 0.22 * accent, decay: len * 0.45 },
      { f: f * 2.14, amp: 0.14 * accent, decay: len * 0.3 },
      { f: f * 2.65, amp: 0.08 * accent, decay: len * 0.22 },
      { f: f * 3.16, amp: 0.05 * accent, decay: len * 0.16 },
    ],
    { t0, rand: r.next },
  );
  // bachi slap and the head's buzz
  noiseBurst(dst, { peak: 0.3 * accent, attack: 0.001, decay: 0.05, type: 'lowpass', f0: 500, t0, rand: r.next });
  noiseBurst(dst, { peak: (0.18 - weight * 0.08) * accent, attack: 0.001, decay: 0.018, type: 'bandpass', f0: 1800, q: 0.9, t0, rand: r.next });
  // the shell's low bloom
  noiseBurst(dst, { peak: 0.12 * accent * (0.5 + weight), attack: 0.01, decay: len * 0.8, type: 'lowpass', f0: 180, t0, rand: r.next });
  return dst;
}

/** The "ka": a stick on the drum's rim, as the demo's music used. */
export function ka(dst, r, { accent = 1, t0 = 0 } = {}) {
  noiseBurst(dst, { peak: 0.35 * accent, attack: 0.0008, decay: 0.03, type: 'highpass', f0: 3500, t0, rand: r.next });
  modes(dst, [{ f: 1850 + r.range(-40, 40), amp: 0.25 * accent, decay: 0.06 }, { f: 3120, amp: 0.1 * accent, decay: 0.04 }], { t0, rand: r.next });
  return dst;
}

/**
 * Gong: the demo's six partials on 98 Hz (plus two), with slow beating, the
 * higher partials swelling after the strike (a gong's bloom) and a soft
 * mallet thump.
 */
export function gong(dst, r, { t0 = 0, f0 = 98, len = 4.2, accent = 1 } = {}) {
  const ratios = [1, 1.52, 2.13, 2.74, 3.43, 4.6, 5.9, 7.1];
  modes(
    dst,
    ratios.map((p, i) => ({
      f: f0 * p,
      amp: (0.24 / (1 + i * 0.5)) * accent,
      decay: Math.max(0.8, len - i * 0.35),
      beat: 0.4 + i * 0.35,
      swell: i >= 3 ? 0.12 + i * 0.04 : 0,
      glide: i >= 4 ? 0.004 : -0.002,
    })),
    { t0, attack: 0.008, rand: r.next },
  );
  noiseBurst(dst, { peak: 0.15 * accent, attack: 0.005, decay: 0.3, type: 'lowpass', f0: 800, t0, rand: r.next });
  noiseBurst(dst, { peak: 0.05 * accent, attack: 0.3, decay: 1.8, type: 'bandpass', f0: 2600, q: 2, t0, rand: r.next }); // shimmer wash
  return dst;
}

/** Electronic kick: a fast sine drop with a click. */
export function kick(r, { accent = 1, tune = 1 } = {}) {
  const b = buffer(0.45);
  tone(b, { freq: 160 * tune, freqEnd: 44 * tune, peak: 1.0 * accent, attack: 0.001, decay: 0.38 });
  tone(b, { freq: 320 * tune, freqEnd: 90 * tune, peak: 0.25 * accent, attack: 0.001, decay: 0.05 });
  noiseBurst(b, { peak: 0.25 * accent, attack: 0.0005, decay: 0.008, type: 'highpass', f0: 2500, rand: r.next });
  return drive(b, 1.4);
}

/** Snare: a tuned body and bright noise. */
export function snare(r, { accent = 1 } = {}) {
  const b = buffer(0.35);
  tone(b, { freq: 230, freqEnd: 180, peak: 0.45 * accent, attack: 0.001, decay: 0.09 });
  tone(b, { freq: 360, freqEnd: 300, peak: 0.2 * accent, attack: 0.001, decay: 0.06 });
  noiseBurst(b, { peak: 0.6 * accent, attack: 0.001, decay: 0.2, type: 'bandpass', f0: 3800, q: 0.6, rand: r.next });
  noiseBurst(b, { peak: 0.3 * accent, attack: 0.001, decay: 0.06, type: 'highpass', f0: 6000, rand: r.next });
  return b;
}

/** Hi-hat: closed (short) or open. */
export function hat(r, { accent = 1, open = false } = {}) {
  const b = buffer(open ? 0.35 : 0.08);
  noiseBurst(b, { peak: 0.35 * accent, attack: 0.0008, decay: open ? 0.28 : 0.035, type: 'highpass', f0: 7500, rand: r.next });
  modes(b, [{ f: 6100, amp: 0.03 * accent, decay: open ? 0.2 : 0.03 }, { f: 8350, amp: 0.02 * accent, decay: open ? 0.15 : 0.02 }], { rand: r.next });
  return b;
}

/** Wood block (mokugyo-like): two woody modes and a click. */
export function woodblock(r, { accent = 1, pitch = 1 } = {}) {
  const b = buffer(0.15);
  modes(b, [{ f: 820 * pitch, amp: 0.5 * accent, decay: 0.09 }, { f: 2170 * pitch, amp: 0.15 * accent, decay: 0.04 }], { attack: 0.0005, rand: r.next });
  noiseBurst(b, { peak: 0.2 * accent, attack: 0.0005, decay: 0.006, type: 'bandpass', f0: 3000, q: 1, rand: r.next });
  return b;
}

/** Shaker: a short burst of band-passed noise with a soft attack. */
export function shaker(r, { accent = 1 } = {}) {
  const b = buffer(0.09);
  noiseBurst(b, { peak: 0.2 * accent, attack: 0.012, decay: 0.05, type: 'bandpass', f0: 6500, q: 1.2, rand: r.next });
  return b;
}

/** Noise riser into a downbeat (a reverse-cymbal swell). */
export function riser(r, seconds, { accent = 1, f0 = 400, f1 = 9000 } = {}) {
  const b = whiteNoise(seconds, r.next);
  filter(b, 'bandpass', f0, { f1, q: 1.4 });
  for (let i = 0; i < b.length; i++) {
    const x = i / b.length;
    b[i] *= 0.25 * accent * x * x * x;
  }
  return b;
}

// ------------------------------------------------------------------ pitched

/**
 * Shamisen-like pluck: a bright Karplus-Strong string with the sawari buzz and
 * the demo's bachi attack boost.
 */
export function shamisen(r, midi, { seconds = 1.2, accent = 1, mute = 0 } = {}) {
  const b = pluck(midiToHz(midi), seconds, r.next, { decay: 0.995, bright: 0.62, buzz: 0.25, attackBoost: 1.0, mute, pickPos: 0.12 });
  // the skin-covered body: a nasal mid resonance
  filter(b, 'peaking', 1400, { q: 1.2, gainDb: 5 });
  filter(b, 'highpass', 120, { q: 0.7 });
  for (let i = 0; i < b.length; i++) b[i] *= 0.5 * accent;
  return b;
}

/** Koto-like muted pluck for the menu's patterns. */
export function koto(r, midi, { seconds = 0.9, accent = 1, mute = 0.5 } = {}) {
  const b = pluck(midiToHz(midi), seconds, r.next, { decay: 0.996, bright: 0.5, attackBoost: 0.6, mute, pickPos: 0.2 });
  filter(b, 'lowpass', 3200, { q: 0.7 });
  for (let i = 0; i < b.length; i++) b[i] *= 0.5 * accent;
  return b;
}

/**
 * Electric piano (FM, Rhodes-like): a sine carrier with a 1:1 modulator whose
 * index falls after the strike, a short high "tine" partial and a soft release.
 *
 * The carrier and the modulator share one phase. With a 1:1 ratio the lower
 * sideband sits at carrier minus modulator, so any detune or phase offset
 * between them puts a component at or near 0 Hz: a slow DC drift under the
 * note. Locked together, sin(p + I sin p) is odd about p = 0 and has no DC.
 * The random detune moves the whole voice instead.
 */
export function epiano(r, midi, { length = 0.5, accent = 1 } = {}) {
  const f = midiToHz(midi);
  const tail = 0.5;
  const b = buffer(length + tail);
  let p = r.next();
  r.next(); // was the modulator's own phase; still drawn so the seeded sequence is unchanged
  let pt = 0;
  const fv = f * (1 + r.range(-0.0015, 0.0015));
  for (let i = 0; i < b.length; i++) {
    const t = i / SR;
    const idx = 0.35 + (1.8 * accent + 0.4) * Math.exp(-t * 6);
    const mod = Math.sin(2 * Math.PI * p) * idx;
    const amp = Math.min(1, t / 0.003) * Math.exp(-t * 1.4) * (t > length ? Math.exp(-(t - length) * 14) : 1);
    const tine = Math.sin(2 * Math.PI * pt) * 0.18 * Math.exp(-t * 40);
    b[i] = (Math.sin(2 * Math.PI * p + mod) + tine) * amp * 0.35 * accent;
    p += fv / SR;
    pt += (f * 14.1) / SR;
    p -= Math.floor(p);
    pt -= Math.floor(pt);
  }
  return b;
}

/**
 * Bass guitar (fingered or slapped): a saw and sine through a low-pass whose
 * cutoff jumps on the pluck, with a little drive. `pop` brightens accents.
 */
export function bass(r, midi, { length = 0.3, accent = 1, pop = 0, sub = 0.5 } = {}) {
  const f = midiToHz(midi);
  const b = buffer(length + 0.08);
  const lp = new Biquad('lowpass', 800, 1.1);
  let ph = r.next();
  for (let i = 0; i < b.length; i++) {
    const t = i / SR;
    if ((i & 15) === 0) lp.set(180 + (900 + pop * 2200) * Math.exp(-t * (18 - pop * 8)));
    const dt = f / SR;
    const v = wave('sawtooth', ph, dt) * 0.6 + Math.sin(2 * Math.PI * ph) * sub;
    const amp = Math.min(1, t / 0.004) * Math.exp(-t * 2.5) * (t > length ? Math.exp(-(t - length) * 60) : 1);
    b[i] = lp.step(v) * amp * 0.6 * accent;
    ph += dt;
    ph -= Math.floor(ph);
  }
  return drive(b, 1.5);
}

/** A sub-bass sine under the metal riffs. */
export function subBass(r, midi, { length = 0.2, accent = 1 } = {}) {
  const f = midiToHz(midi);
  const b = buffer(length + 0.05);
  let ph = 0;
  for (let i = 0; i < b.length; i++) {
    const t = i / SR;
    b[i] = Math.sin(2 * Math.PI * ph) * Math.min(1, t / 0.005) * (t > length ? Math.exp(-(t - length) * 50) : 1) * 0.6 * accent;
    ph += f / SR;
  }
  return b;
}

/**
 * Distorted electric guitar power chord: Karplus-Strong strings for the root,
 * fifth and octave, heavily driven, then shaped like a guitar cabinet. Palm
 * muting (`mute`) shortens and darkens the strings before the distortion, as
 * the demo's chug did with its short envelope and 1.1 kHz low-pass.
 */
export function powerChord(r, midi, { length = 0.2, accent = 1, mute = 1, gain = 9 } = {}) {
  const seconds = length + 0.12;
  const b = buffer(seconds);
  for (const [iv, lvl] of [[0, 1], [7, 0.8], [12, 0.5]]) {
    const s = pluck(midiToHz(midi + iv) * (1 + r.range(-0.002, 0.002)), seconds, r.next, {
      decay: 0.997,
      bright: mute ? 0.35 : 0.55,
      attackBoost: 0.4,
      mute: mute ? 1 : 0,
      pickPos: 0.15,
    });
    addInto(b, s, r.range(0, 0.004), lvl);
  }
  filter(b, 'highpass', 90, { q: 0.7 });
  if (mute) filter(b, 'lowpass', 900, { q: 0.8 });
  for (let i = 0; i < b.length; i++) b[i] *= accent * (mute ? 1.4 : 1);
  drive(b, gain);
  // cabinet: no deep lows, a mid bump, and nothing fizzy above 5 kHz
  filter(b, 'highpass', 100, { q: 0.7 });
  filter(b, 'peaking', 1600, { q: 0.9, gainDb: 3 });
  filter(b, 'lowpass', 4800, { q: 0.7 });
  filter(b, 'lowpass', 5200, { q: 0.7 });
  // the player's hand stops the strings at the end of the note
  const stop = Math.round(length * SR);
  for (let i = stop; i < b.length; i++) b[i] *= Math.exp(-(i - stop) / (0.012 * SR));
  for (let i = 0; i < b.length; i++) b[i] *= 0.3;
  return b;
}

/**
 * Lead voice: a breathy, bending shakuhachi-like tone (sine and triangle with
 * delayed vibrato and a slide up into each note) doubled by a soft detuned saw
 * for weight. `from` is the MIDI note it slides from.
 */
export function lead(r, midi, { length = 0.5, accent = 1, from = null, saw = 0.35, breath = 0.35 } = {}) {
  const f1 = midiToHz(midi);
  const f0 = from != null ? midiToHz(from) : f1 * Math.pow(2, -0.6 / 12);
  const release = 0.12;
  const b = buffer(length + release);
  const glide = from != null ? 0.06 : 0.035;
  const breathNoise = whiteNoise(length + release, r.next);
  filter(breathNoise, 'bandpass', f1 * 2, { q: 3 });
  const lp = new Biquad('lowpass', 2600, 0.8);
  let ph1 = r.next();
  let ph2 = r.next();
  let ph3 = r.next();
  const vibRate = r.range(5.2, 6.0);
  for (let i = 0; i < b.length; i++) {
    const t = i / SR;
    const g = Math.min(1, t / glide);
    const vib = 1 + 0.006 * Math.sin(2 * Math.PI * vibRate * t) * Math.min(1, Math.max(0, (t - 0.18) / 0.25));
    const f = (f0 + (f1 - f0) * (1 - (1 - g) * (1 - g))) * vib;
    const amp = Math.min(1, t / 0.025) * (t > length ? Math.exp(-(t - length) * 30) : 1) * (0.85 + 0.15 * Math.exp(-t * 3));
    const tonal = Math.sin(2 * Math.PI * ph1) * 0.7 + wave('triangle', ph2, f / SR) * 0.3;
    const sawv = (wave('sawtooth', ph3, (f * 1.004) / SR) + wave('sawtooth', (ph3 + 0.37) % 1, (f * 0.996) / SR)) * 0.5;
    b[i] = (tonal + lp.step(sawv) * saw + breathNoise[i] * breath * 3 * (0.4 + 0.6 * Math.exp(-t * 8))) * amp * 0.3 * accent;
    ph1 += f / SR;
    ph2 += f / SR;
    ph3 += f / SR;
    ph1 -= Math.floor(ph1);
    ph2 -= Math.floor(ph2);
    ph3 -= Math.floor(ph3);
  }
  return drive(b, 1.3);
}

/** A slow, dark pad: detuned saws through a low-pass (the demo's drone). */
export function pad(r, midis, { length = 4, accent = 1, cutoff = 600 } = {}) {
  const b = buffer(length + 1.5);
  for (const m of midis) {
    for (const d of [-0.004, 0, 0.004]) {
      const f = midiToHz(m) * (1 + d);
      let ph = r.next();
      for (let i = 0; i < b.length; i++) {
        const t = i / SR;
        const amp = Math.min(1, t / 1.2) * (t > length ? Math.exp(-(t - length) * 2.5) : 1);
        b[i] += wave('sawtooth', ph, f / SR) * amp * 0.05 * accent;
        ph += f / SR;
        ph -= Math.floor(ph);
      }
    }
  }
  filter(b, 'lowpass', cutoff, { q: 0.9 });
  filter(b, 'lowpass', cutoff * 1.5, { q: 0.6 });
  return b;
}

/** Re-exported for the music script's fills. */
export { expEnv };
