extends GutTest
## The GameServices autoload: the settings (their graphics preset applied at
## start), one ControlProfiles, one InputDevices with its InputFeed in the tree
## for the whole game, a pause when the window loses focus during a match, and
## the music: one MusicDirector and the MusicPlayer that follows it.


func _services() -> Node:
	return get_tree().root.get_node_or_null("GameServices")


func after_each() -> void:
	_services().call("stop_music")


func _host() -> MatchHost:
	var host: MatchHost = MatchHost.new()
	host.auto_run = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	return host


func test_the_autoload_is_registered() -> void:
	var services: Node = _services()
	assert_not_null(services, "GameServices is an autoload")
	assert_eq(ProjectSettings.get_setting("autoload/GameServices"), "*res://core/game_services.gd")


func test_it_owns_one_input_with_its_feed_in_the_tree() -> void:
	var services: Node = _services()
	var input: InputDevices = services.get("input")
	var feed: InputFeed = services.get("feed")
	var profiles: ControlProfiles = services.get("profiles")
	assert_not_null(input)
	assert_not_null(profiles)
	assert_not_null(feed)
	assert_true(feed.is_inside_tree(), "the feed sees every event")
	assert_eq(feed.get_parent(), services)
	assert_same(feed.input, input, "the feed hands events to the shared input")
	assert_eq(services.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_it_owns_the_settings_and_applied_their_preset_at_start() -> void:
	var services: Node = _services()
	var settings: GameSettings = services.get("settings")
	assert_not_null(settings)
	var preset: GraphicsPreset = services.call("graphics_preset")
	assert_eq(preset.id, settings.graphics_preset_id)
	assert_eq(preset.id, GraphicsPreset.DEFAULT_ID, "test runs use the default settings (godot.mjs sets %s)" % GameSettings.DEFAULTS_ENV)
	var root: Viewport = get_tree().root
	assert_eq(root.screen_space_aa, preset.screen_space_aa, "the root viewport follows the preset")
	assert_eq(root.msaa_3d, preset.msaa_3d)
	assert_almost_eq(root.scaling_3d_scale, preset.render_scale, 0.001)


func test_it_applied_the_settings_volumes_at_start() -> void:
	var settings: GameSettings = _services().get("settings")
	var master := AudioServer.get_bus_index(&"Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(master),
		GameSettings.layout_volume_db(&"Master") + linear_to_db(settings.master_volume / 100.0), 1e-4)
	var music := AudioServer.get_bus_index(&"Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(music),
		GameSettings.layout_volume_db(&"Music") + linear_to_db(settings.music_volume / 100.0), 1e-4)


func test_a_host_without_its_own_input_takes_the_shared_one() -> void:
	var host: MatchHost = MatchHost.new()
	host.auto_run = false
	add_child_autofree(host)
	host.start(MatchConfig.default_watch())
	assert_same(host.input, _services().get("input"))
	assert_same(host.profiles, _services().get("profiles"))


func test_losing_focus_pauses_a_match_being_played() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.default_duel())
	assert_same(_services().call("current_match"), host)
	assert_true(host.is_playing())
	(_services().get("feed") as InputFeed).focus_lost.emit()
	assert_true(host.is_paused(), "focus loss paused the match")


func test_losing_focus_leaves_the_duel_behind_the_menus_running() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.attract(), true)
	assert_null(_services().call("current_match"))
	(_services().get("feed") as InputFeed).focus_lost.emit()
	assert_false(host.is_paused())


func test_a_stopped_match_is_forgotten() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.default_duel())
	host.stop()
	assert_null(_services().call("current_match"))
	(_services().get("feed") as InputFeed).focus_lost.emit()
	assert_false(host.is_paused())


func test_it_owns_the_music_and_starts_none_by_itself() -> void:
	var services: Node = _services()
	var music: MusicPlayer = services.get("music")
	assert_not_null(services.get("music_director"))
	assert_not_null(music)
	assert_eq(music.get_parent(), services, "the music lives as long as the game")
	assert_eq(music.current_track(), &"", "silent until a screen asks for music")


func test_the_screens_and_the_match_choose_the_track() -> void:
	var services: Node = _services()
	var music: MusicPlayer = services.get("music")
	services.call("play_menu_music")
	assert_eq(music.current_track(), MusicDirector.MENU)
	services.call("play_match_music")
	assert_eq(music.current_track(), MusicDirector.BATTLE)
	services.call("music_event", {"t": "roundOver", "winner": 0, "wins": [2, 1], "perfect": false})
	assert_eq(music.current_track(), MusicDirector.BATTLE, "not at the round's end")
	services.call("music_event", {"t": "roundStart", "round": 4})
	assert_eq(music.current_track(), MusicDirector.MATCH_POINT, "at the next round call")
	services.call("play_menu_music")
	assert_eq(music.current_track(), MusicDirector.MENU)
	services.call("stop_music")
	assert_eq(music.current_track(), &"")


func test_asking_again_after_a_stop_plays_the_track_again() -> void:
	var services: Node = _services()
	var music: MusicPlayer = services.get("music")
	services.call("play_match_music")
	services.call("stop_music")
	services.call("play_match_music")
	assert_eq(music.current_track(), MusicDirector.BATTLE, "the director was already on battle")
	services.call("play_menu_music")
	services.call("stop_music")
	services.call("play_menu_music")
	assert_eq(music.current_track(), MusicDirector.MENU)


func test_it_plays_the_menu_sounds_on_the_ui_bus() -> void:
	var services: Node = _services()
	var sounds: SoundPlayer = services.get("ui_sounds")
	assert_not_null(sounds)
	assert_eq(sounds.get_parent(), services, "they live as long as the game, so a press that changes screens still sounds")
	var log: Array[Dictionary] = []
	var record := func(cue: StringName, voice: Node) -> void: log.append({"cue": cue, "voice": voice})
	sounds.played.connect(record)
	for event: StringName in [&"ui_move", &"ui_select", &"ui_confirm", &"ui_back"]:
		services.call("play_ui", event)
	sounds.played.disconnect(record)
	assert_eq(log.map(func(e: Dictionary) -> StringName: return e["cue"]), [&"ui_move", &"ui_select", &"ui_confirm", &"ui_back"])
	for entry: Dictionary in log:
		assert_true(entry["voice"] is AudioStreamPlayer, "%s plays flat" % entry["cue"])
		assert_eq((entry["voice"] as AudioStreamPlayer).bus, &"UI")
		assert_true((entry["voice"] as AudioStreamPlayer).playing)
	assert_eq(sounds.missing, PackedStringArray(), "every menu sound loads")
