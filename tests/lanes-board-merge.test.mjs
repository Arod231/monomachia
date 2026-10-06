// "Ready to merge" in the Project Manager (tools/lanes-board/merge.mjs): when
// a pull request is ready. The board never merges it.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { MERGE_FIELDS, mergeReadiness } from '../tools/lanes-board/merge.mjs';

const run = (name, conclusion, status = 'COMPLETED') => ({ __typename: 'CheckRun', name, status, conclusion });
const ctx = (context, state) => ({ __typename: 'StatusContext', context, state });
const PR = {
  number: 51, title: 'PM 11-14', url: 'https://github.com/o/r/pull/51', state: 'OPEN', isDraft: false,
  mergeable: 'MERGEABLE', mergeStateStatus: 'CLEAN', baseRefName: 'tools/pm', headRefName: 'lane/pm-11',
  statusCheckRollup: [run('test', 'SUCCESS'), run('export-windows', 'SUCCESS')],
};

describe('mergeReadiness', () => {
  it('asks gh for every field it reads', () => {
    for (const f of ['number', 'state', 'isDraft', 'mergeable', 'mergeStateStatus', 'baseRefName', 'headRefName', 'statusCheckRollup']) {
      assert.ok(MERGE_FIELDS.includes(f), f);
    }
  });

  it('is ready when out of draft, mergeable, every check passed and up to date with its base', () => {
    assert.deepEqual(mergeReadiness(PR), { ready: true, behind: false, reasons: [] });
  });

  it('counts skipped and neutral checks, and passed statuses, as passed', () => {
    const pr = { ...PR, statusCheckRollup: [run('a', 'SUCCESS'), run('b', 'SKIPPED'), run('c', 'NEUTRAL'), ctx('ci/x', 'SUCCESS')] };
    assert.equal(mergeReadiness(pr).ready, true);
    assert.equal(mergeReadiness({ ...PR, statusCheckRollup: [] }).ready, true, 'a repository with no checks');
  });

  it('says it is a draft', () => {
    assert.deepEqual(mergeReadiness({ ...PR, isDraft: true }).reasons, ['It is still a draft.']);
  });

  it('names failing and pending checks', () => {
    const pr = { ...PR, statusCheckRollup: [run('test', 'FAILURE'), run('lint', 'TIMED_OUT'), run('export', null, 'IN_PROGRESS'), ctx('ci/x', 'PENDING'), run('ok', 'SUCCESS')] };
    assert.deepEqual(mergeReadiness(pr), { ready: false, behind: false,
      reasons: ['Checks failed: test, lint.', 'Checks still running: export, ci/x.'] });
  });

  it('says when it conflicts with its base, or GitHub has not worked that out yet', () => {
    assert.deepEqual(mergeReadiness({ ...PR, mergeable: 'CONFLICTING', mergeStateStatus: 'DIRTY' }).reasons, ['It has conflicts with tools/pm.']);
    assert.deepEqual(mergeReadiness({ ...PR, mergeable: 'UNKNOWN', mergeStateStatus: 'UNKNOWN' }).reasons, ['GitHub is still working out whether it merges cleanly.']);
  });

  it('offers Update branch when it is behind its base', () => {
    assert.deepEqual(mergeReadiness({ ...PR, mergeStateStatus: 'BEHIND' }), { ready: false, behind: true, reasons: ['It is behind tools/pm.'] });
  });

  it('says when GitHub blocks it, or it is no longer open', () => {
    assert.deepEqual(mergeReadiness({ ...PR, mergeStateStatus: 'BLOCKED' }).reasons, ["GitHub's rules for tools/pm block it (reviews or required checks)."]);
    assert.deepEqual(mergeReadiness({ ...PR, state: 'MERGED' }), { ready: false, behind: false, reasons: ['It is already merged.'] });
    assert.deepEqual(mergeReadiness({ ...PR, state: 'CLOSED' }).reasons, ['It is closed.']);
  });

  it('gives every reason at once', () => {
    const r = mergeReadiness({ ...PR, isDraft: true, mergeStateStatus: 'BEHIND', statusCheckRollup: [run('test', 'FAILURE')] });
    assert.deepEqual(r.reasons, ['It is still a draft.', 'Checks failed: test.', 'It is behind tools/pm.']);
    assert.equal(r.behind, true);
  });
});
