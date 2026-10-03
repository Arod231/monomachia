// Tests for the audio asset scripts (scripts/audio): the ZIP and WAV readers,
// the DSP and synthesis helpers, and checks on the committed audio files.
// Plain JavaScript because the scripts are Node .mjs modules.

import { describe, expect, it } from 'vitest';
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import zlib from 'node:zlib';
import { openZip } from '../../scripts/audio/lib/zip.mjs';
import { readWav, readWavInfo, writeWav } from '../../scripts/audio/lib/wav.mjs';
import * as dsp from '../../scripts/audio/lib/dsp.mjs';
import { pluck, SR } from '../../scripts/audio/lib/synthkit.mjs';
import { makeRandom, mulberry32 } from '../../scripts/audio/lib/rng.mjs';
import { SOUNDS } from '../../scripts/audio/synth.mjs';
import { epiano } from '../../scripts/audio/lib/instruments.mjs';
import { highpassLoop } from '../../scripts/audio/lib/synthkit.mjs';
import { strongestBeat } from './measure.mjs';

const ROOT = resolve(import.meta.dirname, '..', '..');
const AUDIO = join(ROOT, 'game', 'assets', 'audio');

const sine = (freq, seconds, rate, amp = 0.5) => {
  const n = Math.round(seconds * rate);
  const c = new Float32Array(n);
  for (let i = 0; i < n; i++) c[i] = amp * Math.sin((2 * Math.PI * freq * i) / rate);
  return { sampleRate: rate, channels: [c] };
};

/** Frequency from the rate of upward zero crossings. */
const zeroCrossingHz = (ch, rate) => {
  let first = -1;
  let last = -1;
  let count = 0;
  for (let i = 1; i < ch.length; i++) {
    if (ch[i - 1] < 0 && ch[i] >= 0) {
      if (first < 0) first = i;
      last = i;
      count++;
    }
  }
  return ((count - 1) * rate) / (last - first);
};

/** Builds a zip in memory: one stored and one deflated entry. */
function makeZip(entries) {
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const { name, data, deflate } of entries) {
    const nameBuf = Buffer.from(name, 'utf8');
    const body = deflate ? zlib.deflateRawSync(data) : data;
    const crc = zlib.crc32(data) >>> 0;
    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0);
    lh.writeUInt16LE(20, 4);
    lh.writeUInt16LE(0x800, 6);
    lh.writeUInt16LE(deflate ? 8 : 0, 8);
    lh.writeUInt32LE(crc, 14);
    lh.writeUInt32LE(body.length, 18);
    lh.writeUInt32LE(data.length, 22);
    lh.writeUInt16LE(nameBuf.length, 26);
    locals.push(lh, nameBuf, body);
    const ch = Buffer.alloc(46);
    ch.writeUInt32LE(0x02014b50, 0);
    ch.writeUInt16LE(20, 4);
    ch.writeUInt16LE(20, 6);
    ch.writeUInt16LE(0x800, 8);
    ch.writeUInt16LE(deflate ? 8 : 0, 10);
    ch.writeUInt32LE(crc, 16);
    ch.writeUInt32LE(body.length, 20);
    ch.writeUInt32LE(data.length, 24);
    ch.writeUInt16LE(nameBuf.length, 28);
    ch.writeUInt32LE(offset, 42);
    centrals.push(ch, nameBuf);
    offset += 30 + nameBuf.length + body.length;
  }
  const cd = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(cd.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, cd, end]);
}

describe('zip reader', () => {
  it('reads stored and deflated entries by name, whole or in part', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'monomachia-zip-'));
    try {
      const big = Buffer.alloc(300000);
      for (let i = 0; i < big.length; i++) big[i] = (i * 7) & 0xff;
      const path = join(dir, 'test.zip');
      writeFileSync(path, makeZip([
        { name: 'Library/Stored.txt', data: Buffer.from('hello, bundle'), deflate: false },
        { name: 'Library/Deflated, with comma.bin', data: big, deflate: true },
      ]));
      const zip = openZip(path);
      expect(zip.names()).toEqual(['Library/Stored.txt', 'Library/Deflated, with comma.bin']);
      expect((await zip.read('Library/Stored.txt')).toString()).toBe('hello, bundle');
      expect((await zip.read('Library/Deflated, with comma.bin')).equals(big)).toBe(true);
      const head = await zip.read('Library/Deflated, with comma.bin', { maxBytes: 1000 });
      expect(head.length).toBe(1000);
      expect(head.equals(big.subarray(0, 1000))).toBe(true);
      await expect(zip.read('Library/Missing.wav')).rejects.toThrow(/no entry/);
      zip.close();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe('wav reader and writer', () => {
  it('round-trips 16-bit audio within a dither step, with a loop chunk', () => {
    const a = sine(441, 0.1, 44100);
    const buf = writeWav(a, { loop: { start: 0, end: 4410 } });
    const b = readWav(buf);
    expect(b.sampleRate).toBe(44100);
    expect(b.bits).toBe(16);
    expect(b.channels[0].length).toBe(4410);
    for (let i = 0; i < 4410; i++) expect(Math.abs(b.channels[0][i] - a.channels[0][i])).toBeLessThan(2.5 / 32768);
    const smpl = buf.indexOf('smpl');
    expect(smpl).toBeGreaterThan(0);
    expect(buf.readUInt32LE(smpl + 8 + 44)).toBe(0); // loop start
    expect(buf.readUInt32LE(smpl + 8 + 48)).toBe(4410); // loop end
  });

  it('writes the same bytes every time', () => {
    const a = sine(1000, 0.05, 44100);
    expect(writeWav(a, { seed: 3 }).equals(writeWav(a, { seed: 3 }))).toBe(true);
  });

  it('reads 24-bit integer and 32-bit float stereo, and a file cut short', () => {
    const frames = 100;
    const make = (tag, bits, writeSample) => {
      const block = 2 * (bits / 8);
      const buf = Buffer.alloc(44 + frames * block);
      buf.write('RIFF', 0);
      buf.writeUInt32LE(36 + frames * block, 4);
      buf.write('WAVEfmt ', 8);
      buf.writeUInt32LE(16, 16);
      buf.writeUInt16LE(tag, 20);
      buf.writeUInt16LE(2, 22);
      buf.writeUInt32LE(96000, 24);
      buf.writeUInt32LE(96000 * block, 28);
      buf.writeUInt16LE(block, 32);
      buf.writeUInt16LE(bits, 34);
      buf.write('data', 36);
      buf.writeUInt32LE(frames * block, 40);
      for (let i = 0; i < frames; i++) {
        writeSample(buf, 44 + i * block, i / frames);
        writeSample(buf, 44 + i * block + bits / 8, -i / frames);
      }
      return buf;
    };
    const pcm24 = make(1, 24, (b, p, v) => b.writeIntLE(Math.round(v * 8388607), p, 3));
    const f32 = make(3, 32, (b, p, v) => b.writeFloatLE(v, p));
    for (const buf of [pcm24, f32]) {
      const a = readWav(buf);
      expect(a.sampleRate).toBe(96000);
      expect(a.channels.length).toBe(2);
      expect(a.channels[0][50]).toBeCloseTo(0.5, 5);
      expect(a.channels[1][50]).toBeCloseTo(-0.5, 5);
    }
    const cut = readWav(pcm24.subarray(0, 44 + 40 * 6 + 3));
    expect(cut.truncated).toBe(true);
    expect(cut.channels[0].length).toBe(40);
    expect(readWavInfo(pcm24).frames).toBe(frames);
  });
});

describe('dsp', () => {
  it('resamples 96 kHz to 44.1 kHz keeping pitch and level', () => {
    const a = sine(1000, 0.5, 96000, 0.5);
    const b = dsp.resample(a, 44100);
    expect(b.sampleRate).toBe(44100);
    expect(b.channels[0].length).toBe(22050);
    expect(zeroCrossingHz(b.channels[0], 44100)).toBeCloseTo(1000, 0);
    const mid = dsp.slice(b, 0.1, 0.4);
    expect(dsp.peak(mid)).toBeGreaterThan(0.49);
    expect(dsp.peak(mid)).toBeLessThan(0.51);
  });

  it('removes content above the new Nyquist frequency instead of folding it back', () => {
    const b = dsp.resample(sine(30000, 0.5, 96000, 0.5), 44100);
    expect(dsp.gainToDb(dsp.peak(dsp.slice(b, 0.1, 0.4)) / 0.5)).toBeLessThan(-60);
  });

  it('pitches up an octave by halving the length', () => {
    const b = dsp.pitchShift(sine(500, 0.4, 44100), 12);
    expect(b.channels[0].length).toBe(Math.floor(0.4 * 44100 / 2));
    expect(zeroCrossingHz(b.channels[0], 44100)).toBeCloseTo(1000, 0);
  });

  it('finds separate takes and trims silence', () => {
    const rate = 44100;
    const a = dsp.silence(rate, 3, 1);
    for (const t of [0.5, 1.4, 2.3]) {
      const s = Math.round(t * rate);
      for (let i = 0; i < 4410; i++) a.channels[0][s + i] = 0.5 * Math.sin(i * 0.2) * Math.exp(-i / 1500);
    }
    const takes = dsp.regions(a, { floorDb: -50, minSilence: 0.2 });
    expect(takes.length).toBe(3);
    [0.5, 1.4, 2.3].forEach((t, i) => expect(Math.abs(takes[i].start - t)).toBeLessThan(0.006));
    const trimmed = dsp.trimSilence(a, { thresholdDb: -50, padStart: 0, padEnd: 0 });
    expect(dsp.duration(trimmed)).toBeGreaterThan(1.85);
    expect(dsp.duration(trimmed)).toBeLessThan(2.0);
  });

  it('crossfades a loop so the last sample flows into the first', () => {
    const a = sine(220, 3, 44100, 0.5);
    const loop = dsp.loopCrossfade(a, 2.0, 0.25);
    const c = loop.channels[0];
    expect(c.length).toBe(88200);
    // the jump across the seam is no bigger than one step of the sine
    expect(Math.abs(c[0] - c[c.length - 1])).toBeLessThan(0.5 * 2 * Math.PI * 220 / 44100 * 1.05);
  });

  it('finds the loudest sample in a stretch and measures short-term loudness', () => {
    const rate = 44100;
    const a = dsp.silence(rate, 1, 1);
    a.channels[0][Math.round(0.42 * rate)] = 0.9;
    a.channels[0][Math.round(0.8 * rate)] = -0.5;
    expect(dsp.peakTime(a, 0.3, 0.6)).toBeCloseTo(0.42, 4);
    expect(dsp.peakTime(a, 0.6, 1)).toBeCloseTo(0.8, 4);
    // a full-scale sine's loudest 100 ms is 3 dB under its peak
    expect(dsp.shortTermLoudness(sine(1000, 0.5, rate, 1))).toBeCloseTo(-3.01, 1);
  });

  it('matches loudness, limiting peaks to the ceiling only where it must', () => {
    const rate = 44100;
    // a quiet bed under one spike: peak-normalizing would leave it quiet
    const spiky = sine(300, 0.4, rate, 0.05);
    spiky.channels[0][8000] = 0.9;
    const m = dsp.matchLoudness(spiky, { loudnessDb: -15, ceilingDb: -3 });
    expect(dsp.shortTermLoudness(m.audio)).toBeCloseTo(-15, 1);
    expect(dsp.gainToDb(dsp.peak(m.audio))).toBeLessThanOrEqual(-3 + 1e-4);
    expect(m.limitedDb).toBeGreaterThan(0);
    // a loud, dense clip is only turned down
    const dense = dsp.matchLoudness(sine(300, 0.4, rate, 0.8), { loudnessDb: -15, ceilingDb: -3 });
    expect(dense.limitedDb).toBe(0);
    expect(dsp.shortTermLoudness(dense.audio)).toBeCloseTo(-15, 1);
    // the limiter never lets a sample over its ceiling
    const limited = dsp.limit(dsp.gain(sine(80, 0.3, rate, 0.9), 12), -6);
    expect(dsp.gainToDb(dsp.peak(limited))).toBeLessThanOrEqual(-6 + 1e-4);
  });

  it('decays 20 dB per period and takes out DC', () => {
    const rate = 44100;
    const ones = { sampleRate: rate, channels: [new Float32Array(rate).fill(1)] };
    const d = dsp.decay(ones, 0.5);
    expect(d.channels[0][Math.round(0.5 * rate)]).toBeCloseTo(0.1, 3);
    const offset = sine(441, 0.2, rate, 0.3);
    for (let i = 0; i < offset.channels[0].length; i++) offset.channels[0][i] += 0.2;
    const fixed = dsp.removeDc(offset).channels[0];
    expect(Math.abs(fixed.reduce((x, y) => x + y, 0) / fixed.length)).toBeLessThan(1e-6);
  });

  it('normalizes to a peak and mixes layers at offsets', () => {
    const a = dsp.normalize(sine(100, 0.1, 44100, 0.2), { peakDb: -6 });
    expect(dsp.gainToDb(dsp.peak(a))).toBeCloseTo(-6, 1);
    const m = dsp.mix([{ audio: a }, { audio: a, offset: 0.1 }]);
    expect(dsp.duration(m)).toBeCloseTo(0.2, 3);
  });
});

describe('synthesis', () => {
  it('tunes Karplus-Strong plucks within two cents', () => {
    for (const f of [73.42, 146.83, 440]) {
      const b = pluck(f, 0.5, mulberry32(1), { bright: 0.62, buzz: 0.25 });
      // autocorrelation peak over a window, refined with a parabola
      const start = Math.round(0.1 * SR);
      const len = Math.round(0.2 * SR);
      const corr = (lag) => {
        let s = 0;
        for (let i = start; i < start + len; i++) s += b[i] * b[i + lag];
        return s;
      };
      let best = 0;
      let bestLag = 0;
      for (let lag = Math.floor(SR / (f * 1.2)); lag <= Math.ceil(SR / (f * 0.8)); lag++) {
        const c = corr(lag);
        if (c > best) (best = c), (bestLag = lag);
      }
      const [y0, y1, y2] = [corr(bestLag - 1), best, corr(bestLag + 1)];
      const measured = SR / (bestLag + (y0 - y2) / (2 * (y0 - 2 * y1 + y2)));
      expect(Math.abs(1200 * Math.log2(measured / f))).toBeLessThan(2);
    }
  });

  it('keeps the electric piano free of DC (its 1:1 FM pair stays phase-locked)', () => {
    const r = makeRandom(1234);
    for (const midi of [41, 53, 57, 64, 72]) {
      const b = epiano(r, midi, { length: 0.4 });
      let s = 0;
      let q = 0;
      for (const v of b) (s += v), (q += v * v);
      const meanDb = 20 * Math.log10(Math.abs(s / b.length) / Math.sqrt(q / b.length));
      expect(meanDb, `MIDI ${midi}`).toBeLessThan(-40);
    }
  });

  it('high-passes a loop without breaking its seam', () => {
    // one second of a 220 Hz tone riding on DC and a 2 Hz drift, whole cycles
    const n = SR;
    const L = new Float32Array(n);
    const R = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      L[i] = 0.3 * Math.sin((2 * Math.PI * 220 * i) / n) + 0.2 + 0.2 * Math.sin((2 * Math.PI * 2 * i) / n);
      R[i] = L[i];
    }
    highpassLoop([L, R], 20);
    const mean = L.reduce((x, y) => x + y, 0) / n;
    expect(Math.abs(mean)).toBeLessThan(1e-4);
    // the drift is gone and the tone kept: the wrapped step is a tone step
    const step = Math.abs(L[0] - L[n - 1]);
    expect(step).toBeLessThan(0.3 * ((2 * Math.PI * 220) / n) * 1.1);
    let peak = 0;
    for (let i = n / 2; i < n; i++) peak = Math.max(peak, Math.abs(L[i]));
    expect(peak).toBeGreaterThan(0.29);
    expect(peak).toBeLessThan(0.31);
  });

  it('renders every generated sound the same way twice', () => {
    for (const s of SOUNDS.slice(0, 6)) {
      const a = s.render(makeRandom(s.file));
      const b = s.render(makeRandom(s.file));
      expect(Buffer.from(a.buffer).equals(Buffer.from(b.buffer))).toBe(true);
    }
  });
});

describe('committed audio', () => {
  const files = (dir) => readdirSync(join(AUDIO, dir)).filter((f) => f.endsWith('.wav'));

  it('stays under 40 MB in total', () => {
    let total = 0;
    for (const dir of ['sfx', 'music']) for (const f of files(dir)) total += statSync(join(AUDIO, dir, f)).size;
    expect(total / 1048576).toBeLessThan(40);
  });

  it('has every Sonniss pick and every generated sound, as 16-bit 44.1 kHz', () => {
    const picks = JSON.parse(readFileSync(join(ROOT, 'scripts', 'audio', 'sonniss-picks.json'), 'utf8'));
    const present = new Set(files('sfx'));
    for (const name of [...picks.outputs.map((o) => o.file), ...SOUNDS.map((s) => s.file)]) {
      expect(present.has(name), name).toBe(true);
      const info = readWavInfo(readFileSync(join(AUDIO, 'sfx', name)).subarray(0, 256));
      expect(info.sampleRate, name).toBe(44100);
      expect(info.bits, name).toBe(16);
      expect(info.channels, name).toBe(name.startsWith('amb_') ? 2 : 1);
    }
  });

  describe('music', () => {
    const index = JSON.parse(readFileSync(join(AUDIO, 'music', 'tracks.json'), 'utf8'));
    for (const [id, track] of Object.entries(index.tracks)) {
      it(`${id}: lasts exactly its bars, loops seamlessly and pulses at ${track.bpm} BPM`, () => {
        const a = readWav(readFileSync(join(AUDIO, 'music', track.file)));
        expect(a.channels.length).toBe(2);
        expect(dsp.duration(a)).toBeCloseTo((track.bars * 4 * 60) / track.bpm, 3);

        // Seamless: the step from the last sample to the first is no bigger
        // than the steps just around it.
        const w = Math.round(0.005 * a.sampleRate);
        for (const ch of a.channels) {
          const n = ch.length;
          let local = 0;
          for (let i = n - w; i < n - 1; i++) local = Math.max(local, Math.abs(ch[i + 1] - ch[i]));
          for (let i = 0; i < w; i++) local = Math.max(local, Math.abs(ch[i + 1] - ch[i]));
          expect(Math.abs(ch[0] - ch[n - 1])).toBeLessThanOrEqual(local * 1.5 + 1e-3);
        }

        // Tempo measured from the audio: the strongest beat between 60 and
        // 200 BPM is the track's own tempo, not half or double it.
        const measured = strongestBeat(a);
        expect(Math.abs(measured - track.bpm), `measured ${measured.toFixed(2)} BPM`).toBeLessThanOrEqual(2);

        // No DC or sub-sonic drift: the whole loop and every second of it
        // average out to (nearly) zero.
        for (const ch of a.channels) {
          const sr = a.sampleRate;
          expect(dsp.gainToDb(Math.abs(ch.reduce((x, y) => x + y, 0) / ch.length))).toBeLessThan(-70);
          for (let s = 0; s + sr <= ch.length; s += sr) {
            let sum = 0;
            for (let i = s; i < s + sr; i++) sum += ch[i];
            expect(Math.abs(sum / sr)).toBeLessThan(0.003); // about 100 LSB, -50 dBFS
          }
        }
      }, 60000);
    }
  });
});
