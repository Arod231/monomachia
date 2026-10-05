// "Images of the work": images a session got back from its tools that show
// the game or feature it is building, found in its transcript and served from
// there by reference (no copy is kept). The owner's rule (PM task 16): renders
// it opened from its own worktree's shots/ folder (a Read of a file under
// <its folder>/shots/, its folder being where it was when it made the call),
// and Godot or Blender viewport shots (those MCP servers' tools). Browser-pane
// screenshots, pasted images, images from anywhere else, its subagents' images
// and any result whose call wasn't seen are left out.
// tests/lanes-board-work-images.test.mjs checks the rule.
import { open, stat } from 'node:fs/promises';

const VIEWPORT = /^mcp__([^_]*?(blender|godot)[^_]*)__/i;
const norm = (p) => String(p ?? '').replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();

// What a call's images show, or null when they don't count.
function sourceOf(call) {
  const m = VIEWPORT.exec(call.name);
  if (m) return `${/blender/i.test(m[1]) ? 'Blender' : 'Godot'} viewport`;
  if (call.name !== 'Read' || !call.cwd) return null;
  const file = norm(call.input?.file_path);
  return file.startsWith(`${norm(call.cwd)}/shots/`) ? String(call.input.file_path) : null;
}

// The images of a transcript line's tool results, in order: [{ tool, image }].
function resultImages(o) {
  const out = [];
  const content = o?.message?.content;
  if (o?.type !== 'user' || !Array.isArray(content)) return out;
  for (const c of content) {
    if (c?.type !== 'tool_result' || !Array.isArray(c.content)) continue;
    for (const x of c.content) if (x?.type === 'image' && x.source?.type === 'base64') out.push({ tool: c.tool_use_id, image: x });
  }
  return out;
}

// Fed a transcript's lines in order (text, its number from 0, its byte
// offset), it finds the images of the work: { line, n (which of the line's
// tool-result images), offset, tool, source, type, time }.
export function workImageScanner() {
  const calls = new Map(); // tool_use id -> { name, input, cwd }, for the calls that can count
  const found = [];
  return {
    feed(text, line, offset) {
      if (text.includes('"tool_use"') && (text.includes('"Read"') || VIEWPORT.test(text.match(/"name":"(mcp__[^"]+)"/)?.[1] ?? ''))) {
        let o;
        try { o = JSON.parse(text); } catch { return; }
        for (const c of Array.isArray(o?.message?.content) ? o.message.content : []) {
          if (c?.type === 'tool_use' && (c.name === 'Read' || VIEWPORT.test(c.name))) calls.set(c.id, { name: c.name, input: c.input, cwd: o.cwd ?? null });
        }
        return;
      }
      if (!text.includes('"tool_result"') || !text.includes('"image"')) return;
      let o;
      try { o = JSON.parse(text); } catch { return; }
      resultImages(o).forEach(({ tool, image }, n) => {
        const call = calls.get(tool);
        const source = call && sourceOf(call);
        if (source) found.push({ line, n, offset, tool: call.name, source, type: image.source.media_type ?? 'image/png', time: Date.parse(o.timestamp) || 0 });
      });
    },
    found: () => found,
  };
}

// ---------- a transcript's images, kept up to date as it grows ----------
const CHUNK = 8 << 20;
const indexes = new Map(); // file -> { offset, line, scanner, busy }

async function catchUp(file, ix) {
  const { size } = await stat(file);
  if (size < ix.offset) { Object.assign(ix, { offset: 0, line: 0, scanner: workImageScanner() }); } // started again
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
      let data = Buffer.concat([rest, buf.subarray(0, bytesRead)]);
      let start = 0;
      for (let nl = data.indexOf(10); nl >= 0; start = nl + 1, nl = data.indexOf(10, start)) {
        ix.scanner.feed(data.toString('utf8', start, nl), ix.line++, ix.offset);
        ix.offset += nl + 1 - start;
      }
      rest = data.subarray(start); // a half-written last line waits for the next look
      data = null;
    }
  } finally { await fh.close(); }
}

// The images of the work in a transcript, oldest first.
export function workImagesOf(file) {
  let ix = indexes.get(file);
  if (!ix) { ix = { offset: 0, line: 0, scanner: workImageScanner(), busy: Promise.resolve() }; indexes.set(file, ix); }
  const run = ix.busy.then(() => catchUp(file, ix)).then(() => ix.scanner.found());
  ix.busy = run.catch(() => {});
  return run;
}

// One image of the work, by its reference (line and n): { type, bytes }, or
// null when the reference isn't one of them.
export async function workImageAt(file, line, n) {
  const f = (await workImagesOf(file)).find((x) => x.line === line && x.n === n);
  if (!f) return null;
  const fh = await open(file, 'r');
  try {
    const parts = [];
    for (let at = f.offset; ;) {
      const buf = Buffer.alloc(1 << 20);
      const { bytesRead } = await fh.read(buf, 0, buf.length, at);
      if (!bytesRead) break;
      const nl = buf.subarray(0, bytesRead).indexOf(10);
      parts.push(buf.subarray(0, nl < 0 ? bytesRead : nl));
      if (nl >= 0) break;
      at += bytesRead;
    }
    const image = resultImages(JSON.parse(Buffer.concat(parts).toString('utf8')))[n]?.image;
    return image ? { type: f.type, bytes: Buffer.from(image.source.data, 'base64') } : null;
  } catch { return null; } finally { await fh.close(); }
}
