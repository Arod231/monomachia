class_name LookGrade
extends RefCounted
## The realistic look's night and its one colour grade (milestone-1 task 43),
## as the look test (task 30) settled them beside the mood board: dark first,
## the moon's cold light, mist in volumetric fog that eats the background,
## colour only as accents.
##
## - environment() builds an arena's environment over its own sky:
##   blue-black ambient, volumetric and depth fog, ambient occlusion, subtle
##   bloom, the AgX tone map and the grade. The graphics presets turn its
##   atmosphere down (GraphicsApplier).
## - grade() puts only the grade (tone map, contrast, saturation and the
##   grade curve) on an environment that brings its own lighting (the menus'
##   fighter preview, the Studio), so every camera shows the same grade.

## The grade's tone mapping and exposure.
const TONEMAP: Environment.ToneMapper = Environment.TONE_MAPPER_AGX
const EXPOSURE: float = 0.82
const CONTRAST: float = 1.18
const SATURATION: float = 0.72

static var _curve: GradientTexture1D


## The night over `base`'s sky (a quieter copy of it, night_sky()).
static func environment(base: Environment) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = night_sky(base.sky)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.16
	e.ambient_light_sky_contribution = 0.35
	e.ambient_light_color = LookPalette.MIST
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_exposure = EXPOSURE
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.6
	e.ssao_power = 1.4
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.03
	e.volumetric_fog_albedo = LookPalette.MIST
	e.volumetric_fog_emission = LookPalette.NIGHT_INK
	e.volumetric_fog_emission_energy = 0.6
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_length = 48.0
	e.volumetric_fog_sky_affect = 0.35
	e.volumetric_fog_ambient_inject = 0.25
	e.fog_enabled = true
	e.fog_light_color = LookPalette.MIST
	e.fog_density = 0.0035
	e.fog_sky_affect = 0.5
	e.fog_aerial_perspective = 0.35
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_strength = 0.9
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	grade(e)
	return e


## Puts the grade on `env`: the AgX tone map, contrast up, colour pulled back
## but for the accents, and the grade curve. Its exposure is left alone.
static func grade(env: Environment) -> void:
	env.tonemap_mode = TONEMAP
	env.adjustment_enabled = true
	env.adjustment_contrast = CONTRAST
	env.adjustment_saturation = SATURATION
	env.adjustment_color_correction = grade_curve()


## Whether `env` carries the grade.
static func is_graded(env: Environment) -> bool:
	return env != null and env.tonemap_mode == TONEMAP and env.adjustment_enabled \
		and env.adjustment_color_correction == grade_curve()


## The arena's sky, quieter: a copy with its red haze and the clouds' red
## edges pulled back, so the blood moon is the one strong colour in it. A sky
## that isn't a shader is kept as it is.
static func night_sky(sky: Sky) -> Sky:
	if sky == null or not sky.sky_material is ShaderMaterial:
		return sky
	# the material copied, its textures (the look's noise) shared
	var out := sky.duplicate() as Sky
	var m := (sky.sky_material as ShaderMaterial).duplicate() as ShaderMaterial
	out.sky_material = m
	m.set_shader_parameter(&"haze_strength", 0.12)
	m.set_shader_parameter(&"cloud_edge_color", Color(0.16, 0.07, 0.07))
	m.set_shader_parameter(&"horizon_color", LookPalette.MIST.darkened(0.45))
	m.set_shader_parameter(&"below_color", LookPalette.MIST.darkened(0.55))
	return out


## The grade curve, one for every environment: each channel through a curve
## that lifts black to NIGHT_INK, cools the mid tones toward moonlit steel and
## warms the highlights a touch (a 1D colour correction).
static func grade_curve() -> GradientTexture1D:
	if _curve == null:
		var g := Gradient.new()
		g.set_offset(0, 0.0)
		g.set_color(0, LookPalette.NIGHT_INK)
		g.set_offset(1, 1.0)
		g.set_color(1, Color(1.0, 0.97, 0.92))
		g.add_point(0.45, Color(0.42, 0.45, 0.5))
		_curve = GradientTexture1D.new()
		_curve.gradient = g
		_curve.width = 256
	return _curve
