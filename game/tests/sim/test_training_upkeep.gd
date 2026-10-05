extends GutTest
## Training's upkeep in the rules (TrainingUpkeep, task 23.1): getting up at
## once after a K.O., the refill 90 frames after the last hurt (2 HP a frame,
## the dummy's posture draining 2 a frame, the ultimate back at full HP), and
## the dummy re-arming after 240 frames disarmed. Through the rules' public
## surface, with the upkeep stepped after each world step as the host does.

const H := preload("res://tests/sim/sim_helpers.gd")

## The spec's numbers (the demo's Game.trainingUpkeep()).
const REFILL_AFTER: int = 90
const REFILL_RATE: float = 2.0
const REARM_AFTER: int = 240


func after_each() -> void:
	H.dispose_all()


## Steps the world n times with idle input, the upkeep after each step.
func _run(W: World, up: TrainingUpkeep, n: int, p0: Callable = Callable()) -> void:
	for i: int in n:
		var in0: RawInput = H.idle() if p0.is_null() else p0.call(i)
		W.step([in0, H.idle()])
		up.step()


## Sets a fighter's HP between steps and runs the step that notices it:
## that step's frame is the hurt's.
func _hurt(W: World, up: TrainingUpkeep, f: Fighter, hp: float) -> void:
	f.hp = hp
	_run(W, up, 1)


func _world() -> World:
	var W: World = H.make_world(Moves.KATANA, Moves.GREATSWORD)
	H.run(W, 1)
	return W


# ------------------------------------------------------------------ K.O.

func test_a_ko_in_training_stands_up_at_once() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	var dummy: Fighter = W.fighters[1]
	dummy.hp = 1.0
	dummy.posture = 40.0
	dummy.ult_used = true
	var rec: H.Rec = H.Rec.new()
	var stood: bool = false
	for i: int in 60:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		rec.collect(W)
		var downed: bool = dummy.state == &"ko"
		up.step()
		if downed:
			stood = true
			assert_eq(dummy.state, &"free", "up the same step")
			assert_eq(dummy.hp, SimConst.HP_MAX, "full HP")
			assert_eq(dummy.posture, 0.0, "posture empty")
			assert_false(dummy.ult_used, "the ultimate back")
			assert_false(dummy.ult_announced)
			assert_false(W.ko_resolved, "the K.O. is cleared")
			assert_eq(W.slowmo_frames, 0, "no slow motion")
			break
	assert_true(rec.has(&"ko"), "the light knocked the dummy out")
	assert_true(stood)


func test_the_player_stands_up_too() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	var me: Fighter = W.fighters[0]
	me.set_state(&"ko")
	up.step()
	assert_eq(me.state, &"free")
	assert_eq(me.hp, SimConst.HP_MAX)


# ------------------------------------------------------------------ refill

func test_hp_refills_2_a_frame_from_90_frames_after_the_last_hurt() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	_run(W, up, 5)
	var me: Fighter = W.fighters[0]
	_hurt(W, up, me, 50.0)
	_run(W, up, REFILL_AFTER)
	assert_eq(me.hp, 50.0, "nothing for 90 frames")
	_run(W, up, 1)
	assert_eq(me.hp, 52.0, "then 2 a frame")
	_run(W, up, 4)
	assert_eq(me.hp, 60.0)
	_run(W, up, 100)
	assert_eq(me.hp, SimConst.HP_MAX, "up to full and no more")


func test_a_new_hurt_restarts_the_wait() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	var me: Fighter = W.fighters[0]
	_hurt(W, up, me, 50.0)
	_run(W, up, 60)
	_hurt(W, up, me, 40.0)
	_run(W, up, REFILL_AFTER)
	assert_eq(me.hp, 40.0, "the wait counts from the second hurt")
	_run(W, up, 1)
	assert_eq(me.hp, 42.0)


func test_only_the_dummy_s_posture_drains_with_the_refill() -> void:
	var W: World = _world()
	var twin: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	for w: World in [W, twin]:
		w.fighters[0].posture = 60.0
		w.fighters[1].posture = 60.0
	# both hurt, so both refill: only the dummy's posture drains
	for w: World in [W, twin]:
		w.fighters[0].hp = 70.0
		w.fighters[1].hp = 90.0
	W.step([H.idle(), H.idle()])
	up.step()
	twin.step([H.idle(), H.idle()])
	for i: int in REFILL_AFTER + 10:
		W.step([H.idle(), H.idle()])
		twin.step([H.idle(), H.idle()])
		up.step()
	assert_eq(W.fighters[0].posture, twin.fighters[0].posture, "the player's posture is the rules' own")
	assert_almost_eq(twin.fighters[1].posture - W.fighters[1].posture, 10 * REFILL_RATE, 0.001, "the dummy's drains 2 a frame more")


func test_full_hp_gives_the_ultimate_back() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	var me: Fighter = W.fighters[0]
	me.ult_used = true
	_hurt(W, up, me, 97.0)
	_run(W, up, REFILL_AFTER + 1)
	assert_true(me.ult_used, "not yet at full")
	_run(W, up, 1)
	assert_eq(me.hp, SimConst.HP_MAX)
	assert_false(me.ult_used, "back at full HP")


func test_refill_off_leaves_hp_and_posture_alone() -> void:
	var W: World = _world()
	var twin: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	up.refill = false
	for w: World in [W, twin]:
		w.fighters[0].hp = 50.0
		w.fighters[1].posture = 60.0
	for i: int in 200:
		W.step([H.idle(), H.idle()])
		twin.step([H.idle(), H.idle()])
		up.step()
	assert_eq(W.fighters[0].hp, 50.0)
	assert_eq(W.fighters[1].posture, twin.fighters[1].posture)


# ------------------------------------------------------------------ re-arming

func test_the_dummy_re_arms_after_240_frames_disarmed_and_free() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	var dummy: Fighter = W.fighters[1]
	dummy.disarm(W.fighters[0], &"parried")
	assert_false(dummy.armed)
	assert_not_null(W.weapon_of(1), "its weapon on the floor")
	_run(W, up, 1) # the step that notices the disarm
	_run(W, up, REARM_AFTER)
	assert_false(dummy.armed, "not before 240 frames")
	_run(W, up, 1)
	assert_true(dummy.armed, "re-armed")
	assert_null(W.weapon_of(1), "the dropped weapon is gone")


func test_the_dummy_waits_while_it_is_hurt() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	var dummy: Fighter = W.fighters[1]
	dummy.disarm(W.fighters[0], &"parried")
	_run(W, up, 200)
	_hurt(W, up, dummy, dummy.hp - 5.0)
	_run(W, up, REARM_AFTER)
	assert_false(dummy.armed, "the wait counts from the hurt")
	_run(W, up, 1)
	assert_true(dummy.armed)


func test_the_wait_counts_from_the_disarm_however_long_unhurt_before() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	_run(W, up, REARM_AFTER + 50)
	var dummy: Fighter = W.fighters[1]
	dummy.disarm(W.fighters[0], &"parried")
	_run(W, up, 120)
	assert_false(dummy.armed, "240 frames disarmed, not 240 unhurt")
	_run(W, up, REARM_AFTER)
	assert_true(dummy.armed)


func test_the_player_is_never_re_armed() -> void:
	var W: World = _world()
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	var me: Fighter = W.fighters[0]
	me.disarm(W.fighters[1], &"parried")
	_run(W, up, REARM_AFTER + 60)
	assert_false(me.armed, "the player picks it up")
	assert_not_null(W.weapon_of(0))
