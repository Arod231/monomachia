class_name KeyedPose
extends RefCounted
## Hand-keyed clips from key poses (the /animeref tool's output when pose
## tracking can't read the reference): each key says where the feet and
## wrists go and how the hips and spine turn, and solve() turns it into bone
## rotations on the humanoid profile with two-bone IK, so the keys stay short
## and readable and a planted foot lands exactly where its key puts it.
## build() makes the Animation: one rotation track per posed bone and a
## position track on the hips, keyed only at the key poses (cubic), so the
## clip can still be edited by hand in Godot.
##
## A key, in fighter space (the skeleton's: +Y up, +Z forward, metres from
## the floor under the fighter, sized on the Hunter):
## - "f": its rules frame (60 a second);
## - "hips": {"y": drop (negative lowers), "z": forward, "x": to the left,
##   "rot": [pitch, yaw, roll]};
## - "spine", "chest", "upper_chest", "neck", "head": [pitch, yaw, roll];
## - "legs" and "arms", each {"left": limb, "right": limb}, a limb being
##   {"at": [out, up, fwd] the ankle or wrist, "pole": [out, up, fwd] the way
##   the knee or elbow points, and optionally "dir" and "up" for the foot or
##   hand: its bone's Y axis (toes, knuckles) and Z axis (the top of the
##   foot, the palm's side, as in the T-pose rest), or for a hand "blade":
##   [out, up, fwd] the way a weapon held in it points (FighterRig's grip
##   lays the blade along the hand's X axis), the knuckles following the
##   forearm}.
## Angles are degrees: pitch leans forward, yaw turns to the fighter's
## left, roll leans to the right. "out" is away from the body's middle on
## the limb's own side, so left and right keys read the same.
##
## Bones no key poses (shoulders, fingers, toes) hold the base pose: frame 0
## of the clip the file names as "base" (the weapon idle's fist, so the hand
## still closes round a grip).

const SKELETON_PREFIX: String = "%GeneralSkeleton"
## The spine's bones, from the hips up, and their keys.
const SPINE: Array[Array] = [
	[&"Spine", "spine"], [&"Chest", "chest"], [&"UpperChest", "upper_chest"], [&"Neck", "neck"], [&"Head", "head"],
]
## The way a limb's lower bone swings from the upper as the joint bends, in
## the rest pose: the shin back, the forearm forward.
const LEG_BEND: Vector3 = Vector3(0.0, 0.0, -1.0)
const ARM_BEND: Vector3 = Vector3(0.0, 0.0, 1.0)


## One solved pose: each posed bone's rotation (its local pose, as a track
## holds it) and the hips' position (skeleton space, metres).
class Pose:
	var rot: Dictionary[StringName, Quaternion] = {}
	var hips: Vector3 = Vector3.ZERO
	## Each bone's place in fighter space, for checks.
	var global: Dictionary[StringName, Transform3D] = {}


## `side` "left" or "right": the key's [out, up, fwd] in fighter space.
static func side_vec(side: String, v: Array) -> Vector3:
	var out: float = float(v[0]) * (1.0 if side == "left" else -1.0)
	return Vector3(out, float(v[1]), float(v[2]))


## [pitch, yaw, roll] in degrees as a basis.
static func euler(v: Variant) -> Basis:
	if v == null:
		return Basis.IDENTITY
	var a: Array = v
	return Basis.from_euler(Vector3(deg_to_rad(float(a[0])), deg_to_rad(float(a[1])), deg_to_rad(float(a[2]))), EULER_ORDER_YXZ)


## The rotation taking direction a0 (with b0 square to it) onto a1 (with b1).
static func frame(a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3) -> Basis:
	return _ortho(a1, b1) * _ortho(a0, b0).transposed()


static func _ortho(a: Vector3, b: Vector3) -> Basis:
	var x: Vector3 = a.normalized()
	var y: Vector3 = (b - x * b.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


## The base pose's local rotation per bone: `base` sampled at its start, or
## the rest pose for a bone it has no track for.
static func base_pose(sk: Skeleton3D, base: Animation) -> Dictionary[StringName, Quaternion]:
	var out: Dictionary[StringName, Quaternion] = {}
	for i: int in sk.get_bone_count():
		out[StringName(sk.get_bone_name(i))] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
	if base == null:
		return out
	for t: int in base.get_track_count():
		if base.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone: StringName = base.track_get_path(t).get_concatenated_subnames()
		if out.has(bone):
			out[bone] = base.rotation_track_interpolate(t, 0.0)
	return out


## Solves key `key` on skeleton `sk` (its rest pose and bone lengths) over
## the base pose `base` (base_pose()).
static func solve(key: Dictionary, sk: Skeleton3D, base: Dictionary[StringName, Quaternion]) -> Pose:
	var pose: Pose = Pose.new()
	var g: Dictionary[StringName, Transform3D] = {}
	for i: int in sk.get_bone_count():
		var parent: int = sk.get_bone_parent(i)
		var bone: StringName = StringName(sk.get_bone_name(i))
		var local: Transform3D = Transform3D(Basis(base[bone]), sk.get_bone_rest(i).origin)
		g[bone] = g[StringName(sk.get_bone_name(parent))] * local if parent >= 0 else local
	# the hips
	var h: Dictionary = key.get("hips", {})
	var hips_i: int = sk.find_bone("Hips")
	var hips_rest: Transform3D = sk.get_bone_rest(hips_i)
	pose.hips = hips_rest.origin + Vector3(float(h.get("x", 0.0)), float(h.get("y", 0.0)), float(h.get("z", 0.0)))
	var hips_basis: Basis = euler(h.get("rot")) * hips_rest.basis
	pose.rot[&"Hips"] = hips_basis.get_rotation_quaternion()
	g[&"Hips"] = g[StringName(sk.get_bone_name(sk.get_bone_parent(hips_i)))] * Transform3D(hips_basis, pose.hips)
	# the spine, each bone turned on top of its rest
	for entry: Array in SPINE:
		var bone: StringName = entry[0]
		var i: int = sk.find_bone(bone)
		var rest: Transform3D = sk.get_bone_rest(i)
		var b: Basis = euler(key.get(entry[1])) * rest.basis
		pose.rot[bone] = b.get_rotation_quaternion()
		g[bone] = g[StringName(sk.get_bone_name(sk.get_bone_parent(i)))] * Transform3D(b, rest.origin)
	# the shoulders follow the chest on the base pose
	for s: String in ["Left", "Right"]:
		var bone: StringName = StringName(s + "Shoulder")
		var i: int = sk.find_bone(bone)
		g[bone] = g[&"UpperChest"] * Transform3D(Basis(base[bone]), sk.get_bone_rest(i).origin)
	var legs: Dictionary = key.get("legs", {})
	var arms: Dictionary = key.get("arms", {})
	for side: String in ["left", "right"]:
		var s: String = side.capitalize()
		if legs.has(side):
			_limb(pose, g, sk, side, legs[side], &"Hips", StringName(s + "UpperLeg"), StringName(s + "LowerLeg"), StringName(s + "Foot"), LEG_BEND)
		if arms.has(side):
			_limb(pose, g, sk, side, arms[side], StringName(s + "Shoulder"), StringName(s + "UpperArm"), StringName(s + "LowerArm"), StringName(s + "Hand"), ARM_BEND)
	pose.global = g
	return pose


## Poses a limb by two-bone IK: the upper bone from `parent`'s place toward
## the joint, which bends toward the pole, the lower on to the end at the
## key's "at" (pulled in to just short of reach), then the end bone turned
## to the key's "dir" and "up", or kept on the lower's rest turn.
static func _limb(pose: Pose, g: Dictionary[StringName, Transform3D], sk: Skeleton3D, side: String, spec: Dictionary, parent: StringName, upper: StringName, lower: StringName, end: StringName, bend0: Vector3) -> void:
	var iu: int = sk.find_bone(upper)
	var il: int = sk.find_bone(lower)
	var ie: int = sk.find_bone(end)
	var gp: Transform3D = g[parent]
	var root: Vector3 = gp * sk.get_bone_rest(iu).origin
	var rest_u: Basis = sk.get_bone_global_rest(iu).basis.orthonormalized()
	var rest_l: Basis = sk.get_bone_global_rest(il).basis.orthonormalized()
	var rest_e: Basis = sk.get_bone_global_rest(ie).basis.orthonormalized()
	var a: float = sk.get_bone_rest(il).origin.length()
	var b: float = sk.get_bone_rest(ie).origin.length()
	var target: Vector3 = side_vec(side, spec["at"])
	var pole: Vector3 = side_vec(side, spec.get("pole", [0.0, 0.0, 1.0]))
	var to: Vector3 = target - root
	var d: float = clampf(to.length(), absf(a - b) + 0.001, (a + b) * 0.9995)
	var u: Vector3 = to.normalized()
	var cos_a: float = clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var pp: Vector3 = pole - u * pole.dot(u)
	if pp.length() < 0.0001:
		pp = u.cross(Vector3.RIGHT if absf(u.x) < 0.9 else Vector3.UP)
	pp = pp.normalized()
	var knee: Vector3 = root + a * (u * cos_a + pp * sqrt(maxf(0.0, 1.0 - cos_a * cos_a)))
	var tip: Vector3 = root + u * d
	var du: Vector3 = (knee - root).normalized()
	var dl: Vector3 = (tip - knee).normalized()
	var bend: Vector3 = dl - du * dl.dot(du)
	if bend.length() < 0.001:
		# straight: it would bend away from where the joint points
		bend = -(pp - du * pp.dot(du))
	# the joints' rest offsets (not quite along the bones' Y axes: the ankle
	# sits behind the shin's line), so the end lands on the key
	var seg_u: Vector3 = (sk.get_bone_global_rest(il).origin - sk.get_bone_global_rest(iu).origin).normalized()
	var seg_l: Vector3 = (sk.get_bone_global_rest(ie).origin - sk.get_bone_global_rest(il).origin).normalized()
	var turn_u: Basis = frame(seg_u, bend0, du, bend.normalized())
	var gu: Basis = turn_u * rest_u
	var gl: Basis = Basis(Quaternion((turn_u * seg_l).normalized(), dl)) * turn_u * rest_l
	var ge: Basis
	if spec.has("blade"):
		# the held blade lies along the hand's X axis (its -X on the left, a
		# mirrored grip): turn it there, the knuckles following the forearm
		var x0: Vector3 = rest_e.x if side == "right" else -rest_e.x
		ge = frame(x0, rest_e.y, side_vec(side, spec["blade"]), dl) * rest_e
	elif spec.has("dir"):
		var up: Vector3 = side_vec(side, spec["up"]) if spec.has("up") else rest_e.z
		ge = frame(rest_e.y, rest_e.z, side_vec(side, spec["dir"]), up) * rest_e
	else:
		ge = gl * (rest_l.transposed() * rest_e)
	g[upper] = Transform3D(gu, root)
	g[lower] = Transform3D(gl, g[upper] * sk.get_bone_rest(il).origin)
	g[end] = Transform3D(ge, g[lower] * sk.get_bone_rest(ie).origin)
	pose.rot[upper] = (gp.basis.orthonormalized().transposed() * gu).get_rotation_quaternion()
	pose.rot[lower] = (gu.transposed() * gl).get_rotation_quaternion()
	pose.rot[end] = (gl.transposed() * ge).get_rotation_quaternion()


## The clip of key file `data` on skeleton `sk`: every key solved, the
## base pose's bones held, cubic tracks keyed at the keys' frames. The hips'
## position is written over the skeleton's motion scale, so it fits each
## fighter's height.
static func build(data: Dictionary, sk: Skeleton3D, base: Animation) -> Animation:
	var fps: float = float(data.get("fps", SimConst.FPS))
	var frames: float = float(data["frames"])
	var held: Dictionary[StringName, Quaternion] = base_pose(sk, base)
	var keys: Array = data["keys"]
	var poses: Array[Pose] = []
	for key: Dictionary in keys:
		poses.append(solve(key, sk, held))
	var anim: Animation = Animation.new()
	anim.length = frames / fps
	anim.loop_mode = Animation.LOOP_NONE
	var hips_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_track, NodePath("%s:Hips" % SKELETON_PREFIX))
	anim.track_set_interpolation_type(hips_track, Animation.INTERPOLATION_CUBIC)
	var scale: float = sk.motion_scale if sk.motion_scale > 0.0 else 1.0
	for k: int in poses.size():
		anim.position_track_insert_key(hips_track, float(keys[k]["f"]) / fps, poses[k].hips / scale)
	for i: int in sk.get_bone_count():
		var bone: StringName = StringName(sk.get_bone_name(i))
		if bone == &"Root":
			continue
		var t: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [SKELETON_PREFIX, bone]))
		var posed: bool = poses[0].rot.has(bone)
		anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC if posed else Animation.INTERPOLATION_LINEAR)
		if not posed:
			anim.rotation_track_insert_key(t, 0.0, held[bone])
			continue
		var last: Quaternion = poses[0].rot[bone]
		for k: int in poses.size():
			var q: Quaternion = poses[k].rot[bone]
			# the short way round from the key before
			if q.dot(last) < 0.0:
				q = -q
			anim.rotation_track_insert_key(t, float(keys[k]["f"]) / fps, q)
			last = q
	return anim
