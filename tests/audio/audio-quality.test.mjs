// Measured checks on the committed sound effects: the defects the audio
// verification pass found (late or doubled hits, slow UI attacks, uneven
// loudness inside variation pools, DC, long silent tails) must not come back.
// The measurements are in measure.mjs; the music's tempo and DC are checked
// in audio-tools.test.mjs.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
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
    assert.ok(impacts.length > 30);
    for (const f of impacts) {
      const { peakMs, laterDb } = attack(load(f));
      assert.ok(peakMs <= 15, `${f} peaks at ${peakMs} ms`);
      assert.ok(laterDb < -3, `${f} hits again at ${laterDb.toFixed(1)} dB`);
    }
  });

  it('menu move, select and back sounds peak within 10 ms', () => {
    const menu = oneShots.filter((f) => MENU.test(f));
    assert.equal(menu.length, 7);
    for (const f of menu) assert.ok(attack(load(f)).peakMs <= 10, f);
  });

  it('dodge cloth flaps and the dash peak within 30 ms', () => {
    for (const f of oneShots.filter((x) => /^(dodge_cloth_|ult_dash_)/.test(x))) {
      assert.ok(attack(load(f)).peakMs <= 30, f);
    }
  });

  it('carry no DC', () => {
    for (const f of names) assert.ok(dcDb(load(f)) < -70, f);
  });

  it('end within 30 ms of their last sample above -60 dBFS', () => {
    for (const f of oneShots) assert.ok(tailMs(load(f)) <= 30, f);
  });

  it('match their pool loudness, peaks under the ceiling', () => {
    for (const [name, pool] of Object.entries(POOLS)) {
      const files = oneShots.filter((f) => pool.files.test(f));
      assert.ok(files.length >= 2, name);
      for (const f of files) {
        const a = load(f);
        assert.ok(Math.abs(loudness(a) - pool.loudnessDb) < 0.5, `${f} in ${name}`);
        assert.ok(peakDb(a) <= pool.ceilingDb + 0.1, f);
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
    assert.ok(cues.length > 30);
    const pooled = cues.filter((c) => c.files.length > 1 && !c.files.some((f) => f.startsWith('amb_')));
    assert.ok(pooled.length > 20);
    for (const { cue, files } of pooled) {
      const levels = files.map((f) => loudness(load(f)));
      const spread = Math.max(...levels) - Math.min(...levels);
      assert.ok(spread <= 2, `${cue}: ${files.map((f, i) => `${f} ${levels[i].toFixed(1)}`).join(', ')}`);
    }
  });
});
