class_name V3
extends RefCounted
## Port of the Vec3 interface in v0.1-web-mvp:src/sim/math.ts: a position or velocity in
## metres, y up.
##
## Port note: 64-bit floats instead of Godot's Vector3, which is float32 and
## would drift from the TypeScript rules. Like the TS object literals it has
## reference semantics: assigning a V3 shares it, V3.make() makes a new one.

var x: float = 0.0
var y: float = 0.0
var z: float = 0.0


## v3(x = 0, y = 0, z = 0)
static func make(px: float = 0.0, py: float = 0.0, pz: float = 0.0) -> V3:
	var v: V3 = V3.new()
	v.x = px
	v.y = py
	v.z = pz
	return v


# Vector operations for the swings (task 7). Not in math.ts. Each returns a new
# V3 and leaves its arguments alone. Lengths use sqrt, which IEEE 754 rounds
# exactly on every platform, so no JsMath call is needed.

static func add(a: V3, b: V3) -> V3:
	return V3.make(a.x + b.x, a.y + b.y, a.z + b.z)


static func sub(a: V3, b: V3) -> V3:
	return V3.make(a.x - b.x, a.y - b.y, a.z - b.z)


static func scale(a: V3, s: float) -> V3:
	return V3.make(a.x * s, a.y * s, a.z * s)


static func dot(a: V3, b: V3) -> float:
	return a.x * b.x + a.y * b.y + a.z * b.z


## Right-handed, like Godot's axes: cross(+X, +Y) is +Z.
static func cross(a: V3, b: V3) -> V3:
	return V3.make(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)


static func length(a: V3) -> float:
	return sqrt(a.x * a.x + a.y * a.y + a.z * a.z)


static func distance(a: V3, b: V3) -> float:
	return V3.length(V3.sub(b, a))


## The unit vector along `a`, or the zero vector when `a` is zero.
static func normalized(a: V3) -> V3:
	var l: float = V3.length(a)
	return V3.scale(a, 1.0 / l) if l > 1e-12 else V3.make()


static func lerp(a: V3, b: V3, t: float) -> V3:
	return V3.make(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)


func _to_string() -> String:
	return "(%s, %s, %s)" % [x, y, z]
