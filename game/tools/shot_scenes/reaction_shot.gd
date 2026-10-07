extends Node
## The physical reaction layer's clip (milestone-1 task 70): a computer duel
## of two Hunters with the Katana, played to --lead= steps (30 by default)
## before the --hits= hit (3; blocks count too with --blocks) lands, then left to play on, so a
## clip shows the blows land and the bodies give under them. --reaction=off
## switches the layer off for comparison, --slow plays at half speed.
## Record it with
##   npm run clip -- reaction --seconds 6
##   npm run clip -- reaction --seconds 6 --out shots/reaction_off.mp4 --reaction=off

const SEED: int = 11

@export var hits: int = 3
@export var lead: int = 30
@export var reaction_on: bool = true
@export var slow: bool = false
## Count blocks as well as hits (--blocks).
@export var blocks: bool = false

var host: MatchHost
var _view: MatchView
var _ready_flag: bool = false


func shot_frames() -> int:
	return 2


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--hits="):
			hits = int(a.trim_prefix("--hits="))
		elif a.begins_with("--lead="):
			lead = int(a.trim_prefix("--lead="))
		elif a == "--reaction=off":
			reaction_on = false
		elif a == "--blocks":
			blocks = true
		elif a == "--slow":
			slow = true
	# where the blow lands: a first run counts the steps to it
	var at: int = _steps_to_blow()
	host = _start()
	host.step(maxi(0, at - lead))
	var view: MatchView = host.get_node("View")
	_view = view
	# framed close and side-on after the view moves its camera
	process_priority = 1000
	for f: FighterView in view.fighters:
		f.model.rig.reaction.active = reaction_on
	view.snap_camera()
	host.get_node("Hud").set("visible", false)
	if slow:
		Engine.time_scale = 0.5
	host.auto_run = true
	_frame()
	_ready_flag = true


func _process(_delta: float) -> void:
	if _view != null:
		_frame()


## Side-on to the pair, close, at chest height.
func _frame() -> void:
	var a: Vector3 = host.display_position(0)
	var b: Vector3 = host.display_position(1)
	var mid: Vector3 = (a + b) * 0.5
	var along: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var side: Vector3 = along.cross(Vector3.UP)
	var look: Vector3 = Vector3(mid.x, 1.2, mid.z)
	_view.camera.global_transform = Transform3D(Basis.IDENTITY, look + side * 3.2 + Vector3(0.0, 0.25, 0.0)).looking_at(look, Vector3.UP)


func _start() -> MatchHost:
	var h: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	h.auto_run = false
	add_child(h)
	h.start(MatchConfig.make(
		MatchConfig.WATCH,
		MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"),
		SEED,
	))
	return h


func _steps_to_blow() -> int:
	var h: MatchHost = _start()
	var seen: Array[int] = [0]
	h.sim_event.connect(func(e: Dictionary) -> void:
		if e["t"] == &"hit" or (blocks and e["t"] == &"block"):
			seen[0] += 1)
	var n: int = 0
	while seen[0] < hits and n < 60000:
		h.step(1)
		n += 1
	remove_child(h)
	h.free()
	return n
