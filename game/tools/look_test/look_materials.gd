class_name LookMaterials
extends RefCounted
## The look test's materials (milestone-1 task 30): turns a tree drawn in the
## toon look into physically based materials, in the look test only. The
## game keeps the toon look until the art conversion (the owner's choice,
## Oct 5).
##
## - A toon material (ToonMaterials: toon.gdshader or its two-sided twin)
##   becomes a StandardMaterial3D with its base colour, texture, normal map
##   and emission, rough cloth and leather on a fighter (FIGHTER_SURFACE),
##   worn metal on a weapon's fittings (WEAPON_SURFACE), plain stone and wood
##   on a prop (PROP_SURFACE).
## - A shader lit by toon_light.gdshaderinc (the stone floor, the rock, the
##   Katana's blade and wrap) is copied with PBR_LIGHT in its place, which
##   keeps its uniforms but drops its light(), so Godot's physically based
##   lighting lights it; its own ROUGHNESS and METALLIC give way to the
##   look_roughness and look_metallic uniforms, set per shader (SURFACES).
## - Outline passes (next_pass) go from every material, toon or not: the
##   realistic look has no ink lines.

const PBR_LIGHT: String = "res://tools/look_test/pbr_light.gdshaderinc"
const TOON_LIGHT: String = "res://shaders/toon_light.gdshaderinc"

## [roughness, metallic] by surface.
const FIGHTER_SURFACE: Array[float] = [0.82, 0.0]
const WEAPON_SURFACE: Array[float] = [0.42, 0.85]
const PROP_SURFACE: Array[float] = [0.88, 0.0]
## [roughness, metallic] for each re-lit shader, by its file; others PROP_SURFACE.
const SURFACES: Dictionary[String, Array] = {
	"res://weapons/katana/katana_blade.gdshader": [0.2, 1.0],
	"res://weapons/katana/katana_wrap.gdshader": [0.75, 0.0],
	"res://shaders/stone_floor.gdshader": [0.86, 0.0],
	"res://shaders/rock.gdshader": [0.92, 0.0],
}

## Each re-lit shader, by the original.
var _shaders: Dictionary[Shader, Shader] = {}
## Each converted material, by the original, so shared materials stay shared.
var _done: Dictionary[Material, Material] = {}
## How many materials it converted, by kind ("standard", "relit").
var counts: Dictionary[String, int] = {"standard": 0, "relit": 0}


## Converts every material under `root` (overrides, surface overrides and
## the meshes' own surfaces, set as surface overrides).
func convert_tree(root: Node) -> void:
	if root is GeometryInstance3D:
		_convert_geometry(root as GeometryInstance3D)
	for child: Node in root.get_children():
		convert_tree(child)


func _convert_geometry(g: GeometryInstance3D) -> void:
	if g.material_override != null:
		g.material_override = physical(g.material_override)
	if g is MeshInstance3D:
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi.mesh == null:
			return
		for i: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			if m != null:
				mi.set_surface_override_material(i, physical(m))


## The physically based material for `m`: converted once, then shared.
func physical(m: Material) -> Material:
	if _done.has(m):
		return _done[m]
	var out: Material = m
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var sm: ShaderMaterial = m as ShaderMaterial
		if sm.shader == ToonMaterials.TOON_SHADER or sm.shader == ToonMaterials.TOON_TWO_SIDED_SHADER:
			out = _standard(sm)
			counts["standard"] += 1
		elif sm.shader.code.contains(TOON_LIGHT):
			out = _relit(sm)
			counts["relit"] += 1
	if out == m and m.next_pass is ShaderMaterial and (m.next_pass as ShaderMaterial).shader == ToonMaterials.OUTLINE_SHADER:
		out = m.duplicate() as Material
		_unlined(out)
	_done[m] = out
	_done[out] = out
	return out


## Drops a copy's outline pass and the marks by which GraphicsApplier would
## give it back (ToonMaterials.META_OUTLINE, META_KIND).
static func _unlined(m: Material) -> void:
	m.next_pass = null
	for key: StringName in [ToonMaterials.META_OUTLINE, ToonMaterials.META_KIND]:
		if m.has_meta(key):
			m.remove_meta(key)


## A toon material as a StandardMaterial3D.
func _standard(sm: ShaderMaterial) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	var base: Variant = sm.get_shader_parameter(&"base_color")
	s.albedo_color = base if base is Color else Color(0.72, 0.70, 0.66)
	var tex: Variant = sm.get_shader_parameter(&"albedo_texture")
	if tex is Texture2D:
		s.albedo_texture = tex
	var normal: Variant = sm.get_shader_parameter(&"normal_texture")
	var strength: Variant = sm.get_shader_parameter(&"normal_strength")
	if normal is Texture2D and strength is float and float(strength) > 0.0:
		s.normal_enabled = true
		s.normal_texture = normal
		s.normal_scale = float(strength)
	var energy: Variant = sm.get_shader_parameter(&"emission_energy")
	if energy is float and float(energy) > 0.0:
		s.emission_enabled = true
		s.emission = sm.get_shader_parameter(&"emission_color")
		s.emission_energy_multiplier = float(energy)
	if sm.get_shader_parameter(&"use_vertex_color") == true:
		s.vertex_color_use_as_albedo = true
	if sm.shader == ToonMaterials.TOON_TWO_SIDED_SHADER:
		s.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface: Array[float] = PROP_SURFACE
	match ToonMaterials.outline_kind_of(sm):
		ToonMaterials.OutlineKind.FIGHTER:
			surface = FIGHTER_SURFACE
		ToonMaterials.OutlineKind.WEAPON:
			surface = WEAPON_SURFACE
	s.roughness = surface[0]
	s.metallic = surface[1]
	s.metallic_specular = 0.5
	return s


## A copy of a toon-lit shader material, lit physically.
func _relit(sm: ShaderMaterial) -> ShaderMaterial:
	var out := sm.duplicate() as ShaderMaterial
	_unlined(out)
	out.shader = _relit_shader(sm.shader)
	var surface: Array = SURFACES.get(sm.shader.resource_path, PROP_SURFACE)
	out.set_shader_parameter(&"look_roughness", float(surface[0]))
	out.set_shader_parameter(&"look_metallic", float(surface[1]))
	return out


## `shader` with the toon lighting swapped for PBR_LIGHT, its own roughness
## and metallic for the look's uniforms.
func _relit_shader(shader: Shader) -> Shader:
	if _shaders.has(shader):
		return _shaders[shader]
	var code: String = shader.code.replace(TOON_LIGHT, PBR_LIGHT)
	var re := RegEx.create_from_string("(?m)^\\s*(ROUGHNESS|METALLIC)\\s*=[^;]*;\\s*$")
	code = re.sub(code, "", true)
	code = code.replace("void fragment() {", "void fragment() {\n\tROUGHNESS = look_roughness;\n\tMETALLIC = look_metallic;")
	var out := Shader.new()
	out.code = code
	_shaders[shader] = out
	return out
