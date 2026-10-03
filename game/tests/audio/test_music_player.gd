extends GutTest
## MusicPlayer: plays the music director's tracks on the Music bus through two
## FadedLoops. A switch starts the new track silent and stops the old one in
## the same mix as the new one rises, so the two overlap with no gap. Most
## tests give every track its own stream holding one level and capture the
## Music bus, so a gap shows as a dip and a doubled track as a bump.

const LEVEL := 0.5
## The dummy driver mixes about every 93 ms; these waits leave plenty of room.
const WAIT := 2.0

var capture: BusCapture
var music: MusicPlayer


func before_each() -> void:
	capture = BusCapture.new().attach(&"Music")
	music = MusicPlayer.new()
	add_child_autofree(music)


func after_each() -> void:
	var audible := music.loops.any(func(loop: FadedLoop) -> bool: return loop.is_audible())
	music.stop()
	if audible:
		# Let the fade play out, so it doesn't spill into the next test.
		await wait_until(capture.silent_after.bind(capture.collect()), WAIT)
	capture.detach()


## Gives every track its own stream at the same level, in place of its file.
func _level_tracks() -> void:
	for track: StringName in MusicDirector.TRACK_IDS:
		music.streams[track] = BusCapture.level_stream(LEVEL)


## The loop playing [param track]'s stream, or null.
func _loop_for(track: StringName) -> FadedLoop:
	for loop: FadedLoop in music.loops:
		if loop.is_playing() and loop.player.stream == music.streams.get(track):
			return loop
	return null


func _playing() -> int:
	return music.loops.filter(func(loop: FadedLoop) -> bool: return loop.is_playing()).size()


func _until_audible(track: StringName) -> bool:
	return await wait_until(func() -> bool:
		var loop := _loop_for(track)
		return loop != null and loop.is_audible(), WAIT)


func test_each_track_plays_its_file_on_the_music_bus() -> void:
	for track: StringName in MusicDirector.TRACK_IDS:
		music.play(track)
		assert_eq(music.current_track(), track)
		var loop := _loop_for(track)
		assert_not_null(loop, "a loop plays %s" % track)
		if loop != null:
			assert_eq(loop.player.stream.resource_path, MusicDirector.track_path(track))
			assert_eq(loop.player.bus, &"Music")


func test_a_switch_overlaps_the_tracks_with_no_gap() -> void:
	_level_tracks()
	music.play(&"menu")
	assert_true(await _until_audible(&"menu"))
	var menu := _loop_for(&"menu")
	assert_true(await wait_until(func() -> bool:
		capture.collect()
		return BusCapture.first_at_or_above(capture.left(), LEVEL * 0.999) >= 0, WAIT))
	capture.clear()
	music.play(&"battle")
	assert_true(menu.is_playing(), "the menu track plays on while the battle track starts silent")
	assert_true(await wait_until(func() -> bool: return not menu.is_playing(), WAIT), "the menu track stops")
	assert_true(_loop_for(&"battle").is_audible(), "once the battle track has risen")
	# Take in the mix where one falls as the other rises, and a little after.
	var seen := capture.collect()
	assert_true(await wait_until(func() -> bool: return capture.collect() > seen + 1024, WAIT))
	var s := capture.left()
	var lowest := LEVEL
	var highest := 0.0
	for x: float in s:
		lowest = minf(lowest, x)
		highest = maxf(highest, x)
	assert_gt(lowest, LEVEL * 0.98, "no dip: the old track fades only as the new one rises")
	assert_lt(highest, LEVEL * 1.02, "no bump: the old track does stop")
	assert_lt(BusCapture.biggest_step(s), LEVEL * 0.01, "no jump")


func test_the_track_already_playing_carries_on() -> void:
	_level_tracks()
	music.play(&"battle")
	assert_true(await _until_audible(&"battle"))
	var loop := _loop_for(&"battle")
	var position := loop.player.get_playback_position()
	music.play(&"battle")
	assert_true(loop.is_audible(), "not restarted from silence")
	assert_gte(loop.player.get_playback_position(), position, "not back at its start")
	assert_eq(_playing(), 1, "no second copy starts")


func test_switching_back_before_the_new_track_rises_keeps_the_old_one() -> void:
	_level_tracks()
	music.play(&"menu")
	assert_true(await _until_audible(&"menu"))
	var menu := _loop_for(&"menu")
	AudioServer.lock()
	music.play(&"battle")
	music.play(&"menu")
	music.advance()
	var battle := _loop_for(&"battle")
	var playing := _playing()
	AudioServer.unlock()
	assert_eq(music.current_track(), &"menu")
	assert_true(menu.is_audible(), "the menu track never stopped")
	assert_null(battle, "the battle track was dropped before it was heard")
	assert_eq(playing, 1, "and the menu track isn't started over")


func test_it_follows_the_director() -> void:
	_level_tracks()
	var director := MusicDirector.new()
	music.bind(director)
	director.enter_match()
	assert_eq(music.current_track(), &"battle")
	director.round_call([2, 1])
	assert_eq(music.current_track(), &"match_point")
	director.enter_menu()
	assert_eq(music.current_track(), &"menu")


func test_stop_fades_out_both_tracks_and_forgets_the_track() -> void:
	_level_tracks()
	music.play(&"menu")
	assert_true(await _until_audible(&"menu"))
	music.play(&"battle")
	music.stop()
	assert_eq(music.current_track(), &"")
	for loop: FadedLoop in music.loops:
		assert_false(loop.is_playing())
	music.play(&"menu")
	assert_not_null(_loop_for(&"menu"), "it plays again after a stop")


func test_a_track_without_music_plays_nothing() -> void:
	_level_tracks()
	music.play(&"menu")
	music.play(&"no_such_track")
	assert_push_error("no_such_track")
	assert_eq(music.current_track(), &"menu", "the music playing carries on")
	assert_not_null(_loop_for(&"menu"))


func test_it_plays_on_through_a_paused_tree() -> void:
	assert_eq(music.process_mode, Node.PROCESS_MODE_ALWAYS, "music carries on through pauses")
	for loop: FadedLoop in music.loops:
		assert_eq(loop.get_parent(), music)
