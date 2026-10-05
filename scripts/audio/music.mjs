#!/usr/bin/env node
// Generates the three placeholder music loops (stereo, 16-bit, 44.1 kHz) into
// game/assets/audio/music/, and tracks.json with each track's tempo and length.
//
//   menu_110.wav         110 BPM, 16 bars: slower, groovy electric and oriental funk
//   battle_140.wav       140 BPM, 16 bars: dark fantasy oriental with metal and electronics
//   match_point_160.wav  160 BPM, 16 bars: the battle material, intensified
//
// It grows out of the web demo's music sequencer (v0.1-web-mvp:src/audio/audio.ts): the same
// taiko groove (strokes on the 1st, 5th, 11th and 13th sixteenths, the rim "ka"
// on the off sixteenths), the palm-muted distorted chug on D, plucked strings
// in the Japanese In scale and the low sawtooth drone, now composed into
// 16-bar loops with bass, electric piano, a lead motif and a mix.
//
// Each file is exactly `bars` long and loops seamlessly: every note that rings
// past the end is wrapped round to the start, and the reverb, echo, DC-blocking
// high-pass and compressor run over the loop twice so the start already
// carries the end's tail. The loop is also written into a 'smpl' chunk for
// Godot. Because of that wrapped tail every loop starts mid-signal: the player
// has to fade a track in and out (10-20 ms) or it clicks.
//
// usage: node scripts/audio/music.mjs [--only=<regex>]

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { SR, compress, highpassLoop, panGains, pingPong, reverb } from './lib/synthkit.mjs';
import {
  bass,
  epiano,
  gong,
  hat,
  ka,
  kick,
  koto,
  lead,
  pad,
  powerChord,
  riser,
  shaker,
  shamisen,
  snare,
  subBass,
  taiko,
  woodblock,
} from './lib/instruments.mjs';
import { buffer } from './lib/synthkit.mjs';
import { makeRandom, seedFrom } from './lib/rng.mjs';
import { writeWav } from './lib/wav.mjs';
import { writeSourcesMd } from './lib/sources.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(HERE, '..', '..', 'game', 'assets', 'audio', 'music');

/** The tracks, their tempo and length (also written to tracks.json). */
export const TRACKS = [
  {
    id: 'menu',
    file: 'menu_110.wav',
    bpm: 110,
    bars: 16,
    description: 'Menus and character select: slower, groovy electric and oriental funk (funk bass, electric-piano chords, muted koto-like plucks in D Hirajoshi, light taiko, rim, wood block and shaker)',
  },
  {
    id: 'battle',
    file: 'battle_140.wav',
    bpm: 140,
    bars: 16,
    description: 'Battle: dark fantasy oriental with metal and electronics (taiko and kick groove, double-tracked palm-muted distorted riff in drop D, shamisen-like plucks in the D In scale, a shakuhachi-like lead motif, sub bass and a low drone)',
  },
  {
    id: 'match_point',
    file: 'match_point_160.wav',
    bpm: 160,
    bars: 16,
    description: 'Match point (either fighter on two round wins): the battle theme intensified (double-time taiko, constant sixteenth-note gallop riff, double kick, the lead motif an octave up with a harmony a fourth below)',
  },
];

// ------------------------------------------------------------------ mixer

/** Corner of the master DC-blocking high-pass (Hz); the sub bass reaches down to A0 (27.5 Hz). */
export const MASTER_HIGHPASS_HZ = 20;

/**
 * The ensemble sway: the whole band runs a little ahead of and behind the grid
 * together, as players do, by up to SWAY_SECONDS over SWAY_CYCLES slow cycles
 * per loop (one every 6.4 beats in a 16-bar loop; never more than 0.8% off tempo, so
 * nobody hears it as rushing). Next to the per-note jitter it keeps
 * neighbouring beats closer in time than beats further apart, as in played
 * music: with machine-exact timing, a beat and the beat two later match as
 * well as neighbours do, and a kick-snare groove measures at half its tempo.
 * Whole cycles per loop keep the loop seamless.
 */
export const SWAY_SECONDS = 0.003;
export const SWAY_CYCLES = 10;

/**
 * A loop-length stereo mix with a reverb bus and an echo bus. Everything
 * added past the end wraps round to the start.
 */
class LoopMix {
  constructor(track, seed) {
    this.bpm = track.bpm;
    this.bars = track.bars;
    this.sixteenth = 60 / this.bpm / 4;
    this.seconds = this.bars * 16 * this.sixteenth;
    this.n = Math.round(this.seconds * SR);
    const pair = () => [new Float32Array(this.n), new Float32Array(this.n)];
    this.main = pair();
    this.rev = pair();
    this.dly = pair();
    this.energy = new Map();
    this.r = makeRandom(seed);
    this.swing = 0.5;
  }

  /** Seconds at bar b (0-based), sixteenth s, with swing on the off sixteenths. */
  at(b, s = 0) {
    const whole = Math.floor(s);
    const swingDelay = whole % 2 === 1 ? (this.swing - 0.5) * 2 * this.sixteenth : 0;
    return (b * 16 + s) * this.sixteenth + swingDelay;
  }

  /** The ensemble sway at time t (seconds): see SWAY_SECONDS. */
  sway(t) {
    return SWAY_SECONDS * Math.sin((2 * Math.PI * SWAY_CYCLES * t) / this.seconds);
  }

  /**
   * Mixes a mono buffer in at time t (seconds) with gain, pan and sends.
   * `humanize` is the per-note timing jitter; every note also follows the
   * ensemble sway.
   */
  add(buf, t, { gain = 1, pan = 0, rev = 0, dly = 0, stem = 'misc', humanize = 0.002 } = {}) {
    const jitter = humanize ? this.r.range(-humanize, humanize) : 0;
    let p = Math.round((t + jitter + this.sway(t)) * SR) % this.n;
    if (p < 0) p += this.n;
    const [gl, gr] = panGains(pan);
    const [ml, mr] = this.main;
    const [rl, rr] = this.rev;
    const [dl, dr] = this.dly;
    let e = 0;
    for (let i = 0; i < buf.length; i++) {
      const k = (p + i) % this.n;
      const v = buf[i] * gain;
      ml[k] += v * gl;
      mr[k] += v * gr;
      if (rev) {
        rl[k] += v * gl * rev;
        rr[k] += v * gr * rev;
      }
      if (dly) {
        dl[k] += v * gl * dly;
        dr[k] += v * gr * dly;
      }
      e += v * v;
    }
    this.energy.set(stem, (this.energy.get(stem) ?? 0) + e);
  }

  /**
   * Final mix: reverb and echo (both circular), a DC-blocking high-pass, glue
   * compression, a soft limiter.
   */
  master({ revGain = 1, dlyGain = 0.6, dlyTime, peakDb = -1 }) {
    const wetR = reverb(this.rev, { room: 0.82, damp: 0.35, loop: true });
    const wetD = pingPong(this.dly, { time: dlyTime ?? this.sixteenth * 3, feedback: 0.38, lowpass: 3500, loop: true });
    const L = new Float32Array(this.n);
    const R = new Float32Array(this.n);
    let dry = 0;
    let wetRev = 0;
    let wetDly = 0;
    for (let i = 0; i < this.n; i++) {
      L[i] = this.main[0][i] + wetR[0][i] * revGain + wetD[0][i] * dlyGain;
      R[i] = this.main[1][i] + wetR[1][i] * revGain + wetD[1][i] * dlyGain;
      dry += this.main[0][i] ** 2 + this.main[1][i] ** 2;
      wetRev += (wetR[0][i] * revGain) ** 2 + (wetR[1][i] * revGain) ** 2;
      wetDly += (wetD[0][i] * dlyGain) ** 2 + (wetD[1][i] * dlyGain) ** 2;
    }
    // Reverb and echo levels against the dry mix, for the log.
    this.wetReport = `reverb ${(10 * Math.log10(wetRev / dry)).toFixed(1)} dB, echo ${(10 * Math.log10(wetDly / dry)).toFixed(1)} dB`;
    // Block DC and sub-sonic drift (short notes that start on a sine phase
    // leave some) before it can take headroom or push the compressor about.
    // The filter wraps round the loop, so the seam stays seamless.
    highpassLoop([L, R], MASTER_HIGHPASS_HZ);
    // Level the mix before compressing so the settings mean the same for every track.
    let pk = 0;
    for (let i = 0; i < this.n; i++) pk = Math.max(pk, Math.abs(L[i]), Math.abs(R[i]));
    const pre = Math.pow(10, -3 / 20) / (pk || 1);
    for (let i = 0; i < this.n; i++) {
      L[i] *= pre;
      R[i] *= pre;
    }
    compress([L, R], { thresholdDb: -16, ratio: 3, attack: 0.008, release: 0.18, makeupDb: 5, loop: true });
    // soft limiter, then the final level
    for (let i = 0; i < this.n; i++) {
      L[i] = Math.tanh(L[i] * 1.1);
      R[i] = Math.tanh(R[i] * 1.1);
    }
    pk = 0;
    for (let i = 0; i < this.n; i++) pk = Math.max(pk, Math.abs(L[i]), Math.abs(R[i]));
    const g = Math.pow(10, peakDb / 20) / (pk || 1);
    let sq = 0;
    for (let i = 0; i < this.n; i++) {
      L[i] *= g;
      R[i] *= g;
      sq += L[i] * L[i] + R[i] * R[i];
    }
    this.rmsDb = 10 * Math.log10(sq / (2 * this.n));
    return [L, R];
  }

  stemReport() {
    const total = [...this.energy.values()].reduce((a, b) => a + b, 0);
    return [...this.energy.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([k, v]) => `${k} ${(10 * Math.log10(v / total)).toFixed(1)}`)
      .join(', ');
  }
}

// ------------------------------------------------------------------ music data

// The D In scale (D Eb G A Bb), as the demo's plucks used, by degree from D4.
const IN_SCALE = [0, 1, 5, 7, 8];
const inDegree = (deg, base = 62) => {
  const oct = Math.floor(deg / 5);
  const i = ((deg % 5) + 5) % 5;
  return base + oct * 12 + IN_SCALE[i];
};

const D1 = 26, A1 = 33, Bb1 = 34, C2 = 36, D2 = 38, Eb2 = 39, F2 = 41, G2 = 43, A2 = 45;

/** Two-bar riffs: [sixteenth, root, length in sixteenths, palm-muted]. */
const RIFF_A = [
  [
    [0, D2, 1, 1], [2, D2, 1, 1], [3, D2, 1, 1], [4, Eb2, 2, 0], [6, D2, 1, 1], [7, D2, 1, 1], [8, D2, 1, 1],
    [10, D2, 1, 1], [11, D2, 1, 1], [12, F2, 2, 0], [14, D2, 1, 1], [15, D2, 1, 1],
  ],
  [
    [0, D2, 1, 1], [2, D2, 1, 1], [3, D2, 1, 1], [4, C2, 2, 0], [6, D2, 1, 1], [7, D2, 1, 1], [8, Bb1, 4, 0],
    [12, A1, 2, 0], [14, Eb2, 2, 0],
  ],
];
const RIFF_B = [
  [
    [0, Bb1, 1, 1], [2, Bb1, 1, 1], [3, Bb1, 1, 1], [4, C2, 2, 0], [6, Bb1, 1, 1], [7, Bb1, 1, 1], [8, Bb1, 1, 1],
    [10, Bb1, 1, 1], [11, Bb1, 1, 1], [12, D2, 2, 0], [14, Bb1, 1, 1], [15, Bb1, 1, 1],
  ],
  [
    [0, C2, 1, 1], [2, C2, 1, 1], [3, C2, 1, 1], [4, D2, 2, 0], [6, C2, 1, 1], [7, C2, 1, 1], [8, Eb2, 4, 0],
    [12, D2, 2, 0], [14, A1, 2, 0],
  ],
];
/** The last bar: a chromatic climb back to D for the loop. */
const RIFF_FILL = [
  [0, D2, 1, 1], [1, D2, 1, 1], [2, D2, 1, 1], [3, D2, 1, 1], [4, D2, 1, 1], [5, D2, 1, 1], [6, D2, 1, 1], [7, D2, 1, 1],
  [8, Eb2, 1, 1], [9, Eb2, 1, 1], [10, Eb2, 1, 1], [11, Eb2, 1, 1], [12, F2, 1, 1], [13, F2, 1, 1], [14, G2, 1, 0], [15, A2, 1, 0],
];

/** The lead motif, four bars: [sixteenth, MIDI note, length in sixteenths]. */
const MOTIF = [
  [[0, 69, 6], [6, 70, 2], [8, 69, 4], [12, 67, 2], [14, 69, 2]],
  [[0, 74, 8], [8, 75, 4], [12, 74, 2], [14, 70, 2]],
  [[0, 69, 6], [6, 67, 2], [8, 63, 4], [12, 67, 2], [14, 69, 2]],
  [[0, 62, 10], [12, 69, 2], [14, 70, 2]],
];
/** Its answer, climbing to the high D. */
const MOTIF_ANSWER = [
  MOTIF[0],
  [[0, 79, 4], [4, 81, 4], [8, 82, 4], [12, 81, 4]],
  [[0, 74, 6], [6, 75, 2], [8, 74, 4], [12, 69, 4]],
  [[0, 74, 14]],
];

/** One bar of the shamisen ostinato, as In-scale degrees from D4. */
const OSTINATO = [[0, 5], [2, 3], [3, 4], [4, 3], [6, 2], [8, 5], [10, 6], [11, 5], [12, 3], [14, 2]];

function playRiffBar(mix, bar, notes, { accent = 1, gainScale = 1 } = {}) {
  const r = mix.r;
  for (const [s, root, len, muted] of notes) {
    const t = mix.at(bar, s);
    const length = len * mix.sixteenth * (muted ? 0.8 : 0.95);
    const acc = (s % 4 === 0 ? 1 : 0.85) * accent * (muted ? 1 : 1.1);
    // double-tracked: two separately rendered takes panned hard left and right
    for (const pan of [-0.85, 0.85]) {
      const g = powerChord(r, root, { length, accent: acc, mute: muted });
      mix.add(g, t + r.range(0, 0.006), { gain: 0.55 * gainScale, pan, rev: 0.04, stem: 'guitars' });
    }
    mix.add(subBass(r, root - 12, { length, accent: acc }), t, { gain: 0.4 * gainScale, stem: 'sub', humanize: 0 });
  }
}

function playMotif(mix, startBar, motif, { octave = 0, harmony = null, gain = 0.5 } = {}) {
  let prev = null;
  motif.forEach((bar, bi) => {
    for (const [s, note, len] of bar) {
      const t = mix.at(startBar + bi, s);
      const length = len * mix.sixteenth * 0.92;
      const m = note + octave;
      mix.add(lead(mix.r, m, { length, from: prev != null && Math.abs(prev - m) <= 5 ? prev : null }), t, {
        gain,
        pan: 0.1,
        rev: 0.35,
        dly: 0.22,
        stem: 'lead',
      });
      // a shamisen doubling the attack gives the line its bite
      mix.add(shamisen(mix.r, m, { seconds: Math.min(1.2, length + 0.4), accent: 0.8 }), t, { gain: 0.22, pan: -0.2, rev: 0.2, stem: 'lead' });
      if (harmony != null) {
        mix.add(lead(mix.r, m + harmony, { length, saw: 0.25, breath: 0.2 }), t, { gain: gain * 0.55, pan: -0.35, rev: 0.35, dly: 0.1, stem: 'lead' });
      }
      prev = m;
    }
  });
}

function playOstinato(mix, bar, { shift = 0, gain = 0.15, sixteenths = false } = {}) {
  const cell = sixteenths
    ? Array.from({ length: 16 }, (_, s) => [s, OSTINATO.find(([x]) => x === s)?.[1] ?? OSTINATO.filter(([x]) => x < s).pop()?.[1] ?? 5])
    : OSTINATO;
  for (const [s, deg] of cell) {
    const accent = s % 4 === 0 ? 1 : 0.75;
    mix.add(shamisen(mix.r, inDegree(deg + shift), { seconds: 0.9, accent, mute: sixteenths && s % 2 ? 0.4 : 0 }), mix.at(bar, s), {
      gain,
      pan: s % 2 ? 0.45 : 0.3,
      rev: 0.25,
      dly: 0.08,
      stem: 'shamisen',
    });
  }
}

// ------------------------------------------------------------------ tracks

function renderBattle(track, { intense = false } = {}) {
  const mix = new LoopMix(track, seedFrom(track.file));
  const r = mix.r;
  const T = (b, s) => mix.at(b, s);

  // A soft gong marks the top of the loop; risers lead into bar 9 and back to bar 1.
  mix.add(gong(buffer(4.6), r, { f0: 73.4, accent: 0.6 }), 0, { gain: 0.35, rev: 0.4, stem: 'fx', humanize: 0 });
  mix.add(riser(r, mix.sixteenth * 16), T(7, 0), { gain: 0.5, rev: 0.3, stem: 'fx', humanize: 0 });
  mix.add(riser(r, mix.sixteenth * 16), T(15, 0), { gain: 0.6, rev: 0.3, stem: 'fx', humanize: 0 });

  // Drone pads under each section.
  for (const [bar, notes] of [[0, [D2, A2, 50]], [4, [D2, A2, 50]], [8, [Bb1, F2, 46]], [10, [C2, G2, 48]], [12, [D2, A2, 50]]]) {
    const len = (bar === 8 || bar === 10 ? 2 : 4) * 16 * mix.sixteenth;
    mix.add(pad(r, notes, { length: len, cutoff: intense ? 900 : 650 }), T(bar, 0), { gain: 0.5, rev: 0.4, stem: 'pad', humanize: 0 });
  }

  for (let bar = 0; bar < 16; bar++) {
    const section = Math.floor(bar / 4); // 0 intro groove, 1 motif, 2 riff B, 3 answer + fill
    const last = bar === 15;

    // ---- taiko: the demo's groove, doubled in time at match point
    const big = intense ? [0, 4, 8, 12] : bar % 2 ? [0, 6, 10] : [0, 10];
    for (const s of big) mix.add(taiko(buffer(1.2), r, { weight: 1, accent: s === 0 ? 1 : 0.8 }), T(bar, s), { gain: 0.8, rev: 0.25, stem: 'taiko' });
    const light = intense ? [2, 6, 10, 14, 3, 7, 11, 15].filter((s) => s % 2 === 0 || bar % 2) : [4, 12];
    for (const s of light) mix.add(taiko(buffer(0.6), r, { weight: 0.1, accent: s % 4 === 0 ? 0.8 : 0.55 }), T(bar, s), { gain: 0.45, pan: 0.25, rev: 0.2, stem: 'taiko' });
    for (let s = 1; s < 16; s += 2) mix.add(ka(buffer(0.12), r, { accent: 0.4 }), T(bar, s), { gain: 1.1, pan: -0.3, stem: 'perc' });

    // ---- kit
    const kicks = intense
      ? section === 3 ? Array.from({ length: 16 }, (_, s) => s) : [0, 3, 4, 8, 10, 12, 14]
      : section >= 2 ? [0, 3, 6, 8, 10, 14] : [0, 3, 8, 10];
    for (const s of kicks) mix.add(kick(r, { accent: s % 4 === 0 ? 1 : 0.75 }), T(bar, s), { gain: 0.7, stem: 'kick' });
    for (const s of [4, 12]) mix.add(snare(r, { accent: 1 }), T(bar, s), { gain: 1.7, rev: 0.22, stem: 'snare' });
    if (last) for (const s of [13, 14, 15]) mix.add(snare(r, { accent: 0.6 + (s - 13) * 0.2 }), T(bar, s), { gain: 1.5, rev: 0.2, stem: 'snare' });
    const hats = intense || section >= 2 ? Array.from({ length: 16 }, (_, s) => s) : [0, 2, 4, 6, 8, 10, 12, 14];
    for (const s of hats) mix.add(hat(r, { accent: s % 2 ? 0.55 : 0.9, open: s === 0 && bar % 4 === 0 }), T(bar, s), { gain: 1.2, pan: 0.35, stem: 'hats' });

    // ---- riff
    let notes;
    if (last) notes = RIFF_FILL;
    else if (section === 2) notes = RIFF_B[bar % 2];
    else notes = RIFF_A[bar % 2];
    if (intense && !last) {
      // gallop every sixteenth between the accents
      const accents = new Map(notes.filter((n) => !n[3]).map((n) => [n[0], n]));
      const root = notes[0][1];
      const filled = [];
      for (let s = 0; s < 16; s++) {
        const a = accents.get(s);
        if (a) {
          filled.push(a);
          s += a[2] - 1;
        } else filled.push([s, root, 1, 1]);
      }
      notes = filled;
    }
    playRiffBar(mix, bar, notes, { accent: 1 });

    // ---- shamisen ostinato in the sections without the lead
    if (section === 0 || section === 2) playOstinato(mix, bar, { shift: section === 2 ? -1 : 0, sixteenths: intense });
  }

  // ---- the lead motif and its answer
  playMotif(mix, 4, MOTIF, { octave: intense ? 12 : 0, harmony: intense ? -5 : null, gain: 0.7 });
  playMotif(mix, 12, MOTIF_ANSWER, { octave: 0, harmony: intense ? -5 : null, gain: 0.7 });

  return mix;
}

function renderMenu(track) {
  const mix = new LoopMix(track, seedFrom(track.file));
  mix.swing = 0.56;
  const r = mix.r;
  const T = (b, s) => mix.at(b, s);

  // Chords (rootless electric-piano voicings) and bass roots, one per bar.
  const CHORDS = [
    { root: D2, voicing: [53, 57, 60, 64] }, // Dm9
    { root: Bb1, voicing: [57, 60, 62, 65] }, // Bbmaj9
    { root: 31, voicing: [53, 57, 58, 62] }, // Gm9
    { root: A1, voicing: [55, 57, 62, 64], turn: [55, 58, 61, 64] }, // A7sus4, then A7(b9)
  ];
  // Muted koto-like plucks in D Hirajoshi (D E F A Bb), a two-bar motif.
  const KOTO = [
    [[0, 69], [2, 74], [3, 76], [4, 77], [6, 76], [8, 74], [10, 69], [11, 70], [12, 69], [14, 65]],
    [[0, 64], [2, 65], [4, 69], [6, 74], [7, 76], [8, 77], [10, 81], [12, 81], [13, 77], [14, 76]],
  ];

  // The demo's low drone, now following the chords.
  for (let bar = 0; bar < 16; bar += 4) {
    mix.add(pad(r, [D2 + 12, A2 + 12], { length: 16 * 4 * mix.sixteenth, cutoff: 500 }), T(bar, 0), { gain: 0.35, rev: 0.5, stem: 'pad', humanize: 0 });
  }

  for (let bar = 0; bar < 16; bar++) {
    const section = Math.floor(bar / 4); // 0 intro, 1 full, 2 breakdown, 3 full + fill
    const chord = CHORDS[bar % 4];
    const nextRoot = CHORDS[(bar + 1) % 4].root;

    // ---- electric piano comping (funk stabs on and off the beat)
    const stabs = section === 2 ? [[0, 6], [10, 4]] : bar % 2 ? [[0, 2], [3, 3], [7, 2], [10, 2], [14, 2]] : [[0, 3], [6, 2], [10, 3], [13, 2]];
    for (const [s, len] of stabs) {
      const voicing = chord.turn && s >= 8 ? chord.turn : chord.voicing;
      const acc = s % 4 === 0 ? 0.9 : 0.7;
      voicing.forEach((m, i) => {
        mix.add(epiano(r, m, { length: len * mix.sixteenth * 0.9, accent: acc }), T(bar, s) + i * 0.004, {
          gain: 0.32,
          pan: bar % 2 ? 0.25 : -0.25,
          rev: 0.3,
          dly: 0.12,
          stem: 'epiano',
        });
      });
    }

    // ---- funk bass
    const R = chord.root;
    const groove =
      section === 2
        ? [[0, R, 6, 1, 0], [8, R + 7, 4, 0.8, 0], [12, R + 12, 2, 0.8, 1], [14, R + 10, 2, 0.7, 0]]
        : [
            [0, R, 3, 1, 0], [3, R + 12, 1, 0.65, 1], [4, R, 1, 0.45, 0], [6, R + 7, 2, 0.8, 0], [8, R, 2, 0.9, 0],
            [10, R + 10, 1, 0.7, 0], [11, R + 12, 2, 0.8, 1], [14, R + 7, 1, 0.7, 0], [15, nextRoot - 1, 1, 0.6, 0],
          ];
    for (const [s, m, len, acc, pop] of groove) {
      mix.add(bass(r, m, { length: len * mix.sixteenth * 0.9, accent: acc, pop }), T(bar, s), { gain: 0.6, stem: 'bass' });
    }

    // ---- koto plucks in the full sections
    if (section === 1 || section === 3 || (section === 2 && bar % 2 === 1)) {
      const phrase = KOTO[bar % 2];
      const down = section === 2 ? -12 : 0;
      for (const [s, m] of phrase) {
        mix.add(koto(r, m + down, { accent: s % 4 === 0 ? 1 : 0.75, mute: 0.55 }), T(bar, s), { gain: 0.85, pan: 0.4, rev: 0.25, dly: 0.15, stem: 'koto' });
      }
    }

    // ---- light percussion: taiko, rim, wood block, shaker
    mix.add(taiko(buffer(0.7), r, { weight: 0.3, accent: 0.8 }), T(bar, 0), { gain: 0.6, rev: 0.25, stem: 'taiko' });
    if (section !== 2) mix.add(taiko(buffer(0.6), r, { weight: 0.15, accent: 0.55 }), T(bar, 11), { gain: 0.5, rev: 0.2, stem: 'taiko' });
    for (const s of [4, 12]) mix.add(ka(buffer(0.12), r, { accent: 0.9 }), T(bar, s), { gain: 0.8, pan: -0.15, rev: 0.15, stem: 'perc' });
    if (section >= 1) {
      for (const s of [2, 6, 10, 14]) mix.add(woodblock(r, { accent: 0.8, pitch: s % 8 === 2 ? 1 : 1.19 }), T(bar, s), { gain: 0.55, pan: -0.45, rev: 0.15, stem: 'perc' });
      if (section !== 2) for (let s = 0; s < 16; s++) mix.add(shaker(r, { accent: s % 2 ? 0.6 : 1 }), T(bar, s), { gain: 0.6, pan: 0.5, stem: 'perc' });
    }
    if (bar % 4 === 3) {
      // a small taiko fill into the next phrase (the last bar leads back to the top)
      const fill = bar === 15 ? [12, 13, 14, 15] : [14, 15];
      for (const s of fill) mix.add(taiko(buffer(0.6), r, { weight: 0.2, accent: 0.5 + (s - 12) * 0.1 }), T(bar, s), { gain: 0.5, rev: 0.2, stem: 'taiko' });
    }
  }
  return mix;
}

// ------------------------------------------------------------------ main

const RENDER = {
  menu: (t) => renderMenu(t),
  battle: (t) => renderBattle(t),
  match_point: (t) => renderBattle(t, { intense: true }),
};

/** Renders and masters one track: {mix, channels: [L, R]}. */
export function renderTrack(track) {
  const mix = RENDER[track.id](track);
  return { mix, channels: mix.master({ revGain: 1.1, dlyGain: 1.0 }) };
}

function main() {
  const onlyArg = process.argv.find((a) => a.startsWith('--only='));
  const only = onlyArg ? new RegExp(onlyArg.slice(7), 'i') : null;
  mkdirSync(OUT_DIR, { recursive: true });
  for (const track of TRACKS) {
    if (only && !only.test(track.file)) continue;
    const { mix, channels: [L, R] } = renderTrack(track);
    writeFileSync(join(OUT_DIR, track.file), writeWav({ sampleRate: SR, channels: [L, R] }, { loop: { start: 0, end: mix.n }, seed: seedFrom(track.file) }));
    console.log(`  music/${track.file.padEnd(22)} ${track.bpm} BPM, ${track.bars} bars, ${(mix.n / SR).toFixed(3)} s, RMS ${mix.rmsDb.toFixed(1)} dBFS`);
    console.log(`    stems (dB of total): ${mix.stemReport()}; ${mix.wetReport} against the dry mix`);
  }
  const index = {
    $comment: 'Placeholder music written by scripts/audio/music.mjs. Every track is a seamless loop of exactly `bars` bars of 4/4 at `bpm`.',
    tracks: Object.fromEntries(
      TRACKS.map((t) => [
        t.id,
        { file: t.file, bpm: t.bpm, bars: t.bars, beats_per_bar: 4, seconds: +((t.bars * 4 * 60) / t.bpm).toFixed(6), loop: true },
      ]),
    ),
  };
  writeFileSync(join(OUT_DIR, 'tracks.json'), JSON.stringify(index, null, 2) + '\n');
}

// Not awaited at the top level: writeSourcesMd imports this module for TRACKS.
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
  writeSourcesMd()
    .then(() => console.log('music: done.'))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
