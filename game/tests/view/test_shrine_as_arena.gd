extends GutTest
## The Moonlit Shrine as every match's arena (plan task 17.10): with the
## rules' wall at the shrine's 15 m, fighters and dropped weapons stay inside
## its parapet, and no match camera can reach its props.

const SHRINE_SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"
const WeaponTests := preload("res://tests/content/test_weapons.gd")
## How near a prop may come to a camera: the near plane's corners reach about
## 0.16 m (NEAR_REACH), and a little more keeps a pillar from filling the view.
const CLEARANCE: float = 0.3
## How far the camera's near plane reaches: its corners, at a 0.1 m near clip,
## a 60 degree field of view and 16:9.
const NEAR_REACH: float = 0.16
## A generous bound on how high a fighter's feet go (jumps, leaps, being held
## up on the Impaler's blade); the computer matches below check it.
const FEET_CEILING: float = 2.5
## A body reaching this far from the centre is backed against the wall.
const AT_THE_WALL: float = SimConst.ARENA_RADIUS - 0.01

var def: ArenaDef


func before_each() -> void:
	def = ArenaScenes.def(ArenaScenes.MOONLIT_SHRINE)


func after_each() -> void:
	SimHelpers.dispose_all()


func test_a_default_match_is_fought_on_the_shrine() -> void:
	assert_eq(MatchConfig.DEFAULT_ARENA, ArenaScenes.MOONLIT_SHRINE)
	assert_eq(def.walkable_radius, SimConst.ARENA_RADIUS, "the rules' wall is the shrine's")
	assert_eq(ArenaScenes.scene_path(MatchConfig.DEFAULT_ARENA), SHRINE_SCENE)


func test_computer_matches_back_fighters_against_the_wall_but_never_through_it() -> void:
	# Whether a match reaches the wall depends on how it plays, which every
	# rule change shifts, so seeds run until one has (at least three matches,
	# at most thirty: since task 31's Right Cut and Return Cut, fewer matches
	# reach it), and every match run is checked. The cost: losing the wall
	# shows only once all thirty seeds miss it.
	var furthest_body: float = 0.0
	var highest_feet: float = 0.0
	var played: int = 0
	for seed_value: int in range(11, 41):
		if played >= 3 and furthest_body > AT_THE_WALL:
			break
		played += 1
		var W: World = SimHelpers.track(World.new(FighterConfig.make(Moves.KATANA), FighterConfig.make(Moves.GREATSWORD), seed_value))
		var M: Match = Match.new(W)
		var brains: Array[AIBrain] = [
			AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"hard"], seed_value),
			AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"], seed_value + 100),
		]
		for _i: int in 60 * 60 * 12:
			M.step([brains[0].think(), brains[1].think()])
			W.drain_events()
			for f: Fighter in W.fighters:
				furthest_body = maxf(furthest_body, JsMath.hypot(f.pos.x, f.pos.z) + SimConst.FIGHTER_RADIUS)
				highest_feet = maxf(highest_feet, f.pos.y)
			if M.phase == &"matchEnd":
				break
		assert_eq(M.phase, &"matchEnd", "seed %d: the match finished" % seed_value)
		for b: AIBrain in brains:
			b.dispose()
	assert_gt(furthest_body, AT_THE_WALL, "a fighter was backed against the wall")
	assert_lte(furthest_body, def.wall_inner_radius(), "and no fighter's body passed the parapet's inner face")
	assert_lt(highest_feet, FEET_CEILING, "no fighter's feet went higher than FEET_CEILING")


func test_a_weapon_disarmed_at_the_wall_stays_wholly_inside_the_parapet() -> void:
	# A dropped weapon flies centred on its rules position along its length
	# and sticks with its point at it, leaning back STUCK_WEAPON_LEAN along its
	# flight (MatchView, milestone-1 task 86). The worst cases: lying straight
	# out at its furthest in flight, and stuck with the whole length leaning
	# outward.
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		var model: Node3D = WeaponLook.load_id(id).instantiate()
		add_child_autofree(model)
		var length: float = WeaponTests._bounds(model).size.y
		for heading: float in [0.0, PI / 4.0, PI / 2.0, -PI / 2.0]:
			var W: World = SimHelpers.make_world(Moves.WEAPONS[id])
			var victim: Fighter = W.fighters[0]
			victim.pos = V3.make(0.0, 0.0, 14.5)
			W.fighters[1].pos = V3.make(-JsMath.sin(heading) * 2.0, 0.0, 14.5 - JsMath.cos(heading) * 2.0)
			victim.disarm(W.fighters[1], &"parried")
			var furthest: float = 0.0
			for _i: int in 120:
				W.step([RawInput.empty(), RawInput.empty()])
				furthest = maxf(furthest, JsMath.hypot(W.weapons[0].pos.x, W.weapons[0].pos.z))
			var label: String = "%s, %.2f m long, flying %.0f° off straight out" % [id, length, rad_to_deg(heading)]
			assert_true(W.weapons[0].grounded, label + ": it sticks")
			assert_lte(furthest + length * 0.5, def.wall_inner_radius(), label + ": never pokes into the parapet in flight")
			var stuck: float = JsMath.hypot(W.weapons[0].pos.x, W.weapons[0].pos.z)
			assert_lte(stuck + length * sin(SimConst.STUCK_WEAPON_LEAN), def.wall_inner_radius(), label + ": nor stuck")


## A physics space holding the shrine's props (bought art included) and the
## gates' rope barriers, one static body per mesh, named after it, leaving
## out the meshes named in leave_out.
func _prop_space(leave_out: Array[StringName]) -> PhysicsDirectSpaceState3D:
	var shrine: Node3D = (load(SHRINE_SCENE) as PackedScene).instantiate()
	add_child_autofree(shrine)
	var props: Node3D = shrine.find_child("Props", true, false)
	var meshes: Array[Node] = props.find_children("*", "MeshInstance3D", true, false)
	for rope: Node in shrine.find_children("GateRope*", "Node3D", true, false):
		meshes.append_array(rope.find_children("*", "MeshInstance3D", true, false))
	assert_gt(meshes.size(), 10, "the shrine has its props")
	for mi: MeshInstance3D in meshes:
		if leave_out.has(mi.name):
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(mi.mesh.get_faces())
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = mi.global_transform
		var body := StaticBody3D.new()
		body.name = mi.name
		body.add_child(cs)
		add_child_autofree(body)
	await wait_physics_frames(2)
	return get_viewport().world_3d.direct_space_state


## The lowest and highest a match camera goes (x, y): the rig's own targets
## with the fighters closest and furthest apart, standing and as high as their
## feet go, plus the shake. (The KO orbit and Versus use the same targets.)
static func _camera_heights(rig: CameraRig) -> Vector2:
	var heights: Array[float] = []
	for apart: float in [0.5, 2.0 * (SimConst.ARENA_RADIUS - SimConst.FIGHTER_RADIUS)]:
		for feet: float in [0.0, FEET_CEILING]:
			var player := Vector3(0.0, feet, 0.0)
			var opponent := Vector3(0.0, feet, apart)
			heights.append((rig.follow_target(player, opponent, Vector3.BACK)["pos"] as Vector3).y)
			heights.append((rig.watch_target(player, opponent, Vector3.BACK, 0.0)["pos"] as Vector3).y)
	var shake: float = rig.shake_max * rig.shake_amplitude * 0.5
	return Vector2(heights.min() - shake, heights.max() + shake)


func test_no_prop_reaches_into_the_room_the_match_cameras_move_in() -> void:
	# Every match camera but the menu's orbit is clamped within arena_limit()
	# of the centre, between the heights _camera_heights finds: the room. The
	# cameras pass over the parapet, which is checked on its own.
	var space: PhysicsDirectSpaceState3D = await _prop_space([&"Parapet"])
	var rig: CameraRig = autofree(CameraRig.new())
	rig.apply_arena(def.camera_max_radius, def.camera_far)
	var band: Vector2 = _camera_heights(rig)
	var room := CylinderShape3D.new()
	room.radius = rig.arena_limit() + CLEARANCE
	room.height = band.y - band.x + 2.0 * CLEARANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = room
	query.transform = Transform3D(Basis(), Vector3(0.0, (band.x + band.y) * 0.5, 0.0))
	var inside: Array[String] = []
	for hit: Dictionary in space.intersect_shape(query, 32):
		var n: String = String((hit["collider"] as Node).name)
		if not inside.has(n):
			inside.append(n)
	assert_eq(inside, [] as Array[String], "props within %.2f m of the centre, %.2f to %.2f m up" % [room.radius, band.x - CLEARANCE, band.y + CLEARANCE])


func test_the_cameras_pass_over_the_parapet_clear_of_their_near_plane() -> void:
	var shrine: Node3D = (load(SHRINE_SCENE) as PackedScene).instantiate()
	add_child_autofree(shrine)
	var parapet: MeshInstance3D = shrine.find_child("Parapet", true, false)
	var top: float = (parapet.global_transform * parapet.get_aabb()).end.y
	var rig: CameraRig = autofree(CameraRig.new())
	assert_lt(top, _camera_heights(rig).x - NEAR_REACH, "the parapet's top (%.2f m) stays under the lowest camera" % top)


## The sweep that found the cameras in the props at the old 19.5 m limit, kept
## as a scenario: the player backed against the wall at every degree, the
## opponent 2.5, 6 or 12 m away at bearings up to 60 degrees either side, and
## the follow camera never within CLEARANCE of a prop nor passing through one
## between degrees.
func test_the_follow_camera_round_the_wall_never_meets_a_prop() -> void:
	var space: PhysicsDirectSpaceState3D = await _prop_space([])
	var rig: CameraRig = autofree(CameraRig.new())
	rig.apply_arena(def.camera_max_radius, def.camera_far)
	var ball := SphereShape3D.new()
	ball.radius = CLEARANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	var met: Dictionary[String, PackedInt32Array] = {}
	var r: float = SimConst.ARENA_RADIUS - SimConst.FIGHTER_RADIUS
	for bearing: float in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		for d: float in [2.5, 6.0, 12.0]:
			var path := PackedVector3Array()
			for deg: int in 360:
				var player: Vector3 = ShrineLayout.polar(deg, r)
				var opponent: Vector3 = player + (-player).normalized().rotated(Vector3.UP, deg_to_rad(bearing)) * d
				var direction: Vector3 = (opponent - player).normalized()
				path.append(rig.clamp_to_arena(rig.follow_target(player, opponent, direction)["pos"]))
			for i: int in path.size():
				var names: Array[String] = []
				query.transform = Transform3D(Basis(), path[i])
				for hit: Dictionary in space.intersect_shape(query, 4):
					names.append(String((hit["collider"] as Node).name))
				var ray := PhysicsRayQueryParameters3D.create(path[i], path[(i + 1) % path.size()])
				ray.hit_back_faces = true
				var through: Dictionary = space.intersect_ray(ray)
				if not through.is_empty():
					names.append(String((through["collider"] as Node).name))
				for n: String in names:
					var key: String = "bearing %d, %s m: %s" % [bearing, d, n]
					if not met.has(key):
						met[key] = PackedInt32Array()
					met[key].append(i)
	var lines: Array[String] = []
	for key: String in met:
		lines.append("%s at %s deg" % [key, met[key]])
	assert_eq(lines, [] as Array[String], "the follow camera meets a prop (one mesh per material):\n%s" % "\n".join(lines))
