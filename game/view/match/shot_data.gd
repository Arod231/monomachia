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
## +Y up, metres), and its field of view. Between keys it eases on a
## Catmull-Rom curve through them; past the last it holds it.

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


## The camera at `t` seconds in the fighter's frame: {pos, look, fov}.
func sample(t: float) -> Dictionary:
	var n: int = times.size()
	if n == 0:
		return {"pos": Vector3.ZERO, "look": Vector3.FORWARD, "fov": 50.0}
	if t <= times[0] or n == 1:
		return {"pos": positions[0], "look": looks[0], "fov": fovs[0]}
	if t >= times[n - 1]:
		return {"pos": positions[n - 1], "look": looks[n - 1], "fov": fovs[n - 1]}
	var i: int = 0
	while i < n - 2 and t >= times[i + 1]:
		i += 1
	var u: float = (t - times[i]) / (times[i + 1] - times[i])
	var a: int = maxi(i - 1, 0)
	var d: int = mini(i + 2, n - 1)
	return {
		"pos": positions[i].cubic_interpolate(positions[i + 1], positions[a], positions[d], u),
		"look": looks[i].cubic_interpolate(looks[i + 1], looks[a], looks[d], u),
		"fov": lerpf(fovs[i], fovs[i + 1], smoothstep(0.0, 1.0, u)),
	}


## The camera at `t` seconds in the match's space, for the fighter at `me`
## facing its opponent at `other` (feet positions): {pos, look, fov}.
func view_at(t: float, me: Vector3, other: Vector3) -> Dictionary:
	var s: Dictionary = sample(t)
	var frame: Transform3D = fighter_frame(me, other)
	return {"pos": frame * (s["pos"] as Vector3), "look": frame * (s["look"] as Vector3), "fov": s["fov"]}


## The frame of a fighter at `me` facing `other`: origin at its feet, +Z
## toward the opponent, +X to its left.
static func fighter_frame(me: Vector3, other: Vector3) -> Transform3D:
	var z: Vector3 = Vector3(other.x - me.x, 0.0, other.z - me.z)
	z = z.normalized() if z.length() > 1e-4 else Vector3.BACK
	var x: Vector3 = Vector3.UP.cross(z)
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(me.x, 0.0, me.z))
