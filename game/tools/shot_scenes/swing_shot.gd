extends Node
## Screenshots of the swing debug view (task 7.15). The player's Rogue cuts
## at a training dummy 1.6 m away with Right Cut on a level slash at 1.2 m
## (the rule tests' slash, from tests/sim/swing_fixtures.gd: no real move has
## a swing until task 7.16, so this process gives Right Cut one), and the shot
## holds the moment the outcome lands, two steps on, in hit-stop for a hit or
## a block. The camera looks down from beside the fighters so the sweeps, the
## dummy's capsule and the contact flash share the frame. Render one with
##   node scripts/godot.mjs shots res://tools/shot_scenes/swing_debug.tscn <out.png> 30 --moment=hit
## --moment= picks hit (the dummy standing), block (the dummy holding block)
## or whiff (the slash at 2.2 m, over the dummy's head).

const SF := preload("res://tests/sim/swing_fixtures.gd")
const SEED: int = 7
const CUT: StringName = &"k_l1"

@export_enum("hit", "block", "whiff") var moment: String = "hit"
## Frames to let the renderer settle before the capture.
@export var settle_frames: int = 10

var host: MatchHost
var _ready_flag: bool = false
var _outcome: StringName = &""


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--moment="):
			moment = a.trim_prefix("--moment=")
	var cut: AttackDef = Moves.KATANA.moves[CUT]
	cut.swing = SF.level_slash(cut, 2.2 if moment == "whiff" else 1.2)
	Moves.KATANA.derive_reach()

	var keys: FakeDeviceState = FakeDeviceState.new()
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"katana", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", &"katana"), dummy, SEED)
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.input = InputDevices.new(keys)
	host.profiles = ControlProfiles.new()
	add_child(host)
	host.start(cfg)
	var view: MatchView = host.get_node("View")
	view.set_swing_debug(true)
	host.sim_event.connect(_on_event)
	if moment == "block":
		(host.brain(1) as TrainingBrain).set_behaviour(&"block")
	host.step(Match.INTRO_FRAMES + 20)
	_place_apart(1.6)

	keys.press_key(KEY_J)
	host.step(2)
	keys.release_key(KEY_J)
	var n: int = 0
	while _outcome == &"" and n < 60:
		host.step(1)
		n += 1
	if _outcome != StringName(moment):
		push_warning("swing_shot: wanted a %s, got %s" % [moment, _outcome])
	host.step(2)

	view.snap_camera()
	_frame_beside(view.camera)
	view.swing_debug_view.redraw()
	view.swing_debug_view.set_process(false)
	var hud: MatchHud = host.get_node("Hud")
	hud.snap_bars()
	view.set_process(false)
	hud.set_process(false)
	_ready_flag = true


## Moves the fighters to `metres` apart about their midpoint, on the line
## between them, standing still, facing each other, and steps twice so the
## view shows it.
func _place_apart(metres: float) -> void:
	var a: Fighter = host.fighter(0)
	var b: Fighter = host.fighter(1)
	var mid: Vector3 = Vector3(a.pos.x + b.pos.x, 0.0, a.pos.z + b.pos.z) * 0.5
	var along: Vector3 = Vector3(b.pos.x - a.pos.x, 0.0, b.pos.z - a.pos.z).normalized()
	for pair: Array in [[a, -0.5], [b, 0.5]]:
		var f: Fighter = pair[0]
		var at: Vector3 = mid + along * metres * float(pair[1])
		f.pos = V3.make(at.x, 0.0, at.z)
		f.vel = V3.make()
	a.yaw = SimMath.yaw_to(a.pos, b.pos)
	b.yaw = SimMath.yaw_to(b.pos, a.pos)
	host.step(2)


## Puts the camera 2.8 m out to the attacker's left of the fighters'
## midpoint and 2.6 m up, looking down at the cut's height there.
func _frame_beside(camera: Camera3D) -> void:
	var a: Vector3 = host.display_position(0)
	var b: Vector3 = host.display_position(1)
	var mid: Vector3 = (a + b) * 0.5
	var along: Vector3 = (b - a).normalized()
	var left: Vector3 = Vector3.UP.cross(along)
	camera.global_position = mid + left * 2.8 + Vector3(0.0, 2.6, 0.0)
	camera.look_at(mid + Vector3(0.0, 1.1, 0.0))


func _on_event(e: Dictionary) -> void:
	if _outcome == &"" and [&"hit", &"block", &"parry", &"whiff"].has(e["t"]):
		_outcome = e["t"]
