class_name SimMath
extends RefCounted
## Port of src/sim/math.ts.
##
## Small math helpers for the simulation (no three.js dependency so it runs in tests).
##
## Port notes:
## - Vec2 and Vec3 live in v2.gd and v3.gd; v2() and v3() are V2.make() and V3.make().
## - TS dist2 and yawTo accept Vec2 | Vec3; every caller passes a Vec3, so here
##   they take V3.
## - Math.sin, Math.cos and Math.atan2 are JsMath.sin, JsMath.cos and
##   JsMath.atan2: V8's exact results (see js_math.gd). Math.sqrt is sqrt.
## - js_round() is the JS Math.round, which GDScript's round() is not (it rounds
##   halves away from zero; JS rounds them toward +infinity).
## - easeInOut's Math.pow(x, 2) is a plain square, so no rule depends on the
##   C library's pow.


static func clamp(v: float, lo: float, hi: float) -> float:
	return lo if v < lo else (hi if v > hi else v)


static func lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


static func sign(v: float) -> float:
	return -1.0 if v < 0.0 else 1.0


static func len2(x: float, z: float) -> float:
	return sqrt(x * x + z * z)


static func dist2(a: V3, b: V3) -> float:
	return len2(b.x - a.x, b.z - a.z)


static func norm2(x: float, z: float) -> V2:
	var l: float = sqrt(x * x + z * z)
	return V2.make(x / l, z / l) if l > 1e-9 else V2.make(0.0, 1.0)


## Forward unit vector for a yaw angle. yaw=0 faces +Z; positive yaw turns toward +X.
static func fwd(yaw: float) -> V2:
	return V2.make(JsMath.sin(yaw), JsMath.cos(yaw))


## Right-hand unit vector for a yaw angle (fighter's own right side).
static func right(yaw: float) -> V2:
	# right = forward x up = (-fz, fx)
	return V2.make(-JsMath.cos(yaw), JsMath.sin(yaw))


## A point given in a fighter's own space, `local` = (right, up, forward) in
## metres from their feet, placed in the world for a fighter at `pos` facing
## `yaw`. Not in math.ts; the swings (task 7) use it.
##
## Facing +Z, a fighter's right is -X, so (right, up, forward) is a mirror image
## of Godot's axes: a cross product taken on (right, up, forward) vectors comes
## out reversed in the world. Take cross products after converting.
static func local_to_world(pos: V3, yaw: float, local: V3) -> V3:
	var f: V2 = fwd(yaw)
	var r: V2 = right(yaw)
	return V3.make(pos.x + r.x * local.x + f.x * local.z,
			pos.y + local.y,
			pos.z + r.z * local.x + f.z * local.z)


static func yaw_to(from: V3, to: V3) -> float:
	return JsMath.atan2(to.x - from.x, to.z - from.z)


static func wrap_angle(a: float) -> float:
	while a > PI:
		a -= PI * 2.0
	while a < -PI:
		a += PI * 2.0
	return a


## Rotate `current` toward `target` by at most `max_step` radians.
static func turn_toward(current: float, target: float, max_step: float) -> float:
	var d: float = wrap_angle(target - current)
	if absf(d) <= max_step:
		return target
	return wrap_angle(current + signf(d) * max_step)


static func angle_between(yaw: float, dir_yaw: float) -> float:
	return absf(wrap_angle(dir_yaw - yaw))


const DEG: float = PI / 180.0


## The roll's travel at `t` (0 to 1 of its frames): SimConst.MOVE_ROLL_CURVE,
## in a straight line between its points.
static func roll_travel(t: float) -> float:
	var c: Array[float] = SimConst.MOVE_ROLL_CURVE
	var n: int = c.size() - 1
	if t <= 0.0:
		return c[0]
	if t >= 1.0:
		return c[n]
	var x: float = t * float(n)
	var i: int = floori(x)
	return c[i] + (c[i + 1] - c[i]) * (x - float(i))


static func ease_out_cubic(t: float) -> float:
	var u: float = 1.0 - t
	return 1.0 - u * u * u


static func ease_in_out(t: float) -> float:
	if t < 0.5:
		return 2.0 * t * t
	var u: float = -2.0 * t + 2.0
	return 1.0 - u * u / 2.0


## JS Math.round: the nearest integer, halves toward +infinity
## (js_round(-0.5) == 0, js_round(2.5) == 3). Not in math.ts; the port uses it
## wherever the TS calls Math.round. Computed as floor plus a fraction test
## rather than floor(x + 0.5), which is wrong for 0.49999999999999994 and for
## odd integers above 2^52.
static func js_round(x: float) -> int:
	var r: float = floorf(x)
	return int(r + 1.0) if x - r >= 0.5 else int(r)


## The shortest distance between the segment from `a0` to `a1` and the one
## from `b0` to `b1` (either may be a single point), in 64-bit (task 7.7).
static func segment_distance(a0: V3, a1: V3, b0: V3, b1: V3) -> float:
	var p: Array[V3] = segment_closest(a0, a1, b0, b1)
	return V3.distance(p[0], p[1])


## The closest points of the segment from `a0` to `a1` and the one from `b0`
## to `b1` (either may be a single point), in 64-bit (task 7.8): the point on
## the first, then the point on the second, each a new V3. Ericson's closest
## points between segments: the closest points of the two lines, each clamped
## onto its segment, the other then re-found.
static func segment_closest(a0: V3, a1: V3, b0: V3, b1: V3) -> Array[V3]:
	var da: V3 = V3.sub(a1, a0)
	var db: V3 = V3.sub(b1, b0)
	var r: V3 = V3.sub(a0, b0)
	var aa: float = V3.dot(da, da)
	var bb: float = V3.dot(db, db)
	var rb: float = V3.dot(db, r)
	var s: float = 0.0
	var t: float = 0.0
	if aa <= 1e-24 and bb <= 1e-24:
		pass
	elif aa <= 1e-24:
		t = clampf(rb / bb, 0.0, 1.0)
	else:
		var ra: float = V3.dot(da, r)
		if bb <= 1e-24:
			s = clampf(-ra / aa, 0.0, 1.0)
		else:
			var ab: float = V3.dot(da, db)
			var denom: float = aa * bb - ab * ab
			# parallel segments: any s will do, so start from a0
			s = clampf((ab * rb - ra * bb) / denom, 0.0, 1.0) if denom > 1e-24 else 0.0
			t = (ab * s + rb) / bb
			if t < 0.0:
				t = 0.0
				s = clampf(-ra / aa, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((ab - ra) / aa, 0.0, 1.0)
	return [V3.add(a0, V3.scale(da, s)), V3.add(b0, V3.scale(db, t))]
