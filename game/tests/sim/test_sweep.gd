extends GutTest
## Blade sweeps (task 7.8): the quad a blade covers from one tick to the
## next, tested against a hurt capsule grown by half the blade's thickness,
## with where the blade went deepest, how deep, and the most of it inside at
## any moment of the tick. The defender stands at the origin, 0.35 m round
## from the feet to 1.75 m (an axis from 0.35 to 1.4 m up), facing an
## attacker toward -Z, and the blade is a Katana's, 15 mm thick, so it
## touches within 0.3575 m of the axis. The answers are worked out by hand;
## for twisted quads they're checked against points sampled across the quad.

const RADIUS: float = 0.35
const HALF: float = 0.0075
const REACH: float = RADIUS + HALF
const EPS: float = 1e-12
## The most blade inside is found by a search through the tick, to well
## under a micrometre.
const LENGTH_EPS: float = 1e-6

## Twisted quads, each blade turning out of the plane it travels in: base and
## tip at the last tick, then at this one.
const TWISTED: Array[Array] = [
	# a rising cut through the body
	[[-0.5, 0.9, -0.6], [0.3, 1.5, -0.2], [-0.3, 1.0, -0.5], [0.4, 0.9, 0.3]],
	# a cut over the head, grazing it
	[[-0.4, 1.6, -0.5], [0.4, 1.85, -0.3], [-0.3, 1.75, 0.4], [0.5, 1.7, 0.5]],
	# a cut down the side, the tip in
	[[0.3, 0.6, -0.7], [0.45, 1.3, -0.2], [0.5, 0.7, -0.6], [0.3, 1.2, 0.4]],
	# the same cut 25 cm further off, missing
	[[0.55, 0.6, -0.7], [0.7, 1.3, -0.2], [0.75, 0.7, -0.6], [0.55, 1.2, 0.4]],
]


static func _v(x: float, y: float, z: float) -> V3:
	return V3.make(x, y, z)


static func _body() -> SimCapsule:
	return SimCapsule.make(_v(0.0, 0.35, 0.0), _v(0.0, 1.4, 0.0), RADIUS)


static func _sweep(base0: V3, tip0: V3, base1: V3, tip1: V3, half: float = HALF) -> BladeSweep:
	return BladeSweep.touch(base0, tip0, base1, tip1, half, _body())


## A blade held still from `base` to `tip`.
static func _held(base: V3, tip: V3) -> BladeSweep:
	return _sweep(base, tip, base, tip)


func _assert_touch(s: BladeSweep, depth: float, inside: float, what: String) -> void:
	assert_not_null(s, "%s touches" % what)
	if s == null:
		return
	assert_almost_eq(s.depth, depth, EPS, "%s: the depth" % what)
	assert_almost_eq(s.length_inside, inside, LENGTH_EPS, "%s: the blade inside" % what)


func _assert_contact(s: BladeSweep, want: V3, what: String) -> void:
	if s != null:
		assert_almost_eq(V3.distance(s.contact, want), 0.0, EPS, "%s: the contact %s, want %s" % [what, s.contact, want])


## The contact is at (x, from y_lo to y_hi, z).
func _assert_contact_on(s: BladeSweep, x: float, y_lo: float, y_hi: float, z: float, what: String) -> void:
	if s != null:
		assert_almost_eq(s.contact.x, x, EPS, "%s: the contact's x" % what)
		assert_almost_eq(s.contact.z, z, EPS, "%s: the contact's z" % what)
		assert_between(s.contact.y, y_lo, y_hi, "%s: the contact's height" % what)


func test_a_blade_crossing_the_body_touches_at_the_axis() -> void:
	# a level blade, 1 m long, carried straight through the defender at 1.2 m
	var s: BladeSweep = _sweep(_v(-0.6, 1.2, -0.5), _v(0.4, 1.2, -0.5), _v(-0.6, 1.2, 0.5), _v(0.4, 1.2, 0.5))
	# right across the capsule as it passes the axis
	_assert_touch(s, REACH, 2.0 * REACH, "a blade through the body")
	_assert_contact(s, _v(0.0, 1.2, 0.0), "where it crosses the axis")


func test_a_blade_passing_above_or_behind_misses() -> void:
	var y: float = 1.4 + REACH + 0.01
	assert_null(_sweep(_v(-0.6, y, -0.5), _v(0.4, y, -0.5), _v(-0.6, y, 0.5), _v(0.4, y, 0.5)),
			"a level blade carried 1 cm over the head")
	var z: float = REACH + 0.04
	assert_null(_sweep(_v(-0.6, 0.9, z), _v(-0.6, 1.6, z), _v(0.6, 0.9, z), _v(0.6, 1.6, z)),
			"an upright blade swept across 4 cm behind the defender")


func test_the_graze_limit_to_the_centimetre() -> void:
	# no blade, a Katana's and a Greatsword's: each touches 5 mm inside the
	# capsule's radius plus half its thickness and misses 5 mm outside, down
	# the side and over the head
	for half: float in [0.0, 0.0075, 0.011]:
		var reach: float = RADIUS + half
		for off: float in [-0.005, 0.005]:
			var z: float = reach + off
			var side: BladeSweep = _sweep(_v(-0.6, 0.9, z), _v(-0.6, 1.6, z), _v(0.6, 0.9, z), _v(0.6, 1.6, z), half)
			var y: float = 1.4 + reach + off
			var over: BladeSweep = _sweep(_v(-0.6, y, -0.5), _v(0.4, y, -0.5), _v(-0.6, y, 0.5), _v(0.4, y, 0.5), half)
			var what: String = "%.1f cm from the limit, %.1f mm half thick" % [off * 100.0, half * 1000.0]
			if off > 0.0:
				assert_null(side, "an upright blade down the side, %s" % what)
				assert_null(over, "a level blade over the head, %s" % what)
				continue
			# the upright blade passing the axis from 0.9 m to the top of the
			# head's reach, and the level one across the top of the head
			_assert_touch(side, 0.005, 1.4 + sqrt(reach * reach - z * z) - 0.9, "an upright blade down the side, %s" % what)
			_assert_contact_on(side, 0.0, 0.9, 1.4, z, "an upright blade down the side, %s" % what)
			_assert_touch(over, 0.005, 2.0 * sqrt(reach * reach - (y - 1.4) * (y - 1.4)), "a level blade over the head, %s" % what)
			_assert_contact(over, _v(0.0, y, 0.0), "a level blade over the head, %s" % what)


func test_a_blade_that_does_not_move() -> void:
	var s: BladeSweep = _held(_v(-0.6, 1.2, -0.2), _v(0.4, 1.2, -0.2))
	_assert_touch(s, REACH - 0.2, 2.0 * sqrt(REACH * REACH - 0.04), "a level blade held 20 cm in front of the axis")
	_assert_contact(s, _v(0.0, 1.2, -0.2), "a level blade held 20 cm in front of the axis")
	assert_null(_held(_v(-0.6, 1.2, -0.4), _v(0.4, 1.2, -0.4)), "a level blade held 40 cm in front")
	# upright blades held 30 cm beside the axis, reaching past its top: inside
	# up to the top of the head's reach
	var top: float = 1.4 + sqrt(REACH * REACH - 0.09)
	var up: BladeSweep = _held(_v(0.3, 1.2, 0.0), _v(0.3, 1.9, 0.0))
	_assert_touch(up, REACH - 0.3, top - 1.2, "an upright blade held beside the head, point up")
	_assert_contact_on(up, 0.3, 1.2, 1.4, 0.0, "an upright blade held beside the head, point up")
	var down: BladeSweep = _held(_v(0.3, 2.2, 0.0), _v(0.3, 1.5, 0.0))
	_assert_touch(down, REACH - sqrt(0.09 + 0.01), top - 1.5, "an upright blade held beside the head, point down")
	_assert_contact(down, _v(0.3, 1.5, 0.0), "an upright blade held beside the head, point down")


func test_no_tunnelling_at_0_6_m_per_tick() -> void:
	# an upright blade 30 cm in front of the axis, moving 0.6 m across it in
	# a tick: it misses where it starts and where it ends
	var b0: V3 = _v(-0.3, 0.9, -0.3)
	var t0: V3 = _v(-0.3, 1.6, -0.3)
	var b1: V3 = _v(0.3, 0.9, -0.3)
	var t1: V3 = _v(0.3, 1.6, -0.3)
	assert_null(_held(b0, t0), "the upright blade misses at the last tick")
	assert_null(_held(b1, t1), "and at this one")
	var flat: BladeSweep = _sweep(b0, t0, b1, t1)
	_assert_touch(flat, REACH - 0.3, 1.4 + sqrt(REACH * REACH - 0.09) - 0.9, "the upright blade passing")
	_assert_contact_on(flat, 0.0, 0.9, 1.4, -0.3, "the upright blade passing")
	# a level blade's tip crossing 25 cm in front of the axis
	b0 = _v(-0.3, 1.2, -1.0)
	t0 = _v(-0.3, 1.2, -0.25)
	b1 = _v(0.3, 1.2, -1.0)
	t1 = _v(0.3, 1.2, -0.25)
	assert_null(_held(b0, t0), "the level blade misses at the last tick")
	assert_null(_held(b1, t1), "and at this one")
	var tip: BladeSweep = _sweep(b0, t0, b1, t1)
	_assert_touch(tip, REACH - 0.25, REACH - 0.25, "the level blade's tip passing")
	_assert_contact(tip, _v(0.0, 1.2, -0.25), "the level blade's tip passing")


func test_parallel_sweeps() -> void:
	# an upright blade swept through the axis, so its quad holds the axis:
	# all of it is inside as it passes
	var through: BladeSweep = _sweep(_v(-0.5, 0.9, 0.0), _v(-0.5, 1.6, 0.0), _v(0.5, 0.9, 0.0), _v(0.5, 1.6, 0.0))
	_assert_touch(through, REACH, 0.7, "an upright blade swept through the axis")
	_assert_contact_on(through, 0.0, 0.9, 1.4, 0.0, "an upright blade swept through the axis")
	# a thrust: the blade moves along its own line, so its quad is a line,
	# and the tip ends 10 cm short of the axis
	var thrust: BladeSweep = _sweep(_v(0.0, 1.2, -1.4), _v(0.0, 1.2, -0.6), _v(0.0, 1.2, -0.9), _v(0.0, 1.2, -0.1))
	_assert_touch(thrust, REACH - 0.1, REACH - 0.1, "a thrust")
	_assert_contact(thrust, _v(0.0, 1.2, -0.1), "a thrust")
	# an upright blade dropping 0.4 m beside the body, 30 cm from the axis:
	# all of it is inside at the end
	var drop: BladeSweep = _sweep(_v(0.3, 1.2, 0.0), _v(0.3, 1.9, 0.0), _v(0.3, 0.8, 0.0), _v(0.3, 1.5, 0.0))
	_assert_touch(drop, REACH - 0.3, 0.7, "a blade dropping beside the body")
	_assert_contact_on(drop, 0.3, 0.8, 1.4, 0.0, "a blade dropping beside the body")


func test_the_most_blade_inside_at_any_moment_of_the_tick() -> void:
	# a level blade's tip crossing 25 cm in front of the axis, nearest it
	# 58.75% of the way through the tick
	var tip: BladeSweep = _sweep(_v(-0.47, 1.2, -1.0), _v(-0.47, 1.2, -0.25), _v(0.33, 1.2, -1.0), _v(0.33, 1.2, -0.25))
	_assert_touch(tip, REACH - 0.25, REACH - 0.25, "a tip passing late in the tick")
	# a dagger's blade, 26 cm, carried level through the body: all of it
	var dagger: BladeSweep = _sweep(_v(-0.13, 1.2, -0.6), _v(0.13, 1.2, -0.6), _v(-0.13, 1.2, 0.6), _v(0.13, 1.2, 0.6))
	_assert_touch(dagger, REACH, 0.26, "a dagger's blade through the body")
	# an upright blade grazing the side by 0.1 mm, inside for under a
	# fortieth of the tick, nearest at 53.125%: still the blade from 0.9 m to
	# the top of the head's reach
	var z: float = -(REACH - 0.0001)
	var graze: BladeSweep = _sweep(_v(-0.31875, 0.9, z), _v(-0.31875, 1.6, z), _v(0.28125, 0.9, z), _v(0.28125, 1.6, z))
	_assert_touch(graze, 0.0001, 1.4 + sqrt(REACH * REACH - z * z) - 0.9, "a brief graze")


## Points across the quad's two triangles, base0, tip0, tip1 and base0, tip1,
## base1, at `n` steps along each side.
static func _samples(q: Array[V3], n: int) -> Array[V3]:
	var out: Array[V3] = []
	for tri: Array[V3] in [[q[0], q[1], q[3]], [q[0], q[3], q[2]]] as Array[Array]:
		for i: int in n + 1:
			for j: int in n + 1 - i:
				var u: float = float(i) / n
				var w: float = float(j) / n
				out.append(V3.add(V3.add(V3.scale(tri[0], 1.0 - u - w), V3.scale(tri[1], u)), V3.scale(tri[2], w)))
	return out


## The most of the blade inside, counted 5 mm at a time along the blade at
## each 1% of the tick.
static func _counted_inside(q: Array[V3], body: SimCapsule) -> float:
	var most: float = 0.0
	for i: int in 101:
		var base: V3 = V3.lerp(q[0], q[2], i / 100.0)
		var tip: V3 = V3.lerp(q[1], q[3], i / 100.0)
		var steps: int = ceili(V3.distance(base, tip) / 0.005)
		var inside: int = 0
		for j: int in steps:
			var p: V3 = V3.lerp(base, tip, (j + 0.5) / steps)
			if SimMath.segment_distance(p, p, body.a, body.b) <= REACH:
				inside += 1
		most = maxf(most, V3.distance(base, tip) * inside / steps)
	return most


func test_contact_points_on_twisted_quads() -> void:
	var body: SimCapsule = _body()
	var touched: int = 0
	for corners: Array in TWISTED:
		var q: Array[V3] = []
		for c: Array in corners:
			q.append(_v(c[0], c[1], c[2]))
		var what: String = "the quad from %s" % q[0]
		var step: float = 0.0
		for e: Array in [[0, 1], [1, 3], [3, 2], [2, 0], [0, 3]]:
			step = maxf(step, V3.distance(q[e[0]], q[e[1]]) / 40.0)
		var samples: Array[V3] = _samples(q, 40)
		var nearest: float = INF
		for p: V3 in samples:
			nearest = minf(nearest, SimMath.segment_distance(p, p, body.a, body.b))
		var s: BladeSweep = BladeSweep.touch(q[0], q[1], q[2], q[3], HALF, body)
		if s == null:
			assert_gt(nearest, REACH, "%s misses, and no point on it is within reach" % what)
			continue
		touched += 1
		var off_axis: float = REACH - s.depth
		assert_lte(off_axis, nearest + EPS, "%s: no point on it is nearer the axis than the contact" % what)
		assert_gte(off_axis, nearest - step, "%s: the contact is as near as the nearest point found" % what)
		assert_almost_eq(SimMath.segment_distance(s.contact, s.contact, body.a, body.b), off_axis, EPS,
				"%s: the contact is that far from the axis" % what)
		var to_quad: float = INF
		for p: V3 in samples:
			to_quad = minf(to_quad, V3.distance(p, s.contact))
		assert_lt(to_quad, step, "%s: the contact is on the quad" % what)
		assert_almost_eq(s.length_inside, _counted_inside(q, body), 0.01, "%s: the most blade inside" % what)
	assert_eq(touched, 3, "three of the quads touch")
