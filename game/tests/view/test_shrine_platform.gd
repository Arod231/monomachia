extends GutTest
## The Shrine's modelled platform (milestone-1 task 50): the paving's slabs
## where the floor's shader draws its joints, tilted and sunk by up to
## 1.5 cm, never above the rules' floor; the curb stones round the rim; the
## parapet remodelled at today's footprint; the gates' landings and steps;
## all the project's own model, built in Blender from the arena's own numbers
## (platform.json, which must match them), the arena's data unchanged.

const SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"
const SPEC := "res://../scripts/blender/shrine/platform.json"

var arena: MoonlitShrine


func before_all() -> void:
	arena = (load(SCENE) as PackedScene).instantiate()
	add_child(arena)


func after_all() -> void:
	arena.free()


## Whether a and b match, numbers within tol, all the way down.
func _same(a: Variant, b: Variant, tol: float, at: String) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > tol:
			fail_test("%s: %s, the arena says %s" % [at, a, b])
			return false
		return true
	if a is Dictionary and b is Dictionary:
		var ok: bool = (a as Dictionary).size() == (b as Dictionary).size()
		if not ok:
			fail_test("%s: keys %s, the arena's %s" % [at, (a as Dictionary).keys(), (b as Dictionary).keys()])
		for k: Variant in b:
			if not (a as Dictionary).has(k):
				fail_test("%s: no %s" % [at, k])
				ok = false
			elif not _same(a[k], b[k], tol, "%s.%s" % [at, k]):
				ok = false
		return ok
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			fail_test("%s: %d entries, the arena's %d" % [at, (a as Array).size(), (b as Array).size()])
			return false
		var ok: bool = true
		for i: int in (b as Array).size():
			ok = _same(a[i], b[i], tol, "%s[%d]" % [at, i]) and ok
		return ok
	if a != b:
		fail_test("%s: %s, the arena says %s" % [at, a, b])
		return false
	return true


func test_the_model_is_built_from_the_arenas_own_numbers() -> void:
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(SPEC))
	var committed: Variant = JSON.parse_string(text)
	assert_true(committed is Dictionary, "platform.json is there")
	# through JSON, so both sides are numbers and arrays alike
	var now: Variant = JSON.parse_string(JSON.stringify(ShrinePlatform.model_spec(arena.layout, arena.def)))
	assert_true(_same(committed, now, 1e-4, "platform.json"),
		"platform.json matches the arena (else run export_platform_spec.gd, rebuild and export the platform)")


func test_the_rings_match_the_floors_shader() -> void:
	var spec: Dictionary = ShrinePlatform.model_spec(arena.layout, arena.def)
	var rings: Array = spec["floor"]["rings"]
	assert_almost_eq(float(rings[0]["inner"]), arena.layout.centre_radius, 1e-5, "from the centre stone")
	assert_almost_eq(float(rings[-1]["outer"]), arena.def.floor_radius, 1e-5, "out to the floor's rim")
	for r: Dictionary in rings:
		assert_between(float(r["offset"]), 0.0, 1.0, "ring %d's turn" % r["index"])
		assert_gte(int(r["tiles"]), 8)
	assert_lte(float(spec["floor"]["max_drop"]), 0.015, "slabs sink by 1.5 cm at most")


func _vertices(mi: MeshInstance3D, surface: int) -> Array[PackedVector3Array]:
	var arrays: Array = mi.mesh.surface_get_arrays(surface)
	return [arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL]]


func test_the_slabs_lie_just_under_the_rules_floor_in_the_floors_shader() -> void:
	var floor_mi := arena.get_node("Platform/Floor") as MeshInstance3D
	var paving := floor_mi.get_surface_override_material(0) as ShaderMaterial
	assert_eq(paving.shader, ShrinePlatform.STONE_FLOOR, "the paving's shader on the slabs")
	assert_eq(float(paving.get_shader_parameter(&"joint_wobble")), 0.0, "its joints where the slabs' are")
	assert_true(LookMaterials.is_physical(floor_mi.get_surface_override_material(1)), "the bed of grit")
	var got: Array[PackedVector3Array] = _vertices(floor_mi, 0)
	var highest: float = -INF
	var tops: int = 0
	var deep: int = 0
	for i: int in got[0].size():
		var v: Vector3 = got[0][i]
		highest = maxf(highest, v.y)
		# the slabs' tops (the bed of grit is its own surface): their chipped
		# rims may dip a little further
		if got[1][i].y > 0.99:
			tops += 1
			deep += 1 if v.y < -0.016 else 0
	assert_lte(highest, 0.0005, "never above the floor, so no foot sinks into it")
	assert_gt(tops, 1000, "the slabs' tops")
	assert_lt(float(deep) / tops, 0.05, "the tops at most 1.5 cm down but for chips, so no foot floats over them")


func test_the_parapet_plinth_and_landings_are_modelled_in_the_stone_scans() -> void:
	for path: String in ["Platform/Plinth", "Platform/Props/Parapet", "Platform/Props/Landing"]:
		var mi := arena.get_node(path) as MeshInstance3D
		assert_not_null(mi, path)
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			assert_true(LookMaterials.is_physical(m), "%s surface %d is a look surface" % [path, s])
			assert_not_null((m as ShaderMaterial).get_shader_parameter(&"albedo_texture"), "%s surface %d wears its scan" % [path, s])
	var parapet := arena.get_node("Platform/Props/Parapet") as MeshInstance3D
	var top: float = parapet.get_aabb().end.y
	assert_between(top, arena.def.wall_height, arena.def.wall_height + 0.6, "today's height, the end posts' finials over it")
