extends SceneTree
const FB = preload("res://src/fighter_builder.gd")
const ST = preload("res://src/stage.gd")
const OUT := "<scratch>/spike-anim/shots/"

func _initialize() -> void:
	_run.call_deferred()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var hair := "Hair_Long" if args.is_empty() else args[0]
	var world := Node3D.new()
	root.add_child(world)
	ST.neutral(world)
	var f: Node3D = FB.build(hair)
	world.add_child(f)
	var skel: Skeleton3D = f.find_child("GeneralSkeleton", true, false)
	var ap: AnimationPlayer = f.get_node("AnimationPlayer")
	var lab: Label = ST.label(world)
	var cam: Camera3D = ST.camera(world, Vector3(0, 0.95, 3.6), Vector3(0, 0.9, 0), 40)
	var imgs := []
	var close := []
	var views := [[Vector3(0, 0.95, 3.6), "front"], [Vector3(-2.35, 1.0, 2.75), "3/4"]]
	# rest pose
	skel.reset_bone_poses()
	await _wait(4)
	for v in views:
		cam.global_position = v[0]; cam.look_at(Vector3(0, 0.9, 0))
		lab.text = "rest  " + v[1]
		imgs.append(await ST.grab(self))
	ap.play("ual1/Idle")
	await _wait(40)
	ap.pause()
	for v in views:
		cam.global_position = v[0]; cam.look_at(Vector3(0, 0.9, 0))
		lab.text = "idle (UAL retargeted)  " + v[1]
		imgs.append(await ST.grab(self))
	ST.sheet(imgs, Rect2i(450, 0, 700, 900), 4, 0.8, OUT + "m1_fighter_rest_idle.png")
	cam.fov = 28
	for v in [[Vector3(0, 1.58, 1.2), "head front"], [Vector3(-0.8, 1.6, 0.9), "head 3/4"], [Vector3(0.9, 1.62, -0.6), "head back 3/4"]]:
		cam.global_position = v[0]; cam.look_at(Vector3(0, 1.5, 0))
		lab.text = hair + "  " + v[1]
		close.append(await ST.grab(self))
	ST.sheet(close, Rect2i(400, 0, 800, 900), 3, 0.7, OUT + "m1_head_%s.png" % hair)
	quit(0)
