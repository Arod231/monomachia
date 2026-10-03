class_name FighterRig
extends RefCounted
## The modifier stack that poses a fighter's body over its playing clip and
## puts its weapon in its hands: the production version of the animation
## spike's rig (docs/research/animation-spike). FighterModel installs one on
## its skeleton. In order, under the skeleton:
##
## 1. BodyLayer: the procedural body (lean, hips, spine, head);
## 2. RigPre: each gripping hand's frame on its handle, turned about it to
##    carry on the line of its forearm, which sets the wrist target, the
##    elbow poles, the clavicles near full reach, and the foot targets and
##    knee poles (the knees over the toes);
## 3. RightArmIK and LeftArmIK (TwoBoneIK3D: upper arm, forearm, hand), one
##    per arm so that each can be on or off;
## 4. LegIK (TwoBoneIK3D, both legs: thigh, shin, foot);
## 5. RigPost: each gripping hand turned to its frame, with part of the turn
##    taken by the forearm, and the feet laid flat at their yaw;
## 6. HandGrip: closes the holding hands' fingers, and sets the wrists of
##    hands that carry a weapon;
## 7. RigCarry: puts carried weapons in their hands.
##
## Skeleton space is the fighter's own frame: +Z forward, +X to the
## fighter's left, +Y up, metres from the ground.
##
## A held weapon is posed or carried:
## - posed (pose_weapon()): its transform in skeleton space is given, and
##   the arms reach for it on IK. The main hand grips the weapon's origin;
##   the off hand of a two-handed weapon grips its OffHandGrip marker; each
##   of a pair is in its own hand. The off hand of a one-handed weapon stays
##   free, on the clip.
## - carried (when attached, and after carry_weapons()): it follows its hand
##   as the clip moves it, set in the fist as the fighter's WeaponHold says,
##   with no IK. A stand-in until guard poses and swings place every weapon
##   (plan tasks 14 and 15).
##
## Arm and leg lengths and the fists are measured from each skeleton, so the
## Hunter's longer arms and larger hands are gripped right. Nothing carries
## over from one update to the next: the same inputs give the same pose.

const SIDES: Array[String] = ["Right", "Left"]

## How many times a gripping hand's turn about its handle is refined (see
## seat()): the wrist moves round the handle as the hand turns, and the
## elbow with it, so each pass starts from the last one's wrist.
const ROLL_PASSES: int = 4
## The share of a gripping hand's twist that its forearm takes. The skeleton
## has no twist bones, so a wrist twisted on its own would pinch.
const FOREARM_TWIST: float = 0.5
## The left elbow's pole from its shoulder, in the chest's frame and in arm
## lengths: out, down and back, so the elbows hang. The right is mirrored.
const ELBOW_POLE: Vector3 = Vector3(0.61, -1.12, -0.72)
## Near full reach the shoulder girdle swings toward the wrist target, so the
## arm doesn't lock straight: past CLAVICLE_START of the arm's length from
## the shoulder, by CLAVICLE_GAIN radians per metre further, up to
## CLAVICLE_MAX degrees.
const CLAVICLE_START: float = 0.9
const CLAVICLE_GAIN: float = 2.2
const CLAVICLE_MAX: float = 18.0

var skeleton: Skeleton3D
var body: BodyLayer
var hand_grip: HandGrip
## How far the arms of gripping hands follow the IK (1) rather than the
## clip (0).
var arm_weight: float = 1.0
## How far the legs follow the IK to the foot targets (1) rather than the
## clip (0).
var leg_weight: float = 0.0
## Each elbow's pole (see ELBOW_POLE), by side.
var elbow_pole: Dictionary[String, Vector3] = {
	"Right": Vector3(-ELBOW_POLE.x, ELBOW_POLE.y, ELBOW_POLE.z),
	"Left": ELBOW_POLE,
}
## A tweak added to each elbow's pole, by side: in skeleton space (not
## turned with the chest) and in arm lengths, as a swing's key holds it
## (SwingPlayer). None by default.
var pole_tweak: Dictionary[String, Vector3] = {"Right": Vector3.ZERO, "Left": Vector3.ZERO}
## The foot targets, by side: where the foot bone (the ankle) goes, in
## skeleton space, and the foot's turn from straight ahead (radians,
## positive to the left). They start where the rest pose has them. Each
## knee bends over its toes: its pole is ahead of the leg, on the plane
## through the hip, the ankle and the way the toes point.
var foot_position: Dictionary[String, Vector3] = {}
var foot_yaw: Dictionary[String, float] = {"Right": 0.0, "Left": 0.0}
## How far the leg IK keeps each foot where the clip put it, turned as the
## clip turned it, with the knee bent the way the clip bends it (1), rather
## than on the foot targets (0): the body layer can drop the hips into a
## crouch over the clip's planted feet.
var clip_feet: float = 0.0

var _arm_ik: Dictionary[String, TwoBoneIK3D] = {}
var _leg_ik: TwoBoneIK3D
var _markers: Dictionary[String, Node3D] = {}
var _arm_length: Dictionary[String, float] = {}
## Each arm's upper arm and forearm: shoulder to elbow and elbow to wrist.
var _upper_arm: Dictionary[String, float] = {}
var _forearm: Dictionary[String, float] = {}
var _leg_length: Dictionary[String, float] = {}
var _foot_rest: Dictionary[String, Quaternion] = {}
var _ids: Dictionary[String, int] = {}

var _look: WeaponLook
var _weapons: Array[Node3D] = []
var _posed: Array[bool] = []
var _poses: Array[Transform3D] = []
var _hold: WeaponHold
## The hand frames being reached in the current update, by side.
var _frames: Dictionary[String, Transform3D] = {}


## Installs the stack on `sk`, after any modifiers it already has.
func _init(sk: Skeleton3D) -> void:
	skeleton = sk
	hand_grip = HandGrip.new()
	hand_grip.name = &"HandGrip"
	hand_grip.measure(sk)
	for side: String in SIDES:
		_upper_arm[side] = _rest_origin(side + "UpperArm").distance_to(_rest_origin(side + "LowerArm"))
		_forearm[side] = _rest_origin(side + "LowerArm").distance_to(_rest_origin(side + "Hand"))
		_arm_length[side] = _upper_arm[side] + _forearm[side]
		_leg_length[side] = _rest_origin(side + "UpperLeg").distance_to(_rest_origin(side + "LowerLeg")) \
			+ _rest_origin(side + "LowerLeg").distance_to(_rest_origin(side + "Foot"))
		_foot_rest[side] = sk.get_bone_global_rest(_id(side + "Foot")).basis.get_rotation_quaternion()
		foot_position[side] = _rest_origin(side + "Foot")
		for marker: String in ["HandTarget", "ElbowPole", "FootTarget", "KneePole"]:
			var m: Node3D = Node3D.new()
			m.name = side + marker
			sk.add_child(m)
			_markers[side + marker] = m
	body = BodyLayer.new()
	body.name = &"BodyLayer"
	sk.add_child(body)
	_add_callback(&"RigPre", _pre)
	for side: String in SIDES:
		_arm_ik[side] = _add_ik(side + "ArmIK", [side], ["UpperArm", "LowerArm", "Hand"], "HandTarget", "ElbowPole")
	_leg_ik = _add_ik("LegIK", SIDES, ["UpperLeg", "LowerLeg", "Foot"], "FootTarget", "KneePole")
	_add_callback(&"RigPost", _post)
	sk.add_child(hand_grip)
	_add_callback(&"RigCarry", _carry)


## A weapon's transform in skeleton space from its main grip point, the way
## its blade points and the way its edge faces (made square to the blade).
static func weapon_frame(grip: Vector3, blade: Vector3, edge: Vector3) -> Transform3D:
	var y: Vector3 = blade.normalized()
	var x: Vector3 = (edge - y * edge.dot(y)).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), grip)


## Where a two-bone limb's middle joint goes when its end reaches `wrist`
## from `shoulder`, with bones `upper` and `lower` long, bent toward `pole`:
## in the plane of the three, on the pole's side (as the arms' and legs'
## TwoBoneIK3D bend them). A wrist out of reach is taken as far as the limb
## goes.
static func elbow_at(shoulder: Vector3, wrist: Vector3, pole: Vector3, upper: float, lower: float) -> Vector3:
	var to: Vector3 = wrist - shoulder
	var d: float = clampf(to.length(), absf(upper - lower) + 1e-4, upper + lower - 1e-4)
	var along: Vector3 = to.normalized()
	var toward: Vector3 = pole - shoulder
	var side: Vector3 = (toward - along * toward.dot(along)).normalized()
	var a: float = (upper * upper + d * d - lower * lower) / (2.0 * d)
	return shoulder + along * a + side * sqrt(maxf(upper * upper - a * a, 0.0))


## The fist of a hand ("Right" or "Left") round the held handle, in
## hand-bone space (see HandGrip.fist()).
func fist(side: String) -> Transform3D:
	return hand_grip.fist(side)


## An arm's length, shoulder to wrist, in the rest pose.
func arm_length(side: String) -> float:
	return _arm_length[side]


func leg_length(side: String) -> float:
	return _leg_length[side]


## Where a foot bone (the ankle) is in the rest pose.
func rest_foot(side: String) -> Vector3:
	return _rest_origin(side + "Foot")


## Puts a weapon's instances in the hands (one, or two for a pair, made from
## `look`), carried as `hold` says (null: straight in the fist) until posed.
func hold_weapons(look: WeaponLook, instances: Array[Node3D], hold: WeaponHold) -> void:
	_look = look
	_weapons = instances.duplicate()
	_hold = hold
	if look != null:
		hand_grip.grip_radius = look.grip_radius
	_posed.clear()
	_poses.clear()
	for w: Node3D in _weapons:
		_posed.append(false)
		_poses.append(Transform3D.IDENTITY)
	_update_hands()


## Lets go of the weapons.
func release_weapons() -> void:
	hold_weapons(null, [], null)


## Poses held weapon `index` at `xf` in skeleton space (see weapon_frame()):
## the hands that grip it reach for it on IK.
func pose_weapon(index: int, xf: Transform3D) -> void:
	_posed[index] = true
	_poses[index] = xf
	_weapons[index].transform = xf
	_update_hands()


## Lets every held weapon follow its hand again, as carried.
func carry_weapons() -> void:
	for i: int in _posed.size():
		_posed[i] = false
	_update_hands()


func is_posed(index: int) -> bool:
	return index < _posed.size() and _posed[index]


## True when the hand grips a weapon, posed or carried.
func holds(side: String) -> bool:
	return drives(side) or _carried_index(side) >= 0


## True when the IK places this arm: the hand grips a posed weapon.
func drives(side: String) -> bool:
	var grip: Array = _grip(side)
	return not grip.is_empty() and _posed[grip[0]]


## Where the hand's grip centre should be, in skeleton space: the point it
## grips on its posed weapon. Only for a hand that drives().
func grip_point(side: String) -> Vector3:
	var grip: Array = _grip(side)
	return _poses[grip[0]] * (grip[1] as Vector3)


## The hand frame (the hand bone's transform in skeleton space) that seats a
## hand on its posed weapon's grip point: the one its arm reached for in the
## last update or, before the first, the one it would reach for from the
## clip's pose. Only for a hand that drives().
func hand_frame(side: String) -> Transform3D:
	if _frames.has(side):
		return _frames[side]
	var grip: Array = _grip(side)
	var chest: Basis = skeleton.get_bone_global_pose(_id("UpperChest")).basis.orthonormalized()
	return seat(side, _poses[grip[0]], grip[1], _origin(skeleton, side + "UpperArm"), chest)


## The hand frame that seats a hand on `point` (in weapon space) of a weapon
## posed at `weapon_xf`, for an arm whose shoulder is at `shoulder` with the
## chest turned `chest` (in skeleton space): the fist round the handle there,
## turned about the handle so that the hand carries on the line of its
## forearm, from the elbow the arm's IK will bend toward its pole
## (elbow_at()). The wrist then neither bends back nor forward, however the
## blade points; how far it turns sideways is up to the guard.
func seat(side: String, weapon_xf: Transform3D, point: Vector3, shoulder: Vector3, chest: Basis) -> Transform3D:
	var pole: Vector3 = _pole(side, shoulder, chest)
	var to_weapon: Basis = weapon_xf.basis.inverse()
	var wrist: Vector3 = weapon_xf * point
	var frame: Transform3D = Transform3D.IDENTITY
	for i: int in ROLL_PASSES:
		var elbow: Vector3 = elbow_at(shoulder, wrist, pole, _upper_arm[side], _forearm[side])
		# The forearm's way in the weapon's frame. The hand's +Y (to the
		# knuckles) is the weapon's +X (the edge) turned `roll` about the
		# handle (+Y).
		var forearm: Vector3 = to_weapon * (wrist - elbow)
		var roll: float = atan2(-forearm.z, forearm.x)
		frame = weapon_xf * Transform3D(Basis(Vector3.UP, roll), point) * hand_grip.fist(side).affine_inverse()
		wrist = frame.origin
	return frame


## The hands that grip held weapon `index` when it is posed, each with the
## point it grips, in weapon space.
func grips_on(index: int) -> Dictionary[String, Vector3]:
	var out: Dictionary[String, Vector3] = {}
	for side: String in SIDES:
		var grip: Array = _grip(side)
		if not grip.is_empty() and grip[0] == index:
			out[side] = grip[1]
	return out


## [weapon index, grip point in weapon space] for a hand on a posed weapon:
## the main hand on the first weapon's origin, the off hand on the second of
## a pair or on a two-handed weapon's OffHandGrip. Empty when the hand has
## nothing to grip.
func _grip(side: String) -> Array:
	if _weapons.is_empty():
		return []
	if side == "Right":
		return [0, Vector3.ZERO]
	if _look.paired and _weapons.size() > 1:
		return [1, Vector3.ZERO]
	if _look.two_handed:
		var off: Marker3D = WeaponLook.marker(_weapons[0], WeaponLook.OFF_HAND_GRIP)
		if off != null:
			return [0, off.position]
	return []


## The weapon a hand carries (unposed), or -1: the main hand carries the
## first, the off hand the second of a pair.
func _carried_index(side: String) -> int:
	var index: int = 0 if side == "Right" else 1
	return index if index < _weapons.size() and not _posed[index] else -1


## Closes the holding hands, and sets the hold's wrists on the hands that
## carry a weapon (never on a hand the IK places).
func _update_hands() -> void:
	hand_grip.right_hand = holds("Right")
	hand_grip.left_hand = holds("Left")
	hand_grip.clear_wrists()
	if _carried_index("Right") >= 0 and _hold != null and _hold.set_right_wrist:
		hand_grip.set_wrist("Right", _hold.right_wrist)
	if _carried_index("Left") >= 0 and (_hold == null or _hold.set_left_wrist):
		hand_grip.set_wrist("Left", _hold.left_wrist if _hold != null else Vector3.ZERO)


func _pre(sk: Skeleton3D, _delta: float) -> void:
	_frames.clear()
	var chest: Basis = sk.get_bone_global_pose(_id("UpperChest")).basis.orthonormalized()
	for side: String in SIDES:
		var ik: TwoBoneIK3D = _arm_ik[side]
		ik.active = arm_weight > 0.001 and drives(side)
		ik.influence = clampf(arm_weight, 0.0, 1.0)
		if not ik.active:
			continue
		var shoulder: Vector3 = _origin(sk, side + "UpperArm")
		var grip: Array = _grip(side)
		var frame: Transform3D = seat(side, _poses[grip[0]], grip[1], shoulder, chest)
		_frames[side] = frame
		_markers[side + "HandTarget"].transform = frame
		var over: float = shoulder.distance_to(frame.origin) - CLAVICLE_START * _arm_length[side]
		if over > 0.0:
			var clavicle: int = _id(side + "Shoulder")
			var pivot: Vector3 = sk.get_bone_global_pose(clavicle).origin
			var axis: Vector3 = (shoulder - pivot).cross(frame.origin - pivot)
			if axis.length() > 1e-5:
				var angle: float = minf(over * CLAVICLE_GAIN, deg_to_rad(CLAVICLE_MAX)) * ik.influence
				BodyLayer.rot_global(sk, clavicle, Quaternion(axis.normalized(), angle))
				shoulder = _origin(sk, side + "UpperArm")
		_markers[side + "ElbowPole"].position = _pole(side, shoulder, chest)
	_leg_ik.active = leg_weight > 0.001
	_leg_ik.influence = clampf(leg_weight, 0.0, 1.0)
	if not _leg_ik.active:
		return
	var from_clip: float = clampf(clip_feet, 0.0, 1.0)
	for side: String in SIDES:
		# The knee over the toes: its pole ahead of the leg, on the plane
		# through the hip, the ankle and the way the toes point.
		var at: Vector3 = foot_position[side]
		var ahead: Vector3 = Vector3(sin(foot_yaw[side]), 0.0, cos(foot_yaw[side]))
		var pole: Vector3 = (_origin(sk, side + "UpperLeg") + at) * 0.5 + ahead * _leg_length[side]
		if from_clip > 0.0:
			# The foot where the clip has it, the knee bent the clip's way:
			# out from the line between the clip's hip and foot.
			var foot: Vector3 = body.clip_feet[side].origin
			var knee: Vector3 = body.clip_knees[side]
			var bend: Vector3 = knee - (body.clip_hips[side] + foot) * 0.5
			if bend.length() < 0.01:
				bend = body.clip_feet[side].basis.y
			at = at.lerp(foot, from_clip)
			pole = pole.lerp(knee + bend.normalized() * _leg_length[side], from_clip)
		_markers[side + "FootTarget"].position = at
		_markers[side + "KneePole"].position = pole


func _post(sk: Skeleton3D, _delta: float) -> void:
	for side: String in _frames:
		var weight: float = _arm_ik[side].influence
		var hand: int = _id(side + "Hand")
		var lower: int = _id(side + "LowerArm")
		var want: Quaternion = _frames[side].basis.get_rotation_quaternion()
		# The forearm takes part of the hand's twist about it, turning about
		# the line from the elbow to the wrist so the wrist stays put.
		var lower_pose: Transform3D = sk.get_bone_global_pose(lower)
		var twist: float = _twist(lower_pose.basis.get_rotation_quaternion().inverse() * want) \
			- _twist(sk.get_bone_rest(hand).basis.get_rotation_quaternion())
		var axis: Vector3 = (sk.get_bone_global_pose(hand).origin - lower_pose.origin).normalized()
		BodyLayer.rot_global(sk, lower, Quaternion(axis, wrapf(twist, -PI, PI) * FOREARM_TWIST * weight))
		var now: Quaternion = sk.get_bone_global_pose(hand).basis.get_rotation_quaternion()
		BodyLayer.rot_global(sk, hand, now.slerp(want, weight) * now.inverse())
	if _leg_ik.active:
		for side: String in SIDES:
			var foot: int = _id(side + "Foot")
			var now: Quaternion = sk.get_bone_global_pose(foot).basis.get_rotation_quaternion()
			var want: Quaternion = Quaternion(Vector3.UP, foot_yaw[side]) * _foot_rest[side]
			if clip_feet > 0.0:
				want = want.slerp(body.clip_feet[side].basis.get_rotation_quaternion(), clampf(clip_feet, 0.0, 1.0))
			BodyLayer.rot_global(sk, foot, now.slerp(want, _leg_ik.influence) * now.inverse())


## Puts each carried weapon in its hand's fist, turned by the hold's grip.
func _carry(sk: Skeleton3D, _delta: float) -> void:
	var grip: Transform3D = _hold.grip_transform() if _hold != null else Transform3D.IDENTITY
	for side: String in SIDES:
		var index: int = _carried_index(side)
		if index >= 0:
			_weapons[index].transform = sk.get_bone_global_pose(_id(side + "Hand")) * hand_grip.fist(side) * grip


## Sets every elbow's pole tweak back to none.
func clear_pole_tweaks() -> void:
	for side: String in SIDES:
		pole_tweak[side] = Vector3.ZERO


## Where an arm's elbow pole is, for its shoulder at `shoulder` with the
## chest turned `chest` (see ELBOW_POLE), plus its tweak (pole_tweak).
func _pole(side: String, shoulder: Vector3, chest: Basis) -> Vector3:
	return shoulder + (chest * elbow_pole[side] + pole_tweak[side]) * _arm_length[side]


## The turn of a rotation about its own +Y (radians).
static func _twist(q: Quaternion) -> float:
	return 2.0 * atan2(q.y, q.w)


func _add_callback(node_name: StringName, callback: Callable) -> void:
	var node: RigCallback = RigCallback.new()
	node.name = node_name
	node.callback = callback
	skeleton.add_child(node)


## A TwoBoneIK3D with one chain per side, each reaching for its side's
## target marker, bent toward its pole marker.
func _add_ik(node_name: String, sides: Array[String], chain: Array[String], target: String, pole: String) -> TwoBoneIK3D:
	var ik: TwoBoneIK3D = TwoBoneIK3D.new()
	ik.name = node_name
	skeleton.add_child(ik)
	ik.setting_count = sides.size()
	for i: int in sides.size():
		var side: String = sides[i]
		ik.set_root_bone_name(i, side + chain[0])
		ik.set_middle_bone_name(i, side + chain[1])
		ik.set_end_bone_name(i, side + chain[2])
		ik.set_target_node(i, ik.get_path_to(_markers[side + target]))
		ik.set_pole_node(i, ik.get_path_to(_markers[side + pole]))
		ik.set_pole_direction(i, SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Z)
	ik.active = false
	return ik


func _origin(sk: Skeleton3D, bone_name: String) -> Vector3:
	return sk.get_bone_global_pose(_id(bone_name)).origin


func _rest_origin(bone_name: String) -> Vector3:
	return skeleton.get_bone_global_rest(_id(bone_name)).origin


func _id(bone_name: String) -> int:
	if not _ids.has(bone_name):
		_ids[bone_name] = skeleton.find_bone(bone_name)
	return _ids[bone_name]
