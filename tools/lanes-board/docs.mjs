// What a session wrote and published, for its page's Docs (docs-api.mjs):
// the Markdown files, HTML pages and PDFs its Write and Edit calls name (the
// owner's choice, PM task 17), the claude.ai artifacts it published, its
// branch, and the rule for which of those files may be served: only a file
// the transcript names, inside the repo or one of its worktrees.
// tests/lanes-board-docs.test.mjs checks them.
import path from 'node:path';

const KINDS = { '.md': 'md', '.markdown': 'md', '.html': 'html', '.htm': 'html', '.pdf': 'pdf' };
export const docKind = (file) => KINDS[path.extname(String(file ?? '')).toLowerCase()] ?? null;

const WRITES = new Set(['Write', 'Edit', 'MultiEdit']);
const ARTIFACT_URL = /https:\/\/claude\.ai\/(?:code\/)?artifact\/[A-Za-z0-9-]+/;
// A path with forward slashes and no . or .. steps, for comparing (with lower case).
export const cleanPath = (p) => path.posix.normalize(String(p ?? '').replace(/\\/g, '/')).replace(/\/+$/, '');
const key = (p) => cleanPath(p).toLowerCase();
const textOf = (c) => (typeof c === 'string' ? c : Array.isArray(c) ? c.map((x) => (x?.type === 'text' ? x.text : '')).join('\n') : '');

// Fed a transcript's lines in order (transcript-index.mjs), it keeps docs()
// ({ path, kind, time, cwd }, newest first), artifacts() ({ url, title, time },
// newest first) and branch(). A call counts once its result says it worked.
export function docScanner() {
  const calls = new Map(); // tool_use id -> { doc } or { artifact }
  const docs = new Map(); // key(path) -> { path, kind, time, cwd }
  const artifacts = new Map(); // url -> { url, title, time }
  let branch = null;
  return {
    feed(text) {
      const b = /"gitBranch":"([^"]+)"/.exec(text)?.[1];
      if (b && b !== 'HEAD') branch = b;
      if (text.includes('"tool_use"') && /"name":"(Write|Edit|MultiEdit|Artifact)"/.test(text)) {
        let o;
        try { o = JSON.parse(text); } catch { return; }
        for (const c of Array.isArray(o?.message?.content) ? o.message.content : []) {
          if (c?.type !== 'tool_use') continue;
          const input = c.input ?? {};
          if (WRITES.has(c.name) && docKind(input.file_path)) calls.set(c.id, { doc: { path: String(input.file_path), cwd: o.cwd ?? null } });
          if (c.name === 'Artifact' && (input.action ?? 'publish') === 'publish' && !input.asset) {
            const title = input.title || (input.file_path ? path.basename(String(input.file_path).replace(/\\/g, '/')) : 'Artifact');
            calls.set(c.id, { artifact: { title } });
          }
        }
        return;
      }
      if (!calls.size || !text.includes('"tool_result"')) return;
      const ids = [...text.matchAll(/"tool_use_id":"([^"]+)"/g)].map((m) => m[1]).filter((id) => calls.has(id));
      if (!ids.length) return;
      let o;
      try { o = JSON.parse(text); } catch { return; }
      const time = Date.parse(o.timestamp) || 0;
      for (const r of Array.isArray(o?.message?.content) ? o.message.content : []) {
        const call = r?.type === 'tool_result' && calls.get(r.tool_use_id);
        if (!call) continue;
        calls.delete(r.tool_use_id);
        if (r.is_error) continue;
        if (call.doc) {
          const k = key(call.doc.path);
          docs.delete(k);
          docs.set(k, { path: call.doc.path, kind: docKind(call.doc.path), time, cwd: call.doc.cwd });
        } else {
          const url = ARTIFACT_URL.exec(textOf(r.content))?.[0];
          if (!url) continue;
          artifacts.delete(url);
          artifacts.set(url, { url, title: call.artifact.title, time });
        }
      }
    },
    docs: () => [...docs.values()].reverse(),
    artifacts: () => [...artifacts.values()].reverse(),
    branch: () => branch,
    named: () => new Set(docs.keys()),
  };
}

const inside = (p, root) => p === root || p.startsWith(`${root}/`);

// Where a named document lives: { root, rel, live }, or null when it may not be
// served. named: the keys of the paths the transcript names (docScanner's
// named(), or any paths); roots: the main checkout, then each live worktree;
// cwd: the folder the session wrote it from. A file in a live root is read
// from there (live), relative to the deepest root. One in a worktree since
// removed (the session's folder, under the main checkout's .claude/worktrees/
// but no live worktree) is read from git by its place in that folder.
export function docPlace(file, { named, roots, cwd }) {
  const want = key(file);
  if (![...named].some((n) => key(n) === want)) return null;
  const p = cleanPath(file);
  const lower = p.toLowerCase();
  const live = roots.map(cleanPath).filter((r) => inside(lower, r.toLowerCase())).sort((a, b) => b.length - a.length);
  if (!live.length) return null;
  const main = cleanPath(roots[0]).toLowerCase();
  const c = cwd ? cleanPath(cwd) : null;
  // A removed worktree sat where the app and lanes make them, in .claude/worktrees/.
  const gone = c && live[0].toLowerCase() === main && inside(c.toLowerCase(), `${main}/.claude/worktrees`) && inside(lower, c.toLowerCase())
    && !roots.slice(1).some((r) => inside(c.toLowerCase(), cleanPath(r).toLowerCase()));
  const root = gone ? c : live[0];
  return { root, rel: p.slice(root.length + 1), live: !gone };
}
