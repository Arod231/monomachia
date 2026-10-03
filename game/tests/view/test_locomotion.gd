extends GutTest
## Locomotion, the legs under a fighter in the match: idle (the weapon's hold
## clip), walk, jog and sprint blended by the rules' speed, every clip played
## from one shared step phase that moves a stride per cycle, each fighter's
## strides measured from its own clips by FootPhase, all on the rules' clock,
## so it holds still in hit-stop and pause. The legs turn toward the way the
## fighter travels (at most 80°, running backwards past 100° with hysteresis)
## on a spring, the feet going with them, while the chest keeps facing the
## opponent.

## The bones compared when a pose should be a clip's.
const BONES: Array[String] = ["Hips", "Spine", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "LeftFoot"]
const W_IDLE: int = 0
const W_WALK: int = 1
const W_JOG: int = 2
const W_SPRINT: int = 3


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


## The local poses of BONES in clip `clip` at `seconds`, played alone on the
## model's own player (the tree is shown again afterwards by the caller).
func _clip_pose(v: FighterView, clip: StringName, seconds: float) -> Array[Transform3D]:
	var ap: AnimationPlayer = v.model.animation_player
	ap.play(String(FighterModel.LIBRARY) + "/" + String(clip), 0.0)
	ap.seek(seconds, true)
	return _pose(v)


func _assert_pose(a: Array[Transform3D], b: Array[Transform3D], what: String) -> void:
	for i: int in BONES.size():
		assert_almost_eq(a[i].origin, b[i].origin, Vector3.ONE * 2e-3, "%s: %s's position" % [what, BONES[i]])
		var angle: float = rad_to_deg(a[i].basis.get_rotation_quaternion().angle_to(b[i].basis.get_rotation_quaternion()))
		assert_lt(angle, 0.5, "%s: %s's rotation" % [what, BONES[i]])


func _weights(s: float, run: float = 3.9, sprint: float = 7.2) -> PackedFloat32Array:
	return Locomotion.weights(s, run, sprint)


func _assert_weights(got: PackedFloat32Array, want: Array, what: String) -> void:
	assert_eq(got.size(), 4, what)
	for i: int in 4:
		assert_almost_eq(got[i], float(want[i]), 1e-5, "%s: %s" % [what, ["idle", "walk", "jog", "sprint"][i]])


## A bone's turn about the vertical from its rest, in a posed frame's bones
## (radians, positive to the fighter's left).
static func _heading(v: FighterView, bones: Array[Transform3D], bone: String) -> float:
	var sk: Skeleton3D = v.model.skeleton
	var i: int = sk.find_bone(bone)
	var turn: Basis = bones[i].basis.orthonormalized() * sk.get_bone_global_rest(i).basis.orthonormalized().inverse()
	var fwd: Vector3 = turn * Vector3.BACK
	return atan2(fwd.x, fwd.z)


## Where a bone of the posed frame is in the world.
static func _world_at(v: FighterView, bones: Array[Transform3D], bone: String) -> Vector3:
	var sk: Skeleton3D = v.model.skeleton
	return sk.global_transform * bones[sk.find_bone(bone)].origin


## The posed fighter's bones, at the end of the modifier stack.
func _posed(v: FighterView) -> Array[Transform3D]:
	var frame: PoseCheck.Frame = await PoseCheck.frame_of(v.model)
	return frame.bones


# ------------------------------------------------------------------ the blend

func test_the_blend_is_idle_at_rest_walk_at_0_98_jog_at_the_run_and_sprint_at_the_sprint() -> void:
	_assert_weights(_weights(0.0), [1, 0, 0, 0], "at rest")
	_assert_weights(_weights(0.98), [0, 1, 0, 0], "at 0.98 m/s")
	_assert_weights(_weights(3.9), [0, 0, 1, 0], "at the run, 3.9 m/s")
	_assert_weights(_weights(7.2), [0, 0, 0, 1], "at the sprint, 7.2 m/s")
	_assert_weights(_weights(0.49), [0.5, 0.5, 0, 0], "half way to the walk")
	_assert_weights(_weights((0.98 + 3.9) / 2.0), [0, 0.5, 0.5, 0], "half way to the run")
	_assert_weights(_weights((3.9 + 7.2) / 2.0), [0, 0, 0.5, 0.5], "half way to the sprint")
	_assert_weights(_weights(9.0), [0, 0, 0, 1], "past the sprint")
	# a Greatsword's run and sprint (its 0.9 speed)
	_assert_weights(_weights(3.51, 3.51, 6.48), [0, 0, 1, 0], "the Greatsword's run")
	_assert_weights(_weights(6.48, 3.51, 6.48), [0, 0, 0, 1], "the Greatsword's sprint")
	var s: float = 0.0
	while s < 8.0:
		var w: PackedFloat32Array = _weights(s)
		assert_almost_eq(w[0] + w[1] + w[2] + w[3], 1.0, 1e-5, "the weights sum to 1 at %.2f m/s" % s)
		s += 0.05


func test_each_fighters_strides_are_measured_from_its_own_clips() -> void:
	var walk: Vector2 = Vector2(0.85, 1.1)
	var bands: Array[Vector2] = [walk, Vector2(4.5, 5.8), Vector2(7.5, 9.5)]
	var strides: Array[float] = []
	for id: StringName in FighterLook.IDS:
		var v: FighterView = _view(id)
		var gaits: Array[FootPhase.Gait] = v.locomotion.gaits
		assert_eq(gaits.size(), 3)
		for i: int in 3:
			var g: FootPhase.Gait = gaits[i]
			assert_eq(g.clip, Locomotion.CLIPS[i])
			assert_between(g.speed, bands[i].x, bands[i].y, "%s %s's ground speed" % [id, g.clip])
			assert_almost_eq(g.stride, g.speed * g.length, 1e-4, "%s %s: a stride per cycle" % [id, g.clip])
			assert_almost_eq(fposmod(g.right_stance - g.left_stance, 1.0), 0.5, 0.07, "%s %s: the feet half a cycle apart" % [id, g.clip])
		strides.append(gaits[1].stride)
		var again: FootPhase.Gait = FootPhase.measure(v.model, Locomotion.CLIPS[1])
		assert_almost_eq(again.stride, gaits[1].stride, 1e-4, "%s: the same measure again" % id)
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


# ------------------------------------------------------------------ the phase

func test_the_phase_moves_a_stride_per_cycle_on_each_rules_frame() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	_show(v, f)
	var most: float = SimConst.MOVE_SPRINT / loco.gaits[2].stride / 60.0
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
		var s: float = _speed(f)
		top = maxf(top, s)
		var moved: float = fposmod(loco.phase - before, 1.0)
		assert_almost_eq(moved, s / loco.stride(s) / 60.0, 1e-5, "at %.2f m/s, frame %d" % [s, W.frame])
		assert_lt(moved, most + 1e-6, "never more than a sprint's step")
	assert_almost_eq(top, SimConst.MOVE_SPRINT, 1e-3, "it reached the sprint")
	assert_almost_eq(loco.stride(SimConst.MOVE_SPRINT), loco.gaits[2].stride, 1e-5, "a sprint's stride at the sprint")
	assert_almost_eq(loco.stride(0.3), loco.gaits[0].stride, 1e-5, "a walk's stride below the walk")


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
	# across the wrap from just under 1 to just over 0, and back again
	# running backwards: the short way round
	loco.prev_phase = 0.99
	loco.phase = 0.01
	_show(v, f, 0.5)
	assert_almost_eq(wrapf(loco.shown_phase, -0.5, 0.5), 0.0, 1e-6, "half way round the wrap")
	loco.prev_phase = 0.01
	loco.phase = 0.99
	_show(v, f, 0.25)
	assert_almost_eq(wrapf(loco.shown_phase, -0.5, 0.5), 0.005, 1e-6, "a quarter of the way back round it")


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

func test_at_rest_the_hold_clip_plays_on_the_rules_clock() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter")
	for i: int in 70:
		_step(W, v, SimHelpers.idle())
	v.update_from(f, Vector3.ZERO, 0.0, 0.5, 1.0 / 60.0, 0.0)
	var shown: Array[Transform3D] = _pose(v)
	_assert_weights(v.locomotion.shown, [1, 0, 0, 0], "at rest")
	_assert_pose(shown, _clip_pose(v, v.model.idle_clip(), (W.frame + 0.5) / 60.0), "the hold clip at the rules' frame")
	v.update_from(f, Vector3.ZERO, 0.0, 0.5, 3.0, 7.0)
	_assert_pose(_pose(v), shown, "the same frame shows the same however much wall time passes")


func test_a_running_fighter_jogs_and_a_sprinting_one_sprints_from_the_shared_phase() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for spec: Array in [[SimHelpers.move(0.0, 1.0), W_JOG], [SimHelpers.move(0.0, 1.0, Btn.SPRINT), W_SPRINT]]:
		for i: int in 25:
			_step(W, v, spec[0])
		var which: int = spec[1]
		var want: Array = [0, 0, 0, 0]
		want[which] = 1
		_assert_weights(loco.shown, want, "at %.2f m/s" % _speed(f))
		var g: FootPhase.Gait = loco.gaits[which - 1]
		var at: float = fposmod(loco.shown_phase + g.left_stance, 1.0) * g.length
		assert_almost_eq(loco.clip_time(which - 1, loco.shown_phase), at, 1e-6)
		var shown: Array[Transform3D] = _pose(v)
		_assert_pose(shown, _clip_pose(v, g.clip, at), "%s at the shared phase" % g.clip)
		_show(v, f)


func test_a_greatsword_runs_and_sprints_at_its_own_speeds() -> void:
	var W: World = _world(24.0, Moves.GREATSWORD)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", Moves.GREATSWORD)
	var loco: Locomotion = v.locomotion
	for i: int in 25:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	assert_almost_eq(_speed(f), SimConst.MOVE_RUN_FORWARD * Moves.GREATSWORD.speed_mult, 1e-4, "its run")
	_assert_weights(loco.shown, [0, 0, 1, 0], "a full jog at its run")
	for i: int in 25:
		_step(W, v, SimHelpers.move(0.0, 1.0, Btn.SPRINT))
	assert_almost_eq(_speed(f), SimConst.MOVE_SPRINT * Moves.GREATSWORD.speed_mult, 1e-4, "its sprint")
	_assert_weights(loco.shown, [0, 0, 0, 1], "a full sprint at its sprint")


func test_the_left_foot_is_at_mid_stance_at_phase_zero_in_every_clip() -> void:
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	var sk: Skeleton3D = v.model.skeleton
	for i: int in 3:
		var g: FootPhase.Gait = loco.gaits[i]
		_clip_pose(v, g.clip, loco.clip_time(i, 0.0))
		var left: float = sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin.z
		var zs: PackedFloat32Array = PackedFloat32Array()
		for k: int in 40:
			_clip_pose(v, g.clip, g.length * k / 40.0)
			zs.append(sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin.z)
		var lo: float = zs[0]
		var hi: float = zs[0]
		for z: float in zs:
			lo = minf(lo, z)
			hi = maxf(hi, z)
		assert_almost_eq(left, (lo + hi) / 2.0, 0.03 * (hi - lo), "%s: the left foot passes the middle of its sweep" % g.clip)


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


# ------------------------------------------------------------------ the hip turn

func test_the_legs_turn_toward_travel_in_eight_directions() -> void:
	# [travel, runs backwards, the legs' turn], in degrees, positive to the
	# fighter's left: forwards up to the side (the turn stops at 80°),
	# backwards behind it, the legs turned to the travel's opposite
	var cases: Array = [
		[0.0, false, 0.0], [45.0, false, 45.0], [90.0, false, 80.0], [135.0, true, -45.0],
		[180.0, true, 0.0], [-135.0, true, 45.0], [-90.0, false, -80.0], [-45.0, false, -45.0],
	]
	for c: Array in cases:
		var travel: float = deg_to_rad(c[0])
		for was: bool in [false, true]:
			assert_eq(Locomotion.runs_backwards(travel, was), c[1], "%+.0f° after running %s" % [c[0], "backwards" if was else "forwards"])
		assert_almost_eq(rad_to_deg(Locomotion.leg_target(travel, c[1])), c[2], 1e-4, "%+.0f°: the legs' turn" % c[0])
	assert_almost_eq(rad_to_deg(Locomotion.leg_target(-PI, true)), 0.0, 1e-4, "straight back either way round")


func test_running_backwards_switches_at_100_degrees_with_hysteresis() -> void:
	for side: float in [1.0, -1.0]:
		var at: Callable = func(deg: float, was: bool) -> bool:
			return Locomotion.runs_backwards(side * deg_to_rad(deg), was)
		assert_false(at.call(104.0, false), "short of 105° a forward run stays forward")
		assert_true(at.call(106.0, false), "past 105° it runs backwards")
		assert_true(at.call(96.0, true), "over 95° a backward run stays backward")
		assert_false(at.call(94.0, true), "under 95° it runs forwards again")
		assert_false(at.call(100.0, false), "at 100° each keeps what it was")
		assert_true(at.call(100.0, true), "at 100° each keeps what it was")
	# the rules' strafe orbits out a little, travelling at up to about 92°
	# from the facing: it runs forwards whatever came before
	assert_false(Locomotion.runs_backwards(deg_to_rad(92.0), true), "a strafe after a backpedal")
	# in the band the turn stops at 80°, whichever way the legs run
	assert_almost_eq(rad_to_deg(Locomotion.leg_target(deg_to_rad(100.0), false)), 80.0, 1e-4)
	assert_almost_eq(rad_to_deg(Locomotion.leg_target(deg_to_rad(100.0), true)), -80.0, 1e-4)


func test_the_legs_turn_on_a_critically_damped_spring() -> void:
	# from rest toward a turn of 1, frame by frame: on the closed form
	# 1 - (1 + wt)e^(-wt), never overshooting
	var w: float = Locomotion.LEG_SPRING
	assert_eq(w, 12.0)
	var x: Vector2 = Vector2.ZERO
	for i: int in 60:
		var before: float = x.x
		x = Locomotion.spring(x.x, x.y, 1.0, w, 1.0 / 60.0)
		var t: float = (i + 1) / 60.0
		assert_almost_eq(x.x, 1.0 - (1.0 + w * t) * exp(-w * t), 1e-5, "frame %d" % (i + 1))
		assert_gte(x.x, before, "never turning back")
		assert_lte(x.x, 1.0, "never overshooting")
	# two half steps land where one whole step does
	var one: Vector2 = Locomotion.spring(0.2, -0.5, 1.0, w, 1.0 / 30.0)
	var half: Vector2 = Locomotion.spring(0.2, -0.5, 1.0, w, 1.0 / 60.0)
	half = Locomotion.spring(half.x, half.y, 1.0, w, 1.0 / 60.0)
	assert_almost_eq(half.x, one.x, 1e-6)
	assert_almost_eq(half.y, one.y, 1e-5)


func test_strafing_turns_the_legs_toward_travel_and_keeps_the_chest_on_the_opponent() -> void:
	var W: World = _world(3.0)
	var f: Fighter = W.fighters[0]
	var opp: Fighter = W.fighters[1]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	var body: BodyLayer = v.model.rig.body
	_show(v, f)
	# left, then right: [the strafe axis, the way the legs turn]
	for spec: Array in [[-1.0, 1.0], [1.0, -1.0]]:
		for i: int in 60:
			_step(W, v, SimHelpers.move(spec[0], 0.0))
			if i < 40:
				continue
			var bones: Array[Transform3D] = await _posed(v)
			var to: float = SimMath.yaw_to(f.pos, opp.pos)
			for bone: String in ["UpperChest", "Head"]:
				var off: float = rad_to_deg(wrapf(f.yaw + _heading(v, bones, bone) - to, -PI, PI))
				assert_lt(absf(off), 5.0, "%s faces the opponent strafing %s (off by %.1f°)" % [bone, "left" if spec[0] < 0.0 else "right", off])
			assert_gt(_heading(v, bones, "Hips") * spec[1], deg_to_rad(45.0), "the hips turn toward travel")
		assert_false(loco.backwards)
		assert_almost_eq(rad_to_deg(loco.leg_yaw), 80.0 * spec[1], 0.5, "the legs turned as far as they go")
	for i: int in 50:
		_step(W, v, SimHelpers.idle())
	assert_almost_eq(rad_to_deg(loco.leg_yaw), 0.0, 0.5, "and back to straight once it stops")
	assert_eq(body.untwist, 1.0, "at rest the guard stance squares the chest to the hips")


func test_backpedalling_runs_the_cycle_backwards_with_the_legs_straight() -> void:
	# near enough the middle that it doesn't back into the wall; with the
	# Greatsword, whose legs walk on the clips from the first frame (the
	# Katana's tap step from rest is its guard's shuffle)
	var W: World = _world(8.0, Moves.GREATSWORD)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", Moves.GREATSWORD)
	var loco: Locomotion = v.locomotion
	_show(v, f)
	for i: int in 50:
		var before: float = loco.phase
		_step(W, v, SimHelpers.move(0.0, -1.0))
		var s: float = _speed(f)
		assert_true(loco.backwards, "frame %d" % W.frame)
		assert_almost_eq(wrapf(loco.phase - before, -0.5, 0.5), -s / loco.stride(s) / 60.0, 1e-5, "back a stride per cycle at %.2f m/s" % s)
	assert_almost_eq(_speed(f), SimConst.MOVE_RUN_BACK * Moves.GREATSWORD.speed_mult, 1e-3, "at the backpedal's speed")
	assert_almost_eq(rad_to_deg(loco.leg_yaw), 0.0, 0.5, "the legs straight")
	for i: int in 20:
		_step(W, v, SimHelpers.idle())
	assert_false(loco.backwards, "standing still, the legs face forwards again")


func test_moving_back_left_runs_backwards_with_the_legs_turned_right() -> void:
	var W: World = _world(8.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	for i: int in 50:
		_step(W, v, SimHelpers.move(-0.7071, -0.7071))
	var travel: float = rad_to_deg(Locomotion.travel(f))
	assert_between(travel, 120.0, 140.0, "back and to the left")
	assert_true(loco.backwards)
	assert_almost_eq(rad_to_deg(loco.leg_yaw), travel - 180.0, 0.5, "turned to the right, running back along it")
	var bones: Array[Transform3D] = await _posed(v)
	assert_lt(_heading(v, bones, "Hips"), deg_to_rad(-25.0), "the hips turned right")


func test_the_legs_turn_holds_in_hit_stop_and_shows_between_frames_by_alpha() -> void:
	# the Greatsword turns its legs from the first frame of a strafe
	var W: World = _world(3.0, Moves.GREATSWORD)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", Moves.GREATSWORD)
	var loco: Locomotion = v.locomotion
	var body: BodyLayer = v.model.rig.body
	_show(v, f)
	for i: int in 5:
		_step(W, v, SimHelpers.move(-1.0, 0.0))
	var held: float = loco.leg_yaw
	assert_between(rad_to_deg(held), 5.0, 70.0, "turning")
	W.hitstop = 8
	for i: int in 8:
		_step(W, v, SimHelpers.move(-1.0, 0.0))
		assert_eq(loco.leg_yaw, held, "hit-stop step %d" % i)
		assert_eq(loco.shown_leg_yaw, held)
	_step(W, v, SimHelpers.move(-1.0, 0.0))
	assert_gt(loco.leg_yaw, held, "and turns on after it")
	for alpha: float in [0.0, 0.5]:
		_show(v, f, alpha)
		assert_almost_eq(loco.shown_leg_yaw, lerpf(held, loco.leg_yaw, alpha), 1e-6, "alpha %.1f" % alpha)
	assert_almost_eq(body.pelvis_yaw, 0.7 * loco.shown_leg_yaw, 1e-6, "the pelvis takes 70% of the turn")
	assert_almost_eq(body.thigh_yaw, 0.3 * loco.shown_leg_yaw, 1e-6, "the thighs the rest")
	assert_almost_eq(body.spine_yaw, -0.7 * loco.shown_leg_yaw, 1e-6, "the spine turns the chest back")


func test_the_planted_foot_stays_put_running_on_a_diagonal() -> void:
	# the Greatsword's legs run on the clips from the first frame
	var W: World = _world(24.0, Moves.GREATSWORD)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", Moves.GREATSWORD)
	var loco: Locomotion = v.locomotion
	_show(v, f)
	for i: int in 40:
		_step(W, v, SimHelpers.move(-0.7071, 0.7071))
	assert_almost_eq(rad_to_deg(loco.leg_yaw), rad_to_deg(Locomotion.travel(f)), 0.5, "the legs turned the way it runs")
	var last: Vector3 = Vector3.INF
	var slides: Array[float] = []
	for i: int in 80:
		_step(W, v, SimHelpers.move(-0.7071, 0.7071))
		var foot: Vector3 = _world_at(v, await _posed(v), "LeftFoot")
		var planted: bool = absf(wrapf(loco.shown_phase, -0.5, 0.5)) < 0.05
		if planted and last != Vector3.INF:
			slides.append(Vector2(foot.x - last.x, foot.z - last.z).length() * 60.0)
		last = foot if planted else Vector3.INF
	assert_gt(slides.size(), 4, "it passed mid-stance")
	var s: float = _speed(f)
	for slide: float in slides:
		assert_lt(slide, 0.2 * s, "the left foot at mid-stance slides %.2f m/s over the ground, running at %.2f" % [slide, s])


func test_the_arms_keep_their_grip_while_strafing() -> void:
	var W: World = _world(3.0)
	var f: Fighter = W.fighters[0]
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


# ------------------------------------------------------------------ the lean and the brace

## How far the top of a body leaning by rotation vector `lean` moves, and
## which way, in the fighter's frame (x to its left, z forward).
static func _tipped(lean: Vector3) -> Vector3:
	if lean.length() < 1e-6:
		return Vector3.ZERO
	var up: Vector3 = Basis(lean.normalized(), lean.length()) * Vector3.UP
	return Vector3(up.x, 0.0, up.z)


func test_the_lean_tips_toward_acceleration_and_stops_at_11_degrees() -> void:
	var most: float = deg_to_rad(11.0)
	assert_almost_eq(Lean.MOST, most, 1e-6)
	assert_almost_eq(Lean.target_tilt(Vector3(0.0, 0.0, 5.0)), Vector3(0.0, 0.0, 0.07), Vector3.ONE * 1e-6, "0.014 rad per m/s², forward")
	assert_almost_eq(Lean.target_tilt(Vector3(0.0, 0.0, -30.0)), Vector3(0.0, 0.0, -most), Vector3.ONE * 1e-6, "back, as far as it goes")
	assert_almost_eq(Lean.target_tilt(Vector3(-3.0, 0.0, 4.0)), Vector3(-0.042, 0.0, 0.056), Vector3.ONE * 1e-6, "toward it, right and forward")
	assert_eq(Lean.target_tilt(Vector3.ZERO), Vector3.ZERO, "upright without it")
	# the rotation tips the top of the body the way the tilt says
	for tilt: Vector3 in [Vector3(0.0, 0.0, 0.1), Vector3(0.0, 0.0, -0.15), Vector3(0.08, 0.0, 0.0), Vector3(-0.06, 0.0, 0.08)]:
		var tipped: Vector3 = _tipped(Lean.rotation(tilt))
		assert_almost_eq(tipped.normalized(), tilt.normalized(), Vector3.ONE * 1e-5, "tilt %s: its way" % tilt)
		assert_almost_eq(tipped.length(), sin(tilt.length()), 1e-5, "tilt %s: its angle" % tilt)


func test_the_brace_drops_the_hips_against_the_way_of_travel() -> void:
	var ahead: Vector3 = Vector3(0.0, 0.0, 1.0)
	assert_almost_eq(Lean.brace_drop(Vector3(0.0, 0.0, -10.0), ahead), 0.035, 1e-6, "0.35 cm per m/s² of braking")
	assert_almost_eq(Lean.brace_drop(Vector3(0.0, 0.0, -30.0), ahead), Lean.DROP_MOST, 1e-6, "at most 5 cm")
	assert_almost_eq(Lean.DROP_MOST, 0.05, 1e-6)
	assert_eq(Lean.brace_drop(Vector3(0.0, 0.0, 10.0), ahead), 0.0, "speeding up")
	assert_eq(Lean.brace_drop(Vector3(8.0, 0.0, 0.0), ahead), 0.0, "turning")
	assert_almost_eq(Lean.brace_drop(Vector3(-6.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)), 0.021, 1e-6, "braking a run to the left")


func test_running_leans_into_the_start_and_stands_up_at_speed() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var lean: Lean = v.locomotion.lean
	_show(v, f)
	var most: float = 0.0
	var last: float = 0.0
	for i: int in 60:
		_step(W, v, SimHelpers.move(0.0, 1.0))
		var t: Vector3 = lean.shown_tilt
		assert_lte(t.length(), Lean.MOST + 1e-6, "never past 11°, frame %d" % W.frame)
		if i == 0:
			assert_lt(rad_to_deg(t.length()), 2.0, "no snap on the first frame")
		most = maxf(most, t.z)
		assert_lt(lean.shown_drop, 0.005, "no brace speeding up")
		last = t.length()
	assert_gt(rad_to_deg(most), 4.0, "leaning forward into the start")
	assert_lt(rad_to_deg(last), 0.5, "upright again at a steady run")


func test_braking_leans_back_and_drops_the_hips_then_settles() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var lean: Lean = v.locomotion.lean
	var body: BodyLayer = v.model.rig.body
	for i: int in 50:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	var back: float = 0.0
	var back_at: int = -1
	var drop: float = 0.0
	var stopped: int = -1
	var settled: int = -1
	for i: int in 60:
		_step(W, v, SimHelpers.idle())
		var t: Vector3 = lean.shown_tilt
		assert_lte(t.length(), Lean.MOST + 1e-6, "never past 11°")
		assert_lte(lean.shown_drop, Lean.DROP_MOST + 1e-6, "never past 5 cm")
		if t.z < back:
			back = t.z
			back_at = i
		drop = maxf(drop, lean.shown_drop)
		assert_almost_eq(body.lean, Lean.rotation(t), Vector3.ONE * 1e-6, "on the body")
		# the brace on top of the guard stance's crouch and its shuffle's bob,
		# as far as the legs are the guard's, and its sink
		var stance: float = v.locomotion.shown[0]
		assert_almost_eq(body.hips_offset.y, -lean.shown_drop + (v.locomotion.shuffle.shown_bob - GuardStance.CROUCH) * stance - v.sink, 1e-6, "on the hips")
		if stopped < 0 and _speed(f) == 0.0:
			stopped = i
		var still: bool = rad_to_deg(t.length()) < 0.5 and lean.shown_drop < 0.005
		if back_at >= 0 and settled < 0 and still:
			settled = i
		elif not still:
			settled = -1
	assert_lt(rad_to_deg(back), -9.0, "leaning back to brake")
	assert_gt(drop, 0.035, "the hips dropping")
	assert_between(stopped, 0, 12, "stopped")
	assert_lte(back_at - stopped, 3, "leaning furthest back as it stops")
	assert_between(settled - stopped, 1, 24, "settling upright, the hips back up, within 0.4 s of stopping")


func test_the_lean_holds_in_hit_stop_and_shows_between_frames_by_alpha() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var lean: Lean = v.locomotion.lean
	for i: int in 50:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	for i: int in 4:
		_step(W, v, SimHelpers.idle())
	var tilt: Vector3 = lean.tilt
	var drop: float = lean.drop
	assert_lt(tilt.z, -0.02, "leaning back")
	W.hitstop = 8
	for i: int in 8:
		_step(W, v, SimHelpers.idle())
		assert_eq(lean.tilt, tilt, "hit-stop step %d" % i)
		assert_eq(lean.drop, drop)
	_step(W, v, SimHelpers.idle())
	assert_ne(lean.tilt, tilt, "and moves on after it")
	for alpha: float in [0.0, 0.5]:
		_show(v, f, alpha)
		assert_almost_eq(lean.shown_tilt, tilt.lerp(lean.tilt, alpha), Vector3.ONE * 1e-6, "alpha %.1f" % alpha)
		assert_almost_eq(lean.shown_drop, lerpf(drop, lean.drop, alpha), 1e-6)


func test_circling_the_opponent_leans_into_the_turn() -> void:
	var W: World = _world(3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var lean: Lean = v.locomotion.lean
	for i: int in 90:
		_step(W, v, SimHelpers.move(-1.0, 0.0))
	# 3.5 m/s round a 3 m circle pulls 4.1 m/s² toward the opponent
	var t: Vector3 = lean.shown_tilt
	assert_between(rad_to_deg(t.z), 2.5, 4.5, "toward the opponent, into the turn")
	assert_lt(absf(rad_to_deg(t.x)), 0.5, "not along the way it runs")
	assert_lt(lean.shown_drop, 0.005, "no brace")


func test_an_attack_from_a_run_doesnt_lean_back() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var lean: Lean = v.locomotion.lean
	for i: int in 50:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	_step(W, v, SimHelpers.move(0.0, 1.0, Btn.LIGHT))
	assert_eq(f.state, &"attack")
	for i: int in 20:
		_step(W, v, SimHelpers.move(0.0, 1.0))
		assert_lt(rad_to_deg(lean.shown_tilt.length()), 1.0, "the attack's own change of speed is its own, frame %d" % W.frame)
		assert_lt(lean.shown_drop, 0.005)


func test_the_guard_rides_the_lean() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view()
	var loco: Locomotion = v.locomotion
	var rig: FighterRig = v.model.rig
	var sk: Skeleton3D = v.model.skeleton
	var chest: int = sk.find_bone("UpperChest")
	for i: int in 50:
		_step(W, v, SimHelpers.move(0.0, 1.0))
	for i: int in 15:
		_step(W, v, SimHelpers.idle())
		if rad_to_deg(loco.lean.shown_tilt.length()) > 8.0:
			break
	assert_gt(rad_to_deg(loco.lean.shown_tilt.length()), 8.0, "leaning back hard")
	var leaning: Array[Transform3D] = await _posed(v)
	var held: Vector3 = leaning[chest].affine_inverse() * rig.grip_point("Right")
	for side: String in FighterRig.SIDES:
		if rig.drives(side):
			assert_lt(leaning[sk.find_bone(side + "Hand")].origin.distance_to(rig.hand_frame(side).origin), 0.01, "%s hand on its grip" % side)
	# the same frame shown upright: the grip sits where it did against the chest
	loco.lean.prev_tilt = Vector3.ZERO
	loco.lean.tilt = Vector3.ZERO
	loco.lean.prev_drop = 0.0
	loco.lean.drop = 0.0
	_show(v, f)
	var upright: Array[Transform3D] = await _posed(v)
	var still: Vector3 = upright[chest].affine_inverse() * rig.grip_point("Right")
	assert_lt(held.distance_to(still), 0.015, "the grip rides with the chest")


func test_the_lean_is_the_same_when_shown_every_other_frame() -> void:
	# a match drawn at 30 fps shows two rules frames at a time
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var every: FighterView = _view()
	var other: FighterView = _view()
	_show(every, f)
	_show(other, f)
	var inputs: Array[RawInput] = []
	for i: int in 50:
		inputs.append(SimHelpers.move(0.0, 1.0))
	for i: int in 30:
		inputs.append(SimHelpers.idle())
	var most: float = 0.0
	for i: int in inputs.size():
		W.step([inputs[i], SimHelpers.idle()])
		_show(every, f)
		if i % 2 == 1:
			_show(other, f)
			var a: Lean = every.locomotion.lean
			var b: Lean = other.locomotion.lean
			most = maxf(most, a.tilt.length())
			assert_lt(rad_to_deg(a.tilt.distance_to(b.tilt)), 1.0, "frame %d: %.1f° against %.1f°" % [W.frame, rad_to_deg(a.tilt.z), rad_to_deg(b.tilt.z)])
			assert_lt(absf(a.drop - b.drop), 0.005, "frame %d's brace" % W.frame)
	assert_gt(rad_to_deg(most), 8.0, "it leaned")
