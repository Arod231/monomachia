extends GutTest
## The game's flow in main.tscn, headless and without the clock: title over
## the duel behind the menus -> main menu -> Duel against the computer -> the
## results -> Rematch or Main menu, and pause during play, with the music each
## screen and match asks GameServices for, and the menus' sounds.

const MainScript := preload("res://scenes/main.gd")

var main: Node
var host: MatchHost
## Every menu sound GameServices plays during a test: {cue, bus}.
var ui_log: Array[Dictionary] = []
var _record_ui: Callable


func before_each() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# These tests don't need the shrine: the stand-in keeps them fast.
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	host = main.get_node("MatchHost")
	host.auto_run = false
	ui_log.clear()
	_record_ui = func(cue: StringName, voice: Node) -> void: ui_log.append({"cue": cue, "bus": voice.get("bus")})
	_ui_sounds().played.connect(_record_ui)


func after_each() -> void:
	_ui_sounds().played.disconnect(_record_ui)


func _ui_sounds() -> SoundPlayer:
	return get_tree().root.get_node("GameServices").get("ui_sounds")


func _ui_cues() -> Array[StringName]:
	var cues: Array[StringName] = []
	for entry: Dictionary in ui_log:
		cues.append(entry["cue"])
		assert_eq(entry["bus"], &"UI", "%s on the UI bus" % entry["cue"])
	return cues


func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = pressed
		get_viewport().push_input(e)


func _screen() -> int:
	return int(main.get("screen"))


func test_matches_default_to_the_default_arena() -> void:
	var fresh: Node = autofree((load("res://scenes/main.tscn") as PackedScene).instantiate())
	assert_eq(fresh.get("arena_id"), MatchConfig.DEFAULT_ARENA)


func test_the_duel_behind_the_menus_and_every_match_use_its_arena() -> void:
	assert_eq(host.config.arena_id, ArenaScenes.STANDIN, "the duel behind the menus")
	main.call("start_duel")
	assert_eq(host.config.arena_id, ArenaScenes.STANDIN, "a duel")
	main.call("start_watch")
	assert_eq(host.config.arena_id, ArenaScenes.STANDIN, "a watch match")


func test_it_opens_on_the_title_over_a_computer_duel() -> void:
	assert_eq(_screen(), MainScript.Screen.TITLE)
	assert_true((main.get("title") as Control).visible)
	assert_true(host.is_started())
	assert_true(host.attract, "the duel behind the menus")
	assert_false(host.is_playing())


func test_the_title_leads_to_the_main_menu() -> void:
	main.call("show_main_menu")
	assert_eq(_screen(), MainScript.Screen.MENU)
	var menu: MenuScreen = main.get("main_menu")
	assert_true(menu.visible)
	var labels: Array[String] = []
	for b: Button in menu.buttons:
		labels.append(b.text.get_slice("\n", 0))
	assert_eq(labels, ["Duel", "Training", "Watch", "How to play", "Controls", "Settings", "Quit"] as Array[String])
	var subs: Array[String] = []
	for b: Button in menu.buttons:
		subs.append((b.get_node("Sub") as Label).text)
	assert_eq(subs, ["vs computer", "parries and counters", "computer vs computer", "rules and move lists", "keys and buttons", "picture and sound", "to the desktop"] as Array[String], "each entry's sublabel")


func test_the_main_menu_hides_the_title_and_stays_open_while_the_duel_plays() -> void:
	main.call("show_main_menu")
	host.step(420)
	await get_tree().process_frame
	assert_eq(_screen(), MainScript.Screen.MENU)
	assert_false((main.get("title") as Control).visible, "the title is closed")
	assert_true((main.get("main_menu") as Control).visible)


func test_back_on_the_main_menu_returns_to_the_title() -> void:
	main.call("show_main_menu")
	_press_key(KEY_ESCAPE)
	assert_eq(_screen(), MainScript.Screen.TITLE)
	assert_true((main.get("title") as Control).visible)
	assert_false((main.get("main_menu") as Control).visible)


## Presses `step` until the select's `item` has the focus.
func _walk_to(item: Control, step: Callable) -> void:
	var select: FighterSelect = main.get("select")
	for _i: int in 8:
		if select.focused_item() == item:
			return
		step.call()
	assert_eq(select.focused_item(), item, "reached %s" % item.name)


func test_a_keyboard_alone_walks_from_the_title_to_a_duel() -> void:
	_press_key(KEY_A)
	assert_eq(_screen(), MainScript.Screen.MENU, "any key goes on")
	await get_tree().process_frame
	_press_key(KEY_ENTER)
	assert_eq(_screen(), MainScript.Screen.SELECT, "Duel opens the fighter select")
	await get_tree().process_frame
	var select: FighterSelect = main.get("select")
	_press_key(KEY_RIGHT)
	_walk_to(select.confirm, _press_key.bind(KEY_DOWN))
	_press_key(KEY_ENTER)
	await get_tree().process_frame
	_walk_to(select.skill_row, _press_key.bind(KEY_DOWN))
	_press_key(KEY_LEFT)
	_walk_to(select.confirm, _press_key.bind(KEY_DOWN))
	_press_key(KEY_ENTER)
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_eq(host.config.mode, MatchConfig.DUEL)
	assert_eq([host.config.sides[0].fighter_id, host.config.sides[1].fighter_id], [&"hunter", &"hunter"])
	assert_eq(host.config.sides[1].difficulty, &"easy")
	assert_eq([host.config.sides[0].palette, host.config.sides[1].palette], [0, 1], "the mirror's second palette")
	assert_eq(host.config.arena_id, ArenaScenes.STANDIN, "the test's arena")


func test_a_controller_alone_walks_from_the_title_to_a_duel() -> void:
	_press_pad(JOY_BUTTON_Y)
	assert_eq(_screen(), MainScript.Screen.MENU, "any button goes on")
	await get_tree().process_frame
	_press_pad(JOY_BUTTON_DPAD_DOWN)
	_press_pad(JOY_BUTTON_DPAD_UP)
	_press_pad(JOY_BUTTON_A)
	assert_eq(_screen(), MainScript.Screen.SELECT)
	await get_tree().process_frame
	var select: FighterSelect = main.get("select")
	_walk_to(select.confirm, _press_pad.bind(JOY_BUTTON_DPAD_DOWN))
	_press_pad(JOY_BUTTON_A)
	await get_tree().process_frame
	_walk_to(select.confirm, _press_pad.bind(JOY_BUTTON_DPAD_DOWN))
	_press_pad(JOY_BUTTON_A)
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_eq(host.config.mode, MatchConfig.DUEL)
	assert_eq([host.config.sides[0].weapon_id, host.config.sides[1].weapon_id], [&"katana", &"katana"], "the defaults: the Hunter mirror")


func test_watch_opens_the_select_for_watch() -> void:
	main.call("show_main_menu")
	await get_tree().process_frame
	_press_key(KEY_DOWN) # Training
	_press_key(KEY_DOWN) # Watch
	_press_key(KEY_ENTER)
	assert_eq(_screen(), MainScript.Screen.SELECT)
	var select: FighterSelect = main.get("select")
	assert_eq(select.draft.mode, MatchConfig.WATCH)
	assert_eq(select.side_title.text, "Red fighter")
	select.show_side(1)
	select.confirm.pressed.emit()
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_eq(host.config.mode, MatchConfig.WATCH)
	assert_eq(host.config.human_count(), 0)


func test_back_steps_through_the_select_to_the_main_menu_on_duel() -> void:
	main.call("show_main_menu")
	await get_tree().process_frame
	_press_key(KEY_ENTER)
	var select: FighterSelect = main.get("select")
	select.show_side(1)
	_press_key(KEY_ESCAPE)
	assert_eq(_screen(), MainScript.Screen.SELECT, "the first Back steps to your side")
	assert_eq(select.side, 0)
	_press_key(KEY_ESCAPE)
	assert_eq(_screen(), MainScript.Screen.MENU, "the next leaves the select")
	await get_tree().process_frame
	var menu: MenuScreen = main.get("main_menu")
	assert_eq(menu.focused_button(), menu.buttons[0], "back on Duel")


func test_the_last_picks_return() -> void:
	main.call("open_select", MatchConfig.DUEL)
	var select: FighterSelect = main.get("select")
	var third: StringName = Moves.KATANA.abilities[2]
	MatchSelection.set_ability(select.draft, 0, 0, third)
	MatchSelection.set_difficulty(select.draft, 1, &"hard")
	select.show_side(1)
	select.confirm.pressed.emit()
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	main.call("quit_to_menu")
	main.call("open_select", MatchConfig.DUEL)
	assert_eq(select.draft.sides[0].resolved_abilities()[0], third, "the block ability")
	assert_eq(select.draft.sides[1].difficulty, &"hard", "the skill")
	main.call("open_select", MatchConfig.WATCH)
	assert_eq(select.draft.sides[0].resolved_abilities(), Moves.KATANA.default_abilities, "each mode keeps its own")


func test_leaving_the_select_keeps_nothing() -> void:
	main.call("open_select", MatchConfig.DUEL)
	var select: FighterSelect = main.get("select")
	MatchSelection.set_difficulty(select.draft, 1, &"hard")
	select.step_back()
	main.call("open_select", MatchConfig.DUEL)
	assert_eq(select.draft.sides[1].difficulty, &"normal")


func test_test_runs_neither_read_nor_write_the_saved_picks() -> void:
	var selection: MatchSelection = main.get("selection")
	assert_false(selection.persist, "MONOMACHIA_DEFAULT_SETTINGS is set for test runs")


func test_a_duel_runs_from_the_menu_to_the_results_and_back() -> void:
	main.call("show_main_menu")
	main.call("start_duel")
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_false(host.attract)
	assert_true(host.is_playing())
	assert_eq(host.config.mode, MatchConfig.DUEL)
	assert_eq(host.config.sides[0].fighter_id, &"hunter")
	assert_eq(host.config.sides[0].weapon_id, &"katana")
	assert_true(host.config.sides[0].is_human())
	assert_eq(host.config.sides[1].fighter_id, &"hunter")
	assert_eq(host.config.sides[1].weapon_id, &"katana")
	assert_eq(host.config.sides[1].difficulty, &"normal")
	# nobody touches the controls: the computer wins
	var steps: int = 0
	while _screen() != MainScript.Screen.RESULTS and steps < 60 * 60 * 12:
		host.step(1)
		steps += 1
	assert_eq(_screen(), MainScript.Screen.RESULTS)
	var results: ResultsScreen = main.get("results_screen")
	assert_true(results.visible)
	assert_eq(results.results.winner, 1)
	assert_eq(results.results.wins[1], 3)
	assert_eq(results.results.title(), "Defeat")
	var seed_before: int = host.config.world_seed
	main.call("rematch")
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_true(host.is_playing())
	assert_ne(host.config.world_seed, seed_before, "a rematch takes a new seed")
	assert_eq(host.config.sides[1].weapon_id, &"katana", "the same loadouts")
	main.call("quit_to_menu")
	assert_eq(_screen(), MainScript.Screen.MENU)
	assert_true(host.attract)


func test_watch_starts_computer_against_computer() -> void:
	main.call("start_watch")
	assert_eq(host.config.mode, MatchConfig.WATCH)
	assert_eq(host.config.human_count(), 0)
	assert_eq((host.get_node("View") as MatchView).camera.mode, CameraRig.Mode.WATCH)


func test_pause_opens_the_pause_menu_and_resume_closes_it() -> void:
	main.call("start_duel")
	host.step(30)
	host.pause()
	assert_eq(_screen(), MainScript.Screen.PAUSED)
	assert_true((main.get("pause_menu") as MenuScreen).visible)
	assert_eq(host.step(5), 0, "nothing moves while paused")
	main.call("resume")
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_false((main.get("pause_menu") as MenuScreen).visible)
	assert_eq(host.step(5), 5)


func test_resume_from_the_host_closes_the_pause_menu() -> void:
	# Start or the pause binding resumes in the host (see test_match_host)
	main.call("start_duel")
	host.pause()
	host.resume()
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_false((main.get("pause_menu") as MenuScreen).visible)


# ------------------------------------------------------------------ music

func _music() -> MusicPlayer:
	return get_tree().root.get_node("GameServices").get("music")


func test_the_title_and_the_menus_play_the_menu_track() -> void:
	assert_eq(_music().current_track(), MusicDirector.MENU, "the title")
	main.call("show_main_menu")
	assert_eq(_music().current_track(), MusicDirector.MENU, "the main menu")


func test_the_music_follows_a_duel_to_match_point_and_back_to_the_menu() -> void:
	main.call("start_duel")
	assert_eq(_music().current_track(), MusicDirector.BATTLE, "a played match")
	# The track after each round's end and each round call.
	var log: Array[Dictionary] = []
	host.sim_event.connect(func(e: Dictionary) -> void:
		if str(e["t"]) in ["roundOver", "roundStart"]:
			log.append({"t": str(e["t"]), "wins": e.get("wins", []), "track": _music().current_track()}))
	var steps: int = 0
	while _screen() != MainScript.Screen.RESULTS and steps < 60 * 60 * 12:
		host.step(1)
		steps += 1
		if steps == 600:
			host.pause()
			assert_eq(_music().current_track(), MusicDirector.BATTLE, "a pause keeps the music")
			host.resume()
	assert_eq(_screen(), MainScript.Screen.RESULTS)
	var most: int = 0
	var track: StringName = MusicDirector.BATTLE
	for entry: Dictionary in log:
		if entry["t"] == "roundOver":
			most = (entry["wins"] as Array).max()
			assert_eq(entry["track"], track, "a round's end changes nothing: %s" % entry)
		else:
			track = MusicDirector.MATCH_POINT if most >= MusicDirector.MATCH_POINT_WINS else MusicDirector.BATTLE
			assert_eq(entry["track"], track, "the round call: %s" % entry)
	assert_eq(track, MusicDirector.MATCH_POINT, "the match reached match point")
	assert_eq(_music().current_track(), MusicDirector.MENU, "the results")
	main.call("rematch")
	assert_eq(_music().current_track(), MusicDirector.BATTLE, "a rematch starts on the battle track")
	main.call("quit_to_menu")
	assert_eq(_music().current_track(), MusicDirector.MENU, "quit to the main menu")


func test_the_duel_behind_the_menus_never_changes_the_track() -> void:
	host.step(600)
	# even when one of its fighters reaches two wins
	host.sim_event.emit({"t": "roundOver", "winner": 0, "wins": [2, 0], "perfect": false})
	host.sim_event.emit({"t": "roundStart", "round": 3})
	assert_eq(_music().current_track(), MusicDirector.MENU, "behind the title")
	main.call("show_main_menu")
	host.sim_event.emit({"t": "roundOver", "winner": 1, "wins": [2, 2], "perfect": false})
	host.sim_event.emit({"t": "roundStart", "round": 5})
	assert_eq(_music().current_track(), MusicDirector.MENU, "behind the main menu")


func test_watch_plays_the_battle_track() -> void:
	main.call("start_watch")
	assert_eq(_music().current_track(), MusicDirector.BATTLE)


func test_the_music_stops_when_the_screens_go() -> void:
	assert_eq(_music().current_track(), MusicDirector.MENU)
	remove_child(main)
	var track: StringName = _music().current_track()
	add_child(main)
	assert_eq(track, &"", "the game's screens are gone")


# ------------------------------------------------------------------ menu sounds

## Opens the main menu and lets its first button take the focus.
func _main_menu_open() -> MenuScreen:
	main.call("show_main_menu")
	await get_tree().process_frame
	var menu: MenuScreen = main.get("main_menu")
	assert_eq(menu.focused_button(), menu.buttons[0])
	return menu


func test_opening_a_menu_is_silent_and_moving_its_focus_plays_ui_move() -> void:
	var menu: MenuScreen = await _main_menu_open()
	assert_eq(_ui_cues(), [] as Array[StringName], "opening the menu")
	_press_key(KEY_DOWN)
	assert_eq(menu.focused_button(), menu.buttons[1])
	_press_key(KEY_S)
	assert_eq(menu.focused_button(), menu.buttons[2])
	menu.buttons[0].grab_focus()
	assert_eq(_ui_cues(), [&"ui_move", &"ui_move", &"ui_move"] as Array[StringName], "arrows, W/S and the mouse")


func test_pressing_a_button_plays_ui_select() -> void:
	await _main_menu_open()
	_press_key(KEY_ENTER)
	assert_eq(_screen(), MainScript.Screen.SELECT, "Enter chose Duel")
	main.call("start_duel")
	host.pause()
	_focus_first("pause_menu")
	_press_pad(JOY_BUTTON_A)
	assert_eq(_screen(), MainScript.Screen.PLAYING, "A chose Resume")
	assert_eq(_ui_cues(), [&"ui_select", &"ui_select"] as Array[StringName])


func test_back_plays_ui_back_and_the_menu_reopens_silently() -> void:
	await _main_menu_open()
	_press_key(KEY_DOWN)
	_press_pad(JOY_BUTTON_B)
	assert_eq(_screen(), MainScript.Screen.TITLE)
	_press_pad(JOY_BUTTON_A)
	assert_eq(_screen(), MainScript.Screen.MENU)
	await get_tree().process_frame
	assert_eq(_ui_cues(), [&"ui_move", &"ui_back", &"ui_confirm"] as Array[StringName],
		"reopened on its first button, from the second, without a move")


func test_going_on_from_the_title_plays_ui_confirm() -> void:
	_press_key(KEY_SPACE)
	assert_eq(_screen(), MainScript.Screen.MENU)
	await get_tree().process_frame
	assert_eq(_ui_cues(), [&"ui_confirm"] as Array[StringName], "and the menu it opens is silent")


func test_clicking_the_title_plays_ui_confirm() -> void:
	# Headless runs never route a click to a Control (no mouse is over the
	# window), so the click is handed to the title as the GUI would hand it.
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	(main.get("title") as TitleScreen)._gui_input(e)
	assert_eq(_screen(), MainScript.Screen.MENU)
	assert_eq(_ui_cues(), [&"ui_confirm"] as Array[StringName])


func test_the_results_screen_s_buttons_sound_too() -> void:
	main.call("start_duel")
	host.step(Match.INTRO_FRAMES + 10)
	host.match_finished.emit(host.results())
	await get_tree().process_frame
	_press_key(KEY_DOWN)
	_press_pad(JOY_BUTTON_B)
	assert_eq(_screen(), MainScript.Screen.MENU)
	assert_eq(_ui_cues(), [&"ui_move", &"ui_back"] as Array[StringName])


func test_the_duel_behind_the_menus_makes_no_sound() -> void:
	var match_log: Array[StringName] = []
	(host.get_node("Audio") as MatchAudio).player.played.connect(func(cue: StringName, _v: Node) -> void: match_log.append(cue))
	host.step(60 * 20)
	main.call("show_main_menu")
	host.step(60 * 20)
	assert_eq(match_log, [] as Array[StringName], "no match sound")
	assert_eq(_ui_cues(), [] as Array[StringName], "and no menu sound")


# ------------------------------------------------------------------ seeds

func test_attract_restarts_and_matches_share_one_seed_sequence() -> void:
	var attract_seed: int = host.config.world_seed
	assert_true(host.seed_source.is_valid(), "main hands the host its sequence")
	var restart_seed: int = int(host.seed_source.call())
	assert_ne(restart_seed, attract_seed, "an attract restart takes the next seed")
	main.call("start_duel")
	assert_ne(host.config.world_seed, attract_seed, "the Duel doesn't replay the attract duel's seed")
	assert_ne(host.config.world_seed, restart_seed, "nor the restart's")


# ------------------------------------------------------------------ a bad config

func test_a_config_the_host_refuses_goes_back_to_the_main_menu() -> void:
	main.call("start_duel")
	var bad: MatchConfig = MatchConfig.default_duel()
	bad.mode = &"ranked"
	assert_false(main.call("start_match", bad))
	assert_push_error("bad match config")
	assert_eq(_screen(), MainScript.Screen.MENU)
	assert_true((main.get("main_menu") as MenuScreen).visible)
	assert_true(host.attract, "the duel behind the menus runs")


# ------------------------------------------------------------------ controllers

func _press_pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = pressed
		get_viewport().push_input(e)


func _focus_first(menu_name: String) -> MenuScreen:
	var menu: MenuScreen = main.get(menu_name)
	menu.buttons[0].grab_focus()
	return menu


func test_a_controller_drives_the_menus() -> void:
	main.call("show_main_menu")
	_focus_first("main_menu")
	_press_pad(JOY_BUTTON_B)
	assert_eq(_screen(), MainScript.Screen.TITLE, "B on the main menu goes back to the title")
	_press_pad(JOY_BUTTON_A)
	assert_eq(_screen(), MainScript.Screen.MENU, "any button on the title goes on")
	_focus_first("main_menu")
	_press_pad(JOY_BUTTON_A)
	assert_eq(_screen(), MainScript.Screen.SELECT, "A chooses Duel")
	(main.get("select") as FighterSelect).locked_in.emit(MatchSelection.default_draft(MatchConfig.DUEL))
	assert_eq(_screen(), MainScript.Screen.PLAYING, "locked in")
	assert_eq(host.config.mode, MatchConfig.DUEL)
	host.pause()
	_focus_first("pause_menu")
	_press_pad(JOY_BUTTON_A)
	assert_eq(_screen(), MainScript.Screen.PLAYING, "A on Resume")
	host.pause()
	_press_pad(JOY_BUTTON_B)
	assert_eq(_screen(), MainScript.Screen.PLAYING, "B on the pause menu resumes")
	assert_false(host.is_paused())


func test_back_on_the_results_goes_to_the_main_menu() -> void:
	main.call("start_duel")
	host.step(Match.INTRO_FRAMES + 10)
	host.match_finished.emit(host.results())
	assert_eq(_screen(), MainScript.Screen.RESULTS)
	_focus_first("results_screen")
	_press_pad(JOY_BUTTON_B)
	assert_eq(_screen(), MainScript.Screen.MENU)
	assert_true(host.attract)


func test_the_input_feed_sees_the_presses_the_menus_take() -> void:
	var input: InputDevices = get_tree().root.get_node("GameServices").get("input")
	var before: InputDevices.LastUsed = input.last_used
	input.last_used = InputDevices.LastUsed.KEYBOARD
	main.call("show_main_menu")
	_press_pad(JOY_BUTTON_B)
	var seen: InputDevices.LastUsed = input.last_used
	input.last_used = before
	assert_eq(_screen(), MainScript.Screen.TITLE, "the menu took B")
	assert_eq(seen, InputDevices.LastUsed.PAD, "and the feed saw it: labels follow the controller")


func test_a_replay_file_plays_from_the_title() -> void:
	# milestone-1 task 6: --replay=<log> plays a recorded match, nobody in control
	assert_eq(host.record_dir, "", "test runs save no logs")
	main.call("start_watch")
	host.step(Match.INTRO_FRAMES + 120)
	var log_a: InputLog = host.input_log
	main.call("quit_to_menu")
	var path: String = "user://test_main_flow_replay.json"
	assert_eq(log_a.save(path), OK)
	assert_true(main.call("start_replay", path))
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_true(host.is_replaying())
	watch_signals(host)
	host.step(log_a.step_count() + 1)
	assert_true(get_signal_parameters(host, "replay_checked")[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_false(main.call("start_replay", "user://no_such_log.json"), "a missing log stays put")
	assert_push_error("no file")
