// Tests for tests/assert-matches.mjs, the one check node:assert lacks.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertMatches } from './assert-matches.mjs';

describe('assertMatches', () => {
  it('passes when the actual object has every expected key with an equal value', () => {
    assertMatches({ a: 1, b: 'x', extra: true }, { a: 1, b: 'x' });
  });

  it('checks nested objects as subsets too', () => {
    assertMatches({ counts: { done: 1, open: 2, launched: 0 }, total: 3 }, { counts: { done: 1, open: 2 } });
    assert.throws(() => assertMatches({ counts: { done: 1 } }, { counts: { done: 2 } }), assert.AssertionError);
  });

  it('fails on a missing key or a different value', () => {
    assert.throws(() => assertMatches({ a: 1 }, { a: 1, b: 2 }), assert.AssertionError);
    assert.throws(() => assertMatches({ a: 1 }, { a: '1' }), assert.AssertionError);
    assert.throws(() => assertMatches(null, { a: 1 }), assert.AssertionError);
  });

  it('compares arrays whole, as Vitest did', () => {
    assertMatches({ names: ['a', 'b'] }, { names: ['a', 'b'] });
    assert.throws(() => assertMatches({ names: ['a', 'b'] }, { names: [] }), assert.AssertionError);
    assert.throws(() => assertMatches({ names: ['a', 'b'] }, { names: ['a'] }), assert.AssertionError);
  });

  it('puts the message on a failure', () => {
    assert.throws(() => assertMatches({ a: 1 }, { a: 2 }, 'the a field'), /the a field/);
  });
});
