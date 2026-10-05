class_name MatchView
extends Node3D
## The match as the player sees it: the arena (by id, through ArenaScenes),
## the two fighters (FighterView), the dropped weapons and the camera rig. It listens
## to a MatchHost and reads the rules' state every frame; it never changes
## the rules.
##
## Seams for the other lanes: the real arena replaces the stand-in through
## ArenaScenes, and when its root carries an ArenaDef as `def`, the camera
## takes its camera_max_radius and camera_far (read by name, so any resource
## with those two numbers will do); the fighters are placed and posed in
## update_fighters(), and swings (task 14.10) take over their posing from
## StickPose inside FighterView; the combat effects (task 18) are a
## CombatEffects child, spawned from _on_sim_event() by the event table
## (EffectTable) beside the camera's shake and field-of-view kicks, drawn on
## the effect clock every frame and cleared at round start.
##
## A walking or running fighter puts its feet down where its clips land them
## (Locomotion, authored-animation task 29): the view reports each as a
## footfall, for the match's sound to play its footstep there (MatchAudio).
##
## With swing_debug on (F3 in a debug build, or --swing-debug), a
## SwingDebugView draws the hurt capsules, the blades' sweeps and where each
## outcome landed over the match (task 7.15).
##
## Reduce flashes and shaking (task 18.11) follows the player's settings at
## match start and whenever they change (apply_reduce_flashes()): the
## camera's shake scaled to REDUCED_SHAKE, no field-of-view kicks, and the
## effects' flashes and the fighters' body flashes at REDUCED_FLASH of their
## brightness, at full size (the owner's choice, Oct 4, 2026).

## A fighter's foot came down on the ground at `at` while its footsteps are
## its clips' (steps_from_clips()).
signal footfall(side: int, at: Vector3)

## The most rules frames the view may be behind a fighter and still give its
## footsteps: a frame's rules steps come before the view draws them.
const FOOTFALL_LAG: int = 4

## The host to follow. The default is the parent (match_host.tscn).
@export var host_path: NodePath = ^".."
## The camera follows the host's view side (the first human side).
@export var camera_path: NodePath = ^"CameraRig"
## Camera shake per event (the demo's amounts). Hits shake on heavies only;
## the demo also shook light hits by light_hit_shake.
@export var heavy_hit_shake: float = 0.45
@export var light_hit_shake: float = 0.0
@export var heavy_block_shake: float = 0.3
@export var light_block_shake: float = 0.12
@export var parry_shake: float = 0.35
@export var counter_shake: float = 0.5
@export var disarm_shake: float = 0.8
@export var ko_shake: float = 0.7
## The camera's kick on contact (plan task 14.12): degrees of field of view
## when a strike lands or is blocked, by the class of the attacker's weapon
## (its weight), half again for a heavy.
@export var contact_kick: Dictionary[StringName, float] = {
	&"fists": 0.6, &"small": 0.8, &"medium": 1.4, &"colossal": 2.4,
}
const HEAVY_KICK: float = 1.5
## Reduce flashes and shaking: the shake's scale, and the flashes' brightness.
const REDUCED_SHAKE: float = 0.15
const REDUCED_FLASH: float = 0.45

## Draws blade sweeps and hurt capsules over the match (SwingDebugView, task
## 7.15). F3 turns it on and off in a debug build, and --swing-debug on the
## command line (npm run play -- --swing-debug) turns it on.
@export var swing_debug: bool = false

var host: MatchHost
var camera: CameraRig
var arena: Node3D
var arena_id: StringName = &""
## The two fighters, kept across matches: each rebuilds its model only when
## its fighter changes.
var fighters: Array[FighterView] = []
## The swing debug view while swing_debug is on, else null.
var swing_debug_view: SwingDebugView
## The combat effects (flashes, rings, particles) on the effect clock.
var effects: CombatEffects
## The recall's power-up aura and burst (task 30b), drawn with the effects.
var recall_aura: RecallAura = RecallAura.new()
## The settings whose Reduce flashes switch the view follows (use_settings();
## the game's by default).
var settings: GameSettings
## How bright the fighters' body flashes are (REDUCED_FLASH with Reduce
## flashes on).
var body_flash_scale: float = 1.0

## owner side -> Node3D: the dropped weapon stand-ins.
var _dropped: Dictionary[int, Node3D] = {}
## The beams over dropped weapons: one mesh, and a material for each side,
## built with the view and recoloured each match (beam_material()). A
## StandardMaterial3D made at the disarm compiled its shader on the main
## thread, some 40 ms at every disarm, since freeing the last beam freed it.
var _beam_mesh: CylinderMesh = _make_beam_mesh()
var _beam_mats: Array[StandardMaterial3D] = [_make_beam_material(), _make_beam_material()]
var _time: float = 0.0


func _ready() -> void:
	for m: StandardMaterial3D in _beam_mats:
		m.get_rid() # builds the beams' shader now, not at the first disarm
	camera = get_node_or_null(camera_path) as CameraRig
	if camera == null:
		camera = CameraRig.new()
		camera.name = "CameraRig"
		add_child(camera)
	if effects == null:
		effects = CombatEffects.new()
		add_child(effects)
		effects.host = host
	if settings == null:
		use_settings(GameServices.settings)
	if host == null and has_node(host_path):
		var h: Node = get_node(host_path)
		if h is MatchHost:
			bind(h as MatchHost)
	if swing_debug or wants_swing_debug(OS.get_cmdline_args()) or wants_swing_debug(OS.get_cmdline_user_args()):
		set_swing_debug(true)


## Follows these settings' Reduce flashes switch: applies it now, and again
## whenever they change (GameSettings.changed). The settings followed before
## no longer reach the view.
func use_settings(p_settings: GameSettings) -> void:
	if settings != null and settings.changed.is_connected(apply_reduce_flashes):
		settings.changed.disconnect(apply_reduce_flashes)
	settings = p_settings
	if settings != null:
		settings.changed.connect(apply_reduce_flashes)
	apply_reduce_flashes()


## Reduce flashes and shaking (18.11) on or off, as the settings say: the
## camera's shake scale and field-of-view kicks, the effects' flash
## brightness and the body flashes'.
func apply_reduce_flashes() -> void:
	var on: bool = settings != null and settings.reduce_flashes
	camera.shake_scale = REDUCED_SHAKE if on else 1.0
	camera.fov_kick_scale = 0.0 if on else 1.0
	effects.flash_scale = REDUCED_FLASH if on else 1.0
	body_flash_scale = REDUCED_FLASH if on else 1.0


func bind(p_host: MatchHost) -> void:
	if host != null:
		host.match_started.disconnect(_on_match_started)
		host.sim_event.disconnect(_on_sim_event)
		host.loadout_changed.disconnect(_on_loadout_changed)
	host = p_host
	if effects != null:
		effects.host = host
	host.match_started.connect(_on_match_started)
	host.sim_event.connect(_on_sim_event)
	host.loadout_changed.connect(_on_loadout_changed)
	if swing_debug_view != null:
		swing_debug_view.bind(host)
	if host.is_started():
		_on_match_started(host.config)


func _process(delta: float) -> void:
	if host == null or not host.is_started():
		return
	_time += delta
	render(delta)


## Places everything for this frame (fighters, dropped weapons, camera).
func render(delta: float) -> void:
	update_fighters(delta)
	_update_dropped()
	_feed_trails()
	_feed_auras()
	effects.update(effects.clock())
	var me: int = host.view_side()
	camera.update_rig(delta, host.display_position(me), host.display_position(1 - me))


## Places the camera where it wants to be at once (match start, screenshots).
func snap_camera() -> void:
	if host == null or not host.is_started():
		return
	update_fighters(0.0)
	_update_dropped()
	_feed_trails()
	effects.update(effects.clock())
	var me: int = host.view_side()
	camera.snap(host.display_position(me), host.display_position(1 - me))


func update_fighters(delta: float) -> void:
	var a: float = host.alpha()
	for i: int in fighters.size():
		fighters[i].update_from(host.fighter(i), host.display_position(i), host.display_yaw(i), a, delta, _time)
		for at: Vector3 in fighters[i].locomotion.footfalls:
			footfall.emit(i, at)


## Lays each held blade, as posed this frame, into its trail, with the
## trail rules' strength and colour (TrailState) on the frame shown.
func _feed_trails() -> void:
	var t: float = effects.clock()
	var a: float = host.alpha()
	for i: int in fighters.size():
		var rules: TrailState = TrailState.of(host.fighter(i), a)
		var blades: Array[PackedVector3Array] = fighters[i].blade_segments()
		var width: float = fighters[i].trail_width()
		for hand: int in mini(2, blades.size()):
			var span: PackedVector3Array = WeaponTrail.span(blades[hand][0], blades[hand][1], width)
			effects.feed_trail(i, hand, t, span[0], span[1], rules.intensity(hand), rules.kind)


## Throws each recalling fighter's power-up aura (RecallAura, task 30b) for
## the rules frames stepped since the last drawn frame.
func _feed_auras() -> void:
	for i: int in fighters.size():
		recall_aura.feed(effects, i, host.fighter(i))


## True when side `side`'s footsteps fall where its clips land its feet
## (reported as footfalls) rather than by the stride count: the view is
## keeping up with it (drawn within FOOTFALL_LAG rules frames; a match
## stepped without being drawn keeps the stride count).
func steps_from_clips(side: int) -> bool:
	if host == null or side >= fighters.size() or fighters[side].locomotion == null:
		return false
	var loco: Locomotion = fighters[side].locomotion
	var f: Fighter = host.fighter(side)
	if f == null or f.world == null or loco.rules_frame() < 0:
		return false
	return f.world.frame - loco.rules_frame() <= FOOTFALL_LAG


# ------------------------------------------------------------------ match start

func _on_match_started(cfg: MatchConfig) -> void:
	_load_arena(cfg.arena_id)
	while fighters.size() < 2:
		var f: FighterView = FighterView.new()
		f.name = "Fighter%d" % fighters.size()
		add_child(f)
		fighters.append(f)
	for i: int in 2:
		var s: MatchSide = cfg.sides[i]
		fighters[i].setup(s.fighter_id, s.palette, s.weapon_id, i)
		_beam_mats[i].albedo_color = Color(LookPalette.side_color(s.palette), 0.35)
	_clear_dropped()
	effects.clear()
	effects.set_preset(GameServices.graphics_preset())
	apply_reduce_flashes()
	if host.attract:
		camera.mode = CameraRig.Mode.MENU
	elif cfg.mode == MatchConfig.WATCH:
		camera.mode = CameraRig.Mode.WATCH
	else:
		camera.mode = CameraRig.Mode.FOLLOW
	camera.reset_round()
	camera.shake = 0.0
	camera.fov_kick = 0.0
	camera.current = true
	snap_camera()


## A side's weapon changed mid-match (the training dummy's): its fighter
## holds the new one.
func _on_loadout_changed(side: int) -> void:
	if side < fighters.size():
		fighters[side].set_weapon(host.fighter(side).weapon.id)


func _load_arena(id: StringName) -> void:
	if arena != null and arena_id == id:
		return
	set_arena(ArenaScenes.instantiate(id), id)


## Puts an arena in place of the current one and hands the camera the arena's
## camera data: the root's `def` (an ArenaDef) camera_max_radius and
## camera_far, or the camera's defaults when it has none (the stand-in).
func set_arena(node: Node3D, id: StringName) -> void:
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = node
	arena.name = "Arena"
	add_child(arena)
	move_child(arena, 0)
	arena_id = id
	var data: Dictionary = arena_camera_data(arena)
	camera.apply_arena(data["max_radius"], data["far"])


## { "max_radius", "far" } from an arena root's `def`, 0 for what it lacks.
static func arena_camera_data(node: Node) -> Dictionary:
	var out: Dictionary = {"max_radius": 0.0, "far": 0.0}
	var def: Variant = node.get("def")
	if def is Object:
		var r: Variant = (def as Object).get("camera_max_radius")
		var f: Variant = (def as Object).get("camera_far")
		if r is float or r is int:
			out["max_radius"] = float(r)
		if f is float or f is int:
			out["far"] = float(f)
	return out


# ------------------------------------------------------------------ swing debug

## Turns the swing debug view (SwingDebugView, task 7.15) on or off: on, it is
## added as a child following the host; off, it is freed.
func set_swing_debug(on: bool) -> void:
	swing_debug = on
	if on and swing_debug_view == null:
		swing_debug_view = SwingDebugView.new()
		add_child(swing_debug_view)
		if host != null:
			swing_debug_view.bind(host)
	elif not on and swing_debug_view != null:
		swing_debug_view.queue_free()
		swing_debug_view = null


## Whether command-line arguments `args` ask for the swing debug view.
static func wants_swing_debug(args: PackedStringArray) -> bool:
	return args.has("--swing-debug")


## F3 turns the swing debug view on and off in a debug build.
func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F3 or not OS.is_debug_build():
		return
	set_swing_debug(not swing_debug)
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ events

## Kicks the camera for a hit or block event `e`, by the weight of the
## attacker's weapon (contact_kick).
func _kick_on_contact(e: Dictionary) -> void:
	if host == null or host.world == null:
		return
	var by: Fighter = host.world.fighters[int(e["attacker"])]
	var kick: float = float(contact_kick.get(by.moveset().cls, 0.0))
	camera.kick_fov(kick * (HEAVY_KICK if e["heavy"] else 1.0))


## Flashes fighter i's body (a hit's tint, a disarm's or a K.O.'s white) at
## this strength, dimmed by body_flash_scale.
func _body_flash(i: int, color: Color, strength: float) -> void:
	fighters[i].flash(color, strength * body_flash_scale, host.world.frame)


func _on_sim_event(e: Dictionary) -> void:
	if EffectTable.has(e["t"]):
		effects.on_event(e, host.world.frame)
	match e["t"]:
		&"hit":
			var heavy: bool = e["heavy"]
			camera.add_shake(heavy_hit_shake if heavy else light_hit_shake)
			_kick_on_contact(e)
			var color: Color = Color(1.0, 0.94, 0.88) if e["sound"] == &"fist" else Color(1.0, 0.38, 0.25)
			_body_flash(int(e["target"]), color, 0.55 if heavy else 0.4)
		&"block":
			camera.add_shake(heavy_block_shake if e["heavy"] else light_block_shake)
			_kick_on_contact(e)
		&"parry":
			camera.add_shake(parry_shake)
			camera.kick_fov(3.0 if e["kind"] == &"parry" else 5.0)
		&"counter":
			camera.add_shake(counter_shake)
			camera.kick_fov(6.0)
		&"disarm":
			camera.add_shake(disarm_shake)
			camera.kick_fov(7.0)
			_body_flash(int(e["victim"]), Color.WHITE, 0.6)
		&"ultStart":
			camera.kick_fov(8.0)
		&"ultWave":
			camera.add_shake(0.5)
		&"ultImpale":
			camera.add_shake(0.6)
		&"ultBurst":
			camera.add_shake(1.2)
			camera.kick_fov(10.0)
		&"ultLightning":
			camera.add_shake(0.3)
		&"recallBurst":
			# the recall's power-up burst (task 30b): the flare and shockwave,
			# and the opponent blasted away when it hits
			RecallAura.burst(effects, e, host.world.frame)
			camera.add_shake(1.0 if e["hit"] else 0.4)
			camera.kick_fov(8.0)
			if e["hit"]:
				_body_flash(int(e["on"]), Color(1.0, 0.9, 0.55), 0.7)
		&"ko":
			camera.add_shake(ko_shake)
			var loser: int = int(e["loser"])
			if loser >= 0:
				_body_flash(loser, Color.WHITE, 0.8)
			if host.config.mode != MatchConfig.VERSUS:
				camera.start_ko_orbit()
		&"roundStart":
			camera.reset_round()
			_clear_dropped()
			effects.clear()
			recall_aura.clear()


# ------------------------------------------------------------------ dropped weapons

func _update_dropped() -> void:
	var seen: Dictionary[int, bool] = {}
	for w: DroppedWeapon in host.world.weapons:
		seen[w.owner] = true
		var node: Node3D = _dropped.get(w.owner, null)
		if node == null:
			node = _make_dropped(w.owner, w.weapon_id)
			_dropped[w.owner] = node
		node.position = Vector3(w.pos.x, w.pos.y, w.pos.z)
		var stick: Node3D = node.get_node("Stick")
		stick.rotation = Vector3(PI / 2.0 + w.tumble, w.yaw, 0.0)
		var beam: Node3D = node.get_node("Beam")
		beam.visible = w.grounded
		beam.position = Vector3(0.0, 1.75 - w.pos.y, 0.0)
	for side_id: int in _dropped.keys():
		if not seen.has(side_id):
			_dropped[side_id].queue_free()
			_dropped.erase(side_id)


func _clear_dropped() -> void:
	for side_id: int in _dropped.keys():
		_dropped[side_id].queue_free()
	_dropped.clear()


func _make_dropped(side_id: int, weapon_id: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Dropped%d" % side_id
	add_child(root)
	var stick: Node3D = Node3D.new()
	stick.name = "Stick"
	root.add_child(stick)
	# the weapon's own model (both of a pair), in the toon look like a held
	# one, centred on the rules' position along its length
	var look: WeaponLook = WeaponLook.load_id(weapon_id) if WeaponLook.IDS.has(weapon_id) else null
	if look != null:
		for k: int in 2 if look.paired else 1:
			var w: Node3D = look.instantiate()
			w.name = "Weapon%d" % k
			stick.add_child(w)
			w.position = Vector3(0.12 * float(k), -_middle(w), 0.0)
	# a pillar of light in the owner's colour over a weapon on the ground
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = _beam_mesh
	beam.material_override = _beam_mats[side_id]
	beam.visible = false
	root.add_child(beam)
	GraphicsApplier.apply_to_tree(GameServices.graphics_preset(), root)
	return root


## The material side `side`'s dropped weapon's beam is drawn with, in its
## colour this match.
func beam_material(side: int) -> StandardMaterial3D:
	return _beam_mats[side]


## The mesh every dropped weapon's beam is drawn with.
func beam_mesh() -> CylinderMesh:
	return _beam_mesh


static func _make_beam_mesh() -> CylinderMesh:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.12
	cyl.height = 3.5
	return cyl


## A beam's see-through, unlit material; _on_match_started() colours it.
static func _make_beam_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Halfway along a weapon model's length (its +Y), from its meshes' bounds.
static func _middle(w: Node3D) -> float:
	var lo: float = INF
	var hi: float = -INF
	for node: Node in w.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var box: AABB = mi.transform * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	return (lo + hi) * 0.5 if lo <= hi else 0.0
