// The round trip for a session's Docs: what it wrote is listed and served from
// its worktree, else its branch, else its pull request's head; its pull
// request (through a stand-in gh) and its artifacts are listed; nothing it
// didn't name, or outside the repo, is served.
import { execFileSync } from 'node:child_process';
import { appendFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';
import { SESSION, startBoard, waitFor } from './lanes-board-harness.mjs';

const STUB = fileURLToPath(new URL('./lanes-board-gh-stub.mjs', import.meta.url));

describe('the round trip: docs, the pull request and artifacts', () => {
  let board, base, dir, mergedOid;
  const git = (...args) => execFileSync('git', ['-c', 'user.name=T', '-c', 'user.email=t@e.com', ...args], { cwd: board.repo, windowsHide: true, encoding: 'utf8' }).trim();
  const add = (o) => appendFileSync(board.transcriptOf(SESSION), `${JSON.stringify({ sessionId: SESSION, cwd: board.repo, gitBranch: 'lane/x', timestamp: new Date().toISOString(), ...o })}\n`);
  let n = 0;
  const wrote = (file) => {
    const id = `w${n++}`;
    add({ type: 'assistant', message: { role: 'assistant', content: [{ type: 'tool_use', id, name: 'Write', input: { file_path: file, content: '' } }] } });
    add({ type: 'user', message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: id, content: 'File written' }] } });
  };
  const doc = (file) => fetch(`${base}/doc?session=${SESSION}&path=${encodeURIComponent(file)}`);
  before(async () => {
    dir = mkdtempSync(path.join(os.tmpdir(), 'pm-docs-'));
    const fixture = path.join(dir, 'fixture.json');
    const log = path.join(dir, 'log.jsonl');
    writeFileSync(log, '');
    writeFileSync(fixture, JSON.stringify({ repo: 'o/r', prs: [] }));
    board = await startBoard({ env: { LANES_GH: STUB, LANES_GH_FIXTURE: fixture, LANES_GH_LOG: log } });
    base = `http://localhost:${board.port}`;
    // The repository: README on main, docs/gone.md only on lane/x, docs/merged.md only in a commit no branch holds.
    writeFileSync(path.join(board.repo, 'README.md'), '# Readme');
    git('add', 'README.md'); git('commit', '-q', '-m', 'Readme');
    git('switch', '-q', '-c', 'lane/x');
    mkdirSync(path.join(board.repo, 'docs'));
    writeFileSync(path.join(board.repo, 'docs', 'gone.md'), '# Gone from disk');
    git('add', 'docs'); git('commit', '-q', '-m', 'Gone');
    git('switch', '-q', '-c', 'tmp');
    writeFileSync(path.join(board.repo, 'docs', 'merged.md'), '# Merged');
    git('add', 'docs'); git('commit', '-q', '-m', 'Merged');
    mergedOid = git('rev-parse', 'HEAD');
    git('switch', '-q', 'main'); git('branch', '-q', '-D', 'tmp');
    mkdirSync(path.join(board.repo, 'docs'), { recursive: true });
    mkdirSync(path.join(board.repo, 'notes'));
    writeFileSync(path.join(board.repo, 'docs', 'plan.md'), '# Plan\n\nStep <one>.');
    writeFileSync(path.join(board.repo, 'notes', 'page.html'), '<h1>Page</h1>');
    writeFileSync(path.join(board.repo, 'docs', 'spec.pdf'), '%PDF-1.4 fixture');
    writeFileSync(path.join(board.root, 'outside.md'), '# Outside');
    writeFileSync(fixture, JSON.stringify({ repo: 'o/r',
      prs: [{ number: 7, title: 'Lane x', headRefName: 'lane/x', baseRefName: 'main', isDraft: false, url: 'https://github.com/o/r/pull/7' }],
      views: { 7: { number: 7, title: 'Lane x', url: 'https://github.com/o/r/pull/7', state: 'OPEN', isDraft: false, body: '## Summary\n\nDocs.',
        baseRefName: 'main', headRefName: 'lane/x', headRefOid: mergedOid, additions: 12, deletions: 3,
        statusCheckRollup: [{ __typename: 'CheckRun', name: 'test', status: 'COMPLETED', conclusion: 'SUCCESS' }],
        files: [{ path: 'docs/plan.md', additions: 12, deletions: 3 }] } } }));
    for (const f of ['docs/spec.pdf', 'docs/plan.md', 'notes/page.html', 'docs/gone.md', 'docs/merged.md', 'docs/never.md']) wrote(path.join(board.repo, f));
    wrote(path.join(board.root, 'outside.md'));
    add({ type: 'assistant', message: { role: 'assistant', content: [{ type: 'tool_use', id: 'art', name: 'Artifact', input: { file_path: 'r.html', title: 'Report' } }] } });
    add({ type: 'user', message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: 'art', content: 'Published https://claude.ai/artifact/Rep0rt' }] } });
  });
  after(async () => { await board?.stop(); rmSync(dir, { recursive: true, force: true }); });

  it('lists what it wrote inside the repo, newest first, its artifacts and its pull request', async () => {
    const d = await waitFor(async () => { const b = (await board.get(`/docs?session=${SESSION}`)).body; return b?.pr && b; }, 20000, 'the pull request');
    assert.deepEqual(d.docs.map((x) => [x.name, x.kind, x.dir]), [
      ['never.md', 'md', 'docs'], ['merged.md', 'md', 'docs'], ['gone.md', 'md', 'docs'], ['page.html', 'html', 'notes'], ['plan.md', 'md', 'docs'], ['spec.pdf', 'pdf', 'docs']]);
    assert.deepEqual(d.artifacts.map((a) => [a.title, a.url]), [['Report', 'https://claude.ai/artifact/Rep0rt']]);
    assertMatches(d.pr, { number: 7, title: 'Lane x', url: 'https://github.com/o/r/pull/7', state: 'OPEN', base: 'main', head: 'lane/x', body: '## Summary\n\nDocs.',
      additions: 12, deletions: 3, checks: [{ name: 'test', state: 'SUCCESS' }], files: [{ path: 'docs/plan.md', additions: 12, deletions: 3 }] });
  });

  it("serves a PDF as it is, unsandboxed so the browser's viewer can show it", async () => {
    const pdf = await doc(path.join(board.repo, 'docs', 'spec.pdf'));
    assert.equal(pdf.status, 200);
    assert.equal(pdf.headers.get('content-type'), 'application/pdf');
    assert.equal(pdf.headers.get('content-security-policy'), null);
    assert.equal(await pdf.text(), '%PDF-1.4 fixture');
  });

  it('serves a document from the worktree, an HTML page sandboxed', async () => {
    const md = await doc(path.join(board.repo, 'docs', 'plan.md'));
    assert.equal(md.status, 200);
    assert.equal(md.headers.get('content-type'), 'text/markdown; charset=utf-8');
    assert.equal(md.headers.get('x-doc-from'), 'its worktree');
    assert.equal(await md.text(), '# Plan\n\nStep <one>.');
    const html = await doc(path.join(board.repo, 'notes', 'page.html'));
    assert.equal(html.headers.get('content-type'), 'text/html; charset=utf-8');
    assert.match(html.headers.get('content-security-policy'), /^sandbox\b/);
    assert.doesNotMatch(html.headers.get('content-security-policy'), /allow-same-origin/);
  });

  it('reads one gone from disk from its branch, then from its pull request\'s head', async () => {
    const gone = await doc(path.join(board.repo, 'docs', 'gone.md'));
    assert.equal(gone.status, 200);
    assert.equal(gone.headers.get('x-doc-from'), 'branch lane/x');
    assert.equal(await gone.text(), '# Gone from disk');
    const merged = await doc(path.join(board.repo, 'docs', 'merged.md'));
    assert.equal(merged.headers.get('x-doc-from'), "pull request #7's head");
    assert.equal(await merged.text(), '# Merged');
    assert.equal((await doc(path.join(board.repo, 'docs', 'never.md'))).status, 410);
  });

  it('serves nothing it did not name, nor anything outside the repo', async () => {
    assert.equal((await doc(path.join(board.repo, 'README.md'))).status, 404);
    assert.equal((await doc(path.join(board.root, 'outside.md'))).status, 404);
    assert.equal((await fetch(`${base}/doc?session=nope&path=x.md`)).status, 404);
  });
});
