// Seeded random numbers, so every generated or processed file is repeatable.

/** Mulberry32: a small, fast 32-bit generator. Returns floats in [0, 1). */
export function mulberry32(seed) {
  let a = seed >>> 0;
  return function next() {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** A 32-bit seed from a string (FNV-1a), for per-file seeds from names. */
export function seedFrom(text) {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** Helpers bound to one generator. */
export function makeRandom(seed) {
  const next = mulberry32(typeof seed === 'string' ? seedFrom(seed) : seed);
  return {
    next,
    /** uniform in [lo, hi) */
    range: (lo, hi) => lo + (hi - lo) * next(),
    /** uniform in [-1, 1) */
    bipolar: () => next() * 2 - 1,
    /** integer in [lo, hi] */
    int: (lo, hi) => lo + Math.floor(next() * (hi - lo + 1)),
    pick: (arr) => arr[Math.floor(next() * arr.length)],
    chance: (p) => next() < p,
  };
}
