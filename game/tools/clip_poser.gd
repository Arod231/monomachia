class_name ClipPoser
extends RefCounted
## Poses a fighter with a clip, or a chain of clips played one after
## another, at any time, and reads its parts in the fighter's own (right,
## up, forward) frame: the sampled clip SwingBake bakes from (pose() is the
## Callable it takes). The fighter's weapon is fixed in its hand
## (FighterModel.fix_weapons()), and each pose is read once the whole
## modifier stack has run, so the off hand's IK, and a two-handed weapon
## drawn in toward the off shoulder, are in it: the weapon read is the
## weapon shown. The parts:
## - a hand: the held weapon's grip (its origin), blade (+Y) and edge (+X);
##   a bare hand's fist frame (FighterRig.fist());
## - a foot: the ankle, the blade toward the toes and the edge out of the
##   sole, square to it, both as the rest pose has them in the foot bone;
## - the body: the hips' turn (pelvis) and the upper chest's (torso) about
##   the vertical from their rest, in degrees, positive toward the fighter's
##   right, and the hips' travel from their rest (pelvis shift).
## Skeleton space is the fighter's frame with +X to the fighter's left
## (FighterRig), so x turns round.
##
## A chain entry is "<library>/<clip id>", or part of a clip ("@from" or
## "@from-to" after the id; ClipChain): each part fades in from the one
## before over ClipChain.BLEND source frames, its bones blended as the
## clip director's crossfade blends them (task 11).

const SIDES: Dictionary[String, String] = {"right": "Right", "left": "Left"}

var model: FighterModel
## The chain's entries: the clips' names in the model's AnimationPlayer
## (each maybe a part of one), played in this order.
var chain: Array[String] = []
## The chain's length (s).
var length: float = 0.0
var _parts: Array[ClipChain.Part] = []
## Each part's library ("HumanM/"), by part.
var _libraries: PackedStringArray = PackedStringArray()
var _foot_axes: Dictionary[String, Array] = {}
var _captured: Dictionary[StringName, Swing.Sample] = {}
var _last_time: float = NAN


## `p_model` must be in the tree, holding its weapon (or none, for bare
## hands); its skeleton is switched to manual updates and its weapons fixed.
func _init(p_model: FighterModel, p_chain: Array[String], reverse: bool = false) -> void:
	model = p_model
	chain = p_chain
	model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	if not model.weapons.is_empty():
		model.fix_weapons(reverse)
	var entries: Array[String] = []
	var lengths: Dictionary = {}
	for entry: String in chain:
		var slash: int = entry.find("/")
		var library: String = entry.substr(0, slash + 1)
		var rest: String = entry.substr(slash + 1)
		_libraries.append(library)
		entries.append(rest)
		var id: StringName = ClipChain.parse(rest, [] as Array[String]).id
		lengths[id] = model.animation_player.get_animation(library + String(id)).length * float(ClipManifest.SOURCE_FPS)
	var why: Array[String] = []
	_parts = ClipChain.lay_out(entries, lengths, why)
	if _parts.is_empty():
		push_error("ClipPoser: %s" % "; ".join(why))
	length = ClipChain.length_of(_parts) / float(ClipManifest.SOURCE_FPS)
	var sk: Skeleton3D = model.skeleton
	for side: String in SIDES.values():
		var foot: int = sk.find_bone(side + "Foot")
		var rest: Transform3D = sk.get_bone_global_rest(foot)
		var toward: Vector3 = (sk.get_bone_global_rest(sk.find_bone(side + "Toes")).origin - rest.origin).normalized()
		var sole: Vector3 = Vector3.DOWN - toward * Vector3.DOWN.dot(toward)
		var inv: Basis = rest.basis.orthonormalized().inverse()
		_foot_axes[side] = [inv * toward, inv * sole.normalized()]


## The chain's parts as laid out (ClipChain.lay_out), each with its start.
func parts() -> Array[ClipChain.Part]:
	return _parts


## The parts' poses at `time` (s from the chain's start), by part (every
## hand, foot and the body; Swing.PARTS).
func pose(time: float) -> Dictionary[StringName, Swing.Sample]:
	if time == _last_time and not _captured.is_empty():
		# the skeleton skips an update that changes nothing
		return _captured
	_last_time = time
	var at: ClipChain.Place = ClipChain.place(_parts, time * float(ClipManifest.SOURCE_FPS))
	var sk: Skeleton3D = model.skeleton
	var under: Array = []
	if at.under >= 0:
		_apply(at.under, at.under_frame)
		under = _bone_poses(sk)
	_apply(at.part, at.frame)
	if at.under >= 0:
		_blend(sk, under, at.under_weight)
	_captured = {}
	var carry: SkeletonModifier3D = sk.get_node(^"RigCarry")
	carry.modification_processed.connect(_capture, CONNECT_ONE_SHOT)
	# advance() only queues the update for the frame's end; the notification
	# runs the modifier stack now
	sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	if _captured.is_empty():
		carry.modification_processed.disconnect(_capture)
		push_error("ClipPoser: the skeleton didn't update")
	return _captured


## Plays part `index` of the chain at source frame `frame` of its clip,
## posing the bones.
func _apply(index: int, frame: float) -> void:
	var player: AnimationPlayer = model.animation_player
	var anim_name: String = _libraries[index] + String(_parts[index].id)
	player.play(anim_name, 0.0)
	player.seek(clampf(frame / float(ClipManifest.SOURCE_FPS), 0.0, player.get_animation(anim_name).length), true)
	player.pause()


## Every bone's local pose: [positions, rotations, scales].
static func _bone_poses(sk: Skeleton3D) -> Array:
	var p: PackedVector3Array = PackedVector3Array()
	var r: Array[Quaternion] = []
	var s: PackedVector3Array = PackedVector3Array()
	for b: int in sk.get_bone_count():
		p.append(sk.get_bone_pose_position(b))
		r.append(sk.get_bone_pose_rotation(b))
		s.append(sk.get_bone_pose_scale(b))
	return [p, r, s]


## Blends the bones' poses toward `under` (_bone_poses()) by `weight`.
static func _blend(sk: Skeleton3D, under: Array, weight: float) -> void:
	for b: int in sk.get_bone_count():
		sk.set_bone_pose_position(b, sk.get_bone_pose_position(b).lerp(under[0][b], weight))
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(under[1][b], weight))
		sk.set_bone_pose_scale(b, sk.get_bone_pose_scale(b).lerp(under[2][b], weight))


func _capture() -> void:
	var sk: Skeleton3D = model.skeleton
	var out: Dictionary[StringName, Swing.Sample] = {}
	for side: String in SIDES:
		var bone: String = SIDES[side]
		var hand: Transform3D = sk.get_bone_global_pose(sk.find_bone(bone + "Hand"))
		var held: Transform3D = hand * model.rig.fist(bone)
		var index: int = 0 if side == "right" else 1
		if index < model.weapons.size() and (index == 0 or model.weapon_look.paired):
			held = model.weapons[index].transform
		out[StringName(side + "_hand")] = frame_sample(held)
		var foot: Transform3D = sk.get_bone_global_pose(sk.find_bone(bone + "Foot"))
		var axes: Array = _foot_axes[bone]
		var basis: Basis = foot.basis.orthonormalized()
		out[StringName(side + "_foot")] = limb_sample(foot.origin, basis * (axes[0] as Vector3), basis * (axes[1] as Vector3))
		# the shoulder a bash strikes with: out along the shoulder line, its
		# edge the chest's forward
		var other: String = SIDES["left" if side == "right" else "right"]
		var joint: Vector3 = sk.get_bone_global_pose(sk.find_bone(bone + "UpperArm")).origin
		var away: Vector3 = joint - sk.get_bone_global_pose(sk.find_bone(other + "UpperArm")).origin
		var chest: Basis = sk.get_bone_global_pose(sk.find_bone("UpperChest")).basis.orthonormalized()
		out[StringName(side + "_shoulder")] = limb_sample(joint, away, chest.z)
		# the knee a knee strike strikes with: down the shin, its edge the
		# shin's front (out of the leg's bend; the toes' way when it's straight)
		var knee: Vector3 = sk.get_bone_global_pose(sk.find_bone(bone + "LowerLeg")).origin
		var thigh: Vector3 = (knee - sk.get_bone_global_pose(sk.find_bone(bone + "UpperLeg")).origin).normalized()
		var shin: Vector3 = (foot.origin - knee).normalized()
		var front: Vector3 = thigh - shin
		if front.length() < 0.05:
			front = basis * (axes[0] as Vector3)
		out[StringName(side + "_knee")] = limb_sample(knee, shin, front)
	var body: Swing.Sample = Swing.Sample.new()
	var hips: int = sk.find_bone("Hips")
	body.pelvis = coil(sk, hips)
	body.torso = coil(sk, sk.find_bone("UpperChest"))
	body.pelvis_shift = to_fighter(sk.get_bone_global_pose(hips).origin - sk.get_bone_global_rest(hips).origin)
	out[&"body"] = body
	_captured = out


## A held thing's frame (skeleton space: grip at the origin, blade +Y, edge
## +X) as a hand's sample.
static func frame_sample(xf: Transform3D) -> Swing.Sample:
	return limb_sample(xf.origin, xf.basis.y, xf.basis.x)


static func limb_sample(grip: Vector3, blade: Vector3, edge: Vector3) -> Swing.Sample:
	var s: Swing.Sample = Swing.Sample.new()
	s.grip = to_fighter(grip)
	s.blade = to_fighter(blade.normalized())
	var y: Vector3 = blade.normalized()
	s.edge = to_fighter((edge - y * edge.dot(y)).normalized())
	return s


## A bone's turn about the vertical from its rest, in degrees, positive
## toward the fighter's right (-X in skeleton space): read from the way its
## side (its rest's +X, the fighter's left) has turned, which bending
## forward or back leaves alone.
static func coil(sk: Skeleton3D, bone: int) -> float:
	var turn: Quaternion = sk.get_bone_global_pose(bone).basis.get_rotation_quaternion() \
		* sk.get_bone_global_rest(bone).basis.get_rotation_quaternion().inverse()
	var side: Vector3 = turn * Vector3.RIGHT
	return rad_to_deg(atan2(side.z, side.x))


## A skeleton-space point or direction in the fighter's (right, up,
## forward) frame.
static func to_fighter(v: Vector3) -> V3:
	return V3.make(-v.x, v.y, v.z)
