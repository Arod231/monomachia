extends GutTest
## The duelling-distance reach test (task 7.14). Every light of a weapon's
## string with a swing, played from standing at a defender standing at its
## weapon's duelling distance (WeaponDef.duel_distance: Katana 2.5 m,
## Greatsword 3.0, Daggers 2.0, bare hands 1.6), puts the last 15-20 cm of its
## blade into them: the most blade inside the defender's capsule at any
## moment of the active ticks (SwingReach.touches(), BladeSweep's length
## inside). Its lunge ends on the frame it first touches, so the front foot
## lands on contact, and from 6 m it whiffs. Empty until the lights have
## swings; the check itself is tested on synthetic lights.

const RT := preload("res://tests/sim/reach_table.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const CUT: StringName = &"k_l1"
const MIN_INSIDE: float = 0.15
const MAX_INSIDE: float = 0.20
const WHIFF_FROM: float = 6.0


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
			inside = maxf(inside, c.length_inside)
		if inside < MIN_INSIDE or inside > MAX_INSIDE:
			out.append("%s: %.1f cm of blade inside from %.1f m, not 15-20 cm" % [at, inside * 100.0, w.duel_distance])
		var lunge_end: int = m.lunge_end if m.lunge_end != AttackDef.UNSET else m.startup + m.active
		if lunge_end != touches[0].frame:
			out.append("%s: the lunge ends on frame %d, the first touch is on %d" % [at, lunge_end, touches[0].frame])
	if SwingReach.first_contact(m, w, WHIFF_FROM, 0.0, body) != null:
		out.append("%s: touches from %.0f m" % [at, WHIFF_FROM])
	return out


## Every problem of every light of the string with a swing on `w`.
static func _weapon_problems(w: WeaponDef) -> Array[String]:
	var out: Array[String] = []
	for id: StringName in w.moves:
		var m: AttackDef = w.moves[id]
		if m.swing != null and RT.strikes(m) and RT.kind_of(w, id) == &"string_light":
			out.append_array(_problems(w, id))
	return out


func test_each_weapon_has_its_duelling_distance() -> void:
	var want: Dictionary[StringName, float] = {&"katana": 2.5, &"greatsword": 3.0, &"daggers": 2.0, &"fists": 1.6}
	for id: StringName in want:
		assert_eq(Moves.WEAPONS[id].duel_distance, want[id], String(id))


func test_every_light_with_a_swing_puts_15_to_20_cm_into_a_defender_at_the_duelling_distance() -> void:
	var problems: Array[String] = []
	for id: StringName in Moves.WEAPONS:
		problems.append_array(_weapon_problems(Moves.WEAPONS[id]))
	assert_eq(problems, [] as Array[String])


## A Katana with a straight blade of its own length and thickness (0.09 to
## 0.777 m along the hand's frame, 1.5 cm), whose Right Cut holds its point
## level and straight ahead, the grip `out` m in front at 1.2 m up: the point
## is 0.777 m further out (or `blade_tip`). From 2.5 m apart, Right Cut's
## 0.35 m lunge (done on frame 12, its first active frame) leaves the
## defender's capsule, grown by half the blade, 2.15 - 0.3575 = 1.7925 m
## away, so `out` - 1.0155 m of blade is inside.
static func _point(out: float, blade_tip: float = 0.777) -> WeaponDef:
	var key: Swing.KeyPose = SF.key(0, [0.0, 1.2, out], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0])
	var w: WeaponDef = SF.weapon(&"katana", {CUT: SF.held(Moves.KATANA.moves[CUT], {SF.RIGHT: key} as Dictionary[StringName, Swing.KeyPose])})
	w.blade = StrikeSegment.make(V3.make(0.0, 0.09, 0.0), V3.make(0.0, blade_tip, 0.0), 0.015)
	w.derive_reach()
	return w


static func _has(problems: Array[String], words: String) -> bool:
	for p: String in problems:
		if p.contains(words):
			return true
	return false


func test_the_check_passes_a_light_that_puts_17_cm_in_and_fails_a_graze_and_30_cm() -> void:
	assert_eq(_weapon_problems(_point(1.1905)), [] as Array[String], "17.5 cm in, the lunge ending on the touch")
	var graze: Array[String] = _weapon_problems(_point(1.0355))
	assert_true(_has(graze, "2.0 cm of blade inside"), "2 cm in only grazes: %s" % [graze])
	var deep: Array[String] = _weapon_problems(_point(1.3155))
	assert_true(_has(deep, "30.0 cm of blade inside"), "30 cm is too deep: %s" % [deep])
	var short: Array[String] = _weapon_problems(_point(0.9))
	assert_true(_has(short, "no touch from 2.5 m"), "one that falls short: %s" % [short])


func test_the_check_counts_the_blade_inside_not_how_deep_it_goes() -> void:
	# the blade held level across the front, pointing right, 1.8034 m out:
	# 2.15 - 1.8034 = 0.3466 m from the defender's axis it cuts a chord of
	# 2 * sqrt(0.3575² - 0.3466²) = 17.5 cm through the capsule, though only
	# 1.1 cm deep
	var w: WeaponDef = _point(1.0)
	var across: Swing.KeyPose = SF.key(0, [-0.3, 1.2, 1.8034], [1.0, 0.0, 0.0], [0.0, -1.0, 0.0])
	var cut: AttackDef = w.moves[CUT]
	cut.swing = SF.held(cut, {SF.RIGHT: across} as Dictionary[StringName, Swing.KeyPose])
	w.derive_reach()
	assert_eq(_weapon_problems(w), [] as Array[String], "17.5 cm of blade inside")


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
	assert_eq(_weapon_problems(w), [] as Array[String], "17.45 cm at its deepest")


func test_the_check_fails_a_lunge_that_ends_before_the_touch_and_a_light_that_reaches_6_m() -> void:
	# the grip 1.2 m out on a level slash: the sweep from 60° to 20° (frame
	# 12) passes wide of the defender 2.15 m away, and the one across the
	# front (frame 13) reaches them
	var w: WeaponDef = SF.weapon(&"katana", {CUT: SF.level_slash(Moves.KATANA.moves[CUT], 1.2, 60.0, -60.0, 1.2)})
	var late: Array[String] = _weapon_problems(w)
	assert_true(_has(late, "the lunge ends on frame 12, the first touch is on 13"), "%s" % [late])
	# a blade 6 m long reaches a defender 6 m away
	var long: Array[String] = _weapon_problems(_point(0.45, 6.0))
	assert_true(_has(long, "touches from 6 m"), "%s" % [long])
