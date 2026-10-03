extends SceneTree
# Grip tuning: close-ups of both hands on the katana for several roll (gamma) / diagonal (beta) values.
const Fighter = preload("res://src/fighter.gd")
const ST = preload("res://src/stage.gd")
const OUT := "<scratch>/spike-anim/shots/"
const DT := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()   # list of "gR,gL,beta" in degrees
	var world := Node3D.new()
	root.add_child(world)
	ST.neutral(world)
	var lab: Label = ST.label(world)
	lab.position = Vector2(305, 12)
	lab.add_theme_font_size_override("font_size", 26)
	var cam: Camera3D = ST.camera(world, Vector3(0, 1, 4), Vector3(0, 0.9, 0), 30)
	var f := Fighter.new()
	world.add_child(f)
	f.equip_katana()
	var guard_p := Vector3(-0.07, 1.07, 0.36)
	var guard_a := Vector3(0.13, 0.45, 0.88)
	var guard_e := Vector3(0, -1, 0)
	var imgs := []
	for combo in args:
		var v := (combo as String).split(",")
		f.rig.gamma = {"R": deg_to_rad(float(v[0])), "L": deg_to_rad(float(v[1]))}
		f.rig.beta = deg_to_rad(float(v[2]))
		for view in [[Vector3(-0.45, 1.3, 1.15), "front-right"], [Vector3(0.7, 1.25, 0.8), "front-left"], [Vector3(-0.1, 1.9, 0.5), "top"]]:
			cam.global_position = view[0]
			cam.look_at(Vector3(-0.07, 1.04, 0.3))
			lab.text = "gR %s gL %s beta %s  %s" % [v[0], v[1], v[2], view[1]]
			for i in 3:
				f.step_move(DT, Vector3.ZERO)
				f.set_weapon(guard_p, guard_a, guard_e)
				f.advance_anim(DT)
				if i < 2:
					await process_frame
			imgs.append(await ST.grab(self))
	ST.sheet(imgs, Rect2i(300, 0, 1000, 900), 3, 0.5, OUT + "dev_grip_sweep.png")
	quit(0)
