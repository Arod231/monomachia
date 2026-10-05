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


## A clip keyed on 12 source frames: each [bone, type, Callable(k) -> value].
static func _clip(tracks: Array) -> Animation:
	var a: Animation = Animation.new()
	a.length = 11.0 / ClipManifest.SOURCE_FPS
	for spec: Array in tracks:
		var t: int = a.add_track(spec[1])
		a.track_set_path(t, NodePath("%GeneralSkeleton:" + spec[0]))
		for k: int in 12:
			a.track_insert_key(t, k / ClipManifest.SOURCE_FPS, (spec[2] as Callable).call(k))
	return a


func test_a_composed_clip_takes_the_upper_body_and_the_legs_from_each_clip() -> void:
	var R: int = Animation.TYPE_ROTATION_3D
	var P: int = Animation.TYPE_POSITION_3D
	var upper: Animation = _clip([
		["Hips", P, func(k: int) -> Vector3: return Vector3(0.0, 1.0, 0.0)],
		["Hips", R, func(k: int) -> Quaternion: return Quaternion(Vector3.UP, 0.3 + 0.05 * k) * Quaternion(Vector3.RIGHT, 0.1)],
		["Spine", R, func(k: int) -> Quaternion: return Quaternion(Vector3.RIGHT, 0.2) * Quaternion(Vector3.UP, 0.1)],
		["LeftHand", R, func(k: int) -> Quaternion: return Quaternion(Vector3.BACK, 0.05 * k)],
		["LeftUpperLeg", R, func(k: int) -> Quaternion: return Quaternion(Vector3.RIGHT, 0.4)],
	])
	var legs: Animation = _clip([
		["Hips", P, func(k: int) -> Vector3: return Vector3(0.0, 0.5, 0.01 * k)],
		["Hips", R, func(k: int) -> Quaternion: return Quaternion(Vector3.UP, -0.8) * Quaternion(Vector3.RIGHT, -0.3 - 0.02 * k)],
		["Spine", R, func(k: int) -> Quaternion: return Quaternion(Vector3.RIGHT, 0.5)],
		["LeftHand", R, func(k: int) -> Quaternion: return Quaternion(Vector3.BACK, 1.0)],
		["LeftUpperLeg", R, func(k: int) -> Quaternion: return Quaternion(Vector3.RIGHT, 1.2 - 0.02 * k)],
	])
	var c: Animation = ImportClips.compose(upper, legs, 2, 1)
	var fps: float = ClipManifest.SOURCE_FPS
	assert_almost_eq(c.length, 9.0 / fps, 1e-5, "as long as the upper clip runs on from its frame")
	var from: Array[String] = []
	for t: int in c.get_track_count():
		var path: NodePath = c.track_get_path(t)
		var bone: String = path.get_concatenated_subnames()
		var src: Animation = legs if Locomotion.is_leg_bone(bone) else upper
		from.append("%s/%d %s" % [bone, c.track_get_type(t), "legs" if src == legs else "upper"])
		if bone == "Spine":
			continue
		var st: int = src.find_track(path, c.track_get_type(t))
		for k: int in [0, 5, 9]:
			var at: float = (k + (1 if src == legs else 2)) / fps
			if c.track_get_type(t) == R:
				var got: Quaternion = c.rotation_track_interpolate(t, k / fps)
				var want: Quaternion = src.rotation_track_interpolate(st, at)
				assert_lt(Vector4(got.x - want.x, got.y - want.y, got.z - want.z, got.w - want.w).length(), 1e-5, "%s at frame %d" % [path, k])
			else:
				assert_almost_eq(c.position_track_interpolate(t, k / fps), src.position_track_interpolate(st, at), Vector3.ONE * 1e-5, "%s at frame %d" % [path, k])
	from.sort()
	assert_eq(from, ["Hips/1 legs", "Hips/2 legs", "LeftHand/2 upper", "LeftUpperLeg/2 legs", "Spine/2 upper"] as Array[String], "each bone from its clip")
	# the upper body stands as in its own clip, on the legs' hips
	var spine: int = c.find_track(^"%GeneralSkeleton:Spine", R)
	for k: int in [0, 4, 9]:
		var ha: Quaternion = upper.rotation_track_interpolate(1, (k + 2) / fps)
		var sa: Quaternion = upper.rotation_track_interpolate(2, (k + 2) / fps)
		var hs: Quaternion = legs.rotation_track_interpolate(1, (k + 1) / fps)
		var sc: Quaternion = c.rotation_track_interpolate(spine, k / fps)
		var got: Quaternion = hs * sc
		var want: Quaternion = ha * sa
		assert_lt(Vector4(got.x - want.x, got.y - want.y, got.z - want.z, got.w - want.w).length(), 1e-5, "frame %d: the chest as in the upper clip" % k)


func test_staged_names_keep_only_safe_characters() -> void:
	var clip: ClipManifest.Clip = ClipManifest.Clip.new()
	clip.source = "Roll01 [RM]"
	assert_eq(ImportClips.staged_path(&"HumanM", clip), "res://assets/kevin_iglesias/staging/HumanM@Roll01_RM.fbx")


func _prop_tracks(anim: Animation) -> Array[String]:
	var out: Array[String] = []
	for t: int in anim.get_track_count():
		if String(anim.track_get_path(t)).contains("Prop"):
			out.append("%s/%d" % [anim.track_get_path(t), anim.track_get_type(t)])
	return out


func _with_props() -> Animation:
	var anim: Animation = Animation.new()
	for spec: Array in [
		["%GeneralSkeleton:B-handProp.R", Animation.TYPE_ROTATION_3D, Quaternion(0.1, 0.2, 0.3, 0.9).normalized()],
		["%GeneralSkeleton:B-handProp.R", Animation.TYPE_POSITION_3D, Vector3(0.05, 0.02, 0.1)],
		["%GeneralSkeleton:B-handProp.R", Animation.TYPE_SCALE_3D, Vector3.ONE],
		["%GeneralSkeleton:LeftHand", Animation.TYPE_ROTATION_3D, Quaternion.IDENTITY],
	]:
		var t: int = anim.add_track(spec[1])
		anim.track_set_path(t, NodePath(spec[0]))
		anim.track_insert_key(t, 0.0, spec[2])
	return anim


func test_strip_keeps_the_prop_bones_only_for_a_clip_that_asks() -> void:
	var dropped: Animation = _with_props()
	ImportClips.strip(dropped)
	assert_eq(_prop_tracks(dropped), [] as Array[String], "dropped as today")
	var kept: Animation = _with_props()
	ImportClips.strip(kept, true)
	assert_eq(_prop_tracks(kept), [
		"%%GeneralSkeleton:B-handProp.R/%d" % Animation.TYPE_ROTATION_3D,
		"%%GeneralSkeleton:B-handProp.R/%d" % Animation.TYPE_POSITION_3D,
	] as Array[String], "the weapon's own motion: turn and travel, no scale")
	assert_eq(kept.get_track_count(), 3, "the hand stays too")


func test_mirroring_moves_a_prop_to_the_other_hand() -> void:
	var anim: Animation = _with_props()
	ImportClips.strip(anim, true)
	ImportClips.mirror(anim)
	assert_eq(_prop_tracks(anim), [
		"%%GeneralSkeleton:B-handProp.L/%d" % Animation.TYPE_ROTATION_3D,
		"%%GeneralSkeleton:B-handProp.L/%d" % Animation.TYPE_POSITION_3D,
	] as Array[String])
	var q: Quaternion = Quaternion(0.1, 0.2, 0.3, 0.9).normalized()
	assert_eq(anim.track_get_key_value(0, 0), Quaternion(q.x, -q.y, -q.z, q.w), "turned as its reflection")
	assert_eq(anim.track_get_key_value(1, 0), Vector3(-0.05, 0.02, 0.1), "moved to the other side")


func test_an_exported_clip_stages_by_its_id_from_the_asset_repository() -> void:
	var clip: ClipManifest.Clip = ClipManifest.Clip.new()
	clip.id = &"Attack1H01_R"
	clip.source = "Attack1H01_R"
	clip.pack = "Human Melee Animations"
	clip.export_path = "exports/clips/attack1h01_r.glb"
	assert_eq(ImportClips.staged_path(&"HumanF", clip), "res://assets/kevin_iglesias/staging/HumanF@Attack1H01_R.glb",
		"a GLB, by its id, the same file for every set")
	assert_eq(ImportClips.staged_path(&"HumanM", clip, "res://elsewhere"), "res://elsewhere/HumanM@Attack1H01_R.glb")
	var m: ClipManifest = ClipManifest.new()
	m.sets[&"HumanF"] = "Female"
	assert_eq(ImportClips.source_path(m, &"HumanF", clip), AssetSource.folder().path_join("exports/clips/attack1h01_r.glb"),
		"read from the asset repository, not the packs")


func test_the_import_settings_retarget_a_glb_at_its_armature() -> void:
	var fbx: String = ImportClips.import_settings("res://a.fbx")
	assert_string_contains(fbx, "\"PATH:Skeleton3D\": {")
	assert_string_contains(fbx, "\"retarget/remove_tracks/unmapped_bones\": true")
	assert_string_contains(fbx, "fbx/importer=0")
	var glb: String = ImportClips.import_settings("res://a.glb", "Rig/Skeleton3D", true)
	assert_string_contains(glb, "\"PATH:Rig/Skeleton3D\": {")
	assert_string_contains(glb, ImportClips.BONE_MAP)
	assert_string_contains(glb, "\"retarget/remove_tracks/unmapped_bones\": false", "props kept: the unmapped bones' tracks stay")
	assert_string_contains(glb, "animation/fps=30")
	assert_string_contains(glb, "gltf/naming_version")
	assert_false(glb.contains("fbx/"), "no FBX settings")


## A GLB holding only `json` as its JSON chunk.
func _glb(json: Dictionary) -> String:
	var path: String = "user://test_import_clips.glb"
	var text: PackedByteArray = JSON.stringify(json).to_utf8_buffer()
	while text.size() % 4 != 0:
		text.append(0x20)
	var out: StreamPeerBuffer = StreamPeerBuffer.new()
	out.put_u32(0x46546C67)
	out.put_u32(2)
	out.put_u32(12 + 8 + text.size())
	out.put_u32(text.size())
	out.put_u32(0x4E4F534A)
	out.put_data(text)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out.data_array)
	f.close()
	return path


func test_the_skeleton_is_found_under_the_armature_a_glb_names() -> void:
	var rig: String = _glb({"nodes": [{"name": "Hunter.Rig", "children": [1]}, {"name": "B-root", "children": [2]}, {"name": "B-hips"}],
		"skins": [{"joints": [1, 2]}]})
	assert_eq(ImportClips.glb_skeleton_path(rig), "Hunter_Rig/Skeleton3D", "the armature's name as Godot names its node")
	var bare: String = _glb({"nodes": [{"name": "B-root", "children": [1]}, {"name": "B-hips"}], "skins": [{"joints": [0, 1]}]})
	assert_eq(ImportClips.glb_skeleton_path(bare), "Skeleton3D", "joints at the top: the skeleton is at the top")
	var none: String = _glb({"nodes": [{"name": "Box"}]})
	assert_eq(ImportClips.glb_skeleton_path(none), "", "no skin, no skeleton")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(rig))


# --- local-only ----------------------------------------------------------------

func test_local_the_packs_hold_every_manifest_clip() -> void:
	if not AssetSource.has_iglesias():
		pending("local-only: no Iglesias packs here (%s)" % AssetSource.SETTING_FILE)
		return
	var m: ClipManifest = ClipManifest.read()
	for set_name: StringName in m.sets:
		for clip: ClipManifest.Clip in m.sourced():
			var path: String = ImportClips.source_path(m, set_name, clip)
			assert_true(FileAccess.file_exists(path), "found %s" % path)


func test_local_the_bone_map_maps_every_bone_the_tool_uses() -> void:
	var m: ClipManifest = ClipManifest.read()
	var path: String = ImportClips.staged_path(&"HumanM", m.sourced()[0])
	if not ResourceLoader.exists(path):
		pending("local-only: no clips imported (node scripts/godot.mjs clips)")
		return
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for set_name: StringName in m.sets:
		for clip: ClipManifest.Clip in m.sourced():
			var scene: Node = (load(ImportClips.staged_path(set_name, clip)) as PackedScene).instantiate()
			var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
			for i: int in sk.get_bone_count():
				var bone: StringName = StringName(sk.get_bone_name(i))
				assert_true(profile.find_bone(bone) >= 0 or BoneMapTool.UNMAPPED.has(bone),
					"%s@%s: %s is mapped or left out on purpose" % [set_name, clip.id, bone])
			scene.free()


func test_local_two_builds_write_identical_libraries() -> void:
	var m: ClipManifest = ClipManifest.read()
	if not ResourceLoader.exists(ImportClips.staged_path(&"HumanM", m.sourced()[0])):
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
