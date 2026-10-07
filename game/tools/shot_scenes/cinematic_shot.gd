extends Node
## The shot director's clip (milestone-1 task 97): a computer duel of two
## Hunters with the Katana, played to --lead= steps (45 by default) before
## the shot director first chooses the --shot= shot (match_ko by default:
## the KO that wins the match), then left to play on, so a clip shows the
## gameplay camera hand over to the shot and back. Record it with
##   npm run clip -- cinematic --seconds 8
##   npm run clip -- cinematic --seconds 6 --out shots/cinematic_finisher.mp4 --shot=finisher_katana

const SEED: int = 11

@export var shot: StringName = &"match_ko"
@export var lead: int = 45

var host: MatchHost
var _ready_flag: bool = false


func shot_frames() -> int:
	return 2


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = StringName(a.trim_prefix("--shot="))
		elif a.begins_with("--lead="):
			lead = int(a.trim_prefix("--lead="))
	var at: int = _steps_to_shot()
	host = _start()
	host.step(maxi(0, at - lead))
	(host.get_node("View") as MatchView).snap_camera()
	host.auto_run = true
	_ready_flag = true


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


## How many steps until the director first chooses the shot (the whole
## match when it never does: the clip then shows its end).
func _steps_to_shot() -> int:
	var h: MatchHost = _start()
	var found: Array[bool] = [false]
	h.sim_event.connect(func(e: Dictionary) -> void:
		if ShotDirector.choose(e, h.world).get("shot", &"") == shot:
			found[0] = true)
	var n: int = 0
	while not found[0] and n < 60000 and h.sim_match.phase != &"matchEnd":
		h.step(1)
		n += 1
	if not found[0]:
		push_warning("cinematic_shot: no %s in %d steps" % [shot, n])
	remove_child(h)
	h.free()
	return n
