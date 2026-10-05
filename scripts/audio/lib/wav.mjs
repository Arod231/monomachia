// WAV reading and writing.
//
// readWav understands RIFF and RF64 files with 8/16/24/32-bit integer or
// 32/64-bit float samples, any channel count and WAVE_FORMAT_EXTENSIBLE
// headers. It also accepts a file cut short (the start of a long recording
// read with a byte limit): the data chunk is clamped to the bytes present.
//
// writeWav writes 16-bit PCM with triangular dither from a seeded generator
// (so the output is byte-for-byte repeatable) and can embed a loop in a
// 'smpl' chunk, which Godot's WAV importer picks up as the loop points.

import { mulberry32 } from './rng.mjs';

const FORMAT_PCM = 1;
const FORMAT_FLOAT = 3;
const FORMAT_EXTENSIBLE = 0xfffe;

/**
 * @typedef {{sampleRate: number, channels: Float32Array[]}} Audio
 * Planar float audio: one Float32Array per channel, samples in [-1, 1].
 */

/**
 * Reads the format and the position of the data chunk without decoding.
 * @param {Buffer} buf
 */
export function readWavInfo(buf) {
  const riff = buf.toString('ascii', 0, 4);
  if ((riff !== 'RIFF' && riff !== 'RF64') || buf.toString('ascii', 8, 12) !== 'WAVE') {
    throw new Error(`not a WAV file (${riff})`);
  }
  let p = 12;
  let fmt = null;
  let dataOffset = -1;
  let dataSize = 0;
  let ds64DataSize = null;
  while (p + 8 <= buf.length) {
    const id = buf.toString('ascii', p, p + 4);
    const size = buf.readUInt32LE(p + 4);
    const body = p + 8;
    if (id === 'ds64' && body + 16 <= buf.length) ds64DataSize = Number(buf.readBigUInt64LE(body + 8));
    if (id === 'fmt ') {
      let tag = buf.readUInt16LE(body);
      const channels = buf.readUInt16LE(body + 2);
      const sampleRate = buf.readUInt32LE(body + 4);
      const blockAlign = buf.readUInt16LE(body + 12);
      const bits = buf.readUInt16LE(body + 14);
      if (tag === FORMAT_EXTENSIBLE && size >= 40) tag = buf.readUInt16LE(body + 24);
      fmt = { tag, channels, sampleRate, blockAlign, bits };
    }
    if (id === 'data') {
      dataOffset = body;
      dataSize = size === 0xffffffff && ds64DataSize != null ? ds64DataSize : size;
      break;
    }
    p = body + size + (size & 1);
  }
  if (!fmt) throw new Error('WAV has no fmt chunk');
  if (dataOffset < 0) throw new Error('WAV has no data chunk');
  const available = Math.min(dataSize, buf.length - dataOffset);
  const frames = Math.floor(available / fmt.blockAlign);
  return { ...fmt, dataOffset, frames, declaredFrames: Math.floor(dataSize / fmt.blockAlign) };
}

/**
 * Decodes a WAV file to planar float audio.
 * @param {Buffer} buf
 * @returns {Audio & {bits: number, format: 'int'|'float', truncated: boolean}}
 */
export function readWav(buf) {
  const info = readWavInfo(buf);
  const { tag, channels: nch, sampleRate, blockAlign, bits, dataOffset, frames } = info;
  const bytes = bits / 8;
  const float = tag === FORMAT_FLOAT;
  if (!float && tag !== FORMAT_PCM) throw new Error(`unsupported WAV format tag ${tag}`);
  if (float && bits !== 32 && bits !== 64) throw new Error(`unsupported float width ${bits}`);
  if (!float && ![8, 16, 24, 32].includes(bits)) throw new Error(`unsupported PCM width ${bits}`);
  const channels = Array.from({ length: nch }, () => new Float32Array(frames));
  for (let c = 0; c < nch; c++) {
    const out = channels[c];
    let p = dataOffset + c * bytes;
    for (let i = 0; i < frames; i++, p += blockAlign) {
      let v;
      if (float) v = bits === 32 ? buf.readFloatLE(p) : buf.readDoubleLE(p);
      else if (bits === 16) v = buf.readInt16LE(p) / 32768;
      else if (bits === 24) v = buf.readIntLE(p, 3) / 8388608;
      else if (bits === 32) v = buf.readInt32LE(p) / 2147483648;
      else v = (buf[p] - 128) / 128;
      out[i] = v;
    }
  }
  return {
    sampleRate,
    channels,
    bits,
    format: float ? 'float' : 'int',
    truncated: frames < info.declaredFrames,
  };
}

/**
 * Encodes planar float audio as a 16-bit PCM WAV.
 * @param {Audio} audio
 * @param {{loop?: {start: number, end: number}, dither?: boolean, seed?: number}} [opts]
 *   loop: loop points in frames (end exclusive), written as a 'smpl' chunk.
 * @returns {Buffer}
 */
export function writeWav(audio, { loop, dither = true, seed = 0x5eed } = {}) {
  const nch = audio.channels.length;
  if (nch < 1) throw new Error('writeWav: no channels');
  const frames = audio.channels[0].length;
  const blockAlign = nch * 2;
  const dataSize = frames * blockAlign;
  const smplSize = loop ? 36 + 24 : 0;
  const total = 12 + (8 + 16) + (loop ? 8 + smplSize : 0) + 8 + dataSize + (dataSize & 1);
  const buf = Buffer.alloc(total);
  let p = 0;
  buf.write('RIFF', p, 'ascii');
  buf.writeUInt32LE(total - 8, p + 4);
  buf.write('WAVE', p + 8, 'ascii');
  p = 12;
  buf.write('fmt ', p, 'ascii');
  buf.writeUInt32LE(16, p + 4);
  buf.writeUInt16LE(FORMAT_PCM, p + 8);
  buf.writeUInt16LE(nch, p + 10);
  buf.writeUInt32LE(audio.sampleRate, p + 12);
  buf.writeUInt32LE(audio.sampleRate * blockAlign, p + 16);
  buf.writeUInt16LE(blockAlign, p + 20);
  buf.writeUInt16LE(16, p + 22);
  p += 24;
  if (loop) {
    buf.write('smpl', p, 'ascii');
    buf.writeUInt32LE(smplSize, p + 4);
    const b = p + 8;
    buf.writeUInt32LE(0, b); // manufacturer
    buf.writeUInt32LE(0, b + 4); // product
    buf.writeUInt32LE(Math.round(1e9 / audio.sampleRate), b + 8); // sample period (ns)
    buf.writeUInt32LE(60, b + 12); // MIDI unity note
    buf.writeUInt32LE(0, b + 16); // pitch fraction
    buf.writeUInt32LE(0, b + 20); // SMPTE format
    buf.writeUInt32LE(0, b + 24); // SMPTE offset
    buf.writeUInt32LE(1, b + 28); // one loop
    buf.writeUInt32LE(0, b + 32); // no sampler data
    buf.writeUInt32LE(0, b + 36); // cue id
    buf.writeUInt32LE(0, b + 40); // forward loop
    buf.writeUInt32LE(loop.start, b + 44);
    buf.writeUInt32LE(loop.end, b + 48); // Godot reads this as the loop end frame
    buf.writeUInt32LE(0, b + 52); // fraction
    buf.writeUInt32LE(0, b + 56); // play count: infinite
    p += 8 + smplSize;
  }
  buf.write('data', p, 'ascii');
  buf.writeUInt32LE(dataSize, p + 4);
  p += 8;
  const rand = mulberry32(seed);
  for (let i = 0; i < frames; i++) {
    for (let c = 0; c < nch; c++) {
      let v = audio.channels[c][i] * 32767;
      if (dither) v += rand() - rand(); // triangular dither, +/- 1 LSB
      let s = Math.round(v);
      if (s > 32767) s = 32767;
      else if (s < -32768) s = -32768;
      buf.writeInt16LE(s, p);
      p += 2;
    }
  }
  return buf;
}
