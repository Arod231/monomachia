extends Node3D
## Puts every shader in the project on screen so that each one compiles in a
## real window: a headless run uses the dummy renderer and never compiles
## shaders, so the tests can't catch a shader error. `npm run shots` fails
## when Godot prints SHADER ERROR or a script error, so this scene fails on
## any broken shader:
##   node scripts/godot.mjs shots res://tools/shot_scenes/shader_check.tscn <out.png>
##
## It finds the .gdshader files (a shader include compiles with the shaders
## that include it). Spatial shaders go on quads in a grid in front of the
## camera, canvas_item shaders on squares along the bottom, particle shaders
## drive a few particles, fog shaders fill a fog volume, and sky shaders take
## turns as the sky, a few frames each. A shader of any other mode is
## reported as an error, so a new kind isn't skipped silently.

## Folders whose shaders aren't the game's own (dot-folders such as .godot
## are hidden from DirAccess already).
const SKIP_DIRS: Array[String] = ["res://addons"]
## Frames to let the renderer settle before the sky shaders take turns.
const SETTLE_FRAMES: int = 3
## Frames to let each sky compile and draw.
const FRAMES_PER_SKY: int = 3
## The grid of spatial quads: columns, and the spacing in metres.
const GRID_COLUMNS: int = 8
const GRID_STEP: float = 1.3
## The canvas_item squares: their size and spacing in pixels, from the left
## of the bottom row.
const SQUARE_SIZE: float = 100.0
const SQUARE_STEP: float = 110.0

var _skies: Array[Shader] = []
var _sky_material: ShaderMaterial
var _frames: int = 0
var _sky_index: int = 0
var _done: bool = false


func shot_frames() -> int:
	return SETTLE_FRAMES


func shot_ready() -> bool:
	return _done


## Every .gdshader under `dir_path`, outside SKIP_DIRS.
static func _shader_paths(dir_path: String, out: Array[String]) -> Array[String]:
	if SKIP_DIRS.has(dir_path):
		return out
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		_shader_paths(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.ends_with(".gdshader"):
			out.append(dir_path.path_join(file))
	return out


func _ready() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 0, 6)
	add_child(camera)
	camera.make_current()
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	add_child(light)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.volumetric_fog_enabled = true
	env.sky = Sky.new()
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	add_child(canvas_layer)

	var paths: Array[String] = _shader_paths("res://", [])
	var counts: Dictionary[String, int] = {"spatial": 0, "canvas_item": 0, "particles": 0, "fog": 0, "sky": 0}
	var bottom: float = get_viewport().get_visible_rect().size.y - SQUARE_SIZE - 20.0
	for path: String in paths:
		var shader: Shader = load(path) as Shader
		if shader == null:
			push_error("shader_check: cannot load %s" % path)
			continue
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		match shader.get_mode():
			Shader.MODE_SPATIAL:
				var n: int = counts["spatial"]
				var quad: MeshInstance3D = MeshInstance3D.new()
				quad.mesh = QuadMesh.new()
				quad.material_override = material
				var column: int = n % GRID_COLUMNS
				var row: int = floori(float(n) / GRID_COLUMNS)
				quad.position = Vector3((column - GRID_COLUMNS * 0.5) * GRID_STEP, 2.0 - row * GRID_STEP, 0)
				add_child(quad)
				counts["spatial"] = n + 1
			Shader.MODE_CANVAS_ITEM:
				var rect: ColorRect = ColorRect.new()
				rect.material = material
				rect.position = Vector2(20.0 + counts["canvas_item"] * SQUARE_STEP, bottom)
				rect.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
				canvas_layer.add_child(rect)
				counts["canvas_item"] += 1
			Shader.MODE_PARTICLES:
				var particles: GPUParticles3D = GPUParticles3D.new()
				particles.process_material = material
				particles.draw_pass_1 = QuadMesh.new()
				particles.amount = 4
				particles.position = Vector3(3, -2, 0)
				add_child(particles)
				counts["particles"] += 1
			Shader.MODE_FOG:
				var fog: FogVolume = FogVolume.new()
				fog.material = material
				fog.position = Vector3(-3, -2, 0)
				add_child(fog)
				counts["fog"] += 1
			Shader.MODE_SKY:
				_skies.append(shader)
				counts["sky"] += 1
			_:
				push_error("shader_check: %s is a kind of shader this scene doesn't draw (mode %d)" % [path, shader.get_mode()])
	print("shader_check: %d shaders %s" % [paths.size(), counts])
	_sky_material = ShaderMaterial.new()
	if not _skies.is_empty():
		_sky_material.shader = _skies[0]
		env.sky.sky_material = _sky_material
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.1, 0.1, 0.12)


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _frames < FRAMES_PER_SKY:
		return
	_frames = 0
	_sky_index += 1
	if _sky_index >= _skies.size():
		_done = true
		return
	_sky_material.shader = _skies[_sky_index]
