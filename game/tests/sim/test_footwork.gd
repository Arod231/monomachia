extends GutTest
## Starts, stops and pivots (milestone-1 task 57, stories 85-89): short rules
## states that move a fighter exactly as their clips travel (the frame-data
## table's profile rows, Footwork.PROFILE_CLIPS), with every action cutting
## in at once, a run or sprint stop running on when the stick goes the same
## way again and a run stop turning into a pivot when it goes back, and the
## tap step unchanged. The owner's answers of Oct 8: four ways each, one
## profile per kind, a pivot past 135° at the run's pace, a reversal out of a
## sprint playing the sprint stop first.

const H := preload("res://tests/sim/sim_helpers.gd")


func after_each() -> void:
	H.dispose_all()


## A world with fighter 0 `gap` m from fighter 1 holding `weapon`.
static func _world(gap: float = 20.0, weapon: WeaponDef = Moves.KATANA) -> World:
	return H.make_world(weapon, Moves.KATANA, gap)


## Steps `W` `n` times with fighter 0 on `inp`.
static func _hold(W: World, inp: RawInput, n: int) -> void:
	for i: int in n:
		W.step([inp, H.idle()])


## Fighter 0's moves along `dir` (world unit vector) over each of `n` steps on
## `inp`.
static func _moves(W: World, inp: RawInput, n: int, dir: V2) -> Array[float]:
	var a: Fighter = W.fighters[0]
	var out: Array[float] = []
	for i: int in n:
		var x: float = a.pos.x
		var z: float = a.pos.z
		W.step([inp, H.idle()])
		out.append((a.pos.x - x) * dir.x + (a.pos.z - z) * dir.z)
	return out


static func _forward(W: World) -> V2:
	var a: Fighter = W.fighters[0]
	return SimMath.norm2(W.fighters[1].pos.x - a.pos.x, W.fighters[1].pos.z - a.pos.z)


## That each of fighter 0's moves matches kind `kind`'s profile frame by frame.
func _assert_profile(moved: Array[float], kind: StringName) -> void:
	assert_eq(moved.size(), Footwork.frames(kind))
	for f: int in moved.size():
		assert_almost_eq(moved[f], Footwork.travel_at(kind, f + 1), 1e-6, "%s frame %d moves as its clip travels" % [kind, f + 1])


# ------------------------------------------------------------------ the table

func test_each_kind_takes_the_spec_s_time_and_distance_from_its_clip() -> void:
	# the spec's momentum and gait table: guarded starts and stops within 6
	# frames; run stops and pivots 12-15 frames and up to about 0.5 m; the
	# sprint stop about 20 frames and 1 m
	assert_between(Footwork.frames(Footwork.START), 1, 6, "a guarded start")
	assert_between(Footwork.frames(Footwork.STOP), 1, 6, "a guarded stop")
	assert_between(Footwork.frames(Footwork.RUN_STOP), 12, 15, "a run stop")
	assert_between(Footwork.path(Footwork.RUN_STOP), 0.3, 0.6, "a run stop's distance")
	assert_between(Footwork.frames(Footwork.PIVOT), 12, 15, "a pivot")
	assert_between(Footwork.path(Footwork.PIVOT), 0.3, 0.6, "a pivot's path out and back")
	assert_lt(Footwork.travel_at(Footwork.PIVOT, Footwork.frames(Footwork.PIVOT)), 0.0, "a pivot ends going back")
	assert_between(Footwork.frames(Footwork.SPRINT_STOP), 18, 22, "a sprint stop")
	assert_between(Footwork.distance(Footwork.SPRINT_STOP), 0.8, 1.2, "a sprint stop's distance")


func test_the_starts_stops_and_pivots_are_off_the_not_keyed_list() -> void:
	for name: String in ["start", "stop", "pivot"]:
		assert_false(FrameDataTable.shared().not_keyed_yet.has(name), "%s is keyed" % name)
	for kind: StringName in Footwork.KINDS:
		assert_has(FrameDataRows.TRAVEL_CLIPS, Footwork.PROFILE_CLIPS[kind], "%s's travel is in the table" % kind)


# ------------------------------------------------------------------ the states

func test_a_guarded_start_sets_off_as_its_clip_travels() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_hold(W, H.btn(Btn.BLOCK), 10)
	var dir: V2 = _forward(W)
	var inp: RawInput = H.move(0.0, 1.0, Btn.BLOCK)
	W.step([inp, H.idle()])
	assert_eq(a.state, &"footwork", "setting off while blocking starts at once")
	assert_eq(a.footwork_kind, Footwork.START)
	assert_true(a.blocking, "still blocking")
	var moved: Array[float] = [_last(W, a)]
	moved.append_array(_moves(W, inp, Footwork.frames(Footwork.START) - 1, dir))
	_assert_profile(moved, Footwork.START)
	assert_eq(a.state, &"free", "then the guarded shuffle")


func test_a_guarded_stop_and_a_walk_s_stop_settle_as_the_stop_clip_travels() -> void:
	for buttons: Array in [[Btn.BLOCK], []]:
		var W: World = _world()
		var a: Fighter = W.fighters[0]
		var walk: RawInput = H.move(0.0, 1.0, Btn.BLOCK) if not buttons.is_empty() else H.move(0.0, 0.5)
		_hold(W, walk, 40)
		var dir: V2 = _forward(W)
		var let_go: RawInput = H.btn(Btn.BLOCK) if not buttons.is_empty() else H.idle()
		var moved: Array[float] = _moves(W, let_go, Footwork.frames(Footwork.STOP), dir)
		assert_eq(a.state, &"free")
		_assert_profile(moved, Footwork.STOP)
		_hold(W, let_go, 1)
		assert_almost_eq(JsMath.hypot(a.vel.x, a.vel.z), 0.0, 0.05, "standing")


func test_letting_go_at_a_run_plays_the_run_stop() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(0.0, 1.0), 40)
	var dir: V2 = _forward(W)
	W.step([H.idle(), H.idle()])
	assert_eq(a.state, &"footwork")
	assert_eq(a.footwork_kind, Footwork.RUN_STOP)
	assert_eq(a.footwork_way, &"forward")
	var moved: Array[float] = [_last(W, a)]
	moved.append_array(_moves(W, H.idle(), Footwork.frames(Footwork.RUN_STOP) - 1, dir))
	_assert_profile(moved, Footwork.RUN_STOP)
	assert_eq(a.state, &"free")


func test_a_run_stop_strafing_left_goes_the_left_way() -> void:
	var W: World = _world(6.0)
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(-1.0, 0.0), 40)
	W.step([H.idle(), H.idle()])
	assert_eq(a.footwork_kind, Footwork.RUN_STOP)
	assert_eq(a.footwork_way, &"left")


func test_pushing_the_same_way_again_runs_on_at_once() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(0.0, 1.0), 40)
	_hold(W, H.idle(), 4)
	assert_eq(a.state, &"footwork")
	W.step([H.move(0.0, 1.0), H.idle()])
	assert_eq(a.state, &"free", "back into the run")
	assert_true(a.moving)


func test_pushing_back_during_a_run_stop_pivots() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(0.0, 1.0), 40)
	_hold(W, H.idle(), 3)
	W.step([H.move(0.0, -1.0), H.idle()])
	assert_eq(a.state, &"footwork")
	assert_eq(a.footwork_kind, Footwork.PIVOT)


func test_swinging_the_stick_back_at_a_run_pivots_as_its_clip_travels() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(0.0, 1.0), 40)
	var dir: V2 = _forward(W)
	var back: RawInput = H.move(0.0, -1.0)
	W.step([back, H.idle()])
	assert_eq(a.state, &"footwork")
	assert_eq(a.footwork_kind, Footwork.PIVOT)
	var moved: Array[float] = [_last(W, a)]
	moved.append_array(_moves(W, back, Footwork.frames(Footwork.PIVOT) - 1, dir))
	_assert_profile(moved, Footwork.PIVOT)
	assert_eq(a.state, &"free")
	assert_lt(a.vel.x * dir.x + a.vel.z * dir.z, 0.0, "handing on going back")


func test_a_turn_of_90_degrees_steers_through_the_blend() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(0.0, 1.0), 40)
	W.step([H.move(1.0, 0.0), H.idle()])
	assert_eq(a.state, &"free", "no pivot under 135 degrees")


func test_letting_go_of_a_sprint_or_reversing_it_plays_the_sprint_stop() -> void:
	for back: bool in [false, true]:
		var W: World = _world(40.0)
		var a: Fighter = W.fighters[0]
		_hold(W, H.move(0.0, 1.0, Btn.SPRINT), 60)
		var dir: V2 = _forward(W)
		var inp: RawInput = H.move(0.0, -1.0, Btn.SPRINT) if back else H.idle()
		W.step([inp, H.idle()])
		assert_eq(a.state, &"footwork")
		assert_eq(a.footwork_kind, Footwork.SPRINT_STOP, "reversing" if back else "letting go")
		var moved: Array[float] = [_last(W, a)]
		moved.append_array(_moves(W, inp, Footwork.frames(Footwork.SPRINT_STOP) - 1, dir))
		_assert_profile(moved, Footwork.SPRINT_STOP)


func test_every_action_cuts_into_a_run_stop_on_its_first_frame() -> void:
	# [buttons pressed, the state it starts]
	for spec: Array in [[Btn.LIGHT, &"attack"], [Btn.HEAVY, &"attack"], [Btn.DODGE, &"backstep"], [Btn.JUMP, &"jump"]]:
		var W: World = _world()
		var a: Fighter = W.fighters[0]
		_hold(W, H.move(0.0, 1.0), 40)
		_hold(W, H.idle(), 3)
		assert_eq(a.state, &"footwork")
		W.step([H.btn(spec[0]), H.idle()])
		assert_eq(a.state, spec[1], "%s cuts in at once" % spec[1])


func test_a_block_cuts_into_a_run_stop_with_no_momentum() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(0.0, 1.0), 40)
	_hold(W, H.idle(), 3)
	W.step([H.btn(Btn.BLOCK), H.idle()])
	assert_eq(a.state, &"free")
	assert_true(a.blocking)
	assert_lt(JsMath.hypot(a.vel.x, a.vel.z), 0.7, "the run's leftover only in the blend")


func test_a_parry_press_is_taken_during_footwork() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(0.0, 1.0), 40)
	_hold(W, H.idle(), 3)
	assert_true(a.is_guard_capable(), "footwork is guard-capable")


func test_the_greatsword_keeps_its_deceleration() -> void:
	# no footwork until milestone 2's clips
	var W: World = _world(20.0, Moves.GREATSWORD)
	var a: Fighter = W.fighters[0]
	_hold(W, H.move(0.0, 1.0), 40)
	W.step([H.idle(), H.idle()])
	assert_eq(a.state, &"free")


func test_the_tap_step_keeps_its_instant_start_and_distance() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	var dir: V2 = _forward(W)
	W.step([H.move(0.0, 1.0), H.idle()])
	assert_eq(a.state, &"step", "a push from neutral steps at once")
	var first: float = _last(W, a)
	assert_almost_eq(first, SimConst.MOVE_STEP_DIST / float(SimConst.MOVE_STEP_FRAMES), 1e-6, "at full pace from its first frame")


## How far fighter 0 moved along the opponent's way on the step just taken
## (from its velocity: the world integrates it).
static func _last(W: World, a: Fighter) -> float:
	var dir: V2 = _forward(W)
	return (a.vel.x * dir.x + a.vel.z * dir.z) * SimConst.DT
