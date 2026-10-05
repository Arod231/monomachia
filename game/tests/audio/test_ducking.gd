extends GutTest
## Ducking: the Music and Ambience buses each carry a compressor keyed by the
## Combat bus, so loud combat sounds (heavy impacts, the round calls) pull them
## down a few dB, quiet ones leave them alone, and they come back within about
## half a second. Each test plays a stream holding one level on the ducked bus
## and another on Combat, and captures the ducked bus after its effects, so
## each captured sample is the ducked bus's gain.

const LEVEL := 0.5
## The dummy driver mixes about every 93 ms; these waits leave plenty of room.
const WAIT := 2.0
## Combat levels like the game's (measured in a Watch match): heavy impacts and
## the calls peak between -6 and +1 dB, light hits and whooshes around -8 dB,
## and the quietest combat sounds below -12 dB.
const HEAVY_DB := -3.0
const QUIET_DB := -14.0

var capture: BusCapture
var players: Array[AudioStreamPlayer] = []


func after_each() -> void:
	for p: AudioStreamPlayer in players:
		p.stop()
	players.clear()
	if capture != null:
		# Let the stops play out, so nothing spills into the next test.
		await wait_until(capture.silent_after.bind(capture.collect()), WAIT)
		capture.detach()
		capture = null


func _play(bus: StringName, level: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = BusCapture.level_stream(level)
	p.bus = bus
	add_child_autofree(p)
	p.play()
	players.append(p)
	return p


## Waits until the bus has mixed [param count] more frames.
func _mix_more(count: int) -> bool:
	var target := capture.collect() + count
	return await wait_until(func() -> bool: return capture.collect() >= target, WAIT)


## Plays the level on [param bus] until it is steady, then a combat sound at
## [param combat_db] until the bus is steady again; returns the bus's level then
## (the last 2048 frames' lowest), and leaves the combat sound playing.
func _ducked_under(bus: StringName, combat_db: float) -> float:
	capture = BusCapture.new().attach(bus, true)
	_play(bus, LEVEL)
	assert_true(await wait_until(func() -> bool:
		capture.collect()
		return BusCapture.first_at_or_above(capture.left(), LEVEL * 0.999) >= 0, WAIT), "the %s bed plays" % bus)
	_play(&"Combat", db_to_linear(combat_db))
	assert_true(await _mix_more(8192), "the mixer runs on")
	var s := capture.left(capture.frames.size() - 2048)
	var lowest := LEVEL
	for x: float in s:
		lowest = minf(lowest, x)
	return lowest


func test_a_heavy_combat_sound_ducks_the_music_a_few_db() -> void:
	var level := await _ducked_under(&"Music", HEAVY_DB)
	assert_between(linear_to_db(LEVEL / level), 2.0, 6.0, "dB of ducking")


func test_a_heavy_combat_sound_ducks_the_ambience_a_few_db() -> void:
	var level := await _ducked_under(&"Ambience", HEAVY_DB)
	assert_between(linear_to_db(LEVEL / level), 2.0, 6.0, "dB of ducking")


func test_a_quiet_combat_sound_leaves_the_music_alone() -> void:
	var level := await _ducked_under(&"Music", QUIET_DB)
	assert_lt(linear_to_db(LEVEL / level), 0.5, "dB of ducking")


func test_the_music_comes_back_within_about_half_a_second() -> void:
	var ducked := await _ducked_under(&"Music", HEAVY_DB)
	capture.clear()
	players[1].stop()
	var back := LEVEL * db_to_linear(-1.0)
	assert_true(await wait_until(func() -> bool:
		capture.collect()
		return BusCapture.first_at_or_above(capture.left(), back) >= 0, WAIT), "the music comes back")
	var s := capture.left()
	var rising := BusCapture.first_at_or_above(s, ducked * 1.01)
	var within_1_db := BusCapture.first_at_or_above(s, back)
	assert_between(BusCapture.ms(within_1_db - rising), 150.0, 700.0, "ms to come back within 1 dB, smoothly")
	assert_lt(BusCapture.biggest_step(s), LEVEL * 0.01, "no jump")
