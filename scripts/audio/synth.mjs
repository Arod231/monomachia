#!/usr/bin/env node
// Generates the sound effects the Sonniss bundle has no recordings for: taiko,
// gong, the parry ring, footsteps on stone, falls and landings, cloth swishes,
// metal pings, the round-call drums, the Hunter's gear and the placeholder
// pain and death cries. They are written to
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
  Biquad,
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
  wave,
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

// ------------------------------------------------------------------ effort vocals

// The placeholder effort vocals the bundle has no recordings for (milestone-1
// task 114): a man's pain grunts and death cries, until a vocals pack is
// bought. The kiai and the breaths are cut from the bundle's male recordings
// (sonniss-picks.json). One voice, sung through moving formants: a glottal
// pulse with jitter and shimmer, a breath of aspiration noise riding it, and
// vocal fry as the voice breaks.

/** Male vowel formants: [Hz, bandwidth Hz, level] for F1-F4. */
const VOICE_VOWELS = {
  ah: [[730, 90, 1], [1090, 110, 0.5], [2440, 160, 0.18], [3400, 250, 0.08]],
  uh: [[640, 80, 1], [1190, 100, 0.45], [2390, 150, 0.15], [3300, 250, 0.06]],
  eh: [[530, 70, 1], [1840, 110, 0.4], [2480, 160, 0.2], [3500, 250, 0.08]],
  oo: [[320, 60, 1], [800, 90, 0.3], [2240, 150, 0.06], [3300, 250, 0.03]],
  // a pressed, strained throat: the formants pulled toward the middle
  ugh: [[600, 110, 1], [1250, 140, 0.55], [2500, 200, 0.2], [3400, 300, 0.07]],
};

/** A value along a piecewise-linear curve of [t, value] points at time t. */
function curve(points, t) {
  if (t <= points[0][0]) return points[0][1];
  for (let i = 1; i < points.length; i++) {
    if (t <= points[i][0]) {
      const [t0, v0] = points[i - 1];
      const [t1, v1] = points[i];
      return v0 + ((v1 - v0) * (t - t0)) / (t1 - t0);
    }
  }
  return points[points.length - 1][1];
}

/**
 * One utterance. `pitch`, `level`, `breath` (the aspiration's share) and
 * `fry` (how much the pulses fall irregular and low, 0-1) are [t, value]
 * curves; `vowels` is [t, vowel] points the formants glide between; `jitter`
 * is the pitch's random wobble (a fraction, per glottal period).
 */
function voice(r, seconds, { pitch, level, vowels, breath = [[0, 0.15]], fry = [[0, 0]], jitter = 0.012 }) {
  const n = Math.ceil(seconds * SR);
  const src = new Float32Array(n);
  const air = new Float32Array(n);
  let ph = 0;
  let wobble = 1;
  let shimmer = 1;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const fr = curve(fry, t);
    let f = curve(pitch, t) * wobble;
    // fry: the pulses slow and stumble as the voice breaks
    if (fr > 0) f *= 1 - 0.55 * fr;
    const before = ph;
    ph += f / SR;
    if (ph >= 1) {
      ph -= 1;
      wobble = 1 + (r.next() * 2 - 1) * (jitter + 0.05 * fr);
      shimmer = 1 - r.next() * (0.12 + 0.5 * fr);
    }
    // a glottal pulse: a sawtooth softened by its cube, rich in harmonics
    const s = wave('sawtooth', before, f / SR);
    const a = curve(level, t);
    src[i] = (s - 0.3 * s * s * s) * a * shimmer;
    // the breath rides the pulse, strongest as the glottis opens
    air[i] = (r.next() * 2 - 1) * a * curve(breath, t) * (0.6 + 0.4 * Math.max(0, Math.sin(Math.PI * 2 * ph)));
  }
  const mix = new Float32Array(n);
  for (let k = 0; k < 4; k++) {
    // two biquads in series per formant, retuned as the vowel glides
    const freqAt = (t) => {
      const prev = [...vowels].reverse().find(([vt]) => vt <= t) ?? vowels[0];
      const next = vowels.find(([vt]) => vt > t) ?? prev;
      const u = next === prev ? 0 : (t - prev[0]) / (next[0] - prev[0]);
      const a = VOICE_VOWELS[prev[1]][k];
      const b = VOICE_VOWELS[next[1]][k];
      return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u];
    };
    const [f0, bw0] = freqAt(0);
    const q1 = new Biquad('bandpass', f0, f0 / bw0);
    const q2 = new Biquad('bandpass', f0, f0 / bw0);
    for (let i = 0; i < n; i++) {
      const t = i / SR;
      const [fc, bw, lvl] = freqAt(t);
      if ((i & 31) === 0) {
        q1.q = fc / bw;
        q2.q = fc / bw;
        q1.set(fc);
        q2.set(fc);
      }
      mix[i] += q2.step(q1.step(src[i] + air[i] * 0.5)) * lvl * 4;
    }
  }
  // the breath also leaks around the formants, a hiss above them
  filter(air, 'highpass', 1800, { q: 0.7 });
  for (let i = 0; i < n; i++) mix[i] += air[i] * 0.25;
  filter(mix, 'highpass', 90, { q: 0.7 });
  filter(mix, 'peaking', 3000, { q: 1, gainDb: 3 }); // presence
  return mix;
}

// Pain on a light hit: a short grunt forced out, a glottal catch at the start.
for (let v = 1; v <= 4; v++) {
  sound(
    `gen_pain_0${v}.wav`,
    'Pain on a light hit taken: a short grunt forced out (milestone-1 task 114, a placeholder until a vocals pack is bought)',
    'A male voice (a glottal pulse with jitter and shimmer and a breath of aspiration, through moving formants) pressed into "ugh" then "uh", its pitch jumping up and falling, a hard glottal start and a breathy end',
    0.32,
    (r) => {
      const len = r.range(0.17, 0.24);
      const top = r.range(150, 190);
      return voice(r, 0.32, {
        pitch: [[0, top * 0.85], [0.03, top], [len, top * 0.72]],
        level: [[0, 0], [0.006, 1], [len * 0.6, 0.75], [len, 0.05], [len + 0.04, 0]],
        vowels: [[0, 'ugh'], [len, v % 2 ? 'uh' : 'ah']],
        breath: [[0, 0.25], [len * 0.7, 0.4], [len, 0.9]],
        fry: [[0, 0], [len * 0.7, 0], [len, 0.5]],
        jitter: 0.02,
      });
    },
    { peakDb: -3 },
  );
}

// Pain on a heavy hit: a longer, rougher cry.
for (let v = 1; v <= 3; v++) {
  sound(
    `gen_pain_heavy_0${v}.wav`,
    'Pain on a heavy hit taken: a rough, longer cry (milestone-1 task 114, a placeholder)',
    'The same voice opened from "ugh" to "ah", higher and rougher (more jitter and breath), rising then falling away into fry and a breath out',
    0.6,
    (r) => {
      const len = r.range(0.34, 0.46);
      const top = r.range(190, 230);
      return voice(r, 0.6, {
        pitch: [[0, top * 0.8], [0.05, top], [len * 0.6, top * 0.92], [len, top * 0.6]],
        level: [[0, 0], [0.008, 1], [len * 0.5, 0.9], [len, 0.08], [len + 0.08, 0]],
        vowels: [[0, 'ugh'], [0.06, 'ah'], [len, 'uh']],
        breath: [[0, 0.35], [len * 0.5, 0.45], [len, 1]],
        fry: [[0, 0], [len * 0.65, 0.1], [len, 0.7]],
        jitter: 0.03,
      });
    },
    { peakDb: -3 },
  );
}

// The death cry: a long cry that falls and breaks, the last breath going out.
for (let v = 1; v <= 3; v++) {
  sound(
    `gen_death_0${v}.wav`,
    'Death cry on a K.O. or a finisher\'s kill: a long cry falling and breaking into the last breath (milestone-1 task 114, a placeholder)',
    'The same voice: a strained "ah" rising, then falling an octave through "uh" as jitter and fry take it and the voice breaks into breath, the breath trailing out',
    1.5,
    (r) => {
      const len = r.range(0.95, 1.2);
      const top = r.range(170, 210);
      return voice(r, 1.5, {
        pitch: [[0, top * 0.85], [0.1, top], [0.3, top * 0.95], [len, top * 0.48]],
        level: [[0, 0], [0.02, 1], [0.35, 0.9], [len * 0.85, 0.35], [len, 0.06], [len + 0.25, 0]],
        vowels: [[0, 'ugh'], [0.08, 'ah'], [0.4, 'ah'], [len * 0.8, 'uh'], [len, 'oo']],
        breath: [[0, 0.3], [0.4, 0.35], [len * 0.8, 0.7], [len, 1], [len + 0.25, 1]],
        fry: [[0, 0], [0.45, 0.05], [len * 0.8, 0.5], [len, 0.9]],
        jitter: 0.025,
      });
    },
    { peakDb: -3 },
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
