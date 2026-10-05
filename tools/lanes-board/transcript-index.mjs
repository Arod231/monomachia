// A whole transcript read once and then only what's appended: a scanner
// ({ feed(text, line, offset), ... }) is fed every complete line in order, its
// number from 0 and its byte offset, and kept per file and kind. Images of the
// work (work-images.mjs) and what a session wrote and published (docs.mjs)
// both need the whole transcript, which the board's tail read doesn't give.
import { open, stat } from 'node:fs/promises';

const CHUNK = 8 << 20;
const indexes = new Map(); // `${kind}\n${file}` -> { offset, line, scanner, busy }

async function catchUp(file, ix, make) {
  const { size } = await stat(file);
  if (size < ix.offset) Object.assign(ix, { offset: 0, line: 0, scanner: make() }); // started again
  if (size === ix.offset) return;
  const fh = await open(file, 'r');
  try {
    let rest = Buffer.alloc(0);
    let at = ix.offset;
    while (at < size) {
      const buf = Buffer.alloc(Math.min(CHUNK, size - at));
      const { bytesRead } = await fh.read(buf, 0, buf.length, at);
      if (!bytesRead) break;
      at += bytesRead;
      const data = Buffer.concat([rest, buf.subarray(0, bytesRead)]); // starts at ix.offset
      let start = 0;
      for (let nl = data.indexOf(10); nl >= 0; start = nl + 1, nl = data.indexOf(10, start)) {
        ix.scanner.feed(data.toString('utf8', start, nl), ix.line++, ix.offset);
        ix.offset += nl + 1 - start;
      }
      rest = data.subarray(start); // a half-written last line waits for the next look
    }
  } finally { await fh.close(); }
}

// The scanner of file for kind (make() starts one), caught up to the file's end.
export function scanned(file, kind, make) {
  const key = `${kind}\n${file}`;
  let ix = indexes.get(key);
  if (!ix) { ix = { offset: 0, line: 0, scanner: make(), busy: Promise.resolve() }; indexes.set(key, ix); }
  const run = ix.busy.then(() => catchUp(file, ix, make)).then(() => ix.scanner);
  ix.busy = run.catch(() => {});
  return run;
}

// The one line that starts at offset, parsed.
export async function lineAt(file, offset) {
  const fh = await open(file, 'r');
  try {
    const parts = [];
    for (let at = offset; ;) {
      const buf = Buffer.alloc(1 << 20);
      const { bytesRead } = await fh.read(buf, 0, buf.length, at);
      if (!bytesRead) break;
      const nl = buf.subarray(0, bytesRead).indexOf(10);
      parts.push(buf.subarray(0, nl < 0 ? bytesRead : nl));
      if (nl >= 0) break;
      at += bytesRead;
    }
    return JSON.parse(Buffer.concat(parts).toString('utf8'));
  } finally { await fh.close(); }
}
