class_name PoseCheck
extends RefCounted
## Measures a posed fighter against the rules every swing and stance must
## meet on the real skeleton (the spec's "Weapon swings", from the animation
## spike's critique):
## - each wrist the IK places bent at most WRIST_BEND_MAX from its forearm's
##   line and turned at most WRIST_DEVIATION_MAX sideways;
## - each elbow the IK places never locked (past ELBOW_LOCKED), and between
##   ELBOW_CONTACT_MIN and ELBOW_CONTACT_MAX on the first active frame;
## - each knee over its toes: on or outside the plane of its hip, ankle and
##   toes, never caved in past KNEE_INSIDE;
## - every held blade at least BLADE_CLEARANCE from its own fighter's body;
## - each planted foot within FOOT_SLIDE_MAX of where it landed (milestone-1
##   task 9), measured over a run of frames by a FootTrack: a foot is planted
##   by FootLock's rule (its ankle within PLANT_HEIGHT of its rest height,
##   let go above LIFT_HEIGHT), and its slide is how far it has moved along
##   the ground, in the world, since it came down;
## - and, not a check but a measure, how much blade is inside a defender's
##   capsule (the rules' hurt capsule, DEFENDER_RADIUS round from the feet to
##   DEFENDER_HEIGHT).
##
## The body is a set of capsules (head, torso, upper arms, forearms, thighs)
## measured from each fighter's own meshes when the check is made, each
## riding its bones. A check measures a Frame: every bone's pose at the end
## of the modifier stack, in skeleton space (frame_of() steps a fighter's
## skeleton once to take one). Tests and tools can edit a frame to make up
## poses. Skeleton space is the fighter's own frame: +Z forward, +X to the
## fighter's left, +Y up, metres from the ground; a frame's root carries
## it into the world.

const SIDES: Array[String] = ["Right", "Left"]

## Wrist limits (degrees): bend toward the palm or the back of the hand, and
## deviation toward the thumb or the little finger.
const WRIST_BEND_MAX: float = 60.0
const WRIST_DEVIATION_MAX: float = 25.0
## The inside angle at an elbow (degrees, 180 straight): never past
## ELBOW_LOCKED, and in the contact band on the first active frame.
const ELBOW_LOCKED: float = 170.0
const ELBOW_CONTACT_MIN: float = 150.0
const ELBOW_CONTACT_MAX: float = 160.0
## How far a knee may sit inside the plane of its hip, ankle and toes (m).
const KNEE_INSIDE: float = 0.01
## The closest a blade may come to its own fighter's body (m). A held
## blade's base sits about a hand's width from its own wrist, clear of the
## forearm's capsule, which stops where the forearm does.
const BLADE_CLEARANCE: float = 0.05
## The most a planted foot may slide from where it landed (m), the per-move
## checklist's item 8; and when a foot is planted, FootLock's heights above
## its ankle's rest height (m).
const FOOT_SLIDE_MAX: float = 0.01
const PLANT_HEIGHT: float = FootLock.PLANT_HEIGHT
const LIFT_HEIGHT: float = FootLock.LIFT_HEIGHT
## The defender's hurt capsule (m): the rules' 0.42 m round, from the feet
## to 2.0 m (FighterBody's).
const DEFENDER_RADIUS: float = 0.42
const DEFENDER_HEIGHT: float = 2.0
## The duelling distance between the fighters (m), the Katana's (3.0 m
## since its 1.3 m blade, KE task 2; 3.3 m on the taller bodies, task 3).
const SPACING: float = 3.3

## The capsules, as [name, the bones whose vertices it wraps, its axis from
## one bone's joint to another's, or to the crown when the second is empty].
const CAPSULE_PARTS: Array[Array] = [
	["head", [&"Head"], &"Head", &""],
	["torso", [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"LeftShoulder", &"RightShoulder"], &"Hips", &"Neck"],
	["right upper arm", [&"RightUpperArm"], &"RightUpperArm", &"RightLowerArm"],
	["left upper arm", [&"LeftUpperArm"], &"LeftUpperArm", &"LeftLowerArm"],
	["right forearm", [&"RightLowerArm"], &"RightLowerArm", &"RightHand"],
	["left forearm", [&"LeftLowerArm"], &"LeftLowerArm", &"LeftHand"],
	["right thigh", [&"RightUpperLeg"], &"RightUpperLeg", &"RightLowerLeg"],
	["left thigh", [&"LeftUpperLeg"], &"LeftUpperLeg", &"LeftLowerLeg"],
]
## A capsule's radius takes in this share of its part's vertices: a pouch, a
## flap or the corner of a shoulder doesn't fatten a whole part, and the
## clearance covers what sticks out past it.
const CAPSULE_SHARE: float = 0.9


## A posed fighter to measure.
class Frame:
	## Every bone's pose at the end of the modifier stack, in skeleton space,
	## by bone index.
	var bones: Array[Transform3D] = []
	## The arms the IK places (their hands grip a posed weapon), by side.
	var driven: Array[String] = []
	## Each held blade, in skeleton space: [BladeBase, BladeTip].
	var blades: Array[PackedVector3Array] = []
	## Where the defender's feet are, in skeleton space; Vector3.INF for none.
	var defender: Vector3 = Vector3.INF
	## Skeleton space to the world (the skeleton's global transform).
	var root: Transform3D = Transform3D.IDENTITY

	func copy() -> Frame:
		var f: Frame = Frame.new()
		f.root = root
		f.bones = bones.duplicate()
		f.driven = driven.duplicate()
		for b: PackedVector3Array in blades:
			f.blades.append(b.duplicate())
		f.defender = defender
		return f


## A capsule round part of the body, riding its bones: its axis runs from
## a point fixed to one bone to a point fixed to another.
class Capsule:
	var name: String = ""
	var radius: float = 0.0
	## The axis's length at rest (m).
	var length: float = 0.0
	var from_bone: int = -1
	var from_point: Vector3 = Vector3.ZERO
	var to_bone: int = -1
	var to_point: Vector3 = Vector3.ZERO

	## The axis's two ends in a frame's bones.
	func ends(bones: Array[Transform3D]) -> PackedVector3Array:
		return PackedVector3Array([bones[from_bone] * from_point, bones[to_bone] * to_point])


## What a frame measured, and what failed.
class Report:
	## Measured on the first active frame: the elbows' contact band applies.
	var contact: bool = false
	## Each wrist the IK places, by side: x its bend (degrees, + toward the
	## palm), y its deviation (+ toward the thumb).
	var wrists: Dictionary[String, Vector2] = {}
	## Each elbow the IK places, by side: its inside angle (degrees).
	var elbows: Dictionary[String, float] = {}
	## Each knee, by side: how far it is outside the plane of its hip, ankle
	## and toes (m); negative is inside.
	var knees: Dictionary[String, float] = {}
	## The nearest any held blade comes to the body's capsules (m), and the
	## capsule it is nearest; INF with no blade.
	var blade_gap: float = INF
	var blade_near: String = ""
	## How much blade is inside the defender's capsule (m); -1 with no
	## defender.
	var reach: float = -1.0
	## Each planted foot's slide from where it landed (m), by side; only
	## with a FootTrack, and only the feet planted on this frame.
	var feet: Dictionary[String, float] = {}

	func failures() -> PackedStringArray:
		var out: PackedStringArray = []
		for side: String in wrists:
			var w: Vector2 = wrists[side]
			if absf(w.x) > WRIST_BEND_MAX:
				out.append("%s wrist bent %.0f°" % [side.to_lower(), w.x])
			if absf(w.y) > WRIST_DEVIATION_MAX:
				out.append("%s wrist turned %.0f° sideways" % [side.to_lower(), w.y])
		for side: String in elbows:
			var e: float = elbows[side]
			if e > ELBOW_LOCKED:
				out.append("%s elbow locked at %.0f°" % [side.to_lower(), e])
			elif contact and (e < ELBOW_CONTACT_MIN or e > ELBOW_CONTACT_MAX):
				out.append("%s elbow at %.0f° on contact" % [side.to_lower(), e])
		for side: String in knees:
			if knees[side] < -KNEE_INSIDE:
				out.append("%s knee %.1f cm inside the foot line" % [side.to_lower(), -knees[side] * 100.0])
		if blade_gap < BLADE_CLEARANCE:
			out.append("blade %.1f cm from the %s" % [blade_gap * 100.0, blade_near])
		for side: String in feet:
			if feet[side] > FOOT_SLIDE_MAX:
				out.append("%s foot slid %.1f cm" % [side.to_lower(), feet[side] * 100.0])
		return out

	func passed() -> bool:
		return failures().is_empty()

	## The numbers on one line, for logs and contact sheets.
	func summary() -> String:
		var parts: PackedStringArray = []
		var w: PackedStringArray = []
		for side: String in wrists:
			w.append("%s %+.0f/%+.0f" % [side.left(1), wrists[side].x, wrists[side].y])
		if not w.is_empty():
			parts.append("wrist " + " ".join(w))
		var e: PackedStringArray = []
		for side: String in elbows:
			e.append("%s %.0f" % [side.left(1), elbows[side]])
		if not e.is_empty():
			parts.append("elbow " + " ".join(e))
		var k: PackedStringArray = []
		for side: String in knees:
			k.append("%s %+.1f" % [side.left(1), knees[side] * 100.0])
		parts.append("knee cm " + " ".join(k))
		if blade_gap < INF:
			parts.append("blade %.1f cm (%s)" % [blade_gap * 100.0, blade_near])
		if reach >= 0.0:
			parts.append("reach %.1f cm" % (reach * 100.0))
		var slid: PackedStringArray = []
		for side: String in feet:
			slid.append("%s %.1f" % [side.left(1), feet[side] * 100.0])
		if not slid.is_empty():
			parts.append("slide %s cm" % " ".join(slid))
		return " · ".join(parts)


## Follows the feet over a run of frames: where each planted foot came down,
## so a frame's slide is measured from there. One track per run (a move);
## frames go in order.
class FootTrack:
	var check: PoseCheck
	## Where each planted foot came down (world), by side.
	var landed: Dictionary[String, Vector3] = {}

	func _init(p_check: PoseCheck) -> void:
		check = p_check

	## Each foot planted on `frame`, by side: how far it has slid along the
	## ground since it came down (m).
	func step(frame: Frame) -> Dictionary[String, float]:
		var out: Dictionary[String, float] = {}
		for side: String in SIDES:
			var at: Vector3 = frame.root * frame.bones[check.bone(side + "Foot")].origin
			var limit: float = LIFT_HEIGHT if landed.has(side) else PLANT_HEIGHT
			if at.y > check.ankle_rest[side] + limit:
				landed.erase(side)
				continue
			if not landed.has(side):
				landed[side] = at
			out[side] = Vector2(at.x - landed[side].x, at.z - landed[side].z).length()
		return out


## The body's capsules.
var capsules: Array[Capsule] = []
## Each ankle's height in the rest pose (m above the ground), by side.
var ankle_rest: Dictionary[String, float] = {}

var _ids: Dictionary[String, int] = {}


## Measures `model`'s body (from its meshes and its skeleton's rest pose).
func _init(model: FighterModel) -> void:
	var sk: Skeleton3D = model.skeleton
	for i: int in sk.get_bone_count():
		_ids[sk.get_bone_name(i)] = i
	capsules = _measure_capsules(sk)
	for side: String in SIDES:
		ankle_rest[side] = sk.get_bone_global_rest(_ids[side + "Foot"]).origin.y


## Steps `model`'s skeleton once and takes the frame at the end of its
## modifier stack, with its held blades (await it: the skeleton updates at
## the end of the tree's frame). Outside an update the skeleton holds the
## clip's pose, so the bones are read as the last modifier finishes; the
## caller resumes on the tree's next frame, outside the skeleton's update,
## so it can pose and step the skeleton again. The skeleton must be in
## MODIFIER_CALLBACK_MODE_PROCESS_MANUAL; returns an empty frame otherwise.
static func frame_of(model: FighterModel) -> Frame:
	var frame: Frame = Frame.new()
	var sk: Skeleton3D = model.skeleton
	if sk.modifier_callback_mode_process != Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL:
		push_error("PoseCheck.frame_of: the skeleton must be stepped by hand (MODIFIER_CALLBACK_MODE_PROCESS_MANUAL)")
		return frame
	var grab: Callable = func() -> void:
		frame.bones.clear()
		for i: int in sk.get_bone_count():
			frame.bones.append(sk.get_bone_global_pose(i))
	var last: SkeletonModifier3D = sk.get_node(^"RigCarry")
	last.modification_processed.connect(grab, CONNECT_ONE_SHOT)
	sk.advance(1.0 / 60.0)
	for i: int in 4:
		if not frame.bones.is_empty():
			break
		await sk.get_tree().process_frame
	if frame.bones.is_empty():
		last.modification_processed.disconnect(grab)
		push_error("PoseCheck.frame_of: the skeleton didn't update")
		return frame
	frame.root = sk.global_transform
	for side: String in SIDES:
		if model.rig.drives(side):
			frame.driven.append(side)
	var to_sk: Transform3D = sk.transform.affine_inverse() * model.weapon_root.transform
	for w: Node3D in model.weapons:
		var xf: Transform3D = to_sk * w.transform
		var seg: PackedVector3Array = WeaponLook.blade_segment(w)
		frame.blades.append(xf * seg)
	return frame


## Measures a frame; `contact` when it is the first active frame of a move.
## With `track`, the frame is the next of its run and the planted feet's
## slides are measured too.
func measure(frame: Frame, contact: bool = false, track: FootTrack = null) -> Report:
	var r: Report = Report.new()
	r.contact = contact
	if track != null:
		r.feet = track.step(frame)
	var b: Array[Transform3D] = frame.bones
	for side: String in SIDES:
		if not frame.driven.has(side):
			continue
		var lower: Vector3 = b[_ids[side + "LowerArm"]].origin
		r.wrists[side] = _wrist_angles(lower, b[_ids[side + "Hand"]], side)
		var shoulder: Vector3 = b[_ids[side + "UpperArm"]].origin
		r.elbows[side] = rad_to_deg((shoulder - lower).angle_to(b[_ids[side + "Hand"]].origin - lower))
	for side: String in SIDES:
		var other: String = "Left" if side == "Right" else "Right"
		r.knees[side] = knee_offset(
			b[_ids[side + "UpperLeg"]].origin, b[_ids[side + "LowerLeg"]].origin,
			b[_ids[side + "Foot"]], b[_ids[other + "UpperLeg"]].origin)
	for blade: PackedVector3Array in frame.blades:
		for c: Capsule in capsules:
			var ends: PackedVector3Array = c.ends(b)
			var near: PackedVector3Array = Geometry3D.get_closest_points_between_segments(blade[0], blade[1], ends[0], ends[1])
			var gap: float = near[0].distance_to(near[1]) - c.radius
			if gap < r.blade_gap:
				r.blade_gap = gap
				r.blade_near = c.name
	if frame.defender != Vector3.INF:
		r.reach = 0.0
		for blade: PackedVector3Array in frame.blades:
			r.reach = maxf(r.reach, blade_inside(blade[0], blade[1], frame.defender))
	return r


## The index of the bone with this name.
func bone(bone_name: String) -> int:
	return _ids[bone_name]


## The capsule with this name, or null.
func capsule(capsule_name: String) -> Capsule:
	for c: Capsule in capsules:
		if c.name == capsule_name:
			return c
	return null


## The hand on `side` in a frame's bones with its wrist straight: turned the
## least way that puts it in line with its forearm.
func straight_hand(side: String, bones: Array[Transform3D]) -> Transform3D:
	var hand: Transform3D = bones[_ids[side + "Hand"]]
	var along: Vector3 = (hand.origin - bones[_ids[side + "LowerArm"]].origin).normalized()
	var b: Basis = hand.basis.orthonormalized()
	var turn: Quaternion = Quaternion(b.y, along)
	return Transform3D(Basis(turn) * b, hand.origin)


## How far a knee is outside the plane through its hip that holds the line
## to its ankle and the way its toes point (m; negative is inside). `foot` is
## the foot bone's pose (its origin the ankle, +Y toward the toes); outside
## is away from the other hip.
static func knee_offset(hip: Vector3, knee: Vector3, foot: Transform3D, other_hip: Vector3) -> float:
	var normal: Vector3 = (foot.origin - hip).cross(foot.basis.y)
	if normal.length() < 1e-6:
		return 0.0
	normal = normal.normalized()
	if normal.dot(hip - other_hip) < 0.0:
		normal = -normal
	return (knee - hip).dot(normal)


## How much of the blade from `base` to `tip` is inside the defender's
## capsule standing with its feet at `feet` (m). The capsule is convex, so
## the inside is one stretch of the blade: find its deepest point, then its
## two edges.
static func blade_inside(base: Vector3, tip: Vector3, feet: Vector3) -> float:
	var a: Vector3 = feet + Vector3(0.0, DEFENDER_RADIUS, 0.0)
	var b: Vector3 = feet + Vector3(0.0, DEFENDER_HEIGHT - DEFENDER_RADIUS, 0.0)
	var depth: Callable = func(t: float) -> float:
		var p: Vector3 = base.lerp(tip, t)
		return DEFENDER_RADIUS - p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))
	# the depth is concave along the blade: ternary search for its peak
	var lo: float = 0.0
	var hi: float = 1.0
	for i: int in 60:
		var m1: float = lo + (hi - lo) / 3.0
		var m2: float = hi - (hi - lo) / 3.0
		if depth.call(m1) < depth.call(m2):
			lo = m1
		else:
			hi = m2
	var deepest: float = (lo + hi) * 0.5
	if depth.call(deepest) <= 0.0:
		return 0.0
	var enter: float = 0.0 if depth.call(0.0) >= 0.0 else _edge(depth, 0.0, deepest)
	var leave: float = 1.0 if depth.call(1.0) >= 0.0 else _edge(depth, 1.0, deepest)
	return (leave - enter) * base.distance_to(tip)


## Where `depth` crosses zero between `outside` (negative) and `inside`.
static func _edge(depth: Callable, outside: float, inside: float) -> float:
	for i: int in 50:
		var mid: float = (outside + inside) * 0.5
		if depth.call(mid) >= 0.0:
			inside = mid
		else:
			outside = mid
	return (outside + inside) * 0.5


## A wrist's bend and deviation (degrees) from the line of its forearm (the
## lower arm's joint to the hand's) as the hand sees it: a hand bone's +Y
## runs to the knuckles, +Z out of the palm, and +X to the thumb on the right
## hand and away from it on the left. (At rest the fighters' hands are within
## 2 degrees of their forearms' line.) The deviation is how far the forearm's
## line leaves the plane the hand bends in (at most 90 degrees either way),
## and the bend is its angle within that plane, so a hand folded far back
## doesn't count its fold twice.
static func _wrist_angles(elbow: Vector3, hand: Transform3D, side: String) -> Vector2:
	var along: Vector3 = hand.basis.orthonormalized().inverse() * (hand.origin - elbow).normalized()
	var bend: float = atan2(-along.z, along.y)
	var deviation: float = asin(clampf(-along.x if side == "Right" else along.x, -1.0, 1.0))
	return Vector2(rad_to_deg(bend), rad_to_deg(deviation))


# ------------------------------------------------------------------ the body

## Fits each capsule to its part's vertices at rest. Each skinned vertex
## goes with the bone that weighs most on it. The axis is moved off the
## joints by the part's mean offset from it (a torso's off the spine, which
## runs down the back), and the radius takes in CAPSULE_SHARE of the part's
## vertices; the head's counts only those above its joint, since long hair
## hangs down the back. Each end is then drawn in so its cap stops where the
## part's vertices stop (the torso's at the collar, not over the face); the
## head's axis runs up the head bone from its joint, stopping a radius short
## of the crown. Last, headwear on a bone attachment (the Hunter's hat) is
## the hat margin: the capsule grows to take all of it in.
func _measure_capsules(sk: Skeleton3D) -> Array[Capsule]:
	var skinned: Dictionary[int, PackedVector3Array] = _skinned_vertices(sk)
	var attached: Dictionary[int, PackedVector3Array] = _attached_vertices(sk)
	var out: Array[Capsule] = []
	for part: Array in CAPSULE_PARTS:
		var from_bone: int = _ids[String(part[2])]
		var from_rest: Transform3D = sk.get_bone_global_rest(from_bone)
		var points: PackedVector3Array = []
		var worn: PackedVector3Array = []
		for bone: StringName in part[1]:
			points.append_array(skinned.get(_ids[String(bone)], PackedVector3Array()))
			worn.append_array(attached.get(_ids[String(bone)], PackedVector3Array()))
		var head: bool = part[3] == &""
		var to_bone: int = from_bone if head else _ids[String(part[3])]
		var a: Vector3 = from_rest.origin
		var axis: Vector3 = from_rest.basis.y.normalized() if head else (sk.get_bone_global_rest(to_bone).origin - a).normalized()
		# how far the part's vertices reach along the axis
		var lo: float = INF
		var hi: float = -INF
		for p: Vector3 in points:
			var t: float = (p - a).dot(axis)
			lo = minf(lo, t)
			hi = maxf(hi, t)
		if head:
			lo = 0.0
		var span: float = hi if head else a.distance_to(sk.get_bone_global_rest(to_bone).origin)
		var along: PackedVector3Array = []
		var offset: Vector3 = Vector3.ZERO
		for p: Vector3 in points:
			var t: float = (p - a).dot(axis)
			if t >= 0.0 and t <= span:
				along.append(p)
				offset += (p - a) - axis * t
		if along.is_empty():
			push_error("PoseCheck: no vertices along the %s" % part[0])
			continue
		offset /= float(along.size())
		a += offset
		var b: Vector3 = a + axis * span
		var dists: PackedFloat32Array = []
		for p: Vector3 in (along if head else points):
			dists.append(p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)))
		dists.sort()
		var r: float = dists[mini(dists.size() - 1, int(dists.size() * CAPSULE_SHARE))]
		# draw the ends in so the caps stop where the vertices do
		var start: float = 0.0 if head else lo + r
		var end: float = hi - r
		if end < start:
			start = (start + end) * 0.5 if not head else 0.0
			end = start
		b = a + axis * end
		a = a + axis * start
		for p: Vector3 in worn:
			r = maxf(r, p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)))
		var c: Capsule = Capsule.new()
		c.name = part[0]
		c.radius = r
		c.length = a.distance_to(b)
		c.from_bone = from_bone
		c.from_point = from_rest.affine_inverse() * a
		c.to_bone = to_bone
		c.to_point = sk.get_bone_global_rest(to_bone).affine_inverse() * b
		out.append(c)
	return out


## Every vertex of the fighter's skinned meshes at rest, in skeleton space,
## by the bone that weighs most on it.
static func _skinned_vertices(sk: Skeleton3D) -> Dictionary[int, PackedVector3Array]:
	var lists: Dictionary[int, Array] = {}
	for node: Node in sk.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		# (cloth on a rig of its own, the Hunter's scarf, isn't the body)
		if mi.skin == null or mi.get_node_or_null(mi.skeleton) != sk:
			continue
		var bind_bone: PackedInt32Array = []
		var to_rest: Array[Transform3D] = []
		for i: int in mi.skin.get_bind_count():
			var bone: int = mi.skin.get_bind_bone(i)
			if bone < 0:
				bone = sk.find_bone(mi.skin.get_bind_name(i))
			bind_bone.append(bone)
			to_rest.append(sk.get_bone_global_rest(bone) * mi.skin.get_bind_pose(i))
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or bones.is_empty():
				continue
			var per: int = bones.size() / verts.size()
			for v: int in verts.size():
				var best: int = v * per
				for k: int in range(v * per + 1, v * per + per):
					if weights[k] > weights[best]:
						best = k
				var bind: int = bones[best]
				var bone: int = bind_bone[bind]
				if not lists.has(bone):
					lists[bone] = []
				lists[bone].append(to_rest[bind] * verts[v])
	var out: Dictionary[int, PackedVector3Array] = {}
	for bone: int in lists:
		out[bone] = PackedVector3Array(lists[bone])
	return out


## Every vertex of the meshes worn on bone attachments (the hat) at rest, in
## skeleton space, by the bone they ride on.
static func _attached_vertices(sk: Skeleton3D) -> Dictionary[int, PackedVector3Array]:
	var out: Dictionary[int, PackedVector3Array] = {}
	for node: Node in sk.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var attachment: BoneAttachment3D = mi.get_parent() as BoneAttachment3D
		if mi.skin != null or attachment == null:
			continue
		var bone: int = sk.find_bone(attachment.bone_name)
		var xf: Transform3D = sk.get_bone_global_rest(bone) * mi.transform
		var pts: PackedVector3Array = out.get(bone, PackedVector3Array())
		for s: int in mi.mesh.get_surface_count():
			pts.append_array(xf * (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		out[bone] = pts
	return out
