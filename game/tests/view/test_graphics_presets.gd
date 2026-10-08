extends GutTest
## Graphics presets (milestone-1 task 29, stories 182-184): Ultra, High,
## Medium and Low load, Ultra is the reference that every other preset
## follows but for its named cuts (resolution and upscaler, and atmosphere),
## Low keeps what reads the fight, a graphics card's name maps to a preset,
## and applying one sets what it promises on a small scene with one of
## everything the applier touches.


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


## The preset's own settings (its script variables), by name.
func _settings(p: GraphicsPreset) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in p.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[prop["name"]] = p.get(prop["name"])
	return out


func test_four_presets_load_and_ultra_is_the_reference_and_the_default() -> void:
	assert_eq(GraphicsPreset.IDS, [&"low", &"medium", &"high", &"ultra"] as Array[StringName])
	var presets: Array[GraphicsPreset] = _presets()
	for i: int in presets.size():
		assert_not_null(presets[i])
		if presets[i] != null:
			assert_eq(presets[i].id, GraphicsPreset.IDS[i])
			assert_false(presets[i].display_name.is_empty())
	assert_eq(GraphicsPreset.REFERENCE_ID, &"ultra")
	assert_eq(GraphicsPreset.DEFAULT_ID, &"ultra", "what tests and shots render at")
	assert_eq(GraphicsPreset.default_preset().id, &"ultra")
	assert_eq(GraphicsPreset.ultra().id, GraphicsPreset.REFERENCE_ID)
	assert_null(GraphicsPreset.load_id(&"extreme"), "no such preset")


func test_every_preset_follows_ultra_but_for_its_named_cuts() -> void:
	var ultra: Dictionary = _settings(GraphicsPreset.ultra())
	for p: GraphicsPreset in _presets():
		var mine: Dictionary = _settings(p)
		for key: String in ultra:
			if key in ["id", "display_name"]:
				continue
			if GraphicsPreset.CUTS.has(StringName(key)):
				continue
			assert_eq(mine[key], ultra[key], "%s keeps Ultra's %s" % [p.id, key])


## The parry push-in's depth of field joins them (milestone-1 task 39: off on
## Low, the owner's choice, Oct 6), and the sparks' contact lights (task 37:
## Ultra and High only, the owner's choice, Oct 6), and the fighters' key
## light shadows (task 44: off on Low, the owner's choice, Oct 7), and the
## Shrine's volumetric clouds and lighter landscape (task 51: the volume on
## Ultra and High, the lighter models on Low, the owner's choice, Oct 8),
## and the cap on the arena's marks (task 115: 96, 96, 48, 24; Oct 8).
func test_the_cuts_are_resolution_and_atmosphere_only() -> void:
	assert_eq(GraphicsPreset.CUTS, [
		&"render_scale", &"scaling_3d_mode", &"screen_space_aa",
		&"volumetric_fog", &"petal_lights", &"ambient_occlusion", &"minor_decals",
		&"push_in_dof", &"spark_light", &"fighter_shadows", &"global_illumination",
		&"floor_petal_ratio", &"volumetric_clouds", &"light_landscape", &"arena_marks",
	] as Array[StringName])


func test_the_clouds_are_volumetric_on_ultra_and_high_and_low_draws_the_lighter_landscape() -> void:
	for id: StringName in GraphicsPreset.IDS:
		var p: GraphicsPreset = GraphicsPreset.load_id(id)
		assert_eq(p.volumetric_clouds, id == &"ultra" or id == &"high", "%s's clouds" % id)
		assert_eq(p.light_landscape, id == &"low", "%s's landscape" % id)


func test_the_presets_switch_the_cloud_volume_and_the_landscape_models() -> void:
	var root := Node3D.new()
	var parts: Dictionary[String, Node3D] = {}
	for part: Array in [["Volume", GraphicsApplier.GROUP_CLOUDS, GraphicsApplier.META_VOLUMETRIC_CLOUDS, true],
			["Layer", GraphicsApplier.GROUP_CLOUDS, GraphicsApplier.META_VOLUMETRIC_CLOUDS, false],
			["Full", GraphicsApplier.GROUP_LANDSCAPE, GraphicsApplier.META_LIGHT_LANDSCAPE, false],
			["Light", GraphicsApplier.GROUP_LANDSCAPE, GraphicsApplier.META_LIGHT_LANDSCAPE, true]]:
		var n := Node3D.new()
		n.add_to_group(part[1])
		n.set_meta(part[2], part[3])
		root.add_child(n)
		parts[part[0]] = n
	var shown: Dictionary[StringName, Array] = {
		&"ultra": ["Volume", "Full"], &"high": ["Volume", "Full"], &"medium": ["Layer", "Full"], &"low": ["Layer", "Light"],
	}
	for id: StringName in shown:
		GraphicsApplier.apply_to_tree(GraphicsPreset.load_id(id), root)
		for name: String in parts:
			assert_eq(parts[name].visible, shown[id].has(name), "%s shows %s: %s" % [id, name, shown[id].has(name)])
	root.free()


func test_every_viewport_has_room_for_the_lanterns_and_canopy_lights_shadows() -> void:
	var vp := SubViewport.new()
	GraphicsApplier.apply_to_viewport(GraphicsPreset.load_id(&"ultra"), vp)
	assert_eq(vp.positional_shadow_atlas_size, GraphicsApplier.POSITIONAL_SHADOW_ATLAS)
	assert_eq(vp.get_positional_shadow_atlas_quadrant_subdiv(1), Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16)
	vp.free()


func test_global_illumination_lights_ultra_and_high_only() -> void:
	for id: StringName in GraphicsPreset.IDS:
		assert_eq(GraphicsPreset.load_id(id).global_illumination, id == &"ultra" or id == &"high", "%s's GI" % id)


func test_the_presets_turn_the_environments_global_illumination_on_and_off() -> void:
	var root := Node3D.new()
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.sdfgi_enabled = true
	root.add_child(we)
	GraphicsApplier.apply_to_tree(GraphicsPreset.load_id(&"low"), root)
	assert_false(we.environment.sdfgi_enabled, "off on Low")
	GraphicsApplier.apply_to_tree(GraphicsPreset.load_id(&"ultra"), root)
	assert_true(we.environment.sdfgi_enabled, "back on Ultra")
	root.free()


func test_the_sparks_contact_light_shows_on_ultra_and_high_only() -> void:
	for id: StringName in GraphicsPreset.IDS:
		assert_eq(GraphicsPreset.load_id(id).spark_light, id == &"ultra" or id == &"high", "%s's contact light" % id)


func test_ultra_renders_at_two_thirds_with_fsr_2_and_keeps_all_the_atmosphere() -> void:
	var u: GraphicsPreset = GraphicsPreset.load_id(&"ultra")
	assert_almost_eq(u.render_scale, 2.0 / 3.0, 0.001, "1440p at 4K, FSR 2.2's Quality mode")
	assert_eq(u.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2)
	assert_eq(u.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED, "FSR 2 does its own anti-aliasing")
	assert_true(u.volumetric_fog)
	assert_true(u.petal_lights)
	assert_true(u.ambient_occlusion)
	assert_true(u.minor_decals)


func test_high_and_medium_upscale_from_59_percent_and_medium_drops_ao_and_some_decals() -> void:
	for id: StringName in [&"high", &"medium"]:
		var p: GraphicsPreset = GraphicsPreset.load_id(id)
		assert_almost_eq(p.render_scale, 1.0 / 1.7, 0.001, "%s: FSR 2.2's Balanced mode" % id)
		assert_eq(p.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2)
		assert_eq(p.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
		assert_true(p.volumetric_fog, id)
		assert_true(p.petal_lights, id)
	assert_true(GraphicsPreset.load_id(&"high").ambient_occlusion)
	assert_true(GraphicsPreset.load_id(&"high").minor_decals)
	assert_false(GraphicsPreset.load_id(&"medium").ambient_occlusion)
	assert_false(GraphicsPreset.load_id(&"medium").minor_decals)


func test_low_drops_only_atmosphere_and_upscales_with_fsr_1() -> void:
	var low: GraphicsPreset = GraphicsPreset.load_id(&"low")
	assert_false(low.volumetric_fog, "height fog in its place")
	assert_true(low.height_fog)
	assert_true(low.fog_enabled)
	assert_false(low.petal_lights)
	assert_false(low.ambient_occlusion)
	assert_false(low.minor_decals)
	assert_almost_eq(low.render_scale, 2.0 / 3.0, 0.001, "720p at 1080p")
	assert_eq(low.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR, "FSR 1 until the laptop bench picks")
	assert_eq(low.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA, "FSR 1 doesn't anti-alias")
	assert_false(low.push_in_dof, "the push-in without its blur")
	for id: StringName in [&"medium", &"high", &"ultra"]:
		assert_true(GraphicsPreset.load_id(id).push_in_dof, id)


func test_low_keeps_what_reads_the_fight() -> void:
	# The palettes, the rim lights, blood, the 危 and the cinematic shots aren't
	# preset settings at all; what Low may change can't reach them, and what
	# the applier touches on fighters, weapons and effects matches Ultra's.
	var low: GraphicsPreset = GraphicsPreset.load_id(&"low")
	var ultra: GraphicsPreset = GraphicsPreset.ultra()
	for key: StringName in [&"particle_ratio", &"shadows_enabled", &"shadow_atlas_size", &"minor_lights",
			&"glow_enabled", &"fog_enabled"]:
		assert_eq(low.get(key), ultra.get(key), "Low keeps Ultra's %s" % key)


# ------------------------------------------------------------------ the card

func test_a_graphics_card_maps_to_a_preset() -> void:
	var cases: Dictionary = {
		"NVIDIA GeForce RTX 3080": &"ultra",
		"NVIDIA GeForce RTX 3090 Ti": &"ultra",
		"NVIDIA GeForce RTX 4070 SUPER": &"ultra",
		"NVIDIA GeForce RTX 4090": &"ultra",
		"NVIDIA GeForce RTX 5080": &"ultra",
		"AMD Radeon RX 6800 XT": &"ultra",
		"AMD Radeon RX 6950 XT": &"ultra",
		"AMD Radeon RX 7900 XTX": &"ultra",
		"AMD Radeon RX 7800 XT": &"ultra",
		"NVIDIA GeForce RTX 3070": &"high",
		"NVIDIA GeForce RTX 2060": &"high",
		"NVIDIA GeForce RTX 4060 Laptop GPU": &"high",
		"NVIDIA GeForce RTX 5060": &"high",
		"AMD Radeon RX 6600": &"high",
		"AMD Radeon RX 7600": &"high",
		"NVIDIA GeForce GTX 1080 Ti": &"medium",
		"NVIDIA GeForce GTX 1650": &"medium",
		"NVIDIA GeForce GTX 970": &"medium",
		"AMD Radeon RX 580 Series": &"medium",
		"AMD Radeon RX 5700 XT": &"medium",
		"AMD Radeon(TM) Graphics": &"low",
		"AMD Radeon(TM) Vega 8 Graphics": &"low",
		"AMD Radeon Vega 8 Graphics": &"low",
		"Intel(R) UHD Graphics 620": &"low",
		"Intel(R) Iris(R) Xe Graphics": &"low",
		"Intel(R) HD Graphics 520": &"low",
		"Some Future GPU 9000": &"medium",
		"": &"medium",
	}
	for card: String in cases:
		assert_eq(GraphicsPreset.for_card(card), cases[card], "'%s'" % card)
	assert_eq(GraphicsPreset.UNKNOWN_CARD_ID, &"medium")


func test_the_card_table_is_committed_data_and_names_only_real_presets() -> void:
	var rules: Array[Dictionary] = GraphicsPreset.card_rules()
	assert_gt(rules.size(), 5)
	for r: Dictionary in rules:
		assert_true(GraphicsPreset.IDS.has(StringName(r["preset"])), str(r))
		var re := RegEx.new()
		assert_eq(re.compile(str(r["pattern"])), OK, str(r))


# ------------------------------------------------------------------ applying

## A small scene with one of everything the applier touches, in this order:
## environment (with height fog), shadow light, minor light, particles, far
## scenery, petal light, a fighter's key light, minor decal and a camera rig.
func _scene(volumetric: bool = true, ssao: bool = true) -> Node3D:
	var root := Node3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.fog_height_density = 0.02
	env.environment.volumetric_fog_enabled = volumetric
	env.environment.ssao_enabled = ssao
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
	var petal := OmniLight3D.new()
	petal.add_to_group(GraphicsApplier.GROUP_PETAL_LIGHT)
	root.add_child(petal)
	var fighter_key := SpotLight3D.new()
	fighter_key.add_to_group(GraphicsApplier.GROUP_FIGHTER_KEY)
	root.add_child(fighter_key)
	var decal := Decal.new()
	decal.add_to_group(GraphicsApplier.GROUP_MINOR_DECAL)
	root.add_child(decal)
	root.add_child(CameraRig.new())
	return root


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
		assert_eq((root.get_child(5) as OmniLight3D).visible, p.petal_lights, "%s petal lights" % p.id)
		assert_eq((root.get_child(6) as SpotLight3D).shadow_enabled, p.fighter_shadows, "%s fighter key shadows" % p.id)
		assert_eq((root.get_child(7) as Decal).visible, p.minor_decals, "%s minor decals" % p.id)
		var env: Environment = (root.get_child(0) as WorldEnvironment).environment
		assert_eq(env.fog_enabled, p.fog_enabled, "%s fog" % p.id)
		assert_eq(env.glow_enabled, p.glow_enabled, "%s glow" % p.id)
		assert_eq(env.fog_height_density > 0.0, p.height_fog, "%s height fog" % p.id)
		assert_eq(env.volumetric_fog_enabled, p.volumetric_fog, "%s volumetric fog" % p.id)
		assert_eq(env.ssao_enabled, p.ambient_occlusion, "%s ambient occlusion" % p.id)
		assert_true(LookGrade.is_graded(env), "%s colour grade" % p.id)
		assert_eq(vp.msaa_3d, p.msaa_3d, "%s MSAA" % p.id)
		assert_eq(vp.screen_space_aa, p.screen_space_aa, "%s screen-space AA" % p.id)
		assert_almost_eq(vp.scaling_3d_scale, p.render_scale, 0.001, "%s render scale" % p.id)
		assert_eq(vp.scaling_3d_mode, p.scaling_3d_mode, "%s upscaler" % p.id)
		assert_eq((root.get_child(8) as CameraRig).dof_allowed, p.push_in_dof, "%s push-in depth of field" % p.id)


func test_atmosphere_the_scene_lacks_stays_off_and_switching_brings_back_what_it_has() -> void:
	var bare: Node3D = add_child_autofree(_scene(false, false))
	GraphicsApplier.apply(GraphicsPreset.ultra(), bare)
	var env: Environment = (bare.get_child(0) as WorldEnvironment).environment
	assert_false(env.volumetric_fog_enabled, "Ultra turns on no volumetric fog an arena didn't bring")
	assert_false(env.ssao_enabled, "nor ambient occlusion")
	var full: Node3D = add_child_autofree(_scene())
	env = (full.get_child(0) as WorldEnvironment).environment
	var base: float = env.fog_height_density
	GraphicsApplier.apply(GraphicsPreset.load_id(&"low"), full)
	assert_false(env.volumetric_fog_enabled)
	assert_false(env.ssao_enabled)
	assert_almost_eq(env.fog_height_density, base, 1e-6, "Low keeps the height fog")
	GraphicsApplier.apply(GraphicsPreset.ultra(), full)
	assert_true(env.volumetric_fog_enabled, "back on Ultra")
	assert_true(env.ssao_enabled)


func test_a_scene_with_its_own_grade_keeps_it() -> void:
	var root: Node3D = add_child_autofree(_scene())
	var env: Environment = (root.get_child(0) as WorldEnvironment).environment
	var own := ImageTexture3D.new()
	env.adjustment_color_correction = own
	GraphicsApplier.apply(GraphicsPreset.default_preset(), root)
	assert_same(env.adjustment_color_correction, own)
