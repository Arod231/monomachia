extends GutTest
## The duelling-distance reach test (task 7.14). Every light of a weapon's
## string with a swing, played from standing at a defender standing at its
## weapon's duelling distance (WeaponDef.duel_distance: Katana 3.3 m and bare
## hands 1.85 since KE task 3, Greatsword 3.35 and Daggers 2.3 since KE task
## 4), puts the last 15-20 cm of its blade into them: the most blade inside
## the defender's capsule at any moment of the active ticks
## (SwingReach.touches(), BladeSweep's length inside); bare hands' fist, shorter than that across its knuckles, goes
## 15-20 cm deep (SwingReach.inside(), authored-animation task 24). Its
## lunge ends on the frame it first touches, so the front foot lands on
## contact, and from 6 m it whiffs. The check itself is tested on synthetic
## lights. Since milestone-1 task 17 the Greatsword's and the Daggers' moves
## play their clips at 1.0x with no band test until milestone 2 re-keys them
## (the spec's P10): what they get wrong is printed, not failed
## (MILESTONE_2). Since milestone-1 task 18 a Katana or bare-hands light
## taken off the band tables' waiting list is held by the distance-band test
## (test_move_bands.gd) instead, so this guards today's reach only for the
## moves still waiting (still_waits()).

const RT := preload("res://tests/sim/reach_table.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const CUT: StringName = &"k_l1"
const MIN_INSIDE: float = 0.15
const MAX_INSIDE: float = 0.20
## Bare hands' lights go up to 21 cm deep on KE task 3's taller bodies, until
## their re-keys (the owner's choice).
const FISTS_MAX_INSIDE: float = 0.21
const WHIFF_FROM: float = 6.0
## The synthetic lights below are worked out for Right Cut's lunge ending on
## frame 12, the demo's; its baked swing ends it on 13 (authored-animation
## task 9).
const DEMO_LUNGE_END: int = 12
## The weapons whose reach waits for milestone 2.
const MILESTONE_2: Array[StringName] = [&"greatsword", &"daggers"]


## What light `id` of `w` gets wrong against the rule, or nothing.
static func _problems(w: WeaponDef, id: StringName) -> Array[String]:
	var m: AttackDef = w.moves[id]
	var body: FighterBody = FighterBody.of(&"")
	var at: String = "%s.%s" % [w.id, id]
	var out: Array[String] = []
	var touches: Array[SwingReach.Contact] = SwingReach.touches(m, w, w.duel_distance, 0.0, body)
	if touches.is_empty():
		out.append("%s: no touch from %.1f m" % [at, w.duel_distance])
	else:
		var inside: float = 0.0
		for c: SwingReach.Contact in touches:
			inside = maxf(inside, SwingReach.inside(c, w))
		var most: float = FISTS_MAX_INSIDE if w.id == &"fists" else MAX_INSIDE
		if inside < MIN_INSIDE or inside > most:
			out.append("%s: %.1f cm of blade inside from %.1f m, not 15-%.0f cm" % [at, inside * 100.0, w.duel_distance, most * 100.0])
		var lunge_end: int = m.lunge_end if m.lunge_end != AttackDef.UNSET else m.startup + m.active
		if lunge_end != touches[0].frame:
			out.append("%s: the lunge ends on frame %d, the first touch is on %d" % [at, lunge_end, touches[0].frame])
	if SwingReach.first_contact(m, w, WHIFF_FROM, 0.0, body) != null:
		out.append("%s: touches from %.0f m" % [at, WHIFF_FROM])
	return out


## Whether today's reach checks still guard move `id` of `w`: every move of
## every move the band tests don't hold (MoveBands.is_held()): a weapon with
## no bands, a Counter Lunge, and a banded weapon's moves still on the
## waiting list.
static func still_waits(w: WeaponDef, id: StringName) -> bool:
	var kind: StringName = StringName(FrameDataTable.shared().row(w.id, id).get("kind", ""))
	return not MoveBands.shared().is_held(w.id, id, kind)


## Every problem of every light of the string with a swing on `w`.
static func _weapon_problems(w: WeaponDef) -> Array[String]:
	var out: Array[String] = []
	for id: StringName in w.moves:
		var m: AttackDef = w.moves[id]
		if m.swing != null and RT.strikes(m) and RT.kind_of(w, id) == &"string_light" and still_waits(w, id):
			out.append_array(_problems(w, id))
	return out


func test_each_weapon_has_its_duelling_distance() -> void:
	var want: Dictionary[StringName, float] = {&"katana": 3.3, &"greatsword": 3.35, &"daggers": 2.3, &"fists": 1.85}
	for id: StringName in want:
		assert_eq(Moves.WEAPONS[id].duel_distance, want[id], String(id))


func test_a_fist_is_measured_by_its_depth_and_a_blade_by_its_length_inside() -> void:
	assert_true(SwingReach.measures_depth(Moves.FISTS), "the knuckles are shorter than the rule")
	for w: WeaponDef in [Moves.KATANA, Moves.GREATSWORD, Moves.DAGGERS]:
		assert_false(SwingReach.measures_depth(w), "%s: its blade" % w.id)
	var c: SwingReach.Contact = SwingReach.Contact.new()
	c.depth = 0.18
	c.length_inside = 0.07
	assert_eq(SwingReach.inside(c, Moves.FISTS), 0.18)
	assert_eq(SwingReach.inside(c, Moves.DAGGERS), 0.07)


func test_every_light_with_a_swing_puts_15_to_20_cm_into_a_defender_at_the_duelling_distance() -> void:
	var problems: Array[String] = []
	for id: StringName in Moves.WEAPONS:
		if MILESTONE_2.has(id):
			for p: String in _weapon_problems(Moves.WEAPONS[id]):
				gut.p("milestone 2: " + p)
			continue
		problems.append_array(_weapon_problems(Moves.WEAPONS[id]))
	assert_eq(problems, [] as Array[String])


## A Katana with a straight blade as thick as its own (0.09 to 1.507 m along
## the hand's frame, 1.5 cm), whose Right Cut holds its point level and
## straight ahead, the grip `out` m in front at 1.2 m up: the point is 1.507 m
## further out (or `blade_tip`). From 3.3 m apart, Right Cut's 0.35 m lunge
## (done on frame 12, its first active frame) leaves the defender's 0.42 m
## capsule, grown by half the blade, 2.95 - 0.4275 = 2.5225 m away, so
## `out` - 1.0155 m of blade is inside (the 0.777 m blade from 2.5 m before
## KE task 2, the 1.277 m one from 3.0 m before KE task 3).
static func _point(out: float, blade_tip: float = 1.507) -> WeaponDef:
	var key: Swing.KeyPose = SF.key(0, [0.0, 1.2, out], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0])
	var w: WeaponDef = SF.weapon(&"katana", {CUT: SF.held(Moves.KATANA.moves[CUT], {SF.RIGHT: key} as Dictionary[StringName, Swing.KeyPose])})
	w.blade = StrikeSegment.make(V3.make(0.0, 0.09, 0.0), V3.make(0.0, blade_tip, 0.0), 0.015)
	(w.moves[CUT] as AttackDef).lunge_end = DEMO_LUNGE_END
	w.derive_reach()
	return w


static func _has(problems: Array[String], words: String) -> bool:
	for p: String in problems:
		if p.contains(words):
			return true
	return false


func test_the_check_passes_a_light_that_puts_17_cm_in_and_fails_a_graze_and_30_cm() -> void:
	assert_eq(_problems(_point(1.1905), CUT), [] as Array[String], "17.5 cm in, the lunge ending on the touch")
	var graze: Array[String] = _problems(_point(1.0355), CUT)
	assert_true(_has(graze, "2.0 cm of blade inside"), "2 cm in only grazes: %s" % [graze])
	var deep: Array[String] = _problems(_point(1.3155), CUT)
	assert_true(_has(deep, "30.0 cm of blade inside"), "30 cm is too deep: %s" % [deep])
	var short: Array[String] = _problems(_point(0.9), CUT)
	assert_true(_has(short, "no touch from 3.3 m"), "one that falls short: %s" % [short])


func test_the_check_counts_the_blade_inside_not_how_deep_it_goes() -> void:
	# the blade held level across the front, pointing right, 2.5316 m out:
	# 2.95 - 2.5316 = 0.4184 m from the defender's axis it cuts a chord of
	# 2 * sqrt(0.4275² - 0.4184²) = 17.5 cm through the capsule, though only
	# 0.9 cm deep
	var w: WeaponDef = _point(1.0)
	var across: Swing.KeyPose = SF.key(0, [-0.3, 1.2, 2.5316], [1.0, 0.0, 0.0], [0.0, -1.0, 0.0])
	var cut: AttackDef = w.moves[CUT]
	cut.swing = SF.held(cut, {SF.RIGHT: across} as Dictionary[StringName, Swing.KeyPose])
	w.derive_reach()
	assert_eq(_problems(w, CUT), [] as Array[String], "17.5 cm of blade inside")


func test_the_check_measures_the_deepest_tick_not_the_first_touch() -> void:
	# the point pushed on through the active frames: 1.45 cm in on frame 12,
	# where it first touches and the lunge ends, then 8.45 and 17.45 cm
	var w: WeaponDef = _point(1.0)
	var keys: Array[Swing.KeyPose] = []
	for k: Array in [[7, 1.0, 0.0], [11, 1.0, 1.0], [12, 1.03, 1.0], [13, 1.1, 1.0], [14, 1.19, 1.0], [18, 1.19, 0.0]]:
		keys.append(SF.key(k[0], [0.0, 1.2, k[1]], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0], k[2]))
	var cut: AttackDef = w.moves[CUT]
	var swing: Swing = Swing.new(cut.total_frames(), {SF.RIGHT: keys[0]} as Dictionary[StringName, Swing.KeyPose])
	swing.add_track(SF.RIGHT, keys)
	cut.swing = swing
	w.derive_reach()
	assert_eq(_problems(w, CUT), [] as Array[String], "17.45 cm at its deepest")


func test_the_check_fails_a_lunge_that_ends_before_the_touch_and_a_light_that_reaches_6_m() -> void:
	# the grip 1.43 m out on a level slash: the sweep from 60° to 20° (frame
	# 12) passes wide of the defender, and the one across the front (frame
	# 13) reaches them
	var w: WeaponDef = SF.weapon(&"katana", {CUT: SF.level_slash(Moves.KATANA.moves[CUT], 1.2, 60.0, -60.0, 1.43)})
	(w.moves[CUT] as AttackDef).lunge_end = DEMO_LUNGE_END
	var late: Array[String] = _problems(w, CUT)
	assert_true(_has(late, "the lunge ends on frame 12, the first touch is on 13"), "%s" % [late])
	# a blade 6 m long reaches a defender 6 m away
	var long: Array[String] = _problems(_point(0.45, 6.0), CUT)
	assert_true(_has(long, "touches from 6 m"), "%s" % [long])
