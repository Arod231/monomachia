// A minimal read-only ZIP reader: finds the central directory at the end of
// the archive and reads single entries by random access, so a chosen file can
// be taken out of a multi-gigabyte zip without extracting the rest.
// Supports stored and deflated entries and the ZIP64 extensions.

import { closeSync, createReadStream, fstatSync, openSync, readSync } from 'node:fs';
import zlib from 'node:zlib';

const SIG_EOCD = 0x06054b50;
const SIG_ZIP64_LOCATOR = 0x07064b50;
const SIG_ZIP64_EOCD = 0x06064b50;
const SIG_CENTRAL = 0x02014b50;
const SIG_LOCAL = 0x04034b50;

function readAt(fd, length, position) {
  const buf = Buffer.alloc(length);
  let done = 0;
  while (done < length) {
    const n = readSync(fd, buf, done, length - done, position + done);
    if (n === 0) break;
    done += n;
  }
  return done === length ? buf : buf.subarray(0, done);
}

function findEndOfCentralDirectory(fd, size) {
  // The end record is 22 bytes plus a comment of up to 65535 bytes.
  const len = Math.min(size, 22 + 65535 + 20);
  const base = size - len;
  const buf = readAt(fd, len, base);
  for (let i = len - 22; i >= 0; i--) {
    if (buf.readUInt32LE(i) === SIG_EOCD) return { buf, i, base };
  }
  throw new Error('not a zip file (no end of central directory record)');
}

/**
 * Opens a zip file and reads its central directory.
 * @param {string} path
 */
export function openZip(path) {
  const fd = openSync(path, 'r');
  try {
    const size = fstatSync(fd).size;
    const { buf, i } = findEndOfCentralDirectory(fd, size);
    let count = buf.readUInt16LE(i + 10);
    let cdSize = buf.readUInt32LE(i + 12);
    let cdOffset = buf.readUInt32LE(i + 16);
    if (count === 0xffff || cdSize === 0xffffffff || cdOffset === 0xffffffff) {
      const loc = i - 20;
      if (loc < 0 || buf.readUInt32LE(loc) !== SIG_ZIP64_LOCATOR) throw new Error('ZIP64 locator missing');
      const z64Offset = Number(buf.readBigUInt64LE(loc + 8));
      const z = readAt(fd, 56, z64Offset);
      if (z.readUInt32LE(0) !== SIG_ZIP64_EOCD) throw new Error('ZIP64 end record missing');
      count = Number(z.readBigUInt64LE(32));
      cdSize = Number(z.readBigUInt64LE(40));
      cdOffset = Number(z.readBigUInt64LE(48));
    }
    const cd = readAt(fd, cdSize, cdOffset);
    /** @type {Map<string, {name:string, method:number, crc:number, compressedSize:number, size:number, localOffset:number}>} */
    const entries = new Map();
    let p = 0;
    for (let n = 0; n < count && p + 46 <= cd.length; n++) {
      if (cd.readUInt32LE(p) !== SIG_CENTRAL) throw new Error(`bad central directory entry at ${p}`);
      const flags = cd.readUInt16LE(p + 8);
      const method = cd.readUInt16LE(p + 10);
      const crc = cd.readUInt32LE(p + 16);
      let compressedSize = cd.readUInt32LE(p + 20);
      let usize = cd.readUInt32LE(p + 24);
      const nameLen = cd.readUInt16LE(p + 28);
      const extraLen = cd.readUInt16LE(p + 30);
      const commentLen = cd.readUInt16LE(p + 32);
      let localOffset = cd.readUInt32LE(p + 42);
      const nameBuf = cd.subarray(p + 46, p + 46 + nameLen);
      // Bit 11 marks UTF-8 names; older tools write CP437, which matches ASCII.
      const name = nameBuf.toString(flags & 0x800 ? 'utf8' : 'latin1');
      const extra = cd.subarray(p + 46 + nameLen, p + 46 + nameLen + extraLen);
      let q = 0;
      while (q + 4 <= extra.length) {
        const id = extra.readUInt16LE(q);
        const sz = extra.readUInt16LE(q + 2);
        if (id === 0x0001) {
          let r = q + 4;
          if (usize === 0xffffffff) (usize = Number(extra.readBigUInt64LE(r))), (r += 8);
          if (compressedSize === 0xffffffff) (compressedSize = Number(extra.readBigUInt64LE(r))), (r += 8);
          if (localOffset === 0xffffffff) (localOffset = Number(extra.readBigUInt64LE(r))), (r += 8);
        }
        q += 4 + sz;
      }
      entries.set(name, { name, method, crc, compressedSize, size: usize, localOffset });
      p += 46 + nameLen + extraLen + commentLen;
    }
    return new ZipFile(path, fd, entries);
  } catch (err) {
    closeSync(fd);
    throw err;
  }
}

class ZipFile {
  constructor(path, fd, entries) {
    this.path = path;
    this.fd = fd;
    this.entries = entries;
  }

  /** Names of every entry, in central directory order. */
  names() {
    return [...this.entries.keys()];
  }

  /** @param {string} name */
  has(name) {
    return this.entries.has(name);
  }

  dataOffset(entry) {
    const lh = readAt(this.fd, 30, entry.localOffset);
    if (lh.readUInt32LE(0) !== SIG_LOCAL) throw new Error(`bad local header for ${entry.name}`);
    return entry.localOffset + 30 + lh.readUInt16LE(26) + lh.readUInt16LE(28);
  }

  /**
   * Reads one entry, inflating it on the fly. With maxBytes, stops after that
   * many uncompressed bytes (enough for the start of a long recording).
   * A full read is checked against the entry's CRC-32.
   * @param {string} name
   * @param {{maxBytes?: number}} [opts]
   * @returns {Promise<Buffer>}
   */
  read(name, { maxBytes = Infinity } = {}) {
    const entry = this.entries.get(name);
    if (!entry) return Promise.reject(new Error(`no entry "${name}" in ${this.path}`));
    const start = this.dataOffset(entry);
    const want = Math.min(entry.size, maxBytes);
    if (entry.method === 0) {
      const buf = readAt(this.fd, want, start);
      return Promise.resolve(this.#checked(entry, buf, want));
    }
    if (entry.method !== 8) return Promise.reject(new Error(`unsupported compression method ${entry.method} for ${name}`));
    if (entry.compressedSize === 0) return Promise.resolve(Buffer.alloc(0));
    return new Promise((resolveRead, rejectRead) => {
      const src = createReadStream(this.path, {
        start,
        end: start + entry.compressedSize - 1,
        highWaterMark: 1 << 20,
      });
      const inflate = zlib.createInflateRaw({ chunkSize: 1 << 20 });
      const chunks = [];
      let total = 0;
      let settled = false;
      const finish = (err, buf) => {
        if (settled) return;
        settled = true;
        src.destroy();
        inflate.destroy();
        if (err) rejectRead(err);
        else {
          try {
            resolveRead(this.#checked(entry, buf, want));
          } catch (e) {
            rejectRead(e);
          }
        }
      };
      inflate.on('data', (chunk) => {
        chunks.push(chunk);
        total += chunk.length;
        if (total >= want) finish(null, Buffer.concat(chunks, total).subarray(0, want));
      });
      inflate.on('end', () => finish(null, Buffer.concat(chunks, total)));
      inflate.on('error', (e) => finish(e));
      src.on('error', (e) => finish(e));
      src.pipe(inflate);
    });
  }

  #checked(entry, buf, want) {
    if (buf.length < want) throw new Error(`${entry.name}: read ${buf.length} of ${want} bytes`);
    if (want === entry.size && typeof zlib.crc32 === 'function') {
      const crc = zlib.crc32(buf) >>> 0;
      if (crc !== entry.crc >>> 0) throw new Error(`${entry.name}: CRC mismatch`);
    }
    return buf;
  }

  close() {
    closeSync(this.fd);
  }
}
