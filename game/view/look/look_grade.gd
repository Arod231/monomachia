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
	# little of the sky (its red round the moon) in the ambient light
	e.ambient_light_sky_contribution = 0.12
	e.ambient_light_color = LookPalette.MIST
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_exposure = EXPOSURE
	# global illumination: glowing surfaces (the wisteria's blossoms, the
	# lanterns' paper) light what's round them like natural light sources
	e.sdfgi_enabled = true
	e.sdfgi_use_occlusion = true
	e.sdfgi_read_sky_light = true
	e.sdfgi_cascades = 4
	e.sdfgi_min_cell_size = 0.2
	e.sdfgi_energy = SDFGI_ENERGY
	e.sdfgi_bounce_feedback = 0.4
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
	# the sky shows through the mist, so the blood moon keeps its red
	e.volumetric_fog_sky_affect = 0.15
	e.volumetric_fog_ambient_inject = 0.0
	e.fog_enabled = true
	e.fog_light_color = LookPalette.MIST
	e.fog_density = 0.0035
	e.fog_sky_affect = 0.2
	e.fog_aerial_perspective = 0.35
	e.glow_enabled = true
	# the glowing things halo (the blossoms like neon, the lanterns, the
	# moon); only what's past the threshold blooms, the rest stays the night
	e.glow_intensity = 0.8
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(4, 0.5)
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


## The arena's sky: a copy with the blood moon brightened (NIGHT_MOON_ENERGY, past the bloom's
## threshold, in a purer red, its red haze at NIGHT_MOON_HAZE), so the moon is the one strong
## colour in it and pops (the owner's word, Oct 7). A sky that isn't a shader
## is kept as it is.
## How strongly the global illumination carries glowing surfaces' light.
const SDFGI_ENERGY: float = 1.0
const NIGHT_MOON_ENERGY: float = 2.4
const NIGHT_MOON_HAZE: float = 0.28
## The blood moon (the owner's word, Oct 7: blood red as the toon look's
## was, imposing, a bit larger, stylized): its angular radius (radians; the
## shader's own is 0.085), a vivid orange-red at a brightness the tone map
## keeps vivid, its darker seas, the red haze round it and the clouds' red
## edges.
const NIGHT_MOON_RADIUS: float = 0.115
const NIGHT_MOON_COLOR := Color(0.85, 0.05, 0.0)
const NIGHT_MOON_SHADOW := Color(0.3, 0.01, 0.0)
const NIGHT_MOON_HAZE_COLOR := Color(0.48, 0.04, 0.02)
const NIGHT_CLOUD_EDGE := Color(0.42, 0.08, 0.05)
## The night sky, near black from the zenith to the horizon, and its clouds:
## near-black silhouettes, lit red round the moon (NIGHT_CLOUD_GLOW).
const NIGHT_ZENITH := Color(0.004, 0.004, 0.008)
const NIGHT_SKY := Color(0.008, 0.008, 0.014)
const NIGHT_HORIZON := Color(0.03, 0.028, 0.04)
const NIGHT_CLOUD := Color(0.006, 0.005, 0.008)
const NIGHT_CLOUD_GLOW: float = 0.45


static func night_sky(sky: Sky) -> Sky:
	if sky == null or not sky.sky_material is ShaderMaterial:
		return sky
	# the material copied, its textures (the look's noise) shared
	var out := sky.duplicate() as Sky
	var m := (sky.sky_material as ShaderMaterial).duplicate() as ShaderMaterial
	out.sky_material = m
	m.set_shader_parameter(&"haze_strength", NIGHT_MOON_HAZE)
	m.set_shader_parameter(&"moon_energy", NIGHT_MOON_ENERGY)
	m.set_shader_parameter(&"moon_color", NIGHT_MOON_COLOR)
	m.set_shader_parameter(&"moon_radius", NIGHT_MOON_RADIUS)
	m.set_shader_parameter(&"moon_shadow_color", NIGHT_MOON_SHADOW)
	m.set_shader_parameter(&"haze_color", NIGHT_MOON_HAZE_COLOR)
	m.set_shader_parameter(&"cloud_edge_color", NIGHT_CLOUD_EDGE)
	# a night sky near black, so the blood moon and the clouds it lights
	# stand out against it (the owner's word, Oct 7)
	m.set_shader_parameter(&"zenith_color", NIGHT_ZENITH)
	m.set_shader_parameter(&"sky_color", NIGHT_SKY)
	m.set_shader_parameter(&"horizon_color", NIGHT_HORIZON)
	m.set_shader_parameter(&"below_color", NIGHT_HORIZON)
	m.set_shader_parameter(&"cloud_color", NIGHT_CLOUD)
	m.set_shader_parameter(&"cloud_moon_glow", NIGHT_CLOUD_GLOW)
	m.set_shader_parameter(&"cloud_amount", 1.0)
	m.set_shader_parameter(&"star_amount", 1.0)
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
