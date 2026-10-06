extends GutTest
## Inertial blending (milestone-1 task 23): on a hand-off the new pose shows
## at once with what is left of the old one laid over it, decaying to
## nothing within the blend's frames, never overshooting the new pose.

const EPS: float = 1e-6


# ------------------------------------------------------------------ the decay

func test_a_still_offset_decays_from_itself_to_nothing_within_the_blend() -> void:
	var last: float = 1.0
	for i: int in 41:
		var t: float = 4.0 * float(i) / 40.0
		var x: float = InertialBlend.decay(1.0, 0.0, 4.0, t)
		assert_true(x <= last + EPS, "never grows (t %.2f)" % t)
		assert_true(x >= 0.0, "never past the new pose (t %.2f)" % t)
		last = x
	assert_almost_eq(InertialBlend.decay(1.0, 0.0, 4.0, 0.0), 1.0, EPS, "the old pose at the hand-off")
	assert_eq(InertialBlend.decay(1.0, 0.0, 4.0, 4.0), 0.0, "the new pose at the blend's end")
	assert_eq(InertialBlend.decay(1.0, 0.0, 4.0, 9.0), 0.0, "and after")


func test_the_offset_leaves_with_the_speed_it_had() -> void:
	# closing on the new pose at 0.2 a frame: it carries on at that speed
	var dt: float = 1e-4
	var speed: float = (InertialBlend.decay(1.0, -0.2, 6.0, dt) - 1.0) / dt
	assert_almost_eq(speed, -0.2, 1e-3)


func test_no_speed_ever_carries_it_past_the_new_pose() -> void:
	for v0: float in [-0.1, -0.5, -2.0, -10.0, 0.3, 5.0]:
		for length: float in [2.0, 4.0, 8.0]:
			for i: int in 81:
				var t: float = length * float(i) / 80.0
				var x: float = InertialBlend.decay(0.5, v0, length, t)
				assert_true(x >= 0.0 and x <= 0.5 + EPS, "v0 %.1f over %d: %.4f at %.2f" % [v0, int(length), x, t])
			assert_eq(InertialBlend.decay(0.5, v0, length, length), 0.0, "v0 %.1f over %d: done at the end" % [v0, int(length)])


func test_moving_away_counts_as_still() -> void:
	assert_eq(InertialBlend.decay(1.0, 0.5, 4.0, 2.0), InertialBlend.decay(1.0, 0.0, 4.0, 2.0))


# ------------------------------------------------------------------ on a skeleton

## A two-bone skeleton with the modifier, stepped by hand.
func _skeleton() -> Array:
	var sk: Skeleton3D = Skeleton3D.new()
	sk.add_bone("Root")
	sk.add_bone("Arm")
	sk.set_bone_parent(1, 0)
	sk.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	sk.reset_bone_poses()
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var ib: InertialBlend = InertialBlend.new()
	sk.add_child(ib)
	add_child_autofree(sk)
	return [sk, ib]


## Shows the clip's pose (the arm turned `deg` about X, the root at `root`)
## at world time `time` and gives what the modifier made of it.
func _show(sk: Skeleton3D, ib: InertialBlend, time: float, deg: float, root: Vector3 = Vector3.ZERO) -> Array:
	ib.time = time
	sk.set_bone_pose_rotation(1, Quaternion(Vector3.RIGHT, deg_to_rad(deg)))
	sk.set_bone_pose_position(0, root)
	var out: Array = []
	var grab: Callable = func() -> void:
		# a lambda takes locals by value: fill the array, don't reassign it
		out.clear()
		out.append(rad_to_deg(sk.get_bone_pose_rotation(1).get_angle()) * signf(sk.get_bone_pose_rotation(1).x))
		out.append(sk.get_bone_pose_position(0))
	if not ib.active:
		# switched off, it doesn't run: the pose is the clip's
		sk.advance(1.0 / 60.0)
		grab.call()
		return out
	ib.modification_processed.connect(grab, CONNECT_ONE_SHOT)
	sk.advance(1.0 / 60.0)
	if out.is_empty():
		await wait_process_frames(1)
	return out


func test_a_step_change_shows_the_old_pose_then_decays_to_the_new_within_its_frames() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var ib: InertialBlend = made[1]
	await _show(sk, ib, 0.0, 0.0)
	await _show(sk, ib, 1.0, 0.0)
	ib.request(4)
	var angles: Array[float] = []
	for i: int in 9:
		var shown: Array = await _show(sk, ib, 2.0 + 0.5 * i, 60.0, Vector3(0.0, 0.0, 0.3))
		angles.append(float(shown[0]))
	assert_almost_eq(angles[0], 0.0, 0.01, "the hand-off shows the old pose")
	for i: int in range(1, angles.size()):
		assert_true(angles[i] >= angles[i - 1] - 0.01, "on toward the new pose (%s)" % str(angles))
		assert_true(angles[i] <= 60.0 + 0.01, "never past it (%s)" % str(angles))
	assert_almost_eq(angles[8], 60.0, 0.01, "the new pose 4 frames on")


func test_a_move_decays_as_a_turn_does() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var ib: InertialBlend = made[1]
	await _show(sk, ib, 0.0, 0.0)
	await _show(sk, ib, 1.0, 0.0)
	ib.request(4)
	var at_handoff: Array = await _show(sk, ib, 2.0, 0.0, Vector3(0.0, 0.0, 0.3))
	assert_almost_eq((at_handoff[1] as Vector3).z, 0.0, 1e-4, "the root where it was shown")
	var mid: Array = await _show(sk, ib, 4.0, 0.0, Vector3(0.0, 0.0, 0.3))
	assert_between((mid[1] as Vector3).z, 0.0, 0.3)
	var done: Array = await _show(sk, ib, 6.0, 0.0, Vector3(0.0, 0.0, 0.3))
	assert_almost_eq((done[1] as Vector3).z, 0.3, 1e-6, "and where the clip puts it after")


func test_with_no_request_or_switched_off_the_clip_shows_as_it_is() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var ib: InertialBlend = made[1]
	await _show(sk, ib, 0.0, 0.0)
	var shown: Array = await _show(sk, ib, 1.0, 45.0)
	assert_almost_eq(float(shown[0]), 45.0, 0.01, "no request: a cut")
	ib.active = false
	ib.request(4)
	shown = await _show(sk, ib, 2.0, 10.0)
	assert_almost_eq(float(shown[0]), 10.0, 0.01, "switched off: a cut")


func test_hit_stop_holds_the_blend() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var ib: InertialBlend = made[1]
	await _show(sk, ib, 0.0, 0.0)
	await _show(sk, ib, 1.0, 0.0)
	ib.request(4)
	await _show(sk, ib, 2.0, 60.0)
	var a: Array = await _show(sk, ib, 3.0, 60.0)
	var held: Array = await _show(sk, ib, 3.0, 60.0)
	assert_almost_eq(float(held[0]), float(a[0]), 1e-4, "the world's time stands still, and so does the blend")
