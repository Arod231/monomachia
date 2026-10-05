extends GutTest
## The screens of tasks 22.8-22.10 in the game's flow (main.tscn): Controls
## and Settings from the main menu and back with keys and with a controller,
## each saving where a test run may write, never the player's own files.

var main: Node
var host: MatchHost
var stack: ScreenStack


func before_each() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	host = main.get_node("MatchHost")
	host.auto_run = false
	stack = main.get("stack")
	main.call("show_main_menu")
	await get_tree().process_frame


func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		get_viewport().push_input(e)


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		get_viewport().push_input(e)


func _entry_names() -> Array[String]:
	var out: Array[String] = []
	for b: Button in (main.get("main_menu") as MenuScreen).buttons:
		out.append(b.text)
	return out


## Moves the main menu's focus to an entry with the down key or the D-pad.
func _walk_to(entry: String, pad: bool) -> void:
	var menu: MenuScreen = main.get("main_menu")
	for i: int in menu.buttons.size():
		var f: Button = menu.focused_button()
		if f != null and f.text == entry:
			return
		if pad:
			_pad(JOY_BUTTON_DPAD_DOWN)
		else:
			_key(KEY_DOWN)
	fail_test("%s not reached" % entry)


func test_controls_and_settings_come_before_quit_on_the_main_menu() -> void:
	var names: Array[String] = _entry_names()
	assert_eq(names.slice(-3), ["Controls", "Settings", "Quit"] as Array[String])


func test_keys_open_controls_from_the_main_menu_and_back_returns() -> void:
	_walk_to("Controls", false)
	_key(KEY_ENTER)
	assert_eq(stack.top(), main.get("controls_screen"))
	assert_true((main.get("controls_screen") as Control).visible)
	assert_false((main.get("main_menu") as Control).visible)
	_key(KEY_ESCAPE)
	assert_eq(stack.top(), main.get("main_menu"))
	await get_tree().process_frame
	var back_on: Button = (main.get("main_menu") as MenuScreen).focused_button()
	assert_eq(back_on.text if back_on != null else "", "Controls", "back on the entry that opened it")


func test_a_controller_opens_settings_from_the_main_menu_and_back_returns() -> void:
	_walk_to("Settings", true)
	_pad(JOY_BUTTON_A)
	assert_eq(stack.top(), main.get("settings_screen"))
	_pad(JOY_BUTTON_B)
	assert_eq(stack.top(), main.get("main_menu"))


func test_the_screens_play_on_the_games_own_settings_and_profiles() -> void:
	var settings_screen: SettingsScreen = main.get("settings_screen")
	var controls_screen: ControlsScreen = main.get("controls_screen")
	assert_eq(settings_screen.settings, GameServices.settings)
	assert_eq(controls_screen.profiles, GameServices.profiles)
	assert_eq(controls_screen.input, GameServices.input)


## godot.mjs runs tests asking for the defaults, so the screens save beside
## the player's files.
func test_a_test_run_never_saves_over_the_players_files() -> void:
	assert_true(OS.has_environment(GameSettings.DEFAULTS_ENV))
	assert_eq((main.get("settings_screen") as SettingsScreen).save_path, "user://test_run_settings.cfg")
	assert_eq((main.get("controls_screen") as ControlsScreen).save_path, "user://test_run_controls.cfg")
	assert_eq(GameSettings.save_path_for_run(GameSettings.PATH, false), GameSettings.PATH, "a player's run saves to the file")
	assert_eq(GameSettings.save_path_for_run(ControlProfiles.PATH, false), ControlProfiles.PATH)


## Nor do they read them: the game's controls start as one fresh "Player 1"
## profile, whatever the player saved to user://controls.cfg.
func test_a_test_run_starts_from_fresh_controls_profiles() -> void:
	assert_true(OS.has_environment(GameSettings.DEFAULTS_ENV))
	assert_eq(GameServices.profiles.names(), PackedStringArray(["Player 1"]))
	assert_eq(GameServices.profiles.active, 0)
	assert_eq(GameServices.profiles.active_profile().kb, Bindings.default_kb())
	assert_eq(GameServices.profiles.active_profile().pad, Bindings.default_pad())


## A finished match's results, as the host hands them over.
func _results_after(cfg: MatchConfig) -> ResultsScreen:
	cfg.arena_id = ArenaScenes.STANDIN
	main.call("start_match", cfg)
	var r: MatchResults = MatchResults.new()
	r.mode = cfg.mode
	r.winner = 1
	r.player_side = 0 if cfg.mode == MatchConfig.DUEL else -1
	r.names = ["Rogue", "Hunter"] as Array[String]
	r.weapons = ["Katana", "Greatsword"] as Array[String]
	main.call("_on_match_finished", r)
	await get_tree().process_frame
	return main.get("results_screen")


func test_change_fighters_opens_the_duel_select_over_the_main_menu() -> void:
	var results: ResultsScreen = await _results_after(MatchConfig.default_duel(5))
	assert_eq(stack.top(), results)
	assert_eq(results.focused_item(), results.rematch_button)
	_key(KEY_RIGHT)
	assert_eq(results.focused_item(), results.change_button, "right walks the row")
	_key(KEY_ENTER)
	var select: FighterSelect = main.get("select")
	assert_eq(stack.top(), select)
	assert_eq(select.draft.mode, MatchConfig.DUEL)
	assert_false(host.is_playing(), "the played match is over")
	assert_true(host.attract, "the duel behind the menus plays again")
	await get_tree().process_frame
	_key(KEY_ESCAPE)
	assert_eq(stack.top(), main.get("main_menu"), "Back from the select lands on the main menu")


func test_change_fighters_after_watch_opens_the_watch_select_with_a_controller() -> void:
	await _results_after(MatchConfig.default_watch(5))
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_A)
	var select: FighterSelect = main.get("select")
	assert_eq(stack.top(), select)
	assert_eq(select.draft.mode, MatchConfig.WATCH)
	assert_eq(select.side_title.text, "Red fighter")


func test_rematch_and_main_menu_still_work_from_the_results() -> void:
	await _results_after(MatchConfig.default_duel(5))
	var seed_before: int = host.config.world_seed
	_key(KEY_ENTER)
	assert_true(host.is_playing())
	assert_ne(host.config.world_seed, seed_before, "a rematch takes a new seed")
	await _results_after(MatchConfig.default_duel(6))
	_key(KEY_LEFT)
	_key(KEY_ENTER)
	assert_eq(stack.top(), main.get("main_menu"), "left from Rematch wraps to Main menu")
