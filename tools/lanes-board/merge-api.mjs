// "Ready to merge" for the bell (lock-screen push too), mounted by server.mjs
// (rules in merge.mjs): every pollMs it looks at the open pull requests of
// recent sessions and notes each one that turns ready to merge. The Project
// Manager never merges: since Oct 6 (owner's choice) merges are done on GitHub,
// or by a session the owner tells to. gh always runs against the repository on
// GitHub (--repo) from a folder that is no checkout.
import { execFile } from 'node:child_process';
import { appendFile, mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import { MERGE_FIELDS, mergeReadiness } from './merge.mjs';

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
// routes' branches(); stateFile: which pull requests were already said to be ready.
export function mergeWatch({ repoDir, relay, gh, prOf, sessions, stateFile, pollMs = 0, log = console.error }) {
  const outside = os.tmpdir();
  let repoName = null;
  async function repo() {
    repoName ??= JSON.parse(await gh(['repo', 'view', '--json', 'nameWithOwner'], { cwd: repoDir })).nameWithOwner;
    return repoName;
  }
  const view = async (number) => JSON.parse(await gh(['pr', 'view', String(number), '--repo', await repo(), '--json', MERGE_FIELDS.join(',')], { cwd: outside }));

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

  return { look };
}
