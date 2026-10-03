extends GutTest
## The music director picks the menu, battle and match-point tracks, and the
## track files match their declared tempo and length.


func test_starts_on_the_menu_track() -> void:
	var director := MusicDirector.new()
	assert_eq(director.current_track(), MusicDirector.MENU)
	assert_eq(director.enter_menu(), MusicDirector.MENU)


func test_a_match_plays_the_battle_track() -> void:
	var director := MusicDirector.new()
	assert_eq(director.enter_match(), MusicDirector.BATTLE)
	assert_eq(director.handle_event({"t": "roundStart", "round": 1}), MusicDirector.BATTLE)


func test_switches_to_match_point_at_the_round_call_after_a_two_one_score() -> void:
	var director := MusicDirector.new()
	director.enter_match()
	director.handle_event({"t": "roundOver", "winner": 0, "wins": [1, 0], "perfect": false})
	assert_eq(director.handle_event({"t": "roundStart", "round": 2}), MusicDirector.BATTLE)
	director.handle_event({"t": "roundOver", "winner": 1, "wins": [1, 1], "perfect": false})
	assert_eq(director.handle_event({"t": "roundStart", "round": 3}), MusicDirector.BATTLE)
	director.handle_event({"t": "roundOver", "winner": 0, "wins": [2, 1], "perfect": false})
	# still the battle track until the round is called
	assert_eq(director.current_track(), MusicDirector.BATTLE)
	assert_eq(director.handle_event({"t": "roundStart", "round": 4}), MusicDirector.MATCH_POINT)
	# and it stays there for a 2-2 final round
	director.handle_event({"t": "roundOver", "winner": 1, "wins": [2, 2], "perfect": false})
	assert_eq(director.handle_event({"t": "roundStart", "round": 5}), MusicDirector.MATCH_POINT)


func test_round_call_directly_with_wins() -> void:
	var director := MusicDirector.new()
	director.enter_match()
	assert_eq(director.round_call([0, 1]), MusicDirector.BATTLE)
	assert_eq(director.round_call([1, 2]), MusicDirector.MATCH_POINT)


func test_back_to_the_menu_after_a_match() -> void:
	var director := MusicDirector.new()
	director.enter_match()
	director.round_call([2, 0])
	assert_eq(director.enter_menu(), MusicDirector.MENU)
	# a new match starts from the battle track again
	assert_eq(director.enter_match(), MusicDirector.BATTLE)
	assert_eq(director.handle_event({"t": "roundStart", "round": 1}), MusicDirector.BATTLE)


func test_emits_track_changed_only_on_changes() -> void:
	var director := MusicDirector.new()
	watch_signals(director)
	director.enter_menu()
	assert_signal_emit_count(director, "track_changed", 0)
	director.enter_match()
	director.handle_event({"t": "roundStart", "round": 1})
	assert_signal_emit_count(director, "track_changed", 1)
	assert_signal_emitted_with_parameters(director, "track_changed", [MusicDirector.BATTLE])


func test_track_tempos_are_the_design_tempos() -> void:
	assert_eq(int(MusicDirector.track_info(MusicDirector.MENU)["bpm"]), 110)
	assert_eq(int(MusicDirector.track_info(MusicDirector.BATTLE)["bpm"]), 140)
	assert_eq(int(MusicDirector.track_info(MusicDirector.MATCH_POINT)["bpm"]), 160)


func test_track_files_load_loop_and_last_exactly_their_bars() -> void:
	for track: StringName in MusicDirector.TRACK_IDS:
		var info := MusicDirector.track_info(track)
		assert_false(info.is_empty(), "no tracks.json entry for %s" % track)
		var stream := load(MusicDirector.track_path(track)) as AudioStreamWAV
		assert_not_null(stream, "%s does not load" % track)
		if stream == null:
			continue
		assert_true(stream.stereo, "%s should be stereo" % track)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s should loop" % track)
		var expected := float(info["bars"]) * float(info["beats_per_bar"]) * 60.0 / float(info["bpm"])
		assert_almost_eq(stream.get_length(), expected, 0.001, "%s length vs its tempo" % track)
		assert_almost_eq(float(info["seconds"]), expected, 0.001)
		# the loop spans the whole file, so the end flows straight into the start
		assert_eq(stream.loop_begin, 0)
		assert_almost_eq(stream.loop_end, roundi(expected * stream.mix_rate), 1, "%s loop end" % track)


func test_seconds_to_next_bar() -> void:
	# 140 BPM: a bar of four beats lasts 60 / 140 * 4 seconds.
	var bar := 60.0 / 140.0 * 4.0
	assert_almost_eq(MusicDirector.seconds_to_next_bar(MusicDirector.BATTLE, 0.25 * bar), 0.75 * bar, 0.0001)
	assert_almost_eq(MusicDirector.seconds_to_next_bar(MusicDirector.BATTLE, 2.0 * bar), 0.0, 0.0001)
