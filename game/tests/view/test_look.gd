extends GutTest
## The toon look's building blocks: the toon and outline shaders load,
## ToonMaterials gives fighters, weapons and props their lighting and an ink
## outline pass that switches on and off, and LookNoise builds the shared
## noise texture the same way every time, tiling seamlessly.

const SHADERS: Array[String] = [
	"res://shaders/toon.gdshader",
	"res://shaders/toon_two_sided.gdshader",
	"res://shaders/outline.gdshader",
]
const INCLUDES: Array[String] = [
	"res://shaders/toon_light.gdshaderinc",
	"res://shaders/toon_surface.gdshaderinc",
	"res://shaders/look_noise.gdshaderinc",
]
const KATANA_BLADE: String = "res://weapons/katana/materials/blade.tres"
const RED: Color = Color(0.7, 0.16, 0.13)


## The names of the uniforms in shader code, its includes' too.
static func _uniforms(code: String) -> PackedStringArray:
	var names := PackedStringArray()
	for m: RegExMatch in RegEx.create_from_string('#include\\s+"([^"]+)"').search_all(code):
		names.append_array(_uniforms((load(m.get_string(1)) as ShaderInclude).code))
	for m: RegExMatch in RegEx.create_from_string("uniform\\s+\\w+\\s+(\\w+)").search_all(code):
		names.append(m.get_string(1))
	return names


## A parameter of m, once its shader is known to declare it: a misspelt name
## would set nothing, so the test reads only real uniforms.
func _param(m: ShaderMaterial, param: StringName) -> Variant:
	assert_has(_uniforms(m.shader.code), String(param), "%s is a uniform of %s" % [param, m.shader.resource_path])
	return m.get_shader_parameter(param)


## A float parameter of m, 0 when unset.
func _number(m: ShaderMaterial, param: StringName) -> float:
	var v: Variant = _param(m, param)
	return 0.0 if v == null else float(v)


func test_the_toon_shaders_and_their_includes_load() -> void:
	for path: String in SHADERS:
		var shader := load(path) as Shader
		assert_not_null(shader, path)
		if shader != null:
			assert_eq(shader.get_mode(), Shader.MODE_SPATIAL, path)
	for path: String in INCLUDES:
		assert_not_null(load(path) as ShaderInclude, path)


func test_fighters_get_a_rim_and_an_outline() -> void:
	var m: ShaderMaterial = ToonMaterials.fighter(RED)
	assert_eq(m.shader, ToonMaterials.TOON_SHADER)
	assert_eq(_param(m, &"base_color"), RED)
	assert_eq(ToonMaterials.outline_kind_of(m), ToonMaterials.OutlineKind.FIGHTER)
	assert_true(ToonMaterials.is_outlined(m), "outlined")
	assert_gt(_number(m, &"rim_strength"), 0.0, "a rim light")
	assert_gt(_number(m, &"rim_emission"), 0.0, "a glow at the silhouette, for dark backgrounds")


func test_steel_gets_a_hard_highlight_and_wood_does_not() -> void:
	var steel: ShaderMaterial = ToonMaterials.weapon(LookPalette.STEEL)
	var wood: ShaderMaterial = ToonMaterials.weapon(LookPalette.WOOD_DARK, false)
	for m: ShaderMaterial in [steel, wood]:
		assert_eq(ToonMaterials.outline_kind_of(m), ToonMaterials.OutlineKind.WEAPON)
		assert_true(ToonMaterials.is_outlined(m))
		assert_gt(_number(m, &"rim_strength"), 0.0)
	assert_gt(_number(steel, &"specular_strength"), 0.0)
	assert_eq(_number(wood, &"specular_strength"), 0.0)


func test_props_take_vertex_colours_and_ink_wash_stains() -> void:
	var m: ShaderMaterial = ToonMaterials.prop(LookPalette.STONE, 0.4)
	assert_eq(ToonMaterials.outline_kind_of(m), ToonMaterials.OutlineKind.PROP)
	assert_true(ToonMaterials.is_outlined(m))
	assert_eq(_param(m, &"use_vertex_color"), true)
	assert_almost_eq(_number(m, &"wash_amount"), 0.4, 1e-6)
	assert_eq(_number(m, &"rim_strength"), 0.0, "no rim: a floor at a grazing angle would glow")
	var scenery: ShaderMaterial = ToonMaterials.prop(LookPalette.STONE, 0.3, false)
	assert_eq(ToonMaterials.outline_kind_of(scenery), ToonMaterials.OutlineKind.NONE)
	assert_false(ToonMaterials.is_outlined(scenery))
	assert_null(scenery.next_pass)


func test_the_outline_takes_the_materials_ink_and_its_kinds_width() -> void:
	var ink := Color(0.2, 0.05, 0.05)
	var materials: Array[ShaderMaterial] = [
		ToonMaterials.fighter(RED, ink),
		ToonMaterials.weapon(LookPalette.STEEL),
		ToonMaterials.prop(LookPalette.STONE),
	]
	for m: ShaderMaterial in materials:
		var outline := m.next_pass as ShaderMaterial
		assert_eq(outline.shader, ToonMaterials.OUTLINE_SHADER)
		assert_eq(_param(outline, &"ink_color"), _param(m, &"ink_color"), "the outline uses the material's ink")
		var width: float = ToonMaterials.OUTLINE_WIDTH[ToonMaterials.outline_kind_of(m)]
		assert_almost_eq(_number(outline, &"width_px"), width, 1e-6)
	assert_eq(_param(materials[0], &"ink_color"), ink)
	assert_eq(_param(materials[1], &"ink_color"), LookPalette.INK, "ink by default")


func test_an_outline_switches_off_and_back_with_a_width_scale() -> void:
	var m: ShaderMaterial = ToonMaterials.prop(LookPalette.STONE)
	ToonMaterials.set_outline(m, false)
	assert_null(m.next_pass)
	assert_false(ToonMaterials.is_outlined(m))
	assert_eq(ToonMaterials.outline_kind_of(m), ToonMaterials.OutlineKind.PROP, "keeps its kind while off")
	ToonMaterials.set_outline(m, true, 0.5)
	assert_true(ToonMaterials.is_outlined(m))
	var width: float = _number(m.next_pass as ShaderMaterial, &"width_px")
	assert_almost_eq(width, ToonMaterials.OUTLINE_WIDTH[ToonMaterials.OutlineKind.PROP] * 0.5, 1e-6)


func test_a_material_without_an_outline_stays_without_one() -> void:
	var m: ShaderMaterial = ToonMaterials.prop(LookPalette.STONE, 0.3, false)
	ToonMaterials.set_outline(m, true)
	assert_null(m.next_pass)
	assert_eq(ToonMaterials.outline_kind_of(null), ToonMaterials.OutlineKind.NONE)
	assert_false(ToonMaterials.is_outlined(null))


func test_the_two_sided_toon_shader_differs_only_in_culling() -> void:
	var one: Shader = ToonMaterials.TOON_SHADER
	var two: Shader = ToonMaterials.TOON_TWO_SIDED_SHADER
	assert_string_contains(one.code, "cull_back")
	assert_string_contains(two.code, "cull_disabled")
	assert_eq(_uniforms(two.code), _uniforms(one.code), "the same parameters")


## An imported fighter material, like the Quaternius ones: textured, normal
## mapped and drawn from both sides.
func _imported(two_sided: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "MI_Test"
	m.albedo_color = Color(0.4, 0.3, 0.2)
	m.albedo_texture = LookNoise.texture()
	m.normal_enabled = true
	m.normal_texture = LookNoise.texture()
	m.normal_scale = 0.8
	m.vertex_color_use_as_albedo = true
	m.metallic_specular = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_BACK
	return m


func test_a_fighter_surface_keeps_what_it_was_imported_with() -> void:
	var source: StandardMaterial3D = _imported()
	var m: ShaderMaterial = ToonMaterials.fighter_from(source)
	assert_eq(m.shader, ToonMaterials.TOON_TWO_SIDED_SHADER, "drawn from both sides, like the import")
	assert_eq(m.resource_name, "MI_Test", "keeps its name")
	assert_eq(_param(m, &"base_color"), source.albedo_color)
	assert_eq(_param(m, &"albedo_texture"), source.albedo_texture)
	assert_eq(_param(m, &"normal_texture"), source.normal_texture)
	assert_almost_eq(_number(m, &"normal_strength"), 0.8 * ToonMaterials.FIGHTER_NORMAL_STRENGTH, 1e-6)
	assert_eq(_param(m, &"use_vertex_color"), true)
	assert_eq(_number(m, &"specular_strength"), 0.0, "cloth and skin have no hard highlight")
	assert_gt(_number(m, &"rim_strength"), 0.0, "the fighters' rim")
	assert_eq(ToonMaterials.outline_kind_of(m), ToonMaterials.OutlineKind.FIGHTER)
	assert_true(ToonMaterials.is_outlined(m))
	assert_true(ToonMaterials.is_toon(m))
	var plain: StandardMaterial3D = _imported(false)
	plain.normal_enabled = false
	var one_sided: ShaderMaterial = ToonMaterials.fighter_from(plain)
	assert_eq(one_sided.shader, ToonMaterials.TOON_SHADER)
	assert_eq(_number(one_sided, &"normal_strength"), 0.0, "no normal map, no bumps")


func test_a_weapon_material_becomes_toon_steel_or_leather() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.165, 0.18)
	steel.metallic = 0.3
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.19, 0.12, 0.08)
	for source: StandardMaterial3D in [steel, leather]:
		var m: ShaderMaterial = ToonMaterials.weapon_from(source)
		assert_eq(m.shader, ToonMaterials.TOON_SHADER)
		assert_eq(_param(m, &"base_color"), source.albedo_color)
		assert_eq(ToonMaterials.outline_kind_of(m), ToonMaterials.OutlineKind.WEAPON)
		assert_true(ToonMaterials.is_outlined(m))
	assert_gt(_number(ToonMaterials.weapon_from(steel), &"specular_strength"), 0.0, "metal gets the hard highlight")
	assert_eq(_number(ToonMaterials.weapon_from(leather), &"specular_strength"), 0.0, "leather doesn't")


func test_a_toon_lit_shader_of_its_own_keeps_its_parameters() -> void:
	var blade: ShaderMaterial = load(KATANA_BLADE)
	assert_string_contains(blade.shader.code, "toon_light.gdshaderinc", "the katana's blade is toon-lit")
	var m: ShaderMaterial = ToonMaterials.weapon_from(blade)
	assert_ne(m, blade, "a copy, so the resource stays as it is")
	assert_eq(m.shader, blade.shader)
	for param: StringName in [&"steel", &"hamon", &"specular_strength"]:
		assert_eq(_param(m, param), blade.get_shader_parameter(param), "%s comes from the resource" % param)
	assert_gt(_number(m, &"specular_strength"), 0.0, "the resource asks for a highlight")
	assert_gt(_number(m, &"rim_strength"), 0.0, "and gets the weapons' rim")
	assert_eq(_param(m, LookNoise.PARAM), LookNoise.texture())
	assert_true(ToonMaterials.is_outlined(m))
	assert_true(ToonMaterials.is_toon(m))
	assert_false(ToonMaterials.is_toon(blade), "the resource itself carries no outline")
	assert_false(ToonMaterials.is_toon(StandardMaterial3D.new()))
	assert_false(ToonMaterials.is_toon(null))


func test_every_material_gets_the_shared_noise_texture() -> void:
	for m: ShaderMaterial in [ToonMaterials.fighter(RED), ToonMaterials.weapon(LookPalette.STEEL), ToonMaterials.prop(LookPalette.STONE)]:
		assert_eq(_param(m, LookNoise.PARAM), LookNoise.texture())


func test_look_noise_is_the_same_for_the_same_seed() -> void:
	var a: Image = LookNoise.build(64, 4, 9)
	assert_eq(a.get_width(), 64)
	assert_eq(a.get_format(), Image.FORMAT_RGBA8)
	assert_eq(a.get_data(), LookNoise.build(64, 4, 9).get_data())
	assert_ne(a.get_data(), LookNoise.build(64, 4, 10).get_data(), "another seed, other noise")


## The step across the texture's edge (last texel to first) is no steeper
## than the noise's steps inside, in both directions and every channel.
func test_look_noise_tiles_without_a_seam() -> void:
	var size: int = 64
	var img: Image = LookNoise.build(size, 4, 9)
	var inside: float = 0.0
	var seam: float = 0.0
	for a: int in size:
		for b: int in size - 1:
			for c: int in 3:
				inside = maxf(inside, absf(img.get_pixel(b + 1, a)[c] - img.get_pixel(b, a)[c]))
				inside = maxf(inside, absf(img.get_pixel(a, b + 1)[c] - img.get_pixel(a, b)[c]))
		for c: int in 3:
			seam = maxf(seam, absf(img.get_pixel(0, a)[c] - img.get_pixel(size - 1, a)[c]))
			seam = maxf(seam, absf(img.get_pixel(a, 0)[c] - img.get_pixel(a, size - 1)[c]))
	assert_gt(inside, 0.0, "the noise varies")
	assert_lte(seam, inside)


func test_the_shared_noise_texture_has_mipmaps_and_matches_the_shader_lattice() -> void:
	var tex: ImageTexture = LookNoise.texture()
	assert_eq(tex.get_width(), LookNoise.SIZE)
	assert_true(tex.get_image().has_mipmaps(), "mipmapped, for surfaces seen far away")
	var include := load("res://shaders/look_noise.gdshaderinc") as ShaderInclude
	assert_string_contains(include.code, "LOOK_NOISE_CELLS = %.1f;" % LookNoise.CELLS)
