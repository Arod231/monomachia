extends GutTest
## SwingCheck (task 7.7) seats a hand on its grip as the fighter rig does
## (FighterRig.seat(): the fist turned round the handle to its forearm, task
## 14.8), so the wrists it checks are the wrists the rig draws: for each
## fighter at rest, both hands of the Katana and a dagger in the left hand,
## the wrist within 5 mm and the hand pointing the same way within 1°. The
## rules' (right, up, forward) become Godot's axes with right as -X.

const ORIENTATIONS: Array[Array] = [
	# grip, blade, edge
	[[0.1, 1.3, 0.35], [0.0, 1.0, 0.3], [0.0, -0.3, 1.0]],
	[[0.3, 1.5, 0.1], [-0.7, 0.2, -0.6], [0.6, 0.3, -0.5]],
	[[-0.2, 1.0, 0.4], [-0.5, -0.8, 0.3], [0.2, -0.2, -0.9]],
]


static func _godot(v: V3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


static func _v(a: Array) -> V3:
	return V3.make(a[0], a[1], a[2])


## A key holding the weapon at `o` (grip, blade, edge; the edge squared).
static func _key(o: Array) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.grip = _v(o[0])
	k.blade = V3.normalized(_v(o[1]))
	var edge: V3 = _v(o[2])
	k.edge = V3.normalized(V3.sub(edge, V3.scale(k.blade, V3.dot(edge, k.blade))))
	return k


## The weapon posed by `k`, in Godot's axes: X the edge, Y the blade.
static func _weapon_xf(k: Swing.KeyPose) -> Transform3D:
	var x: Vector3 = _godot(k.edge)
	var y: Vector3 = _godot(k.blade)
	return Transform3D(Basis(x, y, x.cross(y)), _godot(k.grip))


## The rig's seat of the hand on `side` at rest: its shoulder where the rest
## pose has it, the chest unturned.
func _assert_seated(rig: FighterRig, side: String, weapon_xf: Transform3D, point: Vector3, arm: SwingCheck.Arm, what: String) -> void:
	var sk: Skeleton3D = rig.skeleton
	var shoulder: Vector3 = sk.get_bone_global_rest(sk.find_bone(side + "UpperArm")).origin
	var chest: Basis = sk.get_bone_global_rest(sk.find_bone("UpperChest")).basis.orthonormalized()
	var hand: Transform3D = rig.seat(side, weapon_xf, point, shoulder, chest)
	assert_lt(hand.origin.distance_to(_godot(arm.wrist)), 0.005, "%s: the wrist at %s, the rig's %s" % [what, _godot(arm.wrist), hand.origin])
	var turn: float = rad_to_deg(hand.basis.y.normalized().angle_to(_godot(arm.along)))
	assert_lt(turn, 1.0, "%s: the hand points along the rig's hand (%.2f° off)" % [what, turn])


func test_the_check_seats_the_hands_as_the_rig_does() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = FighterLook.instantiate_fighter(id)
		add_child_autofree(f)
		var body: ReferenceBody = ReferenceBody.of(id)
		for o: Array in ORIENTATIONS:
			var k: Swing.KeyPose = _key(o)
			var s: Swing = Swing.new(1)
			s.add_track(&"right_hand", [k] as Array[Swing.KeyPose])
			var katana: SwingCheck.Moment = SwingCheck.moment(s, Moves.KATANA, body, 0.0)
			var xf: Transform3D = _weapon_xf(k)
			var off: V3 = Moves.KATANA.off_hand_grip
			_assert_seated(f.rig, "Right", xf, Vector3.ZERO, katana.arms[&"right"], "%s right hand %s" % [id, o[0]])
			_assert_seated(f.rig, "Left", xf, Vector3(off.x, off.y, off.z), katana.arms[&"left"], "%s left hand, Katana %s" % [id, o[0]])
			var left: Swing = Swing.new(1)
			left.add_track(&"left_hand", [k] as Array[Swing.KeyPose])
			var dagger: SwingCheck.Moment = SwingCheck.moment(left, Moves.DAGGERS, body, 0.0)
			_assert_seated(f.rig, "Left", xf, Vector3.ZERO, dagger.arms[&"left"], "%s left hand, dagger %s" % [id, o[0]])
