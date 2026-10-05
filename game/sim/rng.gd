class_name Rng
extends RefCounted
## Port of v0.1-web-mvp:src/sim/rng.ts.
##
## Deterministic pseudo-random numbers (mulberry32) so matches can be replayed in tests.
##
## Port notes: bit-exact with the TS. GDScript ints are signed 64-bit, so the
## state is kept as a uint32 in [0, 2^32) and every step is masked back to 32
## bits, which reproduces JS's `>>> 0` and the int32 wrap of `^`, `|` and
## Math.imul (they all agree modulo 2^32). _imul splits the multiply so the
## product never overflows 64 bits.

const _MASK32: int = 0xFFFFFFFF

var _s: int


func _init(seed_value: int = 1234567) -> void:
	_s = seed_value & _MASK32


## The generator's state (milestone-1 task 5).
func snapshot() -> Dictionary:
	return {&"_s": _s}


## Puts a snapshot() back (milestone-1 task 134).
func restore(s: Dictionary) -> void:
	_s = s[&"_s"]


func next() -> float:
	_s = (_s + 0x6D2B79F5) & _MASK32
	var t: int = _s
	t = _imul(t ^ (t >> 15), t | 1)
	t ^= (t + _imul(t ^ (t >> 7), t | 61)) & _MASK32
	return float((t ^ (t >> 14)) & _MASK32) / 4294967296.0


func range(lo: float, hi: float) -> float:
	return lo + (hi - lo) * next()


func int(lo: int, hi_inclusive: int) -> int:
	return lo + int(floorf(next() * float(hi_inclusive - lo + 1)))


func chance(p: float) -> bool:
	return next() < p


func pick(arr: Array) -> Variant:
	return arr[int(floorf(next() * float(arr.size())))]


## Math.imul for two uint32 values, returned as a uint32 (the int32 result
## modulo 2^32). a * b is split at 16 bits so no partial product reaches 2^63.
static func _imul(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & _MASK32
