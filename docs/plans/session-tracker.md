# Session tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the progress dashboard a tracked tool in `tools/progress-dashboard/` and add a Sessions list, a page per session (stage task tiles linked to that stage's docs) and a feedback sidebar whose notes reach the session through a Claude Code hook.

**Architecture:** The existing Node server (`server.mjs`, no dependencies) keeps its `/data` progress model and gains a `routes.mjs` handler for `/api/*` and `/session/*`. Small single-purpose modules feed it: `repo.mjs` finds the main checkout, `sessions.mjs` reads transcripts, `stage.mjs` matches sessions to lanes and stages, `docs.mjs` cuts plan and spec text, `markdown.mjs` renders it safely, and `feedback.mjs` queues feedback. A separate hook script (`feedback-hook.mjs`), installed to `~/.claude/hooks/session-feedback/` by `install-hook.mjs`, delivers queued feedback on `Stop` and `UserPromptSubmit`.

**Tech Stack:** Node 22+ ES modules (`node:http`, `node:fs/promises`, `node:child_process`), `node:test` + `node:assert/strict`, plain HTML/CSS/JS pages with no build step and no CDN.

**Spec:** `docs/specs/session-tracker.md`

## Global Constraints

- No npm dependencies. Node built-ins only. Pages load nothing from the internet.
- Tests run on Windows (this PC) and on CI's `ubuntu-latest` with Node 22. No test reads `~/.claude` or the real transcripts; tests use temporary folders.
- `npm test` runs `test:dashboard`, which is `node --test "tools/progress-dashboard/tests/*.test.mjs"`.
- The server listens on `127.0.0.1` only. `PORT` defaults to 5199 and `REPO` overrides the main checkout.
- `POST /api/feedback/:id` gives 403 unless the Origin (or the Referer's origin) is `http://localhost:<port>` or `http://127.0.0.1:<port>`. It gives 400 for a body over 64 KB, bad JSON, or no notes and no message. It gives 404 for an unknown session.
- Session ids must match `^[0-9a-f-]{36}$` before any file path is built from them.
- Feedback queue: `~/.claude/session-feedback/<sessionId>.jsonl`, overridable by `SESSION_FEEDBACK_DIR`. Lock file `<sessionId>.lock`, made with the `wx` flag, retried for 2 s, stale after 10 s.
- Hook: no output and exit 0 when nothing is queued or on any error. Errors go to `hook-errors.log` in the feedback folder.
- Live means a transcript changed within 3 minutes. Sessions over 24 h old fold into "Earlier (n)".
- Tile colours: done is blue, working is green and pulses at 1.2 s (a steady ring under `prefers-reduced-motion`), next is a teal outline, blocked is grey, not started is plain.
- Every commit: run `npm test` and `npm run typecheck` first, then commit and push `tools/session-tracker`. The branch has no upstream, so push with `git push origin tools/session-tracker`.
- Tick each task here when it's done.

## Review Focus

1. **A transcript mid-write:** the last line is half a JSON record. Expected: the session still lists with its title, cwd and branch from the complete lines (test in Task 2).
2. **A main-checkout session from days ago:** for example "Stage 3 completion" on `feature/godot-rebuild`. Expected: it shows stage 3 from its title, not the main lane's current stage, and it does not pulse as working on the main lane's task, which belongs to the newest main-checkout session only (test in Task 5).
3. **Docs text that looks like HTML or a script link:** for example `<script>`, `[x](javascript:alert(1))` or `` `a*b*c` ``. Expected: it shows as text, the link is dropped and the code isn't turned italic (tests in Task 3).
4. **Feedback sent while the hook fires:** the server appends while the hook rewrites, and a crashed hook leaves a stale lock. Expected: nothing is lost or delivered twice, and a lock older than 10 s doesn't block forever (tests in Task 8).
5. **Settings already holding other hooks or broken JSON:** for example the superpowers plugin's settings. Expected: install keeps everything else, adds nothing on a second run, and refuses to write over a settings file it can't parse (tests in Task 10).

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `tools/progress-dashboard/server.mjs` | moved in. Progress model (`collect()`), static pages, mounts `routes.mjs` | 1, 5 |
| `tools/progress-dashboard/index.html` | moved in. Dashboard page, plus the Sessions section and teal "next" | 1, 6 |
| `tools/progress-dashboard/repo.mjs` | `findRepo()`, `mainWorktree()`, `projectPrefix()` | 1 |
| `tools/progress-dashboard/sessions.mjs` | `readSession()`, `listSessions()`, `summarize()` | 2 |
| `tools/progress-dashboard/markdown.mjs` | `renderMarkdown()`, `escapeHtml()`. Runs in node and the browser | 3 |
| `tools/progress-dashboard/docs.mjs` | `taskBlock()`, `parentBlock()`, `storyIds()`, `parseStories()`, `stageDocs()` | 4 |
| `tools/progress-dashboard/stage.mjs` | `sessionStage()`, `attachStages()`, `taskStates()` | 5 |
| `tools/progress-dashboard/routes.mjs` | `makeRoutes()`, `allowedOrigin()`, `cleanFeedback()` | 5, 8 |
| `tools/progress-dashboard/session.html` | session page: header, picker, tiles, docs, sidebar | 7, 9 |
| `tools/progress-dashboard/feedback.mjs` | queue: `queueFeedback()`, `readFeedback()`, `takeQueued()`, `withLock()`, `formatFeedback()` | 8 |
| `tools/progress-dashboard/feedback-hook.mjs` | `runHook()`, plus a main that reads stdin | 10 |
| `tools/progress-dashboard/install-hook.mjs` | `install()`, `uninstall()`, `hookCommand()` | 10 |
| `tools/progress-dashboard/tests/*.test.mjs` | node:test suites, one per module | all |
| `package.json` | `dashboard`, `test:dashboard`, `test` chain | 1 |
| `CLAUDE.md` | Commands: `npm run dashboard` | 1 |

---

### Task 1: Move the dashboard into `tools/` and find the main checkout

- [x] Done when: the server runs from this worktree and shows the same stages and lanes as the old copy.

**Files:**
- Create: `tools/progress-dashboard/server.mjs`, copied from `C:/Users/Win11/Desktop/Monomachia/.claude/progress-dashboard/server.mjs`
- Create: `tools/progress-dashboard/index.html`, copied from the same folder
- Create: `tools/progress-dashboard/repo.mjs`
- Create: `tools/progress-dashboard/tests/repo.test.mjs`
- Modify: `package.json` (scripts), `CLAUDE.md` (Commands)

**Interfaces:**
- Produces: `mainWorktree(porcelain: string): string|null`, `findRepo({cwd?, env?}): Promise<string>`, `projectPrefix(repo: string): string`

- [x] **Step 1: Copy the two files unchanged**

```bash
mkdir -p tools/progress-dashboard/tests
cp "C:/Users/Win11/Desktop/Monomachia/.claude/progress-dashboard/server.mjs" tools/progress-dashboard/
cp "C:/Users/Win11/Desktop/Monomachia/.claude/progress-dashboard/index.html" tools/progress-dashboard/
```

- [x] **Step 2: Write the failing test** `tools/progress-dashboard/tests/repo.test.mjs`

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { mainWorktree, findRepo, projectPrefix } from '../repo.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));

test('mainWorktree takes the first worktree of the porcelain list', () => {
  const porcelain = 'worktree /a/main\nHEAD 123\nbranch refs/heads/x\n\nworktree /a/main/.claude/worktrees/w\nHEAD 456\n';
  assert.equal(mainWorktree(porcelain), path.normalize('/a/main'));
  assert.equal(mainWorktree(''), null);
});

test('findRepo gives the checkout that owns the .git folder, even from a worktree', async () => {
  const common = execFileSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { cwd: HERE, encoding: 'utf8' }).trim();
  assert.equal(path.resolve(await findRepo({ cwd: HERE, env: {} })), path.resolve(path.dirname(common)));
});

test('findRepo honours REPO', async () => {
  assert.equal(await findRepo({ cwd: HERE, env: { REPO: '/x/y' } }), path.resolve('/x/y'));
});

test('projectPrefix turns every non-alphanumeric character into a dash', { skip: process.platform !== 'win32' }, () => {
  assert.equal(projectPrefix('C:\\Users\\Win11\\Desktop\\Monomachia'), 'C--Users-Win11-Desktop-Monomachia');
});

test('projectPrefix on posix paths', { skip: process.platform === 'win32' }, () => {
  assert.equal(projectPrefix('/home/a/Mono.x'), '-home-a-Mono-x');
});
```

- [x] **Step 3: Run it and see it fail**

Run: `node --test "tools/progress-dashboard/tests/*.test.mjs"`
Expected: FAIL, `Cannot find module '../repo.mjs'`.

- [x] **Step 4: Write `repo.mjs`**

```js
// Finds the main checkout, whose plan and worktree list the dashboard reads,
// so a copy run from any lane's worktree shows the same data.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const run = promisify(execFile);
const HERE = path.dirname(fileURLToPath(import.meta.url));

export function mainWorktree(porcelain) {
  const line = porcelain.split(/\r?\n/).find((l) => l.startsWith('worktree '));
  return line ? path.normalize(line.slice(9)) : null;
}

export async function findRepo({ cwd = HERE, env = process.env } = {}) {
  if (env.REPO) return path.resolve(env.REPO);
  const { stdout } = await run('git', ['--no-optional-locks', 'worktree', 'list', '--porcelain'], { cwd, windowsHide: true });
  const repo = mainWorktree(stdout);
  if (!repo) throw new Error('git worktree list named no worktree');
  return repo;
}

// Claude Code names a project's transcript folder after its path this way.
export function projectPrefix(repo) {
  return path.resolve(repo).replace(/[^A-Za-z0-9]/g, '-');
}
```

- [x] **Step 5: Use it in `server.mjs`.** Replace `const REPO = path.resolve(HERE, '..', '..');` with:

```js
import { findRepo } from './repo.mjs';
const REPO = await findRepo();
```

Then change the header comment's run line to `npm run dashboard   ->   http://localhost:5199`, and the "Local tooling, not committed." sentence to "Run from any checkout: it reads the main checkout."

- [x] **Step 6: Scripts and docs.** In `package.json` `scripts`, change `"test"` to `"npm run test:web && npm run test:godot && npm run test:dashboard"`, and add:

```json
"test:dashboard": "node --test \"tools/progress-dashboard/tests/*.test.mjs\"",
"dashboard": "node tools/progress-dashboard/server.mjs",
```

In CLAUDE.md's `## Commands`, add: `` - `npm run dashboard`: progress dashboard and session tracker at http://localhost:5199 (reads the main checkout from any worktree) ``.

- [x] **Step 7: Run the tests and see them pass**

Run: `npm run test:dashboard`
Expected: 4 pass and 1 skipped.

- [x] **Step 8: Check it against the old copy**

```bash
PORT=5198 node tools/progress-dashboard/server.mjs &
curl -s localhost:5198/data > /tmp/new.json; curl -s localhost:5199/data > /tmp/old.json
node -e "const a=require('/tmp/new.json'),b=require('/tmp/old.json');console.log(a.total===b.total&&a.done===b.done&&a.lanes.length===b.lanes.length)"
```

Expected: `true`. (Use the scratchpad instead of `/tmp`. If 5199 isn't running, start the old copy with `node C:/Users/Win11/Desktop/Monomachia/.claude/progress-dashboard/server.mjs`.) Stop the 5198 server afterwards.

- [x] **Step 9: Commit** (after `npm test` and `npm run typecheck`)

```bash
git add tools/progress-dashboard package.json CLAUDE.md docs/plans/session-tracker.md
git commit -m "Track the progress dashboard in tools/ and find the main checkout from any worktree"
git push origin tools/session-tracker
```

---

### Task 2: Read Claude Code transcripts into sessions

- [x] Done when: `listSessions()` gives one record per transcript, newest first, from fixtures.

**Files:**
- Create: `tools/progress-dashboard/sessions.mjs`
- Create: `tools/progress-dashboard/tests/sessions.test.mjs`

**Interfaces:**
- Produces: `LIVE_MS = 180000`; `summarize(records, into?): {title?, firstPrompt?, cwd?, branch?}`; `readSession(file, now?): Promise<Session>`; `listSessions({projectsDir, prefix, now?}): Promise<Session[]>`
- `Session = { id, file, title, cwd, folder, branch, lastActive /* ms */, live }`

- [x] **Step 1: Write the failing tests** `tests/sessions.test.mjs`

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, utimes } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { readSession, listSessions, LIVE_MS } from '../sessions.mjs';

const ID1 = '11111111-1111-1111-1111-111111111111';
const ID2 = '22222222-2222-2222-2222-222222222222';
const line = (o) => JSON.stringify(o) + '\n';
const user = (text) => line({ type: 'user', message: { role: 'user', content: text }, cwd: 'C:\\r', gitBranch: 'b0' });

async function tmp() { return mkdtemp(path.join(os.tmpdir(), 'sessions-')); }

test('title, cwd and branch come from the last records; a half-written last line is skipped', async () => {
  const dir = await tmp();
  const f = path.join(dir, `${ID1}.jsonl`);
  await writeFile(f, user('hello') +
    line({ type: 'custom-title', customTitle: 'Old title' }) +
    line({ type: 'assistant', cwd: 'C:\\w\\lane', gitBranch: 'godot/stage-7-swings' }) +
    line({ type: 'custom-title', customTitle: 'Stage 7 swing foundations' }) +
    '{"type":"custom-title","customTi');
  const s = await readSession(f);
  assert.equal(s.id, ID1);
  assert.equal(s.title, 'Stage 7 swing foundations');
  assert.equal(s.cwd, 'C:\\w\\lane');
  assert.equal(s.folder, 'lane');
  assert.equal(s.branch, 'godot/stage-7-swings');
});

test('without a custom title, the first real prompt cut to 80 characters; then the short id', async () => {
  const dir = await tmp();
  const a = path.join(dir, `${ID1}.jsonl`);
  await writeFile(a, line({ type: 'user', message: { content: '<command-name>/x</command-name>' } }) + user('y'.repeat(100)));
  assert.equal((await readSession(a)).title, 'y'.repeat(80));
  const b = path.join(dir, `${ID2}.jsonl`);
  await writeFile(b, line({ type: 'assistant', cwd: 'C:\\r' }));
  assert.equal((await readSession(b)).title, '22222222');
});

test('array content parts count as a prompt', async () => {
  const dir = await tmp();
  const f = path.join(dir, `${ID1}.jsonl`);
  await writeFile(f, line({ type: 'user', message: { content: [{ type: 'text', text: 'Begin stage 6' }] } }));
  assert.equal((await readSession(f)).title, 'Begin stage 6');
});

test('steps back past a long tail to find the title', async () => {
  const dir = await tmp();
  const f = path.join(dir, `${ID1}.jsonl`);
  const filler = (n) => line({ type: 'assistant', message: { content: 'z'.repeat(1000) } }).repeat(n);
  // The title sits past the 64 KB head and 600 KB before the end: only stepping back finds it.
  await writeFile(f, user('first') + filler(100) + line({ type: 'custom-title', customTitle: 'Deep title' }) + filler(600));
  assert.equal((await readSession(f)).title, 'Deep title');
});

test('live within 3 minutes; listSessions keeps only the project prefix, newest first', async () => {
  const root = await tmp();
  const mine = path.join(root, 'C--Mono'); const worktree = path.join(root, 'C--Mono--claude-worktrees-x');
  const other = path.join(root, 'C--Other');
  for (const d of [mine, worktree, other]) await mkdir(d);
  await writeFile(path.join(mine, `${ID1}.jsonl`), user('old'));
  await writeFile(path.join(worktree, `${ID2}.jsonl`), user('new'));
  await writeFile(path.join(other, '33333333-3333-3333-3333-333333333333.jsonl'), user('other'));
  await mkdir(path.join(mine, ID1)); // the per-session folder Claude Code makes is ignored
  const now = Date.now();
  await utimes(path.join(mine, `${ID1}.jsonl`), new Date(now - 3600e3), new Date(now - 3600e3));
  await utimes(path.join(worktree, `${ID2}.jsonl`), new Date(now - 1000), new Date(now - 1000));
  const list = await listSessions({ projectsDir: root, prefix: 'C--Mono', now });
  assert.deepEqual(list.map((s) => s.id), [ID2, ID1]);
  assert.equal(list[0].live, true);
  assert.equal(list[1].live, false);
  assert.ok(LIVE_MS === 180000);
});

test('a missing projects folder gives an empty list', async () => {
  assert.deepEqual(await listSessions({ projectsDir: path.join(os.tmpdir(), 'nope-' + Date.now()), prefix: 'x' }), []);
});
```

- [x] **Step 2: Run them and see them fail**

Run: `npm run test:dashboard`
Expected: FAIL, `Cannot find module '../sessions.mjs'`.

- [x] **Step 3: Write `sessions.mjs`**

```js
// Claude Code sessions for this project, read from their transcript files
// (~/.claude/projects/<prefix>*/<id>.jsonl). Only the head and tail of each
// file are read, and results are cached by size and modified time.
import { open, readdir, stat } from 'node:fs/promises';
import path from 'node:path';

export const LIVE_MS = 3 * 60 * 1000;
const HEAD = 64 << 10;
const CHUNK = 256 << 10;
const MAX_BACK = 4 << 20;

function records(text) {
  const out = [];
  for (const raw of text.split('\n')) {
    const t = raw.trim();
    if (!t) continue;
    try { out.push(JSON.parse(t)); } catch { /* a line cut by a chunk edge or mid-write */ }
  }
  return out;
}

function promptText(r) {
  if (r.type !== 'user' || r.isMeta) return null;
  const c = r.message?.content;
  const text = typeof c === 'string' ? c : Array.isArray(c) ? c.find((p) => p?.type === 'text')?.text : null;
  if (!text || text.trimStart().startsWith('<')) return null;
  return text.trim();
}

// Later records win for title, cwd and branch; the first prompt is the earliest.
export function summarize(recs, into = {}) {
  for (const r of recs) {
    if (r.type === 'custom-title' && r.customTitle) into.title = r.customTitle;
    if (typeof r.cwd === 'string') into.cwd = r.cwd;
    if (typeof r.gitBranch === 'string') into.branch = r.gitBranch;
    if (into.firstPrompt == null) { const p = promptText(r); if (p) into.firstPrompt = p; }
  }
  return into;
}

export async function readSession(file, now = Date.now()) {
  const st = await stat(file);
  const fh = await open(file, 'r');
  try {
    const read = async (pos, len) => {
      const buf = Buffer.alloc(len);
      const { bytesRead } = await fh.read(buf, 0, len, pos);
      return buf.toString('utf8', 0, bytesRead);
    };
    const head = summarize(records(await read(0, Math.min(HEAD, st.size))));
    const found = {};
    let end = st.size;
    while (end > 0 && st.size - end < MAX_BACK && !(found.title && found.cwd && found.branch)) {
      const start = Math.max(0, end - CHUNK);
      let text = await read(start, end - start);
      if (start > 0) text = text.slice(text.indexOf('\n') + 1);
      const s = summarize(records(text));
      for (const k of ['title', 'cwd', 'branch']) if (found[k] == null && s[k] != null) found[k] = s[k];
      end = start;
    }
    const id = path.basename(file, '.jsonl');
    const cwd = found.cwd ?? head.cwd ?? null;
    return {
      id, file,
      title: found.title ?? head.title ?? head.firstPrompt?.slice(0, 80) ?? id.slice(0, 8),
      cwd,
      folder: cwd ? path.win32.basename(cwd.replaceAll('/', '\\')) : '',
      branch: found.branch ?? head.branch ?? null,
      lastActive: st.mtimeMs,
      live: now - st.mtimeMs < LIVE_MS,
    };
  } finally {
    await fh.close();
  }
}

const cache = new Map(); // file -> { size, mtimeMs, session }

export async function listSessions({ projectsDir, prefix, now = Date.now() }) {
  let dirs;
  try { dirs = await readdir(projectsDir, { withFileTypes: true }); } catch { return []; }
  const out = [];
  for (const d of dirs) {
    if (!d.isDirectory() || !d.name.startsWith(prefix)) continue;
    const dir = path.join(projectsDir, d.name);
    for (const f of await readdir(dir, { withFileTypes: true })) {
      if (!f.isFile() || !f.name.endsWith('.jsonl')) continue;
      const file = path.join(dir, f.name);
      try {
        const st = await stat(file);
        let hit = cache.get(file);
        if (!hit || hit.size !== st.size || hit.mtimeMs !== st.mtimeMs) {
          hit = { size: st.size, mtimeMs: st.mtimeMs, session: await readSession(file, now) };
          cache.set(file, hit);
        }
        out.push({ ...hit.session, live: now - hit.session.lastActive < LIVE_MS });
      } catch { /* removed while listing */ }
    }
  }
  return out.sort((a, b) => b.lastActive - a.lastActive);
}
```

(`path.win32.basename` after turning `/` into `\` gives the last folder for both Windows and posix cwd strings.)

- [x] **Step 4: Run the tests and see them pass**

Run: `npm run test:dashboard`
Expected: all pass.

- [x] **Step 5: Smoke test it on the real transcripts**

```bash
node -e "import('./tools/progress-dashboard/sessions.mjs').then(async m=>{const l=await m.listSessions({projectsDir:require('os').homedir()+'/.claude/projects',prefix:'C--Users-Win11-Desktop-Monomachia'});console.log(l.length,l.slice(0,3).map(s=>[s.title,s.branch,s.live]))})"
```

Expected: about 20 sessions. The first is this one, titled "Claude Code session tracker and docs", and it is live.

- [x] **Step 6: Commit** (after `npm test` and `npm run typecheck`): `git add tools/progress-dashboard` then `git commit -m "Read Claude Code transcripts into dashboard sessions"`, and push.

---

### Task 3: A safe Markdown renderer

- [x] Done when: plan task blocks render as nested lists, with nothing in the docs able to inject HTML.

**Files:**
- Create: `tools/progress-dashboard/markdown.mjs` (no node imports, so the page can import it)
- Create: `tools/progress-dashboard/tests/markdown.test.mjs`

**Interfaces:**
- Produces: `escapeHtml(s): string`, `renderMarkdown(md): string`

- [x] **Step 1: Write the failing tests**

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderMarkdown as md, escapeHtml } from '../markdown.mjs';

test('escapes HTML everywhere', () => {
  assert.equal(escapeHtml(`<a href="x">'&`), '&lt;a href=&quot;x&quot;&gt;&#39;&amp;');
  assert.equal(md('<script>alert(1)</script>'), '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>');
});

test('inline: bold, italic, code (no emphasis inside code), links', () => {
  assert.equal(md('**b** *i* `a*b*c`'), '<p><strong>b</strong> <em>i</em> <code>a*b*c</code></p>');
  assert.equal(md('[doc](#task-7.1)'), '<p><a href="#task-7.1">doc</a></p>');
  assert.equal(md('[x](https://e.com/a?b=1&c=2)'), '<p><a href="https://e.com/a?b=1&amp;c=2">x</a></p>');
});

test('unsafe link schemes are dropped to their text', () => {
  assert.equal(md('[x](javascript:alert(1))'), '<p>x</p>');
  assert.equal(md('[x](data:text/html,hi)'), '<p>x</p>');
});

test('nested lists, continuation lines and checkboxes', () => {
  const src = '- [ ] **7.1 Title.** Text\n  - Check: a\n    more\n  - Blocked by: none\n- [x] next';
  assert.equal(md(src),
    '<ul><li><input type="checkbox" disabled> <strong>7.1 Title.</strong> Text' +
    '<ul><li>Check: a more</li><li>Blocked by: none</li></ul></li>' +
    '<li><input type="checkbox" disabled checked> next</li></ul>');
});

test('paragraphs and headings', () => {
  assert.equal(md('one\ntwo\n\n### H'), '<p>one two</p><h3>H</h3>');
});
```

- [x] **Step 2: Run them and see them fail**

Run: `npm run test:dashboard`
Expected: FAIL, the module is missing.

- [x] **Step 3: Write `markdown.mjs`**

```js
// The small piece of Markdown the plan and spec use: paragraphs, headings,
// nested "-" lists, checkboxes, **bold**, *italic*, `code` and [links](url).
// Everything is escaped first; links are kept only for http(s), # and relative URLs.
export function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

const SAFE_URL = (u) => /^https?:\/\//i.test(u) || u.startsWith('#') || !/^[a-z][a-z0-9+.-]*:/i.test(u);

function inline(text) {
  return String(text).split(/(`[^`]+`)/).map((part) => {
    if (/^`[^`]+`$/.test(part)) return `<code>${escapeHtml(part.slice(1, -1))}</code>`;
    return escapeHtml(part)
      .replace(/\[([^\]]+)\]\(([^)\s]+(?:\([^)\s]*\))?)\)/g, (_, t, u) => (SAFE_URL(u) ? `<a href="${u}">${t}</a>` : t))
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/(^|[^*\w])\*([^*\s][^*]*?)\*(?!\*)/g, '$1<em>$2</em>');
  }).join('');
}

function item(text) {
  const m = text.match(/^\[([ xX])\]\s+(.*)$/);
  if (!m) return inline(text);
  return `<input type="checkbox" disabled${m[1] === ' ' ? '' : ' checked'}> ${inline(m[2])}`;
}

export function renderMarkdown(src) {
  const lines = String(src ?? '').replace(/\r/g, '').split('\n');
  let html = '';
  let para = [];
  const stack = []; // indents of the open lists, each with an open <li>
  const flush = () => { if (para.length) { html += `<p>${inline(para.join(' '))}</p>`; para = []; } };
  const closeAll = () => { while (stack.length) { html += '</li></ul>'; stack.pop(); } };
  for (const line of lines) {
    if (!line.trim()) { flush(); continue; }
    const indent = line.match(/^\s*/)[0].length;
    const li = line.match(/^\s*[-*]\s+(.*)$/);
    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) { flush(); closeAll(); html += `<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`; continue; }
    if (li) {
      flush();
      if (!stack.length || indent > stack.at(-1)) { html += '<ul>'; stack.push(indent); }
      else {
        while (stack.length > 1 && indent < stack.at(-1)) { html += '</li></ul>'; stack.pop(); }
        html += '</li>';
      }
      html += `<li>${item(li[1])}`;
      continue;
    }
    if (stack.length && indent > 0) { html += ` ${inline(line.trim())}`; continue; }
    closeAll();
    para.push(line.trim());
  }
  flush();
  closeAll();
  return html;
}
```

- [x] **Step 4: Run the tests and see them pass.** If the nested-list test fails on spacing, fix the renderer, not the expected string.

- [x] **Step 5: Commit**: `git commit -m "Add a safe Markdown renderer for the dashboard's docs"`, then push.

---

### Task 4: Cut task blocks and stories out of the plan and spec

- [ ] Done when: `stageDocs()` gives stage 7's parent text, each task's block and its stories from fixture text.

**Files:**
- Create: `tools/progress-dashboard/docs.mjs`
- Create: `tools/progress-dashboard/tests/docs.test.mjs`

**Interfaces:**
- Consumes: the stage objects from `collect()` (`{ n, name, full, tasks: string[] }`)
- Produces:
  - `taskBlock(planText, id): string|null`
  - `parentBlock(planText, major): string|null`
  - `storyIds(block): number[]`
  - `parseStories(specText): Map<number, {n, done, text}>`
  - `stageDocs(planText, specText, stage, states): {n, name, full, parents: [{id, markdown}], tasks: [{id, title, state, blockedBy, markdown, stories}]}`, where `states` is `Map<id, {state, blockedBy}>` (from Task 5's `taskStates`)

- [ ] **Step 1: Write the failing tests**

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { taskBlock, parentBlock, storyIds, parseStories, stageDocs } from '../docs.mjs';

const PLAN = `## Tasks

- [ ] **7. Swing-based hits.**
  - Delivers: swings.
  - Check: tests.
  - [x] **7.1 Helpers.** Vector ops.
    - Check: identities.
      - deeper note
    - Blocked by: none · Stories: 59
  - [ ] **7.2 Swing data.** Keys.

    - Check: loads.
    - Blocked by: 7.1 · Stories: 16, 21–23
- [ ] **8. Fluid rules.**
`;
const SPEC = `## User Stories

### Attacking

16. [ ] As a player, I want arcs.
21. [x] As a player, I want blade hits.
22. [ ] As a player, I want unblockables.
`;

test('taskBlock takes the task line and everything indented under it, dedented', () => {
  assert.equal(taskBlock(PLAN, '7.1'),
    '- [x] **7.1 Helpers.** Vector ops.\n  - Check: identities.\n    - deeper note\n  - Blocked by: none · Stories: 59');
  assert.equal(taskBlock(PLAN, '7.2'),
    '- [ ] **7.2 Swing data.** Keys.\n\n  - Check: loads.\n  - Blocked by: 7.1 · Stories: 16, 21–23');
  assert.equal(taskBlock(PLAN, '9.9'), null);
});

test('parentBlock stops at the first subtask', () => {
  assert.equal(parentBlock(PLAN, '7'), '- [ ] **7. Swing-based hits.**\n  - Delivers: swings.\n  - Check: tests.');
  assert.equal(parentBlock(PLAN, '12'), null);
});

test('storyIds reads lists and ranges; parseStories keeps ticks', () => {
  assert.deepEqual(storyIds(taskBlock(PLAN, '7.2')), [16, 21, 22, 23]);
  assert.deepEqual(storyIds('- [ ] **x** no stories'), []);
  const s = parseStories(SPEC);
  assert.deepEqual(s.get(21), { n: 21, done: true, text: 'As a player, I want blade hits.' });
});

test('stageDocs puts it together, skipping missing stories', () => {
  const stage = { n: 7, name: 'Swing foundations', full: 'Swing foundations', tasks: ['7.1', '7.2'] };
  const states = new Map([['7.1', { state: 'done', blockedBy: [] }], ['7.2', { state: 'next', blockedBy: [] }]]);
  const d = stageDocs(PLAN, SPEC, stage, states);
  assert.deepEqual(d.parents.map((p) => p.id), ['7']);
  assert.equal(d.tasks[1].title, 'Swing data');
  assert.equal(d.tasks[1].state, 'next');
  assert.deepEqual(d.tasks[1].stories.map((s) => s.n), [16, 21, 22]); // 23 isn't in the spec
});
```

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Write `docs.mjs`**

```js
// Cuts the build plan's task blocks and the spec's user stories, so a stage's
// page can show what each task delivers and how it is checked.
const TASK = /^(\s*)- \[[ x]\] \*\*(\d+b?\.\d+)\s+(.*?)\*\*/;
const PARENT = /^- \[[ x]\] \*\*(\d+b?)\.\s/;
const indentOf = (l) => l.match(/^\s*/)[0].length;

function blockAt(lines, i, stopAtTask = false) {
  const base = indentOf(lines[i]);
  let j = i + 1;
  while (j < lines.length && (!lines[j].trim() || indentOf(lines[j]) > base) && !(stopAtTask && TASK.test(lines[j]))) j++;
  while (j > i + 1 && !lines[j - 1].trim()) j--;
  return lines.slice(i, j).map((l) => l.slice(Math.min(base, indentOf(l)))).join('\n');
}

export function taskBlock(planText, id) {
  const lines = planText.replace(/\r/g, '').split('\n');
  const i = lines.findIndex((l) => l.match(TASK)?.[2] === id);
  return i < 0 ? null : blockAt(lines, i);
}

export function parentBlock(planText, major) {
  const lines = planText.replace(/\r/g, '').split('\n');
  const i = lines.findIndex((l) => l.match(PARENT)?.[1] === major);
  return i < 0 ? null : blockAt(lines, i, true);
}

export function storyIds(block) {
  const m = block?.match(/Stories:\s*([^\n·]*)/);
  if (!m) return [];
  const out = [];
  for (const [, a, b] of m[1].matchAll(/(\d+)(?:\s*[–-]\s*(\d+))?/g)) {
    for (let n = Number(a); n <= Number(b ?? a); n++) out.push(n);
  }
  return out;
}

export function parseStories(specText) {
  const section = specText.replace(/\r/g, '').split(/^## User Stories/m)[1]?.split(/^## /m)[0] ?? '';
  const map = new Map();
  for (const line of section.split('\n')) {
    const m = line.match(/^(\d+)\.\s+\[([ x])\]\s+(.*)$/);
    if (m) map.set(Number(m[1]), { n: Number(m[1]), done: m[2] === 'x', text: m[3] });
  }
  return map;
}

export function stageDocs(planText, specText, stage, states) {
  const stories = parseStories(specText);
  const majors = [...new Set(stage.tasks.map((id) => id.split('.')[0]))];
  return {
    n: stage.n, name: stage.name, full: stage.full,
    parents: majors.map((id) => ({ id, markdown: parentBlock(planText, id) })).filter((p) => p.markdown),
    tasks: stage.tasks.map((id) => {
      const markdown = taskBlock(planText, id) ?? '';
      const title = markdown.match(TASK)?.[3].replace(/[.;]\s*$/, '') ?? id;
      const st = states.get(id) ?? { state: 'rest', blockedBy: [] };
      return {
        id, title, state: st.state, blockedBy: st.blockedBy, markdown,
        stories: storyIds(markdown).map((n) => stories.get(n)).filter(Boolean),
      };
    }),
  };
}
```

- [ ] **Step 4: Run the tests and see them pass.** Then smoke test on the real plan: `node -e "import('./tools/progress-dashboard/docs.mjs').then(m=>{const fs=require('fs');console.log(m.taskBlock(fs.readFileSync('docs/plans/godot-rebuild.md','utf8'),'7.13'))})"` should print 7.13's three lines.

- [ ] **Step 5: Commit**: `git commit -m "Cut plan task blocks and spec stories for the stage pages"`, then push.

---

### Task 5: Match sessions to stages, and the session and stage API

- [ ] Done when: `GET /api/sessions`, `/api/session/:id` and `/api/stage/:n` answer with real data on port 5198.

**Files:**
- Create: `tools/progress-dashboard/stage.mjs`, `tools/progress-dashboard/routes.mjs`
- Create: `tools/progress-dashboard/tests/stage.test.mjs`, `tools/progress-dashboard/tests/routes.test.mjs`
- Modify: `tools/progress-dashboard/server.mjs` (`collect()` also returns `blockers` and `doneIds`; the request handler tries the routes first)

**Interfaces:**
- Consumes: `collect()` data (`stages[{n,name,full,tasks,done,working,next}]`, `lanes[{path,branch,kind,stage,task,title,state}]`), `listSessions`, `stageDocs`
- Produces:
  - `sessionStage(session, data): number|null`
  - `attachStages(sessions, data): SessionView[]`, where `SessionView = Session & { stage, task, taskTitle, laneState }`
  - `taskStates(stage, data): Map<id, {state, blockedBy}>`
  - `makeRoutes(ctx): (req, res) => Promise<boolean>`, where `ctx = { here, port, repo, getData, listSessions, feedbackDir, hookInstalled }`

- [ ] **Step 1: Write the failing tests** `tests/stage.test.mjs`

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sessionStage, attachStages, taskStates } from '../stage.mjs';

const data = {
  stages: [
    { n: 3, name: 'The shrine', tasks: ['17.1'], done: ['17.1'], working: [], next: [] },
    { n: 6, name: 'Strings', tasks: ['9.1', '9.2'], done: ['9.1'], working: [], next: ['9.2'] },
    { n: 7, name: 'Swings', tasks: ['7.1', '7.2', '7.3'], done: ['7.1'], working: ['7.2'], next: [] },
    { n: 8, name: 'Animation', tasks: ['14.3', '14.4'], done: [], working: [], next: [] },
  ],
  lanes: [
    { path: 'C:\\m', branch: 'feature/godot-rebuild', kind: 'main', stage: null, task: '9.2', title: 'Iai', state: 'next' },
    { path: 'C:\\s7', branch: 'godot/stage-7-swings', kind: 'stage', stage: 7, task: '7.2', title: 'Swing data', state: 'working' },
  ],
  blockers: { '7.3': ['7.2'], '14.4': ['14.3'] },
  doneIds: ['17.1', '9.1', '7.1'],
};
const s = (o) => ({ id: o.id ?? 'x', title: '', cwd: null, branch: null, lastActive: 0, ...o });

test('stage from the branch, the title, or the main lane', () => {
  assert.equal(sessionStage(s({ branch: 'godot/stage-7-swings' }), data), 7);
  assert.equal(sessionStage(s({ branch: 'godot/shuffle-footsteps', title: 'Stage 8 work' }), data), null);
  assert.equal(sessionStage(s({ branch: 'claude/x', title: 'Stage 3 completion' }), data), 3);
  assert.equal(sessionStage(s({ branch: 'HEAD', title: 'Fighter animation core tasks 14.3–14.9' }), data), 8);
  assert.equal(sessionStage(s({ branch: 'feature/godot-rebuild', title: 'Stage 3 completion' }), data), 3);
  assert.equal(sessionStage(s({ branch: 'feature/godot-rebuild', title: 'Godot Rebuild' }), data), 6);
  assert.equal(sessionStage(s({ branch: 'master', title: 'CLAUDE.md commit' }), data), null);
  assert.equal(sessionStage(s({ branch: 'claude/x', title: 'Stage 99' }), data), null);
});

test('a lane goes only to its newest session, by cwd first, then by stage', () => {
  const list = attachStages([
    s({ id: 'new-main', cwd: 'C:\\m', branch: 'feature/godot-rebuild', title: 'Godot Rebuild', lastActive: 9 }),
    s({ id: 'app-wt', cwd: 'C:\\wt', branch: 'godot/stage-7-swings', lastActive: 8 }),
    s({ id: 'old-main', cwd: 'C:\\m', branch: 'feature/godot-rebuild', title: 'Stage 3 completion', lastActive: 1 }),
  ], data);
  assert.deepEqual(list.map((x) => [x.id, x.stage, x.task, x.laneState]), [
    ['new-main', 6, '9.2', 'next'],
    ['app-wt', 7, '7.2', 'working'],
    ['old-main', 3, null, null],
  ]);
});

test('task states: done, working, next, blocked, rest', () => {
  const st = taskStates(data.stages[2], data);
  assert.deepEqual(Object.fromEntries([...st].map(([k, v]) => [k, v.state])), { '7.1': 'done', '7.2': 'working', '7.3': 'blocked' });
  assert.deepEqual(st.get('7.3').blockedBy, ['7.2']);
  assert.equal(taskStates(data.stages[3], data).get('14.3').state, 'rest');
});
```

- [ ] **Step 2: Write `stage.mjs`**

```js
// Which build-order stage a Claude Code session works on, and which lane's
// current task belongs to it. See docs/specs/session-tracker.md.
import path from 'node:path';

const MAIN_BRANCH = 'feature/godot-rebuild';
const norm = (p) => (p ? path.resolve(p).toLowerCase() : '');
const stageOfTask = (data, id) => data.stages.find((s) => s.tasks.includes(id))?.n ?? null;
const laneStage = (data, l) => l.stage ?? (l.task ? stageOfTask(data, l.task) : null);

export function sessionStage(session, data) {
  const branch = session.branch ?? '';
  const title = session.title ?? '';
  let n = null;
  const m = branch.match(/^godot\/stage-(\d+)/);
  if (m) n = Number(m[1]);
  else if (branch.startsWith('godot/')) return null; // off-plan work
  else {
    const t = title.match(/\bstage\s+(\d+)\b/i);
    const id = title.match(/\b(\d+b?\.\d+)\b/)?.[1];
    if (t) n = Number(t[1]);
    else if (id) n = stageOfTask(data, id);
    else if (branch === MAIN_BRANCH) {
      const main = data.lanes.find((l) => l.kind === 'main');
      n = main ? laneStage(data, main) : null;
    }
  }
  return data.stages.some((s) => s.n === n) ? n : null;
}

// Sessions newest first in, same order out. Each lane goes to the newest
// session in its folder, or failing that the newest session on its stage.
export function attachStages(sessions, data) {
  const sorted = [...sessions].sort((a, b) => b.lastActive - a.lastActive);
  const views = sorted.map((s) => ({ ...s, stage: sessionStage(s, data), task: null, taskTitle: '', laneState: null }));
  const give = (v, lane) => Object.assign(v, { task: lane.task ?? null, taskTitle: lane.title ?? '', laneState: lane.state });
  const claimed = new Set();
  for (const lane of data.lanes) {
    const v = views.find((x) => norm(x.cwd) === norm(lane.path));
    if (v) { give(v, lane); claimed.add(lane); }
  }
  for (const lane of data.lanes) {
    if (claimed.has(lane) || lane.kind === 'offplan') continue;
    const n = laneStage(data, lane);
    const v = views.find((x) => x.stage === n && x.laneState == null && n != null);
    if (v) give(v, lane);
  }
  return views;
}

export function taskStates(stage, data) {
  const done = new Set(data.doneIds);
  const working = new Set(stage.working);
  const next = new Set(stage.next);
  return new Map(stage.tasks.map((id) => {
    const blockedBy = (data.blockers[id] ?? []).filter((b) => !done.has(b));
    const state = done.has(id) ? 'done' : working.has(id) ? 'working' : next.has(id) ? 'next' : blockedBy.length ? 'blocked' : 'rest';
    return [id, { state, blockedBy }];
  }));
}
```

The old main-checkout session in the second test keeps `laneState` null, because the main lane went to the newer session by folder. That is Review Focus line 2.

- [ ] **Step 3: Write the failing route tests** `tests/routes.test.mjs` (GET routes now; Task 8 adds the feedback cases)

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeRoutes } from '../routes.mjs';

const ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
async function serve(extra = {}) {
  let server;
  const repo = await mkdtemp(path.join(os.tmpdir(), 'repo-'));
  await mkdir(path.join(repo, 'docs/plans'), { recursive: true });
  await mkdir(path.join(repo, 'docs/specs'), { recursive: true });
  await writeFile(path.join(repo, 'docs/plans/godot-rebuild.md'), '- [ ] **7. Swings.**\n  - [ ] **7.1 Helpers.** x\n    - Blocked by: none · Stories: 1\n');
  await writeFile(path.join(repo, 'docs/specs/godot-rebuild.md'), '## User Stories\n\n1. [ ] As a player, I want it.\n');
  const data = { stages: [{ n: 7, name: 'Swings', full: 'Swings', tasks: ['7.1'], done: [], working: ['7.1'], next: [] }],
    lanes: [], blockers: {}, doneIds: [] };
  const handle = makeRoutes({
    here: path.dirname(path.dirname(fileURLToPath(import.meta.url))), repo, port: () => server.address().port,
    getData: async () => data,
    listSessions: async () => [{ id: ID, title: 'Stage 7', cwd: 'C:\\x', folder: 'x', branch: 'godot/stage-7-a', lastActive: 5, live: true }],
    feedbackDir: await mkdtemp(path.join(os.tmpdir(), 'fb-')),
    hookInstalled: async () => false,
    ...extra,
  });
  server = createServer(async (req, res) => { if (!(await handle(req, res))) { res.writeHead(418); res.end(); } });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { base, close: () => server.close() };
}

test('GET /api/sessions, /api/session/:id and /api/stage/:n', async (t) => {
  const s = await serve(); t.after(s.close);
  const list = await (await fetch(`${s.base}/api/sessions`)).json();
  assert.equal(list[0].stage, 7);
  assert.equal((await fetch(`${s.base}/api/session/${ID}`)).status, 200);
  assert.equal((await fetch(`${s.base}/api/session/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb`)).status, 404);
  const stage = await (await fetch(`${s.base}/api/stage/7`)).json();
  assert.equal(stage.tasks[0].state, 'working');
  assert.equal(stage.tasks[0].stories[0].n, 1);
  assert.equal((await fetch(`${s.base}/api/stage/99`)).status, 404);
});

test('session page and the renderer are served; other paths fall through', async (t) => {
  const s = await serve(); t.after(s.close);
  assert.match(await (await fetch(`${s.base}/session/${ID}`)).text(), /<html/);
  assert.match((await fetch(`${s.base}/markdown.mjs`)).headers.get('content-type'), /javascript/);
  assert.equal((await fetch(`${s.base}/data`)).status, 418);
});
```

Because `serve()` reads `session.html`, put a placeholder `tools/progress-dashboard/session.html` (`<!doctype html><html><body>Session</body></html>`) in this task. Task 7 replaces it.

- [ ] **Step 4: Write `routes.mjs`** (the GET part; Task 8 adds POST and the feedback GET)

```js
// /api/* and /session/* for the session tracker. Mounted by server.mjs before
// its own routes; returns false for anything it doesn't serve.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { attachStages, taskStates } from './stage.mjs';
import { stageDocs } from './docs.mjs';

const PLAN = 'docs/plans/godot-rebuild.md';
const SPEC = 'docs/specs/godot-rebuild.md';

function send(res, status, body, type = 'application/json') {
  res.writeHead(status, { 'content-type': type, 'cache-control': 'no-store' });
  res.end(type === 'application/json' ? JSON.stringify(body) : body);
}

export function makeRoutes(ctx) {
  async function sessions() {
    const [data, list] = await Promise.all([ctx.getData(), ctx.listSessions()]);
    return attachStages(list, data);
  }
  return async function handle(req, res) {
    const url = new URL(req.url, 'http://localhost');
    const p = url.pathname;
    let m;
    if (req.method === 'GET' && p === '/api/sessions') { send(res, 200, await sessions()); return true; }
    if (req.method === 'GET' && (m = p.match(/^\/api\/session\/([^/]+)$/))) {
      const s = (await sessions()).find((x) => x.id === m[1]);
      send(res, s ? 200 : 404, s ?? { error: 'no such session' });
      return true;
    }
    if (req.method === 'GET' && (m = p.match(/^\/api\/stage\/(\d+)$/))) {
      const data = await ctx.getData();
      const stage = data.stages.find((s) => s.n === Number(m[1]));
      if (!stage) { send(res, 404, { error: 'no such stage' }); return true; }
      const [plan, spec] = await Promise.all([PLAN, SPEC].map((f) => readFile(path.join(ctx.repo, f), 'utf8')));
      send(res, 200, stageDocs(plan, spec, stage, taskStates(stage, data)));
      return true;
    }
    if (req.method === 'GET' && /^\/session\/[^/]+$/.test(p)) {
      send(res, 200, await readFile(path.join(ctx.here, 'session.html')), 'text/html; charset=utf-8');
      return true;
    }
    if (req.method === 'GET' && p === '/markdown.mjs') {
      send(res, 200, await readFile(path.join(ctx.here, 'markdown.mjs')), 'text/javascript; charset=utf-8');
      return true;
    }
    return false;
  };
}
```

- [ ] **Step 5: Mount it in `server.mjs`.**
  - In `collect()`'s returned object, add `blockers,` and `doneIds: [...done].filter((id) => all.includes(id)),`.
  - At the top, add:

```js
import os from 'node:os';
import { makeRoutes } from './routes.mjs';
import { listSessions } from './sessions.mjs';
import { projectPrefix } from './repo.mjs';
```

  - After `data()`, add (Task 8 adds `feedbackDir` and `hookInstalled` to this object):

```js
const routes = makeRoutes({
  here: HERE, repo: REPO, port: PORT, getData: data,
  listSessions: () => listSessions({ projectsDir: path.join(os.homedir(), '.claude', 'projects'), prefix: projectPrefix(REPO) }),
});
```

  As the first line inside the `try` of the request handler, add `if (await routes(req, res)) return;`.

- [ ] **Step 6: Run all the tests and see them pass.** Then check live: `PORT=5198 node tools/progress-dashboard/server.mjs`, then `curl -s localhost:5198/api/sessions` (the stage 7 session should show stage 7) and `curl -s localhost:5198/api/stage/7` (15 tasks with markdown).

- [ ] **Step 7: Commit**: `git commit -m "Serve sessions with their stage and lane, and each stage's docs"`, then push.

---

### Task 6: Sessions section on the dashboard

- [ ] Done when: the dashboard lists the sessions as specified, and every row opens its session page.

**Files:**
- Modify: `tools/progress-dashboard/index.html`

**Interfaces:**
- Consumes: `GET /api/sessions` (`SessionView[]`)

- [ ] **Step 1: Colours.** Change `--next` to teal in all three token blocks (`#0f9fb0` light, `#22b5c6` dark). Add `--working-glow: rgba(27,175,122,.55)`, and set `--working: #1baf7a` (light) / `#199e70` (dark), so working is green as the spec says. Change the legend text to match.

- [ ] **Step 2: Markup.** Above `<h2>Lanes</h2>`, add:

```html
<h2>Sessions</h2>
<section class="sessions" id="sessions"></section>
<details class="earlier" id="earlier"><summary id="earlier-sum"></summary><section class="sessions" id="sessions-old"></section></details>
```

- [ ] **Step 3: Styles**

```css
.sessions { display: grid; gap: 6px; }
.sess { display: grid; grid-template-columns: 14px minmax(0, 1fr) auto; gap: 4px 10px; align-items: center; padding: 8px 12px; background: var(--card); border: 1px solid var(--border); border-radius: 8px; color: inherit; text-decoration: none; }
.sess:hover { border-color: var(--border-strong); }
.sess .t { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sess .m { grid-column: 2 / -1; font-size: 12px; color: var(--text-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sess .ago { font-size: 12px; color: var(--muted); font-variant-numeric: tabular-nums; }
.chip { font-size: 11px; padding: 1px 6px; border-radius: 999px; background: var(--surface); margin-right: 6px; }
.dot { width: 9px; height: 9px; border-radius: 50%; background: var(--rest); }
.dot.live { background: var(--working); animation: pulse 1.2s ease-in-out infinite; }
@keyframes pulse { 0%,100% { box-shadow: 0 0 0 0 var(--working-glow); } 50% { box-shadow: 0 0 0 5px transparent; } }
@media (prefers-reduced-motion: reduce) { .dot.live { animation: none; box-shadow: 0 0 0 2px var(--working-glow); } }
.earlier { margin-top: 8px; } .earlier summary { cursor: pointer; font-size: 13px; color: var(--text-2); padding: 4px 0; }
```

- [ ] **Step 4: Script.** Add this to the page script and call `refreshSessions()` from `refresh()`:

```js
const DAY = 864e5;
const STATE_CLS = { working: 'working', next: 'next', blocked: 'blocked', finished: 'done', offplan: 'working', idle: 'rest' };
function sessRow(s) {
  const task = s.task ? `<span class="sw ${STATE_CLS[s.laneState] ?? 'rest'}"></span> ${esc(s.task)} ${esc(s.taskTitle)}` : '';
  return `<a class="sess" href="/session/${encodeURIComponent(s.id)}">
    <i class="dot${s.live ? ' live' : ''}" title="${s.live ? 'Live' : 'Not live'}"></i>
    <span class="t" title="${esc(s.title)}">${esc(s.title)}</span>
    <span class="ago">${esc(ago(s.lastActive / 1000))}</span>
    <span class="m">${s.stage != null ? `<span class="chip">Stage ${s.stage}</span>` : ''}${task}${task ? ' · ' : ''}${esc(s.branch ?? '')}</span></a>`;
}
async function refreshSessions() {
  const list = await (await fetch('/api/sessions', { cache: 'no-store' })).json();
  const recent = list.filter((s) => Date.now() - s.lastActive < DAY);
  const old = list.filter((s) => Date.now() - s.lastActive >= DAY);
  $('sessions').innerHTML = recent.map(sessRow).join('') || '<div class="others">No sessions in the last day.</div>';
  $('sessions-old').innerHTML = old.map(sessRow).join('');
  $('earlier').hidden = !old.length;
  $('earlier-sum').textContent = `Earlier (${old.length})`;
}
try { $('earlier').open = localStorage.getItem('earlierOpen') === '1'; } catch {}
$('earlier').addEventListener('toggle', () => { try { localStorage.setItem('earlierOpen', $('earlier').open ? '1' : '0'); } catch {} });
```

- [ ] **Step 5: Check it in the Browser pane** at `http://localhost:5198`:
  - the Sessions list shows the real sessions, with this one live and pulsing;
  - "Earlier" opens, closes and is remembered across a reload;
  - the stage chips and the lane task look right for the stage 7 session;
  - take shots at 1280 px and 375 px, in light and dark.

  There are no unit tests for the page itself.

- [ ] **Step 6: Commit**: `git commit -m "List Claude Code sessions on the dashboard; working is green, next is teal"`, then push.

---

### Task 7: The session page: header, stage picker, task tiles and docs

- [ ] Done when: `/session/<id>` shows the stage's tiles and docs, the current task pulses green, the tiles link to their sections, and a refresh keeps the scroll position.

**Files:**
- Modify (replace the placeholder): `tools/progress-dashboard/session.html`

**Interfaces:**
- Consumes: `GET /api/session/:id`, `GET /api/stage/:n`, `GET /data` (stage list for the picker), `/markdown.mjs` (`renderMarkdown`)
- Produces, for Task 9: `<section class="task" id="task-<id>" data-task="<id>">` holding a `.doc` element with the rendered markdown and stories; `window.onDocsRendered` hooks (a list of callbacks run after docs are rebuilt)

- [ ] **Step 1: Page skeleton.** Copy the `:root` token blocks from `index.html` (with Task 6's colours), the `body` and `main` base styles, and `esc()`/`ago()`. Then:

```html
<header class="top">
  <a href="/" class="back">← Dashboard</a>
  <h1 id="title">Loading…</h1>
  <div class="meta" id="meta"></div>
  <label class="pick">Stage <select id="stage-pick"></select></label>
</header>
<nav class="tiles" id="tiles" aria-label="Tasks in this stage"></nav>
<div class="layout">
  <article class="docs" id="docs"></article>
  <aside class="side" id="side"></aside>
</div>
<script type="module">
import { renderMarkdown, escapeHtml as esc } from '/markdown.mjs';
// ... Steps 3-5
</script>
```

- [ ] **Step 2: Styles for tiles and layout**

```css
.tiles { display: flex; flex-wrap: wrap; gap: 6px; margin: 14px 0 18px; }
.tile { display: block; min-width: 0; width: 132px; padding: 6px 8px; border-radius: 8px; border: 1px solid var(--border-strong); background: var(--card); color: var(--text); text-decoration: none; font-size: 12px; line-height: 1.3; }
.tile .id { font-weight: 600; font-variant-numeric: tabular-nums; }
.tile .tt { display: block; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--text-2); }
.tile.done { background: var(--done); border-color: var(--done); color: #fff; } .tile.done .tt { color: rgba(255,255,255,.85); }
.tile.done .id::after { content: " ✓"; }
.tile.working { background: var(--working); border-color: var(--working); color: #fff; animation: flash 1.2s ease-in-out infinite; } .tile.working .tt { color: rgba(255,255,255,.9); }
.tile.next { border: 2px solid var(--next); }
.tile.blocked { background: var(--surface); color: var(--muted); border-style: dashed; }
@keyframes flash { 0%,100% { box-shadow: 0 0 0 0 var(--working-glow); filter: brightness(1); } 50% { box-shadow: 0 0 0 6px transparent; filter: brightness(1.18); } }
@media (prefers-reduced-motion: reduce) { .tile.working { animation: none; box-shadow: 0 0 0 3px var(--working-glow); } }
.layout { display: grid; grid-template-columns: minmax(0, 1fr); gap: 18px; }
@media (min-width: 900px) { .layout.with-side { grid-template-columns: minmax(0, 1fr) 320px; } }
.task { scroll-margin-top: 12px; border-top: 1px solid var(--border); padding: 12px 0; }
.task.flash { animation: hl 1.5s ease-out; }
@keyframes hl { from { background: var(--working-glow); } to { background: transparent; } }
.badge { font-size: 11px; padding: 1px 7px; border-radius: 999px; margin-left: 8px; vertical-align: 2px; }
.doc ul { padding-left: 20px; margin: 4px 0; } .doc code { font-size: 12.5px; background: var(--surface); padding: 0 3px; border-radius: 3px; }
.stories { font-size: 13px; color: var(--text-2); margin-top: 6px; }
main { max-width: 1200px; }
```

- [ ] **Step 3: Load and render**

```js
const id = location.pathname.split('/').pop();
const params = new URLSearchParams(location.search);
let session = null, stageNo = null, lastDocsKey = '';
const LABEL = { done: 'Done', working: 'Being worked on', next: 'Next up', blocked: 'Blocked', rest: 'Not started' };

function tiles(stage) {
  return stage.tasks.map((t) => {
    const tip = `${t.id} ${t.title} — ${LABEL[t.state]}${t.blockedBy.length ? ` (waits for ${t.blockedBy.join(', ')})` : ''}`;
    return `<a class="tile ${t.state}" href="#task-${t.id}" title="${esc(tip)}"><span class="id">${esc(t.id)}</span><span class="tt">${esc(t.title)}</span></a>`;
  }).join('');
}
function docs(stage) {
  const parents = stage.parents.map((p) => `<section class="parent doc">${renderMarkdown(p.markdown)}</section>`).join('');
  return parents + stage.tasks.map((t) => `<section class="task" id="task-${esc(t.id)}" data-task="${esc(t.id)}">
    <h2>${esc(t.id)} ${esc(t.title)}<span class="badge sw-${t.state}" data-badge>${LABEL[t.state]}</span></h2>
    <div class="doc">${renderMarkdown(t.markdown)}${t.stories.length ? `<div class="stories"><strong>Stories</strong><ul>${t.stories.map((s) => `<li>${s.done ? '✓' : '○'} ${s.n}. ${esc(s.text)}</li>`).join('')}</ul></div>` : ''}</div></section>`).join('');
}
window.onDocsRendered = [];
async function load() {
  session = await (await fetch(`/api/session/${id}`, { cache: 'no-store' })).json();
  $('title').textContent = session.title ?? 'Unknown session';
  document.title = `${session.title ?? 'Session'} · Sessions`;
  $('meta').textContent = `${session.branch ?? ''} · ${session.folder ?? ''} · ${session.live ? 'live' : `last active ${ago(session.lastActive / 1000)}`}`;
  stageNo = params.has('stage') ? Number(params.get('stage')) : session.stage;
  if (stageNo == null) { $('tiles').innerHTML = ''; $('docs').innerHTML = '<p class="muted">No stage — pick one above.</p>'; return; }
  const stage = await (await fetch(`/api/stage/${stageNo}`, { cache: 'no-store' })).json();
  $('tiles').innerHTML = tiles(stage);
  const key = JSON.stringify(stage.tasks.map((t) => [t.id, t.markdown, t.stories])) + JSON.stringify(stage.parents);
  if (key !== lastDocsKey) {
    const y = scrollY;
    $('docs').innerHTML = docs(stage);
    lastDocsKey = key;
    scrollTo(0, y);
    for (const f of window.onDocsRendered) f();
  } else {
    for (const t of stage.tasks) {
      const b = document.querySelector(`#task-${CSS.escape(t.id)} [data-badge]`);
      if (b) { b.textContent = LABEL[t.state]; b.className = `badge sw-${t.state}`; }
    }
  }
}
```

(`$` is `(id) => document.getElementById(id)`. Give `.badge.sw-done/working/next/blocked/rest` the same colours as the tiles.)

- [ ] **Step 4: Stage picker, hash jumps, refresh**

```js
async function fillPicker() {
  const d = await (await fetch('/data', { cache: 'no-store' })).json();
  $('stage-pick').innerHTML = `<option value="">No stage</option>` + d.stages.map((s) => `<option value="${s.n}">${s.n}. ${esc(s.name)}</option>`).join('');
  $('stage-pick').value = stageNo ?? '';
}
$('stage-pick').addEventListener('change', (e) => {
  const v = e.target.value;
  if (v) params.set('stage', v); else params.delete('stage');
  history.replaceState(null, '', `${location.pathname}?${params}`);
  lastDocsKey = '';
  load();
});
function jump() {
  const el = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)));
  if (!el) return;
  el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash');
}
addEventListener('hashchange', jump);
await load(); await fillPicker(); jump();
setInterval(() => load().catch(() => {}), 10000);
```

(Tile links are plain `#task-…` hrefs, so a click sets the hash and fires `hashchange`. Clicking the same tile twice doesn't change the hash, so also add a click listener on `#tiles` that calls `jump()` when `e.target.closest('.tile').hash === location.hash`.)

- [ ] **Step 5: Check it in the Browser pane** at `/session/<stage-7-session-id>`:
  - stage 7's 15 tiles show, with 7.1–7.12 blue and ticked, 7.13 pulsing green or teal depending on its lane state, and the blocked tiles grey;
  - clicking a tile scrolls to and flashes its section, and the URL shows `#task-7.13`;
  - reloading with the hash lands on that section;
  - the picker switches to stage 8, and `?stage=8` survives a reload;
  - the page for a no-stage session (this one) shows the picker prompt;
  - after scrolling, waiting 10 s doesn't move the page;
  - shots at 1280 px and 375 px, in light and dark.

- [ ] **Step 6: Commit**: `git commit -m "Add a page per session with the stage's task tiles and docs"`, then push.

---

### Task 8: The feedback queue and its routes

- [ ] Done when: feedback can be queued, listed and taken. Locks hold under two writers, and POSTs from another origin are refused.

**Files:**
- Create: `tools/progress-dashboard/feedback.mjs`, `tools/progress-dashboard/tests/feedback.test.mjs`
- Modify: `tools/progress-dashboard/routes.mjs` (POST and GET feedback), `tools/progress-dashboard/tests/routes.test.mjs`, `tools/progress-dashboard/server.mjs` (use the real `feedbackDir`)

**Interfaces:**
- Produces:
  - `SESSION_ID: RegExp`
  - `feedbackDir(env?): string`
  - `withLock(dir, id, fn, opts?)`
  - `queueFeedback(dir, id, {stage, stageName, notes, message}, now?): Promise<Item>`
  - `readFeedback(dir, id): Promise<Item[]>` (newest first)
  - `takeQueued(dir, id, via, now?): Promise<Item[]>`
  - `formatFeedback(items): string`
  - in routes: `allowedOrigin(headers, port): boolean` and `cleanFeedback(body): {stage, stageName, notes, message}|null`
- `Item = { id, created, stage, stageName, notes: [{task, quote, note}], message, status: 'queued'|'delivered', delivered, via }`. `stageName` lets the hook name the stage without reading the plan.

- [ ] **Step 1: Write the failing tests** `tests/feedback.test.mjs`

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, utimes, readFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { queueFeedback, readFeedback, takeQueued, withLock, formatFeedback } from '../feedback.mjs';

const ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const dir = () => mkdtemp(path.join(os.tmpdir(), 'fb-'));
const note = { task: '7.13', quote: 'first_contact()', note: 'Report depth too.' };

test('queue, read newest first, take once', async () => {
  const d = await dir();
  await queueFeedback(d, ID, { stage: 7, stageName: 'Swing foundations', notes: [note], message: '' }, 1000);
  await queueFeedback(d, ID, { stage: 7, stageName: 'Swing foundations', notes: [], message: 'Answer first.' }, 2000);
  assert.deepEqual((await readFeedback(d, ID)).map((i) => i.message), ['Answer first.', '']);
  const taken = await takeQueued(d, ID, 'stop', 3000);
  assert.equal(taken.length, 2);
  assert.ok((await readFeedback(d, ID)).every((i) => i.status === 'delivered' && i.via === 'stop'));
  assert.deepEqual(await takeQueued(d, ID, 'stop'), []);
});

test('bad session ids never reach the file system', async () => {
  const d = await dir();
  await assert.rejects(queueFeedback(d, '../../etc/passwd', { message: 'x' }), /bad session id/);
  await assert.rejects(readFeedback(d, 'x'), /bad session id/);
});

test('takeQueued with no queue file does nothing and makes no folder', async () => {
  const d = path.join(os.tmpdir(), `fb-none-${Date.now()}`);
  assert.deepEqual(await takeQueued(d, ID, 'prompt'), []);
});

test('two writers at once: nothing lost, nothing delivered twice', async () => {
  const d = await dir();
  await Promise.all(Array.from({ length: 20 }, (_, i) => queueFeedback(d, ID, { message: `m${i}` })));
  const [a, b] = await Promise.all([takeQueued(d, ID, 'stop'), takeQueued(d, ID, 'prompt')]);
  assert.equal(a.length + b.length, 20);
  assert.equal((await readFeedback(d, ID)).length, 20);
});

test('a stale lock is removed; a fresh one times out', async () => {
  const d = await dir();
  const lock = path.join(d, `${ID}.lock`);
  await writeFile(lock, '');
  const old = new Date(Date.now() - 60e3);
  await utimes(lock, old, old);
  assert.equal(await withLock(d, ID, async () => 'ran'), 'ran');
  await writeFile(lock, '');
  await assert.rejects(withLock(d, ID, async () => 'no', { waitMs: 100 }), /locked/);
});

test('formatFeedback matches the spec', () => {
  const text = formatFeedback([{ stage: 7, stageName: 'Swing foundations', notes: [note], message: 'Answer first.' }]);
  assert.equal(text, 'Feedback from the owner, sent from the progress dashboard while viewing Stage 7 (Swing foundations):\n\n' +
    'Notes on the docs:\n- [7.13] "first_contact()" -> Report depth too.\n\nMessage:\nAnswer first.');
});
```

- [ ] **Step 2: Write `feedback.mjs`**

```js
// The feedback queue: one JSON-lines file per session in ~/.claude/session-feedback,
// appended by the dashboard and marked delivered by the hook, both under a lock file.
import { appendFile, mkdir, open, readFile, stat, unlink, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

export const SESSION_ID = /^[0-9a-f-]{36}$/;

export function feedbackDir(env = process.env) {
  return env.SESSION_FEEDBACK_DIR || path.join(os.homedir(), '.claude', 'session-feedback');
}

function fileOf(dir, id) {
  if (!SESSION_ID.test(String(id))) throw new Error(`bad session id: ${id}`);
  return path.join(dir, `${id}.jsonl`);
}

export async function withLock(dir, id, fn, { waitMs = 2000, staleMs = 10000 } = {}) {
  fileOf(dir, id);
  await mkdir(dir, { recursive: true });
  const lock = path.join(dir, `${id}.lock`);
  const start = Date.now();
  for (;;) {
    try { await (await open(lock, 'wx')).close(); break; } catch (e) {
      if (e.code !== 'EEXIST') throw e;
      const age = await stat(lock).then((s) => Date.now() - s.mtimeMs, () => 0);
      if (age > staleMs) { await unlink(lock).catch(() => {}); continue; }
      if (Date.now() - start > waitMs) throw new Error('feedback queue is locked');
      await new Promise((r) => setTimeout(r, 20));
    }
  }
  try { return await fn(); } finally { await unlink(lock).catch(() => {}); }
}

async function readItems(file) {
  let text;
  try { text = await readFile(file, 'utf8'); } catch (e) { if (e.code === 'ENOENT') return []; throw e; }
  return text.split('\n').filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
}

export async function queueFeedback(dir, id, { stage = null, stageName = '', notes = [], message = '' }, now = Date.now()) {
  const file = fileOf(dir, id);
  const item = {
    id: `${now}-${Math.random().toString(36).slice(2, 8)}`, created: new Date(now).toISOString(),
    stage, stageName, notes, message, status: 'queued', delivered: null, via: null,
  };
  await withLock(dir, id, () => appendFile(file, JSON.stringify(item) + '\n'));
  return item;
}

export async function readFeedback(dir, id) {
  return (await readItems(fileOf(dir, id))).reverse();
}

export async function takeQueued(dir, id, via, now = Date.now()) {
  const file = fileOf(dir, id);
  if (!(await stat(file).then(() => true, () => false))) return [];
  return withLock(dir, id, async () => {
    const items = await readItems(file);
    const taken = items.filter((i) => i.status === 'queued');
    if (!taken.length) return [];
    for (const i of taken) Object.assign(i, { status: 'delivered', delivered: new Date(now).toISOString(), via });
    await writeFile(file, items.map((i) => JSON.stringify(i)).join('\n') + '\n');
    return taken;
  });
}

export function formatFeedback(items) {
  const where = [...new Set(items.map((i) => (i.stage == null ? 'no stage' : `Stage ${i.stage}${i.stageName ? ` (${i.stageName})` : ''}`)))];
  let out = `Feedback from the owner, sent from the progress dashboard while viewing ${where.join(' and ')}:\n`;
  const notes = items.flatMap((i) => i.notes ?? []);
  if (notes.length) out += `\nNotes on the docs:\n${notes.map((n) => `- [${n.task}] "${n.quote}" -> ${n.note}`).join('\n')}\n`;
  const msgs = items.map((i) => i.message?.trim()).filter(Boolean);
  if (msgs.length) out += `\nMessage:\n${msgs.join('\n\n')}\n`;
  return out.trimEnd();
}
```

- [ ] **Step 3: Add the route tests** to `tests/routes.test.mjs`

```js
const post = (s, id, body, origin) => fetch(`${s.base}/api/feedback/${id}`, {
  method: 'POST', body: typeof body === 'string' ? body : JSON.stringify(body),
  headers: { 'content-type': 'application/json', ...(origin ? { origin } : {}) },
});

test('POST /api/feedback checks the origin, the body and the session', async (t) => {
  const s = await serve(); t.after(s.close);
  const here = s.base.replace('127.0.0.1', 'localhost');
  const good = { stage: 7, stageName: 'Swings', notes: [{ task: '7.1', quote: 'x', note: 'y' }], message: '' };
  assert.equal((await post(s, ID, good)).status, 403);
  assert.equal((await post(s, ID, good, 'https://evil.example')).status, 403);
  assert.equal((await post(s, ID, good, here)).status, 200);
  assert.equal((await post(s, ID, good, s.base)).status, 200);
  assert.equal((await post(s, ID, '{bad', here)).status, 400);
  assert.equal((await post(s, ID, { notes: [], message: '  ' }, here)).status, 400);
  assert.equal((await post(s, ID, { message: 'x'.repeat(70000) }, here)).status, 400);
  assert.equal((await post(s, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', good, here)).status, 404);
  const items = await (await fetch(`${s.base}/api/feedback/${ID}`)).json();
  assert.equal(items.items.length, 2);
  assert.equal(items.hookInstalled, false);
});
```

`serve()` passes `port` as a getter (the test server listens on port 0), so the route resolves it with `typeof ctx.port === 'function' ? ctx.port() : ctx.port`.

- [ ] **Step 4: Add to `routes.mjs`**

```js
import { queueFeedback, readFeedback, SESSION_ID } from './feedback.mjs';
const LIMIT = 64 << 10;

export function allowedOrigin(headers, port) {
  let o = headers.origin;
  if (!o && headers.referer) { try { o = new URL(headers.referer).origin; } catch { o = null; } }
  return o === `http://localhost:${port}` || o === `http://127.0.0.1:${port}`;
}

export function cleanFeedback(body) {
  if (!body || typeof body !== 'object') return null;
  const str = (v, max) => (typeof v === 'string' ? v.slice(0, max) : '');
  const notes = (Array.isArray(body.notes) ? body.notes : [])
    .map((n) => ({ task: str(n?.task, 20), quote: str(n?.quote, 300), note: str(n?.note, 4000).trim() }))
    .filter((n) => n.note);
  const message = str(body.message, 20000).trim();
  if (!notes.length && !message) return null;
  return { stage: Number.isInteger(body.stage) ? body.stage : null, stageName: str(body.stageName, 120), notes, message };
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    // Read past the limit without keeping it, so the client still gets its 400.
    let size = 0; const chunks = [];
    req.on('data', (c) => { size += c.length; if (size <= LIMIT) chunks.push(c); });
    req.on('end', () => (size > LIMIT ? reject(new Error('too big')) : resolve(Buffer.concat(chunks).toString('utf8'))));
    req.on('error', reject);
  });
}
```

Inside `handle`, before `return false`:

```js
if ((m = p.match(/^\/api\/feedback\/([^/]+)$/))) {
  const sid = m[1];
  if (!SESSION_ID.test(sid) || !(await sessions()).some((x) => x.id === sid)) { send(res, 404, { error: 'no such session' }); return true; }
  if (req.method === 'GET') {
    send(res, 200, { items: await readFeedback(ctx.feedbackDir, sid), hookInstalled: await ctx.hookInstalled() });
    return true;
  }
  if (req.method === 'POST') {
    const port = typeof ctx.port === 'function' ? ctx.port() : ctx.port;
    if (!allowedOrigin(req.headers, port)) { send(res, 403, { error: 'origin not allowed' }); return true; }
    let body;
    try { body = cleanFeedback(JSON.parse(await readBody(req))); } catch { body = null; }
    if (!body) { send(res, 400, { error: 'send notes or a message (under 64 KB)' }); return true; }
    send(res, 200, await queueFeedback(ctx.feedbackDir, sid, body));
    return true;
  }
}
```

- [ ] **Step 5: In `server.mjs`,** add `import { feedbackDir } from './feedback.mjs';` and `stat` to the `node:fs/promises` import, then add to the `makeRoutes({...})` object:

```js
  feedbackDir: feedbackDir(),
  hookInstalled: () => stat(path.join(os.homedir(), '.claude', 'hooks', 'session-feedback', 'feedback-hook.mjs')).then(() => true, () => false),
```

- [ ] **Step 6: Run all the tests and see them pass.** Mutation check: with `allowedOrigin` always returning true, the 403 asserts must fail; with `takeQueued` not filtering on `status`, the "take once" test must fail.

- [ ] **Step 7: Commit**: `git commit -m "Queue feedback per session, refusing other origins"`, then push.

---

### Task 9: The feedback sidebar

- [ ] Done when: you can highlight text, add a note, write a message and send, drafts survive a reload, and the Sent list shows each item's status.

**Files:**
- Modify: `tools/progress-dashboard/session.html`

**Interfaces:**
- Consumes: Task 7's `section.task[data-task] .doc` and `window.onDocsRendered`; `GET/POST /api/feedback/:id` (`{items, hookInstalled}` / `Item`)

- [ ] **Step 1: Sidebar markup** inside `<aside id="side">`, plus a toggle in the header (`<button id="fb-toggle">Feedback</button>`):

```html
<div class="fb" id="fb" hidden>
  <div class="warn" id="fb-warn" hidden>The feedback hook isn't installed, so feedback will queue but not arrive. Run <code>node tools/progress-dashboard/install-hook.mjs</code>.</div>
  <h3>Notes</h3><div id="fb-notes"><p class="hint">Select text in the docs to add a note.</p></div>
  <h3>Message</h3><textarea id="fb-msg" rows="5" placeholder="Overall feedback for this session (optional)"></textarea>
  <button id="fb-send" disabled>Send to session</button> <span id="fb-err" class="err"></span>
  <h3>Sent</h3><div id="fb-idle" class="hint" hidden>This session is idle. It gets this with your next message to it.</div><ol id="fb-sent"></ol>
</div>
<button id="add-note" class="add-note" hidden>Add note</button>
```

Toggling adds or removes `with-side` on `.layout`, flips `#fb`'s `hidden` and is remembered in `localStorage` (`fbOpen`). The toggle label shows the draft count: `Feedback (2)`.

- [ ] **Step 2: Draft state and storage**

```js
const KEY = `fb-draft-${id}`;
let draft = { notes: [], message: '' }; // notes: [{ id, task, quote, offset, note }]
try { draft = JSON.parse(localStorage.getItem(KEY)) ?? draft; } catch {}
const save = () => { try { localStorage.setItem(KEY, JSON.stringify(draft)); } catch {} updateSend(); };
function updateSend() {
  $('fb-send').disabled = !(draft.notes.some((n) => n.note.trim()) || draft.message.trim());
  $('fb-toggle').textContent = draft.notes.length ? `Feedback (${draft.notes.length})` : 'Feedback';
}
```

- [ ] **Step 3: Selection to note.** Offsets are counted in the section's `.doc` text, so a highlight can be found again after a rebuild.

```js
function textOffset(root, node, off) {
  const r = document.createRange(); r.setStart(root, 0); r.setEnd(node, off); return r.toString().length;
}
function sectionOf(node) { return (node.nodeType === 1 ? node : node.parentElement)?.closest('section.task .doc'); }
document.addEventListener('selectionchange', () => {
  const sel = getSelection(); const btn = $('add-note');
  if (!sel.rangeCount || sel.isCollapsed) { btn.hidden = true; return; }
  const r = sel.getRangeAt(0);
  const a = sectionOf(r.startContainer), b = sectionOf(r.endContainer);
  if (!a || a !== b || !r.toString().trim()) { btn.hidden = true; return; }
  const box = r.getBoundingClientRect();
  Object.assign(btn.style, { position: 'fixed', top: `${Math.max(8, box.top - 34)}px`, left: `${Math.min(innerWidth - 100, box.left)}px` });
  btn.hidden = false;
});
$('add-note').addEventListener('mousedown', (e) => e.preventDefault()); // keep the selection
$('add-note').addEventListener('click', () => {
  const r = getSelection().getRangeAt(0); const doc = sectionOf(r.startContainer);
  const n = { id: `n${Date.now()}`, task: doc.closest('section.task').dataset.task,
    quote: r.toString().trim().slice(0, 300), offset: textOffset(doc, r.startContainer, r.startOffset), note: '' };
  draft.notes.push(n); save(); getSelection().removeAllRanges(); $('add-note').hidden = true;
  openSidebar(); paintMarks(); renderNotes(); document.querySelector(`[data-note-card="${n.id}"] textarea`)?.focus();
});
```

- [ ] **Step 4: Marks that survive rebuilds**

```js
function markRange(root, start, end, noteId) {
  const walk = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let pos = 0; const parts = [];
  for (let n = walk.nextNode(); n; n = walk.nextNode()) {
    const len = n.data.length, a = Math.max(start, pos), b = Math.min(end, pos + len);
    if (a < b) parts.push([n, a - pos, b - pos]);
    pos += len;
  }
  for (const [n, a, b] of parts) {
    const mid = n.splitText(a); mid.splitText(b - a);
    const m = document.createElement('mark'); m.dataset.note = noteId; mid.replaceWith(m); m.append(mid);
  }
  return parts.length > 0;
}
function paintMarks() {
  document.querySelectorAll('mark[data-note]').forEach((m) => m.replaceWith(...m.childNodes));
  document.querySelectorAll('section.task .doc').forEach((d) => d.normalize());
  for (const n of draft.notes) {
    const doc = document.querySelector(`section.task[data-task="${CSS.escape(n.task)}"] .doc`);
    const text = doc?.textContent ?? '';
    let at = text.indexOf(n.quote, n.offset); if (at < 0) at = text.indexOf(n.quote);
    n.lost = !doc || at < 0;
    if (!n.lost) markRange(doc, at, at + n.quote.length, n.id);
  }
}
window.onDocsRendered.push(() => { paintMarks(); renderNotes(); });
```

(`n.quote` is the trimmed selection, so `indexOf` finds it in the section's text. A quote that crosses an element boundary still matches, because `textContent` flattens it.)

- [ ] **Step 5: Note cards, message, send, sent list**

```js
function renderNotes() {
  $('fb-notes').innerHTML = draft.notes.length ? draft.notes.map((n) => `<div class="card" data-note-card="${n.id}">
      <div class="q"><b>${esc(n.task)}</b> “${esc(n.quote)}”${n.lost ? ' <span class="err">passage changed</span>' : ''}</div>
      <textarea rows="3" placeholder="Your note">${esc(n.note)}</textarea>
      <button class="rm" title="Remove note">Remove</button></div>`).join('')
    : '<p class="hint">Select text in the docs to add a note.</p>';
}
$('fb-notes').addEventListener('input', (e) => {
  const card = e.target.closest('[data-note-card]'); const n = draft.notes.find((x) => x.id === card.dataset.noteCard);
  n.note = e.target.value; save();
});
$('fb-notes').addEventListener('click', (e) => {
  const card = e.target.closest('[data-note-card]'); if (!card) return;
  if (e.target.matches('.rm')) { draft.notes = draft.notes.filter((x) => x.id !== card.dataset.noteCard); save(); paintMarks(); renderNotes(); return; }
  if (!e.target.matches('textarea')) document.querySelector(`mark[data-note="${card.dataset.noteCard}"]`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
});
$('fb-msg').value = draft.message;
$('fb-msg').addEventListener('input', (e) => { draft.message = e.target.value; save(); });
$('fb-send').addEventListener('click', async () => {
  $('fb-err').textContent = ''; $('fb-send').disabled = true;
  const stageName = $('stage-pick').selectedOptions[0]?.textContent.replace(/^\d+\.\s*/, '') ?? '';
  try {
    const res = await fetch(`/api/feedback/${id}`, { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ stage: stageNo, stageName, notes: draft.notes.map(({ task, quote, note }) => ({ task, quote, note })), message: draft.message }) });
    if (!res.ok) throw new Error((await res.json()).error ?? res.statusText);
    draft = { notes: [], message: '' }; save(); $('fb-msg').value = ''; paintMarks(); renderNotes(); await loadSent();
  } catch (err) { $('fb-err').textContent = `Not sent: ${err.message}`; updateSend(); }
});
async function loadSent() {
  const { items, hookInstalled } = await (await fetch(`/api/feedback/${id}`, { cache: 'no-store' })).json();
  $('fb-warn').hidden = hookInstalled;
  $('fb-idle').hidden = !(items.some((i) => i.status === 'queued') && !session?.live);
  $('fb-sent').innerHTML = items.map((i) => {
    const status = i.status === 'queued' ? 'Queued'
      : `Delivered (${i.via === 'stop' ? 'end of turn' : 'with your prompt'}) ${new Date(i.delivered).toLocaleTimeString()}`;
    const preview = i.message || i.notes.map((n) => `[${n.task}] ${n.note}`).join(' · ');
    return `<li><span class="when">${new Date(i.created).toLocaleTimeString()}</span> <span class="st ${i.status}">${esc(status)}</span><div class="pv">${esc(preview.slice(0, 140))}</div></li>`;
  }).join('');
}
```

Call `paintMarks(); renderNotes(); updateSend(); loadSent();` after the first `load()`, and `loadSent()` in the 10 s refresh.

- [ ] **Step 6: Check it in the Browser pane:**
  - select part of a 7.13 Check line, then Add note: the passage is highlighted and a card appears with the quote;
  - type a note, reload: the note and highlight are back;
  - a selection across two task sections shows no button;
  - Send gives a new "Queued" item in Sent and clears the draft;
  - `curl` the queue file under `~/.claude/session-feedback/` to see the item;
  - narrow to 375 px: the sidebar sits below the docs with no sideways scroll.

  Use this session's page for the Send test, so the delivery check in Task 11 has an item ready.

- [ ] **Step 7: Commit**: `git commit -m "Add the feedback sidebar: highlight, note, message, send"`, then push.

---

### Task 10: The delivery hook and its installer

- [ ] Done when: the hook's output matches the spec for both events, and install/uninstall keep every other setting.

**Files:**
- Create: `tools/progress-dashboard/feedback-hook.mjs`, `tools/progress-dashboard/install-hook.mjs`
- Create: `tools/progress-dashboard/tests/hook.test.mjs`, `tools/progress-dashboard/tests/install.test.mjs`

**Interfaces:**
- Consumes: `feedbackDir`, `takeQueued`, `formatFeedback`, `SESSION_ID` from `feedback.mjs`
- Produces:
  - `runHook(input: string, {dir, now}): Promise<string>`, which gives the stdout text, `''` for none
  - `install({home, from}): Promise<{changed}>` and `uninstall({home}): Promise<{changed}>`
  - `hookDir(home)` and `hookCommand(home)`

- [ ] **Step 1: Write the failing tests** `tests/hook.test.mjs`

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runHook } from '../feedback-hook.mjs';
import { queueFeedback, readFeedback } from '../feedback.mjs';

const ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const HOOK = path.join(path.dirname(path.dirname(fileURLToPath(import.meta.url))), 'feedback-hook.mjs');
const input = (event) => JSON.stringify({ session_id: ID, hook_event_name: event, stop_hook_active: false });

test('nothing queued: no output', async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'hook-'));
  assert.equal(await runHook(input('Stop'), { dir }), '');
});

test('Stop blocks with the feedback once; the second Stop is silent', async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'hook-'));
  await queueFeedback(dir, ID, { stage: 7, stageName: 'Swing foundations', message: 'Answer first.' });
  const out = JSON.parse(await runHook(input('Stop'), { dir }));
  assert.equal(out.decision, 'block');
  assert.match(out.reason, /^Feedback from the owner.*Stage 7 \(Swing foundations\)[\s\S]*Answer first\.$/);
  assert.equal((await readFeedback(dir, ID))[0].via, 'stop');
  assert.equal(await runHook(input('Stop'), { dir }), '');
});

test('UserPromptSubmit adds context', async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'hook-'));
  await queueFeedback(dir, ID, { message: 'Hi' });
  const out = JSON.parse(await runHook(input('UserPromptSubmit'), { dir }));
  assert.equal(out.hookSpecificOutput.hookEventName, 'UserPromptSubmit');
  assert.match(out.hookSpecificOutput.additionalContext, /Hi$/);
});

test('as a process: bad stdin is logged, no output, exit 0', async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'hook-'));
  const child = execFile(process.execPath, [HOOK], { env: { ...process.env, SESSION_FEEDBACK_DIR: dir } });
  child.stdin.end('{not json');
  const [code, stdout] = await new Promise((r) => { let o = ''; child.stdout.on('data', (d) => (o += d)); child.on('close', (c) => r([c, o])); });
  assert.equal(code, 0);
  assert.equal(stdout, '');
  assert.match(await readFile(path.join(dir, 'hook-errors.log'), 'utf8'), /JSON/);
});
```

`tests/install.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, access } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { install, uninstall, hookDir } from '../install-hook.mjs';

async function home(settings) {
  const h = await mkdtemp(path.join(os.tmpdir(), 'home-'));
  await mkdir(path.join(h, '.claude'));
  if (settings !== undefined) await writeFile(path.join(h, '.claude', 'settings.json'), typeof settings === 'string' ? settings : JSON.stringify(settings));
  return h;
}
const read = async (h) => JSON.parse(await readFile(path.join(h, '.claude', 'settings.json'), 'utf8'));
const OTHER = { enabledPlugins: { 'superpowers@x': true }, hooks: { Stop: [{ hooks: [{ type: 'command', command: 'echo other' }] }] } };

test('install adds both hooks, keeps the rest, copies files, backs up', async () => {
  const h = await home(OTHER);
  assert.deepEqual(await install({ home: h }), { changed: true });
  const s = await read(h);
  assert.deepEqual(s.enabledPlugins, OTHER.enabledPlugins);
  assert.equal(s.hooks.Stop.length, 2);
  assert.match(s.hooks.UserPromptSubmit[0].hooks[0].command, /session-feedback\/feedback-hook\.mjs"$/);
  await access(path.join(hookDir(h), 'feedback-hook.mjs'));
  await access(path.join(hookDir(h), 'feedback.mjs'));
  assert.deepEqual(JSON.parse(await readFile(path.join(h, '.claude', 'settings.json.bak-session-feedback'), 'utf8')), OTHER);
});

test('a second install adds nothing; uninstall removes only ours', async () => {
  const h = await home(OTHER);
  await install({ home: h });
  assert.deepEqual(await install({ home: h }), { changed: false });
  assert.equal((await read(h)).hooks.Stop.length, 2);
  await uninstall({ home: h });
  assert.deepEqual((await read(h)).hooks, OTHER.hooks);
  await assert.rejects(access(hookDir(h)));
});

test('no settings file: one is made; broken JSON: refused, untouched', async () => {
  const h = await home();
  await install({ home: h });
  assert.equal((await read(h)).hooks.Stop.length, 1);
  const bad = await home('{ "hooks": ');
  await assert.rejects(install({ home: bad }));
  assert.equal(await readFile(path.join(bad, '.claude', 'settings.json'), 'utf8'), '{ "hooks": ');
});
```

- [ ] **Step 2: Write `feedback-hook.mjs`**

```js
// Claude Code hook (Stop and UserPromptSubmit): hands a session the feedback
// queued for it from the progress dashboard, exactly once. Installed by
// install-hook.mjs; silent when nothing is queued or anything goes wrong.
import { appendFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { feedbackDir, formatFeedback, SESSION_ID, takeQueued } from './feedback.mjs';

export async function runHook(input, { dir = feedbackDir(), now = Date.now() } = {}) {
  const { session_id: id, hook_event_name: event } = JSON.parse(input);
  const via = event === 'Stop' ? 'stop' : event === 'UserPromptSubmit' ? 'prompt' : null;
  if (!via || !SESSION_ID.test(String(id))) return '';
  const items = await takeQueued(dir, id, via, now);
  if (!items.length) return '';
  const text = formatFeedback(items);
  return JSON.stringify(via === 'stop'
    ? { decision: 'block', reason: text }
    : { hookSpecificOutput: { hookEventName: 'UserPromptSubmit', additionalContext: text } });
}

async function main() {
  const dir = feedbackDir();
  let input = '';
  try {
    for await (const chunk of process.stdin) input += chunk;
    const out = await runHook(input, { dir });
    if (out) process.stdout.write(out);
  } catch (err) {
    try {
      await mkdir(dir, { recursive: true });
      await appendFile(path.join(dir, 'hook-errors.log'), `${new Date().toISOString()} ${err?.stack ?? err}\n`);
    } catch { /* never block the session */ }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) await main();
```

- [ ] **Step 3: Write `install-hook.mjs`**

```js
// Installs the feedback hook for every Claude Code session on this PC:
// copies it to ~/.claude/hooks/session-feedback/ and registers it in
// ~/.claude/settings.json (Stop, UserPromptSubmit). --uninstall reverses it.
//   node tools/progress-dashboard/install-hook.mjs [--uninstall]
import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FILES = ['feedback-hook.mjs', 'feedback.mjs'];
const EVENTS = ['Stop', 'UserPromptSubmit'];
const MARK = 'session-feedback/feedback-hook.mjs';

export const hookDir = (home) => path.join(home, '.claude', 'hooks', 'session-feedback');
export const hookCommand = (home) => `node "${path.join(hookDir(home), 'feedback-hook.mjs').replaceAll('\\', '/')}"`;
const ours = (group) => (group?.hooks ?? []).some((h) => String(h.command ?? '').includes(MARK));
const settingsFile = (home) => path.join(home, '.claude', 'settings.json');

async function readSettings(file) {
  try { return JSON.parse(await readFile(file, 'utf8')); } catch (e) { if (e.code === 'ENOENT') return {}; throw e; }
}
async function writeSettings(file, settings) {
  await copyFile(file, `${file}.bak-session-feedback`).catch((e) => { if (e.code !== 'ENOENT') throw e; });
  await writeFile(file, JSON.stringify(settings, null, 2) + '\n');
}

export async function install({ home = os.homedir(), from = HERE } = {}) {
  const file = settingsFile(home);
  const s = await readSettings(file); // throws on broken JSON before anything is written
  await mkdir(hookDir(home), { recursive: true });
  for (const f of FILES) await copyFile(path.join(from, f), path.join(hookDir(home), f));
  s.hooks ??= {};
  let changed = false;
  for (const ev of EVENTS) {
    s.hooks[ev] ??= [];
    if (!s.hooks[ev].some(ours)) { s.hooks[ev].push({ hooks: [{ type: 'command', command: hookCommand(home) }] }); changed = true; }
  }
  if (changed) await writeSettings(file, s);
  return { changed };
}

export async function uninstall({ home = os.homedir() } = {}) {
  const file = settingsFile(home);
  const s = await readSettings(file);
  let changed = false;
  for (const ev of EVENTS) {
    const groups = s.hooks?.[ev];
    if (!groups) continue;
    const kept = groups.filter((g) => !ours(g));
    if (kept.length !== groups.length) changed = true;
    if (kept.length) s.hooks[ev] = kept; else delete s.hooks[ev];
  }
  if (s.hooks && !Object.keys(s.hooks).length) delete s.hooks;
  if (changed) await writeSettings(file, s);
  await rm(hookDir(home), { recursive: true, force: true });
  return { changed };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const off = process.argv.includes('--uninstall');
  const { changed } = await (off ? uninstall() : install());
  console.log(off ? (changed ? 'Feedback hook removed.' : 'Feedback hook was not registered; files removed.')
    : (changed ? `Feedback hook installed: ${hookCommand(os.homedir())}` : 'Feedback hook files updated; already registered.'));
}
```

- [ ] **Step 4: Run all the tests and see them pass.** Mutation check: drop the `status === 'queued'` filter and the second-Stop test must fail; drop `ours` from install and the second-install test must fail.

- [ ] **Step 5: Commit**: `git commit -m "Add the session feedback hook and its installer"`, then push.

---

### Task 11: Install the hook, deliver end to end, finish the PR

- [ ] Done when: feedback sent from this session's page arrives in this session, the shots are reviewed and the pull request is ready.

**Files:**
- Modify: `docs/plans/session-tracker.md` (ticks), `docs/specs/session-tracker.md` (status line)

- [ ] **Step 1: Install** (the owner approved this settings change on 2026-10-02): run `node tools/progress-dashboard/install-hook.mjs`. Show the owner the new entries with `node -e "console.log(JSON.stringify(require(require('os').homedir()+'/.claude/settings.json').hooks,null,2))"`.
- [ ] **Step 2: End to end.**
  - From this session's page on port 5198, add a note and a message and Send.
  - Finish the turn. The Stop hook should bring the feedback back into this session as a new instruction.
  - Then the sidebar shows "Delivered (end of turn)".
  - Then repeat with a queued item and the owner's next prompt (UserPromptSubmit path).
  - If either doesn't arrive, check `~/.claude/session-feedback/hook-errors.log` and diagnose before going on.
- [ ] **Step 3: Visual review.** Shots of the dashboard and a session page at 1280 px and 375 px, in light and dark, including the pulsing tile and a highlighted note. Send them to the owner.
- [ ] **Step 4: Whole-branch review** (superpowers:requesting-code-review), then fix what it finds.
- [ ] **Step 5:**
  - set the spec's status line to "built";
  - tick the tasks;
  - commit and push;
  - mark the pull request ready;
  - tell the owner in one line what's in it and give the link;
  - ask for approval.

### Task 12: Switch-over after the merge (each step with the owner's OK)

- [ ] Done when: the "progress" launch config runs the tracked copy and the old copy is gone.

- [ ] **Step 1:** After the owner approves and the PR merges into `feature/godot-rebuild`, the main lane pulls. Then point the main checkout's `.claude/launch.json` "progress" entry at `tools/progress-dashboard/server.mjs`. This edit is in the main checkout's `.claude/`: ask the owner or the main-lane session to make it, or do it from a session in the main checkout.
- [ ] **Step 2:** Remove `.claude/progress-dashboard/` from `.git/info/exclude`, and delete the old untracked copy (with the owner's OK; look at it first for anything newer).
- [ ] **Step 3:** Tell the estimates session (the `estimated-time-by-stage` worktree) that its draft now has to be ported onto `tools/progress-dashboard/`.
- [ ] **Step 4:** Update the progress-dashboard memory: the path, `npm run dashboard`, the hook install, and that the dashboard is tracked.
