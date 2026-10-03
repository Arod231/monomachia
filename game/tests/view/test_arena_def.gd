extends GutTest
## The Moonlit Shrine's arena data (ArenaDef): its ids and sound, spawns where
## and facing as the rules start each round, gates beyond the spawns, the wall
## outside the walkable circle, and the starting camera inside its limit.

const DEF_PATH := "res://arenas/moonlit_shrine/moonlit_shrine.tres"

var def: ArenaDef


func before_each() -> void:
	def = load(DEF_PATH)


func test_the_shrine_loads_with_its_ids_and_a_looping_ambience() -> void:
	assert_not_null(def)
	assert_eq(def.id, &"moonlit_shrine")
	assert_eq(def.display_name, "Moonlit Shrine")
	assert_eq(def.scene_path, "res://arenas/moonlit_shrine/moonlit_shrine.tscn")
	assert_eq(def.ambience_id, &"ambience_shrine")
	assert_true(SoundBank.CUES.has(def.ambience_id), "the ambience is a cue in the sound bank")
	assert_true(SoundBank.CUES[def.ambience_id].get("loop", false), "and it loops")


func test_spawns_stand_and_face_as_the_rules_start_a_round() -> void:
	var world := World.new(FighterConfig.make(Moves.KATANA), FighterConfig.make(Moves.KATANA))
	assert_eq(def.spawn_points.size(), 2)
	for side: int in 2:
		var f: Fighter = world.fighters[side]
		var spawn: Transform3D = def.spawn_point(side)
		assert_almost_eq(spawn.origin, Vector3(f.pos.x, f.pos.y, f.pos.z), Vector3.ONE * 1e-4, "side %d starts on its spawn" % side)
		var forward: V2 = SimMath.fwd(f.yaw)
		assert_almost_eq(-spawn.basis.z, Vector3(forward.x, 0.0, forward.z), Vector3.ONE * 1e-4, "side %d faces as the rules face it" % side)
		assert_true(def.is_walkable(spawn.origin, SimConst.FIGHTER_RADIUS), "side %d's spawn is walkable" % side)
	world.dispose()


func test_gates_stand_beyond_their_spawns_and_face_the_centre() -> void:
	assert_eq(def.gate_anchors.size(), 2)
	for side: int in 2:
		var gate: Transform3D = def.gate_anchor(side)
		var spawn: Vector3 = def.spawn_point(side).origin
		var gate_r: float = Vector2(gate.origin.x, gate.origin.z).length()
		assert_gt(gate_r, def.wall_radius, "gate %d stands past the wall" % side)
		assert_gt(gate.origin.z * spawn.z, 0.0, "gate %d at its own side's end" % side)
		assert_almost_eq((-gate.basis.z).dot(-gate.origin.normalized()), 1.0, 1e-4, "gate %d faces the centre" % side)


func test_the_wall_stands_outside_the_walkable_circle() -> void:
	assert_eq(def.walkable_radius, SimConst.ARENA_RADIUS, "the rules' wall")
	assert_almost_eq(def.wall_inner_radius(), 15.075, 1e-4)
	assert_almost_eq(def.wall_outer_radius(), 15.525, 1e-4)
	assert_gte(def.floor_radius, def.wall_outer_radius(), "the floor runs under the whole wall")
	assert_eq(def.validate(), PackedStringArray(), "the data validates")


func test_validate_reports_a_wall_inside_the_walkable_circle() -> void:
	var bad: ArenaDef = def.duplicate()
	bad.wall_radius = 14.0
	assert_eq(bad.validate().size(), 1)
	assert_string_contains(bad.validate()[0], "inside the walkable radius")


func test_validate_reports_a_spawn_too_close_to_the_wall_for_a_fighter() -> void:
	var bad: ArenaDef = def.duplicate()
	bad.spawn_points = [Transform3D(def.spawn_points[0].basis, Vector3(0.0, 0.0, -14.8)), def.spawn_points[1]]
	assert_true("spawn 0 is outside the walkable area" in bad.validate(), "a fighter (%.2f m) there would poke through the wall" % SimConst.FIGHTER_RADIUS)


func test_the_starting_cameras_stay_inside_the_arenas_limit() -> void:
	var rig: CameraRig = autofree(CameraRig.new())
	rig.apply_arena(def.camera_max_radius, def.camera_far)
	for side: int in 2:
		var me: Vector3 = def.spawn_point(side).origin
		var them: Vector3 = def.spawn_point(1 - side).origin
		var follow: Dictionary = rig.follow_target(me, them, (them - me).normalized())
		var watch: Dictionary = rig.watch_target(me, them, (them - me).normalized(), 0.0)
		for target: Dictionary in [follow, watch]:
			var pos: Vector3 = target["pos"]
			assert_lt(Vector2(pos.x, pos.z).length(), def.camera_max_radius, "side %d's start is inside the limit" % side)
			assert_eq(rig.clamp_to_arena(pos), pos)
