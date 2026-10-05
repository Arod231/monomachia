extends SceneTree
# Milestone 5: toon ramp (3 bands) + ink outline on fighters and katana, dark moonlit stage
# with one moon directional light and a rim light. Guard pose and contact frames.
const Fighter = preload("res://src/fighter.gd")
const ST = preload("res://src/stage.gd")
const Swing = preload("res://src/swing.gd")
const Driver = preload("res://src/attack_driver.gd")
const Trail = preload("res://src/trail.gd")
const Look = preload("res://src/look.gd")
const OUT := "<scratch>/spike-anim/shots/"
const DT := 1.0 / 60.0
const RIM := Vector3(0.55, 0.4, -0.75)

var cam: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func _guard(f) -> void:
	f.set_weapon(Vector3(-0.07, 1.07, 0.36), Vector3(0.13, 0.45, 0.88), Vector3(0, -1, 0))

func _set_cam(c: Dictionary) -> void:
	cam.fov = c.fov
	cam.global_position = c.pos
	cam.look_at(c.look)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	Look.moonlit(world, Vector3(-0.55, 0.7, 0.45))
	# vignette
	var cl := CanvasLayer.new()
	world.add_child(cl)
	var vg := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.set_color(1, Color(0.0, 0.0, 0.02, 0.6))
	gr.add_point(0.55, Color(0, 0, 0, 0))
	gt.gradient = gr
	vg.texture = gt
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	cl.add_child(vg)
	# decorative moon in the sky, in view of the over-the-shoulder camera
	var moon_disc := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 5.0
	sp.height = 10.0
	moon_disc.mesh = sp
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.85, 0.9, 1.0)
	mm.emission_enabled = true
	mm.emission = Color(0.8, 0.88, 1.0)
	mm.emission_energy_multiplier = 1.6
	mm.disable_fog = true
	moon_disc.material_override = mm
	moon_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_disc.position = Vector3(-0.42, 0.24, -0.88).normalized() * 120.0
	world.add_child(moon_disc)
	cam = ST.camera(world, Vector3(0, 1, 4), Vector3(0, 0.9, 0), 40)
	cam.far = 400.0
	var a := Fighter.new()
	world.add_child(a)
	a.equip_katana(Look.katana_materials(RIM))
	a.face(Vector3(0, 0, 1))
	Look.apply_fighter(a, RIM)
	var b := Fighter.new("Hair_Long", "res://assets/ranger/T_Ranger_3_BaseColor.png")
	world.add_child(b)
	b.equip_katana(Look.katana_materials(RIM))
	var dist := 2.5
	var uargs := OS.get_cmdline_user_args()
	var tag := ""
	if not uargs.is_empty():
		dist = float(uargs[0])
		tag = "_d%s" % uargs[0]
	b.global_position = Vector3(0, 0, dist)
	b.face(Vector3(0, 0, -1))
	Look.apply_fighter(b, RIM)
	var trail := Trail.new()
	world.add_child(trail)
	for i in 40:
		for f in [a, b]:
			f.step_move(DT, Vector3.ZERO)
			_guard(f)
			f.advance_anim(DT)
		await process_frame
	var cams := {
		"34": {"pos": Vector3(-3.2, 1.75, 2.3), "look": Vector3(0.0, 1.1, 1.0), "fov": 40.0},
		"guard_close": {"pos": Vector3(-2.0, 1.5, 2.1), "look": Vector3(0.0, 1.05, 0.3), "fov": 36.0},
		"ots": {"pos": Vector3(0.9, 2.2, 7.1), "look": Vector3(0.0, 1.15, 0.2), "fov": 60.0},
		"ots_wide": {"pos": Vector3(1.4, 2.2, 7.1), "look": Vector3(0.3, 1.15, 0.2), "fov": 60.0},
	}
	for k in ["guard_close", "ots"]:
		_set_cam(cams[k])
		var img: Image = await ST.grab(self)
		img.save_png(OUT + "m5_guard_%s%s.png" % [k, tag])
	var drv := Driver.new(a)
	var moves := [[Swing.right_cut(), "cut1", 13, [0, 4, 8, 10, 11, 12, 13, 14, 16, 20, 25, 30]], [Swing.return_cut(), "cut2", 12, []]]
	for mv in moves:
		var m = mv[0]
		drv.start(m)
		var sheet := []
		for t in m.total() + 1:
			drv.pose(float(t))
			a.step_move(DT, Vector3.ZERO)
			drv.pose(float(t))
			a.advance_anim(DT)
			b.step_move(DT, Vector3.ZERO)
			_guard(b)
			b.advance_anim(DT)
			var segs := []
			var ts := maxf(float(m.startup) - 1.0, t - 4.0)
			while ts <= t + 0.001:
				segs.append(drv.blade_world(ts))
				ts += 0.25
			trail.draw(segs if t <= m.startup + m.active + 3 else [])
			if t == mv[2]:
				for k in ["34", "ots", "ots_wide"]:
					_set_cam(cams[k])
					var img: Image = await ST.grab(self)
					img.save_png(OUT + "m5_contact_%s_%s%s.png" % [mv[1], k, tag])
			if t in mv[3]:
				_set_cam(cams["34"])
				sheet.append(await ST.grab(self))
			elif t != mv[2]:
				await process_frame
		if not sheet.is_empty():
			ST.sheet(sheet, Rect2i(250, 80, 1100, 760), 6, 0.45, OUT + "m5_%s_sheet_34%s.png" % [mv[1], tag])
	quit(0)
