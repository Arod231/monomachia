class_name FootstepCadence
extends RefCounted
## When each fighter's feet come down: a footfall every stride of ground the
## fighter covers on foot. Plain logic with no nodes; MatchAudio feeds it
## every rules step and plays the footstep cue at each footfall.
##
## Only a fighter moving freely on the ground counts (the free state, which
## covers walking, running, sprinting and the guard walk), or walking in the
## Iai stance (Fighter.in_stance). Nothing counts in the air, in a dodge, a
## tap step (it has its own scuff), an attack's lunge,
## while knocked back or down, in hit-stop (the world's frame stands still),
## or across a jump in position (a new round places the fighters).
##
## The stride follows the pace, read from the distance covered each step: a
## guard walk below [member walk_below], a sprint from [member sprint_from],
## else a run. The footfalls stand in for the real foot contacts: a fighter
## walking in its guard already steps where its guard shuffle lands its feet
## (MatchAudio skips its footfalls then), and when the running clips have
## contacts they can call MatchAudio.foot_down() instead.

## Metres between footfalls at each pace.
var walk_stride: float = 0.8
var run_stride: float = 1.3
var sprint_stride: float = 2.0
## Speeds (m/s) that separate the paces, around the gait clips' own speeds
## (milestone-1 task 55, Gaits): the walks run 1.7-2.2 m/s and the guard walk
## the run slowed by blocking (at most 2.8, forward), the runs 3.9-4.7 and
## the sprint 7.0.
var walk_below: float = 3.2
var sprint_from: float = 5.0
## The most a fighter can cover in one step on foot (m); a longer move is a
## jump in position, not a stride.
var max_step: float = 0.5

## Per fighter: where it stood at the last step (null before the first), and
## the distance covered since its last footfall.
var _last: Array = [null, null]
var _travel: Array[float] = [0.0, 0.0]
var _frame: int = -1


## Forgets every fighter's position and the distance it has covered.
func reset() -> void:
	_last = [null, null]
	_travel = [0.0, 0.0]
	_frame = -1


## Feeds one rules step: the fighters and the world's frame after it. Returns
## the footfalls it made, each [code]{"fighter": int, "at": Vector3}[/code],
## at the fighter's feet.
func update(fighters: Array, frame: int) -> Array[Dictionary]:
	var feet: Array[Dictionary] = []
	var moved := frame != _frame
	_frame = frame
	for i: int in fighters.size():
		var f: Fighter = fighters[i]
		var at := Vector3(f.pos.x, f.pos.y, f.pos.z)
		var last: Variant = _last[i]
		_last[i] = at
		if last == null or not moved or not (f.state == &"free" or f.in_stance()) or f.airborne():
			continue
		var d := Vector2(at.x - (last as Vector3).x, at.z - (last as Vector3).z).length()
		if d > max_step:
			continue
		_travel[i] += d
		var stride := stride_for(d / SimConst.DT)
		if _travel[i] >= stride:
			_travel[i] -= stride
			feet.append({"fighter": i, "at": at})
	return feet


## The distance between footfalls at a speed (m/s).
func stride_for(speed: float) -> float:
	if speed < walk_below:
		return walk_stride
	if speed >= sprint_from:
		return sprint_stride
	return run_stride
