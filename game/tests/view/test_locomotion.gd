extends GutTest
## Locomotion, the legs under a fighter in the match (authored-animation task
## 29): the director's idle with the packs' directional walk, run and sprint
## clips (the CC0 fallback's without the packs) blended by the rules'
## velocity in the fighter's facing space, every clip played from one shared
## step phase that moves a stride per cycle, each fighter's gaits measured
## from its own clips by FootPhase, all on the rules' clock, so it holds
## still in hit-stop and pause. A tap step is half a walking cycle, a sprint
## held backwards turns the body away, standing the legs step round on the
## spot, and the footsteps fall where the clips' feet come down.

## The bones compared when a pose should be a clip's.
const BONES: Array[String] = ["Hips", "Spine", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "LeftFoot"]


func after_each() -> void:
	SimHelpers.dispose_all()


## Two fighters `gap` apart, fighter 0 facing +Z toward fighter 1.
func _world(gap: float = 24.0, weapon: WeaponDef = Moves.KATANA) -> World:
	return SimHelpers.make_world(weapon, Moves.KATANA, gap)


func _view(fighter_id: StringName = &"rogue", weapon: WeaponDef = Moves.KATANA) -> FighterView:
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(fighter_id, 0, weapon.id, 0)
	v.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	return v


func _show(v: FighterView, f: Fighter, alpha: float = 1.0) -> void:
	v.update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, alpha, 1.0 / 60.0, 0.0)


## Steps the world once with fighter 0's input and shows fighter 0.
func _step(W: World, v: FighterView, input: RawInput) -> void:
	W.step([input, SimHelpers.idle()])
	_show(v, W.fighters[0])


static func _speed(f: Fighter) -> float:
	return Vector2(f.vel.x, f.vel.z).length()


## The animated (pre-modifier) local poses of BONES.
func _pose(v: FighterView) -> Array[Transform3D]:
	var sk: Skeleton3D = v.model.skeleton
	var out: Array[Transform3D] = []
	for bone: String in BONES:
		out.append(sk.get_bone_pose(sk.find_bone(bone)))
	return out


## The local poses of BONES in clip `clip` (a name in the model's player) at
## `seconds`, played alone on the model's own player.
func _clip_pose(v: FighterView, clip: String, seconds: float) -> Array[Transform3D]:
	var ap: AnimationPlayer = v.model.animation_player
	ap.play(clip if clip.contains("/") else String(FighterModel.LIBRARY) + "/" + clip, 0.0)
	ap.seek(seconds, true)
	return _pose(v)


func _assert_pose(a: Array[Transform3D], b: Array[Transform3D], what: String) -> void:
	for i: int in BONES.size():
		assert_almost_eq(a[i].origin, b[i].origin, Vector3.ONE * 2e-3, "%s: %s's position" % [what, BONES[i]])
		var angle: float = rad_to_deg(a[i].basis.get_rotation_quaternion().angle_to(b[i].basis.get_rotation_quaternion()))
		assert_lt(angle, 0.5, "%s: %s's rotation" % [what, BONES[i]])


func _assert_gaits(got: PackedFloat32Array, want: Array, what: String) -> void:
	assert_eq(got.size(), 4, what)
	for i: int in 4:
		assert_almost_eq(got[i], float(want[i]), 1e-5, "%s: %s" % [what, ["idle", "walk", "run", "sprint"][i]])


## That blend `got` (as Locomotion.blend() gives it) is `want`, within
## 1e-5, ignoring weights under that.
func _assert_blend(got: Dictionary, want: Dictionary, what: String = "") -> void:
	for k: Variant in want:
		assert_almost_eq(float(got.get(k, 0.0)), float(want[k]), 1e-5, "%s: %s" % [what, k])
	for k: Variant in got:
		if not want.has(k):
			assert_lt(float(got[k]), 1e-5, "%s: no %s" % [what, k])


## The heaviest clip shown now.
static func _top(loco: Locomotion) -> String:
	return loco.shown_clips[0][0] if not loco.shown_clips.is_empty() else ""


## Where a bone of the posed frame is in the world.
static func _world_at(v: FighterView, bones: Array[Transform3D], bone: String) -> Vector3:
	var sk: Skeleton3D = v.model.skeleton
	return sk.global_transform * bones[sk.find_bone(bone)].origin


## The posed fighter's bones, at the end of the modifier stack.
func _posed(v: FighterView) -> Array[Transform3D]:
	var frame: PoseCheck.Frame = await PoseCheck.frame_of(v.model)
	return frame.bones


# ------------------------------------------------------------------ the blend

func test_the_ways_are_every_45_degrees_and_blend_between_neighbours() -> void:
	assert_eq(Locomotion.way_weights(0.0), Vector3(0, 1, 0), "straight ahead")
	assert_almost_eq(Locomotion.way_weights(deg_to_rad(22.5)), Vector3(0, 1, 0.5), Vector3.ONE * 1e-5, "half way to forward-left")
	assert_almost_eq(Locomotion.way_weights(deg_to_rad(90.0)), Vector3(2, 3, 0), Vector3.ONE * 1e-5, "left")
	assert_almost_eq(Locomotion.way_weights(PI), Vector3(4, 5, 0), Vector3.ONE * 1e-5, "back")
	assert_almost_eq(Locomotion.way_weights(-PI), Vector3(4, 5, 0), Vector3.ONE * 1e-5, "back, the other way round")
	assert_almost_eq(Locomotion.way_weights(deg_to_rad(-45.0)), Vector3(7, 0, 0), Vector3.ONE * 1e-5, "forward-right")
	assert_almost_eq(Locomotion.way_weights(deg_to_rad(-22.5)), Vector3(7, 0, 0.5), Vector3.ONE * 1e-5, "between forward-right and forward")


func test_the_gaits_are_idle_at_rest_then_walk_run_and_sprint_at_their_anchors() -> void:
	var g: Callable = func(s: float) -> PackedFloat32Array: return Locomotion.gait_weights(s, 2.0, 3.9, 7.2)
	_assert_gaits(g.call(0.0), [1, 0, 0, 0], "at rest")
	_assert_gaits(g.call(1.0), [0.5, 0.5, 0, 0], "half way to the walk")
	_assert_gaits(g.call(2.0), [0, 1, 0, 0], "at the walk")
	_assert_gaits(g.call(3.9), [0, 0, 1, 0], "at the run")
	_assert_gaits(g.call((3.9 + 7.2) / 2.0), [0, 0, 0.5, 0.5], "half way to the sprint")
	_assert_gaits(g.call(9.0), [0, 0, 0, 1], "past the sprint")
	var s: float = 0.0
	while s < 8.0:
		var w: PackedFloat32Array = g.call(s)
		assert_almost_eq(w[0] + w[1] + w[2] + w[3], 1.0, 1e-5, "the weights sum to 1 at %.2f m/s" % s)
		s += 0.05


func test_the_run_is_anchored_on_the_run_clips_own_speeds_that_way() -> void:
	# milestone-1 task 55: the rules' run is each way's run clip's measured speed
	assert_almost_eq(Locomotion.run_speed_at(0.0), _table_speed("Run01_Forward"), 1e-5, "ahead")
	assert_almost_eq(Locomotion.run_speed_at(PI / 2.0), _table_speed("StrafeRun01_Left"), 1e-5, "left")
	assert_almost_eq(Locomotion.run_speed_at(-PI / 2.0), _table_speed("StrafeRun01_Left_Mirror"), 1e-5, "right")
	assert_almost_eq(Locomotion.run_speed_at(PI), _table_speed("RunBackward"), 1e-5, "back")
	# between two ways, the two clips' speeds blended
	var half: float = (_table_speed("Run01_Forward") + _table_speed("Run01_ForwardLeft")) / 2.0
	assert_almost_eq(Locomotion.run_speed_at(PI / 8.0), half, 1e-5, "between ahead and forward-left")


## Clip `id`'s measured speed in the frame-data table.
static func _table_speed(id: String) -> float:
	return float(FrameDataTable.shared().gaits[id]["speed"])


func test_each_way_plays_its_clip_and_between_two_ways_both() -> void:
	var t: Dictionary[StringName, Array] = Locomotion.PACK_CLIPS
	var at: Callable = func(deg: float, s: float) -> Dictionary: return Locomotion.blend(deg_to_rad(deg), s, 2.0, 3.9, 7.2, t)
	_assert_blend(at.call(0.0, 3.9), {"": 0.0, "Run01_Forward": 1.0}, "running ahead")
	_assert_blend(at.call(90.0, 2.0), {"": 0.0, "StrafeWalk01_Left": 1.0}, "walking left: the strafe walk")
	_assert_blend(at.call(-90.0, 7.2), {"": 0.0, "Sprint01_Right": 1.0}, "sprinting right")
	_assert_blend(at.call(135.0, 3.9), {"": 0.0, "RunBackwardLeft": 1.0}, "running back and left")
	var half: Dictionary = at.call(22.5, 3.9)
	assert_almost_eq(float(half["Run01_Forward"]), 0.5, 1e-5, "between ahead and forward-left")
	assert_almost_eq(float(half["Run01_ForwardLeft"]), 0.5, 1e-5)
	_assert_blend(at.call(180.0, 7.2), {"": 0.0, "RunBackward": 1.0}, "no sprint goes back: the run")
	var mixed: Dictionary = at.call(0.0, 2.95)
	assert_almost_eq(float(mixed["Walk01_Forward"]), 0.5, 1e-5, "half way from the walk to the run")
	assert_almost_eq(float(mixed["Run01_Forward"]), 0.5, 1e-5)
	# without the packs: the CC0 walks in eight ways, the jog and sprint ahead
	var f: Dictionary[StringName, Array] = Locomotion.FALLBACK_CLIPS
	_assert_blend(Locomotion.blend(PI / 2.0, 3.9, 2.0, 3.9, 7.2, f), {"": 0.0, "Walk_L": 1.0}, "no CC0 run sideways: the walk")
	_assert_blend(Locomotion.blend(0.0, 7.2, 2.0, 3.9, 7.2, f), {"": 0.0, "Sprint": 1.0})
	for deg: float in range(-180, 181, 15):
		for s: float in [0.0, 0.5, 2.0, 3.0, 5.0, 8.0]:
			var sum: float = 0.0
			for w: float in (at.call(deg, s) as Dictionary).values():
				sum += w
			assert_almost_eq(sum, 1.0, 1e-5, "the weights sum to 1 at %+.0f°, %.1f m/s" % [deg, s])


func test_guarded_the_walk_is_the_guarded_cycle_blended_every_90_degrees() -> void:
	# milestone-1 task 56: the guarded shuffles and strafes in four ways take
	# the walk's place, a diagonal blending the two ways round it
	var t: Dictionary[StringName, Array] = Locomotion.PACK_CLIPS
	var guard: Array = Gaits.GUARD_CLIPS[&"katana"]
	var at: Callable = func(deg: float, s: float, share: float) -> Dictionary:
		return Locomotion.blend(deg_to_rad(deg), s, 2.8, 3.9, 7.2, t, guard, share)
	_assert_blend(at.call(0.0, 2.8, 1.0), {"": 0.0, "KatanaShuffleForward": 1.0}, "shuffling forward")
	_assert_blend(at.call(180.0, 2.8, 1.0), {"": 0.0, "KatanaShuffleBack": 1.0}, "shuffling back")
	_assert_blend(at.call(90.0, 1.4, 1.0), {"": 0.5, "KatanaStrafeLeft": 0.5}, "setting off left")
	_assert_blend(at.call(-90.0, 2.8, 1.0), {"": 0.0, "KatanaStrafeRight": 1.0}, "strafing right")
	_assert_blend(at.call(45.0, 2.8, 1.0), {"": 0.0, "KatanaShuffleForward": 0.5, "KatanaStrafeLeft": 0.5}, "a diagonal")
	_assert_blend(at.call(0.0, 2.8, 0.25), {"": 0.0, "KatanaShuffleForward": 0.25, "Walk01_Forward": 0.75}, "a quarter guarded")
	_assert_blend(at.call(0.0, 3.9, 1.0), {"": 0.0, "Run01_Forward": 1.0}, "the run is the run's")


func test_each_fighters_gaits_are_measured_from_its_own_clips() -> void:
	var strides: Array[float] = []
	for id: StringName in FighterLook.IDS:
		var v: FighterView = _view(id)
		var loco: Locomotion = v.locomotion
		for gait: StringName in Locomotion.GAITS:
			var row: Array = loco.clips[gait]
			for d: int in Locomotion.WAYS:
				var clip: String = row[d]
				if clip == "":
					continue
				var g: FootPhase.Gait = loco.gaits[clip]
				var want: float = rad_to_deg(Locomotion.WAY_STEP * d)
				var got: float = rad_to_deg(atan2(g.way.x, g.way.y))
				if ClipLibraries.available():
					# the packs' names say the way; the CC0 walks aren't reviewed
					assert_lt(absf(wrapf(got - want, -180.0, 180.0)), 5.0, "%s %s travels its way (%.0f°)" % [id, clip, got])
				assert_gt(g.speed, 0.5, "%s %s moves" % [id, clip])
				assert_almost_eq(g.stride, g.speed * g.length, 1e-4, "%s %s: a stride per cycle" % [id, clip])
				assert_almost_eq(fposmod(g.right_stance - g.left_stance, 1.0), 0.5, 0.12, "%s %s: the feet about half a cycle apart" % [id, clip])
		var walk: String = loco.clips[&"walk"][0]
		strides.append(loco.gaits[walk].stride)
		var again: FootPhase.Gait = FootPhase.measure(v.model, StringName(walk))
		if walk.begins_with("HumanM/"):
			# the Hunter's pack clips take the table's stride (milestone-1 task 55)
			assert_almost_eq(loco.gaits[walk].stride, float(FrameDataTable.shared().gaits[walk.get_file()]["stride"]), 1e-4,
				"%s: the table's stride" % id)
		else:
			assert_almost_eq(again.stride, loco.gaits[walk].stride, 1e-4, "%s: the same measure again" % id)
	assert_ne(strides[0], strides[1], "each fighter its own")


func test_a_foot_sweeping_back_gives_the_ground_speed_at_mid_stance() -> void:
	# 2 m/s back for the first half of a 1 s cycle (z from +0.5 to -0.5),
	# then swinging forward again
	var z: PackedFloat32Array = PackedFloat32Array()
	var n: int = 200
	for i: int in n:
		var t: float = float(i) / n
		z.append(0.5 - 2.0 * t if t < 0.5 else -0.5 + 2.0 * (t - 0.5))
	var mid: Vector2 = FootPhase.mid_stance(z, 1.0 / n)
	assert_almost_eq(mid.x, 0.25, 1e-3, "mid-stance a quarter of the way round")
	assert_almost_eq(mid.y, 2.0, 1e-3, "the ground passes at 2 m/s")


func test_a_clip_travels_against_its_planted_feet() -> void:
	# a foot down for half the cycle sliding to the +x side (the fighter's
	# left) at 2 m/s, up and back over the other half: travelling right
	var feet: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	var n: int = 100
	for i: int in n:
		var t: float = float(i) / n
		feet[0].append(Vector3(-0.5 + 2.0 * t, 0.0, 0.0) if t < 0.5 else Vector3(0.5 - 2.0 * (t - 0.5), 0.2, 0.0))
		feet[1].append(feet[0][i] + Vector3(0.0, 0.0, 0.2))
	var way: Vector2 = FootPhase.travel_way(feet, 1.0 / n)
	assert_almost_eq(way, Vector2(-1.0, 0.0), Vector2.ONE * 1e-4, "to the right")
	assert_almost_eq(FootPhase.contact(feet[0]), 0.0, 1e-6, "down at the cycle's start")


# ------------------------------------------------------------------ the phase

func test_the_phase_moves_a_stride_per_cycle_on_each_rules_frame() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	_show(v, f)
	var inputs: Array[RawInput] = []
	for i: int in 20:
		inputs.append(SimHelpers.idle())
	for i: int in 30:
		inputs.append(SimHelpers.move(0.0, 1.0))
	for i: int in 40:
		inputs.append(SimHelpers.move(0.0, 1.0, Btn.SPRINT))
	var top: float = 0.0
	for input: RawInput in inputs:
		var before: float = loco.phase
		_step(W, v, input)
		if f.state == &"step":
			continue
		var s: float = _speed(f)
		top = maxf(top, s)
		var b: Dictionary = loco.blend_at(loco.way, s, loco.run_speed, loco.sprint_speed)
		var moved: float = fposmod(loco.phase - before, 1.0)
		assert_almost_eq(moved, s / loco.stride(b, loco.way) / 60.0, 1e-5, "at %.2f m/s, frame %d" % [s, W.frame])
	assert_almost_eq(top, Gaits.sprint_speed(), 1e-3, "it reached the sprint")
	assert_eq(_top(loco), loco.clips[&"sprint"][0], "sprinting ahead")


func test_the_shown_phase_blends_between_rules_frames_by_alpha() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 30:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	var step: float = fposmod(loco.phase - loco.prev_phase, 1.0)
	assert_gt(step, 0.0)
	for alpha: float in [0.0, 0.25, 1.0]:
		_show(v, f, alpha)
		assert_almost_eq(loco.shown_phase, fposmod(loco.prev_phase + step * alpha, 1.0), 1e-6, "alpha %.2f" % alpha)
	# across the wrap from just under 1 to just over 0: the short way round
	loco.prev_phase = 0.99
	loco.phase = 0.01
	_show(v, f, 0.5)
	assert_almost_eq(wrapf(loco.shown_phase, -0.5, 0.5), 0.0, 1e-6, "half way round the wrap")


func test_the_phase_holds_in_hit_stop() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 30:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	assert_gt(_speed(f), 3.0)
	var held: float = loco.phase
	var pose: Array[Transform3D] = _pose(v)
	W.hitstop = 8
	for i: int in 8:
		_step(W, v, SimHelpers.move(0.0, 1.0))
		assert_eq(loco.phase, held, "hit-stop step %d" % i)
	_assert_pose(_pose(v), pose, "the legs hold still")
	_step(W, v, SimHelpers.move(0.0, 1.0))
	assert_ne(loco.phase, held, "and walk on after it")


func test_the_phase_holds_while_the_match_is_paused() -> void:
	var host: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	add_child_autofree(host)
	host.start(MatchConfig.make(
		MatchConfig.DUEL,
		MatchSide.computer(&"rogue", &"katana", 0, &"normal"),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"normal"),
		7,
	))
	var view: MatchView = host.get_node("View")
	var loco: Locomotion = view.fighters[0].locomotion
	var steps: int = 0
	while _speed(host.fighter(0)) < 1.0 and steps < 600:
		host.step(1)
		view.update_fighters(1.0 / 60.0)
		steps += 1
	assert_gt(_speed(host.fighter(0)), 1.0, "the computer walks")
	host.pause()
	assert_true(host.is_paused())
	var held: float = loco.shown_phase
	var pose: Array[Transform3D] = _pose(view.fighters[0])
	for i: int in 5:
		assert_eq(host.advance(0.25), 0)
		view.update_fighters(0.25)
		assert_eq(loco.shown_phase, held, "paused, update %d" % i)
	_assert_pose(_pose(view.fighters[0]), pose, "the legs hold still")
	host.resume()
	host.step(1)
	view.update_fighters(1.0 / 60.0)
	assert_ne(loco.shown_phase, held, "and walk on after it")


# ------------------------------------------------------------------ the pose

func test_at_rest_the_directors_idle_plays_on_the_rules_clock() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter")
	for i: int in 70:
		_step(W, v, SimHelpers.idle())
	v.update_from(f, Vector3.ZERO, 0.0, 0.5, 1.0 / 60.0, 0.0)
	var shown: Array[Transform3D] = _pose(v)
	assert_eq(v.locomotion.shown_idle, 1.0, "at rest")
	assert_eq(String(v.locomotion.idle_clip()), v.shot.idle, "the director's idle, the Katana's too (the guard stance is retired)")
	_assert_pose(shown, _clip_pose(v, v.shot.idle, (W.frame + 0.5) / 60.0), "the idle at the rules' frame")
	v.update_from(f, Vector3.ZERO, 0.0, 0.5, 3.0, 7.0)
	_assert_pose(_pose(v), shown, "the same frame shows the same however much wall time passes")


func test_running_ahead_shows_the_run_at_the_shared_phase() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 25:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	var run: String = loco.clips[&"run"][0]
	assert_eq(loco.shown_clips.size(), 1, "one clip: %s" % [loco.shown_clips])
	assert_eq(_top(loco), run)
	var at: float = loco.clip_time(run, loco.shown_phase)
	assert_almost_eq(at, fposmod(loco.shown_phase + loco.gaits[run].left_stance, 1.0) * loco.gaits[run].length, 1e-6)
	_assert_pose(_pose(v), _clip_pose(v, run, at), "%s at the shared phase" % run)
	assert_almost_eq(_speed(f), _table_speed("Run01_Forward"), 1e-3)


func test_strafing_backpedalling_and_the_diagonals_play_their_ways_clips() -> void:
	# [stick x, stick y, the way the legs go (degrees, + left)]
	for spec: Array in [[-1.0, 0.0, 90.0], [1.0, 0.0, -90.0], [0.0, -1.0, 180.0], [-0.7071, 0.7071, 45.0], [0.7071, -0.7071, -135.0]]:
		var W: World = _world(8.0)
		var f: Fighter = W.fighters[0]
		var v: FighterView = _view()
		var loco: Locomotion = v.locomotion
		var before: float = 0.0
		for i: int in 40:
			before = loco.phase
			_step(W, v, SimHelpers.move(spec[0], spec[1]))
		var want: float = deg_to_rad(spec[2])
		assert_lt(absf(wrapf(loco.way - want, -PI, PI)), deg_to_rad(12.0), "travelling %+.0f°: the legs go %.0f°" % [spec[2], rad_to_deg(loco.way)])
		var d: int = roundi(fposmod(want, TAU) / Locomotion.WAY_STEP) % Locomotion.WAYS
		var names: Array = loco.shown_clips.map(func(c: Array) -> String: return c[0])
		var run: String = loco.clips[&"run"][d] if loco.clips[&"run"][d] != "" else loco.clips[&"walk"][d]
		assert_has(names, run, "%+.0f°: %s shows (%s)" % [spec[2], run, names])
		assert_gt(fposmod(loco.phase - before, 1.0), 0.0, "the cycle runs forward whichever way")
		assert_lt(fposmod(loco.phase - before, 1.0), 0.1)
		assert_eq(loco.shown_away, 0.0, "the body faces the opponent")


func test_a_greatsword_runs_and_sprints_at_its_own_speeds() -> void:
	var W: World = _world(24.0, Moves.GREATSWORD)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", Moves.GREATSWORD)
	var loco: Locomotion = v.locomotion
	for i: int in 25:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	assert_almost_eq(_speed(f), _table_speed("Run01_Forward") * Moves.GREATSWORD.speed_mult, 1e-4, "its run")
	assert_eq(loco.shown_clips.size(), 1)
	assert_eq(_top(loco), loco.clips[&"run"][0], "a full run at its run")
	for i: int in 25:
		_step(W, v, SimHelpers.move(0.0, 1.0, Btn.SPRINT))
	assert_almost_eq(_speed(f), Gaits.sprint_speed() * Moves.GREATSWORD.speed_mult, 1e-4, "its sprint")
	assert_eq(_top(loco), loco.clips[&"sprint"][0], "a full sprint at its sprint")
	assert_almost_eq(float(loco.shown_clips[0][1]), 1.0, 1e-5)


func test_the_left_foot_is_at_mid_stance_at_phase_zero_in_every_clip() -> void:
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	var sk: Skeleton3D = v.model.skeleton
	for gait: StringName in Locomotion.GAITS:
		for clip: String in loco.clips[gait]:
			if clip == "":
				continue
			var g: FootPhase.Gait = loco.gaits[clip]
			var along: Callable = func(t: float) -> float:
				_clip_pose(v, clip, t)
				var p: Vector3 = sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin
				return p.x * g.way.x + p.z * g.way.y
			var left: float = along.call(loco.clip_time(clip, 0.0))
			var lo: float = INF
			var hi: float = -INF
			for k: int in 40:
				var z: float = along.call(g.length * k / 40.0)
				lo = minf(lo, z)
				hi = maxf(hi, z)
			assert_almost_eq(left, (lo + hi) / 2.0, 0.05 * (hi - lo), "%s: the left foot passes the middle of its sweep" % clip)


func test_only_walking_and_running_on_the_ground_move_the_legs() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	f.vel = V3.make(0.0, 0.0, 3.9)
	assert_almost_eq(Locomotion.ground_speed(f), 3.9, 1e-6, "free")
	f.set_state(&"step")
	assert_almost_eq(Locomotion.ground_speed(f), 3.9, 1e-6, "a step")
	for state: StringName in [&"dodge", &"backstep", &"attack", &"hitstun", &"jump", &"ko"]:
		f.set_state(state)
		assert_eq(Locomotion.ground_speed(f), 0.0, state)
	f.set_state(&"free")
	f.pos = V3.make(0.0, 0.5, 0.0)
	assert_eq(Locomotion.ground_speed(f), 0.0, "in the air")


func test_setting_off_and_stopping_cross_over_from_the_idle_in_6_frames() -> void:
	var W: World = _world()
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 20:
		_step(W, v, SimHelpers.idle())
	assert_eq(loco.shown_idle, 1.0)
	var idles: Array[float] = []
	for i: int in Locomotion.MOVING_FRAMES + 2:
		_step(W, v, SimHelpers.move(0.0, 1.0, Btn.SPRINT))
		idles.append(loco.shown_idle)
	gut.p(idles)
	assert_gt(idles[0], 0.5, "not all at once: %s" % [idles])
	for k: int in range(1, idles.size()):
		assert_lte(idles[k], idles[k - 1], "the idle gives way")
	assert_eq(idles[Locomotion.MOVING_FRAMES - 1], 0.0, "and is gone after 6 frames")
	for i: int in 30:
		_step(W, v, SimHelpers.idle())
	assert_eq(loco.shown_idle, 1.0, "back on the idle once it stops")
	assert_true(loco.shown_clips.is_empty())


func test_a_tap_step_is_one_walking_step_its_way() -> void:
	var W: World = _world(8.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 20:
		_step(W, v, SimHelpers.idle())
	var from: float = loco.phase
	var frames: int = 0
	_step(W, v, SimHelpers.move(1.0, 0.0))
	while f.state == &"step":
		frames += 1
		# walking alone (the facing follows the opponent a little as it steps)
		assert_eq(_top(loco), loco.clips[&"walk"][6], "the walk to the right")
		for c: Array in loco.shown_clips:
			assert_has(loco.clips[&"walk"], c[0], "walks only")
		assert_lt(absf(wrapf(loco.way + PI / 2.0, -PI, PI)), deg_to_rad(6.0), "the step's way")
		_step(W, v, SimHelpers.move(1.0, 0.0))
	assert_eq(frames, SimConst.MOVE_STEP_FRAMES, "the step's frames")
	assert_almost_eq(fposmod(loco.prev_phase - from, 1.0), 0.5, 1e-4, "half a cycle: one step")
	assert_true(loco.footfalls.is_empty(), "the step's own scuff: no footfalls")


func test_a_sprint_held_backwards_turns_the_body_away_and_back() -> void:
	var W: World = _world(4.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 40:
		_step(W, v, SimHelpers.move(0.0, -1.0, Btn.SPRINT))
	assert_gt(f.sprint_frames, 0, "sprinting")
	assert_almost_eq(absf(loco.away), PI, deg_to_rad(5.0), "turned right round, away from the opponent")
	assert_lt(absf(wrapf(loco.way, -PI, PI)), deg_to_rad(10.0), "the legs sprint ahead")
	assert_eq(_top(loco), loco.clips[&"sprint"][0], "on the forward sprint")
	assert_almost_eq(v.model.rotation.y, loco.shown_away, 1e-6, "the model turned with it")
	for i: int in 60:
		_step(W, v, SimHelpers.idle())
	assert_almost_eq(loco.away, 0.0, 0.02, "facing the opponent again once it stops")
	# a sideways sprint stays facing the opponent
	for i: int in 30:
		_step(W, v, SimHelpers.move(1.0, 0.0, Btn.SPRINT))
	assert_almost_eq(loco.away, 0.0, 1e-3, "sprinting sideways")


func test_standing_the_legs_step_round_once_the_facing_turns_30_degrees() -> void:
	var W: World = _world(3.0)
	var f: Fighter = W.fighters[0]
	var opp: Fighter = W.fighters[1]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 10:
		_step(W, v, SimHelpers.idle())
	if loco.turn_clips.is_empty():
		pass_test("no turn on the spot without the packs")
		return
	assert_eq(loco.turn_frame, -1)
	# the opponent walks round to the fighter's left; the rules turn it
	var started: int = -1
	for i: int in 40:
		var a: float = deg_to_rad(2.0 * (i + 1))
		opp.pos = V3.make(f.pos.x + 3.0 * sin(a), 0.0, f.pos.z + 3.0 * cos(a))
		_step(W, v, SimHelpers.idle())
		if loco.turn_frame >= 0 and started < 0:
			started = i
			assert_true(loco.turn_left, "turning to the left")
			assert_gt(rad_to_deg(f.yaw), 30.0, "past 30°")
			assert_lt(rad_to_deg(f.yaw), 34.5, "as it passes 30°")
	assert_gt(started, 0, "the legs stepped round")
	assert_gt(loco.shown_turn, 0.0, "the turn shows")
	# the opponent stops; any turn the facing still owes plays out, then none
	for i: int in 3 * Locomotion.TURN_FRAMES:
		_step(W, v, SimHelpers.idle())
	assert_eq(loco.turn_frame, -1, "and ends")
	assert_eq(loco.shown_turn, 0.0)


# ------------------------------------------------------------------ the feet

func test_planted_feet_move_under_a_centimetre_running_on_a_diagonal() -> void:
	var W: World = _world(24.0, Moves.GREATSWORD)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", Moves.GREATSWORD)
	var lock: FootLock = v.foot_lock
	for i: int in 40:
		_step(W, v, SimHelpers.move(-0.7071, 0.7071))
	var held: Dictionary[String, Vector3] = {}
	var moved: Array[float] = []
	var holds: int = 0
	for i: int in 80:
		_step(W, v, SimHelpers.move(-0.7071, 0.7071))
		var bones: Array[Transform3D] = await _posed(v)
		for side: String in FighterRig.SIDES:
			if not lock.holds(side):
				held.erase(side)
				continue
			var foot: Vector3 = _world_at(v, bones, side + "Foot")
			if held.has(side):
				moved.append(Vector2(foot.x - held[side].x, foot.z - held[side].z).length())
			else:
				held[side] = foot
				holds += 1
	assert_gte(holds, 4, "each foot planted as it runs, twice")
	for m: float in moved:
		assert_lt(m, 0.01, "a held foot moves %.1f cm" % (m * 100.0))
	assert_gt(_speed(f), 3.0)


func test_the_arms_keep_their_grip_while_strafing() -> void:
	var W: World = _world(3.0)
	# two-handed, so the off hand grips by IK (KE task 10)
	W.fighters[0].grip = WeaponGrip.TWO_HANDED
	var v: FighterView = _view()
	var rig: FighterRig = v.model.rig
	var sk: Skeleton3D = v.model.skeleton
	for i: int in 50:
		_step(W, v, SimHelpers.move(-1.0, 0.0))
		if i < 20:
			continue
		var bones: Array[Transform3D] = await _posed(v)
		for side: String in FighterRig.SIDES:
			if not rig.drives(side):
				continue
			var hand: Vector3 = bones[sk.find_bone(side + "Hand")].origin
			assert_lt(hand.distance_to(rig.hand_frame(side).origin), 0.01, "%s hand on its grip, frame %d" % [side, W.frame])


func test_the_footsteps_fall_where_the_clips_feet_come_down() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 30:
		_step(W, v, SimHelpers.idle())
		assert_true(loco.footfalls.is_empty(), "standing: none")
	var falls: Array[Vector3] = []
	var frames: Array[int] = []
	for i: int in 90:
		_step(W, v, SimHelpers.move(0.0, 1.0))
		for at: Vector3 in loco.footfalls:
			falls.append(at)
			frames.append(W.frame)
			assert_lt(Vector2(at.x - f.pos.x, at.z - f.pos.z).length(), 0.8, "under the fighter")
			assert_almost_eq(at.y, f.pos.y, 1e-4, "on the ground")
	var run: String = loco.clips[&"run"][0]
	var per_cycle: float = _table_speed("Run01_Forward") / loco.gaits[run].stride
	assert_gt(falls.size(), int(per_cycle * 2.0 * 1.0), "two footsteps a cycle over the last second at least")
	for k: int in range(1, falls.size()):
		assert_gt(frames[k] - frames[k - 1], 3, "footsteps apart")
	# alternate sides of the running line
	var side: Callable = func(at: Vector3) -> float: return signf(at.x - f.pos.x)
	for k: int in range(maxi(1, falls.size() - 4), falls.size()):
		assert_ne(side.call(falls[k]), side.call(falls[k - 1]), "left, right, left")


func test_local_every_gait_clip_plays_at_1x_at_the_rules_speed() -> void:
	# milestone-1 task 55 (story 81): the rules move the Hunter at each gait
	# clip's own measured speed, so its clip plays at 1.0x of the world's time
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	# [stick x, stick y, sprint, the gait, the way's index in Gaits.WAYS]
	for spec: Array in [[0.0, 0.5, false, &"walk", 0], [0.0, -0.5, false, &"walk", 4], [-0.5, 0.0, false, &"walk", 2],
			[0.5, 0.0, false, &"walk", 6], [0.0, 1.0, false, &"run", 0], [-0.7071, 0.7071, false, &"run", 1],
			[-1.0, 0.0, false, &"run", 2], [0.0, -1.0, false, &"run", 4], [0.7071, -0.7071, false, &"run", 5],
			[1.0, 0.0, false, &"run", 6], [0.0, 1.0, true, &"sprint", 0]]:
		var W: World = _world(40.0)
		var v: FighterView = _view(&"hunter")
		var loco: Locomotion = v.locomotion
		var input: RawInput = SimHelpers.move(spec[0], spec[1], Btn.SPRINT) if spec[2] else SimHelpers.move(spec[0], spec[1])
		var clip: String = loco.clips[spec[3]][spec[4]]
		var rates: Array[float] = []
		for i: int in 40:
			var before: float = loco.phase
			_step(W, v, input)
			if i >= 30:
				rates.append(fposmod(loco.phase - before, 1.0) * loco.gaits[clip].length * 60.0)
		assert_eq(_top(loco), clip, "%s %s: its clip shows" % [spec[3], clip])
		for r: float in rates:
			assert_almost_eq(r, 1.0, 0.02, "%s plays at 1.0x (%.4f)" % [clip, r])


func test_local_blocking_the_katanas_legs_play_its_guarded_cycles_at_1x() -> void:
	# milestone-1 task 56: blocking, the Katana moves at its guarded shuffles'
	# and strafes' own speeds, so the legs play them at 1.0x; disarmed, the walk
	# is bare hands' guarded cycles
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	# [stick x, stick y, armed, the way's index in a GUARD_CLIPS row]
	for spec: Array in [[0.0, 1.0, true, 0], [-1.0, 0.0, true, 1], [0.0, -1.0, true, 2], [1.0, 0.0, true, 3],
			[0.0, 0.5, false, 0], [-0.5, 0.0, false, 1], [0.0, -0.5, false, 2], [0.5, 0.0, false, 3]]:
		var W: World = _world(40.0)
		var f: Fighter = W.fighters[0]
		if not spec[2]:
			f.armed = false
		var v: FighterView = _view(&"hunter")
		var loco: Locomotion = v.locomotion
		var input: RawInput = SimHelpers.move(spec[0], spec[1], Btn.BLOCK) if spec[2] else SimHelpers.move(spec[0], spec[1])
		var rates: Array[float] = []
		var clip: String = ""
		for i: int in 40:
			var before: float = loco.phase
			_step(W, v, input)
			clip = loco.guard_clips[&"katana" if spec[2] else &"fists"][spec[3]]
			if i >= 30:
				rates.append(fposmod(loco.phase - before, 1.0) * loco.gaits[clip].length * 60.0)
		assert_eq(_top(loco), clip, "%s shows" % clip)
		for r: float in rates:
			assert_almost_eq(r, 1.0, 0.02, "%s plays at 1.0x (%.4f)" % [clip, r])


func test_local_footwork_plays_its_clip_at_1x_over_the_legs() -> void:
	# milestone-1 task 57: a run stop, a pivot and a tap step show their clips
	# by class, kind and way, from the state's first frame at 1.0x, crossed
	# over to within FOOT_FADE frames
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	# [run first, then the stick, the kind, the way]
	for spec: Array in [[true, Vector2.ZERO, &"run_stop", &"forward"], [true, Vector2(0.0, -1.0), &"pivot", &"forward"],
			[false, Vector2(0.0, 1.0), &"tap_step", &"forward"], [false, Vector2(-1.0, 0.0), &"tap_step", &"left"]]:
		var W: World = _world(24.0)
		var f: Fighter = W.fighters[0]
		var v: FighterView = _view(&"hunter")
		var loco: Locomotion = v.locomotion
		# standing a moment first: the view's first update only sets the legs
		for i: int in 3:
			_step(W, v, SimHelpers.idle())
		if spec[0]:
			for i: int in 40:
				_step(W, v, SimHelpers.move(0.0, 1.0))
		var stick: Vector2 = spec[1]
		var want: String = "HumanM/%s" % StateClips.shared().footwork_clip(&"katana", spec[2], spec[3])
		for i: int in Locomotion.FOOT_FADE:
			_step(W, v, SimHelpers.move(stick.x, stick.y) if stick != Vector2.ZERO else SimHelpers.idle())
		assert_eq(loco.foot_clip, want, "%s %s shows %s" % [spec[2], spec[3], want])
		assert_almost_eq(loco.shown_foot, 1.0, 1e-5, "crossed over within %d frames" % Locomotion.FOOT_FADE)
		assert_almost_eq(loco.foot_time, float(f.sf + 1) / 60.0, 1e-6, "at the state's frame, 1.0x")
