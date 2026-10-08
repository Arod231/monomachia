extends GutTest
## The Shrine's buildings remodelled in place (milestone-1 task 132,
## ShrineBuildings): Kasuga lanterns on the lanterns' spots with their paper
## round the fire, a torii on each gate with its shimenawa and shide, the
## pillars whole and broken at their layout heights, the far pagodas and
## temple halls on their cliffs, all the project's own models in the look's
## physically based surfaces with maps of their own, the paper and windows
## glowing.

const SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"

var arena: MoonlitShrine


func before_all() -> void:
	arena = (load(SCENE) as PackedScene).instantiate()
	add_child(arena)


func after_all() -> void:
	arena.free()


func _props() -> Node3D:
	return arena.get_node("Platform/Props") as Node3D


## mi's bounds in arena space.
func _world_aabb(mi: MeshInstance3D) -> AABB:
	return mi.global_transform * mi.get_aabb()


## Whether m is a look surface carrying the model's own colour map.
func _mapped_surface(m: Material) -> bool:
	return LookMaterials.is_physical(m) and (m as ShaderMaterial).get_shader_parameter(&"albedo_texture") != null


func _assert_surfaces(mi: MeshInstance3D, label: String) -> void:
	assert_gt(mi.mesh.get_surface_count(), 0, label)
	for s: int in mi.mesh.get_surface_count():
		assert_true(_mapped_surface(mi.get_surface_override_material(s)), "%s surface %d is a look surface with its maps" % [label, s])
	assert_ne(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts shadows" % label)


## A far building's surfaces: look surfaces, each with its scan but the
## spire's plain bronze, casting no shadow.
func _assert_far_surfaces(mi: MeshInstance3D, label: String) -> void:
	var mapped: int = 0
	for s: int in mi.mesh.get_surface_count():
		var m: Material = mi.get_surface_override_material(s)
		assert_true(LookMaterials.is_physical(m), "%s surface %d is a look surface" % [label, s])
		if _mapped_surface(m):
			mapped += 1
	assert_gte(mapped, 4, "%s's roof, timber, stone and lacquer in their scans" % label)
	assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "far scenery casts no shadow")


func test_a_kasuga_lantern_stands_on_every_lantern_spot_its_paper_round_the_fire() -> void:
	var layout: ShrineLayout = arena.layout
	var phases: Dictionary[float, bool] = {}
	var meshes: Array[Mesh] = []
	for i: int in layout.lantern_angles.size():
		var lantern := _props().get_node("Lantern%d" % i) as Node3D
		var spot: Vector3 = ShrineLayout.polar(layout.lantern_angles[i], layout.lantern_radius, ShrinePlatform.LEDGE_Y)
		assert_almost_eq(lantern.position, spot, Vector3.ONE * 0.001, "lantern %d on its spot" % i)
		var stone := lantern.get_node("Stone") as MeshInstance3D
		var paper := lantern.get_node("Paper") as MeshInstance3D
		_assert_surfaces(stone, "lantern %d" % i)
		var height: AABB = stone.get_aabb()
		assert_between(height.end.y, 3.1, 3.4, "lantern %d about 3.2 m tall" % i)
		assert_almost_eq(height.position.y, 0.0, 0.03, "lantern %d stands on its foot" % i)
		var round_fire: AABB = paper.get_aabb()
		assert_almost_eq(round_fire.get_center().y, ShrineProps.LANTERN_FIRE.y, 0.05, "lantern %d's paper round the fire" % i)
		assert_true(round_fire.has_point(ShrineProps.LANTERN_FIRE), "lantern %d's paper surrounds the fire" % i)
		assert_eq(paper.material_override.shader, ShrineProps.LANTERN_GLOW, "lantern %d's paper glows" % i)
		assert_eq(paper.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a lit paper casts no shadow")
		phases[snappedf(float(paper.get_instance_shader_parameter(&"phase_offset")), 0.001)] = true
		meshes.append(stone.mesh)
	assert_eq(phases.size(), layout.lantern_angles.size(), "each lantern flickers at its own phase")
	assert_ne(meshes[0], meshes[1], "the lanterns weathered apart, taken in turn")
	assert_eq(meshes[0], meshes[ShrineBuildings.LANTERN_VARIANTS], "and again")


func test_a_torii_with_its_shimenawa_and_shide_stands_on_each_gate() -> void:
	var layout: ShrineLayout = arena.layout
	for side: int in 2:
		var torii := _props().get_node("Torii%d" % side) as Node3D
		var gate: Transform3D = arena.def.gate_anchor(side)
		assert_almost_eq(torii.global_position, gate.origin, Vector3.ONE * 0.001, "torii %d on its gate" % side)
		var wood := torii.get_node("Wood") as MeshInstance3D
		_assert_surfaces(wood, "torii %d" % side)
		var whole: AABB = _world_aabb(wood)
		assert_between(whole.end.y, layout.torii_height + 0.6, layout.torii_height + 1.4, "torii %d's top beam over its height" % side)
		var rope := torii.get_node("Rope") as MeshInstance3D
		_assert_surfaces(rope, "torii %d's shimenawa" % side)
		var hung: AABB = rope.get_aabb()
		assert_between(hung.get_center().y, layout.torii_height * 0.5, layout.torii_height * 0.76, "the shimenawa under the tie beam")
		assert_lt(hung.size.x, layout.torii_span, "between the pillars")
		var paper := torii.get_node("Paper") as MeshInstance3D
		assert_lt(paper.get_aabb().end.y, hung.end.y, "the shide hang from it")


func test_the_pillars_stand_whole_or_broken_at_their_heights() -> void:
	var layout: ShrineLayout = arena.layout
	for i: int in layout.pillars.size():
		var p: Vector4 = layout.pillars[i]
		var pillar := _props().get_node("Pillar%d" % i) as Node3D
		var spot: Vector3 = ShrineLayout.polar(p.x, p.y, ShrinePlatform.LEDGE_Y)
		assert_almost_eq(pillar.position, spot, Vector3.ONE * 0.001, "pillar %d on its spot" % i)
		var stone := pillar.get_node("Stone") as MeshInstance3D
		_assert_surfaces(stone, "pillar %d" % i)
		var top: float = _world_aabb(stone).end.y - ShrinePlatform.LEDGE_Y
		var broken: bool = p.w > 0.5
		if broken:
			assert_between(top, p.z * 0.85, p.z * 1.15, "broken pillar %d snapped about its height" % i)
			assert_null(pillar.get_node_or_null("Rope"), "a broken pillar lost its rope")
		else:
			assert_almost_eq(top, p.z, p.z * 0.03, "pillar %d at its height" % i)
			assert_not_null(pillar.get_node_or_null("Rope"), "a whole pillar keeps its rope")
			assert_not_null(pillar.get_node_or_null("Paper"), "and its shide")


func test_the_far_pagodas_and_temple_halls_are_modelled_and_lit() -> void:
	var cliffs: Node = arena.get_node("World/Cliffs")
	var found: int = 0
	for child: Node in cliffs.get_children():
		var n: String = child.name
		if not (n.begins_with("Pagoda") or n.begins_with("TempleHall")):
			continue
		found += 1
		var body := child.get_node("Body") as MeshInstance3D
		_assert_far_surfaces(body, n)
		var window := child.get_node("Window") as MeshInstance3D
		assert_eq(window.material_override.shader, ShrineProps.LANTERN_GLOW, "%s's windows glow" % n)
	var expected: int = 0
	for c: Vector4 in arena.layout.cliffs:
		expected += 2 if c.w >= ShrineBackdrop.TEMPLE_CLIFF and c.w < ShrineBackdrop.PAGODA_CLIFF else 1
	assert_eq(found, expected, "a building on every cliff, as before")


func test_the_floating_rocks_carry_the_modelled_lantern_and_broken_pillar() -> void:
	var rocks: Node = arena.get_node("Underside/FloatingRocks")
	assert_not_null(rocks.get_node_or_null("FloatingRock0/Lantern0/Stone"), "the first rock's lantern")
	assert_not_null(rocks.get_node_or_null("FloatingRock2/Pillar2/Stone"), "the third rock's broken pillar")
