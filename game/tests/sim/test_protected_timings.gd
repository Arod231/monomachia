extends GutTest
## The protected timings (milestone-1 task 22): the spec's protected-timing
## table, retuned once for the Katana and bare hands and frozen, and the
## free-frame rule over the follow-up pairs.
##
## The numbers are stated here, not read from ProtectedTimings, so changing
## one fails until this test is changed too, with the owner's OK. They are
## the spec's table as corrected with the owner on Oct 5: each hitstun the
## free-frame rule sets is a frame longer than the spec first counted
## (Katana lights 24, bare hands' 18, heavies 41, bare hands' 35), since a
## follow-up plays its first frame the step after its branch point.
##
## The retune takes effect in two parts (the owner's choice): a move's own
## values (hitstun, blockstun, hit-stop, the charge bonus) as its family
## re-keys it, so today's stand-ins keep today's; the outcome values (the
## counters' stuns, the disarm's stagger and daze, the knockdown, the
## outcome hit-stops) at once, for every Katana and bare-hands move. The
## weapon of the move decides which set applies.

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")


func after_each() -> void:
	H.dispose_all()


# ------------------------------------------------------------------ the frozen values

## [hitstun light, heavy, ability, ultimate], [blockstun light, heavy,
## ability], [hit-stop light, heavy, ability, ultimate], [charge bonus
## hitstun, blockstun, hit-stop], [hit-stop of a parry, Flash or redirect,
## disarm, stomp, leap], [stomp, Flash, redirect stun], [disarm stagger,
## disarmed daze], [knockdown fall, down, rise, guard window].
static func _row(t: ProtectedTimings) -> Array:
	return [
		[t.hitstun(&"light"), t.hitstun(&"heavy"), t.hitstun(&"ability"), t.hitstun(&"ultimate")],
		[t.blockstun(&"light"), t.blockstun(&"heavy"), t.blockstun(&"ability")],
		[t.hitstop(&"light"), t.hitstop(&"heavy"), t.hitstop(&"ability"), t.hitstop(&"ultimate")],
		[t.charge_hitstun, t.charge_blockstun, t.charge_hitstop],
		[t.parry_hitstop, t.flash_hitstop, t.disarm_hitstop, t.stomp_hitstop, t.leap_hitstop],
		[t.stomp_stun, t.flash_stun, t.redirect_stun],
		[t.disarm_stagger, t.disarmed_daze],
		[t.knockdown_fall, t.knockdown_ground, t.knockdown_rise, t.knockdown_guard],
	]


func test_the_katana_takes_the_retuned_values() -> void:
	var t: ProtectedTimings = ProtectedTimings.for_weapon(&"katana")
	assert_true(t.retuned)
	assert_eq(_row(t), [
		[24, 41, 36, 60], [15, 24, 21], [5, 9, 8, 14], [18, 12, 4],
		[10, 12, 16, 12, 8], [90, 66, 56], [36, 66], [30, 30, 40, 20],
	])
	assert_eq(t.hitstun(&"ultimate", &"u_moon_v"), 75, "Moonsplitter's waves")
	assert_eq(t.hitstun(&"ultimate", &"u_moon_h"), 75)
	assert_eq(t.hitstun(&"special"), 36, "any other kind counts as an ability")
	assert_eq(t.knockdown_frames(), 100)


func test_bare_hands_take_the_retuned_values_from_their_own_floor() -> void:
	var t: ProtectedTimings = ProtectedTimings.for_weapon(&"fists")
	assert_true(t.retuned)
	assert_eq(_row(t), [
		[18, 35, 36, 60], [15, 24, 21], [5, 9, 8, 14], [18, 12, 4],
		[10, 12, 16, 12, 8], [90, 66, 56], [36, 66], [30, 30, 40, 20],
	])
	assert_eq(t.hitstun(&"ultimate", &"f_breaker"), 54, "Breaker Palm")


func test_the_greatsword_and_the_daggers_keep_today_s() -> void:
	for w: StringName in [&"greatsword", &"daggers", &""]:
		var t: ProtectedTimings = ProtectedTimings.for_weapon(w)
		assert_false(t.retuned, "%s keeps today's" % w)
		assert_eq(_row(t), [
			[14, 26, 24, 40], [10, 16, 14], [4, 7, 6, 6], [12, 8, 4],
			[8, 10, 14, 10, 6], [70, 60, 50], [26, 60], [20, 30, 25, 15],
		], "%s's" % w)
		assert_eq(t.hitstun(&"ultimate", &"u_moon_v"), 40, "no move of its own")


func test_the_kept_timings_are_unchanged() -> void:
	assert_eq([Moves.KATANA.parry_window, Moves.FISTS.parry_window], [9, 8], "the parry and redirect windows")
	assert_eq(SimConst.INPUT_BUFFER, 8)
	assert_eq([SimConst.MOVE_DODGE_FRAMES, SimConst.MOVE_DODGE_I_FRAMES, SimConst.MOVE_DODGE_RECOVERY, SimConst.MOVE_DODGE_DIST], [16, 12, 9, 2.8], "the roll")
	assert_eq([SimConst.MOVE_BACKSTEP_FRAMES, SimConst.MOVE_BACKSTEP_I_FRAMES, SimConst.MOVE_BACKSTEP_RECOVERY, SimConst.MOVE_BACKSTEP_DIST], [14, 10, 9, 2.1], "the backstep")
	assert_eq([SimConst.PARRY_RECOIL, SimConst.PARRY_RECOIL_GUARD_AFTER, SimConst.PARRIER_RECOVERY], [26, 14, 7], "the parry recoil")
	assert_eq([SimConst.PARRY_SPAM_WINDOW, SimConst.PARRY_SPAM_PENALTY, SimConst.PARRY_MIN_WINDOW], [30, 3, 2], "the parry-spam shrink")
	assert_eq([ProtectedTimings.block_hitstop(5), ProtectedTimings.block_hitstop(9), ProtectedTimings.block_hitstop(4)], [3, 7, 3], "a block's hit-stop: the move's less 2, at least 3")
	# frozen with them (P35; milestone-1 task 103 built it): about a second
	assert_eq([SimConst.FINISHER_PROMPT_FRAMES, SimConst.FINISHER_PROMPT_SLOWMO], [18, 0.3], "the finisher prompt: 18 rules frames at 0.3x")


# ------------------------------------------------------------------ a move's own values

func test_today_s_stand_ins_keep_today_s_values() -> void:
	var cut: AttackDef = Moves.KATANA.moves[&"k_dl"]
	assert_false(cut.real_markers, "Wind Cut is a stand-in today")
	assert_eq([cut.hitstun, cut.blockstun, cut.hitstop], [14, 10, 4])
	# bare hands keep no stand-in on today's values: every attack is keyed
	# (tasks 89, 93, 94, 99 and 133) but Counter Lunge, on the retuned light
	# hitstun since task 22
	assert_eq([Moves.KATANA.moves[&"k_h2"].hitstun, Moves.KATANA.moves[&"k_h2"].hitstop], [26, 7])
	assert_same(ProtectedTimings.for_move(cut), ProtectedTimings.today())


func test_the_re_keyed_lights_take_the_retuned_values() -> void:
	# the light string, re-keyed (tasks 31 and 32)
	for id: StringName in [&"k_l1", &"k_l2", &"k_l3", &"k_l4"]:
		var cut: AttackDef = Moves.KATANA.moves[id]
		assert_true(cut.real_markers, "%s is on real markers" % id)
		assert_eq([cut.hitstun, cut.blockstun, cut.hitstop], [24, 15, 5], id)
		assert_same(ProtectedTimings.for_move(cut), ProtectedTimings.for_weapon(&"katana"), id)
	# bare hands' light string, re-keyed (task 89): Jab and Cross no longer
	# keep their own 16, so no hit of the string is guaranteed
	for id: StringName in [&"f_l1", &"f_l2", &"f_l3"]:
		var punch: AttackDef = Moves.FISTS.moves[id]
		assert_true(punch.real_markers, "%s is on real markers" % id)
		assert_eq([punch.hitstun, punch.blockstun, punch.hitstop], [18, 15, 5], id)
		assert_same(ProtectedTimings.for_move(punch), ProtectedTimings.for_weapon(&"fists"), id)


func test_the_counter_lunges_already_take_their_weapon_s_light_hitstun() -> void:
	# both have real markers since task 17 (P48: 23 and 17, a frame on here)
	assert_eq(Moves.KATANA.moves[&"k_lunge"].hitstun, 24)
	assert_eq(Moves.FISTS.moves[&"f_lunge"].hitstun, 18)


func test_the_hidden_weapons_moves_keep_today_s() -> void:
	assert_eq(Moves.DAGGERS.moves[&"d_l1"].hitstun, 10, "the Daggers' string keeps its 10")
	for w: WeaponDef in [Moves.GREATSWORD, Moves.DAGGERS]:
		for m: AttackDef in w.moves.values():
			assert_same(ProtectedTimings.for_move(m), ProtectedTimings.today(), "%s.%s" % [w.id, m.id])


func test_every_move_knows_its_weapon() -> void:
	for wid: StringName in Moves.WEAPONS:
		for m: AttackDef in Moves.WEAPONS[wid].moves.values():
			assert_eq(m.weapon, wid, "%s.%s" % [wid, m.id])
	assert_eq(Moves.ULT_HITS[&"u_moon_v"].weapon, &"katana", "Moonsplitter's waves are the Katana's")
	assert_eq(Moves.ULT_HITS[&"u_burst"].weapon, &"greatsword")
	assert_eq(Moves.ULT_HITS[&"u_tempest"].weapon, &"daggers")


## A made-up Katana or bare-hands move of `kind` on real markers, as its
## family's re-key leaves it, with no row in the table.
static func _re_keyed(kind: StringName, weapon: StringName = &"katana", extra: Dictionary = {}) -> AttackDef:
	var rec: Dictionary = {"id": &"t_cut", "name": "Test Cut", "kind": kind, "type": &"slash",
		"startup": 24, "active": 3, "recovery": 24, "damage": 5, "posture": 5, "real_markers": true}
	rec.merge(extra, true)
	return AttackDef.finalize_moves({&"t_cut": rec}, weapon)[&"t_cut"]


func test_a_re_keyed_move_takes_the_retuned_values_of_its_kind() -> void:
	var light: AttackDef = _re_keyed(&"light")
	assert_eq([light.hitstun, light.blockstun, light.hitstop], [24, 15, 5])
	var heavy: AttackDef = _re_keyed(&"heavy")
	assert_eq([heavy.hitstun, heavy.blockstun, heavy.hitstop], [41, 24, 9])
	var jab: AttackDef = _re_keyed(&"light", &"fists")
	assert_eq([jab.hitstun, jab.blockstun, jab.hitstop], [18, 15, 5])
	assert_eq(_re_keyed(&"heavy", &"fists").hitstun, 35)
	assert_eq(_re_keyed(&"ability").hitstun, 36)
	assert_same(ProtectedTimings.for_move(light), ProtectedTimings.for_weapon(&"katana"))
	var hidden: AttackDef = _re_keyed(&"light", &"greatsword")
	assert_eq(hidden.hitstun, 14, "a hidden weapon's move keeps today's, even on real markers")


func test_a_re_keyed_move_setting_its_own_protected_timing_is_refused() -> void:
	_re_keyed(&"light", &"katana", {"hitstun": 16})
	assert_push_error("t_cut sets hitstun")


# ------------------------------------------------------------------ in play: the outcome values

## A world of `w1` (fighter 0, the attacker) against `w2` (fighter 1), 2 m apart.
static func _world(w1: WeaponDef = Moves.KATANA, w2: WeaponDef = Moves.KATANA) -> World:
	return H.make_world(w1, w2, 2.0)


func test_a_parried_katana_move_takes_the_retuned_hit_stop() -> void:
	var W: World = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_l1"], &"parry", false)
	assert_eq(W.hitstop, 10)
	assert_eq([W.fighters[0].state, W.fighters[0].state_dur], [&"recoil", 26], "the parry recoil kept")


func test_the_parried_move_s_weapon_decides() -> void:
	var W: World = _world(Moves.GREATSWORD, Moves.KATANA)
	W.apply(W.fighters[0], W.fighters[1], Moves.GREATSWORD.moves[&"g_l1"], &"parry", false)
	assert_eq(W.hitstop, 8, "a Greatsword move parried by a Katana: today's")


func test_flash_and_redirect_stun_for_the_retuned_frames() -> void:
	var W: World = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_l1"], &"flash", false)
	assert_eq([W.fighters[0].state, W.fighters[0].state_dur, W.hitstop], [&"stunned", 66, 12])
	W = _world(Moves.KATANA, Moves.FISTS)
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_l1"], &"redirect", false)
	assert_eq([W.fighters[0].state, W.fighters[0].state_dur, W.hitstop], [&"stunned", 56, 12])
	W = _world(Moves.GREATSWORD, Moves.KATANA)
	W.apply(W.fighters[0], W.fighters[1], Moves.GREATSWORD.moves[&"g_l1"], &"flash", false)
	assert_eq([W.fighters[0].state_dur, W.hitstop], [60, 10], "a Greatsword move Flashed: today's")


func test_the_stomp_and_the_leap() -> void:
	var W: World = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_thrust"], &"stomp", false)
	assert_eq([W.fighters[0].state, W.fighters[0].state_dur, W.hitstop], [&"stunned", 90, 12])
	W = _world(Moves.GREATSWORD, Moves.KATANA)
	W.apply(W.fighters[0], W.fighters[1], Moves.GREATSWORD.moves[&"g_dh"], &"stomp", false)
	assert_eq([W.fighters[0].state_dur, W.hitstop], [70, 10], "a Greatsword thrust stomped: today's")
	W = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_sweep"], &"leap", false)
	assert_eq([W.fighters[0].state_dur, W.hitstop], [SimConst.LEAP_STUN, 8], "the leap's stun is not a protected timing")


func test_a_disarm_staggers_for_the_retuned_frames() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	a.posture = SimConst.POSTURE_MAX
	W.apply(a, W.fighters[1], Moves.KATANA.moves[&"k_l1"], &"parry", false)
	assert_false(a.armed)
	assert_eq([a.state, a.state_dur, W.hitstop], [&"disarmStagger", 36, 16])
	W = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_h2"], &"disarm", false)
	assert_eq([W.fighters[1].state, W.fighters[1].state_dur, W.hitstop], [&"disarmStagger", 36, 16], "a blocked power attack")
	W = _world(Moves.GREATSWORD, Moves.KATANA)
	W.apply(W.fighters[0], W.fighters[1], Moves.GREATSWORD.moves[&"g_h1"], &"disarm", false)
	assert_eq([W.fighters[1].state_dur, W.hitstop], [26, 14], "by a Greatsword: today's")


func test_a_disarmed_fighter_s_broken_posture_dazes_for_the_retuned_frames() -> void:
	var W: World = _world()
	var b: Fighter = W.fighters[1]
	b.armed = false
	b.posture = SimConst.POSTURE_MAX
	W.apply(W.fighters[0], b, Moves.KATANA.moves[&"k_l1"], &"hit", false)
	assert_eq([b.state, b.state_dur], [&"stagger", 66])
	W = _world(Moves.FISTS, Moves.KATANA)
	var a: Fighter = W.fighters[0]
	a.armed = false
	a.posture = SimConst.POSTURE_MAX
	W.apply(a, W.fighters[1], Moves.FISTS.moves[&"f_l1"], &"parry", false)
	assert_eq([a.state, a.state_dur], [&"stagger", 66], "a parried bare-hands move")


func test_a_katana_knockdown_takes_the_retuned_phases() -> void:
	var W: World = _world()
	var b: Fighter = W.fighters[1]
	W.apply(W.fighters[0], b, Moves.KATANA.moves[&"k_thrust"], &"hit", false)
	assert_eq([b.state, b.state_dur], [&"knockdown", 100])
	var phases: Array = []
	var downed_to: int = 0
	for sf: int in range(1, 101):
		b.sf = sf
		phases.append(b.knockdown_phase())
		if b.is_downed():
			downed_to = sf
	assert_eq([phases.count(&"fall"), phases.count(&"ground"), phases.count(&"standUp")], [30, 30, 40])
	assert_eq(downed_to, 80, "invulnerable to rise frame 20, then the 20-frame guard window")


func test_a_greatsword_knockdown_keeps_today_s_phases() -> void:
	var W: World = _world(Moves.GREATSWORD, Moves.KATANA)
	var b: Fighter = W.fighters[1]
	W.apply(W.fighters[0], b, Moves.GREATSWORD.moves[&"g_slam"], &"hit", false)
	assert_eq([b.state, b.state_dur], [&"knockdown", 75])
	b.sf = 60
	assert_true(b.is_downed(), "down to rise frame 10")
	b.sf = 61
	assert_false(b.is_downed())


# ------------------------------------------------------------------ in play: a move's own values

func test_a_stand_in_hit_and_block_keep_today_s() -> void:
	var W: World = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_dl"], &"hit", false)
	assert_eq([W.fighters[1].state_dur, W.hitstop], [14, 4])
	W = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_dl"], &"block", false)
	assert_eq([W.fighters[1].state_dur, W.hitstop], [10, 3])


func test_the_re_keyed_right_cut_hits_and_is_blocked_on_the_retuned_values() -> void:
	var W: World = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_l1"], &"hit", false)
	assert_eq([W.fighters[1].state_dur, W.hitstop], [24, 5])
	W = _world()
	W.apply(W.fighters[0], W.fighters[1], Moves.KATANA.moves[&"k_l1"], &"block", false)
	assert_eq([W.fighters[1].state_dur, W.hitstop], [15, 3])


func test_a_re_keyed_hit_block_and_charge_take_the_retuned_values() -> void:
	var W: World = _world()
	W.apply(W.fighters[0], W.fighters[1], _re_keyed(&"light"), &"hit", false)
	assert_eq([W.fighters[1].state, W.fighters[1].state_dur, W.hitstop], [&"hitstun", 24, 5])
	W = _world()
	W.apply(W.fighters[0], W.fighters[1], _re_keyed(&"light"), &"block", false)
	assert_eq([W.fighters[1].state, W.fighters[1].state_dur, W.hitstop], [&"blockstun", 15, 3])
	W = _world()
	W.apply(W.fighters[0], W.fighters[1], _re_keyed(&"heavy"), &"hit", false, World.HitCtx.make(0.5, false))
	assert_eq([W.fighters[1].state_dur, W.hitstop], [41 + 9, 9 + 2], "half the charge bonus: +18 and +4 halved")
	W = _world()
	W.apply(W.fighters[0], W.fighters[1], _re_keyed(&"heavy"), &"block", false, World.HitCtx.make(0.5, false))
	assert_eq(W.fighters[1].state_dur, 24 + 6, "and +12 of blockstun halved")


# ------------------------------------------------------------------ the free-frame rule

## A made-up move of `kind` with `startup`, one active frame and `hitstun`,
## branching to "t_next" `gap` frames after its active frame.
static func _pair_move(startup: int, hitstun: int, gap: int, kind: StringName = &"light") -> AttackDef:
	var m: AttackDef = AttackDef.new()
	m.id = &"t_first"
	m.kind = kind
	m.startup = startup
	m.active = 1
	m.recovery = 40
	m.hitstun = hitstun
	m.chain_light = &"t_next"
	m.branches = {&"t_next": PackedInt32Array([startup + 1 + gap, startup + 40])}
	return m


static func _follow(startup: int) -> AttackDef:
	var m: AttackDef = AttackDef.new()
	m.id = &"t_next"
	m.kind = &"light"
	m.startup = startup
	m.active = 1
	return m


func test_at_the_band_floors_the_retuned_hitstuns_leave_two_free_frames() -> void:
	var k: ProtectedTimings = ProtectedTimings.for_weapon(&"katana")
	var f: ProtectedTimings = ProtectedTimings.for_weapon(&"fists")
	# the Katana's light floor 24, bare hands' 18; a light branches 1 frame
	# after its active frames, a heavy 18 (the earliest branch points)
	assert_eq(FollowUpCheck.free_frames(_pair_move(24, k.hitstun(&"light"), 1), _follow(24)), 2, "Katana light into light")
	assert_eq(FollowUpCheck.free_frames(_pair_move(42, k.hitstun(&"heavy"), 18, &"heavy"), _follow(24)), 2, "Katana heavy into light")
	assert_eq(FollowUpCheck.free_frames(_pair_move(18, f.hitstun(&"light"), 1), _follow(18)), 2, "bare hands' light into light")
	assert_eq(FollowUpCheck.free_frames(_pair_move(33, f.hitstun(&"heavy"), 18, &"heavy"), _follow(18)), 2, "bare hands' heavy into light")


func test_the_game_s_held_pairs_keep_the_rule() -> void:
	# every pair with both moves off the waiting list: Right Cut into Return
	# Cut since task 31; each family's keying task brings its pairs in
	for w: WeaponDef in [Moves.KATANA, Moves.FISTS]:
		assert_eq(FollowUpCheck.weapon_problems(w), [] as Array[String], "%s's pairs" % w.id)


func test_a_held_pair_breaking_the_rule_fails() -> void:
	var w: WeaponDef = SF.without_swings(&"katana")
	var cut: AttackDef = w.moves[&"k_l1"]
	var held: Callable = func(id: StringName) -> bool: return id == &"k_l1" or id == &"k_l2"
	var kind: Callable = func(_id: StringName) -> StringName: return &"string_light"
	# Return Cut lands 28 frames after a hit on Right Cut's last active frame
	# (task 31: branching 2 frames after it, startup 25), 11 frames inside a
	# hitstun of 39
	cut.hitstun = 39
	var problems: Array[String] = FollowUpCheck.problems(w, held, kind)
	assert_eq(problems.size(), 1, str(problems))
	assert_string_contains(problems[0], "katana.k_l1 -> k_l2: the defender is free -11 frames")
	# a branch point on the last active frame
	cut.hitstun = 1
	cut.branches[&"k_l2"] = PackedInt32Array([cut.startup + cut.active, 40])
	problems = FollowUpCheck.problems(w, held, kind)
	assert_eq(problems.size(), 1, str(problems))
	assert_string_contains(problems[0], "branches 0 frames after its active frames (a string_light's earliest is 1)")
	# and nothing once the pair is fixed
	cut.branches[&"k_l2"] = PackedInt32Array([cut.startup + cut.active + 1, 40])
	assert_eq(FollowUpCheck.problems(w, held, kind), [] as Array[String])


## A light string run: fighter 0 with `w` plays `first` (pressed if it opens
## the string, else started as it is: a later pair measured from its own
## first move, not the string's opener), its follow-up
## `second` pressed as soon as it can be, at an idle defender of the same
## weapon 1.8 m away, which presses block only on step `press` (-1 for
## never). Gives the steps the hits landed on, the first step the defender
## was out of hitstun after the first hit, and the events.
static func _string_run(w: WeaponDef, first: StringName, second: StringName, press: int) -> Dictionary:
	var W: World = H.make_world(w, w, 1.8)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var def: AttackDef = w.moves[first]
	var follow_btn: int = Btn.LIGHT if def.chain_light == second else Btn.HEAVY
	var first_btn: int = Btn.HEAVY if def.kind == &"heavy" else Btn.LIGHT
	var direct: bool = first != (w.heavy_start if def.kind == &"heavy" else w.light_start)
	if direct:
		a.start_attack(first)
	var rec: H.Rec = H.Rec.new()
	var hits: Array[int] = []
	var free_step: int = -1
	var was_hit: bool = false
	for i: int in 160:
		var p0: RawInput = (H.idle() if direct else H.btn(first_btn)) if i == 0 else (H.btn(follow_btn) if i == def.startup + 1 else H.idle())
		W.step([p0, H.btn(Btn.BLOCK) if i == press else H.idle()])
		var before: int = rec.count(&"hit")
		rec.collect(W)
		if rec.count(&"hit") > before:
			hits.append(i)
		if b.state == &"hitstun":
			was_hit = true
		elif was_hit and free_step < 0:
			free_step = i
	return {"hits": hits, "free": free_step, "rec": rec}


## Whether, in a run of `first` into `second`, a defender hit by `first`
## and pressing block on its first free step parries `second`; and that it
## has at least the free steps FollowUpCheck counts (which count a hit on the
## last active frame, the latest it can land; a real one lands on its first
## touch, earlier).
func _defender_parries_the_next_hit(w: WeaponDef, first: StringName, second: StringName) -> void:
	var probe: Dictionary = _string_run(w, first, second, -1)
	var hits: Array[int] = probe["hits"]
	assert_eq(hits.size(), 2, "%s.%s and %s both land on an idle defender" % [w.id, first, second])
	if hits.size() < 2:
		return
	assert_gte(hits[1] - int(probe["free"]), FollowUpCheck.free_frames(w.moves[first], w.moves[second]), "%s -> %s: at least the free frames counted" % [first, second])
	var run: Dictionary = _string_run(w, first, second, int(probe["free"]))
	var rec: H.Rec = run["rec"]
	assert_eq([rec.count(&"hit"), rec.count(&"parry")], [1, 1], "%s -> %s: the next hit parried" % [first, second])


func test_a_defender_can_parry_the_next_hit_of_every_held_light_pair() -> void:
	var bands: MoveBands = MoveBands.shared()
	var table: FrameDataTable = FrameDataTable.shared()
	var pairs: int = 0
	for w: WeaponDef in [Moves.KATANA, Moves.FISTS]:
		for id: StringName in w.moves:
			var def: AttackDef = w.moves[id]
			var kind: StringName = StringName(table.row(w.id, id).get("kind", ""))
			if kind != &"string_light" or not bands.is_held(w.id, id, kind):
				continue
			var next: StringName = def.chain_light
			if next != &"" and bands.is_held(w.id, next, StringName(table.row(w.id, next).get("kind", ""))):
				_defender_parries_the_next_hit(w, id, next)
				pairs += 1
	# each keying task brings its pairs in: the Katana's whole string since
	# task 32 (Right Cut into Return Cut into Kesa Cut into Crown Cut)
	assert_gte(pairs, 3, "the light string's three pairs are held")


func test_a_made_up_pair_at_the_floors_can_be_parried_with_two_frames_to_spare() -> void:
	# Right Cut and Return Cut at the light floor (24), hitting on their one
	# active frame, Return Cut branching a frame after Right Cut's, with the
	# retuned hitstun: the run's free steps are FollowUpCheck's 2
	var w: WeaponDef = SF.without_swings(&"katana")
	for id: StringName in [&"k_l1", &"k_l2"]:
		var m: AttackDef = w.moves[id]
		m.startup = 24
		m.active = 1
		m.recovery = 24
		m.real_markers = true
		m.lunge = 0.0
		m.hitstun = ProtectedTimings.for_move(m).hitstun(m.kind)
	w.moves[&"k_l1"].branches[&"k_l2"] = PackedInt32Array([26, 49])
	assert_eq(FollowUpCheck.free_frames(w.moves[&"k_l1"], w.moves[&"k_l2"]), 2)
	_defender_parries_the_next_hit(w, &"k_l1", &"k_l2")
