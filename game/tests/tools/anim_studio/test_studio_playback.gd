extends GutTest
## The Studio editor's playback model (StudioPlayback, milestone-1 task 25):
## the playhead over source frames, played, stepped, looped and sought.


func _playback(length: float) -> StudioPlayback:
	var p: StudioPlayback = StudioPlayback.new()
	p.length = length
	return p


func test_a_second_at_rate_1_moves_30_source_frames() -> void:
	var p: StudioPlayback = _playback(60.0)
	p.playing = true
	p.advance(1.0)
	assert_almost_eq(p.frame, 30.0, 1e-9)
	assert_almost_eq(p.source_time(), 1.0, 1e-9)
	p.rate = 0.5
	p.advance(1.0)
	assert_almost_eq(p.frame, 45.0, 1e-9, "half speed")


func test_it_moves_only_while_playing() -> void:
	var p: StudioPlayback = _playback(60.0)
	p.advance(1.0)
	assert_eq(p.frame, 0.0)


func test_the_end_wraps_when_looping_and_stops_when_not() -> void:
	var p: StudioPlayback = _playback(30.0)
	p.playing = true
	p.advance(1.2)
	assert_almost_eq(p.frame, 6.0, 1e-6, "round again")
	p.loop = false
	p.advance(1.2)
	assert_eq(p.frame, 30.0, "held at the end")
	assert_false(p.playing, "and stopped")


func test_stepping_stops_at_the_ends_without_loop_and_wraps_with_it() -> void:
	var p: StudioPlayback = _playback(30.0)
	p.loop = false
	p.step(-1)
	assert_eq(p.frame, 0.0, "the start holds")
	p.seek(29.6)
	p.step(1)
	assert_eq(p.frame, 30.0, "from the whole frame it is on")
	p.step(1)
	assert_eq(p.frame, 30.0, "the end holds")
	p.loop = true
	p.step(1)
	assert_eq(p.frame, 0.0, "wraps to the start")
	p.step(-1)
	assert_eq(p.frame, 30.0, "and back to the end")


func test_seek_clamps_and_the_rate_stays_within_its_range() -> void:
	var p: StudioPlayback = _playback(30.0)
	p.seek(-4.0)
	assert_eq(p.frame, 0.0)
	p.seek(99.0)
	assert_eq(p.frame, 30.0)
	p.seek(12.5)
	assert_eq(p.frame, 12.5, "half frames stay")
	p.rate = 9.0
	assert_eq(p.rate, StudioPlayback.MAX_RATE)
	p.rate = 0.0
	assert_eq(p.rate, StudioPlayback.MIN_RATE)
