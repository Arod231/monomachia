extends Node
## The before-and-after video's frame renderer (authored-animation task 14;
## tools/move_video.gd runs it): see that file. Loaded at run time, once the
## project's autoloads are up, so its class names resolve in whichever
## checkout runs it.

const SIDE_DISTANCE: float = 4.4
## How far ahead of the attacker the camera centres (m): the body and the
## blade's reach. MoveBench shows no defender.
const AHEAD: float = 0.9
const CAMERA_HEIGHT: float = 1.25


## Renders the frames as the command line asks, then quits the tree.
func run() -> void:
	var tree: SceneTree = get_tree()
	var weapon_id: StringName = &"katana"
	var fighter_id: StringName = &"hunter"
	var out: String = ""
	var only: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--weapon="):
			weapon_id = StringName(a.trim_prefix("--weapon="))
		elif a.begins_with("--fighter="):
			fighter_id = StringName(a.trim_prefix("--fighter="))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--moves="):
			only = a.trim_prefix("--moves=").split(",")
	if out == "":
		printerr("move_video: --out=<dir> is needed")
		tree.quit(1)
		return
	await tree.process_frame
	var stage: Node3D = _stage()
	add_child(stage)
	var weapon: WeaponDef = Moves.WEAPONS[weapon_id]
	var listing: PackedStringArray = []
	for id: StringName in weapon.moves:
		if not only.is_empty() and not only.has(String(id)):
			continue
		var bench: MoveBench = MoveBench.new(stage, fighter_id, weapon)
		if not bench.begin(id):
			bench.dispose()
			continue
		DirAccess.make_dir_recursive_absolute(out.path_join(String(id)))
		var n: int = 0
		while true:
			var step: MoveBench.Step = await bench.next_frame()
			if step == null:
				break
			_aim(stage.get_node("Camera") as Camera3D, bench)
			await tree.process_frame
			await RenderingServer.frame_post_draw
			n += 1
			tree.root.get_texture().get_image().save_png(out.path_join(String(id)).path_join("%04d.png" % n))
		listing.append("%s %d %s" % [id, n, (weapon.moves[id] as AttackDef).name])
		bench.dispose()
		print("move_video: %s, %d frames" % [id, n])
	var f: FileAccess = FileAccess.open(out.path_join("moves.txt"), FileAccess.WRITE)
	f.store_string("\n".join(listing) + "\n")
	f.close()
	tree.quit(0)


## A plain studio: a floor, a sun, a sky light and the camera.
func _stage() -> Node3D:
	var stage: Node3D = Node3D.new()
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.73, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.61, 0.6)
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	var cam: Camera3D = Camera3D.new()
	cam.name = &"Camera"
	cam.fov = 40.0
	stage.add_child(cam)
	cam.make_current()
	return stage


## Side on to the line between the fighters, centred a little ahead of the
## attacker.
func _aim(cam: Camera3D, bench: MoveBench) -> void:
	# the attacker where its view stands, the defender as far off as the rules
	# have it
	var shown: Vector3 = (bench.view as Node3D).global_position
	var a: Vector3 = Vector3(shown.x, 0.0, shown.z)
	var d: Vector3 = a + Vector3(bench.defender.pos.x - bench.attacker.pos.x, 0.0, bench.defender.pos.z - bench.attacker.pos.z)
	var along: Vector3 = (d - a).normalized() if a.distance_to(d) > 0.01 else Vector3.FORWARD
	var mid: Vector3 = a + along * AHEAD
	var side: Vector3 = along.cross(Vector3.UP).normalized()
	cam.position = mid + side * SIDE_DISTANCE + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	cam.look_at(mid + Vector3(0.0, 1.0, 0.0), Vector3.UP)
