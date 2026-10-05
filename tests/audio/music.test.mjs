// Tests for the generated score's instruments and arrangement (scripts/audio/music.mjs,
// milestone-1 task 113): the shakuhachi, the biwa and the low choir, the battle loop
// led by them, and the match point's electronic and metal layers building in.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { SR } from '../../scripts/audio/lib/synthkit.mjs';
import { makeRandom } from '../../scripts/audio/lib/rng.mjs';
import { biwa, choir, midiToHz, shakuhachi } from '../../scripts/audio/lib/instruments.mjs';
import { TRACKS, renderTrack } from '../../scripts/audio/music.mjs';

const same = (a, b) => Buffer.from(a.buffer).equals(Buffer.from(b.buffer));

/** The pitch (Hz) of a stretch of a buffer, by autocorrelation between lo and hi Hz. */
function pitch(b, from, to, lo, hi) {
  const x = b.subarray(Math.round(from * SR), Math.round(to * SR));
  const corr = (lag) => {
    let s = 0;
    for (let i = 0; i + lag < x.length; i++) s += x[i] * x[i + lag];
    return s;
  };
  let best = -Infinity;
  let bestLag = 0;
  for (let lag = Math.floor(SR / hi); lag <= Math.ceil(SR / lo); lag++) {
    const c = corr(lag);
    if (c > best) (best = c), (bestLag = lag);
  }
  const [y0, y1, y2] = [corr(bestLag - 1), best, corr(bestLag + 1)];
  return SR / (bestLag + (y0 - y2) / (2 * (y0 - 2 * y1 + y2)));
}

const cents = (f, midi) => 1200 * Math.log2(f / midiToHz(midi));

/** The mean against the RMS, in dB. */
function dcDb(b) {
  let s = 0;
  let q = 0;
  for (const v of b) (s += v), (q += v * v);
  return 20 * Math.log10(Math.abs(s / b.length) / Math.sqrt(q / b.length));
}

describe('the score instruments', () => {
  const voices = {
    shakuhachi: (r) => shakuhachi(r, 69, { length: 0.8, from: 67 }),
    biwa: (r) => biwa(r, 50, { seconds: 1.2, bend: 1 }),
    choir: (r) => choir(r, [38, 45, 50], { length: 1.5, vowel: 'ah' }),
  };

  for (const [name, render] of Object.entries(voices)) {
    it(`renders the ${name} the same way twice, with no DC`, () => {
      const a = render(makeRandom(name));
      const b = render(makeRandom(name));
      assert.ok(same(a, b));
      assert.ok(dcDb(a) < -40, `${name}: ${dcDb(a).toFixed(1)} dB`);
      assert.ok(a.every(Number.isFinite));
    });
  }

  it('bends the shakuhachi up into its note and holds it there', () => {
    const b = shakuhachi(makeRandom(1), 69, { length: 0.8 });
    const start = pitch(b, 0.0, 0.03, 300, 600);
    const held = pitch(b, 0.3, 0.55, 300, 600);
    assert.ok(cents(start, 69) < -40, `starts below: ${cents(start, 69).toFixed(0)} cents`);
    assert.ok(Math.abs(cents(held, 69)) < 15, `held: ${cents(held, 69).toFixed(0)} cents`);
  });

  it('bends the biwa a semitone up after its strike', () => {
    const plain = biwa(makeRandom(2), 50, { seconds: 1 });
    const bent = biwa(makeRandom(2), 50, { seconds: 1, bend: 1 });
    assert.ok(Math.abs(cents(pitch(plain, 0.4, 0.6, 100, 200), 50)) < 15);
    assert.ok(Math.abs(cents(pitch(bent, 0.4, 0.6, 100, 200), 51)) < 15);
  });

  it('sings the choir on its chord\'s root', () => {
    const b = choir(makeRandom(3), [45], { length: 1, vowel: 'oo' });
    assert.ok(Math.abs(cents(pitch(b, 0.5, 0.9, 80, 160), 45)) < 15);
  });
});

describe('the battle and match-point loops', () => {
  const render = (id) => renderTrack(TRACKS.find((t) => t.id === id));
  const battleTrack = render('battle');
  const battle = battleTrack.mix;
  const point = render('match_point').mix;
  const traditional = ['taiko', 'shakuhachi', 'biwa', 'choir'];
  const modern = ['kick', 'snare', 'hats', 'guitars'];
  const bars = (mix, stem, from, to) => [...(mix.barEnergy.get(stem) ?? new Float64Array(mix.bars)).slice(from, to)].reduce((a, b) => a + b, 0) / (to - from);

  it('leads the battle loop with traditional instruments only', () => {
    for (const s of traditional) assert.ok(battle.energy.get(s) > 0, `battle has the ${s}`);
    for (const s of modern) assert.equal(battle.energy.has(s), false, `battle has no ${s}`);
  });

  it('keeps the traditional bed at match point and adds the electronic and metal layers', () => {
    for (const s of [...traditional, ...modern]) assert.ok(point.energy.get(s) > 0, `match point has the ${s}`);
  });

  it('builds the match point\'s layers in over its first bars, then drives', () => {
    for (const s of modern) {
      const opening = bars(point, s, 0, 2);
      const drive = bars(point, s, 4, 15);
      assert.ok(opening < drive * 0.5, `${s}: bars 1-2 ${opening.toExponential(2)} against ${drive.toExponential(2)}`);
    }
  });

  it('renders a loop the same way twice', () => {
    const again = render('battle');
    battleTrack.channels.forEach((ch, i) => assert.ok(same(ch, again.channels[i]), `channel ${i}`));
  });
});
