extends GutTest
## Swing entries and the exit (task 7.4): a move enters from the weapon's
## guard on a fresh start and from the previous move's hand-off key when it
## follows one, its keys' frames (and so its active frames) are the same
## either way, and it exits back to the guard on its last frame.

const H := preload("res://tests/sim/sim_helpers.gd")
const EPS: float = 1e-12
const RIGHT: StringName = &"right_hand"
const BODY: StringName = &"body"


func after_each() -> void:
	H.dispose_all()


static func _v(a: Array) -> V3:
	return V3.make(a[0], a[1], a[2])


static func _hand(frame: int, grip: Array, blade: Array, edge: Array, ease: float = 1.0) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.grip = _v(grip)
	k.blade = V3.normalized(_v(blade))
	k.edge = V3.normalized(_v(edge))
	k.ease = ease
	return k


static func _body(frame: int, torso: float, pelvis: float, ease: float = 1.0) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.torso = torso
	k.pelvis = pelvis
	k.ease = ease
	return k


static func _guard() -> Dictionary[StringName, Swing.KeyPose]:
	return {
		RIGHT: _hand(0, [0.05, 1.1, 0.3], [0.0, 0.6, 0.8], [0.0, 0.8, -0.6]),
		BODY: _body(0, 0.0, 5.0),
	}


## A right-to-left cut (30 frames, active 12-14) ending low left, and a
## left-to-right cut (29 frames, active 11-13) starting near there. The
## second's first keys have ease 1 and are peaks (the grip furthest from the
## pivot, the coil furthest round), so the stretch after them would change
## with the entry if their tangents saw it, and an uncapped entry would
## overshoot them.
static func _pair() -> Array[Swing]:
	var guard: Dictionary[StringName, Swing.KeyPose] = _guard()
	var right_cut: Swing = Swing.new(30, guard)
	right_cut.add_track(RIGHT, [
		_hand(6, [0.45, 1.55, 0.05], [0.3, 1.0, -0.2], [-1.0, 0.0, -0.1], 0.0),
		_hand(11, [0.4, 1.4, 0.45], [0.7, 0.0, 0.7], [0.0, -1.0, 0.0]),
		_hand(14, [-0.3, 1.2, 0.5], [-0.7, 0.0, 0.7], [0.0, -1.0, 0.0]),
		_hand(20, [-0.35, 0.95, 0.2], [-0.6, -0.8, 0.0], [0.0, 0.0, -1.0], 0.0),
	] as Array[Swing.KeyPose])
	right_cut.add_track(BODY, [_body(6, 45.0, 20.0, 0.0), _body(20, -30.0, -25.0, 0.0)] as Array[Swing.KeyPose])
	var return_cut: Swing = Swing.new(29, guard)
	return_cut.add_track(RIGHT, [
		_hand(4, [-0.34, 0.97, 0.21], [-0.6, -0.8, 0.05], [0.0, 0.0, -1.0]),
		_hand(8, [-0.4, 1.25, 0.2], [-0.8, 0.2, -0.5], [0.0, -1.0, 0.0], 0.0),
		_hand(12, [0.0, 1.3, 0.6], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0]),
		_hand(18, [0.35, 1.3, 0.3], [0.7, 0.3, 0.0], [0.0, 1.0, 0.0], 0.0),
	] as Array[Swing.KeyPose])
	return_cut.add_track(BODY, [_body(4, -30.0, -25.0), _body(18, 25.0, 20.0, 0.0)] as Array[Swing.KeyPose])
	return [right_cut, return_cut]


func _assert_pose(got: Swing.Sample, want: Swing.KeyPose, what: String) -> void:
	for field: String in ["grip", "blade", "edge"]:
		var g: V3 = got.get(field)
		var w: V3 = want.get(field)
		assert_almost_eq(V3.distance(g, w), 0.0, EPS, "%s: %s" % [what, field])


static func _same(a: Swing.Sample, b: Swing.Sample) -> bool:
	for field: String in ["grip", "blade", "edge", "pole", "pelvis_shift"]:
		var va: V3 = a.get(field)
		var vb: V3 = b.get(field)
		if va.x != vb.x or va.y != vb.y or va.z != vb.z:
			return false
	return a.torso == b.torso and a.pelvis == b.pelvis


func test_a_fresh_start_enters_from_the_guard() -> void:
	var return_cut: Swing = _pair()[1]
	_assert_pose(return_cut.tick(RIGHT, 0), return_cut.guard[RIGHT], "the hand on frame 0")
	_assert_pose(return_cut.sample(RIGHT, 0.0), return_cut.guard[RIGHT], "sampled on frame 0")
	assert_eq([return_cut.tick(BODY, 0).torso, return_cut.tick(BODY, 0).pelvis], [0.0, 5.0], "the guard's coil on frame 0")


func test_a_chained_start_enters_from_the_previous_hand_off() -> void:
	var pair: Array[Swing] = _pair()
	var right_cut: Swing = pair[0]
	var return_cut: Swing = pair[1]
	assert_same(right_cut.hand_off(RIGHT), right_cut.track(RIGHT)[-1], "the hand-off key is the last key")
	_assert_pose(return_cut.tick(RIGHT, 0, right_cut), right_cut.hand_off(RIGHT), "the hand on frame 0")
	_assert_pose(return_cut.sample(RIGHT, 0.0, right_cut), right_cut.hand_off(RIGHT), "sampled on frame 0")
	assert_eq([return_cut.tick(BODY, 0, right_cut).torso, return_cut.tick(BODY, 0, right_cut).pelvis], [-30.0, -25.0],
			"the previous move's coil on frame 0")
	assert_false(_same(return_cut.tick(RIGHT, 2, right_cut), return_cut.tick(RIGHT, 2)), "the entries differ on the way in")


func test_the_keyed_frames_are_the_same_whatever_the_entry() -> void:
	var pair: Array[Swing] = _pair()
	var right_cut: Swing = pair[0]
	var return_cut: Swing = pair[1]
	for part: StringName in [RIGHT, BODY]:
		for f: int in range(4, 30):
			assert_true(_same(return_cut.tick(part, f, right_cut), return_cut.tick(part, f)), "%s on frame %d" % [part, f])
		for t: float in [4.5, 11.25, 12.5, 13.75]:
			assert_true(_same(return_cut.sample(part, t, right_cut), return_cut.sample(part, t)), "%s at %s" % [part, t])


func test_a_move_without_the_part_enters_from_the_guard() -> void:
	var return_cut: Swing = _pair()[1]
	var body_only: Swing = Swing.new(20, return_cut.guard)
	body_only.add_track(BODY, [_body(3, 10.0, 0.0), _body(15, 20.0, 0.0)] as Array[Swing.KeyPose])
	_assert_pose(return_cut.tick(RIGHT, 0, body_only), return_cut.guard[RIGHT], "no hand to hand off")
	assert_eq(return_cut.tick(BODY, 0, body_only).torso, 20.0, "the body hands off")


func test_the_entry_leaves_its_pose_from_rest() -> void:
	var pair: Array[Swing] = _pair()
	for chained_from: Swing in [null, pair[0]]:
		var d: float = 1e-4
		var from: Swing.Sample = pair[1].sample(RIGHT, 0.0, chained_from)
		var moved: float = V3.distance(pair[1].sample(RIGHT, d, chained_from).grip, from.grip) / d
		assert_lt(moved, 1e-3, "the grip starts at rest (chained: %s)" % (chained_from != null))
		var coil: float = absf(pair[1].sample(BODY, d, chained_from).torso - pair[1].sample(BODY, 0.0, chained_from).torso) / d
		assert_lt(coil, 1e-3, "the coil starts at rest (chained: %s)" % (chained_from != null))


func test_the_entry_stays_between_its_ends() -> void:
	var return_cut: Swing = _pair()[1]
	var piv: V3 = SwingSampler.pivot(RIGHT)
	var guard_r: float = V3.distance(return_cut.guard[RIGHT].grip, piv)
	var first_r: float = V3.distance(return_cut.track(RIGHT)[0].grip, piv)
	for i: int in 41:
		var t: float = i * 0.1
		var r: float = V3.distance(return_cut.sample(RIGHT, t).grip, piv)
		assert_between(r, minf(guard_r, first_r) - EPS, maxf(guard_r, first_r) + EPS, "distance from the pivot at %s" % t)
		var torso: float = return_cut.sample(BODY, t).torso
		assert_between(torso, -30.0 - EPS, 0.0 + EPS, "torso coil at %s" % t)


func test_the_exit_reaches_the_guard_on_the_last_frame() -> void:
	var return_cut: Swing = _pair()[1]
	for f: int in [29, 35]:
		_assert_pose(return_cut.tick(RIGHT, f), return_cut.guard[RIGHT], "the hand on frame %d" % f)
		assert_eq([return_cut.tick(BODY, f).torso, return_cut.tick(BODY, f).pelvis], [0.0, 5.0], "the coil on frame %d" % f)
	var d: float = 1e-4
	var arrive: float = V3.distance(return_cut.sample(RIGHT, 29.0 - d).grip, return_cut.sample(RIGHT, 29.0).grip) / d
	assert_lt(arrive, 1e-3, "the grip arrives at rest")
	assert_false(_same(return_cut.tick(RIGHT, 24), return_cut.tick(RIGHT, 18)), "the hand leaves the hand-off key")


func test_a_follow_up_records_the_move_it_follows() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	var seen: Dictionary[StringName, Variant] = {}
	for i: int in 80:
		# the second press before Right Cut's branch point (34, task 31)
		W.step([H.btn(Btn.LIGHT) if i == 0 or i == 30 else H.idle(), H.idle()])
		if f.state == &"attack" and not seen.has(f.atk.def.id):
			seen[f.atk.def.id] = f.atk.chained_from
	assert_eq(seen.keys(), [&"k_l1", &"k_l2"], "Right Cut, then Return Cut")
	assert_null(seen[&"k_l1"], "a fresh start follows nothing")
	assert_same(seen[&"k_l2"], Moves.KATANA.moves[&"k_l1"], "Return Cut follows Right Cut")
