extends GutTest
## Weapons fixed to the hands for authored clips (FighterRig.fix_weapons()):
## each rides its hand at its grip, the handle inside the closed fist on both
## fighters; the off hand of a two-handed weapon reaches its OffHandGrip on
## IK over the clip (within 1 cm); the Daggers fill both hands and turn into
## the reverse hold. The CC0 UAL clips drive these; the local-only test runs
## the Iglesias clips of task 1 and skips itself without the libraries.

const NEAR: float = 0.01
## A one-handed CC0 sword clip whose off hand wanders well off the handle.
const CLIP: StringName = &"Sword_Regular_A"
## Task 1's Iglesias clips, the ones the off hand must hold the grip through
## (the catalogue's punches and kicks are bare-handed).
const TASK1_CLIPS: Array[StringName] = [&"CombatIdle1H01", &"Attack1H01_R", &"Attack2H01", &"Roll01", &"CombatDeath01", &"Dodge01"]


func _fighter(id: StringName, weapon: StringName, reverse: bool = false) -> FighterModel:
	var f: FighterModel = FighterLook.instantiate_fighter(id)
	f.autoplay_idle = false
	add_child_autofree(f)
	f.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	f.attach_weapon(WeaponLook.load_id(weapon))
	f.fix_weapons(reverse)
	return f


func _at(f: FighterModel, anim_name: String, time: float) -> void:
	f.animation_player.play(anim_name, 0.0)
	f.animation_player.seek(time, true)
	f.animation_player.pause()


## Steps the skeleton once; every bone's pose at the end of the modifier stack.
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


func _grip_centre(f: FighterModel, poses: Array[Transform3D], side: String) -> Vector3:
	return _bone(f, poses, side + "Hand") * f.rig.fist(side).origin


static func _to_line(p: Vector3, a: Vector3, dir: Vector3) -> float:
	var d: Vector3 = p - a
	return (d - dir * d.dot(dir)).length()


## The gap from the off hand's grip centre to a two-handed weapon's
## OffHandGrip, after a step.
func _off_hand_gap(f: FighterModel, poses: Array[Transform3D]) -> float:
	var w: Node3D = f.weapons[0]
	var off: Vector3 = w.transform * WeaponLook.marker(w, WeaponLook.OFF_HAND_GRIP).position
	return _grip_centre(f, poses, "Left").distance_to(off)


func test_a_fixed_weapon_rides_the_clips_main_hand() -> void:
	for id: StringName in FighterLook.IDS:
		for weapon: StringName in WeaponLook.IDS:
			var f: FighterModel = _fighter(id, weapon)
			for time: float in [0.1, 0.45, 0.8]:
				_at(f, "ual/" + CLIP, time)
				var poses: Array[Transform3D] = await _posed(f)
				var want: Transform3D = _bone(f, poses, "RightHand") * f.rig.fixed_grip("Right")
				if f.rig.is_drawn_in():
					# drawn in for the off hand: the main hand reaches it on IK
					assert_lt(_grip_centre(f, poses, "Right").distance_to(f.weapons[0].transform.origin), NEAR, "%s %s at %.2f s: drawn in, still in the right fist" % [id, weapon, time])
				else:
					assert_true(f.weapons[0].transform.is_equal_approx(want), "%s %s at %.2f s: in the right fist" % [id, weapon, time])
			assert_true(f.rig.is_fixed())
			assert_eq(f.hand_grip.wrists.size(), 0, "the clip keeps the wrists")


func test_the_off_hand_reaches_a_two_handed_weapons_grip_over_the_clip() -> void:
	for id: StringName in FighterLook.IDS:
		for weapon: StringName in [&"katana", &"greatsword"]:
			var f: FighterModel = _fighter(id, weapon)
			assert_true(f.rig.drives("Left"))
			for time: float in [0.0, 0.3, 0.6, 0.9]:
				_at(f, "ual/" + CLIP, time)
				var poses: Array[Transform3D] = await _posed(f)
				var gap: float = _off_hand_gap(f, poses)
				assert_lt(gap, NEAR, "%s %s at %.2f s: off hand %.1f cm from the off-hand grip" % [id, weapon, time, gap * 100.0])


func test_the_handle_sits_inside_each_fist() -> void:
	for id: StringName in FighterLook.IDS:
		for weapon: StringName in WeaponLook.IDS:
			var f: FighterModel = _fighter(id, weapon)
			_at(f, "ual/" + CLIP, 0.45)
			var poses: Array[Transform3D] = await _posed(f)
			var radius: float = f.weapon_look.grip_radius
			for side: String in FighterRig.SIDES:
				var held: Node3D = f.weapons[1 if side == "Left" and f.weapon_look.paired else 0]
				var axis: Vector3 = held.transform.basis.y.normalized()
				var centre: Vector3 = _grip_centre(f, poses, side)
				assert_lt(_to_line(centre, held.transform.origin, axis), 0.005, "%s %s %s: the handle runs through the fist" % [id, weapon, side])
				var half: float = HandGrip.FINGER_HALF * f.rig.fist(side).origin.y / HandGrip.FIST_ALONG
				for finger: String in HandGrip.FINGERS:
					var bone: int = f.skeleton.find_bone(side + finger + "Intermediate")
					var gap: float = _to_line(poses[bone].origin, centre, axis) - radius
					assert_almost_eq(gap, half, 0.003, "%s %s %s: %s %.1f cm off the handle" % [id, weapon, side, finger, gap * 100.0])


func test_daggers_fill_both_hands_and_turn_into_the_reverse_hold() -> void:
	var f: FighterModel = _fighter(&"rogue", &"daggers")
	_at(f, "ual/" + CLIP, 0.45)
	var poses: Array[Transform3D] = await _posed(f)
	var forward: Array[Vector3] = []
	for i: int in 2:
		var side: String = FighterRig.SIDES[i]
		assert_lt(_grip_centre(f, poses, side).distance_to(f.weapons[i].transform.origin), NEAR, "the %s dagger in its fist" % side)
		forward.append(f.weapons[i].transform.basis.y)
	assert_false(f.rig.drives("Left"), "no IK: each dagger rides its own hand")
	f.fix_weapons(true)
	poses = await _posed(f)
	for i: int in 2:
		var side: String = FighterRig.SIDES[i]
		assert_lt(_grip_centre(f, poses, side).distance_to(f.weapons[i].transform.origin), NEAR, "the reversed %s dagger stays in its fist" % side)
		assert_almost_eq(f.weapons[i].transform.basis.y.dot(forward[i]), -1.0, 0.001, "the %s blade points the other way" % side)
	# halfway through the flip (task 21): square to the forward blade
	f.rig.set_reverse_turn(0.5)
	poses = await _posed(f)
	for i: int in 2:
		var side: String = FighterRig.SIDES[i]
		assert_lt(_grip_centre(f, poses, side).distance_to(f.weapons[i].transform.origin), NEAR, "the turning %s dagger stays in its fist" % side)
		assert_almost_eq(f.weapons[i].transform.basis.y.dot(forward[i]), 0.0, 0.001, "the %s blade halfway round" % side)


func test_posing_or_carrying_unfixes_the_weapons() -> void:
	var f: FighterModel = _fighter(&"hunter", &"katana")
	f.carry_weapons()
	assert_false(f.rig.is_fixed())
	assert_false(f.rig.drives("Left"))
	f.fix_weapons()
	f.pose_weapon(0, FighterRig.weapon_frame(Vector3(-0.06, 1.08, 0.27), Vector3(0.12, 0.5, 0.86), Vector3(0, -1, 0)))
	assert_false(f.rig.is_fixed())
	assert_true(f.rig.drives("Right"), "posed: the IK places the hands again")


func test_local_the_off_hand_holds_the_grip_through_the_iglesias_clips() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	for pair: Array in [[&"hunter", &"HumanM"], [&"rogue", &"HumanF"]]:
		for weapon: StringName in [&"katana", &"greatsword"]:
			var f: FighterModel = _fighter(pair[0], weapon)
			var lib: AnimationLibrary = ClipLibraries.load_set(pair[1])
			f.animation_player.add_animation_library(pair[1], lib)
			var worst: float = 0.0
			var where: String = ""
			for clip: StringName in TASK1_CLIPS:
				var length: float = lib.get_animation(clip).length
				for i: int in 9:
					_at(f, "%s/%s" % [pair[1], clip], length * i / 8.0)
					var poses: Array[Transform3D] = await _posed(f)
					var gap: float = _off_hand_gap(f, poses)
					if gap > worst:
						worst = gap
						where = "%s at %.2f s" % [clip, length * i / 8.0]
			assert_lt(worst, NEAR, "%s with the %s: worst off-hand gap %.1f cm (%s)" % [pair[0], weapon, worst * 100.0, where])


## KE task 10: with the off hand let go (FighterRig.off_hand 0, the
## one-handed grip's clips) the IK leaves it on the clip, open, and the main
## hand holds the weapon alone; part of the way, it reaches part of the way.
func test_the_off_hand_lets_go_of_the_grip_in_one_hand() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id, &"katana")
		_at(f, "ual/" + CLIP, 0.45)
		f.rig.off_hand = 0.0
		assert_false(f.rig.drives("Left"), "%s: no IK on the off hand" % id)
		var poses: Array[Transform3D] = await _posed(f)
		var free: float = _off_hand_gap(f, poses)
		assert_gt(free, 0.05, "%s: the clip's off hand, %.1f cm off the grip" % [id, free * 100.0])
		assert_false(f.hand_grip.left_hand, "%s: the off hand open" % id)
		assert_true(f.weapons[0].transform.is_equal_approx(_bone(f, poses, "RightHand") * f.rig.fixed_grip("Right")), "%s: in the right fist" % id)
		f.rig.off_hand = 0.5
		assert_true(f.rig.drives("Left"), "%s: part of the way, on IK" % id)
		var half: float = _off_hand_gap(f, await _posed(f))
		assert_between(half, NEAR, free - NEAR, "%s: part of the way there (%.1f cm)" % [id, half * 100.0])
		f.rig.off_hand = 1.0
		assert_lt(_off_hand_gap(f, await _posed(f)), NEAR, "%s: all the way on" % id)


## Through a grip switch (KE tasks 8 and 10): the clips each of the Katana's
## grips plays standing and guarding (StateClips' grips: its idle, which is
## also its carry, its guard's loop and hit) and its re-grip into it keep the
## blade in the right fist; the two-handed grip's keep the off hand on its
## grip by IK, the one-handed grip's leave it off the handle on the clip, and
## the re-grip into two hands brings it to the handle by its own end.
func test_local_the_katana_stays_in_hand_through_a_grip_switch() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var sc: StateClips = StateClips.read()
	for pair: Array in [[&"hunter", &"HumanM"], [&"rogue", &"HumanF"]]:
		var f: FighterModel = _fighter(pair[0], &"katana")
		var lib: AnimationLibrary = ClipLibraries.load_set(pair[1])
		f.animation_player.add_animation_library(pair[1], lib)
		for grip: StringName in [WeaponGrip.ONE_HANDED, WeaponGrip.TWO_HANDED]:
			var clips: Array[StringName] = [sc.idle_for(&"katana", grip), sc.carry_for(&"katana", grip)]
			clips.append_array(sc.guard_for(&"katana", grip))
			clips.append(sc.regrip_for(&"katana", grip))
			for clip: StringName in clips:
				var one: bool = sc.one_handed(&"katana", clip)
				assert_eq(one, grip == WeaponGrip.ONE_HANDED, "%s is the %s grip's" % [clip, grip])
				f.rig.off_hand = 0.0 if one else 1.0
				var length: float = lib.get_animation(clip).length
				for i: int in 5:
					_at(f, "%s/%s" % [pair[1], clip], length * i / 4.0)
					var poses: Array[Transform3D] = await _posed(f)
					var gap: float = _off_hand_gap(f, poses)
					if one:
						if clip != sc.regrip_for(&"katana", grip) or i == 4:
							assert_gt(gap, 0.05, "%s %s at %.2f s: the off hand off the handle (%.1f cm)" % [pair[0], clip, length * i / 4.0, gap * 100.0])
					else:
						assert_lt(gap, NEAR, "%s %s at %.2f s: off hand %.1f cm off" % [pair[0], clip, length * i / 4.0, gap * 100.0])
					assert_lt(_grip_centre(f, poses, "Right").distance_to(f.weapons[0].transform.origin), 0.05, "%s %s %s: in the right fist" % [pair[0], grip, clip])
		# the re-grip into two hands carries the clip's own off hand toward the
		# handle (the IK, coming in with it, seats it there)
		var into: StringName = sc.regrip_for(&"katana", WeaponGrip.TWO_HANDED)
		f.rig.off_hand = 0.0
		_at(f, "%s/%s" % [pair[1], into], 0.0)
		var from: float = _off_hand_gap(f, await _posed(f))
		_at(f, "%s/%s" % [pair[1], into], lib.get_animation(into).length)
		var reached: float = _off_hand_gap(f, await _posed(f))
		gut.p("%s: the re-grip's own off hand goes from %.1f to %.1f cm from the grip" % [pair[0], from * 100.0, reached * 100.0])
		assert_lt(reached, from * 0.5, "%s: the re-grip carries the off hand to the handle" % pair[0])


## The per-move checklist's item 10 (milestone-1 task 40): each keyed move's
## clip, every deflect pair and the light block keep the off hand on the
## Katana's grip (within NEAR) on every rules frame, on both fighters, the
## worst recorded by row (a bare-hands move holds nothing, and a one-handed
## grip's own hit lets the off hand go, KE task 11: item 10 doesn't apply).
## Recorded for the owner, not held: task 40 reports
## these, and the new strings re-key them.
func test_local_the_keyed_clips_keep_the_off_hand_on_the_grip() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var sc: StateClips = StateClips.read()
	var rows: Dictionary[StringName, Array] = {}
	var free: int = 0
	for m: Array in ChecklistResults.keyed_moves():
		# a chain's first part's clip (the Iai's, KE task 18)
		var clip: StringName = ClipChain.parse(String((Moves.WEAPONS[m[0]] as WeaponDef).moves[m[1]].swing.clips[0]), [] as Array[String]).id if m[0] != &"fists" else &""
		if clip != &"" and sc.one_handed(m[0], clip):
			ChecklistResults.record_problems(10, m[1], [] as Array[String])
			free += 1
		elif m[0] != &"fists":
			rows[m[1]] = [clip]
	var clip_rows: Dictionary[StringName, Array] = ChecklistResults.clip_rows()
	rows[&"clip_deflect_light"] = clip_rows[&"clip_deflect_light"]
	rows[&"clip_block_light"] = clip_rows[&"clip_block_light"]
	# the clips of task 90's pairs that hold the Katana: the redirected
	# attacker's recoil and the blade's deflects at a limb
	rows[&"clip_deflect_redirect"] = [&"RedirectRecoil"]
	rows[&"clip_deflect_limb"] = [&"LimbDeflectHigh", &"LimbDeflectLow"]
	## the worst gap by clip: [gap (m), where]
	var worst: Dictionary[StringName, Array] = {}
	for pair: Array in [[&"hunter", &"HumanM"], [&"rogue", &"HumanF"]]:
		var f: FighterModel = _fighter(pair[0], &"katana")
		var lib: AnimationLibrary = ClipLibraries.load_set(pair[1])
		f.animation_player.add_animation_library(pair[1], lib)
		for row: StringName in rows:
			for clip: StringName in rows[row]:
				var length: float = lib.get_animation(clip).length
				var w: Array = worst.get(clip, [0.0, ""])
				for i: int in int(length * 60.0) + 1:
					_at(f, "%s/%s" % [pair[1], clip], i / 60.0)
					var gap: float = _off_hand_gap(f, await _posed(f))
					if gap > w[0]:
						w = [gap, "%s at rules frame %d" % [pair[0], i]]
				worst[clip] = w
	var lines: PackedStringArray = []
	for row: StringName in rows:
		var by_clip: Dictionary = {}
		for clip: StringName in rows[row]:
			var w: Array = worst[clip]
			lines.append("%-22s off hand %4.1f cm off the grip (%s)" % [clip, w[0] * 100.0, w[1]])
			by_clip[clip] = [] if w[0] < NEAR else ["off hand %.1f cm off the grip, %s" % [w[0] * 100.0, w[1]]]
		if row.begins_with("clip_"):
			ChecklistResults.record_clips(10, row, by_clip)
		else:
			ChecklistResults.record_problems(10, row, by_clip.values()[0])
	gut.p("the keyed clips' off hand, worst over every rules frame:\n" + "\n".join(lines))
	assert_eq(worst.size(), 28, "four lights, four pairs, the block, Crouching Crown and the two-handed string's own five (KE tasks 12-14), the redirected attacker's recoil and the blade's two deflects at a limb (milestone-1 task 90), Heaven Splitter and Rising Heaven (KE task 17), Leaping Cleave, Whirl Cut, Lunging Cut and Falling Crown (tasks 75 and 76), their off hand on the grip")
	assert_eq(free, 12, "the one-handed grip's own hits 1 to 4 (KE tasks 11 and 12), Crescent Coil (KE task 16), and the Iai's draws and Returning Draw (KE task 18), Running Draw, Wind Cut, Rising Cut and Aerial Cut (tasks 75 and 76), the off hand free")
