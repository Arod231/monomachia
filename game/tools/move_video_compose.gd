extends SceneTree
## Composes the before-and-after video (authored-animation task 14): the
## frames tools/move_video.gd rendered from a feature/godot-rebuild checkout
## (before, the procedural animation) and from this branch (after, the
## clips), side by side, each move captioned, at half speed (every rules
## frame shown twice at 60 fps), with each move's last frame held a moment.
## Run under Movie Maker, which writes the video:
##
##   godot --path game --resolution 1600x900 --fixed-fps 60 --write-movie <out.avi> \
##     --script res://tools/move_video_compose.gd -- --before=<dir> --after=<dir>
##
## node scripts/move_video.mjs runs the whole thing.

const REPEAT: int = 2
const HOLD: int = 30
const PANEL: Vector2 = Vector2(800.0, 900.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var before: String = ""
	var after: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--before="):
			before = a.trim_prefix("--before=")
		elif a.begins_with("--after="):
			after = a.trim_prefix("--after=")
	var ui: Control = Control.new()
	ui.size = PANEL * Vector2(2.0, 1.0)
	root.add_child(ui)
	var panels: Array[TextureRect] = []
	var captions: Array[Label] = []
	for i: int in 2:
		var tr: TextureRect = TextureRect.new()
		tr.position = Vector2(PANEL.x * i, 0.0)
		tr.size = PANEL
		ui.add_child(tr)
		panels.append(tr)
		var label: Label = Label.new()
		label.position = Vector2(PANEL.x * i + 16.0, 12.0)
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
		ui.add_child(label)
		captions.append(label)
	var moves: PackedStringArray = FileAccess.get_file_as_string(after.path_join("moves.txt")).strip_edges().split("\n")
	for line: String in moves:
		var parts: PackedStringArray = line.split(" ", false, 2)
		if parts.size() < 3:
			continue
		var id: String = parts[0]
		var title: String = parts[2]
		var counts: Array[int] = [_count(before.path_join(id)), _count(after.path_join(id))]
		var n: int = maxi(counts[0], counts[1])
		for f: int in range(1, n + 1 + HOLD / REPEAT):
			for i: int in 2:
				var dir: String = [before, after][i].path_join(id)
				var k: int = mini(f, counts[i])
				if k > 0:
					panels[i].texture = ImageTexture.create_from_image(Image.load_from_file(dir.path_join("%04d.png" % k)))
				captions[i].text = "%s · %s\n%s, frame %d of %d" % [
					["before: procedural", "after: clips"][i], title, id, mini(f, counts[i]), counts[i]]
			for r: int in REPEAT:
				await process_frame
	quit(0)


static func _count(dir: String) -> int:
	var n: int = 0
	while FileAccess.file_exists(dir.path_join("%04d.png" % (n + 1))):
		n += 1
	return n
