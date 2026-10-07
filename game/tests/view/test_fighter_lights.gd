extends GutTest
## Each fighter's own key and rim light (milestone-1 task 44): they touch
## only that fighter (its side's render layer, which its body and held
## weapons carry and nothing else does), stay out of the fog, hang where the
## look test lit it from and turn with it, and the key casts shadows on
## every preset but Low.

const SHRINE_SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"


func _view(side: int, weapon: StringName = &"katana") -> FighterView:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(&"hunter", side, weapon, side)
	v.show_lights(true)
	return v


static func _geometry(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		out.append(n as GeometryInstance3D)
	return out


func test_each_side_has_its_own_layer_beside_the_fighters_layer() -> void:
	assert_ne(LookPalette.side_layer(0), LookPalette.side_layer(1))
	for side: int in 2:
		var bit: int = LookPalette.side_layer(side)
		assert_eq(bit & (1 | LookPalette.FIGHTER_LAYER | LookPalette.GROUND_LAYER | LookPalette.BELOW_DECK_LAYER), 0,
			"side %d's layer is its own" % side)
		assert_eq(LookPalette.SIDE_LAYERS_MASK & bit, bit)


func test_the_lights_touch_only_their_own_fighter_and_no_fog() -> void:
	for side: int in 2:
		var v: FighterView = _view(side)
		for light: SpotLight3D in [v.lights.key, v.lights.rim]:
			assert_eq(light.light_cull_mask, LookPalette.side_layer(side), "%s lights side %d only" % [light.name, side])
			assert_eq(light.light_volumetric_fog_energy, 0.0, "%s stays out of the fog" % light.name)


func test_the_fighter_and_its_weapon_carry_its_side_s_layer_and_not_the_other_s() -> void:
	for side: int in 2:
		var v: FighterView = _view(side)
		var mine: int = LookPalette.side_layer(side)
		var theirs: int = LookPalette.side_layer(1 - side)
		var weapons: int = 0
		for g: GeometryInstance3D in _geometry(v.model):
			if g.layers & LookPalette.FIGHTER_LAYER == 0:
				continue
			assert_eq(g.layers & mine, mine, "side %d: %s is on its layer" % [side, g.name])
			assert_eq(g.layers & theirs, 0, "side %d: %s isn't on the other's" % [side, g.name])
			if v.model.weapon_root != null and v.model.weapon_root.is_ancestor_of(g):
				weapons += 1
		assert_gt(weapons, 0, "side %d's Katana is lit by its lights" % side)
	# a weapon picked up later, and a fighter moved to the other side, follow
	var v: FighterView = _view(0, &"fists")
	v.setup(&"hunter", 1, &"katana", 1)
	for g: GeometryInstance3D in _geometry(v.model):
		if g.layers & LookPalette.FIGHTER_LAYER:
			assert_eq(g.layers & LookPalette.SIDE_LAYERS_MASK, LookPalette.side_layer(1), "%s moved to side 1" % g.name)
	assert_eq(v.lights.key.light_cull_mask, LookPalette.side_layer(1))


func test_the_key_hangs_ahead_and_left_and_the_rim_behind_both_above_aimed_at_the_chest() -> void:
	var v: FighterView = _view(0)
	var key: SpotLight3D = v.lights.key
	var rim: SpotLight3D = v.lights.rim
	# the fighter's own space: +Z ahead, +X its left
	assert_gt(key.position.z, 1.0, "the key ahead")
	assert_gt(key.position.x, 1.0, "and to its left")
	assert_lt(rim.position.z, -1.0, "the rim behind")
	assert_gt(key.position.y, FighterLights.CHEST.y, "the key above the chest")
	assert_gt(rim.position.y, key.position.y, "the rim higher still")
	for light: SpotLight3D in [key, rim]:
		var aim: Vector3 = -light.transform.basis.z
		assert_almost_eq(aim, (FighterLights.CHEST - light.position).normalized(), Vector3.ONE * 1e-4, "%s aims at the chest" % light.name)
		assert_gte(light.spot_range, light.position.distance_to(FighterLights.CHEST) + 1.0, "%s reaches past the fighter" % light.name)


func test_the_lights_move_and_turn_with_the_fighter() -> void:
	var v: FighterView = _view(0)
	var w := World.new(FighterConfig.make(Moves.KATANA, []), FighterConfig.make(Moves.KATANA, []), 7)
	var f: Fighter = w.fighters[0]
	var yaw: float = 1.1
	var at := Vector3(3.0, 0.0, -2.0)
	v.update_from(f, at, yaw, 1.0, 1.0 / 60.0, 0.0)
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	var left: Vector3 = Vector3.UP.cross(ahead)
	var key_at: Vector3 = v.lights.key.global_position - at
	assert_almost_eq(key_at.dot(ahead), FighterLights.KEY_AT.z, 1e-4, "ahead of the turned fighter")
	assert_almost_eq(key_at.dot(left), FighterLights.KEY_AT.x, 1e-4, "to its left")
	w.dispose()


func test_the_key_casts_shadows_on_every_preset_but_low() -> void:
	var v: FighterView = _view(0)
	for id: StringName in GraphicsPreset.IDS:
		var preset: GraphicsPreset = GraphicsPreset.load_id(id)
		GraphicsApplier.apply_to_tree(preset, v)
		assert_eq(v.lights.key.shadow_enabled, id != &"low", "%s: the key's shadows" % id)
		assert_eq(preset.fighter_shadows, id != &"low")
		assert_true(v.lights.rim.visible and v.lights.key.visible, "%s keeps both lights" % id)
	GraphicsApplier.apply_to_tree(GraphicsPreset.ultra(), v)


func test_lights_are_off_until_asked_and_go_when_turned_off() -> void:
	var v := FighterView.new()
	add_child_autofree(v)
	v.setup(&"hunter", 0, &"katana", 0)
	assert_null(v.lights, "the tools' views stay neutral")
	v.show_lights(true)
	assert_not_null(v.lights)
	v.show_lights(false)
	assert_null(v.lights)
	assert_eq(v.find_children("*", "SpotLight3D", true, false).size(), 0)


## No arena geometry carries a side's layer, so the fighters' lights never
## reach the Shrine.
func test_no_arena_geometry_is_on_a_side_layer() -> void:
	var shrine: Node3D = (load(SHRINE_SCENE) as PackedScene).instantiate()
	add_child_autofree(shrine)
	for g: GeometryInstance3D in _geometry(shrine):
		assert_eq(g.layers & LookPalette.SIDE_LAYERS_MASK, 0, "%s isn't lit by the fighters' lights" % g.name)
