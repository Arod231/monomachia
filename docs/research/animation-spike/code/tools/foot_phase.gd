extends SceneTree
const FB = preload("res://src/fighter_builder.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var f: Node3D = FB.build("")
	root.add_child(f)
	var skel: Skeleton3D = f.find_child("GeneralSkeleton", true, false)
	var ap: AnimationPlayer = f.get_node("AnimationPlayer")
	var lf := skel.find_bone("LeftFoot"); var rf := skel.find_bone("RightFoot"); var hips := skel.find_bone("Hips")
	for clip in ["ual1/Walk", "ual1/Jog_Fwd", "ual1/Sprint", "ual1/Idle"]:
		ap.play(clip)
		var a := ap.get_animation(clip)
		var n := 60
		var best := -1e9; var best_t := 0.0
		var line := ""
		for i in n:
			var t := a.length * i / n
			ap.seek(t, true)
			var d := skel.get_bone_global_pose(lf).origin.z - skel.get_bone_global_pose(rf).origin.z
			if d > best:
				best = d; best_t = i / float(n)
			if i % 6 == 0:
				line += "%.2f " % d
		print(clip, " len=", a.length, " left-foot-forward-max at phase ", best_t, " (", best, ")  samples: ", line, " hipsY0=", skel.get_bone_global_pose(hips).origin.y)
	quit(0)
