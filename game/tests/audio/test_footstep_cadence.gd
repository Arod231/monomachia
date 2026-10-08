extends GutTest
## FootstepCadence: a footfall every stride of ground covered on foot, with a
## stride per pace (guard walk, run, sprint), the Iai stance's sheathed walk
## included, and none in the air, in a dodge, while knocked back, in hit-stop
## or across a jump in position.

const DT: float = SimConst.DT
## The forward run's and the sprint's speeds (m/s): the gait clips' own.
static var RUN: float = Gaits.speed(&"run", 0.0)
static var SPRINT: float = Gaits.sprint_speed()

var cadence: FootstepCadence
var world: World


func before_each() -> void:
	cadence = FootstepCadence.new()
	world = SimHelpers.make_world()


func after_each() -> void:
	SimHelpers.dispose_all()


## Moves fighter i along x at speed (m/s) for frames rules steps, in state,
## advancing the world's frame unless frozen; returns the footfalls.
func _move(i: int, speed: float, frames: int, state: StringName = &"free", height: float = 0.0,
		frozen: bool = false) -> Array[Dictionary]:
	var f: Fighter = world.fighters[i]
	f.state = state
	f.pos.y = height
	var feet: Array[Dictionary] = []
	for k: int in frames:
		f.pos.x += speed * DT
		if not frozen:
			world.frame += 1
		feet.append_array(cadence.update(world.fighters, world.frame))
	return feet


func test_distance_over_stride_gives_the_count() -> void:
	var feet := _move(0, RUN, 110)
	var covered := RUN * 110 * DT
	assert_eq(feet.size(), int(covered / cadence.run_stride), "%.2f m at a run" % covered)
	for foot: Dictionary in feet:
		assert_eq(foot["fighter"], 0)


func test_each_footfall_is_at_the_fighter_s_feet() -> void:
	var f: Fighter = world.fighters[0]
	var at: Array[Vector3] = []
	for k: int in 60:
		f.pos.x += RUN * DT
		world.frame += 1
		for foot: Dictionary in cadence.update(world.fighters, world.frame):
			assert_almost_eq(foot["at"], Vector3(f.pos.x, f.pos.y, f.pos.z), Vector3.ONE * 1e-5)
			at.append(foot["at"])
	assert_gt(at.size(), 0)


func test_a_guard_walk_and_a_sprint_take_their_own_strides() -> void:
	var walk := RUN * SimConst.MOVE_BLOCK_SPEED_MULT
	assert_eq(_move(0, walk, 120).size(), int(walk * 120 * DT / cadence.walk_stride), "a guard walk")
	cadence.reset()
	assert_eq(_move(1, SPRINT, 110).size(), int(SPRINT * 110 * DT / cadence.sprint_stride),
		"a sprint")
	assert_lt(cadence.walk_stride, cadence.run_stride)
	assert_lt(cadence.run_stride, cadence.sprint_stride)


func test_both_fighters_count_on_their_own() -> void:
	var a: Fighter = world.fighters[0]
	var b: Fighter = world.fighters[1]
	var feet: Array[Dictionary] = []
	for k: int in 110:
		a.pos.x += RUN * DT
		b.pos.z += SPRINT * DT
		world.frame += 1
		feet.append_array(cadence.update(world.fighters, world.frame))
	var per_side := [0, 0]
	for foot: Dictionary in feet:
		per_side[foot["fighter"]] += 1
	assert_eq(per_side[0], int(RUN * 110 * DT / cadence.run_stride))
	assert_eq(per_side[1], int(SPRINT * 110 * DT / cadence.sprint_stride))


func test_a_sheathed_walk_steps_at_the_walking_stride() -> void:
	# fighter 0 holds heavy (the Katana's Iai) with the stick right: sheathed
	# after 9 frames, it strafes round the opponent at the blocking walk
	var f: Fighter = world.fighters[0]
	var feet: Array[Dictionary] = []
	var walked: float = 0.0
	for k: int in 130:
		var x: float = f.pos.x
		var z: float = f.pos.z
		world.step([SimHelpers.move(1.0, 0.0, Btn.HEAVY), SimHelpers.idle()])
		feet.append_array(cadence.update(world.fighters, world.frame))
		walked += Vector2(f.pos.x - x, f.pos.z - z).length()
	assert_true(f.in_stance(), "still sheathed")
	assert_gt(walked, 3.0 * cadence.walk_stride, "it walked")
	assert_eq(feet.size(), int(walked / cadence.walk_stride), "a footfall every walking stride")


func test_standing_gives_none() -> void:
	assert_eq(_move(0, 0.0, 300).size(), 0)


func test_jumping_gives_none() -> void:
	assert_eq(_move(0, RUN, 120, &"jump", 0.6).size(), 0)
	assert_eq(_move(0, RUN, 120, &"free", 0.6).size(), 0, "off the ground in any state")


func test_dodging_gives_none() -> void:
	assert_eq(_move(0, 9.0, 120, &"dodge").size(), 0)
	assert_eq(_move(0, 6.0, 120, &"backstep").size(), 0)


func test_being_knocked_back_gives_none() -> void:
	assert_eq(_move(0, 6.0, 120, &"hitstun").size(), 0)
	assert_eq(_move(0, 6.0, 120, &"ko").size(), 0)


func test_hit_stop_gives_none() -> void:
	assert_eq(_move(0, RUN, 120, &"free", 0.0, true).size(), 0, "the world's frame stood still")


func test_a_jump_in_position_is_not_walked() -> void:
	_move(0, RUN, 1)
	world.fighters[0].pos.x += 6.0
	world.frame += 1
	assert_eq(cadence.update(world.fighters, world.frame).size(), 0, "a new round places the fighters")


func test_reset_forgets_the_distance_walked() -> void:
	var almost := cadence.run_stride - 0.1
	_move(0, RUN, int(almost / (RUN * DT)))
	cadence.reset()
	assert_eq(_move(0, RUN, 5).size(), 0, "the first stride starts again")
