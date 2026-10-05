extends GutTest
## FadedLoop: a looping stream that never starts or stops cold. These tests
## capture the Music bus while the loop plays a stream that holds one level,
## so each captured sample is the loop's gain at that moment: a click shows as
## a jump, a fade as a ramp whose length can be measured.

const LEVEL := 0.5
## The dummy driver mixes about every 93 ms; these waits leave plenty of room.
const WAIT := 2.0

var capture: BusCapture
var loop: FadedLoop


func before_each() -> void:
	capture = BusCapture.new().attach(&"Music")
	loop = FadedLoop.new()
	add_child_autofree(loop)


func after_each() -> void:
	var audible := loop.is_audible()
	loop.stop()
	if audible:
		# Let the fade play out, so it doesn't spill into the next test.
		await wait_until(capture.silent_after.bind(capture.collect()), WAIT)
	capture.detach()


## Waits until the captured sound reaches [param level] (or falls to it when
## [param falling]); false on a timeout.
func _until_captured(level: float, falling := false) -> bool:
	return await wait_until(func() -> bool:
		capture.collect()
		var s := capture.left()
		if falling:
			return BusCapture.first_at_or_below(s, level) >= 0
		return BusCapture.first_at_or_above(s, level) >= 0, WAIT)


func test_a_start_rises_from_silence_in_10_to_20_ms() -> void:
	loop.play(BusCapture.level_stream(LEVEL))
	assert_true(await _until_captured(LEVEL * 0.999), "the loop reaches its level")
	var s := capture.left()
	var leaves := BusCapture.first_at_or_above(s, LEVEL * 0.001)
	var full := BusCapture.first_at_or_above(s, LEVEL * 0.999)
	assert_gt(leaves, 0, "it plays silent first")
	assert_between(BusCapture.ms(full - leaves), 10.0, 20.0, "silence to full, in ms")
	assert_lt(BusCapture.biggest_step(s), LEVEL * 0.01, "no jump anywhere: a cold start jumps by the whole level")


func test_a_stop_falls_to_silence_in_10_to_20_ms() -> void:
	loop.play(BusCapture.level_stream(LEVEL))
	assert_true(await _until_captured(LEVEL * 0.999))
	capture.clear()
	loop.stop()
	assert_false(loop.is_playing())
	assert_true(await _until_captured(LEVEL * 0.0001, true), "the loop falls silent")
	var s := capture.left()
	var leaves := BusCapture.first_at_or_below(s, LEVEL * 0.999)
	var silent := BusCapture.first_at_or_below(s, LEVEL * 0.001)
	assert_between(BusCapture.ms(silent - leaves), 10.0, 20.0, "full to silence, in ms")
	assert_lt(BusCapture.biggest_step(s), LEVEL * 0.01, "no jump: a cut drops by the whole level")


func test_it_rises_only_once_the_mixer_has_played_it() -> void:
	watch_signals(loop)
	# Hold the mixer, so it can't play the loop between these calls.
	AudioServer.lock()
	loop.play(BusCapture.level_stream(LEVEL))
	loop.advance()
	var audible := loop.is_audible()
	var db := loop.player.volume_db
	AudioServer.unlock()
	assert_true(loop.is_playing())
	assert_false(audible, "not before its first mix")
	assert_eq(db, FadedLoop.SILENT_DB, "the first mix is silent: Godot plays a new sound's first mix at full volume")
	assert_true(await wait_until(loop.is_audible, WAIT), "it rises once mixed")
	assert_eq(loop.player.volume_db, loop.volume_db)
	assert_signal_emit_count(loop, "rising", 1)


func test_its_level_is_its_volume() -> void:
	loop.volume_db = -6.0
	loop.play(BusCapture.level_stream(LEVEL))
	var expected := LEVEL * db_to_linear(-6.0)
	assert_true(await _until_captured(expected * 0.999))
	var s := capture.left()
	assert_almost_eq(s[s.size() - 1], expected, expected * 0.001)
	assert_eq(loop.player.bus, &"Music")


func test_it_plays_on_through_a_paused_tree() -> void:
	assert_eq(loop.process_mode, Node.PROCESS_MODE_ALWAYS, "music and ambience carry on through pauses")
