extends GutTest
## The Shrine's mist and sky (milestone-1 task 49): banks of mist drifting on
## the night's wind over the courtyard and up through the canopy, shafts of
## the cool moonlight breaking through the wisteria into it (the canopy
## shadows the shafts' light in the mist alone, so the trees still cast no
## shadow on the arena), and a near-black sky of many varied stars, some
## twinkling, with a faint Milky Way away from the moon.

const SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"

var arena: MoonlitShrine


func before_all() -> void:
	arena = (load(SCENE) as PackedScene).instantiate()
	add_child(arena)


func after_all() -> void:
	arena.free()


func _sky() -> ShaderMaterial:
	var env := (arena.get_node("WorldEnvironment") as WorldEnvironment).environment
	return env.sky.sky_material as ShaderMaterial


## The value of material's uniform param: its own, or its shader's default.
func _param(material: ShaderMaterial, param: StringName) -> Variant:
	var names: Array = material.shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u["name"])
	assert_has(names, String(param), "%s is a uniform of %s" % [param, material.shader.resource_path])
	var v: Variant = material.get_shader_parameter(param)
	return v if v != null else RenderingServer.shader_get_parameter_default(material.shader.get_rid(), param)


func test_the_paving_wears_the_scanned_stone_with_grime_in_its_joints_and_some_slabs_broken() -> void:
	var floor_mi := arena.get_node("Platform/Floor") as MeshInstance3D
	var m := floor_mi.get_surface_override_material(0) as ShaderMaterial
	assert_true(bool(_param(m, &"use_scans")), "the scans on")
	for map: StringName in [&"stone_albedo", &"stone_normal", &"stone_rough", &"grime_albedo", &"grime_normal"]:
		assert_true(_param(m, map) is Texture2D, "%s from the paving export" % map)
	assert_gt(float(_param(m, &"broken_amount")), 0.0, "some slabs broken")
	assert_gt(float(_param(m, &"grime_spread")), 0.0, "grime spreading from the joints")


func test_banks_of_mist_drift_on_the_wind_over_the_courtyard_and_up_through_the_canopy() -> void:
	var banks := arena.get_node("MistBanks") as FogVolume
	assert_not_null(banks)
	assert_gt(banks.size.x, arena.def.floor_radius * 2.0, "over the whole floor")
	assert_gt(banks.size.z, arena.def.floor_radius * 2.0)
	assert_lte(banks.position.y - banks.size.y * 0.5, 0.0, "from the floor")
	assert_gt(banks.position.y + banks.size.y * 0.5, ShrineWisteria.CANOPY_FLOOR, "up through the canopy")
	var m := banks.material as ShaderMaterial
	assert_not_null(m, "a fog shader")
	assert_eq(m.shader, MoonlitShrine.MIST_BANK)
	assert_eq(_param(m, &"wind"), arena.layout.wind, "drifting on the night's wind")
	assert_eq(_param(m, &"look_noise_tex"), LookNoise.texture(), "banks of the look's noise")
	assert_true(m.shader.code.contains("TIME"), "they drift")
	assert_lt(Color(_param(m, &"albedo")).r, Color(_param(m, &"albedo")).b, "cool, not red")


func test_shafts_of_cool_moonlight_break_through_the_canopy_into_the_mist() -> void:
	var shafts := arena.get_node("Lights/MoonShafts") as DirectionalLight3D
	var key := arena.get_node("Lights/MoonKey") as DirectionalLight3D
	# a light's cull mask also limits its shadow casters, so it takes in the
	# canopy, and nothing else
	assert_eq(shafts.light_cull_mask, LookPalette.CANOPY_LAYER, "lighting the mist and only the canopy")
	assert_gt(shafts.light_energy * shafts.light_volumetric_fog_energy, key.light_energy * key.light_volumetric_fog_energy * 2.0,
		"the shafts outshine the key in the mist")
	assert_lte(shafts.light_energy, 0.05, "and barely touch the canopy, whose blossoms keep their own glow")
	assert_gt(shafts.light_color.b, shafts.light_color.r, "cool steel-blue, no red haze")
	assert_true(shafts.is_in_group(GraphicsApplier.GROUP_SHADOW_LIGHT), "the preset sets its shadows")
	assert_eq(shafts.shadow_caster_mask, LookPalette.CANOPY_LAYER, "only the canopy breaks its light")
	assert_eq(shafts.sky_mode, DirectionalLight3D.SKY_MODE_LIGHT_ONLY, "the sky draws the one moon")
	assert_almost_eq(shafts.global_basis.z, arena.layout.key_light_direction.normalized(), Vector3.ONE * 1e-4,
		"from high up, as the key")
	assert_gt(arena.layout.key_light_direction.normalized().y, 0.5, "high up")


func test_the_canopy_shadows_the_shafts_and_no_other_light() -> void:
	var canopy: int = 0
	for tree: Node in arena.get_node("Platform/Wisteria").get_children():
		for node: Node in tree.find_children("*", "GeometryInstance3D", true, false):
			var geo := node as GeometryInstance3D
			if not (geo.name.ends_with("_Bark") or geo.name.ends_with("_Blossom")):
				continue
			assert_ne(geo.layers & LookPalette.CANOPY_LAYER, 0, "%s on the canopy layer" % geo.name)
			assert_ne(geo.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s breaks the shafts" % geo.name)
			canopy += 1
	assert_gt(canopy, 5, "the trees' bark and blossoms")
	var lights: int = 0
	for node: Node in arena.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.name == &"MoonShafts" or not light.shadow_enabled:
			continue
		assert_eq(light.shadow_caster_mask & LookPalette.CANOPY_LAYER, 0, "%s takes no shadow from the trees" % light.name)
		lights += 1
	assert_gt(lights, 3, "the moon, the lanterns and the canopy lights")
	var fighter := FighterLights.new()
	assert_eq(fighter.key.shadow_caster_mask & LookPalette.CANOPY_LAYER, 0, "nor the fighters' own key")
	fighter.free()


func test_the_sky_is_near_black_with_many_varied_stars_some_twinkling_and_a_faint_milky_way() -> void:
	var sky := _sky()
	assert_gt(float(_param(sky, &"star_amount")), 0.0)
	assert_gt(float(_param(sky, &"star_colour_spread")), 0.0, "stars of varied colour")
	assert_gt(float(_param(sky, &"twinkle")), 0.0, "some twinkling")
	var band := float(_param(sky, &"milky_way"))
	assert_between(band, 0.01, 0.5, "a faint Milky Way")
	var pole: Vector3 = (_param(sky, &"milky_way_pole") as Vector3).normalized()
	var moon: Vector3 = arena.layout.moon_direction.normalized()
	assert_gt(absf(pole.dot(moon)), cos(deg_to_rad(30.0)), "its band runs well away from the moon")
	var zenith := Color(_param(sky, &"zenith_color"))
	assert_lt(zenith.get_luminance(), 0.03, "near black")
	assert_true(sky.shader.code.contains("AT_CUBEMAP_PASS"), "no twinkling in the reflections")
