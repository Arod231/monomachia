extends Node3D
## Checks that ink outlines draw as wide as they're asked to be and cast no
## shadow: headless runs can't render, so the tests can't. Three things stand
## CAMERA_DISTANCE from the camera over a white floor, under a light from
## straight above:
## - a toon fighter sphere (smooth normals) and a MeshKit box (smoothed
##   normals in CUSTOM0), both outlined at WIDTH_SCALE times their width. The
##   ink ring at each one's left edge must measure that width in pixels (sized
##   for 1080p, so scaled to the window's height), within TOLERANCE of it;
## - the same fighter sphere without an outline. The outlined sphere's shadow
##   must be as wide as this one's, within SHADOW_SLACK pixels.
## On failure it prints why, saves what it saw to <out.png> and exits with
## code 1:
##   node scripts/godot.mjs shots res://tools/shot_scenes/outline_check.tscn <out.png>
## (Each of these went wrong once: a projection read with the wrong sign left
## every outline 1.5 mm wide, unit smoothed normals moved box faces out by only
## 1/sqrt(3) of the width, and the hulls drew into the shadow maps.)

## Wide enough to measure to a pixel or two, near enough that the hulls stay
## under the outline shader's max_width.
const WIDTH_SCALE: float = 3.0
const CAMERA_DISTANCE: float = 3.0
## How far a measured ring may be from the width asked, as a fraction of it.
const TOLERANCE: float = 0.3
## How many pixels wider one shadow may be than the other (their edges are
## soft, and the two spheres stand at mirrored angles to the camera).
const SHADOW_SLACK: int = 6
## Where things stand: the spheres to the sides, the box in the middle.
const SPHERE_X: float = 1.2
const SPHERE_RADIUS: float = 0.5
const BOX_SIZE: float = 0.6
const FLOOR_Y: float = -0.6
## Pixels darker than INK_LUMA are ink; floor pixels darker than SHADOW_LUMA
## are in shadow.
const INK_LUMA: float = 0.2
const SHADOW_LUMA: float = 0.75

var _passed: bool = false


func shot_frames() -> int:
	return 5


func shot_ready() -> bool:
	return _passed


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.25
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-90, 0, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshKit.new()
	ground.disc(Transform3D(Basis(), Vector3(0, FLOOR_Y, 0)), 10.0, 64, 4)
	var white := StandardMaterial3D.new()
	add_child(MeshKit.instance(ground.commit(), white))

	var outlined: ShaderMaterial = ToonMaterials.fighter(Color(0.75, 0.7, 0.6))
	ToonMaterials.set_outline(outlined, true, WIDTH_SCALE)
	var plain: ShaderMaterial = ToonMaterials.fighter(Color(0.75, 0.7, 0.6))
	ToonMaterials.set_outline(plain, false)
	var stone: ShaderMaterial = ToonMaterials.prop(Color(0.75, 0.7, 0.6), 0.0)
	ToonMaterials.set_outline(stone, true, WIDTH_SCALE)
	_add_sphere(-SPHERE_X, outlined)
	_add_sphere(SPHERE_X, plain)
	var box := MeshKit.new()
	box.box(Transform3D.IDENTITY, Vector3.ONE * BOX_SIZE)
	add_child(MeshKit.instance(box.commit(true), stone))

	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	add_child(camera)
	camera.make_current()
	_check.call_deferred()


func _add_sphere(x: float, material: Material) -> void:
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = SPHERE_RADIUS
	mesh.height = SPHERE_RADIUS * 2.0
	sphere.mesh = mesh
	sphere.material_override = material
	sphere.position = Vector3(x, 0, 0)
	add_child(sphere)


func _check() -> void:
	for i: int in 3:
		await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var errors: PackedStringArray = []
	var to_px: float = img.get_height() / 1080.0
	var middle: int = floori(img.get_height() / 2.0)
	var fighter: float = ToonMaterials.OUTLINE_WIDTH[ToonMaterials.OutlineKind.FIGHTER] * WIDTH_SCALE * to_px
	var prop: float = ToonMaterials.OUTLINE_WIDTH[ToonMaterials.OutlineKind.PROP] * WIDTH_SCALE * to_px
	_check_ring(errors, "sphere", _ink_run(img, middle, 0), fighter)
	# Halfway between a sphere's inner edge and the box's: the box's ring is
	# the first to the right of it, and each sphere's shadow lies beyond it.
	var gap: float = (SPHERE_X - SPHERE_RADIUS + BOX_SIZE / 2.0) / 2.0
	var left_gap: int = _screen_x(img, -gap, CAMERA_DISTANCE)
	var right_gap: int = _screen_x(img, gap, CAMERA_DISTANCE)
	_check_ring(errors, "box", _ink_run(img, middle, left_gap), prop)
	# A floor row just in front of the spheres, through their shadows. The
	# shadows' soft edges are dithered, so every dark pixel on a side counts.
	var row: int = middle + roundi(0.218 / tan(deg_to_rad(30.0)) * img.get_height() / 2.0)
	var left: int = _shadow_pixels(img, row, 0, left_gap)
	var right: int = _shadow_pixels(img, row, right_gap, img.get_width())
	print("outline_check: shadows %d px with an outline, %d px without" % [left, right])
	if right < 50 or absi(left - right) > SHADOW_SLACK:
		errors.append("the outlined sphere's shadow is %d px wide against %d px without an outline" % [left, right])
	if errors.is_empty():
		_passed = true
		return
	for e: String in errors:
		printerr("outline_check: " + e)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			img.save_png(arg.trim_prefix("--out="))
	get_tree().quit(1)


func _check_ring(errors: PackedStringArray, what: String, ring: int, expected: float) -> void:
	print("outline_check: %s ring %d px, expected %.1f px" % [what, ring, expected])
	if absf(ring - expected) > expected * TOLERANCE:
		errors.append("the %s's outline is %d px wide instead of about %.1f px" % [what, ring, expected])


## The screen column of a point x metres to the side, depth metres away.
static func _screen_x(img: Image, x: float, depth: float) -> int:
	var px_per_unit: float = img.get_height() / 2.0 / tan(deg_to_rad(30.0))
	return roundi(img.get_width() / 2.0 + x / depth * px_per_unit)


## The length of the first run of ink pixels along row y, from column from_x
## rightwards (the blended pixels at its edges don't count).
static func _ink_run(img: Image, y: int, from_x: int) -> int:
	var count: int = 0
	for x: int in range(from_x, img.get_width()):
		if img.get_pixel(x, y).get_luminance() < INK_LUMA:
			count += 1
		elif count > 0:
			break
	return count


## How many pixels of row y, in columns from_x up to to_x, are in shadow.
static func _shadow_pixels(img: Image, y: int, from_x: int, to_x: int) -> int:
	var count: int = 0
	for x: int in range(from_x, to_x):
		if img.get_pixel(x, y).get_luminance() < SHADOW_LUMA:
			count += 1
	return count
