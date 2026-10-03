extends SceneTree
# Milestone 3: katana mid guard with both hands IK'd on the grip, stance legs IK'd.
const Fighter = preload("res://src/fighter.gd")
const ST = preload("res://src/stage.gd")
const OUT := "<scratch>/spike-anim/shots/"
const DT := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := "" if args.is_empty() else args[0]
	var world := Node3D.new()
	root.add_child(world)
	ST.neutral(world)
	var lab: Label = ST.label(world)
	var cam: Camera3D = ST.camera(world, Vector3(0, 1, 4), Vector3(0, 0.9, 0), 36)
	var f := Fighter.new()
	world.add_child(f)
	f.equip_katana()
	f.face(Vector3(0, 0, 1))
	var guard_p := Vector3(-0.07, 1.07, 0.36)
	var guard_a := Vector3(0.13, 0.45, 0.88)
	var guard_e := Vector3(0, -1, 0)
	for i in 30:
		f.step_move(DT, Vector3.ZERO)
		f.set_weapon(guard_p, guard_a, guard_e)
		f.advance_anim(DT)
		await process_frame
	print("IK: ", f.rig.debug_errors())
	lab.position = Vector2(505, 12)
	lab.add_theme_font_size_override("font_size", 22)
	var imgs := []
	var views := [[Vector3(0.3, 1.25, 3.4), Vector3(0, 0.95, 0.1), "guard front", 36.0],
		[Vector3(-2.3, 1.3, 2.6), Vector3(0, 0.95, 0.1), "guard 3/4 (right side)", 36.0],
		[Vector3(2.6, 1.3, 2.2), Vector3(0, 0.95, 0.1), "guard 3/4 (left side)", 36.0],
		[Vector3(-3.4, 1.2, 0.2), Vector3(0, 0.95, 0.1), "guard side", 36.0]]
	for v in views:
		cam.global_position = v[0]
		cam.look_at(v[1])
		cam.fov = v[3]
		lab.text = v[2]
		f.set_weapon(guard_p, guard_a, guard_e)
		f.step_move(DT, Vector3.ZERO)
		f.advance_anim(DT)
		imgs.append(await ST.grab(self))
	lab.position = Vector2(505, 12)
	ST.sheet(imgs, Rect2i(500, 0, 600, 900), 4, 0.8, OUT + "m3_guard%s.png" % tag)
	# hands close-up
	lab.position = Vector2(305, 12)
	var close := []
	for v in [[Vector3(-0.35, 1.25, 1.2), "grip close (front-right)"], [Vector3(0.55, 1.2, 1.0), "grip close (front-left)"], [Vector3(-0.8, 1.05, 0.35), "grip close (right side)"]]:
		cam.global_position = v[0]
		cam.look_at(Vector3(-0.05, 1.05, 0.3))
		cam.fov = 30
		lab.text = v[1]
		f.set_weapon(guard_p, guard_a, guard_e)
		f.step_move(DT, Vector3.ZERO)
		f.advance_anim(DT)
		close.append(await ST.grab(self))
	lab.position = Vector2(305, 12)
	ST.sheet(close, Rect2i(300, 0, 1000, 900), 3, 0.6, OUT + "m3_grip_close%s.png" % tag)
	quit(0)
