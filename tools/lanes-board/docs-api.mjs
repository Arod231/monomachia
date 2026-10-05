// A session's Docs, mounted by server.mjs (rules in docs.mjs): what it wrote,
// its pull request and the artifacts it published.
//   GET /docs?session=          { docs: [{ path, name, dir, kind, time }], artifacts, branch, pr }
//   GET /doc?session=&path=     the document itself, from its worktree, else its
//                               branch (local, then origin's), else its pull
//                               request's head commit; 404 for a path the session
//                               didn't write inside the repo or a worktree, 410
//                               for one no longer found anywhere
// Markdown goes as text (the pages render it), HTML in a sandbox (scripts but
// no access to the Project Manager), PDF as it is. The pull request is asked
// of GitHub at most once a minute per branch.
import { execFile } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { cleanPath, docPlace, docScanner } from './docs.mjs';
import { SESSION_ID } from './sessions.mjs';
import { scanned } from './transcript-index.mjs';

const run = promisify(execFile);
const PR_MS = 60 * 1000;
const MAX_BYTES = 25 << 20;
const TYPES = { md: 'text/markdown; charset=utf-8', html: 'text/html; charset=utf-8', pdf: 'application/pdf' };
const PR_FIELDS = 'number,title,url,state,isDraft,body,baseRefName,headRefName,headRefOid,additions,deletions,statusCheckRollup,files';

// repoDir: the main checkout; worktrees(): the live ones ({ path }); gh:
// ghRunner() (merge-api.mjs); prOf(branch): its open pull request from the
// board's list; fileOf(session): its transcript's path, or null.
export function docsApi({ repoDir, worktrees, gh, prOf = () => null, fileOf }) {
  let repoName = null;
  const repo = async () => (repoName ??= JSON.parse(await gh(['repo', 'view', '--json', 'nameWithOwner'], { cwd: repoDir })).nameWithOwner);

  // The branch's pull request, open or not, cached a minute (null when none).
  const prs = new Map(); // branch -> { time, pr }
  async function prOfBranch(branch) {
    const hit = prs.get(branch);
    if (hit && Date.now() - hit.time < PR_MS) return hit.pr;
    let pr = null;
    try {
      const r = await repo();
      let number = prOf(branch)?.number;
      if (!number) {
        const list = JSON.parse(await gh(['pr', 'list', '--repo', r, '--head', branch, '--state', 'all', '--limit', '5', '--json', 'number,headRefName'], { cwd: os.tmpdir() }));
        number = list.find((p) => p.headRefName === branch)?.number;
      }
      if (number) {
        const v = JSON.parse(await gh(['pr', 'view', String(number), '--repo', r, '--json', PR_FIELDS], { cwd: os.tmpdir() }));
        pr = { number: v.number, title: v.title, url: v.url, state: v.state, draft: !!v.isDraft, body: v.body ?? '', base: v.baseRefName, head: v.headRefName,
          headOid: v.headRefOid ?? null, additions: v.additions ?? 0, deletions: v.deletions ?? 0,
          checks: (v.statusCheckRollup ?? []).map((c) => ({ name: c.name ?? c.context ?? '?', state: c.conclusion || c.state || c.status || '' })),
          files: (v.files ?? []).map((f) => ({ path: f.path, additions: f.additions ?? 0, deletions: f.deletions ?? 0 })) };
      }
    } catch { /* gh not signed in, or offline: no pull request shown */ }
    prs.set(branch, { time: Date.now(), pr });
    return pr;
  }

  async function scannerOf(session) {
    if (!SESSION_ID.test(session ?? '')) return null;
    const file = await fileOf(session);
    return file ? scanned(file, 'docs', docScanner) : null;
  }
  const rootsNow = async () => [repoDir, ...(await worktrees()).map((w) => w.path).filter((p) => cleanPath(p).toLowerCase() !== cleanPath(repoDir).toLowerCase())];

  async function list(url) {
    const sc = await scannerOf(url.searchParams.get('session'));
    if (!sc) throw new Error('No session with that id');
    const roots = await rootsNow();
    const named = sc.named();
    const docs = sc.docs().map((d) => {
      const place = docPlace(d.path, { named, roots, cwd: d.cwd });
      if (!place) return null;
      const rel = place.rel.split('/');
      return { path: d.path, name: rel.at(-1), dir: rel.slice(0, -1).join('/'), kind: d.kind, time: d.time };
    }).filter(Boolean);
    const branch = sc.branch();
    return { docs, artifacts: sc.artifacts(), branch, pr: branch ? await prOfBranch(branch) : null };
  }

  const gitShow = async (ref, rel) => {
    try {
      const { stdout } = await run('git', ['--no-optional-locks', 'show', `${ref}:${rel}`], { cwd: repoDir, encoding: 'buffer', maxBuffer: MAX_BYTES, windowsHide: true });
      return stdout;
    } catch { return null; }
  };

  // The document: { bytes, kind, from }, 'gone', or null when it may not be served.
  async function find(session, file) {
    const sc = await scannerOf(session);
    const doc = sc?.docs().find((d) => cleanPath(d.path).toLowerCase() === cleanPath(file).toLowerCase());
    if (!doc) return null;
    const place = docPlace(doc.path, { named: sc.named(), roots: await rootsNow(), cwd: doc.cwd });
    if (!place) return null;
    if (place.live) {
      try { return { bytes: await readFile(path.join(place.root, place.rel)), kind: doc.kind, from: 'its worktree' }; } catch { /* gone from disk */ }
    }
    const branch = sc.branch();
    if (branch) {
      for (const ref of [branch, `origin/${branch}`]) {
        const bytes = await gitShow(ref, place.rel);
        if (bytes) return { bytes, kind: doc.kind, from: `branch ${ref}` };
      }
      const pr = await prOfBranch(branch);
      const bytes = pr?.headOid && await gitShow(pr.headOid, place.rel);
      if (bytes) return { bytes, kind: doc.kind, from: `pull request #${pr.number}'s head` };
    }
    return 'gone';
  }

  async function serve(req, res, url) {
    if (url.pathname !== '/doc') return false;
    const d = await find(url.searchParams.get('session'), url.searchParams.get('path') ?? '');
    if (!d || d === 'gone') {
      res.writeHead(d ? 410 : 404, { 'content-type': 'text/plain; charset=utf-8' });
      res.end(d ? 'That document is no longer in its worktree, its branch or its pull request.' : 'No such document for this session.');
      return true;
    }
    res.writeHead(200, { 'content-type': TYPES[d.kind], 'content-length': d.bytes.length, 'cache-control': 'no-store', 'x-content-type-options': 'nosniff',
      // An opaque origin: a page's scripts run but can't act as the Project
      // Manager. A PDF goes without, as a sandbox can stop the browser's viewer.
      ...(d.kind === 'pdf' ? {} : { 'content-security-policy': 'sandbox allow-scripts allow-popups allow-popups-to-escape-sandbox' }), 'x-doc-from': d.from });
    res.end(d.bytes);
    return true;
  }

  return {
    get(url) { return url.pathname === '/docs' ? list(url) : undefined; },
    serve,
  };
}
