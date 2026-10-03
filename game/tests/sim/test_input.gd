extends GutTest
## Port of the "input tracker" tests in tests/match.test.ts, plus the direction
## helpers checked against the TypeScript (game/tests/fixtures/math.json, written
## by scripts/sim-fixtures.ts).

const EPS: float = 1e-12


## helpers.ts btn(...B)
func _btn(buttons: Array[int]) -> RawInput:
	var mask: int = 0
	for b: int in buttons:
		mask |= 1 << b
	return RawInput.make(0.0, 0.0, mask)


## helpers.ts move(mx, my, ...B)
func _move(mx: float, my: float, buttons: Array[int] = []) -> RawInput:
	var r: RawInput = _btn(buttons)
	r.mx = mx
	r.my = my
	return r


func _fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % name))


func test_a_fresh_push_from_neutral_requests_a_step() -> void:
	var t: InputTracker = InputTracker.new()
	t.update(RawInput.empty(), 1)
	t.update(_move(0.0, 1.0), 2)
	assert_true(t.step_request)
	t.update(_move(0.0, 1.0), 3)
	assert_false(t.step_request)


func test_double_tap_and_hold_latches_a_sprint_releasing_clears_it() -> void:
	var t: InputTracker = InputTracker.new()
	var f: int = 1
	t.update(_move(0.0, 1.0), f)
	f += 1
	t.update(_move(0.0, 1.0), f)
	f += 1
	t.update(RawInput.empty(), f)
	f += 1
	t.update(RawInput.empty(), f)
	f += 1
	t.update(_move(0.0, 1.0), f)
	f += 1
	assert_true(t.sprinting())
	t.update(RawInput.empty(), f)
	f += 1
	assert_false(t.sprinting())


func test_a_slow_second_push_does_not_sprint() -> void:
	var t: InputTracker = InputTracker.new()
	var f: int = 1
	t.update(_move(0.0, 1.0), f)
	f += 1
	t.update(RawInput.empty(), f)
	f += 1
	for i: int in 30:
		t.update(RawInput.empty(), f)
		f += 1
	t.update(_move(0.0, 1.0), f)
	f += 1
	assert_false(t.sprinting())


func test_buffers_presses_for_a_few_frames() -> void:
	var t: InputTracker = InputTracker.new()
	t.update(_btn([Btn.LIGHT]), 10)
	t.update(RawInput.empty(), 14)
	assert_true(t.buffered(Btn.LIGHT))
	t.update(RawInput.empty(), 30)
	assert_false(t.buffered(Btn.LIGHT))


func test_edges_consume_and_held_frames() -> void:
	var t: InputTracker = InputTracker.new()
	t.update(_btn([Btn.HEAVY, Btn.BLOCK]), 5)
	assert_true(t.pressed_now(Btn.HEAVY))
	assert_true(t.is_held(Btn.BLOCK))
	assert_false(t.is_held(Btn.LIGHT))
	assert_eq(t.press_frame[Btn.HEAVY], 5)
	t.update(_btn([Btn.HEAVY]), 6)
	assert_false(t.pressed_now(Btn.HEAVY))
	assert_eq(t.held_frames(Btn.HEAVY), 1)
	assert_eq(t.release_frame[Btn.BLOCK], 6)
	assert_true(t.buffered(Btn.HEAVY, 2))
	t.consume(Btn.HEAVY)
	assert_false(t.buffered(Btn.HEAVY))
	assert_eq(t.held_frames(Btn.BLOCK), 0)
	assert_eq(Btn.bit(Btn.SPRINT), 128)
	assert_true(_move(0.5, 0.5, [Btn.SPRINT]).buttons == Btn.bit(Btn.SPRINT))


func test_sprint_button_sprints_only_while_moving() -> void:
	var t: InputTracker = InputTracker.new()
	t.update(_btn([Btn.SPRINT]), 1)
	assert_false(t.sprinting())
	assert_false(t.moving())
	t.update(_move(1.0, 0.0, [Btn.SPRINT]), 2)
	assert_true(t.sprinting())
	assert_true(t.moving())
	assert_eq(t.dir, 2)


func test_same_sector_wraps_around() -> void:
	assert_true(InputTracker.same_sector(0, 7))
	assert_true(InputTracker.same_sector(7, 0))
	assert_true(InputTracker.same_sector(3, 4))
	assert_false(InputTracker.same_sector(0, 2))
	assert_false(InputTracker.same_sector(-1, 0))


func test_dir_index_matches_the_typescript() -> void:
	var cases: Array = _fixture("math")["dirIndex"]
	assert_gt(cases.size(), 0)
	for c: Array in cases:
		assert_eq(InputTracker.dir_index(c[0], c[1]), int(c[2]), "dirIndex(%s, %s)" % [c[0], c[1]])


func test_dir_vector_matches_the_typescript() -> void:
	var cases: Array = _fixture("math")["dirVector"]
	assert_gt(cases.size(), 0)
	for c: Array in cases:
		var v: RawInput = InputTracker.dir_vector(int(c[0]))
		assert_almost_eq(v.mx, float(c[1]), EPS, "dirVector(%s).mx" % c[0])
		assert_almost_eq(v.my, float(c[2]), EPS, "dirVector(%s).my" % c[0])
