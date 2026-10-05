extends GutTest
## Reach and arc derived from each swing (task 7.13). A swing's reach is how
## far its blade reaches across the ground from the fighter's feet through the
## active frames, plus half the thickness its sweep tests, without the lunge:
## the demo's meaning of a move's range. Its arc is twice the blade's widest
## bearing from the facing over those frames, 360 when it passes behind.
## SwingReach.first_contact() plays a move at a defender standing at a
## distance and bearing, lunge and turning included, and gives the frame it
## first touches and how deep.

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const CUT: StringName = &"k_l1"
const EPS: float = 1e-9


func after_each() -> void:
	H.dispose_all()


## Right Cut on a Katana with no swings (its baked one left off).
static func _cut() -> AttackDef:
	return SF.without_swings(&"katana").moves[CUT]


## A Katana whose Right Cut has `swing` and whose blade is a straight test
## blade, 0.1 to 0.8 m along the hand's frame and 2 cm thick, so the numbers
## work out by hand.
static func _straight(swing: Swing, unblockable: bool = false) -> WeaponDef:
	var w: WeaponDef = SF.weapon(&"katana", {CUT: swing})
	w.blade = StrikeSegment.make(V3.make(0.0, 0.1, 0.0), V3.make(0.0, 0.8, 0.0), 0.02)
	(w.moves[CUT] as AttackDef).unblockable = unblockable
	w.derive_reach()
	return w


func test_a_slash_reaches_as_far_as_its_tip_and_its_arc_spans_its_active_frames() -> void:
	# a level slash from 60° right to 60° left over the active frames, the
	# grip 0.45 m out and the blade pointing straight out: the tip is 1.25 m
	# out, and 1 cm more is half the blade. The settle, 80° left on frame 18,
	# is past the active frames.
	var swing: Swing = _straight(SF.level_slash(_cut())).moves[CUT].swing
	assert_almost_eq(swing.reach, 1.26, EPS, "the tip, 0.45 + 0.8 m out, and half the 2 cm blade")
	assert_almost_eq(swing.arc, 120.0, EPS, "60° either side")
	# from 30° right to 50° left, the grip 0.6 m out; the settle, 70° left on
	# frame 18, is past the active frames
	var wide: Swing = _straight(SF.level_slash(_cut(), 1.2, 30.0, -50.0, 0.6)).moves[CUT].swing
	assert_almost_eq(wide.reach, 1.41, EPS, "0.6 + 0.8 m out, and 1 cm")
	assert_almost_eq(wide.arc, 100.0, EPS, "twice the wider side's 50°")


func test_an_unblockable_reaches_its_bonus_further() -> void:
	var swing: Swing = _straight(SF.level_slash(_cut()), true).moves[CUT].swing
	assert_almost_eq(swing.reach, 1.36, EPS, "10 cm further")
	assert_almost_eq(swing.arc, 120.0, EPS, "the same arc")


func test_a_spin_that_passes_behind_has_an_arc_of_360() -> void:
	# 120° a frame from straight ahead round to the right and on round to
	# where it started: no tick has the blade straight behind, but it passes
	# behind between frames 12 and 13
	var degs: Dictionary[int, float] = {7: 0.0, 11: 0.0, 12: 120.0, 13: 240.0, 14: 360.0, 18: 380.0}
	var spin: Swing = _straight(SF.level_swing(_cut(), 1.2, degs, 0.45, [7, 18] as Array[int])).moves[CUT].swing
	assert_almost_eq(spin.arc, 360.0, EPS, "all the way round")
	assert_almost_eq(spin.reach, 1.26, EPS, "as far out as the slash")
	# 85° either side, which stops short of passing behind
	var wide: Swing = _straight(SF.level_slash(_cut(), 1.2, 85.0, -85.0)).moves[CUT].swing
	assert_almost_eq(wide.arc, 170.0, EPS, "170° stays 170°")


## Steps a world in which fighter 0, with `w`, starts Right Cut at an idle
## defender standing `distance` m away at `bearing` degrees to its right, and
## returns the first active frame its blades touched the defender and how
## deep, or [] for none.
func _stepped_first_touch(w: WeaponDef, distance: float, bearing: float) -> Array:
	var W: World = H.make_world(w, Moves.KATANA, distance)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var off: float = bearing * SimMath.DEG
	b.pos = SimMath.local_to_world(a.pos, a.yaw, V3.make(distance * JsMath.sin(off), 0.0, distance * JsMath.cos(off)))
	for i: int in 32:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		if a.state != &"attack":
			continue
		var f: int = a.atk.frame
		if f > _cut().startup and f <= _cut().startup + _cut().active:
			var touch: BladeSweep = a.blade_touch(b.hurt_capsule())
			if touch != null:
				return [f, touch.depth]
	return []


func test_first_contact_agrees_with_a_stepped_world() -> void:
	var w: WeaponDef = SF.weapon(&"katana", {CUT: SF.level_slash(_cut())})
	var body: FighterBody = FighterBody.of(&"")
	# 0.9 m: too close to lunge, so the sweep from 60° to 20° already touches
	# (at 1.0 m the Katana's curve holds its 20° pose 3.8 cm clear); 1.6 m:
	# the lunge to 1.25 m, and the sweep across the front; 2.2 m: short by the
	# lunge's end; 1.6 m at 40° right: the attacker turns to the defender as
	# it winds up
	var cases: Array[Array] = [[0.9, 0.0, 12], [1.6, 0.0, 13], [2.2, 0.0, -1], [1.6, 40.0, 13]]
	for c: Array in cases:
		var what: String = "%.1f m at %d°" % [c[0], c[1]]
		var want: Array = _stepped_first_touch(w, c[0], c[1])
		assert_eq(want[0] if not want.is_empty() else -1, c[2], "%s: the stepped world" % what)
		var got: SwingReach.Contact = SwingReach.first_contact(w.moves[CUT], w, c[0], c[1], body)
		if want.is_empty():
			assert_null(got, "%s: no contact" % what)
			continue
		assert_not_null(got, "%s: a contact" % what)
		if got != null:
			assert_eq(got.frame, want[0], "%s: the frame" % what)
			assert_almost_eq(got.depth, want[1], EPS, "%s: the depth" % what)


func test_a_move_reads_its_swings_reach_and_arc_and_without_one_its_authored_range_and_arc() -> void:
	assert_eq(_cut().reach(), 2.2, "Right Cut without a swing: its authored range")
	assert_eq(_cut().reach_arc(), 110.0, "and arc")
	var def: AttackDef = _straight(SF.level_slash(_cut())).moves[CUT]
	assert_almost_eq(def.reach(), 1.26, EPS, "with one: its swing's reach")
	assert_almost_eq(def.reach_arc(), 120.0, EPS, "and arc")
	assert_eq(def.range, 2.2, "the authored range stays for the counters' cones")


func test_the_weapons_reach_comes_from_its_light_starters_hand_keyed_swing() -> void:
	assert_eq(SF.without_swings(&"katana").reach, 2.1, "the Katana's authored reach while Right Cut has no swing")
	var other: WeaponDef = SF.without_swings(&"katana")
	other.moves[&"k_l2"].swing = SF.level_slash(other.moves[&"k_l2"])
	other.derive_reach()
	assert_eq(other.reach, 2.1, "a swing on another move leaves it")
	# a swing baked from a clip leaves the authored reach (its lunge was
	# lengthened to keep the reach table's distances; authored animation 20)
	assert_eq(Moves.KATANA.reach, 2.1, "Right Cut's swing, baked from a clip, leaves the Katana's authored reach")
	assert_eq(Moves.GREATSWORD.reach, 2.75, "and Heavy Swing's the Greatsword's")
	var w: WeaponDef = _straight(SF.level_slash(_cut()))
	assert_almost_eq(w.reach, 1.26, EPS, "a swing on the light starter gives it")


func test_the_computer_takes_a_move_as_a_threat_within_its_reach() -> void:
	# the reach, a fighter's radius, the lunge and 0.6 m: 2.2 + 0.42 + 0.35 +
	# 0.6 = 3.57 m for the cone, 1.26 + 0.42 + 0.35 + 0.6 = 2.63 m with the
	# straight blade's swing
	assert_true(AIBrain.threatens(_cut(), 3.5), "the cone's Right Cut at 3.5 m")
	assert_false(AIBrain.threatens(_cut(), 3.6), "and not at 3.6 m")
	var def: AttackDef = _straight(SF.level_slash(_cut())).moves[CUT]
	assert_true(AIBrain.threatens(def, 2.6), "the swing's at 2.6 m")
	assert_false(AIBrain.threatens(def, 2.7), "and not at 2.7 m")
	assert_true(AIBrain.threatens(Moves.KATANA.moves[&"k_thrust"], 10.0), "an unblockable at any distance, for its counter")


func test_the_dummy_keeps_its_practice_distance_until_its_light_starter_has_a_swing() -> void:
	var demo: Dictionary[StringName, float] = {&"katana": 2.2, &"greatsword": 2.6, &"daggers": 1.8, &"fists": 2.2}
	for id: StringName in demo:
		var w0: WeaponDef = SF.without_swings(id)
		assert_eq(TrainingBrain.practice_distance(w0), demo[id], "%s: the demo's distance" % id)
	assert_eq(TrainingBrain.practice_distance(Moves.KATANA), Moves.KATANA.reach, "the Katana's Right Cut is baked (task 9): its reach")
	var w: WeaponDef = _straight(SF.level_slash(_cut()))
	assert_almost_eq(TrainingBrain.practice_distance(w), 1.26, EPS, "with a swing on Right Cut, the weapon's reach")
