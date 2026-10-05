extends SceneTree
## Writes the BoneMap that retargets Kevin Iglesias's HumanM and HumanF clips
## (his `B-` rig) to Godot's humanoid profile (SkeletonProfileHumanoid), so
## they play on the Quaternius fighters the way the UAL clips do through
## ual_bone_map.tres. The import tool points each converted clip's
## Skeleton3D at it.
##
## Run: node scripts/godot.mjs script res://tools/build_iglesias_bone_map.gd
##
## The rig has 55 bones (56 in the clips, which add B-spineProxy). 52 map to
## the profile. Left unmapped, so the importer drops their tracks:
## - B-handProp.L/R, the prop sockets;
## - B-jaw;
## - B-spineProxy, a helper on B-root that drives nothing.
## The rig has no upper chest: B-chest carries the neck and the shoulders, so
## it maps to Chest and the profile's UpperChest stays unmapped (it holds its
## rest pose on the Quaternius skeleton). The profile's eyes have no source
## bone. The map is ours; no file from the packs, and no clip converted from
## one, is ever committed (docs/specs/authored-animation.md, Licence). See
## docs/research/retarget-prototype.md for how it was checked.

const OUT_PATH: String = "res://assets/kevin_iglesias/iglesias_bone_map.tres"
## The rig's bones left unmapped on purpose (see above).
const UNMAPPED: Array[StringName] = [&"B-handProp.L", &"B-handProp.R", &"B-jaw", &"B-spineProxy"]


## Profile bone name -> Iglesias bone name.
static func mapping() -> Dictionary[StringName, StringName]:
	var m: Dictionary[StringName, StringName] = {
		&"Root": &"B-root", &"Hips": &"B-hips",
		&"Spine": &"B-spine", &"Chest": &"B-chest",
		&"Neck": &"B-neck", &"Head": &"B-head",
	}
	for side: Array in [["Left", "L"], ["Right", "R"]]:
		var p: String = side[0]
		var s: String = "." + side[1]
		m[StringName(p + "Shoulder")] = StringName("B-shoulder" + s)
		m[StringName(p + "UpperArm")] = StringName("B-upperArm" + s)
		m[StringName(p + "LowerArm")] = StringName("B-forearm" + s)
		m[StringName(p + "Hand")] = StringName("B-hand" + s)
		m[StringName(p + "ThumbMetacarpal")] = StringName("B-thumb01" + s)
		m[StringName(p + "ThumbProximal")] = StringName("B-thumb02" + s)
		m[StringName(p + "ThumbDistal")] = StringName("B-thumb03" + s)
		for finger: Array in [["Index", "indexFinger"], ["Middle", "middleFinger"], ["Ring", "ringFinger"], ["Little", "pinky"]]:
			m[StringName(p + finger[0] + "Proximal")] = StringName("B-" + finger[1] + "01" + s)
			m[StringName(p + finger[0] + "Intermediate")] = StringName("B-" + finger[1] + "02" + s)
			m[StringName(p + finger[0] + "Distal")] = StringName("B-" + finger[1] + "03" + s)
		m[StringName(p + "UpperLeg")] = StringName("B-thigh" + s)
		m[StringName(p + "LowerLeg")] = StringName("B-shin" + s)
		m[StringName(p + "Foot")] = StringName("B-foot" + s)
		m[StringName(p + "Toes")] = StringName("B-toe" + s)
	return m


func _initialize() -> void:
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	var bone_map: BoneMap = BoneMap.new()
	bone_map.profile = profile
	var m: Dictionary[StringName, StringName] = mapping()
	var unmapped: Array[StringName] = []
	for i: int in profile.bone_size:
		var profile_bone: StringName = profile.get_bone_name(i)
		if m.has(profile_bone):
			bone_map.set_skeleton_bone_name(profile_bone, m[profile_bone])
		else:
			unmapped.append(profile_bone)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var err: Error = ResourceSaver.save(bone_map, OUT_PATH)
	if err != OK:
		printerr("build_iglesias_bone_map: cannot save %s (%s)" % [OUT_PATH, error_string(err)])
		quit(1)
		return
	print("build_iglesias_bone_map: %d of %d profile bones mapped; unmapped %s; saved %s" % [m.size(), profile.bone_size, unmapped, OUT_PATH])
	quit(0)
