extends GutTest
## The swing sampler (task 7.3): the grip travels on an arc around the
## shoulder-line pivot, the blade turns with the hand's arc frame, keys with
## ease 0 hold still, and each swing keeps a table of its whole frames.

const EPS: float = 1e-12
const R2: float = 0.7071067811865475 # 1 / sqrt(2)
const RIGHT: StringName = &"right_hand"
const BODY: StringName = &"body"


static func _v(a: Array) -> V3:
	return V3.make(a[0], a[1], a[2])


static func _hand(frame: int, grip: Array, blade: Array, edge: Array, ease: float = 1.0, pole: Array = [0.0, 0.0, 0.0]) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.grip = _v(grip)
	k.blade = V3.normalized(_v(blade))
	k.edge = V3.normalized(_v(edge))
	k.pole = _v(pole)
	k.ease = ease
	return k


static func _body(frame: int, torso: float, pelvis: float, shift: Array = [0.0, 0.0, 0.0], ease: float = 1.0) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.torso = torso
	k.pelvis = pelvis
	k.pelvis_shift = _v(shift)
	k.ease = ease
	return k


## A right-to-left cut of 30 frames: loaded high right, cocked and held, then
## across the front to low left, with the body coiling and unwinding.
static func _cut() -> Swing:
	var s: Swing = Swing.new(30)
	s.add_track(RIGHT, [
		_hand(0, [0.1, 1.15, 0.35], [0.0, 0.6, 0.8], [0.0, 0.8, -0.6], 0.0),
		_hand(8, [0.45, 1.6, 0.05], [0.0, 1.0, 0.0], [-1.0, 0.0, 0.0], 0.0, [0.1, 0.2, -0.05]),
		_hand(12, [0.4, 1.4, 0.45], [R2, 0.0, R2], [0.0, -1.0, 0.0]),
		_hand(14, [0.0, 1.3, 0.62], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0]),
		_hand(17, [-0.4, 1.15, 0.4], [-R2, 0.0, R2], [0.0, -1.0, 0.0]),
		_hand(28, [-0.35, 0.95, 0.2], [-0.6, -0.8, 0.0], [0.0, 0.0, -1.0], 0.0),
	] as Array[Swing.KeyPose])
	s.add_track(BODY, [
		_body(0, 0.0, 0.0, [0.0, 0.0, 0.0], 0.0),
		_body(8, 50.0, 25.0, [0.0, -0.03, -0.12], 0.0),
		_body(15, -20.0, -30.0, [0.0, -0.06, 0.1]),
		_body(28, -35.0, -30.0, [0.0, -0.04, 0.05], 0.0),
	] as Array[Swing.KeyPose])
	return s


func _assert_v3(v: V3, want: V3, what: String, eps: float = EPS) -> void:
	assert_almost_eq(v.x, want.x, eps, "%s.x" % what)
	assert_almost_eq(v.y, want.y, eps, "%s.y" % what)
	assert_almost_eq(v.z, want.z, eps, "%s.z" % what)


func test_samples_at_key_frames_are_the_keys() -> void:
	var s: Swing = _cut()
	for k: Swing.KeyPose in s.track(RIGHT):
		for got: Swing.Sample in [s.sample(RIGHT, float(k.frame)), s.tick(RIGHT, k.frame)]:
			_assert_v3(got.grip, k.grip, "grip at %d" % k.frame)
			_assert_v3(got.blade, k.blade, "blade at %d" % k.frame)
			_assert_v3(got.edge, k.edge, "edge at %d" % k.frame)
			_assert_v3(got.pole, k.pole, "pole at %d" % k.frame)
	for k: Swing.KeyPose in s.track(BODY):
		for got: Swing.Sample in [s.sample(BODY, float(k.frame)), s.tick(BODY, k.frame)]:
			assert_almost_eq(got.torso, k.torso, EPS, "torso at %d" % k.frame)
			assert_almost_eq(got.pelvis, k.pelvis, EPS, "pelvis at %d" % k.frame)
			_assert_v3(got.pelvis_shift, k.pelvis_shift, "pelvis shift at %d" % k.frame)


## How fast the grip moves (m per frame) just before and just after frame t.
static func _grip_speeds(s: Swing, t: float) -> Array[float]:
	var d: float = 1e-4
	var at: V3 = s.sample(RIGHT, t).grip
	return [V3.distance(s.sample(RIGHT, t - d).grip, at) / d, V3.distance(s.sample(RIGHT, t + d).grip, at) / d]


func test_ease_0_keys_hold_still() -> void:
	var s: Swing = _cut()
	var d: float = 1e-4
	for f: float in [8.0, 28.0]:
		for speed: float in _grip_speeds(s, f):
			assert_lt(speed, 1e-3, "the grip stops at frame %s" % f)
		var blade: V3 = s.sample(RIGHT, f).blade
		var turn_before: float = JsMath.atan2(V3.length(V3.cross(s.sample(RIGHT, f - d).blade, blade)), V3.dot(s.sample(RIGHT, f - d).blade, blade))
		assert_lt(turn_before / d, 1e-3, "the blade stops turning at frame %s" % f)
	assert_lt(_grip_speeds(s, 0.0)[1], 1e-3, "the grip starts from rest")
	for speed: float in _grip_speeds(s, 14.0):
		assert_gt(speed, 0.05, "the grip sweeps through the ease-1 key at frame 14")
	for f: float in [8.0, 28.0]:
		var at: float = s.sample(BODY, f).torso
		assert_lt(absf(s.sample(BODY, f + d).torso - at) / d, 1e-3, "the coil holds at frame %s" % f)
	assert_gt(absf(s.sample(BODY, 11.0 + d).torso - s.sample(BODY, 11.0).torso) / d, 1.0, "the coil unwinds between its keys")


func test_the_grip_arcs_round_the_pivot() -> void:
	var piv: V3 = SwingSampler.pivot(RIGHT)
	var s: Swing = Swing.new(10)
	s.add_track(RIGHT, [
		_hand(0, [piv.x + 0.5, piv.y, piv.z], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0]),
		_hand(10, [piv.x, piv.y, piv.z + 0.5], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0]),
	] as Array[Swing.KeyPose])
	var mid: V3 = V3.sub(s.sample(RIGHT, 5.0).grip, piv)
	_assert_v3(mid, V3.make(0.5 * R2, 0.0, 0.5 * R2), "halfway is on the arc at 45 degrees, not the chord")
	for f: int in 11:
		assert_almost_eq(V3.distance(s.tick(RIGHT, f).grip, piv), 0.5, EPS, "frame %d is 0.5 m from the pivot" % f)


func test_the_grip_keeps_between_its_keys_distances_from_the_pivot() -> void:
	var s: Swing = _cut()
	var piv: V3 = SwingSampler.pivot(RIGHT)
	var keys: Array[Swing.KeyPose] = s.track(RIGHT)
	for i: int in keys.size() - 1:
		var ra: float = V3.distance(keys[i].grip, piv)
		var rb: float = V3.distance(keys[i + 1].grip, piv)
		for f: int in range(keys[i].frame, keys[i + 1].frame + 1):
			var r: float = V3.distance(s.tick(RIGHT, f).grip, piv)
			assert_between(r, minf(ra, rb) - EPS, maxf(ra, rb) + EPS, "frame %d" % f)
	var body: Array[Swing.KeyPose] = s.track(BODY)
	for i: int in body.size() - 1:
		for f: int in range(body[i].frame, body[i + 1].frame + 1):
			var t: float = s.tick(BODY, f).torso
			assert_between(t, minf(body[i].torso, body[i + 1].torso) - EPS, maxf(body[i].torso, body[i + 1].torso) + EPS, "torso at %d" % f)


func test_the_edge_stays_square_to_the_blade() -> void:
	var s: Swing = _cut()
	for i: int in 300:
		var t: float = i * 0.1
		var got: Swing.Sample = s.sample(RIGHT, t)
		assert_almost_eq(V3.length(got.blade), 1.0, 1e-12, "blade unit length at %s" % t)
		assert_almost_eq(V3.length(got.edge), 1.0, 1e-12, "edge unit length at %s" % t)
		assert_almost_eq(V3.dot(got.blade, got.edge), 0.0, 1e-12, "edge square to the blade at %s" % t)


func test_the_blade_turns_with_the_hand() -> void:
	# A quarter sweep round the pivot with the blade held 30 degrees off the
	# arm (toward the sweep) and tilted up 20 degrees, at both keys.
	var piv: V3 = SwingSampler.pivot(RIGHT)
	var radial_a: V3 = V3.make(1.0, 0.0, 0.0)
	var radial_b: V3 = V3.make(0.0, 0.0, 1.0)
	var about_up: Callable = func(v: V3, deg: float) -> V3: return Quat64.rotate(Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), deg * SimMath.DEG), v)
	var wrist: Callable = func(radial: V3) -> Array[V3]:
		# turn 30 degrees from the radial toward the sweep (about -up here),
		# then tilt 20 degrees up
		var flat: V3 = about_up.call(radial, -30.0)
		var blade: V3 = V3.normalized(V3.add(V3.scale(flat, cos(20.0 * SimMath.DEG)), V3.make(0.0, sin(20.0 * SimMath.DEG), 0.0)))
		var edge: V3 = V3.normalized(V3.cross(blade, V3.make(0.0, 1.0, 0.0)))
		return [blade, edge]
	var a: Array[V3] = wrist.call(radial_a)
	var b: Array[V3] = wrist.call(radial_b)
	var s: Swing = Swing.new(12)
	s.add_track(RIGHT, [
		_hand(0, [piv.x + 0.5, piv.y, piv.z], [a[0].x, a[0].y, a[0].z], [a[1].x, a[1].y, a[1].z]),
		_hand(12, [piv.x, piv.y, piv.z + 0.5], [b[0].x, b[0].y, b[0].z], [b[1].x, b[1].y, b[1].z]),
	] as Array[Swing.KeyPose])
	for f: int in 13:
		var got: Swing.Sample = s.tick(RIGHT, f)
		var radial: V3 = V3.normalized(V3.sub(got.grip, piv))
		var want: Array[V3] = wrist.call(radial)
		_assert_v3(got.blade, want[0], "blade at %d keeps its angle to the arm" % f, 1e-9)
		_assert_v3(got.edge, want[1], "edge at %d" % f, 1e-9)
	# Halfway, the hand has swung 45 degrees round, and the blade's heading with it.
	var flat: Callable = func(v: V3) -> V3: return V3.normalized(V3.make(v.x, 0.0, v.z))
	var start: V3 = flat.call(a[0])
	var half: V3 = flat.call(s.tick(RIGHT, 6).blade)
	assert_almost_eq(JsMath.atan2(V3.length(V3.cross(start, half)), V3.dot(start, half)), 45.0 * SimMath.DEG, 1e-9, "the heading turns 45 degrees")


func test_ticks_are_the_samples_at_whole_frames_and_hold_past_the_end() -> void:
	var s: Swing = _cut()
	for f: int in 31:
		for part: StringName in [RIGHT, BODY]:
			var a: Swing.Sample = s.tick(part, f)
			var b: Swing.Sample = s.sample(part, float(f))
			assert_eq([a.grip.x, a.grip.y, a.grip.z, a.blade.x, a.blade.y, a.blade.z, a.edge.x, a.edge.y, a.edge.z, a.torso, a.pelvis],
					[b.grip.x, b.grip.y, b.grip.z, b.blade.x, b.blade.y, b.blade.z, b.edge.x, b.edge.y, b.edge.z, b.torso, b.pelvis], "%s at %d" % [part, f])
	assert_same(s.tick(RIGHT, 45), s.tick(RIGHT, 30), "past the end holds the last frame")
	assert_same(s.tick(RIGHT, -3), s.tick(RIGHT, 0), "before the start holds frame 0")
	assert_null(s.tick(&"left_hand", 5), "no track, no tick")
	assert_null(s.sample(&"left_hand", 5.0), "no track, no sample")


func test_two_loads_give_bit_identical_tables() -> void:
	var records: Dictionary = {}
	for id: StringName in [&"t_cut", &"t_stabs"]:
		records[id] = {"id": id, "name": String(id), "kind": &"light", "startup": 4, "active": 2, "recovery": 6}
	var first: Dictionary[StringName, Swing] = SwingFile.read("res://tests/fixtures/swings/swing_test.json", AttackDef.finalize_moves(records))
	var second: Dictionary[StringName, Swing] = SwingFile.read("res://tests/fixtures/swings/swing_test.json", AttackDef.finalize_moves(records))
	var compared: int = 0
	for id: StringName in first:
		for part: StringName in first[id].parts():
			for f: int in first[id].last_frame + 1:
				var a: Swing.Sample = first[id].tick(part, f)
				var b: Swing.Sample = second[id].tick(part, f)
				for field: String in ["grip", "blade", "edge", "pole", "pelvis_shift"]:
					var va: V3 = a.get(field)
					var vb: V3 = b.get(field)
					assert_true(va.x == vb.x and va.y == vb.y and va.z == vb.z, "%s.%s %s at %d" % [id, part, field, f])
				assert_true(a.torso == b.torso and a.pelvis == b.pelvis, "%s.%s coil at %d" % [id, part, f])
				compared += 1
	assert_eq(compared, 4 * 13, "every frame (0-12) of the fixture's four tracks")
