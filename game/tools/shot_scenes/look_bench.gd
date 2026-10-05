extends Node3D
## The look bench: toon fighters, blades and a stone lantern under a moon key
## light in the night environment, for judging the toon bands, the rim light,
## the ink outlines and the ink-wash finish by eye. Outlines are on in the left
## half and off in the right. Each half has a group at a duel's distance from
## the camera and another FAR metres further back, to show how the lines hold
## up far away. Render with
##   node scripts/godot.mjs shots res://tools/shot_scenes/look_bench.tscn <out.png> 20 [args]
## where the args are any of:
## - --width-scale=<x> multiplies every outline width, for comparing widths;
## - --ink=off|lite|lines|full sets the ink-wash pass's quality (full by
##   default; anything else fails the run);
## - --ink-strength=<x> and --ink-width=<px> set the ink lines' strength and
##   width (the shader's defaults otherwise);
## - --no-grade leaves the colour grade off;
## - --preset=low|medium|high applies that graphics preset to the whole bench
##   (the left half's outlines and their width, the pass, the shadows and the
##   anti-aliasing). The bench then puts back what its own arguments say: the
##   right half's outlines go off again, and an explicit --ink and --no-grade
##   still win, while --width-scale gives way to the preset's.
## The pass covers the whole screen; the label at the top says how it's set.

## How far behind the near groups the far ones stand.
const FAR: float = 14.0
## Half the distance between the left and right groups.
const HALF_GAP: float = 2.4
## The game camera's field of view, and about where it sits behind a fighter
## looking at an opponent 6 m away.
const CAMERA_FOV: float = 60.0
const CAMERA_POSITION: Vector3 = Vector3(0, 1.9, 6.0)
const CAMERA_TARGET: Vector3 = Vector3(0, 1.2, -2.0)

var _ink: InkWashPass


func shot_frames() -> int:
	return 20


func _ready() -> void:
	_add_environment()
	var floor_kit := MeshKit.new()
	floor_kit.disc(Transform3D.IDENTITY, 40.0, 48, 4)
	add_child(MeshKit.instance(floor_kit.commit(), ToonMaterials.prop(LookPalette.STONE_DARK, 0.35, false), false))
	var preset: GraphicsPreset = null
	var preset_id: String = _arg(&"preset", "")
	if not preset_id.is_empty():
		preset = GraphicsPreset.load_id(StringName(preset_id))
		if preset == null:
			push_error("look_bench.gd: --preset must be low, medium or high, not '%s'" % preset_id)
	var width_scale: float = preset.outline_width_scale if preset != null else _arg(&"width-scale", "1").to_float()
	_add_label(_ink_label(preset), Vector3(0, 2.95, 0))
	var plain: Array[ShaderMaterial] = []
	for outlined: bool in [true, false]:
		var x: float = -HALF_GAP if outlined else HALF_GAP
		var materials: Array[ShaderMaterial] = []
		materials.append_array(_add_group(Vector3(x, 0, 0), LookPalette.SIDE_COLORS[0]))
		materials.append_array(_add_group(Vector3(x * 0.6, 0, -FAR), LookPalette.SIDE_COLORS[1]))
		for m: ShaderMaterial in materials:
			ToonMaterials.set_outline(m, outlined, width_scale)
		if not outlined:
			plain = materials
		var on_text: String = ("outlines per preset (x%.2f)" if preset != null else "outlines on (x%.2f)") % width_scale
		_add_label(on_text if outlined else "outlines off", Vector3(x, 2.45, 0))
	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.position = CAMERA_POSITION
	add_child(camera)
	camera.look_at(CAMERA_TARGET)
	camera.make_current()
	if preset != null:
		var quality: InkWashPass.Quality = _ink.quality
		GraphicsApplier.apply(preset, self, get_viewport())
		for m: ShaderMaterial in plain:
			ToonMaterials.set_outline(m, false)
		if not _arg(&"ink", "").is_empty():
			_ink.set_quality(quality)
		if _flag(&"no-grade"):
			var env: Environment = (get_node(^"Environment") as WorldEnvironment).environment
			env.adjustment_enabled = false


func _add_label(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.005
	label.modulate = LookPalette.BONE
	label.position = at
	add_child(label)


## How the preset, the ink-wash pass and the grade are set, for the top label.
static func _ink_label(preset: GraphicsPreset) -> String:
	var ink: String = _arg(&"ink", "")
	if ink.is_empty():
		ink = String(InkWashPass.Quality.find_key(preset.post_quality)).to_lower() if preset != null else "full"
	var text: String = "ink %s" % ink
	if preset != null:
		text = "%s preset, %s" % [preset.display_name, text]
	for param: StringName in [&"ink-strength", &"ink-width"]:
		if not _arg(param, "").is_empty():
			text += ", %s %s" % [String(param).trim_prefix("ink-"), _arg(param, "")]
	return text + (", no grade" if _flag(&"no-grade") else "")


## The value of the --<name>=<value> argument, or fallback.
static func _arg(name: StringName, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


## Whether the bare --<name> flag was given.
static func _flag(name: StringName) -> bool:
	return OS.get_cmdline_user_args().has("--%s" % name)


## The night environment, graded, with a moon key light from the right that
## casts shadows, and the ink-wash pass.
func _add_environment() -> void:
	var env := (load("res://view/look/ink_night_environment.tres") as Environment).duplicate() as Environment
	if not _flag(&"no-grade"):
		InkGrade.apply(env)
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.74, 0.82, 1.0)
	moon.light_energy = 1.35
	moon.shadow_enabled = true
	moon.add_to_group(GraphicsApplier.GROUP_SHADOW_LIGHT)
	add_child(moon)
	moon.look_at_from_position(Vector3.ZERO, Vector3(-0.95, -1.05, -0.25), Vector3.UP)
	_ink = InkWashPass.new()
	add_child(_ink)
	var quality: String = _arg(&"ink", "full").to_upper()
	if not InkWashPass.Quality.has(quality):
		# Named with its .gd, so `godot.mjs shots` fails the run once the shot
		# is saved (quitting this early in a shot run hangs Godot instead).
		push_error("look_bench.gd: --ink must be off, lite, lines or full, not '%s'" % quality.to_lower())
		return
	_ink.set_quality(InkWashPass.Quality[quality])
	var params: Dictionary[StringName, StringName] = {&"ink-strength": &"line_strength", &"ink-width": &"line_width_px"}
	for arg: StringName in params:
		if not _arg(arg, "").is_empty():
			_ink.set_param(params[arg], _arg(arg, "").to_float())


## A fighter (a body capsule and a head) holding a blade across its body, so
## the outline shows inner contours, and a stone lantern beside it. Returns
## the group's materials.
func _add_group(at: Vector3, color: Color) -> Array[ShaderMaterial]:
	var group := Node3D.new()
	group.position = at
	add_child(group)
	var cloth: ShaderMaterial = ToonMaterials.fighter(color)
	var skin: ShaderMaterial = ToonMaterials.fighter(LookPalette.INK_SOFT)
	var steel: ShaderMaterial = ToonMaterials.weapon(LookPalette.STEEL)
	var wood: ShaderMaterial = ToonMaterials.weapon(LookPalette.WOOD_DARK, false)
	var stone: ShaderMaterial = ToonMaterials.prop(LookPalette.STONE)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.5
	body.mesh = capsule
	body.material_override = cloth
	body.position = Vector3(-0.5, 0.75, 0)
	group.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	head.mesh = sphere
	head.material_override = skin
	head.position = Vector3(-0.5, 1.66, 0)
	group.add_child(head)

	# The blade crosses the body from the right hip to above the left shoulder.
	var grip := Transform3D(Basis(Vector3.FORWARD, 0.7), Vector3(-0.3, 0.85, 0.36))
	var blade := MeshKit.new()
	blade.box(grip * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(0.05, 0.95, 0.012))
	group.add_child(MeshKit.instance(blade.commit(true), steel))
	var hilt := MeshKit.new()
	hilt.box(grip, Vector3(0.04, 0.26, 0.04))
	group.add_child(MeshKit.instance(hilt.commit(true), wood))

	var kits := MeshKitSet.new()
	var lantern: MeshKit = kits.kit(&"stone")
	var base := Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.65, 0, -0.2))
	lantern.box(base * Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.7, 0.2, 0.7))
	lantern.cylinder(base * Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.14, 0.11, 0.7, 10)
	lantern.box(base * Transform3D(Basis(), Vector3(0, 0.95, 0)), Vector3(0.5, 0.1, 0.5))
	lantern.box(base * Transform3D(Basis(), Vector3(0, 1.15, 0)), Vector3(0.36, 0.3, 0.36))
	lantern.roof(base * Transform3D(Basis(), Vector3(0, 1.33, 0)), 0.42, 0.42, 0.3, 0.12, 4, 0.06)
	kits.finish(group, {&"stone": stone}, [&"stone"])
	return [cloth, skin, steel, wood, stone]
