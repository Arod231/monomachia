#!/usr/bin/env node
// Helps choose slices for sonniss-picks.json: for every bundle recording whose
// path matches a pattern, prints its format, level and the onsets (the starts
// of separate hits or takes) found in it.
//
// usage: node scripts/audio/sonniss-inspect.mjs "<regex>" [--until=<seconds>] [--rise=<dB>] [--gap=<seconds>]
//          [--env=<seconds per character>] [--envfrom=<s>] [--envfor=<s>] [--bands] [--floor=<dB>]

import { openBundle, readRecording } from './lib/sonniss.mjs';
import { highpass, levels, lowpass, onsets, regions, stats, slice } from './lib/dsp.mjs';

const args = process.argv.slice(2);
const pattern = new RegExp(args.find((a) => !a.startsWith('--')) ?? '.', 'i');
const opt = (name, dflt) => {
  const a = args.find((x) => x.startsWith(`--${name}=`));
  return a ? Number(a.split('=')[1]) : dflt;
};
const until = opt('until', 30);
const riseDb = opt('rise', 12);
const minGap = opt('gap', 0.25);
const envHop = opt('env', 0); // seconds per character of the level graph; 0 = off
const envFor = opt('envfor', 10);
const floorDb = opt('floor', -50); // level that separates takes
const envFrom = opt('envfrom', 0);
const bands = args.includes('--bands');

const bundle = openBundle();
for (const m of bundle.missing) console.log(`missing part ${m.part}: ${m.path}`);
for (const [part, zip] of bundle.zips) {
  for (const name of zip.names()) {
    if (!/\.wav$/i.test(name) || !pattern.test(name)) continue;
    const audio = await readRecording(zip, name, { until });
    const s = stats(audio);
    console.log(`\n[part ${part}] ${name}`);
    console.log(`  ${s.sampleRate} Hz, ${s.channels} ch, read ${s.seconds} s${audio.truncated ? ' (truncated)' : ''}, peak ${s.peakDb} dB, rms ${s.rmsDb} dB`);
    const found = onsets(audio, { riseDb, minGap });
    const lines = found.slice(0, 40).map((o, i) => {
      const next = found[i + 1]?.time ?? s.seconds;
      const seg = stats(slice(audio, o.time, Math.min(next, o.time + 1.5)));
      return `    ${o.time.toFixed(3)} s  peak ${seg.peakDb} dB  rms(1.5 s) ${seg.rmsDb} dB`;
    });
    console.log(`  onsets (${found.length}):\n${lines.join('\n')}`);
    const takes = regions(audio, { floorDb, minSilence: minGap });
    console.log(
      `  takes above ${floorDb} dB (${takes.length}): ` +
        takes.slice(0, 40).map((r) => `${r.start.toFixed(2)}-${r.end.toFixed(2)} (peak ${r.peakTime.toFixed(2)}, ${r.peakDb})`).join(', '),
    );
    if (envHop > 0) {
      // Compact level graphs: one character per hop, 0-9 = 6 dB steps above -60 dBFS,
      // for the full band and, with --bands, below 250 Hz and above 2.5 kHz.
      const part = slice(audio, envFrom, envFrom + envFor);
      const graphs = [['all', part]];
      if (bands) graphs.push(['low', lowpass(part, 250, 2)], ['high', highpass(part, 2500, 2)]);
      const rows = graphs.map(([label, a]) => [label, levels(a, envHop).map((d) => (d < -60 ? '.' : String(Math.min(9, Math.floor((d + 60) / 6)))))]);
      for (let i = 0; i < rows[0][1].length; i += 100) {
        for (const [label, chars] of rows) console.log(`  ${label.padEnd(4)} ${(envFrom + i * envHop).toFixed(2).padStart(6)} s |${chars.slice(i, i + 100).join('')}`);
      }
    }
  }
}
bundle.close();
