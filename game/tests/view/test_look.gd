extends GutTest
## The realistic look's building blocks (milestone-1 task 43): the surface
## shaders load and leave the lighting to Godot's physically based model,
## LookMaterials gives fighters, weapons and props their roughness and
## metalness with no outline pass, LookGrade builds the night and its one
## grade, and LookNoise builds the shared noise texture the same way every
## time, tiling seamlessly.

const SHADERS: Array[String] = [
	"res://shaders/surface.gdshader",
	"res://shaders/surface_two_sided.gdshader",
]
const INCLUDES: Array[String] = [
	"res://shaders/surface.gdshaderinc",
	"res://shaders/blood_stain.gdshaderinc",
	"res://shaders/look_noise.gdshaderinc",
]
## Every shader a lit surface of the game draws with: none brings a toon
## light() of its own.
const LIT_SHADERS: Array[String] = [
	"res://shaders/surface.gdshader",
	"res://shaders/surface_two_sided.gdshader",
	"res://shaders/stone_floor.gdshader",
	"res://shaders/rock.gdshader",
	"res://weapons/katana/katana_blade.gdshader",
	"res://weapons/katana/katana_wrap.gdshader",
]
const KATANA_BLADE: String = "res://weapons/katana/materials/blade.tres"
const RED: Color = Color(0.7, 0.16, 0.13)


## The code of a shader with its includes inlined.
static func _code(code: String) -> String:
	var out: String = code
	for m: RegExMatch in RegEx.create_from_string('#include\\s+"([^"]+)"').search_all(code):
		out += "\n" + _code((load(m.get_string(1)) as ShaderInclude).code)
	return out


## The names of the uniforms in shader code, its includes' too.
static func _uniforms(code: String) -> PackedStringArray:
	var names := PackedStringArray()
	for m: RegExMatch in RegEx.create_from_string("uniform\\s+\\w+\\s+(\\w+)").search_all(_code(code)):
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


func test_the_surface_shaders_and_their_includes_load() -> void:
	for path: String in SHADERS:
		var shader := load(path) as Shader
		assert_not_null(shader, path)
		if shader != null:
			assert_eq(shader.get_mode(), Shader.MODE_SPATIAL, path)
	for path: String in INCLUDES:
		assert_not_null(load(path) as ShaderInclude, path)


func test_no_lit_surface_brings_its_own_light() -> void:
	for path: String in LIT_SHADERS:
		var code: String = _code((load(path) as Shader).code)
		assert_false(code.contains("void light()"), "%s is lit by Godot's physically based model" % path)
		assert_true(code.contains("ROUGHNESS"), "%s sets its roughness" % path)


func test_the_two_sided_surface_differs_only_in_culling() -> void:
	var one: String = (load(SHADERS[0]) as Shader).code
	var two: String = (load(SHADERS[1]) as Shader).code
	assert_string_contains(one, "cull_back")
	assert_string_contains(two, "cull_disabled")
	assert_string_contains(two, '#include "res://shaders/surface.gdshaderinc"')


func test_a_fighter_is_rough_cloth_with_no_outline() -> void:
	var m: ShaderMaterial = LookMaterials.fighter(RED)
	assert_eq(m.shader, LookMaterials.SURFACE_SHADER)
	assert_eq(_param(m, &"base_color"), RED)
	assert_almost_eq(_number(m, &"roughness"), LookMaterials.FIGHTER_SURFACE.x, 1e-6)
	assert_eq(_number(m, &"metallic"), 0.0)
	assert_eq(LookMaterials.surface_of(m), LookMaterials.Surface.FIGHTER)
	assert_true(LookMaterials.is_physical(m))
	assert_null(m.next_pass, "no outline pass")


## An imported material, as the Quaternius models bring them.
func _imported(two_sided: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "MI_Test"
	m.albedo_color = Color(0.9, 0.8, 0.7)
	m.albedo_texture = LookNoise.texture()
	m.normal_enabled = true
	m.normal_texture = LookNoise.texture()
	m.normal_scale = 0.8
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_BACK
	return m


func test_a_fighter_surface_keeps_what_it_was_imported_with() -> void:
	var source: StandardMaterial3D = _imported()
	var m: ShaderMaterial = LookMaterials.fighter_from(source)
	assert_eq(m.shader, LookMaterials.SURFACE_TWO_SIDED_SHADER, "drawn from both sides, like the import")
	assert_eq(m.resource_name, "MI_Test", "keeps its name")
	assert_eq(_param(m, &"base_color"), source.albedo_color)
	assert_eq(_param(m, &"albedo_texture"), source.albedo_texture)
	assert_eq(_param(m, &"normal_texture"), source.normal_texture)
	assert_almost_eq(_number(m, &"normal_strength"), 0.8 * LookMaterials.FIGHTER_NORMAL_STRENGTH, 1e-6)
	assert_eq(_param(m, &"use_vertex_color"), true)
	assert_almost_eq(_number(m, &"roughness"), LookMaterials.FIGHTER_SURFACE.x, 1e-6)
	assert_eq(LookMaterials.surface_of(m), LookMaterials.Surface.FIGHTER)
	assert_null(m.next_pass)
	var plain: StandardMaterial3D = _imported(false)
	plain.normal_enabled = false
	var one_sided: ShaderMaterial = LookMaterials.fighter_from(plain)
	assert_eq(one_sided.shader, LookMaterials.SURFACE_SHADER)
	assert_eq(_number(one_sided, &"normal_strength"), 0.0, "no normal map, no bumps")


func test_a_weapon_material_becomes_steel_or_leather() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.165, 0.18)
	steel.metallic = 0.3
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.19, 0.12, 0.08)
	for source: StandardMaterial3D in [steel, leather]:
		var m: ShaderMaterial = LookMaterials.weapon_from(source)
		assert_eq(m.shader, LookMaterials.SURFACE_SHADER)
		assert_eq(_param(m, &"base_color"), source.albedo_color)
		assert_eq(LookMaterials.surface_of(m), LookMaterials.Surface.WEAPON)
		assert_null(m.next_pass)
	var metal: ShaderMaterial = LookMaterials.weapon_from(steel)
	assert_almost_eq(_number(metal, &"metallic"), LookMaterials.METAL_SURFACE.y, 1e-6, "steel is metal")
	assert_lt(_number(metal, &"roughness"), LookMaterials.WEAPON_SURFACE.x, "and smoother than leather")
	assert_eq(_number(LookMaterials.weapon_from(leather), &"metallic"), 0.0, "leather isn't")


func test_a_shader_of_its_own_keeps_its_parameters() -> void:
	var blade: ShaderMaterial = load(KATANA_BLADE)
	var m: ShaderMaterial = LookMaterials.weapon_from(blade)
	assert_ne(m, blade, "a copy, so the resource stays as it is")
	assert_eq(m.shader, blade.shader)
	for param: StringName in [&"steel", &"hamon"]:
		assert_eq(_param(m, param), blade.get_shader_parameter(param), "%s comes from the resource" % param)
	assert_string_contains(m.shader.code, "uniform float metallic : hint_range(0.0, 1.0) = 1.0;", "the blade is steel")
	assert_eq(_param(m, LookNoise.PARAM), LookNoise.texture())
	assert_true(LookMaterials.is_physical(m))
	assert_false(LookMaterials.is_physical(blade), "the resource itself is left alone")
	assert_false(LookMaterials.is_physical(StandardMaterial3D.new()))
	assert_false(LookMaterials.is_physical(null))


func test_a_prop_is_rough_and_takes_the_mesh_s_shading() -> void:
	var m: ShaderMaterial = LookMaterials.prop(LookPalette.STONE)
	assert_eq(_param(m, &"base_color"), LookPalette.STONE)
	assert_eq(_param(m, &"use_vertex_color"), true, "MeshKit's baked shading")
	assert_almost_eq(_number(m, &"roughness"), LookMaterials.PROP_SURFACE.x, 1e-6)
	assert_eq(LookMaterials.surface_of(m), LookMaterials.Surface.PROP)


func test_every_material_gets_the_shared_noise_texture() -> void:
	for m: ShaderMaterial in [LookMaterials.fighter(RED), LookMaterials.weapon(LookPalette.STEEL), LookMaterials.prop(LookPalette.STONE)]:
		assert_eq(_param(m, LookNoise.PARAM), LookNoise.texture())


func test_the_night_has_the_look_test_s_atmosphere_and_the_grade() -> void:
	var base := Environment.new()
	base.sky = Sky.new()
	var e: Environment = LookGrade.environment(base)
	assert_eq(e.background_mode, Environment.BG_SKY)
	assert_eq(e.tonemap_mode, Environment.TONE_MAPPER_AGX, "AgX, not filmic")
	assert_almost_eq(e.tonemap_exposure, LookGrade.EXPOSURE, 1e-6)
	assert_true(e.volumetric_fog_enabled, "mist in volumetric fog")
	assert_true(e.ssao_enabled, "ambient occlusion")
	assert_true(e.sdfgi_enabled, "global illumination, so glowing surfaces light what's round them")
	assert_true(e.fog_enabled, "depth fog")
	assert_true(e.glow_enabled, "subtle bloom")
	assert_lt(e.glow_bloom, 0.1, "subtle")
	assert_true(LookGrade.is_graded(e))


func test_the_grade_lifts_black_to_night_ink_and_pulls_colour_back() -> void:
	var e := Environment.new()
	assert_false(LookGrade.is_graded(e))
	LookGrade.grade(e)
	assert_true(LookGrade.is_graded(e))
	assert_lt(e.adjustment_saturation, 1.0, "colour pulled back but for the accents")
	assert_gt(e.adjustment_contrast, 1.0)
	var g: Gradient = LookGrade.grade_curve().gradient
	assert_eq(g.sample(0.0), LookPalette.NIGHT_INK, "black lifts to the night's ink")
	var mid: Color = g.sample(0.45)
	assert_gt(mid.b, mid.r, "the mid tones cool toward moonlit steel")
	assert_eq(LookGrade.grade_curve(), LookGrade.grade_curve(), "one curve for every environment")


func test_the_night_sky_quiets_a_shader_sky_and_leaves_others() -> void:
	var sky := Sky.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/sky_moonlit.gdshader")
	sky.sky_material = m
	var quiet: Sky = LookGrade.night_sky(sky)
	assert_ne(quiet, sky, "a copy")
	var qm := quiet.sky_material as ShaderMaterial
	assert_eq(qm.get_shader_parameter(&"moon_color"), LookGrade.NIGHT_MOON_COLOR, "a purer blood red")
	assert_gt(LookGrade.NIGHT_MOON_RADIUS, 0.085, "larger than the sky shader's own")
	assert_almost_eq(float(qm.get_shader_parameter(&"moon_radius")), LookGrade.NIGHT_MOON_RADIUS, 1e-6)
	assert_almost_eq(float(qm.get_shader_parameter(&"haze_strength")), LookGrade.NIGHT_MOON_HAZE, 1e-6)
	assert_almost_eq(float(qm.get_shader_parameter(&"moon_energy")), LookGrade.NIGHT_MOON_ENERGY, 1e-6)
	assert_gt(LookGrade.NIGHT_MOON_COLOR.r, LookGrade.NIGHT_MOON_COLOR.g * 8.0, "a deep blood red")
	var plain := Sky.new()
	plain.sky_material = ProceduralSkyMaterial.new()
	assert_eq(LookGrade.night_sky(plain), plain)


func test_film_grain_is_faint_and_under_the_hud() -> void:
	var grain := FilmGrain.new()
	add_child_autofree(grain)
	assert_gt(grain.layer, SplitView.LAYER, "over both halves of a split screen")
	assert_lt(grain.layer, 5, "under the HUD")
	assert_lt(FilmGrain.AMOUNT, 0.1, "light")
	assert_eq(grain.rect.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never takes a click")


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
