extends GutTest
## The Shrine's banners and grass (milestone-1 task 131): twelve nobori
## evenly round the ledge, clear of its props and beyond the cameras' room,
## their cloth swaying on the wind; short grass in the paving's joints across
## the floor, thicker by the parapet and on the ledge, picture only.

const SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"
## How close a banner's pole may come to a lantern, pillar or tree trunk, or
## to a torii's post (m).
const PROP_CLEARANCE: float = 0.8
## Round a banner's pole, out to BARK_CLEARANCE, no bark higher over the
## ledge than ROOT_HEIGHT (m).
const BARK_CLEARANCE: float = 0.15
const ROOT_HEIGHT: float = 0.2

var arena: MoonlitShrine


func before_all() -> void:
	arena = (load(SCENE) as PackedScene).instantiate() as MoonlitShrine
	add_child(arena)


func after_all() -> void:
	arena.free()


func _banners() -> Node3D:
	return arena.get_node("Platform/Banners") as Node3D


static func _world_vertices(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s: int in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(mi.global_transform * v)
	return out


func test_twelve_banners_stand_evenly_round_the_ledge() -> void:
	var banners: Node3D = _banners()
	assert_eq(banners.get_child_count(), 12)
	var layout: ShrineLayout = arena.layout
	assert_eq(layout.banners.size(), 12)
	var cloths: Dictionary = {}
	for i: int in banners.get_child_count():
		var b: Node3D = banners.get_child(i)
		var at: Vector3 = b.global_position
		var angle: float = fposmod(rad_to_deg(atan2(at.x, at.z)), 360.0)
		assert_almost_eq(angle, 15.0 + 30.0 * i, 1.01, "%s every 30°" % b.name)
		assert_almost_eq(Vector2(at.x, at.z).length(), layout.banners[i].y, 0.001)
		assert_almost_eq(at.y, ShrinePlatform.LEDGE_Y, 0.001, "on the ledge")
		# its cloth faces the courtyard
		var face: Vector3 = b.global_transform.basis.z
		assert_gt(face.dot(-Vector3(at.x, 0.0, at.z).normalized()), 0.99, "%s faces the courtyard" % b.name)
		var cloth: MeshInstance3D = b.get_node("Cloth")
		cloths[cloth.mesh] = true
	assert_eq(cloths.size(), 4, "the four banners in turn")


func test_the_banners_stand_clear_of_the_ledges_props_and_the_gates() -> void:
	var layout: ShrineLayout = arena.layout
	var def: ArenaDef = arena.def
	var props: Array[Vector3] = []
	for a: float in layout.lantern_angles:
		props.append(ShrineLayout.polar(a, layout.lantern_radius))
	for p: Vector4 in layout.pillars:
		props.append(ShrineLayout.polar(p.x, p.y))
	for g: int in 2:
		var gate: Transform3D = def.gate_anchor(g)
		for side: float in [-1.0, 1.0]:
			props.append(gate * Vector3(side * layout.torii_span * 0.5, 0.0, 0.0))
	for spot: Vector3 in ShrineBanners.spots(layout):
		var flat := Vector3(spot.x, 0.0, spot.z)
		for p: Vector3 in props:
			assert_gt(flat.distance_to(Vector3(p.x, 0.0, p.z)), PROP_CLEARANCE, "a banner at %s clear of a prop at %s" % [flat, p])
		for g: int in 2:
			var gate: Vector3 = def.gate_anchor(g).origin
			assert_gt(flat.angle_to(Vector3(gate.x, 0.0, gate.z)), deg_to_rad(12.0), "a banner at %s clear of a gate" % flat)


func test_the_banners_stand_clear_of_the_wisterias_bark() -> void:
	# within BARK_CLEARANCE of a pole, no bark stands higher than ROOT_HEIGHT
	# over the ledge (a root lying on the rock), up to the top of its cloth:
	# the bark's tallest point over each 10 cm cell of the ledge
	var tallest: Dictionary = {}
	for node: Node in arena.get_node("Platform/Wisteria").find_children("*_Bark", "MeshInstance3D", true, false):
		for w: Vector3 in _world_vertices(node as MeshInstance3D):
			if w.y < ShrinePlatform.LEDGE_Y + 4.6:
				var cell := Vector2i(floori(w.x * 10.0), floori(w.z * 10.0))
				tallest[cell] = maxf(tallest.get(cell, -INF), w.y)
	assert_gt(tallest.size(), 1000, "the trees' bark found")
	var reach: int = ceili(BARK_CLEARANCE * 10.0)
	for spot: Vector3 in ShrineBanners.spots(arena.layout):
		var centre := Vector2i(floori(spot.x * 10.0), floori(spot.z * 10.0))
		var top: float = -INF
		for dx: int in range(-reach, reach + 1):
			for dz: int in range(-reach, reach + 1):
				if Vector2(dx, dz).length() <= BARK_CLEARANCE * 10.0:
					top = maxf(top, tallest.get(centre + Vector2i(dx, dz), -INF))
		assert_lt(top - ShrinePlatform.LEDGE_Y, ROOT_HEIGHT, "a banner at %s stands clear of the bark (%.2f m of it within %.2f m)" % [spot, top - ShrinePlatform.LEDGE_Y, BARK_CLEARANCE])


func test_no_banner_reaches_into_the_cameras_room() -> void:
	# beyond camera_max_radius, a banner can never stand between a camera and
	# a fighter, since both are inside it
	for node: Node in _banners().find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		for w: Vector3 in _world_vertices(mi):
			var r: float = Vector2(w.x, w.z).length()
			if r < arena.def.camera_max_radius + 0.8:
				fail_test("%s/%s reaches in to %.2f m" % [mi.get_parent().name, mi.name, r])
				return
	pass_test("every banner beyond the cameras' room")


func test_the_banners_cloth_sways_on_the_wind_in_the_look() -> void:
	for b: Node in _banners().get_children():
		var cloth: MeshInstance3D = b.get_node("Cloth")
		var m: ShaderMaterial = cloth.get_active_material(0)
		assert_eq(m.shader, LookMaterials.SWAY_SHADER, "%s's cloth sways" % b.name)
		assert_true(m.shader.code.contains("wind.gdshaderinc"), "on the Shrine's one wind")
		assert_true(m.get_shader_parameter(&"sway_from_red"), "its weight in the vertex red")
		assert_gt(float(m.get_shader_parameter(&"flutter")), 0.0, "and flutters")
		assert_not_null(m.get_shader_parameter(&"albedo_texture"), "dyed with its mon and kanji")
		var pole: MeshInstance3D = b.get_node("Pole")
		assert_true(LookMaterials.is_physical(pole.get_active_material(0)), "%s's pole in the look" % b.name)


## Every tuft's place: ShrineGrass.placements(), which the multimeshes hold
## (read here, since a headless run keeps no instance transforms to read back).
func _tufts() -> Array[Transform3D]:
	var count: int = 0
	for node: Node in arena.get_node("Platform/Grass").get_children():
		count += (node as MultiMeshInstance3D).multimesh.instance_count
	var out: Array[Transform3D] = ShrineGrass.placements(arena.layout, arena.def)
	assert_eq(count, out.size(), "the multimeshes hold every tuft")
	return out


func test_grass_grows_in_the_paving_across_the_floor_and_on_the_ledge() -> void:
	var tufts: Array[Transform3D] = _tufts()
	var def: ArenaDef = arena.def
	var inside: int = 0
	var centre_band: int = 0
	var wall_band: int = 0
	var ledge: int = 0
	for t: Transform3D in tufts:
		var r: float = Vector2(t.origin.x, t.origin.z).length()
		if r < def.walkable_radius:
			inside += 1
			assert_almost_eq(t.origin.y, 0.0, 0.001, "on the floor")
		if r > 3.0 and r < 7.0:
			centre_band += 1
		if r > 12.0 and r < def.wall_inner_radius():
			wall_band += 1
		if r > def.floor_radius:
			ledge += 1
			assert_almost_eq(t.origin.y, ShrinePlatform.LEDGE_Y, 0.001, "on the ledge")
	assert_gt(inside, 100, "in the walkable circle too")
	# per square metre: the band by the parapet against the one near the centre
	var centre_area: float = PI * (7.0 * 7.0 - 3.0 * 3.0)
	var wall_area: float = PI * (def.wall_inner_radius() ** 2 - 12.0 * 12.0)
	assert_gt(wall_band / wall_area, 3.0 * centre_band / centre_area, "thicker by the parapet")
	assert_gt(ledge, 500, "and on the ledge")


func test_the_floor_grass_is_too_short_to_hide_the_feet_and_never_collides() -> void:
	var grass: Node = arena.get_node("Platform/Grass")
	var tall_of: float = 0.0
	for node: Node in grass.get_children():
		var mmi: MultiMeshInstance3D = node
		var tall: float = maxf(tall_of, mmi.multimesh.mesh.get_aabb().end.y)
		tall_of = tall
		assert_eq(mmi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % mmi.name)
		var m: ShaderMaterial = mmi.material_override
		assert_eq(m.shader, LookMaterials.SWAY_SHADER, "the grass sways")
		assert_true(m.shader.code.contains("wind.gdshaderinc"), "on the Shrine's one wind")
		assert_true(m.get_shader_parameter(&"use_vertex_color"), "coloured by its blades' vertex colour")
	assert_eq(grass.find_children("*", "CollisionObject3D", true, false).size(), 0, "picture only")
	var tallest: float = 0.0
	for t: Transform3D in _tufts():
		if Vector2(t.origin.x, t.origin.z).length() < arena.def.floor_radius:
			tallest = maxf(tallest, tall_of * t.basis.get_scale().y)
	assert_lt(tallest, ShrineGrass.FLOOR_HEIGHT, "the tallest tuft on the floor stands %.3f m" % tallest)


func test_the_floor_grass_grows_on_the_ring_joints_or_the_parapets_foot() -> void:
	var layout: ShrineLayout = arena.layout
	var wall: float = arena.def.wall_inner_radius()
	for t: Transform3D in _tufts():
		var r: float = Vector2(t.origin.x, t.origin.z).length()
		if r > arena.def.floor_radius:
			continue
		var k: float = (r - layout.centre_radius) / layout.ring_width
		var on_joint: bool = absf(k - roundf(k)) * layout.ring_width < 0.03
		var at_foot: bool = r > wall - 0.31
		if not (on_joint or at_foot):
			fail_test("a tuft at %.3f m grows on bare stone" % r)
			return
	pass_test("every floor tuft in a joint")
