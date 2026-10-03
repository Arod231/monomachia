extends GutTest
## Graphics presets: the three load and High is the default, they scale up
## from Low to High, fighters and weapons stay outlined on every preset, and
## applying one sets what it promises on a small scene with one of everything
## the applier touches.


## Applying a preset changes the renderer's shadow settings, which are global:
## put back the preset the game started with.
func after_all() -> void:
	var services: Node = get_tree().root.get_node("GameServices")
	GraphicsApplier.apply(services.call("graphics_preset"), null)


func _presets() -> Array[GraphicsPreset]:
	var out: Array[GraphicsPreset] = []
	for id: StringName in GraphicsPreset.IDS:
		out.append(GraphicsPreset.load_id(id))
	return out


func test_three_presets_load_and_high_is_the_default() -> void:
	var presets: Array[GraphicsPreset] = _presets()
	assert_eq(GraphicsPreset.IDS, [&"low", &"medium", &"high"] as Array[StringName])
	for i: int in presets.size():
		assert_not_null(presets[i])
		if presets[i] != null:
			assert_eq(presets[i].id, GraphicsPreset.IDS[i])
			assert_false(presets[i].display_name.is_empty())
	assert_eq(GraphicsPreset.DEFAULT_ID, &"high")
	assert_eq(GraphicsPreset.default_preset().id, &"high")
	assert_null(GraphicsPreset.load_id(&"ultra"), "no such preset")


func test_the_presets_scale_up_from_low_to_high() -> void:
	var p: Array[GraphicsPreset] = _presets()
	for i: int in 2:
		var lo: GraphicsPreset = p[i]
		var hi: GraphicsPreset = p[i + 1]
		var pair: String = "%s <= %s" % [lo.id, hi.id]
		assert_lte(lo.shadow_atlas_size, hi.shadow_atlas_size, "shadow size " + pair)
		assert_lte(lo.shadow_max_distance, hi.shadow_max_distance, "shadow distance " + pair)
		assert_lte(lo.particle_ratio, hi.particle_ratio, "particles " + pair)
		assert_lte(lo.post_quality, hi.post_quality, "post quality " + pair)
		assert_lte(lo.scenery_detail, hi.scenery_detail, "scenery detail " + pair)
		assert_lte(lo.outline_width_scale, hi.outline_width_scale, "outline width " + pair)
	assert_eq(p[2].post_quality, InkWashPass.Quality.FULL, "High draws the full ink-wash pass")


func test_fighters_and_weapons_are_outlined_on_every_preset_and_props_on_high() -> void:
	for p: GraphicsPreset in _presets():
		assert_true(p.outlines_on(ToonMaterials.OutlineKind.FIGHTER), "%s outlines fighters" % p.id)
		assert_true(p.outlines_on(ToonMaterials.OutlineKind.WEAPON), "%s outlines weapons" % p.id)
		assert_eq(p.outlines_on(ToonMaterials.OutlineKind.PROP), p.id == &"high", "%s outlines props only on High" % p.id)
		assert_false(p.outlines_on(ToonMaterials.OutlineKind.NONE), "%s leaves scenery alone" % p.id)
		assert_eq(p.outline_width_scale, 1.0, "%s keeps the owner's outline widths" % p.id)


func test_every_preset_uses_fxaa_and_leaves_glow_and_normal_lines_off() -> void:
	for p: GraphicsPreset in _presets():
		assert_eq(p.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA, "%s FXAA" % p.id)
		assert_eq(p.msaa_3d, Viewport.MSAA_DISABLED, "%s no MSAA" % p.id)
		assert_false(p.glow_enabled, "%s glow off" % p.id)
		assert_false(p.ink_normal_lines, "%s no normal buffer" % p.id)


## A small scene with one of everything the applier touches, in this order:
## environment, shadow light, minor light, particles, far scenery, ink-wash
## pass, then a fighter, a weapon, a prop and an unoutlined scenery mesh.
func _scene() -> Node3D:
	var root := Node3D.new()
	var env := WorldEnvironment.new()
	env.environment = (load("res://view/look/ink_night_environment.tres") as Environment).duplicate()
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.add_to_group(GraphicsApplier.GROUP_SHADOW_LIGHT)
	root.add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.add_to_group(GraphicsApplier.GROUP_MINOR_LIGHT)
	root.add_child(lamp)
	var particles := GPUParticles3D.new()
	particles.add_to_group(GraphicsApplier.GROUP_PARTICLES)
	root.add_child(particles)
	var far := Node3D.new()
	far.set_meta(GraphicsApplier.META_DETAIL, 2)
	far.add_to_group(GraphicsApplier.GROUP_SCENERY)
	root.add_child(far)
	root.add_child(InkWashPass.new())
	var materials: Array[ShaderMaterial] = [
		ToonMaterials.fighter(LookPalette.SIDE_COLORS[0]),
		ToonMaterials.weapon(LookPalette.STEEL),
		ToonMaterials.prop(LookPalette.STONE),
		ToonMaterials.prop(LookPalette.STONE, 0.3, false),
	]
	for m: ShaderMaterial in materials:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = m
		root.add_child(mi)
	return root


func _material(root: Node3D, index: int) -> Material:
	return (root.get_child(index) as MeshInstance3D).material_override


func test_each_preset_applies_to_the_scene_and_the_viewport() -> void:
	for p: GraphicsPreset in _presets():
		var root: Node3D = add_child_autofree(_scene())
		var vp := SubViewport.new()
		add_child_autofree(vp)
		GraphicsApplier.apply(p, root, vp)
		var sun := root.get_child(1) as DirectionalLight3D
		assert_eq(sun.shadow_enabled, p.shadows_enabled, "%s shadows" % p.id)
		assert_almost_eq(sun.directional_shadow_max_distance, p.shadow_max_distance, 0.001, "%s shadow distance" % p.id)
		var modes: Dictionary[int, DirectionalLight3D.ShadowMode] = {
			1: DirectionalLight3D.SHADOW_ORTHOGONAL,
			2: DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			4: DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		}
		assert_eq(sun.directional_shadow_mode, modes[p.shadow_splits], "%s shadow splits" % p.id)
		assert_eq((root.get_child(2) as OmniLight3D).visible, p.minor_lights, "%s minor lights" % p.id)
		assert_almost_eq((root.get_child(3) as GPUParticles3D).amount_ratio, p.particle_ratio, 0.001, "%s particles" % p.id)
		assert_eq((root.get_child(4) as Node3D).visible, p.scenery_detail >= 2, "%s scenery detail" % p.id)
		var ink := root.get_child(5) as InkWashPass
		assert_eq(ink.quality, p.post_quality, "%s post quality" % p.id)
		assert_eq(ink.visible, p.post_quality != InkWashPass.Quality.OFF, "%s pass shown" % p.id)
		assert_eq(ink.normal_lines, p.ink_normal_lines, "%s normal lines" % p.id)
		var env: Environment = (root.get_child(0) as WorldEnvironment).environment
		assert_eq(env.fog_enabled, p.fog_enabled, "%s fog" % p.id)
		assert_eq(env.glow_enabled, p.glow_enabled, "%s glow" % p.id)
		assert_eq(env.fog_height_density > 0.0, p.height_fog, "%s height fog" % p.id)
		assert_eq(env.adjustment_color_correction, InkGrade.lut(), "%s colour grade" % p.id)
		assert_eq(ToonMaterials.is_outlined(_material(root, 6)), p.outline_fighters, "%s fighter outline" % p.id)
		assert_eq(ToonMaterials.is_outlined(_material(root, 7)), p.outline_weapons, "%s weapon outline" % p.id)
		assert_eq(ToonMaterials.is_outlined(_material(root, 8)), p.outline_props, "%s prop outline" % p.id)
		assert_false(ToonMaterials.is_outlined(_material(root, 9)), "%s leaves scenery without an outline" % p.id)
		var width: float = (_material(root, 6).next_pass as ShaderMaterial).get_shader_parameter(&"width_px")
		var expected: float = ToonMaterials.OUTLINE_WIDTH[ToonMaterials.OutlineKind.FIGHTER] * p.outline_width_scale
		assert_almost_eq(width, expected, 1e-5, "%s outline width" % p.id)
		assert_eq(vp.msaa_3d, p.msaa_3d, "%s MSAA" % p.id)
		assert_eq(vp.screen_space_aa, p.screen_space_aa, "%s screen-space AA" % p.id)
		assert_almost_eq(vp.scaling_3d_scale, p.render_scale, 0.001, "%s render scale" % p.id)


func test_switching_presets_restores_height_fog() -> void:
	var root: Node3D = add_child_autofree(_scene())
	var env: Environment = (root.get_child(0) as WorldEnvironment).environment
	var base: float = env.fog_height_density
	GraphicsApplier.apply(GraphicsPreset.load_id(&"low"), root)
	assert_eq(env.fog_height_density, 0.0)
	GraphicsApplier.apply(GraphicsPreset.load_id(&"high"), root)
	assert_almost_eq(env.fog_height_density, base, 1e-6)


func test_a_scene_with_its_own_grade_keeps_it() -> void:
	var root: Node3D = add_child_autofree(_scene())
	var env: Environment = (root.get_child(0) as WorldEnvironment).environment
	var own := ImageTexture3D.new()
	env.adjustment_color_correction = own
	GraphicsApplier.apply(GraphicsPreset.default_preset(), root)
	assert_same(env.adjustment_color_correction, own)


func test_a_material_shared_by_two_meshes_is_switched_once_and_consistently() -> void:
	var root: Node3D = add_child_autofree(_scene())
	var shared: Material = _material(root, 8)
	var twin := MeshInstance3D.new()
	twin.mesh = BoxMesh.new()
	twin.material_override = shared
	root.add_child(twin)
	GraphicsApplier.apply(GraphicsPreset.load_id(&"low"), root)
	assert_false(ToonMaterials.is_outlined(shared))
	GraphicsApplier.apply(GraphicsPreset.load_id(&"high"), root)
	assert_true(ToonMaterials.is_outlined(shared))
