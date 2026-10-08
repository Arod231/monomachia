extends GutTest
## The Moonlit Shrine's wisteria (milestone-1 task 48, ShrineWisteria): five
## unique giant trees on the ledge in the realistic look's bark, their roots
## short of the courtyard's floor and the wall's inner face, their canopies
## over the arena above the fighters and clear of the moon, each lighting the
## fight purple under its blossoms and dropping glowing petals, with petal
## lights drifting down among them; young ones on the floating rocks.

const SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"

var arena: MoonlitShrine


func before_all() -> void:
	arena = (load(SCENE) as PackedScene).instantiate()
	add_child(arena)


func after_all() -> void:
	arena.free()


func _grove() -> Node3D:
	return arena.get_node("Platform/Wisteria") as Node3D


func _trees() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i: int in arena.layout.trees.size():
		out.append(_grove().get_node("Wisteria%d" % i) as Node3D)
	return out


## Every vertex of the tree's meshes named *suffix, in world space.
func _vertices(tree: Node3D, suffix: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node: Node in tree.find_children("*" + suffix, "MeshInstance3D", false, false):
		var mi := node as MeshInstance3D
		var xform: Transform3D = mi.global_transform
		for s: int in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xform * v)
	return out


func test_five_unique_trees_stand_on_the_ledge_where_the_layout_puts_them() -> void:
	var trees: Array[Node3D] = _trees()
	assert_eq(trees.size(), 5, "five giant trees")
	var variants: Dictionary[int, bool] = {}
	for i: int in trees.size():
		var t: Vector4 = arena.layout.trees[i]
		variants[int(t.w)] = true
		var spot: Vector3 = ShrineLayout.polar(t.x, t.y, ShrinePlatform.LEDGE_Y)
		assert_almost_eq(trees[i].global_position, spot, Vector3.ONE * 0.01, "tree %d on its spot" % i)
		assert_gt(t.y, arena.def.camera_max_radius + 2.0, "tree %d out on the ledge" % i)
	assert_eq(variants.size(), ShrineWisteria.VARIANTS, "each of the five models once")


func test_the_trees_are_giants_with_thick_trunks() -> void:
	for tree: Node3D in _trees():
		var box := AABB()
		var first: bool = true
		for w: Vector3 in _vertices(tree, "_Bark"):
			box = AABB(w, Vector3.ZERO) if first else box.expand(w)
			first = false
		assert_gt(box.size.y, 15.0, "%s towers over the courtyard" % tree.name)
		assert_gt(maxf(box.size.x, box.size.z), 30.0, "and spreads wide")
		var trunk: float = 0.0
		var foot := Vector2(tree.global_position.x, tree.global_position.z)
		for w: Vector3 in _vertices(tree, "_Bark"):
			if absf(w.y - 3.0) < 0.3:
				trunk = maxf(trunk, Vector2(w.x, w.z).distance_to(foot))
		assert_gt(trunk, 1.0, "%s's trunk is over 2 m across at 3 m up" % tree.name)


func test_the_bark_is_the_scan_on_the_physically_based_surface() -> void:
	for tree: Node3D in _trees():
		var bark: Array[Node] = tree.find_children("*_Bark", "MeshInstance3D", false, false)
		assert_eq(bark.size(), 1, "%s has its bark" % tree.name)
		var m: Material = (bark[0] as MeshInstance3D).material_override
		assert_true(LookMaterials.is_physical(m), "%s's bark is a look surface" % tree.name)
		assert_eq(LookMaterials.surface_of(m), LookMaterials.Surface.PROP)
		var shader := m as ShaderMaterial
		assert_not_null(shader.get_shader_parameter(&"albedo_texture"), "in Bark Willow's colour")
		assert_not_null(shader.get_shader_parameter(&"normal_texture"), "with its relief")
		assert_gt(float(shader.get_shader_parameter(&"normal_strength")), 0.0)
		assert_eq(tree.find_children("*_Blossom", "MeshInstance3D", false, false).size(), 1, "%s blossoms" % tree.name)


## Out to the cameras' limit, a tree is either on the ledge and the wall's
## lip (its roots, outside the wall's inner face and no higher than its top)
## or up in the canopy, over CANOPY_FLOOR: never between, where it would
## stand between a camera and the fighters.
func test_nothing_of_a_tree_hangs_in_the_cameras_room() -> void:
	var room: float = arena.def.camera_max_radius + 0.2
	var lip: float = arena.def.wall_height + 0.4
	for tree: Node3D in _trees():
		var bad: int = 0
		var example := Vector3.ZERO
		for suffix: String in ["_Bark", "_Blossom"]:
			for w: Vector3 in _vertices(tree, suffix):
				var r: float = Vector2(w.x, w.z).length()
				if r >= room or w.y > ShrineWisteria.CANOPY_FLOOR:
					continue
				if suffix == "_Bark" and r > arena.def.wall_inner_radius() and w.y < lip:
					continue
				bad += 1
				example = w
		assert_eq(bad, 0, "%s keeps out of the cameras' room (e.g. %s)" % [tree.name, example])


func test_the_canopies_hang_over_the_arena_and_into_one_another() -> void:
	var over: int = 0
	var reach: Array[float] = []
	for tree: Node3D in _trees():
		var nearest: float = INF
		for w: Vector3 in _vertices(tree, "_Blossom"):
			nearest = minf(nearest, Vector2(w.x, w.z).length())
			if Vector2(w.x, w.z).length() < arena.def.walkable_radius:
				over += 1
		reach.append(nearest)
		assert_lt(nearest, arena.def.walkable_radius - 3.0, "%s's blossoms hang over the arena" % tree.name)
	assert_gt(over, 5000, "the canopy is full over the fight")
	# neighbours' canopies overlap: blossoms of one within a metre of the other's
	var trees: Array[Node3D] = _trees()
	var overlaps: int = 0
	for i: int in trees.size():
		var a: PackedVector3Array = _vertices(trees[i], "_Blossom")
		for j: int in range(i + 1, trees.size()):
			var b: PackedVector3Array = _vertices(trees[j], "_Blossom")
			var box: AABB = _box(b).grow(1.0)
			for k: int in range(0, a.size(), 16):
				if box.has_point(a[k]):
					overlaps += 1
					break
	assert_gte(overlaps, 4, "most neighbours' canopies overlap")


func _box(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	return box


## Whether point w is on the line to the moon from a camera within
## MOON_CAMERA_RADIUS of the centre, CAMERA_LOW to CAMERA_HIGH up: the
## cameras looking through it at the moon sit at w - s * moon.
func _in_moon_line(w: Vector3, moon: Vector3) -> bool:
	var hi: float = (w.y - ShrineWisteria.CAMERA_LOW) / moon.y
	if hi <= 0.0:
		return false
	var lo: float = maxf(0.0, (w.y - ShrineWisteria.CAMERA_HIGH) / moon.y)
	var a := Vector2(w.x - moon.x * lo, w.z - moon.z * lo)
	var b := Vector2(w.x - moon.x * hi, w.z - moon.z * hi)
	var ab: Vector2 = b - a
	var t: float = 0.0 if ab.length_squared() < 1e-9 else clampf(-a.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).length() < ShrineWisteria.MOON_CAMERA_RADIUS


func test_the_canopies_leave_the_moon_clear_from_the_fight() -> void:
	var moon: Vector3 = arena.layout.moon_direction.normalized()
	for tree: Node3D in _trees():
		var bad: int = 0
		for suffix: String in ["_Bark", "_Blossom"]:
			for w: Vector3 in _vertices(tree, suffix):
				bad += 1 if _in_moon_line(w, moon) else 0
		assert_eq(bad, 0, "%s keeps out of the moon's way" % tree.name)


func test_every_tree_lights_the_fight_purple_under_its_blossoms() -> void:
	for tree: Node3D in _trees():
		var markers: Array[Node3D] = ShrineWisteria.glow_markers(tree)
		assert_gte(markers.size(), 3, "%s has its blossom clusters" % tree.name)
		for marker: Node3D in markers:
			var light := marker.get_node("CanopyLight") as OmniLight3D
			assert_eq(light.light_color, ShrineWisteria.BLOSSOM)
			assert_true(light.shadow_enabled, "the fighters cast shadows in its light")
			assert_false(light.is_in_group(GraphicsApplier.GROUP_MINOR_LIGHT), "on every preset")
			assert_gt(marker.global_position.y, ShrineWisteria.CANOPY_FLOOR - 2.0, "up in the canopy")
			assert_gt(light.omni_range, marker.global_position.y + 2.0, "reaching down to the fighters")


## The trees cast no shadows on the arena, branches or blossoms (only the
## moon shafts in the mist take theirs, milestone-1 task 49:
## test_shrine_mist_sky.gd), and the glowing blossoms take none; the moon
## lights the arena blood red without a red haze in the mist, the fighters
## casting its shadows away from it.
func test_the_trees_cast_no_shadows_and_the_moon_lights_without_a_haze() -> void:
	for tree: Node3D in _trees():
		for node: Node in tree.find_children("*", "GeometryInstance3D", true, false):
			var geo := node as GeometryInstance3D
			if geo.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				assert_eq(geo.layers & LookPalette.CANOPY_LAYER, LookPalette.CANOPY_LAYER,
					"%s's %s casts its shadow only on the canopy layer" % [tree.name, node.name])
		for node: Node in tree.find_children("*_Blossom", "GeometryInstance3D", false, false):
			var glow := (node as GeometryInstance3D).material_override as ShaderMaterial
			assert_true(glow.shader in [ShrineWisteria.BLOSSOM_SHADER, ShrineWisteria.BLOSSOM_DOOM_SHADER],
				"%s's blossoms take no shadow" % tree.name)
	# both blossom shaders (the night's and match point's) take no shadow
	var blossom_code: String = FileAccess.get_file_as_string("res://shaders/wisteria_blossom.gdshaderinc")
	assert_eq(blossom_code.count("shadows_disabled"), 2, "the blossoms take no shadow, night or match point")
	var moon := arena.get_node("Lights/MoonLight") as DirectionalLight3D
	assert_ne(moon.light_cull_mask & LookPalette.GROUND_LAYER, 0, "the moon lights the arena")
	assert_eq(moon.light_volumetric_fog_energy, 0.0, "no red haze in the mist")
	assert_true(moon.shadow_enabled, "the fighters cast its shadows")
	assert_eq(moon.shadow_caster_mask & LookPalette.CANOPY_LAYER, 0, "the trees don't")
	assert_gt(moon.light_color.r, moon.light_color.g * 4.0, "blood red")
	assert_almost_eq(moon.global_transform.basis.z, arena.layout.moon_direction.normalized(), Vector3.ONE * 0.01, "from the moon")
	assert_null(arena.get_node_or_null("Lights/MoonRays"))


func _canopy_lights() -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for node: Node in _grove().find_children("CanopyLight", "OmniLight3D", true, false):
		out.append(node as OmniLight3D)
	return out


## How brightly the canopy lights reach a spot of the floor: each light's
## energy over the distance squared, inside its range.
func _canopy_light_at(spot: Vector3) -> float:
	var sum: float = 0.0
	for light: OmniLight3D in _canopy_lights():
		var d: float = light.global_position.distance_to(spot)
		if d < light.omni_range:
			sum += light.light_energy * pow(1.0 - d / light.omni_range, light.omni_attenuation) / maxf(d * d, 1.0)
	return sum


## The blossoms light the arena from where they hang, not as a filter over
## it: their lights hang under the canopy over the courtyard and reach every
## spot of the floor, brightest under the canopy and fading toward the
## centre, and keep out of the fog, so no purple haze hangs over the fight.
func test_the_blossoms_light_the_arena_in_pools_under_the_canopy() -> void:
	var lights: Array[OmniLight3D] = _canopy_lights()
	var over: int = 0
	for light: OmniLight3D in lights:
		var at: Vector3 = light.global_position
		if Vector2(at.x, at.z).length() < arena.def.camera_max_radius:
			over += 1
		assert_eq(light.light_cull_mask & LookPalette.GROUND_LAYER, LookPalette.GROUND_LAYER, "it lights the floor")
		assert_lte(light.light_volumetric_fog_energy, 0.3, "no purple haze in the fog")
	assert_gte(over, 15, "most canopy lights hang over the courtyard")
	var r: float = arena.def.walkable_radius
	for x: int in range(-15, 16, 3):
		for z: int in range(-15, 16, 3):
			var spot := Vector3(x, 0.0, z)
			if Vector2(spot.x, spot.z).length() <= r:
				assert_gt(_canopy_light_at(spot), 0.0, "the blossoms reach the floor at %s" % spot)
	# under the canopy (each light's foot) against the centre
	var under: float = 0.0
	for light: OmniLight3D in lights:
		var foot := Vector3(light.global_position.x, 0.0, light.global_position.z)
		if foot.length() < r:
			under = maxf(under, _canopy_light_at(foot))
	assert_gt(under, _canopy_light_at(Vector3.ZERO) * 1.5, "pools of light under the canopy, dimmer at the centre")


## Like the reference the owner chose: the blossoms glow pink-lavender, past
## the bloom's threshold so they halo softly, but not so bright they glare.
func test_the_blossoms_glow_softly() -> void:
	for tree: Node3D in _trees():
		var blossom := tree.find_children("*_Blossom", "MeshInstance3D", false, false)[0] as MeshInstance3D
		var m := blossom.material_override as ShaderMaterial
		assert_not_null(m, "%s's blossoms wear the glow" % tree.name)
		assert_eq(m.shader, ShrineWisteria.BLOSSOM_SHADER)
		assert_not_null(m.get_shader_parameter(&"albedo_texture"), "glowing in the raceme's shape")
		assert_eq(m.get_shader_parameter(&"emission_color"), ShrineWisteria.BLOSSOM_GLOW)
		assert_almost_eq(float(m.get_shader_parameter(&"alpha_scissor")), 0.5, 0.001, "cut out by the raceme")
		assert_eq(blossom.gi_mode, GeometryInstance3D.GI_MODE_STATIC, "its glow lights what's round it")
		var glow: Color = ShrineWisteria.BLOSSOM_GLOW * float(m.get_shader_parameter(&"emission_energy"))
		assert_between(maxf(glow.r, maxf(glow.g, glow.b)), 1.5, 4.0, "past the bloom's threshold, short of glare")
	assert_gt(ShrineWisteria.BLOSSOM_GLOW.b, ShrineWisteria.BLOSSOM_GLOW.g, "lavender")
	assert_gt(ShrineWisteria.BLOSSOM_GLOW.r, ShrineWisteria.BLOSSOM_GLOW.g, "toward pink")


func test_petals_fall_from_every_canopy_on_the_presets_particles() -> void:
	for i: int in arena.layout.trees.size():
		var petals := _grove().get_node("Petals%d" % i) as GPUParticles3D
		assert_true(petals.is_in_group(GraphicsApplier.GROUP_PARTICLES), "the presets thin them")
		assert_eq(petals.amount, ShrineWisteria.PETALS)
		assert_eq(petals.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_gt(petals.global_position.y, ShrineWisteria.CANOPY_FLOOR, "from up in the canopy")
		var m := petals.process_material as ParticleProcessMaterial
		assert_gte(m.scale_max, 0.14, "petals big enough to see falling")
		var ramp: Gradient = (m.color_ramp as GradientTexture1D).gradient
		var peak: float = 0.0
		for c: Color in ramp.colors:
			peak = maxf(peak, maxf(c.r, maxf(c.g, c.b)))
		assert_between(peak, 1.5, 4.0, "glowing softly, as the blossoms do")


func test_petal_lights_drift_down_and_start_again() -> void:
	var lights: Array[Node] = _grove().get_node("PetalLights").get_children()
	assert_eq(lights.size(), ShrineWisteria.PETAL_LIGHTS)
	var light := lights[0] as OmniLight3D
	assert_true(light.is_in_group(GraphicsApplier.GROUP_PETAL_LIGHT), "Low drops them")
	assert_false(light.shadow_enabled)
	var from: Vector3 = light.get_meta(&"from")
	var calm := Wind.new()
	calm.speed = 0.0
	ShrineWisteria.drift_petal_lights(_grove(), 0.0, calm)
	var start: float = light.position.y
	ShrineWisteria.drift_petal_lights(_grove(), 4.0, calm)
	assert_lt(light.position.y, start - 1.0, "it falls")
	assert_gt(light.position.y, from.y - ShrineWisteria.PETAL_FALL - 0.01, "no further than its loop")
	var fall_time: float = ShrineWisteria.PETAL_FALL / ((ShrineWisteria.PETAL_FALL_SPEED.x + ShrineWisteria.PETAL_FALL_SPEED.y) * 0.5)
	ShrineWisteria.drift_petal_lights(_grove(), fall_time, calm)
	assert_almost_eq(light.position.y, start, 0.01, "and starts again")


func test_young_wisteria_grow_on_the_floating_rocks() -> void:
	var young: Array[Node] = arena.get_node("Underside/FloatingRocks").find_children("YoungWisteria", "Node3D", true, false)
	assert_gt(young.size(), 0, "the rocks carry young trees")
	for tree: Node in young:
		assert_eq(ShrineWisteria.glow_markers(tree as Node3D).size(), 0, "which light nothing")
		assert_lt((tree as Node3D).scale.x, 0.2, "small")


## Match point: the petals' glow and light turn blood red (never pink), and
## back to lavender.
func test_at_match_point_the_petals_glow_and_light_blood_red() -> void:
	ShrineWisteria.set_doom(_grove(), 1.0)
	var m := _grove().get_meta(&"blossom") as ShaderMaterial
	var red: Color = m.get_shader_parameter(&"emission_color")
	assert_gt(red.r, maxf(red.g, red.b) * 10.0, "a deep red, not pink")
	assert_lt(float(m.get_shader_parameter(&"emission_energy")), ShrineWisteria.BLOSSOM_EMISSION, "dimmer: doom, not neon")
	assert_true(m.get_shader_parameter(&"emission_multiply"), "the raceme's lavender never added to the red")
	assert_eq(m.shader, ShrineWisteria.BLOSSOM_DOOM_SHADER, "shining through the mist")
	for light: OmniLight3D in _canopy_lights():
		assert_gt(light.light_color.r, maxf(light.light_color.g, light.light_color.b) * 10.0, "the canopy lights blood red")
	var petals := _grove().get_node("Petals0") as GPUParticles3D
	var c: Color = ((petals.process_material as ParticleProcessMaterial).color_ramp as GradientTexture1D).gradient.colors[1]
	assert_gt(c.r, maxf(c.g, c.b) * 10.0, "the falling petals blood red")
	ShrineWisteria.set_doom(_grove(), 0.0)
	assert_eq(m.get_shader_parameter(&"emission_color"), ShrineWisteria.BLOSSOM_GLOW, "lavender again")
	assert_eq(m.shader, ShrineWisteria.BLOSSOM_SHADER)
	assert_eq(_canopy_lights()[0].light_color, ShrineWisteria.BLOSSOM)


func test_the_shrine_eases_into_match_point_and_out_of_it_at_once() -> void:
	arena.set_match_point(true)
	simulate(arena, 30, 0.05)
	assert_between(arena.match_point_doom(), 0.2, 0.9, "turning over a few seconds")
	simulate(arena, 80, 0.05)
	assert_eq(arena.match_point_doom(), 1.0, "blood red")
	arena.set_match_point(false)
	assert_eq(arena.match_point_doom(), 0.0, "a new match: lavender at once")
	assert_eq((_grove().get_meta(&"blossom") as ShaderMaterial).get_shader_parameter(&"emission_color"), ShrineWisteria.BLOSSOM_GLOW)


func test_match_point_is_the_round_after_a_side_reaches_two_wins() -> void:
	assert_false(MatchView.is_match_point([0, 0]))
	assert_false(MatchView.is_match_point([1, 1]))
	assert_true(MatchView.is_match_point([2, 0]))
	assert_true(MatchView.is_match_point([1, 2]))
