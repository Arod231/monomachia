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
	H.run(W, 90, func(i: int) -> RawInput: return H.btn(Btn.ULTIMATE) if i == 0 else H.idle(), IDLE, r)
	assert_eq(r.find(&"ultWave").get("kind"), &"vertical")
	assert_almost_eq(W.fighters[1].hp, 70.0, CLOSE)


func test_ultimates_moonsplitter_horizontal_can_be_jumped_over() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var r: H.Rec = H.Rec.new()
	W.fighters[0].hp = 20.0
	# tilt sideways while sheathed; defender jumps as the wave approaches
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.ULTIMATE) if i == 0 else (H.move(1.0, 0.0) if i < 40 else H.idle())
	H.run(W, 100, p0, func(i: int) -> RawInput: return H.btn(Btn.JUMP) if i == 62 else H.idle(), r)
	assert_eq(r.find(&"ultWave").get("kind"), &"horizontal")
	assert_eq(W.fighters[1].hp, 100.0)


## Story 64: the vertical wave is avoided by stepping aside out of its lane
## as it comes (a sideways dodge: the wave is undodgeable, so the step does
## it, not the dodge's invulnerability); the horizontal one isn't (only a
## jump clears it).
func test_moonsplitter_s_vertical_wave_is_avoided_by_stepping_aside_the_horizontal_is_not() -> void:
	for variant: StringName in [&"vertical", &"horizontal"]:
		var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 8.0)
		W.fighters[0].hp = 20.0
		var r: H.Rec = H.Rec.new()
		var p0: Callable = func(i: int) -> RawInput:
			if i == 0:
				return H.btn(Btn.ULTIMATE)
			return H.move(1.0, 0.0) if variant == &"horizontal" and i < 40 else H.idle()
		var p1: Callable = func(i: int) -> RawInput: return H.move(1.0, 0.0, Btn.DODGE) if i == 61 else H.idle()
		H.run(W, 100, p0, p1, r)
		assert_eq(r.find(&"ultWave").get("kind"), variant)
		if variant == &"vertical":
			assert_eq(W.fighters[1].hp, 100.0, "stepped out of the vertical wave's lane")
		else:
			assert_almost_eq(W.fighters[1].hp, 70.0, CLOSE, "the horizontal wave spans the stage")


func test_moonsplitter_sends_its_wave_60_frames_in_and_frees_the_fighter_42_after() -> void:
	# milestone-1 task 98 (the owner's choice): 60 frames to the wave, 42
	# after it, inside the Katana's ultimate band (54-66, 36-48)
	assert_eq(SimConst.MOONSPLITTER_WAVE, 60)
	assert_eq(SimConst.MOONSPLITTER_RECOVERY, 42)
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 20.0)
	var a: Fighter = W.fighters[0]
	a.hp = 20.0
	var free_at: Array[int] = [-1]
	var frozen: Array[int] = [0]
	var at: Dictionary = {&"ultStart": -1, &"ultWave": -1}
	for i: int in 160:
		# the wave's hit-stop holds the fighter's recovery too: count it apart
		if int(at[&"ultWave"]) >= 0 and free_at[0] < 0 and W.hitstop > 0:
			frozen[0] += 1
		W.step([H.btn(Btn.ULTIMATE) if i == 0 else H.idle(), H.idle()])
		for e: Dictionary in W.drain_events():
			if at.has(e["t"]) and int(at[e["t"]]) < 0:
				at[e["t"]] = i
		if free_at[0] < 0 and int(at[&"ultStart"]) >= 0 and a.state == &"free":
			free_at[0] = i
	assert_gt(int(at[&"ultStart"]), -1, "it starts")
	assert_eq(int(at[&"ultWave"]) - int(at[&"ultStart"]), 60, "the wave leaves 60 frames after the start")
	assert_eq(free_at[0] - int(at[&"ultWave"]) - frozen[0], 42, "the fighter is free 42 frames after the wave, its hit-stop aside")


func test_moonsplitter_s_pick_locks_when_the_draw_starts() -> void:
	# the draw starts 46 frames in (the stance's end); a tilt after it
	# changes nothing, a tilt before it picks
	assert_eq(SimConst.MOONSPLITTER_DRAW, 46)
	for case: Array in [[30, 45, &"horizontal"], [47, 70, &"vertical"]]:
		var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 20.0)
		W.fighters[0].hp = 20.0
		var r: H.Rec = H.Rec.new()
		var from: int = case[0]
		var to: int = case[1]
		var p0: Callable = func(i: int) -> RawInput:
			if i == 0:
				return H.btn(Btn.ULTIMATE)
			return H.move(1.0, 0.0) if i >= from and i <= to else H.idle()
		H.run(W, 80, p0, IDLE, r)
		assert_eq(r.find(&"ultWave").get("kind"), case[2], "tilted sideways on steps %d-%d" % [from, to])


func test_moonsplitter_s_waves_take_the_retuned_hitstun_and_hit_stop() -> void:
	# a re-keyed move takes the frozen protected timings (task 22's retune)
	for id: StringName in [&"u_moon_v", &"u_moon_h"]:
		var m: AttackDef = Moves.ULT_HITS[id]
		assert_eq(m.hitstun, 75, "%s's hitstun" % id)
		assert_eq(m.hitstop, 14, "%s's hit-stop" % id)


func test_moonsplitter_s_timing_lands_in_the_katana_s_ultimate_band() -> void:
	var bands: MoveBands = MoveBands.read()
	var row: Dictionary = {"kind": "ultimate", "to_wave": SimConst.MOONSPLITTER_WAVE, "recovery": SimConst.MOONSPLITTER_RECOVERY}
	assert_eq(bands.timing_problems(&"katana", &"moonsplitter", row), [] as Array[String])


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


func test_breaker_palm_is_re_keyed_led_by_its_clip_s_travel_with_the_retuned_hitstun_and_hit_stop() -> void:
	# task 99: 36 / 4 / 36 off its clip's markers, the rules' lunge retired
	var m: AttackDef = Moves.FISTS.moves[&"f_breaker"]
	assert_eq([m.startup, m.active, m.recovery], [36, 4, 36])
	assert_true(m.by_travel, "moved by its clip's travel")
	assert_eq(m.lunge_from(4.1), 0.0, "no lunge")
	assert_eq(m.hitstun, 54)
	assert_eq(m.hitstop, 14)
	var forward: float = 0.0
	for f: int in m.startup + m.active + 1:
		var t: PackedFloat64Array = m.travel_at(f)
		if not t.is_empty():
			forward += t[0]
	assert_between(forward, 3.0, 3.6, "a surging step of about 3 m by the end of its active frames")


func test_breaker_palm_surges_on_its_travel_touching_from_4_1_m_and_missing_from_4_6_m() -> void:
	for d: float in [4.1, 4.6]:
		var W: World = H.make_world(Moves.KATANA, Moves.KATANA, d)
		var a: Fighter = W.fighters[0]
		var b: Fighter = W.fighters[1]
		a.hp = 20.0
		a.armed = false
		var from: V3 = V3.make(a.pos.x, a.pos.y, a.pos.z)
		var r: H.Rec = H.Rec.new()
		var p0: Callable = func(i: int) -> RawInput:
			return H.btn(Btn.ULTIMATE) if i == 0 else (H.btn(Btn.HEAVY) if i == 10 else H.idle())
		H.run(W, 120, p0, IDLE, r)
		var hit: Dictionary = r.find(&"hit")
		if d < 4.5:
			assert_eq(hit.get("attack"), &"f_breaker", "touches from %.1f m" % d)
			assert_lt(b.hp, 100.0, "it lands")
		else:
			assert_true(hit.is_empty(), "misses from %.1f m" % d)
			assert_gt(SimMath.dist2(a.pos, from), 3.0, "the surge carried it on")
		H.dispose_all()
