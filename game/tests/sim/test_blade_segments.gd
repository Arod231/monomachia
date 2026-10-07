extends GutTest
## Each striking track's strike segment in the world, tick by tick (task
## 7.9): placed from the swing's pose at the attack's frame and the fighter's
## position and facing, once the fighters have moved and before hits are
## decided, with the last tick's kept beside it for the sweep. The swings are
## synthetic (swing_fixtures.gd), on fresh weapons; no real move has one yet.
## A Katana's blade runs from (0.0015, 0.09, 0) to (-0.077, 1.39, 0) in its
## grip's frame (+X the edge, +Y the blade), 15 mm thick.

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const EPS: float = 1e-12
const RIGHT: StringName = &"right_hand"


func after_each() -> void:
	H.dispose_all()


## A Katana whose Right Cut holds the blade level and straight ahead, its
## edge to the left, the grip at (0.2, 1.3, 0.5): its base is then at
## (0.1985, 1.3, 0.59) and its tip at (0.277, 1.3, 1.89) in the fighter's
## space.
static func _straight_ahead() -> WeaponDef:
	var pose: Swing.KeyPose = SF.key(0, [0.2, 1.3, 0.5], [0.0, 0.0, 1.0], [-1.0, 0.0, 0.0])
	return SF.weapon(&"katana", {&"k_l1": SF.held(Moves.KATANA.moves[&"k_l1"], {RIGHT: pose})})


## A copy of `v`, which the rules may go on changing.
static func _copy(v: V3) -> V3:
	return V3.make(v.x, v.y, v.z)


func _assert_v3(got: V3, want: V3, what: String, eps: float = EPS) -> void:
	assert_almost_eq(V3.distance(got, want), 0.0, eps, "%s: got %s, want %s" % [what, got, want])


## The fighter's only segment.
func _only(f: Fighter) -> BladeSegment:
	var all: Array[BladeSegment] = f.blade_segments()
	assert_eq(all.size(), 1, "one striking track")
	return all[0] if all.size() == 1 else BladeSegment.new()


func test_the_world_tip_at_two_yaws() -> void:
	for yaw: float in [0.0, PI / 2.0]:
		var W: World = H.make_world(_straight_ahead(), Moves.KATANA, 6.0)
		var f: Fighter = W.fighters[0]
		if yaw != 0.0:
			# facing +X across the arena
			f.pos = V3.make(-3.0, 0.0, 0.0)
			W.fighters[1].pos = V3.make(3.0, 0.0, 0.0)
			f.yaw = yaw
			W.fighters[1].yaw = -yaw
		W.step([H.btn(Btn.LIGHT), H.idle()])
		H.run(W, 20)
		assert_eq(f.yaw, yaw, "still facing the opponent")
		var b: BladeSegment = _only(f)
		var p: V3 = f.pos
		if yaw == 0.0:
			# facing +Z, the fighter's right is -X
			_assert_v3(b.base, V3.make(p.x - 0.1985, 1.3, p.z + 0.59), "the base facing +Z")
			_assert_v3(b.tip, V3.make(p.x - 0.277, 1.3, p.z + 1.89), "the tip facing +Z")
		else:
			# facing +X, the fighter's right is +Z
			_assert_v3(b.base, V3.make(p.x + 0.59, 1.3, p.z + 0.1985), "the base facing +X")
			_assert_v3(b.tip, V3.make(p.x + 1.89, 1.3, p.z + 0.277), "the tip facing +X")
		assert_eq(b.part, RIGHT)
		assert_eq(b.half_thickness, 0.0075, "half the Katana's 15 mm")


func test_the_blade_is_placed_where_hits_are_decided_after_the_fighters_are_pushed_apart() -> void:
	# 0.5 m apart, inside the 1.0 m that keeps fighters apart: each step
	# pushes them back out after they move, and the blade goes with the push
	var W: World = H.make_world(_straight_ahead(), Moves.KATANA, 0.5)
	var f: Fighter = W.fighters[0]
	W.step([H.btn(Btn.LIGHT), H.idle()])
	assert_almost_eq(f.pos.z, -0.5, EPS, "pushed back to 0.5 m from the middle")
	_assert_v3(_only(f).tip, V3.make(f.pos.x - 0.277, 1.3, f.pos.z + 1.89), "the tip, where the fighter was pushed to")


func test_the_segment_is_the_pose_at_the_attack_s_frame_and_the_last_tick_s_beside_it() -> void:
	var cut: AttackDef = SF.timed(Moves.KATANA.moves[&"k_l1"])
	var W: World = H.make_world(SF.weapon(&"katana", {&"k_l1": SF.level_slash(cut, 1.2)}), Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	var seen: int = 0
	var last_pos: V3 = _copy(f.pos)
	for i: int in 30:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		var was_at: V3 = last_pos
		last_pos = _copy(f.pos)
		if f.state != &"attack" or f.atk.frame <= cut.startup or f.atk.frame > cut.startup + cut.active:
			continue
		# the slash keys every active frame, from 60° right to 60° left;
		# facing +Z, (right, up, forward) is (-x, y, z) from the feet, where
		# the fighter stood at each tick (the lunge runs to frame 12)
		var b: BladeSegment = _only(f)
		for at: Array in [[b.tip, f.atk.frame, f.pos], [b.prev_tip, f.atk.frame - 1, was_at]]:
			var a: float = (60.0 - 120.0 * (at[1] - cut.startup) / cut.active) * SimMath.DEG
			var s: float = JsMath.sin(a)
			var c: float = JsMath.cos(a)
			var right: float = 0.45 * s + 0.077 * c + 1.39 * s
			var forward: float = 0.45 * c - 0.077 * s + 1.39 * c
			_assert_v3(at[0], V3.make(at[2].x - right, 1.2, at[2].z + forward), "the tip at frame %d" % at[1])
		seen += 1
	assert_eq(seen, cut.active, "every active frame")


func test_the_segment_follows_the_lunge() -> void:
	var W: World = H.make_world(_straight_ahead(), Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	W.step([H.btn(Btn.LIGHT), H.idle()])
	var first: V3 = _copy(_only(f).tip)
	var last_pos: V3 = _copy(f.pos)
	for i: int in 15:
		W.step([H.idle(), H.idle()])
		var b: BladeSegment = _only(f)
		_assert_v3(V3.sub(b.tip, b.prev_tip), V3.sub(f.pos, last_pos), "the tip moves with the fighter on tick %d" % i)
		_assert_v3(V3.sub(b.base, b.prev_base), V3.sub(f.pos, last_pos), "and the base")
		last_pos = _copy(f.pos)
	# Right Cut lunges 0.35 m by frame 12
	_assert_v3(_only(f).tip, V3.add(first, V3.make(0.0, 0.0, 0.35)), "the lunge carried the blade 0.35 m", 1e-9)


func test_the_segment_turns_with_tracking() -> void:
	var W: World = H.make_world(_straight_ahead(), Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	# the opponent off to the left, 45° from where the fighter faces
	f.pos = V3.make(0.0, 0.0, 0.0)
	W.fighters[1].pos = V3.make(-2.5, 0.0, 2.5)
	var reach: float = sqrt(0.277 * 0.277 + 1.89 * 1.89)
	var bearing: float = atan2(-0.277, 1.89)
	for i: int in 15:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		var b: BladeSegment = _only(f)
		var dx: float = b.tip.x - f.pos.x
		var dz: float = b.tip.z - f.pos.z
		assert_almost_eq(sqrt(dx * dx + dz * dz), reach, 1e-12, "the tip stays as far out on tick %d" % i)
		assert_almost_eq(SimMath.wrap_angle(atan2(dx, dz) - f.yaw), bearing, 1e-12, "and as far round from the facing on tick %d" % i)
	assert_lt(f.yaw, -30.0 * SimMath.DEG, "the fighter turned toward the opponent")


func test_the_segment_holds_in_a_charge_and_through_extra_recovery() -> void:
	var iai: AttackDef = Moves.KATANA.moves[&"k_iai"]
	var W: World = H.make_world(SF.weapon(&"katana", {&"k_iai": SF.level_slash(iai, 1.2)}), Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	var charged: int = 0
	var past_the_end: int = 0
	var last: BladeSegment = null
	for i: int in 120:
		W.step([H.btn(Btn.HEAVY) if i < 50 else H.idle(), H.idle()])
		if f.state != &"attack":
			break
		var b: BladeSegment = _only(f)
		if f.atk.charging or f.atk.frame > iai.total_frames():
			if f.atk.charging:
				assert_eq(f.atk.frame, Fighter.CHARGE_CHECK_FRAME, "the frame holds in the charge")
			_assert_v3(b.tip, b.prev_tip, "the tip holds on tick %d (frame %d)" % [i, f.atk.frame])
			_assert_v3(b.base, b.prev_base, "and the base")
			_assert_v3(b.prev_tip, last.tip, "where it was the tick before")
			if f.atk.charging:
				charged += 1
			else:
				past_the_end += 1
		elif f.atk.frame > Fighter.CHARGE_CHECK_FRAME and f.atk.frame < iai.startup - 4:
			# on its way from the guard to the cocked pose
			assert_gt(V3.distance(b.tip, b.prev_tip), 0.0, "the blade moves again after the charge, on frame %d" % f.atk.frame)
		last = b
	assert_gt(charged, 30, "the Iai was charged")
	assert_gt(past_the_end, 0, "and ran into extra recovery")


func test_the_segment_holds_in_hit_stop() -> void:
	var cut: AttackDef = SF.timed(Moves.KATANA.moves[&"k_l1"])
	# 1.6 m apart: the lunge closes to 1.25 m, and the slash cuts through the
	# idle opponent (task 7.10: its sweep decides)
	var W: World = H.make_world(SF.weapon(&"katana", {&"k_l1": SF.level_slash(cut, 1.2)}), Moves.KATANA, 1.6)
	var f: Fighter = W.fighters[0]
	var hit: bool = false
	for i: int in 20:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		for e: Dictionary in W.drain_events():
			hit = hit or e["t"] == &"hit"
		if hit:
			break
	assert_true(hit, "Right Cut hit")
	assert_gt(W.hitstop, 0, "into hit-stop")
	var frame: int = f.atk.frame
	var tip: V3 = _copy(_only(f).tip)
	var prev_tip: V3 = _copy(_only(f).prev_tip)
	var held: int = 0
	while W.hitstop > 0:
		W.step([H.idle(), H.idle()])
		held += 1
		assert_eq(f.atk.frame, frame, "the frame holds")
		_assert_v3(_only(f).tip, tip, "the tip holds")
		_assert_v3(_only(f).prev_tip, prev_tip, "and the last tick's")
	assert_gt(held, 0, "for the hit-stop's ticks")
	W.step([H.idle(), H.idle()])
	_assert_v3(_only(f).prev_tip, tip, "then the sweep goes on from where the blade held")
	assert_gt(V3.distance(_only(f).tip, tip), 0.0, "to the next frame's")


func test_the_first_tick_s_last_segment_is_its_own() -> void:
	var cuts: Dictionary[StringName, Swing] = {
		&"k_l1": SF.level_slash(Moves.KATANA.moves[&"k_l1"], 1.2),
		&"k_l2": SF.level_slash(Moves.KATANA.moves[&"k_l2"], 1.2, -60.0, 60.0),
	}
	var W: World = H.make_world(SF.weapon(&"katana", cuts), Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	var firsts: Array[StringName] = []
	for i: int in 40:
		W.step([H.btn(Btn.LIGHT) if i == 0 or i == 13 else H.idle(), H.idle()])
		if f.state != &"attack" or f.atk.frame != 0:
			continue
		var b: BladeSegment = _only(f)
		firsts.append(f.atk.def.id)
		_assert_v3(b.prev_tip, b.tip, "%s's first tick sweeps nothing: the tip" % f.atk.def.id)
		_assert_v3(b.prev_base, b.base, "and the base")
		if f.atk.def.id == &"k_l2":
			# Return Cut enters from Right Cut's hand-off, its settle 80° left,
			# not from the guard
			var a: float = -80.0 * SimMath.DEG
			var right: float = 0.45 * sin(a) + 0.077 * cos(a) + 1.39 * sin(a)
			var forward: float = 0.45 * cos(a) - 0.077 * sin(a) + 1.39 * cos(a)
			_assert_v3(b.tip, V3.make(f.pos.x - right, 1.2, f.pos.z + forward), "Return Cut starts at Right Cut's hand-off", 1e-9)
	assert_eq(firsts, [&"k_l1", &"k_l2"] as Array[StringName], "Right Cut, then Return Cut")


func test_only_striking_tracks_of_swings_have_segments() -> void:
	var W: World = H.make_world(SF.without_swings(&"katana"), Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	assert_eq(f.blade_segments(), [] as Array[BladeSegment], "none outside an attack")
	W.step([H.btn(Btn.LIGHT), H.idle()])
	assert_eq(f.state, &"attack")
	assert_eq(f.blade_segments(), [] as Array[BladeSegment], "none for a move without a swing")
	# a dagger in each hand, and a coil: two blades
	var low: Swing.KeyPose = SF.key(0, [0.2, 1.0, 0.3], [0.0, 0.0, 1.0], [-1.0, 0.0, 0.0])
	var high: Swing.KeyPose = SF.key(0, [-0.2, 1.3, 0.3], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0])
	var twin: Swing = SF.held(Moves.DAGGERS.moves[&"d_l1"], {RIGHT: low, &"left_hand": high, &"body": SF.body_key(0, 20.0, 10.0)})
	W = H.make_world(SF.weapon(&"daggers", {&"d_l1": twin}), Moves.KATANA, 6.0)
	W.step([H.btn(Btn.LIGHT), H.idle()])
	var parts: Array[StringName] = []
	for b: BladeSegment in W.fighters[0].blade_segments():
		parts.append(b.part)
		assert_eq(b.half_thickness, 0.007, "%s: half a dagger's 14 mm" % b.part)
	assert_eq(parts, [RIGHT, &"left_hand"] as Array[StringName], "both daggers, and not the body")
	# bare hands: a fist and a foot
	var kick: Swing.KeyPose = SF.key(0, [0.1, 0.4, 0.3], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0])
	var punch: Swing = SF.held(Moves.FISTS.moves[&"f_l1"], {RIGHT: low, &"right_foot": kick})
	W = H.make_world(SF.weapon(&"fists", {&"f_l1": punch}), Moves.KATANA, 6.0)
	W.step([H.btn(Btn.LIGHT), H.idle()])
	var halves: Dictionary[StringName, float] = {}
	for b: BladeSegment in W.fighters[0].blade_segments():
		halves[b.part] = b.half_thickness
	assert_eq(halves, {RIGHT: 0.0435, &"right_foot": 0.0575} as Dictionary[StringName, float], "the fist and the foot")
	# the foot's frame: from the ankle, the toe 23 cm along the foot,
	# forward, and 3.3 cm toward the sole, down; facing +Z
	var foot: BladeSegment = W.fighters[0].blade_segments()[1]
	var p: V3 = W.fighters[0].pos
	_assert_v3(foot.tip, V3.make(p.x - 0.1, 0.4 - 0.033, p.z + 0.3 + 0.23), "the foot's tip")
