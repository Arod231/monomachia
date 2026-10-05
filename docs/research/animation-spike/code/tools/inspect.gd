extends SceneTree
func _p(n: Node, d: int) -> void:
	var extra := ""
	if n is Skeleton3D:
		extra = " bones=%d" % n.get_bone_count()
	if n is MeshInstance3D:
		extra = " skin=%s skel=%s surf=%d" % [n.skin != null, n.skeleton, n.mesh.get_surface_count()]
	if n is AnimationPlayer:
		extra = " anims=%s" % [n.get_animation_list().size()]
	print("  ".repeat(d), n.name, " <", n.get_class(), ">", extra, " xf=", (n as Node3D).transform if n is Node3D else "")
	for c in n.get_children():
		_p(c, d + 1)
func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		print("=== ", path)
		var s: Node = (load(path) as PackedScene).instantiate()
		_p(s, 0)
		var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
		for b in ["root", "Root", "pelvis", "Hips", "spine_03", "UpperChest", "upperarm_r", "RightUpperArm", "lowerarm_r", "RightLowerArm", "hand_r", "RightHand", "hand_l", "LeftHand", "Head", "thigh_r", "RightUpperLeg", "foot_r", "RightFoot"]:
			var i := sk.find_bone(b)
			if i >= 0:
				print("  ", b, " rest=", sk.get_bone_rest(i), " global=", sk.get_bone_global_rest(i))
		var ap: AnimationPlayer = s.find_child("AnimationPlayer", true, false)
		if ap:
			print("  anims: ", ap.get_animation_list())
			if ap.has_animation("Idle"):
				var a := ap.get_animation("Idle")
				for t in min(a.get_track_count(), 8):
					print("   track ", a.track_get_path(t), " type ", a.track_get_type(t))
		s.free()
	quit(0)
