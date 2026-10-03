extends SceneTree
const FB = preload("res://src/fighter_builder.gd")
func _initialize() -> void:
	var f: Node3D = FB.build("")
	var sk: Skeleton3D = f.find_child("GeneralSkeleton", true, false)
	for b in ["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "RightMiddleProximal", "RightIndexProximal", "RightLittleProximal", "RightIndexIntermediate", "RightIndexDistal", "RightThumbMetacarpal", "RightThumbProximal", "RightThumbDistal", "LeftHand", "LeftMiddleProximal", "LeftThumbMetacarpal", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes", "LeftFoot", "LeftToes", "Spine", "Chest", "UpperChest", "Neck", "Head"]:
		var i := sk.find_bone(b)
		print(b, " id=", i, " parent=", sk.get_bone_name(sk.get_bone_parent(i)), " g=", sk.get_bone_global_rest(i))
	var out := ""
	for i in sk.get_bone_count():
		out += sk.get_bone_name(i) + ","
	print(out)
	f.free()
	quit(0)
