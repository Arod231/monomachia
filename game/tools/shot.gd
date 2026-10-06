extends SceneTree
## Renders a scene in a window and saves a screenshot. Run through
## `npm run shots -- <res://scene.tscn> <out.png> [frames]`.
## Needs a real window (it can be off-screen): viewport capture does not work
## with --headless.
##
## A scene can take control of the capture by defining `func shot_frames() -> int`
## (how many frames to wait) and `func shot_ready() -> bool` (true once it has
## posed itself), and hand over the picture to save with
## `func shot_image() -> Image` (null saves the screen).
##
## With `--record=<frames>` (`npm run clip`, which runs it under Movie Maker),
## the scene runs that many more frames after the still is saved, then it
## quits, so the movie ends with them.


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return fallback


func _run() -> void:
	var scene_path: String = _arg("scene", "res://scenes/main.tscn")
	var out: String = _arg("out", "user://shot.png")
	var frames: int = int(_arg("frames", "30"))
	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("shot: cannot load %s" % scene_path)
		quit(1)
		return
	var node: Node = packed.instantiate()
	root.add_child(node)
	if node.has_method("shot_frames"):
		frames = node.call("shot_frames")
	for i: int in frames:
		await process_frame
	if node.has_method("shot_ready"):
		var guard: int = 0
		# Generous: a contact sheet waits several frames for each of its shots.
		while not node.call("shot_ready") and guard < 6000:
			await process_frame
			guard += 1
	await RenderingServer.frame_post_draw
	var img: Image = node.call("shot_image") if node.has_method("shot_image") else null
	if img == null:
		img = root.get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	if err != OK:
		printerr("shot: failed to save %s (%s)" % [out, error_string(err)])
		quit(1)
		return
	print("shot: saved %s (%dx%d)" % [out, img.get_width(), img.get_height()])
	var record: int = int(_arg("record", "0"))
	if record > 0:
		print("shot: recording %d frames" % record)
		for i: int in record:
			await process_frame
	quit(0)
