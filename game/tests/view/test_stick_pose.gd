extends GutTest
## The stick poses FighterView poses the fighters from, read from the rules'
## state: guard, block, an attack sweeping wind-up -> strike ->
## follow-through -> guard, a reel when hit, the fall on KO, bare hands when
## disarmed, and the Iai's sheathe.


func after_each() -> void:
	SimHelpers.dispose_all()


func _world(w1: WeaponDef = Moves.KATANA, w2: WeaponDef = Moves.KATANA) -> World:
	return SimHelpers.make_world(w1, w2)


func _press(W: World, b: int) -> void:
	W.step([SimHelpers.btn(b), SimHelpers.idle()])


func test_the_sticks_are_as_long_as_their_weapons_rank() -> void:
	assert_gt(StickPose.LENGTH[&"greatsword"], StickPose.LENGTH[&"katana"])
	assert_gt(StickPose.LENGTH[&"katana"], StickPose.LENGTH[&"daggers"])


## Two hands on one grip exactly for the weapons whose look says so.
func test_two_handed_comes_from_the_weapon_look() -> void:
	for weapon: WeaponDef in [Moves.KATANA, Moves.GREATSWORD, Moves.DAGGERS]:
		var W: World = _world(weapon)
		var p: StickPose.Pose = StickPose.compute(W.fighters[0], 0.0)
		assert_eq(p.two_handed, WeaponLook.load_id(weapon.id).two_handed, String(weapon.id))


## Overheads and slams come down the body's centre line instead of swinging
## out round the side, so they read as vertical cuts.
func test_vertical_attacks_stay_on_the_centre_line() -> void:
	for anim: StringName in [&"overhead", &"slam", &"leapCleave", &"plunge"]:
		var keys: Array = StickPose.ARCH[anim]
		var a: Vector3 = StickPose.local(keys[0]["rh"])
		var b: Vector3 = StickPose.local(keys[1]["rh"])
		for k: int in 11:
			var t: float = float(k) / 10.0
			var at: Vector3 = StickPose.arc(a, b, t)
			assert_lt(absf(at.x), StickPose.CENTRE_LINE, "%s at %.1f" % [anim, t])
	# a slash still sweeps round the body
	var ka: Vector3 = StickPose.local(StickPose.ARCH[&"slashRL"][0]["rh"])
	var kb: Vector3 = StickPose.local(StickPose.ARCH[&"slashRL"][1]["rh"])
	var mid: Vector3 = StickPose.arc(ka, kb, 0.5)
	assert_gt(Vector2(mid.x, mid.z).length(), Vector2(ka.x, ka.z).lerp(Vector2(kb.x, kb.z), 0.5).length() + 0.01, "an arc, not a chord")


func test_a_free_fighter_holds_the_guard() -> void:
	var W: World = _world()
	var p: StickPose.Pose = StickPose.compute(W.fighters[0], 0.0)
	assert_eq(p.phase, &"guard")
	assert_true(p.two_handed)
	assert_false(p.bare)
	assert_gt(p.right.pos.z, 0.1, "the hands are in front of the body")


func test_blocking_raises_the_block() -> void:
	var W: World = _world()
	for i: int in 3:
		W.step([SimHelpers.btn(Btn.BLOCK), SimHelpers.idle()])
	assert_true(W.fighters[0].blocking)
	var p: StickPose.Pose = StickPose.compute(W.fighters[0], 1.0)
	assert_eq(p.phase, &"block")
	assert_lt(absf(p.right.dir.y), 0.5, "the katana held across the body")


func test_an_attack_sweeps_through_its_arc() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_press(W, Btn.LIGHT)
	assert_eq(a.state, &"attack")
	var def: AttackDef = a.atk.def
	assert_eq(def.anim, &"slashRL")
	var phases: Array[StringName] = []
	var hand_x: Array[float] = []
	var dirs: Array[Vector3] = []
	while a.state == &"attack":
		var p: StickPose.Pose = StickPose.compute(a, 1.0)
		if phases.is_empty() or phases[-1] != p.phase:
			phases.append(p.phase)
		hand_x.append(p.right.pos.x)
		dirs.append(p.right.dir)
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	assert_eq(phases, [&"windup", &"strike", &"follow", &"recover"] as Array[StringName], "wind-up, strike, follow-through, back to guard")
	# a right-to-left cut: the hand starts on the right (-x) and ends on the left (+x)
	var lowest: float = hand_x.min()
	var highest: float = hand_x.max()
	assert_lt(lowest, -0.3, "wound up on the right")
	assert_gt(highest, 0.25, "followed through to the left")
	var turned: float = 0.0
	for i: int in range(1, dirs.size()):
		turned += dirs[i - 1].angle_to(dirs[i])
	assert_gt(turned, PI * 0.8, "the blade sweeps a wide arc")
	assert_eq(StickPose.compute(a, 1.0).phase, &"guard", "and returns to guard")


func test_the_strike_lands_on_the_impact_key() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_press(W, Btn.LIGHT)
	var def: AttackDef = a.atk.def
	while a.atk.frame < def.startup + 1:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	var p: StickPose.Pose = StickPose.compute(a, 1.0)
	var impact: Dictionary = StickPose.attack_keys(def, &"katana")[1]
	assert_almost_eq(p.right.pos, (impact["right"] as StickPose.Hand).pos, Vector3.ONE * 1e-4)


func test_an_unblockable_glows_red_while_it_winds_up() -> void:
	var W: World = _world(Moves.GREATSWORD)
	var a: Fighter = W.fighters[0]
	a.start_attack(&"g_sweep")
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	assert_true(a.atk.def.unblockable)
	var p: StickPose.Pose = StickPose.compute(a, 1.0)
	assert_eq(p.glow, &"danger")
	assert_eq(p.glow_amount, 1.0)


func test_a_hit_fighter_reels_and_a_ko_falls() -> void:
	var W: World = _world()
	var b: Fighter = W.fighters[1]
	b.enter_hitstun(20)
	var p: StickPose.Pose = StickPose.compute(b, 1.0)
	assert_eq(p.phase, &"reel")
	assert_lt(p.lean, -0.1, "leaning back")
	b.to_ko()
	for i: int in 30:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	p = StickPose.compute(b, 1.0)
	assert_eq(p.phase, &"down")
	assert_almost_eq(p.down, 1.0, 1e-6, "lying on the floor")


func test_a_disarmed_fighter_is_bare_handed() -> void:
	var W: World = _world()
	var b: Fighter = W.fighters[1]
	b.armed = false
	var p: StickPose.Pose = StickPose.compute(b, 1.0)
	assert_true(p.bare)
	assert_false(p.two_handed)


func test_daggers_left_hand_moves_mirror_the_right() -> void:
	var def: AttackDef = Moves.DAGGERS.moves[&"d_l2"]
	assert_eq(def.hand, &"L")
	var keys: Array[Dictionary] = StickPose.attack_keys(def, &"daggers")
	var right_keys: Array[Dictionary] = StickPose.attack_keys(Moves.DAGGERS.moves[&"d_l1"], &"daggers")
	var l: StickPose.Hand = keys[1]["left"]
	var r: StickPose.Hand = right_keys[1]["right"]
	assert_almost_eq(l.pos, StickPose.mirrored(r.pos), Vector3.ONE * 1e-6)


func test_every_move_names_a_pose_the_stand_in_has() -> void:
	# the weapons' moves by their anim; bare hands' by their type, as the
	# stand-in has no hand-to-hand poses; the ultimates' hits are posed from
	# the ultimate state, not as attacks
	for wid: StringName in Moves.PLAYABLE_WEAPONS:
		for id: StringName in Moves.WEAPONS[wid].moves:
			var anim: StringName = Moves.WEAPONS[wid].moves[id].anim
			assert_true(
				StickPose.ARCH.has(anim) or StickPose.SHEATHED_DRAWS.has(anim),
				"%s.%s's anim %s is one of the stand-in's poses" % [wid, id, anim],
			)
	for id: StringName in Moves.FISTS.moves:
		var type: StringName = Moves.FISTS.moves[id].type
		assert_true(
			StickPose.ARCH.has(StickPose.TYPE_ARCH.get(type, &"")), "bare hands' %s, a %s, has its type's pose" % [id, type]
		)
	for anim: StringName in StickPose.SHEATHED_DRAWS:
		assert_true(StickPose.ARCH.has(StickPose.SHEATHED_DRAWS[anim]), "%s draws into one of the poses" % anim)


# ------------------------------------------------------------------ the Iai's sheathe

## Fighter 0 (Katana) holds heavy, with the stick at mx, for hold steps, then
## lets go, for n steps; returns its pose after each step (alpha 1, so the
## pose of the step just taken) and its attack's frame then (-1 outside one).
func _iai_poses(hold: int, mx: float, n: int) -> Array[Dictionary]:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	var out: Array[Dictionary] = []
	for i: int in n:
		var p0: RawInput = SimHelpers.move(mx, 0.0, Btn.HEAVY) if i < hold else SimHelpers.move(mx, 0.0)
		W.step([p0, SimHelpers.idle()])
		var attacking: bool = a.state == &"attack" and a.atk != null
		out.append({"pose": StickPose.compute(a, 1.0), "frame": a.atk.frame if attacking else -1})
	return out


## The pose in poses when the attack's frame was frame (null if never).
static func _pose_at(poses: Array[Dictionary], frame: int) -> StickPose.Pose:
	for step: Dictionary in poses:
		if step["frame"] == frame:
			return step["pose"]
	return null


## The phases a run of poses goes through, each once, in order.
static func _phases(poses: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for step: Dictionary in poses:
		var phase: StringName = (step["pose"] as StickPose.Pose).phase
		if out.is_empty() or out[-1] != phase:
			out.append(phase)
	return out


func test_the_iai_sheathes_then_draws() -> void:
	assert_eq(
		_phases(_iai_poses(1, 0.0, 60)),
		[&"sheathe", &"draw", &"strike", &"follow", &"recover", &"guard"] as Array[StringName],
		"tapped: sheathed and drawn at once",
	)
	assert_eq(
		_phases(_iai_poses(40, 0.0, 100)),
		[&"sheathe", &"sheathed", &"draw", &"strike", &"follow", &"recover", &"guard"] as Array[StringName],
		"held: the sheathed stance until heavy is let go",
	)


func test_the_sheathed_hand_sits_by_the_left_hip() -> void:
	# in the stance, 20 steps in; the fighter's left is +x in its own frame
	var p: StickPose.Pose = _iai_poses(40, 0.0, 20)[-1]["pose"]
	assert_eq(p.phase, &"sheathed")
	assert_gt(p.right.pos.x, 0.05, "the hand on the hilt is left of the centre line")
	assert_between(p.right.pos.y, 0.85, 1.15, "at the hip's height")
	assert_between(p.right.pos.z, 0.0, 0.35, "just in front of the hip")
	assert_lt(p.right.dir.z, -0.7, "the blade lies back along the hip")
	assert_eq(p.glow, &"charge", "glowing as the charge builds")


## The Iai's wind-up ends on frame 16: 70% of its 23-frame startup, as every
## attack's wind-up does.
const IAI_WINDUP_END: int = 16


func test_both_draws_start_from_the_sheathe() -> void:
	# held to step 40, so the draw starts on step 40, on frame 10, and goes out
	# in front before it rises into the cut's wind-up
	var draws: Array[Dictionary] = [
		{"way": "the vertical", "mx": 0.0, "draws_into": &"overhead"},
		{"way": "the horizontal", "mx": 1.0, "draws_into": &"slashRL"},
	]
	for d: Dictionary in draws:
		var poses: Array[Dictionary] = _iai_poses(40, d["mx"], 60)
		var sheathed: StickPose.Pose = poses[39]["pose"]
		var drawing: StickPose.Pose = poses[40]["pose"]
		assert_eq([sheathed.phase, drawing.phase], [&"sheathed", &"draw"], "%s: sheathed, then drawn" % d["way"])
		assert_lt(sheathed.right.pos.distance_to(drawing.right.pos), 0.15, "%s starts from the sheathe" % d["way"])
		var midway: StickPose.Pose = _pose_at(poses, 12)
		assert_gt(midway.right.dir.z, 0.7, "%s: halfway, the blade points forward, out of the sheathe" % d["way"])
		assert_gt(midway.right.pos.z, 0.3, "%s: and the hands are out in front, clear of the body" % d["way"])
		var windup: Vector3 = StickPose.local(StickPose.ARCH[d["draws_into"]][0]["rh"])
		var at_windup_end: StickPose.Pose = _pose_at(poses, IAI_WINDUP_END)
		assert_lt(at_windup_end.right.pos.distance_to(windup), 0.1, "%s draws into the %s wind-up" % [d["way"], d["draws_into"]])


