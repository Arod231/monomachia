#!/usr/bin/env node
// Generates the sound effects the Sonniss bundle has no recordings for: taiko,
// gong, the parry ring, footsteps on stone, falls and landings, cloth swishes,
// metal pings and the round-call drums. They are written to
// game/assets/audio/sfx/gen_*.wav (mono, 16-bit, 44.1 kHz).
//
// The recipes are ports of the web demo's Web Audio sounds (v0.1-web-mvp:src/audio/audio.ts),
// kept in character and given more body: modal resonances, beating partials,
// several seeded variations. Every sound has its own seed, so the output is the
// same on every run. Each is high-passed at 25 Hz to remove DC, normalized,
// matched in loudness to the other variations of its pool (lib/pools.mjs) and
// trimmed where its tail falls under -60 dBFS.
//
// usage: node scripts/audio/synth.mjs [--only=<regex>]

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  SR,
  addInto,
  buffer,
  drive,
  filter,
  metal,
  modes,
  noiseBurst,
  normalizeBuf,
  tidy,
  tone,
  whiteNoise,
  expEnv,
} from './lib/synthkit.mjs';
import { makeRandom, seedFrom } from './lib/rng.mjs';
import { writeWav } from './lib/wav.mjs';
import { writeSourcesMd } from './lib/sources.mjs';
import { gong, ka, taiko } from './lib/instruments.mjs';
import { matchLoudness, removeDc, settleLoudness } from './lib/dsp.mjs';
import { poolFor } from './lib/pools.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(HERE, '..', '..', 'game', 'assets', 'audio', 'sfx');

// ------------------------------------------------------------------ parry ring

/**
 * The parry ring: the demo's 1.18 kHz bell partials, now with beating pairs
 * and a long, pure tail so it reads as a reward, clearly apart from a block's
 * short clang. `f0` and `partials` vary it.
 */
function parryRing(dst, r, { f0 = 1180, partials = [1, 2.32, 3.87, 5.71, 7.2], len = 1.35, t0 = 0, sparkle = 1 } = {}) {
  modes(
    dst,
    partials.map((p, i) => ({
      f: f0 * p * (1 + r.range(-0.003, 0.003)),
      amp: 0.32 / (1 + i * 0.75),
      decay: len * (1 - i * 0.13),
      beat: 2.5 + i * 1.7 + r.range(-0.5, 0.5),
    })),
    { t0, attack: 0.0015, rand: r.next },
  );
  // the demo's sweeping hiss of the blades parting, and its low thump
  noiseBurst(dst, { peak: 0.3 * sparkle, attack: 0.004, decay: 0.32, type: 'bandpass', f0: 3200, f1: 9000, q: 4, t0, rand: r.next });
  tone(dst, { freq: 95, freqEnd: 55, peak: 0.45, attack: 0.002, decay: 0.16, t0 });
  return dst;
}

// ------------------------------------------------------------------ sound list

/**
 * Every generated sound: its file, what it is for, how it is made (for
 * SOURCES.md) and its recipe. `peakDb` sets the level it is normalized to.
 */
export const SOUNDS = [];

function sound(file, use, how, seconds, render, { peakDb = -1 } = {}) {
  SOUNDS.push({ file, use, how, seconds, render, peakDb });
}

// Taiko, two weights with two strokes each.
for (const [weight, name, use] of [
  [0.1, 'light', 'Taiko hit, light (counters, round-call accents, music)'],
  [0.95, 'heavy', 'Taiko hit, heavy (KO, the ultimate, the round call)'],
]) {
  for (let v = 1; v <= 2; v++) {
    sound(
      `gen_taiko_${name}_0${v}.wav`,
      use,
      'Pitch-dropping sine fundamental with membrane modes (1.59, 2.14, 2.65, 3.16), bachi slap noise and a low shell bloom (the demo\'s taiko, extended)',
      0.4 + weight * 1.1,
      (r) => taiko(buffer(0.4 + weight * 1.1), r, { weight: weight + (v - 1) * 0.05, accent: 1 }),
    );
  }
}

sound('gen_gong.wav', 'Gong for the round start and the KO', 'Eight inharmonic partials on 98 Hz with slow beating, a delayed swell of the upper partials, mallet thump and a shimmer wash', 4.6, (r) => gong(buffer(4.6), r));

for (const [v, f0, partials] of [
  [1, 1180, [1, 2.32, 3.87, 5.71, 7.2]],
  [2, 1245, [1, 2.41, 3.95, 5.62, 7.44]],
  [3, 1120, [1, 2.28, 3.79, 5.88, 7.05]],
]) {
  sound(
    `gen_parry_ring_0${v}.wav`,
    'Parry: the bright, ringing layer that marks a parry (distinct from a block clang)',
    `Bell-like modes on ${f0} Hz (ratios ${partials.join(', ')}) with beating pairs and a 1.3 s tail, a rising band-passed hiss and a low thump (the demo's parry clang, extended)`,
    1.5,
    (r) => parryRing(buffer(1.5), r, { f0, partials }),
  );
}

sound(
  'gen_parry_flash.wav',
  'Flash (the Katana\'s parry stance): a higher, airier ring with a second chime',
  'Parry ring on 1.45 kHz plus an overtone chime a fifth up 50 ms later and a glassy high shimmer (the demo\'s flash clang, extended)',
  1.6,
  (r) => {
    const b = buffer(1.6);
    parryRing(b, r, { f0: 1450, partials: [1, 2.32, 3.87, 5.71], len: 1.3 });
    metal(b, { f0: 1450 * 1.5, partials: [1, 2.1], peak: 0.14, decay: 0.9, t0: 0.05, rand: r.next });
    modes(b, [{ f: 5200, amp: 0.04, decay: 0.7, beat: 7, swell: 0.05 }], { t0: 0.02, rand: r.next });
    return b;
  },
);

sound(
  'gen_parry_redirect.wav',
  'Redirect (a disarmed fighter\'s hand counter): a body thud with a lower ring',
  'Sine thud 160 to 70 Hz, band-passed noise sweeping down from 1.8 kHz and a short 900 Hz metallic ring (the demo\'s redirect)',
  0.9,
  (r) => {
    const b = buffer(0.9);
    tone(b, { freq: 160, freqEnd: 70, peak: 0.6, attack: 0.002, decay: 0.18 });
    noiseBurst(b, { peak: 0.4, attack: 0.002, decay: 0.12, type: 'bandpass', f0: 1800, f1: 600, q: 2, rand: r.next });
    metal(b, { f0: 900, partials: [1, 2.4, 4.1], peak: 0.15, decay: 0.5, rand: r.next });
    noiseBurst(b, { peak: 0.2, attack: 0.001, decay: 0.06, type: 'lowpass', f0: 1200, rand: r.next }); // palm slap
    return b;
  },
);

sound(
  'gen_telegraph.wav',
  'Unblockable warning: a taiko stroke under a sharp, high temple-bell ping',
  'Light taiko plus a 2.4 kHz ping (ratios 1, 2.7, 4.2) with beating, 10 ms after the drum (the demo\'s telegraph)',
  1.0,
  (r) => {
    const b = buffer(1.0);
    taiko(b, r, { weight: 0.35, accent: 0.9 });
    modes(
      b,
      [
        { f: 2400, amp: 0.2, decay: 0.55, beat: 5 },
        { f: 2400 * 2.7, amp: 0.08, decay: 0.3, beat: 9 },
        { f: 2400 * 4.2, amp: 0.03, decay: 0.18 },
      ],
      { t0: 0.01, rand: r.next },
    );
    return b;
  },
);

// Footsteps on stone: soft leather boots with cloth trousers. Heel, then the
// ball of the foot rolling down, a little grit, and the cloth moving.
for (let v = 1; v <= 6; v++) {
  sound(
    `gen_footstep_stone_0${v}.wav`,
    'Footstep on stone (soft cloth-and-leather boots), for the walk and run cycles',
    'Heel thump (sine 70-110 Hz) and band-passed leather tap, a softer ball-of-foot tap 35-60 ms later, faint high grit and a cloth brush; each variant seeded differently',
    0.3,
    (r) => {
      const b = buffer(0.3);
      const heel = r.range(0.8, 1);
      tone(b, { freq: r.range(95, 120), freqEnd: r.range(60, 75), peak: 0.45 * heel, attack: 0.002, decay: r.range(0.035, 0.05) });
      noiseBurst(b, { peak: 0.5 * heel, attack: 0.001, decay: r.range(0.018, 0.03), type: 'bandpass', f0: r.range(900, 1500), q: r.range(0.8, 1.3), rand: r.next });
      noiseBurst(b, { peak: 0.2 * heel, attack: 0.001, decay: 0.012, type: 'bandpass', f0: r.range(2400, 3400), q: 1.5, rand: r.next });
      const toe = r.range(0.035, 0.06);
      noiseBurst(b, { peak: r.range(0.18, 0.3), attack: 0.002, decay: r.range(0.02, 0.035), type: 'bandpass', f0: r.range(1300, 2000), q: 1, t0: toe, rand: r.next });
      tone(b, { freq: r.range(130, 160), freqEnd: 80, peak: 0.12, attack: 0.002, decay: 0.03, t0: toe });
      noiseBurst(b, { peak: r.range(0.04, 0.07), attack: 0.004, decay: r.range(0.04, 0.07), type: 'highpass', f0: 4500, t0: 0.004, rand: r.next }); // grit
      noiseBurst(b, { peak: r.range(0.05, 0.09), attack: 0.02, decay: 0.08, type: 'bandpass', f0: r.range(700, 1100), q: 0.6, t0: 0.01, rand: r.next }); // cloth
      return b;
    },
    { peakDb: -3 },
  );
}

for (let v = 1; v <= 2; v++) {
  sound(
    `gen_step_scuff_0${v}.wav`,
    'Quick step (the tap step) and jump push-off: a boot scuffing on stone',
    'A dragged band of high-passed noise with a gritty tremble, a small heel tap and a cloth swish',
    0.3,
    (r) => {
      const b = buffer(0.3);
      const scuff = whiteNoise(0.18, r.next);
      filter(scuff, 'bandpass', r.range(2200, 3000), { f1: r.range(1200, 1600), q: 0.7 });
      const gritRate = r.range(90, 140);
      const gritPhase = r.range(0, Math.PI * 2);
      for (let i = 0; i < scuff.length; i++) {
        const t = i / SR;
        const grit = 0.6 + 0.4 * Math.abs(Math.sin(t * gritRate * Math.PI * 2 + gritPhase));
        scuff[i] *= expEnv(t, 0.5, 0.012, 0.16) * grit;
      }
      addInto(b, scuff, 0.004);
      noiseBurst(b, { peak: 0.3, attack: 0.001, decay: 0.02, type: 'bandpass', f0: 1200, q: 1, rand: r.next });
      tone(b, { freq: 110, freqEnd: 70, peak: 0.25, attack: 0.002, decay: 0.04 });
      noiseBurst(b, { peak: 0.1, attack: 0.03, decay: 0.1, type: 'bandpass', f0: 900, q: 0.6, t0: 0.02, rand: r.next });
      return b;
    },
    { peakDb: -3 },
  );
}

for (let v = 1; v <= 2; v++) {
  sound(
    `gen_land_0${v}.wav`,
    'Landing from a jump: both boots and the body\'s weight on stone',
    'Sine thump 90 to 45 Hz and low-passed noise (the demo\'s land), plus two boot taps a few milliseconds apart and a cloth settle',
    0.45,
    (r) => {
      const b = buffer(0.45);
      tone(b, { freq: r.range(85, 95), freqEnd: 45, peak: 0.55, attack: 0.002, decay: 0.12 });
      noiseBurst(b, { peak: 0.35, attack: 0.002, decay: 0.08, type: 'lowpass', f0: 700, rand: r.next });
      const gap = r.range(0.008, 0.02);
      for (const t0 of [0, gap]) noiseBurst(b, { peak: 0.3, attack: 0.001, decay: 0.03, type: 'bandpass', f0: r.range(900, 1400), q: 1, t0, rand: r.next });
      noiseBurst(b, { peak: 0.08, attack: 0.03, decay: 0.2, type: 'bandpass', f0: 800, q: 0.6, t0: 0.02, rand: r.next });
      return b;
    },
  );
}

sound(
  'gen_body_fall.wav',
  'A fighter\'s body falling to the stone floor (KO, knockdowns)',
  'Low sine thud 70 to 38 Hz with low-passed body noise, a second smaller impact as the limbs land, gear rattle and a cloth rustle',
  1.0,
  (r) => {
    const b = buffer(1.0);
    tone(b, { freq: 70, freqEnd: 38, peak: 0.8, attack: 0.003, decay: 0.3 });
    noiseBurst(b, { peak: 0.55, attack: 0.003, decay: 0.2, type: 'lowpass', f0: 600, f1: 250, rand: r.next });
    noiseBurst(b, { peak: 0.25, attack: 0.001, decay: 0.04, type: 'bandpass', f0: 1100, q: 0.8, rand: r.next });
    const t2 = r.range(0.11, 0.15);
    tone(b, { freq: 95, freqEnd: 50, peak: 0.35, attack: 0.003, decay: 0.15, t0: t2 });
    noiseBurst(b, { peak: 0.3, attack: 0.002, decay: 0.1, type: 'lowpass', f0: 900, t0: t2, rand: r.next });
    for (let i = 0; i < 4; i++) {
      noiseBurst(b, { peak: r.range(0.04, 0.09), attack: 0.001, decay: 0.02, type: 'bandpass', f0: r.range(2500, 4500), q: 3, t0: r.range(0.02, 0.3), rand: r.next });
    }
    noiseBurst(b, { peak: 0.1, attack: 0.05, decay: 0.35, type: 'bandpass', f0: 1000, q: 0.5, t0: 0.03, rand: r.next });
    return b;
  },
);

for (let v = 1; v <= 3; v++) {
  sound(
    `gen_dodge_0${v}.wav`,
    'Dodge and backstep: a cloth swish',
    'Band-passed noise sweeping up from 700 Hz to 1.6 kHz with a fluttering tremble and a low air push (the demo\'s dodge, extended)',
    0.35,
    (r) => {
      const b = buffer(0.35);
      const lo = r.range(600, 800);
      const swish = whiteNoise(0.3, r.next);
      filter(swish, 'bandpass', lo, { f1: lo * r.range(2.1, 2.6), q: 0.8, sweep: 0.2 });
      const rate = r.range(28, 42);
      const attack = r.range(0.025, 0.04);
      const decay = r.range(0.13, 0.17);
      for (let i = 0; i < swish.length; i++) {
        const t = i / SR;
        const flutter = 0.75 + 0.25 * Math.sin(2 * Math.PI * rate * t);
        swish[i] *= expEnv(t, 0.6, attack, decay) * flutter;
      }
      addInto(b, swish);
      noiseBurst(b, { peak: 0.2, attack: 0.01, decay: 0.08, type: 'lowpass', f0: 600, t0: 0.02, rand: r.next });
      return b;
    },
    { peakDb: -3 },
  );
}

sound(
  'gen_pickup.wav',
  'Picking a dropped weapon back up: a metal ping and the grip settling in the hand',
  'The demo\'s 1.6 kHz metal ping (partials 1, 2.4) with beating, plus a leather-grip slap',
  0.7,
  (r) => {
    const b = buffer(0.7);
    modes(b, [{ f: 1600, amp: 0.3, decay: 0.45, beat: 4 }, { f: 1600 * 2.4, amp: 0.15, decay: 0.3, beat: 6 }], { rand: r.next });
    noiseBurst(b, { peak: 0.25, attack: 0.001, decay: 0.03, type: 'bandpass', f0: 900, q: 1, rand: r.next });
    return b;
  },
);

sound(
  'gen_recall.wav',
  'Recall (the ultimate\'s weapon recall): the metal ping with a rising shimmer',
  'The demo\'s 1.6 kHz ping, preceded by a quick rising chime (In-scale notes) and an air swell',
  1.0,
  (r) => {
    const b = buffer(1.0);
    const notes = [587.3, 622.3, 784, 830.6, 1174.7];
    notes.forEach((f, i) => modes(b, [{ f, amp: 0.1, decay: 0.35, beat: 3 }, { f: f * 2.4, amp: 0.03, decay: 0.2 }], { t0: i * 0.035, rand: r.next }));
    noiseBurst(b, { peak: 0.12, attack: 0.15, decay: 0.1, type: 'bandpass', f0: 1500, f1: 6000, q: 1.5, rand: r.next });
    modes(b, [{ f: 1600, amp: 0.3, decay: 0.5, beat: 4 }, { f: 1600 * 2.4, amp: 0.15, decay: 0.32, beat: 6 }], { t0: 0.2, rand: r.next });
    return b;
  },
);

sound(
  'gen_stagger.wav',
  'Stagger (posture broken, dazed): a dull, wobbling metallic tone',
  'The demo\'s 700 Hz metal tone (partials 1, 1.5) with a slow detuned wobble, sagging in pitch, over a soft thump',
  1.0,
  (r) => {
    const b = buffer(1.0);
    modes(b, [
      { f: 700, amp: 0.25, decay: 0.8, beat: 6.5, glide: -0.06 },
      { f: 1050, amp: 0.14, decay: 0.6, beat: 4.2, glide: -0.06 },
      { f: 1640, amp: 0.05, decay: 0.35, beat: 9, glide: -0.05 },
    ], { rand: r.next });
    tone(b, { freq: 120, freqEnd: 60, peak: 0.3, attack: 0.003, decay: 0.12 });
    return b;
  },
);

sound(
  'gen_disarm_sting.wav',
  'Disarm: the weapon torn from the hand (played with a parry contact)',
  'The parry ring, a 640 Hz metallic ring (partials 1, 2.9, 5.1) 50 ms later, a falling 55 to 30 Hz thump and a descending shing as the weapon flies (the demo\'s disarm)',
  1.6,
  (r) => {
    const b = buffer(1.6);
    parryRing(b, r, { f0: 1180, len: 1.2, sparkle: 0.8 });
    metal(b, { f0: 640, partials: [1, 2.9, 5.1], peak: 0.25, decay: 0.8, t0: 0.05, rand: r.next });
    tone(b, { freq: 55, freqEnd: 30, peak: 0.7, attack: 0.003, decay: 0.5 });
    noiseBurst(b, { peak: 0.18, attack: 0.02, decay: 0.45, type: 'bandpass', f0: 7000, f1: 1500, q: 3, t0: 0.08, rand: r.next });
    return b;
  },
);

sound(
  'gen_ult_start.wav',
  'Ultimate start: a rising rush over a dark chord and a taiko stroke',
  'Band-passed noise rising 300 Hz to 4 kHz, a detuned sawtooth D-A-D chord swelling through a low-pass, a heavy taiko at the start and a light one at the top of the rise (the demo\'s ultStart, extended)',
  1.6,
  (r) => {
    const b = buffer(1.6);
    noiseBurst(b, { peak: 0.35, attack: 0.75, decay: 0.35, type: 'bandpass', f0: 300, f1: 4000, q: 1.5, rand: r.next });
    const chord = buffer(1.5);
    for (const f of [73.4, 146.8, 220, 293.7]) {
      for (const d of [-0.004, 0.004]) tone(chord, { freq: f * (1 + d), type: 'sawtooth', peak: 0.05, attack: 0.5, decay: 0.8 });
    }
    filter(chord, 'lowpass', 300, { f1: 3000, q: 1.2, sweep: 0.8 });
    addInto(b, chord);
    taiko(b, r, { weight: 0.9, accent: 1.1 });
    taiko(b, r, { weight: 0.2, accent: 0.7, t0: 0.78 });
    return b;
  },
);

sound(
  'gen_ult_ready.wav',
  'Ultimate ready: a rising shimmer in the In scale',
  'Five bell tones (D, E-flat, G, A, D in the In scale) rising 60 ms apart, with beating partials and a soft high air swell',
  1.6,
  (r) => {
    const b = buffer(1.6);
    const notes = [587.3, 622.3, 784, 880, 1174.7];
    notes.forEach((f, i) =>
      modes(b, [{ f, amp: 0.16, decay: 1.0, beat: 3.5 }, { f: f * 2.76, amp: 0.04, decay: 0.5, beat: 6 }, { f: f * 5.4, amp: 0.015, decay: 0.25 }], { t0: i * 0.06, rand: r.next }),
    );
    noiseBurst(b, { peak: 0.06, attack: 0.3, decay: 0.8, type: 'bandpass', f0: 5000, q: 2, rand: r.next });
    return b;
  },
);

sound(
  'gen_round_roll.wav',
  'Round call: a taiko roll that speeds up and swells into a heavy stroke',
  'Alternating light taiko strokes accelerating from 7 to 18 per second over 1.3 s, crescendo, ending on a heavy stroke with a rim "ka"',
  2.4,
  (r) => {
    const b = buffer(2.4);
    let t = 0;
    const dur = 1.3;
    let k = 0;
    while (t < dur) {
      const x = t / dur;
      taiko(b, r, { weight: k % 2 ? 0.15 : 0.25, accent: 0.25 + 0.55 * x * x, t0: t });
      t += 1 / (7 + 11 * x);
      k++;
    }
    taiko(b, r, { weight: 1, accent: 1.2, t0: dur + 0.04 });
    ka(b, r, { accent: 0.8, t0: dur + 0.04 });
    return b;
  },
);

sound(
  'gen_fight.wav',
  '"Fight" call: the demo\'s taiko double hit',
  'A heavy taiko stroke and a second one 180 ms later (the demo\'s fight call), each with a rim "ka"',
  1.8,
  (r) => {
    const b = buffer(1.8);
    taiko(b, r, { weight: 0.8, accent: 1.2 });
    ka(b, r, { accent: 0.6 });
    taiko(b, r, { weight: 0.95, accent: 1.0, t0: 0.18 });
    ka(b, r, { accent: 0.5, t0: 0.18 });
    return b;
  },
);

for (let v = 1; v <= 2; v++) {
  sound(
    `gen_bone_crunch_0${v}.wav`,
    'Bone-and-rock crunch layer for colossal hits and the stomp counter',
    'The demo\'s crush: a 75 to 32 Hz sine drop and low-passed noise, with a burst of short resonant cracks',
    0.6,
    (r) => {
      const b = buffer(0.6);
      tone(b, { freq: 75, freqEnd: 32, peak: 0.8, attack: 0.003, decay: 0.35 });
      noiseBurst(b, { peak: 0.6, attack: 0.003, decay: 0.28, type: 'lowpass', f0: 1100, f1: 200, rand: r.next });
      for (let i = 0; i < 9; i++) {
        noiseBurst(b, { peak: r.range(0.2, 0.4), attack: 0.0008, decay: r.range(0.008, 0.02), type: 'bandpass', f0: r.range(1500, 3800), q: r.range(2, 5), t0: r.range(0.0, 0.18), rand: r.next });
      }
      drive(b, 1.6);
      return b;
    },
  );
}

sound(
  'gen_lightning_zap.wav',
  'Lightning Tempest: an electric crackle layered over the recorded thunder',
  'The demo\'s lightning: eight high-passed noise cracks 25 ms apart and a square-wave zap falling from 1.8 kHz to 300 Hz',
  0.5,
  (r) => {
    const b = buffer(0.5);
    for (let i = 0; i < 8; i++) noiseBurst(b, { peak: 0.35, attack: 0.001, decay: 0.03, type: 'highpass', f0: 3000, t0: i * 0.025 + r.range(0, 0.006), rand: r.next });
    tone(b, { freq: 1800, freqEnd: 300, type: 'square', peak: 0.08, attack: 0.001, decay: 0.2 });
    return b;
  },
);

// ------------------------------------------------------------------ the Hunter's gear

// The Hunter's own gear (milestone-1 task 36): the bundle has cloth but no
// leather or sword fittings, so these are made here and played with its cloth
// recordings (hunter_cloth_*): the brass fittings of the scabbard and belt
// ticking, the lacquered scabbard knocking at the hip, and the leather
// harness creaking.

/** One brass fitting ticking: a few high inharmonic modes, very short. */
function fittingTick(dst, r, { t0 = 0, peak = 0.3 } = {}) {
  const f0 = r.range(2600, 3600);
  modes(
    dst,
    [
      { f: f0, amp: peak, decay: r.range(0.035, 0.06) },
      { f: f0 * r.range(2.3, 2.6), amp: peak * 0.5, decay: r.range(0.02, 0.035) },
      { f: f0 * r.range(3.9, 4.4), amp: peak * 0.25, decay: 0.015 },
    ],
    { t0, rand: r.next },
  );
  noiseBurst(dst, { peak: peak * 0.4, attack: 0.0005, decay: 0.006, type: 'highpass', f0: 5000, t0, rand: r.next });
}

/** The lacquered wooden scabbard knocking against the hip: a hollow box. */
function scabbardKnock(dst, r, { t0 = 0, peak = 0.5 } = {}) {
  const f0 = r.range(520, 700);
  modes(
    dst,
    [
      { f: f0, amp: peak, decay: r.range(0.05, 0.08) },
      { f: f0 * r.range(1.55, 1.7), amp: peak * 0.55, decay: 0.05 },
      { f: f0 * r.range(2.6, 2.9), amp: peak * 0.3, decay: 0.03 },
    ],
    { t0, rand: r.next },
  );
  noiseBurst(dst, { peak: peak * 0.6, attack: 0.0008, decay: 0.012, type: 'bandpass', f0: r.range(1400, 2000), q: 1.2, t0, rand: r.next });
}

/**
 * Leather straining: a creak is the leather sticking and slipping, a train of
 * small clicks whose rate wanders, rung through the strap's body.
 */
function leatherCreak(dst, r, { t0 = 0, seconds = 0.2, peak = 0.35 } = {}) {
  const creak = buffer(seconds + 0.02);
  let t = 0;
  const rate0 = r.range(35, 55);
  const rate1 = rate0 * r.range(0.6, 1.5);
  while (t < seconds) {
    const u = t / seconds;
    const rate = rate0 + (rate1 - rate0) * u;
    const env = Math.sin(Math.PI * u) ** 0.7;
    noiseBurst(creak, { peak: peak * env * r.range(0.6, 1), attack: 0.0004, decay: r.range(0.003, 0.006), type: 'bandpass', f0: r.range(900, 1600), q: 3, t0: t, rand: r.next });
    t += (1 / rate) * r.range(0.8, 1.2);
  }
  filter(creak, 'bandpass', r.range(1000, 1400), { q: 0.8 });
  addInto(dst, creak, t0);
}

for (let v = 1; v <= 4; v++) {
  sound(
    `gen_hunter_gear_tick_0${v}.wav`,
    'The Hunter\'s gear under a footfall: a brass fitting or two ticking against the scabbard (milestone-1 task 36)',
    'One or two short brass ticks (inharmonic modes from 2.6-3.6 kHz, a high click) a few milliseconds apart, and a faint scabbard knock',
    0.15,
    (r) => {
      const b = buffer(0.15);
      fittingTick(b, r, { peak: 0.35 });
      if (v % 2 === 0) fittingTick(b, r, { t0: r.range(0.012, 0.03), peak: 0.18 });
      scabbardKnock(b, r, { t0: r.range(0.003, 0.01), peak: 0.12 });
      return b;
    },
    { peakDb: -6 },
  );
}

for (let v = 1; v <= 3; v++) {
  sound(
    `gen_hunter_gear_rattle_0${v}.wav`,
    'The Hunter\'s gear in a dodge, a roll or a landing: the scabbard knocking, the fittings rattling and the harness creaking (milestone-1 task 36)',
    'A scabbard knock (a hollow 520-700 Hz box) with a second softer one, four to six brass ticks scattered over 120 ms, and a short leather creak (a wandering train of band-passed clicks)',
    0.4,
    (r) => {
      const b = buffer(0.4);
      scabbardKnock(b, r, { peak: 0.5 });
      scabbardKnock(b, r, { t0: r.range(0.05, 0.09), peak: 0.25 });
      const ticks = 4 + Math.floor(r.range(0, 3));
      for (let i = 0; i < ticks; i++) fittingTick(b, r, { t0: r.range(0.002, 0.12), peak: r.range(0.12, 0.28) });
      leatherCreak(b, r, { t0: r.range(0.02, 0.05), seconds: r.range(0.14, 0.2), peak: 0.22 });
      return b;
    },
    { peakDb: -3 },
  );
}

for (let v = 1; v <= 3; v++) {
  sound(
    `gen_hunter_creak_0${v}.wav`,
    'The Hunter\'s leather harness creaking with a swing (milestone-1 task 36)',
    'A leather creak (a train of band-passed clicks at 35-55 a second, wandering in rate) and a single brass tick',
    0.3,
    (r) => {
      const b = buffer(0.3);
      leatherCreak(b, r, { seconds: r.range(0.16, 0.24), peak: 0.4 });
      fittingTick(b, r, { t0: r.range(0.03, 0.1), peak: 0.12 });
      return b;
    },
    { peakDb: -6 },
  );
}

// ------------------------------------------------------------------ main

/** High-pass corner (Hz) that takes the DC and sub-sonic drift out of every sound. */
export const DC_BLOCK_HZ = 25;

/**
 * Renders one sound, finished: high-passed (the pitch-dropping sines and
 * one-sided noise bursts leave a DC offset), normalized to its peak level,
 * matched to its variation pool's loudness (lib/pools.mjs), and trimmed.
 * `report` receives the pool, the gain and any limiting.
 */
export function renderSound(s, report = {}) {
  const raw = s.render(makeRandom(seedFrom(s.file)));
  filter(raw, 'highpass', DC_BLOCK_HZ, { q: Math.SQRT1_2 });
  const out = normalizeBuf(raw, s.peakDb);
  const pool = poolFor(s.file);
  if (!pool) return tidy(out);
  const m = matchLoudness({ sampleRate: SR, channels: [out] }, pool);
  Object.assign(report, { pool: pool.name, gainDb: m.gainDb, limitedDb: m.limitedDb });
  // the limiter can leave a little DC on a one-sided transient
  const tidied = { sampleRate: SR, channels: [tidy(removeDc(m.audio).channels[0])] };
  return settleLoudness(tidied, pool).channels[0];
}

function main() {
  const onlyArg = process.argv.find((a) => a.startsWith('--only='));
  const only = onlyArg ? new RegExp(onlyArg.slice(7), 'i') : null;
  mkdirSync(OUT_DIR, { recursive: true });
  let n = 0;
  for (const s of SOUNDS) {
    if (only && !only.test(s.file)) continue;
    const report = {};
    const out = renderSound(s, report);
    writeFileSync(join(OUT_DIR, s.file), writeWav({ sampleRate: SR, channels: [out] }, { seed: seedFrom(s.file) }));
    let matched = '';
    if (report.pool) {
      matched = `  ${report.pool} ${report.gainDb >= 0 ? '+' : ''}${report.gainDb.toFixed(1)} dB`;
      if (report.limitedDb > 0.05) matched += `, limited ${report.limitedDb.toFixed(1)} dB`;
    }
    console.log(`  sfx/${s.file.padEnd(28)} ${(out.length / SR).toFixed(2).padStart(5)} s${matched}`);
    n++;
  }
  return n;
}

// Not awaited at the top level: writeSourcesMd imports this module for SOUNDS.
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const n = main();
  writeSourcesMd()
    .then(() => console.log(`synth: wrote ${n} file(s).`))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
