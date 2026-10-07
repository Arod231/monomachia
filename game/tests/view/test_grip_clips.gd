extends GutTest
## Per-grip clips in the view (KE task 8): the clip director picks the idle,
## the guard and the carry by weapon and grip (StateClips "grips"), and plays
## the grip's re-grip transition on a switch (D15), asking an inertial blend
## where there is none. The Katana's grips stand in on today's idle and guard
## until KE task 10 keys their own.

const H := preload("res://tests/sim/sim_helpers.gd")
const ONE: StringName = WeaponGrip.ONE_HANDED
const TWO: StringName = WeaponGrip.TWO_HANDED
## The made-up clips' length (s).
const LENGTH: float = 0.5
## A made-up re-grip's length (s): 12 rules frames.
const REGRIP_LENGTH: float = 0.2


func before_each() -> void:
	FrozenStateClips.install()


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
		ONE: {&"idle": &"Idle_one", &"guard": [&"Guard_one_Loop", &"Guard_one_Hit"], &"carry": &""},
		TWO: {&"idle": &"Idle_two", &"guard": [&"Guard_two_Loop", &"Guard_two_Hit"], &"carry": &"Carry_two"},
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


func test_the_katana_s_grips_stand_in_on_today_s_idle_and_guard() -> void:
	var t: StateClips = StateClips.read()
	assert_eq(t.errors, PackedStringArray())
	for grip: StringName in [ONE, TWO]:
		assert_eq(t.idle_for(&"katana", grip), t.idle[&"katana"], "%s: today's guard idle until KE task 10" % grip)
		assert_eq(t.guard_for(&"katana", grip), t.guard_clips[&"katana"], "%s: today's guard" % grip)
		assert_eq(t.carry_for(&"katana", grip), &"", "%s: no carry yet" % grip)
		assert_eq(t.regrip_for(&"katana", grip), &"", "%s: no re-grip yet" % grip)
	assert_true(t.grip_clips.has(&"katana"), "the Katana's grips are listed")


func test_the_table_refuses_a_grip_without_its_clips() -> void:
	var path: String = "user://grip_clips_test.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FrozenStateClips.PATH))
	data["grips"] = {"katana": {"one_handed": {"idle": "X"}, "sideways": {"idle": "Y", "guard": ["A", "B"]}, "regrip": {"two_handed": 3}}}
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var t: StateClips = StateClips.read(path)
	DirAccess.remove_absolute(path)
	var all: String = "\n".join(t.errors)
	assert_string_contains(all, "grips.katana.one_handed")
	assert_string_contains(all, "sideways")
	assert_string_contains(all, "grips.katana.regrip")
