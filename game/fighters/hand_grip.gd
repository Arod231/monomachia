class_name HandGrip
extends SkeletonModifier3D
## Closes a fighter's hands into fists around a weapon's handle, whatever the
## playing clip does with the fingers, and sets the wrists the weapon's hold
## asks for (see WeaponHold). FighterRig adds one to the skeleton, after the
## IK, turns a hand on when it holds a weapon, and sets a wrist only for a
## hand that carries its weapon: where the IK places a hand, the rig has
## already turned it onto the handle.
##
## The fist is fitted to the handle. The handle (of radius `grip_radius`,
## from the weapon's look) lies across the hand at the base of the fingers,
## against the palm: fist() is its centre and frame. Each finger is curled
## joint by joint so that its joints and its tip lie a finger's half
## thickness off the handle all the way round (wrap_curls()). The hand is
## measured from the skeleton's rest pose (measure()), so a larger hand
## closes on the same handle with more curl, and a thick handle opens the
## fist.
##
## After retargeting, a hand bone's +Y runs from the wrist to the knuckles
## and +Z comes out of the palm; +X points to the thumb on the right hand and
## away from it on the left. Each finger bone's +Y runs along the finger, so
## turning it about its own +X curls it toward the palm. The fingers and the
## wrist are set from the rest pose, so they don't depend on the clip.

const SIDES: Array[String] = ["Right", "Left"]
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Little"]
const SEGMENTS: Array[String] = ["Proximal", "Intermediate", "Distal"]
## The fist's frame in hand-bone space: +Y out of the thumb side (along the
## handle), +X out of the knuckles, and +Z into the palm (right) or out of it
## (left). A weapon held straight has its origin and axes here (see
## WeaponLook).
const FIST_BASIS: Dictionary[String, Basis] = {
	"Right": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
	"Left": Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)),
}
## Where the handle's centre lies along the hand, under the base of the
## fingers, as a fraction of the hand's length (the wrist to the middle
## knuckle).
const FIST_ALONG: float = 0.81
## The palm's skin at the base of the fingers, out of the hand bone's plane,
## and a finger's half thickness, as fractions of the hand's length (1.4 and
## 0.8 cm on the Rogue).
const PALM_OUT: float = 0.164
const FINGER_HALF: float = 0.092
## The thumb swings across the front of the handle (degrees), then bends at
## its two joints in this proportion, as far as it takes to bring its tip
## onto the handle (thumb_scale()). 36 since KE task 3: at 30 the Hunter's
## larger thumb curled past the Katana's handle 1.1 cm short of it.
const THUMB_SWING: float = 36.0
const THUMB_CURL: Dictionary[String, float] = {"Proximal": 28.0, "Distal": 38.0}
## The most the thumb's bend is scaled by, and the step its search takes.
const THUMB_SCALE_MAX: float = 3.0
const THUMB_SCALE_STEP: float = 0.02

@export var right_hand: bool = false
@export var left_hand: bool = false
## The radius of the handle the hands close on, in metres (see
## WeaponLook.grip_radius).
@export var grip_radius: float = 0.015:
	set(value):
		grip_radius = value
		_curls.clear()

## Wrist rotations from straight, by side ("Right", "Left"); a side that
## isn't here keeps the clip's wrist.
var wrists: Dictionary[String, Quaternion] = {}

var _ids: Dictionary[String, int] = {}
## Each hand's length, by side.
var _hand_length: Dictionary[String, float] = {}
## Each finger at rest, by side and finger ("RightIndex"), in the hand's
## curl plane (along the hand, out of the palm): [its knuckle, the lengths
## of its three segments, their rest directions].
var _fingers: Dictionary[String, Array] = {}
## Each finger's three curls (radians) for the current grip_radius, and
## each thumb's bend scale ("RightThumb").
var _curls: Dictionary[String, PackedFloat32Array] = {}
## Each thumb at rest, by side: the rest transforms of its metacarpal,
## proximal and distal bones (each in its parent's space; the metacarpal in
## the hand's) and its tip's position in the distal bone.
var _thumbs: Dictionary[String, Array] = {}


## Measures the hands from the skeleton's rest pose. FighterRig calls it on
## installing the grip; otherwise the first update does.
func measure(sk: Skeleton3D) -> void:
	_curls.clear()
	for side: String in SIDES:
		var hand_inv: Transform3D = sk.get_bone_global_rest(_id(sk, side + "Hand")).affine_inverse()
		_hand_length[side] = sk.get_bone_rest(_id(sk, side + "MiddleProximal")).origin.y
		for finger: String in FINGERS:
			# The knuckle, the two finger joints and the tip (the distal
			# bone's child, or past the distal joint).
			var points: Array[Vector2] = []
			var bone: int = _id(sk, side + finger + "Proximal")
			while bone >= 0 and points.size() < 4:
				var p: Vector3 = hand_inv * sk.get_bone_global_rest(bone).origin
				points.append(Vector2(p.y, p.z))
				var children: PackedInt32Array = sk.get_bone_children(bone)
				bone = children[0] if not children.is_empty() else -1
			if points.size() == 3:
				points.append(points[2] + (points[2] - points[1]) * 0.8)
			var lengths: PackedFloat32Array = PackedFloat32Array()
			var dirs: Array[Vector2] = []
			for i: int in 3:
				lengths.append(points[i].distance_to(points[i + 1]))
				dirs.append((points[i + 1] - points[i]).normalized())
			_fingers[side + finger] = [points[0], lengths, dirs]
		var thumb: Array = []
		for segment: String in ["Metacarpal", "Proximal", "Distal"]:
			thumb.append(sk.get_bone_rest(_id(sk, side + "Thumb" + segment)))
		var tips: PackedInt32Array = sk.get_bone_children(_id(sk, side + "ThumbDistal"))
		thumb.append(sk.get_bone_rest(tips[0]).origin if not tips.is_empty() else (thumb[2] as Transform3D).origin)
		_thumbs[side] = thumb


## A hand's fist for the current grip_radius, in hand-bone space: the
## handle's centre and frame (see FIST_BASIS).
func fist(side: String) -> Transform3D:
	var hand: float = _hand_length[side]
	return Transform3D(FIST_BASIS[side], Vector3(0.0, FIST_ALONG * hand, PALM_OUT * hand + grip_radius))


## The curls (radians, about each bone's +X) that wrap a finger round a
## handle, in the hand's curl plane (x along the hand, y out of the palm):
## from its knuckle, each joint and then the tip is put on the circle of
## `radius` round `centre`, one segment length on from the joint before,
## going round the handle the way fingers curl. `rest_dirs` are the
## segments' directions at rest. A joint that can't reach the circle points
## straight at its centre.
static func wrap_curls(knuckle: Vector2, lengths: PackedFloat32Array, rest_dirs: Array[Vector2],
		centre: Vector2, radius: float) -> PackedFloat32Array:
	var curls: PackedFloat32Array = PackedFloat32Array()
	var at: Vector2 = knuckle
	var turned: float = 0.0
	for i: int in 3:
		var next: Vector2 = _round_handle(at, lengths[i], centre, radius)
		# The segment's turn from rest, less what the joints before it have
		# turned it, taken the short way: a finger wraps more than half a
		# turn in all.
		var curl: float = wrapf(rest_dirs[i].angle_to(next - at) - turned, -PI, PI)
		curls.append(curl)
		turned += curl
		at = next
	return curls


## The point `length` from `at` on the circle of `radius` round `centre`,
## the nearer one round the circle the way fingers curl (counter-clockwise
## in the curl plane).
static func _round_handle(at: Vector2, length: float, centre: Vector2, radius: float) -> Vector2:
	var d: float = at.distance_to(centre)
	if d < 1e-6 or d > length + radius or d < absf(length - radius):
		return at + (centre - at).normalized() * length
	var along: float = (length * length - radius * radius + d * d) / (2.0 * d)
	var off: float = sqrt(maxf(length * length - along * along, 0.0))
	var u: Vector2 = (centre - at) / d
	var base: Vector2 = at + u * along
	var a: Vector2 = base + Vector2(-u.y, u.x) * off
	var b: Vector2 = base - Vector2(-u.y, u.x) * off
	var start: float = (at - centre).angle()
	var round_a: float = wrapf((a - centre).angle() - start, 0.0, TAU)
	var round_b: float = wrapf((b - centre).angle() - start, 0.0, TAU)
	return a if round_a < round_b else b


## How far a thumb bends round the current handle, as a scale on
## THUMB_CURL: the least bend that brings its tip a finger's half thickness
## off the handle, or, if none does, the bend that brings it nearest.
func thumb_scale(side: String) -> float:
	var hand: float = _hand_length[side]
	var centre: Vector2 = Vector2(FIST_ALONG * hand, PALM_OUT * hand + grip_radius)
	var target: float = grip_radius + FINGER_HALF * hand
	var best: float = 0.0
	var nearest: float = INF
	var bend: float = 0.0
	var last: float = INF
	while bend <= THUMB_SCALE_MAX:
		var tip: Vector3 = _thumb_tip(side, bend)
		var gap: float = Vector2(tip.y, tip.z).distance_to(centre) - target
		if gap <= 0.0:
			# Between this step and the last, where the tip meets the handle.
			return bend - THUMB_SCALE_STEP * gap / (gap - last) if last < INF else bend
		if gap < nearest:
			nearest = gap
			best = bend
		last = gap
		bend += THUMB_SCALE_STEP
	return best


## The thumb's tip in hand-bone space, swung across the handle and bent by
## `bend_scale` times THUMB_CURL.
func _thumb_tip(side: String, bend_scale: float) -> Vector3:
	var rest: Array = _thumbs[side]
	var swing: float = deg_to_rad(THUMB_SWING) * (-1.0 if side == "Right" else 1.0)
	var meta: Transform3D = rest[0]
	var xf: Transform3D = Transform3D(Basis(Quaternion(Vector3.UP, swing) * meta.basis.get_rotation_quaternion()), meta.origin)
	for segment: String in THUMB_CURL:
		var bone: Transform3D = rest[1 if segment == "Proximal" else 2]
		var turn: Quaternion = Quaternion(Vector3.RIGHT, deg_to_rad(THUMB_CURL[segment]) * bend_scale)
		xf = xf * Transform3D(Basis(bone.basis.get_rotation_quaternion() * turn), bone.origin)
	return xf * (rest[3] as Vector3)


## Sets a wrist (side "Right" or "Left") to `degrees` from straight (see
## WeaponHold.right_wrist).
func set_wrist(side: String, degrees: Vector3) -> void:
	wrists[side] = Quaternion.from_euler(degrees * (PI / 180.0))


func clear_wrists() -> void:
	wrists.clear()


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	if _hand_length.is_empty():
		measure(sk)
	for side: String in wrists:
		_set_from_rest(sk, side + "Hand", wrists[side])
	if right_hand:
		_close(sk, "Right")
	if left_hand:
		_close(sk, "Left")


func _close(sk: Skeleton3D, side: String) -> void:
	var hand: float = _hand_length[side]
	var centre: Vector2 = Vector2(FIST_ALONG * hand, PALM_OUT * hand + grip_radius)
	for finger: String in FINGERS:
		var key: String = side + finger
		if not _curls.has(key):
			var rest: Array = _fingers[key]
			_curls[key] = wrap_curls(rest[0], rest[1], rest[2], centre, grip_radius + FINGER_HALF * hand)
		for i: int in 3:
			_set_from_rest(sk, key + SEGMENTS[i], Quaternion(Vector3.RIGHT, _curls[key][i]))
	# The metacarpal swings about the hand's length (the hand bone's Y, in
	# the metacarpal's parent space) toward the palm. The hand's X points to
	# the thumb on the right hand and away from it on the left, so the turn is
	# mirrored.
	var swing: float = deg_to_rad(THUMB_SWING) * (-1.0 if side == "Right" else 1.0)
	_set_from_rest(sk, side + "ThumbMetacarpal", Quaternion(Vector3.UP, swing), true)
	var thumb: String = side + "Thumb"
	if not _curls.has(thumb):
		_curls[thumb] = PackedFloat32Array([thumb_scale(side)])
	for segment: String in THUMB_CURL:
		var bend: float = deg_to_rad(THUMB_CURL[segment]) * _curls[thumb][0]
		_set_from_rest(sk, thumb + segment, Quaternion(Vector3.RIGHT, bend))


## Sets a bone to its rest rotation turned by `turn`, in the bone's own
## space or, with `in_parent`, in its parent's.
func _set_from_rest(sk: Skeleton3D, bone_name: String, turn: Quaternion, in_parent: bool = false) -> void:
	var bone: int = _id(sk, bone_name)
	if bone < 0:
		return
	var rest: Quaternion = sk.get_bone_rest(bone).basis.get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone, turn * rest if in_parent else rest * turn)


func _id(sk: Skeleton3D, bone_name: String) -> int:
	if not _ids.has(bone_name):
		_ids[bone_name] = sk.find_bone(bone_name)
	return _ids[bone_name]
