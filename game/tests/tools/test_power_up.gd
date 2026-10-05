extends GutTest
## The recall's hand-keyed power-up (KeyedClips.POWER_UP, authored-animation
## task 30b): committed, built from its key file, fitted to the recall, the
## feet planted wide throughout, and at the burst the head thrown back and
## the fists low at the sides, on both fighters.

const BuildKeyedClips := preload("res://tools/build_keyed_clips.gd")
const KEYS: String = "res://assets/authored/keys/power_up.json"


func _model(id: StringName) -> FighterModel:
	var model: FighterModel = FighterLook.instantiate_fighter(id)
	model.autoplay_idle = false
	add_child_autofree(model)
	model.animation_player.add_animation_library(KeyedClips.LIBRARY, KeyedClips.load_library())
	return model


func _keys() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(KEYS))


## Poses `model` with the power-up at rules frame `f`.
func _pose(model: FighterModel, f: int) -> Skeleton3D:
	model.animation_player.play(KeyedClips.anim_name(KeyedClips.POWER_UP), 0.0)
	model.animation_player.seek(float(f) / float(SimConst.FPS), true)
	return model.skeleton


func _bone(sk: Skeleton3D, bone: String) -> Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(bone))


func test_the_library_holds_it_fitted_to_the_recall() -> void:
	var lib: AnimationLibrary = KeyedClips.load_library()
	assert_true(lib.has_animation(KeyedClips.POWER_UP))
	var anim: Animation = lib.get_animation(KeyedClips.POWER_UP)
	assert_almost_eq(anim.length * SimConst.FPS, float(SimConst.RECALL_FRAMES), 0.001, "the recall's 26 frames")
	assert_eq(anim.loop_mode, Animation.LOOP_NONE)
	assert_eq(BuildKeyedClips.check(_keys()), "", "the key file is well formed")
	assert_true((_keys()["keys"] as Array).any(func(k: Dictionary) -> bool: return int(k["f"]) == SimConst.RECALL_BURST_FRAME), "a key on the burst")


func test_the_committed_library_is_built_from_the_key_file() -> void:
	var model: FighterModel = _model(&"hunter")
	var data: Dictionary = _keys()
	var fresh: Animation = KeyedPose.build(data, model.skeleton, FighterModel.ANIMATION_LIBRARY.get_animation(StringName(data["base"])))
	var committed: Animation = KeyedClips.load_library().get_animation(KeyedClips.POWER_UP)
	assert_eq(committed.get_track_count(), fresh.get_track_count())
	for f: int in [0, 6, 12, 16, 21, 26]:
		var time: float = float(f) / float(SimConst.FPS)
		for t: int in fresh.get_track_count():
			var c: int = committed.find_track(fresh.track_get_path(t), fresh.track_get_type(t))
			if c < 0:
				fail_test("%s is missing from the committed clip" % fresh.track_get_path(t))
				continue
			if fresh.track_get_type(t) == Animation.TYPE_POSITION_3D:
				assert_lt(fresh.position_track_interpolate(t, time).distance_to(committed.position_track_interpolate(c, time)), 0.001)
			else:
				assert_gt(absf(fresh.rotation_track_interpolate(t, time).dot(committed.rotation_track_interpolate(c, time))), 0.9999)


func test_the_feet_stay_planted_wide_and_the_burst_throws_the_head_back() -> void:
	for id: StringName in FighterLook.IDS:
		var model: FighterModel = _model(id)
		var sk: Skeleton3D = _pose(model, 0)
		var feet: Dictionary[String, Vector3] = {}
		for side: String in ["Left", "Right"]:
			feet[side] = _bone(sk, side + "Foot").origin
		assert_gt(feet["Left"].distance_to(feet["Right"]), 0.45, "%s: planted wide" % id)
		var head0: Basis = _bone(sk, "Head").basis
		for f: int in range(0, SimConst.RECALL_FRAMES + 1, 2):
			_pose(model, f)
			for side: String in feet:
				var now: Vector3 = _bone(sk, side + "Foot").origin
				assert_lt(now.distance_to(feet[side]), 0.012, "%s frame %d: the %s foot stays put" % [id, f, side])
		_pose(model, SimConst.RECALL_BURST_FRAME)
		var ahead: Vector3 = _bone(sk, "Head").basis * head0.inverse() * Vector3.BACK
		assert_gt(ahead.y, 0.3, "%s: the head thrown back at the burst, looking up" % id)
		for side: String in ["Left", "Right"]:
			var wrist: Vector3 = _bone(sk, side + "Hand").origin
			assert_lt(wrist.y, 0.95, "%s: the %s fist low" % [id, side])
			assert_gt(absf(wrist.x), 0.25, "%s: the %s fist out at the side" % [id, side])
			assert_lt(wrist.z, 0.08, "%s: the %s fist not reaching forward" % [id, side])
