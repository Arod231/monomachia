extends SkeletonModifier3D
# Procedural body layer. Runs AFTER the AnimationTree has posed the skeleton and BEFORE the arm IK.
# Everything is expressed in skeleton space (= fighter local space: +Z forward, +X left, +Y up).
# Rotations are applied parent-first as pre-multiplied global rotations, so each one is easy to reason about.

var pelvis_yaw := 0.0      # turn hips (and everything below the spine) about vertical, + = left
var thigh_yaw := 0.0       # extra turn of both legs at the hip joints
var spine_yaw := 0.0       # total yaw spread over Spine/Chest/UpperChest (usually cancels pelvis_yaw)
var spine_pitch := 0.0     # forward bend spread over the spine, + = forward
var spine_roll := 0.0      # side bend, + = top leans to the fighter's right
var head_yaw := 0.0        # spread over Neck/Head, keeps the eyes on the opponent
var head_pitch := 0.0
var hips_offset := Vector3.ZERO   # pelvis translation (dip, shift), skeleton space
var lean := Vector3.ZERO          # rotation vector about the Root bone (ground pivot): lean into acceleration

var feet_pose := {}       # animated foot transforms after the hip/leg turn, before the pelvis drop (for crouched walking)

var _ids := {}

func _id(n: String) -> int:
	if not _ids.has(n):
		_ids[n] = get_skeleton().find_bone(n)
	return _ids[n]

static func rot_global(sk: Skeleton3D, bone: int, q: Quaternion) -> void:
	# new_global = q * old_global  =>  new_local = parent_global^-1 * q * parent_global * local
	var p := sk.get_bone_parent(bone)
	var pg := Quaternion.IDENTITY
	if p >= 0:
		pg = sk.get_bone_global_pose(p).basis.get_rotation_quaternion()
	var local := sk.get_bone_pose_rotation(bone)
	sk.set_bone_pose_rotation(bone, (pg.inverse() * q * pg * local).normalized())

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var up := Vector3.UP
	if lean.length() > 1e-5:
		rot_global(sk, _id("Root"), Quaternion(lean.normalized(), lean.length()))
	if absf(pelvis_yaw) > 1e-5:
		rot_global(sk, _id("Hips"), Quaternion(up, pelvis_yaw))
	if absf(thigh_yaw) > 1e-5:
		rot_global(sk, _id("LeftUpperLeg"), Quaternion(up, thigh_yaw))
		rot_global(sk, _id("RightUpperLeg"), Quaternion(up, thigh_yaw))
	feet_pose["R"] = sk.get_bone_global_pose(_id("RightFoot"))
	feet_pose["L"] = sk.get_bone_global_pose(_id("LeftFoot"))
	if hips_offset != Vector3.ZERO:
		var root_q := sk.get_bone_global_pose(_id("Root")).basis.get_rotation_quaternion()
		sk.set_bone_pose_position(_id("Hips"), sk.get_bone_pose_position(_id("Hips")) + root_q.inverse() * hips_offset)
	var chain := [["Spine", 0.28], ["Chest", 0.36], ["UpperChest", 0.36]]
	for c in chain:
		var b := _id(c[0])
		var w: float = c[1]
		if absf(spine_yaw) > 1e-5:
			rot_global(sk, b, Quaternion(up, spine_yaw * w))
		var bb := sk.get_bone_global_pose(b).basis.orthonormalized()
		if absf(spine_pitch) > 1e-5:
			rot_global(sk, b, Quaternion(bb.x.normalized(), spine_pitch * w))
		if absf(spine_roll) > 1e-5:
			rot_global(sk, b, Quaternion(bb.z.normalized(), spine_roll * w))
	for c in [["Neck", 0.45], ["Head", 0.55]]:
		var b := _id(c[0])
		var w: float = c[1]
		if absf(head_yaw) > 1e-5:
			rot_global(sk, b, Quaternion(up, head_yaw * w))
		if absf(head_pitch) > 1e-5:
			var bb := sk.get_bone_global_pose(b).basis.orthonormalized()
			rot_global(sk, b, Quaternion(bb.x.normalized(), head_pitch * w))
