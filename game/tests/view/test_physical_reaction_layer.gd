extends GutTest
## The physical reaction layer (milestone-1 task 70; spec stories 96, 98):
## damped springs on the spine, head and arms, kicked by a hit or a block
## from where and how hard it landed, on the world's time, picture only.

const EPS: float = 1e-4


# ------------------------------------------------------------------ the spring

func test_a_push_shows_at_once_peaks_overshoots_a_little_and_settles_in_half_a_second() -> void:
	var r: Callable = PhysicalReactionLayer.response
	assert_eq(r.call(-0.5), 0.0, "nothing before the push")
	var at_kick: float = r.call(0.0)
	assert_between(at_kick, 0.3, 0.7, "the kick shows at once, so hit-stop holds it there")
	var peak: float = -INF
	var peak_at: float = 0.0
	var low: float = INF
	for i: int in 601:
		var t: float = 60.0 * float(i) / 600.0
		var x: float = r.call(t)
		if x > peak:
			peak = x
			peak_at = t
		low = minf(low, x)
		if t >= 30.0:
			assert_lt(absf(x), 0.03, "settled within half a second (%.1f frames: %.4f)" % [t, x])
	assert_almost_eq(peak, 1.0, 0.01, "a unit push peaks at 1")
	assert_between(peak_at, 1.0, 5.0, "a few frames after the kick")
	assert_between(-low, 0.05, 0.35, "it overshoots a little past the pose on its way back")


func test_heavier_blows_and_weapons_push_harder_and_blocks_less() -> void:
	var s: Callable = PhysicalReactionLayer.strength
	assert_gt(s.call(true, &"medium"), s.call(false, &"medium"), "a heavy over a light")
	assert_gt(s.call(false, &"colossal"), s.call(false, &"medium"))
	assert_gt(s.call(false, &"medium"), s.call(false, &"small"))
	assert_gt(s.call(false, &"small"), s.call(false, &"fists"))
	assert_almost_eq(float(s.call(false, &"medium")), 1.0, EPS, "a light blade hit is the unit")
	assert_lt(s.call(true, &"medium", true), s.call(true, &"medium"), "a block pushes less than a hit")
	assert_gt(s.call(false, &"no_such_class"), 0.0, "an unknown weapon still pushes")


# ------------------------------------------------------------------ on a skeleton

## A spine, a head and a right arm (the fighter's frame: +Z forward, +X to
## its left, +Y up), with the layer, stepped by hand.
func _skeleton() -> Array:
	var sk: Skeleton3D = Skeleton3D.new()
	var bones: Array = [
		["Hips", -1, Vector3(0.0, 1.0, 0.0)],
		["Spine", 0, Vector3(0.0, 0.12, 0.0)],
		["Chest", 1, Vector3(0.0, 0.14, 0.0)],
		["UpperChest", 2, Vector3(0.0, 0.14, 0.0)],
		["Neck", 3, Vector3(0.0, 0.14, 0.0)],
		["Head", 4, Vector3(0.0, 0.1, 0.0)],
		["RightShoulder", 3, Vector3(-0.06, 0.1, 0.0)],
		["RightUpperArm", 6, Vector3(-0.12, 0.0, 0.0)],
		["RightLowerArm", 7, Vector3(-0.28, 0.0, 0.0)],
		["RightHand", 8, Vector3(-0.25, 0.0, 0.0)],
	]
	for b: Array in bones:
		var i: int = sk.get_bone_count()
		sk.add_bone(b[0])
		if int(b[1]) >= 0:
			sk.set_bone_parent(i, int(b[1]))
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, b[2]))
	sk.reset_bone_poses()
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var layer: PhysicalReactionLayer = PhysicalReactionLayer.new()
	sk.add_child(layer)
	add_child_autofree(sk)
	return [sk, layer]


## Shows the rest pose at world time `time` and gives each bone's turn in
## skeleton space from its rest after the layer ran: name -> Quaternion,
## and "pose" -> each bone's local pose rotation.
func _show(sk: Skeleton3D, layer: PhysicalReactionLayer, time: float) -> Dictionary:
	layer.time = time
	sk.reset_bone_poses()
	var out: Dictionary = {}
	var grab: Callable = func() -> void:
		out.clear()
		for i: int in sk.get_bone_count():
			var g: Basis = sk.get_bone_global_pose(i).basis.orthonormalized()
			out[sk.get_bone_name(i)] = g.get_rotation_quaternion() * sk.get_bone_global_rest(i).basis.get_rotation_quaternion().inverse()
			out["local " + sk.get_bone_name(i)] = sk.get_bone_pose_rotation(i)
	if not layer.active:
		sk.advance(1.0 / 60.0)
		grab.call()
		return out
	layer.modification_processed.connect(grab, CONNECT_ONE_SHOT)
	sk.advance(1.0 / 60.0)
	if out.is_empty():
		await wait_process_frames(1)
	return out


## Where the head's tip ends up in skeleton space for a pose from _show().
func _head_top(sk: Skeleton3D, shown: Dictionary) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone("Head")).origin + (shown["Head"] as Quaternion) * Vector3(0.0, 0.1, 0.0)


func _angle(shown: Dictionary, bone: String) -> float:
	return rad_to_deg((shown[bone] as Quaternion).get_angle())


## A blow to the chest from in front, pushing the fighter back (-Z).
func _chest_blow(layer: PhysicalReactionLayer, at: float, strength: float = 1.0, parts: int = PhysicalReactionLayer.HIT, arms: float = 1.0) -> void:
	layer.push(at, Vector3(0.0, 1.4, 0.15), Vector3(0.0, 0.0, -1.0), strength, parts, arms)


func test_a_blow_to_the_chest_tips_the_body_back_then_settles_to_the_clip() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	await _show(sk, layer, 9.0)
	_chest_blow(layer, 10.0)
	var at_kick: Dictionary = await _show(sk, layer, 10.0)
	assert_gt(_angle(at_kick, "UpperChest"), 1.0, "the kick shows on the push's frame")
	var peak: Dictionary = await _show(sk, layer, 12.5)
	var top: Vector3 = _head_top(sk, peak)
	assert_lt(top.z, -0.02, "the head goes back with the blow (%s)" % top)
	assert_gt(_angle(peak, "UpperChest"), _angle(at_kick, "UpperChest"), "on to its peak")
	assert_lt(_angle(peak, "Spine"), _angle(peak, "UpperChest"), "the spine further from the blow moves less")
	var settled: Dictionary = await _show(sk, layer, 45.0)
	for bone: String in ["Spine", "Chest", "UpperChest", "Neck", "Head", "RightUpperArm"]:
		assert_lt(_angle(settled, bone), 0.5, "%s back on the clip" % bone)
	var long_after: Dictionary = await _show(sk, layer, 200.0)
	for bone: String in ["Spine", "UpperChest", "Head"]:
		assert_almost_eq(_angle(long_after, bone), 0.0, 1e-3, "%s exactly on the clip once done" % bone)


func test_a_blow_to_the_head_turns_the_head_most() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	layer.push(0.0, Vector3(-0.08, 1.68, 0.08), Vector3(1.0, 0.0, 0.0), 1.0, PhysicalReactionLayer.HIT, 1.0)
	var peak: Dictionary = await _show(sk, layer, 2.5)
	var local_head: float = rad_to_deg((peak["local Head"] as Quaternion).get_angle())
	var local_spine: float = rad_to_deg((peak["local Spine"] as Quaternion).get_angle())
	assert_gt(local_head, local_spine, "the head takes more than the spine low down")
	assert_gt(_head_top(sk, peak).x, 0.0, "pushed to the fighter's left, away from a blow from its right")


func test_no_push_or_a_zero_push_leaves_the_pose() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	var none: Dictionary = await _show(sk, layer, 5.0)
	_chest_blow(layer, 6.0, 0.0)
	var zero: Dictionary = await _show(sk, layer, 8.0)
	for bone: String in ["Spine", "Chest", "UpperChest", "Neck", "Head", "RightShoulder", "RightUpperArm", "RightLowerArm"]:
		assert_almost_eq(_angle(none, bone), 0.0, 1e-4, "%s: no push" % bone)
		assert_almost_eq(_angle(zero, bone), 0.0, 1e-4, "%s: a zero push" % bone)


func test_switched_off_the_clip_shows_as_it_is() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	_chest_blow(layer, 0.0)
	layer.active = false
	var shown: Dictionary = await _show(sk, layer, 2.0)
	assert_almost_eq(_angle(shown, "UpperChest"), 0.0, 1e-4)


func test_hit_stop_holds_the_push_and_the_same_frames_give_the_same_pose() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	_chest_blow(layer, 3.0)
	var a: Dictionary = await _show(sk, layer, 3.0)
	var held: Dictionary = await _show(sk, layer, 3.0)
	assert_almost_eq(_angle(held, "UpperChest"), _angle(a, "UpperChest"), 1e-5, "the world's time stands still, and so does the push")
	# a second skeleton shown at other frames in between lands on the same pose
	var other: Array = _skeleton()
	var sk2: Skeleton3D = other[0]
	var layer2: PhysicalReactionLayer = other[1]
	_chest_blow(layer2, 3.0)
	await _show(sk2, layer2, 3.0)
	for t: float in [3.3, 4.7, 5.1, 6.9]:
		await _show(sk2, layer2, t)
	var b1: Dictionary = await _show(sk, layer, 8.25)
	var b2: Dictionary = await _show(sk2, layer2, 8.25)
	for bone: String in ["Spine", "UpperChest", "Head", "RightLowerArm"]:
		assert_almost_eq(_angle(b1, bone), _angle(b2, bone), 1e-4, "%s the same at the same frame" % bone)


func test_pushes_add_up_to_a_limit() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	_chest_blow(layer, 0.0)
	var one: Dictionary = await _show(sk, layer, 2.5)
	_chest_blow(layer, 2.5)
	var two: Dictionary = await _show(sk, layer, 2.5)
	assert_gt(_angle(two, "UpperChest"), _angle(one, "UpperChest") * 1.3, "a second blow adds to the first")
	for i: int in 30:
		_chest_blow(layer, 2.5, 3.0)
	var many: Dictionary = await _show(sk, layer, 2.5)
	assert_lt(rad_to_deg((many["local UpperChest"] as Quaternion).get_angle()), PhysicalReactionLayer.MAX_ANGLE + 0.01, "never past the limit")


func test_a_block_pushes_the_arms_and_upper_spine_only() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	layer.push(0.0, Vector3(-0.3, 1.45, 0.3), Vector3(0.0, 0.0, -1.0), 1.0, PhysicalReactionLayer.BLOCK, 1.0)
	var shown: Dictionary = await _show(sk, layer, 2.5)
	for bone: String in ["Spine", "Neck", "Head"]:
		assert_almost_eq(rad_to_deg((shown["local " + bone] as Quaternion).get_angle()), 0.0, 1e-4, "%s left alone" % bone)
	for bone: String in ["UpperChest", "RightUpperArm", "RightLowerArm"]:
		assert_gt(rad_to_deg((shown["local " + bone] as Quaternion).get_angle()), 0.3, "%s pushed" % bone)


func test_the_arms_share_scales_only_the_arms() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	var arm_blow: Vector3 = Vector3(-0.4, 1.45, 0.05)
	layer.push(0.0, arm_blow, Vector3(0.0, 0.0, -1.0), 1.0, PhysicalReactionLayer.HIT, 1.0)
	var full: Dictionary = await _show(sk, layer, 2.5)
	layer.clear()
	layer.push(0.0, arm_blow, Vector3(0.0, 0.0, -1.0), 1.0, PhysicalReactionLayer.HIT, 0.25)
	var soft: Dictionary = await _show(sk, layer, 2.5)
	var arm_full: float = rad_to_deg((full["local RightUpperArm"] as Quaternion).get_angle())
	var arm_soft: float = rad_to_deg((soft["local RightUpperArm"] as Quaternion).get_angle())
	assert_gt(arm_full, 0.5)
	assert_almost_eq(arm_soft, arm_full * 0.25, arm_full * 0.02, "a quarter of the arm's push")
	assert_almost_eq(rad_to_deg((soft["local UpperChest"] as Quaternion).get_angle()),
		rad_to_deg((full["local UpperChest"] as Quaternion).get_angle()), 1e-3, "the spine's push unchanged")


func test_clear_forgets_every_push() -> void:
	var made: Array = _skeleton()
	var sk: Skeleton3D = made[0]
	var layer: PhysicalReactionLayer = made[1]
	_chest_blow(layer, 0.0)
	layer.clear()
	var shown: Dictionary = await _show(sk, layer, 2.5)
	assert_almost_eq(_angle(shown, "UpperChest"), 0.0, 1e-4)
	assert_false(layer.reacting())
