extends GutTest
## Reference bodies (task 7.6): the Rogue's and the Hunter's arms, spine and
## proxy capsules as rules data, for the swing checks (task 7.7). The torso
## coil turns the torso and the shoulders about the spine, the pelvis coil
## turns the thighs at the hips, and the pelvis shift carries everything but
## the knees; the head keeps facing ahead. tests/content/test_reference_bodies.gd
## keeps the numbers to the skeletons.

const EPS: float = 1e-9


func _assert_v3(got: V3, want: V3, what: String) -> void:
	assert_almost_eq(V3.distance(got, want), 0.0, EPS, "%s: got (%s, %s, %s)" % [what, got.x, got.y, got.z])


func _assert_capsule(got: SimCapsule, a: V3, b: V3, radius: float, what: String) -> void:
	_assert_v3(got.a, a, what + " (a)")
	_assert_v3(got.b, b, what + " (b)")
	assert_eq(got.radius, radius, what + " (radius)")


## A body with an upright spine at the origin, square to hand-work the turns.
static func _square() -> ReferenceBody:
	return ReferenceBody.from_record(&"square", {
		"shoulders": {"right": [0.15, 1.4, 0.0], "left": [-0.15, 1.4, 0.0]},
		"upper_arm": 0.25,
		"forearm": 0.24,
		"wrist": [-0.08, 0.0, 0.03],
		"spine": [[0.0, 0.9, 0.0], [0.0, 1.4, 0.0]],
		"torso": {"a": [0.0, 0.9, 0.05], "b": [0.0, 1.4, 0.05], "radius": 0.2},
		"head": {"a": [0.0, 1.55, 0.02], "b": [0.0, 1.62, 0.02], "radius": 0.17},
		"thighs": {
			"right": {"a": [0.1, 0.9, 0.0], "b": [0.1, 0.5, 0.0], "radius": 0.15},
			"left": {"a": [-0.1, 0.9, 0.0], "b": [-0.1, 0.5, 0.0], "radius": 0.15},
		},
		"upper_arm_radius": {"right": 0.06, "left": 0.12},
		"forearm_radius": {"right": 0.07, "left": 0.07},
	})


func test_the_rogue_and_the_hunter_have_reference_bodies() -> void:
	assert_eq(ReferenceBody.BODIES.keys(), [&"rogue", &"hunter"])
	for id: StringName in ReferenceBody.BODIES:
		var body: ReferenceBody = ReferenceBody.of(id)
		assert_eq(body.id, id)
		assert_between(body.upper_arm, 0.2, 0.3, "%s: upper arm" % id)
		assert_between(body.forearm, 0.2, 0.3, "%s: forearm" % id)
		for side: StringName in ReferenceBody.SIDES:
			assert_not_null(body.shoulders.get(side), "%s: %s shoulder" % [id, side])
			assert_not_null(body.thighs.get(side), "%s: %s thigh" % [id, side])
			assert_gt(body.upper_arm_radius.get(side, 0.0), 0.0, "%s: %s upper arm's radius" % [id, side])
			assert_gt(body.forearm_radius.get(side, 0.0), 0.0, "%s: %s forearm's radius" % [id, side])
		assert_eq(body.shoulders[&"left"].x, -body.shoulders[&"right"].x, "%s: the shoulders mirror" % id)
		assert_gt(body.head.b.y, body.torso.b.y, "%s: the head is above the torso" % id)


func test_an_unknown_fighter_has_no_reference_body() -> void:
	assert_null(ReferenceBody.of(&"ronin"))
	assert_push_error("unknown fighter ronin")


func test_the_left_wrist_mirrors_the_right() -> void:
	var body: ReferenceBody = _square()
	_assert_v3(body.wrist_in_fist(&"right"), V3.make(-0.08, 0.0, 0.03), "the right wrist, behind the fist")
	_assert_v3(body.wrist_in_fist(&"left"), V3.make(-0.08, 0.0, -0.03), "the left wrist, on the fist's other face")


func test_no_coil_and_no_shift_is_the_rest_pose() -> void:
	var body: ReferenceBody = _square()
	var posed: ReferenceBody = body.posed(0.0, 0.0, V3.make())
	_assert_v3(posed.shoulders[&"right"], body.shoulders[&"right"], "right shoulder")
	_assert_capsule(posed.torso, body.torso.a, body.torso.b, 0.2, "torso")
	_assert_capsule(posed.thighs[&"left"], body.thighs[&"left"].a, body.thighs[&"left"].b, 0.15, "left thigh")


func test_the_torso_coil_turns_the_torso_and_the_shoulders_toward_the_right() -> void:
	var body: ReferenceBody = _square()
	var posed: ReferenceBody = body.posed(90.0, 0.0, V3.make())
	# turning toward the right takes forward to right and right to back
	_assert_v3(posed.shoulders[&"right"], V3.make(0.0, 1.4, -0.15), "the right shoulder goes back")
	_assert_v3(posed.shoulders[&"left"], V3.make(0.0, 1.4, 0.15), "the left shoulder comes forward")
	_assert_capsule(posed.torso, V3.make(0.05, 0.9, 0.0), V3.make(0.05, 1.4, 0.0), 0.2, "the torso's front turns right")
	_assert_capsule(posed.head, body.head.a, body.head.b, 0.17, "the head keeps facing ahead")
	_assert_capsule(posed.thighs[&"right"], body.thighs[&"right"].a, body.thighs[&"right"].b, 0.15, "the thighs stay")
	var back: ReferenceBody = body.posed(-30.0, 0.0, V3.make())
	_assert_v3(back.shoulders[&"right"], V3.make(0.15 * cos(PI / 6.0), 1.4, 0.15 * sin(PI / 6.0)), "a negative coil turns left")
	_assert_v3(body.shoulders[&"right"], V3.make(0.15, 1.4, 0.0), "posing leaves the body as it was")


func test_the_pelvis_coil_turns_the_thighs_at_the_hips() -> void:
	var body: ReferenceBody = _square()
	var posed: ReferenceBody = body.posed(0.0, 90.0, V3.make())
	_assert_capsule(posed.thighs[&"right"], V3.make(0.0, 0.9, -0.1), V3.make(0.1, 0.5, 0.0), 0.15, "the right hip goes back, the knee stays")
	_assert_capsule(posed.thighs[&"left"], V3.make(0.0, 0.9, 0.1), V3.make(-0.1, 0.5, 0.0), 0.15, "the left hip comes forward")
	_assert_v3(posed.shoulders[&"right"], body.shoulders[&"right"], "the shoulders stay")
	_assert_capsule(posed.torso, body.torso.a, body.torso.b, 0.2, "the torso stays")


func test_the_pelvis_shift_carries_all_but_the_knees() -> void:
	var body: ReferenceBody = _square()
	var shift: V3 = V3.make(0.02, -0.05, -0.1)
	var posed: ReferenceBody = body.posed(0.0, 0.0, shift)
	_assert_v3(posed.shoulders[&"right"], V3.make(0.17, 1.35, -0.1), "the shoulder")
	_assert_capsule(posed.torso, V3.make(0.02, 0.85, -0.05), V3.make(0.02, 1.35, -0.05), 0.2, "the torso")
	_assert_capsule(posed.head, V3.make(0.02, 1.5, -0.08), V3.make(0.02, 1.57, -0.08), 0.17, "the head")
	_assert_capsule(posed.thighs[&"right"], V3.make(0.12, 0.85, -0.1), V3.make(0.1, 0.5, 0.0), 0.15, "the hip moves, the knee stays")
	_assert_v3(posed.spine_base, V3.make(0.02, 0.85, -0.1), "the spine")
	# coil and shift together: the turn is about the shifted spine
	var both: ReferenceBody = body.posed(90.0, 0.0, shift)
	_assert_v3(both.shoulders[&"right"], V3.make(0.02, 1.35, -0.25), "the right shoulder turns about the moved spine")


func test_the_real_bodies_coil_about_their_own_spines() -> void:
	for id: StringName in ReferenceBody.BODIES:
		var body: ReferenceBody = ReferenceBody.of(id)
		var posed: ReferenceBody = body.posed(45.0, 30.0, V3.make())
		for side: StringName in ReferenceBody.SIDES:
			var axis: V3 = V3.normalized(V3.sub(body.spine_top, body.spine_base))
			var before: V3 = V3.sub(body.shoulders[side], body.spine_base)
			var after: V3 = V3.sub(posed.shoulders[side], body.spine_base)
			assert_almost_eq(V3.dot(after, axis), V3.dot(before, axis), EPS, "%s %s shoulder: same height up the spine" % [id, side])
			assert_almost_eq(V3.length(after), V3.length(before), EPS, "%s %s shoulder: same distance from it" % [id, side])
			assert_ne(V3.distance(posed.shoulders[side], body.shoulders[side]), 0.0, "%s %s shoulder moved" % [id, side])
