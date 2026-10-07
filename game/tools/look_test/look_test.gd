class_name LookTest
extends Node
## The look test (milestone-1 task 30; spec stories 134, 138): one fighter,
## the Hunter in crimson with the Katana, in a corner of the Moonlit Shrine
## at Ultra, in the realistic look the mood board settled (moodboard/ in the
## asset repository), playing the pilot family's moves (the Katana's light
## string) as they stand, under the gameplay camera's framing (the board's
## Camera 2). It is its own scene: the game keeps the toon look until the art
## conversion (the owner's choice, Oct 5).
##
## What it shows (the look stories 140, 142, 154 and the Godot check's 4-6):
## - physically based materials on the fighter, the Katana and the Shrine
##   (LookMaterials), no outlines and no ink-wash pass;
## - dark first: the moon's cold key, blue-black shadow (NIGHT_INK), mist in
##   volumetric fog that eats the background, the lanterns the few warm
##   lights, colour only as accents;
## - the fighter lifted out of the dark by a key and a rim light that touch
##   only fighters (LookPalette.FIGHTER_LAYER);
## - clean while fighting: FSR 2.2's temporal anti-aliasing at Ultra's 67%
##   (or Godot's TAA at full resolution, --aa=taa), subtle bloom, ambient
##   occlusion, fog, the grade and light grain;
## - the features milestone 1 needs (Godot check 6): volumetric fog, decals
##   (a damp stain and moss), GPU particles (dust in the moonlight), temporal
##   anti-aliasing and FSR 2.2, spring bones (a sageo cord with a tassel on
##   the saya, in the fighter's crimson) and skeleton modifiers (the fighter's
##   rig);
## - the pilot's effects in the look (milestone-1 task 37): each light's
##   strike leaves its air smear, and with --contact= each light, as its
##   strike lands, meets an imagined guard at the blade's tip, throwing that
##   contact's sparks and lighting the fighter with them (block, heavy_block,
##   parry, flash or redirect, the effect table's, CombatEffects as in a
##   match).
##
## Shots, beside the mood board:
##   npm run shots -- res://tools/look_test/look_test.tscn <out.png> 40 [options]
## Options: --view=gameplay (default), close or wide; --at=<step> holds the
## string at that rules step of its loop (else it plays); --aa=fsr2
## (default), taa or off; --preset=<id> (default ultra); --contact=block,
## heavy_block, parry, flash or redirect (none by default) stages that contact
## at each light's first active frame.
## The bench (Godot check 5: 99% of frames at 14 ms or less on the RTX 3090):
##   npm run bench:look [-- --res=3840x2160 --frames=1800 --out=<file.csv>]
## renders at --res into its own target, warms up for WARMUP_FRAMES, times
## --frames frames, prints the summary against GATE_MS and writes the frames.

## The look's colours, from the mood board.
const NIGHT_INK := Color("#0b0e16")
const MOON_STEEL := Color("#8f9bb0")
const MIST := Color("#4b5468")
const LANTERN_EMBER := Color("#d4873a")
const MOSS := Color("#2f3a2a")
const CRIMSON := Color("#9e2b25")
const DEEP_CRIMSON := Color("#5c1618")
## What the outfit's orange red is multiplied by to reach CRIMSON.
const DYE := Color(0.86, 0.62, 0.66)
## How much of the moon's red wash the backdrop keeps (quiet_backdrop()).
const MOON_WASH: float = 0.35

## The gameplay camera's framing: the board's Camera 2, For Honor's.
const CAMERA_BACK: float = 4.08
const CAMERA_SIDE: float = 1.0
const CAMERA_CLOSE_SIDE: float = 0.6
const CAMERA_CLOSE_FROM: float = 4.2
const CAMERA_HEIGHT: float = 1.75
const CAMERA_FOV: float = 55.0

## The look test's gate (Godot check 5), and the bench's run.
const GATE_MS: float = 14.0
const WARMUP_FRAMES: int = 600
const BENCH_FRAMES: int = 1800
const BENCH_RES := Vector2i(3840, 2160)

## Where the fighter stands: this far in from the lantern it faces (m), and
## the hidden opponent CAMERA_CLOSE_FROM ahead of it, so the camera frames
## it as at Camera 2's base distance.
const FROM_LANTERN: float = 5.5
## The light string's loop: the first press, and how long the fighter stands
## in its guard after the string before it starts again (rules steps).
const FIRST_PRESS: int = 12
const REST_STEPS: int = 70
const STRING_LENGTH: int = 4

## The sageo cord: segments, each this long (m), and the tassel.
const CORD_SEGMENTS: int = 6
## The contacts --contact= stages, as the rules' events would name them
## (a Katana on a Katana; a redirect by a bare hand).
const CONTACTS: Dictionary = {
	&"block": {"t": &"block", "heavy": false},
	&"heavy_block": {"t": &"block", "heavy": true},
	&"parry": {"t": &"parry", "kind": &"parry"},
	&"flash": {"t": &"parry", "kind": &"flash"},
	&"redirect": {"t": &"parry", "kind": &"redirect", "defender_weapon": &"fists"},
}
const CORD_SEGMENT: float = 0.045

enum View { GAMEPLAY, CLOSE, WIDE }

var view_kind: View = View.GAMEPLAY
var hold_step: int = -1
var aa: StringName = &"fsr2"
var preset: GraphicsPreset
var bench: bool = false
## Whether the stage renders into its own target (the bench, and tests,
## which must not change the window they run in) rather than the window.
var own_viewport: bool = false
var bench_res: Vector2i = BENCH_RES
var bench_frames: int = BENCH_FRAMES
var out_path: String = ""

## The stage (everything 3D), its viewport, and what is on it.
var stage: Node3D
var arena: Node3D
var environment: Environment
## The arena's own environment, which the look's is built over.
var _arena_environment: Environment
var world: World
var fighter: FighterView
var camera: Camera3D
var rig_camera: CameraRig
var key_light: SpotLight3D
var rim_light: SpotLight3D
var cord: Skeleton3D
var cord_sim: SkeletonModifier3D
var materials: LookMaterials = LookMaterials.new()
## The match's effects layer: the air smears and the staged contacts'
## sparks, puffs and light (milestone-1 task 37).
var effects: CombatEffects
## The contact staged at each light's strike (--contact=), or none.
var contact: StringName = &""

var _spot: Vector3
var _facing: Vector3
var _step: int = 0
var _loop_step: int = 0
var _presses: int = 0
## The attack the last follow-up was pressed in.
var _pressed_in: AttackState = null
var _rested: int = 0
var _time: float = 0.0
var _target: SubViewport
var _frame: int = 0
var _last_usec: int = 0
var _frame_ms: PackedFloat64Array = PackedFloat64Array()
var _gpu_ms: PackedFloat64Array = PackedFloat64Array()
var _cpu_ms: PackedFloat64Array = PackedFloat64Array()


func _ready() -> void:
	var problem: String = read_args(OS.get_cmdline_user_args())
	if problem != "":
		push_error("look_test: " + problem)
	build()
	if bench:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("look_test: bench at %dx%d, %d warm-up and %d timed frames, on %s" % [bench_res.x, bench_res.y,
			WARMUP_FRAMES, bench_frames, RenderingServer.get_video_adapter_name()])


## Reads --view=, --at=, --aa=, --preset=, --contact=, --bench, --res=,
## --frames= and --out=; returns what is wrong with them, or "".
func read_args(args: PackedStringArray) -> String:
	preset = GraphicsPreset.ultra()
	for a: String in args:
		var kv: PackedStringArray = a.split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"--view":
				if not View.has(v.to_upper()):
					return "--view takes gameplay, close or wide, not %s" % v
				view_kind = View[v.to_upper()]
			"--at":
				hold_step = int(v)
			"--aa":
				if not [&"fsr2", &"taa", &"off"].has(StringName(v)):
					return "--aa takes fsr2, taa or off, not %s" % v
				aa = StringName(v)
			"--preset":
				preset = GraphicsPreset.load_id(StringName(v))
			"--bench":
				bench = true
			"--res":
				var wh: PackedStringArray = v.split("x")
				bench_res = Vector2i(int(wh[0]), int(wh[1]))
			"--frames":
				bench_frames = int(v)
			"--out":
				out_path = v
			"--contact":
				if not CONTACTS.has(StringName(v)):
					return "--contact takes block, heavy_block, parry, flash or redirect, not %s" % v
				contact = StringName(v)
	return ""


## Builds the stage: the Shrine in the realistic look, the fighter in its
## corner, the lights, the camera, the cord, decals, dust and grain.
func build() -> void:
	stage = Node3D.new()
	stage.name = "Stage"
	if bench or own_viewport:
		_target = SubViewport.new()
		_target.name = "BenchTarget"
		_target.size = bench_res
		_target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_target)
		_target.add_child(stage)
		var shown := TextureRect.new()
		shown.texture = _target.get_texture()
		shown.set_anchors_preset(Control.PRESET_FULL_RECT)
		shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(shown)
		RenderingServer.viewport_set_measure_render_time(_target.get_viewport_rid(), true)
	else:
		add_child(stage)
	arena = (load("res://arenas/moonlit_shrine/moonlit_shrine.tscn") as PackedScene).instantiate() as Node3D
	stage.add_child(arena)
	_realistic_arena()
	_place()
	_new_world()
	fighter = FighterView.new()
	fighter.name = "Fighter"
	stage.add_child(fighter)
	fighter.setup(&"hunter", 0, &"katana", 0)
	materials.convert_tree(fighter)
	_dye(fighter)
	_build_cord()
	_build_lights()
	_build_camera()
	_build_decals()
	_build_dust()
	_build_mist()
	_build_grain()
	effects = CombatEffects.new()
	stage.add_child(effects)
	_apply_preset()
	if hold_step >= 0:
		# each step drawn, so the smear and a staged contact see the blade
		for i: int in hold_step:
			_advance()
			_show(0.0)
	_show(0.0)
	if rig_camera != null:
		rig_camera.snap(_pos(0), _pos(1))


func _process(delta: float) -> void:
	if hold_step < 0:
		_advance()
	_time += delta
	_show(delta)
	if bench:
		_bench_frame()


# ------------------------------------------------------------------ the Shrine

## The Shrine in the realistic look: its toon materials physically based, no
## ink-wash pass, the look's environment, and its lights into the fog.
func _realistic_arena() -> void:
	for node: Node in arena.find_children("*", "InkWashPass", true, false):
		node.queue_free()
		node.get_parent().remove_child(node)
	materials.convert_tree(arena)
	quiet_backdrop(arena)
	_arena_environment = (arena.get_node(^"WorldEnvironment") as WorldEnvironment).environment
	var key: DirectionalLight3D = arena.get_node(^"Lights/MoonKey") as DirectionalLight3D
	key.light_color = MOON_STEEL.lightened(0.25)
	key.light_energy = 0.9
	key.light_volumetric_fog_energy = 1.2
	# the red rim lights fighters only, but fog takes every light: none in it
	(arena.get_node(^"Lights/MoonRim") as Light3D).light_volumetric_fog_energy = 0.0
	for light: Node in arena.get_node(^"Platform/LanternLights").get_children():
		var lantern: OmniLight3D = light as OmniLight3D
		lantern.light_color = LANTERN_EMBER
		lantern.light_volumetric_fog_energy = 2.0
		lantern.shadow_enabled = true


## The mountains' and the cloud sea's red wash toward the moon, cut to
## MOON_WASH of it, so the blood moon stays the accent and the distance falls
## back into the night's mist (the board's "colour only as accents").
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


## The look's environment over the arena's sky: blue-black ambient, mist in
## volumetric fog and depth fog, ambient occlusion, subtle bloom, a filmic
## tone map and the grade (the shadows lifted toward NIGHT_INK, colour
## pulled back but for the accents).
static func realistic_environment(base: Environment) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = night_sky(base.sky)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.16
	e.ambient_light_sky_contribution = 0.35
	e.ambient_light_color = MIST
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 0.82
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.6
	e.ssao_power = 1.4
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.03
	e.volumetric_fog_albedo = MIST
	e.volumetric_fog_emission = NIGHT_INK
	e.volumetric_fog_emission_energy = 0.6
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_length = 48.0
	e.volumetric_fog_sky_affect = 0.35
	e.volumetric_fog_ambient_inject = 0.25
	e.fog_enabled = true
	e.fog_light_color = MIST
	e.fog_density = 0.0035
	e.fog_sky_affect = 0.5
	e.fog_aerial_perspective = 0.35
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_strength = 0.9
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.18
	e.adjustment_saturation = 0.72
	e.adjustment_color_correction = grade_curve()
	return e


## The arena's sky, quieter: a copy with its red haze and the clouds' red
## edges pulled back, so the blood moon is the one strong colour in it.
static func night_sky(sky: Sky) -> Sky:
	if sky == null or not sky.sky_material is ShaderMaterial:
		return sky
	var out := sky.duplicate(true) as Sky
	var m := out.sky_material as ShaderMaterial
	m.set_shader_parameter(&"haze_strength", 0.12)
	m.set_shader_parameter(&"cloud_edge_color", Color(0.16, 0.07, 0.07))
	m.set_shader_parameter(&"horizon_color", MIST.darkened(0.45))
	m.set_shader_parameter(&"below_color", MIST.darkened(0.55))
	return out


## The grade: each channel through a curve that lifts black to NIGHT_INK,
## cools the mid tones toward moonlit steel and warms the highlights a
## touch (a 1D colour correction).
static func grade_curve() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, NIGHT_INK)
	g.set_offset(1, 1.0)
	g.set_color(1, Color(1.0, 0.97, 0.92))
	g.add_point(0.45, Color(0.42, 0.45, 0.5))
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


# ------------------------------------------------------------------ the fighter

## The corner: the lantern most toward the moon, the fighter FROM_LANTERN in
## from it facing it, so the camera behind it sees the lantern, the wall and
## the blood moon.
func _place() -> void:
	var moon: Vector3 = (arena.get(&"layout") as ShrineLayout).moon_direction
	var moon_flat := Vector3(moon.x, 0.0, moon.z).normalized()
	var best: Vector3 = Vector3(0.0, 0.0, 10.0)
	var best_dot: float = -2.0
	for light: Node in arena.get_node(^"Platform/LanternLights").get_children():
		var p: Vector3 = (light as Node3D).global_position
		var flat := Vector3(p.x, 0.0, p.z)
		var d: float = flat.normalized().dot(moon_flat)
		if d > best_dot:
			best_dot = d
			best = flat
	_facing = best.normalized()
	_spot = best - _facing * FROM_LANTERN


## A new world for the loop: the fighter on its spot facing the lantern, the
## hidden opponent CAMERA_CLOSE_FROM ahead.
func _new_world() -> void:
	world = World.new(FighterConfig.make(Moves.KATANA, []), FighterConfig.make(Moves.KATANA, []), 7)
	var a: Fighter = world.fighters[0]
	var b: Fighter = world.fighters[1]
	var there: Vector3 = _spot + _facing * CAMERA_CLOSE_FROM
	a.pos = V3.make(_spot.x, 0.0, _spot.z)
	b.pos = V3.make(there.x, 0.0, there.z)
	a.yaw = atan2(_facing.x, _facing.z)
	b.yaw = atan2(-_facing.x, -_facing.z)
	a.set_state(&"free")
	b.set_state(&"free")
	_loop_step = 0
	_presses = 0
	_pressed_in = null
	_rested = 0


## One rules step of the loop: the string's lights pressed as each can take
## its follow-up, then the guard, then the loop again.
func _advance() -> void:
	var a: Fighter = world.fighters[0]
	var press: bool = false
	if _presses == 0 and _loop_step == FIRST_PRESS:
		press = true
	elif _presses > 0 and _presses < STRING_LENGTH and world.hitstop == 0 and a.state == &"attack" and a.atk != null \
			and a.atk != _pressed_in and a.atk.frame > a.atk.def.startup and a.atk.def.chain_light != &"":
		# once per attack, never in hit-stop, where the frames stand still
		press = true
	if press:
		_presses += 1
		_pressed_in = a.atk
	world.step([RawInput.make(0.0, 0.0, 1 << Btn.LIGHT) if press else RawInput.make(0.0, 0.0, 0), RawInput.make(0.0, 0.0, 0)])
	_stage_contact()
	_loop_step += 1
	_step += 1
	if _presses > 0 and a.state == &"free":
		_rested += 1
		if _rested >= REST_STEPS:
			_new_world()


func _pos(i: int) -> Vector3:
	var f: Fighter = world.fighters[i]
	return Vector3(f.pos.x, f.pos.y, f.pos.z)


## On a light's first active frame, with --contact=, the contact's effects
## where the rules' blade is (its tip, as the rules place it that frame), the
## sparks thrown along its sweep (the tip's travel over the frame), as the
## rules' event for that contact would spawn.
func _stage_contact() -> void:
	var a: Fighter = world.fighters[0]
	if contact == &"" or a.state != &"attack" or a.atk == null or a.atk.frame != a.atk.def.startup + 1 or a.atk.blades.is_empty():
		return
	var blade: BladeSegment = a.atk.blades[0]
	var tip: Vector3 = Vector3(blade.tip.x, blade.tip.y, blade.tip.z)
	var e: Dictionary = {"pos": {"x": tip.x, "y": tip.y, "z": tip.z}, "weapon": &"katana", "defender_weapon": &"katana",
		"attacker": 0, "parrier": 1, "target": 1}
	e.merge(CONTACTS[contact], true)
	var sweep: Vector3 = tip - Vector3(blade.prev_tip.x, blade.prev_tip.y, blade.prev_tip.z)
	if sweep.length() > 1e-4:
		e["dir"] = {"x": sweep.x, "y": sweep.y, "z": sweep.z}
	effects.on_event(e, world.frame)


## Poses the fighter and moves the lights and the camera with it; lays the
## blade into its air smear and ages the effects.
func _show(delta: float) -> void:
	var f: Fighter = world.fighters[0]
	fighter.update_from(f, _pos(0), f.yaw, 1.0, delta, _time)
	var blades: Array[PackedVector3Array] = fighter.blade_segments()
	if not blades.is_empty():
		var rules: TrailState = TrailState.of(f, 1.0)
		var span: PackedVector3Array = AirSmear.span(blades[0][0], blades[0][1])
		effects.feed_smear(0, TrailState.RIGHT, float(world.frame), span[0], span[1], rules.intensity(TrailState.RIGHT), rules.kind)
	effects.update(float(world.frame))
	var chest: Vector3 = _pos(0) + Vector3(0.0, 1.3, 0.0)
	var ahead: Vector3 = (_pos(1) - _pos(0)).normalized()
	var left: Vector3 = Vector3.UP.cross(ahead).normalized()
	key_light.global_position = chest + ahead * 2.2 + left * 1.6 + Vector3(0.0, 1.4, 0.0)
	key_light.look_at(chest, Vector3.UP)
	rim_light.global_position = chest + ahead * 1.6 - left * 1.8 + Vector3(0.0, 1.8, 0.0) - ahead * 3.4
	rim_light.look_at(chest, Vector3.UP)
	match view_kind:
		View.GAMEPLAY:
			rig_camera.update_rig(delta, _pos(0), _pos(1))
		View.CLOSE:
			camera.global_position = chest + ahead * 2.3 + left * 1.2 + Vector3(0.0, -0.1, 0.0)
			camera.look_at(chest + Vector3(0.0, -0.1, 0.0), Vector3.UP)
		View.WIDE:
			camera.global_position = _pos(0) - ahead * 7.5 - left * 3.0 + Vector3(0.0, 3.2, 0.0)
			camera.look_at(_pos(0) + ahead * 3.0 + Vector3(0.0, 1.4, 0.0), Vector3.UP)
	(arena as Object).call(&"cull_below_deck", camera)


## Pulls the fighter's cloth toward the board's crimson (#9e2b25): the
## outfit's baked palette is an orange red; a tint on its physically based
## materials, in the look test only (the art conversion re-dyes it).
func _dye(root: Node) -> void:
	for g: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi.mesh == null:
			continue
		for i: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(i)
			var sm: StandardMaterial3D = m as StandardMaterial3D
			if sm != null and sm.albedo_texture != null and sm.albedo_texture.resource_path.contains("outfit"):
				var dyed := sm.duplicate() as StandardMaterial3D
				dyed.albedo_color = sm.albedo_color * DYE
				mi.set_surface_override_material(i, dyed)


# ------------------------------------------------------------------ lights and camera

## The key and the rim on the fighter alone: the key from in front and to its
## left in moonlit steel, the rim cold from behind and above, both on
## FIGHTER_LAYER, so the fighter comes out of the dark and nothing else does.
func _build_lights() -> void:
	key_light = SpotLight3D.new()
	key_light.name = "FighterKey"
	key_light.light_color = MOON_STEEL.lightened(0.3)
	key_light.light_energy = 6.0
	key_light.spot_range = 7.0
	key_light.spot_angle = 26.0
	key_light.light_cull_mask = LookPalette.FIGHTER_LAYER
	key_light.light_volumetric_fog_energy = 0.0
	key_light.shadow_enabled = true
	stage.add_child(key_light)
	rim_light = SpotLight3D.new()
	rim_light.name = "FighterRim"
	rim_light.light_color = Color(0.72, 0.8, 1.0)
	rim_light.light_energy = 9.0
	rim_light.spot_range = 8.0
	rim_light.spot_angle = 22.0
	rim_light.light_cull_mask = LookPalette.FIGHTER_LAYER
	rim_light.light_volumetric_fog_energy = 0.0
	stage.add_child(rim_light)


## The gameplay camera with Camera 2's numbers, or a plain camera for the
## close and wide views.
func _build_camera() -> void:
	var def: ArenaDef = arena.get(&"def") as ArenaDef
	if view_kind == View.GAMEPLAY:
		rig_camera = camera_2()
		rig_camera.apply_arena(def.camera_max_radius, def.camera_far)
		camera = rig_camera
	else:
		camera = Camera3D.new()
		camera.fov = 40.0 if view_kind == View.CLOSE else CAMERA_FOV
		camera.far = def.camera_far
	camera.name = "Camera"
	stage.add_child(camera)
	camera.current = true


## The match camera framed as the mood board's Camera 2: about 3.4 m back,
## 1.0 m to the right, swinging out 0.6 m for each metre closer than 3.5 m,
## 1.75 m up, a 55° field of view.
static func camera_2() -> CameraRig:
	var c := CameraRig.new()
	c.follow_back = CAMERA_BACK
	c.follow_side = CAMERA_SIDE
	c.follow_close_side = CAMERA_CLOSE_SIDE
	c.follow_close_from = CAMERA_CLOSE_FROM
	c.follow_far_from = CAMERA_CLOSE_FROM
	c.follow_height = CAMERA_HEIGHT
	c.base_fov = CAMERA_FOV
	return c


## Ultra (or --preset=) on the stage's viewport and tree, then the look's
## environment, which the preset's toon-look settings (no glow) would undo;
## --aa=taa trades FSR 2.2 for Godot's TAA at full resolution, --aa=off for
## neither.
func _apply_preset() -> void:
	var vp: Viewport = _target if _target != null else get_viewport()
	GraphicsApplier.apply(preset, stage, vp)
	environment = realistic_environment(_arena_environment)
	(arena.get_node(^"WorldEnvironment") as WorldEnvironment).environment = environment
	match aa:
		&"taa":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.use_taa = true
		&"off":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.use_taa = false


# ------------------------------------------------------------------ the cord, decals, dust, grain

## The sageo: a cord of CORD_SEGMENTS bones hanging from the saya's mouth,
## with a tassel, swung by a SpringBoneSimulator3D (spring bones, Godot check
## 6), in the fighter's crimson.
func _build_cord() -> void:
	var saya: Node3D = fighter.model.rig.saya
	var parent: Node3D = saya if saya != null else fighter.model.skeleton
	cord = Skeleton3D.new()
	cord.name = "Sageo"
	parent.add_child(cord)
	cord.position = Vector3(0.02, 0.06, 0.0)
	for i: int in CORD_SEGMENTS:
		var bone: int = cord.add_bone("Cord%d" % i)
		if i > 0:
			cord.set_bone_parent(bone, i - 1)
			cord.set_bone_rest(bone, Transform3D(Basis.IDENTITY, Vector3(0.0, -CORD_SEGMENT, 0.0)))
	cord.reset_bone_poses()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CRIMSON
	mat.roughness = 0.9
	for i: int in CORD_SEGMENTS:
		var at := BoneAttachment3D.new()
		at.bone_name = "Cord%d" % i
		cord.add_child(at)
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0045
		cyl.bottom_radius = 0.0045
		cyl.height = CORD_SEGMENT
		cyl.radial_segments = 6
		cyl.material = mat
		seg.mesh = cyl
		seg.position = Vector3(0.0, -CORD_SEGMENT * 0.5, 0.0)
		seg.layers = LookPalette.FIGHTER_LAYER
		at.add_child(seg)
		if i == CORD_SEGMENTS - 1:
			var tassel := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.005
			cone.bottom_radius = 0.016
			cone.height = 0.07
			cone.radial_segments = 8
			var tmat := mat.duplicate() as StandardMaterial3D
			tmat.albedo_color = DEEP_CRIMSON
			cone.material = tmat
			tassel.mesh = cone
			tassel.position = Vector3(0.0, -CORD_SEGMENT - 0.035, 0.0)
			tassel.layers = LookPalette.FIGHTER_LAYER
			at.add_child(tassel)
	var sim := SpringBoneSimulator3D.new()
	sim.name = "CordSpring"
	cord.add_child(sim)
	sim.setting_count = 1
	sim.set_root_bone_name(0, "Cord0")
	sim.set_end_bone_name(0, "Cord%d" % (CORD_SEGMENTS - 1))
	sim.set_extend_end_bone(0, true)
	sim.set_end_bone_length(0, CORD_SEGMENT)
	sim.set_stiffness(0, 0.35)
	sim.set_drag(0, 0.35)
	sim.set_gravity(0, 1.6)
	sim.set_gravity_direction(0, Vector3.DOWN)
	sim.set_radius(0, 0.006)
	cord_sim = sim


## Decals on the stones: a damp stain where the fighter stands and moss at
## the foot of the lantern (Godot check 6), from generated textures.
func _build_decals() -> void:
	var stain := Decal.new()
	stain.name = "DampStain"
	stain.size = Vector3(2.4, 0.6, 2.4)
	stain.texture_albedo = _blot(Color(0.02, 0.025, 0.035, 0.55))
	stain.position = _spot + _facing * 1.4 + Vector3(0.0, 0.1, 0.0)
	stage.add_child(stain)
	var moss := Decal.new()
	moss.name = "Moss"
	moss.size = Vector3(2.0, 0.8, 2.0)
	moss.texture_albedo = _blot(Color(MOSS, 0.85), true)
	moss.position = _spot + _facing * (FROM_LANTERN - 0.7) + Vector3(0.0, 0.2, 0.0)
	stage.add_child(moss)


## A soft blot of `color`, ragged with noise when `ragged`.
static func _blot(color: Color, ragged: bool = false) -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.06
	for y: int in 128:
		for x: int in 128:
			var d: float = Vector2(x - 63.5, y - 63.5).length() / 64.0
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			if ragged:
				a *= clampf(0.5 + noise.get_noise_2d(x, y) * 1.4, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, color.a * a))
	return ImageTexture.create_from_image(img)


## Dust in the moonlight around the fighter: GPU particles (Godot check 6),
## drifting slowly, lit, so the fog's light catches them.
func _build_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 140
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.fixed_fps = 30
	dust.randomness = 0.6
	dust.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 5, 10))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.0, 1.2, 3.0)
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
	m.emission = MOON_STEEL
	m.emission_energy_multiplier = 0.12
	quad.material = m
	dust.draw_pass_1 = quad
	dust.position = _spot + _facing * 1.5 + Vector3(0.0, 1.5, 0.0)
	dust.add_to_group(GraphicsApplier.GROUP_PARTICLES)
	stage.add_child(dust)


## Ground mist: a fog volume a metre and a half deep over the corner, thicker
## low down, for the lanterns and the moon to light (volumetric fog).
func _build_mist() -> void:
	var v := FogVolume.new()
	v.name = "GroundMist"
	v.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	v.size = Vector3(26.0, 1.6, 26.0)
	v.position = _spot + _facing * 2.0 + Vector3(0.0, 0.5, 0.0)
	var m := FogMaterial.new()
	m.density = 0.18
	m.albedo = MIST.lightened(0.15)
	m.height_falloff = 1.6
	m.edge_fade = 0.6
	v.material = m
	stage.add_child(v)


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


## Light grain over the frame: a faint, moving noise, drawn over the stage's
## viewport.
func _build_grain() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Grain"
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float amount = 0.035;\nvoid fragment() {\n\tfloat n = fract(sin(dot(FRAGCOORD.xy + vec2(TIME * 61.0, TIME * 17.0), vec2(12.9898, 78.233))) * 43758.5453);\n\tCOLOR = vec4(vec3(n), amount);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	layer.add_child(rect)
	if _target != null:
		_target.add_child(layer)
	else:
		add_child(layer)


# ------------------------------------------------------------------ the bench

func _bench_frame() -> void:
	var now: int = Time.get_ticks_usec()
	_frame += 1
	if _frame > WARMUP_FRAMES and _last_usec > 0:
		var rid: RID = _target.get_viewport_rid()
		_frame_ms.append(float(now - _last_usec) / 1000.0)
		_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
	_last_usec = now
	if _frame_ms.size() >= bench_frames:
		_finish_bench()


func _finish_bench() -> void:
	set_process(false)
	var p99: float = FrameTimes.percentile(_frame_ms, 99.0)
	var within: int = 0
	for ms: float in _frame_ms:
		if ms <= GATE_MS:
			within += 1
	print("look_test: 99th percentile %.2f ms against %.1f ms: %s (%.2f%% of %d frames within)" % [p99, GATE_MS,
		"holds" if p99 <= GATE_MS else "fails", 100.0 * float(within) / float(_frame_ms.size()), _frame_ms.size()])
	print("look_test: mean %.2f ms, worst %.2f ms; GPU mean %.2f ms, CPU mean %.2f ms" % [FrameTimes.mean(_frame_ms),
		Array(_frame_ms).max(), FrameTimes.mean(_gpu_ms), FrameTimes.mean(_cpu_ms)])
	if out_path != "":
		var steps := PackedInt32Array()
		steps.resize(_frame_ms.size())
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(FrameTimes.csv(_frame_ms, _gpu_ms, _cpu_ms, steps))
			f.close()
	get_tree().quit(0)
