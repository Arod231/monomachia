// "Images of the work": images a session got back from its tools that show
// the game or feature it is building, found in its transcript and served from
// there by reference (no copy is kept). The owner's rule (PM task 16): renders
// it opened from its own worktree's shots/ folder (a Read of a file under
// <its folder>/shots/, its folder being where it was when it made the call),
// and Godot or Blender viewport shots (those MCP servers' tools). Browser-pane
// screenshots, pasted images, images from anywhere else, its subagents' images
// and any result whose call wasn't seen are left out.
// tests/lanes-board-work-images.test.mjs checks the rule.
import path from 'node:path';
import { lineAt, scanned } from './transcript-index.mjs';

// An MCP server named for Blender or Godot (mcp__<server>__<tool>; the server's
// name may hold underscores, as in godot_mcp).
const VIEWPORT = /^mcp__(.*?(blender|godot).*?)__/i;
const norm = (p) => path.posix.normalize(String(p ?? '').replace(/\\/g, '/')).replace(/\/+$/, '').toLowerCase();

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
      if (text.includes('"tool_use"') && (text.includes('"Read"') || [...text.matchAll(/"name":"(mcp__[^"]+)"/g)].some((m) => VIEWPORT.test(m[1])))) {
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
// The images of the work in a transcript, oldest first.
export const workImagesOf = async (file) => (await scanned(file, 'work-images', workImageScanner)).found();

// One image of the work, by its reference (line and n): { type, bytes }, or
// null when the reference isn't one of them.
export async function workImageAt(file, line, n) {
  const f = (await workImagesOf(file)).find((x) => x.line === line && x.n === n);
  if (!f) return null;
  try {
    const image = resultImages(await lineAt(file, f.offset))[n]?.image;
    return image ? { type: f.type, bytes: Buffer.from(image.source.data, 'base64') } : null;
  } catch { return null; }
}
