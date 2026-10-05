extends GutTest
## Port of tests/ultimate.test.ts.

const H := preload("res://tests/sim/sim_helpers.gd")
## toBeCloseTo's default precision (2 digits)
const CLOSE: float = 0.005

## helpers.ts idle as an input function: run() treats a null Callable as idle
var IDLE: Callable = Callable()


func after_each() -> void:
	H.dispose_all()


func test_ultimates_are_locked_above_25_percent_hp() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(W, 5, func(i: int) -> RawInput: return H.btn(Btn.LIGHT, Btn.HEAVY) if i == 0 else H.idle(), IDLE, r)
	assert_false(r.has(&"ultStart"))


func test_ultimates_unlock_at_25_percent_hp_fire_on_light_heavy_and_only_once_per_round() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 3.0)
	var r: H.Rec = H.Rec.new()
	var a: Fighter = W.fighters[0]
	a.hp = 25.0
	H.run(W, 3, IDLE, IDLE, r)
	assert_true(r.has(&"ultReady"))
	H.run(W, 100, func(i: int) -> RawInput: return H.btn(Btn.LIGHT, Btn.HEAVY) if i == 0 else H.idle(), IDLE, r)
	assert_eq(r.count(&"ultStart"), 1)
	var r2: H.Rec = H.Rec.new()
	H.run(W, 100, func(i: int) -> RawInput: return H.btn(Btn.LIGHT, Btn.HEAVY) if i == 0 else H.idle(), IDLE, r2)
	assert_false(r2.has(&"ultStart"))


func test_ultimates_light_pressed_a_frame_before_heavy_still_counts_as_the_chord() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 3.0)
	var r: H.Rec = H.Rec.new()
	W.fighters[0].hp = 20.0
	H.run(
		W,
		10,
		func(i: int) -> RawInput: return H.btn(Btn.LIGHT) if i == 0 else (H.btn(Btn.HEAVY) if i == 2 else H.idle()),
		IDLE,
		r,
	)
	assert_true(r.has(&"ultStart"))


func test_ultimates_moonsplitter_vertical_crosses_the_stage_and_hits() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var r: H.Rec = H.Rec.new()
	W.fighters[0].hp = 20.0
	H.run(W, 70, func(i: int) -> RawInput: return H.btn(Btn.ULTIMATE) if i == 0 else H.idle(), IDLE, r)
	assert_eq(r.find(&"ultWave").get("kind"), &"vertical")
	assert_almost_eq(W.fighters[1].hp, 70.0, CLOSE)


func test_ultimates_moonsplitter_horizontal_can_be_jumped_over() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var r: H.Rec = H.Rec.new()
	W.fighters[0].hp = 20.0
	# tilt sideways while sheathed; defender jumps as the wave approaches
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.ULTIMATE) if i == 0 else (H.move(1.0, 0.0) if i < 30 else H.idle())
	H.run(W, 70, p0, func(i: int) -> RawInput: return H.btn(Btn.JUMP) if i == 38 else H.idle(), r)
	assert_eq(r.find(&"ultWave").get("kind"), &"horizontal")
	assert_eq(W.fighters[1].hp, 100.0)


func test_ultimates_impaler_dashes_impales_and_bursts_on_heavy() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 6.0)
	var r: H.Rec = H.Rec.new()
	W.fighters[0].hp = 20.0
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.ULTIMATE) if i == 0 else (H.btn(Btn.HEAVY) if i >= 50 and i % 3 == 0 else H.idle())
	H.run(W, 140, p0, IDLE, r)
	assert_true(r.has(&"ultImpale"))
	assert_true(r.has(&"ultBurst"))
	assert_almost_eq(W.fighters[1].hp, 65.0, CLOSE)


func test_ultimates_lightning_tempest_lands_six_spins_and_a_finisher() -> void:
	var W: World = H.make_world(Moves.DAGGERS, Moves.KATANA, 7.0)
	var r: H.Rec = H.Rec.new()
	W.fighters[0].hp = 20.0
	H.run(W, 140, func(i: int) -> RawInput: return H.btn(Btn.ULTIMATE) if i == 0 else H.idle(), IDLE, r)
	var hits: Array[Dictionary] = r.all(&"hit")
	assert_eq(hits.size(), 7)
	assert_almost_eq(W.fighters[1].hp, 100.0 - 6.0 * 5.0 - 8.0, CLOSE)


func test_ultimates_disarmed_the_ultimate_offers_recall_which_re_arms() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 4.0)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	a.hp = 20.0
	a.posture = 100.0
	a.disarm(b, &"parried")
	H.run(W, 60)
	var r: H.Rec = H.Rec.new()
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.ULTIMATE) if i == 0 else (H.btn(Btn.LIGHT) if i == 10 else H.idle())
	H.run(W, 80, p0, IDLE, r)
	assert_true(r.has(&"ultChoice"))
	assert_true(r.has(&"recall"))
	assert_true(a.armed)
	assert_null(W.weapon_of(0))


func test_ultimates_disarmed_choosing_heavy_throws_the_breaker_palm_posture_blow() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 1.8)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	a.hp = 20.0
	a.armed = false
	var r: H.Rec = H.Rec.new()
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.ULTIMATE) if i == 0 else (H.btn(Btn.HEAVY) if i == 10 else H.idle())
	H.run(W, 80, p0, IDLE, r)
	var hit: Dictionary = r.find(&"hit")
	assert_eq(hit.get("attack"), &"f_breaker")
	assert_almost_eq(b.posture, minf(100.0, 50.0 * SimConst.HIT_POSTURE_MULT), CLOSE)
