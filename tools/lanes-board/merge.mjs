// Whether a session's pull request is ready to merge, from the fields
// `gh pr view --json` gives, for the bell's "ready to merge". Pure, no I/O:
// merge-api.mjs runs gh. The Project Manager never merges: since Oct 6 (owner's
// choice) merges are done on GitHub, or by a session the owner tells to. Ready
// means every check passed, skipped or neutral (PM task 13, Oct 5).

// The fields mergeReadiness reads, for `gh pr view <n> --json <fields>`.
export const MERGE_FIELDS = ['number', 'title', 'url', 'state', 'isDraft', 'mergeable', 'mergeStateStatus', 'baseRefName', 'headRefName',
  'headRefOid', 'statusCheckRollup'];

const PASSED = new Set(['SUCCESS', 'SKIPPED', 'NEUTRAL']);

// A check run (Actions) or a commit status, as passed, failed or pending.
function checkOf(c) {
  if (c.__typename === 'StatusContext' || 'context' in c) {
    const state = String(c.state ?? '').toUpperCase();
    return { name: c.context ?? '?', is: state === 'SUCCESS' ? 'passed' : state === 'PENDING' || state === 'EXPECTED' ? 'pending' : 'failed' };
  }
  if (String(c.status ?? '').toUpperCase() !== 'COMPLETED') return { name: c.name ?? '?', is: 'pending' };
  return { name: c.name ?? '?', is: PASSED.has(String(c.conclusion ?? '').toUpperCase()) ? 'passed' : 'failed' };
}

// { ready, behind, reasons }: ready when open, out of draft, mergeable, every
// check passed and not behind its base; otherwise every reason it isn't.
// behind: it can take its base's changes with Update branch.
export function mergeReadiness(pr) {
  if (pr.state === 'MERGED') return { ready: false, behind: false, reasons: ['It is already merged.'] };
  if (pr.state && pr.state !== 'OPEN') return { ready: false, behind: false, reasons: ['It is closed.'] };
  const reasons = [];
  if (pr.isDraft) reasons.push('It is still a draft.');
  const checks = (pr.statusCheckRollup ?? []).map(checkOf);
  const named = (is) => [...new Set(checks.filter((c) => c.is === is).map((c) => c.name))];
  if (named('failed').length) reasons.push(`Checks failed: ${named('failed').join(', ')}.`);
  if (named('pending').length) reasons.push(`Checks still running: ${named('pending').join(', ')}.`);
  const base = pr.baseRefName ?? 'its base';
  if (pr.mergeable === 'CONFLICTING') reasons.push(`It has conflicts with ${base}.`);
  else if (pr.mergeable !== 'MERGEABLE') reasons.push('GitHub is still working out whether it merges cleanly.');
  const behind = pr.mergeStateStatus === 'BEHIND';
  if (behind) reasons.push(`It is behind ${base}.`);
  if (pr.mergeStateStatus === 'BLOCKED' && !reasons.length) reasons.push(`GitHub's rules for ${base} block it (reviews or required checks).`);
  return { ready: reasons.length === 0, behind, reasons };
}
