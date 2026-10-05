// Merge from a session's page, mounted by server.mjs (rules in merge.mjs). gh
// always runs against the repository on GitHub (--repo) from a folder that is no
// checkout, so a merge never touches a local branch or worktree; the session is
// then told to tidy up its own. Every pollMs it also looks at the open pull
// requests of recent sessions and notes, for the bell (and lock-screen push),
// each one that turns ready to merge.
//   GET  /merge?session=          { pr, ready, behind, reasons }
//   POST /merge/update { session, number }   gh pr update-branch (when behind)
//   POST /merge        { session, number }   gh pr merge --merge --delete-branch
import { execFile } from 'node:child_process';
import { appendFile, mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { MERGE_FIELDS, mergeReadiness, mergedMessage } from './merge.mjs';
import { SESSION_ID } from './sessions.mjs';

const run = promisify(execFile);

// Runs gh (or stub, a script run with node: the tests' stand-in for gh) and
// gives its output.
export function ghRunner(stub = process.env.LANES_GH) {
  return async (args, opts = {}) => {
    const o = { windowsHide: true, timeout: 60_000, maxBuffer: 8 << 20, ...opts };
    const { stdout } = stub ? await run(process.execPath, [stub, ...args], o) : await run('gh', args, o);
    return stdout;
  };
}

// repoDir: the main checkout (it names the repository); relay: the relay
// folder, whose events.jsonl the bell reads; gh: ghRunner(); prOf(branch):
// the branch's open pull request from the board's list; sessions: the Sessions
// routes' deliver(session, text) and branches(); stateFile: which pull requests
// were already said to be ready.
export function mergeApi({ repoDir, relay, gh, prOf, sessions, stateFile, pollMs = 0, log = console.error }) {
  const outside = os.tmpdir();
  let repoName = null;
  async function repo() {
    repoName ??= JSON.parse(await gh(['repo', 'view', '--json', 'nameWithOwner'], { cwd: repoDir })).nameWithOwner;
    return repoName;
  }
  const view = async (number) => JSON.parse(await gh(['pr', 'view', String(number), '--repo', await repo(), '--json', MERGE_FIELDS.join(',')], { cwd: outside }));

  async function prFor(session) {
    if (!SESSION_ID.test(session ?? '')) throw new Error('Bad session id');
    const s = (await sessions.branches()).find((x) => x.id === session);
    const pr = s ? prOf(s.branch) : null;
    if (!pr) throw new Error('This session has no open pull request');
    return pr;
  }

  async function status(url) {
    const pr = await prFor(url.searchParams.get('session'));
    const full = await view(pr.number);
    return { pr: { number: full.number, title: full.title, url: full.url, base: full.baseRefName, head: full.headRefName, draft: !!full.isDraft },
      ...mergeReadiness(full) };
  }

  // The pull request the page named, which must be the session's.
  async function named(body) {
    const pr = await prFor(body?.session);
    if (Number(body?.number) !== pr.number) throw new Error(`That isn't this session's pull request (it has #${pr.number})`);
    return view(pr.number);
  }

  async function update(body) {
    const full = await named(body);
    if (!mergeReadiness(full).behind) throw new Error('It is not behind its base');
    await gh(['pr', 'update-branch', String(full.number), '--repo', await repo()], { cwd: outside });
    return { updated: true, number: full.number };
  }

  // Merged only when ready, and only the commit that was checked.
  async function merge(body) {
    const full = await named(body);
    const r = mergeReadiness(full);
    if (!r.ready) throw new Error(`Not ready to merge: ${r.reasons.join(' ')}`);
    await gh(['pr', 'merge', String(full.number), '--repo', await repo(), '--merge', '--delete-branch', '--match-head-commit', full.headRefOid], { cwd: outside });
    const told = await sessions.deliver(body.session, mergedMessage(full));
    return { merged: true, number: full.number, base: full.baseRefName, told: told.when };
  }

  // ---------- "ready to merge" for the bell ----------
  let said = null; // pull request numbers already said to be ready
  async function look() {
    said ??= new Set((await readFile(stateFile, 'utf8').then(JSON.parse, () => null))?.ready ?? []);
    const before = [...said].sort().join();
    const seen = new Set();
    for (const s of await sessions.branches()) {
      const pr = prOf(s.branch);
      if (!pr || seen.has(pr.number)) continue;
      seen.add(pr.number);
      let full;
      try { full = await view(pr.number); } catch (err) { log(`merge: couldn't read #${pr.number}: ${err.message}`); continue; }
      if (!mergeReadiness(full).ready) { said.delete(pr.number); continue; }
      if (said.has(pr.number)) continue;
      said.add(pr.number);
      await mkdir(relay, { recursive: true });
      await appendFile(path.join(relay, 'events.jsonl'), `${JSON.stringify({ time: Date.now(), kind: 'pr-ready', session: s.id,
        pr: { number: full.number, title: full.title, base: full.baseRefName } })}\n`);
    }
    for (const n of [...said]) if (!seen.has(n)) said.delete(n); // merged or closed since
    if ([...said].sort().join() !== before) {
      const tmp = `${stateFile}.${process.pid}.tmp`;
      await writeFile(tmp, JSON.stringify({ ready: [...said] }));
      await rename(tmp, stateFile);
    }
  }
  let looking = false;
  if (pollMs > 0) {
    setInterval(() => {
      if (looking) return;
      looking = true;
      look().catch((err) => log(`merge: ${err.message}`)).finally(() => { looking = false; });
    }, pollMs).unref();
  }

  return {
    get(url) {
      if (url.pathname === '/merge') return status(url);
      return undefined;
    },
    post(route, body) {
      if (route === '/merge') return merge(body);
      if (route === '/merge/update') return update(body);
      return undefined;
    },
  };
}
