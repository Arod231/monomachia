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
## the effect clock every frame and cleared at round start. A parry pushes
## the camera in instead of kicking it (milestone-1 task 39: parry_push_in,
## flash_push_in for a Flash or a redirect), held through the hit-stop, with
## the graphics preset's depth of field.
##
## A hit or a block pushes its target's physical reaction layer (milestone-1
## task 70, reaction_of()): from where it landed, by its weight and the
## attacker's weapon, the guard alone on a block; picture only.
##
## The shot director (milestone-1 task 97, `shots`) takes every event: a
## connecting ultimate, a finisher or the match-winning KO hands every camera
## (both halves in Versus) to its cinematic shot for as long as it plays, and
## the recall pushes them in instead.
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
## camera's shake scaled to REDUCED_SHAKE, no field-of-view kicks or
## push-ins, and the
## effects' flashes and the fighters' body flashes at REDUCED_FLASH of their
## brightness, at full size (the owner's choice, Oct 4, 2026).
##
## Versus draws a split screen (task 23.6, SplitView): player 1 on the left
## and player 2 on the right, each half with its own CameraRig following its
## player toward the other (`cameras`; `camera` stays player 1's). Shake and
## field-of-view kicks reach both, the KO orbit stays off, both halves take
## the graphics preset, and each half's camera decides the shrine's
## underside for itself. The other modes keep the one camera on the screen.

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
## The parry's push-in (milestone-1 task 39): the share of the way to the
## camera's look point, on a parry and on a Flash or a redirect.
@export var parry_push_in: float = 0.15
@export var flash_push_in: float = 0.25
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
## The share of a reaction's push the arms take while the pushed fighter's
## own swing is in its active frames, so a traded swing still reads along
## its path (milestone-1 task 70).
const ACTIVE_SWING_ARMS: float = 0.3
## How deep a stuck weapon's point sits in the ground (milestone-1 task 86).
const STUCK_EMBED: float = 0.12

## Draws blade sweeps and hurt capsules over the match (SwingDebugView, task
## 7.15). F3 turns it on and off in a debug build, and --swing-debug on the
## command line (npm run play -- --swing-debug) turns it on.
@export var swing_debug: bool = false

var host: MatchHost
## Player 1's camera (the screen's outside Versus).
var camera: CameraRig
## Every camera drawing the match: [camera], or in Versus [player 1's,
## player 2's], one in each half of the split.
var cameras: Array[CameraRig] = []
## Versus's split screen (task 23.6), or null in the other modes.
var split: SplitView
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
## Blood (milestone-1 task 38): bursts, stains on bodies and blades, the
## floor's splatter, at the settings' Blood level.
var blood: BloodEffects
## The shot director (milestone-1 task 97): chooses and plays the cinematic
## shots.
var shots: ShotDirector = ShotDirector.new()
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
	cameras = [camera]
	if effects == null:
		effects = CombatEffects.new()
		add_child(effects)
		effects.host = host
	if blood == null:
		blood = BloodEffects.new()
		add_child(blood)
		blood.host = host
	if settings == null:
		use_settings(GameServices.settings)
	if host == null and has_node(host_path):
		var h: Node = get_node(host_path)
		if h is MatchHost:
			bind(h as MatchHost)
	if swing_debug or wants_swing_debug(OS.get_cmdline_args()) or wants_swing_debug(OS.get_cmdline_user_args()):
		set_swing_debug(true)


## Follows these settings' Reduce flashes switch and Blood level: applies
## them now, and again whenever they change (GameSettings.changed). The
## settings followed before no longer reach the view.
func use_settings(p_settings: GameSettings) -> void:
	if settings != null and settings.changed.is_connected(_apply_settings):
		settings.changed.disconnect(_apply_settings)
	settings = p_settings
	if settings != null:
		settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	apply_reduce_flashes()
	apply_blood()


## The Blood setting (milestone-1 task 38): how much blood the match draws,
## at once (turning it off hides what is there).
func apply_blood() -> void:
	if blood != null:
		blood.setting = settings.blood if settings != null else GameSettings.BLOOD_ON
		blood.update(effects.clock() if effects != null else 0.0)


## Reduce flashes and shaking (18.11) on or off, as the settings say: the
## camera's shake scale and field-of-view kicks, the effects' flash and spark
## brightness, the contact lights' (halved, milestone-1 task 37) and the body
## flashes'.
func apply_reduce_flashes() -> void:
	var on: bool = settings != null and settings.reduce_flashes
	for cam: CameraRig in cameras:
		cam.shake_scale = REDUCED_SHAKE if on else 1.0
		cam.fov_kick_scale = 0.0 if on else 1.0
		cam.push_in_scale = 0.0 if on else 1.0
	effects.flash_scale = REDUCED_FLASH if on else 1.0
	effects.light_scale = CombatEffects.REDUCED_LIGHT if on else 1.0
	body_flash_scale = REDUCED_FLASH if on else 1.0


func bind(p_host: MatchHost) -> void:
	if host != null:
		host.match_started.disconnect(_on_match_started)
		host.sim_event.disconnect(_on_sim_event)
		host.loadout_changed.disconnect(_on_loadout_changed)
	host = p_host
	if effects != null:
		effects.host = host
	if blood != null:
		blood.host = host
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
	_feed_smears()
	_feed_auras()
	effects.update(effects.clock())
	blood.update(effects.clock())
	for cam: CameraRig in cameras:
		cam.frozen = host.world.hitstop > 0
	_show_shot(delta)
	if split != null:
		for i: int in 2:
			cameras[i].update_rig(delta, host.display_position(i), host.display_position(1 - i))
		_cull_below_deck()
		return
	var me: int = host.view_side()
	camera.update_rig(delta, host.display_position(me), host.display_position(1 - me))


## Places the camera where it wants to be at once (match start, screenshots).
func snap_camera() -> void:
	if host == null or not host.is_started():
		return
	update_fighters(0.0)
	_update_dropped()
	_feed_smears()
	effects.update(effects.clock())
	blood.update(effects.clock())
	if split != null:
		for i: int in 2:
			cameras[i].snap(host.display_position(i), host.display_position(1 - i))
		_cull_below_deck()
		return
	var me: int = host.view_side()
	camera.snap(host.display_position(me), host.display_position(1 - me))


func update_fighters(delta: float) -> void:
	var a: float = host.alpha()
	for i: int in fighters.size():
		fighters[i].update_from(host.fighter(i), host.display_position(i), host.display_yaw(i), a, delta, _time)
		for at: Vector3 in fighters[i].locomotion.footfalls:
			footfall.emit(i, at)


## Lays each held blade, as posed this frame, into its air smear, with the
## smear rules' strength and tint (TrailState) on the frame shown.
func _feed_smears() -> void:
	var t: float = effects.clock()
	var a: float = host.alpha()
	for i: int in fighters.size():
		var rules: TrailState = TrailState.of(host.fighter(i), a)
		var blades: Array[PackedVector3Array] = fighters[i].blade_segments()
		for hand: int in mini(2, blades.size()):
			var span: PackedVector3Array = AirSmear.span(blades[hand][0], blades[hand][1])
			effects.feed_smear(i, hand, t, span[0], span[1], rules.intensity(hand), rules.kind)


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
	blood.new_match(fighters)
	_use_split(cfg.mode == MatchConfig.VERSUS and not host.attract)
	apply_reduce_flashes()
	var camera_mode: CameraRig.Mode = CameraRig.Mode.FOLLOW
	if host.attract:
		camera_mode = CameraRig.Mode.MENU
	elif cfg.mode == MatchConfig.WATCH:
		camera_mode = CameraRig.Mode.WATCH
	shots.stop()
	for cam: CameraRig in cameras:
		cam.mode = camera_mode
		cam.reset_round()
		cam.shake = 0.0
		cam.fov_kick = 0.0
		cam.end_push_in()
		cam.end_shot()
		cam.dof_allowed = GameServices.graphics_preset().push_in_dof
		cam.current = true
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
	for cam: CameraRig in cameras:
		cam.apply_arena(data["max_radius"], data["far"])


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


# ------------------------------------------------------------------ split screen

## Versus's split screen on or off (task 23.6). On: a SplitView of two
## halves drawing this world, player 1's camera (`camera`) moved into the
## left half and a copy of it made for player 2 in the right, so the root
## viewport has no camera and draws no 3D under them. A rematch keeps the
## split as it is. Off: the camera back on the view, drawing the screen, and
## the split freed with player 2's camera.
func _use_split(on: bool) -> void:
	if on == (split != null):
		return
	if on:
		split = SplitView.new()
		add_child(split)
		split.share_world(get_viewport().find_world_3d())
		split.apply_preset(GameServices.graphics_preset())
		var second: CameraRig = camera.duplicate() as CameraRig
		second.name = "CameraRig2"
		camera.reparent(split.viewports[0], false)
		split.viewports[1].add_child(second)
		second.apply_arena(camera.arena_max_radius, camera.arena_far)
		cameras = [camera, second]
	else:
		camera.reparent(self, false)
		remove_child(split)
		split.queue_free()
		split = null
		cameras = [camera]
	camera.current = true


## Each half's camera decides whether it sees the rock under the shrine's
## rim (MoonlitShrine.cull_below_deck(), by the BELOW_DECK_LAYER bit of its
## own cull mask) after it has moved: the arena decides only for its own
## viewport's camera, and in Versus the root viewport has none.
func _cull_below_deck() -> void:
	if arena == null or not arena.has_method(&"cull_below_deck"):
		return
	for cam: CameraRig in cameras:
		arena.call(&"cull_below_deck", cam)


## Shakes every camera (both halves in Versus).
func _shake(amount: float) -> void:
	for cam: CameraRig in cameras:
		cam.add_shake(amount)


## Pushes every camera in toward its look point (both halves in Versus).
func _push_in(amount: float) -> void:
	for cam: CameraRig in cameras:
		cam.push_in(amount)


## Kicks every camera's field of view (both halves in Versus).
func _kick(amount: float) -> void:
	for cam: CameraRig in cameras:
		cam.kick_fov(amount)


## Moves the cinematic shot on by `delta` seconds of real time and hands
## every camera its view, or back to the gameplay framing once it is done.
func _show_shot(delta: float) -> void:
	shots.advance(delta, host.world.frame)
	var v: Dictionary = shots.view([host.display_position(0), host.display_position(1)])
	for cam: CameraRig in cameras:
		if v.is_empty():
			cam.end_shot()
		else:
			cam.show_shot(v)


# ------------------------------------------------------------------ events

## Kicks the camera for a hit or block event `e`, by the weight of the
## attacker's weapon (contact_kick).
func _kick_on_contact(e: Dictionary) -> void:
	if host == null or host.world == null:
		return
	var by: Fighter = host.world.fighters[int(e["attacker"])]
	var kick: float = float(contact_kick.get(by.moveset().cls, 0.0))
	_kick(kick * (HEAVY_KICK if e["heavy"] else 1.0))


## Flashes fighter i's body (a hit's tint, a disarm's or a K.O.'s white) at
## this strength, dimmed by body_flash_scale.
func _body_flash(i: int, color: Color, strength: float) -> void:
	fighters[i].flash(color, strength * body_flash_scale, host.world.frame)


## The push a rules event gives a fighter's physical reaction layer
## (milestone-1 task 70): {side, contact, from, strength, parts, arms} for a
## hit or a block with a contact point, {} for anything else. A hit pushes
## every part, a block the guard (PhysicalReactionLayer.BLOCK), each by its
## weight and the attacker's weapon class; driven from the attacker's place
## at the contact's height; the arms take ACTIVE_SWING_ARMS of it while the
## target's own swing is active.
static func reaction_of(e: Dictionary, W: World) -> Dictionary:
	var t: StringName = e["t"]
	if (t != &"hit" and t != &"block") or not e.has("pos") or W == null:
		return {}
	var block: bool = t == &"block"
	var by: Fighter = W.fighters[int(e["attacker"])]
	var on: Fighter = W.fighters[int(e["target"])]
	var p: Dictionary = e["pos"]
	var contact: Vector3 = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
	return {
		"side": on.id,
		"contact": contact,
		"from": Vector3(by.pos.x, contact.y, by.pos.z),
		"strength": PhysicalReactionLayer.strength(bool(e["heavy"]), by.moveset().cls, block),
		"parts": PhysicalReactionLayer.BLOCK if block else PhysicalReactionLayer.HIT,
		"arms": ACTIVE_SWING_ARMS if on.attack_phase() == &"active" else 1.0,
	}


func _on_sim_event(e: Dictionary) -> void:
	if EffectTable.has(e["t"]):
		effects.on_event(e, host.world.frame)
	blood.on_event(e, effects.clock())
	var asked: Dictionary = shots.on_event(e, host.world)
	if asked.has("push_in"):
		_push_in(float(asked["push_in"]))
	var push: Dictionary = reaction_of(e, host.world)
	if not push.is_empty():
		fighters[int(push["side"])].react(push["contact"], push["from"], push["strength"], push["parts"], push["arms"], float(host.world.frame))
	match e["t"]:
		&"hit":
			var heavy: bool = e["heavy"]
			_shake(heavy_hit_shake if heavy else light_hit_shake)
			_kick_on_contact(e)
			var color: Color = Color(1.0, 0.94, 0.88) if e["sound"] == &"fist" else Color(1.0, 0.38, 0.25)
			_body_flash(int(e["target"]), color, 0.55 if heavy else 0.4)
		&"block":
			_shake(heavy_block_shake if e["heavy"] else light_block_shake)
			_kick_on_contact(e)
		&"parry":
			_shake(parry_shake)
			_push_in(parry_push_in if e["kind"] == &"parry" else flash_push_in)
		&"counter":
			_shake(counter_shake)
			_kick(6.0)
		&"disarm":
			_shake(disarm_shake)
			_kick(7.0)
			_body_flash(int(e["victim"]), Color.WHITE, 0.6)
		&"ultStart":
			_kick(8.0)
		&"ultWave":
			_shake(0.5)
		&"ultImpale":
			_shake(0.6)
		&"ultBurst":
			_shake(1.2)
			_kick(10.0)
		&"ultLightning":
			_shake(0.3)
		&"recallBurst":
			# the recall's power-up burst (task 30b): the flare and shockwave,
			# and the opponent blasted away when it hits
			RecallAura.burst(effects, e, host.world.frame)
			_shake(1.0 if e["hit"] else 0.4)
			_kick(8.0)
			if e["hit"]:
				_body_flash(int(e["on"]), Color(1.0, 0.9, 0.55), 0.7)
		&"ko":
			_shake(ko_shake)
			var loser: int = int(e["loser"])
			if loser >= 0:
				_body_flash(loser, Color.WHITE, 0.8)
			if host.config.mode != MatchConfig.VERSUS:
				camera.start_ko_orbit()
		&"roundStart":
			for cam: CameraRig in cameras:
				cam.reset_round()
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
		stick.rotation = Vector3(w.pitch, w.yaw, 0.0)
		# centred on the rules' position as it leaves the hands, its point
		# STUCK_EMBED into the ground there once it sticks (milestone-1 task 86)
		var flown: float = 1.0 if w.grounded else float(w.flown) / float(w.flight_frames)
		for model: Node in stick.get_children():
			var m: Node3D = model
			m.position.y = lerpf(-float(m.get_meta(&"middle")), STUCK_EMBED - float(m.get_meta(&"tip")), flown)
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
	# one, its middle and point along its length kept for _update_dropped()
	var look: WeaponLook = WeaponLook.load_id(weapon_id) if WeaponLook.IDS.has(weapon_id) else null
	if look != null:
		for k: int in 2 if look.paired else 1:
			var w: Node3D = look.instantiate()
			w.name = "Weapon%d" % k
			stick.add_child(w)
			var span: Vector2 = _span(w)
			w.set_meta(&"middle", (span.x + span.y) * 0.5)
			w.set_meta(&"tip", span.y)
			w.position = Vector3(0.12 * float(k), -float(w.get_meta(&"middle")), 0.0)
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


## A weapon model's extent along its length (its +Y, toward the point), from
## its meshes' bounds: (pommel end, point).
static func _span(w: Node3D) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for node: Node in w.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var box: AABB = mi.transform * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	return Vector2(lo, hi) if lo <= hi else Vector2.ZERO
