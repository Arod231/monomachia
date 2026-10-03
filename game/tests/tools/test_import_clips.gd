extends GutTest
## The Iglesias clip import tool (tools/import_clips.gd). The track surgery is
## tested on committed CC0 clips, so it runs everywhere. The tests marked
## local-only need the packs (.assets-src-path) or an import already run
## (`node scripts/godot.mjs clips`), and skip themselves with a message
## without them, as on CI.

const ImportClips := preload("res://tools/import_clips.gd")
const BoneMapTool := preload("res://tools/build_iglesias_bone_map.gd")
const UAL: AnimationLibrary = preload("res://assets/quaternius/animations/ual_library.res")


func _hunter() -> FighterModel:
	var model: FighterModel = (load("res://fighters/hunter/hunter.tscn") as PackedScene).instantiate()
	model.autoplay_idle = false
	add_child_autofree(model)
	return model


func _bone_positions(model: FighterModel) -> Dictionary[String, Vector3]:
	var out: Dictionary[String, Vector3] = {}
	var sk: Skeleton3D = model.skeleton
	for i: int in sk.get_bone_count():
		out[sk.get_bone_name(i)] = sk.get_bone_global_pose(i).origin
	return out


func test_strip_keeps_only_bone_rotations_and_the_hips_travel() -> void:
	var anim: Animation = Animation.new()
	var kept: Array[String] = []
	for spec: Array in [
		["%GeneralSkeleton:Root", Animation.TYPE_POSITION_3D], ["%GeneralSkeleton:Root", Animation.TYPE_ROTATION_3D],
		["%GeneralSkeleton:Hips", Animation.TYPE_POSITION_3D], ["%GeneralSkeleton:Hips", Animation.TYPE_ROTATION_3D],
		["%GeneralSkeleton:LeftHand", Animation.TYPE_SCALE_3D], ["%GeneralSkeleton:LeftHand", Animation.TYPE_POSITION_3D],
		["%GeneralSkeleton:LeftHand", Animation.TYPE_ROTATION_3D], ["%GeneralSkeleton:B-jaw", Animation.TYPE_ROTATION_3D],
		["Other:Hips", Animation.TYPE_ROTATION_3D],
	]:
		var t: int = anim.add_track(spec[1])
		anim.track_set_path(t, NodePath(spec[0]))
	ImportClips.strip(anim)
	for t: int in anim.get_track_count():
		kept.append("%s/%d" % [anim.track_get_path(t), anim.track_get_type(t)])
	assert_eq(kept, [
		"%%GeneralSkeleton:Hips/%d" % Animation.TYPE_POSITION_3D,
		"%%GeneralSkeleton:Hips/%d" % Animation.TYPE_ROTATION_3D,
		"%%GeneralSkeleton:LeftHand/%d" % Animation.TYPE_ROTATION_3D,
	] as Array[String])


func test_the_hips_travel_scales_from_its_rest() -> void:
	var anim: Animation = Animation.new()
	var t: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t, ^"%GeneralSkeleton:Hips")
	anim.position_track_insert_key(t, 0.0, Vector3(0.0, 1.0, 0.02))
	anim.position_track_insert_key(t, 0.5, Vector3(0.1, 0.8, 0.12))
	ImportClips.scale_hips(anim, Vector3(0.0, 1.0, 0.02), 1.5)
	assert_almost_eq(anim.track_get_key_value(t, 0), Vector3(0.0, 1.0, 0.02), Vector3.ONE * 1e-6, "rest stays")
	assert_almost_eq(anim.track_get_key_value(t, 1), Vector3(0.15, 0.7, 0.17), Vector3.ONE * 1e-6, "travel x1.5")


func test_a_mirrored_clip_poses_the_body_as_its_reflection() -> void:
	var model: FighterModel = _hunter()
	var original: Animation = UAL.get_animation(&"Sword_Regular_A")
	var mirrored: Animation = original.duplicate(true)
	ImportClips.mirror(mirrored)
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation(&"a", original)
	lib.add_animation(&"m", mirrored)
	model.animation_player.add_animation_library(&"test", lib)
	for time: float in [0.2, 0.5, 0.8]:
		model.animation_player.play(&"test/a", 0.0)
		model.animation_player.seek(time, true)
		var a: Dictionary[String, Vector3] = _bone_positions(model)
		model.animation_player.play(&"test/m", 0.0)
		model.animation_player.seek(time, true)
		var m: Dictionary[String, Vector3] = _bone_positions(model)
		var worst: float = 0.0
		var worst_bone: String = ""
		for bone: String in a:
			var other: String = bone
			if bone.begins_with("Left"):
				other = "Right" + bone.substr(4)
			elif bone.begins_with("Right"):
				other = "Left" + bone.substr(5)
			elif bone.ends_with("_l"):
				other = bone.trim_suffix("_l") + "_r"
			elif bone.ends_with("_r"):
				other = bone.trim_suffix("_r") + "_l"
			if not m.has(other):
				continue
			var p: Vector3 = a[bone]
			var d: float = m[other].distance_to(Vector3(-p.x, p.y, p.z))
			if d > worst:
				worst = d
				worst_bone = bone
		assert_lt(worst, 0.015, "at %.1f s every bone lands on its mirror image (worst %s, %.1f cm)" % [time, worst_bone, worst * 100.0])


func test_mirroring_twice_gives_the_clip_back() -> void:
	var original: Animation = UAL.get_animation(&"Sword_Regular_A")
	var twice: Animation = original.duplicate(true)
	ImportClips.mirror(twice)
	ImportClips.mirror(twice)
	assert_eq(twice.get_track_count(), original.get_track_count())
	for t: int in original.get_track_count():
		assert_eq(twice.track_get_path(t), original.track_get_path(t))
		for i: int in original.track_get_key_count(t):
			assert_eq(twice.track_get_key_value(t, i), original.track_get_key_value(t, i))


func test_staged_names_keep_only_safe_characters() -> void:
	var clip: ClipManifest.Clip = ClipManifest.Clip.new()
	clip.source = "Roll01 [RM]"
	assert_eq(ImportClips.staged_path(&"HumanM", clip), "res://assets/kevin_iglesias/staging/HumanM@Roll01_RM.fbx")


# --- local-only ----------------------------------------------------------------

func test_local_the_packs_hold_every_manifest_clip() -> void:
	if not AssetSource.has_iglesias():
		pending("local-only: no Iglesias packs here (%s)" % AssetSource.SETTING_FILE)
		return
	var m: ClipManifest = ClipManifest.read()
	for set_name: StringName in m.sets:
		for clip: ClipManifest.Clip in m.clips.values():
			var path: String = ImportClips.source_path(m, set_name, clip)
			assert_true(FileAccess.file_exists(path), "found %s" % path)


func test_local_the_bone_map_maps_every_bone_the_tool_uses() -> void:
	var m: ClipManifest = ClipManifest.read()
	var path: String = ImportClips.staged_path(&"HumanM", m.clips.values()[0])
	if not ResourceLoader.exists(path):
		pending("local-only: no clips imported (node scripts/godot.mjs clips)")
		return
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for set_name: StringName in m.sets:
		for clip: ClipManifest.Clip in m.clips.values():
			var scene: Node = (load(ImportClips.staged_path(set_name, clip)) as PackedScene).instantiate()
			var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
			for i: int in sk.get_bone_count():
				var bone: StringName = StringName(sk.get_bone_name(i))
				assert_true(profile.find_bone(bone) >= 0 or BoneMapTool.UNMAPPED.has(bone),
					"%s@%s: %s is mapped or left out on purpose" % [set_name, clip.id, bone])
			scene.free()


func test_local_two_builds_write_identical_libraries() -> void:
	var m: ClipManifest = ClipManifest.read()
	if not ResourceLoader.exists(ImportClips.staged_path(&"HumanM", m.clips.values()[0])):
		pending("local-only: no clips imported (node scripts/godot.mjs clips)")
		return
	var path: String = "user://test_import_clips_determinism.res"
	for set_name: StringName in m.sets:
		ResourceSaver.save(ImportClips.build_set(m, set_name), path)
		var first: PackedByteArray = FileAccess.get_file_as_bytes(path)
		ResourceSaver.save(ImportClips.build_set(m, set_name), path)
		assert_eq(FileAccess.get_file_as_bytes(path), first, "%s builds the same twice" % set_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_local_the_libraries_hold_the_manifest() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var m: ClipManifest = ClipManifest.read()
	for set_name: StringName in ClipLibraries.SETS:
		var lib: AnimationLibrary = ClipLibraries.load_set(set_name)
		var names: PackedStringArray = []
		for n: StringName in lib.get_animation_list():
			names.append(String(n))
		names.sort()
		var ids: PackedStringArray = []
		for id: StringName in m.ids():
			ids.append(String(id))
		ids.sort()
		assert_eq(names, ids, "%s holds exactly the manifest's clips" % set_name)
		for clip: ClipManifest.Clip in m.clips.values():
			if not lib.has_animation(clip.id):
				continue
			var anim: Animation = lib.get_animation(clip.id)
			assert_eq(anim.loop_mode, Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE, "%s loop" % clip.id)
			assert_lte(clip.markers["settle"], roundi(anim.length * ClipManifest.SOURCE_FPS), "%s settles inside the clip" % clip.id)
			assert_eq(anim.find_track(^"%GeneralSkeleton:Root", Animation.TYPE_POSITION_3D), -1, "%s has no root travel" % clip.id)


func test_local_the_smoke_run_plays_every_clip() -> void:
	var line: String = SmokeRun.check_clips(self)
	if not ClipLibraries.available():
		assert_string_contains(line, "not in this build")
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	assert_string_contains(line, "each played")
	assert_engine_error_count(0, "every clip moves the body")
