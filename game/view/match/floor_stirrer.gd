class_name FloorStirrer
extends RefCounted
## Builds each drawn frame's FloorStir from the fighters (milestone-1 task
## 137), for the arena's floor to react to (the Shrine's fallen petals are
## pushed about by the fighters' movement and weapon attacks):
## - each fighter on the floor pushes round its feet at the speed it's shown
##   moving: a walk or a run at WALK_*, a step at STEP_*, a roll or a backstep
##   wider and harder at ROLL_*; standing still pushes nothing, nor does a
##   fighter in the air (higher than AIRBORNE), nor the jump back to the spawn
##   at a new round (further than TELEPORT in a frame);
## - each held blade sweeps the floor where it passes lower than
##   SWEEP_HEIGHT, faster than SWEEP_SPEED;
## - a landing (LAND_BURST), a knocked-down fighter hitting the ground
##   (DOWN_BURST) and a stomp (STOMP_BURST) burst once; so do the rules'
##   blows (on_event(): a hit, a heavy block, a KO, the recall's and the
##   ultimates' bursts, a movement attack coming down, milestone-1 task 77),
##   at their target's feet or where they go off.
## Bursts are (radius, strength). It reads the view and the rules' states and
## events and writes nothing back: picture only.

const WALK_RADIUS: float = 0.4
const WALK_STRENGTH: float = 1.0
const STEP_RADIUS: float = 0.6
const STEP_STRENGTH: float = 1.5
const ROLL_RADIUS: float = 0.9
const ROLL_STRENGTH: float = 2.2
## Higher than this (m) over the floor, a fighter's feet are off it.
const AIRBORNE: float = 0.15
## Further than this (m) in one frame is a jump to the spawn, not a move.
const TELEPORT: float = 1.0
const SWEEP_HEIGHT: float = 0.7
const SWEEP_SPEED: float = 2.0
const LAND_BURST := Vector2(0.9, 1.8)
const DOWN_BURST := Vector2(1.3, 2.4)
const STOMP_BURST := Vector2(1.6, 3.0)
const TOUCHDOWN_BURST := Vector2(1.6, 3.0)
const HIT_BURST := Vector2(0.5, 0.8)
const HEAVY_HIT_BURST := Vector2(0.8, 1.5)
const HEAVY_BLOCK_BURST := Vector2(0.6, 1.0)
const KO_BURST := Vector2(1.4, 2.5)
const RECALL_BURST := Vector2(2.5, 3.5)
const ULT_BURST := Vector2(3.0, 4.0)
const ULT_WAVE_BURST := Vector2(1.5, 3.0)

## Per side, from the last frame: where it stood, its state and knockdown
## phase, and its blades.
var _last_at: Array[Vector3] = []
var _last_state: Array[StringName] = []
var _last_phase: Array[StringName] = []
var _last_blades: Array[Array] = []
## The bursts from the rules' events since the last frame.
var _waiting: Array[FloorStir.Push] = []


## This frame's stir, delta seconds after the last: sides holds one entry per
## fighter, {"at": where it's shown (Vector3), "state": its rules state,
## "phase": its knockdown phase (Fighter.knockdown_phase()), "blades": its
## blades as posed (FighterView.blade_segments())}.
func frame(delta: float, sides: Array[Dictionary]) -> FloorStir:
	var out := FloorStir.new()
	for b: FloorStir.Push in _waiting:
		out.bursts.append(b)
	_waiting.clear()
	while _last_at.size() < sides.size():
		_last_at.append(Vector3.INF)
		_last_state.append(&"")
		_last_phase.append(&"")
		_last_blades.append([])
	for i: int in sides.size():
		var side: Dictionary = sides[i]
		var at: Vector3 = side["at"]
		var state: StringName = side.get("state", &"free")
		var phase: StringName = side.get("phase", &"")
		var blades: Array = side.get("blades", [])
		var moved: Vector3 = at - _last_at[i] if _last_at[i] != Vector3.INF else Vector3.ZERO
		var velocity: Vector3 = Vector3.ZERO
		if delta > 0.0 and Vector2(moved.x, moved.z).length() <= TELEPORT:
			velocity = moved / delta
		var floor_at := Vector3(at.x, 0.0, at.z)
		if at.y <= AIRBORNE:
			var feet: Vector2 = _feet(state)
			out.push(floor_at, velocity, feet.x, feet.y)
		if state != _last_state[i]:
			if state == &"land":
				out.burst(floor_at, LAND_BURST.x, LAND_BURST.y)
			elif state == &"stomp":
				out.burst(floor_at, STOMP_BURST.x, STOMP_BURST.y)
		if state == &"knockdown" and phase == &"ground" and _last_phase[i] == &"fall":
			out.burst(floor_at, DOWN_BURST.x, DOWN_BURST.y)
		if delta > 0.0 and state == &"attack":
			for hand: int in mini(blades.size(), _last_blades[i].size()):
				_sweep(out, _last_blades[i][hand], blades[hand], delta)
		_last_at[i] = at
		_last_state[i] = state
		_last_phase[i] = phase
		_last_blades[i] = blades.duplicate()
	return out


## Takes a rules event: a blow that reaches the floor bursts it on the next
## frame. at_of(side) is where side's fighter is shown.
func on_event(e: Dictionary, at_of: Callable) -> void:
	match e.get("t", &""):
		&"hit":
			_burst_at(at_of.call(int(e["target"])), HEAVY_HIT_BURST if e.get("heavy", false) else HIT_BURST)
		&"block":
			if e.get("heavy", false):
				_burst_at(at_of.call(int(e["target"])), HEAVY_BLOCK_BURST)
		&"ko":
			if int(e.get("loser", -1)) >= 0:
				_burst_at(at_of.call(int(e["loser"])), KO_BURST)
		&"recallBurst":
			_burst_at(_vector(e["pos"]), RECALL_BURST)
		&"ultBurst":
			if e.has("pos"):
				_burst_at(_vector(e["pos"]), ULT_BURST)
		&"ultWave":
			if e.has("pos"):
				_burst_at(_vector(e["pos"]), ULT_WAVE_BURST)
		&"touchdown":
			if e.has("pos"):
				_burst_at(_vector(e["pos"]), TOUCHDOWN_BURST)


## Forgets the last frame and the waiting bursts (a new match).
func reset() -> void:
	_last_at.clear()
	_last_state.clear()
	_last_phase.clear()
	_last_blades.clear()
	_waiting.clear()


## (radius, strength) of a fighter's feet in state.
static func _feet(state: StringName) -> Vector2:
	match state:
		&"dodge", &"backstep":
			return Vector2(ROLL_RADIUS, ROLL_STRENGTH)
		&"step":
			return Vector2(STEP_RADIUS, STEP_STRENGTH)
	return Vector2(WALK_RADIUS, WALK_STRENGTH)


## A blade that moved from was to now (each [base, tip]), if it passed low and
## fast enough.
static func _sweep(out: FloorStir, was: PackedVector3Array, now: PackedVector3Array, delta: float) -> void:
	if was.size() < 2 or now.size() < 2:
		return
	if minf(now[0].y, now[1].y) > SWEEP_HEIGHT:
		return
	var va: Vector3 = (now[0] - was[0]) / delta
	var vb: Vector3 = (now[1] - was[1]) / delta
	if maxf(va.length(), vb.length()) < SWEEP_SPEED:
		return
	out.sweep(now[0], now[1], va, vb)


func _burst_at(at: Vector3, burst: Vector2) -> void:
	_waiting.append(FloorStir._push(Vector3(at.x, 0.0, at.z), Vector3.ZERO, burst.x, burst.y))


static func _vector(d: Variant) -> Vector3:
	if d is Vector3:
		return d
	return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
