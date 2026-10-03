extends GutTest
## The ink-wash finish: the full-screen pass picks its shader by quality and
## keeps its parameters across a swap, InkGrade bakes a colour grade that
## mutes the arena but keeps the fighters' colours and inks the blacks, and
## the night environment is tuned for both.

const PASS_SHADERS: Array[String] = [
	"res://shaders/ink_wash.gdshader",
	"res://shaders/ink_wash_lite.gdshader",
]


## The names of a shader's uniforms, as compiled (an #ifdef that hides one
## leaves it out).
static func _uniforms(shader: Shader) -> PackedStringArray:
	var names := PackedStringArray()
	for u: Dictionary in shader.get_shader_uniform_list():
		names.append(u[&"name"])
	return names


func _ink() -> InkWashPass:
	return autofree(InkWashPass.new())


func test_the_pass_shaders_and_their_include_load() -> void:
	for path: String in PASS_SHADERS:
		var shader := load(path) as Shader
		assert_not_null(shader, path)
		if shader != null:
			assert_eq(shader.get_mode(), Shader.MODE_SPATIAL, path)
	assert_not_null(load("res://shaders/ink_wash.gdshaderinc") as ShaderInclude)
	assert_eq(InkWashPass.SHADER_NORMALS.resource_path, PASS_SHADERS[0])
	assert_eq(InkWashPass.SHADER_DEPTH.resource_path, PASS_SHADERS[1])


func test_only_the_normals_variant_reads_the_normal_buffer() -> void:
	# The normal buffer (normal_tex) is a screen texture, which the uniform
	# list leaves out; it is declared under the same #ifdef as the threshold.
	assert_string_contains(InkWashPass.SHADER_NORMALS.code, "#define INK_NORMALS")
	assert_false(InkWashPass.SHADER_DEPTH.code.contains("INK_NORMALS"))
	assert_has(_uniforms(InkWashPass.SHADER_NORMALS), "normal_threshold")
	assert_does_not_have(_uniforms(InkWashPass.SHADER_DEPTH), "normal_threshold")


func test_the_noise_include_has_the_screen_space_lookups() -> void:
	var include := load("res://shaders/look_noise.gdshaderinc") as ShaderInclude
	assert_string_contains(include.code, "vec3 look_noise_lod0(vec2 p)")
	assert_string_contains(include.code, "float look_white(vec2 frag)")


func test_the_pass_is_a_screen_quad_drawn_first_among_the_transparent() -> void:
	var ink: InkWashPass = _ink()
	assert_eq((ink.mesh as QuadMesh).size, Vector2(2, 2))
	assert_eq(ink.get_material().render_priority, Material.RENDER_PRIORITY_MIN)
	assert_eq(ink.material_override, ink.get_material())
	assert_eq(ink.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_true(ink.is_in_group(InkWashPass.GROUP))
	assert_eq(ink.get_material().get_shader_parameter(LookNoise.PARAM), LookNoise.texture())


func test_the_ink_lines_are_the_owners_pick() -> void:
	assert_eq(InkWashPass.LINE_WIDTH_PX, 2.0, "picked by the owner on Oct 1")
	assert_eq(InkWashPass.LINE_STRENGTH, 0.85)
	var m: ShaderMaterial = _ink().get_material()
	assert_eq(m.get_shader_parameter(&"line_width_px"), InkWashPass.LINE_WIDTH_PX)
	assert_eq(m.get_shader_parameter(&"line_strength"), InkWashPass.LINE_STRENGTH)
	var include := load("res://shaders/ink_wash.gdshaderinc") as ShaderInclude
	assert_string_contains(include.code, "line_width_px : hint_range(0.5, 4.0) = %.1f;" % InkWashPass.LINE_WIDTH_PX, "the shader's default agrees")


func test_quality_sets_the_shaders_quality_and_off_hides_the_pass() -> void:
	var ink: InkWashPass = _ink()
	assert_eq(ink.quality, InkWashPass.Quality.FULL, "full by default")
	var expected: Dictionary[InkWashPass.Quality, int] = {
		InkWashPass.Quality.LITE: 1,
		InkWashPass.Quality.LINES: 2,
		InkWashPass.Quality.FULL: 3,
	}
	for q: InkWashPass.Quality in expected:
		ink.set_quality(q)
		assert_true(ink.visible, "visible at %d" % q)
		assert_eq(ink.get_material().get_shader_parameter(&"quality"), expected[q])
	ink.set_quality(InkWashPass.Quality.OFF)
	assert_false(ink.visible)


func test_normal_lines_pick_the_full_shader_only_when_lines_are_drawn() -> void:
	var ink: InkWashPass = _ink()
	assert_eq(ink.get_material().shader, InkWashPass.SHADER_DEPTH, "no normal buffer unless asked")
	ink.set_normal_lines(true)
	assert_eq(ink.get_material().shader, InkWashPass.SHADER_NORMALS)
	ink.set_quality(InkWashPass.Quality.LINES)
	assert_eq(ink.get_material().shader, InkWashPass.SHADER_NORMALS)
	ink.set_quality(InkWashPass.Quality.LITE)
	assert_eq(ink.get_material().shader, InkWashPass.SHADER_DEPTH, "no lines, so no normal buffer")


func test_parameters_survive_a_shader_swap() -> void:
	var ink: InkWashPass = _ink()
	ink.set_param(&"line_strength", 0.5)
	ink.set_param(&"normal_threshold", 0.6)
	ink.set_normal_lines(true)
	var m: ShaderMaterial = ink.get_material()
	assert_almost_eq(float(m.get_shader_parameter(&"normal_threshold")), 0.6, 1e-6, "set before the normals variant")
	ink.set_normal_lines(false)
	assert_almost_eq(float(m.get_shader_parameter(&"line_strength")), 0.5, 1e-6)
	assert_eq(m.get_shader_parameter(LookNoise.PARAM), LookNoise.texture())


func test_the_parameters_the_pass_sets_are_uniforms_of_both_shaders() -> void:
	var ink: InkWashPass = _ink()
	for shader: Shader in [InkWashPass.SHADER_NORMALS, InkWashPass.SHADER_DEPTH]:
		var names: PackedStringArray = _uniforms(shader)
		for param: String in [&"quality", LookNoise.PARAM, &"line_strength", &"vignette_strength", &"fade_max"]:
			assert_has(names, param, "%s in %s" % [param, shader.resource_path])
	assert_true(ink.has_param(&"line_strength"))
	assert_false(ink.has_param(&"line_strenght"), "a misspelt name is caught")


func test_the_grade_keeps_the_fighters_colours() -> void:
	var red: Color = InkGrade.grade(LookPalette.SIDE_COLORS[0])
	assert_gt(red.r, red.g * 2.0, "red stays red")
	assert_gt(red.s, 0.6, "red keeps its saturation")
	var blue: Color = InkGrade.grade(LookPalette.SIDE_COLORS[1])
	assert_gt(blue.b, blue.r * 1.5, "blue stays blue")
	assert_gt(blue.s, 0.5, "blue keeps most of its saturation")


func test_the_grade_mutes_the_arena_and_inks_the_blacks() -> void:
	var grey := Color(0.5, 0.45, 0.4)
	assert_lt(InkGrade.grade(grey).s, grey.s, "muted colours get more muted")
	var black: Color = InkGrade.grade(Color.BLACK)
	assert_gt(black.b, 0.03, "black settles on ink, not pure black")
	assert_gt(black.b, black.r, "and the ink is cold")
	var white: Color = InkGrade.grade(Color.WHITE)
	assert_gt(white.get_luminance(), 0.95, "white stays bright")


func test_the_grade_keeps_greys_in_order() -> void:
	var last: float = -1.0
	for i: int in 33:
		var v: float = i / 32.0
		var lum: float = InkGrade.grade(Color(v, v, v)).get_luminance()
		assert_gte(lum, last, "grey %.3f is no darker than the one below it" % v)
		last = lum


func test_the_lut_is_the_grade_sampled_on_a_cube() -> void:
	var lut: ImageTexture3D = InkGrade.lut()
	assert_eq([lut.get_width(), lut.get_height(), lut.get_depth()], [InkGrade.SIZE, InkGrade.SIZE, InkGrade.SIZE])
	assert_same(InkGrade.lut(), lut, "built once and shared")
	var slices: Array[Image] = InkGrade.slices(InkGrade.SIZE)
	var last: float = InkGrade.SIZE - 1
	for p: Vector3i in [Vector3i(0, 0, 0), Vector3i(23, 0, 0), Vector3i(0, 23, 0), Vector3i(0, 0, 23), Vector3i(5, 12, 19), Vector3i(23, 23, 23)]:
		var want: Color = InkGrade.grade(Color(p.x / last, p.y / last, p.z / last))
		var got: Color = slices[p.z].get_pixel(p.x, p.y)
		for c: int in 3:
			assert_almost_eq(got[c], want[c], 1.0 / 255.0, "texel %s, channel %d" % [p, c])


func test_apply_turns_the_grade_on_and_leaves_the_rest_neutral() -> void:
	var env := Environment.new()
	env.adjustment_brightness = 1.3
	InkGrade.apply(env)
	assert_true(env.adjustment_enabled)
	assert_eq(env.adjustment_color_correction, InkGrade.lut())
	assert_eq([env.adjustment_brightness, env.adjustment_contrast, env.adjustment_saturation], [1.0, 1.0, 1.0])


func test_the_night_environment_is_tuned() -> void:
	var env := load("res://view/look/ink_night_environment.tres") as Environment
	assert_not_null(env)
	assert_eq(env.background_mode, Environment.BG_COLOR)
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_FILMIC)
	assert_true(env.fog_enabled, "depth fog on")
	assert_eq(env.fog_mode, Environment.FOG_MODE_DEPTH)
	assert_gt(env.fog_height_density, 0.0, "height fog on")
	assert_false(env.glow_enabled, "glow off (it cost about 2 ms on the target laptop)")
	assert_lt(env.glow_intensity, 0.6, "tuned subtle, for turning on on faster GPUs")
	assert_false(env.adjustment_enabled, "the grade is applied at run time")
