class_name InkWashPass
extends MeshInstance3D
## The full-screen ink-wash pass: a 2x2 quad whose shader covers the screen
## from any camera. Add one anywhere in the 3D scene.
##
## It paints over the image with premultiplied alpha (mist fade, ink lines,
## paper grain, vignette) and never reads the screen colour, so Godot doesn't
## copy the screen for it. The colour grade is a LUT in the Environment
## (InkGrade), applied for free in the tonemap pass.
##
## The shader is ink_wash_lite.gdshader (ink lines at depth breaks) unless
## normal_lines is on and lines are drawn: then it is ink_wash.gdshader, which
## also draws lines at normal breaks but makes the depth prepass write the
## normal buffer for every object.
##
## Why a quad and not a CompositorEffect: the spatial shader gets the depth
## and normal-roughness textures for free on Forward+, needs no
## RenderingDevice code, and degrades to nothing headless. It runs at the
## start of the transparent pass (render_priority -128), so particles, mist
## and water drawn after it keep their own colours; that suits glowing embers
## and is the one thing a CompositorEffect at POST_TRANSPARENT would do
## differently. Measured on the target laptop, a pass that copied the screen
## cost about 9 ms at 1080p with MSAA; this one costs a fraction of that.

## What the pass draws; each level adds to the one before.
enum Quality {
	OFF = 0, ## no pass at all
	LITE = 1, ## distance mist, paper grain and vignette
	LINES = 2, ## plus ink lines at depth breaks
	FULL = 3, ## plus line jitter, dry-brush breaks and an ink bleed halo
}

## The variant that also draws lines at normal breaks, and the depth-only one.
const SHADER_NORMALS: Shader = preload("res://shaders/ink_wash.gdshader")
const SHADER_DEPTH: Shader = preload("res://shaders/ink_wash_lite.gdshader")
const GROUP: StringName = &"look_post"
## The ink lines' width in pixels and their strength (coverage at a full
## break, blended in linear light, so 0.85 reads about 0.43 on white). The
## owner picked 2 px at 0.85 from look bench renders on Oct 1; at 1.2 px the
## lines barely read at a duel's distance, and at 3 px they turn ragged.
const LINE_WIDTH_PX: float = 2.0
const LINE_STRENGTH: float = 0.85

@export var quality: Quality = Quality.FULL:
	set = set_quality
## Also draw lines at normal breaks (creases inside a silhouette), at the cost
## of the normal buffer.
@export var normal_lines: bool = false:
	set = set_normal_lines

var _material: ShaderMaterial
## Parameters set through set_param, kept so they survive a shader swap.
var _params: Dictionary[StringName, Variant] = {}


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	_material = ShaderMaterial.new()
	_material.render_priority = Material.RENDER_PRIORITY_MIN
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	ignore_occlusion_culling = true
	extra_cull_margin = 16384.0
	add_to_group(GROUP)
	_update_shader()
	set_param(LookNoise.PARAM, LookNoise.texture())
	set_param(&"line_width_px", LINE_WIDTH_PX)
	set_param(&"line_strength", LINE_STRENGTH)


## Sets what the pass draws; OFF hides it.
func set_quality(value: Quality) -> void:
	quality = value
	visible = value != Quality.OFF
	_update_shader()


## Turns the lines at normal breaks on or off (they draw only from LINES up).
func set_normal_lines(value: bool) -> void:
	normal_lines = value
	_update_shader()


## Whether the ink-wash shader has a parameter called param (in either
## variant: a normal-line parameter set now survives a swap to them).
func has_param(param: StringName) -> bool:
	for u: Dictionary in SHADER_NORMALS.get_shader_uniform_list():
		if u[&"name"] == param:
			return true
	return false


## Sets one ink-wash shader parameter (colours, thresholds, fade...). A name
## the shader doesn't declare is an error, since it would set nothing.
func set_param(param: StringName, value: Variant) -> void:
	if not has_param(param):
		push_error("InkWashPass: the ink-wash shader has no parameter '%s'" % param)
		return
	_params[param] = value
	_material.set_shader_parameter(param, value)


## The pass's material, typed (material_override holds the same one).
func get_material() -> ShaderMaterial:
	return _material


func _update_shader() -> void:
	if _material == null:
		return
	var with_normals: bool = normal_lines and quality >= Quality.LINES
	var shader: Shader = SHADER_NORMALS if with_normals else SHADER_DEPTH
	if _material.shader != shader:
		_material.shader = shader
		for key: StringName in _params:
			_material.set_shader_parameter(key, _params[key])
	_material.set_shader_parameter(&"quality", clampi(quality, Quality.LITE, Quality.FULL))
