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
## - CombatEffects nodes take the preset (their particle counts);
## - Node3D nodes in group look_scenery_detail with meta look_detail (0..2)
##   are shown when the preset's scenery_detail reaches that level;
## - Light3D nodes in group look_petal_light (the petals' lights) and Decal
##   nodes in group look_minor_decal are shown or hidden;
## - InkWashPass nodes get the post quality and the normal lines;
## - WorldEnvironment nodes get fog, height fog and glow, volumetric fog and
##   ambient occlusion (only where the environment had them), and the look's
##   colour grade (InkGrade) unless they bring their own;
## - SubViewports in group graphics_viewports (Versus's split-screen halves)
##   get the anti-aliasing and render scale, as the root viewport does
##   (apply_to_group(); GameServices.apply_graphics() calls it);
## - every material made by ToonMaterials has its outline switched by its
##   OutlineKind.

## Viewports besides the root that draw the match (SplitView's halves).
const VIEWPORTS_GROUP: StringName = &"graphics_viewports"
const GROUP_SHADOW_LIGHT: StringName = &"look_shadow_light"
const GROUP_MINOR_LIGHT: StringName = &"look_minor_light"
const GROUP_PARTICLES: StringName = &"look_particles"
const GROUP_SCENERY: StringName = &"look_scenery_detail"
const GROUP_PETAL_LIGHT: StringName = &"look_petal_light"
const GROUP_MINOR_DECAL: StringName = &"look_minor_decal"
const META_DETAIL: StringName = &"look_detail"
## The environment's own height fog density, kept so a preset that turned it
## off can turn it back on.
const META_BASE_HEIGHT_FOG: StringName = &"look_base_height_fog"
## Whether the environment itself had volumetric fog and ambient occlusion,
## kept so a preset turns on only what the arena brings.
const META_BASE_VOLUMETRIC: StringName = &"look_base_volumetric_fog"
const META_BASE_SSAO: StringName = &"look_base_ssao"

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


## Applies the preset's anti-aliasing, render scale and upscaler to every
## viewport in VIEWPORTS_GROUP.
static func apply_to_group(preset: GraphicsPreset, tree: SceneTree) -> void:
	for node: Node in tree.get_nodes_in_group(VIEWPORTS_GROUP):
		if node is Viewport:
			apply_to_viewport(preset, node as Viewport)


## Applies the preset's anti-aliasing, render scale and upscaler to viewport.
static func apply_to_viewport(preset: GraphicsPreset, viewport: Viewport) -> void:
	viewport.msaa_3d = preset.msaa_3d
	viewport.screen_space_aa = preset.screen_space_aa
	viewport.scaling_3d_scale = preset.render_scale
	viewport.scaling_3d_mode = preset.scaling_3d_mode


static func _walk(preset: GraphicsPreset, node: Node, materials: Dictionary[Material, bool]) -> void:
	if node is DirectionalLight3D and node.is_in_group(GROUP_SHADOW_LIGHT):
		var sun := node as DirectionalLight3D
		sun.shadow_enabled = preset.shadows_enabled
		sun.directional_shadow_max_distance = preset.shadow_max_distance
		sun.directional_shadow_mode = SHADOW_MODES.get(preset.shadow_splits, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	if node is Light3D and node.is_in_group(GROUP_MINOR_LIGHT):
		(node as Light3D).visible = preset.minor_lights
	if node is Light3D and node.is_in_group(GROUP_PETAL_LIGHT):
		(node as Light3D).visible = preset.petal_lights
	if node is Decal and node.is_in_group(GROUP_MINOR_DECAL):
		(node as Decal).visible = preset.minor_decals
	if node is GPUParticles3D and node.is_in_group(GROUP_PARTICLES):
		(node as GPUParticles3D).amount_ratio = preset.particle_ratio
	if node is CombatEffects:
		(node as CombatEffects).set_preset(preset)
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
		env.set_meta(META_BASE_VOLUMETRIC, env.volumetric_fog_enabled)
		env.set_meta(META_BASE_SSAO, env.ssao_enabled)
	env.volumetric_fog_enabled = bool(env.get_meta(META_BASE_VOLUMETRIC, false)) and preset.volumetric_fog
	env.ssao_enabled = bool(env.get_meta(META_BASE_SSAO, false)) and preset.ambient_occlusion
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

