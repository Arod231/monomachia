class_name Quat64
extends RefCounted
## A rotation in 64-bit floats, for the swings (task 7). Not in math.ts.
##
## Godot's Quaternion is float32, like its Vector3, so the rules keep their own.
## Trig goes through JsMath and lengths through sqrt (exactly rounded by IEEE
## 754), so every platform gets the same bits. Rotations are right-handed about
## Godot's axes: a positive turn about +Y takes +Z toward +X, as a positive yaw
## does (SimMath.fwd). The functions take unit quaternions and return new ones.

var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
var w: float = 1.0


static func make(px: float, py: float, pz: float, pw: float) -> Quat64:
	var q: Quat64 = Quat64.new()
	q.x = px
	q.y = py
	q.z = pz
	q.w = pw
	return q


static func identity() -> Quat64:
	return Quat64.make(0.0, 0.0, 0.0, 1.0)


## A turn of `angle` radians about `axis`, which needn't be unit length. A zero
## axis gives the identity.
static func from_axis_angle(axis: V3, angle: float) -> Quat64:
	var n: V3 = V3.normalized(axis)
	var s: float = JsMath.sin(angle * 0.5)
	return Quat64.make(n.x * s, n.y * s, n.z * s, JsMath.cos(angle * 0.5))


## The rotation that turns +Y onto `y_axis` and +X onto `x_axis`, and so +Z onto
## x_axis cross y_axis: a weapon's frame from its blade direction (+Y) and its
## edge (+X). Neither needs to be unit length. `y_axis` is kept as given and
## `x_axis` is squared onto it; when the two are parallel, +X goes to whichever
## world axis is furthest from `y_axis`, squared the same way.
static func from_axes(y_axis: V3, x_axis: V3) -> Quat64:
	var ny: V3 = V3.normalized(y_axis)
	var px: V3 = V3.sub(x_axis, V3.scale(ny, V3.dot(x_axis, ny)))
	if V3.length(px) < 1e-9:
		var helper: V3 = _furthest_axis(ny)
		px = V3.sub(helper, V3.scale(ny, V3.dot(helper, ny)))
	var nx: V3 = V3.normalized(px)
	var nz: V3 = V3.cross(nx, ny)
	# Shepperd's method on the matrix whose columns are nx, ny and nz.
	var trace: float = nx.x + ny.y + nz.z
	if trace > 0.0:
		var s: float = sqrt(trace + 1.0) * 2.0
		return Quat64.make((ny.z - nz.y) / s, (nz.x - nx.z) / s, (nx.y - ny.x) / s, 0.25 * s)
	if nx.x > ny.y and nx.x > nz.z:
		var s: float = sqrt(1.0 + nx.x - ny.y - nz.z) * 2.0
		return Quat64.make(0.25 * s, (ny.x + nx.y) / s, (nz.x + nx.z) / s, (ny.z - nz.y) / s)
	if ny.y > nz.z:
		var s: float = sqrt(1.0 + ny.y - nx.x - nz.z) * 2.0
		return Quat64.make((ny.x + nx.y) / s, 0.25 * s, (nz.y + ny.z) / s, (nz.x - nx.z) / s)
	var s: float = sqrt(1.0 + nz.z - nx.x - ny.y) * 2.0
	return Quat64.make((nz.x + nx.z) / s, (nz.y + ny.z) / s, 0.25 * s, (nx.y - ny.x) / s)


## The shortest turn taking the direction `from` onto the direction `to`
## (neither needs to be unit length). Between opposite directions it is a half
## turn about an axis square to them.
static func from_to(from: V3, to: V3) -> Quat64:
	var a: V3 = V3.normalized(from)
	var b: V3 = V3.normalized(to)
	var d: float = V3.dot(a, b)
	if d < -1.0 + 1e-12:
		# Any axis square to a will do.
		var axis: V3 = V3.normalized(V3.cross(a, _furthest_axis(a)))
		return Quat64.make(axis.x, axis.y, axis.z, 0.0)
	# Half the turn's angle comes from normalizing (a x b, 1 + a . b).
	var c: V3 = V3.cross(a, b)
	var w: float = 1.0 + d
	var l: float = sqrt(c.x * c.x + c.y * c.y + c.z * c.z + w * w)
	return Quat64.make(c.x / l, c.y / l, c.z / l, w / l)


## The rotation `b` followed by `a` (the product a * b).
static func mul(a: Quat64, b: Quat64) -> Quat64:
	return Quat64.make(
			a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
			a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
			a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
			a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)


## The opposite turn (the conjugate, as `q` is unit length).
static func inverse(q: Quat64) -> Quat64:
	return Quat64.make(-q.x, -q.y, -q.z, q.w)


## How far apart two rotations are: the angle of the smallest turn taking one
## to the other, from 0 to PI.
static func angle_between(a: Quat64, b: Quat64) -> float:
	var r: Quat64 = Quat64.mul(Quat64.inverse(a), b)
	return 2.0 * JsMath.atan2(sqrt(r.x * r.x + r.y * r.y + r.z * r.z), absf(r.w))


## From `a` (t = 0) to `b` (t = 1) at an even rate, the short way round.
static func slerp(a: Quat64, b: Quat64, t: float) -> Quat64:
	var bb: Quat64 = _near(a, b)
	var r: Quat64 = Quat64.mul(Quat64.inverse(a), bb)
	# Half the turn from a to b; r.w >= 0, so it is at most PI / 2.
	var half: float = JsMath.atan2(sqrt(r.x * r.x + r.y * r.y + r.z * r.z), r.w)
	if half < 1e-9:
		return Quat64.nlerp(a, bb, t)
	var s: float = JsMath.sin(half)
	var ka: float = JsMath.sin((1.0 - t) * half) / s
	var kb: float = JsMath.sin(t * half) / s
	return Quat64.make(ka * a.x + kb * bb.x, ka * a.y + kb * bb.y, ka * a.z + kb * bb.z, ka * a.w + kb * bb.w)


## From `a` (t = 0) to `b` (t = 1) the short way round, blending the components
## and normalizing: cheaper than slerp, and uneven in rate away from the ends
## and the middle.
static func nlerp(a: Quat64, b: Quat64, t: float) -> Quat64:
	var bb: Quat64 = _near(a, b)
	var q: Quat64 = Quat64.make(a.x + (bb.x - a.x) * t, a.y + (bb.y - a.y) * t, a.z + (bb.z - a.z) * t, a.w + (bb.w - a.w) * t)
	var l: float = sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
	return Quat64.make(q.x / l, q.y / l, q.z / l, q.w / l)


## The world axis furthest from the unit direction `v`, to square onto it.
static func _furthest_axis(v: V3) -> V3:
	var ax: float = absf(v.x)
	var ay: float = absf(v.y)
	var az: float = absf(v.z)
	if ax <= ay and ax <= az:
		return V3.make(1.0, 0.0, 0.0)
	return V3.make(0.0, 1.0, 0.0) if ay <= az else V3.make(0.0, 0.0, 1.0)


## `b`, or -b (the same rotation) when that is nearer `a`, so a blend between
## them takes the short way round.
static func _near(a: Quat64, b: Quat64) -> Quat64:
	if a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w < 0.0:
		return Quat64.make(-b.x, -b.y, -b.z, -b.w)
	return b


## `v` turned by `q`.
static func rotate(q: Quat64, v: V3) -> V3:
	# v + 2w (u x v) + 2 u x (u x v), with u the vector part.
	var u: V3 = V3.make(q.x, q.y, q.z)
	var t: V3 = V3.scale(V3.cross(u, v), 2.0)
	return V3.add(V3.add(v, V3.scale(t, q.w)), V3.cross(u, t))


func _to_string() -> String:
	return "(%s, %s, %s, %s)" % [x, y, z, w]
