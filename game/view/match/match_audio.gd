class_name MatchAudio
extends Node3D
## The match's sound: plays every rules event's cues (see [SoundBank]) through
## its [SoundPlayer] in played matches (Duel, Training, Watch, Versus) and on
## the results screen. The duel behind the menus stays silent, as in the demo.
## A pause holds the sound and its delayed cues (the round gong waits for the
## resume); a new match, the duel behind the menus and quitting each stop
## everything. It listens to a MatchHost and never changes the rules.
##
## Cues marked spatial play in 3D where their event happened
## ([method event_position]): a contact point, where lightning strikes, else
## the chest of the fighter the event names. The calls (the gong, the taiko,
## the parry ring) stay flat. The listener follows the view's camera, except
## in Versus, where it stands between the two fighters facing side-on, player
## 1's fighter on its left (versus_listener(), the owner's choice, Oct 4,
## 2026): the split screen's halves don't listen, so this is the one listener
## and both players hear the fight alike. The
## arena's room is the Arena bus's reverb, which the Combat and Foley buses
## feed (see default_bus_layout.tres): Godot 4.7's Area3D reverb would take a
## 3D cue off its own bus, so there is no reverb area.
##
## Footsteps: [method foot_down] plays the footstep cue where a foot comes
## down, with the fighter's own cloth and gear (SoundBank.FOLEY: the
## Hunter's coat and fittings, milestone-1 task 36). A drawn fighter steps where its walking and running clips land its
## feet (authored-animation task 29), which the view reports
## ([signal MatchView.footfall]); a match stepped without being drawn falls
## back on a FootstepCadence, which turns each rules step's movement into a
## footfall every stride, at the fighter's feet.
##
## The deflect pairs' sounds (milestone-1 task 136): on a steel-on-steel
## parry ([method SoundBank.sounds_deflect_pair]) each half the clips play
## sounds its own cues ([constant SoundBank.DEFLECT_SOUNDS]) on its frames,
## counted in the world's frames from the parry, so the parry's hit-stop
## holds them as it holds the clips. The pair is the one the clips play
## ([method ClipDirector.pick_pair], a move without its own borrowing the
## nearest light's), picked with or without the clip libraries; a half sounds
## while its fighter plays it (the parried attacker recoiling or stunned by the
## parry, not disarmed; the parrier in its recovery or standing on), and a
## half cut short drops its later cues.
##
## A move's own cues on its frames (milestone-1 task 77: Whirl Cut's double
## whoosh round its spin, [constant SoundBank.MOVE_SOUNDS]): each plays at its
## fighter's chest when the attack reaches its frame, once per attack, so a
## hit-stop, which holds the attack's frame, holds it too.
##
## The arena's ambience: a played match fades in the loop its arena's data
## names ([method ambience_cue]) on a [FadedLoop]. It plays on through pauses,
## the results and a rematch in the same arena, and fades out on a quit or
## under the duel behind the menus.

## The fields that name the fighter an event happened to, in the order they
## are looked for (see SimEvents).
const FIGHTER_KEYS: Array[String] = ["f", "attacker", "parrier", "victim", "loser", "owner", "by"]
## The ambience when an arena names none (the stand-in).
const DEFAULT_AMBIENCE := &"ambience_shrine"

## The host to follow. The default is the parent (match_host.tscn).
@export var host_path: NodePath = ^".."
## The camera the listener follows: the view's.
@export var camera_path: NodePath = ^"../View/CameraRig"
## The view whose guard shuffles report footfalls.
@export var view_path: NodePath = ^"../View"
## Where on a fighter its sounds come from: the chest, above its feet (m).
@export var chest_height: float = 1.25
## In Versus, how far the listener stands back from the line between the
## fighters (m), still as far from each: right on the line, each fighter's
## sounds would come from one speaker alone.
@export var versus_back: float = 2.5

var host: MatchHost
var view: MatchView
var player: SoundPlayer
var listener: AudioListener3D
var camera: Camera3D
var footsteps := FootstepCadence.new()
var ambience: FadedLoop
## Parries this step whose deflect pairs' sounds are picked once the step is
## done (task 136), when the fighters stand in the states the parry left.
var _parries: Array[Dictionary] = []
## The deflect pairs' cues waiting on their frames: {cue, frame (the world
## frame it starts on), side, half, place, at (the contact)}.
var _pair_cues: Array[Dictionary] = []
## Per side, the attack whose own cues are playing and the last of its
## frames they were played up to (task 77).
var _move_atk: Array[AttackState] = [null, null]
var _move_frame: Array[int] = [0, 0]


func _ready() -> void:
	player = SoundPlayer.new()
	player.name = "Sounds"
	add_child(player)
	# Load the one-shot cues now, so the first hit doesn't wait on a file.
	var cues: Array[StringName] = []
	for cue_name: StringName in SoundBank.CUES:
		if not SoundBank.CUES[cue_name].get("loop", false):
			cues.append(cue_name)
	player.preload_cues(cues)
	ambience = FadedLoop.new()
	ambience.name = "Ambience"
	add_child(ambience)
	listener = AudioListener3D.new()
	listener.name = "Listener"
	add_child(listener)
	camera = get_node_or_null(camera_path) as Camera3D
	view = get_node_or_null(view_path) as MatchView
	if view != null:
		view.footfall.connect(_on_footfall)
	follow_camera()
	listener.make_current()
	if host == null and has_node(host_path):
		var h: Node = get_node(host_path)
		if h is MatchHost:
			bind(h as MatchHost)


func _process(_delta: float) -> void:
	follow_camera()


func bind(p_host: MatchHost) -> void:
	if host != null:
		host.match_started.disconnect(_on_match_started)
		host.sim_event.disconnect(_on_sim_event)
		host.pause_changed.disconnect(_on_pause_changed)
		host.stopped.disconnect(_on_stopped)
		host.stepped.disconnect(_on_stepped)
	host = p_host
	host.match_started.connect(_on_match_started)
	host.sim_event.connect(_on_sim_event)
	host.pause_changed.connect(_on_pause_changed)
	host.stopped.connect(_on_stopped)
	host.stepped.connect(_on_stepped)


## Puts the listener where the camera is, or in Versus between the fighters
## (versus_listener()). The view moves the camera earlier in
## the frame (it comes first in match_host.tscn).
func follow_camera() -> void:
	if host != null and host.is_started() and host.config.mode == MatchConfig.VERSUS:
		listener.global_transform = versus_listener(host.display_position(0), host.display_position(1), chest_height, versus_back)
	elif camera != null:
		listener.global_transform = camera.global_transform


## A foot of [param side]'s fighter (-1 for nobody's) comes down at
## [param at]: plays a footstep there, and the fighter's own cloth and gear.
func foot_down(at: Vector3, side: int = -1) -> void:
	var sides := cast()
	var fighter: StringName = sides[side] if side >= 0 and side < sides.size() else &""
	for cue: StringName in SoundBank.footfall_cues(fighter):
		player.play_cue(cue, at)


## The fighter on each side of the match playing, by side (their ids, for
## their own cloth, gear and voice); empty before a match.
func cast() -> Array:
	if host == null or host.config == null:
		return []
	return host.config.sides.map(func(s: MatchSide) -> StringName: return s.fighter_id)


## The ambience an arena's data names: its `ambience_id` (read by name, as
## MatchView reads the camera data), else [constant DEFAULT_AMBIENCE].
static func ambience_cue(arena_def: Object) -> StringName:
	if arena_def != null:
		var cue: Variant = arena_def.get("ambience_id")
		if (cue is StringName or cue is String) and not String(cue).is_empty():
			return StringName(cue)
	return DEFAULT_AMBIENCE


## Fades in [param cue]'s loop on its bus at its level, unless it is playing
## already. A cue the bank lacks is an error, and the loop playing carries on.
func start_ambience(cue: StringName) -> void:
	if not SoundBank.CUES.has(cue):
		push_error("MatchAudio: no ambience %s in the sound bank" % cue)
		return
	var stream := player.stream_for(SoundBank.paths_for(cue)[0])
	if stream == null or (ambience.is_playing() and ambience.player.stream == stream):
		return
	ambience.bus = SoundBank.CUES[cue]["bus"]
	ambience.volume_db = SoundBank.CUES[cue]["volume_db"]
	ambience.play(stream)


## Where a rules event happened, for its spatial cues: its contact point
## (pos), where lightning strikes (to), else the chest of the fighter it
## names; null when it names nowhere.
func event_position(e: Dictionary) -> Variant:
	if e.has("pos"):
		return _vector(e["pos"])
	if e.has("to"):
		return _vector(e["to"])
	if host == null or not host.is_started():
		return null
	for key: String in FIGHTER_KEYS:
		if e.has(key):
			var i := int(e[key])
			if i == 0 or i == 1:
				var f: Fighter = host.fighter(i)
				return Vector3(f.pos.x, f.pos.y + chest_height, f.pos.z)
	return null


func _on_match_started(config: MatchConfig) -> void:
	player.stop_all()
	stop_pair_sounds()
	_move_atk = [null, null]
	footsteps.reset()
	if host.attract:
		ambience.stop()
	else:
		start_ambience(ambience_cue(ArenaScenes.def(config.arena_id)))


func _on_sim_event(e: Dictionary) -> void:
	if host.attract:
		return
	player.play_event(e, event_position, cast())
	if SoundBank.sounds_deflect_pair(e):
		_parries.append(e)


func _on_stepped(_step: int) -> void:
	if host.attract:
		return
	update_pair_sounds()
	update_move_sounds()
	for foot: Dictionary in footsteps.update(host.world.fighters, host.world.frame):
		# a drawn fighter steps where its clips' feet land instead
		if view != null and view.steps_from_clips(foot["fighter"]):
			continue
		foot_down(foot["at"], int(foot["fighter"]))


func _on_footfall(side: int, at: Vector3) -> void:
	if host == null or host.attract:
		return
	foot_down(at, side)


func _on_pause_changed(paused: bool) -> void:
	player.set_held(paused)


func _on_stopped() -> void:
	player.stop_all()
	stop_pair_sounds()
	ambience.stop()


## Picks the deflect pairs' sounds of the parries just made and starts each
## waiting cue whose frame the world has reached (task 136); done after every
## step.
func update_pair_sounds() -> void:
	if host == null or not host.is_started():
		return
	for e: Dictionary in _parries:
		_pick_pair_sounds(e)
	_parries.clear()
	var waiting: Array[Dictionary] = []
	for c: Dictionary in _pair_cues:
		var f: Fighter = host.fighter(int(c["side"]))
		if not plays_half(f, c["half"]):
			continue
		if host.world.frame >= int(c["frame"]):
			player.play_cue(c["cue"], _pair_place(c, f))
		else:
			waiting.append(c)
	_pair_cues = waiting


## Plays each fighter's attack's own cues whose frames it has reached since
## the last step (task 77); done after every step.
func update_move_sounds() -> void:
	if host == null or not host.is_started():
		return
	for side: int in 2:
		var f: Fighter = host.fighter(side)
		var a: AttackState = f.atk if f.state == &"attack" else null
		if a == null:
			_move_atk[side] = null
			continue
		if a != _move_atk[side]:
			_move_atk[side] = a
			_move_frame[side] = 0
		for cue: Dictionary in SoundBank.move_cues(a.def.id):
			var at: int = int(cue["frame"])
			if at > _move_frame[side] and at <= a.frame:
				player.play_cue(cue["cue"], Vector3(f.pos.x, f.pos.y + chest_height, f.pos.z))
		_move_frame[side] = maxi(_move_frame[side], a.frame)


## Drops every deflect pair sound not yet played.
func stop_pair_sounds() -> void:
	_parries.clear()
	_pair_cues.clear()


## Whether fighter [param f] is still playing its half [param half] of a
## deflect pair, as ClipDirector plays them: the recoil while parried and
## not guarding again, the deflect through the recovery and on while it
## stands.
static func plays_half(f: Fighter, half: StringName) -> bool:
	if half == &"recoil":
		return ClipDirector.PARRIED_STATES.has(f.state) and f.stun_cause == &"" and not f.blocking
	return f.state == &"parryAnim" or f.state == &"free"


func _pick_pair_sounds(e: Dictionary) -> void:
	var attacker := int(e.get("attacker", -1))
	var parrier := int(e.get("parrier", -1))
	if attacker < 0 or attacker > 1 or parrier < 0 or parrier > 1:
		return
	var direction: StringName = ClipDirector.pick_pair(host.fighter(attacker)).get(&"direction", &"")
	if direction == &"":
		return
	var at: Variant = event_position(e)
	for half: Array in [[parrier, &"deflect"], [attacker, &"recoil"]]:
		var side: int = half[0]
		if half[1] == &"deflect" and host.fighter(side).state != &"parryAnim":
			continue
		if not plays_half(host.fighter(side), half[1]):
			continue
		for cue: Dictionary in SoundBank.deflect_pair_cues(direction, half[1]):
			_pair_cues.append({"cue": cue["cue"], "frame": host.world.frame + int(cue["frame"]), "side": side,
				"half": half[1], "place": cue["place"], "at": at})


## Where a deflect pair's cue sounds: where the blades met, or its fighter's
## chest or feet as it stands now.
func _pair_place(c: Dictionary, f: Fighter) -> Variant:
	match c["place"]:
		&"contact":
			return c["at"]
		&"feet":
			return Vector3(f.pos.x, f.pos.y, f.pos.z)
		_:
			return Vector3(f.pos.x, f.pos.y + chest_height, f.pos.z)


static func _vector(d: Dictionary) -> Vector3:
	return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))


## The Versus listener for fighters at a and b: at chest height on the
## perpendicular through their midpoint, `back` metres from it, facing it,
## with a on its left and b on its right.
static func versus_listener(a: Vector3, b: Vector3, height: float, back: float = 0.0) -> Transform3D:
	var along: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	if along.length() < 0.001:
		along = Vector3.RIGHT
	var right: Vector3 = along.normalized()
	var behind: Vector3 = right.cross(Vector3.UP)
	var mid: Vector3 = Vector3((a.x + b.x) * 0.5, height, (a.z + b.z) * 0.5)
	return Transform3D(Basis(right, Vector3.UP, behind), mid + behind * back)
