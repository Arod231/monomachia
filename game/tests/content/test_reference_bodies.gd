extends GutTest
## The reference bodies (task 7.6) against the fighters they copy. The rules
## never load a scene, so ReferenceBody holds each fighter's numbers; these
## tests measure the Rogue and the Hunter again, at rest, and require every
## committed point, length and radius within 1 cm.
##
## How each number is measured (Godot's axes, whose +X is the fighter's left,
## become (right, up, forward)):
## - the shoulders are the upper-arm joints, the upper arm runs to the elbow
##   and the forearm to the wrist; the wrist is placed in the right fist's
##   frame (HandGrip.fist(), at HandGrip's default handle radius);
## - the spine runs from the middle of the hip joints to the middle of the
##   shoulders;
## - each proxy covers the vertices its bones mostly move (and, for the head,
##   the hat): the torso the hips, spine, chest and collarbones, the head the
##   neck and head, each limb its own bone;
## - the torso is an upright capsule at the middle of its depth, from the
##   hips' height to the shoulders', as wide as its widest point;
## - the head is an upright capsule at the middle of its depth, from the head
##   joint's height up to its crown, as wide as its widest point (the hood or
##   the hat's brim);
## - a limb's capsule runs along its bone, as wide as its widest point beside
##   the bone (beyond the joints, the next proxy covers it).

const TOLERANCE: float = 0.01
## The swing checks keep a blade this far from every proxy (task 7.7).
const MARGIN: float = 0.05
const SIDES: Dictionary[StringName, String] = {&"right": "Right", &"left": "Left"}
const REGIONS: Dictionary[String, Array] = {
	"head": ["Neck", "Head"],
	"torso": ["Hips", "Spine", "Chest", "UpperChest", "LeftShoulder", "RightShoulder"],
	"RightUpperLeg": ["RightUpperLeg"], "LeftUpperLeg": ["LeftUpperLeg"],
	"RightUpperArm": ["RightUpperArm"], "LeftUpperArm": ["LeftUpperArm"],
	"RightLowerArm": ["RightLowerArm"], "LeftLowerArm": ["LeftLowerArm"],
}


static func _ruf(p: Vector3) -> V3:
	return V3.make(-p.x, p.y, p.z)


static func _joint(sk: Skeleton3D, bone: String) -> Vector3:
	return sk.get_bone_global_rest(sk.find_bone(bone)).origin


## `node`'s transform in `top`'s space.
static func _under(node: Node3D, top: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var at: Node = node
	while at != top:
		xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


## The rest-pose vertices (skeleton space) of each region: those whose
## heaviest bone is one of the region's, and a hat's with its bone.
static func _regions(sk: Skeleton3D) -> Dictionary[String, Array]:
	var out: Dictionary[String, Array] = {}
	for region: String in REGIONS:
		out[region] = []
	for node: Node in sk.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var attachment: BoneAttachment3D = mi.get_parent() as BoneAttachment3D
		var xf: Transform3D = _under(mi, sk)
		if attachment != null:
			xf = sk.get_bone_global_rest(sk.find_bone(attachment.bone_name)) * _under(mi, attachment)
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var per: int = bones.size() / maxi(verts.size(), 1)
			for i: int in verts.size():
				var bone: String = String(attachment.bone_name) if attachment != null else ""
				if attachment == null and per > 0:
					var heaviest: int = 0
					for j: int in per:
						if weights[i * per + j] > weights[i * per + heaviest]:
							heaviest = j
					var bind: int = bones[i * per + heaviest]
					bone = String(mi.skin.get_bind_name(bind)) if mi.skin != null else sk.get_bone_name(bind)
				for region: String in REGIONS:
					if REGIONS[region].has(bone):
						out[region].append(xf * verts[i])
	return out


## An upright capsule at the middle of the region's depth, from `bottom` up
## to `top` (or to its crown, less the radius, when `top` is NAN), as wide as
## the region's widest point: [a, b, radius].
static func _upright(points: Array, bottom: float, top: float) -> Array:
	var near: float = INF
	var far: float = -INF
	var crown: float = -INF
	for p: Vector3 in points:
		near = minf(near, p.z)
		far = maxf(far, p.z)
		crown = maxf(crown, p.y)
	var mid: float = (near + far) / 2.0
	var radius: float = 0.0
	for p: Vector3 in points:
		radius = maxf(radius, Vector2(p.x, p.z - mid).length())
	if is_nan(top):
		top = crown - radius
	return [Vector3(0.0, bottom, mid), Vector3(0.0, top, mid), radius]


## A limb's capsule along its bone, from `a` to `b`, as wide as its widest
## point beside the bone.
static func _limb(points: Array, a: Vector3, b: Vector3) -> float:
	var radius: float = 0.0
	var ab: Vector3 = b - a
	for p: Vector3 in points:
		var along: float = (p - a).dot(ab) / ab.length_squared()
		if along >= 0.0 and along <= 1.0:
			radius = maxf(radius, p.distance_to(a + ab * along))
	return radius


func _skeleton(id: StringName) -> Skeleton3D:
	var f: FighterModel = FighterLook.instantiate_fighter(id)
	add_child_autofree(f)
	return f.skeleton


func _near(got: V3, want: Vector3, what: String) -> void:
	var w: V3 = _ruf(want)
	assert_lt(V3.distance(got, w), TOLERANCE, "%s: (%.3f, %.3f, %.3f) measures (%.3f, %.3f, %.3f)" % [what, got.x, got.y, got.z, w.x, w.y, w.z])


func _close(got: float, want: float, what: String) -> void:
	assert_almost_eq(got, want, TOLERANCE, "%s: %.3f measures %.3f" % [what, got, want])


func _capsule(got: SimCapsule, want: Array, what: String) -> void:
	_near(got.a, want[0], what + " (a)")
	_near(got.b, want[1], what + " (b)")
	_close(got.radius, want[2], what + " (radius)")


func test_every_fighter_has_a_reference_body() -> void:
	assert_eq(ReferenceBody.BODIES.keys(), FighterLook.IDS)


func test_the_arms_match_the_skeletons() -> void:
	for id: StringName in FighterLook.IDS:
		var sk: Skeleton3D = _skeleton(id)
		var body: ReferenceBody = ReferenceBody.of(id)
		var grip: HandGrip = HandGrip.new()
		autofree(grip)
		grip.measure(sk)
		for side: StringName in SIDES:
			var s: String = SIDES[side]
			var shoulder: Vector3 = _joint(sk, s + "UpperArm")
			var elbow: Vector3 = _joint(sk, s + "LowerArm")
			var wrist: Vector3 = _joint(sk, s + "Hand")
			_near(body.shoulders[side], shoulder, "%s %s shoulder" % [id, side])
			_close(body.upper_arm, shoulder.distance_to(elbow), "%s %s upper arm" % [id, side])
			_close(body.forearm, elbow.distance_to(wrist), "%s %s forearm" % [id, side])
			# the fist's frame is already (edge, blade, flat), as the rules take it
			var in_fist: Vector3 = (sk.get_bone_global_rest(sk.find_bone(s + "Hand")) * grip.fist(s)).affine_inverse() * wrist
			var got: V3 = body.wrist_in_fist(side)
			assert_lt(V3.distance(got, V3.make(in_fist.x, in_fist.y, in_fist.z)), TOLERANCE,
					"%s %s wrist in the fist: (%.3f, %.3f, %.3f) measures %s" % [id, side, got.x, got.y, got.z, in_fist])


func test_the_spine_and_the_proxies_match_the_bodies() -> void:
	for id: StringName in FighterLook.IDS:
		var sk: Skeleton3D = _skeleton(id)
		var body: ReferenceBody = ReferenceBody.of(id)
		var regions: Dictionary[String, Array] = _regions(sk)
		for region: String in regions:
			assert_gt(regions[region].size(), 50, "%s: the %s was measured" % [id, region])
		var hips: Vector3 = (_joint(sk, "RightUpperLeg") + _joint(sk, "LeftUpperLeg")) / 2.0
		var shoulders: Vector3 = (_joint(sk, "RightUpperArm") + _joint(sk, "LeftUpperArm")) / 2.0
		_near(body.spine_base, hips, "%s spine base" % id)
		_near(body.spine_top, shoulders, "%s spine top" % id)
		_capsule(body.torso, _upright(regions["torso"], hips.y, shoulders.y), "%s torso" % id)
		_capsule(body.head, _upright(regions["head"], _joint(sk, "Head").y, NAN), "%s head" % id)
		for side: StringName in SIDES:
			var s: String = SIDES[side]
			var hip: Vector3 = _joint(sk, s + "UpperLeg")
			var knee: Vector3 = _joint(sk, s + "LowerLeg")
			_capsule(body.thighs[side], [hip, knee, _limb(regions[s + "UpperLeg"], hip, knee)], "%s %s thigh" % [id, side])
			var shoulder: Vector3 = _joint(sk, s + "UpperArm")
			var elbow: Vector3 = _joint(sk, s + "LowerArm")
			var wrist: Vector3 = _joint(sk, s + "Hand")
			_close(body.upper_arm_radius[side], _limb(regions[s + "UpperArm"], shoulder, elbow), "%s %s upper arm's radius" % [id, side])
			_close(body.forearm_radius[side], _limb(regions[s + "LowerArm"], elbow, wrist), "%s %s forearm's radius" % [id, side])


## How far the farthest of `points` (Godot's axes) lies outside `c`; with
## `alongside`, only the points beside its axis count (past the joints, the
## next proxy covers them).
static func _poke(points: Array, c: SimCapsule, alongside: bool) -> float:
	var a: Vector3 = Vector3(-c.a.x, c.a.y, c.a.z)
	var b: Vector3 = Vector3(-c.b.x, c.b.y, c.b.z)
	var ab: Vector3 = b - a
	var worst: float = -INF
	for p: Vector3 in points:
		var along: float = (p - a).dot(ab) / ab.length_squared() if ab.length_squared() > 0.0 else 0.0
		if alongside and (along < 0.0 or along > 1.0):
			continue
		worst = maxf(worst, p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)) - c.radius)
	return worst


func test_nothing_pokes_out_of_its_proxy_by_the_blade_s_margin() -> void:
	# A capsule can't hug both the crown and a hood's peak or a hat's brim; it
	# ends at the crown, so they poke out by up to 4.4 cm. That stays inside the
	# 5 cm the swing checks keep a blade from every proxy, so a blade they pass
	# still clears the body.
	for id: StringName in FighterLook.IDS:
		var body: ReferenceBody = ReferenceBody.of(id)
		var regions: Dictionary[String, Array] = _regions(_skeleton(id))
		assert_lt(_poke(regions["torso"], body.torso, false), MARGIN, "%s torso" % id)
		assert_lt(_poke(regions["head"], body.head, false), MARGIN, "%s head" % id)
		for side: StringName in SIDES:
			assert_lt(_poke(regions[SIDES[side] + "UpperLeg"], body.thighs[side], true), MARGIN, "%s %s thigh" % [id, side])
