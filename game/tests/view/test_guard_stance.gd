extends GutTest
## The grounded guard stance (GuardStance) a fighter holding the Katana
## stands in, on both fighters in the match's view: the legs on IK with the
## right foot in front toward the opponent and the left behind, turned out
## 30-45 degrees, the feet apart and never crossed, the knees over the toes;
## the pelvis lowered and shifting its weight slowly between the feet on the
## rules' clock; the hips turned while the chest faces the opponent; and the
## Katana's guard passing PoseCheck. The stance gives way to the clips' feet
## as the legs walk, and the other weapons keep their hold clips.

const SIDES: Array[String] = ["Right", "Left"]


func after_each() -> void:
	MoveBench.free_all()
	SimHelpers.dispose_all()


## A bench with fighter `id` standing still in its guard, 2.5 m from the
## defender.
func _bench(id: StringName, weapon: WeaponDef = Moves.KATANA) -> MoveBench:
	return MoveBench.new(self, id, weapon)


func _bone(bench: MoveBench, frame: PoseCheck.Frame, bone: String) -> Transform3D:
	return frame.bones[bench.view.model.skeleton.find_bone(bone)]


## A posed bone's turn about the vertical from its rest (degrees, positive
## to the fighter's left).
func _heading(bench: MoveBench, frame: PoseCheck.Frame, bone: String) -> float:
	var sk: Skeleton3D = bench.view.model.skeleton
	return rad_to_deg(BodyLayer.heading(sk, sk.find_bone(bone), _bone(bench, frame, bone)))


## Which way a posed foot's toes point (degrees from straight ahead,
## positive to the fighter's left).
func _foot_yaw(bench: MoveBench, frame: PoseCheck.Frame, side: String) -> float:
	var toes: Vector3 = _bone(bench, frame, side + "Foot").basis.y
	return rad_to_deg(atan2(toes.x, toes.z))


## How far the posed hips are from where the clip has them.
func _hips_off_the_clip(bench: MoveBench) -> Vector3:
	var frame: PoseCheck.Frame = await bench.frame()
	var sk: Skeleton3D = bench.view.model.skeleton
	# outside an update the skeleton holds the clip's pose
	return _bone(bench, frame, "Hips").origin - sk.get_bone_global_pose(sk.find_bone("Hips")).origin


## Steps the bench's world `frames` times with no input and shows it.
func _wait(bench: MoveBench, frames: int) -> void:
	for i: int in frames:
		bench.drive(RawInput.empty())


# ------------------------------------------------------------------ the feet

## The right foot is in front, pointing at the opponent; the left is behind,
## turned out 30-45 degrees from the front foot.
func test_the_front_foot_points_at_the_opponent_and_the_rear_turns_out() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var frame: PoseCheck.Frame = await bench.frame()
		var front: Vector3 = _bone(bench, frame, "RightFoot").origin
		var rear: Vector3 = _bone(bench, frame, "LeftFoot").origin
		gut.p("%s: front foot %s at %+.1f°, rear %s at %+.1f°" % [id, front, _foot_yaw(bench, frame, "Right"), rear, _foot_yaw(bench, frame, "Left")])
		assert_gt(front.z - rear.z, 0.3, "%s: the right foot in front" % id)
		assert_lt(absf(_foot_yaw(bench, frame, "Right")), 10.0, "%s: the front foot points at the opponent" % id)
		var out: float = _foot_yaw(bench, frame, "Left") - _foot_yaw(bench, frame, "Right")
		assert_between(out, 30.0, 45.0, "%s: the rear foot turned out" % id)
		var sk: Skeleton3D = bench.view.model.skeleton
		for side: String in SIDES:
			assert_almost_eq(_bone(bench, frame, side + "Foot").basis.y.normalized().y, 0.0, 0.03, "%s: the %s foot flat" % [id, side])
			var rest: float = sk.get_bone_global_rest(sk.find_bone(side + "Foot")).origin.y
			assert_almost_eq(_bone(bench, frame, side + "Foot").origin.y, rest, 0.005, "%s: the %s foot on the floor" % [id, side])


## The feet stand a stance's width apart across the way the fighter faces,
## each on its own side of the mid-line, heels and toes.
func test_the_feet_stand_apart_without_crossing() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var frame: PoseCheck.Frame = await bench.frame()
		var width: float = _bone(bench, frame, "LeftFoot").origin.x - _bone(bench, frame, "RightFoot").origin.x
		gut.p("%s: the feet %.1f cm apart across" % [id, width * 100.0])
		assert_between(width, 0.2, 0.35, "%s: the stance's width" % id)
		for bone: String in ["Foot", "Toes"]:
			assert_lt(_bone(bench, frame, "Right" + bone).origin.x, -0.03, "%s: the right %s on the right" % [id, bone])
			assert_gt(_bone(bench, frame, "Left" + bone).origin.x, 0.03, "%s: the left %s on the left" % [id, bone])


## Each knee is over its toes: on the plane of its hip, ankle and toes or
## just outside it (PoseCheck's measure), never inside and not bowed out.
func test_the_knees_are_over_the_toes() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var report: PoseCheck.Report = bench.check.measure(await bench.frame())
		for side: String in SIDES:
			gut.p("%s %s knee %+.1f cm" % [id, side, report.knees[side] * 100.0])
			assert_between(report.knees[side], -0.002, 0.03, "%s: the %s knee over the toes" % [id, side])


# ------------------------------------------------------------------ the body

## The pelvis is lowered from the relaxed idle's, the hips turned toward the
## rear foot's side while the chest faces the opponent, the torso set a
## little forward over the hips, and the head up, watching the opponent.
func test_the_pelvis_is_lowered_and_turned_under_a_square_chest() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var frame: PoseCheck.Frame = await bench.frame()
		var sk: Skeleton3D = bench.view.model.skeleton
		# the clip's own hips, before the modifiers
		var clip_hips: Vector3 = sk.get_bone_global_pose(sk.find_bone("Hips")).origin
		var hips: Vector3 = _bone(bench, frame, "Hips").origin
		gut.p("%s: hips %.1f cm down, turned %+.1f°, chest %+.1f°" % [id, (clip_hips.y - hips.y) * 100.0, _heading(bench, frame, "Hips"), _heading(bench, frame, "UpperChest")])
		assert_between(clip_hips.y - hips.y, 0.06, 0.12, "%s: the pelvis lowered" % id)
		assert_between(_heading(bench, frame, "Hips"), 8.0, 25.0, "%s: the hips turned toward the rear foot's side" % id)
		assert_lt(absf(_heading(bench, frame, "UpperChest")), 8.0, "%s: the chest faces the opponent" % id)
		var neck: Vector3 = _bone(bench, frame, "Neck").origin
		assert_gt(neck.z - hips.z, 0.0, "%s: the torso over the hips, not behind them" % id)
		# the head up, watching the opponent over the bent spine, where the
		# relaxed idle looks 14 degrees down at the floor
		var head: int = sk.find_bone("Head")
		var rest: Basis = sk.get_bone_global_rest(head).basis.orthonormalized().inverse()
		var gaze: Vector3 = _bone(bench, frame, "Head").basis.orthonormalized() * rest * Vector3.BACK
		gut.p("%s: the gaze %.1f° down" % [id, rad_to_deg(-asin(gaze.y))])
		assert_between(rad_to_deg(-asin(gaze.y)), 0.0, 10.0, "%s: the gaze on the opponent" % id)
		assert_lt(absf(rad_to_deg(atan2(gaze.x, gaze.z))), 8.0, "%s: the face toward the opponent" % id)


## The weight shifts slowly between the feet: over GuardStance's period the
## hips sway along the line from the rear foot to the front one, never fast,
## and the sway follows the rules' clock, not the wall's.
func test_the_weight_shifts_slowly_between_the_feet() -> void:
	# the sway itself
	var most: float = 0.0
	var fastest: float = 0.0
	var before: Vector3 = GuardStance.shift(0.0)
	for i: int in range(1, int(GuardStance.SHIFT_PERIOD * 60.0) + 1):
		var now: Vector3 = GuardStance.shift(float(i) / 60.0)
		most = maxf(most, now.length())
		fastest = maxf(fastest, now.distance_to(before) * 60.0)
		before = now
	assert_between(most, 0.015, 0.04, "the sway's reach either way")
	assert_lt(fastest, 0.05, "slow: under 5 cm/s")
	assert_almost_eq(GuardStance.shift(GuardStance.SHIFT_PERIOD), GuardStance.shift(0.0), Vector3.ONE * 1e-5, "it comes round")
	assert_gt(GuardStance.SHIFT_PERIOD, 3.0, "a slow cycle")
	var line: Vector3 = (GuardStance.FEET["Right"] - GuardStance.FEET["Left"]) * Vector3(1, 0, 1)
	assert_lt(GuardStance.shift(GuardStance.SHIFT_PERIOD / 4.0).normalized().cross(line.normalized()).length(), 0.01, "along the line between the feet")
	# on the fighter, from the world's frames, over the clip's own sway
	var bench: MoveBench = _bench(&"rogue")
	var first: Vector3 = await _hips_off_the_clip(bench)
	var first_grip: Vector3 = bench.view.model.rig.grip_point("Right")
	var quarter: int = int(GuardStance.SHIFT_PERIOD * 60.0 / 4.0)
	_wait(bench, quarter)
	var moved: Vector3 = await _hips_off_the_clip(bench) - first
	var grip_moved: Vector3 = bench.view.model.rig.grip_point("Right") - first_grip
	var later: PoseCheck.Frame = await bench.frame()
	var want: Vector3 = GuardStance.shift(float(bench.world.frame) / 60.0) - GuardStance.shift(float(bench.world.frame - quarter) / 60.0)
	gut.p("the hips moved %s over a quarter of the sway, the sway %s" % [moved, want])
	assert_gt(want.length(), 0.015, "a quarter of the sway is a visible shift")
	assert_almost_eq(Vector2(moved.x, moved.z), Vector2(want.x, want.z), Vector2.ONE * 0.006, "the hips go with it")
	assert_almost_eq(grip_moved, want, Vector3.ONE * 0.003, "and the weapon rides with the hips")
	# the wall's clock (StickPose's idle time) doesn't move it
	var f: Fighter = bench.attacker
	bench.view.update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, 1.0, 1.0 / 60.0, 7.3)
	var same: PoseCheck.Frame = await bench.frame()
	assert_almost_eq(_bone(bench, same, "Hips").origin, _bone(bench, later, "Hips").origin, Vector3.ONE * 1e-4, "only the rules' frames move it")


# ------------------------------------------------------------------ the guard

## The Katana's guard passes PoseCheck on both fighters: wrists, elbows,
## knees and the blade's clearance.
func test_the_katana_guard_passes_pose_check() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		var report: PoseCheck.Report = bench.check.measure(await bench.frame())
		gut.p("%s katana guard: %s" % [id, report.summary()])
		assert_eq(report.wrists.keys(), SIDES, "%s: both hands on the handle" % id)
		assert_true(report.passed(), "%s: %s" % [id, report.failures()])


## The guard stands over the relaxed idle clip in place of the Katana
## hold's; the other weapons keep their holds' clips and the clips' feet.
func test_only_the_katana_stands_in_the_guard() -> void:
	for id: StringName in FighterLook.IDS:
		var bench: MoveBench = _bench(id)
		await bench.frame()
		assert_eq(bench.view.locomotion.idle_clip(), GuardStance.CLIP, "%s: the Katana's guard over the relaxed idle" % id)
		assert_almost_eq(bench.view.model.rig.clip_feet, 0.0, 1e-5, "%s: the feet on the stance" % id)
		for weapon: WeaponDef in [Moves.GREATSWORD, Moves.DAGGERS]:
			var other: MoveBench = _bench(id, weapon)
			await other.frame()
			assert_eq(other.view.locomotion.idle_clip(), other.view.model.idle_clip(), "%s with the %s: the hold's clip" % [id, weapon.id])
			assert_almost_eq(other.view.model.rig.clip_feet, 1.0, 1e-5, "%s with the %s: the clip's feet" % [id, weapon.id])
			assert_eq(other.view.model.rig.body.untwist, 0.0, "%s with the %s: the clip's own chest" % [id, weapon.id])
			assert_eq(other.view.model.rig.body.hips_offset, Vector3.ZERO, "%s with the %s: the clip's own hips" % [id, weapon.id])


## As the legs walk, the stance's feet give way to the clips': at a run the
## feet are the clip's, and standing again they are the stance's.
func test_the_stance_gives_way_to_the_clips_as_the_legs_walk() -> void:
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(&"rogue", 0, Moves.KATANA.id, 0)
	v.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var f: Fighter = W.fighters[0]
	var show: Callable = func() -> void:
		v.update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, 1.0, 1.0 / 60.0, 0.0)
	show.call()
	assert_almost_eq(v.model.rig.clip_feet, 0.0, 1e-5, "standing: the stance's feet")
	for i: int in 30:
		W.step([SimHelpers.move(0.0, 1.0), SimHelpers.idle()])
		show.call()
	assert_almost_eq(v.model.rig.clip_feet, 1.0, 1e-5, "running: the clip's feet")
	for i: int in 30:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		show.call()
	assert_almost_eq(v.model.rig.clip_feet, 0.0, 1e-5, "standing again")
