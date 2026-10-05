// Finds the Sonniss GDC 2026 bundle zips and reads single recordings out of
// them as audio, without extracting anything to disk.
//
// The zips are looked for in SONNISS_DIR if set, else in ~/Downloads.

import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { openZip } from './zip.mjs';
import { readWav, readWavInfo } from './wav.mjs';

export const PART_COUNT = 5;

export function sonnissDir() {
  return process.env.SONNISS_DIR || join(homedir(), 'Downloads');
}

export function partPath(part) {
  return join(sonnissDir(), `Sonniss.com-GDC2026-GameAudioBundle${part}of${PART_COUNT}.zip`);
}

/** Opens the bundle parts that exist; reports the ones that don't. */
export function openBundle() {
  const zips = new Map();
  const missing = [];
  for (let part = 1; part <= PART_COUNT; part++) {
    const p = partPath(part);
    if (existsSync(p)) zips.set(part, openZip(p));
    else missing.push({ part, path: p });
  }
  return {
    zips,
    missing,
    has: (part) => zips.has(part),
    close: () => {
      for (const z of zips.values()) z.close();
    },
  };
}

/**
 * Reads one recording, optionally only up to `until` seconds (the rest of the
 * entry is never inflated).
 * @param {import('./zip.mjs').ZipFile} zip
 * @param {string} entry path inside the zip
 * @param {{until?: number}} [opts]
 */
export async function readRecording(zip, entry, { until } = {}) {
  let maxBytes = Infinity;
  if (until != null && Number.isFinite(until)) {
    const head = await zip.read(entry, { maxBytes: 1 << 20 });
    const info = readWavInfo(head);
    maxBytes = info.dataOffset + Math.ceil(until * info.sampleRate) * info.blockAlign;
  }
  const buf = await zip.read(entry, { maxBytes });
  return readWav(buf);
}
