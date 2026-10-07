extends GutTest
## The hand-keyed clips (KeyedClips) and their builder (KeyedPose,
## tools/build_keyed_clips.gd): the committed library is up to date with its
## key files, and the stomp's keys land where they say on both fighters.

const BuildKeyedClips := preload("res://tools/build_keyed_clips.gd")
const STOMP_KEYS: String = "res://assets/authored/keys/mikiri_stomp.json"
## The stomp's frames with the right foot planted on the spear.
const PLANTED: Array[int] = [8, 11, 15, 20, 26]


func _model(id: StringName) -> FighterModel:
	var model: FighterModel = FighterLook.instantiate_fighter(id)
	model.autoplay_idle = false
	add_child_autofree(model)
	model.animation_player.add_animation_library(KeyedClips.LIBRARY, KeyedClips.load_library())
	return model


func _keys() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(STOMP_KEYS))


func _key_at(f: int) -> Dictionary:
	for key: Dictionary in _keys()["keys"]:
		if int(key["f"]) == f:
			return key
	return {}


## Poses `model` with the stomp at rules frame `f`.
func _pose(model: FighterModel, f: int) -> Skeleton3D:
	model.animation_player.play(KeyedClips.anim_name(KeyedClips.STOMP), 0.0)
	model.animation_player.seek(float(f) / float(SimConst.FPS), true)
	return model.skeleton


func _bone(sk: Skeleton3D, bone: String) -> Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(bone))


func test_the_library_holds_the_stomp_fitted_to_the_stomp_state() -> void:
	var lib: AnimationLibrary = KeyedClips.load_library()
	assert_not_null(lib, "the keyed library is committed")
	if lib == null:
		return
	assert_true(lib.has_animation(KeyedClips.STOMP))
	var anim: Animation = lib.get_animation(KeyedClips.STOMP)
	assert_almost_eq(anim.length * SimConst.FPS, 26.0, 0.001, "the stomp state's 26 frames (Fighter.begin_stomp())")
	assert_eq(anim.loop_mode, Animation.LOOP_NONE)
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for t: int in anim.get_track_count():
		var path: NodePath = anim.track_get_path(t)
		assert_eq(String(path.get_concatenated_names()), KeyedPose.SKELETON_PREFIX, "%s addresses the general skeleton" % path)
		assert_ne(path.get_concatenated_subnames(), &"Root", "no root motion: the rules move the fighter")
		assert_true(profile.find_bone(path.get_concatenated_subnames()) >= 0 or String(path.get_concatenated_subnames()).contains("leaf"), "%s is a profile bone" % path)
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			assert_eq(path.get_concatenated_subnames(), &"Hips", "only the hips move")


func test_the_key_file_is_well_formed() -> void:
	assert_eq(BuildKeyedClips.check(_keys()), "")
	var broken: Dictionary = _keys()
	(broken["keys"] as Array).reverse()
	assert_ne(BuildKeyedClips.check(broken), "", "keys out of order are refused")


func test_the_committed_library_is_built_from_the_key_file() -> void:
	# a re-key must be rebuilt (node scripts/godot.mjs script res://tools/build_keyed_clips.gd)
	var model: FighterModel = _model(&"hunter")
	var data: Dictionary = _keys()
	var fresh: Animation = KeyedPose.build(data, model.skeleton, FighterModel.ANIMATION_LIBRARY.get_animation(StringName(data["base"])))
	var committed: Animation = KeyedClips.load_library().get_animation(KeyedClips.STOMP)
	assert_eq(committed.get_track_count(), fresh.get_track_count())
	for f: int in [0, 5, 11, 19, 26]:
		var time: float = float(f) / float(SimConst.FPS)
		for t: int in fresh.get_track_count():
			var c: int = committed.find_track(fresh.track_get_path(t), fresh.track_get_type(t))
			assert_gte(c, 0, "%s is in the committed clip" % fresh.track_get_path(t))
			if c < 0:
				continue
			if fresh.track_get_type(t) == Animation.TYPE_POSITION_3D:
				assert_lt(fresh.position_track_interpolate(t, time).distance_to(committed.position_track_interpolate(c, time)), 0.001, "the hips at frame %d" % f)
			else:
				var a: Quaternion = fresh.rotation_track_interpolate(t, time)
				var b: Quaternion = committed.rotation_track_interpolate(c, time)
				assert_gt(absf(a.dot(b)), 0.9999, "%s at frame %d" % [fresh.track_get_path(t), f])


func test_the_right_foot_stays_planted_on_the_spear_on_both_fighters() -> void:
	for id: StringName in [&"hunter", &"rogue"]:
		var model: FighterModel = _model(id)
		var sk: Skeleton3D = model.skeleton
		var rest_y: float = sk.get_bone_global_rest(sk.find_bone("RightFoot")).origin.y
		var first: Vector3 = Vector3.ZERO
		for f: int in PLANTED:
			var ankle: Vector3 = _bone(_pose(model, f), "RightFoot").origin
			if f == PLANTED[0]:
				first = ankle
			# the keys are sized on the Hunter: the Rogue's shorter feet leave her
			# ankle up to 2 cm over her rest height, as her UAL clips do
			assert_almost_eq(ankle.y, rest_y, 0.015 if id == &"hunter" else 0.025, "%s: the right foot on the floor at frame %d" % [id, f])
			assert_lt(Vector2(ankle.x, ankle.z).distance_to(Vector2(first.x, first.z)), 0.03, "%s: the right foot stays put at frame %d" % [id, f])
		if id == &"hunter":
			# where the key puts it (the keys are sized on the Hunter)
			var at: Array = _key_at(8)["legs"]["right"]["at"]
			assert_lt(first.distance_to(KeyedPose.side_vec("right", at)), 0.01, "the Hunter's right ankle on its key")


func test_the_feet_leave_the_floor_through_the_hop() -> void:
	var model: FighterModel = _model(&"hunter")
	var sk: Skeleton3D = _pose(model, 4)
	var rest_y: float = sk.get_bone_global_rest(sk.find_bone("RightFoot")).origin.y
	assert_gt(_bone(sk, "RightFoot").origin.y, rest_y + 0.2, "the right knee driven up at the apex")
	assert_gt(_bone(sk, "LeftFoot").origin.y, rest_y + 0.15, "the left leg tucked")


func test_the_blade_points_where_each_key_says() -> void:
	# FighterRig's grip lays the blade along the right hand's X axis
	var model: FighterModel = _model(&"hunter")
	for key: Dictionary in _keys()["keys"]:
		var f: int = int(key["f"])
		var want: Vector3 = KeyedPose.side_vec("right", key["arms"]["right"]["blade"]).normalized()
		var blade: Vector3 = _bone(_pose(model, f), "RightHand").basis.x.normalized()
		assert_gt(blade.dot(want), 0.97, "the blade at frame %d" % f)


func test_the_press_is_the_lowest_point() -> void:
	var model: FighterModel = _model(&"hunter")
	var lowest: int = -1
	var low: float = INF
	for f: int in 27:
		var y: float = _bone(_pose(model, f), "Hips").origin.y
		if y < low:
			low = y
			lowest = f
	assert_between(lowest, 10, 16, "the hips bottom out in the held press")


## Poses `model` with clip `clip` at rules frame `f`.
func _pose_clip(model: FighterModel, clip: StringName, f: int) -> Skeleton3D:
	model.animation_player.play(KeyedClips.anim_name(clip), 0.0)
	model.animation_player.seek(float(f) / float(SimConst.FPS), true)
	return model.skeleton


## Where the right hand's held blade tip is (FighterRig's grip: the blade
## along the hand's X axis, the grip a little past the wrist), for a blade
## `length` m long (0: the weapon's own).
func _tip(sk: Skeleton3D, weapon: StringName, length: float = 0.0) -> Vector3:
	var hand: Transform3D = _bone(sk, "RightHand")
	if length <= 0.0:
		length = WeaponLook.blade_segment(autofree(WeaponLook.load_id(weapon).instantiate()))[1].length()
	return hand.origin + hand.basis.x.normalized() * (length + 0.07)


func test_the_library_holds_the_thrusters_pin_fitted_to_the_stomps_stun() -> void:
	var lib: AnimationLibrary = KeyedClips.load_library()
	assert_true(lib.has_animation(KeyedClips.PINNED))
	assert_almost_eq(lib.get_animation(KeyedClips.PINNED).length * SimConst.FPS, float(ProtectedTimings.today().stomp_stun), 0.001, "built for today's 70-frame stun (family 6 re-keys it to the retuned 90)")


## The Katana blade the stomp and the pin were keyed for (m, the habaki's
## end to the tip). The 1.3 m blade (KE task 2) dips below the floor in
## both; on the owner's word (Oct 7) that's recorded for their re-key, not
## fixed, so the test holds the clips to the blade they were keyed for and
## prints the 1.3 m blade's worst.
const KEYED_KATANA_BLADE: float = 0.69


func test_the_held_blades_stay_above_the_floor() -> void:
	var model: FighterModel = _model(&"hunter")
	var worst: Array = [["the stomper's", 0.0, -1], ["the thruster's", 0.0, -1]]
	for f: int in 27:
		var sk: Skeleton3D = _pose_clip(model, KeyedClips.STOMP, f)
		assert_gt(_tip(sk, &"katana", KEYED_KATANA_BLADE).y, 0.0, "the stomper's blade at frame %d" % f)
		var y: float = _tip(sk, &"katana").y
		if y < worst[0][1]:
			worst[0] = [worst[0][0], y, f]
	for f: int in 71:
		if KeyedClips.pin_weight(float(f)) > 0.0:
			continue  # pinned to the floor by the view
		var sk: Skeleton3D = _pose_clip(model, KeyedClips.PINNED, f)
		assert_gt(_tip(sk, &"katana", KEYED_KATANA_BLADE).y, 0.0, "the thruster's blade at frame %d" % f)
		var y: float = _tip(sk, &"katana").y
		if y < worst[1][1]:
			worst[1] = [worst[1][0], y, f]
	for w: Array in worst:
		if w[2] >= 0:
			gut.p("the 1.3 m blade: %s %.1f cm below the floor at frame %d, for the re-key" % [w[0], -100.0 * w[1], w[2]])


func test_the_thruster_is_yanked_down_then_flings_the_weapon_up() -> void:
	var model: FighterModel = _model(&"hunter")
	for f: int in [8, 12, 18]:
		assert_lt(_bone(_pose_clip(model, KeyedClips.PINNED, f), "RightHand").origin.y, 0.6, "pinned: the hands down at the blade at frame %d" % f)
	assert_gt(_bone(_pose_clip(model, KeyedClips.PINNED, 24), "RightHand").origin.y, 1.1, "wrenched free: the weapon flung up")
	var bent: float = _bone(_pose_clip(model, KeyedClips.PINNED, 12), "Head").origin.y
	assert_lt(bent, _bone(_pose_clip(model, KeyedClips.PINNED, 42), "Head").origin.y - 0.2, "bent over the pin, lower than in the daze")


func test_the_pin_distances_fit_the_blades_between_the_hands_and_the_foot() -> void:
	# at the stomp's pin distance, from the thruster's held grip to the
	# stomper's foot is about the blade's length (KeyedClips.STOMP_FOOT)
	var model: FighterModel = _model(&"hunter")
	var sk: Skeleton3D = _pose_clip(model, KeyedClips.PINNED, 12)
	var grip: Vector3 = _bone(sk, "RightHand").origin
	for weapon: StringName in [&"katana", &"greatsword", &"daggers"]:
		var length: float = WeaponLook.blade_segment(autofree(WeaponLook.load_id(weapon).instantiate()))[1].length()
		var foot: Vector3 = Vector3(-KeyedClips.STOMP_FOOT.x, KeyedClips.STOMP_FOOT.y, SimConst.STOMP_PIN_DIST[weapon] - KeyedClips.STOMP_FOOT.z)
		var gap: float = grip.distance_to(foot) - length
		assert_between(gap, -0.15, 0.4 if weapon == &"daggers" else 0.15, "%s: the blade spans the grip to the foot (%.2f m over)" % [weapon, gap])
