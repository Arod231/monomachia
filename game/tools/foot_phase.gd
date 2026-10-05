extends SceneTree
## Prints the gait of every locomotion clip on every fighter (FootPhase):
## the way and ground speed each clip travels, its stride, where in its cycle
## each foot is at mid-stance and where each comes down: the packs' clips
## when they are there, else the CC0 fallback's (Locomotion's clip table).
##
## Run: node scripts/godot.mjs script res://tools/foot_phase.gd [-- --trace=<clip>]
## --trace= also prints the feet through that clip's cycle on each fighter
## (height and how far forward, in centimetres).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var trace: StringName = &""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--trace="):
			trace = StringName(a.trim_prefix("--trace="))
	for id: StringName in FighterLook.IDS:
		var model: FighterModel = FighterLook.instantiate_fighter(id)
		model.autoplay_idle = false
		root.add_child(model)
		await process_frame
		var loco: Locomotion = Locomotion.new(model, id)
		print("%s (%s):" % [model.look.display_name, id])
		for gait: StringName in Locomotion.GAITS:
			for clip: String in loco.clips[gait]:
				if clip != "":
					print("  ", loco.gaits[clip])
		if trace != &"":
			_trace(model, trace)
		model.free()
	quit(0)


func _trace(model: FighterModel, clip: StringName) -> void:
	var ap: AnimationPlayer = model.animation_player
	var sk: Skeleton3D = model.skeleton
	var anim_name: String = String(clip) if String(clip).contains("/") else String(FighterModel.LIBRARY) + "/" + String(clip)
	var anim: Animation = ap.get_animation(anim_name)
	ap.play(anim_name, 0.0)
	print("  %s: phase, left foot y z, right foot y z, hips y (cm)" % clip)
	for i: int in 40:
		ap.seek(anim.length * i / 40.0, true)
		var l: Vector3 = sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin * 100.0
		var r: Vector3 = sk.get_bone_global_pose(sk.find_bone("RightFoot")).origin * 100.0
		var h: Vector3 = sk.get_bone_global_pose(sk.find_bone("Hips")).origin * 100.0
		print("    %.3f  L %5.1f %6.1f   R %5.1f %6.1f   hips %5.1f" % [i / 40.0, l.y, l.z, r.y, r.z, h.y])
