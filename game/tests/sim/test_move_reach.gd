extends GutTest
## The other moves' reach test (task 7.14). Every move with a swing that
## strikes, other than the string's lights (test_duel_reach.gd), touches a
## defender standing at its distance in the spec's table of test distances
## (reach_table.gd), played from standing by SwingReach.first_contact().
## Empty until the moves have swings; the check and the table are tested on
## their own. Since milestone-1 task 17 the Greatsword's and the Daggers'
## moves play their clips at 1.0x with no band test until milestone 2
## re-keys them (the spec's P10): what they get wrong is printed, not failed
## (test_duel_reach.gd's MILESTONE_2). Since milestone-1 task 18 a Katana or
## bare-hands move off the band tables' waiting list is held by the
## distance-band test (test_move_bands.gd) instead, so this guards today's
## reach only for the moves still waiting (DuelReach.still_waits()).

const RT := preload("res://tests/sim/reach_table.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const DuelReach := preload("res://tests/sim/test_duel_reach.gd")


## What move `id` of `w` gets wrong against its row of the table, or nothing.
static func _problems(w: WeaponDef, id: StringName) -> Array[String]:
	var d: float = RT.distance(w, id)
	if SwingReach.first_contact(w.moves[id], w, d, 0.0, FighterBody.of(&"")) != null:
		return [] as Array[String]
	return ["%s.%s (%s): no touch from %.1f m" % [w.id, id, RT.kind_of(w, id), d]] as Array[String]


## Every problem of every move with a swing on `w` but the string's lights.
static func _weapon_problems(w: WeaponDef) -> Array[String]:
	var out: Array[String] = []
	for id: StringName in w.moves:
		var m: AttackDef = w.moves[id]
		if m.swing != null and RT.strikes(m) and RT.kind_of(w, id) != &"string_light" and DuelReach.still_waits(w, id):
			out.append_array(_problems(w, id))
	return out


func test_every_other_move_with_a_swing_touches_from_its_test_distance() -> void:
	var problems: Array[String] = []
	for id: StringName in Moves.WEAPONS:
		if DuelReach.MILESTONE_2.has(id):
			for p: String in _weapon_problems(Moves.WEAPONS[id]):
				gut.p("milestone 2: " + p)
			continue
		problems.append_array(_weapon_problems(Moves.WEAPONS[id]))
	assert_eq(problems, [] as Array[String])


func test_every_bare_hands_move_misses_from_6_m() -> void:
	# task 25: a punch or kick lunging its furthest still falls well short
	# (Counter Lunge works its lunge out from the distance, so it reaches)
	var w: WeaponDef = Moves.FISTS
	for id: StringName in w.moves:
		var m: AttackDef = w.moves[id]
		if m.swing != null and RT.strikes(m) and m.special != &"counterLunge":
			assert_null(SwingReach.first_contact(m, w, 6.0, 0.0, FighterBody.of(&"")), "%s touches from 6 m" % id)


func test_the_table_gives_each_kind_of_move_its_distance() -> void:
	# the Katana, duelling at 3.3 m (KE task 3), has a move of every kind but
	# an ultimate
	var want: Dictionary[StringName, float] = {
		&"k_l1": 3.3, &"k_l4": 3.3, # the string's lights
		&"k_h1f": 3.8, &"k_rdraw": 3.8, &"k_h2": 3.8, # heavies, + 0.5 m
		&"k_iai": 4.4, &"k_iai_h": 4.4, # the Iai Slashes' own 4.4 m
		&"k_sl": 4.8, &"k_sh": 5.8, # sprint light + 1.5 m, heavy + 2.5 m
		&"k_dl": 3.3, &"k_dh": 3.3, # dodge attacks
		&"k_bl": 3.8, &"k_bh": 5.3, # backstep light + 0.5 m, heavy + 2 m
		&"k_jl": 2.8, &"k_jh": 2.8, # jump attacks - 0.5 m
		&"k_lunge": 5.3, # the counter lunge + 2 m
		&"k_thrust": 4.3, &"k_sweep": 4.3, # unblockable abilities + 1 m
	}
	for id: StringName in want:
		assert_almost_eq(RT.distance(Moves.KATANA, id), want[id], 1e-9, String(id))
	assert_almost_eq(RT.distance(Moves.GREATSWORD, &"g_crush"), 3.35, 1e-9, "Guard Crusher, an ability that can be blocked")
	assert_almost_eq(RT.distance(Moves.GREATSWORD, &"g_dh"), 3.35, 1e-9, "Skewer, from a dodge, by its slot")
	assert_almost_eq(RT.distance(Moves.FISTS, &"f_breaker"), 4.35, 1e-9, "Breaker Palm, the ultimate's palm, + 2.5 m")
	assert_false(RT.strikes(Moves.KATANA.moves[&"k_flash"]), "Flash strikes nothing, so it isn't tested")


## A Katana whose Running Draw holds its point straight ahead, the grip `out`
## m in front at 1.2 m up.
static func _running_draw(out: float) -> WeaponDef:
	var key: Swing.KeyPose = SF.key(0, [0.0, 1.2, out], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0])
	return SF.weapon(&"katana", {&"k_sl": SF.held(Moves.KATANA.moves[&"k_sl"], {SF.RIGHT: key} as Dictionary[StringName, Swing.KeyPose])})


func test_the_check_passes_a_move_that_reaches_its_distance_and_fails_one_that_falls_short() -> void:
	# Running Draw from 4.8 m lunges 1.6 m, leaving the defender's 0.42 m
	# capsule, grown by half the blade, 3.2 - 0.4275 = 2.7725 m away: a point
	# 0.45 + 1.39 m out falls short, one 1.5 + 1.39 m out reaches it
	assert_eq(_weapon_problems(_running_draw(1.5)), [] as Array[String], "reaching")
	assert_eq(_weapon_problems(_running_draw(0.45)), ["katana.k_sl (sprint_light): no touch from 4.8 m"] as Array[String],
			"falling short")
