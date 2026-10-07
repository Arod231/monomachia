class_name BladeSweep
extends RefCounted
## A blade sweep (task 7.8): the surface a strike segment covers from one
## tick to the next, tested against a hurt capsule. Between the ticks each
## end of the segment travels in a straight line, so the sweep is the quad
## base0, tip0, tip1, base1. A blade that turns out of the plane it travels in
## makes a twisted quad, which isn't flat, so the sweep is taken as the two
## flat triangles base0, tip0, tip1 and base0, tip1, base1. It touches when
## any point of it comes within the capsule's radius plus half the segment's
## thickness of the capsule's axis, so a blade passing a hair further off
## misses, as it visibly does. Pure 64-bit geometry, the same on every
## machine.

## How many even steps through the tick the search for the most blade inside
## tries, and how many golden sections then close in on the best.
const _STEPS: int = 16
const _SECTIONS: int = 30
## (sqrt(5) - 1) / 2
const _GOLDEN: float = 0.6180339887498949

## The sweep's point nearest the capsule's axis: where the blade went deepest
## in the tick. Where the sweep holds the axis along a line, the first such
## point found.
var contact: V3 = V3.make()
## How far into the capsule the blade went: the capsule's radius plus half the
## segment's thickness, less the contact's distance from the axis.
var depth: float = 0.0
## The most of the segment inside the capsule, grown as for the touch, at any
## moment of the tick, in metres along it: what the reach tests measure (task
## 7.14). Found by a search through the tick, to well under a micrometre. It
## can be 0 on a touch: a twisted quad's triangles stand a little off the
## blade's path between its corners.
var length_inside: float = 0.0
## How the tip travelled through the tick, tip0 to tip1 (milestone-1 task
## 34: the parry's sweep, which picks the deflect pair).
var sweep: V3 = V3.make()


class _Nearest:
	var point: V3 = null
	var distance: float = INF

	## Keeps `p`, `d` from the axis, when it's nearer than any point so far.
	func offer(p: V3, d: float) -> void:
		if d < distance:
			point = p
			distance = d


## The touch of a segment moving from `base0` to `tip0` at the last tick to
## `base1` to `tip1` at this one, with half its thickness `half_thickness`, on
## `capsule`; null when it misses.
static func touch(base0: V3, tip0: V3, base1: V3, tip1: V3, half_thickness: float, capsule: SimCapsule) -> BladeSweep:
	var reach: float = capsule.radius + half_thickness
	# The nearest point is where the axis crosses a triangle, or over a
	# triangle from an end of the axis, or on one of the triangles' edges.
	var near: _Nearest = _Nearest.new()
	_face(base0, tip0, tip1, capsule.a, capsule.b, near)
	_face(base0, tip1, base1, capsule.a, capsule.b, near)
	for edge: Array[V3] in [[base0, tip0], [tip0, tip1], [tip1, base1], [base1, base0], [base0, tip1]] as Array[Array]:
		var p: Array[V3] = SimMath.segment_closest(edge[0], edge[1], capsule.a, capsule.b)
		near.offer(p[0], V3.distance(p[0], p[1]))
	if near.distance > reach:
		return null
	var s: BladeSweep = BladeSweep.new()
	s.contact = near.point
	s.depth = reach - near.distance
	s.length_inside = _most_inside([base0, tip0, base1, tip1], capsule, reach)
	s.sweep = V3.sub(tip1, tip0)
	return s


## Offers `near` the points of the triangle p0, p1, p2 inside its edges that
## might be nearest the axis from `a` to `b`: where the axis crosses it, and
## where each end of the axis stands over it. A triangle with no area is all
## edges.
static func _face(p0: V3, p1: V3, p2: V3, a: V3, b: V3, near: _Nearest) -> void:
	var n: V3 = V3.cross(V3.sub(p1, p0), V3.sub(p2, p0))
	var nn: float = V3.dot(n, n)
	if nn <= 1e-18:
		return
	var da: float = V3.dot(n, V3.sub(a, p0))
	var db: float = V3.dot(n, V3.sub(b, p0))
	if da != db and ((da <= 0.0 and db >= 0.0) or (da >= 0.0 and db <= 0.0)):
		var x: V3 = V3.lerp(a, b, da / (da - db))
		if _within(x, p0, p1, p2, n):
			near.offer(x, 0.0)
	for end: Array in [[a, da], [b, db]]:
		var over: V3 = V3.sub(end[0], V3.scale(n, end[1] / nn))
		if _within(over, p0, p1, p2, n):
			near.offer(over, absf(end[1]) / sqrt(nn))


## Whether `x`, in the plane of the triangle p0, p1, p2 with normal `n`, is
## inside its edges.
static func _within(x: V3, p0: V3, p1: V3, p2: V3, n: V3) -> bool:
	return V3.dot(n, V3.cross(V3.sub(p1, p0), V3.sub(x, p0))) >= 0.0 \
			and V3.dot(n, V3.cross(V3.sub(p2, p1), V3.sub(x, p1))) >= 0.0 \
			and V3.dot(n, V3.cross(V3.sub(p0, p2), V3.sub(x, p2))) >= 0.0


## The most of the segment inside the capsule, grown to `reach`, at any moment
## of the tick, `q` being base0, tip0, base1, tip1. The tick is tried at even
## steps, and the best step's neighbourhood is then narrowed by golden
## sections. A moment with none of the segment inside scores how far it is
## from reaching the capsule, below 0, so a graze too brief for the steps is
## still closed in on.
static func _most_inside(q: Array[V3], capsule: SimCapsule, reach: float) -> float:
	var best: float = -INF
	var at: int = 0
	for i: int in _STEPS + 1:
		var score: float = _score(q, capsule, reach, float(i) / _STEPS)
		if score > best:
			best = score
			at = i
	var lo: float = maxf(float(at - 1) / _STEPS, 0.0)
	var hi: float = minf(float(at + 1) / _STEPS, 1.0)
	var c: float = hi - _GOLDEN * (hi - lo)
	var d: float = lo + _GOLDEN * (hi - lo)
	var fc: float = _score(q, capsule, reach, c)
	var fd: float = _score(q, capsule, reach, d)
	best = maxf(best, maxf(fc, fd))
	for i: int in _SECTIONS:
		if fc >= fd:
			hi = d
			d = c
			fd = fc
			c = hi - _GOLDEN * (hi - lo)
			fc = _score(q, capsule, reach, c)
			best = maxf(best, fc)
		else:
			lo = c
			c = d
			fc = fd
			d = lo + _GOLDEN * (hi - lo)
			fd = _score(q, capsule, reach, d)
			best = maxf(best, fd)
	return maxf(best, 0.0)


## The length of the segment inside the capsule at `t` through the tick or,
## when none of it is, how far it is from reaching it, below 0.
static func _score(q: Array[V3], capsule: SimCapsule, reach: float, t: float) -> float:
	var base: V3 = V3.lerp(q[0], q[2], t)
	var tip: V3 = V3.lerp(q[1], q[3], t)
	var inside: float = _inside(base, tip, capsule, reach)
	if inside > 0.0:
		return inside
	return minf(reach - SimMath.segment_distance(base, tip, capsule.a, capsule.b), 0.0)


## The length of the segment from `base` to `tip` within `reach` of the
## capsule's axis. The grown capsule is the cylinder round the axis and a
## ball at each end, and since it's convex, the stretches of the segment's
## line inside the three meet in one.
static func _inside(base: V3, tip: V3, capsule: SimCapsule, reach: float) -> float:
	var d: V3 = V3.sub(tip, base)
	var lo: float = INF
	var hi: float = -INF
	for span: PackedFloat64Array in [_in_ball(base, d, capsule.a, reach), _in_ball(base, d, capsule.b, reach),
			_in_cylinder(base, d, capsule.a, capsule.b, reach)]:
		if span[0] <= span[1]:
			lo = minf(lo, span[0])
			hi = maxf(hi, span[1])
	lo = maxf(lo, 0.0)
	hi = minf(hi, 1.0)
	return V3.length(d) * (hi - lo) if hi > lo else 0.0


## Where the line p + u d is within `r` of `o`, as [from, to] in u, from
## after to for nowhere.
static func _in_ball(p: V3, d: V3, o: V3, r: float) -> PackedFloat64Array:
	var w: V3 = V3.sub(p, o)
	return _below_zero(V3.dot(d, d), V3.dot(d, w), V3.dot(w, w) - r * r)


## Where the line p + u d is within `r` of the axis from `a` to `b`, between
## the planes square to the axis at its ends, as [from, to] in u, from after
## to for nowhere.
static func _in_cylinder(p: V3, d: V3, a: V3, b: V3, r: float) -> PackedFloat64Array:
	var axis: V3 = V3.sub(b, a)
	var aa: float = V3.dot(axis, axis)
	if aa <= 1e-24:
		return PackedFloat64Array([INF, -INF])
	# how far along the axis, from a (0) to b (1), and the part square to it
	var rel: V3 = V3.sub(p, a)
	var along_p: float = V3.dot(rel, axis) / aa
	var along_d: float = V3.dot(d, axis) / aa
	var off_p: V3 = V3.sub(rel, V3.scale(axis, along_p))
	var off_d: V3 = V3.sub(d, V3.scale(axis, along_d))
	var span: PackedFloat64Array = _below_zero(V3.dot(off_d, off_d), V3.dot(off_d, off_p), V3.dot(off_p, off_p) - r * r)
	if along_d == 0.0:
		if along_p < 0.0 or along_p > 1.0:
			return PackedFloat64Array([INF, -INF])
		return span
	var u0: float = -along_p / along_d
	var u1: float = (1.0 - along_p) / along_d
	span[0] = maxf(span[0], minf(u0, u1))
	span[1] = minf(span[1], maxf(u0, u1))
	return span


## Where a u² + 2 b u + c <= 0, for a >= 0, as [from, to] in u: everywhere or
## nowhere when a is 0, and from after to for nowhere.
static func _below_zero(a: float, b: float, c: float) -> PackedFloat64Array:
	if a <= 1e-24:
		return PackedFloat64Array([-INF, INF] if c <= 0.0 else [INF, -INF])
	var disc: float = b * b - a * c
	if disc < 0.0:
		return PackedFloat64Array([INF, -INF])
	var root: float = sqrt(disc)
	return PackedFloat64Array([(-b - root) / a, (-b + root) / a])
