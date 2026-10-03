extends Node3D
## Checks that the ink-wash pass draws its ink lines where depth breaks and
## nowhere else: headless runs can't render, so the tests can't. Everything is
## unshaded white under a white sky, so only the pass's ink shows. The camera
## stands CAMERA_HEIGHT above a floor that runs to the horizon, looking along
## it at a box BOX_DISTANCE away. With the pass at full quality (lines, jitter
## and dry-brush breaks) and its grain, vignette and mist off:
## - the box's left edge carries a line against the sky and against the far
##   floor, at least MIN_LINE px wide and darker than INK_LUMA;
## - the floor beside the box, seen at ever more grazing angles toward the
##   horizon, has no ink at all (the jittered edge test once drew false lines
##   along it within about 16 px of the horizon);
## - with the pass at LITE, the box's edge has no line.
## It prints the lines' widths and darkness, for tuning their strength. On
## failure it prints why, saves what it saw to <out.png> and exits with code 1:
##   node scripts/godot.mjs shots res://tools/shot_scenes/ink_check.tscn <out.png>

const CAMERA_HEIGHT: float = 1.0
const CAMERA_FOV: float = 60.0
const BOX_DISTANCE: float = 3.0
const BOX_SIZE: float = 1.2
## The box's top stands this far above the camera's eye line.
const BOX_TOP: float = 0.2
## How far away the floor is where the second line is measured.
const FLOOR_DISTANCE: float = 13.0
## Pixels darker than this are ink. The lines measure about 0.4 to 0.65 on
## white (the dry-brush breaks thin them), and the bleed halo around them
## about 0.94.
const INK_LUMA: float = 0.75
## InkWashPass.LINE_WIDTH_PX is 2: a line measures 2 px against the sky
## (whose side is never inked) and about 4 px against the floor.
const MIN_LINE: int = 2
## Columns this close to the box's sides, and between them, are left out of
## the floor count (its base meets the floor in a crease, which rightly draws
## a line).
const BOX_MARGIN_PX: int = 40

var _ink: InkWashPass
var _passed: bool = false


func shot_frames() -> int:
	return 5


func shot_ready() -> bool:
	return _passed


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ground := MeshKit.new()
	ground.disc(Transform3D(Basis(), Vector3(0, -CAMERA_HEIGHT, 0)), 400.0, 64, 4)
	add_child(MeshKit.instance(ground.commit(), white, false))
	var box := MeshKit.new()
	var centre := Vector3(0, BOX_TOP - BOX_SIZE / 2.0, -BOX_DISTANCE - BOX_SIZE / 2.0)
	box.box(Transform3D(Basis(), centre), Vector3.ONE * BOX_SIZE)
	add_child(MeshKit.instance(box.commit(), white, false))

	_ink = InkWashPass.new()
	_ink.set_param(&"grain_strength", 0.0)
	_ink.set_param(&"vignette_strength", 0.0)
	_ink.set_param(&"fade_max", 0.0)
	add_child(_ink)

	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.far = 1000.0
	add_child(camera)
	camera.make_current()
	_check.call_deferred()


func _check() -> void:
	var full: Image = await _capture()
	var errors: PackedStringArray = []
	var middle: int = floori(full.get_height() / 2.0)
	var box_left: int = roundi(full.get_width() / 2.0 - _to_px(full, BOX_SIZE / 2.0, BOX_DISTANCE))
	# A row through the box's top part, against the sky, and one lower down,
	# against the floor FLOOR_DISTANCE away.
	var rows: Dictionary[String, int] = {
		"sky": middle - roundi(_to_px(full, BOX_TOP / 2.0, BOX_DISTANCE)),
		"far floor": middle + roundi(_to_px(full, CAMERA_HEIGHT, FLOOR_DISTANCE)),
	}
	for against: String in rows:
		var line: Vector2 = _line_at(full, rows[against], box_left)
		print("ink_check: line against the %s %d px wide, darkest luma %.2f" % [against, line.x, line.y])
		if line.x < MIN_LINE:
			errors.append("no ink line at the box's edge against the %s" % against)
	var box_half: float = _to_px(full, BOX_SIZE / 2.0, BOX_DISTANCE) + BOX_MARGIN_PX
	var stray: int = _floor_ink(full, middle, full.get_width() / 2.0 - box_half, full.get_width() / 2.0 + box_half)
	print("ink_check: %d ink pixels on the open floor" % stray)
	if stray > 0:
		errors.append("%d ink pixels on the open floor, where nothing breaks" % stray)
	var failed: Image = full if not errors.is_empty() else null

	_ink.set_quality(InkWashPass.Quality.LITE)
	var lite: Image = await _capture()
	var lite_line: Vector2 = _line_at(lite, rows["sky"], box_left)
	print("ink_check: at LITE, line %d px" % lite_line.x)
	if lite_line.x > 0:
		errors.append("the pass draws lines at LITE")
		if failed == null:
			failed = lite

	if errors.is_empty():
		# The saved shot shows the lines.
		_ink.set_quality(InkWashPass.Quality.FULL)
		await _capture()
		_passed = true
		return
	for e: String in errors:
		printerr("ink_check: " + e)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			failed.save_png(arg.trim_prefix("--out="))
	get_tree().quit(1)


func _capture() -> Image:
	for i: int in 3:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## How many pixels across the screen a length of size metres covers, depth
## metres from the camera.
static func _to_px(img: Image, size: float, depth: float) -> float:
	return size / depth * img.get_height() / 2.0 / tan(deg_to_rad(CAMERA_FOV / 2.0))


## Within 6 px either side of column x along row y: how many pixels are ink,
## and the darkest luminance of them all.
static func _line_at(img: Image, y: int, x: int) -> Vector2:
	var count: int = 0
	var darkest: float = 1.0
	for i: int in range(x - 6, x + 7):
		var luma: float = img.get_pixel(i, y).get_luminance()
		darkest = minf(darkest, luma)
		if luma < INK_LUMA:
			count += 1
	return Vector2(count, darkest)


## Ink pixels on the floor below the horizon (row middle), outside the
## columns from left to right where the box stands.
static func _floor_ink(img: Image, middle: int, left: float, right: float) -> int:
	var count: int = 0
	for y: int in range(middle + 1, img.get_height()):
		for x: int in img.get_width():
			if x > left and x < right:
				continue
			if img.get_pixel(x, y).get_luminance() < INK_LUMA:
				count += 1
	return count
