class_name ToonMaterials
extends RefCounted
## Makes the shared toon material and its ink outline, for fighters, weapons
## and props alike. Every material remembers its outline pass and its outline
## kind (metadata), so the graphics presets can switch outlines per kind.
##
## Outline choice (see docs/specs/godot-rebuild.md, "Look"):
## - Fighters and weapons: inverted hull (outline.gdshader). It draws inner
##   contours (an arm across the torso, a blade over the body), keeps a
##   constant on-screen width at any camera distance, takes the material's own
##   ink colour, and works with the custom toon shader. Always on.
## - Props: the same hull, with smoothed normals baked by MeshKit, on High
##   only. It gives architecture a heavier silhouette stroke over the ink-wash
##   pass's thin crease lines. On Medium and Low the ink-wash pass (or nothing)
##   draws prop lines, which costs no extra geometry pass.
## - The built-in STENCIL_MODE_OUTLINE was evaluated and not used for
##   outlines: it draws the silhouette only (no inner lines), its thickness is
##   fixed in metres (thin far away, fat up close), it needs a
##   StandardMaterial3D rather than this shader, and a stencil read forces the
##   pass into the transparent queue. Its sibling STENCIL_MODE_XRAY is the
##   right tool later for showing a fighter hidden behind a pillar.

## What an outline is drawn for: each kind has its own width, and the
## graphics presets switch kinds on and off.
enum OutlineKind { NONE, FIGHTER, WEAPON, PROP }

const TOON_SHADER: Shader = preload("res://shaders/toon.gdshader")
## The same toon surface drawn from both sides, for open shells (hoods, cloth
## edges, hair cards).
const TOON_TWO_SIDED_SHADER: Shader = preload("res://shaders/toon_two_sided.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/outline.gdshader")

const META_OUTLINE: StringName = &"look_outline"
const META_KIND: StringName = &"look_outline_kind"

## Outline width in pixels at 1080p, per kind (the owner's pick from the look
## bench).
const OUTLINE_WIDTH: Dictionary[OutlineKind, float] = {
	OutlineKind.FIGHTER: 3.0,
	OutlineKind.WEAPON: 2.4,
	OutlineKind.PROP: 2.25,
}


## A toon material with base colour color. params are shader parameters to
## set (for example {&"rim_strength": 0.8}). ink is the outline and wash colour.
static func make(color: Color, kind: OutlineKind = OutlineKind.PROP, params: Dictionary = {},
		ink: Color = LookPalette.INK) -> ShaderMaterial:
	return make_with_shader(TOON_SHADER, kind, params.merged({&"base_color": color}), ink)


## Like make(), for another shader that includes toon_light.gdshaderinc (the
## stone floor, rock).
static func make_with_shader(shader: Shader, kind: OutlineKind, params: Dictionary = {},
		ink: Color = LookPalette.INK) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"ink_color", ink)
	LookNoise.apply_to(m)
	for key: Variant in params:
		m.set_shader_parameter(key, params[key])
	m.set_meta(META_KIND, kind)
	if kind != OutlineKind.NONE:
		var outline: ShaderMaterial = make_outline(ink, OUTLINE_WIDTH[kind])
		m.set_meta(META_OUTLINE, outline)
		m.next_pass = outline
	return m


## A fighter's lighting: strong rim, a little fresnel glow, less brush noise
## (clean reads beat painterly ones on the fighters), and no hard highlight
## on cloth, leather or skin.
const FIGHTER_PARAMS: Dictionary = {
	&"rim_strength": 0.6,
	&"rim_width": 0.2,
	&"rim_emission": 0.1,
	&"brush_noise": 0.05,
	&"shadow_fill": 0.16,
	&"specular_strength": 0.0,
}
## How much of an imported normal map a fighter keeps: fine bumps would break
## the toon bands into noise.
const FIGHTER_NORMAL_STRENGTH: float = 0.4
## A weapon: rim, no brush noise, and (WEAPON_METAL_PARAMS) a hard toon
## highlight for steel.
const WEAPON_PARAMS: Dictionary = {
	&"rim_strength": 0.8,
	&"rim_width": 0.3,
	&"brush_noise": 0.0,
	&"specular_strength": 0.0,
}
const WEAPON_METAL_PARAMS: Dictionary = {
	&"specular_strength": 1.6,
	&"specular_size": 0.06,
}


## A fighter's cloth or skin in one colour.
static func fighter(color: Color, ink: Color = LookPalette.INK) -> ShaderMaterial:
	return make(color, OutlineKind.FIGHTER, FIGHTER_PARAMS, ink)


## A fighter surface from the material it was imported with: its colour,
## base-colour texture, normal map and vertex colour carried over, drawn from
## both sides when the import is. Its name is kept, so the palettes still
## find the outfit by name.
static func fighter_from(source: BaseMaterial3D, ink: Color = LookPalette.INK) -> ShaderMaterial:
	var two_sided: bool = source.cull_mode == BaseMaterial3D.CULL_DISABLED
	var params: Dictionary = FIGHTER_PARAMS.merged({
		&"base_color": source.albedo_color,
		&"albedo_texture": source.albedo_texture,
		&"use_vertex_color": source.vertex_color_use_as_albedo,
		&"normal_strength": 0.0,
	}, true)
	if source.normal_enabled and source.normal_texture != null:
		params[&"normal_texture"] = source.normal_texture
		params[&"normal_strength"] = source.normal_scale * FIGHTER_NORMAL_STRENGTH
	var m: ShaderMaterial = make_with_shader(TOON_TWO_SIDED_SHADER if two_sided else TOON_SHADER,
		OutlineKind.FIGHTER, params, ink)
	m.resource_name = source.resource_name
	return m


## A weapon: hard toon highlight for steel, thinner outline.
static func weapon(color: Color, metal: bool = true) -> ShaderMaterial:
	return make(color, OutlineKind.WEAPON, WEAPON_PARAMS.merged(WEAPON_METAL_PARAMS, true) if metal else WEAPON_PARAMS)


## A weapon surface from the material its model was made with, keeping its
## name:
## - a StandardMaterial3D becomes toon steel (with the highlight) when it is
##   at all metallic, and toon leather or wood otherwise, in its colour;
## - a ShaderMaterial whose shader is toon-lit (includes
##   toon_light.gdshaderinc, like the Katana's blade and wrap) is copied with
##   the weapon's rim and outline, and every parameter the source sets (its
##   own colours, a highlight it asks for) kept.
static func weapon_from(source: Material) -> ShaderMaterial:
	var m: ShaderMaterial
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		m = weapon(base.albedo_color, base.metallic > 0.0)
	else:
		var shaded := source as ShaderMaterial
		var params: Dictionary = WEAPON_PARAMS.duplicate()
		for u: Dictionary in shaded.shader.get_shader_uniform_list():
			var value: Variant = shaded.get_shader_parameter(u[&"name"])
			if value != null:
				params[StringName(u[&"name"])] = value
		m = make_with_shader(shaded.shader, OutlineKind.WEAPON, params)
	m.resource_name = source.resource_name
	return m


## Whether material was made here (by make() or make_with_shader()), so it
## carries the look's outline kind.
static func is_toon(material: Material) -> bool:
	return material is ShaderMaterial and material.has_meta(META_KIND)


## A prop: painterly wash stains and no rim (a floor seen at a grazing angle
## would glow), outlined as a PROP, or not at all for distant scenery.
static func prop(color: Color, wash: float = 0.35, outlined: bool = true, ink: Color = LookPalette.INK) -> ShaderMaterial:
	return make(color, OutlineKind.PROP if outlined else OutlineKind.NONE, {
		&"wash_amount": wash,
		&"rim_strength": 0.0,
		&"use_vertex_color": true,
	}, ink)


## An ink outline pass on its own.
static func make_outline(ink: Color, width_px: float) -> ShaderMaterial:
	var o := ShaderMaterial.new()
	o.shader = OUTLINE_SHADER
	o.set_shader_parameter(&"ink_color", ink)
	o.set_shader_parameter(&"width_px", width_px)
	return o


## The outline kind a material was made with (NONE for any other material).
static func outline_kind_of(material: Material) -> OutlineKind:
	if material == null or not material.has_meta(META_KIND):
		return OutlineKind.NONE
	return material.get_meta(META_KIND) as OutlineKind


## Turns a material's outline pass on or off, at width_scale times its kind's
## width. A material made without an outline is left alone.
static func set_outline(material: Material, enabled: bool, width_scale: float = 1.0) -> void:
	if material == null or not material.has_meta(META_OUTLINE):
		return
	var outline: ShaderMaterial = material.get_meta(META_OUTLINE)
	outline.set_shader_parameter(&"width_px", OUTLINE_WIDTH[outline_kind_of(material)] * width_scale)
	material.next_pass = outline if enabled else null


## True while a material's outline pass is switched on.
static func is_outlined(material: Material) -> bool:
	return material != null and material.has_meta(META_OUTLINE) and material.next_pass == material.get_meta(META_OUTLINE)
