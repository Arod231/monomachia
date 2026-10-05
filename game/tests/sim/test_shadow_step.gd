extends GutTest
## Shadow Step, the Daggers' block ability (d_shadow, block + heavy by
## default): invulnerable through its first 20 frames, it carries the fighter
## round the opponent over its active frames (0.95 of a half-turn toward the
## held side, ending 1.35 m off), leaves the opponent unable to turn for 6
## frames and makes a light started within 30 frames of its end a backstab
## (1.6 times the damage). Authored-animation task 22 plays it from Roll01
## with the body hidden through the active frames (ClipDirector.blinks()).

const D: StringName = &"d_shadow"


func after_each() -> void:
	SimHelpers.dispose_all()


## Daggers against an idle Katana, 2.0 m apart.
func _world() -> World:
	return SimHelpers.make_world(Moves.DAGGERS, Moves.KATANA, 2.0)


## Starts the step (block held, heavy pressed) and steps through it; returns
## the world frame (after its step) on which the step readied the backstab,
## at the end of its active frames.
func _step_through(W: World, rec: SimHelpers.Rec, mx: float = 0.0) -> int:
	var a: Fighter = W.fighters[0]
	W.step([SimHelpers.move(mx, 0.0, Btn.BLOCK, Btn.HEAVY), SimHelpers.idle()])
	rec.collect(W)
	assert_eq(a.state, &"attack")
	assert_eq(a.atk.def.id if a.atk != null else &"", D, "block + heavy steps")
	var ready: int = -1
	while a.state == &"attack":
		W.step([SimHelpers.move(mx, 0.0), SimHelpers.idle()])
		rec.collect(W)
		if ready < 0 and rec.has(&"backstabReady"):
			ready = W.frame
	return ready


func test_the_step_carries_the_fighter_round_to_the_opponents_back() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var start: float = JsMath.atan2(a.pos.x - b.pos.x, a.pos.z - b.pos.z)
	var rec: SimHelpers.Rec = SimHelpers.Rec.new()
	var ready: int = _step_through(W, rec)
	assert_true(rec.has(&"backstabReady"), "it readies a backstab")
	assert_almost_eq(JsMath.hypot(a.pos.x - b.pos.x, a.pos.z - b.pos.z), 1.35, 0.05, "1.35 m off the opponent")
	var round_by: float = absf(wrapf(JsMath.atan2(a.pos.x - b.pos.x, a.pos.z - b.pos.z) - start, -PI, PI))
	assert_almost_eq(round_by, PI * 0.95, 0.05, "0.95 of a half-turn round them")
	assert_eq(b.blind_until, ready + 6, "the opponent can't turn for 6 frames after the step")


func test_the_opponent_cant_turn_while_blinded() -> void:
	var W: World = _world()
	var b: Fighter = W.fighters[1]
	_step_through(W, SimHelpers.Rec.new())
	# blinded again, turned away from the fighter: it holds there until the
	# blind ends
	b.blind_until = W.frame + 6
	b.yaw = wrapf(b.yaw + PI * 0.5, -PI, PI)
	var held: float = b.yaw
	while W.frame < b.blind_until:
		assert_eq(b.yaw, held, "frame %d: blinded, it can't turn" % W.frame)
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	SimHelpers.run(W, 3)
	assert_ne(b.yaw, held, "then it turns")


func test_the_held_side_sets_the_way_round() -> void:
	var sides: Array[float] = []
	for mx: float in [0.0, -1.0]:
		var W: World = _world()
		_step_through(W, SimHelpers.Rec.new(), mx)
		sides.append(W.fighters[0].pos.x - W.fighters[1].pos.x)
	assert_gt(absf(sides[0]), 0.0)
	assert_eq(signf(sides[0]), -signf(sides[1]), "held left, it circles the other way (%.2f vs %.2f)" % sides)


func test_the_step_is_invulnerable_through_its_first_40_frames() -> void:
	# 20 until its frames came from its clip at 1.0x, carried onto them
	# (milestone-1 task 17)
	var def: AttackDef = Moves.DAGGERS.moves[D]
	assert_eq(Array(def.invuln), [0, 40])
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	W.step([SimHelpers.btn(Btn.BLOCK, Btn.HEAVY), SimHelpers.idle()])
	while a.state == &"attack":
		var f: int = a.atk.frame
		assert_eq(a.is_invulnerable(), f >= 0 and f <= 40, "frame %d" % f)
		W.step([SimHelpers.idle(), SimHelpers.idle()])


func test_a_light_soon_after_is_a_backstab() -> void:
	var W: World = _world()
	var rec: SimHelpers.Rec = SimHelpers.Rec.new()
	_step_through(W, rec)
	assert_eq(W.fighters[0].state, &"free")
	SimHelpers.run(W, 30, SimHelpers.tap_at(0, Btn.LIGHT), Callable(), rec)
	var hit: Dictionary = rec.find(&"hit")
	assert_false(hit.is_empty(), "the light lands")
	assert_true(hit.get("backstab", false), "a backstab")
	assert_almost_eq(float(hit.get("damage", 0.0)), Moves.DAGGERS.moves[&"d_l1"].damage * 1.6, 1e-6, "1.6 times the damage")


func test_a_light_after_the_window_is_not_a_backstab() -> void:
	var W: World = _world()
	var rec: SimHelpers.Rec = SimHelpers.Rec.new()
	_step_through(W, rec)
	SimHelpers.run(W, 31)
	rec = SimHelpers.Rec.new()
	W.fighters[0].pos = V3.make(W.fighters[1].pos.x, 0.0, W.fighters[1].pos.z - 1.35)
	W.fighters[0].yaw = 0.0
	SimHelpers.run(W, 30, SimHelpers.tap_at(0, Btn.LIGHT), Callable(), rec)
	var hit: Dictionary = rec.find(&"hit")
	assert_false(hit.is_empty(), "the light lands")
	assert_false(hit.get("backstab", true), "too late for a backstab")
