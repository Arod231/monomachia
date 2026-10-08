extends GutTest
## The Moonlit Shrine's distant landscape in real 3D (milestone-1 task 51,
## ShrineBackdrop): today's rings of mountains and cliff spires, sculpted in
## Blender from the arena's own numbers (landscape.json, which must match
## them) and brought in by the export, lit rock in the paving's scans, each
## with a lighter twin that Low draws in its place; the far buildings fading
## with their rock; and the sea of clouds a volume the moon lights on Ultra
## and High, its mesh layers on Medium and Low.

const SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"
const SPEC := "res://../scripts/blender/shrine/landscape.json"

var arena: MoonlitShrine
var _services: Node


func before_all() -> void:
	_services = get_tree().root.get_node("GameServices")
	arena = (load(SCENE) as PackedScene).instantiate()
	add_child(arena)


func after_all() -> void:
	GraphicsApplier.apply_to_tree(_services.call("graphics_preset"), arena)
	arena.free()


func _world_vertices(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s: int in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			out.append(mi.global_transform * v)
	return out


func _faces(mi: MeshInstance3D) -> int:
	var n: int = 0
	for s: int in mi.mesh.get_surface_count():
		n += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


## The highest point in each sector (degrees wide) round the shrine.
func _skyline(mi: MeshInstance3D, sector: float) -> Dictionary[int, float]:
	var out: Dictionary[int, float] = {}
	for v: Vector3 in _world_vertices(mi):
		var k: int = floori(fposmod(rad_to_deg(atan2(v.x, v.z)), 360.0) / sector)
		out[k] = maxf(out.get(k, -INF), v.y)
	return out


## Whether a and b match, numbers within tol, all the way down.
func _same(a: Variant, b: Variant, tol: float, at: String) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > tol:
			fail_test("%s: %s, the arena says %s" % [at, a, b])
			return false
		return true
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			fail_test("%s: keys %s, the arena's %s" % [at, (a as Dictionary).keys(), (b as Dictionary).keys()])
			return false
		for k: Variant in b:
			if not (a as Dictionary).has(k) or not _same(a[k], b[k], tol, "%s.%s" % [at, k]):
				return false
		return true
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			fail_test("%s: %d items, the arena's %d" % [at, (a as Array).size(), (b as Array).size()])
			return false
		for i: int in (b as Array).size():
			if not _same(a[i], b[i], tol, "%s[%d]" % [at, i]):
				return false
		return true
	if a != b:
		fail_test("%s: %s, the arena says %s" % [at, a, b])
		return false
	return true


func test_the_landscape_is_sculpted_from_the_arenas_own_numbers() -> void:
	var committed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(SPEC)))
	assert_true(committed is Dictionary, "landscape.json is there")
	var now: Variant = JSON.parse_string(JSON.stringify(ShrineBackdrop.landscape_spec(arena.layout)))
	assert_true(_same(committed, now, 1e-3, "landscape.json"),
		"landscape.json matches the arena (else run export_landscape_spec.gd, rebuild and export the landscape)")


func test_every_range_and_spire_is_the_landscape_model_with_a_lighter_twin() -> void:
	var pairs: Array[MeshInstance3D] = []
	for i: int in arena.layout.mountain_layers.size():
		pairs.append(arena.get_node("World/Mountains/Range%d" % i) as MeshInstance3D)
	for i: int in arena.layout.cliffs.size():
		pairs.append(arena.get_node("World/Cliffs/Spire%d" % i) as MeshInstance3D)
	for full: MeshInstance3D in pairs:
		var light := full.get_parent().get_node(NodePath(String(full.name) + "Low")) as MeshInstance3D
		assert_not_null(light, "%s has its lighter twin" % full.name)
		assert_true(full.mesh.resource_path.begins_with(ShrineBackdrop.MODEL) or full.mesh.resource_path.is_empty(),
			"%s is the model's" % full.name)
		assert_lt(_faces(light), _faces(full) * 0.35, "%s's twin is lighter" % full.name)
		assert_eq(full.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "far scenery casts no shadow")
		assert_eq(light.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		for mi: MeshInstance3D in [full, light]:
			var m := mi.material_override as ShaderMaterial
			assert_eq(m.shader, ShrineBackdrop.LANDSCAPE, "%s is the landscape's rock" % mi.name)
			assert_not_null(m.get_shader_parameter(&"stone_albedo"), "in the paving's scan")
			assert_not_null(m.get_shader_parameter(&"grime_albedo"), "with its moss")


## The lighter twin keeps the silhouette: its skyline within 8% of the
## range's height over the clouds in every 2-degree sector (it keeps every
## other point of the crest, so only the finest jags between them go; under
## a degree seen from the courtyard).
func test_the_lighter_ranges_keep_their_skyline() -> void:
	var cloud: float = arena.layout.cloud_sea_height
	for i: int in arena.layout.mountain_layers.size():
		var full: Dictionary[int, float] = _skyline(arena.get_node("World/Mountains/Range%d" % i) as MeshInstance3D, 2.0)
		var light: Dictionary[int, float] = _skyline(arena.get_node("World/Mountains/Range%dLow" % i) as MeshInstance3D, 2.0)
		var height: float = full.values().max() - cloud
		var worst: float = 0.0
		for k: int in full:
			worst = maxf(worst, absf(full[k] - light.get(k, -INF)) / height)
		assert_lt(worst, 0.08, "Range%dLow keeps Range%d's skyline" % [i, i])


## Real 3D: each range has depth (its face reaches well in from its crest) and
## its crest is the spec's, roughened only a little where it stands clear of
## the moon.
func test_the_ranges_have_depth_and_keep_the_specs_crest() -> void:
	var spec: Dictionary = ShrineBackdrop.landscape_spec(arena.layout)
	var cloud: float = arena.layout.cloud_sea_height
	for i: int in arena.layout.mountain_layers.size():
		var mi := arena.get_node("World/Mountains/Range%d" % i) as MeshInstance3D
		var near: float = INF
		var far: float = 0.0
		for v: Vector3 in _world_vertices(mi):
			var r: float = Vector2(v.x, v.z).length()
			near = minf(near, r)
			far = maxf(far, r)
		var d: float = arena.layout.mountain_layers[i].x
		assert_gt(far - near, d * 0.25, "Range%d has depth" % i)
		var sky: Dictionary[int, float] = _skyline(mi, 2.0)
		var points: Array = spec["ranges"][i]["crest"]
		for k: int in sky:
			# the spec's crest in the sector, and with half a degree either
			# side (a point on its edge belongs to both)
			var inside: float = -INF
			var round_it: float = -INF
			for p: Array in points:
				var a: float = fposmod(rad_to_deg(atan2(float(p[0]), float(p[2]))), 360.0)
				var off: float = angle_difference(deg_to_rad(k * 2.0 + 1.0), deg_to_rad(a))
				if absf(rad_to_deg(off)) <= 1.0:
					inside = maxf(inside, float(p[1]))
				if absf(rad_to_deg(off)) <= 1.5:
					round_it = maxf(round_it, float(p[1]))
			var tol: float = maxf(round_it - cloud, 10.0) * 0.12 + 1.0
			assert_lt(sky[k], round_it + tol, "Range%d's crest at %d degrees, no higher than the spec's" % [i, k * 2])
			assert_gt(sky[k], inside - tol, "Range%d's crest at %d degrees, no lower" % [i, k * 2])


## Each spire's top is flat out to most of its radius at its layout height,
## where its buildings stand.
func test_the_spires_tops_are_flat_where_their_buildings_stand() -> void:
	for i: int in arena.layout.cliffs.size():
		var c: Vector4 = arena.layout.cliffs[i]
		var centre: Vector3 = ShrineLayout.polar(c.x, c.y)
		var on_top: int = 0
		for v: Vector3 in _world_vertices(arena.get_node("World/Cliffs/Spire%d" % i) as MeshInstance3D):
			if Vector2(v.x - centre.x, v.z - centre.z).length() < c.w * 0.65:
				on_top += 1
				assert_almost_eq(v.y, c.z, 0.02, "Spire%d's top at its height" % i)
				if absf(v.y - c.z) > 0.02:
					break
		assert_gt(on_top, 10, "Spire%d has a top" % i)


func test_the_far_buildings_fade_with_their_rock() -> void:
	var sea := (arena.get_node("World/CloudSea") as MeshInstance3D).material_override as ShaderMaterial
	var horizon: Color = sea.get_shader_parameter(&"horizon_color")
	var found: int = 0
	for building: Node in arena.get_node("World/Cliffs").get_children():
		var body := building.get_node_or_null(^"Body") as MeshInstance3D
		if body == null:
			continue
		found += 1
		for s: int in body.get_surface_override_material_count():
			var m := body.get_surface_override_material(s) as ShaderMaterial
			if m.shader == LookMaterials.SURFACE_SHADER or m.shader == LookMaterials.SURFACE_FAR_SHADER:
				assert_eq(m.shader, LookMaterials.SURFACE_FAR_SHADER, "%s fades like its rock" % building.name)
				assert_true(LookMaterials.is_physical(m), "and stays a look surface")
	assert_gt(found, 0, "the cliffs carry buildings")
	var rock := (arena.get_node("World/Mountains/Range0") as MeshInstance3D).material_override as ShaderMaterial
	assert_eq(rock.get_shader_parameter(&"horizon_color"), horizon, "into the horizon's mist, as the clouds")


func test_the_presets_choose_the_cloud_volume_or_layers_and_the_landscapes_models() -> void:
	for id: StringName in GraphicsPreset.IDS:
		var preset: GraphicsPreset = GraphicsPreset.load_id(id)
		GraphicsApplier.apply_to_tree(preset, arena)
		var volume: bool = preset.volumetric_clouds
		assert_eq((arena.get_node("World/CloudVolume") as Node3D).visible, volume, "%s: the volume" % id)
		assert_eq((arena.get_node("World/CloudSea") as Node3D).visible, not volume, "%s: the sea's layer" % id)
		assert_eq((arena.get_node("World/CloudVeil") as Node3D).visible, not volume, "%s: the veil" % id)
		var light: bool = preset.light_landscape
		assert_eq((arena.get_node("World/Mountains/Range2") as Node3D).visible, not light, "%s: the full range" % id)
		assert_eq((arena.get_node("World/Mountains/Range2Low") as Node3D).visible, light, "%s: the lighter range" % id)
		assert_eq((arena.get_node("World/Cliffs/Spire1Low") as Node3D).visible, light, "%s: the lighter spire" % id)


## Every ray starts above the cloud: the volume's disc stands, at each
## distance, over the highest top its shader can reach there (the billows
## and the fog banks between the ranges).
func test_the_cloud_volumes_disc_stands_over_every_top_the_cloud_can_reach() -> void:
	var mi := arena.get_node("World/CloudVolume") as MeshInstance3D
	var m := mi.material_override as ShaderMaterial
	assert_eq(m.shader, ShrineBackdrop.CLOUD_VOLUME)
	var top: float = m.get_shader_parameter(&"cloud_top")
	var billow: float = m.get_shader_parameter(&"billow")
	var radii: Vector4 = m.get_shader_parameter(&"bank_radii")
	var heights: Vector4 = m.get_shader_parameter(&"bank_heights")
	var width: float = m.get_shader_parameter(&"bank_width")
	assert_gt(heights[0], 0.0, "fog banks rise between the ranges")
	var rings: PackedVector4Array = arena.layout.mountain_layers
	assert_almost_eq(radii[0], (rings[0].x + rings[1].x) * 0.5, 0.01, "midway between the first two ranges")
	for v: Vector3 in _world_vertices(mi):
		var r: float = Vector2(v.x, v.z).length()
		var highest: float = top + billow
		for i: int in 4:
			var d: float = (r - radii[i]) / width
			# the shader's banks rise by up to 1.45 times their height
			highest += heights[i] * 1.45 * exp(-d * d)
		if v.y < highest:
			fail_test("the disc at %.0f m lies under the cloud's highest top there (%.1f < %.1f)" % [r, v.y, highest])
			return
	pass_test("the disc stands over the cloud everywhere")
