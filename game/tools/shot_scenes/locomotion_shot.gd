extends Node
## The legs on a script of moves (milestone-1 tasks 56 and 57): the Hunter
## with the Katana walks each move of a script against an idle opponent 6 m
## away on the studio stage, filmed from three-quarters in front, low so the
## feet show, each move captioned. Each move starts afresh from a standing
## guard. Needs the clip libraries (`node scripts/godot.mjs clips`).
##
##   npm run clip -- locomotion --seconds 14 [--script=guard] [--fighter=hunter]
##
## Scripts (SCRIPTS):
## - guard: blocking, a shuffle forward, a shuffle back, a strafe left and
##   right and a diagonal; then disarmed, bare hands' walk the same ways (task
##   56).

const PreviewScene := preload("res://fighters/preview/preview.gd")

## Each script's moves: [caption, stick x, stick y, buttons, armed, seconds].
const SCRIPTS: Dictionary[String, Array] = {
	"guard": [
		["Blocking: shuffle forward", 0.0, 1.0, [Btn.BLOCK], true, 1.6],
		["Blocking: shuffle back", 0.0, -1.0, [Btn.BLOCK], true, 1.6],
		["Blocking: strafe left", -1.0, 0.0, [Btn.BLOCK], true, 1.6],
		["Blocking: strafe right", 1.0, 0.0, [Btn.BLOCK], true, 1.6],
		["Blocking: forward-left", -0.7071, 0.7071, [Btn.BLOCK], true, 1.6],
		["Disarmed: walk forward", 0.0, 0.5, [], false, 1.4],
		["Disarmed: walk back", 0.0, -0.5, [], false, 1.4],
		["Disarmed: walk left", -0.5, 0.0, [], false, 1.4],
		["Disarmed: walk right", 0.5, 0.0, [], false, 1.4],
	],
}
## The fighters' distance apart as each move starts (m).
const GAP: float = 6.0
## How long each move stands in guard before it sets off (s).
const STAND: float = 0.3

var script_name: String = "guard"
var fighter_id: StringName = &"hunter"

var _world: World
var _views: Array[FighterView] = []
var _camera: Camera3D
var _caption: Label
var _move: int = -1
var _left: float = 0.0
var _time: float = 0.0
var _carry: float = 0.0
var _ready_flag: bool = false


func shot_frames() -> int:
	return 2


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--script="):
			script_name = a.trim_prefix("--script=")
		elif a.begins_with("--fighter="):
			fighter_id = StringName(a.trim_prefix("--fighter="))
	if not SCRIPTS.has(script_name):
		push_error("locomotion_shot: unknown script %s" % script_name)
		return
	if not ClipLibraries.available():
		push_error("locomotion_shot: no clip libraries; run `node scripts/godot.mjs clips` (needs the packs, see .assets-src-path)")
		return
	PreviewScene.build_studio_stage(self)
	for side: int in 2:
		var v: FighterView = FighterView.new()
		add_child(v)
		v.setup(fighter_id if side == 0 else &"hunter", side, &"katana", side)
		_views.append(v)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(32, 24)
	_caption.add_theme_font_size_override("font_size", 34)
	layer.add_child(_caption)
	GraphicsApplier.apply(GameServices.graphics_preset(), self, get_viewport())
	_next_move()
	_show(0.0)
	_ready_flag = true


func _process(delta: float) -> void:
	if _world == null:
		return
	_left -= delta
	if _left <= 0.0:
		_next_move()
	_carry += delta * float(SimConst.FPS)
	while _carry >= 1.0:
		_carry -= 1.0
		_step()
	_time += delta
	_show(delta)


## Starts the script's next move (round again after the last) from a
## standing guard GAP apart.
func _next_move() -> void:
	var moves: Array = SCRIPTS[script_name]
	_move = (_move + 1) % moves.size()
	var m: Array = moves[_move]
	_world = World.new(FighterConfig.make(Moves.KATANA, []), FighterConfig.make(Moves.KATANA, []), 7)
	var a: Fighter = _world.fighters[0]
	var b: Fighter = _world.fighters[1]
	a.pos = V3.make(0.0, 0.0, -GAP / 2.0)
	b.pos = V3.make(0.0, 0.0, GAP / 2.0)
	a.yaw = 0.0
	b.yaw = PI
	a.set_state(&"free")
	b.set_state(&"free")
	a.armed = bool(m[4])
	_left = STAND + float(m[5])
	_caption.text = String(m[0])


func _step() -> void:
	var m: Array = SCRIPTS[script_name][_move]
	var mask: int = 0
	for b: Variant in m[3]:
		mask |= 1 << int(b)
	var standing: bool = _left > float(m[5])
	var inp: RawInput = RawInput.make(0.0, 0.0, mask) if standing else RawInput.make(float(m[1]), float(m[2]), mask)
	_world.step([inp, RawInput.empty()])
	_world.drain_events()


## Shows both fighters and frames fighter 0 from three-quarters in front, at
## knee height, so its strafes cross the frame.
func _show(delta: float) -> void:
	for i: int in 2:
		var f: Fighter = _world.fighters[i]
		_views[i].update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, 1.0, delta, _time)
	var a: Fighter = _world.fighters[0]
	var look: Vector3 = Vector3(a.pos.x, 0.75, a.pos.z)
	_camera.global_transform = Transform3D(Basis.IDENTITY, look + Vector3(2.4, 0.3, 1.9)).looking_at(look, Vector3.UP)
