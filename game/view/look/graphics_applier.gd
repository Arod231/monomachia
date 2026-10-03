class_name GraphicsApplier
extends RefCounted
## Applies a GraphicsPreset to the renderer, a viewport and a scene tree. It
## keeps no state: the preset in use is GameSettings'
## (GameServices.graphics_preset()). GameServices applies it to the renderer
## and the root viewport at start, and a scene applies it to its own tree
## with apply_to_tree() when it loads.
##
## The tree is found by convention, so arenas and fighters don't need to know
## about presets:
## - DirectionalLight3D nodes in group look_shadow_light get the shadow
##   settings;
## - Light3D nodes in group look_minor_light are shown or hidden;
## - GPUParticles3D nodes in group look_particles get the particle ratio;
## - Node3D nodes in group look_scenery_detail with meta look_detail (0..2)
##   are shown when the preset's scenery_detail reaches that level;
## - InkWashPass nodes get the post quality and the normal lines;
## - WorldEnvironment nodes get fog, height fog and glow, and the look's
##   colour grade (InkGrade) unless they bring their own;
## - every material made by ToonMaterials has its outline switched by its
##   OutlineKind.

const GROUP_SHADOW_LIGHT: StringName = &"look_shadow_light"
const GROUP_MINOR_LIGHT: StringName = &"look_minor_light"
const GROUP_PARTICLES: StringName = &"look_particles"
const GROUP_SCENERY: StringName = &"look_scenery_detail"
const META_DETAIL: StringName = &"look_detail"
## The environment's own height fog density, kept so a preset that turned it
## off can turn it back on.
const META_BASE_HEIGHT_FOG: StringName = &"look_base_height_fog"

const SHADOW_MODES: Dictionary[int, DirectionalLight3D.ShadowMode] = {
	1: DirectionalLight3D.SHADOW_ORTHOGONAL,
	2: DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
	4: DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
}


## Applies preset to the renderer (shadow atlas and filtering), to viewport
## (anti-aliasing and render scale) if given, and to every matching node
## under root if given.
static func apply(preset: GraphicsPreset, root: Node, viewport: Viewport = null) -> void:
	RenderingServer.directional_shadow_atlas_set_size(preset.shadow_atlas_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(preset.soft_shadow_quality)
	RenderingServer.positional_soft_shadow_filter_set_quality(preset.soft_shadow_quality)
	if viewport != null:
		apply_to_viewport(preset, viewport)
	if root != null:
		apply_to_tree(preset, root)


## Applies preset to root and every matching node under it, leaving the
## renderer and the viewport alone.
static func apply_to_tree(preset: GraphicsPreset, root: Node) -> void:
	var materials: Dictionary[Material, bool] = {}
	_walk(preset, root, materials)
	for material: Material in materials:
		var kind: ToonMaterials.OutlineKind = ToonMaterials.outline_kind_of(material)
		if kind != ToonMaterials.OutlineKind.NONE:
			ToonMaterials.set_outline(material, preset.outlines_on(kind), preset.outline_width_scale)


## Applies the preset's anti-aliasing and render scale to viewport.
static func apply_to_viewport(preset: GraphicsPreset, viewport: Viewport) -> void:
	viewport.msaa_3d = preset.msaa_3d
	viewport.screen_space_aa = preset.screen_space_aa
	viewport.scaling_3d_scale = preset.render_scale
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if is_equal_approx(preset.render_scale, 1.0) \
		else Viewport.SCALING_3D_MODE_FSR


static func _walk(preset: GraphicsPreset, node: Node, materials: Dictionary[Material, bool]) -> void:
	if node is DirectionalLight3D and node.is_in_group(GROUP_SHADOW_LIGHT):
		var sun := node as DirectionalLight3D
		sun.shadow_enabled = preset.shadows_enabled
		sun.directional_shadow_max_distance = preset.shadow_max_distance
		sun.directional_shadow_mode = SHADOW_MODES.get(preset.shadow_splits, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	if node is Light3D and node.is_in_group(GROUP_MINOR_LIGHT):
		(node as Light3D).visible = preset.minor_lights
	if node is GPUParticles3D and node.is_in_group(GROUP_PARTICLES):
		(node as GPUParticles3D).amount_ratio = preset.particle_ratio
	if node is Node3D and node.is_in_group(GROUP_SCENERY):
		(node as Node3D).visible = int(node.get_meta(META_DETAIL, 0)) <= preset.scenery_detail
	if node is InkWashPass:
		(node as InkWashPass).set_quality(preset.post_quality)
		(node as InkWashPass).set_normal_lines(preset.ink_normal_lines)
	if node is WorldEnvironment:
		_apply_environment(preset, (node as WorldEnvironment).environment)
	if node is GeometryInstance3D:
		_collect_materials(node as GeometryInstance3D, materials)
	for child: Node in node.get_children():
		_walk(preset, child, materials)


static func _apply_environment(preset: GraphicsPreset, env: Environment) -> void:
	if env == null:
		return
	if not env.has_meta(META_BASE_HEIGHT_FOG):
		env.set_meta(META_BASE_HEIGHT_FOG, env.fog_height_density)
	env.fog_enabled = preset.fog_enabled
	env.fog_height_density = float(env.get_meta(META_BASE_HEIGHT_FOG)) if preset.height_fog else 0.0
	env.glow_enabled = preset.glow_enabled
	if env.adjustment_color_correction == null:
		InkGrade.apply(env)


## Every material geo draws with: its override, its surface overrides and its
## mesh's own surface materials.
static func _collect_materials(geo: GeometryInstance3D, materials: Dictionary[Material, bool]) -> void:
	if geo.material_override != null:
		materials[geo.material_override] = true
	var source: Mesh = null
	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		source = mi.mesh
		for s: int in mi.get_surface_override_material_count():
			var m: Material = mi.get_surface_override_material(s)
			if m != null:
				materials[m] = true
	elif geo is MultiMeshInstance3D:
		var mm: MultiMesh = (geo as MultiMeshInstance3D).multimesh
		if mm != null:
			source = mm.mesh
	if source != null:
		for s: int in source.get_surface_count():
			var m: Material = source.surface_get_material(s)
			if m != null:
				materials[m] = true

