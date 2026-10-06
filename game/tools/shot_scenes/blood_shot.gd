extends Node
## The Blood setting's shots (milestone-1 task 38): a computer duel of two
## Hunters with the Katana, stepped to the --hits= blade hit (4 by default)
## the indigo Hunter (side 0, where red reads best) takes
## and --after= steps past it (12: the burst falling, the hit's body flash
## gone), framed close on the fighter just cut, side-on, between the two, at the Blood level
## --blood= (on, reduced or off). Render it with
##   npm run shots -- res://tools/shot_scenes/blood.tscn shots/blood_on.png 30 --blood=on

const SEED: int = 11

## The Blood level (GameSettings.BLOOD_LEVELS).
@export var level: StringName = GameSettings.BLOOD_ON
@export var hits: int = 4
@export var after: int = 12
@export var settle_frames: int = 10

var host: MatchHost
var _ready_flag: bool = false
var _hits: int = 0
var _last_target: int = 1


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--blood="):
			level = StringName(a.trim_prefix("--blood="))
		elif a.begins_with("--hits="):
			hits = int(a.trim_prefix("--hits="))
		elif a.begins_with("--after="):
			after = int(a.trim_prefix("--after="))
	# the run's own settings (shot runs use the defaults, never saved)
	GameServices.settings.blood = level
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	add_child(host)
	host.sim_event.connect(_on_event)
	host.start(MatchConfig.make(
		MatchConfig.WATCH,
		MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"),
		SEED,
	))
	var n: int = 0
	while _hits < hits and n < 60000:
		host.step(1)
		n += 1
	if _hits < hits:
		push_warning("blood_shot: %d blade hits in %d steps" % [_hits, n])
	host.step(after)
	var view: MatchView = host.get_node("View")
	view.snap_camera()
	_frame(view.camera, _last_target)
	view.set_process(false)
	host.get_node("Hud").set("visible", false)
	_ready_flag = true


func _on_event(e: Dictionary) -> void:
	if e["t"] == &"hit" and e.get("sound", &"blade") == &"blade" and int(e["target"]) == 0:
		_hits += 1
		_last_target = 0


## Close on fighter i from its side, a little toward the attacker.
func _frame(cam: Camera3D, i: int) -> void:
	var me: Vector3 = host.display_position(i)
	var other: Vector3 = host.display_position(1 - i)
	var toward: Vector3 = Vector3(other.x - me.x, 0.0, other.z - me.z).normalized()
	var side: Vector3 = toward.cross(Vector3.UP)
	var look: Vector3 = me + Vector3(0.0, 1.05, 0.0)
	var at: Vector3 = me + toward * 0.9 + side * 2.3 + Vector3(0.0, 1.45, 0.0)
	cam.global_transform = Transform3D(Basis.IDENTITY, at).looking_at(look, Vector3.UP)
	cam.set_process(false)
