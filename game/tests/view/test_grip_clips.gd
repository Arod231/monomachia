extends GutTest
## Per-grip clips in the view (KE task 8): the clip director picks the idle,
## the guard and the carry by weapon and grip (StateClips "grips"), and plays
## the grip's re-grip transition on a switch (D15), asking an inertial blend
## where there is none. Since KE task 10 the Katana's grips have their own
## clips, and the off hand follows the clip playing (Shot.off_hand): on the
## handle for a two-handed clip, left on the clip for the one-handed grip's.

const H := preload("res://tests/sim/sim_helpers.gd")
const ONE: StringName = WeaponGrip.ONE_HANDED
const TWO: StringName = WeaponGrip.TWO_HANDED
## The made-up clips' length (s).
const LENGTH: float = 0.5
## A made-up re-grip's length (s): 12 rules frames.
const REGRIP_LENGTH: float = 0.2


func before_each() -> void:
	FrozenStateClips.install()
	# from a round's start, one-handed
	H.grip = &""


func after_each() -> void:
	FrozenStateClips.restore()
	H.dispose_all()


## The frozen table with made-up per-grip clips for the Katana: each grip its
## own idle (Idle_one, Idle_two) and guard (Guard_<grip>_Loop and _Hit), the
## two-handed grip a carry (Carry_two), and both re-grips (To_one, To_two)
## unless `regrips` is false. A context whose tree has them.
static func _ctx(regrips: bool = true) -> ClipDirector.Context:
	var t: StateClips = StateClips.read(FrozenStateClips.PATH)
	t.grip_clips[&"katana"] = {
		ONE: {&"idle": &"Idle_one", &"guard": [&"Guard_one_Loop", &"Guard_one_Hit"], &"carry": &"", &"moves": [] as Array[StringName]},
		TWO: {&"idle": &"Idle_two", &"guard": [&"Guard_two_Loop", &"Guard_two_Hit"], &"carry": &"Carry_two", &"moves": [] as Array[StringName]},
	}
	if regrips:
		t.regrips[&"katana"] = {ONE: &"To_one", TWO: &"To_two"}
	StateClips.use(t)
	var lengths: Dictionary[String, float] = {}
	for set_name: StringName in ClipLibraries.SETS:
		for id: String in ["Idle_one", "Idle_two", "Guard_one_Loop", "Guard_one_Hit", "Guard_two_Loop", "Guard_two_Hit", "Carry_two"]:
			lengths["%s/%s" % [set_name, id]] = LENGTH
		for id: String in ["To_one", "To_two"]:
			lengths["%s/%s" % [set_name, id]] = REGRIP_LENGTH
	return ClipDirector.Context.make(&"hunter", true, lengths)


static func _with_grip(base: RawInput) -> RawInput:
	return RawInput.make(base.mx, base.my, base.buttons | Btn.bit(Btn.GRIP))


## Steps W with fighter 0 on `p0` and the director after it.
static func _next(W: World, prev: ClipDirector.Shot, ctx: ClipDirector.Context, p0: RawInput = null) -> ClipDirector.Shot:
	W.step([H.idle() if p0 == null else p0, H.idle()])
	return ClipDirector.step(prev, W.fighters[0], ctx)


func test_the_idle_follows_the_grip() -> void:
	var ctx: ClipDirector.Context = _ctx()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = ClipDirector.step(null, W.fighters[0], ctx)
	assert_eq(shot.idle, "HumanM/Idle_one", "one-handed")
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	assert_eq(shot.idle, "HumanM/Idle_two", "two-handed")


func test_the_guard_follows_the_grip() -> void:
	var ctx: ClipDirector.Context = _ctx()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx, H.btn(Btn.BLOCK))
	assert_eq([shot.phase, shot.clip.name], [&"guard", "HumanM/Guard_one_Loop"], "one-handed")
	for i: int in 20:
		shot = _next(W, shot, ctx, _with_grip(H.btn(Btn.BLOCK)) if i == 0 else H.btn(Btn.BLOCK))
	assert_eq([shot.phase, shot.clip.name], [&"guard", "HumanM/Guard_two_Loop"], "two-handed, once the re-grip has played")


func test_the_carry_follows_the_grip() -> void:
	var ctx: ClipDirector.Context = _ctx(false)
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	assert_eq(shot.drive, ClipDirector.LEGS, "one-handed: no carry")
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	shot = _next(W, shot, ctx)
	assert_eq([shot.drive, shot.clip.name], [ClipDirector.CARRY, "HumanM/Carry_two"], "two-handed: its carry over the legs")
	assert_eq(shot.legs_free(), 1.0, "on the upper body")
	shot = _next(W, shot, ctx, H.btn(Btn.LIGHT))
	assert_ne(shot.drive, ClipDirector.CARRY, "an attack takes over")


## KE task 10: the carry (a guard idle) loops at its own speed, and gives way
## to the gait's upper body running ahead; strafing keeps it.
func test_the_carry_loops_and_gives_way_running_ahead() -> void:
	var ctx: ClipDirector.Context = _ctx(false)
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 24.0)
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx, _with_grip(H.idle()))
	var times: Array[float] = []
	for i: int in 40:
		shot = _next(W, shot, ctx)
		times.append(shot.clip.time)
	assert_eq(shot.clip.name, "HumanM/Carry_two")
	assert_almost_eq(times[1] - times[0], 1.0 / SimConst.FPS, 1e-6, "at 1.0")
	assert_lt(times.max(), LENGTH, "looping inside the clip")
	assert_lt(times[-1], times[0] + 39.0 / SimConst.FPS, "it has looped")
	for i: int in 30:
		shot = _next(W, shot, ctx, H.move(-1.0, 0.0))
	assert_eq(shot.drive, ClipDirector.CARRY, "strafing keeps it")
	for i: int in 30:
		shot = _next(W, shot, ctx, H.move(0.0, 1.0))
	assert_true(ClipDirector.running_ahead(f), "running at the opponent")
	assert_eq(shot.drive, ClipDirector.LEGS, "the run's own upper body")


func test_a_switch_plays_the_new_grip_s_re_grip_on_the_upper_body() -> void:
	var ctx: ClipDirector.Context = _ctx()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	assert_eq([shot.drive, shot.phase, shot.clip.name], [ClipDirector.STATE, &"regrip", "HumanM/To_two"], "into two hands")
	assert_true(shot.upper, "the legs' blend under it")
	assert_gt(shot.blend, 0, "an inertial blend into it")
	assert_almost_eq(shot.clip.time, 0.0, 1e-9, "from its start")
	var frames: int = 0
	while shot.phase == &"regrip" and frames < 60:
		shot = _next(W, shot, ctx)
		frames += 1
	assert_eq(frames, roundi(REGRIP_LENGTH * SimConst.FPS), "at its own speed, then hands on")
	assert_eq(shot.drive, ClipDirector.CARRY, "on to the two-handed carry")
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	assert_eq([shot.phase, shot.clip.name], [&"regrip", "HumanM/To_one"], "and back out of two hands")


func test_an_attack_cuts_the_re_grip_short() -> void:
	var ctx: ClipDirector.Context = _ctx()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	assert_eq(shot.phase, &"regrip")
	shot = _next(W, shot, ctx, H.btn(Btn.LIGHT))
	assert_ne(shot.phase, &"regrip", "the light's clip takes over")


func test_a_switch_mid_attack_plays_no_re_grip() -> void:
	var ctx: ClipDirector.Context = _ctx()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx, H.btn(Btn.LIGHT))
	for i: int in 5:
		shot = _next(W, shot, ctx)
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	assert_ne(shot.phase, &"regrip", "the swing plays on; the next hit's clip is the new grip's")


func test_without_a_re_grip_a_switch_asks_an_inertial_blend() -> void:
	var ctx: ClipDirector.Context = _ctx(false)
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	shot = _next(W, shot, ctx)
	assert_eq(shot.blend, 0)
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	assert_ne(shot.phase, &"regrip")
	assert_gt(shot.blend, 0, "the new grip's pose blended in")


func test_a_disarm_is_no_switch() -> void:
	var ctx: ClipDirector.Context = _ctx()
	var W: World = H.make_world()
	var f: Fighter = W.fighters[0]
	var shot: ClipDirector.Shot = _next(W, null, ctx, _with_grip(H.idle()))
	for i: int in 20:
		shot = _next(W, shot, ctx)
	f.disarm(W.fighters[1], &"parried")
	shot = _next(W, shot, ctx)
	assert_ne(shot.phase, &"regrip", "bare hands have no grip to switch")


func test_weapons_without_grips_and_the_frozen_table_keep_their_clips() -> void:
	var t: StateClips = StateClips.read(FrozenStateClips.PATH)
	assert_eq(t.idle_for(&"katana", ONE), t.idle[&"katana"], "no grips entry: the weapon's idle")
	assert_eq(t.guard_for(&"greatsword", &""), t.guard_clips[&"greatsword"])
	assert_eq(t.carry_for(&"katana", TWO), &"")
	assert_eq(t.regrip_for(&"katana", TWO), &"")


## KE task 10: each grip its own guard idle, doubling as its carry, and its
## own block (the one-handed the pack's parry as it is, the two-handed a
## two-handed re-key of it), and a re-grip into each; the one-handed grip's
## clips leave the off hand off the handle.
func test_the_katana_s_grips_play_their_own_clips() -> void:
	var t: StateClips = StateClips.read()
	assert_eq(t.errors, PackedStringArray())
	assert_eq(t.idle_for(&"katana", ONE), &"KatanaGuard1H", "one-handed: the blade low at the side")
	assert_eq(t.idle_for(&"katana", TWO), &"KatanaGuard", "two-handed: the guard of milestone-1 task 33")
	for grip: StringName in [ONE, TWO]:
		assert_eq(t.carry_for(&"katana", grip), t.idle_for(&"katana", grip), "%s: the guard idle doubles as the carry" % grip)
	assert_eq(t.guard_for(&"katana", ONE), [&"Parry1H01_R_Loop", &"Parry1H01_R_Hit"], "one-handed: the pack's parry")
	assert_eq(t.guard_for(&"katana", TWO), [&"KatanaBlockLoop", &"KatanaBlockHit"], "two-handed: its re-key")
	assert_eq(t.regrip_for(&"katana", TWO), &"KatanaRegripTo2H")
	assert_eq(t.regrip_for(&"katana", ONE), &"KatanaRegripTo1H")
	for id: StringName in [&"KatanaGuard1H", &"Parry1H01_R_Loop", &"Parry1H01_R_Hit", &"KatanaRegripTo1H"]:
		assert_true(t.one_handed(&"katana", id), "%s leaves the off hand off the handle" % id)
	for id: StringName in [&"KatanaGuard", &"KatanaBlockLoop", &"KatanaBlockHit", &"KatanaRegripTo2H"]:
		assert_false(t.one_handed(&"katana", id), "%s holds the handle in both hands" % id)
	assert_false(t.one_handed(&"greatsword", &"Parry1H01_R_Loop"), "a weapon without grips holds as it always has")


func test_the_table_refuses_a_grip_without_its_clips() -> void:
	var path: String = "user://grip_clips_test.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FrozenStateClips.PATH))
	data["grips"] = {"katana": {"one_handed": {"idle": "X"}, "two_handed": {"idle": "Z", "guard": ["A", "B"], "moves": "C"}, "sideways": {"idle": "Y", "guard": ["A", "B"]}, "regrip": {"two_handed": 3}}}
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var t: StateClips = StateClips.read(path)
	DirAccess.remove_absolute(path)
	var all: String = "\n".join(t.errors)
	assert_string_contains(all, "grips.katana.one_handed")
	assert_string_contains(all, "sideways")
	assert_string_contains(all, "grips.katana.regrip")
	assert_string_contains(all, "grips.katana.two_handed")


# ------------------------------------------------------- the off hand (KE task 10)

## The made-up table, its one-handed grip also playing `moves` in one hand:
## Idle_one, its guard and To_one (the grip's own) leave the off hand on the
## clip, and so do those.
static func _one_handed(moves: Array[StringName] = []) -> ClipDirector.Context:
	var ctx: ClipDirector.Context = _ctx()
	(StateClips.shared().grip_clips[&"katana"][ONE] as Dictionary)[&"moves"] = moves
	# the one-handed light's clip, so it plays
	for set_name: StringName in ClipLibraries.SETS:
		ctx.lengths["%s/%s" % [set_name, _light_clip()]] = 2.0
	return ctx


## The one-handed string's hit 1's clip (Slanting Cut's since KE task 11).
static func _light_clip() -> StringName:
	return (Moves.KATANA.moves[Moves.KATANA.grip(ONE).hit(1)] as AttackDef).swing.clips[0]


func test_a_round_starts_with_the_off_hand_off_the_handle() -> void:
	var ctx: ClipDirector.Context = _one_handed()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = ClipDirector.step(null, W.fighters[0], ctx)
	assert_eq(shot.off_hand, 0.0, "one-handed from the first frame")
	assert_eq(shot.off_hand_before, 0.0)
	shot = _next(W, shot, ctx, H.btn(Btn.BLOCK))
	assert_eq([shot.clip.name, shot.off_hand], ["HumanM/Guard_one_Loop", 0.0], "and in the one-handed guard")


func test_the_off_hand_joins_the_handle_with_the_re_grip() -> void:
	var ctx: ClipDirector.Context = _one_handed()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	assert_eq(shot.phase, &"regrip")
	var last: float = shot.off_hand
	assert_lt(last, 0.1, "it starts off the handle")
	while shot.phase == &"regrip":
		shot = _next(W, shot, ctx)
		assert_true(shot.off_hand >= last, "it only closes in (%.3f after %.3f)" % [shot.off_hand, last])
		last = shot.off_hand
	assert_eq(shot.off_hand, 1.0, "on the handle once the re-grip has played")


func test_the_off_hand_lets_go_within_a_few_frames() -> void:
	var ctx: ClipDirector.Context = _one_handed()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx, _with_grip(H.idle()))
	for i: int in 30:
		shot = _next(W, shot, ctx)
	assert_eq(shot.off_hand, 1.0, "two-handed")
	shot = _next(W, shot, ctx, _with_grip(H.idle()))
	assert_eq(shot.clip.name, "HumanM/To_one")
	var frames: int = 1
	while shot.off_hand > 0.0 and frames < 60:
		var before: float = shot.off_hand
		shot = _next(W, shot, ctx)
		assert_lt(shot.off_hand, before, "it lets go steadily")
		assert_eq(shot.off_hand_before, before)
		frames += 1
	assert_eq(frames, ClipDirector.OFF_HAND_FRAMES, "off the handle in %d rules frames" % ClipDirector.OFF_HAND_FRAMES)


func test_a_two_handed_clip_takes_the_off_hand_back() -> void:
	var ctx: ClipDirector.Context = _one_handed()
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	shot = _next(W, shot, ctx, H.btn(Btn.LIGHT))
	assert_eq(shot.drive, ClipDirector.ATTACK, "the light, its clip not among the frozen grip's moves: a two-handed clip")
	for i: int in ClipDirector.OFF_HAND_FRAMES - 1:
		shot = _next(W, shot, ctx)
	assert_eq(shot.off_hand, 1.0, "on the handle within %d rules frames" % ClipDirector.OFF_HAND_FRAMES)


func test_the_one_handed_grip_s_moves_keep_it_off() -> void:
	var ctx: ClipDirector.Context = _one_handed([_light_clip()])
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = _next(W, null, ctx)
	shot = _next(W, shot, ctx, H.btn(Btn.LIGHT))
	assert_eq(shot.drive, ClipDirector.ATTACK)
	for i: int in 10:
		shot = _next(W, shot, ctx)
		assert_eq(shot.off_hand, 0.0, "a one-handed move's clip keeps it on the clip")


func test_without_the_packs_the_off_hand_holds_the_handle() -> void:
	_one_handed()
	var ctx: ClipDirector.Context = ClipDirector.Context.make(&"hunter", false, {} as Dictionary[String, float])
	var W: World = H.make_world()
	var shot: ClipDirector.Shot = ClipDirector.step(null, W.fighters[0], ctx)
	assert_eq(shot.off_hand, 1.0, "the CC0 stand-ins are held as they always were")
