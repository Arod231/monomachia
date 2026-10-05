# The board's second brain button (patch)

The all-lanes board (http://localhost:5197) is local tooling in another worktree, `.claude/worktrees/remaining-tasks-visualization-5452d7/.claude/all-lanes/`, and it isn't tracked, so this branch can't change it directly. This is the change for that board's own session to apply (task SB.7 in `docs/plans/second-brain.md`). It was tested on a copy of the board at port 5195.

What it does:

- A **Second brain** button beside the title opens `/brain/` in a popup window named `second-brain` (1200 × 820). A second click brings the same window back. If the browser blocks popups, the board's own tab goes to `/brain/` instead.
- The server answers `/brain` (redirect) and `/brain/*`. It copies `tools/second-brain/` out of git into `.brain-cache/<commit>/` (inside the already-excluded `all-lanes` folder), imports `serve.mjs`, and serves the viewer and `notes.json` from it.
- The tool and the hand-written notes come from the newest of `origin/feature/godot-rebuild`, `feature/godot-rebuild`, `origin/tools/second-brain` and `tools/second-brain` that has `brain/Home.md`. The plans, docs and code come from the newest rebuild-branch tip, plus any doc the tool's branch adds, so plan ticks are live even before this branch merges. Nothing reads a working tree, and nothing fetches.
- The board needs a restart for the server change (the page change shows on reload).

When the board becomes tracked (`tools/session-tracker`, PR #7), its `/brain/` routes can import `tools/second-brain/serve.mjs` directly instead of copying it out of git.

## server.mjs

```diff
@@ -7,6 +7,6 @@ import { createServer } from 'node:http';
 import { execFile } from 'node:child_process';
 import { promisify } from 'node:util';
-import { readFile, readdir, stat, access, writeFile, open } from 'node:fs/promises';
-import { fileURLToPath } from 'node:url';
+import { readFile, readdir, stat, access, writeFile, open, mkdir } from 'node:fs/promises';
+import { fileURLToPath, pathToFileURL } from 'node:url';
 import os from 'node:os';
 import path from 'node:path';
@@ -655,4 +655,73 @@ async function endLaunch(body) {
 }
 
+// ---------- the second brain ----------
+// The board's "Second brain" button opens /brain/: the vault and viewer from
+// tools/second-brain (docs/specs/second-brain.md). All of it comes from git,
+// never a working tree: the tool and the hand-written notes (brain/) from the
+// newest branch that has them, and the plans, docs and code they're built over
+// from the newest rebuild-branch tip, so plan ticks show before the tool merges.
+const BRAIN_TOOL_REFS = ['origin/feature/godot-rebuild', 'feature/godot-rebuild', 'origin/tools/second-brain', 'tools/second-brain'];
+const BRAIN_CONTENT_REFS = ['origin/feature/godot-rebuild', 'feature/godot-rebuild'];
+const BRAIN_FILES = ['vault.mjs', 'sources.mjs', 'serve.mjs', 'viewer.html', 'vendor/marked.umd.js'];
+const brainTools = new Map(); // tool commit -> { handle, sources, set }
+
+async function newestRef(refs, needs) {
+  let best = null;
+  for (const ref of refs) {
+    const line = (await tryGit(REPO, 'log', '-1', '--format=%H %ct', ref, '--'))?.trim();
+    if (!line) continue;
+    const [commit, t] = line.split(' ');
+    if (needs && (await tryGit(REPO, 'cat-file', '-e', `${commit}:${needs}`)) === null) continue;
+    if (!best || Number(t) > best.t) best = { ref, commit, t: Number(t) };
+  }
+  return best;
+}
+
+// The tool's files at a commit, copied out of git once into .brain-cache/<commit>/ and imported from there.
+async function brainTool(commit) {
+  if (brainTools.has(commit)) return brainTools.get(commit);
+  const dir = path.join(HERE, '.brain-cache', commit.slice(0, 12));
+  for (const f of BRAIN_FILES) {
+    const out = path.join(dir, f);
+    try { await access(out); continue; } catch {}
+    const { stdout } = await run('git', ['--no-optional-locks', 'show', `${commit}:tools/second-brain/${f}`], { cwd: REPO, maxBuffer: 64 << 20, windowsHide: true, encoding: 'buffer' });
+    await mkdir(path.dirname(out), { recursive: true });
+    await writeFile(out, stdout);
+  }
+  const { brainHandler } = await import(pathToFileURL(path.join(dir, 'serve.mjs')).href);
+  const sources = await import(pathToFileURL(path.join(dir, 'sources.mjs')).href);
+  let current = null; // { key, source, label }, set before each notes.json
+  const tool = { sources, handle: brainHandler({ getSource: () => current, viewerDir: dir }), set: (c) => { current = c; } };
+  brainTools.set(commit, tool);
+  return tool;
+}
+
+// Files under brain/ (and docs the content commit doesn't have yet, such as the
+// vault's own spec) from the tool's commit; everything else from the content commit.
+function overlaySource(content, notes) {
+  const base = new Set(content.list());
+  const own = new Set(notes.list().filter((p) => p.startsWith('brain/') || (p.startsWith('docs/') && !base.has(p))));
+  return {
+    list: () => [...content.list().filter((p) => !p.startsWith('brain/')), ...own],
+    read: (p) => (own.has(p) ? notes.read(p) : content.read(p)),
+    subjects: () => content.subjects(),
+  };
+}
+
+async function serveBrain(req, res, sub) {
+  const toolRef = await newestRef(BRAIN_TOOL_REFS, 'brain/Home.md');
+  if (!toolRef) { res.writeHead(404, { 'content-type': 'text/plain' }); res.end('No branch has the second brain yet (tools/second-brain).'); return; }
+  const tool = await brainTool(toolRef.commit);
+  if (sub.split('?')[0] === 'notes.json') {
+    const contentRef = (await newestRef(BRAIN_CONTENT_REFS)) ?? toolRef;
+    const { gitSource } = tool.sources;
+    const notes = gitSource(REPO, toolRef.commit);
+    const source = contentRef.commit === toolRef.commit ? notes : overlaySource(gitSource(REPO, contentRef.commit), notes);
+    const label = contentRef.commit === toolRef.commit ? toolRef.ref : `${contentRef.ref} + notes from ${toolRef.ref}`;
+    tool.set({ key: `${toolRef.commit.slice(0, 7)}+${contentRef.commit.slice(0, 7)}`, source, label });
+  }
+  await tool.handle(req, res, sub);
+}
+
 // Only this page may launch: the request must come from the board's own origin.
 function sameOrigin(req) {
@@ -684,4 +753,6 @@ createServer(async (req, res) => {
       return;
     }
+    if (req.url === '/brain') { res.writeHead(302, { location: '/brain/' }); res.end(); return; }
+    if (req.url.startsWith('/brain/')) { await serveBrain(req, res, req.url.slice('/brain/'.length)); return; }
     if (req.url.startsWith('/data')) {
       const body = JSON.stringify(await data());
```

## index.html

```diff
@@ -136,4 +136,5 @@ body.has-queue.queue-collapsed main { padding-bottom: 72px; }
   <header>
     <h1>Monomachia progress</h1>
+    <button class="btn small" id="brainBtn" title="The project's knowledge as linked notes: weapons, systems, plans, docs and code (opens in a popup window)">Second brain</button>
     <span class="stamp" id="stamp"><span class="live"></span><span id="stampText">Loading…</span></span>
   </header>
@@ -160,4 +161,14 @@ body.has-queue.queue-collapsed main { padding-bottom: 72px; }
 <script>
 const $ = (id) => document.getElementById(id);
+// The second brain (tools/second-brain), served by this board under /brain/, in
+// its own popup window; a second click brings the same window back.
+$('brainBtn').addEventListener('click', () => {
+  const w = window.open('', 'second-brain', 'popup,width=1200,height=820');
+  if (!w) { location.href = '/brain/'; return; }
+  let fresh = true;
+  try { fresh = !w.location.pathname.startsWith('/brain/'); } catch { /* another page in that window */ }
+  if (fresh) w.location.href = '/brain/';
+  w.focus();
+});
 const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
 const SHORT = { gr: 'GR', aa: 'AA', st: 'ST' };
```
