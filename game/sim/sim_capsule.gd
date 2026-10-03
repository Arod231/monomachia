class_name SimCapsule
extends RefCounted
## A capsule in the rules (task 7.5): every point within `radius` of the
## segment from `a` to `b`, in metres. A fighter's hurt capsule is one
## (Fighter.hurt_capsule()), and blade sweeps are tested against them (task
## 7.8). Named SimCapsule, not Capsule, so the global name doesn't shadow
## other scripts' own capsule classes, such as PoseCheck.Capsule.

var a: V3 = V3.make()
var b: V3 = V3.make()
var radius: float = 0.0


static func make(p_a: V3, p_b: V3, p_radius: float) -> SimCapsule:
	var c: SimCapsule = SimCapsule.new()
	c.a = p_a
	c.b = p_b
	c.radius = p_radius
	return c
