extends GutTest
## The band tables (game/sim/moves/bands.json, MoveBands, milestone-1 task
## 18), read as data, as CI reads them: the spec's timing band table and
## distance band table, one row per move kind per weapon, and the waiting
## list. Every Katana and bare-hands move off the waiting list must land in
## its kind's timing band (the frame-data table's startup, active and
## recovery) and connect from its distance band (SwingReach, played from
## standing: it touches from "touches from", and from the duelling and the
## computer's preferred distances where those are closer; a string light
## puts 5-30 cm in at its duelling distance (15-20 cm until KE task 2's
## 1.3 m blade; the string re-keys set the new depth); it touches nothing from
## "misses from"). Each keying task takes its moves off the list; the old
## reach checks (test_duel_reach.gd, test_move_reach.gd) keep guarding the
## moves still on it.

const SF := preload("res://tests/sim/swing_fixtures.gd")
## The weapons milestone 1 holds to the bands; the Greatsword and the
## Daggers wait for milestone 2 (the spec's P10).
const BANDED: Array[StringName] = [&"katana", &"fists"]
## The moves keyed into their bands so far, by weapon: the light string
## (Right Cut and Return Cut, task 31; Kesa Cut and Crown Cut, task 32), and
## Breaker Palm (task 99).
const KEYED: Dictionary = {&"katana": [&"k_l1", &"k_l2", &"k_l3", &"k_l4"], &"fists": [&"f_breaker"]}


func _bands() -> MoveBands:
	var b: MoveBands = MoveBands.read()
	assert_eq(b.errors, PackedStringArray(), "the band tables read cleanly")
	return b


## Every timing-band problem of every banded move off `bands`' waiting list.
static func _timing_problems(bands: MoveBands, table: FrameDataTable) -> Array[String]:
	var out: Array[String] = []
	for wid: StringName in BANDED:
		for id: StringName in Moves.WEAPONS[wid].moves:
			var row: Dictionary = table.row(wid, id)
			if bands.is_held(wid, id, StringName(row.get("kind", ""))):
				out.append_array(bands.timing_problems(wid, id, row))
	return out


## Every distance-band problem of every banded move off `bands`' waiting
## list, with `weapons` standing in for the game's where given.
static func _distance_problems(bands: MoveBands, table: FrameDataTable, weapons: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	for wid: StringName in BANDED:
		var w: WeaponDef = weapons.get(wid, Moves.WEAPONS[wid])
		for id: StringName in w.moves:
			var kind: StringName = StringName(table.row(wid, id).get("kind", ""))
			if bands.is_held(wid, id, kind):
				out.append_array(bands.distance_problems(w, id, kind))
	return out


## Records the per-move checklist's item `item` for every keyed move from
## `problems` (each begins "<weapon>.<move>", then a colon or a space):
## passed when none names it.
static func _record(item: int, problems: Array[String]) -> void:
	for m: Array in ChecklistResults.keyed_moves():
		var at: String = "%s.%s" % [m[0], m[1]]
		ChecklistResults.record_problems(item, m[1], problems.filter(func(p: String) -> bool: return p.begins_with(at + ":") or p.begins_with(at + " ")))


func test_every_katana_and_bare_hands_move_off_the_waiting_list_lands_in_its_timing_band() -> void:
	var problems: Array[String] = _timing_problems(_bands(), FrameDataTable.shared())
	_record(1, problems)
	assert_eq(problems, [] as Array[String])


func test_every_katana_and_bare_hands_move_off_the_waiting_list_connects_from_its_distance_band() -> void:
	var problems: Array[String] = _distance_problems(_bands(), FrameDataTable.shared())
	_record(2, problems)
	assert_eq(problems, [] as Array[String])


func test_a_move_taken_off_the_waiting_list_while_out_of_band_fails_both_tests() -> void:
	# Wind Cut, still a stand-in, lands on its 9th frame today, against the
	# dodge light band's 24-30; a Wind Cut held 0.3 m out falls short of 3.3 m
	# and of 2.8 m, lunge and all
	var bands: MoveBands = _bands()
	bands.waiting[&"katana"].erase(&"k_dl")
	var timing: Array[String] = _timing_problems(bands, FrameDataTable.shared())
	assert_true(timing.has("katana.k_dl (dodge_light): startup 9, not 24-30"), "%s" % [timing])
	assert_true(timing.all(func(p: String) -> bool: return p.begins_with("katana.k_dl ")), "only Wind Cut: %s" % [timing])
	# (the fixture's straight blade changes the keyed lights' reach, so only
	# Wind Cut's lines count here)
	var wind: Callable = func(p: String) -> bool: return p.begins_with("katana.k_dl ")
	var short: Array[String] = _distance_problems(bands, FrameDataTable.shared(), {&"katana": _point(0.3, &"k_dl")})
	assert_eq(short.filter(wind), ["katana.k_dl (dodge_light): no touch from 3.3 m", "katana.k_dl (dodge_light): no touch from 2.8 m"])
	assert_eq(_distance_problems(_bands(), FrameDataTable.shared(), {&"katana": _point(0.3, &"k_dl")}).filter(wind), [],
			"on the list, it isn't checked")


func test_the_waiting_list_holds_only_katana_and_bare_hands_moves() -> void:
	var bands: MoveBands = _bands()
	assert_eq(bands.waiting.keys().filter(func(w: Variant) -> bool: return not BANDED.has(w)), [], "only the Katana and bare hands wait")
	for wid: StringName in bands.waiting:
		var seen: Dictionary = {}
		for id: StringName in bands.waiting[wid]:
			assert_true(Moves.WEAPONS[wid].moves.has(id), "%s.%s is a move" % [wid, id])
			assert_false(seen.has(id), "%s.%s listed once" % [wid, id])
			seen[id] = true
			var kind: StringName = StringName(FrameDataTable.shared().row(wid, id).get("kind", ""))
			assert_ne(kind, &"counter_lunge", "%s.%s: the Counter Lunges get no band test until milestone 2" % [wid, id])


func test_every_katana_and_bare_hands_move_but_the_counter_lunges_and_the_keyed_waits_for_its_family() -> void:
	# task 14's stand-in markers, until each keying task takes its moves off
	var bands: MoveBands = _bands()
	for wid: StringName in BANDED:
		for id: StringName in Moves.WEAPONS[wid].moves:
			var kind: StringName = StringName(FrameDataTable.shared().row(wid, id)["kind"])
			var keyed: bool = KEYED.get(wid, []).has(id)
			assert_eq(bands.is_waiting(wid, id), kind != &"counter_lunge" and not keyed, "%s.%s" % [wid, id])
	assert_eq(bands.waiting[&"katana"].size() + bands.waiting[&"fists"].size(), 30, "Crescent Coil waits for its re-key (KE task 16)")


func test_every_banded_move_has_a_timing_band_and_every_striking_one_a_distance_band() -> void:
	var bands: MoveBands = _bands()
	for wid: StringName in BANDED:
		var w: WeaponDef = Moves.WEAPONS[wid]
		for id: StringName in w.moves:
			var kind: StringName = StringName(FrameDataTable.shared().row(wid, id)["kind"])
			if kind == &"counter_lunge":
				continue
			assert_false(bands.timing_band(wid, kind).is_empty(), "%s.%s: a timing band for %s" % [wid, id, kind])
			var m: AttackDef = w.moves[id]
			if m.damage > 0.0 or m.posture > 0.0:
				assert_true(bands.distance_band(wid, kind).has("touches"), "%s.%s: a distance band for %s" % [wid, id, kind])


func test_the_timing_bands_are_the_spec_s_table() -> void:
	var bands: MoveBands = _bands()
	var want: Dictionary = {
		&"katana": {
			&"string_light": {"startup": [24, 30], "active": [3, 6], "recovery": [24, 36]},
			&"string_heavy": {"startup": [42, 54], "active": [4, 8], "recovery": [36, 48]},
			&"iai_draw": {"startup": [36, 48], "from_stance": [15, 21], "active": [4, 6], "recovery": [36, 48]},
			&"iai_follow_up": {"startup": [36, 45], "active": [4, 6], "recovery": [30, 42]},
			&"unblockable": {"startup": [48, 60], "active": [4, 6], "recovery": [36, 48]},
			&"sprint_light": {"startup": [27, 33], "active": [4, 6], "recovery": [30, 42]},
			&"sprint_heavy": {"startup": [42, 54], "active": [4, 8], "recovery": [36, 48]},
			&"dodge_light": {"startup": [24, 30], "active": [3, 6], "recovery": [24, 36]},
			&"dodge_heavy": {"startup": [36, 48], "active": [5, 8], "recovery": [36, 48]},
			&"backstep_light": {"startup": [24, 30], "active": [3, 6], "recovery": [24, 36]},
			&"backstep_heavy": {"startup": [36, 48], "active": [4, 6], "recovery": [36, 48]},
			&"jump_light": {"startup": [12, 18], "active": [4, 6], "landing": [12, 18]},
			&"jump_heavy": {"startup": [18, 22], "active": [4, 6], "landing": [18, 24]},
			&"block_ability": {"startup": [2, 4], "active": [18, 18], "recovery": [18, 30]},
			&"ultimate": {"to_wave": [54, 66], "recovery": [36, 48]},
		},
		&"fists": {
			&"string_light": {"startup": [18, 24], "active": [2, 4], "recovery": [15, 24]},
			&"string_heavy": {"startup": [33, 42], "active": [3, 6], "recovery": [30, 42]},
			&"sprint_light": {"startup": [21, 27], "active": [3, 6], "recovery": [24, 36]},
			&"sprint_heavy": {"startup": [33, 42], "active": [4, 6], "recovery": [30, 42]},
			&"dodge_light": {"startup": [18, 24], "active": [2, 4], "recovery": [15, 24]},
			&"dodge_heavy": {"startup": [27, 36], "active": [3, 5], "recovery": [24, 36]},
			&"backstep_light": {"startup": [18, 24], "active": [3, 5], "recovery": [18, 27]},
			&"backstep_heavy": {"startup": [33, 42], "active": [3, 6], "recovery": [24, 36]},
			&"jump_light": {"startup": [12, 18], "active": [3, 5], "landing": [9, 15]},
			&"jump_heavy": {"startup": [18, 27], "active": [4, 6], "landing": [15, 21]},
			&"ultimate": {"startup": [30, 42], "active": [3, 5], "recovery": [30, 42]},
			&"recall": {"startup": [16, 24], "total": [26, 36]},
		},
	}
	for wid: StringName in want:
		assert_eq_deep(bands.timing[wid].keys().map(func(k: Variant) -> StringName: return StringName(k)).filter(
				func(k: StringName) -> bool: return not want[wid].has(k)), [])
		for kind: StringName in want[wid]:
			assert_eq_deep(bands.timing_band(wid, kind), want[wid][kind])


func test_the_distance_bands_are_the_spec_s_table() -> void:
	var bands: MoveBands = _bands()
	var want: Dictionary = {
		&"katana": {
			# the spec's table 0.5 m further out for the 1.3 m blade (KE task 2),
			# another 0.3 m for the taller bodies (KE task 3)
			&"string_light": [3.3, 4.05], &"string_heavy": [3.8, 4.55], &"iai_follow_up": [3.8, 4.55],
			&"iai_draw": [4.4, 5.0], &"sprint_light": [4.8, 5.55], &"sprint_heavy": [5.8, 6.55],
			&"dodge_light": [3.3, 4.05], &"dodge_heavy": [3.3, 4.05], &"backstep_light": [3.8, 4.55],
			&"backstep_heavy": [5.3, 6.05], &"jump_light": [2.8, 3.55], &"jump_heavy": [2.8, 3.55],
			&"unblockable": [4.3, 5.05],
		},
		&"fists": {
			# the spec's table 0.25 m further out for the taller bodies (KE task 3)
			&"string_light": [1.85, 2.35], &"string_heavy": [2.35, 2.85], &"sprint_light": [3.35, 3.85],
			&"sprint_heavy": [4.35, 4.85], &"dodge_light": [1.85, 2.35], &"dodge_heavy": [1.85, 2.35],
			&"backstep_light": [2.35, 2.85], &"backstep_heavy": [3.85, 4.35], &"jump_light": [1.35, 1.85],
			&"jump_heavy": [1.35, 1.85], &"ultimate": [4.35, 4.85],
		},
	}
	for wid: StringName in want:
		for kind: StringName in want[wid]:
			var band: Dictionary = bands.distance_band(wid, kind)
			assert_eq([band.get("touches"), band.get("misses")], want[wid][kind], "%s %s" % [wid, kind])
	assert_eq(bands.distance_band(&"katana", &"string_light")["inside"], [0.04, 0.3], "until the string re-keys (KE tasks 2 and 3)")
	assert_eq(bands.distance_band(&"fists", &"string_light")["inside"], [0.15, 0.21], "until their re-keys (KE task 3)")
	assert_eq(bands.distance_band(&"katana", &"ultimate")["wave"], 33.0, "Moonsplitter: the whole stage")
	assert_eq(bands.distance[&"fists"]["misses_all"], 6.0, "every bare-hands move misses from 6 m")


func test_the_duelling_and_preferred_distances_are_the_weapons() -> void:
	var bands: MoveBands = _bands()
	for wid: StringName in BANDED:
		var w: WeaponDef = Moves.WEAPONS[wid]
		assert_eq(bands.distance[wid]["duel"], w.duel_distance, "%s duels" % wid)
		assert_almost_eq(float(bands.distance[wid]["preferred"]), w.reach, 1e-9, "%s's computer prefers its reach" % wid)


# The checks themselves, on made-up rows and swings.

func test_the_timing_check_names_each_number_out_of_its_band() -> void:
	var bands: MoveBands = _bands()
	var row: Dictionary = {"kind": "string_light", "startup": 24, "active": 6, "recovery": 36}
	assert_eq(bands.timing_problems(&"katana", &"x", row), [] as Array[String], "both ends of every band are in")
	row = {"kind": "string_light", "startup": 23, "active": 7, "recovery": 37}
	assert_eq(bands.timing_problems(&"katana", &"x", row), [
		"katana.x (string_light): startup 23, not 24-30",
		"katana.x (string_light): active 7, not 3-6",
		"katana.x (string_light): recovery 37, not 24-36",
	] as Array[String])


func test_the_iai_is_timed_tapped_and_from_the_stance() -> void:
	# held, the stance holds at the charge check (frame 9) and the draw goes
	# on from there: 45 frames tapped is 36 from the stance, out of 15-21
	var bands: MoveBands = _bands()
	var row: Dictionary = {"kind": "iai_draw", "startup": 45, "active": 5, "recovery": 40}
	assert_eq(bands.timing_problems(&"katana", &"k_iai", row), [
		"katana.k_iai (iai_draw): from the stance 36, not 15-21",
	] as Array[String])
	row["startup"] = 9 + 18
	assert_eq(bands.timing_problems(&"katana", &"k_iai", row), [
		"katana.k_iai (iai_draw): startup 27, not 36-48",
	] as Array[String])


func test_a_jump_attack_needs_its_landing_recovery() -> void:
	var bands: MoveBands = _bands()
	var row: Dictionary = {"kind": "jump_heavy", "startup": 20, "active": 5, "recovery": 18}
	assert_eq(bands.timing_problems(&"katana", &"k_jh", row), [
		"katana.k_jh (jump_heavy): no landing recovery in its row (task 59)",
	] as Array[String])
	row["landing"] = 20
	assert_eq(bands.timing_problems(&"katana", &"k_jh", row), [] as Array[String])


func test_a_move_without_a_row_or_a_band_is_named() -> void:
	var bands: MoveBands = _bands()
	assert_eq(bands.timing_problems(&"katana", &"x", {}), ["katana.x: no row in the frame-data table"] as Array[String])
	assert_eq(bands.timing_problems(&"katana", &"x", {"kind": "counter_lunge", "startup": 1, "active": 1, "recovery": 1}),
			["katana.x (counter_lunge): no timing band"] as Array[String])


## A Katana whose move `id` (Right Cut unless given) holds a straight blade
## of the Katana's length level and straight ahead, the grip `out` m in
## front at 1.2 m up (see test_duel_reach.gd), played as a stand-in lunging
## by its record (SF.weapon()), its blade 1.507 m to the point: from 3.3 m
## apart Right Cut's lunge leaves `out` - 1.0155 m of blade inside.
static func _point(out: float, id: StringName = &"k_l1") -> WeaponDef:
	var key: Swing.KeyPose = SF.key(0, [0.0, 1.2, out], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0])
	var w: WeaponDef = SF.weapon(&"katana", {id: SF.held(Moves.KATANA.moves[id], {SF.RIGHT: key} as Dictionary[StringName, Swing.KeyPose])})
	w.blade = StrikeSegment.make(V3.make(0.0, 0.09, 0.0), V3.make(0.0, 1.507, 0.0), 0.015)
	w.derive_reach()
	return w


func test_the_distance_check_passes_a_light_18_cm_in_that_misses_from_4_05_m() -> void:
	var lines: Array[MoveBands.DistanceLine] = _bands().distance_check(_point(1.1955), &"k_l1", &"string_light")
	assert_eq(lines.map(func(l: MoveBands.DistanceLine) -> String: return l.text), [
		"touches from 3.3 m: 18.0 cm in",
		"touches from 2.8 m",
		"misses from 4.05 m",
	])
	assert_true(lines.all(func(l: MoveBands.DistanceLine) -> bool: return l.ok))
	assert_eq(_bands().distance_problems(_point(1.1955), &"k_l1", &"string_light"), [] as Array[String])


func test_the_distance_check_fails_a_graze_a_short_light_and_one_that_reaches_too_far() -> void:
	var bands: MoveBands = _bands()
	assert_eq(bands.distance_problems(_point(1.0455), &"k_l1", &"string_light"),
			["katana.k_l1 (string_light): touches from 3.3 m: 3.0 cm in, not 4-30 cm"] as Array[String])
	assert_eq(bands.distance_problems(_point(0.9), &"k_l1", &"string_light"),
			["katana.k_l1 (string_light): no touch from 3.3 m"] as Array[String])
	# a point 1.9 m out still reaches a defender 4.05 m away
	assert_has(bands.distance_problems(_point(1.9), &"k_l1", &"string_light"),
			"katana.k_l1 (string_light): touches from 4.05 m, where it must miss")


func test_a_move_that_strikes_nothing_has_no_distance_check() -> void:
	assert_eq(_bands().distance_check(Moves.KATANA, &"k_flash", &"block_ability"), [] as Array[MoveBands.DistanceLine])


func test_the_file_s_mistakes_are_named() -> void:
	var path: String = "user://test_move_bands.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"timing": {"katana": {"string_light": {"startup": [30, 24]}}}, "distance": {}, "waiting": {"katana": ["k_l1"]}, "extra": 1}))
	f.close()
	var b: MoveBands = MoveBands.read(path)
	assert_has(b.errors, "unknown section extra")
	assert_has(b.errors, "timing.katana.string_light.startup: [30, 24] is not a range low to high")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_has(MoveBands.read("res://nowhere.json").errors, "res://nowhere.json is missing")


func test_today_s_reach_checks_guard_only_the_moves_still_waiting() -> void:
	var DuelReach: GDScript = load("res://tests/sim/test_duel_reach.gd")
	assert_true(DuelReach.still_waits(Moves.KATANA, &"k_dl"), "a waiting light (Wind Cut)")
	assert_false(DuelReach.still_waits(Moves.KATANA, &"k_l1"), "a keyed light, held by the band test")
	assert_true(DuelReach.still_waits(Moves.GREATSWORD, &"g_l1"), "a weapon with no bands")
	assert_true(DuelReach.still_waits(Moves.KATANA, &"k_lunge"), "a Counter Lunge, never on the list, keeps today's checks")
	var bands: MoveBands = MoveBands.shared()
	var at: int = bands.waiting[&"katana"].find(&"k_dl")
	bands.waiting[&"katana"].remove_at(at)
	assert_false(DuelReach.still_waits(Moves.KATANA, &"k_dl"), "off the list, the band test holds it")
	bands.waiting[&"katana"].insert(at, &"k_dl")
