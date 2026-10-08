extends GutTest
## The Moonlit Shrine, built headless: the arena's own lights and night sky
## in the realistic look (physically based, no outline, the night's grade, a
## ground mist and dust), with its fog and the moon ahead of player one where the
## layout puts it; the backdrop inside the far clip, cheap, dipping under the
## moon to show the lake, and trimmed per preset; the markers the match
## reads, a floor at y = 0 under the spawns, a parapet, gate ropes and props
## outside the walkable circle with only flat pebbles inside it (and the
## wisteria's canopies high over it, and short grass in the paving's joints,
## which test_shrine_banners_grass.gd covers with the banners), the torii on
## the gate landings, the lanterns' lights, halos and flicker, bought art in
## place of a procedural prop, the ledge under the props, the rock under the
## rim left out per camera by the cameras above the courtyard, the floating
## rocks bobbing, the embers and ash on the wind, and the chosen preset
## applied.

const SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"
const SKY_SHADER: Shader = preload("res://shaders/sky_moonlit.gdshader")
## The backdrop's own shaders, which all take the look's noise.
const BACKDROP_SHADERS: Array[Shader] = [
	ShrineBackdrop.CLOUD_SEA, ShrineBackdrop.MOUNTAIN, ShrineBackdrop.WATERFALL, ShrineBackdrop.LAKE, ShrineBackdrop.MIST,
]
## What each level of scenery detail draws of the backdrop (World's parts):
## 0 keeps the sea of clouds, the mountains and the lake; 1 adds the veil of
## cloud over the sea, the cliffs with their buildings and waterfalls, and the
## lanterns on the lake; 2 adds the mist, round the crag's tip too. Every
## preset draws at 2 since milestone-1 task 29 (Low drops only atmosphere).
const SCENERY: Dictionary[int, Array] = {
	0: ["CloudSea", "Mountains", "Lake"],
	1: ["CloudSea", "CloudVeil", "Mountains", "Lake", "Cliffs", "LakeLanterns"],
	2: ["CloudSea", "CloudVeil", "Mountains", "Lake", "Cliffs", "LakeLanterns", "Mist", "CragMist"],
}
## How far past the moon's disc (radians) nothing may stand.
const MOON_MARGIN := 0.015

var arena: MoonlitShrine
var _services: Node
var _saved_preset: StringName


func before_all() -> void:
	_services = get_tree().root.get_node("GameServices")
	arena = (load(SCENE) as PackedScene).instantiate()
	add_child(arena)


func before_each() -> void:
	_saved_preset = _settings().graphics_preset_id


## Puts back the saved preset, and the shared arena in it.
func after_each() -> void:
	_settings().graphics_preset_id = _saved_preset
	GraphicsApplier.apply_to_tree(_services.call("graphics_preset"), arena)


func after_all() -> void:
	arena.free()


func _settings() -> GameSettings:
	return _services.get("settings") as GameSettings


func test_it_carries_its_arena_data_and_layout() -> void:
	assert_eq(arena.def, ArenaScenes.def(ArenaScenes.MOONLIT_SHRINE), "the shrine's ArenaDef, which the camera reads")
	assert_eq(arena.def.scene_path, SCENE)
	assert_not_null(arena.layout)


func test_its_markers_match_the_arena_data() -> void:
	for side: int in 2:
		var spawn := arena.get_node("Spawn%d" % side) as Marker3D
		var gate := arena.get_node("Gate%d" % side) as Marker3D
		assert_true(spawn.transform.is_equal_approx(arena.def.spawn_point(side)), "Spawn%d" % side)
		assert_true(gate.transform.is_equal_approx(arena.def.gate_anchor(side)), "Gate%d" % side)


func _environment(shrine: MoonlitShrine) -> Environment:
	return (shrine.get_node("WorldEnvironment") as WorldEnvironment).environment


## A parameter of material, once its shader is known to declare it: a
## misspelt name would set nothing, so the test reads only real uniforms.
func _param(material: ShaderMaterial, param: StringName) -> Variant:
	var names: Array = material.shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u["name"])
	assert_has(names, String(param), "%s is a uniform of %s" % [param, material.shader.resource_path])
	return material.get_shader_parameter(param)


## A parameter of shrine's sky (see _param).
func _sky_param(shrine: MoonlitShrine, param: StringName) -> Variant:
	return _param(_environment(shrine).sky.sky_material as ShaderMaterial, param)


## Player one's starting follow camera.
func _player_one_camera() -> Camera3D:
	var rig: CameraRig = autofree(CameraRig.new())
	var me: Vector3 = arena.def.spawn_point(0).origin
	var them: Vector3 = arena.def.spawn_point(1).origin
	var view: Dictionary = rig.follow_target(me, them, (them - me).normalized())
	var cam: Camera3D = _camera_at(view["pos"])
	cam.fov = rig.base_fov
	cam.far = arena.def.camera_far
	cam.look_at(view["look"])
	return cam


func test_its_environment_is_its_own_copy_of_the_night_sky() -> void:
	assert_not_null(arena.def.environment, "the shrine's data brings its sky")
	var env: Environment = _environment(arena)
	assert_ne(env, arena.def.environment, "a copy, so presets don't edit the resource")
	assert_eq(env.background_mode, Environment.BG_SKY)
	var sky := env.sky.sky_material as ShaderMaterial
	assert_eq(sky.shader, SKY_SHADER)
	assert_ne(sky, arena.def.environment.sky.sky_material, "its own sky, so the moon set on it leaves the resource alone")
	assert_eq(_sky_param(arena, LookNoise.PARAM), LookNoise.texture(), "the sky fetches the look's noise")
	assert_eq(_sky_param(arena, &"horizon_color"), LookGrade.NIGHT_HORIZON, "the night's horizon, near black")


## A sky that isn't a shader (bought art, say) comes through as it is.
func test_a_sky_that_isnt_a_shader_is_left_as_it_is() -> void:
	var def := arena.def.duplicate() as ArenaDef
	var panorama := PanoramaSkyMaterial.new()
	def.environment = Environment.new()
	def.environment.background_mode = Environment.BG_SKY
	def.environment.sky = Sky.new()
	def.environment.sky.sky_material = panorama
	var shrine: MoonlitShrine = (load(SCENE) as PackedScene).instantiate()
	shrine.def = def
	add_child_autofree(shrine)
	assert_true(_environment(shrine).sky.sky_material is PanoramaSkyMaterial)


## The shrine's own fog, before a preset turns any of it off.
func test_fog_and_height_fog_are_set() -> void:
	var env: Environment = arena.def.environment
	assert_true(env.fog_enabled, "depth fog")
	assert_gt(env.fog_depth_begin, arena.def.camera_max_radius + arena.def.floor_radius, "which starts past the courtyard")
	assert_gt(env.fog_height_density, 0.0, "height fog")
	assert_lt(env.fog_height, ShrinePlatform.LEDGE_Y, "which gathers under the ledge, leaving the courtyard clear")


## Player one starts at -Z facing +Z, so the moon hangs in their first view.
func test_the_moon_rises_ahead_of_player_one() -> void:
	var toward_moon: Vector3 = arena.layout.moon_direction.normalized()
	assert_almost_eq(_sky_param(arena, &"moon_direction"), toward_moon, Vector3.ONE * 1e-5, "the sky's moon is where the layout puts it")
	assert_gt(toward_moon.y, 0.0, "above the horizon")
	var cam: Camera3D = _player_one_camera()
	assert_true(cam.is_position_in_frustum(cam.global_position + toward_moon * 1000.0), "in player one's first view")


## The moon is data: a layout with the moon elsewhere moves the sky's moon
## and the rim light with it, and leaves other shrines' skies alone.
func test_the_sky_and_the_rim_light_take_the_moon_from_the_layout() -> void:
	var layout := arena.layout.duplicate() as ShrineLayout
	layout.moon_direction = Vector3(-2.0, 1.0, 0.5)
	var shrine: MoonlitShrine = (load(SCENE) as PackedScene).instantiate()
	shrine.layout = layout
	add_child_autofree(shrine)
	var toward_moon: Vector3 = layout.moon_direction.normalized()
	assert_almost_eq(_sky_param(shrine, &"moon_direction"), toward_moon, Vector3.ONE * 1e-5, "the sky's moon")
	var rim := shrine.get_node("Lights/MoonRim") as DirectionalLight3D
	assert_almost_eq(rim.global_basis.z, toward_moon, Vector3.ONE * 1e-4, "the rim light")
	assert_almost_eq(_sky_param(arena, &"moon_direction"), arena.layout.moon_direction.normalized(), Vector3.ONE * 1e-5, "the first shrine's moon stays")


func test_the_moon_casts_the_shadows_and_the_rim_light_touches_fighters_only() -> void:
	var key := arena.get_node("Lights/MoonKey") as DirectionalLight3D
	assert_false(key.shadow_enabled, "the moon's own light casts the shadows, from the moon")
	assert_false(key.is_in_group(GraphicsApplier.GROUP_SHADOW_LIGHT))
	var moon := arena.get_node("Lights/MoonLight") as DirectionalLight3D
	assert_true(moon.is_in_group(GraphicsApplier.GROUP_SHADOW_LIGHT), "the preset sets its shadows")
	assert_ne(moon.shadow_caster_mask & LookPalette.FIGHTER_LAYER, 0, "the fighters cast them")
	assert_almost_eq(moon.global_basis.z, arena.layout.moon_direction.normalized(), Vector3.ONE * 1e-4, "away from the moon")
	var rim := arena.get_node("Lights/MoonRim") as DirectionalLight3D
	assert_eq(rim.light_cull_mask, LookPalette.FIGHTER_LAYER)
	assert_false(rim.shadow_enabled)
	var toward_moon: Vector3 = arena.layout.moon_direction.normalized()
	assert_almost_eq(rim.global_basis.z, toward_moon, Vector3.ONE * 1e-4, "the rim light shines from the moon")


## Milestone-1 task 43: no toon material, outline or ink-wash pass anywhere in
## the Shrine; every lit surface physically based, the night graded.
func test_the_shrine_is_in_the_realistic_look() -> void:
	var lit: int = 0
	for node: Node in arena.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		for m: Material in _materials_of(geo):
			assert_null(m.next_pass, "%s draws no outline" % geo.name)
			var sm := m as ShaderMaterial
			if sm != null and sm.shader != null:
				assert_false(sm.shader.code.contains("void light()"), "%s brings no toon light" % geo.name)
			if LookMaterials.is_physical(m):
				lit += 1
	assert_gt(lit, 10, "the courtyard, its props and the rock are physically based")
	assert_eq(arena.find_children("*", "MeshInstance3D", true, false).filter(
		func(n: Node) -> bool: return n.name == &"InkWash").size(), 0, "no ink-wash pass")
	assert_true(LookGrade.is_graded(_environment(arena)), "the night's grade")
	assert_true(_environment(arena).volumetric_fog_enabled, "mist in volumetric fog on Ultra")


func test_a_ground_mist_and_dust_hang_over_the_courtyard() -> void:
	var mist := arena.get_node("GroundMist") as FogVolume
	assert_not_null(mist)
	assert_gt(mist.size.x, arena.def.floor_radius * 2.0, "over the whole floor")
	assert_lt(mist.size.y, 2.0, "and low")
	var dust := arena.get_node("Dust") as GPUParticles3D
	assert_not_null(dust)
	assert_true(dust.is_in_group(GraphicsApplier.GROUP_PARTICLES), "the preset thins it")
	assert_eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


## The moon's key and the lanterns light the mist (the key softly, for the
## shafts to stand out: milestone-1 task 49); the rim, which touches fighters
## only, doesn't.
func test_the_lights_are_the_look_test_s() -> void:
	var key := arena.get_node("Lights/MoonKey") as DirectionalLight3D
	assert_eq(key.light_color, LookPalette.MOON_STEEL.lightened(0.25))
	assert_gt(key.light_volumetric_fog_energy, 0.0)
	assert_eq((arena.get_node("Lights/MoonRim") as Light3D).light_volumetric_fog_energy, 0.0)
	for light: Node in _lantern_lights(arena):
		var lamp := light as OmniLight3D
		assert_eq(lamp.light_color, LookPalette.LANTERN_EMBER, "%s glows ember" % lamp.name)
		assert_true(lamp.shadow_enabled, "%s casts shadows" % lamp.name)


## Every material geo draws with.
static func _materials_of(geo: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if geo.material_override != null:
		out.append(geo.material_override)
	if geo is MeshInstance3D and (geo as MeshInstance3D).mesh != null:
		var mi := geo as MeshInstance3D
		for i: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(i)
			if m != null:
				out.append(m)
	return out


# ------------------------------------------------------------------ the platform

func test_the_floor_lies_at_zero_under_both_spawns_on_the_ground_layer() -> void:
	var floor_mi := arena.get_node("Platform/Floor") as MeshInstance3D
	var aabb: AABB = floor_mi.get_aabb()
	assert_almost_eq(aabb.end.y, 0.0, 0.001, "floor at y = 0")
	assert_almost_eq(aabb.position.y, 0.0, 0.001, "and flat")
	assert_almost_eq(aabb.end.x, arena.def.floor_radius, 0.01, "out to the floor's edge")
	for side: int in 2:
		var p: Vector3 = arena.def.spawn_point(side).origin
		assert_eq(p.y, 0.0, "spawn %d at floor height" % side)
		assert_lt(Vector2(p.x, p.z).length(), arena.def.floor_radius, "spawn %d on the paving" % side)
	assert_eq(floor_mi.layers, LookPalette.GROUND_LAYER, "lantern lights skip it")
	assert_not_null(arena.get_node_or_null("Platform/Plinth"), "the courtyard's stone edge")


func test_parapet_posts_stand_outside_the_walkable_circle() -> void:
	var posts: PackedVector3Array = ShrinePlatform.post_positions(arena.layout, arena.def)
	assert_gt(posts.size(), 40)
	assert_lt(posts.size(), arena.layout.post_count, "the gates open the parapet")
	for p: Vector3 in posts:
		var inner: float = Vector2(p.x, p.z).length() - ShrinePlatform.POST_HALF * ShrinePlatform.END_POST_WIDEN
		assert_gte(inner, arena.def.walkable_radius, "post at %s" % p)


## Every vertex of mi, in world space.
func _world_vertices(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s: int in mi.mesh.get_surface_count():
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			out.append(mi.global_transform * v)
	return out


func _min_radius(mi: MeshInstance3D) -> float:
	var best: float = INF
	for w: Vector3 in _world_vertices(mi):
		best = minf(best, Vector2(w.x, w.z).length())
	return best


func test_nothing_but_flat_pebbles_is_built_inside_the_walkable_circle() -> void:
	var platform: Node = arena.get_node("Platform")
	var meshes: Array[Node] = platform.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 10, "the floor, the plinth, the props and the ropes")
	for node: Node in meshes:
		if node.name in [&"Floor", &"Pebbles"]:
			continue
		if platform.get_node("Wisteria").is_ancestor_of(node):
			# the wisteria's canopies hang over the arena, high over the fight
			# (test_shrine_wisteria.gd holds them out of the cameras' room)
			for w: Vector3 in _world_vertices(node as MeshInstance3D):
				if Vector2(w.x, w.z).length() < arena.def.walkable_radius and w.y < ShrineWisteria.CANOPY_FLOOR:
					fail_test("%s reaches into the walkable circle at %s" % [node.name, w])
					break
			continue
		assert_gte(_min_radius(node as MeshInstance3D), arena.def.walkable_radius - 0.001, "%s stays outside the walkable circle" % node.name)
	var pebbles := platform.get_node("Props/Pebbles") as MeshInstance3D
	assert_lt(pebbles.get_aabb().end.y, 0.12, "pebbles are flat enough to walk over")
	assert_gte(_min_radius(pebbles), arena.def.walkable_radius - 0.6, "along the foot of the parapet")


func test_each_gate_stands_on_a_landing_level_with_the_floor() -> void:
	var landings := arena.get_node("Platform/Props/Landing") as MeshInstance3D
	var aabb: AABB = landings.get_aabb()
	assert_almost_eq(aabb.end.y, 0.0, 0.02, "landings come up to the floor")
	for side: int in 2:
		var gate: Vector3 = arena.def.gate_anchor(side).origin
		assert_true(aabb.grow(0.01).has_point(gate + Vector3(0.0, -0.05, 0.0)), "a landing under gate %d" % side)


func test_gate_ropes_close_the_gate_openings_outside_the_walkable_circle() -> void:
	for side: int in 2:
		var rope: Node = arena.get_node("Platform/GateRope%d" % side)
		var gate: Vector3 = arena.def.gate_anchor(side).origin
		var meshes: Array[Node] = rope.find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0, "rope %d has meshes" % side)
		for node: Node in meshes:
			var mi := node as MeshInstance3D
			assert_gte(_min_radius(mi), arena.def.walkable_radius, "rope %d outside the walkable circle" % side)
			var centre: Vector3 = mi.global_transform * mi.get_aabb().get_center()
			assert_gt(centre.z * gate.z, 0.0, "rope %d at its own gate's end" % side)
			assert_lt(absf(centre.x), 1.0, "rope %d across the opening" % side)


# ------------------------------------------------------------------ the props

## Every vertex of mi (world space) within radius of point, across the floor.
func _vertices_near(mi: MeshInstance3D, point: Vector3, radius: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for w: Vector3 in _world_vertices(mi):
		if Vector2(w.x - point.x, w.z - point.z).length() < radius:
			out.append(w)
	return out


func test_a_torii_stands_on_each_gate_landing() -> void:
	for side: int in 2:
		var lacquer := arena.get_node("Platform/Props/Torii%d/Wood" % side) as MeshInstance3D
		var gate: Transform3D = arena.def.gate_anchor(side)
		for s: float in [-1.0, 1.0]:
			var foot: Vector3 = gate * Vector3(s * arena.layout.torii_span * 0.5, 0.0, 0.0)
			var verts: PackedVector3Array = _vertices_near(lacquer, foot, 0.5)
			assert_gt(verts.size(), 0, "gate %d has a post at %+d" % [side, s])
			var low: float = INF
			var high: float = -INF
			for v: Vector3 in verts:
				low = minf(low, v.y)
				high = maxf(high, v.y)
			assert_almost_eq(low, 0.0, 0.01, "gate %d post %+d stands on the landing" % [side, s])
			assert_gt(high, arena.layout.torii_height, "gate %d post %+d at the torii's height" % [side, s])


func _lantern_lights(shrine: MoonlitShrine) -> Array[Node]:
	return shrine.get_node("Platform/LanternLights").get_children()


func test_every_lantern_has_a_light_that_lights_fighters_and_the_ground() -> void:
	var lights: Array[Node] = _lantern_lights(arena)
	assert_eq(lights.size(), arena.layout.lantern_angles.size(), "one light per lantern")
	for i: int in lights.size():
		var light := lights[i] as OmniLight3D
		var spot: Vector3 = ShrineLayout.polar(arena.layout.lantern_angles[i], arena.layout.lantern_radius)
		assert_lt(Vector2(light.position.x - spot.x, light.position.z - spot.z).length(), 0.25, "light %d in its lantern" % i)
		assert_between(light.position.y, 1.5, 2.5, "light %d at the lantern's fire" % i)
		assert_ne(light.light_cull_mask & LookPalette.GROUND_LAYER, 0, "light %d lights the ground, a natural light source" % i)
		assert_ne(light.light_cull_mask & LookPalette.FIGHTER_LAYER, 0, "light %d lights fighters" % i)
		assert_true(light.is_in_group(GraphicsApplier.GROUP_MINOR_LIGHT), "the preset turns light %d on or off" % i)
		assert_true(light.shadow_enabled, "light %d casts shadows, as the look test settled (task 43)" % i)
		assert_eq(light.light_color, LookPalette.LANTERN_EMBER, "light %d glows ember" % i)
		assert_gte(light.omni_range, 9.0, "light %d reaches into the courtyard" % i)
		assert_gt(light.light_size, 0.0, "light %d casts soft shadows, like a flame" % i)
		assert_gte(light.light_energy, 3.0, "light %d is bright" % i)


## Where the halos sit is for the shots: the headless renderer keeps no
## MultiMesh transforms to read back.
func test_every_lantern_has_a_halo() -> void:
	var halos := arena.get_node("Platform/LanternHalos") as MultiMeshInstance3D
	assert_eq(halos.multimesh.instance_count, arena.layout.lantern_angles.size())
	assert_eq(halos.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_lantern_lights_flicker_round_their_brightness() -> void:
	var light := _lantern_lights(arena)[0] as OmniLight3D
	var energies: Dictionary[float, bool] = {}
	for frame: int in 12:
		simulate(arena, 1, 0.05)
		energies[snappedf(light.light_energy, 0.001)] = true
		assert_between(light.light_energy, ShrinePlatform.LANTERN_ENERGY * 0.8, ShrinePlatform.LANTERN_ENERGY * 1.2)
	assert_gt(energies.size(), 6, "it flickers")


## A stand-in for a bought model: an empty Node3D scene.
func _bought_art() -> PackedScene:
	var scene := PackedScene.new()
	var model := Node3D.new()
	model.name = "BoughtArt"
	scene.pack(model)
	model.free()
	return scene


## A shrine built with the shared layout, but with bought art for kinds.
func _shrine_with_art(kinds: Array[StringName]) -> MoonlitShrine:
	var layout := arena.layout.duplicate() as ShrineLayout
	var art := _bought_art()
	# A dictionary of its own: a shallow duplicate shares the cached layout's.
	var art_by_kind: Dictionary[StringName, PackedScene] = {}
	for kind: StringName in kinds:
		art_by_kind[kind] = art
	layout.prop_scenes = art_by_kind
	var shrine: MoonlitShrine = (load(SCENE) as PackedScene).instantiate()
	shrine.layout = layout
	add_child_autofree(shrine)
	return shrine


func _props_aabb(shrine: MoonlitShrine, kit_name: String) -> AABB:
	return (shrine.get_node("Platform/Props/" + kit_name) as MeshInstance3D).get_aabb()


func test_a_scene_in_prop_scenes_replaces_the_procedural_lantern_at_the_same_spots() -> void:
	var shrine: MoonlitShrine = _shrine_with_art([&"lantern"])
	var layout: ShrineLayout = shrine.layout
	var placed: Array[Node] = shrine.get_node("Platform/Props").find_children("Lantern*", "Node3D", false, false)
	assert_eq(placed.size(), layout.lantern_angles.size(), "one bought lantern per spot")
	for i: int in placed.size():
		var spot: Vector3 = ShrineLayout.polar(layout.lantern_angles[i], layout.lantern_radius)
		var at: Vector3 = (placed[i] as Node3D).position
		assert_almost_eq(Vector2(at.x, at.z), Vector2(spot.x, spot.z), Vector2.ONE * 0.01, "bought lantern %d on its spot" % i)
	for node: Node in placed:
		assert_null(node.get_node_or_null("Paper"), "%s is the bought one, not the modelled lantern" % node.name)
	assert_eq(_lantern_lights(shrine).size(), layout.lantern_angles.size(), "the bought lanterns still light")
	assert_eq(_lantern_embers(shrine).size(), layout.lantern_angles.size(), "and give off embers")
	assert_eq(_props_aabb(shrine, "StoneDark"), _props_aabb(arena, "StoneDark"), "the pillars as they were without the bought lanterns")
	assert_eq(shrine.get_node("Platform/Wisteria").find_children("Wisteria*", "Node3D", false, false).size(),
		layout.trees.size(), "and the wisteria")


func test_every_prop_kind_can_be_swapped_for_bought_art() -> void:
	var shrine: MoonlitShrine = _shrine_with_art(ShrineLayout.PROP_KINDS)
	var layout: ShrineLayout = shrine.layout
	var expected: Dictionary[String, int] = {
		"Lantern": layout.lantern_angles.size(), "Torii": 2, "Pillar": layout.pillars.size(),
		"Wisteria": layout.trees.size(),
		"Pagoda": 0, "TempleHall": 0,
	}
	for c: Vector4 in layout.cliffs:
		if c.w >= ShrineBackdrop.PAGODA_CLIFF:
			expected["Pagoda"] += 1
		elif c.w >= ShrineBackdrop.TEMPLE_CLIFF:
			expected["Pagoda"] += 1
			expected["TempleHall"] += 1
		else:
			expected["TempleHall"] += 1
	var props: Node = shrine.get_node("Platform/Props")
	var cliffs: Node = shrine.get_node("World/Cliffs")
	for kind: String in expected:
		var parent: Node = cliffs if kind in ["Pagoda", "TempleHall"] else props
		var placed: int = 0
		for child: Node in parent.get_children():
			if child.name.begins_with(kind) and child.name.trim_prefix(kind).is_valid_int():
				placed += 1
		assert_eq(placed, expected[kind], "bought %s in every spot" % kind)
	assert_eq(shrine.get_node("Platform/Wisteria").find_children("Wisteria*", "Node3D", false, false).size(), 0,
		"no procedural wisteria left")
	for parent: Node in [props, cliffs]:
		for child: Node in parent.get_children():
			for part: String in ["Stone", "Wood", "Body"]:
				assert_null(child.get_node_or_null(part), "%s is the bought one, not the modelled one" % child.name)
	var rocks: Array[Node] = shrine.get_node("Underside/FloatingRocks").get_children()
	assert_eq(rocks.size(), layout.floating_rocks.size(), "a bought floating rock in every spot")
	for rock: Node in rocks:
		assert_null(rock.get_node_or_null("Rock"), "%s is the bought one" % rock.name)


func test_bought_art_under_an_unknown_kind_is_reported() -> void:
	var shrine: MoonlitShrine = _shrine_with_art([&"lanturn"])
	assert_push_error("lanturn")
	assert_not_null(shrine.get_node_or_null("Platform/Props/Lantern0/Paper"), "the lanterns are built as usual")


# ------------------------------------------------------------------ the underside

## How far the ledge reaches at angle_deg: its farthest vertex within 4
## degrees of it.
func _ledge_reach(ledge: MeshInstance3D, angle_deg: float) -> float:
	var best: float = 0.0
	for w: Vector3 in _world_vertices(ledge):
		if absf(wrapf(rad_to_deg(atan2(w.x, w.z)) - angle_deg, -180.0, 180.0)) < 4.0:
			best = maxf(best, Vector2(w.x, w.z).length())
	return best


func test_the_ledge_on_the_ground_layer_reaches_past_every_prop_on_it() -> void:
	var ledge := arena.get_node("Underside/Ledge") as MeshInstance3D
	assert_eq(ledge.layers, LookPalette.GROUND_LAYER, "lantern lights skip it")
	var spots: Array[Vector2] = []
	for angle: float in arena.layout.lantern_angles:
		spots.append(Vector2(angle, arena.layout.lantern_radius))
	for p: Vector4 in arena.layout.pillars:
		spots.append(Vector2(p.x, p.y))
	for t: Vector4 in arena.layout.trees:
		spots.append(Vector2(t.x, t.y))
	for spot: Vector2 in spots:
		assert_gt(_ledge_reach(ledge, spot.x), spot.y + 0.6, "the ledge holds the prop at %.0f degrees, %.1f m" % [spot.x, spot.y])
	var aabb: AABB = ledge.get_aabb()
	assert_lt(aabb.position.y, ShrinePlatform.LEDGE_Y, "it droops toward its rim")
	assert_lt(aabb.end.y, 0.0, "under the floor's height")


func test_the_rock_under_the_rim_hangs_on_its_own_layer() -> void:
	var below: Array[Node] = arena.get_node("Underside/BelowDeck").find_children("*", "GeometryInstance3D", true, false)
	below.append(arena.get_node("World/CragMist"))
	var names: Array[StringName] = []
	for node: Node in below:
		names.append(node.name)
		assert_eq((node as GeometryInstance3D).layers, LookPalette.BELOW_DECK_LAYER, "%s on the below-deck layer only" % node.name)
	for part: StringName in [&"Crag", &"Roots", &"Chains", &"CragMist"]:
		assert_has(names, part)
	var crag: AABB = (arena.get_node("Underside/BelowDeck/Crag") as MeshInstance3D).get_aabb()
	assert_lt(crag.end.y, ShrinePlatform.LEDGE_Y, "the crag hangs under the ledge")
	assert_gt(crag.size.y, arena.layout.crag_depth * 0.9, "down to its tip")


## The ledge hides the crag from every camera above it and inside its rim:
## the crag never reaches out past the rim, and the cameras' limit stays
## inside the ledge's least reach.
## (Keys in quarter degrees: the lattice's columns sit every 3.75 degrees.)
func test_the_crag_stays_inside_the_ledges_rim() -> void:
	assert_lt(arena.def.camera_max_radius, arena.layout.crag_radius, "cameras stay over the ledge")
	var ledge := arena.get_node("Underside/Ledge") as MeshInstance3D
	var rim: Dictionary[int, float] = {}
	for w: Vector3 in _world_vertices(ledge):
		var key: int = roundi(rad_to_deg(atan2(w.x, w.z)) * 4.0)
		rim[key] = maxf(rim.get(key, 0.0), Vector2(w.x, w.z).length())
	var outside: int = 0
	var worst: float = 0.0
	for w: Vector3 in _world_vertices(arena.get_node("Underside/BelowDeck/Crag") as MeshInstance3D):
		var key: int = roundi(rad_to_deg(atan2(w.x, w.z)) * 4.0)
		var past: float = Vector2(w.x, w.z).length() - rim.get(key, INF)
		if past > 0.001:
			outside += 1
			worst = maxf(worst, past)
	assert_eq(outside, 0, "crag points past the rim at their angle (worst %.2f m)" % worst)


func _camera_at(pos: Vector3) -> Camera3D:
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.global_position = pos
	return cam


func _draws_below_deck(cam: Camera3D) -> bool:
	return cam.cull_mask & LookPalette.BELOW_DECK_LAYER != 0


func test_the_fight_and_menu_cameras_leave_out_the_rock_under_the_rim() -> void:
	var rig: CameraRig = autofree(CameraRig.new())
	var d: ArenaDef = arena.def
	rig.apply_arena(d.camera_max_radius, d.camera_far, d.camera_rim_height, d.camera_rim_from(), d.camera_rim_full())
	# The rig clamps the fight cameras to its limit, but not the menu's orbit.
	var spots: Array[Vector3] = [rig.menu_target(0.0)["pos"], rig.menu_target(10.0)["pos"]]
	for side: int in 2:
		var me: Vector3 = arena.def.spawn_point(side).origin
		var them: Vector3 = arena.def.spawn_point(1 - side).origin
		# At the spawns, and backed against opposite walls, where the cameras
		# go furthest out and highest.
		var at_wall: Vector3 = me.normalized() * (arena.def.walkable_radius - 0.5)
		for pair: Array in [[me, them], [at_wall, -at_wall]]:
			var a: Vector3 = pair[0]
			var b: Vector3 = pair[1]
			var dir: Vector3 = (b - a).normalized()
			spots.append(rig.rise_over_rim(rig.clamp_to_arena(rig.follow_target(a, b, dir)["pos"])))
			spots.append(rig.rise_over_rim(rig.clamp_to_arena(rig.watch_target(a, b, dir, 0.0)["pos"])))
	for pos: Vector3 in spots:
		var cam: Camera3D = _camera_at(pos)
		arena.cull_below_deck(cam)
		assert_false(_draws_below_deck(cam), "a camera at %s leaves it out" % cam.global_position)


func test_cameras_beyond_or_below_the_courtyard_draw_the_rock_under_the_rim() -> void:
	var a: float = deg_to_rad(228.0)
	var establishing := Vector3(sin(a) * 58.0, -5.0, cos(a) * 58.0)
	for pos: Vector3 in [establishing, Vector3(-12.0, 90.0, 0.0), Vector3(0.0, -2.0, 10.0), Vector3(30.0, 3.0, 0.0)]:
		var cam: Camera3D = _camera_at(pos)
		cam.cull_mask &= ~LookPalette.BELOW_DECK_LAYER
		arena.cull_below_deck(cam)
		assert_true(_draws_below_deck(cam), "a camera at %s draws it" % pos)


func test_each_camera_is_decided_on_its_own() -> void:
	var fight: Camera3D = _camera_at(Vector3(0.0, 2.0, -8.0))
	var far: Camera3D = _camera_at(Vector3(0.0, -5.0, 58.0))
	far.cull_mask &= ~LookPalette.BELOW_DECK_LAYER
	arena.cull_below_deck(fight)
	arena.cull_below_deck(far)
	assert_false(_draws_below_deck(fight))
	assert_true(_draws_below_deck(far))
	assert_eq(fight.cull_mask | LookPalette.BELOW_DECK_LAYER, far.cull_mask, "no other layer changes")


func test_each_frame_the_arena_decides_for_its_viewports_camera() -> void:
	var cam: Camera3D = _camera_at(Vector3(0.0, -5.0, 58.0))
	cam.make_current()
	cam.cull_mask &= ~LookPalette.BELOW_DECK_LAYER
	simulate(arena, 1, 0.016)
	assert_true(_draws_below_deck(cam), "from out beyond the edge")
	cam.global_position = Vector3(0.0, 2.0, -8.0)
	simulate(arena, 1, 0.016)
	assert_false(_draws_below_deck(cam), "from the courtyard")


func test_floating_rocks_bob_over_their_spots() -> void:
	var rocks: Array[Node] = arena.get_node("Underside/FloatingRocks").get_children()
	assert_eq(rocks.size(), arena.layout.floating_rocks.size())
	var start: Array[float] = []
	for rock: Node in rocks:
		start.append((rock as Node3D).position.y)
	simulate(arena, 30, 0.1)
	var moved: bool = false
	for i: int in rocks.size():
		var f: Vector4 = arena.layout.floating_rocks[i]
		var home: Vector3 = ShrineLayout.polar(f.x, f.y, f.z)
		var at: Vector3 = (rocks[i] as Node3D).position
		assert_almost_eq(Vector2(at.x, at.z), Vector2(home.x, home.z), Vector2.ONE * 0.001, "rock %d stays over its spot" % i)
		assert_between(at.y, home.y - ShrineUnderside.BOB_HEIGHT - 0.001, home.y + ShrineUnderside.BOB_HEIGHT + 0.001, "rock %d bobs gently" % i)
		moved = moved or not is_equal_approx(at.y, start[i])
	assert_true(moved, "they bob")


# ------------------------------------------------------------------ the backdrop

## The camera's far clip takes in the whole backdrop from anywhere the
## cameras go (the menu's orbit, unclamped, included), and the arena hands
## it to the match's camera (test_match_scene checks the camera takes it).
## The mist and the lake lanterns aren't measured: the headless renderer
## keeps no MultiMesh transforms.
func test_the_far_clip_reaches_the_farthest_ring_and_the_camera_takes_it() -> void:
	var rig: CameraRig = autofree(CameraRig.new())
	var menu: Vector3 = rig.menu_target(0.0)["pos"]
	var reach: float = maxf(Vector2(arena.def.camera_max_radius, menu.y).length(), menu.length())
	var farthest_ring: float = 0.0
	for ring: Node in arena.get_node("World/Mountains").get_children():
		for v: Vector3 in _world_vertices(ring as MeshInstance3D):
			farthest_ring = maxf(farthest_ring, Vector2(v.x, v.z).length())
	assert_gt(farthest_ring, arena.layout.mountain_layers[-1].x, "out to the farthest ring")
	var farthest: float = 0.0
	for mi: Node in arena.get_node("World").find_children("*", "MeshInstance3D", true, false):
		for v: Vector3 in _world_vertices(mi as MeshInstance3D):
			farthest = maxf(farthest, v.length())
	assert_lt(farthest + reach, arena.def.camera_far, "the whole backdrop inside the far clip")
	assert_eq(MatchView.arena_camera_data(arena)["far"], arena.def.camera_far, "handed to the match's camera")


func test_each_level_of_scenery_detail_draws_its_share_of_the_backdrop() -> void:
	var world: Node = arena.get_node("World")
	for level: int in SCENERY:
		var preset: GraphicsPreset = GraphicsPreset.ultra().duplicate() as GraphicsPreset
		preset.scenery_detail = level
		GraphicsApplier.apply_to_tree(preset, arena)
		var drawn: Array = []
		for part: Node in world.get_children():
			if (part as Node3D).visible:
				drawn.append(String(part.name))
		drawn.sort()
		var expected: Array = SCENERY[level].duplicate()
		expected.sort()
		assert_eq(drawn, expected, "detail %d draws its share" % level)
	for id: StringName in GraphicsPreset.IDS:
		assert_eq(GraphicsPreset.load_id(id).scenery_detail, 2, "%s draws the whole backdrop" % id)


## The ranges dip toward the moon, so its disc clears everything in the
## backdrop in player one's first view.
func test_the_moon_clears_the_backdrop_in_player_ones_view() -> void:
	var eye: Vector3 = _player_one_camera().global_position
	var moon: Vector3 = arena.layout.moon_direction.normalized()
	var moon_angle: float = atan2(moon.x, moon.z)
	var reach: float = float(_sky_param(arena, &"moon_radius")) + MOON_MARGIN
	var highest: float = -INF
	for mi: Node in arena.get_node("World").find_children("*", "MeshInstance3D", true, false):
		for v: Vector3 in _world_vertices(mi as MeshInstance3D):
			var d: Vector3 = v - eye
			if absf(angle_difference(atan2(d.x, d.z), moon_angle)) <= reach:
				highest = maxf(highest, atan2(d.y, Vector2(d.x, d.z).length()))
	assert_gt(highest, 0.0, "the mountains stand under the moon")
	assert_lt(highest, asin(moon.y) - reach, "and below its disc")


## The rings in front of the lake's middle dip under the water toward the
## moon, so from outside the walls (the establishing view) the lake shows
## under the moon, with its glint. (The fight cameras look over the parapet,
## which hides anything as far below the horizon as the water.)
func test_the_rings_in_front_of_the_lake_dip_under_the_water_toward_the_moon() -> void:
	var moon: Vector3 = arena.layout.moon_direction.normalized()
	var moon_angle: float = atan2(moon.x, moon.z)
	var lake: Vector4 = arena.layout.lake
	var in_front: int = 0
	for i: int in arena.layout.mountain_layers.size():
		if arena.layout.mountain_layers[i].x >= lake.y:
			continue
		in_front += 1
		var highest: float = -INF
		for v: Vector3 in _world_vertices(arena.get_node("World/Mountains/Range%d" % i) as MeshInstance3D):
			if absf(angle_difference(atan2(v.x, v.z), moon_angle)) <= deg_to_rad(3.0):
				highest = maxf(highest, v.y)
		assert_lt(highest, lake.z, "Range%d dips under the water" % i)
	assert_gt(in_front, 0, "some rings stand in front of the lake")


## Far scenery stays cheap: on any preset nothing in it casts a shadow.
func test_the_backdrop_casts_no_shadows() -> void:
	GraphicsApplier.apply_to_tree(GraphicsPreset.load_id(&"high"), arena)
	var parts: Array[Node] = arena.get_node("World").find_children("*", "GeometryInstance3D", true, false)
	assert_gt(parts.size(), 0, "the backdrop has parts")
	for node: Node in parts:
		var geo := node as GeometryInstance3D
		assert_eq(geo.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % geo.name)


func test_the_backdrop_shaders_take_the_look_noise() -> void:
	var seen: Dictionary[Shader, bool] = {}
	for node: Node in arena.get_node("World").find_children("*", "GeometryInstance3D", true, false):
		var m := (node as GeometryInstance3D).material_override as ShaderMaterial
		if m == null or not BACKDROP_SHADERS.has(m.shader):
			continue
		seen[m.shader] = true
		assert_eq(_param(m, LookNoise.PARAM), LookNoise.texture(), "%s gets the noise" % node.name)
	assert_eq(seen.size(), BACKDROP_SHADERS.size(), "every backdrop shader is in use")


# ------------------------------------------------------------------ particles

## The embers and ash.
func _particles(shrine: MoonlitShrine) -> Array[Node]:
	return shrine.get_node("Particles").find_children("*", "GPUParticles3D", true, false)


func _lantern_embers(shrine: MoonlitShrine) -> Array[Node]:
	return shrine.get_node("Particles").find_children("LanternEmbers*", "GPUParticles3D", false, false)


func _process_material(emitter: Node) -> ParticleProcessMaterial:
	return (emitter as GPUParticles3D).process_material as ParticleProcessMaterial


## The slowest a particle of m climbs (m/s; negative when it falls): its
## slowest launch, along the middle of its aim. The spread scatters each one
## about that.
func _slowest_climb(m: ParticleProcessMaterial) -> float:
	return m.initial_velocity_min * m.direction.normalized().y


## A particle of emitter launched at the middle speed, along the middle of
## its aim (m/s).
func _middle_launch(emitter: GPUParticles3D) -> Vector3:
	var m := _process_material(emitter)
	return m.direction.normalized() * (m.initial_velocity_min + m.initial_velocity_max) * 0.5


func test_embers_rise_from_every_lanterns_fire() -> void:
	var lights: Array[Node] = _lantern_lights(arena)
	assert_eq(_lantern_embers(arena).size(), lights.size(), "one ember emitter per lantern")
	for i: int in lights.size():
		var embers := arena.get_node("Particles/LanternEmbers%d" % i) as GPUParticles3D
		var fire: Vector3 = (lights[i] as Node3D).global_position
		assert_almost_eq(embers.global_position, fire, Vector3.ONE * 0.01, "embers %d at the lantern's fire" % i)
		var m := _process_material(embers)
		assert_gt(_slowest_climb(m), 0.0, "even the slowest of embers %d climb" % i)
		assert_gte(m.gravity.y, 0.0, "embers %d aren't pulled down" % i)


## The updraft carries embers up from the open air under the ledge's rim,
## all round the island, and even the slowest clear the floor before they
## fade.
func test_embers_rise_past_the_ledges_rim_on_the_updraft() -> void:
	var updraft := arena.get_node("Particles/EdgeEmbers") as GPUParticles3D
	var m := _process_material(updraft)
	assert_eq(m.emission_shape, ParticleProcessMaterial.EMISSION_SHAPE_RING, "all round the island")
	assert_eq(m.emission_ring_axis, Vector3.UP)
	var rim: float = 0.0
	for v: Vector3 in _world_vertices(arena.get_node("Underside/Ledge") as MeshInstance3D):
		rim = maxf(rim, Vector2(v.x, v.z).length())
	assert_gt(m.emission_ring_inner_radius, rim, "out past the rim, not in the rock")
	var lowest: float = updraft.global_position.y - m.emission_ring_height * 0.5
	assert_lt(lowest + m.emission_ring_height, ShrinePlatform.LEDGE_Y, "under it")
	var t: float = updraft.lifetime
	var rise: float = _slowest_climb(m) * t + 0.5 * (m.gravity.y - m.damping_max) * t * t
	assert_gt(lowest + rise, 0.0, "the slowest from the lowest still clear the floor")


## Ash falls over the whole floor from above the torii, the upwind edge too,
## and even the slowest from the lowest reaches the floor while it still
## shows (its colour ramp fades it over the last third of its life).
func test_ash_falls_across_the_courtyard() -> void:
	var ash := arena.get_node("Particles/Ash") as GPUParticles3D
	var m := _process_material(ash)
	assert_eq(m.emission_shape, ParticleProcessMaterial.EMISSION_SHAPE_BOX)
	var from := AABB(ash.global_position - m.emission_box_extents, m.emission_box_extents * 2.0)
	var floor_radius: float = arena.def.floor_radius
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var c: Vector2 = corner * floor_radius
		assert_true(from.has_point(Vector3(c.x, from.get_center().y, c.y)), "over all the floor (%s)" % corner)
	assert_gt(from.position.y, arena.layout.torii_height, "from above the torii")
	# A flake from the middle of the band at the middle speed drifts this far
	# by the time it lands, so the one landing on the upwind edge set off
	# that far further upwind.
	var middle: Vector3 = _middle_launch(ash)
	var drift: Vector2 = Vector2(middle.x, middle.z) * (from.get_center().y / -middle.y)
	var source: Vector2 = -arena.layout.wind.normalized() * floor_radius - drift
	assert_true(from.has_point(Vector3(source.x, from.get_center().y, source.y)), "the flakes landing on the upwind edge set off over the island")
	var t: float = ash.lifetime * 0.75
	var fall: float = -_slowest_climb(m) * t + 0.5 * (-m.gravity.y - m.damping_max) * t * t
	assert_gt(fall, from.position.y, "the slowest from the lowest reach the floor by three quarters of their life")


## One wind, the layout's, carries the embers and ash the way the sea of
## clouds drifts, and no turbulence takes it away: Godot's turbulence steers
## every particle toward its noise field each frame, and measured in a window
## even 1% held the updraft's embers to a third of their climb and kept the
## ash off the floor.
func test_the_embers_and_ash_drift_with_the_wind_the_clouds_drift_on() -> void:
	var wind: Vector2 = arena.layout.wind
	for clouds: String in ["CloudSea", "CloudVeil"]:
		var mat := (arena.get_node("World/" + clouds) as GeometryInstance3D).material_override as ShaderMaterial
		assert_almost_eq(_param(mat, &"drift_direction") as Vector2, wind.normalized(), Vector2.ONE * 0.001, "%s drifts with the wind" % clouds)
	for emitter: Node in _particles(arena):
		var m := _process_material(emitter)
		assert_false(m.turbulence_enabled, "%s keeps to the wind" % emitter.name)
		var middle: Vector3 = _middle_launch(emitter as GPUParticles3D)
		assert_almost_eq(Vector2(middle.x, middle.z), wind, Vector2.ONE * 0.01, "%s drifts at the wind's speed" % emitter.name)
		assert_eq(Vector2(m.gravity.x, m.gravity.z), Vector2.ZERO, "and nothing else pushes %s sideways" % emitter.name)


func test_the_embers_and_ash_cast_no_shadows() -> void:
	for emitter: Node in _particles(arena):
		assert_eq((emitter as GPUParticles3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % emitter.name)


## Close up they would swell into blots over the fighters.
func test_the_embers_and_ash_fade_out_in_front_of_the_camera() -> void:
	for emitter: Node in _particles(arena):
		var mat := ((emitter as GPUParticles3D).draw_pass_1 as QuadMesh).material as ShaderMaterial
		var fade: Vector2 = _param(mat, &"near_fade")
		assert_gt(fade.y, 2.0, "%s is still fading 2 m from the camera" % emitter.name)
		assert_lt(fade.x, fade.y, "%s fades in smoothly" % emitter.name)


func test_each_preset_thins_out_the_embers_and_ash() -> void:
	var emitters: Array[Node] = _particles(arena)
	for id: StringName in GraphicsPreset.IDS:
		var preset: GraphicsPreset = GraphicsPreset.load_id(id)
		GraphicsApplier.apply_to_tree(preset, arena)
		for emitter: Node in emitters:
			assert_almost_eq((emitter as GPUParticles3D).amount_ratio, preset.particle_ratio, 0.001, "%s: %s" % [id, emitter.name])


# ------------------------------------------------------------------ presets

func test_the_saved_preset_is_applied_when_it_loads() -> void:
	_settings().graphics_preset_id = &"low"
	var low_shrine: MoonlitShrine = (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(low_shrine)
	var env: Environment = _environment(low_shrine)
	assert_true(env.has_meta(GraphicsApplier.META_BASE_VOLUMETRIC), "the preset reached the environment")
	assert_false(env.volumetric_fog_enabled, "no volumetric fog on Low")
	assert_false(env.ssao_enabled, "no ambient occlusion on Low")
	assert_true(LookGrade.is_graded(env), "Low keeps Ultra's grade")


func test_every_preset_applies_to_the_courtyard_and_its_props() -> void:
	for id: StringName in GraphicsPreset.IDS:
		var preset: GraphicsPreset = GraphicsPreset.load_id(id)
		GraphicsApplier.apply_to_tree(preset, arena)
		for light: Node in _lantern_lights(arena):
			assert_eq((light as Light3D).visible, preset.minor_lights, "%s: lantern lights" % id)
		var moon := arena.get_node("Lights/MoonLight") as DirectionalLight3D
		assert_eq(moon.directional_shadow_max_distance, preset.shadow_max_distance, "%s: moon shadows" % id)
		var env: Environment = _environment(arena)
		assert_eq(env.fog_enabled, preset.fog_enabled, "%s: fog" % id)
		assert_eq(env.volumetric_fog_enabled, preset.volumetric_fog, "%s: volumetric fog" % id)
		assert_eq(env.glow_enabled, preset.glow_enabled, "%s: bloom" % id)
		assert_true(LookGrade.is_graded(env), "%s: the grade" % id)
