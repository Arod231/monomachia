extends GutTest
## Sweeps decide hits for moves with swings (task 7.10): each active frame
## sweeps the attack's striking tracks against the defender's hurt capsule,
## the first touch decides the outcome in the demo's order, and no touch is a
## whiff. A move without a swing keeps the demo's cone. The swings are
## synthetic level slashes (swing_fixtures.gd) on Right Cut, whose active
## frames are 12 to 14 and which lunges 0.35 m: from 1.6 m apart it closes to
## 1.25 m, so a blade from 0.45 m out (the Katana's tip 1.23 m out) crosses a
## defender standing straight ahead. An unblockable sweeps a blade 10 cm
## thicker on every side (task 7.12).

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const CUT: StringName = &"k_l1"
const OUTCOMES: Array[StringName] = [&"hit", &"block", &"parry", &"whiff", &"evade"]

## The attack frames on which a sweep touched the defender, in the last _play().
var _touched: Array[int] = []
## The defender's lowest feet over the active frames, in the last _play().
var _lowest: float = INF


func after_each() -> void:
	H.dispose_all()


static func _cut() -> AttackDef:
	return SF.timed(Moves.KATANA.moves[CUT])


## Fighter 0 with a Katana whose Right Cut has `swing` (none: the cone), `gap`
## m from an idle Katana.
static func _world(swing: Swing, gap: float = 1.6) -> World:
	# without a swing: Right Cut as a stand-in with none (the cone)
	var w: WeaponDef = SF.weapon(&"katana", {CUT: swing})
	return H.make_world(w, Moves.KATANA, gap)


## Fighter 0 starts Right Cut and fighter 1 plays `defend` (a Callable of the
## step; none: idle) for 32 steps. Returns each outcome event as "<event> on
## <attack frame>".
func _play(W: World, defend: Callable = Callable()) -> Array[String]:
	_touched = []
	_lowest = INF
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var out: Array[String] = []
	var frame: int = -1
	for i: int in 32:
		# a parry ends the attack in the step it lands, so its frame is the one
		# the attack reached in that step
		var held: bool = W.hitstop > 0
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle() if defend.is_null() else defend.call(i)])
		frame = a.atk.frame if a.state == &"attack" else (frame if held else frame + 1)
		if a.state == &"attack":
			if a.blade_touch(b.hurt_capsule()) != null and not _touched.has(frame):
				_touched.append(frame)
			if frame > _cut().startup and frame <= _cut().startup + _cut().active:
				_lowest = minf(_lowest, b.pos.y)
		for e: Dictionary in W.drain_events():
			if OUTCOMES.has(e["t"]):
				out.append("%s on %d" % [e["t"], frame])
	return out


## The active frames of the last _play() on which a sweep touched.
func _active_touches() -> Array[int]:
	var out: Array[int] = []
	for f: int in _touched:
		if f > _cut().startup and f <= _cut().startup + _cut().active:
			out.append(f)
	return out


static func _tap(button: int, at: int) -> Callable:
	return func(i: int) -> RawInput: return H.btn(button) if i == at else H.idle()


func test_a_blade_through_the_defender_hits_and_one_above_or_behind_misses() -> void:
	assert_eq(_play(_world(SF.level_slash(_cut(), 1.2))), ["hit on 13"] as Array[String],
			"a level slash at 1.2 m cuts through")
	# 45 cm over the head, which the capsule's reach ends at 1.7575 m
	assert_eq(_play(_world(SF.level_slash(_cut(), 2.2))), ["whiff on 15"] as Array[String],
			"a level slash at 2.2 m passes over")
	assert_eq(_active_touches(), [] as Array[int], "touching on no active frame")
	# the grip 2.6 m out: the blade passes beyond the defender's back
	assert_eq(_play(_world(SF.level_slash(_cut(), 1.2, 60.0, -60.0, 2.6))), ["whiff on 15"] as Array[String],
			"a level slash behind the defender passes them")
	assert_eq(_active_touches(), [] as Array[int], "touching on no active frame")
	assert_eq(_play(_world(null)), ["hit on 12"] as Array[String], "without a swing, the cone hits")


func test_a_low_sweep_misses_a_jumper() -> void:
	var low: Swing = SF.level_slash(_cut(), 0.2)
	assert_eq(_play(_world(low)), ["hit on 13"] as Array[String], "a blade 20 cm up cuts a standing defender's shins")
	var jump: Callable = _tap(Btn.JUMP, 5)
	assert_eq(_play(_world(low), jump), ["whiff on 15"] as Array[String], "and passes under a jumping one")
	assert_gt(_lowest, 0.3, "who is in the air through the active frames")
	assert_eq(_play(_world(null), jump), ["hit on 12"] as Array[String],
			"where the cone hits them: Right Cut isn't one the demo lets a jump dodge")


func test_the_hit_lands_on_the_first_touch_and_a_touch_after_the_active_frames_whiffs() -> void:
	# from 90° right to 30° left, 40° a frame: the blade first reaches the
	# defender straight ahead on the sweep from 50° to 10°, frame 13
	assert_eq(_play(_world(SF.level_slash(_cut(), 1.2, 90.0, -30.0))), ["hit on 13"] as Array[String],
			"the hit lands on the first touch")
	assert_eq(_touched.slice(0, 1), [13] as Array[int], "the first frame that touched")
	# 90° to 50° through the active frames, then on through the defender by
	# frame 17
	var late: Swing = SF.level_swing(_cut(), 1.2, {7: 90.0, 11: 90.0, 14: 50.0, 17: -30.0} as Dictionary[int, float], 0.45, [7])
	assert_eq(_play(_world(late)), ["whiff on 15"] as Array[String], "a blade that only touches later whiffs")
	assert_gt(_touched.size(), 0, "though it touches")
	for f: int in _touched:
		assert_gt(f, _cut().startup + _cut().active, "after the active frames (frame %d)" % f)


func test_a_parry_timed_to_the_first_touch_parries_and_block_blocks() -> void:
	var cut: Swing = SF.level_slash(_cut(), 1.2, 90.0, -30.0)
	# block pressed on frame 13, as the blade first touches
	var parry: Callable = _tap(Btn.BLOCK, 13)
	assert_eq(_play(_world(cut), parry), ["parry on 13"] as Array[String], "a parry on the first touch")
	assert_eq(_play(_world(null), parry), ["hit on 12"] as Array[String], "where the cone's hit lands a frame before it")
	var hold: Callable = func(_i: int) -> RawInput: return H.btn(Btn.BLOCK)
	assert_eq(_play(_world(cut), hold), ["block on 13"] as Array[String], "a held block blocks the first touch")


## Fighter 0 with a Katana whose Right Cut holds its point straight at the
## defender, flagged unblockable or not (nothing else differs), `gap` m from
## an idle Katana. The grip is 1.2 m up and 0.45 m out with the edge down, so
## the point is 0.777 m further out (and 7.7 cm up, the curve).
static func _point_world(unblockable: bool, gap: float) -> World:
	var point: Swing.KeyPose = SF.key(0, [0.0, 1.2, 0.45], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0])
	var w: WeaponDef = SF.weapon(&"katana", {CUT: SF.held(_cut(), {SF.RIGHT: point} as Dictionary[StringName, Swing.KeyPose])})
	(w.moves[CUT] as AttackDef).unblockable = unblockable
	return H.make_world(w, Moves.KATANA, gap)


func test_an_unblockable_sweeps_a_blade_10_cm_thicker_and_reaches_that_much_further() -> void:
	var normal: World = _point_world(false, 1.99)
	var thick: World = _point_world(true, 1.99)
	for W: World in [normal, thick]:
		W.step([H.btn(Btn.LIGHT), H.idle()])
	assert_almost_eq(normal.fighters[0].blade_segments()[0].half_thickness, 0.0075, 1e-12,
			"Right Cut sweeps half the Katana's 1.5 cm")
	assert_almost_eq(thick.fighters[0].blade_segments()[0].half_thickness, 0.1075, 1e-12,
			"an unblockable one 10 cm more")
	# the lunge (0.35 m, done by frame 12) leaves the point 1.64 - 1.227 =
	# 0.413 m from the defender's axis: beyond the capsule's 0.35 m and half
	# the blade, within them with the 10 cm
	assert_eq(_play(_point_world(false, 1.99)), ["whiff on 15"] as Array[String], "the point stops 5.5 cm short")
	assert_eq(_play(_point_world(true, 1.99)), ["hit on 12"] as Array[String], "the unblockable's reaches 4.5 cm in")
	# 10 cm further back, the unblockable falls as short
	assert_eq(_play(_point_world(true, 2.09)), ["whiff on 15"] as Array[String], "and 10 cm further back, falls as short")
