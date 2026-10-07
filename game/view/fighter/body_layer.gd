class_name BodyLayer
extends SkeletonModifier3D
## The fighter's procedural body pose, laid over the playing clip before the
## arm and leg IK (see FighterRig): a lean about the ground, the hips turned
## and moved, the spine twisted and bent over its three bones, and the head
## turned. Everything is in skeleton space, the fighter's own frame: +Z
## forward, +X to the fighter's left, +Y up, metres from the ground. With
## every value at zero the clip's pose is left alone.
##
## Each turn is applied as a rotation in skeleton space, parent first, so
## that it means the same whatever the clip does. In order: the hips and
## thighs turned, the lean, the hips moved, then the spine and the head.

## How a spine twist or bend is shared over the spine's bones.
const SPINE_SHARE: Dictionary[StringName, float] = {&"Spine": 0.28, &"Chest": 0.36, &"UpperChest": 0.36}
## How a head turn is shared over the neck and head.
const HEAD_SHARE: Dictionary[StringName, float] = {&"Neck": 0.45, &"Head": 0.55}
## The hips and the bones above them that untwist turns back, each after its
## parent.
const TWIST_CHAIN: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head"]

## The whole body leaning about the ground under it, as a rotation vector
## (axis times angle in radians): leaning into acceleration.
var lean: Vector3 = Vector3.ZERO
## The hips, and the legs with them, turned about the vertical (radians,
## positive to the fighter's left).
var pelvis_yaw: float = 0.0
## Both legs turned further at the hips.
var thigh_yaw: float = 0.0
## The spine twisted about the vertical, shared over SPINE_SHARE; often
## against pelvis_yaw, to keep the chest square.
var spine_yaw: float = 0.0
## The spine bent forward (positive) or back.
var spine_pitch: float = 0.0
## The spine bent sideways, positive tipping the top to the fighter's right.
var spine_roll: float = 0.0
## The head turned (positive to the left) and nodded (positive down), shared
## over HEAD_SHARE.
var head_yaw: float = 0.0
var head_pitch: float = 0.0
## The hips moved, in skeleton space: a dip, a weight shift.
var hips_offset: Vector3 = Vector3.ZERO
## The clip's own carry of the hips (milestone-1 task 99), in their pose
## space from the clip's start: its part across the ground is taken out,
## for a clip that carries the body (the recall burst's blasted fall) by
## the travel the rules already move the fighter by.
var carried: Vector3 = Vector3.ZERO
## How much of the clip's own twist above the hips is taken out, 0 to 1: at
## 1 the spine, neck and head face the way the hips do, bone by bone, before
## the turns above. A running clip swings the shoulders round (the jog's by
## about 40° each way), which a fighter facing its opponent as it runs, a
## weapon in its hands, doesn't.
var untwist: float = 0.0

## Where the clip put each leg this update, turned with the hips and thighs
## (pelvis_yaw, thigh_yaw) but before anything else here moved it, by side
## ("Right", "Left"): the hip and knee joints, and the foot. The rig's leg IK
## can keep the feet there (FighterRig.clip_feet), so turned legs plant
## their feet where they turned to.
var clip_hips: Dictionary[String, Vector3] = {}
var clip_knees: Dictionary[String, Vector3] = {}
var clip_feet: Dictionary[String, Transform3D] = {}

var _ids: Dictionary[StringName, int] = {}


## Turns a bone by `turn`, a rotation in skeleton space, about its own
## origin: its new global rotation is `turn` times its old one, and its
## children turn with it.
static func rot_global(sk: Skeleton3D, bone: int, turn: Quaternion) -> void:
	var parent: int = sk.get_bone_parent(bone)
	var parent_q: Quaternion = Quaternion.IDENTITY
	if parent >= 0:
		parent_q = sk.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var local: Quaternion = sk.get_bone_pose_rotation(bone)
	sk.set_bone_pose_rotation(bone, (parent_q.inverse() * turn * parent_q * local).normalized())


## A bone's turn about the vertical from its rest (radians, positive to the
## fighter's left), when its pose in skeleton space is `pose`.
static func heading(sk: Skeleton3D, bone: int, pose: Transform3D) -> float:
	var turn: Basis = pose.basis.orthonormalized() * sk.get_bone_global_rest(bone).basis.orthonormalized().inverse()
	var ahead: Vector3 = turn * Vector3.BACK
	return atan2(ahead.x, ahead.z)


## Sets every value back to zero.
func clear() -> void:
	lean = Vector3.ZERO
	pelvis_yaw = 0.0
	thigh_yaw = 0.0
	spine_yaw = 0.0
	spine_pitch = 0.0
	spine_roll = 0.0
	head_yaw = 0.0
	head_pitch = 0.0
	hips_offset = Vector3.ZERO
	carried = Vector3.ZERO
	untwist = 0.0


## Where a point riding the upper chest (a shoulder, the neck), at `point`
## in the clip's pose, will be once this layer has moved the body: the same
## turns and shifts, worked on the clip's bone poses. Read it between
## updates, while the skeleton holds the clip's pose.
func moved(sk: Skeleton3D, point: Vector3) -> Vector3:
	return upper_body(sk) * point


## How this layer will move the upper chest and everything riding it, from
## the clip's pose (see moved()).
func upper_body(sk: Skeleton3D) -> Transform3D:
	var twists: Dictionary[StringName, float] = _twists(sk)
	var clip: Dictionary[StringName, Transform3D] = {}
	for bone_name: StringName in SPINE_SHARE:
		clip[bone_name] = sk.get_bone_global_pose(_id(sk, bone_name))
	var m: Transform3D = hips_moved(sk)
	for bone_name: StringName in SPINE_SHARE:
		var share: float = SPINE_SHARE[bone_name]
		var at: Vector3 = (m * clip[bone_name]).origin
		var yaw: float = spine_yaw * share - untwist * twists[bone_name]
		if absf(yaw) > 1e-5:
			m = about(at, Quaternion(Vector3.UP, yaw)) * m
		var b: Basis = (m * clip[bone_name]).basis.orthonormalized()
		if absf(spine_pitch) > 1e-5:
			m = about(at, Quaternion(b.x, spine_pitch * share)) * m
		if absf(spine_roll) > 1e-5:
			m = about(at, Quaternion(b.z, spine_roll * share)) * m
	return m


## How this layer will move the hips, and the legs' joints on them, from the
## clip's pose: turned, leaned and moved, before the spine bends (see
## upper_body()).
func hips_moved(sk: Skeleton3D) -> Transform3D:
	var m: Transform3D = Transform3D.IDENTITY
	if absf(pelvis_yaw) > 1e-5:
		m = about(sk.get_bone_global_pose(_id(sk, &"Hips")).origin, Quaternion(Vector3.UP, pelvis_yaw)) * m
	if lean.length() > 1e-5:
		m = about(sk.get_bone_global_pose(_id(sk, &"Root")).origin, Quaternion(lean.normalized(), lean.length())) * m
	return Transform3D(Basis.IDENTITY, hips_offset - _carry(sk)) * m


## The part of `carried` across the ground, in skeleton space.
func _carry(sk: Skeleton3D) -> Vector3:
	if carried == Vector3.ZERO:
		return Vector3.ZERO
	var v: Vector3 = sk.get_bone_global_rest(_id(sk, &"Root")).basis.get_rotation_quaternion() * carried
	return Vector3(v.x, 0.0, v.z)


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var twists: Dictionary[StringName, float] = _twists(sk)
	if absf(pelvis_yaw) > 1e-5:
		rot_global(sk, _id(sk, &"Hips"), Quaternion(Vector3.UP, pelvis_yaw))
	if absf(thigh_yaw) > 1e-5:
		for thigh: StringName in [&"LeftUpperLeg", &"RightUpperLeg"]:
			rot_global(sk, _id(sk, thigh), Quaternion(Vector3.UP, thigh_yaw))
	for side: String in ["Right", "Left"]:
		clip_hips[side] = sk.get_bone_global_pose(_id(sk, StringName(side + "UpperLeg"))).origin
		clip_knees[side] = sk.get_bone_global_pose(_id(sk, StringName(side + "LowerLeg"))).origin
		clip_feet[side] = sk.get_bone_global_pose(_id(sk, StringName(side + "Foot")))
	if lean.length() > 1e-5:
		rot_global(sk, _id(sk, &"Root"), Quaternion(lean.normalized(), lean.length()))
	var shift: Vector3 = hips_offset - _carry(sk)
	if shift != Vector3.ZERO:
		var hips: int = _id(sk, &"Hips")
		var root_q: Quaternion = sk.get_bone_global_pose(_id(sk, &"Root")).basis.get_rotation_quaternion()
		sk.set_bone_pose_position(hips, sk.get_bone_pose_position(hips) + root_q.inverse() * shift)
	for bone_name: StringName in SPINE_SHARE:
		var bone: int = _id(sk, bone_name)
		var share: float = SPINE_SHARE[bone_name]
		var yaw: float = spine_yaw * share - untwist * twists[bone_name]
		if absf(yaw) > 1e-5:
			rot_global(sk, bone, Quaternion(Vector3.UP, yaw))
		var b: Basis = sk.get_bone_global_pose(bone).basis.orthonormalized()
		if absf(spine_pitch) > 1e-5:
			rot_global(sk, bone, Quaternion(b.x, spine_pitch * share))
		if absf(spine_roll) > 1e-5:
			rot_global(sk, bone, Quaternion(b.z, spine_roll * share))
	for bone_name: StringName in HEAD_SHARE:
		var bone: int = _id(sk, bone_name)
		var share: float = HEAD_SHARE[bone_name]
		var yaw: float = head_yaw * share - untwist * twists[bone_name]
		if absf(yaw) > 1e-5:
			rot_global(sk, bone, Quaternion(Vector3.UP, yaw))
		if absf(head_pitch) > 1e-5:
			var b: Basis = sk.get_bone_global_pose(bone).basis.orthonormalized()
			rot_global(sk, bone, Quaternion(b.x, head_pitch * share))


## Each bone of TWIST_CHAIN's twist from the bone before it (radians, by
## name; the hips' is 0), in the pose the skeleton holds now. All 0 when
## nothing is untwisted.
func _twists(sk: Skeleton3D) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	var before: float = 0.0
	for i: int in TWIST_CHAIN.size():
		var bone_name: StringName = TWIST_CHAIN[i]
		out[bone_name] = 0.0
		if absf(untwist) > 1e-5:
			var bone: int = _id(sk, bone_name)
			var turn: float = heading(sk, bone, sk.get_bone_global_pose(bone))
			if i > 0:
				out[bone_name] = wrapf(turn - before, -PI, PI)
			before = turn
	return out


## Turning by `q` about the point `at`.
static func about(at: Vector3, q: Quaternion) -> Transform3D:
	return Transform3D(Basis.IDENTITY, at) * Transform3D(Basis(q), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -at)


func _id(sk: Skeleton3D, bone_name: StringName) -> int:
	if not _ids.has(bone_name):
		_ids[bone_name] = sk.find_bone(bone_name)
	return _ids[bone_name]
