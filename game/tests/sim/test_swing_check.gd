extends GutTest
## SwingCheck (task 7.7): the elbow solve, the wrist's bend and turn, the
## blade's clearance from the body and the arms, and the face in the wind-up,
## on swings built arm by arm. _key() builds each key forward, joint by joint
## from the shoulder, so the check's solve (backward, from the grip) is
## measured against a known arm.

const EPS: float = 1e-9
const RIGHT: StringName = &"right_hand"
const LEFT: StringName = &"left_hand"

var rogue: ReferenceBody


func before_all() -> void:
	rogue = ReferenceBody.of(&"rogue")


## A one-handed test sword: the blade from 9 cm up the handle to 75 cm, 1 cm
## thick.
static func _sword() -> WeaponDef:
	var w: WeaponDef = WeaponDef.new()
	w.id = &"test_sword"
	w.blade = StrikeSegment.make(V3.make(0.0, 0.09, 0.0), V3.make(0.0, 0.75, 0.0), 0.01)
	return w


static func _v(x: float, y: float, z: float) -> V3:
	return V3.make(x, y, z)


## A key for the hand on `side` at `frame`, its arm built from the shoulder of
## `body` (turned by `torso` degrees of coil): the upper arm along `upper`,
## the forearm along `fore`, the hand straight along the forearm with its
## thumb (the blade) as near `thumb` as is square to it, then turned `turn`
## degrees toward the thumb and bent `bend` degrees toward the flat. The edge
## runs along the knuckles; the check turns the hand round the handle to its
## forearm whatever the edge, so a hand built bent is seated straight. The
## pole tweak puts the elbow where it was built.
static func _key(body: ReferenceBody, side: StringName, frame: int, upper: V3, fore: V3, thumb: V3,
		bend: float = 0.0, turn: float = 0.0, torso: float = 0.0) -> Swing.KeyPose:
	var posed: ReferenceBody = body.posed(torso, 0.0, V3.make())
	var shoulder: V3 = posed.shoulders[side]
	var elbow: V3 = V3.add(shoulder, V3.scale(V3.normalized(upper), body.upper_arm))
	var forearm: V3 = V3.normalized(fore)
	var wrist: V3 = V3.add(elbow, V3.scale(forearm, body.forearm))
	var along: V3 = forearm
	var t: V3 = V3.normalized(V3.sub(thumb, V3.scale(along, V3.dot(thumb, along))))
	var flat: V3 = V3.cross(t, along)
	var q: Quat64 = Quat64.from_axis_angle(flat, turn * SimMath.DEG)
	along = Quat64.rotate(q, along)
	t = Quat64.rotate(q, t)
	q = Quat64.from_axis_angle(t, bend * SimMath.DEG)
	along = Quat64.rotate(q, along)
	flat = Quat64.rotate(q, flat)
	var w: V3 = body.wrist_in_fist(side)
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.grip = V3.sub(wrist, V3.add(V3.add(V3.scale(along, w.x), V3.scale(t, w.y)), V3.scale(flat, w.z)))
	k.blade = t
	k.edge = along
	var chest: Quat64 = Quat64.from_axis_angle(V3.normalized(V3.sub(posed.spine_top, posed.spine_base)), torso * SimMath.DEG)
	var p: Array = SwingCheck.ELBOW_POLES[side]
	k.pole = V3.sub(V3.sub(elbow, shoulder), Quat64.rotate(chest, V3.make(p[0], p[1], p[2])))
	return k


## The elbow `_key()` built for the same arm.
static func _built_elbow(body: ReferenceBody, side: StringName, upper: V3) -> V3:
	return V3.add(body.shoulders[side], V3.scale(V3.normalized(upper), body.upper_arm))


static func _body_key(frame: int, torso: float) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.torso = torso
	return k


static func _move(swing: Swing, startup: int, active: int, recovery: int) -> AttackDef:
	var m: AttackDef = AttackDef.new()
	m.id = &"test_move"
	m.startup = startup
	m.active = active
	m.recovery = recovery
	m.swing = swing
	return m


## A right-handed cut (8 frames of wind-up, 3 active, 14 of recovery) on
## `body`: from a guard with the blade upright, cocked to the right, across the
## front from right to left, and on into a follow-through on the left.
static func _cut(body: ReferenceBody) -> Swing:
	var guard: Dictionary[StringName, Swing.KeyPose] = {
		RIGHT: _key(body, &"right", 0, _v(0.15, -0.9, 0.4), _v(-0.15, 0.35, 0.92), _v(0.0, 1.0, 0.6)),
	}
	var s: Swing = Swing.new(25, guard)
	s.add_track(RIGHT, [
		_key(body, &"right", 4, _v(0.45, -0.75, 0.35), _v(0.1, 0.45, 0.88), _v(1.0, 0.6, 0.0)),
		_key(body, &"right", 8, _v(0.3, -0.8, 0.5), _v(-0.1, 0.2, 0.97), _v(1.0, 0.3, 0.0)),
		_key(body, &"right", 11, _v(0.0, -0.6, 0.8), _v(-0.4, 0.1, 0.9), _v(-1.0, 0.3, 0.0)),
		_key(body, &"right", 15, _v(-0.1, -0.7, 0.7), _v(-0.7, -0.1, 0.7), _v(-0.3, 1.0, 0.0)),
	] as Array[Swing.KeyPose])
	return s


## The cut with its key at `frame` replaced by `key`.
static func _cut_with(body: ReferenceBody, frame: int, key: Swing.KeyPose) -> Swing:
	var cut: Swing = _cut(body)
	var keys: Array[Swing.KeyPose] = []
	for k: Swing.KeyPose in cut.track(RIGHT):
		keys.append(key if k.frame == frame else k)
	var s: Swing = Swing.new(cut.last_frame, cut.guard)
	s.add_track(RIGHT, keys)
	return s


## The one problem of `problems` that mentions every one of `words`.
func _assert_named(problems: Array[String], words: Array, what: String) -> void:
	var hits: Array[String] = []
	for p: String in problems:
		var all: bool = true
		for word: String in words:
			all = all and p.contains(word)
		if all:
			hits.append(p)
	assert_eq(hits.size(), 1, "%s: one problem names %s, in %s" % [what, words, problems])


## The one problem of `problems` that mentions every one of `words` has its
## worst moment within half a frame of `frame`, in a stretch that holds it.
func _assert_at(problems: Array[String], words: Array, frame: float, what: String) -> void:
	_assert_named(problems, words, what)
	for p: String in problems:
		var all: bool = true
		for word: String in words:
			all = all and p.contains(word)
		if not all:
			continue
		var worst: float = float(p.get_slice("on frame ", 1).get_slice(" ", 0))
		var span: String = p.get_slice(" (", p.get_slice_count(" (") - 1).trim_suffix(")")
		var first: float = float(span.get_slice(" ", 1))
		var last: float = float(span.get_slice(" ", 3)) if span.begins_with("frames ") else first
		assert_almost_eq(worst, frame, 0.5, "%s: the worst moment near frame %s: %s" % [what, frame, p])
		assert_true(first <= frame and frame <= last, "%s: the stretch holds frame %s: %s" % [what, frame, p])


# ------------------------------------------------------------------ the arm

## What the rig's four passes of the hand's turn round the handle leave
## (FighterRig.seat()): the check lands this near the arm _key() built.
const PASSES_MM: float = 0.002
const PASSES_DEG: float = 2.0


func test_the_elbow_is_solved_where_the_arm_was_built() -> void:
	for body: ReferenceBody in [rogue, ReferenceBody.of(&"hunter")]:
		for arm: Array in [
			[&"right", _v(0.15, -0.9, 0.4), _v(-0.15, 0.35, 0.92)],
			[&"right", _v(0.6, -0.2, 0.3), _v(-0.2, 0.9, -0.3)],
			[&"left", _v(-0.3, -0.7, 0.6), _v(0.4, -0.2, 0.9)],
		]:
			var side: StringName = arm[0]
			var s: Swing = Swing.new(10)
			s.add_track(SwingCheck.HANDS[side], [_key(body, side, 0, arm[1], arm[2], _v(0.0, 1.0, 0.0))] as Array[Swing.KeyPose])
			var a: SwingCheck.Arm = SwingCheck.moment(s, _sword(), body, 0.0).arms[side]
			var what: String = "%s %s arm %s" % [body.id, side, arm[1]]
			# the solve is exact for the wrist the passes reach
			assert_almost_eq(V3.distance(a.shoulder, a.elbow), body.upper_arm, EPS, what + ": the upper arm's length")
			assert_almost_eq(V3.distance(a.elbow, a.wrist), body.forearm, EPS, what + ": the forearm's length")
			# and that wrist is where the arm was built, to what the passes leave
			assert_almost_eq(V3.distance(a.elbow, _built_elbow(body, side, arm[1])), 0.0, PASSES_MM, what + ": the elbow")
			var open: float = 180.0 - Quat64.angle_between(Quat64.from_to(V3.normalized(arm[1]), V3.normalized(arm[2])), Quat64.identity()) / SimMath.DEG
			assert_almost_eq(a.elbow_angle, open, PASSES_DEG, what + ": the elbow's angle")
			assert_almost_eq(a.bend, 0.0, PASSES_DEG, what + ": a straight wrist doesn't bend")
			assert_almost_eq(a.deviation, 0.0, PASSES_DEG, what + ": nor turn")
			assert_eq(a.short, 0.0, what + ": within reach")


func test_a_hand_is_seated_straight_on_its_forearm_and_measures_its_sideways_turn() -> void:
	for side: StringName in [&"right", &"left"]:
		for hand: Array in [[40.0, 0.0], [-75.0, 0.0], [0.0, 20.0], [0.0, -30.0]]:
			var s: Swing = Swing.new(10)
			var x: float = 1.0 if side == &"right" else -1.0
			s.add_track(SwingCheck.HANDS[side], [_key(rogue, side, 0, _v(0.15 * x, -0.9, 0.4), _v(-0.15 * x, 0.35, 0.92),
					_v(0.0, 1.0, 0.0), hand[0], hand[1])] as Array[Swing.KeyPose])
			var a: SwingCheck.Arm = SwingCheck.moment(s, _sword(), rogue, 0.0).arms[side]
			# a hand built bent is turned round the handle onto its forearm
			assert_almost_eq(a.bend, 0.0, PASSES_DEG, "%s hand %s: no bend" % [side, hand])
			if hand[1] != 0.0:
				assert_almost_eq(absf(a.deviation), absf(hand[1]), 0.1, "%s hand %s: the sideways turn" % [side, hand])


func test_without_a_tweak_the_elbow_hangs_out_down_and_back() -> void:
	for side: StringName in [&"right", &"left"]:
		var out: float = 1.0 if side == &"right" else -1.0
		var k: Swing.KeyPose = _key(rogue, side, 0, _v(0.15 * out, -0.9, 0.4), _v(-0.15 * out, 0.35, 0.92), _v(0.0, 1.0, 0.0))
		k.pole = V3.make()
		var s: Swing = Swing.new(10)
		s.add_track(SwingCheck.HANDS[side], [k] as Array[Swing.KeyPose])
		var a: SwingCheck.Arm = SwingCheck.moment(s, _sword(), rogue, 0.0).arms[side]
		# the elbow's offset from the line from the shoulder to the wrist
		var u: V3 = V3.normalized(V3.sub(a.wrist, a.shoulder))
		var off: V3 = V3.sub(V3.sub(a.elbow, a.shoulder), V3.scale(u, V3.dot(V3.sub(a.elbow, a.shoulder), u)))
		assert_gt(off.x * out, 0.0, "%s: out" % side)
		assert_lt(off.y, 0.0, "%s: down" % side)
		assert_lt(off.z, 0.0, "%s: back" % side)


func test_the_torso_coil_carries_the_shoulders_and_the_poles() -> void:
	var k: Swing.KeyPose = _key(rogue, &"right", 0, _v(0.3, -0.8, 0.5), _v(-0.1, 0.2, 0.97), _v(1.0, 0.3, 0.0), 0.0, 0.0, 40.0)
	var s: Swing = Swing.new(10)
	s.add_track(RIGHT, [k] as Array[Swing.KeyPose])
	s.add_track(&"body", [_body_key(0, 40.0)] as Array[Swing.KeyPose])
	var m: SwingCheck.Moment = SwingCheck.moment(s, _sword(), rogue, 0.0)
	var posed: ReferenceBody = rogue.posed(40.0, 0.0, V3.make())
	assert_almost_eq(V3.distance(m.arms[&"right"].shoulder, posed.shoulders[&"right"]), 0.0, EPS, "the coiled shoulder")
	assert_almost_eq(V3.distance(m.proxies["torso"].a, posed.torso.a), 0.0, EPS, "the coiled torso")
	var built: V3 = V3.add(posed.shoulders[&"right"], V3.scale(V3.normalized(_v(0.3, -0.8, 0.5)), rogue.upper_arm))
	assert_almost_eq(V3.distance(m.arms[&"right"].elbow, built), 0.0, PASSES_MM, "the pole turns with the chest")


func test_a_weapon_held_in_both_hands_puts_the_left_hand_on_its_grip() -> void:
	var s: Swing = Swing.new(10)
	s.add_track(RIGHT, [_key(rogue, &"right", 0, _v(0.15, -0.9, 0.4), _v(-0.15, 0.35, 0.92), _v(0.0, 1.0, 0.0))] as Array[Swing.KeyPose])
	var m: SwingCheck.Moment = SwingCheck.moment(s, Moves.KATANA, rogue, 0.0)
	var right: SwingCheck.Arm = m.arms[&"right"]
	var left: SwingCheck.Arm = m.arms[&"left"]
	var k: Swing.KeyPose = s.track(RIGHT)[0]
	assert_almost_eq(V3.distance(left.grip, V3.sub(k.grip, V3.scale(k.blade, 0.15))), 0.0, EPS, "15 cm down the handle")
	assert_almost_eq(V3.distance(left.thumb, right.thumb), 0.0, EPS, "both thumbs up the handle")
	assert_not_null(left.elbow, "the left arm reaches it")
	assert_eq(m.blades.size(), 1, "one blade")


func test_a_two_handed_swing_keys_no_left_hand() -> void:
	var s: Swing = Swing.new(10)
	var k: Swing.KeyPose = _key(rogue, &"right", 0, _v(0.15, -0.9, 0.4), _v(-0.15, 0.35, 0.92), _v(0.0, 1.0, 0.0))
	s.add_track(RIGHT, [k] as Array[Swing.KeyPose])
	s.add_track(LEFT, [k] as Array[Swing.KeyPose])
	_assert_named(SwingCheck.check(_move(s, 3, 2, 5), Moves.KATANA, rogue), ["left_hand", "both hands"], "a keyed left hand")


# ------------------------------------------------------------------ the check

func test_a_good_cut_passes_on_both_bodies() -> void:
	for body: ReferenceBody in [rogue, ReferenceBody.of(&"hunter")]:
		var cut: Swing = _cut(body)
		assert_eq(SwingCheck.check(_move(cut, 8, 3, 14), _sword(), body), [] as Array[String], "%s: from the guard" % body.id)
		assert_eq(SwingCheck.check(_move(cut, 8, 3, 14), _sword(), body, cut), [] as Array[String], "%s: following itself" % body.id)


func test_a_wrist_turned_35_degrees_sideways_fails_and_names_its_frame() -> void:
	var turned: Swing = _cut_with(rogue, 8, _key(rogue, &"right", 8, _v(0.3, -0.8, 0.5), _v(-0.1, 0.2, 0.97), _v(1.0, 0.3, 0.0), 0.0, 35.0))
	var problems: Array[String] = SwingCheck.check(_move(turned, 8, 3, 14), _sword(), rogue)
	_assert_at(problems, ["right_hand", "sideways"], 8.0, "a wrist turned 35°")
	for p: String in problems:
		if p.contains("sideways"):
			# the worst of it, between the keys round frame 8
			var worst: float = float(p.get_slice("turns ", 1).get_slice("°", 0))
			assert_between(worst, 35.0, 37.0, "about 35°: %s" % p)


func test_a_blade_through_the_head_fails_and_names_its_frame() -> void:
	# cocked with the blade laid back across the top of the head
	var through: Swing = _cut_with(rogue, 4, _key(rogue, &"right", 4, _v(0.45, -0.3, 0.2), _v(-0.2, 0.95, 0.0), _v(-1.0, 0.0, -0.3)))
	var problems: Array[String] = SwingCheck.check(_move(through, 8, 3, 14), _sword(), rogue)
	_assert_at(problems, ["right_hand", "of the head"], 4.0, "a blade through the head")


func test_a_blade_through_the_other_forearm_fails() -> void:
	# a dagger in each hand: the left forearm held across the front, and the
	# right hand above it with its blade pointing straight down through it
	var daggers: WeaponDef = WeaponDef.new()
	daggers.blade = StrikeSegment.make(V3.make(0.0, 0.06, 0.0), V3.make(0.0, 0.32, 0.0), 0.014)
	var left: Swing.KeyPose = _key(rogue, &"left", 0, _v(-0.1, -0.8, 0.6), _v(0.9, 0.1, 0.4), _v(0.0, -0.3, 1.0))
	var alone: Swing = Swing.new(10)
	alone.add_track(LEFT, [left] as Array[Swing.KeyPose])
	var arm: SwingCheck.Arm = SwingCheck.moment(alone, daggers, rogue, 0.0).arms[&"left"]
	var right: Swing.KeyPose = Swing.KeyPose.new()
	right.grip = V3.add(V3.lerp(arm.elbow, arm.wrist, 0.5), V3.make(0.0, 0.2, 0.0))
	right.blade = V3.make(0.0, -1.0, 0.0)
	right.edge = V3.make(0.0, 0.0, 1.0)
	var s: Swing = Swing.new(10)
	s.add_track(LEFT, [left] as Array[Swing.KeyPose])
	s.add_track(RIGHT, [right] as Array[Swing.KeyPose])
	var problems: Array[String] = SwingCheck.check(_move(s, 3, 2, 5), daggers, rogue)
	_assert_named(problems, ["right_hand", "of the left forearm", "frames 0 to 10"], "the right blade through the left forearm")
	for p: String in problems:
		assert_false(p.begins_with("left_hand: the blade"), "the left blade is clear: %s" % p)


func test_a_grip_in_front_of_the_face_fails_in_the_wind_up_only() -> void:
	# both hands up in front of the chin
	var key: Swing.KeyPose = _key(rogue, &"right", 4, _v(0.2, -0.6, 0.75), _v(-0.45, 0.85, 0.3), _v(0.3, 0.4, -0.9))
	var crossing: Swing = _cut_with(rogue, 4, key)
	_assert_named(SwingCheck.check(_move(crossing, 8, 3, 14), _sword(), rogue), ["right_hand", "front of the face"], "in the wind-up")
	# the same pose as the follow-through, after the wind-up
	var after: Swing = Swing.new(25, _cut(rogue).guard)
	var keys: Array[Swing.KeyPose] = []
	for k: Swing.KeyPose in _cut(rogue).track(RIGHT):
		keys.append(k)
	var late: Swing.KeyPose = _key(rogue, &"right", 18, _v(0.2, -0.6, 0.75), _v(-0.45, 0.85, 0.3), _v(0.3, 0.4, -0.9))
	keys.append(late)
	after.add_track(RIGHT, keys)
	for p: String in SwingCheck.check(_move(after, 8, 3, 14), _sword(), rogue):
		assert_false(p.contains("face"), "after the wind-up: %s" % p)


func test_a_locked_elbow_and_a_grip_out_of_reach_fail() -> void:
	var straight: Swing.KeyPose = _key(rogue, &"right", 8, _v(0.0, -0.1, 1.0), _v(0.0, -0.05, 1.0), _v(1.0, 0.3, 0.0))
	_assert_at(SwingCheck.check(_move(_cut_with(rogue, 8, straight), 8, 3, 14), _sword(), rogue), ["right_hand", "elbow locks"], 8.0, "an elbow at 177°")
	var far: Swing.KeyPose = _key(rogue, &"right", 8, _v(0.0, -0.1, 1.0), _v(0.0, -0.1, 1.0), _v(1.0, 0.3, 0.0))
	far.grip = V3.add(far.grip, V3.make(0.0, 0.0, 0.1))
	_assert_at(SwingCheck.check(_move(_cut_with(rogue, 8, far), 8, 3, 14), _sword(), rogue), ["right_hand", "10.1 cm out of the arm's reach"], 8.0,
			"a grip 10 cm past reach")


func test_the_entry_from_the_guard_and_from_the_move_before_are_both_checked() -> void:
	# a guard with the wrist turned 40° sideways: the fresh entry starts in it,
	# and every exit ends in it; a chained entry starts from the move before
	# instead
	var cut: Swing = _cut(rogue)
	var bad_guard: Dictionary[StringName, Swing.KeyPose] = {
		RIGHT: _key(rogue, &"right", 0, _v(0.15, -0.9, 0.4), _v(-0.15, 0.35, 0.92), _v(0.0, 1.0, 0.0), 0.0, 40.0),
	}
	var s: Swing = Swing.new(25, bad_guard)
	s.add_track(RIGHT, cut.track(RIGHT))
	var fresh: Array[String] = SwingCheck.check(_move(s, 8, 3, 14), _sword(), rogue)
	_assert_named(fresh, ["wrist turns 40° sideways", "frames 0 to 25"], "entered from the bad guard")
	var chained: Array[String] = SwingCheck.check(_move(s, 8, 3, 14), _sword(), rogue, cut)
	assert_eq(chained.size(), 1, "following a good move, only the exit: %s" % [chained])
	assert_false(chained[0].contains("frames 0 to"), "the entry is clean: %s" % chained[0])
	assert_true(chained[0].contains("to 25)"), "the exit ends in the bad guard: %s" % chained[0])


func test_the_check_looks_between_frames() -> void:
	# in the wind-up the grip sweeps across the front of the face within one
	# frame: clear of it on frames 4 and 5, in front of it between them
	var s: Swing = Swing.new(25, _cut(rogue).guard)
	var keys: Array[Swing.KeyPose] = []
	for x: float in [0.3, -0.3]:
		var k: Swing.KeyPose = Swing.KeyPose.new()
		k.frame = 4 if x > 0.0 else 5
		k.grip = V3.make(x, 1.835, 0.25)
		k.blade = V3.make(0.0, 1.0, 0.0)
		k.edge = V3.make(0.0, 0.0, 1.0)
		keys.append(k)
	keys.append_array(_cut(rogue).track(RIGHT).slice(1))
	s.add_track(RIGHT, keys)
	var face: Array[String] = []
	for p: String in SwingCheck.check(_move(s, 8, 3, 14), _sword(), rogue):
		if p.contains("face"):
			face.append(p)
	assert_eq(face.size(), 1, "the grip crosses the face: %s" % [face])
	if face.size() == 1:
		var span: String = face[0].get_slice(" (", face[0].get_slice_count(" (") - 1)
		var first: float = float(span.get_slice(" ", 1))
		var last: float = float(span.get_slice(" ", 3)) if span.begins_with("frames ") else first
		assert_true(first > 4.0 and last < 5.0, "only between frames 4 and 5: %s" % face[0])


func test_a_blade_through_the_other_upper_arm_fails() -> void:
	# a dagger in each hand: the right blade pointing straight down through the
	# middle of the left upper arm
	var daggers: WeaponDef = WeaponDef.new()
	daggers.blade = StrikeSegment.make(V3.make(0.0, 0.06, 0.0), V3.make(0.0, 0.32, 0.0), 0.014)
	var left: Swing.KeyPose = _key(rogue, &"left", 0, _v(-0.6, -0.6, 0.4), _v(0.4, 0.2, 0.9), _v(0.0, -0.3, 1.0))
	var alone: Swing = Swing.new(10)
	alone.add_track(LEFT, [left] as Array[Swing.KeyPose])
	var arm: SwingCheck.Arm = SwingCheck.moment(alone, daggers, rogue, 0.0).arms[&"left"]
	var right: Swing.KeyPose = Swing.KeyPose.new()
	right.grip = V3.add(V3.lerp(arm.shoulder, arm.elbow, 0.5), V3.make(0.0, 0.2, 0.0))
	right.blade = V3.make(0.0, -1.0, 0.0)
	right.edge = V3.make(0.0, 0.0, 1.0)
	var s: Swing = Swing.new(10)
	s.add_track(LEFT, [left] as Array[Swing.KeyPose])
	s.add_track(RIGHT, [right] as Array[Swing.KeyPose])
	_assert_named(SwingCheck.check(_move(s, 3, 2, 5), daggers, rogue), ["right_hand", "of the left upper arm", "frames 0 to 10"],
			"the right blade through the left upper arm")
