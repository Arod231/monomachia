extends SceneTree
# Milestone 2: locomotion. Strafe left (hip turn), backpedal (reversed walk), run with lean.
const Fighter = preload("res://src/fighter.gd")
const ST = preload("res://src/stage.gd")
const OUT := "<scratch>/spike-anim/shots/"
const DT := 1.0 / 60.0

var world: Node3D
var cam: Camera3D
var lab: Label

func _initialize() -> void:
	_run.call_deferred()

func _frame() -> void:
	await process_frame

func _scenario(title: String, file: String, total: int, desired: Callable, caps: Array, cam_off: Vector3, crop: Rect2i, armed: bool = false) -> void:
	var f := Fighter.new()
	world.add_child(f)
	f.face(Vector3(0, 0, 1))
	if armed:
		f.equip_katana()
	var imgs := []
	for i in total:
		f.step_move(DT, desired.call(i))
		if armed:
			f.set_weapon(Vector3(-0.07, 1.07, 0.36), Vector3(0.13, 0.45, 0.88), Vector3(0, -1, 0))
		f.advance_anim(DT)
		var p := f.global_position
		cam.global_position = p + cam_off
		cam.look_at(p + Vector3(0, 0.9, 0))
		if i in caps:
			var lv := f.global_basis.inverse() * f.vel
			lab.text = "%s  f%d  %.1f m/s  legs %+.0f deg%s" % [title, i, lv.length(), rad_to_deg(f.legs_yaw), "  (reversed)" if f.backwards else ""]
			imgs.append(await ST.grab(self))
		else:
			await _frame()
	ST.sheet(imgs, crop, imgs.size(), 0.75, OUT + file)
	f.queue_free()
	await _frame()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	ST.neutral(world)
	lab = ST.label(world)
	cam = ST.camera(world, Vector3(0, 1, 4), Vector3(0, 0.9, 0), 38)
	var crop := Rect2i(500, 0, 600, 900)
	lab.position = Vector2(505, 12)
	lab.add_theme_font_size_override("font_size", 17)
	# 1. strafe left at block-walk speed (60% of 3.9 m/s), chest keeps facing +Z
	await _scenario("strafe L", "m2_strafe_left.png", 150, func(_i): return Vector3(2.3, 0, 0), [90, 100, 110, 120, 130, 140], Vector3(1.2, 1.4, 4.0), crop)
	# 2. backpedal at 2.0 m/s
	await _scenario("backpedal", "m2_backpedal.png", 150, func(_i): return Vector3(0, 0, -2.0), [90, 100, 110, 120, 130, 140], Vector3(-3.0, 1.3, 2.6), crop)
	# 3. diagonal back-left (legs turned the other way, cycle reversed)
	await _scenario("back-left 135", "m2_back_left.png", 150, func(_i): return Vector3(1.6, 0, -1.6), [90, 102, 114, 126, 138], Vector3(-1.0, 1.4, 4.0), crop)
	# 4. run: accelerate from rest to 3.9 m/s, hold, then brake; side camera shows the lean
	await _scenario("run", "m2_run_lean.png", 110, func(i): return Vector3(0, 0, 3.9) if i < 70 else Vector3.ZERO, [4, 10, 16, 24, 50, 74, 80, 88], Vector3(-4.2, 1.1, 0.0), crop)
	# 5. the real use case: strafing and backpedalling in guard, both hands IK'd on the katana
	await _scenario("guard strafe L", "m2_guard_strafe_left.png", 150, func(_i): return Vector3(2.3, 0, 0), [90, 100, 110, 120, 130, 140], Vector3(1.2, 1.4, 4.0), crop, true)
	await _scenario("guard backpedal", "m2_guard_backpedal.png", 150, func(_i): return Vector3(0, 0, -2.0), [90, 100, 110, 120, 130, 140], Vector3(-3.0, 1.3, 2.6), crop, true)
	quit(0)
