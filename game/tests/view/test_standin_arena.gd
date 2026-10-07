extends GutTest
## The stand-in arena in the realistic look (milestone-1 task 43): every
## surface a physically based prop with no outline, the floor on the ground
## layer, the night with the colour grade, the moon casting the preset's
## shadows, a rim light that
## touches fighters only, the chosen graphics preset applied when the arena
## loads, and spawn and gate markers placed and facing as ArenaDef's are.

var _services: Node
var _saved_preset: StringName


func before_all() -> void:
	_services = get_tree().root.get_node("GameServices")


func before_each() -> void:
	_saved_preset = _settings().graphics_preset_id


func after_each() -> void:
	_settings().graphics_preset_id = _saved_preset


## The arena applies its preset only to itself, but put the renderer back to
## the preset the game started with all the same.
func after_all() -> void:
	GraphicsApplier.apply(_services.call("graphics_preset"), null)


func _settings() -> GameSettings:
	return _services.get("settings") as GameSettings


func _arena() -> Node3D:
	var arena: Node3D = ArenaScenes.instantiate(ArenaScenes.STANDIN)
	add_child_autofree(arena)
	return arena


func _meshes(arena: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in arena.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


func _lights(arena: Node3D, type: String) -> Array[Light3D]:
	var out: Array[Light3D] = []
	for node: Node in arena.find_children("*", type, true, false):
		out.append(node as Light3D)
	return out


func test_every_surface_is_a_physically_based_prop_with_no_outline() -> void:
	var meshes: Array[MeshInstance3D] = _meshes(_arena())
	assert_gte(meshes.size(), 5, "the floor, the apron, the lines, the wall and the pillars")
	for mi: MeshInstance3D in meshes:
		var m: ShaderMaterial = mi.material_override as ShaderMaterial
		assert_not_null(m, "%s draws with a material of its own" % mi.name)
		if m != null:
			assert_true(LookMaterials.is_physical(m), "%s is physically based" % mi.name)
			assert_eq(LookMaterials.surface_of(m), LookMaterials.Surface.PROP, mi.name)
			assert_null(m.next_pass, "%s has no outline" % mi.name)
		for s: int in mi.mesh.get_surface_count():
			assert_null(mi.mesh.surface_get_material(s), "%s has no other material underneath" % mi.name)


func test_the_ground_is_on_the_ground_layer_and_the_lanterns_leave_it_out() -> void:
	var arena: Node3D = _arena()
	for node_name: String in ["Floor", "Apron", "Lines"]:
		assert_eq((arena.get_node(node_name) as MeshInstance3D).layers, LookPalette.GROUND_LAYER, node_name)
	var lanterns: Array[Light3D] = _lights(arena, "OmniLight3D")
	assert_eq(lanterns.size(), 2)
	for lamp: Light3D in lanterns:
		assert_true(lamp.is_in_group(GraphicsApplier.GROUP_MINOR_LIGHT), "%s is a minor light" % lamp.name)
		assert_eq(lamp.light_cull_mask, LookPalette.SMALL_LIGHT_MASK, "%s skips the ground" % lamp.name)


func test_the_moon_casts_the_presets_shadows_and_the_rim_lights_fighters_only() -> void:
	var arena: Node3D = _arena()
	var moon: DirectionalLight3D = arena.get_node("Moon")
	assert_true(moon.is_in_group(GraphicsApplier.GROUP_SHADOW_LIGHT))
	assert_true(moon.shadow_enabled)
	assert_eq(moon.directional_shadow_max_distance, GraphicsPreset.load_id(&"high").shadow_max_distance)
	var rim: DirectionalLight3D = arena.get_node("Rim")
	assert_eq(rim.light_cull_mask, LookPalette.FIGHTER_LAYER, "the floor and walls stay out of the rim light")
	assert_false(rim.shadow_enabled)


func test_the_night_is_the_look_s_and_graded() -> void:
	var arena: Node3D = _arena()
	var env: Environment = (arena.get_node("Environment") as WorldEnvironment).environment
	assert_eq(env.background_mode, Environment.BG_SKY, "a dusk sky behind the pillars")
	assert_eq(env.ambient_light_color, LookPalette.MIST, "the night's mist")
	assert_true(env.volumetric_fog_enabled, "volumetric fog on Ultra")
	assert_true(LookGrade.is_graded(env), "the look's colour grade")
	assert_ne(env, (_arena().get_node("Environment") as WorldEnvironment).environment, "each arena its own, so a preset can change it")


func test_the_chosen_preset_is_applied_when_the_arena_loads() -> void:
	_settings().graphics_preset_id = &"low"
	var low: GraphicsPreset = GraphicsPreset.load_id(&"low")
	var arena: Node3D = _arena()
	# Low drops only atmosphere (milestone-1 task 29): the lanterns and the
	# grade stay as on Ultra
	for lamp: Light3D in _lights(arena, "OmniLight3D"):
		assert_true(lamp.visible, "lantern lights on Low")
	assert_eq((arena.get_node("Moon") as DirectionalLight3D).directional_shadow_max_distance, low.shadow_max_distance)
	var env: Environment = (arena.get_node("Environment") as WorldEnvironment).environment
	assert_false(env.volumetric_fog_enabled, "no volumetric fog on Low")
	assert_true(LookGrade.is_graded(env), "the grade on Low")
	assert_true(env.has_meta(GraphicsApplier.META_BASE_VOLUMETRIC), "the preset reached the environment")
	assert_false(env.volumetric_fog_enabled, "no volumetric fog on Low")


func test_the_arena_follows_the_rules_radius() -> void:
	var arena: Node3D = _arena()
	var r: float = SimConst.ARENA_RADIUS
	var floor_box: AABB = (arena.get_node("Floor") as MeshInstance3D).get_aabb()
	assert_almost_eq(floor_box.size.x, 2.0 * r, 0.01, "the floor reaches the wall")
	# The wall is the lacquered ring below the pillar caps: its inner face is
	# the rules' wall line.
	var lacquer: Mesh = (arena.get_node("Lacquer") as MeshInstance3D).mesh
	var nearest: float = INF
	for v: Vector3 in lacquer.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.y < 1.0:
			nearest = minf(nearest, Vector2(v.x, v.z).length())
	assert_almost_eq(nearest, r, 0.001, "the wall's inner face stands on the wall line")
	var gate: Node3D = arena.get_node("Gate1")
	assert_almost_eq(Vector2(gate.position.x, gate.position.z).length(), r + 3.0, 1e-5, "the gates stand past the wall")


func test_its_markers_stand_and_face_like_arena_data() -> void:
	var arena: Node3D = _arena()
	var world := World.new(FighterConfig.make(Moves.KATANA), FighterConfig.make(Moves.KATANA))
	for side: int in 2:
		var spawn: Node3D = arena.get_node("Spawn%d" % side)
		var f: Fighter = world.fighters[side]
		assert_almost_eq(spawn.position, Vector3(f.pos.x, f.pos.y, f.pos.z), Vector3.ONE * 1e-5, "spawn %d where the rules start the round" % side)
		var forward: V2 = SimMath.fwd(f.yaw)
		assert_almost_eq(-spawn.basis.z, Vector3(forward.x, 0.0, forward.z), Vector3.ONE * 1e-5, "spawn %d faces as the rules face it" % side)
		var gate: Node3D = arena.get_node("Gate%d" % side)
		assert_almost_eq(-gate.basis.z, -gate.position.normalized(), Vector3.ONE * 1e-5, "gate %d faces the centre" % side)
	world.dispose()
