// Tests for the pilot's side-by-side video's plan (scripts/pilot_video.mjs,
// milestone-1 task 40): each panel cut round its hit, a missing hit kept as
// a note, the whole string's window, and the references' table.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { REFERENCES, OURS, cut, plan, stringCut } from '../scripts/pilot_video.mjs';

describe('pilot video plan', () => {
  it('cuts a panel from before its hit to after it', () => {
    assert.deepEqual(cut(10, 0.7, 0.6), { from: 9.3, duration: 1.3 });
  });

  it('never cuts before the start of the footage', () => {
    assert.deepEqual(cut(0.4, 0.7, 0.6), { from: 0, duration: 1.0 });
  });

  it('plans each light with a panel per source, ours first, a missing hit kept as its note', () => {
    const sources = [
      { name: 'Ours', hits: [1, 2, 3, 4] },
      { name: 'Short', hits: [5, 6, 7, null], missing: 'ends at three' },
    ];
    const p = plan(sources, 0.5, 0.5);
    assert.equal(p.length, 4);
    assert.deepEqual(p[0].map((x) => x.name), ['Ours', 'Short']);
    assert.deepEqual(p[0][1], { name: 'Short', from: 4.5, duration: 1 });
    assert.deepEqual(p[3][1], { name: 'Short', note: 'ends at three' });
  });

  it('cuts the whole string from its first hit to its last', () => {
    assert.deepEqual(stringCut({ hits: [2, 3, 4, 5] }, 0.7, 0.8), { from: 1.3, duration: 4.5 });
    assert.deepEqual(stringCut({ hits: [2, 3, null, null] }, 0.5, 0.5), { from: 1.5, duration: 2 });
  });

  it('holds our four lights and four references, Elden Ring marked as the style', () => {
    assert.equal(OURS.hits.length, 4);
    assert.ok(OURS.hits.every((t, i) => i === 0 || t > OURS.hits[i - 1]), 'our hits in order');
    assert.deepEqual(REFERENCES.map((r) => r.game), ['Elden Ring', 'For Honor', 'Ghost of Tsushima', 'Tekken 8']);
    for (const r of REFERENCES) {
      assert.equal(r.hits.length, 4, r.game);
      assert.ok(r.run && r.label, r.game);
      assert.ok(r.hits.every((t) => t === null || t > 0), r.game);
      if (r.hits.includes(null)) assert.ok(r.missing, `${r.game} says why a hit is missing`);
    }
    assert.match(REFERENCES[0].label, /style/i);
  });
});
