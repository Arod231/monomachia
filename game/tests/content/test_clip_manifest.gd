extends GutTest
## The clip manifest and the Iglesias bone map: committed data that needs no
## packs, so these run everywhere (CI included).

const BoneMapTool := preload("res://tools/build_iglesias_bone_map.gd")
const BONE_MAP: String = "res://assets/kevin_iglesias/iglesias_bone_map.tres"


func test_the_manifest_reads_cleanly() -> void:
	var m: ClipManifest = ClipManifest.read()
	assert_eq(m.errors, PackedStringArray(), "no mistakes in the manifest")
	assert_false(m.clips.is_empty(), "it names clips")


func test_the_sets_are_the_two_fighters_sets() -> void:
	var m: ClipManifest = ClipManifest.read()
	assert_eq(m.sets, {&"HumanM": "Male", &"HumanF": "Female"} as Dictionary[StringName, String])
	for set_name: StringName in ClipLibraries.SETS:
		assert_true(m.sets.has(set_name), "the manifest has %s" % set_name)


func test_every_clip_has_its_four_markers_in_order() -> void:
	var m: ClipManifest = ClipManifest.read()
	for clip: ClipManifest.Clip in m.clips.values():
		var rules_length: int = clip.markers.keys().filter(func(k: String) -> bool: return ClipManifest.RULES_LENGTH_MARKERS.has(k)).size()
		assert_eq(clip.markers.size() - rules_length, 4, "%s has four markers" % clip.id)
		var last: int = -1
		for marker: String in ClipManifest.MARKERS:
			assert_true(clip.markers.has(marker), "%s has %s" % [clip.id, marker])
			assert_gte(clip.markers.get(marker, -1), last, "%s: %s comes no earlier than the one before" % [clip.id, marker])
			last = clip.markers.get(marker, last)


func test_every_clip_has_each_feet_contacts_in_order() -> void:
	# measured from the clips by tools/measure_feet.gd (milestone-1 task 14)
	var m: ClipManifest = ClipManifest.read()
	for clip: ClipManifest.Clip in m.clips.values():
		assert_eq(clip.foot_contacts.keys(), ["left", "right"], "%s has both feet's contacts" % clip.id)
		for side: String in clip.foot_contacts:
			var last: int = -1
			for span: Array in clip.foot_contacts[side]:
				assert_gt(int(span[0]), last, "%s %s: each contact after the one before" % [clip.id, side])
				assert_gte(int(span[1]), int(span[0]), "%s %s: lifts at or after it plants" % [clip.id, side])
				last = int(span[1])


func test_no_clip_of_todays_sets_a_rules_length_marker() -> void:
	# the draw, the pull-out, the paired stomp and leap and the finishers set
	# them, and none of those clips is keyed yet
	var m: ClipManifest = ClipManifest.read()
	for clip: ClipManifest.Clip in m.clips.values():
		for name: String in ClipManifest.RULES_LENGTH_MARKERS:
			assert_false(clip.markers.has(name), "%s has no %s marker" % [clip.id, name])


func test_rules_length_markers_and_foot_contacts_read() -> void:
	var path: String = "user://test_clip_manifest_new_markers.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sets": {"HumanM": "Male"}, "clips": {
		"Draw": {"pack": "P", "dir": "D", "source": "Draw", "groups": ["katana"],
			"markers": {"windup": 0, "contact": 9, "contact_end": 12, "settle": 20, "ready": 18},
			"foot_contacts": {"left": [[0, 20]], "right": [[0, 6], [11, 20]]}},
	}}))
	f.close()
	var m: ClipManifest = ClipManifest.read(path)
	assert_eq(m.errors, PackedStringArray())
	var c: ClipManifest.Clip = m.clips[&"Draw"]
	assert_eq(c.markers["ready"], 18)
	assert_eq(c.foot_contacts, {"left": [[0, 20]], "right": [[0, 6], [11, 20]]})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_an_exported_clip_reads_with_or_without_its_origin() -> void:
	var path: String = "user://test_clip_manifest_exported.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sets": {"HumanM": "Male"}, "clips": {
		"Finisher": {"export": "exports/clips/finisher.glb", "groups": ["katana"], "props": true,
			"markers": {"windup": 0, "contact": 9, "contact_end": 12, "settle": 20}},
		"Attack1H01_R": {"export": "exports/clips/attack1h01_r.glb", "pack": "P", "dir": "D", "source": "Attack1H01_R",
			"mirror": true, "groups": ["katana"], "markers": {"windup": 0, "contact": 9, "contact_end": 12, "settle": 20}},
		"Plain": {"pack": "P", "dir": "D", "source": "Plain", "groups": ["katana"],
			"markers": {"windup": 0, "contact": 9, "contact_end": 12, "settle": 20}},
	}}))
	f.close()
	var m: ClipManifest = ClipManifest.read(path)
	assert_eq(m.errors, PackedStringArray())
	var fresh: ClipManifest.Clip = m.clips[&"Finisher"]
	assert_true(fresh.exported(), "named by its export")
	assert_eq(fresh.export_path, "exports/clips/finisher.glb")
	assert_false(fresh.has_origin(), "keyed from scratch: no pack clip behind it")
	assert_true(fresh.props, "keeps its prop bones")
	var replaced: ClipManifest.Clip = m.clips[&"Attack1H01_R"]
	assert_true(replaced.exported())
	assert_true(replaced.has_origin(), "the pack clip it replaces stays its origin")
	assert_eq([replaced.pack, replaced.dir, replaced.source], ["P", "D", "Attack1H01_R"])
	assert_true(replaced.mirror, "mirrored like a pack clip")
	assert_false(replaced.props, "no props unless asked")
	assert_false(m.clips[&"Plain"].exported(), "a pack clip")
	assert_eq(m.sourced().size(), 3, "exported clips have a file of their own")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_every_clip_names_its_file() -> void:
	var m: ClipManifest = ClipManifest.read()
	for clip: ClipManifest.Clip in m.sourced():
		if clip.exported():
			assert_true(clip.export_path.begins_with("exports/") and clip.export_path.ends_with(".glb"), "%s: %s" % [clip.id, clip.export_path])
			continue
		var f: String = clip.file(&"HumanM", "Male")
		# a shared clip's files (the masked poses) sit in one folder for both sets
		var folder: String = clip.dir if clip.shared else "Male/"
		assert_true(f.begins_with(clip.pack + "/Animations/" + folder), "%s: %s" % [clip.id, f])
		assert_true(f.ends_with("HumanM@%s.fbx" % clip.source), "%s: %s" % [clip.id, f])


func test_composed_clips_are_built_from_two_clips_with_files() -> void:
	var m: ClipManifest = ClipManifest.read()
	var composed: Array[ClipManifest.Clip] = []
	for clip: ClipManifest.Clip in m.clips.values():
		if clip.composed():
			composed.append(clip)
			assert_false(m.sourced().has(clip), "%s has no file of its own" % clip.id)
			assert_false(m.clips[clip.upper].composed(), "%s: its upper clip has a file" % clip.id)
			assert_false(m.clips[clip.legs].composed(), "%s: its legs clip has a file" % clip.id)
	assert_false(composed.is_empty(), "Slide Slash's cut over the slide (task 22)")
	assert_eq(m.sourced().size() + composed.size(), m.clips.size())


func test_a_bad_manifest_is_reported() -> void:
	var path: String = "user://test_clip_manifest_bad.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sets": {"HumanM": "Male"}, "clips": {
		"A": {"pack": "P", "dir": "D", "source": "A", "groups": ["katana"], "markers": {"windup": 0, "contact": 9, "contact_end": 4, "settle": 20}},
		"B": {"pack": "P", "dir": "D", "source": "B", "groups": ["swords"], "markers": {"windup": 0, "contact": 1.5, "settle": 20}},
		"C": {"dir": "D", "source": "C", "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3}},
		"E": {"compose": {"upper": "A", "upper_from": 1.5, "legs": "F"}, "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3}},
		"G": {"compose": {"upper": "A"}, "mirror": true, "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3}},
		"H": {"pack": "P", "dir": "D", "source": "H", "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3, "kill": 2.5},
			"foot_contacts": {"left": [[4, 2]], "right": [[0, 3]]}},
		"I": {"pack": "P", "dir": "D", "source": "I", "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3},
			"foot_contacts": {"left": [[0, 3]]}},
		"J": {"export": "C:/clips/j.glb", "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3}},
		"K": {"export": "exports/clips/k.glb", "pack": "P", "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3}},
		"L": {"pack": "P", "dir": "D", "source": "L", "props": "yes", "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3}},
		"M": {"compose": {"upper": "A", "legs": "H"}, "export": "exports/clips/m.glb", "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3}},
		"N": {"export": "exports/../n.glb", "groups": ["katana"], "markers": {"windup": 0, "contact": 1, "contact_end": 2, "settle": 3}},
	}}))
	f.close()
	var m: ClipManifest = ClipManifest.read(path)
	var text: String = "\n".join(m.errors)
	assert_string_contains(text, "A: marker contact_end comes before")
	assert_string_contains(text, "B: marker contact missing or not a whole frame")
	assert_string_contains(text, "B: marker contact_end missing")
	assert_string_contains(text, "C: no pack")
	assert_string_contains(text, "B: unknown group swords")
	assert_string_contains(text, "C: no groups")
	assert_string_contains(text, "E: upper_from is not a whole source frame")
	assert_string_contains(text, "E: composed from F, which is not a clip with a file")
	assert_string_contains(text, "G: a composed clip names its upper and legs clips")
	assert_string_contains(text, "G: a composed clip isn't mirrored")
	assert_string_contains(text, "H: marker kill is not a whole frame")
	assert_string_contains(text, "H: foot_contacts left must be [plant, lift] source frames, in order, each lift at or after its plant")
	assert_string_contains(text, "I: foot_contacts gives left and right")
	assert_false(text.contains("E: no pack"), "a composed clip has no file")
	assert_string_contains(text, "J: export must be a .glb under the asset repository's exports/")
	assert_string_contains(text, "N: export must be a .glb under the asset repository's exports/")
	assert_string_contains(text, "K: an exported clip names all of pack, dir and source as its origin, or none")
	assert_string_contains(text, "L: props is true or false")
	assert_string_contains(text, "M: a composed clip has no export")
	assert_false(text.contains("K: no dir"), "an exported clip's origin is optional")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_bone_map_is_the_tools_mapping() -> void:
	var bone_map: BoneMap = load(BONE_MAP)
	var mapping: Dictionary[StringName, StringName] = BoneMapTool.mapping()
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for i: int in profile.bone_size:
		var bone: StringName = profile.get_bone_name(i)
		assert_eq(bone_map.get_skeleton_bone_name(bone), mapping.get(bone, &""), "%s maps as the tool says" % bone)


func test_every_rig_bone_is_mapped_once_or_left_out_on_purpose() -> void:
	var mapping: Dictionary[StringName, StringName] = BoneMapTool.mapping()
	var seen: Dictionary[StringName, bool] = {}
	for rig_bone: StringName in mapping.values():
		assert_false(seen.has(rig_bone), "%s is mapped once" % rig_bone)
		assert_true(String(rig_bone).begins_with("B-"), "%s is a rig bone" % rig_bone)
		assert_false(BoneMapTool.UNMAPPED.has(rig_bone), "%s isn't also left out" % rig_bone)
		seen[rig_bone] = true
	# Kevin's clips carry 56 bones: 52 mapped, 4 left out.
	assert_eq(mapping.size() + BoneMapTool.UNMAPPED.size(), 56)
	# Only the profile's upper chest, eyes and jaw have no source bone.
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	var unmapped: Array[StringName] = []
	for i: int in profile.bone_size:
		if not mapping.has(profile.get_bone_name(i)):
			unmapped.append(profile.get_bone_name(i))
	assert_eq(unmapped, [&"UpperChest", &"LeftEye", &"RightEye", &"Jaw"] as Array[StringName])


func test_every_clip_is_on_a_catalogue_page_and_every_page_has_clips() -> void:
	var m: ClipManifest = ClipManifest.read()
	var seen: Dictionary[StringName, bool] = {}
	for group: StringName in ClipManifest.GROUPS:
		var ids: Array[StringName] = m.in_group(group)
		assert_false(ids.is_empty(), "the %s page has clips" % group)
		for id: StringName in ids:
			seen[id] = true
	assert_eq(seen.size(), m.clips.size(), "every clip is on a page")
