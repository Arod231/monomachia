extends GutTest
## The grip (KE task 5): a fighter holds its weapon one-handed or two-handed,
## switches at once with the grip button in the states that act, and its
## string advances by count in whichever grip it holds, so strings mix. The
## Katana's two strings stand in as today's four lights, Crown Cut repeated as
## hit 5, until the re-keys; a test Katana with a different two-handed string
## shows the count carrying across a switch. Expected numbers are the spec's
## (D2, D4, D7) and the plan's.

const H := preload("res://tests/sim/sim_helpers.gd")
const CLOSE: float = 0.005

const ONE: StringName = WeaponGrip.ONE_HANDED
const TWO: StringName = WeaponGrip.TWO_HANDED

## Today's four lights, Crown Cut repeated as hit 5: the two-handed grip's
## stand-in string (the plan's Notes) until KE task 13 keys its own.
const STAND_IN: Array[StringName] = [&"k_l1", &"k_l2", &"k_l3", &"k_l4", &"k_l4"]
## The one-handed string: its own hits 1 and 2 (KE task 11), the stand-ins
## after until KE task 12.
const ONE_STRING: Array[StringName] = [&"k_1l1", &"k_1l2", &"k_l3", &"k_l4", &"k_l4"]
## A two-handed string unlike the one-handed one, to tell the grips apart.
const TEST_TWO: Array[StringName] = [&"k_l4", &"k_l3", &"k_l1", &"k_l2", &"k_l3"]


# rounds start in the first grip, one-handed: these tests begin there
func before_each() -> void:
	H.grip = &""


func after_each() -> void:
	H.dispose_all()


## The Katana with TEST_TWO as its two-handed string.
static func _test_katana() -> WeaponDef:
	var w: WeaponDef = KatanaMoves.build()
	var grips: Array[WeaponGrip] = [
		WeaponGrip.make(ONE, STAND_IN, w.grips[0].block_mitigation, w.grips[0].heavy, w.grips[0].draw_heavy),
		WeaponGrip.make(TWO, TEST_TWO, w.grips[1].block_mitigation, w.grips[1].heavy, w.grips[1].draw_heavy),
	]
	w.grips = grips
	return w


## The input `base` gives with the grip button pressed too.
static func _with_grip(base: RawInput) -> RawInput:
	return RawInput.make(base.mx, base.my, base.buttons | Btn.bit(Btn.GRIP))


## Steps W with fighter 0 on `p0` (step index -> RawInput) and fighter 1 on
## `p1` until fighter 0 is in state `s` (at most `limit` steps). Returns the
## steps taken, or -1 if it never got there.
static func _until(W: World, s: StringName, p0: Callable, p1: Callable = Callable(), limit: int = 120) -> int:
	for i: int in limit:
		if W.fighters[0].state == s:
			return i
		W.step([p0.call(i), H.idle() if p1.is_null() else p1.call(i)])
	return limit if W.fighters[0].state == s else -1


## Fighter 0 plays a string of lights, each pressed the step after the
## attack before it swings, pressing the grip button too with the light at
## each index in `switch_at`. Returns the moves that swung, in order.
static func _string(W: World, lights: int, switch_at: Array[int] = []) -> Array[StringName]:
	var r: H.Rec = H.Rec.new()
	var pressed: int = 0
	var due: bool = true
	for i: int in 400:
		var p0: RawInput = H.idle()
		if due and pressed < lights:
			p0 = H.btn(Btn.LIGHT)
			if switch_at.has(pressed):
				p0 = _with_grip(p0)
			pressed += 1
			due = false
		W.step([p0, H.idle()])
		for e: Dictionary in W.drain_events():
			r.events.append(e)
			if e["t"] == &"swing" and e["f"] == 0:
				due = true
	var out: Array[StringName] = []
	for e: Dictionary in r.all(&"swing"):
		if e["f"] == 0:
			out.append(e["attack"])
	return out


# ------------------------------------------------------------------ the grips declared

func test_the_katana_declares_two_grips_with_their_strings() -> void:
	var w: WeaponDef = Moves.KATANA
	assert_eq(w.grips.size(), 2)
	assert_eq([w.grips[0].id, w.grips[1].id], [ONE, TWO], "one-handed first: rounds start in it")
	assert_eq(w.grips[0].string, ONE_STRING, "one-handed: Slanting Cut and Backhand Rise, then today's lights, Crown Cut again as hit 5")
	assert_eq(w.grips[1].string, STAND_IN, "two-handed: today's lights, Crown Cut again as hit 5")
	assert_almost_eq(w.grips[0].block_mitigation, 0.7, CLOSE, "D2: one-handed")
	assert_almost_eq(w.grips[1].block_mitigation, 0.5, CLOSE, "D2: two-handed")


func test_the_other_weapons_have_no_grips() -> void:
	for id: StringName in [&"greatsword", &"daggers", &"fists"]:
		assert_true((Moves.WEAPONS[id] as WeaponDef).grips.is_empty(), "%s keeps one implicit grip" % id)


# ------------------------------------------------------------------ switching

func test_a_round_starts_one_handed() -> void:
	var W: World = H.make_world()
	assert_eq(W.fighters[0].grip, ONE, "a new fighter")
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(W.fighters[0].grip, TWO)
	W.reset_round()
	assert_eq(W.fighters[0].grip, ONE, "the next round")


func test_the_grip_button_switches_at_once_both_ways_and_says_so() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(a.grip, TWO, "one press, the same step")
	var e: Array = W.drain_events().filter(func(x: Dictionary) -> bool: return x["t"] == &"grip")
	assert_eq(e.size(), 1, "a grip event")
	if e.size() == 1:
		assert_eq([e[0]["f"], e[0]["grip"]], [0, TWO])
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(a.grip, TWO, "held, it doesn't switch again")
	W.step([H.idle(), H.idle()])
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(a.grip, ONE, "pressed again, back")


func test_switching_works_standing_moving_and_blocking() -> void:
	var cases: Dictionary = {
		&"free": func(_i: int) -> RawInput: return H.idle(),
		&"step": func(_i: int) -> RawInput: return H.move(1.0, 0.0),
		&"blocking": func(_i: int) -> RawInput: return H.btn(Btn.BLOCK),
	}
	for name: StringName in cases:
		var W: World = H.make_world()
		var a: Fighter = W.fighters[0]
		var p0: Callable = cases[name]
		W.step([p0.call(0), H.idle()])
		var before: StringName = a.state
		W.step([_with_grip(p0.call(1)), H.idle()])
		assert_eq(a.grip, TWO, "%s: switched" % name)
		assert_eq(a.state, before, "%s: still %s" % [name, before])
		if name == &"blocking":
			assert_true(a.blocking, "still blocking")


func test_switching_mid_attack_keeps_the_move_playing() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	H.run(W, 10, H.tap_at(0, Btn.LIGHT))
	assert_eq(a.state, &"attack")
	var frame: int = a.atk.frame
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(a.grip, TWO)
	assert_eq([a.state, a.atk.def.id, a.atk.frame], [&"attack", &"k_1l1", frame + 1], "Slanting Cut plays on")


func test_switching_works_in_the_iai_stance() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	H.run(W, 30, func(_i: int) -> RawInput: return H.btn(Btn.HEAVY))
	assert_true(a.in_stance(), "sheathed in the stance")
	W.step([_with_grip(H.btn(Btn.HEAVY)), H.idle()])
	assert_eq(a.grip, TWO)
	assert_true(a.in_stance(), "still in the stance")


func test_switching_works_landing_and_in_the_parry_s_follow_through() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	assert_ne(_until(W, &"land", H.tap_at(0, Btn.JUMP)), -1, "lands")
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(a.grip, TWO, "landing")
	# fighter 1 lights; fighter 0 parries it a few frames before it lands
	var P: World = H.make_world()
	var d: Fighter = P.fighters[0]
	var reached: int = _until(P, &"parryAnim", H.tap_at(H.LIGHT_LANDS - 4, Btn.BLOCK), H.tap_at(0, Btn.LIGHT))
	assert_ne(reached, -1, "parries")
	assert_gt(P.hitstop, 0, "the parry's hit-stop")
	# pressed in the hit-stop, the switch comes as the step resumes
	P.step([_with_grip(H.idle()), H.idle()])
	while P.hitstop > 0:
		P.step([H.idle(), H.idle()])
	P.step([H.idle(), H.idle()])
	assert_eq(d.state, &"parryAnim", "still following through")
	assert_eq(d.grip, TWO, "in the parry's follow-through")


func test_switching_is_refused_where_the_fighter_can_t_act_and_isn_t_buffered() -> void:
	var setups: Dictionary = {
		&"hitstun": func(f: Fighter) -> void: f.enter_hitstun(40),
		&"blockstun": func(f: Fighter) -> void: f.set_state(&"blockstun", 40),
		&"knockdown": func(f: Fighter) -> void: f.enter_knockdown(),
		&"recoil": func(f: Fighter) -> void: f.enter_recoil(40, 30),
		&"stunned": func(f: Fighter) -> void: f.enter_stun(40),
		&"stagger": func(f: Fighter) -> void: f.enter_stun(40, &"stagger"),
		&"intro": func(f: Fighter) -> void: f.set_state(&"intro"),
		&"victory": func(f: Fighter) -> void: f.set_state(&"victory"),
	}
	for name: StringName in setups:
		var W: World = H.make_world()
		var a: Fighter = W.fighters[0]
		(setups[name] as Callable).call(a)
		W.step([_with_grip(H.idle()), H.idle()])
		assert_eq(a.grip, ONE, "%s: refused" % name)
		assert_false(W.drain_events().any(func(e: Dictionary) -> bool: return e["t"] == &"grip"), "%s: no grip event" % name)
		if name == &"intro" or name == &"victory":
			continue
		H.run(W, 220)
		assert_eq(a.state, &"free", "%s: free again" % name)
		assert_eq(a.grip, ONE, "%s: the press wasn't kept for later" % name)


func test_switching_is_refused_jumping_and_dodging() -> void:
	var starts: Dictionary = {
		&"jump": H.btn(Btn.JUMP),
		&"dodge": H.move(1.0, 0.0, Btn.DODGE),
		&"backstep": H.btn(Btn.DODGE),
	}
	for name: StringName in starts:
		var W: World = H.make_world()
		var a: Fighter = W.fighters[0]
		W.step([starts[name], H.idle()])
		W.step([H.idle(), H.idle()])
		assert_eq(a.state, name, "%s under way" % name)
		W.step([_with_grip(H.idle()), H.idle()])
		assert_eq(a.grip, ONE, "%s: refused" % name)
		H.run(W, 90)
		assert_eq(a.grip, ONE, "%s: not kept for later" % name)


func test_a_weapon_without_grips_ignores_the_button() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA)
	var a: Fighter = W.fighters[0]
	assert_eq(a.grip, &"", "no grip")
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(a.grip, &"")
	assert_false(W.drain_events().any(func(e: Dictionary) -> bool: return e["t"] == &"grip"))


# ------------------------------------------------------------------ the strings

func test_both_grips_play_five_lights_and_the_string_ends_after_hit_5() -> void:
	for grip: StringName in [ONE, TWO]:
		var W: World = H.make_world()
		if grip == TWO:
			W.step([_with_grip(H.idle()), H.idle()])
		assert_eq(_string(W, 6), ONE_STRING if grip == ONE else STAND_IN, "%s: five hits, and a sixth light starts nothing (D4)" % grip)
		assert_eq(W.fighters[0].state, &"free", "%s: free after the last hit" % grip)


func test_hit_5_ends_on_its_own_length() -> void:
	var crown: AttackDef = Moves.KATANA.moves[&"k_l4"]
	var V: World = H.make_world()
	var b: Fighter = V.fighters[0]
	var seen: int = 0
	var last_frame: int = -1
	var pressed: int = 0
	var due: bool = true
	for i: int in 400:
		var p0: RawInput = H.idle()
		if due and pressed < 6:
			p0 = H.btn(Btn.LIGHT)
			pressed += 1
			due = false
		V.step([p0, H.idle()])
		for e: Dictionary in V.drain_events():
			if e["t"] == &"swing" and e["f"] == 0:
				due = true
				seen += 1
		if seen == 5 and b.state == &"attack":
			last_frame = b.atk.frame
	assert_eq(last_frame, crown.total_frames() - 1, "hit 5 runs to its last frame, the step before it ends")


func test_a_mixed_string_carries_the_count_across_switches() -> void:
	var W: World = H.make_world(_test_katana(), Moves.KATANA)
	# one-handed 1 and 2, switch: two-handed 3 and 4, switch back: one-handed 5
	var swung: Array[StringName] = _string(W, 6, [2, 4])
	assert_eq(swung, [&"k_l1", &"k_l2", TEST_TWO[2], TEST_TWO[3], STAND_IN[4]] as Array[StringName])


func test_a_light_from_neutral_starts_the_grip_s_hit_1() -> void:
	var W: World = H.make_world(_test_katana(), Moves.KATANA)
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(_string(W, 2), [TEST_TWO[0], TEST_TWO[1]] as Array[StringName], "two-handed from neutral")


func test_a_heavy_branch_ends_the_count() -> void:
	# L, H (the one-handed heavy, Crescent Coil), then L from neutral starts hit 1 again
	var W: World = H.make_world(_test_katana(), Moves.KATANA)
	var r: H.Rec = H.Rec.new()
	var presses: Array[int] = [Btn.LIGHT, Btn.HEAVY, Btn.LIGHT]
	var pressed: int = 0
	var due: bool = true
	var swung: Array[StringName] = []
	for i: int in 400:
		var p0: RawInput = H.idle()
		if due and pressed < presses.size() and (pressed < 2 or W.fighters[0].state == &"free"):
			p0 = H.btn(presses[pressed])
			pressed += 1
			due = false
		W.step([p0, H.idle()])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"swing" and e["f"] == 0:
				due = true
				swung.append(e["attack"])
	assert_eq(swung, [&"k_l1", &"k_coil", &"k_l1"] as Array[StringName])


# ------------------------------------------------------------------ guarding

func test_a_two_handed_block_takes_less_posture() -> void:
	var takes: Dictionary = {}
	for grip: StringName in [ONE, TWO]:
		var W: World = H.make_world()
		var r: H.Rec = H.Rec.new()
		var p1: Callable = func(i: int) -> RawInput:
			return _with_grip(H.btn(Btn.BLOCK)) if i == 0 and grip == TWO else H.btn(Btn.BLOCK)
		H.run(W, 60, H.tap_at(1, Btn.LIGHT), p1, r)
		assert_true(r.has(&"block"), "%s: blocked" % grip)
		takes[grip] = W.fighters[1].posture
	assert_almost_eq(float(takes[ONE]), 5.0 * 0.7, CLOSE, "one-handed: 0.7 of Right Cut's 5 (D2)")
	assert_almost_eq(float(takes[TWO]), 5.0 * 0.5, CLOSE, "two-handed: 0.5 (D2)")


# ------------------------------------------------------------------ disarmed

func test_bare_hands_have_no_grip_and_the_katana_comes_back_one_handed() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(a.grip, TWO)
	a.disarm(b, &"parried")
	assert_eq(a.grip, ONE, "disarm clears the grip (D7)")
	H.run(W, 120)
	assert_eq(a.state, &"free")
	W.drain_events()
	W.step([_with_grip(H.idle()), H.idle()])
	assert_eq(a.grip, ONE, "bare hands don't switch")
	assert_false(W.drain_events().any(func(e: Dictionary) -> bool: return e["t"] == &"grip"))
	W.remove_dropped_weapon(a.id)
	a.armed = true
	assert_eq(a.grip, ONE, "re-armed, one-handed")


func test_a_training_swap_takes_the_new_weapon_s_first_grip() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	W.step([_with_grip(H.idle()), H.idle()])
	a.take_weapon(Moves.GREATSWORD)
	assert_eq(a.grip, &"", "the Greatsword has none")
	a.take_weapon(Moves.KATANA)
	assert_eq(a.grip, ONE)


# ------------------------------------------------------------------ determinism

## Fighter 0's input on step i: a mixed string with switches, then a block.
static func _mixed(i: int) -> RawInput:
	if i in [0, 40, 80, 120]:
		return H.btn(Btn.LIGHT)
	if i in [50, 125]:
		return _with_grip(H.idle())
	return H.idle()


func test_the_grip_and_count_are_in_the_snapshot_and_hash() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	var s: Dictionary = a.snapshot()
	assert_true(s.has(&"grip") and s.has(&"string_count"))
	var before: String = W.state_hash()
	a.grip = TWO
	assert_ne(W.state_hash(), before, "the grip shows in the hash")
	a.grip = ONE
	a.string_count = 2
	assert_ne(W.state_hash(), before, "the count shows in the hash")


func test_a_match_with_switches_replays_and_restores_to_the_same_hash() -> void:
	var A: World = H.make_world()
	var B: World = H.make_world()
	var hashes: Array[String] = []
	for i: int in 200:
		A.step([_mixed(i), H.idle()])
		B.step([_mixed(i), H.idle()])
		hashes.append(A.state_hash())
	assert_eq(A.state_hash(), B.state_hash(), "the same inputs, the same end")
	# restore mid-string, just after a switch, and play on
	var C: World = H.make_world()
	for i: int in 52:
		C.step([_mixed(i), H.idle()])
	var saved: Dictionary = C.snapshot()
	for i: int in range(52, 200):
		C.step([_mixed(i), H.idle()])
	var end: String = C.state_hash()
	C.restore(saved)
	assert_eq(C.state_hash(), hashes[51], "restored where it was saved")
	for i: int in range(52, 200):
		C.step([_mixed(i), H.idle()])
	assert_eq(C.state_hash(), end, "and steps on the same")
