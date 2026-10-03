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
## the parry ring) stay flat. The listener follows the view's camera. The
## arena's room is the Arena bus's reverb, which the Combat and Foley buses
## feed (see default_bus_layout.tres): Godot 4.7's Area3D reverb would take a
## 3D cue off its own bus, so there is no reverb area.
##
## Footsteps: [method foot_down] plays the footstep cue where a foot comes
## down. A fighter walking in its guard (the Katana's) steps where its guard
## shuffle lands its feet, which the view reports ([signal MatchView.footfall]);
## otherwise a FootstepCadence turns each rules step's movement into a
## footfall every stride, at the fighter's feet. The running clips' own foot
## contacts can take the cadence's place later.
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

var host: MatchHost
var view: MatchView
var player: SoundPlayer
var listener: AudioListener3D
var camera: Camera3D
var footsteps := FootstepCadence.new()
var ambience: FadedLoop


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


## Puts the listener where the camera is. The view moves the camera earlier in
## the frame (it comes first in match_host.tscn).
func follow_camera() -> void:
	if camera != null:
		listener.global_transform = camera.global_transform


## A foot comes down at [param at]: plays a footstep there.
func foot_down(at: Vector3) -> void:
	player.play_cue(&"footstep", at)


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
	footsteps.reset()
	if host.attract:
		ambience.stop()
	else:
		start_ambience(ambience_cue(ArenaScenes.def(config.arena_id)))


func _on_sim_event(e: Dictionary) -> void:
	if host.attract:
		return
	player.play_event(e, event_position)


func _on_stepped(_step: int) -> void:
	if host.attract:
		return
	for foot: Dictionary in footsteps.update(host.world.fighters, host.world.frame):
		# a fighter in its guard steps where its shuffle's feet land instead
		if view != null and view.shuffles(foot["fighter"]):
			continue
		foot_down(foot["at"])


func _on_footfall(_side: int, at: Vector3) -> void:
	if host == null or host.attract:
		return
	foot_down(at)


func _on_pause_changed(paused: bool) -> void:
	player.set_held(paused)


func _on_stopped() -> void:
	player.stop_all()
	ambience.stop()


static func _vector(d: Dictionary) -> Vector3:
	return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
