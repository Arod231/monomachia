extends GutTest
## Gait speeds from the clips (milestone-1 task 55, stories 81 and 82): the
## rules move a fighter at its gait clips' own measured speeds, which the
## frame-data table commits, and a blend of gaits or ways at the blended
## speed. Expected speeds are read from the table's gait rows (the clips'
## measure), the clip for each way from the owner's answers of Oct 8.

const H := preload("res://tests/sim/sim_helpers.gd")

## The owner's answers (Oct 8): the right strafes are the left ones
## mirrored, and the backward run is re-keyed slower than the forward one.
const WALK_FORWARD: String = "Walk01_Forward"
const WALK_LEFT: String = "StrafeWalk01_Left"
const WALK_RIGHT: String = "StrafeWalk01_Left_Mirror"
const WALK_BACK: String = "Walk01_Backward"
const RUN_FORWARD: String = "Run01_Forward"
const RUN_FORWARD_LEFT: String = "Run01_ForwardLeft"
const RUN_LEFT: String = "StrafeRun01_Left"
const RUN_RIGHT: String = "StrafeRun01_Left_Mirror"
const RUN_BACK: String = "RunBackward"
const SPRINT: String = "Sprint01_Forward"
## The stick walks from the dead zone to this tilt, then blends into the run
## at full tilt (the owner's answer).
const WALK_TILT: float = 0.7
## A running jump flies at 3.5 m/s: jump arcs stay rules numbers (spec).
const JUMP_FLIGHT: float = 3.5


func after_each() -> void:
	H.dispose_all()


## Clip `id`'s measured speed (m/s), from the committed table.
static func _speed(id: String) -> float:
	var row: Variant = FrameDataTable.shared().gaits.get(id)
	return float(row["speed"]) if row is Dictionary else NAN


## How far fighter 0 moves in one second holding `inp`, once up to speed (20
## steps in), against an idle opponent `gap` m away.
static func _one_second(weapon: WeaponDef, gap: float, inp: RawInput, armed: bool = true) -> float:
	var W: World = H.make_world(weapon, Moves.KATANA, gap)
	var a: Fighter = W.fighters[0]
	if not armed:
		a.armed = false
	var moved: float = 0.0
	for i: int in 80:
		var x: float = a.pos.x
		var z: float = a.pos.z
		W.step([inp, H.idle()])
		if i >= 20:
			moved += JsMath.hypot(a.pos.x - x, a.pos.z - z)
	return moved


func test_every_gait_clip_has_a_measured_speed_in_the_table() -> void:
	for id: String in Gaits.clips():
		assert_true(_speed(id) > 0.0, "%s has a table row with its speed" % id)


func test_a_full_tilt_runs_each_way_at_its_run_clips_speed() -> void:
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(0.0, 1.0)), _speed(RUN_FORWARD), 1e-6, "forward")
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(0.0, -1.0)), _speed(RUN_BACK), 1e-6, "back")
	# a strafe orbits the opponent; each step is pulled back onto the circle
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(-1.0, 0.0)), _speed(RUN_LEFT), 2e-3, "left")
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(1.0, 0.0)), _speed(RUN_RIGHT), 2e-3, "right")


func test_the_strafes_are_even_and_the_backward_run_is_slower_than_the_forward() -> void:
	assert_almost_eq(_speed(RUN_RIGHT), _speed(RUN_LEFT), 1e-4, "the right strafe run is the left mirrored")
	assert_almost_eq(_speed(WALK_RIGHT), _speed(WALK_LEFT), 1e-4, "the right strafe walk is the left mirrored")
	assert_lt(_speed(RUN_BACK), _speed(RUN_FORWARD), "backing off is slower than closing in")
	assert_almost_eq(_speed(RUN_BACK), 3.9, 0.15, "the backward run re-keyed to about 3.9 m/s")


func test_a_diagonal_runs_at_its_diagonal_clips_speed() -> void:
	var d: float = sqrt(0.5)
	var moved: float = _one_second(Moves.KATANA, 10.0, H.move(-d, d))
	assert_almost_eq(moved, _speed(RUN_FORWARD_LEFT), 2e-3, "forward-left")


func test_a_way_between_two_clips_runs_at_their_blended_speed() -> void:
	# 22.5 degrees right of forward: halfway between the forward run and the
	# forward-right one
	var a: float = deg_to_rad(22.5)
	var expected: float = (_speed(RUN_FORWARD) + _speed("Run01_ForwardRight")) / 2.0
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(sin(a), cos(a))), expected, 3e-3)


func test_a_partial_tilt_walks_at_the_walk_clips_speed() -> void:
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(0.0, 0.5)), _speed(WALK_FORWARD), 1e-6, "forward")
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(0.0, -0.6)), _speed(WALK_BACK), 1e-6, "back")
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(0.45, 0.0)), _speed(WALK_RIGHT), 2e-3, "right")


func test_a_tilt_between_the_walk_and_full_blends_the_walk_into_the_run() -> void:
	var tilt: float = (WALK_TILT + 1.0) / 2.0
	var expected: float = (_speed(WALK_FORWARD) + _speed(RUN_FORWARD)) / 2.0
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(0.0, tilt)), expected, 1e-6)


func test_the_sprint_moves_at_the_sprint_clips_speed() -> void:
	assert_almost_eq(_one_second(Moves.KATANA, 30.0, H.move(0.0, 1.0, Btn.SPRINT)), _speed(SPRINT), 1e-6)


func test_the_greatsword_and_the_daggers_keep_their_speed_on_the_measured_run() -> void:
	assert_almost_eq(_one_second(Moves.GREATSWORD, 10.0, H.move(0.0, 1.0)), _speed(RUN_FORWARD) * 0.9, 1e-6, "Greatsword")
	assert_almost_eq(_one_second(Moves.DAGGERS, 10.0, H.move(0.0, 1.0)), _speed(RUN_FORWARD) * 1.12, 1e-6, "Daggers")


func test_a_disarmed_fighter_keeps_its_speed_until_its_own_gaits() -> void:
	# task 88 gives the disarmed their own gait clips; until then x1.2
	assert_almost_eq(_one_second(Moves.KATANA, 10.0, H.move(0.0, 1.0), false), _speed(RUN_FORWARD) * 1.2, 1e-6)


func test_a_running_jump_still_flies_at_the_rules_speed() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 10.0)
	var a: Fighter = W.fighters[0]
	for i: int in 30:
		W.step([H.move(0.0, 1.0), H.idle()])
	W.step([H.move(0.0, 1.0, Btn.JUMP), H.idle()])
	W.step([H.move(0.0, 1.0), H.idle()])
	assert_eq(a.state, &"jump")
	assert_almost_eq(JsMath.hypot(a.vel.x, a.vel.z), JUMP_FLIGHT, 0.2, "the jump's own flight speed")
