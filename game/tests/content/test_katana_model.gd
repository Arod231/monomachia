extends GutTest
## The Katana and its saya modelled in Blender (milestone-1 task 47,
## scripts/blender/build_katana.py) and brought in by the export: the blade
## the code built, with the mounting modelled (habaki, seppa, a plain iron
## tsuba, fuchi and kashira, black silk ito over white same) and the markers
## where the model's empties are; the saya in black lacquer with horn
## fittings, its sageo cord in the side's dye on spring bones.

const KATANA_GLB: String = "res://assets/exports/weapons/katana.glb"
const SAYA_GLB: String = "res://assets/exports/weapons/katana_saya.glb"
const SURFACES: Array[String] = ["blade", "habaki", "tsuba", "tsuba_rim", "fittings", "same", "ito"]


func _view(fighter_id: StringName, palette: int = 0) -> FighterView:
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(fighter_id, palette, &"katana", 0)
	return v


func test_the_katana_is_the_exported_model_with_its_markers() -> void:
	var w: Node3D = WeaponLook.load_id(&"katana").instantiate()
	add_child_autofree(w)
	var mi: MeshInstance3D = w.get_node(^"Mesh")
	var names: Array[String] = []
	for s: int in mi.mesh.get_surface_count():
		names.append(mi.mesh.surface_get_name(s))
	assert_eq(names, SURFACES, "the mounting's parts, each in its material")
	var model: Node = (load(KATANA_GLB) as PackedScene).instantiate()
	for marker: StringName in [WeaponLook.BLADE_BASE, WeaponLook.BLADE_TIP, WeaponLook.OFF_HAND_GRIP]:
		var empty: Node3D = model.find_child(String(marker), true, false)
		assert_not_null(empty, "the model has %s" % marker)
		if empty != null:
			assert_almost_eq(WeaponLook.marker(w, marker).position, empty.position, Vector3.ONE * 0.001, "%s where the model puts it" % marker)
	model.free()
	var tip: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_TIP).position
	var base: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_BASE).position
	assert_almost_eq((tip - base).length(), 1.3, 0.02, "the blade is 1.3 m (KE task 2)")


func test_the_katana_wears_its_materials_in_the_look() -> void:
	var w: Node3D = WeaponLook.load_id(&"katana").instantiate()
	add_child_autofree(w)
	var mi: MeshInstance3D = w.get_node(^"Mesh")
	var blade: ShaderMaterial = mi.get_active_material(0)
	assert_eq(blade.shader, load("res://weapons/katana/katana_blade.gdshader"), "the blade keeps its temper line")
	for s: int in range(1, mi.mesh.get_surface_count()):
		var m: ShaderMaterial = mi.get_active_material(s)
		assert_eq(m.get_shader_parameter(&"use_orm_texture"), true, "%s reads its roughness and metalness" % m.resource_name)
	var ito: ShaderMaterial = mi.get_active_material(SURFACES.find("ito"))
	var same: ShaderMaterial = mi.get_active_material(SURFACES.find("same"))
	assert_not_null(ito.get_shader_parameter(&"albedo_texture"), "the silk's weave")
	assert_lt(_linear(ito), 0.05, "black silk")
	assert_gt(_linear(same), 0.3, "over white ray skin")


## A surface's mean linear luminance: its colour times its texture's mean.
static func _linear(m: ShaderMaterial) -> float:
	var c: Color = (m.get_shader_parameter(&"base_color") as Color).srgb_to_linear()
	var tex: Texture2D = m.get_shader_parameter(&"albedo_texture")
	if tex != null:
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(1, 1, Image.INTERPOLATE_TRILINEAR)
		c *= img.get_pixel(0, 0).srgb_to_linear()
	return c.get_luminance()


func test_the_saya_is_the_exported_model_and_holds_the_blade() -> void:
	var v: FighterView = _view(&"hunter")
	var saya: Saya = v.model.rig.saya
	assert_not_null(saya)
	if saya == null:
		return
	var box: AABB = saya.bounds()
	for p: Vector3 in WeaponLook.blade_segment(v.model.weapons[0]):
		assert_true(box.grow(0.001).has_point(p), "the blade's %s inside it" % p)
	assert_between(box.size.y, 1.3, 1.55, "as long as the blade and its mouth")
	var lacquer: ShaderMaterial = saya.lacquer()
	assert_not_null(lacquer.get_shader_parameter(&"albedo_texture"), "with its maki-e grasses")
	assert_lt(_linear(lacquer), 0.05, "black lacquer")


func test_the_sageo_hangs_on_spring_bones_in_the_side_s_dye() -> void:
	var colours: Array[Color] = []
	for pal: int in 2:
		var v: FighterView = _view(&"hunter", pal)
		var saya: Saya = v.model.rig.saya
		var sim: SpringBoneSimulator3D = saya.springs
		assert_not_null(sim, "the sageo swings")
		if sim == null:
			return
		assert_eq(sim.setting_count, 1)
		assert_eq(sim.get_root_bone_name(0), "Sageo0")
		assert_eq(sim.get_end_bone_name(0), "Sageo5")
		var cord: Color = saya.cord_material().get_shader_parameter(&"base_color")
		assert_eq(cord, v.model.look.palettes[pal].cord_color, "the cord in palette %d's dye" % pal)
		colours.append(cord)
	assert_ne(colours[0], colours[1], "crimson against indigo")


func test_the_sageo_settles_and_swings() -> void:
	var v: FighterView = _view(&"hunter")
	var saya: Saya = v.model.rig.saya
	var rig: Skeleton3D = saya.cord_rig
	var tip: Array[Vector3] = [Vector3.INF]
	rig.skeleton_updated.connect(func() -> void:
		tip[0] = rig.global_transform * rig.get_bone_global_pose(rig.find_bone("Sageo5")).origin)
	var last: Vector3 = Vector3.INF
	var moved: float = INF
	for frame: int in 120:
		await get_tree().physics_frame
		await get_tree().process_frame
		if frame >= 110:
			moved = minf(moved, tip[0].distance_to(last))
		last = tip[0]
	assert_lt(moved, 0.002, "the cord has come to rest")
	var hanging: Vector3 = tip[0]
	saya.springs.set_gravity_direction(0, Vector3.RIGHT)
	saya.springs.set_gravity(0, 9.8)
	for frame: int in 60:
		await get_tree().physics_frame
		await get_tree().process_frame
	assert_gt(tip[0].distance_to(hanging), 0.05, "a sideways pull swings it")
