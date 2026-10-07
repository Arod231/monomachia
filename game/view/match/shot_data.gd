class_name ShotData
extends Resource
## A cinematic shot's data (milestone-1 task 97; the glossary's Cinematic
## shot): a camera path, a lens, and the camera effects it allows, played by
## the ShotDirector on the presentation side, never in the rules. One
## resource a shot, in `game/view/match/shots/<id>.tres`, like the graphics
## presets.
##
## The path is keys in time (seconds of real time from the shot's start):
## where the camera is and what it looks at, in the frame of the fighter the
## shot is about (origin at its feet, +Z toward its opponent, +X to its left,
## +Y up, metres), and its field of view. A key's position or look point may
## instead be in the other fighter's frame (positions_on_other,
## looks_on_other; milestone-1 task 98: origin at its feet, +Z toward the
## fighter the shot is about), so a shot can swing from one fighter to the
## other whatever the gap. Between keys it eases on a Catmull-Rom curve
## through them, where they stand in the match; past the last it holds it.

## Who the shot's frame is on: the fighter who landed the move (an
## ultimate, a finisher), or the match's winner (the match-winning KO).
const ATTACKER: StringName = &"attacker"
const WINNER: StringName = &"winner"

@export var id: StringName = &""
@export var about: StringName = ATTACKER
## The keys' times (s), from 0, increasing.
@export var times: PackedFloat32Array = PackedFloat32Array()
## Each key's camera position and look point, in the fighter's frame.
@export var positions: PackedVector3Array = PackedVector3Array()
@export var looks: PackedVector3Array = PackedVector3Array()
## Each key's vertical field of view (degrees).
@export var fovs: PackedFloat32Array = PackedFloat32Array()
## Per key, 1 where its position (its look point) is in the other fighter's
## frame; empty for every key in the fighter's.
@export var positions_on_other: PackedByteArray = PackedByteArray()
@export var looks_on_other: PackedByteArray = PackedByteArray()
@export_group("Camera effects")
## A far blur past the look point while the shot plays (where the graphics
## preset allows depth of field): where it starts past the look point (m),
## and how much.
@export var depth_of_field: bool = true
@export var dof_margin: float = 1.0
@export var dof_amount: float = 0.1
## Allowed but not built yet (milestone-1 task 97, the owner's choice): a
## look task builds them as compositor effects and reads these.
@export var motion_blur: bool = false
@export var colour_fringing: bool = false


## How long the path runs (s): its last key's time.
func length() -> float:
	return times[times.size() - 1] if not times.is_empty() else 0.0


## The camera at `t` seconds in the fighter's frame: {pos, look, fov} (the
## keys as written, whichever frame each is in).
func sample(t: float) -> Dictionary:
	return _ease(t, positions, looks)


## The camera at `t` seconds in the match's space, for the fighter at `me`
## facing its opponent at `other` (feet positions): {pos, look, fov}.
func view_at(t: float, me: Vector3, other: Vector3) -> Dictionary:
	var frame: Transform3D = fighter_frame(me, other)
	if positions_on_other.is_empty() and looks_on_other.is_empty():
		var s: Dictionary = sample(t)
		return {"pos": frame * (s["pos"] as Vector3), "look": frame * (s["look"] as Vector3), "fov": s["fov"]}
	var theirs: Transform3D = fighter_frame(other, me)
	return _ease(t, _in_match(positions, positions_on_other, frame, theirs), _in_match(looks, looks_on_other, frame, theirs))


## `points` in the match's space, each by its frame (`on_other`).
static func _in_match(points: PackedVector3Array, on_other: PackedByteArray, mine: Transform3D, theirs: Transform3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in points.size():
		out.append((theirs if i < on_other.size() and on_other[i] != 0 else mine) * points[i])
	return out


## The path at `t` through keys `pos` and `look`: {pos, look, fov}.
func _ease(t: float, pos: PackedVector3Array, look: PackedVector3Array) -> Dictionary:
	var n: int = times.size()
	if n == 0:
		return {"pos": Vector3.ZERO, "look": Vector3.FORWARD, "fov": 50.0}
	if t <= times[0] or n == 1:
		return {"pos": pos[0], "look": look[0], "fov": fovs[0]}
	if t >= times[n - 1]:
		return {"pos": pos[n - 1], "look": look[n - 1], "fov": fovs[n - 1]}
	var i: int = 0
	while i < n - 2 and t >= times[i + 1]:
		i += 1
	var u: float = (t - times[i]) / (times[i + 1] - times[i])
	var a: int = maxi(i - 1, 0)
	var d: int = mini(i + 2, n - 1)
	return {
		"pos": pos[i].cubic_interpolate(pos[i + 1], pos[a], pos[d], u),
		"look": look[i].cubic_interpolate(look[i + 1], look[a], look[d], u),
		"fov": lerpf(fovs[i], fovs[i + 1], smoothstep(0.0, 1.0, u)),
	}


## The frame of a fighter at `me` facing `other`: origin at its feet, +Z
## toward the opponent, +X to its left.
static func fighter_frame(me: Vector3, other: Vector3) -> Transform3D:
	var z: Vector3 = Vector3(other.x - me.x, 0.0, other.z - me.z)
	z = z.normalized() if z.length() > 1e-4 else Vector3.BACK
	var x: Vector3 = Vector3.UP.cross(z)
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(me.x, 0.0, me.z))
