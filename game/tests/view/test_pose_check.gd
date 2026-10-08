extends GutTest
## PoseCheck, the checks every swing and stance must pass on the real posed
## skeleton (the spec's swing rules): wrists within their limits, elbows bent
## 150-160 degrees on contact and never locked, the knees over the toes, the
## blade clear of its own body, and how much blade enters a defender. Made-up
## poses built from a real guard fail where they should; the Katana guard
## is measured on both fighters, the wrists and elbows the IK places
## (test_guard_stance.gd checks that it
## passes); MoveBench plays a move frame by frame on the
## rules' clock, and a report over the stand-in Katana attacks prints.

const SIDES: Array[String] = ["Right", "Left"]


func _bench(fighter_id: StringName, weapon: WeaponDef = Moves.KATANA) -> MoveBench:
	var bench: MoveBench = MoveBench.new(self, fighter_id, weapon)
	return bench


func after_each() -> void:
	MoveBench.free_all()


## A frame of `bench`'s fighter standing in its guard: the match's Katana
## guard, two-handed (milestone-1 task 33), unless `grip` says otherwise.
func _guard_frame(bench: MoveBench, grip: StringName = WeaponGrip.TWO_HANDED) -> PoseCheck.Frame:
	bench.grip = grip
	bench.stand()
	return await bench.frame()


func _bone(bench: MoveBench, frame: PoseCheck.Frame, bone: String) -> Transform3D:
	return frame.bones[bench.view.model.skeleton.find_bone(bone)]


func _set_bone(bench: MoveBench, frame: PoseCheck.Frame, bone: String, xf: Transform3D) -> void:
	frame.bones[bench.view.model.skeleton.find_bone(bone)] = xf


func _has(failures: PackedStringArray, words: String) -> bool:
	for f: String in failures:
		if f.contains(words):
			return true
	return false


# ------------------------------------------------------------------ the body

## Each fighter's capsules are measured from its own meshes: the head's
## wraps the hair, the hood and the hat, and the others hug their limbs.
func test_the_body_capsules_are_measured_from_each_fighter() -> void:
	var bands: Dictionary[String, Vector2] = {
		"head": Vector2(0.08, 0.25),
		"torso": Vector2(0.10, 0.22),
		"right upper arm": Vector2(0.035, 0.10),
		"left upper arm": Vector2(0.035, 0.12),
		"right forearm": Vector2(0.03, 0.08),
		"left forearm": Vector2(0.03, 0.08),
		"right thigh": Vector2(0.06, 0.18),
		"left thigh": Vector2(0.06, 0.18),
	}
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var capsules: Array[PoseCheck.Capsule] = bench.check.capsules
		var names: Array[String] = []
		for c: PoseCheck.Capsule in capsules:
			names.append(c.name)
			gut.p("%s %s: radius %.3f m, axis %.3f m" % [id, c.name, c.radius, c.length])
			assert_between(c.radius, bands[c.name].x, bands[c.name].y, "%s %s" % [id, c.name])
		assert_eq(names, bands.keys(), "%s: head, torso, arms and thighs" % id)
	# the Hunter's tricorn sits inside his head capsule
	var hunter: MoveBench = _bench(&"hunter")
	var frame: PoseCheck.Frame = await _guard_frame(hunter)
	var head: PoseCheck.Capsule = hunter.check.capsule("head")
	var ends: PackedVector3Array = head.ends(frame.bones)
	var hat: MeshInstance3D = hunter.view.model.skeleton.get_node(^"HeadAttachment/Hat")
	# the hat rides the head bone, as the frame has it
	var on_head: Transform3D = _bone(hunter, frame, "Head") * hat.transform
	var worst: float = 0.0
	for s: int in hat.mesh.get_surface_count():
		for v: Vector3 in hat.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = on_head * v
			worst = maxf(worst, p.distance_to(Geometry3D.get_closest_point_to_segment(p, ends[0], ends[1])))
	assert_lt(worst, head.radius + 0.002, "the hat is inside the head capsule")


# ------------------------------------------------------------------ the guard

## The match's Katana guard is measured on both fighters: both wrists,
## both elbows, both knees and the blade. Since plan task 14.8 it passes
## (test_guard_stance.gd); before, the wrists bent past their limits and the
## Rogue's idle clip caved her left knee.
func test_the_katana_guard_is_measured_on_both_fighters() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		# the one-handed guard (KE task 10): the off hand on its clip with the
		# packs, the blade clear of the body
		var one: PoseCheck.Frame = await _guard_frame(bench, WeaponGrip.ONE_HANDED)
		var one_report: PoseCheck.Report = bench.check.measure(one)
		gut.p("%s one-handed katana guard: %s; fails: %s" % [id, one_report.summary(), one_report.failures()])
		assert_gt(one_report.blade_gap, PoseCheck.BLADE_CLEARANCE, "%s one-handed: the blade clears the body" % id)
		assert_eq(one.driven.has("Left"), not ClipLibraries.available(), "%s one-handed: the off hand on IK only on the CC0 stand-ins" % id)
		var frame: PoseCheck.Frame = await _guard_frame(bench)
		var report: PoseCheck.Report = bench.check.measure(frame)
		gut.p("%s katana guard: %s; fails: %s" % [id, report.summary(), report.failures()])
		assert_gt(report.blade_gap, PoseCheck.BLADE_CLEARANCE, "%s: the blade clears the body" % id)
		# the keyed guard's right hand rides the clip (milestone-1 task 33);
		# the off hand is on its grip by IK, and the right too where the
		# weapon is drawn in to it (the CC0 stand-in's one-handed idle)
		assert_true(frame.driven.has("Left"), "%s: the off hand placed by IK" % id)
		assert_eq(report.wrists.keys(), Array(frame.driven), "%s: each wrist the IK places measured" % id)
		assert_eq(report.elbows.keys(), Array(frame.driven), "%s: each elbow the IK places measured" % id)
		assert_eq(report.knees.keys(), SIDES, "%s: both knees measured" % id)
		assert_lt(report.blade_gap, 1.0, "%s: the blade is measured" % id)


## Measuring a frame twice gives the same numbers, and so does capturing the
## same pose twice.
func test_the_same_pose_measures_the_same() -> void:
	var bench: MoveBench = _bench(&"rogue")
	var a: PoseCheck.Report = bench.check.measure(await _guard_frame(bench))
	var b: PoseCheck.Report = bench.check.measure(await _guard_frame(bench))
	assert_eq(a.summary(), b.summary())


# ------------------------------------------------------------------ made-up poses

## A hand bent from the forearm's line (the guard's hand put in line with
## its forearm, then bent): 55 degrees toward the palm passes, 70 either way
## fails; 20 degrees toward the thumb passes, 30 either way fails. A hand
## bone's +X points to the thumb on the right hand and away from it on the
## left, so the same turn reads the other way round on each.
func test_a_wrist_bent_past_its_limits_fails() -> void:
	var bench: MoveBench = _bench(&"rogue")
	var guard: PoseCheck.Frame = await _guard_frame(bench)
	for side: String in SIDES:
		# a turn about the palm's normal that moves the fingers toward the thumb
		var thumbward: float = -1.0 if side == "Right" else 1.0
		for case: Array in [[0.0, 0.0, true], [55.0, 0.0, true], [70.0, 0.0, false], [-70.0, 0.0, false], [0.0, 20.0, true], [0.0, 30.0, false], [0.0, -30.0, false]]:
			var frame: PoseCheck.Frame = guard.copy()
			# both hands placed here, as the IK places them
			frame.driven = SIDES.duplicate()
			var hand: Transform3D = bench.check.straight_hand(side, frame.bones)
			# bend about the hand's own X (toward the palm), then deviate
			# about its palm normal
			var b: Basis = Basis(hand.basis.x.normalized(), deg_to_rad(case[0])) * hand.basis
			b = Basis(b.z.normalized(), thumbward * deg_to_rad(case[1])) * b
			_set_bone(bench, frame, side + "Hand", Transform3D(b, hand.origin))
			var report: PoseCheck.Report = bench.check.measure(frame)
			var wrist: Vector2 = report.wrists[side]
			assert_almost_eq(wrist.x, case[0], 0.5, "%s bend %s" % [side, case])
			assert_almost_eq(wrist.y, case[1], 0.5, "%s deviation %s" % [side, case])
			assert_eq(_has(report.failures(), side.to_lower() + " wrist"), not case[2], "%s %s: %s" % [side, case, report.failures()])


## A blade crossing over the crown 3 cm from the head capsule (the hat's,
## on the Hunter) fails, naming the head; at 6 cm it passes.
func test_a_blade_near_the_head_fails() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var guard: PoseCheck.Frame = await _guard_frame(bench)
		var head: PoseCheck.Capsule = bench.check.capsule("head")
		var ends: PackedVector3Array = head.ends(guard.bones)
		var up: Vector3 = (ends[1] - ends[0]).normalized()
		var across: Vector3 = up.cross(Vector3.BACK).normalized()
		for case: Array in [[0.03, false], [0.06, true]]:
			var frame: PoseCheck.Frame = guard.copy()
			var at: Vector3 = ends[1] + up * (head.radius + case[0])
			frame.blades = [PackedVector3Array([at - across * 0.35, at + across * 0.35])]
			var report: PoseCheck.Report = bench.check.measure(frame)
			assert_almost_eq(report.blade_gap, case[0], 0.003, "%s: %.0f cm" % [id, case[0] * 100.0])
			assert_eq(report.blade_near, "head", id)
			assert_eq(_has(report.failures(), "from the head"), not case[1], "%s %s: %s" % [id, case, report.failures()])


## A frame of `bench`'s fighter in its rest pose (arms out to the sides),
## holding nothing.
func _rest_frame(bench: MoveBench) -> PoseCheck.Frame:
	var frame: PoseCheck.Frame = PoseCheck.Frame.new()
	var sk: Skeleton3D = bench.view.model.skeleton
	for i: int in sk.get_bone_count():
		frame.bones.append(sk.get_bone_global_rest(i))
	return frame


## Each capsule's cap stops where its part does: on the rest pose (arms out
## along X), a blade crossing the right arm's line through the hand, a
## forearm's radius and 4.5 cm past the wrist, clears the forearm (the hand
## isn't a capsule; a cap round the wrist joint would be 4.5 cm off), while
## one crossing 4 cm over the forearm's middle doesn't.
func test_the_capsules_stop_where_their_parts_do() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var frame: PoseCheck.Frame = _rest_frame(bench)
		var wrist: Vector3 = _bone(bench, frame, "RightHand").origin
		var elbow: Vector3 = _bone(bench, frame, "RightLowerArm").origin
		var forearm: PoseCheck.Capsule = bench.check.capsule("right forearm")
		var palm: Vector3 = wrist + (wrist - elbow).normalized() * (forearm.radius + 0.045)
		var over: Vector3 = (wrist + elbow) * 0.5 + Vector3(0.0, forearm.radius + 0.04, 0.0)
		for case: Array in [[palm, true], [over, false]]:
			frame.blades = [PackedVector3Array([case[0] + Vector3(0, 0, -0.3), case[0] + Vector3(0, 0, 0.3)])]
			var report: PoseCheck.Report = bench.check.measure(frame)
			assert_eq(report.passed(), case[1], "%s %s: %s" % [id, "through the hand" if case[1] else "over the forearm", report.summary()])


## A held blade's base sits about a hand's width from its own wrist, and
## clears the forearm's capsule, which stops where the forearm does.
func test_a_held_blade_clears_its_own_wrist() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var frame: PoseCheck.Frame = await _guard_frame(bench)
		var base: Vector3 = frame.blades[0][0]
		var wrist: Vector3 = _bone(bench, frame, "RightHand").origin
		assert_lt(base.distance_to(wrist), 0.15, "%s: the blade's base is near the wrist" % id)
		var forearm: PackedVector3Array = bench.check.capsule("right forearm").ends(frame.bones)
		var near: Vector3 = Geometry3D.get_closest_point_to_segment(base, forearm[0], forearm[1])
		assert_gt(base.distance_to(near) - bench.check.capsule("right forearm").radius, PoseCheck.BLADE_CLEARANCE, "%s: and clear of the forearm" % id)


## Turns the forearm (and the hand with it) about the elbow, in the arm's
## plane, until the elbow's inside angle is `angle` degrees.
func _bend_elbow(bench: MoveBench, frame: PoseCheck.Frame, side: String, angle: float) -> void:
	var s: Vector3 = _bone(bench, frame, side + "UpperArm").origin
	var e: Vector3 = _bone(bench, frame, side + "LowerArm").origin
	var hand: Transform3D = _bone(bench, frame, side + "Hand")
	var now: float = rad_to_deg((s - e).angle_to(hand.origin - e))
	var turn: Basis = Basis((s - e).cross(hand.origin - e).normalized(), deg_to_rad(angle - now))
	_set_bone(bench, frame, side + "Hand", Transform3D(turn * hand.basis, e + turn * (hand.origin - e)))


func test_a_locked_elbow_fails_and_contact_wants_150_to_160() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var guard: PoseCheck.Frame = await _guard_frame(bench)
	var wrist: Vector2 = bench.check.measure(guard).wrists["Left"]
	# [angle, contact, the elbow fails]
	for case: Array in [[180.0, false, true], [172.0, false, true], [165.0, false, false], [165.0, true, true], [155.0, true, false], [140.0, true, true], [140.0, false, false]]:
		var frame: PoseCheck.Frame = guard.copy()
		_bend_elbow(bench, frame, "Left", case[0])
		var report: PoseCheck.Report = bench.check.measure(frame, case[1])
		assert_almost_eq(report.elbows["Left"], case[0], 0.1, "%s" % [case])
		assert_eq(_has(report.failures(), "left elbow"), case[2], "%s: %s" % [case, report.failures()])
		assert_almost_eq(report.wrists["Left"], wrist, Vector2(0.1, 0.1), "%s: the hand moved with the forearm" % [case])


## A knee is measured from the plane through its hip that holds the line to
## its ankle and the way its toes point, outside positive: a foot turned out
## takes the plane with it, so a knee over turned-out toes is on it.
func test_a_knee_is_measured_against_its_toes() -> void:
	var hip: Vector3 = Vector3(0.1, 0.9, 0.0)
	var other: Vector3 = Vector3(-0.1, 0.9, 0.0)
	var ankle: Vector3 = Vector3(0.1, 0.08, 0.0)
	for yaw_deg: float in [0.0, 40.0]:
		# a left foot (+X is the fighter's left) turned out by yaw_deg
		var toes: Vector3 = Vector3(sin(deg_to_rad(yaw_deg)), 0.0, cos(deg_to_rad(yaw_deg)))
		var foot: Transform3D = Transform3D(Basis(toes.cross(Vector3.UP), toes, Vector3.UP), ankle)
		var out_of_plane: Vector3 = (ankle - hip).cross(toes).normalized()
		if out_of_plane.dot(hip - other) < 0.0:
			out_of_plane = -out_of_plane
		var over_toes: Vector3 = (hip + ankle) * 0.5 + toes * 0.08
		for k: float in [0.0, -0.03, 0.04]:
			assert_almost_eq(PoseCheck.knee_offset(hip, over_toes + out_of_plane * k, foot, other), k, 1e-5, "foot turned %.0f, knee %+.2f" % [yaw_deg, k])
	# the right leg: outside is toward -X
	var right: Transform3D = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(-0.1, 0.08, 0.0))
	assert_almost_eq(PoseCheck.knee_offset(other, Vector3(-0.13, 0.5, 0.06), right, hip), 0.03, 1e-5, "the right knee out to its side")


## A knee pushed in past the foot line of the real guard fails.
func test_a_knee_inside_the_foot_line_fails() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var guard: PoseCheck.Frame = await _guard_frame(bench)
	var before: float = bench.check.measure(guard).knees["Right"]
	assert_false(_has(bench.check.measure(guard).failures(), "right knee"), "the guard's right knee passes")
	var hips: Vector3 = _bone(bench, guard, "RightUpperLeg").origin - _bone(bench, guard, "LeftUpperLeg").origin
	var inward: Vector3 = -Vector3(hips.x, 0.0, hips.z).normalized()
	var frame: PoseCheck.Frame = guard.copy()
	var knee: Transform3D = _bone(bench, frame, "RightLowerLeg")
	knee.origin += inward * (before + 0.04)
	_set_bone(bench, frame, "RightLowerLeg", knee)
	var report: PoseCheck.Report = bench.check.measure(frame)
	assert_lt(report.knees["Right"], -0.02, "pushed inside")
	assert_true(_has(report.failures(), "right knee"), "%s" % report.failures())


# ------------------------------------------------------------------ reach

## Reach is the length of blade inside a defender's capsule (0.42 m round,
## from the feet to 2.0 m since KE task 3).
func test_reach_is_the_length_of_blade_inside_the_defender() -> void:
	var feet: Vector3 = Vector3(0.0, 0.0, 2.5)
	var front: float = 2.5 - PoseCheck.DEFENDER_RADIUS
	assert_almost_eq(PoseCheck.blade_inside(Vector3(0, 1, 1.9), Vector3(0, 1, 2.6), feet), 2.6 - front, 1e-4, "into the front")
	assert_almost_eq(PoseCheck.blade_inside(Vector3(0, 1, 1.9), Vector3(0, 1, front - 0.01), feet), 0.0, 1e-6, "short of it")
	assert_almost_eq(PoseCheck.blade_inside(Vector3(-0.5, 1, 2.5), Vector3(0.5, 1, 2.5), feet), 0.84, 1e-4, "right through")
	# over the top: the cap is round, so a blade 0.2 m off the axis at the
	# top of the capsule's height only clips it
	var top: float = PoseCheck.DEFENDER_HEIGHT - PoseCheck.DEFENDER_RADIUS
	var y: float = top + sqrt(PoseCheck.DEFENDER_RADIUS ** 2 - 0.2 ** 2) - 0.01
	var inside: float = PoseCheck.blade_inside(Vector3(-1, y, 2.7), Vector3(1, y, 2.7), feet)
	assert_between(inside, 0.01, 0.4, "the cap: %.3f" % inside)


# ------------------------------------------------------------------ the bench

## MoveBench plays a move on the rules' clock: one report per attack frame,
## hit-stop steps skipped, phases from the frame data and contact on the
## first active frame; the defender stands at the duelling distance.
func test_the_bench_plays_a_move_frame_by_frame() -> void:
	var bench: MoveBench = _bench(&"rogue")
	assert_almost_eq(bench.attacker.pos.x, 0.0, 1e-6)
	assert_almost_eq(bench.defender.pos.z - bench.attacker.pos.z, PoseCheck.SPACING, 1e-6, "the duelling distance")
	var def: AttackDef = Moves.KATANA.moves[&"k_l1"]
	var steps: Array[MoveBench.Step] = await bench.play(&"k_l1")
	var frames: Array[int] = []
	var contacts: int = 0
	for s: MoveBench.Step in steps:
		frames.append(s.frame)
		var want: StringName = &"startup" if s.frame <= def.startup else (&"active" if s.frame <= def.startup + def.active else &"recovery")
		assert_eq(s.phase, want, "frame %d" % s.frame)
		assert_eq(s.contact, s.frame == def.startup + 1, "frame %d" % s.frame)
		assert_eq(s.report.contact, s.contact)
		assert_gt(s.report.reach, -0.5, "reach measured on frame %d" % s.frame)
		if s.contact:
			contacts += 1
	assert_eq(contacts, 1, "one contact frame")
	var expected: Array[int] = []
	for i: int in frames.size():
		expected.append(i + 1)
	assert_eq(frames, expected, "every frame once, in order")
	assert_eq(frames.size(), def.startup + def.active + def.recovery - 1, "the whole move, up to the frame it ends on")
	assert_eq(bench.attacker.state, &"free", "and back to free")


## Each play starts afresh from the guard at the duelling distance, so the
## same move gives the same reports.
func test_the_bench_gives_the_same_reports_twice() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var a: Array[MoveBench.Step] = await bench.play(&"k_l2")
	await bench.play(&"k_h2")
	var b: Array[MoveBench.Step] = await bench.play(&"k_l2")
	assert_eq(a.size(), b.size())
	for i: int in mini(a.size(), b.size()):
		assert_eq(a[i].report.summary(), b[i].report.summary(), "frame %d" % a[i].frame)


## Not yet required to pass: the stand-in stick poses were made for a stick
## figure. Swings (plan task 14.10 on) must pass.
func test_a_move_stepped_by_hand_gives_the_frames_it_plays() -> void:
	var bench: MoveBench = _bench(&"rogue")
	var played: Array[MoveBench.Step] = await bench.play(&"k_l1")
	assert_true(bench.begin(&"k_l1"))
	assert_eq(bench.move, Moves.KATANA.moves[&"k_l1"], "the move being played")
	var stepped: Array[MoveBench.Step] = []
	var s: MoveBench.Step = await bench.next_frame()
	while s != null:
		stepped.append(s)
		s = await bench.next_frame()
	assert_eq(stepped.size(), played.size())
	for i: int in mini(stepped.size(), played.size()):
		assert_eq(stepped[i].frame, played[i].frame)
		assert_eq(stepped[i].phase, played[i].phase)
		assert_eq(stepped[i].report.summary(), played[i].report.summary(), "frame %d measures the same" % played[i].frame)
	assert_null(await bench.next_frame(), "nothing after the move ends")


func test_a_report_over_the_stick_pose_katana_attacks_prints() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var lines: Array[String] = []
		for move_id: StringName in Moves.KATANA.moves:
			var steps: Array[MoveBench.Step] = await bench.play(move_id)
			assert_gt(steps.size(), 0, "%s %s plays" % [id, move_id])
			lines.append(MoveBench.summary(move_id, steps))
		gut.p("%s, StickPose Katana attacks:\n%s" % [id, "\n".join(lines)])


# ------------------------------------------------------------------ foot slide

## A copy of `frame` with foot `side` at world point `at` (the fighter's
## root carries the skeleton into the world).
func _foot_at(bench: MoveBench, frame: PoseCheck.Frame, side: String, at: Vector3) -> PoseCheck.Frame:
	var f: PoseCheck.Frame = frame.copy()
	var foot: Transform3D = _bone(bench, f, side + "Foot")
	foot.origin = f.root.affine_inverse() * at
	_set_bone(bench, f, side + "Foot", foot)
	return f


## A copy of `frame` with the fighter's root moved by `offset` (world).
func _rooted(frame: PoseCheck.Frame, offset: Vector3) -> PoseCheck.Frame:
	var f: PoseCheck.Frame = frame.copy()
	f.root = Transform3D(f.root.basis, f.root.origin + offset)
	return f


## The ground point under where foot `side` would rest (its ankle at its
## rest height), `forward` metres ahead in the world.
func _ground(bench: MoveBench, side: String, forward: float) -> Vector3:
	var x: float = -0.12 if side == "Right" else 0.12
	return Vector3(x, bench.check.ankle_rest[side], forward)


## A planted foot held still while the body moves over it doesn't slide.
func test_a_planted_foot_that_stays_put_does_not_slide() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var guard: PoseCheck.Frame = await _guard_frame(bench)
	var track := PoseCheck.FootTrack.new(bench.check)
	for i: int in 10:
		var f: PoseCheck.Frame = _rooted(guard, Vector3(0.0, 0.0, 0.02 * i))
		f = _foot_at(bench, f, "Right", _ground(bench, "Right", 0.0))
		f = _foot_at(bench, f, "Left", _ground(bench, "Left", 0.3))
		var report: PoseCheck.Report = bench.check.measure(f, false, track)
		assert_almost_eq(report.feet["Right"], 0.0, 1e-5, "frame %d" % i)
		assert_almost_eq(report.feet["Left"], 0.0, 1e-5, "frame %d" % i)
		assert_false(_has(report.failures(), "foot slid"), "%s" % report.failures())


## A planted foot that creeps 6 mm a frame slides from where it landed, and
## fails once it is more than 1 cm away; the summary says so.
func test_a_sliding_foot_fails_past_1_cm() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var guard: PoseCheck.Frame = await _guard_frame(bench)
	var track := PoseCheck.FootTrack.new(bench.check)
	for i: int in 5:
		var f: PoseCheck.Frame = _foot_at(bench, guard, "Right", _ground(bench, "Right", 0.0048 * i) + Vector3(0.0036 * i, 0.0, 0.0))
		var report: PoseCheck.Report = bench.check.measure(f, false, track)
		var slid: float = Vector2(0.0036 * i, 0.0048 * i).length()
		assert_almost_eq(report.feet["Right"], slid, 1e-5, "frame %d: along the ground from where it landed" % i)
		assert_eq(_has(report.failures(), "right foot slid"), slid > PoseCheck.FOOT_SLIDE_MAX, "frame %d: %s" % [i, report.failures()])
		if i == 4:
			assert_true(report.failures().has("right foot slid 2.4 cm"), "%s" % report.failures())
			assert_true(report.summary().contains("slide R 2.4"), report.summary())


## Rising or settling within the plant doesn't count as sliding: only the
## way along the ground does.
func test_a_planted_foot_moving_up_and_down_does_not_slide() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var guard: PoseCheck.Frame = await _guard_frame(bench)
	var track := PoseCheck.FootTrack.new(bench.check)
	for lift: float in [0.0, 0.02, 0.05, 0.0]:
		var f: PoseCheck.Frame = _foot_at(bench, guard, "Right", _ground(bench, "Right", 0.0) + Vector3(0.0, lift, 0.0))
		var report: PoseCheck.Report = bench.check.measure(f, false, track)
		assert_true(report.feet.has("Right"), "held planted at %.2f m up (let go above %.2f)" % [lift, PoseCheck.LIFT_HEIGHT])
		assert_almost_eq(report.feet["Right"], 0.0, 1e-5)


## A lifted foot isn't measured; put down again elsewhere, it lands afresh.
## A foot that comes down only to between the plant and lift heights isn't
## planted yet.
func test_a_lifted_foot_lands_afresh() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var guard: PoseCheck.Frame = await _guard_frame(bench)
	var track := PoseCheck.FootTrack.new(bench.check)
	var at: Vector3 = _ground(bench, "Right", 0.0)
	var steps: Array[Array] = [
		# [forward, lift, planted]
		[0.0, 0.0, true],
		[0.1, 0.10, false],
		[0.3, 0.045, false],
		[0.4, 0.0, true],
		[0.4, 0.0, true],
	]
	for s: Array in steps:
		var f: PoseCheck.Frame = _foot_at(bench, guard, "Right", at + Vector3(0.0, s[1], s[0]))
		var report: PoseCheck.Report = bench.check.measure(f, false, track)
		assert_eq(report.feet.has("Right"), s[2], "%s" % [s])
		if s[2]:
			assert_almost_eq(report.feet["Right"], 0.0, 1e-5, "%s: measured from where it came down" % [s])


## Without a track (a single frame, as the sheets' chosen frames were) no
## foot is measured.
func test_a_single_frame_measures_no_slide() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var report: PoseCheck.Report = bench.check.measure(await _guard_frame(bench))
	assert_true(report.feet.is_empty())


## The bench measures the feet on every frame of a move and its summary
## names the worst frame for the blade and for the feet.
func test_the_bench_tracks_the_feet_and_names_the_worst_frames() -> void:
	var bench: MoveBench = _bench(&"hunter")
	var steps: Array[MoveBench.Step] = await bench.play(&"k_l1")
	var measured: int = 0
	for s: MoveBench.Step in steps:
		if not s.report.feet.is_empty():
			measured += 1
	assert_gt(measured, 0, "planted feet measured")
	var worst: MoveBench.Worst = MoveBench.worst(steps)
	var gap: float = INF
	var slide: float = 0.0
	for s: MoveBench.Step in steps:
		gap = minf(gap, s.report.blade_gap)
		for side: String in s.report.feet:
			slide = maxf(slide, s.report.feet[side])
	assert_almost_eq(worst.blade_gap, gap, 1e-6)
	assert_almost_eq(worst.slide, slide, 1e-6)
	assert_eq(steps[worst.blade_frame - 1].report.blade_gap, gap, "the blade's worst frame")
	var summary: String = MoveBench.summary(&"k_l1", steps)
	assert_true(summary.contains("worst blade fr %d" % worst.blade_frame), summary)
	assert_true(summary.contains("slide %.1f cm" % (slide * 100.0)), summary)


## The baseline (milestone-1 task 9): every Katana move on the Hunter with
## the licensed clips, foot slide and blade clearance on every rules frame,
## each move's worst printed and recorded for the per-move checklist's items
## 8 and 9 (npm run checklist). Not yet required to pass: the families
## re-key the clips.
func test_local_every_katana_move_s_feet_and_blade_print_their_worst() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var bench: MoveBench = _bench(&"hunter")
	var lines: Array[String] = []
	for move_id: StringName in Moves.KATANA.moves:
		var steps: Array[MoveBench.Step] = await bench.play(move_id)
		assert_gt(steps.size(), 0, "%s plays" % move_id)
		var w: MoveBench.Worst = MoveBench.worst(steps)
		lines.append("%-9s %3d fr  blade %5.1f cm (%s, fr %d)  foot slide %4.1f cm (%s, fr %d)" % [
			move_id, steps.size(), w.blade_gap * 100.0, w.blade_near, w.blade_frame,
			w.slide * 100.0, w.slide_side.to_lower() if w.slide_side != "" else "-", w.slide_frame])
		ChecklistResults.record(8, move_id, w.slide <= PoseCheck.FOOT_SLIDE_MAX, "worst %.1f cm at frame %d" % [w.slide * 100.0, w.slide_frame])
		ChecklistResults.record(9, move_id, w.blade_gap >= PoseCheck.BLADE_CLEARANCE, "worst %.1f cm at frame %d" % [w.blade_gap * 100.0, w.blade_frame])
	gut.p("hunter, Katana moves with the clips, worst over every rules frame:\n" + "\n".join(lines))


## KE task 10: each grip's guard idle and block and both re-grips keep the
## 1.3 m blade clear of the body (PoseCheck.BLADE_CLEARANCE) on every rules
## frame, on both fighters: standing one-handed, switching to two hands,
## standing, then guarding, switching back to one hand guarding (the move
## sheet's grip_switch drive).
func test_local_each_grip_s_guards_and_re_grips_keep_the_blade_clear() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var grip: int = 1 << Btn.GRIP
	var block: int = 1 << Btn.BLOCK
	var steps: Array = [[12, 0], [1, grip], [30, 0], [12, block], [1, block | grip], [30, block]]
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		bench.stand()
		## the worst by clip: [blade gap (m), its frame]
		var worst: Dictionary[String, Array] = {}
		var n: int = 0
		for s: Array in steps:
			for i: int in s[0]:
				bench.drive(RawInput.make(0.0, 0.0, s[1]))
				n += 1
				var shot: ClipDirector.Shot = bench.view.shot
				var clip: String = String(shot.clip.name).get_file() if shot.clip != null else String(shot.idle).get_file()
				var r: PoseCheck.Report = bench.check.measure(await bench.frame())
				var w: Array = worst.get(clip, [INF, 0])
				if r.blade_gap < w[0]:
					worst[clip] = [r.blade_gap, n]
		var lines: PackedStringArray = []
		for clip: String in worst:
			lines.append("%-18s blade %5.1f cm from the body (frame %d)" % [clip, worst[clip][0] * 100.0, worst[clip][1]])
			assert_gt(worst[clip][0], PoseCheck.BLADE_CLEARANCE, "%s %s: the blade %.1f cm from the body at frame %d" % [id, clip, worst[clip][0] * 100.0, worst[clip][1]])
		gut.p("%s through a grip switch:\n%s" % [id, "\n".join(lines)])
		for want: String in ["KatanaGuard1H", "KatanaRegripTo2H", "KatanaGuard", "KatanaBlockLoop", "KatanaRegripTo1H", "Parry1H01_R_Loop"]:
			assert_true(worst.has(want), "%s: %s played" % [id, want])


## The per-move checklist's items 8 and 9 for the clip rows (milestone-1 task
## 40): the Hunter with the clips is struck by each of the string's lights
## from the front, each side and behind (standing, then guarding from the
## front), and has each light parried and parries each one, the rules moving
## the body; every rules frame its reaction, recoil or deflect plays is
## measured, and each clip's worst foot slide and blade clearance are
## recorded by row (a hit reaction's blade isn't checked). Recorded for the
## owner, not held: task 40 reports these, the new strings re-key them.
func test_local_the_reaction_clips_feet_and_blade_are_recorded() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var bench: MoveBench = _bench(&"hunter")
	var block: RawInput = RawInput.make(0.0, 0.0, 1 << Btn.BLOCK)
	## worst by clip: [slide (m), its frame, blade gap (m), its frame]
	var worst: Dictionary[StringName, Array] = {}
	var measure: Callable = func(track: PoseCheck.FootTrack, n: int) -> void:
		var shot: ClipDirector.Shot = bench.view.shot
		if shot == null or shot.clip == null:
			return
		var clip := StringName(String(shot.clip.name).get_file())
		var r: PoseCheck.Report = bench.check.measure(await bench.frame(), false, track)
		var w: Array = worst.get(clip, [0.0, 0, INF, 0])
		for side: String in r.feet:
			if r.feet[side] > w[0]:
				w[0] = r.feet[side]
				w[1] = n
		if r.blade_gap < w[2]:
			w[2] = r.blade_gap
			w[3] = n
		worst[clip] = w
	for light: StringName in [&"k_l1", &"k_l2", &"k_l3", &"k_l4"]:
		var startup: int = Moves.KATANA.moves[light].startup
		# struck: from the front, each side and behind, then guarding
		for c: Array in [[0.0, false], [90.0, false], [-90.0, false], [180.0, false], [0.0, true]]:
			bench.stand()
			bench.attacker.yaw = SimMath.wrap_angle(bench.attacker.yaw + deg_to_rad(c[0]))
			bench.attacker.blind_until = 1 << 30
			bench.defender.start_attack(light)
			var track: PoseCheck.FootTrack = PoseCheck.FootTrack.new(bench.check)
			var n: int = 0
			for i: int in 160:
				bench.drive(block if c[1] else RawInput.empty())
				if bench.attacker.state == &"hitstun" or bench.attacker.state == &"blockstun":
					n += 1
					await measure.call(track, n)
				elif n > 0:
					break
		# parried: the fighter's light, the opponent's guard pressed 3 frames
		# before it lands; then parrying: the opponent's light, its own guard
		for parrier: bool in [false, true]:
			bench.stand()
			var striker: Fighter = bench.defender if parrier else bench.attacker
			striker.start_attack(light)
			var track: PoseCheck.FootTrack = PoseCheck.FootTrack.new(bench.check)
			var n: int = 0
			for i: int in 160:
				var guard: RawInput = block if i >= startup - 3 else RawInput.empty()
				if parrier:
					bench.drive(guard)
				else:
					bench.drive(RawInput.empty(), guard)
				var shot: ClipDirector.Shot = bench.view.shot
				if shot != null and (shot.phase == &"recoil" or shot.phase == &"deflect"):
					n += 1
					await measure.call(track, n)
				elif n > 0:
					break
	var rows: Dictionary[StringName, Array] = ChecklistResults.clip_rows()
	var lines: PackedStringArray = []
	for row: StringName in rows:
		var feet: Dictionary = {}
		var blades: Dictionary = {}
		for clip: StringName in rows[row]:
			if not worst.has(clip):
				feet[clip] = ["not reached by the bench's strikes"]
				blades[clip] = feet[clip]
				continue
			var w: Array = worst[clip]
			lines.append("%-22s slide %4.1f cm (fr %d)  blade %5.1f cm (fr %d)" % [clip, w[0] * 100.0, w[1], w[2] * 100.0, w[3]])
			feet[clip] = [] if w[0] <= PoseCheck.FOOT_SLIDE_MAX else ["slides %.1f cm at frame %d" % [w[0] * 100.0, w[1]]]
			blades[clip] = [] if w[2] >= PoseCheck.BLADE_CLEARANCE else ["blade %.1f cm from the body at frame %d" % [w[2] * 100.0, w[3]]]
		ChecklistResults.record_clips(8, row, feet)
		if row != &"clip_hit_light":
			ChecklistResults.record_clips(9, row, blades)
	gut.p("the Hunter's reaction clips with the licensed clips, worst over every rules frame:\n" + "\n".join(lines))
	assert_gt(worst.size(), 0, "the bench reached the reaction clips")
