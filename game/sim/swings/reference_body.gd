class_name ReferenceBody
extends RefCounted
## A fighter's body at rest, as the swing checks (task 7.7) need it: the
## shoulders and the arms' lengths for solving the elbows, the spine the coil
## turns about, and proxy capsules round the torso, the head (with its hood or
## hat), the thighs and the arms, which a blade must keep clear of. Rules data
## per fighter (task 7.6), measured once from the Rogue's and the Hunter's
## skeletons and meshes; tests/content/test_reference_bodies.gd says how and
## keeps the numbers within 1 cm of them. Every swing must pass on both, since
## their proportions differ.
##
## Points are metres (right, up, forward) from the feet, as a swing's keys
## are. The arm proxies have only their radii here: the elbow solve places
## them. posed() turns and shifts the body as a swing's body track does.

const SIDES: Array[StringName] = [&"right", &"left"]

## The bodies by fighter id. "wrist" is the wrist in the right fist's frame
## (WeaponLook's weapon space: +X out of the knuckles, +Y out of the thumb
## side), at the handle radius the fist closes on by default (1.5 cm); the
## left fist's mirrors it across the flat. The weapons' handles (1.4 to 2.7
## cm) move it by under 1.2 cm.
const BODIES: Dictionary[StringName, Dictionary] = {
	&"rogue": {
		"shoulders": {"right": [0.152, 1.418, -0.054], "left": [-0.152, 1.418, -0.054]},
		"upper_arm": 0.240,
		"forearm": 0.249,
		"wrist": [-0.070, 0.0, 0.029],
		"spine": [[0.0, 0.944, -0.052], [0.0, 1.418, -0.054]],
		"torso": {"a": [0.0, 0.944, -0.022], "b": [0.0, 1.418, -0.022], "radius": 0.211},
		# the hood
		"head": {"a": [0.0, 1.550, -0.039], "b": [0.0, 1.623, -0.039], "radius": 0.171},
		"thighs": {
			"right": {"a": [0.111, 0.944, -0.052], "b": [0.111, 0.535, -0.032], "radius": 0.181},
			"left": {"a": [-0.111, 0.944, -0.052], "b": [-0.111, 0.535, -0.032], "radius": 0.181},
		},
		"upper_arm_radius": {"right": 0.052, "left": 0.052},
		# the bracers
		"forearm_radius": {"right": 0.079, "left": 0.079},
	},
	&"hunter": {
		"shoulders": {"right": [0.192, 1.456, -0.065], "left": [-0.192, 1.456, -0.065]},
		"upper_arm": 0.251,
		"forearm": 0.240,
		"wrist": [-0.091, 0.0, 0.033],
		"spine": [[0.0, 0.971, -0.036], [0.0, 1.456, -0.065]],
		"torso": {"a": [0.0, 0.971, -0.035], "b": [0.0, 1.456, -0.035], "radius": 0.228},
		# the tricorn's brim
		"head": {"a": [0.0, 1.600, 0.028], "b": [0.0, 1.662, 0.028], "radius": 0.182},
		"thighs": {
			"right": {"a": [0.091, 0.971, -0.036], "b": [0.091, 0.542, -0.036], "radius": 0.173},
			"left": {"a": [-0.091, 0.971, -0.036], "b": [-0.091, 0.542, -0.036], "radius": 0.174},
		},
		# the pauldron on the left shoulder
		"upper_arm_radius": {"right": 0.067, "left": 0.119},
		"forearm_radius": {"right": 0.066, "left": 0.066},
	},
}

## The fighter id.
var id: StringName = &""
## The shoulder joints by side (&"right", &"left").
var shoulders: Dictionary[StringName, V3] = {}
## Shoulder to elbow, and elbow to wrist.
var upper_arm: float = 0.0
var forearm: float = 0.0
## The wrist in the right fist's frame (see BODIES; wrist_in_fist()).
var wrist: V3 = V3.make()
## The spine, which the coil turns about: from the middle of the hips to the
## middle of the shoulders.
var spine_base: V3 = V3.make()
var spine_top: V3 = V3.make()
var torso: SimCapsule
var head: SimCapsule
## By side.
var thighs: Dictionary[StringName, SimCapsule] = {}
var upper_arm_radius: Dictionary[StringName, float] = {}
var forearm_radius: Dictionary[StringName, float] = {}


## The reference body of the fighter `fighter_id`; null, with an error, when
## no fighter has it.
static func of(fighter_id: StringName) -> ReferenceBody:
	if not BODIES.has(fighter_id):
		push_error("ReferenceBody: unknown fighter %s" % fighter_id)
		return null
	return from_record(fighter_id, BODIES[fighter_id])


## A body from a record shaped like BODIES' (tests build their own).
static func from_record(p_id: StringName, d: Dictionary) -> ReferenceBody:
	var body: ReferenceBody = ReferenceBody.new()
	body.id = p_id
	body.upper_arm = float(d["upper_arm"])
	body.forearm = float(d["forearm"])
	body.wrist = _v(d["wrist"])
	body.spine_base = _v(d["spine"][0])
	body.spine_top = _v(d["spine"][1])
	body.torso = _capsule(d["torso"])
	body.head = _capsule(d["head"])
	for side: StringName in SIDES:
		var s: String = String(side)
		body.shoulders[side] = _v(d["shoulders"][s])
		body.thighs[side] = _capsule(d["thighs"][s])
		body.upper_arm_radius[side] = float(d["upper_arm_radius"][s])
		body.forearm_radius[side] = float(d["forearm_radius"][s])
	return body


## The wrist in the fist's frame of the hand on `side`.
func wrist_in_fist(side: StringName) -> V3:
	return wrist if side == &"right" else V3.make(wrist.x, wrist.y, -wrist.z)


## This body turned and shifted as a swing's body track keys it (a copy; this
## body is left as it is). `torso_coil` turns the torso and the shoulders, and
## `pelvis_coil` the thighs at the hips, about the spine, in degrees, positive
## toward the fighter's right; the head keeps facing ahead and the knees stay
## where they are. `pelvis_shift` (metres) then carries everything but the
## knees.
func posed(torso_coil: float, pelvis_coil: float, pelvis_shift: V3) -> ReferenceBody:
	var axis: V3 = V3.normalized(V3.sub(spine_top, spine_base))
	var chest: Quat64 = Quat64.from_axis_angle(axis, torso_coil * SimMath.DEG)
	var hips: Quat64 = Quat64.from_axis_angle(axis, pelvis_coil * SimMath.DEG)
	var out: ReferenceBody = ReferenceBody.new()
	out.id = id
	out.upper_arm = upper_arm
	out.forearm = forearm
	out.wrist = wrist
	out.spine_base = V3.add(spine_base, pelvis_shift)
	out.spine_top = V3.add(spine_top, pelvis_shift)
	out.torso = SimCapsule.make(_turned(torso.a, chest, pelvis_shift), _turned(torso.b, chest, pelvis_shift), torso.radius)
	out.head = SimCapsule.make(V3.add(head.a, pelvis_shift), V3.add(head.b, pelvis_shift), head.radius)
	for side: StringName in SIDES:
		out.shoulders[side] = _turned(shoulders[side], chest, pelvis_shift)
		var thigh: SimCapsule = thighs[side]
		out.thighs[side] = SimCapsule.make(_turned(thigh.a, hips, pelvis_shift), thigh.b, thigh.radius)
	out.upper_arm_radius = upper_arm_radius.duplicate()
	out.forearm_radius = forearm_radius.duplicate()
	return out


## `p` turned by `turn` about the spine, then shifted by `shift`.
func _turned(p: V3, turn: Quat64, shift: V3) -> V3:
	return V3.add(V3.add(spine_base, Quat64.rotate(turn, V3.sub(p, spine_base))), shift)


static func _v(a: Array) -> V3:
	return V3.make(float(a[0]), float(a[1]), float(a[2]))


static func _capsule(d: Dictionary) -> SimCapsule:
	return SimCapsule.make(_v(d["a"]), _v(d["b"]), float(d["radius"]))
