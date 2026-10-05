extends GutTest
## The rules' strike segments (task 7.5) and off-hand grips (7.7) against the
## models they copy. The rules never load a scene, so each weapon's blade and
## off-hand grip, and bare hands' fist and foot, are numbers in the weapon
## files; these tests keep them in step:
## - a blade runs from the BladeBase marker to the BladeTip marker, within
##   1 cm, and its thickness is the blade's, within 1 mm;
## - a two-handed weapon's off hand grips at its OffHandGrip marker, within
##   1 cm, and a one-handed one has none;
## - the fist runs along the knuckles of both fighters' hands;
## - the foot runs along both fighters' boots, from the heel to the toe, with
##   its underside on the sole.

## A finger's half thickness and the fist's frame are HandGrip's, at the
## handle radius a bare fist closes on (HandGrip's default).
const SIDES: Array[String] = ["Right", "Left"]
const TOE_TIPS: Dictionary[String, String] = {"Right": "ball_leaf_r", "Left": "ball_leaf_l"}


static func _v(p: V3) -> Vector3:
	return Vector3(p.x, p.y, p.z)


## The distance from `p` to the segment from `a` to `b`.
static func _off(p: Vector3, a: Vector3, b: Vector3) -> float:
	return p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))


func _weapon(id: StringName) -> Node3D:
	var w: Node3D = WeaponLook.load_id(id).scene.instantiate()
	add_child_autofree(w)
	return w


func _skeleton(id: StringName) -> Skeleton3D:
	var f: FighterModel = FighterLook.instantiate_fighter(id)
	add_child_autofree(f)
	return f.skeleton


static func _rest(sk: Skeleton3D, bone: String) -> Transform3D:
	return sk.get_bone_global_rest(sk.find_bone(bone))


func test_every_weapon_has_a_blade_and_only_bare_hands_have_a_foot() -> void:
	for id: StringName in Moves.WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[id]
		assert_not_null(w.blade, "%s has a blade" % id)
		if w.blade != null:
			assert_gt(w.blade.thickness, 0.0, "%s: the blade has a thickness" % id)
			assert_gt(V3.distance(w.blade.base, w.blade.tip), 0.05, "%s: the blade has a length" % id)
		if id == &"fists":
			assert_not_null(w.foot, "bare hands kick")
		else:
			assert_null(w.foot, "%s has no kicks" % id)


func test_each_blade_runs_between_its_markers() -> void:
	for id: StringName in WeaponLook.IDS:
		var w: Node3D = _weapon(id)
		var blade: StrikeSegment = Moves.WEAPONS[id].blade
		var base: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_BASE).position
		var tip: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_TIP).position
		assert_lt(_v(blade.base).distance_to(base), 0.01, "%s: the base is BladeBase %s" % [id, base])
		assert_lt(_v(blade.tip).distance_to(tip), 0.01, "%s: the tip is BladeTip %s" % [id, tip])


func test_two_handed_weapons_put_the_off_hand_on_its_marker() -> void:
	for id: StringName in WeaponLook.IDS:
		var w: WeaponDef = Moves.WEAPONS[id]
		var marker: Marker3D = WeaponLook.marker(_weapon(id), WeaponLook.OFF_HAND_GRIP)
		if WeaponLook.load_id(id).two_handed:
			assert_not_null(w.off_hand_grip, "%s is held in both hands" % id)
			if w.off_hand_grip != null:
				assert_lt(_v(w.off_hand_grip).distance_to(marker.position), 0.01, "%s: the off hand at OffHandGrip %s" % [id, marker.position])
		else:
			assert_null(w.off_hand_grip, "%s is held in one hand" % id)
	assert_null(Moves.FISTS.off_hand_grip, "bare hands are two fists")


func test_each_blade_is_as_thick_as_the_model_s() -> void:
	for id: StringName in WeaponLook.IDS:
		var w: Node3D = _weapon(id)
		var blade: StrikeSegment = Moves.WEAPONS[id].blade
		var base_y: float = WeaponLook.marker(w, WeaponLook.BLADE_BASE).position.y
		var tip_y: float = WeaponLook.marker(w, WeaponLook.BLADE_TIP).position.y
		# the furthest any part of the blade, between the markers, stands out
		# of the flat (weapon +Z)
		var out: float = 0.0
		for node: Node in w.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			var xf: Transform3D = w.global_transform.affine_inverse() * mi.global_transform
			for s: int in mi.mesh.get_surface_count():
				for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
					var p: Vector3 = xf * v
					if p.y >= base_y and p.y <= tip_y:
						out = maxf(out, absf(p.z))
		assert_gt(out, 0.0, "%s: the blade was measured" % id)
		assert_between(blade.thickness / 2.0 - out, 0.0, 0.001,
				"%s: half of %.4f m covers the model's %.4f m out of the flat, by at most 1 mm" % [id, blade.thickness, out])


func test_the_fist_runs_along_the_knuckles() -> void:
	var fist: StrikeSegment = Moves.FISTS.blade
	var a: Vector3 = _v(fist.base)
	var b: Vector3 = _v(fist.tip)
	var half: float = fist.thickness / 2.0
	var needed: float = 0.0
	for id: StringName in FighterLook.IDS:
		var sk: Skeleton3D = _skeleton(id)
		var grip: HandGrip = HandGrip.new()
		autofree(grip)
		grip.measure(sk)
		for side: String in SIDES:
			var hand: float = sk.get_bone_rest(sk.find_bone(side + "MiddleProximal")).origin.y
			var finger_half: float = HandGrip.FINGER_HALF * hand
			var to_fist: Transform3D = (_rest(sk, side + "Hand") * grip.fist(side)).affine_inverse()
			var knuckles: Dictionary[String, Vector3] = {}
			for finger: String in HandGrip.FINGERS:
				var k: Vector3 = to_fist * _rest(sk, side + finger + "Proximal").origin
				knuckles[finger] = k
				var covered: float = _off(k, a, b) + finger_half
				needed = maxf(needed, covered)
				assert_lt(covered, half, "%s %s %s knuckle at %s is inside the fist" % [id, side, finger, k])
			# the ends at the outer knuckles, on the fist's middle plane
			var little: Vector3 = knuckles["Little"] * Vector3(1, 1, 0)
			var index: Vector3 = knuckles["Index"] * Vector3(1, 1, 0)
			assert_lt(a.distance_to(little), 0.01, "%s %s: the base is at the little finger's knuckle %s" % [id, side, little])
			assert_lt(b.distance_to(index), 0.01, "%s %s: the tip is at the index finger's knuckle %s" % [id, side, index])
	assert_lt(half - needed, 0.005, "the fist is no thicker than the knuckles need (%.4f m)" % needed)


func test_the_foot_runs_along_the_boot() -> void:
	var foot: StrikeSegment = Moves.FISTS.foot
	var a: Vector3 = _v(foot.base)
	var b: Vector3 = _v(foot.tip)
	var half: float = foot.thickness / 2.0
	assert_eq(a.x, b.x, "the foot's segment runs level with the sole")
	assert_eq([a.z, b.z], [0.0, 0.0], "down the middle of the foot")
	for id: StringName in FighterLook.IDS:
		var sk: Skeleton3D = _skeleton(id)
		for side: String in SIDES:
			var ankle: Transform3D = _rest(sk, side + "Foot")
			# the foot's frame (Swing): from the ankle, +Y along the foot toward
			# the toes and +X out of the sole, which at rest are the Foot bone's
			# +Y, level and forward, and its -Z, down
			assert_almost_eq(ankle.basis.y, Vector3(0, 0, 1), Vector3.ONE * 0.02, "%s %s: the foot points forward, level" % [id, side])
			assert_almost_eq(ankle.basis.z, Vector3(0, 1, 0), Vector3.ONE * 0.02, "%s %s: and its +Z is up" % [id, side])
			var to_foot: Transform3D = Transform3D(Basis(-ankle.basis.z, ankle.basis.y, ankle.basis.x), ankle.origin).affine_inverse()
			for bone: String in [side + "Toes", TOE_TIPS[side]]:
				var p: Vector3 = to_foot * _rest(sk, bone).origin
				assert_lt(_off(p, a, b), half, "%s %s: %s at %s is inside the foot" % [id, side, bone, p])
			# the underside on the sole: the ground, at rest, is the ankle's
			# height out of the sole
			assert_almost_eq(a.x + half, ankle.origin.y, 0.01, "%s %s: the underside is on the sole" % [id, side])
			# the ends at the boot's heel and toe: its furthest points back and
			# forward near the ground
			var heel: float = INF
			var toe: float = -INF
			for node: Node in sk.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = node
				for s: int in mi.mesh.get_surface_count():
					for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
						var p: Vector3 = mi.global_transform * v
						if p.y < 0.03 and absf(p.x - ankle.origin.x) < 0.09:
							var along: float = (to_foot * p).y
							heel = minf(heel, along)
							toe = maxf(toe, along)
			assert_almost_eq(a.y - half, heel, 0.015, "%s %s: the heel" % [id, side])
			assert_almost_eq(b.y + half, toe, 0.015, "%s %s: the toe" % [id, side])
