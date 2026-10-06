// Merge from the Project Manager: whether a session's pull request is ready,
// from the fields `gh pr view --json` gives, and what the session is told once
// it merged. Pure, no I/O: merge-api.mjs runs gh. The owner's choices (PM task
// 13, Oct 5): Merge is offered whatever the base, and ready means every check
// passed, skipped or neutral.

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

// What the session is told once the owner merged its pull request.
export function mergedMessage(pr) {
  return `The owner merged pull request #${pr.number} into ${pr.baseRefName} from the Project Manager (a merge commit; GitHub deleted the remote branch ${pr.headRefName}). `
    + `That merge was the owner's approval. Tidy up: fetch, bring your local ${pr.baseRefName} up to date, and delete your local branch ${pr.headRefName} `
    + 'once nothing else needs it (switch off it first). Then say in one line what you did.';
}
