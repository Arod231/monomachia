extends Node
## Bare hands' strike effects (milestone-1 task 95): a disarmed Hunter
## throws --move= (Dragon Kick, f_sh, by default) at a training dummy
## --gap= metres off (1.85 by default; a jump attack is thrown 3 frames into
## a jump in place), drawn --after= frames past the attack's start (its
## active frames show the striking limb's air smear; a few past its hit, the
## dust-and-cloth impact), framed side-on. --hit=1 steps to the hit instead
## and draws --after= frames past it. Render it with
##   npm run shots -- res://tools/shot_scenes/bare_fx.tscn shots/bare_smear.png 10 --move=f_sh --after=20
##   npm run shots -- res://tools/shot_scenes/bare_fx.tscn shots/bare_impact.png 10 --move=f_bh --hit=1 --after=4

@export var move: StringName = &"f_sh"
@export var gap: float = 1.85
@export var after: int = 20
@export var from_hit: bool = false
@export var settle_frames: int = 10

var host: MatchHost
var _ready_flag: bool = false
var _hit: bool = false


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
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	add_child(host)
	host.sim_event.connect(_on_event)
	var view: MatchView = host.get_node("View")
	view.set_process(false)
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"katana", 1)
	dummy.controller = MatchSide.DUMMY
	host.start(MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"hunter", &"katana"), dummy, 3))
	_step(view, Match.INTRO_FRAMES + 5)
	var a: Fighter = host.fighter(0)
	var b: Fighter = host.fighter(1)
	a.armed = false
	var dx: float = b.pos.x - a.pos.x
	var dz: float = b.pos.z - a.pos.z
	var d: float = sqrt(dx * dx + dz * dz)
	a.pos.x = b.pos.x - dx / d * gap
	a.pos.z = b.pos.z - dz / d * gap
	_step(view, 10)
	if (Moves.FISTS.moves[move] as AttackDef).airborne:
		a._start_jump()
		_step(view, 3)
	if not a.start_attack(move):
		push_warning("bare_fx_shot: %s did not start" % move)
	if from_hit:
		var n: int = 0
		while not _hit and n < 120:
			_step(view, 1)
			n += 1
		if not _hit:
			push_warning("bare_fx_shot: %s never hit" % move)
	_step(view, after)
	_frame(view.camera)
	host.get_node("Hud").set("visible", false)
	_ready_flag = true


func _step(view: MatchView, n: int) -> void:
	for i: int in n:
		host.step(1)
		view.render(1.0 / 60.0)


func _on_event(e: Dictionary) -> void:
	if e["t"] == &"hit" and int(e["attacker"]) == 0:
		_hit = true


## Side-on between the two, a little toward the attacker.
func _frame(cam: Camera3D) -> void:
	var me: Vector3 = host.display_position(0)
	var other: Vector3 = host.display_position(1)
	var toward: Vector3 = Vector3(other.x - me.x, 0.0, other.z - me.z).normalized()
	var side: Vector3 = toward.cross(Vector3.UP)
	var mid: Vector3 = (me + other) * 0.5
	var look: Vector3 = mid + Vector3(0.0, 1.1, 0.0)
	var at: Vector3 = mid + side * 3.6 + Vector3(0.0, 1.4, 0.0)
	cam.global_transform = Transform3D(Basis.IDENTITY, at).looking_at(look, Vector3.UP)
	cam.set_process(false)
