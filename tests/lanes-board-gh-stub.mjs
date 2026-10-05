// A stand-in for gh in the Project Manager's round-trip tests (LANES_GH points
// the board at it). It answers from a fixture (LANES_GH_FIXTURE: { repo, prs,
// views: { <number>: gh pr view's JSON } }) and logs each call, with the folder
// it ran in, to LANES_GH_LOG. A merge marks the pull request merged.
import { appendFileSync, readFileSync, writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const fixtureFile = process.env.LANES_GH_FIXTURE;
const fixture = JSON.parse(readFileSync(fixtureFile, 'utf8'));
appendFileSync(process.env.LANES_GH_LOG, `${JSON.stringify({ args, cwd: process.cwd() })}\n`);
const out = (v) => { process.stdout.write(JSON.stringify(v)); process.exit(0); };
const fail = (msg) => { process.stderr.write(msg); process.exit(1); };

const [a, b, n] = args;
if (a === 'repo' && b === 'view') out({ nameWithOwner: fixture.repo });
if (a === 'pr' && b === 'list') out(fixture.prs ?? []);
if (a === 'pr' && b === 'view') { const v = fixture.views?.[n]; if (v) out(v); fail(`no pull request ${n}`); }
if (a === 'pr' && b === 'update-branch') { process.exit(0); }
if (a === 'pr' && b === 'merge') {
  const v = fixture.views?.[n];
  if (!v) fail(`no pull request ${n}`);
  v.state = 'MERGED';
  writeFileSync(fixtureFile, JSON.stringify(fixture));
  process.exit(0);
}
fail(`the stub doesn't know: gh ${args.join(' ')}`);
