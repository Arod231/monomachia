extends SceneTree
# Milestone 4: Right Cut (R->L) then Return Cut (L->R) as weapon paths, captured at 60 fps sim time
# from a 3/4 side camera and from a For Honor over-the-shoulder camera behind the defender.
const Fighter = preload("res://src/fighter.gd")
const ST = preload("res://src/stage.gd")
const Swing = preload("res://src/swing.gd")
const Driver = preload("res://src/attack_driver.gd")
const Trail = preload("res://src/trail.gd")
const OUT := "<scratch>/spike-anim/shots/"
const DT := 1.0 / 60.0

var look := "neutral"
var prefix := "m4"

func _initialize() -> void:
	_run.call_deferred()

func _guard(f) -> void:
	f.set_weapon(Vector3(-0.07, 1.07, 0.36), Vector3(0.13, 0.45, 0.88), Vector3(0, -1, 0))

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var world := Node3D.new()
	root.add_child(world)
	ST.neutral(world)
	var lab: Label = ST.label(world)
	lab.add_theme_font_size_override("font_size", 30)
	var cam: Camera3D = ST.camera(world, Vector3(0, 1, 4), Vector3(0, 0.9, 0), 40)
	var a := Fighter.new()
	world.add_child(a)
	a.equip_katana()
	a.face(Vector3(0, 0, 1))
	var b := Fighter.new()
	world.add_child(b)
	b.equip_katana()
	b.global_position = Vector3(0, 0, 2.5)
	b.face(Vector3(0, 0, -1))
	var trail := Trail.new()
	world.add_child(trail)
	for i in 30:
		for f in [a, b]:
			f.step_move(DT, Vector3.ZERO)
			_guard(f)
			f.advance_anim(DT)
		await process_frame
	var drv := Driver.new(a)
	var cams := {
		"34": {"pos": Vector3(-3.6, 1.8, 2.0), "look": Vector3(0.0, 1.1, 1.05), "fov": 44.0, "crop": Rect2i(250, 90, 1100, 760), "scale": 0.45},
		"ots": {"pos": Vector3(0.9, 2.2, 7.1), "look": Vector3(0.0, 1.15, 0.2), "fov": 60.0, "crop": Rect2i(420, 120, 760, 620), "scale": 0.6},
		"ots_wide": {"pos": Vector3(1.4, 2.2, 7.1), "look": Vector3(0.3, 1.15, 0.2), "fov": 60.0, "crop": Rect2i(420, 120, 760, 620), "scale": 0.6},
		"hands": {"pos": Vector3(-0.9, 0.45, 0.8), "look": Vector3.ZERO, "fov": 34.0, "crop": Rect2i(400, 100, 800, 700), "scale": 0.45},
		"close": {"pos": Vector3(-2.1, 1.55, 2.1), "look": Vector3(0.0, 1.12, 0.4), "fov": 38.0, "crop": Rect2i(380, 0, 840, 900), "scale": 0.5},
	}
	var moves := [[Swing.right_cut(), "cut1_RtoL", [0, 3, 6, 9, 10, 11, 12, 13, 14, 17, 22, 30]],
		[Swing.return_cut(), "cut2_LtoR", [0, 3, 5, 7, 9, 10, 11, 12, 13, 16, 21, 29]]]
	for mv in moves:
		var m = mv[0]
		drv.start(m)
		var shots := {}
		for k in cams:
			shots[k] = []
		var tip_path := []
		var report := ""
		for t in m.total() + 1:
			drv.pose(float(t))
			a.step_move(DT, Vector3.ZERO)
			drv.pose(float(t))
			a.advance_anim(DT)
			b.step_move(DT, Vector3.ZERO)
			_guard(b)
			b.advance_anim(DT)
			# trail: last 5 frames sampled at quarter frames
			var segs := []
			var t0 := maxf(float(m.startup) - 2.0, t - 5.0)
			var ts := t0
			while ts <= t + 0.001:
				segs.append(drv.blade_world(ts))
				ts += 0.25
			tip_path.append(drv.blade_world(float(t))[1])
			trail.draw(segs, tip_path)
			var bw: Array = drv.blade_world(float(t))
			var tip_l := a.to_local(bw[1])
			# distance from the tip to the defender's body axis (capsule r 0.35)
			var bpos := b.global_position
			var dx := Vector2(bw[1].x - bpos.x, bw[1].z - bpos.z).length()
			report += "f%02d tip fwd %.2f m, up %.2f, gap to defender axis %.2f\n" % [t, tip_l.z, bw[1].y, dx]
			var phase := "startup" if t < m.startup else ("ACTIVE" if t < m.startup + m.active else "recovery")
			if t in mv[2]:
				for k in cams:
					var c: Dictionary = cams[k]
					cam.fov = c.fov
					if k == "hands":
						var gp := a.to_global(m.sample(float(t)).p)
						cam.global_position = gp + c.pos
						cam.look_at(gp)
					else:
						cam.global_position = c.pos
						cam.look_at(c.look)
					lab.position = Vector2(c.crop.position) + Vector2(10, 6)
					lab.text = "%s  f%d  %s" % [m.name, t, phase]
					shots[k].append(await ST.grab(self))
			else:
				await process_frame
		print(mv[1], "\n", report)
		for k in cams:
			var c: Dictionary = cams[k]
			ST.sheet(shots[k], c.crop, 6, c.scale, OUT + "%s_%s_%s.png" % [prefix, mv[1], k])
	quit(0)
