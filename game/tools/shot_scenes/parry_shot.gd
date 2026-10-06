extends Node
## The parry push-in's shots (milestone-1 task 39): a computer duel of two
## Hunters with the Katana, on the first Hunter's follow camera, stepped to
## the --parries= parry (1 by default; --kind= picks parry, flash or
## redirect, any by default) and drawn --after= frames past it (6: pushed in
## and held in the hit-stop; 40: eased back out). --push=0 draws the same
## frame without the push-in, to set beside it. Render it with
##   npm run shots -- res://tools/shot_scenes/parry.tscn shots/parry_in.png 10 --after=6

const SEED: int = 11

@export var parries: int = 1
@export var kind: StringName = &""
@export var after: int = 6
@export var push: bool = true
@export var settle_frames: int = 10

var host: MatchHost
var _ready_flag: bool = false
var _parries: int = 0


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--parries="):
			parries = int(a.trim_prefix("--parries="))
		elif a.begins_with("--kind="):
			kind = StringName(a.trim_prefix("--kind="))
		elif a.begins_with("--after="):
			after = int(a.trim_prefix("--after="))
		elif a.begins_with("--push="):
			push = a.trim_prefix("--push=") != "0"
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	add_child(host)
	host.sim_event.connect(_on_event)
	var view: MatchView = host.get_node("View")
	view.set_process(false)
	if not push:
		view.parry_push_in = 0.0
		view.flash_push_in = 0.0
	host.start(MatchConfig.make(
		MatchConfig.DUEL,
		MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"),
		SEED,
	))
	view.snap_camera()
	var n: int = 0
	while _parries < parries and n < 60000:
		host.step(1)
		view.render(1.0 / 60.0)
		n += 1
	if _parries < parries:
		push_warning("parry_shot: %d parries in %d steps" % [_parries, n])
	for i: int in after:
		host.step(1)
		view.render(1.0 / 60.0)
	host.get_node("Hud").set("visible", false)
	_ready_flag = true


func _on_event(e: Dictionary) -> void:
	if e["t"] == &"parry" and (kind == &"" or e["kind"] == kind):
		_parries += 1
