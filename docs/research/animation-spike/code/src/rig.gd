extends RefCounted
# Weapon grip + stance rig. Adds, in this order, under the Skeleton3D (after the BodyLayer):
#   RigPre  (CB modifier): from the weapon transform, computes each hand's grip frame and wrist target,
#                          the elbow poles, the foot targets and knee poles; writes them to marker nodes.
#   ArmIK   (TwoBoneIK3D): UpperArm -> LowerArm -> Hand, both arms.
#   LegIK   (TwoBoneIK3D): UpperLeg -> LowerLeg -> Foot, both legs (off while the locomotion clips drive the legs).
#   RigPost (CB modifier): sets each hand's rotation to its grip frame, curls fingers around the handle,
#                          and lays the feet flat with their stance yaw.
# All inputs are in skeleton space (= fighter local space: +Z forward, +X left, +Y up).
const BodyLayer = preload("res://src/body_layer.gd")
const CB = preload("res://src/cb_modifier.gd")

const SIDES := {"R": "Right", "L": "Left"}

var sk: Skeleton3D
var arm_ik: TwoBoneIK3D
var leg_ik: TwoBoneIK3D
var mk := {}              # marker nodes

# --- inputs ---
var weapon_xf := Transform3D()   # katana frame in skeleton space (origin tsuba, +Y blade, +X edge)
var body: Object = null          # BodyLayer, for the animated foot poses
var walk_feet_w := 0.0           # 0 = stance feet, 1 = feet from the locomotion clip (crouched walk)
var arm_w := 1.0
var leg_w := 1.0
var hands := {"R": true, "L": true}
var grip_y := {"R": -0.058, "L": -0.196}          # grip centres along the handle (weapon local Y)
var palm := Vector3(0.0, 0.064, 0.026)            # grip centre in hand-bone space (Y = fingers, Z = palm normal)
var beta := deg_to_rad(28.0)                      # diagonal of the handle across the palm
var twist_share := 0.5                            # part of the wrist twist given to the forearm
var arm_len := 0.4895                             # upper arm + forearm (rest)
var gamma := {"R": deg_to_rad(25.0), "L": deg_to_rad(25.0)}                 # roll of each hand about the handle
var pole_off := {"R": Vector3(-0.30, -0.55, -0.35), "L": Vector3(0.30, -0.55, -0.35)}  # from each shoulder, chest space
var feet := {
	"R": {"pos": Vector3(-0.13, 0.0707, 0.20), "yaw": deg_to_rad(-8.0), "lift": 0.0},
	"L": {"pos": Vector3(0.15, 0.0707, -0.22), "yaw": deg_to_rad(32.0), "lift": 0.0},
}
var curl := {"Proximal": deg_to_rad(62.0), "Intermediate": deg_to_rad(88.0), "Distal": deg_to_rad(48.0)}

# --- outputs / debug ---
var hand_q := {}
var wrist_target := {}
var ids := {}
var foot_rest_q := {}

func _id(n: String) -> int:
	if not ids.has(n):
		ids[n] = sk.find_bone(n)
	return ids[n]

func setup(skeleton: Skeleton3D, pole_dir_arm: int = SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Z, pole_dir_leg: int = SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Z) -> void:
	sk = skeleton
	for s in SIDES:
		for n in ["hand", "elbow", "foot", "knee"]:
			var m := Node3D.new()
			m.name = s + "_" + n
			sk.add_child(m)
			mk[s + n] = m
		foot_rest_q[s] = sk.get_bone_global_rest(_id(SIDES[s] + "Foot")).basis.get_rotation_quaternion()
	var pre := CB.new()
	pre.name = "RigPre"
	pre.callback = _pre
	sk.add_child(pre)
	arm_ik = _make_ik("ArmIK", ["UpperArm", "LowerArm", "Hand"], "hand", "elbow", pole_dir_arm)
	leg_ik = _make_ik("LegIK", ["UpperLeg", "LowerLeg", "Foot"], "foot", "knee", pole_dir_leg)
	var post := CB.new()
	post.name = "RigPost"
	post.callback = _post
	sk.add_child(post)

func _make_ik(nm: String, chain: Array, tgt: String, pole: String, pole_dir: int) -> TwoBoneIK3D:
	var ik := TwoBoneIK3D.new()
	ik.name = nm
	sk.add_child(ik)
	ik.setting_count = 2
	var i := 0
	for s in SIDES:
		ik.set_root_bone_name(i, SIDES[s] + chain[0])
		ik.set_middle_bone_name(i, SIDES[s] + chain[1])
		ik.set_end_bone_name(i, SIDES[s] + chain[2])
		ik.set_target_node(i, ik.get_path_to(mk[s + tgt]))
		ik.set_pole_node(i, ik.get_path_to(mk[s + pole]))
		ik.set_pole_direction(i, pole_dir)
		i += 1
	return ik

func _pre(_sk: Skeleton3D, _dt: float) -> void:
	arm_ik.influence = arm_w
	arm_ik.active = arm_w > 0.001
	leg_ik.influence = leg_w
	leg_ik.active = leg_w > 0.001
	var wb := weapon_xf.basis.orthonormalized()
	var wx := wb.x   # edge
	var wy := wb.y   # blade
	var wz := wb.z
	var chest := sk.get_bone_global_pose(_id("UpperChest")).basis.orthonormalized()
	for s in SIDES:
		var grip := weapon_xf * Vector3(0.0, grip_y[s], 0.0)
		var sh := sk.get_bone_global_pose(_id(SIDES[s] + "UpperArm")).origin
		# Grip frame fixed to the handle (hands don't slide on a real grip):
		# thumb toward the tip, metacarpals toward the edge, palm against the handle's side,
		# rolled by gamma about the handle and tilted by beta so the handle crosses the palm diagonally.
		var g: float = gamma[s]
		var n0 := (-wz if s == "R" else wz) * cos(g) + wx * sin(g)
		var f0 := n0.cross(wy) if s == "R" else wy.cross(n0)
		var t := wy * cos(beta) - f0 * sin(beta)
		var f := wy * sin(beta) + f0 * cos(beta)
		var n := n0
		var x := t if s == "R" else -t
		var b := Basis(x, f, n).orthonormalized()
		hand_q[s] = b.get_rotation_quaternion()
		wrist_target[s] = grip - b * palm
		(mk[s + "hand"] as Node3D).transform = Transform3D(b, wrist_target[s])
		# clavicle protraction: when the wrist target is near the limit of reach, swing the
		# shoulder girdle toward it (up to 18 deg) so the arm is not locked straight
		var cl := _id(SIDES[s] + "Shoulder")
		var cpiv := sk.get_bone_global_pose(cl).origin
		var over := sh.distance_to(wrist_target[s]) - 0.9 * arm_len
		if over > 0.0 and arm_w > 0.001:
			var axis := (sh - cpiv).cross(wrist_target[s] - cpiv)
			if axis.length() > 1e-5:
				BodyLayer.rot_global(sk, cl, Quaternion(axis.normalized(), clampf(over * 2.2, 0.0, deg_to_rad(18.0)) * arm_w))
				sh = sk.get_bone_global_pose(_id(SIDES[s] + "UpperArm")).origin
		(mk[s + "elbow"] as Node3D).position = sh + chest * pole_off[s]
		var ft: Dictionary = feet[s]
		var fp: Vector3 = ft.pos + Vector3(0.0, ft.lift, 0.0)
		var fwd := Vector3(sin(ft.yaw), 0.0, cos(ft.yaw))
		if walk_feet_w > 0.001 and body and body.feet_pose.has(s):
			var ap: Transform3D = body.feet_pose[s]
			fp = fp.lerp(ap.origin, walk_feet_w)
			var af := ap.basis.y
			af.y = 0.0
			if af.length() > 0.01:
				fwd = fwd.lerp(af.normalized(), walk_feet_w).normalized()
		(mk[s + "foot"] as Node3D).position = fp
		(mk[s + "knee"] as Node3D).position = fp + Vector3(0.0, 0.5, 0.0) + fwd * 0.7

func _post(_sk: Skeleton3D, _dt: float) -> void:
	if arm_w > 0.001:
		for s in SIDES:
			if not hands[s]:
				continue
			var hb := _id(SIDES[s] + "Hand")
			# share the wrist twist with the forearm (there are no twist bones): rotate the lower arm
			# about its own axis by part of the hand-vs-forearm twist, so the wrist does not candy-wrap
			var la := _id(SIDES[s] + "LowerArm")
			var lag := sk.get_bone_global_pose(la).basis.get_rotation_quaternion()
			var rel: Quaternion = lag.inverse() * hand_q[s]
			var r0 := sk.get_bone_rest(hb).basis.get_rotation_quaternion()
			if rel.w < 0.0:
				rel = -rel
			var tau := wrapf(2.0 * atan2(rel.y, rel.w) - 2.0 * atan2(r0.y, r0.w), -PI, PI)
			var fa_axis := (lag * Vector3.UP).normalized()
			BodyLayer.rot_global(sk, la, Quaternion(fa_axis, tau * twist_share * arm_w))
			var cur := sk.get_bone_global_pose(hb).basis.get_rotation_quaternion()
			var want: Quaternion = cur.slerp(hand_q[s], arm_w)
			BodyLayer.rot_global(sk, hb, want * cur.inverse())
			var hx := sk.get_bone_global_pose(hb).basis.x.normalized()
			for fing in ["Index", "Middle", "Ring", "Little"]:
				var spread := {"Index": 0.92, "Middle": 1.0, "Ring": 1.04, "Little": 1.1}[fing] as float
				for seg in ["Proximal", "Intermediate", "Distal"]:
					BodyLayer.rot_global(sk, _id(SIDES[s] + fing + seg), Quaternion(hx, curl[seg] * spread * arm_w))
			# thumb: swing across the front of the handle, then bend
			var hb2 := sk.get_bone_global_pose(hb).basis.orthonormalized()
			var swing_axis := hb2.y.normalized() * (-1.0 if s == "R" else 1.0)
			BodyLayer.rot_global(sk, _id(SIDES[s] + "ThumbMetacarpal"), Quaternion(swing_axis, deg_to_rad(28.0) * arm_w))
			BodyLayer.rot_global(sk, _id(SIDES[s] + "ThumbProximal"), Quaternion(hx, deg_to_rad(25.0) * arm_w))
			BodyLayer.rot_global(sk, _id(SIDES[s] + "ThumbDistal"), Quaternion(hx, deg_to_rad(30.0) * arm_w))
	if leg_w > 0.001:
		for s in SIDES:
			var fb := _id(SIDES[s] + "Foot")
			var cur := sk.get_bone_global_pose(fb).basis.get_rotation_quaternion()
			var want: Quaternion = Quaternion(Vector3.UP, feet[s].yaw) * foot_rest_q[s]
			if walk_feet_w > 0.001 and body and body.feet_pose.has(s):
				want = want.slerp((body.feet_pose[s] as Transform3D).basis.get_rotation_quaternion(), walk_feet_w)
			BodyLayer.rot_global(sk, fb, cur.slerp(want, leg_w) * cur.inverse())
	last_debug = _debug_now()

var last_debug := ""
func debug_errors() -> String:
	return last_debug

func _debug_now() -> String:
	var out := ""
	for s in SIDES:
		var w := sk.get_bone_global_pose(_id(SIDES[s] + "Hand")).origin
		out += "%s wrist err %.3f  " % [s, w.distance_to(wrist_target[s])]
		var fpos := sk.get_bone_global_pose(_id(SIDES[s] + "Foot")).origin
		out += "%s foot y %.3f  " % [s, fpos.y]
	return out
