class_name Lean
extends RefCounted
## How a fighter leans into its acceleration and braces when it brakes,
## worked out from the rules' velocity on the rules' clock. Locomotion steps
## it once per rules frame and lays it on the body: the whole body tilts
## about the ground under it (BodyLayer.lean) and the hips drop
## (BodyLayer.hips_offset), while the leg IK keeps the feet planted.
##
## - The acceleration counts only while the fighter walks or runs on the
##   ground (Locomotion.walks(), the Iai stance included) on both frames, so
##   an attack's own change of speed, a dodge or a jump adds nothing. It is
##   the change of the rules' velocity over the ground, turns included
##   (circling the opponent pulls toward it), in the fighter's frame, eased
##   by ACCEL_EASE.
## - The body tilts toward it, PER_ACCEL a m/s², at most MOST: forward
##   setting off, back when braking, into a turn.
## - Braking, the acceleration against the way the fighter last travelled,
##   drops the hips, DROP_PER_DECEL a m/s², at most DROP_MOST: the brace.
## - The tilt and the drop follow on a critically damped spring (SPRING), so
##   a sudden change of speed (a tap step from rest is one frame) eases in
##   instead of snapping, and both settle once the speed holds.
##
## Everything is in the fighter's frame, as skeleton space is: x to its left,
## z forward.

## How far the body tilts per m/s² of acceleration (radians).
const PER_ACCEL: float = 0.014
## The furthest it tilts (radians).
const MOST: float = 11.0 * PI / 180.0
## How fast the acceleration it follows eases toward the rules' (1/s). The
## rules brake from a run in 7 frames: at this rate and SPRING the back-lean
## peaks 2 frames after the stop and settles in about 0.3 s, and a tap step
## from rest leans forward over 6 frames.
const ACCEL_EASE: float = 20.0
## How stiff the spring the tilt and the drop follow is (1/s).
const SPRING: float = 30.0
## How far the hips drop per m/s² of braking (m), and the furthest.
const DROP_PER_DECEL: float = 0.0035
const DROP_MOST: float = 0.05
## Below this ground speed (m/s) the fighter has no way it travels: the brace
## goes by the way it last did.
const HEADING_MIN_SPEED: float = 0.1

## The eased acceleration (m/s²).
var accel: Vector3 = Vector3.ZERO
## Which way the top of the body tilts and how far: its length is the angle
## (radians). After the last rules frame, after the one before, and how fast
## it changes.
var tilt: Vector3 = Vector3.ZERO
var prev_tilt: Vector3 = Vector3.ZERO
var tilt_rate: Vector3 = Vector3.ZERO
## How far the hips drop (m), likewise.
var drop: float = 0.0
var prev_drop: float = 0.0
var drop_rate: float = 0.0
## What was shown last.
var shown_tilt: Vector3 = Vector3.ZERO
var shown_drop: float = 0.0

## The rules' velocity over the ground on the last frame, in the world, and
## whether it counted (walking or running on the ground).
var _vel: Vector3 = Vector3.ZERO
var _counted: bool = false
## The way the fighter last travelled, in the world.
var _heading: Vector3 = Vector3.ZERO


## The tilt for acceleration `a`: toward it, PER_ACCEL a m/s², at most MOST.
static func target_tilt(a: Vector3) -> Vector3:
	var size: float = a.length()
	if size < 1e-6:
		return Vector3.ZERO
	return a / size * minf(PER_ACCEL * size, MOST)


## The hips' drop for acceleration `a` against `heading` (the way the
## fighter travels, a unit vector): DROP_PER_DECEL a m/s² of braking, at most
## DROP_MOST.
static func brace_drop(a: Vector3, heading: Vector3) -> float:
	return minf(DROP_PER_DECEL * maxf(0.0, -a.dot(heading)), DROP_MOST)


## The lean, as BodyLayer.lean takes it (a rotation vector), that tips the top
## of the body by `p_tilt`.
static func rotation(p_tilt: Vector3) -> Vector3:
	return Vector3(p_tilt.z, 0.0, -p_tilt.x)


## Starts from fighter `f` as it is, with no acceleration counted.
func reset(f: Fighter) -> void:
	_vel = _ground_velocity(f)
	_counted = _counts(f)
	prev_tilt = tilt
	prev_drop = drop


## Moves on `frames` rules frames to fighter `f` as it is now: the
## acceleration over them (shared evenly), eased, then the springs.
func step(f: Fighter, frames: int) -> void:
	var v: Vector3 = _ground_velocity(f)
	var counts: bool = _counts(f)
	var a: Vector3 = Vector3.ZERO
	if counts and _counted:
		a = (v - _vel) * float(SimConst.FPS) / float(frames)
	_vel = v
	_counted = counts
	if counts and v.length() > HEADING_MIN_SPEED:
		_heading = v.normalized()
	a = _to_fighter(a, f.yaw)
	var heading: Vector3 = _to_fighter(_heading, f.yaw)
	var dt: float = 1.0 / float(SimConst.FPS)
	var ease: float = 1.0 - exp(-ACCEL_EASE * dt)
	for i: int in frames:
		accel += (a - accel) * ease
		prev_tilt = tilt
		prev_drop = drop
		var want: Vector3 = target_tilt(accel)
		for axis: int in [0, 2]:
			var s: Vector2 = Locomotion.spring(tilt[axis], tilt_rate[axis], want[axis], SPRING, dt)
			tilt[axis] = s.x
			tilt_rate[axis] = s.y
		var d: Vector2 = Locomotion.spring(drop, drop_rate, brace_drop(accel, heading), SPRING, dt)
		drop = d.x
		drop_rate = d.y


## Shows the tilt and the drop `alpha` of the way from the frame before to
## the last.
func show(alpha: float) -> void:
	shown_tilt = prev_tilt.lerp(tilt, alpha)
	shown_drop = lerpf(prev_drop, drop, alpha)


## How the shown lean and brace move the upper body, the root of the
## skeleton at `root`: tilted about it, then dropped. A weapon held in a
## guard rides with it.
func carry(root: Vector3) -> Transform3D:
	var turn: Vector3 = rotation(shown_tilt)
	var out: Transform3D = Transform3D.IDENTITY
	if turn.length() > 1e-6:
		out = BodyLayer.about(root, Quaternion(turn.normalized(), turn.length()))
	return Transform3D(Basis.IDENTITY, Vector3(0.0, -shown_drop, 0.0)) * out


static func _counts(f: Fighter) -> bool:
	return Locomotion.walks(f)


static func _ground_velocity(f: Fighter) -> Vector3:
	return Vector3(f.vel.x, 0.0, f.vel.z)


## A world direction in the frame of a fighter facing `yaw`.
static func _to_fighter(w: Vector3, yaw: float) -> Vector3:
	return Vector3(w.x * cos(yaw) - w.z * sin(yaw), 0.0, w.x * sin(yaw) + w.z * cos(yaw))
