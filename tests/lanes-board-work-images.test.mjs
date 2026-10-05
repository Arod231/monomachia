// "Images of the work" (tools/lanes-board/work-images.mjs): which images a
// session got back from its tools count as its progress. The owner's rule
// (PM task 16): renders it opened from its own worktree's shots/ folder, and
// Godot or Blender viewport shots; never Browser-pane screenshots, pasted
// images, images from elsewhere, or anything whose call wasn't seen.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { workImageScanner } from '../tools/lanes-board/work-images.mjs';

const CWD = 'C:\\Users\\o\\Desktop\\Monomachia\\.claude\\worktrees\\lane-x';
const img = (data = 'AAAA', type = 'image/png') => ({ type: 'image', source: { type: 'base64', media_type: type, data } });
const call = (id, name, input, cwd = CWD) => JSON.stringify({ type: 'assistant', cwd, timestamp: '2026-10-05T10:00:00.000Z',
  message: { role: 'assistant', content: [{ type: 'tool_use', id, name, input }] } });
const result = (id, content) => JSON.stringify({ type: 'user', cwd: CWD, timestamp: '2026-10-05T10:00:01.000Z',
  message: { role: 'user', content: [{ type: 'tool_result', tool_use_id: id, content }] } });

function scan(lines) {
  const s = workImageScanner();
  let offset = 0;
  lines.forEach((text, line) => { s.feed(text, line, offset); offset += Buffer.byteLength(text) + 1; });
  return s.found();
}

describe('workImageScanner', () => {
  it('keeps a render the session opened from its own shots folder', () => {
    const lines = [call('t1', 'Read', { file_path: `${CWD}\\shots\\arena.png` }), result('t1', [img('QUJD')])];
    assert.deepEqual(scan(lines), [{ line: 1, n: 0, offset: Buffer.byteLength(lines[0]) + 1, tool: 'Read', source: `${CWD}\\shots\\arena.png`,
      type: 'image/png', time: Date.parse('2026-10-05T10:00:01.000Z') }]);
  });

  it('matches the shots folder whatever the slashes and case', () => {
    const lines = [call('t1', 'Read', { file_path: CWD.replace(/\\/g, '/').toLowerCase() + '/Shots/sub/a.jpg' }), result('t1', [img('x', 'image/jpeg')])];
    assert.equal(scan(lines).length, 1);
  });

  it('keeps Blender and Godot viewport shots, numbering the images in one result', () => {
    const lines = [call('b1', 'mcp__blender__look', {}), result('b1', [{ type: 'text', text: 'Viewport' }, img('a'), img('b')]),
      call('g1', 'mcp__godot__get_screenshot', {}), result('g1', [img('c')]),
      call('g2', 'mcp__godot_mcp__screenshot', {}), result('g2', [img('d')])];
    assert.deepEqual(scan(lines).map((f) => [f.line, f.n, f.tool, f.source]), [
      [1, 0, 'mcp__blender__look', 'Blender viewport'],
      [1, 1, 'mcp__blender__look', 'Blender viewport'],
      [3, 0, 'mcp__godot__get_screenshot', 'Godot viewport'],
      [5, 0, 'mcp__godot_mcp__screenshot', 'Godot viewport'],
    ]);
  });

  it('leaves out Browser-pane screenshots, images from elsewhere and other worktrees, and pasted images', () => {
    const lines = [
      call('c1', 'mcp__Claude_Browser__computer', { action: 'screenshot' }), result('c1', [img()]),
      call('r1', 'Read', { file_path: 'C:\\Users\\o\\Desktop\\reference.png' }), result('r1', [img()]),
      call('r2', 'Read', { file_path: `${CWD}\\docs\\diagram.png` }), result('r2', [img()]),
      call('r4', 'Read', { file_path: `${CWD}\\shots\\..\\docs\\diagram.png` }), result('r4', [img()]),
      call('x1', 'mcp__Claude_Browser__computer', { note: 'mcp__blender__look' }), call('x2', 'mcp__Claude_Browser__computer', {}), result('x2', [img()]),
      call('r3', 'Read', { file_path: 'C:\\Users\\o\\Desktop\\Monomachia\\.claude\\worktrees\\lane-y\\shots\\a.png' }), result('r3', [img()]),
      JSON.stringify({ type: 'user', message: { role: 'user', content: [img()] } }),
      result('unseen', [img()]),
    ];
    assert.deepEqual(scan(lines), []);
  });

  it('judges a call by the folder the session was in when it made it', () => {
    const other = 'C:\\Users\\o\\scratch';
    const lines = [call('t1', 'Read', { file_path: `${other}\\shots\\a.png` }, other), result('t1', [img()])];
    assert.equal(scan(lines).length, 1);
  });
});
