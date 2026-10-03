extends SceneTree
## Writes the BoneMap that retargets every Quaternius asset to Godot's humanoid
## profile (SkeletonProfileHumanoid). The .import files of the animation GLBs,
## the bodies, the outfit parts and the hair all point at it, so every clip
## plays on every body.
##
## Run: node scripts/godot.mjs script res://tools/build_bone_map.gd
##
## Quaternius uses the Unreal mannequin's 65 bone names. 53 of them map to the
## profile; the 12 finger and toe leaf bones stay unmapped, and the profile's
## Jaw, LeftEye and RightEye have no source bone.
## The editor's auto-mapper only runs in the editor UI, so the map is written
## here by name instead.

const OUT_PATH: String = "res://assets/quaternius/ual_bone_map.tres"


## Profile bone name -> Quaternius bone name.
static func mapping() -> Dictionary[StringName, StringName]:
	var m: Dictionary[StringName, StringName] = {
		&"Root": &"root", &"Hips": &"pelvis",
		&"Spine": &"spine_01", &"Chest": &"spine_02", &"UpperChest": &"spine_03",
		&"Neck": &"neck_01", &"Head": &"Head",
	}
	for side: Array in [["Left", "l"], ["Right", "r"]]:
		var p: String = side[0]
		var s: String = side[1]
		m[StringName(p + "Shoulder")] = StringName("clavicle_" + s)
		m[StringName(p + "UpperArm")] = StringName("upperarm_" + s)
		m[StringName(p + "LowerArm")] = StringName("lowerarm_" + s)
		m[StringName(p + "Hand")] = StringName("hand_" + s)
		m[StringName(p + "ThumbMetacarpal")] = StringName("thumb_01_" + s)
		m[StringName(p + "ThumbProximal")] = StringName("thumb_02_" + s)
		m[StringName(p + "ThumbDistal")] = StringName("thumb_03_" + s)
		for finger: Array in [["Index", "index"], ["Middle", "middle"], ["Ring", "ring"], ["Little", "pinky"]]:
			m[StringName(p + finger[0] + "Proximal")] = StringName(finger[1] + "_01_" + s)
			m[StringName(p + finger[0] + "Intermediate")] = StringName(finger[1] + "_02_" + s)
			m[StringName(p + finger[0] + "Distal")] = StringName(finger[1] + "_03_" + s)
		m[StringName(p + "UpperLeg")] = StringName("thigh_" + s)
		m[StringName(p + "LowerLeg")] = StringName("calf_" + s)
		m[StringName(p + "Foot")] = StringName("foot_" + s)
		m[StringName(p + "Toes")] = StringName("ball_" + s)
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
		printerr("build_bone_map: cannot save %s (%s)" % [OUT_PATH, error_string(err)])
		quit(1)
		return
	print("build_bone_map: %d of %d profile bones mapped; unmapped %s; saved %s" % [m.size(), profile.bone_size, unmapped, OUT_PATH])
	quit(0)
