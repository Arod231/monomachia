// Writes game/assets/audio/SOURCES.md: where every committed sound comes from
// and how it was made. Built from the three generators' own data (the Sonniss
// picks, the synthesized sound list and the music track list), so it is
// rewritten, identically, by whichever generator runs.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { POOLS, poolFor } from './pools.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const SCRIPTS = resolve(HERE, '..');
const ROOT = resolve(SCRIPTS, '..', '..');
export const SOURCES_MD = join(ROOT, 'game', 'assets', 'audio', 'SOURCES.md');

const fmt = (n) => String(+n.toFixed(3));

function describeLayer(layer, sources) {
  const src = sources[layer.source];
  const file = src.entry.split('/').pop();
  let cut;
  if (layer.take != null) {
    const where = layer.anchor === 'peak' ? 'peak' : 'start';
    const from = layer.from ? `${fmt(Math.abs(layer.from))} s ${layer.from < 0 ? 'before' : 'after'} its ${where}` : `its ${where}`;
    cut = `take ${layer.take}, ${layer.length != null ? `${fmt(layer.length)} s ` : ''}from ${from}`;
  } else if (layer.peakIn) {
    const lead = layer.from ?? -0.005;
    const where = `its loudest moment between ${fmt(layer.peakIn[0])} and ${fmt(layer.peakIn[1])} s`;
    cut = `${fmt(layer.length)} s from ${fmt(Math.abs(lead))} s ${lead < 0 ? 'before' : 'after'} ${where}`;
  } else {
    const start = layer.start ?? 0;
    const end = layer.end ?? (layer.length != null ? start + layer.length : null);
    cut = end != null ? `${fmt(start)}–${fmt(end)} s` : `from ${fmt(start)} s`;
  }
  const steps = [cut];
  if (layer.pitch) steps.push(`pitch ${layer.pitch > 0 ? '+' : ''}${layer.pitch} st`);
  if (layer.reverse) steps.push('reversed');
  if (layer.decay) steps.push(`decaying 20 dB per ${fmt(layer.decay)} s`);
  if (layer.highpass) steps.push(`high-pass ${layer.highpass} Hz`);
  if (layer.lowpass) steps.push(`low-pass ${layer.lowpass} Hz`);
  if (layer.width != null) steps.push(`stereo width ${layer.width}`);
  if (layer.gainDb) steps.push(`${layer.gainDb > 0 ? '+' : ''}${layer.gainDb} dB`);
  if (layer.offset) steps.push(`at +${fmt(layer.offset)} s`);
  return `${src.library}: \`${file}\` (${steps.join(', ')})`;
}

function describeProcess(p = {}, file = '') {
  const steps = [];
  steps.push(p.channels === 2 ? 'stereo' : 'mono');
  if (p.highpass) steps.push(`high-pass ${p.highpass} Hz`);
  if (p.lowpass) steps.push(`low-pass ${p.lowpass} Hz`);
  const pool = p.loop ? null : poolFor(file);
  const n = p.normalize ?? { peakDb: -1 };
  if (pool) {
    steps.push(`matched in the ${pool.name} pool: loudest 100 ms at ${pool.loudnessDb} dBFS RMS, peaks at most ${pool.ceilingDb} dBFS`);
  } else {
    steps.push(n.rmsDb != null ? `normalized to ${n.rmsDb} dB RMS` : `normalized to ${n.peakDb} dBFS peak`);
  }
  if (p.loop) steps.push(`seamless ${p.loop.seconds} s loop (${p.loop.crossfade} s crossfade)`);
  else steps.push('silence trimmed at -60 dBFS, faded');
  if (p.maxLength) steps.push(`max ${p.maxLength} s`);
  return steps.join(', ');
}

export async function writeSourcesMd() {
  const picks = JSON.parse(readFileSync(join(SCRIPTS, 'sonniss-picks.json'), 'utf8'));
  const { SOUNDS } = await import('../synth.mjs');
  const { TRACKS } = await import('../music.mjs');

  const lines = [];
  lines.push('# Audio sources');
  lines.push('');
  lines.push('Where every sound in `game/assets/audio/` comes from and how it was made. This file is written by the audio scripts; edit the scripts, not this file.');
  lines.push('');
  lines.push('| Folder | Made by | Command |');
  lines.push('|---|---|---|');
  lines.push('| `sfx/` (all but `gen_*`) | cut and processed from the Sonniss bundle | `npm run audio:sonniss` (`scripts/audio/extract-sonniss.mjs`, picks in `scripts/audio/sonniss-picks.json`) |');
  lines.push('| `sfx/gen_*` | synthesized | `npm run audio:synth` (`scripts/audio/synth.mjs`) |');
  lines.push('| `music/` | generated placeholder music | `npm run audio:music` (`scripts/audio/music.mjs`) |');
  lines.push('');
  lines.push('All files are 16-bit PCM WAV at 44.1 kHz. Effects are mono unless noted; the ambience loop and the music are stereo and carry their loop points in a `smpl` chunk, which Godot reads as the loop.');
  lines.push('');
  lines.push('## Licence');
  lines.push('');
  lines.push(`- **Sonniss GDC 2026 Game Audio Bundle (Part 9).** ${picks.licence}`);
  lines.push('- The raw bundle recordings are never committed (the repository is public): only the trimmed, pitched, filtered, mixed and downsampled files listed below. `audio_src/` is ignored by git for any temporary files.');
  lines.push('- **Generated sounds and music** are made from code in this repository and carry the repository\'s licence.');
  lines.push('');
  lines.push('## Variation pools');
  lines.push('');
  lines.push('The sound bank (`game/audio/sound_bank.gd`) plays one variation of a pool at random each time. So that none jumps out, every file in a pool is matched on short-term loudness (the RMS level of its loudest 100 ms) under a peak ceiling: by gain and, where a variation cannot reach the pool\'s level under the ceiling, a fast peak limiter (`scripts/audio/lib/pools.mjs`; the extractor and the synthesizer log the gain and any limiting).');
  lines.push('');
  lines.push('| Pool | Files | Loudest 100 ms | Peak ceiling |');
  lines.push('|---|---|---|---|');
  const allFiles = [...picks.outputs.map((o) => o.file), ...SOUNDS.map((s) => s.file)];
  for (const [name, pool] of Object.entries(POOLS)) {
    const files = allFiles.filter((f) => pool.files.test(f)).map((f) => `\`${f.replace(/\.wav$/, '')}\``);
    lines.push(`| ${name} | ${files.join(', ')} | ${pool.loudnessDb} dBFS | ${pool.ceilingDb} dBFS |`);
  }
  lines.push('');
  lines.push('## Recorded (Sonniss)');
  lines.push('');
  lines.push('| File | Used for | Sources and processing | Output |');
  lines.push('|---|---|---|---|');
  for (const out of picks.outputs) {
    const layers = out.layers.map((l) => describeLayer(l, picks.sources)).join('<br>');
    lines.push(`| \`sfx/${out.file}\` | ${out.use} | ${layers} | ${describeProcess(out.process, out.file)} |`);
  }
  lines.push('');
  lines.push('## Generated sound effects');
  lines.push('');
  lines.push('Synthesized in `scripts/audio/synth.mjs` from seeded noise, oscillators, modal resonators and filters; the design follows the web demo\'s `v0.1-web-mvp:src/audio/audio.ts`. Every sound is high-passed at 25 Hz (12 dB per octave) so it carries no DC, normalized, matched to its pool (above), trimmed where its tail falls under -60 dBFS and faded.');
  lines.push('');
  lines.push('| File | Used for | How it is made |');
  lines.push('|---|---|---|');
  for (const s of SOUNDS) lines.push(`| \`sfx/${s.file}\` | ${s.use} | ${s.how} |`);
  lines.push('');
  lines.push('## Music (placeholder)');
  lines.push('');
  lines.push('Generated in `scripts/audio/music.mjs`; tempos and lengths are also in `music/tracks.json`. Each track is a seamless stereo loop (the reverb tail of the last bar wraps into the first). The master runs through a 20 Hz high-pass that wraps round the loop, so there is no DC or sub-sonic drift, and the band sways together by up to 3 ms around the grid, so the groove is not machine-exact.');
  lines.push('');
  lines.push('Because the tail of the last bar wraps into the first, every loop starts mid-signal, not at silence: the player must fade a track in and out over 10-20 ms when it starts or stops it, or it clicks.');
  lines.push('');
  lines.push('| File | BPM | Bars | Length | Style |');
  lines.push('|---|---|---|---|---|');
  for (const t of TRACKS) {
    const seconds = (t.bars * 4 * 60) / t.bpm;
    lines.push(`| \`music/${t.file}\` | ${t.bpm} | ${t.bars} | ${seconds.toFixed(2)} s | ${t.description} |`);
  }
  lines.push('');
  mkdirSync(dirname(SOURCES_MD), { recursive: true });
  writeFileSync(SOURCES_MD, lines.join('\n'));
}
