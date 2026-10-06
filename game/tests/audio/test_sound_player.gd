extends GutTest
## SoundPlayer: plays the sound bank's cues from pooled voices. Headless runs
## use the dummy audio driver, so these tests check what the player asks the
## voices to do (stream, bus, level, pitch, place), not what comes out.


func _player(flat: int = 4, spatial: int = 4) -> SoundPlayer:
	var player := SoundPlayer.new()
	player.flat_voices = flat
	player.spatial_voices = spatial
	player.auto_run = false
	player.rng.seed = 7
	add_child_autofree(player)
	return player


## Records every cue the player starts, with the voice's settings at that moment.
func _record(player: SoundPlayer) -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	player.played.connect(func(cue: StringName, voice: Node) -> void:
		log.append({
			"cue": cue, "voice": voice, "bus": voice.get("bus"),
			"path": (voice.get("stream") as AudioStream).resource_path,
			"volume_db": voice.get("volume_db"), "pitch": voice.get("pitch_scale"),
		}))
	return log


func _cues(log: Array[Dictionary]) -> Array[StringName]:
	var names: Array[StringName] = []
	for entry: Dictionary in log:
		names.append(entry["cue"])
	return names


func test_a_colossal_hit_plays_both_its_cues_on_combat() -> void:
	var player := _player()
	var log := _record(player)
	player.play_event({"t": "hit", "sound": "colossal", "heavy": true})
	assert_eq(_cues(log), [&"hit_colossal", &"crunch"] as Array[StringName])
	for entry: Dictionary in log:
		assert_eq(entry["bus"], &"Combat")
		assert_has(SoundBank.paths_for(entry["cue"]), entry["path"])
		assert_true((entry["voice"] as Node).get("playing"), "%s is playing" % entry["cue"])


func test_delayed_cues_fire_once_their_delay_has_passed() -> void:
	var player := _player()
	var log := _record(player)
	player.play_event({"t": "ko", "loser": 1, "winner": 0})
	assert_eq(_cues(log), [&"taiko_heavy", &"boom"] as Array[StringName])
	player.advance(0.05)
	assert_eq(log.size(), 2, "the gong waits 0.1 s")
	player.advance(0.06)
	assert_eq(_cues(log), [&"taiko_heavy", &"boom", &"gong"] as Array[StringName])
	player.advance(0.4)
	assert_eq(log.size(), 3, "the body fall waits 0.6 s")
	player.advance(0.1)
	assert_eq(_cues(log), [&"taiko_heavy", &"boom", &"gong", &"body_fall"] as Array[StringName])


func test_the_round_gong_rings_on_the_roll_s_last_stroke() -> void:
	var player := _player()
	var log := _record(player)
	player.play_event({"t": "roundStart", "round": 1})
	assert_eq(_cues(log), [&"round_roll"] as Array[StringName])
	player.advance(1.3)
	assert_eq(log.size(), 1)
	player.advance(0.05)
	assert_eq(_cues(log), [&"round_roll", &"gong"] as Array[StringName])


func test_a_hold_pauses_the_voices_and_the_delay_clock() -> void:
	var player := _player()
	var log := _record(player)
	player.play_event({"t": "roundStart", "round": 1})
	var roll: Node = log[0]["voice"]
	player.set_held(true)
	assert_true(player.is_held())
	assert_true(roll.get("stream_paused"), "the playing roll is paused")
	player.advance(5.0)
	assert_eq(log.size(), 1, "no gong while held")
	player.set_held(false)
	assert_false(roll.get("stream_paused"), "the roll carries on")
	player.advance(1.3)
	assert_eq(log.size(), 1, "the clock stood still while held")
	player.advance(0.05)
	assert_eq(_cues(log), [&"round_roll", &"gong"] as Array[StringName])


func test_an_event_during_a_hold_waits_for_the_release() -> void:
	var player := _player()
	var log := _record(player)
	player.set_held(true)
	player.play_event({"t": "block", "heavy": false})
	player.advance(0.5)
	assert_eq(log.size(), 0, "nothing starts while held")
	player.set_held(false)
	player.advance(0.0)
	assert_eq(_cues(log), [&"clang_light"] as Array[StringName])


func test_a_cue_played_directly_during_a_hold_sounds_even_on_a_stolen_voice() -> void:
	var player := _player(1, 1)
	var log := _record(player)
	player.play_cue(&"ui_move")
	player.set_held(true)
	player.play_cue(&"ui_back")
	assert_eq(log[1]["voice"], log[0]["voice"], "the only voice is stolen")
	assert_false((log[1]["voice"] as Node).get("stream_paused"), "the new cue isn't left paused")
	player.set_held(false)
	assert_true((log[1]["voice"] as Node).get("playing"))


func test_no_cue_repeats_its_last_variation() -> void:
	var player := _player(8, 8)
	var log := _record(player)
	for i in 40:
		player.play_cue(&"whoosh_light")
	var seen := {}
	for i in log.size():
		seen[log[i]["path"]] = true
		if i > 0:
			assert_ne(log[i]["path"], log[i - 1]["path"], "play %d repeats the last variation" % i)
	assert_eq(seen.size(), SoundBank.CUES[&"whoosh_light"]["files"].size(), "every variation gets played")


func test_level_and_pitch_follow_the_cue() -> void:
	var player := _player()
	var log := _record(player)
	for i in 20:
		player.play_cue(&"hit_blade", null, -3.0)
	for entry: Dictionary in log:
		assert_almost_eq(float(entry["volume_db"]), -5.0, 0.0001, "the cue's -2 dB plus the extra -3 dB")
		assert_between(float(entry["pitch"]), 0.94, 1.06)
	assert_ne(log[0]["pitch"], log[1]["pitch"], "the pitch varies")


func test_a_stuck_weapon_plays_on_the_foley_bus_at_its_cue_level() -> void:
	var player := _player()
	var log := _record(player)
	player.play_event({"t": "weaponStuck", "owner": 0})
	assert_eq(_cues(log), [&"weapon_bounce", &"weapon_clatter"] as Array[StringName])
	assert_almost_eq(float(log[0]["volume_db"]), -6.0, 0.001)
	assert_eq(log[0]["bus"], &"Foley")


func test_a_spatial_cue_with_a_position_plays_from_a_3d_voice_there() -> void:
	var player := _player()
	var log := _record(player)
	var at := Vector3(1.5, 1.2, -3.0)
	player.play_cue(&"hit_blade", at)
	assert_true(log[0]["voice"] is AudioStreamPlayer3D)
	assert_almost_eq((log[0]["voice"] as Node3D).global_position, at, Vector3.ONE * 0.0001)


func test_3d_voices_fall_off_gently_and_stay_bright() -> void:
	var player := SoundPlayer.new()
	player.unit_size = 6.0
	add_child_autofree(player)
	var voice := player.play_cue(&"hit_blade", Vector3(0, 1, -7)) as AudioStreamPlayer3D
	assert_eq(voice.attenuation_model, AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	assert_eq(voice.unit_size, 6.0, "a cue plays at its own level unit_size metres away")
	assert_almost_eq(voice.attenuation_filter_cutoff_hz, 20500.0, 0.1, "no distance muffling")


func test_a_near_3d_cue_is_at_most_near_boost_over_its_level() -> void:
	var player := _player()
	player.near_boost_db = 3.0
	var quiet := player.play_cue(&"footstep", Vector3(0, 0, -1)) as AudioStreamPlayer3D
	assert_almost_eq(quiet.max_db, -16.0 + 3.0, 0.001, "a footstep by the camera stays a footstep")
	var loud := player.play_cue(&"hit_colossal", Vector3(0, 1, -1), -1.0) as AudioStreamPlayer3D
	assert_almost_eq(loud.max_db, 0.0 - 1.0 + 3.0, 0.001)


func test_flat_cues_and_cues_without_a_position_play_flat() -> void:
	var player := _player()
	var log := _record(player)
	player.play_cue(&"parry_ring", Vector3(1, 1, 1))
	player.play_cue(&"hit_blade")
	assert_eq(log.size(), 2)
	for entry: Dictionary in log:
		assert_true(entry["voice"] is AudioStreamPlayer, "%s plays flat" % entry["cue"])


func test_an_event_is_placed_by_the_position_resolver() -> void:
	var player := _player()
	var log := _record(player)
	var at := Vector3(-2.0, 1.3, 4.0)
	var events: Array[Dictionary] = []
	player.play_event({"t": "parry", "kind": "parry"}, func(e: Dictionary) -> Variant:
		events.append(e)
		return at)
	assert_eq(events.size(), 1, "the resolver is asked once per event")
	assert_eq(_cues(log), [&"parry_contact", &"parry_ring"] as Array[StringName])
	assert_true(log[0]["voice"] is AudioStreamPlayer3D, "the contact is placed")
	assert_almost_eq((log[0]["voice"] as Node3D).global_position, at, Vector3.ONE * 0.0001)
	assert_true(log[1]["voice"] is AudioStreamPlayer, "the ring stays flat")


func test_a_full_pool_steals_its_oldest_voice_and_never_grows() -> void:
	var player := _player(2, 2)
	var log := _record(player)
	for i in 4:
		player.play_cue(&"hit_blade", Vector3(i, 0, 0))
	for i in 3:
		player.play_cue(&"ui_move")
	assert_eq(log[2]["voice"], log[0]["voice"], "the third 3D cue takes the first voice")
	assert_eq(log[3]["voice"], log[1]["voice"], "the fourth takes the second")
	assert_ne(log[4]["voice"], log[5]["voice"])
	assert_eq(log[6]["voice"], log[4]["voice"], "the flat pool steals too")
	assert_almost_eq((log[3]["voice"] as Node3D).global_position, Vector3(3, 0, 0), Vector3.ONE * 0.0001)
	assert_eq(player.get_child_count(), 4, "two voices of each kind")


func test_a_free_voice_is_used_before_stealing() -> void:
	var player := _player(2, 2)
	var log := _record(player)
	player.play_cue(&"ui_move")
	(log[0]["voice"] as AudioStreamPlayer).stop()
	player.play_cue(&"ui_move")
	player.play_cue(&"ui_move")
	assert_eq(log[1]["voice"], log[0]["voice"], "the stopped voice is free again")
	assert_ne(log[2]["voice"], log[1]["voice"], "the other voice is still free")


func test_an_unknown_event_plays_nothing() -> void:
	var player := _player()
	var log := _record(player)
	player.play_event({"t": "nonsense"})
	player.play_event({"t": "evade"})
	player.advance(5.0)
	assert_eq(log.size(), 0)


func test_stop_all_silences_the_voices_and_drops_pending_cues() -> void:
	var player := _player()
	var log := _record(player)
	player.play_event({"t": "ko", "loser": 1, "winner": 0})
	player.set_held(true)
	player.stop_all()
	assert_false(player.is_held(), "stopping releases the hold")
	for voice: Node in player.get_children():
		assert_false(voice.get("playing"), "%s stopped" % voice.name)
		assert_false(voice.get("stream_paused"), "%s isn't left paused" % voice.name)
	player.advance(2.0)
	assert_eq(log.size(), 2, "the gong and the body fall were dropped")


func test_a_player_is_quiet_until_it_plays_and_after_it_stops() -> void:
	var player := _player()
	assert_true(player.is_quiet())
	player.play_event({"t": "ko", "loser": 1, "winner": 0})
	assert_false(player.is_quiet())
	player.stop_all()
	assert_true(player.is_quiet())


func test_a_waiting_cue_or_a_held_voice_is_not_quiet() -> void:
	var player := _player()
	var voice: Node = player.play_cue(&"ui_move")
	voice.call("stop")
	assert_true(player.is_quiet(), "the only voice finished")
	player.play_event({"t": "roundStart", "round": 1})
	player.set_held(true)
	player.stop_all()
	player.play_event({"t": "counter", "kind": "parry"})
	assert_false(player.is_quiet(), "the counter's taiko waits 30 ms")
	player.advance(0.05)
	player.stop_all()
	player.play_cue(&"ui_move")
	player.set_held(true)
	assert_false(player.is_quiet(), "a paused voice still has its sound")


func test_delayed_cues_run_on_the_process_clock_when_auto_run() -> void:
	var player := _player()
	player.auto_run = true
	var log := _record(player)
	player.play_event({"t": "ko", "loser": 1, "winner": 0})
	player._process(0.2)
	assert_eq(_cues(log), [&"taiko_heavy", &"boom", &"gong"] as Array[StringName])


func test_nothing_is_missing_for_the_real_bank() -> void:
	var player := _player()
	var cues: Array[StringName] = []
	cues.assign(SoundBank.CUES.keys())
	player.preload_cues(cues)
	assert_eq(player.missing, PackedStringArray())
	var path: String = SoundBank.paths_for(&"gong")[0]
	assert_same(player.stream_for(path), load(path), "streams come from the cache")


func test_a_missing_file_is_listed_and_reported_once() -> void:
	var player := _player()
	var path := "res://assets/audio/sfx/no_such_sound.wav"
	assert_null(player.stream_for(path))
	assert_null(player.stream_for(path))
	assert_eq(player.missing, PackedStringArray([path]))
	assert_push_error("no_such_sound.wav")
	assert_push_error_count(1, "reported once")


func test_every_player_lists_a_missing_file_it_asks_for() -> void:
	var first := _player()
	var second := _player()
	var path := "res://assets/audio/sfx/no_such_sound_either.wav"
	assert_null(first.stream_for(path))
	assert_null(second.stream_for(path))
	assert_eq(second.missing, PackedStringArray([path]), "the second player lists it too")
	assert_push_error_count(2, "each player reports it")


func test_an_unknown_cue_is_listed_and_plays_nothing() -> void:
	var player := _player()
	var log := _record(player)
	assert_null(player.play_cue(&"no_such_cue"))
	assert_null(player.play_cue(&"no_such_cue"))
	assert_eq(log.size(), 0)
	assert_eq(player.missing, PackedStringArray(["no_such_cue"]))
	assert_push_error("no_such_cue")
	assert_push_error_count(1, "reported once")
