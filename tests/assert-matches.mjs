// The one check the Node tests use that node:assert lacks: Vitest's
// toMatchObject. assert.partialDeepStrictEqual is close, but it treats arrays
// as subsets too, so `names: []` would pass against any list.

import assert from 'node:assert/strict';

const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

/** actual cut down to the keys expected names, recursing into nested objects. */
function pick(actual, expected) {
  if (!isObject(expected) || !isObject(actual)) return actual;
  return Object.fromEntries(Object.keys(expected).map((k) => [k, k in actual ? pick(actual[k], expected[k]) : undefined]));
}

/**
 * Asserts that actual holds every key of expected with a deep-equal value;
 * keys expected leaves out are ignored, at every level of nested objects.
 * Arrays and other values compare whole.
 */
export function assertMatches(actual, expected, message) {
  assert.deepEqual(pick(actual, expected), expected, message);
}
