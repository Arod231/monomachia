// What a session wrote and published (tools/lanes-board/docs.mjs): the
// documents its Write and Edit calls name, the artifacts it published, and
// the rule for which named files the Project Manager may serve.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { docKind, docPlace, docScanner } from '../tools/lanes-board/docs.mjs';

const W = 'C:\\repo\\.claude\\worktrees\\lane-x';
let n = 0;
const at = (s) => `2026-10-05T10:00:${String(s).padStart(2, '0')}.000Z`;
const call = (id, name, input, s, extra = {}) => JSON.stringify({ type: 'assistant', cwd: W, gitBranch: 'lane/x', timestamp: at(s), ...extra,
  message: { role: 'assistant', content: [{ type: 'tool_use', id, name, input }] } });
const result = (id, content, s, extra = {}) => JSON.stringify({ type: 'user', cwd: W, timestamp: at(s), ...extra,
  message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: id, content, ...extra.result }] } });
function scan(lines) {
  const sc = docScanner();
  lines.forEach((t, i) => sc.feed(t, i, n++));
  return sc;
}

describe('docKind', () => {
  it('lists Markdown, HTML pages and PDFs', () => {
    assert.deepEqual(['a.md', 'b.MARKDOWN', 'c.html', 'd.htm', 'e.pdf', 'f.mjs', 'g'].map(docKind), ['md', 'md', 'html', 'html', 'pdf', null, null]);
  });
});

describe('docScanner', () => {
  it('lists the documents its Write and Edit calls name, newest first, once each', () => {
    const sc = scan([
      call('w1', 'Write', { file_path: `${W}\\docs\\plan.md`, content: '# Plan' }, 1), result('w1', 'ok', 2),
      call('w2', 'Write', { file_path: `${W}\\tools\\x.mjs`, content: '' }, 3), result('w2', 'ok', 4),
      call('e1', 'Edit', { file_path: `${W}\\notes\\page.html`, old_string: 'a', new_string: 'b' }, 5), result('e1', 'ok', 6),
      call('m1', 'MultiEdit', { file_path: `${W}/docs/plan.md`, edits: [] }, 7), result('m1', 'ok', 8),
      call('w3', 'Write', { file_path: `${W}\\docs\\failed.md`, content: '' }, 9), result('w3', 'Error', 10, { result: { is_error: true } }),
    ]);
    assert.deepEqual(sc.docs().map((d) => [d.path, d.kind, d.time, d.cwd]), [
      [`${W}/docs/plan.md`, 'md', Date.parse(at(8)), W],
      [`${W}\\notes\\page.html`, 'html', Date.parse(at(6)), W],
    ]);
  });

  it('keeps its branch, the last one named', () => {
    const sc = scan([call('a', 'Bash', {}, 1), call('b', 'Bash', {}, 2, { gitBranch: 'HEAD' })]);
    assert.equal(sc.branch(), 'lane/x');
  });

  it('lists the artifacts it published, newest first, once each, but not reads, lists, assets or failures', () => {
    const url = 'https://claude.ai/artifact/AbC123xyz';
    const sc = scan([
      call('p1', 'Artifact', { file_path: 'report.html', title: 'Board report' }, 1), result('p1', [{ type: 'text', text: `Published: ${url} (private)` }], 2),
      call('p2', 'Artifact', { action: 'publish', file_path: 'guide.html' }, 3), result('p2', 'Published https://claude.ai/code/artifact/0f6e9c1e-1111-4222-8333-444455556666.', 4),
      call('p3', 'Artifact', { file_path: 'report.html', title: 'Board report' }, 5), result('p3', `Updated ${url}`, 6),
      call('r1', 'Artifact', { action: 'read', url: 'https://claude.ai/artifact/Other1' }, 7), result('r1', 'https://claude.ai/artifact/Other1', 8),
      call('l1', 'Artifact', { action: 'list' }, 9), result('l1', 'https://claude.ai/artifact/Other2', 10),
      call('a1', 'Artifact', { url, file_path: 'x.png', asset: true }, 11), result('a1', `${url}/assets/1`, 12),
      call('f1', 'Artifact', { file_path: 'bad.html' }, 13), result('f1', 'Refused https://claude.ai/artifact/Other3', 14, { result: { is_error: true } }),
    ]);
    assert.deepEqual(sc.artifacts(), [
      { url, title: 'Board report', time: Date.parse(at(6)) },
      { url: 'https://claude.ai/code/artifact/0f6e9c1e-1111-4222-8333-444455556666', title: 'guide.html', time: Date.parse(at(4)) },
    ]);
  });
});

describe('docPlace', () => {
  const named = new Set([`${W}\\docs\\plan.md`, 'C:\\outside\\notes.md', 'C:\\repo\\.claude\\worktrees\\gone\\docs\\old.md', `${W}\\docs\\..\\..\\..\\..\\..\\secret.md`]);
  const roots = ['C:\\repo', W];
  it('places a named file inside a worktree, relative to the deepest one', () => {
    assert.deepEqual(docPlace(`${W}\\docs\\plan.md`, { named, roots, cwd: W }), { root: W.replace(/\\/g, '/'), rel: 'docs/plan.md', live: true });
  });
  it("places a named file under a removed worktree by the session's folder, to be read from git", () => {
    const gone = 'C:\\repo\\.claude\\worktrees\\gone';
    assert.deepEqual(docPlace(`${gone}\\docs\\old.md`, { named, roots, cwd: gone }), { root: gone.replace(/\\/g, '/'), rel: 'docs/old.md', live: false });
  });
  it('places a file written from a subfolder of the main checkout relative to the checkout, on disk', () => {
    const file = 'C:\\repo\\tools\\lanes-board\\notes.md';
    assert.deepEqual(docPlace(file, { named: new Set([file]), roots, cwd: 'C:\\repo\\tools\\lanes-board' }), { root: 'C:/repo', rel: 'tools/lanes-board/notes.md', live: true });
  });
  it('refuses a file the transcript never named, one outside the repo and its worktrees, and a way out', () => {
    assert.equal(docPlace(`${W}\\README.md`, { named, roots, cwd: W }), null);
    assert.equal(docPlace('C:\\outside\\notes.md', { named, roots, cwd: 'C:\\outside' }), null);
    assert.equal(docPlace(`${W}\\docs\\..\\..\\..\\..\\..\\secret.md`, { named, roots, cwd: W }), null);
  });
});
