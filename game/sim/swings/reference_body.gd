class_name ReferenceBody
extends RefCounted
## A fighter's body at rest, as the swing checks (task 7.7) need it: the
## shoulders and the arms' lengths for solving the elbows, the spine the coil
## turns about, and proxy capsules round the torso, the head (with its hood or
## hat), the thighs and the arms, which a blade must keep clear of. Rules data
## per fighter (task 7.6), measured from the Rogue's and the Hunter's
## skeletons and meshes (again on KE task 3's taller bodies); tests/content/test_reference_bodies.gd says how and
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
		"shoulders": {"right": [0.188, 1.631, -0.062], "left": [-0.188, 1.631, -0.062]},
		"upper_arm": 0.276,
		"forearm": 0.287,
		"wrist": [-0.081, 0.0, 0.031],
		"spine": [[0.0, 1.086, -0.060], [0.0, 1.631, -0.062]],
		"torso": {"a": [0.0, 1.086, -0.023], "b": [0.0, 1.631, -0.023], "radius": 0.253},
		# the hood
		"head": {"a": [0.0, 1.782, -0.046], "b": [0.0, 1.859, -0.046], "radius": 0.192},
		"thighs": {
			"right": {"a": [0.128, 1.086, -0.060], "b": [0.128, 0.615, -0.037], "radius": 0.208},
			"left": {"a": [-0.128, 1.086, -0.060], "b": [-0.128, 0.615, -0.037], "radius": 0.208},
		},
		"upper_arm_radius": {"right": 0.060, "left": 0.060},
		# the bracers
		"forearm_radius": {"right": 0.090, "left": 0.090},
	},
	&"hunter": {
		"shoulders": {"right": [0.238, 1.674, -0.075], "left": [-0.238, 1.674, -0.075]},
		"upper_arm": 0.289,
		"forearm": 0.276,
		"wrist": [-0.105, 0.0, 0.036],
		"spine": [[0.0, 1.117, -0.041], [0.0, 1.674, -0.075]],
		"torso": {"a": [0.0, 1.117, -0.040], "b": [0.0, 1.674, -0.040], "radius": 0.275},
		# the tricorn's brim
		"head": {"a": [0.0, 1.840, 0.029], "b": [0.0, 1.900, 0.029], "radius": 0.201},
		"thighs": {
			"right": {"a": [0.104, 1.117, -0.041], "b": [0.104, 0.624, -0.042], "radius": 0.199},
			"left": {"a": [-0.104, 1.117, -0.041], "b": [-0.104, 0.624, -0.042], "radius": 0.200},
		},
		# the pauldron on the left shoulder
		"upper_arm_radius": {"right": 0.077, "left": 0.137},
		"forearm_radius": {"right": 0.075, "left": 0.075},
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
