// Measured checks on the committed sound effects: the defects the audio
// verification pass found (late or doubled hits, slow UI attacks, uneven
// loudness inside variation pools, DC, long silent tails) must not come back.
// The measurements are in measure.mjs; the music's tempo and DC are checked
// in audio-tools.test.mjs.

import { describe, expect, it } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { readWav } from '../../scripts/audio/lib/wav.mjs';
import { POOLS } from '../../scripts/audio/lib/pools.mjs';
import { attack, dcDb, loudness, peakDb, tailMs } from './measure.mjs';

const ROOT = resolve(import.meta.dirname, '..', '..');
const SFX = join(ROOT, 'game', 'assets', 'audio', 'sfx');

const names = readdirSync(SFX).filter((f) => f.endsWith('.wav'));
const oneShots = names.filter((f) => !f.startsWith('amb_'));
const cache = new Map();
const load = (f) => {
  if (!cache.has(f)) cache.set(f, readWav(readFileSync(join(SFX, f))));
  return cache.get(f);
};

/** Impacts: the hit has to be at the start, where the game triggers it. */
const IMPACT = /^(clang_|parry_contact_|hit_|crunch_|body_drop_|weapon_bounce_)/;
/** Menu sounds answer a key press, so they must peak almost at once. */
const MENU = /^ui_(move|select|back)_/;

describe('sound effects', () => {
  it('impacts peak within 15 ms of the start, with no second hit within 3 dB', () => {
    const impacts = oneShots.filter((f) => IMPACT.test(f));
    expect(impacts.length).toBeGreaterThan(30);
    for (const f of impacts) {
      const { peakMs, laterDb } = attack(load(f));
      expect(peakMs, `${f} peaks at ${peakMs} ms`).toBeLessThanOrEqual(15);
      expect(laterDb, `${f} hits again at ${laterDb.toFixed(1)} dB`).toBeLessThan(-3);
    }
  });

  it('menu move, select and back sounds peak within 10 ms', () => {
    const menu = oneShots.filter((f) => MENU.test(f));
    expect(menu.length).toBe(7);
    for (const f of menu) expect(attack(load(f)).peakMs, f).toBeLessThanOrEqual(10);
  });

  it('dodge cloth flaps and the dash peak within 30 ms', () => {
    for (const f of oneShots.filter((x) => /^(dodge_cloth_|ult_dash_)/.test(x))) {
      expect(attack(load(f)).peakMs, f).toBeLessThanOrEqual(30);
    }
  });

  it('carry no DC', () => {
    for (const f of names) expect(dcDb(load(f)), f).toBeLessThan(-70);
  });

  it('end within 30 ms of their last sample above -60 dBFS', () => {
    for (const f of oneShots) expect(tailMs(load(f)), f).toBeLessThanOrEqual(30);
  });

  it('match their pool loudness, peaks under the ceiling', () => {
    for (const [name, pool] of Object.entries(POOLS)) {
      const files = oneShots.filter((f) => pool.files.test(f));
      expect(files.length, name).toBeGreaterThanOrEqual(2);
      for (const f of files) {
        const a = load(f);
        expect(Math.abs(loudness(a) - pool.loudnessDb), `${f} in ${name}`).toBeLessThan(0.5);
        expect(peakDb(a), f).toBeLessThanOrEqual(pool.ceilingDb + 0.1);
      }
    }
  });

  it('vary by at most 2 dB in loudness within every sound bank cue', () => {
    // The cues and their files, read from the sound bank itself.
    const bank = readFileSync(join(ROOT, 'game', 'audio', 'sound_bank.gd'), 'utf8');
    const cues = [...bank.matchAll(/&"(\w+)": \{\s*"files": \[([^\]]*)\]/g)].map((m) => ({
      cue: m[1],
      files: [...m[2].matchAll(/"([^"]+\.wav)"/g)].map((x) => x[1]),
    }));
    expect(cues.length).toBeGreaterThan(30);
    const pooled = cues.filter((c) => c.files.length > 1 && !c.files.some((f) => f.startsWith('amb_')));
    expect(pooled.length).toBeGreaterThan(20);
    for (const { cue, files } of pooled) {
      const levels = files.map((f) => loudness(load(f)));
      const spread = Math.max(...levels) - Math.min(...levels);
      expect(spread, `${cue}: ${files.map((f, i) => `${f} ${levels[i].toFixed(1)}`).join(', ')}`).toBeLessThanOrEqual(2);
    }
  });
});
