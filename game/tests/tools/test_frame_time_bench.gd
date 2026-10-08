extends GutTest
## The frame-time harness and the worst-case replay (milestone-1 task 28,
## stories 201 and 202): the percentile maths and the summary the gate reads,
## the frame-times file, what counts toward the worst case, and the committed
## worst-case log, which must replay to its own end and still show every item
## the worst case needs (re-record it with `npm run bench:record` when a rules
## change makes it drift).


func _values(n: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i: int in n:
		out.append(float(i + 1))
	return out


# ------------------------------------------------------------------ the maths

func test_the_percentile_is_the_nearest_rank() -> void:
	var times: PackedFloat64Array = _values(100)
	times.reverse()
	assert_almost_eq(FrameTimes.percentile(times, 99.0), 99.0, 1e-9, "99 of 100 frames take this long or less")
	assert_almost_eq(FrameTimes.percentile(times, 95.0), 95.0, 1e-9)
	assert_almost_eq(FrameTimes.percentile(times, 100.0), 100.0, 1e-9, "the 100th is the worst")
	assert_almost_eq(FrameTimes.percentile(_values(1000), 99.0), 990.0, 1e-9)
	assert_almost_eq(FrameTimes.percentile(PackedFloat64Array([4.0, 2.0]), 99.0), 4.0, 1e-9, "two frames: the slower")
	assert_almost_eq(FrameTimes.percentile(PackedFloat64Array([7.5]), 99.0), 7.5, 1e-9)
	assert_eq(FrameTimes.percentile(PackedFloat64Array(), 99.0), 0.0, "no frames")
	assert_eq(times[0], 100.0, "the values aren't sorted in place")


func test_the_summary_holds_when_99_percent_of_frames_are_within_16_7_ms() -> void:
	var times := PackedFloat64Array()
	for i: int in 1000:
		times.append(10.0)
	for i: int in 10:
		times[i * 97] = 30.0
	var s: Dictionary = FrameTimes.summary(times)
	assert_eq(s["frames"], 1000)
	assert_almost_eq(s["p99_ms"], 10.0, 1e-9, "10 slow frames in 1,000 are the last 1%")
	assert_true(s["holds"], "99% of the frames within 16.7 ms")
	assert_almost_eq(s["within"], 0.99, 1e-9)
	assert_almost_eq(s["worst_ms"], 30.0, 1e-9)
	assert_eq(s["worst_frame"], 0, "the first of the slowest frames")
	assert_almost_eq(s["mean_ms"], (990 * 10.0 + 10 * 30.0) / 1000.0, 1e-9)
	times[5] = 16.7
	times[6] = 16.71
	s = FrameTimes.summary(times)
	assert_false(s["holds"], "11 frames over the gate")
	assert_almost_eq(s["p99_ms"], 16.71, 1e-9)
	assert_eq(FrameTimes.GATE_MS, 16.7, "the spec's gate")
	assert_eq(FrameTimes.GATE_SHARE, 0.99)


func test_a_frame_at_exactly_16_7_ms_is_within_the_gate() -> void:
	var times := PackedFloat64Array()
	for i: int in 100:
		times.append(16.7)
	assert_true(FrameTimes.summary(times)["holds"])
	assert_false(FrameTimes.summary(PackedFloat64Array())["holds"], "no frames hold nothing")


func test_the_frame_times_file_has_a_row_per_frame() -> void:
	var text: String = FrameTimes.csv(
		PackedFloat64Array([8.25, 17.0]), PackedFloat64Array([6.5, 15.125]),
		PackedFloat64Array([1.0, 1.5]), PackedInt32Array([401, 402]))
	var lines: PackedStringArray = text.strip_edges().split("\n")
	assert_eq(lines.size(), 3)
	assert_eq(lines[0], "frame,step,frame_ms,gpu_ms,cpu_ms")
	assert_eq(lines[1], "1,401,8.250,6.500,1.000")
	assert_eq(lines[2], "2,402,17.000,15.125,1.500")


# ------------------------------------------------------------------ the worst case

func _fighting_steps(c: WorstCase.Coverage, n: int, at_wall: bool) -> void:
	var none: Array[Dictionary] = []
	for i: int in n:
		c.observe(none, at_wall, true)


func test_the_coverage_counts_the_ultimates_and_the_finisher() -> void:
	var c := WorstCase.Coverage.new()
	var events: Array[Dictionary] = [
		{"t": &"ultStart", "f": 0, "ult": &"moonsplitter"},
		{"t": &"ultStart", "f": 1, "ult": &"disarmedChoice"},
		{"t": &"swing", "f": 1, "attack": &"f_breaker"},
		{"t": &"swing", "f": 0, "attack": &"k_l1"},
		{"t": &"finisher", "f": 0},
		{"t": &"hit", "f": 0},
	]
	c.observe(events, false, true)
	assert_eq(c.counts[&"moonsplitter"], 1)
	assert_eq(c.counts[&"breaker"], 1, "only Breaker Palm's swing")
	assert_eq(c.counts[&"finisher"], 1)
	assert_eq(c.missing(), [] as Array[String], "the wall is reported, not required (the owner, Oct 7)")


func test_a_stretch_at_the_wall_is_a_second_in_a_row_during_the_fight() -> void:
	var c := WorstCase.Coverage.new()
	_fighting_steps(c, WorstCase.WALL_STEPS - 1, true)
	_fighting_steps(c, 1, false)
	_fighting_steps(c, WorstCase.WALL_STEPS - 1, true)
	assert_eq(c.longest_wall, WorstCase.WALL_STEPS - 1, "two shorter stretches don't add up")
	assert_eq(c.counts[&"wall"], 0)
	var none: Array[Dictionary] = []
	c.observe(none, true, false)
	assert_eq(c.counts[&"wall"], 0, "not while the fight is stopped")
	_fighting_steps(c, WorstCase.WALL_STEPS, true)
	assert_eq(c.counts[&"wall"], 1)
	_fighting_steps(c, WorstCase.WALL_STEPS * 2, true)
	assert_eq(c.counts[&"wall"], 1, "one stretch, however long")
	assert_eq(c.longest_wall, WorstCase.WALL_STEPS * 3)


func test_at_the_wall_is_within_half_a_metre_of_where_fighters_stop() -> void:
	var stop: float = SimConst.ARENA_RADIUS - SimConst.FIGHTER_RADIUS
	assert_true(WorstCase.near_wall(V3.make(stop - 0.4, 0.0, 0.0)))
	assert_true(WorstCase.near_wall(V3.make(0.0, 0.0, -stop)))
	assert_false(WorstCase.near_wall(V3.make(stop - 0.6, 0.0, 0.0)))
	assert_false(WorstCase.near_wall(V3.make(0.0, 0.0, 0.0)))


func test_the_required_items_are_both_ultimates_and_the_wall_is_reported() -> void:
	# the owner (Oct 7, at milestone-1 task 59): fights no longer reach the
	# wall, so the wall is reported, not required, until they do again
	var keys: Array[StringName] = []
	for item: Array in WorstCase.REQUIRED:
		keys.append(item[0])
	assert_eq(keys, [&"moonsplitter", &"breaker"] as Array[StringName],
		"the finisher joins once task 103 adds it; blood and petals come with every hit and the arena")
	var reported: Array[StringName] = []
	for item: Array in WorstCase.REPORTED:
		reported.append(item[0])
	assert_eq(reported, [&"wall", &"finisher"] as Array[StringName])
	var c := WorstCase.Coverage.new()
	assert_eq(c.missing().size(), 2)
	assert_string_contains(c.line(), "a stretch at the wall 0")
	assert_string_contains(c.line(), "Moonsplitter 0")


func _timeline(steps: int, marks: Dictionary, wall_from: int, wall_to: int) -> WorstCase.Timeline:
	var t := WorstCase.Timeline.new()
	for i: int in steps:
		var events: Array = []
		if marks.has(i):
			events.append(marks[i])
		t.add(events, i >= wall_from and i < wall_to, true)
	return t


func test_the_search_finds_the_earliest_window_that_shows_everything() -> void:
	var moon: Dictionary = {"t": &"ultStart", "f": 0, "ult": &"moonsplitter"}
	var palm: Dictionary = {"t": &"swing", "f": 1, "attack": &"f_breaker"}
	var hit: Dictionary = {"t": &"hit", "f": 0}
	# the wall from 10 to 80, Moonsplitter at 150, Breaker Palm at 170
	var t: WorstCase.Timeline = _timeline(300, {5: hit, 150: moon, 170: palm}, 10, 80)
	assert_eq(t.size(), 300)
	assert_eq(t.events.size(), 2, "only the events that count are kept")
	# the wall isn't required: a 100-step window needs only Moonsplitter (150)
	# and Breaker Palm (170), so it ends after 170
	assert_eq(t.earliest_end(100), 171)
	assert_eq(t.earliest_end(160), 171)
	assert_eq(_timeline(300, {5: moon, 170: palm}, 10, 80).earliest_end(160), -1, "Moonsplitter at 5 and Breaker Palm at 170 don't fit in 160 steps")
	assert_eq(_timeline(50, {}, 0, 50).earliest_end(100), -1, "shorter than the window")
	var c: WorstCase.Coverage = t.coverage(11, 171)
	assert_eq(c.missing(), [] as Array[String])
	assert_eq(c.longest_wall, 69)
	assert_eq(c.counts[&"wall"], 1, "the wall stretch is still counted")
	assert_eq(t.coverage(21, 171).counts[&"wall"], 0, "59 wall steps aren't a stretch")
	assert_eq(t.coverage(21, 171).missing(), [] as Array[String], "and it isn't required")


func test_a_recorded_worst_case_is_a_duel_that_replays_to_its_end() -> void:
	var log_in: InputLog = WorstCase.record(5, 600)
	assert_eq(log_in.step_count(), 600)
	assert_eq(log_in.end_steps, 600)
	assert_eq(log_in.config.mode, MatchConfig.DUEL, "replayed from the Duel's camera and HUD")
	assert_true(log_in.config.sides[0].is_human())
	assert_eq(log_in.config.sides[1].difficulty, &"hard")
	assert_eq(log_in.config.sides[0].weapon_id, &"katana")
	assert_eq(log_in.config.arena_id, MatchConfig.DEFAULT_ARENA, "on the Moonlit Shrine")
	var replayed: Dictionary = WorstCase.replay(log_in)
	assert_true(replayed["ok"], replayed["report"])


# ------------------------------------------------------------------ the committed log

func test_the_committed_worst_case_replays_and_its_window_shows_every_item() -> void:
	var log_in: InputLog = InputLog.load_file(WorstCase.PATH)
	assert_not_null(log_in, "the worst-case log is committed at %s" % WorstCase.PATH)
	if log_in == null:
		return
	assert_gte(log_in.step_count(), WorstCase.STEPS, "a lead-in, then the 90 s window")
	assert_lte(log_in.step_count(), WorstCase.LIMIT)
	assert_eq(log_in.config.mode, MatchConfig.DUEL)
	var replayed: Dictionary = WorstCase.replay(log_in)
	assert_true(replayed["ok"], "%s; re-record it with npm run bench:record" % replayed["report"])
	var coverage: WorstCase.Coverage = replayed["coverage"]
	assert_eq(coverage.missing(), [] as Array[String], "%s; re-record it with npm run bench:record" % coverage.line())
