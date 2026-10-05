extends Node
## The reactions and movement review's video (authored-animation task 31):
## computer against computer in the match's own view, the effects and the
## HUD, so the reactions, the rolls, the knockdowns and the locomotion show
## as they come in play, then the recall's burst played on purpose (it comes
## up about once in fifteen rounds). Each part is captioned. It is a scene,
## run as the main scene (so the autoloads load) under Movie Maker, which
## writes the video:
##
##   godot --path game --resolution 1600x900 --fixed-fps 60 --write-movie <out.avi> \
##     res://tools/review_video.tscn -- [--seconds=75] [--seed=3]
##
## node scripts/review_video.mjs runs it into shots/task31/review_video.avi.

const SEED: int = 3

var _host: MatchHost
var _caption: Label


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var seconds: float = 75.0
	var seed: int = SEED
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
		elif a.begins_with("--seed="):
			seed = int(a.trim_prefix("--seed="))
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24.0, 840.0)
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 6)
	layer.add_child(_caption)
	var parts: Array = [
		["Computer against computer (Hard): the Rogue's Katana against the Hunter's Greatsword", MatchSide.computer(&"rogue", &"katana", 0, &"hard"), MatchSide.computer(&"hunter", &"greatsword", 1, &"hard")],
		["Computer against computer (Hard): the Hunter's Daggers against the Rogue's Katana", MatchSide.computer(&"hunter", &"daggers", 0, &"hard"), MatchSide.computer(&"rogue", &"katana", 1, &"hard")],
	]
	for part: Array in parts:
		await _start(MatchConfig.make(MatchConfig.WATCH, part[1], part[2], seed))
		_caption.text = part[0]
		await _play(int(seconds * float(SimConst.FPS)), func() -> bool: return false)
	for weapon: StringName in [&"katana", &"greatsword"]:
		await _recall(weapon, 2.2, "The recall's power-up burst (task 30b), the %s in reach: the opponent blasted away and down" % weapon)
	await _recall(&"katana", 3.4, "The recall's power-up burst out of reach: the flare alone")
	get_tree().quit(0)


func _start(cfg: MatchConfig) -> void:
	if _host != null:
		_host.queue_free()
		await get_tree().process_frame
	_host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	_host.auto_run = false
	_host.use_services = false
	add_child(_host)
	_host.start(cfg)


## Steps and draws `frames` rules frames, one per rendered frame, or until
## `done` says.
func _play(frames: int, done: Callable) -> void:
	var view: MatchView = _host.get_node("View")
	for i: int in frames:
		if done.call():
			break
		_host.step(1)
		view.render(1.0 / float(SimConst.FPS))
		await get_tree().process_frame


## The disarmed Rogue recalling `weapon` against the idle Hunter `gap` m off.
func _recall(weapon: StringName, gap: float, caption: String) -> void:
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
	dummy.controller = MatchSide.DUMMY
	await _start(MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", weapon), dummy, SEED))
	_caption.text = caption
	_host.step(Match.INTRO_FRAMES + 20)
	var a: Fighter = _host.fighter(0)
	var b: Fighter = _host.fighter(1)
	var mid: Vector3 = Vector3(a.pos.x + b.pos.x, 0.0, a.pos.z + b.pos.z) * 0.5
	var along: Vector3 = Vector3(b.pos.x - a.pos.x, 0.0, b.pos.z - a.pos.z).normalized()
	a.pos = V3.make(mid.x - along.x * gap * 0.5, 0.0, mid.z - along.z * gap * 0.5)
	b.pos = V3.make(mid.x + along.x * gap * 0.5, 0.0, mid.z + along.z * gap * 0.5)
	await _play(30, func() -> bool: return false)
	a.armed = false
	a.set_state(&"recall", SimConst.RECALL_FRAMES)
	await _play(150, func() -> bool: return false)
