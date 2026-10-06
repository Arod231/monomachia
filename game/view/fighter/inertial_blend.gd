class_name InertialBlend
extends SkeletonModifier3D
## Inertial blending (milestone-1 task 23; spec story 94, P11): on a hand-off
## the new motion shows at once, and what is left of the old pose fades out
## over a few frames. The first modifier of the fighter's rig (FighterRig),
## right after the clip and before the procedural body, foot locking and the
## hands' grip; it changes only the picture.
##
## On request(frames) it takes, for every bone, the pose shown last as an
## offset from the pose the clip now gives: a turn about one axis and a move
## along one line, each with the speed it was changing at. Each frame it
## lays what is left of the offset over the clip's pose, decaying to nothing
## by the blend's end along decay() (Bollo's inertialization, GDC 2018: a
## quintic that starts at the offset with its speed and reaches the new pose
## with no speed, its starting speed and length clamped so it never
## overshoots). A request while one is under way starts from what is shown.
##
## It runs on the world's time, in rules frames (time, which the view sets
## each frame, the step plus alpha), so hit-stop and slow motion hold it as
## they hold the clips, and the same frames give the same pose.

## The world's time it is shown at, in rules frames (step + alpha).
var time: float = 0.0

## The blend under way: its length in rules frames (0 for none) and when it
## began.
var _length: float = 0.0
var _start: float = 0.0
var _pending: int = 0
## Per bone: the offset's axis and angle (rad), its angular speed (rad a
## frame, toward or away from the pose), and its line, length (m) and speed.
var _axis: PackedVector3Array = PackedVector3Array()
var _angle: PackedFloat64Array = PackedFloat64Array()
var _angle_speed: PackedFloat64Array = PackedFloat64Array()
var _line: PackedVector3Array = PackedVector3Array()
var _dist: PackedFloat64Array = PackedFloat64Array()
var _dist_speed: PackedFloat64Array = PackedFloat64Array()
## The poses shown at the last two frames, and when.
var _shown_rot: Array[Quaternion] = []
var _shown_pos: PackedVector3Array = PackedVector3Array()
var _shown_time: float = -INF
var _before_rot: Array[Quaternion] = []
var _before_pos: PackedVector3Array = PackedVector3Array()
var _before_time: float = -INF


## Asks for a blend of `frames` rules frames from the pose shown last, taken
## at the next update.
func request(frames: int) -> void:
	_pending = maxi(frames, 0)


## Forgets what was shown (a new match, a jump of the playhead), so the next
## pose shows as it is.
func clear() -> void:
	_length = 0.0
	_pending = 0
	_shown_rot.clear()
	_before_rot.clear()
	_shown_time = -INF
	_before_time = -INF


## Whether a blend is asked for or under way at `time`.
func blending() -> bool:
	return _pending > 0 or (_length > 0.0 and time - _start < _length)


## What is left of an offset `x0` (>= 0), changing at `v0` a frame, `t`
## frames into a blend of `length` frames: from x0 at t = 0 to 0 at the
## (possibly shortened) end, with no speed there and never below 0.
static func decay(x0: float, v0: float, length: float, t: float) -> float:
	if x0 <= 0.0 or length <= 0.0:
		return 0.0
	var v: float = minf(v0, 0.0) # moving away from the pose counts as still
	var T: float = length
	if v < 0.0:
		T = minf(T, -5.0 * x0 / v)
	if t >= T:
		return 0.0
	var T2: float = T * T
	var a0: float = maxf(0.0, (-8.0 * v * T - 20.0 * x0) / T2)
	var A: float = -(a0 * T2 + 6.0 * v * T + 12.0 * x0) / (2.0 * T2 * T2 * T)
	var B: float = (3.0 * a0 * T2 + 16.0 * v * T + 30.0 * x0) / (2.0 * T2 * T2)
	var C: float = -(3.0 * a0 * T2 + 12.0 * v * T + 20.0 * x0) / (2.0 * T2 * T)
	var x: float = (((A * t + B) * t + C) * t + 0.5 * a0) * t * t + v * t + x0
	return clampf(x, 0.0, x0)


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var n: int = sk.get_bone_count()
	if _pending > 0 and _shown_rot.size() == n:
		_begin(sk, float(_pending))
	_pending = 0
	var t: float = time - _start
	var on: bool = _length > 0.0 and t < _length
	if not on:
		_length = 0.0
	var rot: Array[Quaternion] = []
	var pos: PackedVector3Array = PackedVector3Array()
	rot.resize(n)
	pos.resize(n)
	for i: int in n:
		var q: Quaternion = sk.get_bone_pose_rotation(i)
		var p: Vector3 = sk.get_bone_pose_position(i)
		if on:
			var angle: float = decay(_angle[i], _angle_speed[i], _length, t)
			if angle > 0.0:
				q = (Quaternion(_axis[i], angle) * q).normalized()
				sk.set_bone_pose_rotation(i, q)
			var dist: float = decay(_dist[i], _dist_speed[i], _length, t)
			if dist > 0.0:
				p += _line[i] * dist
				sk.set_bone_pose_position(i, p)
		rot[i] = q
		pos[i] = p
	if time != _shown_time:
		_before_rot = _shown_rot
		_before_pos = _shown_pos
		_before_time = _shown_time
	_shown_rot = rot
	_shown_pos = pos
	_shown_time = time


## Takes each bone's offset from the clip's pose now to the pose shown last,
## with the speed it was changing at over the frames before.
func _begin(sk: Skeleton3D, frames: float) -> void:
	var n: int = sk.get_bone_count()
	_axis.resize(n)
	_angle.resize(n)
	_angle_speed.resize(n)
	_line.resize(n)
	_dist.resize(n)
	_dist_speed.resize(n)
	var dt: float = _shown_time - _before_time
	var has_speed: bool = _before_rot.size() == n and dt > 1e-6 and dt < 4.0
	for i: int in n:
		var q: Quaternion = sk.get_bone_pose_rotation(i)
		var p: Vector3 = sk.get_bone_pose_position(i)
		var off: Quaternion = (_shown_rot[i] * q.inverse()).normalized()
		if off.w < 0.0:
			off = -off
		var axis: Vector3 = Vector3(off.x, off.y, off.z)
		var angle: float = off.get_angle() if axis.length() > 1e-9 else 0.0
		axis = axis.normalized() if angle > 0.0 else Vector3.UP
		_axis[i] = axis
		_angle[i] = angle
		_angle_speed[i] = 0.0
		var line: Vector3 = _shown_pos[i] - p
		var dist: float = line.length()
		_line[i] = line / dist if dist > 1e-7 else Vector3.ZERO
		_dist[i] = dist if dist > 1e-7 else 0.0
		_dist_speed[i] = 0.0
		if has_speed:
			# the offset the frame before, taken about the same axis and line
			var before: Quaternion = (_before_rot[i] * q.inverse()).normalized()
			if before.w < 0.0:
				before = -before
			var twist: float = 2.0 * atan2(Vector3(before.x, before.y, before.z).dot(axis), before.w)
			_angle_speed[i] = (angle - twist) / dt
			_dist_speed[i] = (dist - (_before_pos[i] - p).dot(_line[i])) / dt
	_length = frames
	_start = time
