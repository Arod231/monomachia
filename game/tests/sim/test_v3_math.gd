extends GutTest
## The rules' 64-bit vector and rotation helpers (task 7.1): V3's operations,
## Quat64 and SimMath.local_to_world. The swings (task 7) build on them, so
## each is checked against values worked out by hand.

const EPS: float = 1e-12


func _assert_v3(v: V3, x: float, y: float, z: float, what: String, eps: float = EPS) -> void:
	assert_almost_eq(v.x, x, eps, "%s.x" % what)
	assert_almost_eq(v.y, y, eps, "%s.y" % what)
	assert_almost_eq(v.z, z, eps, "%s.z" % what)


func test_v3_arithmetic() -> void:
	var a: V3 = V3.make(1.0, 2.0, 3.0)
	var b: V3 = V3.make(-4.0, 0.5, 2.0)
	_assert_v3(V3.add(a, b), -3.0, 2.5, 5.0, "add")
	_assert_v3(V3.sub(a, b), 5.0, 1.5, 1.0, "sub")
	_assert_v3(V3.scale(a, -2.0), -2.0, -4.0, -6.0, "scale")
	assert_eq(V3.dot(a, b), 3.0, "dot")
	assert_eq(V3.length(V3.make(3.0, 4.0, 12.0)), 13.0, "length")
	assert_eq(V3.distance(V3.make(1.0, 1.0, 1.0), V3.make(4.0, 5.0, 13.0)), 13.0, "distance")
	_assert_v3(V3.lerp(a, b, 0.25), -0.25, 1.625, 2.75, "lerp")


func test_v3_operations_return_new_vectors() -> void:
	var a: V3 = V3.make(1.0, 2.0, 3.0)
	var zero: V3 = V3.make()
	assert_ne(V3.add(a, zero), a, "add gives a new V3")
	assert_ne(V3.scale(a, 1.0), a, "scale gives a new V3")
	_assert_v3(a, 1.0, 2.0, 3.0, "a is untouched")


func test_cross_is_right_handed_like_godots_axes() -> void:
	var x: V3 = V3.make(1.0, 0.0, 0.0)
	var y: V3 = V3.make(0.0, 1.0, 0.0)
	var z: V3 = V3.make(0.0, 0.0, 1.0)
	_assert_v3(V3.cross(x, y), 0.0, 0.0, 1.0, "x cross y")
	_assert_v3(V3.cross(y, z), 1.0, 0.0, 0.0, "y cross z")
	_assert_v3(V3.cross(z, x), 0.0, 1.0, 0.0, "z cross x")
	_assert_v3(V3.cross(y, x), 0.0, 0.0, -1.0, "y cross x")
	_assert_v3(V3.cross(V3.make(1.0, 2.0, 3.0), V3.make(-4.0, 0.5, 2.0)), 2.5, -14.0, 8.5, "a cross b")


func test_v3_normalized() -> void:
	_assert_v3(V3.normalized(V3.make(0.0, 3.0, 4.0)), 0.0, 0.6, 0.8, "normalized")
	_assert_v3(V3.normalized(V3.make()), 0.0, 0.0, 0.0, "the zero vector stays zero")


func test_the_identity_rotation_leaves_vectors_alone() -> void:
	_assert_v3(Quat64.rotate(Quat64.identity(), V3.make(1.0, -2.0, 3.0)), 1.0, -2.0, 3.0, "identity")


func test_axis_angle_rotations_are_right_handed() -> void:
	var quarter: float = PI / 2.0
	_assert_v3(Quat64.rotate(Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), quarter), V3.make(0.0, 0.0, 1.0)),
			1.0, 0.0, 0.0, "+Z a quarter turn about +Y")
	_assert_v3(Quat64.rotate(Quat64.from_axis_angle(V3.make(0.0, 0.0, 1.0), quarter), V3.make(1.0, 0.0, 0.0)),
			0.0, 1.0, 0.0, "+X a quarter turn about +Z")
	_assert_v3(Quat64.rotate(Quat64.from_axis_angle(V3.make(1.0, 0.0, 0.0), quarter), V3.make(0.0, 1.0, 0.0)),
			0.0, 0.0, 1.0, "+Y a quarter turn about +X")
	_assert_v3(Quat64.rotate(Quat64.from_axis_angle(V3.make(0.0, 5.0, 0.0), PI), V3.make(1.0, 2.0, 3.0)),
			-1.0, 2.0, -3.0, "a half turn about an unnormalized axis")


func test_mul_turns_by_the_right_hand_rotation_first() -> void:
	var about_y: Quat64 = Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), PI / 2.0)
	var about_z: Quat64 = Quat64.from_axis_angle(V3.make(0.0, 0.0, 1.0), PI / 2.0)
	# +X about Z gives +Y, which a turn about Y leaves where it is.
	_assert_v3(Quat64.rotate(Quat64.mul(about_y, about_z), V3.make(1.0, 0.0, 0.0)), 0.0, 1.0, 0.0, "y after z")
	# +X about Y gives -Z, which a turn about Z leaves where it is.
	_assert_v3(Quat64.rotate(Quat64.mul(about_z, about_y), V3.make(1.0, 0.0, 0.0)), 0.0, 0.0, -1.0, "z after y")


func test_rotations_round_trip_through_their_inverse() -> void:
	var q: Quat64 = Quat64.mul(Quat64.from_axis_angle(V3.make(1.0, 2.0, -0.5), 1.1),
			Quat64.from_axis_angle(V3.make(-0.3, 0.2, 1.0), -2.6))
	var v: V3 = V3.make(0.4, -1.3, 2.2)
	var turned: V3 = Quat64.rotate(q, v)
	assert_gt(V3.distance(turned, v), 0.5, "the test rotation moves v")
	_assert_v3(Quat64.rotate(Quat64.inverse(q), turned), v.x, v.y, v.z, "turned back")
	_assert_v3(Quat64.rotate(Quat64.mul(q, Quat64.inverse(q)), v), v.x, v.y, v.z, "q times its inverse")
	assert_almost_eq(V3.length(turned), V3.length(v), EPS, "rotation keeps length")


func test_from_axes_turns_y_and_x_onto_the_pair() -> void:
	# A blade pointing forward with its edge down.
	var q: Quat64 = Quat64.from_axes(V3.make(0.0, 0.0, 1.0), V3.make(0.0, -1.0, 0.0))
	_assert_v3(Quat64.rotate(q, V3.make(0.0, 1.0, 0.0)), 0.0, 0.0, 1.0, "+Y")
	_assert_v3(Quat64.rotate(q, V3.make(1.0, 0.0, 0.0)), 0.0, -1.0, 0.0, "+X")
	_assert_v3(Quat64.rotate(q, V3.make(0.0, 0.0, 1.0)), -1.0, 0.0, 0.0, "+Z, x cross y")


func test_from_axes_keeps_y_and_squares_x_onto_it() -> void:
	var q: Quat64 = Quat64.from_axes(V3.make(0.0, 2.0, 0.0), V3.make(1.0, 1.0, 0.0))
	_assert_v3(Quat64.rotate(q, V3.make(0.0, 1.0, 0.0)), 0.0, 1.0, 0.0, "+Y")
	_assert_v3(Quat64.rotate(q, V3.make(1.0, 0.0, 0.0)), 1.0, 0.0, 0.0, "+X")


func test_from_axes_with_parallel_axes_still_turns_y_onto_y() -> void:
	var q: Quat64 = Quat64.from_axes(V3.make(0.0, 0.0, -1.0), V3.make(0.0, 0.0, 3.0))
	_assert_v3(Quat64.rotate(q, V3.make(0.0, 1.0, 0.0)), 0.0, 0.0, -1.0, "+Y")
	var x: V3 = Quat64.rotate(q, V3.make(1.0, 0.0, 0.0))
	assert_almost_eq(V3.length(x), 1.0, EPS, "+X stays unit length")
	assert_almost_eq(x.z, 0.0, EPS, "+X is square to y")


func test_from_axes_round_trips_any_rotation() -> void:
	var rotations: Array[Quat64] = [
		Quat64.identity(),
		Quat64.from_axis_angle(V3.make(1.0, 2.0, -0.5), 1.1),
		Quat64.from_axis_angle(V3.make(-0.3, 0.2, 1.0), -2.6),
		Quat64.from_axis_angle(V3.make(1.0, 0.0, 0.0), PI),
		Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), PI),
		Quat64.from_axis_angle(V3.make(0.0, 0.0, 1.0), PI),
		Quat64.from_axis_angle(V3.make(1.0, 1.0, 1.0), 3.0),
	]
	var v: V3 = V3.make(0.4, -1.3, 2.2)
	for q: Quat64 in rotations:
		var again: Quat64 = Quat64.from_axes(Quat64.rotate(q, V3.make(0.0, 1.0, 0.0)), Quat64.rotate(q, V3.make(1.0, 0.0, 0.0)))
		var want: V3 = Quat64.rotate(q, v)
		_assert_v3(Quat64.rotate(again, v), want.x, want.y, want.z, "round trip of %s" % q)


func test_from_to_is_the_shortest_turn_between_two_directions() -> void:
	var x: V3 = V3.make(1.0, 0.0, 0.0)
	var y: V3 = V3.make(0.0, 1.0, 0.0)
	var q: Quat64 = Quat64.from_to(x, V3.make(0.0, 3.0, 0.0))
	_assert_v3(Quat64.rotate(q, x), 0.0, 1.0, 0.0, "x onto y")
	_assert_v3(Quat64.rotate(q, V3.make(0.0, 0.0, 1.0)), 0.0, 0.0, 1.0, "the axis of the turn stays put")
	assert_almost_eq(Quat64.angle_between(Quat64.identity(), q), PI / 2.0, EPS, "a quarter turn")
	var a: V3 = V3.normalized(V3.make(1.0, 2.0, -0.5))
	var b: V3 = V3.normalized(V3.make(-0.3, 0.2, 1.0))
	var ab: V3 = Quat64.rotate(Quat64.from_to(a, b), a)
	_assert_v3(ab, b.x, b.y, b.z, "a onto b")
	assert_almost_eq(Quat64.angle_between(Quat64.identity(), Quat64.from_to(a, b)), JsMath.atan2(V3.length(V3.cross(a, b)), V3.dot(a, b)), EPS,
			"turns by the angle between them, no more")
	assert_almost_eq(Quat64.angle_between(Quat64.identity(), Quat64.from_to(y, y)), 0.0, EPS, "no turn between equal directions")
	var back: V3 = Quat64.rotate(Quat64.from_to(y, V3.make(0.0, -2.0, 0.0)), y)
	_assert_v3(back, 0.0, -1.0, 0.0, "opposite directions: a half turn")


func test_angle_between_rotations() -> void:
	var axis: V3 = V3.make(1.0, 2.0, -0.5)
	var a: Quat64 = Quat64.from_axis_angle(axis, 0.3)
	var b: Quat64 = Quat64.from_axis_angle(axis, 1.2)
	assert_almost_eq(Quat64.angle_between(Quat64.identity(), Quat64.from_axis_angle(axis, 0.7)), 0.7, EPS, "from identity")
	assert_almost_eq(Quat64.angle_between(a, b), 0.9, EPS, "a to b")
	assert_almost_eq(Quat64.angle_between(b, a), 0.9, EPS, "b to a")
	assert_almost_eq(Quat64.angle_between(Quat64.identity(), Quat64.from_axis_angle(axis, PI)), PI, EPS, "a half turn")
	var negated: Quat64 = Quat64.make(-b.x, -b.y, -b.z, -b.w)
	assert_almost_eq(Quat64.angle_between(b, negated), 0.0, EPS, "q and -q are the same turn")


func test_slerp_ends_on_its_rotations() -> void:
	var a: Quat64 = Quat64.from_axis_angle(V3.make(1.0, 2.0, -0.5), 1.1)
	var b: Quat64 = Quat64.from_axis_angle(V3.make(-0.3, 0.2, 1.0), -2.6)
	assert_almost_eq(Quat64.angle_between(Quat64.slerp(a, b, 0.0), a), 0.0, EPS, "t = 0")
	assert_almost_eq(Quat64.angle_between(Quat64.slerp(a, b, 1.0), b), 0.0, EPS, "t = 1")


func test_slerp_turns_at_an_even_rate() -> void:
	var quarter_turn: Quat64 = Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), PI / 2.0)
	var forward: V3 = V3.make(0.0, 0.0, 1.0)
	_assert_v3(Quat64.rotate(Quat64.slerp(Quat64.identity(), quarter_turn, 0.5), forward),
			0.7071067811865476, 0.0, 0.7071067811865476, "halfway is 45 degrees")
	_assert_v3(Quat64.rotate(Quat64.slerp(Quat64.identity(), quarter_turn, 0.25), forward),
			0.3826834323650898, 0.0, 0.9238795325112867, "a quarter of the way is 22.5 degrees")
	var a: Quat64 = Quat64.from_axis_angle(V3.make(1.0, 2.0, -0.5), 1.1)
	var b: Quat64 = Quat64.from_axis_angle(V3.make(-0.3, 0.2, 1.0), -2.6)
	var whole: float = Quat64.angle_between(a, b)
	var part: Quat64 = Quat64.slerp(a, b, 0.3)
	assert_almost_eq(Quat64.angle_between(a, part), 0.3 * whole, 1e-9, "30% of the way from a")
	assert_almost_eq(Quat64.angle_between(part, b), 0.7 * whole, 1e-9, "70% of the way to b")


func test_slerp_and_nlerp_take_the_short_way_round() -> void:
	var quarter_turn: Quat64 = Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), PI / 2.0)
	var same_turn: Quat64 = Quat64.make(-quarter_turn.x, -quarter_turn.y, -quarter_turn.z, -quarter_turn.w)
	var forward: V3 = V3.make(0.0, 0.0, 1.0)
	_assert_v3(Quat64.rotate(Quat64.slerp(Quat64.identity(), same_turn, 0.5), forward),
			0.7071067811865476, 0.0, 0.7071067811865476, "slerp")
	_assert_v3(Quat64.rotate(Quat64.nlerp(Quat64.identity(), same_turn, 0.5), forward),
			0.7071067811865476, 0.0, 0.7071067811865476, "nlerp")


func test_nlerp_ends_on_its_rotations_and_stays_unit_length() -> void:
	var a: Quat64 = Quat64.from_axis_angle(V3.make(1.0, 2.0, -0.5), 1.1)
	var b: Quat64 = Quat64.from_axis_angle(V3.make(-0.3, 0.2, 1.0), -2.6)
	assert_almost_eq(Quat64.angle_between(Quat64.nlerp(a, b, 0.0), a), 0.0, EPS, "t = 0")
	assert_almost_eq(Quat64.angle_between(Quat64.nlerp(a, b, 1.0), b), 0.0, EPS, "t = 1")
	var mid: Quat64 = Quat64.nlerp(a, b, 0.3)
	assert_almost_eq(sqrt(mid.x * mid.x + mid.y * mid.y + mid.z * mid.z + mid.w * mid.w), 1.0, EPS, "unit length")


func test_slerp_between_nearly_equal_rotations_is_finite() -> void:
	var a: Quat64 = Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), 0.5)
	var b: Quat64 = Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), 0.5 + 1e-13)
	for q: Quat64 in [Quat64.slerp(a, a, 0.5), Quat64.slerp(a, b, 0.5)]:
		assert_almost_eq(Quat64.angle_between(q, a), 0.0, 1e-9, "close to a: %s" % q)


func test_local_to_world_places_right_up_and_forward() -> void:
	var pos: V3 = V3.make(10.0, 0.5, 20.0)
	var local: V3 = V3.make(1.0, 2.0, 3.0) # 1 m right, 2 m up, 3 m forward
	# Facing +Z, a fighter's right is -X.
	_assert_v3(SimMath.local_to_world(pos, 0.0, local), 9.0, 2.5, 23.0, "yaw 0")
	# Facing +X, their right is +Z.
	_assert_v3(SimMath.local_to_world(pos, PI / 2.0, local), 13.0, 2.5, 21.0, "yaw pi/2")
	# Facing -Z, their right is +X.
	_assert_v3(SimMath.local_to_world(pos, PI, local), 11.0, 2.5, 17.0, "yaw pi")
	_assert_v3(pos, 10.0, 0.5, 20.0, "pos is untouched")


func test_a_turn_about_up_by_a_yaw_faces_the_fighters_forward() -> void:
	for yaw: float in [0.0, 0.7, -2.4]:
		var turned: V3 = Quat64.rotate(Quat64.from_axis_angle(V3.make(0.0, 1.0, 0.0), yaw), V3.make(0.0, 0.0, 1.0))
		var f: V2 = SimMath.fwd(yaw)
		_assert_v3(turned, f.x, 0.0, f.z, "forward at yaw %s" % yaw)


static func _seg_dist(a0: Array, a1: Array, b0: Array, b1: Array) -> float:
	return SimMath.segment_distance(
		V3.make(a0[0], a0[1], a0[2]), V3.make(a1[0], a1[1], a1[2]), V3.make(b0[0], b0[1], b0[2]), V3.make(b1[0], b1[1], b1[2]))


func test_segment_distance() -> void:
	assert_eq(_seg_dist([-1, 0, 0], [1, 0, 0], [0, -1, 0], [0, 1, 0]), 0.0, "crossing")
	assert_eq(_seg_dist([-1, 0, 0], [1, 0, 0], [0, -1, 2], [0, 1, 2]), 2.0, "skew, closest inside both")
	assert_almost_eq(_seg_dist([0, 0, 0], [1, 0, 0], [2, 1, 0], [3, 1, 0]), sqrt(2.0), 1e-15, "end to end")
	assert_eq(_seg_dist([0, 0, 0], [2, 0, 0], [1, 3, 0], [3, 3, 0]), 3.0, "parallel and overlapping")
	assert_almost_eq(_seg_dist([0, 0, 0], [1, 0, 0], [3, 4, 0], [5, 4, 0]), sqrt(20.0), 1e-15, "parallel, apart along")
	assert_eq(_seg_dist([0.5, 2, 0], [0.5, 2, 0], [0, 0, 0], [1, 0, 0]), 2.0, "a point against a segment")
	assert_eq(_seg_dist([0, 0, 0], [1, 0, 0], [0.5, 2, 0], [0.5, 2, 0]), 2.0, "a segment against a point")
	assert_eq(_seg_dist([1, 1, 1], [1, 1, 1], [1, 1, 3], [1, 1, 3]), 2.0, "two points")
	assert_almost_eq(_seg_dist([0, 1, 2], [3, -1, 0.5], [-2, 0, 1], [1, 2, -1]), _seg_dist([1, 2, -1], [-2, 0, 1], [3, -1, 0.5], [0, 1, 2]), 1e-15,
			"either order")


func test_segment_closest_points() -> void:
	var a0: V3 = V3.make(-1.0, 0.0, 0.0)
	var a1: V3 = V3.make(1.0, 0.0, 0.0)
	var p: Array[V3] = SimMath.segment_closest(a0, a1, V3.make(0.5, -1.0, 2.0), V3.make(0.5, 1.0, 2.0))
	_assert_v3(p[0], 0.5, 0.0, 0.0, "skew: on the first")
	_assert_v3(p[1], 0.5, 0.0, 2.0, "skew: on the second")
	p = SimMath.segment_closest(a0, a1, V3.make(3.0, 1.0, 0.0), V3.make(4.0, 1.0, 0.0))
	_assert_v3(p[0], 1.0, 0.0, 0.0, "end to end: the first's end")
	_assert_v3(p[1], 3.0, 1.0, 0.0, "end to end: the second's start")
	p = SimMath.segment_closest(a0, a0, V3.make(0.0, 1.0, 0.0), V3.make(0.0, 1.0, 0.0))
	_assert_v3(p[0], -1.0, 0.0, 0.0, "two points: the first")
	_assert_v3(p[1], 0.0, 1.0, 0.0, "two points: the second")
	assert_ne(p[0], a0, "a new V3, not the one passed in")
