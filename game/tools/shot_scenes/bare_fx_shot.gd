extends Node
## Bare hands' strike effects (milestone-1 task 95): a disarmed Hunter
## throws --move= (Dragon Kick, f_sh, by default) at a training dummy
## --gap= metres off (1.85 by default; a jump attack is thrown 3 frames into
## a jump in place), drawn --after= frames past the attack's start (its
## active frames show the striking limb's air smear; a few past its hit, the
## dust-and-cloth impact), framed side-on. --hit=1 steps to the hit instead
## and draws --after= frames past it. A Katana move (k_*, the movement
## attacks of milestone-1 task 77) is thrown armed, its blade's smear and,
## with --touchdown=1, the ground dust where it comes down, --after= frames
## past its touchdown. Render it with
##   npm run shots -- res://tools/shot_scenes/bare_fx.tscn shots/bare_smear.png 10 --move=f_sh --after=20
##   npm run shots -- res://tools/shot_scenes/bare_fx.tscn shots/bare_impact.png 10 --move=f_bh --hit=1 --after=4
##   npm run shots -- res://tools/shot_scenes/bare_fx.tscn shots/whirl.png 10 --move=k_dh --gap=6 --after=36
##   npm run shots -- res://tools/shot_scenes/bare_fx.tscn shots/cleave_dust.png 10 --move=k_sh --gap=8 --touchdown=1 --after=6
## --loop=1 plays on once drawn, throwing the move again from the same place
## each time it ends, at --speed= of the rules' pace (1 by default), for a
## clip:
##   npm run clip -- res://tools/shot_scenes/bare_fx.tscn --seconds 6 --move=k_dh --gap=6 --after=0 --loop=1

@export var move: StringName = &"f_sh"
@export var gap: float = 1.85
@export var after: int = 20
@export var from_hit: bool = false
@export var from_touchdown: bool = false
@export var loop: bool = false
@export var speed: float = 1.0
@export var settle_frames: int = 10

var host: MatchHost
var _ready_flag: bool = false
var _hit: bool = false
var _down: bool = false
var _view: MatchView
var _katana: bool = false
## Rules frames owed to the loop's pace, and the frames since the move ended.
var _owed: float = 0.0
var _rest: int = 0
var _framing: Transform3D


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--move="):
			move = StringName(a.trim_prefix("--move="))
		elif a.begins_with("--gap="):
			gap = float(a.trim_prefix("--gap="))
		elif a.begins_with("--after="):
			after = int(a.trim_prefix("--after="))
		elif a.begins_with("--hit="):
			from_hit = a.trim_prefix("--hit=") != "0"
		elif a.begins_with("--touchdown="):
			from_touchdown = a.trim_prefix("--touchdown=") != "0"
		elif a.begins_with("--loop="):
			loop = a.trim_prefix("--loop=") != "0"
		elif a.begins_with("--speed="):
			speed = float(a.trim_prefix("--speed="))
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	add_child(host)
	host.sim_event.connect(_on_event)
	var view: MatchView = host.get_node("View")
	_view = view
	view.set_process(false)
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"katana", 1)
	dummy.controller = MatchSide.DUMMY
	host.start(MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"hunter", &"katana"), dummy, 3))
	_step(view, Match.INTRO_FRAMES + 5)
	_katana = String(move).begins_with("k_")
	_throw()
	if from_hit:
		var n: int = 0
		while not _hit and n < 120:
			_step(view, 1)
			n += 1
		if not _hit:
			push_warning("bare_fx_shot: %s never hit" % move)
	elif from_touchdown:
		var n: int = 0
		while not _down and n < 120:
			_step(view, 1)
			n += 1
		if not _down:
			push_warning("bare_fx_shot: %s never touched down" % move)
	_step(view, after)
	_frame(view.camera)
	_framing = view.camera.global_transform
	host.get_node("Hud").set("visible", false)
	_ready_flag = true


## Stands fighter 0 `gap` m from the dummy and throws the move (a jump attack
## 3 frames into a jump in place).
func _throw() -> void:
	var a: Fighter = host.fighter(0)
	var b: Fighter = host.fighter(1)
	a.set_state(&"free")
	a.armed = _katana
	var dx: float = b.pos.x - a.pos.x
	var dz: float = b.pos.z - a.pos.z
	var d: float = sqrt(dx * dx + dz * dz)
	a.pos.x = b.pos.x - dx / d * gap
	a.pos.z = b.pos.z - dz / d * gap
	_step(_view, 10)
	if ((Moves.KATANA if _katana else Moves.FISTS).moves[move] as AttackDef).airborne:
		a._start_jump()
		_step(_view, 3)
	if not a.start_attack(move):
		push_warning("bare_fx_shot: %s did not start" % move)


func _process(_delta: float) -> void:
	if not loop or not _ready_flag:
		return
	_owed += speed * 2.0 # two rules frames to each of the clip's 30 a second
	while _owed >= 1.0:
		_owed -= 1.0
		_step(_view, 1)
		_rest = _rest + 1 if host.fighter(0).state != &"attack" else 0
		if _rest > 30:
			_rest = 0
			_throw()
	# each draw puts the view's camera back on its rig: hold the framing
	_view.camera.global_transform = _framing


func _step(view: MatchView, n: int) -> void:
	for i: int in n:
		host.step(1)
		view.render(1.0 / 60.0)


func _on_event(e: Dictionary) -> void:
	if e["t"] == &"hit" and int(e["attacker"]) == 0:
		_hit = true
	elif e["t"] == &"touchdown" and int(e["f"]) == 0:
		_down = true


## Side-on between the two, a little toward the attacker.
func _frame(cam: Camera3D) -> void:
	var me: Vector3 = host.display_position(0)
	var other: Vector3 = host.display_position(1)
	var toward: Vector3 = Vector3(other.x - me.x, 0.0, other.z - me.z).normalized()
	var side: Vector3 = toward.cross(Vector3.UP)
	var mid: Vector3 = (me + other) * 0.5
	var look: Vector3 = mid + Vector3(0.0, 1.1, 0.0)
	# back far enough to keep both in frame however far apart
	var back: float = maxf(3.6, Vector2(other.x - me.x, other.z - me.z).length() * 0.85)
	var at: Vector3 = mid + side * back + Vector3(0.0, 1.4, 0.0)
	cam.global_transform = Transform3D(Basis.IDENTITY, at).looking_at(look, Vector3.UP)
	cam.set_process(false)
