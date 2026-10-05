extends SceneTree
# Builds a BoneMap (SkeletonProfileHumanoid -> UE-style Quaternius UAL bone names) and saves it.
func _initialize() -> void:
	var prof := SkeletonProfileHumanoid.new()
	var bm := BoneMap.new()
	bm.profile = prof
	var m := {
		"Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02", "UpperChest": "spine_03",
		"Neck": "neck_01", "Head": "Head",
		"LeftUpperLeg": "thigh_l", "LeftLowerLeg": "calf_l", "LeftFoot": "foot_l", "LeftToes": "ball_l",
		"RightUpperLeg": "thigh_r", "RightLowerLeg": "calf_r", "RightFoot": "foot_r", "RightToes": "ball_r",
	}
	for side in [["Left", "l"], ["Right", "r"]]:
		var S: String = side[0]; var s: String = side[1]
		m[S + "Shoulder"] = "clavicle_" + s
		m[S + "UpperArm"] = "upperarm_" + s
		m[S + "LowerArm"] = "lowerarm_" + s
		m[S + "Hand"] = "hand_" + s
		m[S + "ThumbMetacarpal"] = "thumb_01_" + s
		m[S + "ThumbProximal"] = "thumb_02_" + s
		m[S + "ThumbDistal"] = "thumb_03_" + s
		for f in [["Index", "index"], ["Middle", "middle"], ["Ring", "ring"], ["Little", "pinky"]]:
			m[S + f[0] + "Proximal"] = f[1] + "_01_" + s
			m[S + f[0] + "Intermediate"] = f[1] + "_02_" + s
			m[S + f[0] + "Distal"] = f[1] + "_03_" + s
	var unmapped := []
	for i in prof.bone_size:
		var pn := prof.get_bone_name(i)
		if m.has(String(pn)):
			bm.set_skeleton_bone_name(pn, StringName(m[String(pn)]))
		else:
			unmapped.append(pn)
	print("PROFILE_BONES=", prof.bone_size, " mapped=", m.size(), " unmapped=", unmapped)
	var err := ResourceSaver.save(bm, "res://assets/bonemap.tres")
	print("SAVE_ERR=", err)
	quit(0)
