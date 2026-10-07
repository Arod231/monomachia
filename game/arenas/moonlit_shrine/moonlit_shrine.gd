class_name MoonlitShrine
extends Node3D
## The Moonlit Shrine arena: a walled stone courtyard floating above a sea of
## clouds under a blood-red moon. Everything is built from code and shaders
## when the scene enters the tree, from two data files: the ArenaDef (def:
## walls, spawns, gates, camera limits, ambience sound) and the ShrineLayout
## (layout: where every piece goes).
##
## Like every arena it brings its own environment and lights, in the
## realistic look (milestone-1 task 43, as the look test settled it): the
## night (LookGrade) over its sky, the moon's cold key, the lanterns' embers,
## a ground mist in the volumetric fog and dust in the moonlight. It applies
## the chosen graphics preset to itself when it loads; the match brings the
## camera and the fighters. It flickers its lantern lights,
## bobs its floating rocks, and leaves the rock under its rim out of the
## cameras above the courtyard (cull_below_deck).
##
## Seams for the match (see ArenaScenes): `def`, from which the camera takes
## its limits; Marker3D children Spawn0, Spawn1 (where the rules start each
## side) and Gate0, Gate1 (the gate anchors); and Platform/GateRope0 and
## GateRope1 (each gate's rope barrier, for the match intro to drop).
##
## Its builders: ShrinePlatform (the courtyard and its props), ShrineUnderside
## (the rock under it and the floating rocks), ShrineBackdrop (the world round
## it) and ShrineParticles (the embers and ash on the wind).

## The highest camera (m above the floor) that leaves out the rock under the
## rim: from there and inside the camera's limit (def.camera_max_radius),
## sight lines over the ledge pass above the crag, its roots and its chains.
const BELOW_DECK_MAX_HEIGHT := 5.0
## How much of the moon's red wash the mountains and the cloud sea keep, so
## the blood moon stays the accent and the distance falls back into the
## night's mist (the mood board's "colour only as accents").
const MOON_WASH: float = 0.35
## The dust motes over the courtyard (the look test's 140 over a corner,
## spread over the whole floor at about a third of that density).
const DUST_AMOUNT: int = 700

@export var def: ArenaDef
@export var layout: ShrineLayout

var _lantern_lights: Array[OmniLight3D] = []
var _floating_rocks: Node3D
var _time: float = 0.0


func _ready() -> void:
	_build()
	GraphicsApplier.apply_to_tree(GameServices.graphics_preset(), self)


func _process(delta: float) -> void:
	_time += delta
	for i: int in _lantern_lights.size():
		_lantern_lights[i].light_energy = ShrinePlatform.LANTERN_ENERGY * _flicker(_time, i)
	ShrineUnderside.bob_rocks(_floating_rocks, layout, _time)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		cull_below_deck(camera)


## Leaves the rock under the rim out of camera's view, or puts it back, by
## where the camera is. It's the camera's choice (the BELOW_DECK_LAYER bit of
## its cull mask), so each view of a split screen decides for itself: the
## arena does this for its viewport's camera every frame, after the match
## view has moved it, and another view's camera needs it called too. The bit
## stays as set when the arena leaves, which only matters to an arena that
## draws on that layer, and it sets the bit again itself.
func cull_below_deck(camera: Camera3D) -> void:
	if _sees_below_deck(to_local(camera.global_position)):
		camera.cull_mask |= LookPalette.BELOW_DECK_LAYER
	else:
		camera.cull_mask &= ~LookPalette.BELOW_DECK_LAYER


## Whether a camera at point (arena space) can see the rock under the rim.
## The fight and menu cameras can't, so they leave it out: drawn behind the
## floor it still cost about 0.4 ms a frame on the target laptop.
func _sees_below_deck(point: Vector3) -> bool:
	# a hair past the limit: a camera clamped to it lands there give or take
	# rounding
	var over_courtyard: bool = Vector2(point.x, point.z).length() <= def.camera_max_radius + 1e-3
	return not (over_courtyard and point.y >= 0.0 and point.y <= BELOW_DECK_MAX_HEIGHT)


## Lantern i's brightness at time t, around 1: three waves at odd rates,
## offset per lantern so they don't flicker together.
static func _flicker(t: float, i: int) -> float:
	return 1.0 + 0.08 * sin(t * 9.0 + i * 1.7) + 0.06 * sin(t * 23.0 + i * 4.1) + 0.035 * sin(t * 3.1 + i)


func _build() -> void:
	assert(def != null and def.environment != null and layout != null, "MoonlitShrine needs def, its environment and layout")
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	# Each arena gets its own copy, sky included, so a preset can change its
	# fog and the layout can place its moon; the night is built over it.
	var base := def.environment.duplicate(true) as Environment
	_dress_sky(base)
	env.environment = LookGrade.environment(base)
	add_child(env)
	add_child(_build_lights())
	add_child(ShrinePlatform.build(layout, def))
	for light: Node in get_node(^"Platform/LanternLights").get_children():
		_lantern_lights.append(light as OmniLight3D)
	add_child(ShrineUnderside.build(layout, def))
	_floating_rocks = get_node(^"Underside/FloatingRocks")
	add_child(ShrineBackdrop.build(layout, base.fog_light_color))
	add_child(ShrineParticles.build(layout, ShrinePlatform.fire_points(layout)))
	add_child(_ground_mist())
	add_child(_dust())
	quiet_backdrop(self)
	_add_markers()


## Marker3D seams: Spawn0, Spawn1 and Gate0, Gate1 from the ArenaDef.
func _add_markers() -> void:
	for side: int in def.spawn_points.size():
		_add_marker("Spawn%d" % side, def.spawn_point(side))
	for side: int in def.gate_anchors.size():
		_add_marker("Gate%d" % side, def.gate_anchor(side))


func _add_marker(marker_name: String, xform: Transform3D) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.transform = xform
	add_child(m)


## The moon's key light (moonlit steel, casting the shadows the preset sets,
## lighting the mist), and a red rim light from the moon's side that touches
## fighters only (and no fog, which every light would otherwise reach).
func _build_lights() -> Node3D:
	var root := Node3D.new()
	root.name = "Lights"
	var key := DirectionalLight3D.new()
	key.name = "MoonKey"
	key.light_color = LookPalette.MOON_STEEL.lightened(0.25)
	key.light_energy = 0.9
	key.light_volumetric_fog_energy = 1.2
	key.shadow_enabled = true
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.2
	key.shadow_blur = 1.0
	key.directional_shadow_split_1 = 0.22
	key.directional_shadow_blend_splits = true
	key.directional_shadow_fade_start = 0.85
	key.light_angular_distance = 0.0
	key.add_to_group(GraphicsApplier.GROUP_SHADOW_LIGHT)
	key.basis = _shining_from(layout.key_light_direction)
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.name = "MoonRim"
	rim.light_color = Color(1.0, 0.36, 0.28)
	rim.light_energy = 1.1
	rim.shadow_enabled = false
	rim.light_cull_mask = LookPalette.FIGHTER_LAYER
	rim.light_volumetric_fog_energy = 0.0
	# Light only: the sky draws the one moon, from the layout.
	rim.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	rim.basis = _shining_from(layout.moon_direction)
	root.add_child(rim)
	return root


## The red wash toward the moon of the mountains, the cloud sea and anything
## else under root with a moon_tint, cut to MOON_WASH of it, on copies of
## their materials.
static func quiet_backdrop(root: Node) -> void:
	var done: Dictionary[Material, Material] = {}
	for g: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = g as GeometryInstance3D
		var m: ShaderMaterial = gi.material_override as ShaderMaterial
		if m == null or m.shader == null or m.get_shader_parameter(&"moon_tint") == null:
			continue
		if not done.has(m):
			var q := m.duplicate() as ShaderMaterial
			q.set_shader_parameter(&"moon_tint", (m.get_shader_parameter(&"moon_tint") as Color) * MOON_WASH)
			done[m] = q
		gi.material_override = done[m]


## Ground mist over the courtyard: a fog volume a metre and a half deep,
## thicker low down, for the lanterns and the moon to light (volumetric fog,
## so the presets that turn that off drop it too).
func _ground_mist() -> FogVolume:
	var v := FogVolume.new()
	v.name = "GroundMist"
	v.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var reach: float = def.floor_radius * 2.0 + 4.0
	v.size = Vector3(reach, 1.6, reach)
	v.position = Vector3(0.0, 0.5, 0.0)
	var m := FogMaterial.new()
	m.density = 0.18
	m.albedo = LookPalette.MIST.lightened(0.15)
	m.height_falloff = 1.6
	m.edge_fade = 0.6
	v.material = m
	return v


## Dust in the moonlight over the courtyard: tiny lit motes drifting slowly,
## so the fog's light catches them; the preset's particle ratio thins them.
func _dust() -> GPUParticles3D:
	var dust := GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = DUST_AMOUNT
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.fixed_fps = 30
	dust.randomness = 0.6
	var r: float = def.floor_radius
	dust.visibility_aabb = AABB(Vector3(-r, -1.0, -r), Vector3(r * 2.0, 5.0, r * 2.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r * 0.85, 1.2, r * 0.85)
	pm.gravity = Vector3(0.0, -0.015, 0.0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.direction = Vector3(1.0, 0.2, 0.3)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_speed_random = 0.3
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.008, 0.008)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.75, 0.78, 0.85, 0.35)
	m.albedo_texture = _mote()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = LookPalette.MOON_STEEL
	m.emission_energy_multiplier = 0.12
	quad.material = m
	dust.draw_pass_1 = quad
	dust.position = Vector3(0.0, 1.5, 0.0)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.add_to_group(GraphicsApplier.GROUP_PARTICLES)
	return dust


## A soft round mote.
static func _mote() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


## Puts the sky's moon where the layout says, paints its horizon in the
## depth fog's colour so the fog fades into it, and gives it the look's noise.
## A sky that isn't a shader (bought art, say) is left as it is.
func _dress_sky(environment: Environment) -> void:
	if environment.sky == null or not environment.sky.sky_material is ShaderMaterial:
		return
	var sky := environment.sky.sky_material as ShaderMaterial
	sky.set_shader_parameter(&"moon_direction", layout.moon_direction.normalized())
	sky.set_shader_parameter(&"horizon_color", environment.fog_light_color)
	LookNoise.apply_to(sky)


## A light's basis shining from from_dir: its -Z points away from it.
static func _shining_from(from_dir: Vector3) -> Basis:
	var d: Vector3 = -from_dir.normalized()
	var up: Vector3 = Vector3.UP if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	return Basis.looking_at(d, up)
