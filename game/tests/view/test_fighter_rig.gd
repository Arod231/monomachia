extends GutTest
## The fighter rig (FighterRig, BodyLayer, HandGrip) on the real fighters: a
## posed weapon puts the hands on its grips (wrists within 1 cm of their
## targets, grips within 1 cm of the WeaponLook points), one-handed,
## two-handed and paired weapons fill the right hands, the fingers wrap the
## handle, the elbows hang, the legs reach their foot targets, the body
## layer turns what it says, and the same input gives the same pose.
##
## Each test steps a fighter's skeleton once by hand and reads every bone at
## the end of the modifier stack: outside an update the skeleton holds the
## clip's pose, since modifiers don't keep what they change.

const CLIP: StringName = &"Idle"
const NEAR: float = 0.01
## Reachable guards, per weapon: [grip, blade direction, edge direction] per
## held weapon, in the fighter's frame (+Z forward, +X to its left).
const GUARDS: Dictionary[StringName, Array] = {
	&"katana": [[Vector3(-0.06, 1.08, 0.27), Vector3(0.12, 0.5, 0.86), Vector3(0.0, -1.0, 0.0)]],
	&"greatsword": [[Vector3(-0.05, 1.15, 0.3), Vector3(0.05, 0.55, 0.83), Vector3(0.0, 0.0, 1.0)]],
	&"daggers": [
		[Vector3(-0.18, 1.12, 0.28), Vector3(-0.05, 0.34, 0.94), Vector3(0.0, -1.0, 0.0)],
		[Vector3(0.18, 1.16, 0.26), Vector3(0.05, 0.34, 0.94), Vector3(0.0, -1.0, 0.0)],
	],
}


## A fighter frozen in the relaxed idle, holding `weapon` (a look, or an id;
## null or &"" for bare hands) in its guard when `posed`.
func _fighter(id: StringName, weapon: Variant = null, posed: bool = true) -> FighterModel:
	var f: FighterModel = FighterLook.instantiate_fighter(id)
	f.autoplay_idle = false
	add_child_autofree(f)
	f.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var look: WeaponLook = weapon as WeaponLook if weapon is WeaponLook else null
	if weapon is StringName and weapon != &"":
		look = WeaponLook.load_id(weapon)
	if look != null:
		f.attach_weapon(look)
		if posed:
			for i: int in f.weapons.size():
				f.pose_weapon(i, _guard(look.id, i))
	f.play(CLIP, 0.0)
	f.animation_player.seek(0.5, true)
	f.animation_player.pause()
	return f


func _guard(weapon_id: StringName, index: int) -> Transform3D:
	var g: Array = GUARDS[weapon_id][index]
	return FighterRig.weapon_frame(g[0], g[1], g[2])


## Steps the skeleton once and returns every bone's pose in skeleton space
## at the end of the modifier stack.
func _posed(f: FighterModel) -> Array[Transform3D]:
	var sk: Skeleton3D = f.skeleton
	var poses: Array[Transform3D] = []
	var grab: Callable = func() -> void:
		poses.clear()
		for i: int in sk.get_bone_count():
			poses.append(sk.get_bone_global_pose(i))
	(sk.get_node(^"RigCarry") as SkeletonModifier3D).modification_processed.connect(grab, CONNECT_ONE_SHOT)
	sk.advance(1.0 / 60.0)
	if poses.is_empty():
		await wait_process_frames(1)
	return poses


func _bone(f: FighterModel, poses: Array[Transform3D], bone: String) -> Transform3D:
	return poses[f.skeleton.find_bone(bone)]


## Where a hand's fist (its grip centre) is in a posed skeleton.
func _grip_centre(f: FighterModel, poses: Array[Transform3D], side: String) -> Vector3:
	return _bone(f, poses, side + "Hand") * f.rig.fist(side).origin


static func _to_line(p: Vector3, a: Vector3, dir: Vector3) -> float:
	var d: Vector3 = p - a
	return (d - dir * d.dot(dir)).length()


func test_the_rig_stacks_its_modifiers_in_order() -> void:
	var f: FighterModel = _fighter(&"rogue")
	var stack: Array[String] = []
	for child: Node in f.skeleton.get_children():
		if child is SkeletonModifier3D:
			stack.append(child.name)
	# inertial blending first, right after the clip (milestone-1 task 23),
	# then the physical reaction layer (task 70)
	assert_eq(stack, ["InertialBlend", "PhysicalReactionLayer", "BodyLayer", "RigPre", "RightArmIK", "LeftArmIK", "LegIK", "RigPost", "HandGrip", "RigCarry"])
	assert_eq(f.rig.inertial, f.skeleton.get_node(^"InertialBlend"))
	assert_eq(f.rig.reaction, f.skeleton.get_node(^"PhysicalReactionLayer"))
	assert_eq(f.rig.body, f.skeleton.get_node(^"BodyLayer"))


## Arm and leg lengths and the fists come from each skeleton: the Hunter's
## hands are larger, so his fist's hollow sits further along the hand.
func test_limbs_and_fists_are_measured_from_each_skeleton() -> void:
	var rogue: FighterModel = _fighter(&"rogue", &"katana", false)
	var hunter: FighterModel = _fighter(&"hunter", &"katana", false)
	assert_almost_eq(rogue.rig.arm_length("Right"), 0.4896, 0.001)
	assert_almost_eq(hunter.rig.arm_length("Right"), 0.4915, 0.001)
	assert_almost_eq(rogue.rig.leg_length("Left"), 0.876, 0.002)
	var fist: Vector3 = rogue.rig.fist("Right").origin
	assert_almost_eq(fist.y, 0.070, 0.001, "under the base of the Rogue's fingers")
	assert_almost_eq(fist.z, 0.028, 0.001, "a katana's radius out of the Rogue's palm")
	assert_gt(hunter.rig.fist("Right").origin.y, fist.y + 0.015, "the Hunter's larger hand")
	rogue.attach_weapon(WeaponLook.load_id(&"greatsword"))
	assert_almost_eq(rogue.rig.fist("Right").origin.z - fist.z, 0.027 - 0.0138, 0.0005, "a thicker handle sits further out of the palm")


## The katana in a guard on both fighters: each wrist within 1 cm of its
## target and its hand turned to its frame on the handle; the right grip on
## the weapon's origin and the left on its OffHandGrip, within 1 cm.
func test_a_posed_katana_puts_both_hands_on_its_grips() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id, &"katana")
		var poses: Array[Transform3D] = await _posed(f)
		var katana: Node3D = f.weapons[0]
		assert_eq(katana.transform, _guard(&"katana", 0), "%s: the katana is where it was posed" % id)
		var points: Dictionary[String, Vector3] = {
			"Right": katana.transform.origin,
			"Left": katana.transform * WeaponLook.marker(katana, WeaponLook.OFF_HAND_GRIP).position,
		}
		for side: String in FighterRig.SIDES:
			var hand: Transform3D = _bone(f, poses, side + "Hand")
			var want: Transform3D = f.rig.hand_frame(side)
			assert_lt(hand.origin.distance_to(want.origin), NEAR, "%s %s wrist on its target" % [id, side])
			assert_lt(rad_to_deg(hand.basis.get_rotation_quaternion().angle_to(want.basis.get_rotation_quaternion())), 1.0, "%s %s hand turned onto the handle" % [id, side])
			var miss: float = _grip_centre(f, poses, side).distance_to(points[side])
			gut.p("%s %s grip %.1f mm from its point" % [id, side, miss * 1000.0])
			assert_lt(miss, NEAR, "%s %s grip on its point" % [id, side])


## Each hand turns round the handle toward its forearm, so the wrist doesn't
## bend back or forward whatever way the blade points: on both fighters, in
## guards with the blade raised, level, upright and off to the right, each
## wrist bends less than 10 degrees (PoseCheck's measure).
func test_each_hand_turns_round_the_handle_toward_its_forearm() -> void:
	var guards: Array[Array] = [
		[Vector3(-0.06, 1.08, 0.27), Vector3(0.12, 0.5, 0.86)],
		[Vector3(-0.04, 1.0, 0.3), Vector3(0.0, 0.2, 1.0)],
		[Vector3(-0.05, 1.12, 0.25), Vector3(0.0, 1.0, 0.3)],
		[Vector3(-0.16, 1.02, 0.28), Vector3(-0.2, 0.6, 0.8)],
	]
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id, &"katana", false)
		var check: PoseCheck = PoseCheck.new(f)
		for g: Array in guards:
			f.pose_weapon(0, FighterRig.weapon_frame(g[0], g[1], Vector3(0.0, -1.0, 0.0)))
			var frame: PoseCheck.Frame = PoseCheck.Frame.new()
			frame.bones = await _posed(f)
			frame.driven.assign(FighterRig.SIDES)
			var wrists: Dictionary[String, Vector2] = check.measure(frame).wrists
			for side: String in FighterRig.SIDES:
				gut.p("%s blade %s: %s wrist bent %+.1f, turned %+.1f" % [id, g[1], side, wrists[side].x, wrists[side].y])
				assert_lt(absf(wrists[side].x), 10.0, "%s, blade %s: the %s wrist in line" % [id, g[1], side])


## elbow_at() says where an arm's IK bends its elbow toward its pole.
func test_the_rig_knows_where_the_ik_bends_each_elbow() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id, &"katana")
		var poses: Array[Transform3D] = await _posed(f)
		var sk: Skeleton3D = f.skeleton
		for side: String in FighterRig.SIDES:
			var shoulder: Vector3 = _bone(f, poses, side + "UpperArm").origin
			var pole: Vector3 = (sk.get_node(NodePath(side + "ElbowPole")) as Node3D).position
			var upper: float = sk.get_bone_global_rest(sk.find_bone(side + "UpperArm")).origin.distance_to(sk.get_bone_global_rest(sk.find_bone(side + "LowerArm")).origin)
			var lower: float = sk.get_bone_global_rest(sk.find_bone(side + "LowerArm")).origin.distance_to(sk.get_bone_global_rest(sk.find_bone(side + "Hand")).origin)
			var predicted: Vector3 = FighterRig.elbow_at(shoulder, _bone(f, poses, side + "Hand").origin, pole, upper, lower)
			assert_lt(predicted.distance_to(_bone(f, poses, side + "LowerArm").origin), 0.005, "%s %s elbow" % [id, side])


func test_the_same_input_gives_the_same_pose() -> void:
	var f: FighterModel = _fighter(&"hunter", &"katana")
	f.rig.leg_weight = 1.0
	f.rig.body.spine_yaw = 0.3
	var first: Array[Transform3D] = await _posed(f)
	var second: Array[Transform3D] = await _posed(f)
	for i: int in first.size():
		assert_true(first[i].is_equal_approx(second[i]), "bone %s moved between updates" % f.skeleton.get_bone_name(i))


func test_the_greatsword_off_hand_reaches_its_off_hand_grip() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id, &"greatsword")
		var poses: Array[Transform3D] = await _posed(f)
		var sword: Node3D = f.weapons[0]
		var off: Vector3 = sword.transform * WeaponLook.marker(sword, WeaponLook.OFF_HAND_GRIP).position
		assert_lt(_grip_centre(f, poses, "Left").distance_to(off), NEAR, "%s's off hand on the greatsword's OffHandGrip" % id)
		assert_lt(_grip_centre(f, poses, "Right").distance_to(sword.transform.origin), NEAR, id)


func test_paired_daggers_fill_both_hands() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id, &"daggers")
		var poses: Array[Transform3D] = await _posed(f)
		assert_eq(f.weapons.size(), 2)
		for i: int in 2:
			var side: String = FighterRig.SIDES[i]
			assert_eq(f.weapons[i].transform, _guard(&"daggers", i))
			assert_lt(_grip_centre(f, poses, side).distance_to(f.weapons[i].transform.origin), NEAR, "%s's %s hand on its dagger" % [id, side])


## A one-handed weapon leaves the off hand to the clip: no IK, an open hand,
## the arm where the clip has it.
func test_a_one_handed_weapon_leaves_the_off_hand_free() -> void:
	var sword: WeaponLook = WeaponLook.load_id(&"katana").duplicate()
	sword.two_handed = false
	var f: FighterModel = _fighter(&"rogue", sword)
	var poses: Array[Transform3D] = await _posed(f)
	assert_true(f.rig.drives("Right"))
	assert_false(f.rig.drives("Left"), "the off hand isn't placed")
	assert_false(f.hand_grip.left_hand, "the off hand stays open")
	assert_false((f.skeleton.get_node(^"LeftArmIK") as TwoBoneIK3D).active)
	for bone: String in ["LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftIndexProximal"]:
		var clip_pose: Transform3D = f.skeleton.get_bone_global_pose(f.skeleton.find_bone(bone))
		assert_true(_bone(f, poses, bone).is_equal_approx(clip_pose), "%s is the clip's" % bone)
	assert_lt(_grip_centre(f, poses, "Right").distance_to(f.weapons[0].transform.origin), NEAR)


## The elbows bend down and out toward their poles, not up or in.
func test_the_elbows_hang() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id, &"katana")
		var poses: Array[Transform3D] = await _posed(f)
		for side: String in FighterRig.SIDES:
			var shoulder: Vector3 = _bone(f, poses, side + "UpperArm").origin
			var elbow: Vector3 = _bone(f, poses, side + "LowerArm").origin
			var wrist: Vector3 = _bone(f, poses, side + "Hand").origin
			var middle: Vector3 = (shoulder + wrist) * 0.5
			assert_lt(elbow.y, middle.y - 0.03, "%s's %s elbow hangs below its arm's line" % [id, side])
			var out: float = -1.0 if side == "Right" else 1.0
			assert_gt((elbow.x - middle.x) * out, 0.0, "%s's %s elbow points out" % [id, side])


## Each finger is curled round the handle: its joints and tip a finger's
## half thickness off the surface (within 3 mm), on every weapon and both
## fighters; the thumb's tip on it too (within 1 cm).
func test_the_fingers_wrap_the_handle() -> void:
	for id: StringName in FighterLook.IDS:
		for weapon: StringName in WeaponLook.IDS:
			var f: FighterModel = _fighter(id, weapon)
			var poses: Array[Transform3D] = await _posed(f)
			var radius: float = f.weapon_look.grip_radius
			for side: String in FighterRig.SIDES:
				var held: Node3D = f.weapons[1 if side == "Left" and f.weapon_look.paired else 0]
				var axis: Vector3 = held.transform.basis.y.normalized()
				var centre: Vector3 = f.rig.grip_point(side)
				var half: float = HandGrip.FINGER_HALF * f.rig.fist(side).origin.y / HandGrip.FIST_ALONG
				for finger: String in HandGrip.FINGERS:
					var bone: int = f.skeleton.find_bone(side + finger + "Intermediate")
					while bone >= 0:
						var gap: float = _to_line(poses[bone].origin, centre, axis) - radius
						assert_almost_eq(gap, half, 0.003, "%s %s %s: %s %.1f cm off the handle" % [id, weapon, side, f.skeleton.get_bone_name(bone), gap * 100.0])
						var children: PackedInt32Array = f.skeleton.get_bone_children(bone)
						bone = children[0] if not children.is_empty() else -1
				var thumb: int = f.skeleton.get_bone_children(f.skeleton.find_bone(side + "ThumbDistal"))[0]
				var thumb_gap: float = _to_line(poses[thumb].origin, centre, axis) - radius
				assert_between(thumb_gap, 0.0, 0.02, "%s %s %s: the thumb's tip %.1f cm off the handle" % [id, weapon, side, thumb_gap * 100.0])


## Carried, a weapon follows its hand, set in the fist as the hold says, and
## the hold's wrists are set; posed, it stays where it was put and the IK's
## hands keep their own wrists.
func test_a_carried_weapon_follows_its_hand() -> void:
	var f: FighterModel = _fighter(&"rogue", &"daggers", false)
	var poses: Array[Transform3D] = await _posed(f)
	for i: int in 2:
		var side: String = FighterRig.SIDES[i]
		var want: Transform3D = _bone(f, poses, side + "Hand") * f.rig.fist(side) * f.hold.grip_transform()
		assert_true(f.weapons[i].transform.is_equal_approx(want), "the %s dagger is in its fist" % side)
	assert_eq(f.hand_grip.wrists.size(), 2, "the hold sets both wrists")
	f.pose_weapon(0, _guard(&"daggers", 0))
	assert_false(f.hand_grip.wrists.has("Right"), "the IK's hand keeps its own wrist")
	assert_true(f.hand_grip.wrists.has("Left"), "the hand that still carries keeps the hold's")
	await _posed(f)
	assert_eq(f.weapons[0].transform, _guard(&"daggers", 0), "a posed dagger stays where it was put")
	f.carry_weapons()
	assert_eq(f.hand_grip.wrists.size(), 2)


## On leg IK the feet go to their targets, flat and turned to their yaw.
func test_leg_ik_puts_the_feet_on_their_targets() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		var rig: FighterRig = f.rig
		rig.leg_weight = 1.0
		rig.foot_position["Right"] += Vector3(-0.05, 0.0, 0.22)
		rig.foot_yaw["Right"] = deg_to_rad(-8.0)
		rig.foot_position["Left"] += Vector3(0.04, 0.0, -0.2)
		rig.foot_yaw["Left"] = deg_to_rad(35.0)
		var poses: Array[Transform3D] = await _posed(f)
		for side: String in FighterRig.SIDES:
			var foot: Transform3D = _bone(f, poses, side + "Foot")
			assert_lt(foot.origin.distance_to(rig.foot_position[side]), NEAR, "%s's %s foot on its target" % [id, side])
			var ahead: Vector3 = foot.basis.y.normalized()
			assert_almost_eq(rad_to_deg(atan2(ahead.x, ahead.z)), rad_to_deg(rig.foot_yaw[side]), 2.0, "%s's %s foot turned" % [id, side])
			assert_almost_eq(ahead.y, 0.0, 0.03, "%s's %s foot flat" % [id, side])


## Near full reach the shoulder comes forward to the hand.
func test_the_clavicle_reaches_near_full_reach() -> void:
	var f: FighterModel = _fighter(&"rogue", &"katana", false)
	var clip_shoulder: Vector3 = f.skeleton.get_bone_global_pose(f.skeleton.find_bone("RightUpperArm")).origin
	f.pose_weapon(0, FighterRig.weapon_frame(Vector3(-0.1, 1.2, 0.42), Vector3(0.0, 0.3, 1.0), Vector3(0.0, -1.0, 0.0)))
	var poses: Array[Transform3D] = await _posed(f)
	var shoulder: Vector3 = _bone(f, poses, "RightUpperArm").origin
	var toward: Vector3 = (f.rig.hand_frame("Right").origin - clip_shoulder).normalized()
	assert_gt((shoulder - clip_shoulder).dot(toward), 0.005, "the right shoulder comes forward")


## All at zero, the body layer leaves the clip alone; each value turns or
## moves what it says.
func test_the_body_layer_turns_the_body() -> void:
	var f: FighterModel = _fighter(&"rogue")
	var sk: Skeleton3D = f.skeleton
	var clip: Array[Transform3D] = await _posed(f)
	for i: int in clip.size():
		assert_true(clip[i].is_equal_approx(sk.get_bone_global_pose(i)), "at zero, %s is the clip's" % sk.get_bone_name(i))
	var yaw_of: Callable = func(poses: Array[Transform3D], bone: String) -> float:
		var fwd: Vector3 = poses[sk.find_bone(bone)].basis.z
		return atan2(fwd.x, fwd.z)
	var body: BodyLayer = f.rig.body
	body.pelvis_yaw = 0.3
	body.spine_yaw = -0.5
	body.head_yaw = 0.4
	body.hips_offset = Vector3(0.0, -0.08, 0.02)
	var posed: Array[Transform3D] = await _posed(f)
	assert_almost_eq(yaw_of.call(posed, "Hips") - yaw_of.call(clip, "Hips"), 0.3, 0.01, "the hips turn")
	assert_almost_eq(yaw_of.call(posed, "UpperChest") - yaw_of.call(clip, "UpperChest"), 0.3 - 0.5, 0.02, "the chest turns by the hips and the spine")
	assert_almost_eq(yaw_of.call(posed, "Head") - yaw_of.call(clip, "Head"), 0.3 - 0.5 + 0.4, 0.02, "the head turns on top")
	var hips: int = sk.find_bone("Hips")
	assert_true(posed[hips].origin.is_equal_approx(clip[hips].origin + Vector3(0.0, -0.08, 0.02)), "the hips move")
	body.clear()
	body.lean = Vector3(0.2, 0.0, 0.0)
	posed = await _posed(f)
	var head: int = sk.find_bone("Head")
	assert_gt(posed[head].origin.z, clip[head].origin.z + 0.2, "leaning about +X tips the body forward")


## A bone's turn about the vertical from its rest (radians, positive to the
## fighter's left).
func _heading(f: FighterModel, poses: Array[Transform3D], bone: String) -> float:
	var i: int = f.skeleton.find_bone(bone)
	var turn: Basis = poses[i].basis.orthonormalized() * f.skeleton.get_bone_global_rest(i).basis.orthonormalized().inverse()
	var fwd: Vector3 = turn * Vector3.BACK
	return atan2(fwd.x, fwd.z)


## Freezes `f` in the jog where it twists its chest furthest from its hips,
## and returns that twist.
func _jog_twisted(f: FighterModel) -> float:
	var ap: AnimationPlayer = f.animation_player
	f.play(&"Jog_Fwd", 0.0)
	var length: float = ap.current_animation_length
	var sk: Skeleton3D = f.skeleton
	var best: float = 0.0
	var best_at: float = 0.0
	for k: int in 24:
		ap.seek(length * k / 24.0, true)
		var clip: Array[Transform3D] = []
		for i: int in sk.get_bone_count():
			clip.append(sk.get_bone_global_pose(i))
		var twist: float = wrapf(_heading(f, clip, "UpperChest") - _heading(f, clip, "Hips"), -PI, PI)
		if absf(twist) > absf(best):
			best = twist
			best_at = length * k / 24.0
	ap.seek(best_at, true)
	ap.pause()
	return best


## Untwisting takes the clip's own twist above the hips out, bone by bone:
## the spine, neck and head face the way the hips do.
func test_untwisting_squares_the_spine_neck_and_head_to_the_hips() -> void:
	var f: FighterModel = _fighter(&"rogue", null, false)
	var twist: float = _jog_twisted(f)
	assert_gt(absf(rad_to_deg(twist)), 30.0, "the jog swings the chest")
	var clip: Array[Transform3D] = await _posed(f)
	var hips: float = _heading(f, clip, "Hips")
	var body: BodyLayer = f.rig.body
	body.untwist = 1.0
	var posed: Array[Transform3D] = await _posed(f)
	for bone: String in ["Spine", "Chest", "UpperChest", "Neck", "Head"]:
		assert_almost_eq(rad_to_deg(wrapf(_heading(f, posed, bone) - hips, -PI, PI)), 0.0, 0.5, "%s faces the way the hips do" % bone)
	assert_almost_eq(_heading(f, posed, "Hips"), hips, 1e-4, "the hips stay")
	body.untwist = 0.5
	posed = await _posed(f)
	assert_almost_eq(wrapf(_heading(f, posed, "UpperChest") - hips, -PI, PI), twist / 2.0, deg_to_rad(0.5), "half of it")
	body.clear()
	assert_eq(body.untwist, 0.0)


## The legs' turn takes the feet with it: the leg IK keeps them where the
## turned legs put them, not where the clip had them.
func test_turned_legs_take_the_planted_feet_with_them() -> void:
	var f: FighterModel = _fighter(&"rogue", null, false)
	f.play(&"Walk", 0.0)
	f.animation_player.seek(0.1, true)
	f.animation_player.pause()
	var sk: Skeleton3D = f.skeleton
	var clip: Array[Transform3D] = await _posed(f)
	var body: BodyLayer = f.rig.body
	body.pelvis_yaw = 0.5
	body.thigh_yaw = 0.2
	var turned: Array[Transform3D] = await _posed(f)
	f.rig.clip_feet = 1.0
	f.rig.leg_weight = 1.0
	body.hips_offset = Vector3(0.0, -0.05, 0.0)
	var planted: Array[Transform3D] = await _posed(f)
	for side: String in FighterRig.SIDES:
		var foot: int = sk.find_bone(side + "Foot")
		assert_gt(turned[foot].origin.distance_to(clip[foot].origin), 0.05, "%s foot: turning the legs moves it" % side)
		assert_lt(planted[foot].origin.distance_to(turned[foot].origin), NEAR, "%s foot planted where the turned leg put it" % side)
		var angle: float = planted[foot].basis.get_rotation_quaternion().angle_to(turned[foot].basis.get_rotation_quaternion())
		assert_lt(rad_to_deg(angle), 1.0, "%s foot turned with the leg" % side)


## moved() says where the body layer puts a point riding the upper chest
## (a shoulder, say), before the skeleton updates: the reach check uses it.
func test_the_body_layer_says_where_it_moves_the_upper_body() -> void:
	var f: FighterModel = _fighter(&"rogue", null, false)
	_jog_twisted(f)
	var sk: Skeleton3D = f.skeleton
	var bones: Array[String] = ["UpperChest", "Neck", "LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm"]
	var body: BodyLayer = f.rig.body
	body.pelvis_yaw = 0.6
	body.thigh_yaw = 0.25
	body.spine_yaw = -0.6
	body.untwist = 1.0
	body.hips_offset = Vector3(0.02, -0.08, 0.03)
	body.spine_pitch = 0.2
	body.spine_roll = -0.1
	body.lean = Vector3(0.08, 0.0, -0.05)
	var said: Dictionary[String, Vector3] = {}
	for bone: String in bones:
		said[bone] = body.moved(sk, sk.get_bone_global_pose(sk.find_bone(bone)).origin)
	var posed: Array[Transform3D] = await _posed(f)
	for bone: String in bones:
		assert_lt(_bone(f, posed, bone).origin.distance_to(said[bone]), 0.001, bone)


## The finger solver on a made-up finger: each joint and the tip land on
## the circle, going round it the way fingers curl.
func test_wrap_curls_puts_each_joint_on_the_circle() -> void:
	var knuckle: Vector2 = Vector2(0.0, 0.0)
	var lengths: PackedFloat32Array = PackedFloat32Array([0.04, 0.03, 0.025])
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT]
	var centre: Vector2 = Vector2(-0.01, 0.03)
	var radius: float = 0.025
	var curls: PackedFloat32Array = HandGrip.wrap_curls(knuckle, lengths, dirs, centre, radius)
	var at: Vector2 = knuckle
	var turned: float = 0.0
	var last_angle: float = (knuckle - centre).angle()
	for i: int in 3:
		assert_gt(curls[i], 0.0, "segment %d curls in" % i)
		turned += curls[i]
		at += Vector2.RIGHT.rotated(turned) * lengths[i]
		assert_almost_eq(at.distance_to(centre), radius, 1e-5, "joint %d on the circle" % (i + 1))
		var angle: float = (at - centre).angle()
		assert_gt(wrapf(angle - last_angle, 0.0, TAU), 0.0, "joint %d further round" % (i + 1))
		assert_lt(wrapf(angle - last_angle, 0.0, TAU), PI, "joint %d further round" % (i + 1))
		last_angle = angle
