class_name LookMaterials
extends RefCounted
## The realistic look's materials (milestone-1 task 43): physically based
## surfaces for fighters, weapons and props, lit by Godot's own model under
## the night's grade (LookGrade), as the look test (task 30) settled them. No
## toon bands, outlines or ink-wash.
##
## Each material is a ShaderMaterial on SURFACE_SHADER (or its two-sided
## twin), so a fighter's surfaces take blood stains (blood_stain.gdshaderinc,
## BloodEffects), and remembers its Surface kind (META_SURFACE), which sets
## its roughness and metalness:
## - a fighter: rough cloth, leather and skin (FIGHTER_SURFACE);
## - a weapon: worn steel (METAL_SURFACE), or wrapped leather and wood
##   (WEAPON_SURFACE);
## - a prop: plain stone and wood (PROP_SURFACE).
## Shaders of their own (the stone floor, the rock, the Katana's blade and
## wrap) set their own roughness and metalness; make_with_shader() gives them
## the look's noise and the kind.

enum Surface { PROP, FIGHTER, WEAPON }

const SURFACE_SHADER: Shader = preload("res://shaders/surface.gdshader")
## The same surface drawn from both sides, for open shells (hoods, cloth
## edges, hair cards).
const SURFACE_TWO_SIDED_SHADER: Shader = preload("res://shaders/surface_two_sided.gdshader")
## The same surface from both sides, swayed by the wind (the Shrine's grass
## and banners, milestone-1 task 131; sway()).
const SWAY_SHADER: Shader = preload("res://shaders/surface_sway.gdshader")
## The same surface for far scenery, faded into the horizon's mist by the
## aerial fade the Shrine's landscape takes (milestone-1 task 51; far()).
const SURFACE_FAR_SHADER: Shader = preload("res://shaders/surface_far.gdshader")

const META_SURFACE: StringName = &"look_surface"

## Roughness and metalness (x, y) by surface, the look test's.
const FIGHTER_SURFACE := Vector2(0.82, 0.0)
const METAL_SURFACE := Vector2(0.42, 0.85)
const WEAPON_SURFACE := Vector2(0.75, 0.0)
const PROP_SURFACE := Vector2(0.88, 0.0)
## How much of an imported normal map a fighter keeps, as the approved look
## test drew it.
const FIGHTER_NORMAL_STRENGTH: float = 0.4


## A surface of `kind` in `color`, with roughness and metalness from
## `surface`. params are more shader parameters to set.
static func make(color: Color, kind: Surface, surface: Vector2, params: Dictionary = {}) -> ShaderMaterial:
	return make_with_shader(SURFACE_SHADER, kind, params.merged({
		&"base_color": color,
		&"roughness": surface.x,
		&"metallic": surface.y,
	}, true))


## A material on `shader` (SURFACE_SHADER, or a shader of its own like the
## stone floor's) of `kind`, with the look's noise and params set.
static func make_with_shader(shader: Shader, kind: Surface, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	LookNoise.apply_to(m)
	for key: Variant in params:
		m.set_shader_parameter(key, params[key])
	m.set_meta(META_SURFACE, kind)
	return m


## A fighter's cloth or skin in one colour.
static func fighter(color: Color) -> ShaderMaterial:
	return make(color, Surface.FIGHTER, FIGHTER_SURFACE)


## A fighter surface from the material it was imported with: its colour,
## base-colour texture, normal map and vertex colour carried over, drawn from
## both sides when the import is. A roughness map (the Hunter's dyed outfit,
## milestone-1 task 45: roughness in green, metalness in blue, as glTF packs
## them) replaces the fixed FIGHTER_SURFACE. Its name is kept, so the palettes still
## find the outfit by name.
static func fighter_from(source: BaseMaterial3D) -> ShaderMaterial:
	var params: Dictionary = {
		&"base_color": source.albedo_color,
		&"albedo_texture": source.albedo_texture,
		&"use_vertex_color": source.vertex_color_use_as_albedo,
		&"roughness": FIGHTER_SURFACE.x,
		&"metallic": FIGHTER_SURFACE.y,
		&"normal_strength": 0.0,
	}
	if source.normal_enabled and source.normal_texture != null:
		params[&"normal_texture"] = source.normal_texture
		params[&"normal_strength"] = source.normal_scale * FIGHTER_NORMAL_STRENGTH
	if source.roughness_texture != null:
		params[&"orm_texture"] = source.roughness_texture
		params[&"use_orm_texture"] = true
	var two_sided: bool = source.cull_mode == BaseMaterial3D.CULL_DISABLED
	var m: ShaderMaterial = make_with_shader(SURFACE_TWO_SIDED_SHADER if two_sided else SURFACE_SHADER,
		Surface.FIGHTER, params)
	m.resource_name = source.resource_name
	return m


## A weapon's steel, or (metal false) its leather, wood or lacquer.
static func weapon(color: Color, metal: bool = true) -> ShaderMaterial:
	return make(color, Surface.WEAPON, METAL_SURFACE if metal else WEAPON_SURFACE)


## A weapon surface from the material its model was made with, keeping its
## name:
## - a StandardMaterial3D becomes steel when it is at all metallic, and
##   leather or wood otherwise, in its colour; one with maps of its own (a
##   model from the Blender export: the Katana's mounting and saya,
##   milestone-1 task 47) keeps its base-colour texture, normal map and
##   roughness map (roughness green, metalness blue, as glTF packs them);
## - a ShaderMaterial of its own (the Katana's blade) is copied, every
##   parameter it sets kept, with the look's noise.
static func weapon_from(source: Material) -> ShaderMaterial:
	var m: ShaderMaterial
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		m = weapon(base.albedo_color, base.metallic > 0.0)
		_carry_maps(m, base)
	else:
		m = (source as ShaderMaterial).duplicate() as ShaderMaterial
		LookNoise.apply_to(m)
		m.set_meta(META_SURFACE, Surface.WEAPON)
	m.resource_name = source.resource_name
	return m


## A material's own maps carried onto a look material: its base-colour
## texture, normal map and roughness map (roughness green, metalness blue,
## as glTF packs them).
static func _carry_maps(m: ShaderMaterial, base: BaseMaterial3D) -> void:
	if base.albedo_texture != null:
		m.set_shader_parameter(&"albedo_texture", base.albedo_texture)
	if base.normal_enabled and base.normal_texture != null:
		m.set_shader_parameter(&"normal_texture", base.normal_texture)
		m.set_shader_parameter(&"normal_strength", base.normal_scale)
	if base.roughness_texture != null:
		m.set_shader_parameter(&"orm_texture", base.roughness_texture)
		m.set_shader_parameter(&"use_orm_texture", true)


## A prop surface from the material a model from the Blender export was made
## with (the Shrine's banner poles, milestone-1 task 131): its colour and its
## own maps, keeping its name.
static func prop_from(source: Material) -> ShaderMaterial:
	var base := source as BaseMaterial3D
	var m: ShaderMaterial = make(base.albedo_color, Surface.PROP, PROP_SURFACE,
		{&"use_vertex_color": base.vertex_color_use_as_albedo})
	_carry_maps(m, base)
	m.resource_name = source.resource_name
	return m


## A prop surface that sways on the arena's one wind (SWAY_SHADER, which
## reads it from wind.gdshaderinc), from the material its model was made
## with: the freest vertex leaning `sway` metres for each m/s of wind and
## fluttering by `flutter`, its weight in its vertex alpha, or in its
## vertex red (`from_red`, the banners' cloth, whose colour is its
## texture's); with the weight in the alpha, the vertex colour is its
## colour (the grass).
static func sway(source: BaseMaterial3D, sway_amount: float, flutter: float, from_red: bool) -> ShaderMaterial:
	var m: ShaderMaterial = make_with_shader(SWAY_SHADER, Surface.PROP, {
		&"base_color": source.albedo_color,
		&"roughness": PROP_SURFACE.x,
		&"metallic": PROP_SURFACE.y,
		&"use_vertex_color": not from_red,
		&"sway": sway_amount,
		&"flutter": flutter,
		&"sway_from_red": from_red,
	})
	_carry_maps(m, source)
	m.resource_name = source.resource_name
	return m


## A prop's stone, wood, lacquer or paper, taking the mesh's vertex colour
## (MeshKit's baked shading) as the toon props did.
static func prop(color: Color, surface: Vector2 = PROP_SURFACE) -> ShaderMaterial:
	return make(color, Surface.PROP, surface, {&"use_vertex_color": true})


## Whether `material` was made here, so it carries its Surface kind.
static func is_physical(material: Material) -> bool:
	return material is ShaderMaterial and material.has_meta(META_SURFACE)


## The kind a material was made as; PROP for any other material.
static func surface_of(material: Material) -> Surface:
	if material == null or not material.has_meta(META_SURFACE):
		return Surface.PROP
	return material.get_meta(META_SURFACE) as Surface


## Whether `shader` is the shared surface, either side (the surfaces a
## fighter's blood stains go on).
static func is_surface_shader(shader: Shader) -> bool:
	return shader == SURFACE_SHADER or shader == SURFACE_TWO_SIDED_SHADER or shader == SURFACE_FAR_SHADER


## A copy of source (a surface) for far scenery: the same surface on
## SURFACE_FAR_SHADER, fading into horizon (the depth fog's colour) by the
## aerial fade. Anything else comes back as it is.
static func far(source: Material, horizon: Color) -> Material:
	if not (source is ShaderMaterial and (source as ShaderMaterial).shader == SURFACE_SHADER):
		return source
	var m := source.duplicate() as ShaderMaterial
	m.shader = SURFACE_FAR_SHADER
	m.set_shader_parameter(&"horizon_color", horizon)
	return m
