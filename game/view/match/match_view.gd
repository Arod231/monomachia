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
## StickPose inside FighterView; the combat effects (task 18) join
## _on_sim_event(), where the camera's shake and field-of-view kicks are
## already wired.
##
## A fighter walking in its guard puts its feet down where its guard shuffle
## lands them: the view reports each as a footfall, for the match's sound to
## play its footstep there (MatchAudio).
##
## With swing_debug on (F3 in a debug build, or --swing-debug), a
## SwingDebugView draws the hurt capsules, the blades' sweeps and where each
## outcome landed over the match (task 7.15).

## A fighter's foot came down on the ground at `at` while its footsteps are
## its guard shuffle's (shuffles()).
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

## Draws blade sweeps and hurt capsules over the match (SwingDebugView, task
## 7.15). F3 turns it on and off in a debug build, and --swing-debug on the
## command line (npm run godot:run -- --swing-debug) turns it on.
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

## owner side -> Node3D: the dropped weapon stand-ins.
var _dropped: Dictionary[int, Node3D] = {}
## Contact flashes: { "node", "mat", "born" (a world frame), "life" (frames),
## "size", "color" }. A stand-in for task 18's sparks; timed on the world's
## frame, which stands still during hit-stop and pause, so they hold through
## both.
var _flashes: Array[Dictionary] = []
var _time: float = 0.0
var _side_palette: Array[int] = [0, 1]


func _ready() -> void:
	camera = get_node_or_null(camera_path) as CameraRig
	if camera == null:
		camera = CameraRig.new()
		camera.name = "CameraRig"
		add_child(camera)
	if host == null and has_node(host_path):
		var h: Node = get_node(host_path)
		if h is MatchHost:
			bind(h as MatchHost)
	if swing_debug or wants_swing_debug(OS.get_cmdline_args()) or wants_swing_debug(OS.get_cmdline_user_args()):
		set_swing_debug(true)


func bind(p_host: MatchHost) -> void:
	if host != null:
		host.match_started.disconnect(_on_match_started)
		host.sim_event.disconnect(_on_sim_event)
	host = p_host
	host.match_started.connect(_on_match_started)
	host.sim_event.connect(_on_sim_event)
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
	_update_flashes()
	var me: int = host.view_side()
	camera.update_rig(delta, host.display_position(me), host.display_position(1 - me))


## Places the camera where it wants to be at once (match start, screenshots).
func snap_camera() -> void:
	if host == null or not host.is_started():
		return
	update_fighters(0.0)
	_update_dropped()
	_update_flashes()
	var me: int = host.view_side()
	camera.snap(host.display_position(me), host.display_position(1 - me))


func update_fighters(delta: float) -> void:
	var a: float = host.alpha()
	for i: int in fighters.size():
		fighters[i].update_from(host.fighter(i), host.display_position(i), host.display_yaw(i), a, delta, _time)
		for at: Vector3 in fighters[i].locomotion.footfalls:
			footfall.emit(i, at)


## True when side `side`'s footsteps fall where its guard shuffle lands its
## feet (reported as footfalls) rather than by the stride count: its legs are
## the guard's, and the view is keeping up with it (drawn within
## FOOTFALL_LAG rules frames; a match stepped without being drawn keeps the
## stride count).
func shuffles(side: int) -> bool:
	if host == null or side >= fighters.size() or fighters[side].locomotion == null:
		return false
	var loco: Locomotion = fighters[side].locomotion
	var f: Fighter = host.fighter(side)
	if f == null or f.world == null or not loco.shuffles():
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
		_side_palette[i] = s.palette
	_clear_dropped()
	_clear_flashes()
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


func _on_sim_event(e: Dictionary) -> void:
	match e["t"]:
		&"hit":
			var heavy: bool = e["heavy"]
			camera.add_shake(heavy_hit_shake if heavy else light_hit_shake)
			_kick_on_contact(e)
			var color: Color = Color(1.0, 0.94, 0.88) if e["sound"] == &"fist" else Color(1.0, 0.38, 0.25)
			fighters[int(e["target"])].flash(color, 0.55 if heavy else 0.4, host.world.frame)
			_spawn_flash(e["pos"], Color(1.0, 0.55, 0.3), 0.7 if heavy else 0.45, 10)
		&"block":
			camera.add_shake(heavy_block_shake if e["heavy"] else light_block_shake)
			_kick_on_contact(e)
			_spawn_flash(e["pos"], Color(1.0, 0.88, 0.6), 0.6 if e["heavy"] else 0.45, 10)
		&"parry":
			camera.add_shake(parry_shake)
			camera.kick_fov(3.0 if e["kind"] == &"parry" else 5.0)
			var parry_color: Color = Color(1.0, 0.95, 0.75)
			if e["kind"] == &"flash":
				parry_color = Color(0.6, 0.85, 1.0)
			elif e["kind"] == &"redirect":
				parry_color = Color(0.48, 1.0, 0.84)
			_spawn_flash(e["pos"], parry_color, 1.0, 18)
		&"counter":
			camera.add_shake(counter_shake)
			camera.kick_fov(6.0)
			_spawn_flash(e["pos"], Color(0.6, 0.85, 1.0), 0.9, 16)
		&"disarm":
			camera.add_shake(disarm_shake)
			camera.kick_fov(7.0)
			fighters[int(e["victim"])].flash(Color.WHITE, 0.6, host.world.frame)
			_spawn_flash(e["pos"], Color.WHITE, 1.3, 20)
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
		&"ko":
			camera.add_shake(ko_shake)
			var loser: int = int(e["loser"])
			if loser >= 0:
				fighters[loser].flash(Color.WHITE, 0.8, host.world.frame)
			if host.config.mode != MatchConfig.VERSUS:
				camera.start_ko_orbit()
		&"roundStart":
			camera.reset_round()
			_clear_dropped()
			_clear_flashes()


# ------------------------------------------------------------------ contact flashes

## A glow at a contact point (an event's "pos") that grows and fades over
## life world frames (frozen through hit-stop).
func _spawn_flash(at: Dictionary, color: Color, size: float, life: int) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Flash"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(float(at["x"]), float(at["y"]), float(at["z"]))
	add_child(mi)
	_flashes.append({"node": mi, "mat": mat, "born": host.world.frame, "life": life, "size": size, "color": color})
	_update_flashes()


func _update_flashes() -> void:
	var keep: Array[Dictionary] = []
	for fl: Dictionary in _flashes:
		var t: float = float(host.world.frame - int(fl["born"])) / float(fl["life"])
		var node: MeshInstance3D = fl["node"]
		if t >= 1.0:
			node.queue_free()
			continue
		var s: float = float(fl["size"]) * (0.55 + 0.75 * t)
		node.scale = Vector3(s, s, s)
		var c: Color = fl["color"]
		c.a = 0.9 * (1.0 - t)
		(fl["mat"] as StandardMaterial3D).albedo_color = c
		keep.append(fl)
	_flashes = keep


func _clear_flashes() -> void:
	for fl: Dictionary in _flashes:
		(fl["node"] as Node).queue_free()
	_flashes.clear()


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
	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.albedo_color = LookPalette.side_color(_side_palette[side_id])
	beam_mat.albedo_color.a = 0.35
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.name = "Beam"
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.12
	cyl.height = 3.5
	beam.mesh = cyl
	beam.material_override = beam_mat
	beam.visible = false
	root.add_child(beam)
	GraphicsApplier.apply_to_tree(GameServices.graphics_preset(), root)
	return root


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
