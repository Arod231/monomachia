extends GutTest
## FloorStirrer (milestone-1 task 137): each drawn frame, what the fighters
## do to the arena's floor, from what the view shows and the rules' states
## and events (a walk's push, a roll's wider one, a blade low and fast
## sweeping, a landing's, a fall's and a blow's burst), for an arena whose
## floor reacts (the Shrine's fallen petals). Picture only.

const DT: float = 1.0 / 60.0


func _side(at: Vector3, state: StringName = &"free", phase: StringName = &"",
		blades: Array[PackedVector3Array] = []) -> Dictionary:
	return {"at": at, "state": state, "phase": phase, "blades": blades}


func _frame(s: FloorStirrer, a: Dictionary, b: Dictionary = {}) -> FloorStir:
	var sides: Array[Dictionary] = [a]
	if not b.is_empty():
		sides.append(b)
	return s.frame(DT, sides)


func test_a_walking_fighter_pushes_by_its_speed_and_a_still_one_doesnt() -> void:
	var s := FloorStirrer.new()
	_frame(s, _side(Vector3(0, 0, 0)))
	var walk: FloorStir = _frame(s, _side(Vector3(0.03, 0, 0)))
	assert_eq(walk.pushes.size(), 1, "the feet push")
	assert_almost_eq(walk.pushes[0].velocity, Vector3(1.8, 0, 0), Vector3.ONE * 1e-3, "at the shown speed")
	assert_almost_eq(walk.pushes[0].radius, FloorStirrer.WALK_RADIUS, 1e-5)
	var still: FloorStir = _frame(s, _side(Vector3(0.03, 0, 0)))
	assert_eq(still.pushes[0].velocity, Vector3.ZERO, "standing still: no speed, so no push")


func test_a_roll_pushes_wider_and_harder_than_a_walk() -> void:
	var s := FloorStirrer.new()
	_frame(s, _side(Vector3.ZERO, &"dodge"))
	var roll: FloorStir = _frame(s, _side(Vector3(0.08, 0, 0), &"dodge"))
	assert_almost_eq(roll.pushes[0].radius, FloorStirrer.ROLL_RADIUS, 1e-5)
	assert_almost_eq(roll.pushes[0].strength, FloorStirrer.ROLL_STRENGTH, 1e-5)
	assert_gt(FloorStirrer.ROLL_RADIUS, FloorStirrer.WALK_RADIUS)
	assert_gt(FloorStirrer.ROLL_STRENGTH, FloorStirrer.WALK_STRENGTH)
	var back: FloorStir = _frame(s, _side(Vector3(0.0, 0, 0), &"backstep"))
	assert_almost_eq(back.pushes[0].radius, FloorStirrer.ROLL_RADIUS, 1e-5, "a backstep too")


func test_an_airborne_fighter_doesnt_touch_the_floor_and_lands_with_a_burst() -> void:
	var s := FloorStirrer.new()
	_frame(s, _side(Vector3(0, 0, 0), &"jump"))
	var up: FloorStir = _frame(s, _side(Vector3(0.05, 0.8, 0), &"jump"))
	assert_eq(up.pushes.size(), 0, "in the air")
	var land: FloorStir = _frame(s, _side(Vector3(0.1, 0, 0), &"land"))
	assert_eq(land.bursts.size(), 1, "the landing bursts once")
	assert_almost_eq(land.bursts[0].radius, FloorStirrer.LAND_BURST.x, 1e-5)
	var after: FloorStir = _frame(s, _side(Vector3(0.1, 0, 0), &"land"))
	assert_eq(after.bursts.size(), 0, "only on the frame it lands")


func test_a_knocked_down_fighter_bursts_once_as_it_hits_the_ground() -> void:
	var s := FloorStirrer.new()
	_frame(s, _side(Vector3.ZERO, &"knockdown", &"fall"))
	var hit: FloorStir = _frame(s, _side(Vector3(0.02, 0, 0), &"knockdown", &"ground"))
	assert_eq(hit.bursts.size(), 1)
	assert_almost_eq(hit.bursts[0].radius, FloorStirrer.DOWN_BURST.x, 1e-5)
	assert_eq(_frame(s, _side(Vector3(0.02, 0, 0), &"knockdown", &"ground")).bursts.size(), 0)


func test_a_jump_back_to_the_spawn_at_a_new_round_pushes_nothing() -> void:
	var s := FloorStirrer.new()
	_frame(s, _side(Vector3(3, 0, 2)))
	var reset: FloorStir = _frame(s, _side(Vector3(0, 0, -4.15)))
	assert_eq(reset.pushes[0].velocity, Vector3.ZERO, "a teleport, not a dash")


func test_a_blade_low_and_fast_sweeps_and_a_high_or_slow_one_doesnt() -> void:
	var s := FloorStirrer.new()
	var low_a: Array[PackedVector3Array] = [PackedVector3Array([Vector3(0, 0.5, 0), Vector3(0.9, 0.2, 0)])]
	var low_b: Array[PackedVector3Array] = [PackedVector3Array([Vector3(0, 0.5, 0.1), Vector3(0.9, 0.2, 0.2)])]
	_frame(s, _side(Vector3.ZERO, &"attack", &"", low_a))
	var swept: FloorStir = _frame(s, _side(Vector3.ZERO, &"attack", &"", low_b))
	assert_eq(swept.sweeps.size(), 1, "the blade sweeps the floor")
	assert_almost_eq(swept.sweeps[0].vb, Vector3(0, 0, 12.0), Vector3.ONE * 1e-3, "the tip's speed")
	var high_a: Array[PackedVector3Array] = [PackedVector3Array([Vector3(0, 1.4, 0), Vector3(0.9, 1.3, 0)])]
	var high_b: Array[PackedVector3Array] = [PackedVector3Array([Vector3(0, 1.4, 0.1), Vector3(0.9, 1.3, 0.2)])]
	_frame(s, _side(Vector3.ZERO, &"attack", &"", high_a))
	assert_eq(_frame(s, _side(Vector3.ZERO, &"attack", &"", high_b)).sweeps.size(), 0, "a blade at the chest")
	_frame(s, _side(Vector3.ZERO, &"free", &"", low_b))
	assert_eq(_frame(s, _side(Vector3.ZERO, &"free", &"", low_b)).sweeps.size(), 0, "a blade at rest")


func test_blows_burst_the_floor_where_they_land_once() -> void:
	var s := FloorStirrer.new()
	var at := func(side: int) -> Vector3: return Vector3(side * 2.0, 0.0, 1.0)
	s.on_event({"t": &"hit", "attacker": 0, "target": 1, "heavy": true}, at)
	s.on_event({"t": &"ko", "loser": 0, "winner": 1}, at)
	s.on_event({"t": &"block", "attacker": 0, "target": 1, "heavy": false}, at)
	var f: FloorStir = _frame(s, _side(Vector3.ZERO), _side(Vector3(2, 0, 1)))
	assert_eq(f.bursts.size(), 2, "the heavy hit and the KO; a light block doesn't reach the floor")
	assert_almost_eq(f.bursts[0].at, Vector3(2, 0, 1), Vector3.ONE * 1e-6, "at the target's feet")
	assert_almost_eq(f.bursts[0].radius, FloorStirrer.HEAVY_HIT_BURST.x, 1e-5)
	assert_almost_eq(f.bursts[1].at, Vector3(0, 0, 1), Vector3.ONE * 1e-6, "at the loser's")
	assert_eq(_frame(s, _side(Vector3.ZERO), _side(Vector3(2, 0, 1))).bursts.size(), 0, "each burst once")
	s.on_event({"t": &"recallBurst", "f": 0, "on": 1, "hit": false, "pos": {"x": 1.0, "y": 1.0, "z": 0.0}}, at)
	var r: FloorStir = _frame(s, _side(Vector3.ZERO), _side(Vector3(2, 0, 1)))
	assert_almost_eq(r.bursts[0].at, Vector3(1, 0, 0), Vector3.ONE * 1e-6, "the recall's burst, on the floor under it")
	s.on_event({"t": &"hit", "attacker": 0, "target": 1, "heavy": true}, at)
	s.reset()
	assert_eq(_frame(s, _side(Vector3.ZERO)).bursts.size(), 0, "a reset drops what's waiting")


## Leaping Cleave and Falling Crown coming down burst the floor where they
## land (milestone-1 task 77), as hard as a stomp's.
func test_a_touchdown_bursts_the_floor_where_it_lands() -> void:
	var s := FloorStirrer.new()
	var at := func(side: int) -> Vector3: return Vector3(side * 2.0, 0.0, 1.0)
	s.on_event({"t": &"touchdown", "f": 0, "attack": &"k_sh", "pos": {"x": 0.5, "y": 0.0, "z": 1.5}}, at)
	var f: FloorStir = _frame(s, _side(Vector3.ZERO), _side(Vector3(2, 0, 1)))
	assert_eq(f.bursts.size(), 1)
	assert_almost_eq(f.bursts[0].at, Vector3(0.5, 0, 1.5), Vector3.ONE * 1e-6, "where it came down")
	assert_almost_eq(f.bursts[0].radius, FloorStirrer.TOUCHDOWN_BURST.x, 1e-5)
	assert_gte(FloorStirrer.TOUCHDOWN_BURST.y, FloorStirrer.LAND_BURST.y, "harder than a landing")
