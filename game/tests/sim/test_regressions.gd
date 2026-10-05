extends GutTest
## Port of tests/regressions.test.ts.
##
## Regression tests for bugs found in the independent code review.
##
## Port note: "never crashes" (TS: not.toThrow) means the run finishes and GUT
## records no script or engine error, which fails the test on its own.

const H := preload("res://tests/sim/sim_helpers.gd")
## toBeCloseTo's default precision (2 digits)
const CLOSE: float = 0.005

## helpers.ts idle as an input function: run() treats a null Callable as idle
var IDLE: Callable = Callable()


## The custom recorder in the Moonsplitter test: notes whether an ultWave event
## has been seen yet.
class WaveRec extends SimHelpers.Rec:
	var waved: bool = false

	func collect(W: World) -> void:
		var ev: Array[Dictionary] = W.drain_events()
		if ev.any(func(e: Dictionary) -> bool: return e["t"] == &"ultWave"):
			waved = true
		events.append_array(ev)


func after_each() -> void:
	H.dispose_all()


func test_changing_a_fighters_weapon_mid_combo_never_crashes() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	var p0: Callable = func(i: int) -> RawInput:
		if i == 6:
			a.weapon = Moves.GREATSWORD
			a.abilities = Moves.GREATSWORD.default_abilities.duplicate()
		return H.btn(Btn.LIGHT) if i % 5 == 0 else H.idle()
	H.run(W, 120, p0, IDLE)
	pass_test("120 steps ran without an error")


func test_a_move_from_a_weapon_you_no_longer_hold_is_refused_instead_of_crashing() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	a.armed = false
	assert_false(a.start_attack(&"k_l2"))
	a.armed = true
	assert_true(a.start_attack(&"f_breaker")) # bare-hand moves always resolve


func test_parrying_a_bare_handed_attacker_at_full_posture_dazes_them_instead_of_disarming_again() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 1.5)
	var r: H.Rec = H.Rec.new()
	var a: Fighter = W.fighters[0]
	a.armed = false
	var p0: Callable = func(i: int) -> RawInput:
		if i <= 6:
			a.posture = SimConst.POSTURE_MAX
			a.last_posture_damage = W.frame
		return H.btn(Btn.LIGHT) if i == 0 else H.idle()
	# jab (startup 5) connects on frame 7; block pressed on frame 3
	H.run(W, 14, p0, func(i: int) -> RawInput: return H.btn(Btn.BLOCK) if i == 2 else H.idle(), r)
	assert_true(r.has(&"parry"))
	assert_false(r.has(&"disarm"))
	assert_true(r.has(&"stagger"))
	assert_eq(a.state, &"stagger")
	assert_lte(a.posture, SimConst.DISARMED_STAGGER_RESET + 1e-6)
	assert_null(W.weapon_of(0))


func test_a_trade_between_two_charged_heavies_is_fair_both_take_the_same_damage() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.2)
	var r: H.Rec = H.Rec.new()
	var hold: Callable = func(i: int) -> RawInput: return H.btn(Btn.HEAVY) if i < 60 else H.idle()
	H.run(W, 140, hold, hold, r)
	var hits: Array[Dictionary] = r.all(&"hit")
	assert_eq(hits.size(), 2)
	assert_gt(hits[0]["damage"], 13.0) # the charge counted for both
	assert_almost_eq(hits[0]["damage"], hits[1]["damage"], CLOSE)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	assert_almost_eq(a.hp, b.hp, CLOSE)


func test_one_block_press_parries_one_hit_not_a_whole_flurry() -> void:
	# find when the first Lightning Tempest spin lands on an idle greatsword
	var probe: World = H.make_world(Moves.DAGGERS, Moves.GREATSWORD, 7.0)
	probe.fighters[0].hp = 20.0
	var first_hit: int = -1
	var i: int = 0
	while i < 140 and first_hit < 0:
		probe.step([H.btn(Btn.ULTIMATE) if i == 0 else H.idle(), H.idle()])
		if probe.drain_events().any(func(e: Dictionary) -> bool: return e["t"] == &"hit"):
			first_hit = probe.frame
		i += 1
	assert_gt(first_hit, 0)

	# one press a frame early: the next spin (10 frames later) would still be
	# inside the greatsword's 12-frame window if the press weren't used up
	var W: World = H.make_world(Moves.DAGGERS, Moves.GREATSWORD, 7.0)
	W.fighters[0].hp = 20.0
	var r: H.Rec = H.Rec.new()
	H.run(
		W,
		140,
		func(j: int) -> RawInput: return H.btn(Btn.ULTIMATE) if j == 0 else H.idle(),
		func(j: int) -> RawInput: return H.btn(Btn.BLOCK) if j == first_hit - 2 else H.idle(),
		r,
	)
	assert_eq(r.count(&"parry"), 1)


func test_a_moonsplitter_wave_still_in_flight_when_the_round_ends_does_no_damage() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var r: WaveRec = WaveRec.new()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	a.hp = 20.0
	var p0: Callable = func(i: int) -> RawInput:
		if r.waved and a.hp > 0.0:
			a.hp = 0.0 # the caster is knocked out while the wave travels
		return H.btn(Btn.ULTIMATE) if i == 0 else H.idle()
	H.run(W, 90, p0, IDLE, r)
	assert_true(r.waved)
	assert_eq(r.count(&"ko"), 1)
	assert_eq(b.hp, 100.0)
