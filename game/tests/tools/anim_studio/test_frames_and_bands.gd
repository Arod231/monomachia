extends GutTest
## The Studio's frames-and-bands view as data (FramesAndBands, milestone-1
## task 25), headless: a move in band, one out of band (waiting for its
## family, or where CI will fail), one that misses from its distance band,
## and a Counter Lunge with no band test.

const SF := preload("res://tests/sim/swing_fixtures.gd")


## A Katana whose Right Cut holds a straight blade level and straight ahead,
## the grip `out` m in front, played as a stand-in (test_move_bands.gd's):
## 1.1955 puts 18 cm in from 3.3 m, 0.9 falls short.
static func _point(out: float) -> WeaponDef:
	var key: Swing.KeyPose = SF.key(0, [0.0, 1.2, out], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0])
	var w: WeaponDef = SF.weapon(&"katana", {&"k_l1": SF.held(Moves.KATANA.moves[&"k_l1"], {SF.RIGHT: key} as Dictionary[StringName, Swing.KeyPose])})
	w.blade = StrikeSegment.make(V3.make(0.0, 0.09, 0.0), V3.make(0.0, 1.507, 0.0), 0.015)
	w.derive_reach()
	return w


## The band tables with move `id` off the waiting list (Right Cut is, since
## task 31).
static func _bands_off(id: StringName = &"k_l1") -> MoveBands:
	var b: MoveBands = MoveBands.read()
	b.waiting[&"katana"].erase(id)
	return b


const IN_BAND: Dictionary = {"kind": "string_light", "startup": 26, "active": 4, "recovery": 30}


func test_a_move_in_band() -> void:
	var v: FramesAndBands = FramesAndBands.build(_point(1.1955), &"k_l1", IN_BAND, {"windup": 3.5}, _bands_off())
	assert_true(v.in_band())
	assert_eq(v.verdict(), "in band")
	assert_eq(v.fields.map(func(f: FramesAndBands.Field) -> String: return f.text()),
			["startup 26 (24-30)", "active 4 (3-6)", "recovery 30 (24-36)"])
	assert_eq(v.distance.map(func(l: MoveBands.DistanceLine) -> String: return l.text),
			["touches from 3.3 m: 18.0 cm in", "touches from 2.8 m", "misses from 4.05 m"])
	assert_eq(v.bars.map(func(b: FramesAndBands.Bar) -> Array: return [b.name, b.from, b.to]),
			[["startup", 0, 26], ["active", 26, 30], ["recovery", 30, 60]])
	assert_eq(v.startup_band, [24, 30], "where the first active frame should fall")


func test_a_move_out_of_its_timing_band() -> void:
	# today's Heaven Splitter, on the stand-ins: 22/4/28 against 42-54, 4-8, 36-48
	var row: Dictionary = FrameDataTable.shared().row(&"katana", &"k_h2")
	var waiting: FramesAndBands = FramesAndBands.build(Moves.KATANA, &"k_h2", row, {}, MoveBands.shared())
	assert_false(waiting.in_band())
	assert_true(waiting.waiting)
	assert_eq(waiting.verdict(), "out of band: waiting for its family")
	assert_eq(waiting.fields.map(func(f: FramesAndBands.Field) -> bool: return f.ok), [false, true, false],
			"the startup and the recovery are out, the active frames in")
	var off: FramesAndBands = FramesAndBands.build(Moves.KATANA, &"k_h2", row, {}, _bands_off(&"k_h2"))
	assert_eq(off.verdict(), "out of band: CI will fail")


func test_the_re_keyed_right_cut_is_in_band() -> void:
	var row: Dictionary = FrameDataTable.shared().row(&"katana", &"k_l1")
	var v: FramesAndBands = FramesAndBands.build(Moves.KATANA, &"k_l1", row, {}, MoveBands.shared())
	assert_false(v.waiting, "off the waiting list (task 31)")
	assert_eq(v.verdict(), "in band")
	assert_eq(v.fields.map(func(f: FramesAndBands.Field) -> String: return f.text()),
			["startup 28 (24-30)", "active 4 (3-6)", "recovery 28 (24-36)"])


func test_a_move_that_misses_from_its_distance_band() -> void:
	var v: FramesAndBands = FramesAndBands.build(_point(0.9), &"k_l1", IN_BAND, {}, _bands_off())
	assert_true(v.fields.all(func(f: FramesAndBands.Field) -> bool: return f.ok), "on time")
	assert_false(v.in_band(), "but short")
	assert_eq(v.distance[0].text, "no touch from 3.3 m")
	assert_false(v.distance[0].ok)
	assert_eq(v.verdict(), "out of band: CI will fail")


func test_a_counter_lunge_has_no_band_test_until_milestone_2() -> void:
	var v: FramesAndBands = FramesAndBands.build(Moves.KATANA, &"k_lunge", FrameDataTable.shared().row(&"katana", &"k_lunge"), {}, MoveBands.shared())
	assert_eq(v.verdict(), "no band test until milestone 2")
	assert_eq(v.fields.size(), 0)
	assert_eq(v.bars.size(), 3, "its frames still show")


func test_the_rules_ruler_starts_at_the_wind_up_two_rules_frames_to_a_source_frame() -> void:
	var v: FramesAndBands = FramesAndBands.build(_point(1.1955), &"k_l1", IN_BAND, {"windup": 3.5}, _bands_off())
	assert_eq(v.to_source(0.0), 3.5)
	assert_eq(v.to_source(26.0), 16.5)
	assert_eq(v.to_rules(16.5), 26.0)


func test_a_hidden_weapon_s_move_has_no_band_test_until_milestone_2() -> void:
	var v: FramesAndBands = FramesAndBands.build(Moves.GREATSWORD, &"g_l1", FrameDataTable.shared().row(&"greatsword", &"g_l1"), {}, MoveBands.shared())
	assert_eq(v.verdict(), "no band test until milestone 2")
