extends WeaponStringsTest
## The Greatsword's new strings (plan task 10): the spec's Greatsword table,
## played through the rules. Expected numbers come from the spec, not the
## code.

## The spec's Greatsword table, all six rows (see WeaponStringsTest.rows):
## the dodge thrusts are in no string, so they have no sides.
const ROWS: Dictionary[StringName, Dictionary] = {
	&"g_l1": {
		"name": "Heavy Swing", "frames": [14, 4, 22], "damage": 9, "posture": 11,
		"light": &"g_l2", "heavy": &"g_h1", "sides": [&"right", &"left"],
	},
	&"g_l2": {
		"name": "Backswing", "frames": [11, 4, 22], "damage": 9, "posture": 11,
		"light": &"", "heavy": &"g_h1", "sides": [&"left", &"right"],
	},
	&"g_h1": {
		"name": "Overhead Strike", "frames": [26, 5, 32], "damage": 18, "posture": 22,
		"light": &"", "heavy": &"g_h2", "sides": [&"centre", &"right"],
	},
	&"g_h2": {
		"name": "Low Sweep", "frames": [26, 5, 34], "damage": 16, "posture": 22,
		"light": &"", "heavy": &"", "sides": [&"right", &"left"],
	},
	&"g_dl": {
		"name": "Piercing Lunge", "frames": [12, 3, 20], "damage": 8, "posture": 10,
		"light": &"", "heavy": &"", "sides": [&"", &""],
	},
	&"g_dh": {
		"name": "Skewer", "frames": [22, 4, 28], "damage": 14, "posture": 18,
		"light": &"", "heavy": &"", "sides": [&"", &""],
	},
}

## A heavy held past its frame 9 charges, standing still, and releases by
## itself 150 frames (2.5 s) later as a full charge, 1.8 times as strong (the
## demo's charge, which Overhead Strike keeps from Crushing Blow).
const CHARGE_FROM: int = 9
const CHARGE_MAX: int = 150

## A defender who jumps 9 steps before a sweep would hit is in the air as it
## cuts (test_combat's jump over Reaping Sweep jumps as early).
const LEAP_LEAD: int = 9

## A defender who dodges forward 6 steps before a thrust would hit is dodging
## into it as it strikes (test_combat's dodge into Piercing Thrust comes as
## early).
const STOMP_LEAD: int = 6


func _init() -> void:
	weapon = Moves.GREATSWORD
	rows = ROWS


## The step fighter 0's attack id first hits in r (-1 if it never does).
static func _hit_step(r: PlayedString, id: StringName) -> int:
	for e: Dictionary in r.by_fighter_0(&"hit"):
		if e["attack"] == id:
			return e["step"]
	return -1


## Checks that fighter 0 gives one warning in r, of kind and naming its
## attack id, on the step id starts.
func _assert_warns(r: PlayedString, kind: StringName, id: StringName) -> void:
	var warnings: Array[Dictionary] = r.by_fighter_0(&"telegraph")
	assert_eq(warnings.size(), 1, "one warning")
	if warnings.size() != 1:
		return
	var e: Dictionary = warnings[0]
	var move_name: String = rows[id]["name"]
	assert_eq([e["kind"], e["attack"]], [kind, id], "a %s's, naming %s" % [kind, move_name])
	assert_eq(e["step"], r.attack.find(id), "on the step %s starts" % move_name)


## Checks that the defender counters fighter 0's attack id in r with kind:
## one counter, by fighter 1 on fighter 0, stunning it out of id, which never
## hits.
func _assert_countered(r: PlayedString, kind: StringName, id: StringName) -> void:
	var move_name: String = rows[id]["name"]
	var counters: Array[Dictionary] = r.all(&"counter")
	assert_eq(counters.size(), 1, "one counter")
	if counters.size() == 1:
		var c: Dictionary = counters[0]
		assert_eq([c["kind"], c["by"], c["on"]], [kind, 1, 0], "the defender's %s, on the attacker" % kind)
		var at: int = c["step"]
		assert_eq([r.attack[at - 1], r.state[at]], [id, &"stunned"], "stunning it out of %s" % move_name)
	assert_false(r.ids(&"hit").has(id), "and %s never hits" % move_name)


# ------------------------------------------------------------------ the momentum lights

func test_two_lights_then_a_heavy_hit_with_heavy_swing_backswing_and_overhead_strike() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	assert_eq(_play([light, light]).ids(&"hit"), [&"g_l1", &"g_l2"] as Array[StringName], "L-L: Heavy Swing, Backswing")
	assert_eq(
		_play([light, light, heavy]).ids(&"hit"),
		[&"g_l1", &"g_l2", &"g_h1"] as Array[StringName],
		"L-L-H: Heavy Swing, Backswing, Overhead Strike",
	)
	assert_eq(_play([light, heavy]).ids(&"hit"), [&"g_l1", &"g_h1"] as Array[StringName], "L-H: Heavy Swing, Overhead Strike")


func test_backswing_swings_sooner_than_heavy_swing_riding_its_momentum() -> void:
	var r: PlayedString = _play([Btn.LIGHT, Btn.LIGHT])
	var swung_on: Array[int] = []
	for e: Dictionary in r.all(&"swing"):
		if e["f"] == 0:
			swung_on.append(r.frame[int(e["step"])])
	assert_eq(swung_on, [14, 11] as Array[int], "Heavy Swing swings on its frame 14, and Backswing on its 11")


func test_a_light_starts_nothing_after_backswing() -> void:
	_assert_starts_nothing_in([Btn.LIGHT, Btn.LIGHT], [&"g_l1", &"g_l2"], [Btn.LIGHT])


# ------------------------------------------------------------------ Overhead Strike

func test_a_heavy_from_neutral_is_overhead_strike() -> void:
	assert_eq(_play([Btn.HEAVY]).ids(&"hit"), [&"g_h1"] as Array[StringName])


func test_a_held_heavy_charges_overhead_strike_standing_still() -> void:
	# heavy held for 60 steps with the stick to the right
	var r: PlayedString = _run(func(i: int) -> RawInput: return H.move(1.0, 0.0, Btn.HEAVY) if i < 60 else H.idle())
	assert_eq(r.charging.find(true), CHARGE_FROM + 1, "charging once its first 9 frames have passed")
	assert_eq(r.charging.rfind(true), 59, "until heavy is let go on step 60")
	assert_eq(r.walked(0, 60), 0.0, "standing still meanwhile, the stick to the side")
	assert_eq(r.ids(&"hit"), [&"g_h1"] as Array[StringName], "then Overhead Strike hits")
	var startup: int = ROWS[&"g_h1"]["frames"][0]
	assert_eq(r.step_of(&"hit") - 60, startup - CHARGE_FROM, "17 frames after the release: the rest of its 26-frame startup")


func test_an_overhead_strike_held_for_2_5_s_releases_by_itself_as_a_stronger_power_attack() -> void:
	var r: PlayedString = _run(func(i: int) -> RawInput: return H.btn(Btn.HEAVY) if i < 220 else H.idle())
	var release: int = r.charging.rfind(true) + 1
	assert_eq(release, CHARGE_FROM + CHARGE_MAX, "the charge ends 150 frames (2.5 s) in, heavy still held")
	assert_eq(r.ids(&"hit"), [&"g_h1"] as Array[StringName], "and Overhead Strike hits")
	assert_almost_eq(float(r.find(&"hit").get("damage", NAN)), 18.0 * 1.8, CLOSE, "with a full charge's damage")


func test_overhead_strike_charges_as_the_l_l_hs_finisher_too() -> void:
	# a held heavy charges however the heavy started, as the demo's Twin Fang
	# does after the Daggers' lights: the L-L-H pressed as _play presses it,
	# with the heavy then held to the end
	var on: Array[int] = _play([Btn.LIGHT, Btn.LIGHT, Btn.HEAVY]).pressed_on
	var second_light: int = on[1]
	var heavy_from: int = on[2]
	var held_finisher: Callable = func(i: int) -> RawInput:
		if i == 0 or i == second_light:
			return H.btn(Btn.LIGHT)
		return H.btn(Btn.HEAVY) if i >= heavy_from else H.idle()
	var r: PlayedString = _run(held_finisher)
	var charged_from: int = r.charging.find(true)
	assert_eq(
		[r.attack[charged_from], r.frame[charged_from]] if charged_from >= 0 else [],
		[&"g_h1", CHARGE_FROM],
		"Overhead Strike charges from its frame 9",
	)
	assert_eq(r.ids(&"hit"), [&"g_l1", &"g_l2", &"g_h1"] as Array[StringName], "and the string hits three times")
	assert_almost_eq(float(r.all(&"hit").back().get("damage", NAN)), 18.0 * 1.8, CLOSE, "the last as a full charge, released by itself")


func test_a_light_starts_no_backswing_out_of_overhead_strike() -> void:
	_assert_starts_nothing_in([Btn.HEAVY], [&"g_h1"], [Btn.LIGHT])
	_assert_starts_nothing_in([Btn.LIGHT, Btn.LIGHT, Btn.HEAVY], [&"g_l1", &"g_l2", &"g_h1"], [Btn.LIGHT])


func test_stopping_after_any_hit_ends_the_string_when_that_move_ends() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	var strings: Array = [
		[light], [light, light], [heavy], [light, heavy], [light, light, heavy],
		[heavy, heavy], [light, heavy, heavy], [light, light, heavy, heavy],
	]
	for presses: Array in strings:
		var typed: Array[int] = []
		typed.assign(presses)
		_assert_stops_after(typed)


# ------------------------------------------------------------------ Low Sweep

func test_overhead_strike_goes_on_to_low_sweep() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	assert_eq(_play([heavy, heavy]).ids(&"hit"), [&"g_h1", &"g_h2"] as Array[StringName], "H-H: Overhead Strike, Low Sweep")
	assert_eq(
		_play([light, light, heavy, heavy]).ids(&"hit"),
		[&"g_l1", &"g_l2", &"g_h1", &"g_h2"] as Array[StringName],
		"L-L-H-H: the L-L-H, then Low Sweep",
	)


func test_low_sweep_telegraphs_a_sweep_as_it_starts() -> void:
	_assert_warns(_play([Btn.HEAVY, Btn.HEAVY]), &"sweep", &"g_h2")


func test_a_blocking_defender_blocks_overhead_strike_but_not_low_sweep() -> void:
	var r: PlayedString = _play_against([Btn.HEAVY, Btn.HEAVY], func(_i: int) -> RawInput: return H.btn(Btn.BLOCK))
	assert_eq(r.ids(&"block"), [&"g_h1"] as Array[StringName], "Overhead Strike is blocked")
	assert_eq(r.ids(&"hit"), [&"g_h2"] as Array[StringName], "Low Sweep hits through the block")


func test_a_defender_in_the_air_as_low_sweep_cuts_leaps_over_it_as_a_counter() -> void:
	# the defender jumps LEAP_LEAD steps before the step Low Sweep hits one
	# who stays put
	var heavies: Array[int] = [Btn.HEAVY, Btn.HEAVY]
	var contact: int = _hit_step(_play(heavies), &"g_h2")
	assert_gt(contact, LEAP_LEAD, "Low Sweep hits a defender who stays put")
	if contact <= LEAP_LEAD:
		return
	_assert_countered(_play_against(heavies, H.tap_at(contact - LEAP_LEAD, Btn.JUMP)), &"leap", &"g_h2")


func test_low_sweep_ends_the_string() -> void:
	_assert_starts_nothing_in([Btn.HEAVY, Btn.HEAVY], [&"g_h1", &"g_h2"], LIGHT_OR_HEAVY)


func test_low_sweep_is_narrower_and_faster_than_reaping_sweep_and_reaches_past_the_lights() -> void:
	# the spec's numbers: Low Sweep 26 frames, 110° and 3.2 m; Reaping Sweep
	# 28 frames and 160°; the lights 3.0 m
	var moves: Dictionary[StringName, AttackDef] = Moves.GREATSWORD.moves
	var low: AttackDef = moves[&"g_h2"]
	var reaping: AttackDef = moves[&"g_sweep"]
	assert_eq([reaping.startup, reaping.arc, moves[&"g_l1"].range], [28, 160.0, 3.0], "Reaping Sweep's and the lights' numbers")
	assert_lt(low.startup, reaping.startup, "Low Sweep starts sooner than Reaping Sweep")
	assert_lt(low.arc, reaping.arc, "and is narrower")
	assert_gt(low.range, moves[&"g_l1"].range, "it reaches past the lights, as an unblockable does")


func test_low_sweep_is_marked_as_an_unblockable_that_can_be_jumped() -> void:
	# the spec: unblockable (dodge invincibility doesn't help against it, and
	# it leaves the danger trail, the red ink trail), jumpable, with the sweep
	# counter, and as a heavy it dodge-cancels from 26 + 5 + 17 = 48. jumpable
	# matters only close in and off to the side, where the hit's cone widens
	# more than the leap counter's, so the flag is held here.
	var m: AttackDef = Moves.GREATSWORD.moves[&"g_h2"]
	assert_eq(
		[m.unblockable, m.undodgeable, m.trail, m.jumpable, m.counter, m.dodge_cancel_from],
		[true, true, &"danger", true, &"sweep", 48],
	)


func test_low_sweep_is_a_sweep_with_its_interim_cone_and_earthbreakers_lunge() -> void:
	# until weapon paths decide hits (task 7): a sweep (the stand-in's sweep
	# pose), 3.2 m and 110°, with Earthbreaker's lunge, knockback and
	# hitstop, its lunge ending two frames after its cut starts, as
	# Earthbreaker's did
	var m: AttackDef = Moves.GREATSWORD.moves[&"g_h2"]
	assert_eq([m.type, m.anim], [&"sweep", &"sweep"], "a sweep")
	assert_eq(
		[m.range, m.arc, m.lunge, m.lunge_start, m.lunge_end, m.knockback, m.hitstop],
		[3.2, 110.0, 0.8, 10, 28, 2.0, 10],
		"range, arc, lunge and its window, knockback and hitstop",
	)


# ------------------------------------------------------------------ the dodge thrusts

func test_a_light_out_of_a_dodge_is_piercing_lunge_which_a_block_stops() -> void:
	assert_eq(_out_of_a_dodge(Btn.LIGHT).ids(&"hit"), [&"g_dl"] as Array[StringName], "Piercing Lunge hits")
	var blocked: PlayedString = _out_of_a_dodge(Btn.LIGHT, func(_i: int) -> RawInput: return H.btn(Btn.BLOCK))
	assert_eq(blocked.ids(&"block"), [&"g_dl"] as Array[StringName], "a blocking defender blocks it")
	assert_eq(blocked.ids(&"hit"), [] as Array[StringName], "and isn't hit")
	assert_eq(blocked.by_fighter_0(&"telegraph"), [] as Array[Dictionary], "it gives no warning")


func test_a_heavy_out_of_a_dodge_is_skewer_which_warns_of_a_thrust_and_goes_through_a_block() -> void:
	var r: PlayedString = _out_of_a_dodge(Btn.HEAVY, func(_i: int) -> RawInput: return H.btn(Btn.BLOCK))
	assert_eq(r.ids(&"hit"), [&"g_dh"] as Array[StringName], "Skewer hits a blocking defender")
	assert_eq(r.ids(&"block"), [] as Array[StringName], "and isn't blocked")
	_assert_warns(r, &"thrust", &"g_dh")


func test_a_forward_dodge_gives_the_thrusts_too_and_a_backward_one_the_back_attacks() -> void:
	var forward := Vector2(0.0, 1.0)
	var back := Vector2(0.0, -1.0)
	var swings: Array[StringName] = []
	for dodge: Array in [[Btn.LIGHT, forward], [Btn.HEAVY, forward], [Btn.LIGHT, back], [Btn.HEAVY, back]]:
		swings.append_array(_out_of_a_dodge(dodge[0], Callable(), dodge[1]).ids(&"swing").slice(0, 1))
	assert_eq(
		swings,
		[&"g_dl", &"g_dh", &"g_bl", &"g_bh"] as Array[StringName],
		"forward: Piercing Lunge and Skewer; back: Rising Edge and Lunge Cleave, the back attacks",
	)


func test_a_defender_dodging_forward_into_skewer_stomps_it() -> void:
	# the defender dodges forward STOMP_LEAD steps before the step Skewer hits
	# one who stays put
	var contact: int = _hit_step(_out_of_a_dodge(Btn.HEAVY), &"g_dh")
	assert_gt(contact, STOMP_LEAD, "Skewer hits a defender who stays put")
	if contact <= STOMP_LEAD:
		return
	var defender_dodges_in: Callable = func(i: int) -> RawInput:
		return H.move(0.0, 1.0, Btn.DODGE) if i == contact - STOMP_LEAD else H.idle()
	_assert_countered(_out_of_a_dodge(Btn.HEAVY, defender_dodges_in), &"stomp", &"g_dh")


func test_piercing_lunge_is_a_blockable_stab_with_its_interim_cone() -> void:
	# until weapon paths decide hits (task 7): a stab (the stand-in's thrust
	# pose), 3.0 m and 50° after a 0.8 m lunge, with Pommel Strike's
	# knockback, and blockable
	var m: AttackDef = Moves.GREATSWORD.moves[&"g_dl"]
	assert_eq([m.type, m.anim, m.unblockable, m.counter], [&"stab", &"thrust", false, &""], "a blockable stab")
	assert_eq([m.range, m.arc, m.lunge, m.knockback], [3.0, 50.0, 0.8, 0.8], "range, arc, lunge and knockback")


func test_skewer_is_an_unblockable_thrust_reaching_past_the_lights_with_its_interim_cone() -> void:
	# until weapon paths decide hits (task 7): a thrust, 3.4 m and 36° after a
	# 1.0 m lunge, past the lights' 3.0 m, turning slowly once it strikes (as
	# the Katana's Piercing Thrust does), with Cyclone's knockback; as an
	# unblockable, undodgeable and with the danger trail
	var moves: Dictionary[StringName, AttackDef] = Moves.GREATSWORD.moves
	var m: AttackDef = moves[&"g_dh"]
	assert_eq([m.type, m.anim], [&"thrust", &"thrust"], "a thrust")
	assert_eq(
		[m.unblockable, m.undodgeable, m.trail, m.track_startup, m.counter],
		[true, true, &"danger", 5.0, &"thrust"],
		"an unblockable (turning slowly as it winds up too), with the thrust counter",
	)
	assert_eq(m.dodge_cancel_from, 40, "as a heavy it dodge-cancels from 22 + 4 + 14")
	assert_eq(
		[m.range, m.arc, m.lunge, m.track_active, m.knockback],
		[3.4, 36.0, 1.0, 0.5, 1.4],
		"range, arc, lunge, turn and knockback",
	)
	assert_eq(moves[&"g_l1"].range, 3.0, "the lights' reach")
	assert_gt(m.range, moves[&"g_l1"].range, "Skewer reaches past the lights, as an unblockable does")


# ------------------------------------------------------------------ the spec's table

func test_all_six_rows_match_the_spec_table() -> void:
	_assert_rows_match_the_spec()


func test_overhead_strike_is_an_overhead_with_crushing_blows_cone() -> void:
	# until weapon paths decide hits (task 7): an overhead (the stand-in's
	# overhead pose) with Crushing Blow's reach, width, lunge, knockback and
	# hitstop
	var m: AttackDef = Moves.GREATSWORD.moves[&"g_h1"]
	assert_eq([m.type, m.anim], [&"overhead", &"overhead"], "an overhead")
	assert_eq(
		[m.range, m.arc, m.lunge, m.lunge_start, m.lunge_end, m.knockback, m.hitstop],
		[3.1, 90.0, 0.7, 10, 30, 1.6, 9],
		"range, arc, lunge and its window, knockback and hitstop",
	)


func test_backswings_lunge_and_dodge_cancel_keep_pace_with_its_faster_start() -> void:
	# the lunge ends one frame after the cut starts, and the dodge cancel
	# opens 8 frames after the cut ends, as Heavy Swing's do (15 and 26)
	var m: AttackDef = Moves.GREATSWORD.moves[&"g_l2"]
	assert_eq([m.lunge, m.lunge_end, m.dodge_cancel_from], [0.4, 12, 23])
