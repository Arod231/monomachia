extends GutTest
## The pause menu in main.tscn (task 22.15): 休止 Paused with Resume, Move
## list, Controls, Settings, Restart and Quit to menu; the sub-screens open
## over the frozen match and Back returns to the pause; the pause binding,
## Esc and Start open and close it, but never from a sub-screen; a profile
## picked in the pause's Controls takes effect on resume.

const MainScript := preload("res://scenes/main.gd")
const DT: float = SimConst.DT

var main: Node
var host: MatchHost
var fake: FakeDeviceState


func before_each() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	host = main.get_node("MatchHost")
	host.auto_run = false


## Gives the host a fake device state before a match starts, so the pause
## binding, Esc and Start can be pressed through host._process().
func _fake_devices() -> void:
	fake = FakeDeviceState.new()
	host.input = InputDevices.new(fake)


func _screen() -> int:
	return int(main.get("screen"))


func _pause_menu() -> PauseScreen:
	return main.get("pause_menu")


func _stack() -> ScreenStack:
	return main.get("stack")


func _top() -> MenuPage:
	return _stack().top()


func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = pressed
		get_viewport().push_input(e)


func _press_pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = pressed
		get_viewport().push_input(e)


func _paused_duel() -> void:
	main.call("start_duel")
	host.step(30)
	host.pause()
	await get_tree().process_frame


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _entry_texts() -> Array[String]:
	var texts: Array[String] = []
	for b: Button in _pause_menu().buttons:
		texts.append(b.text)
	return texts


# ------------------------------------------------------------------ opening

func test_the_pause_binding_opens_the_pause_menu() -> void:
	_fake_devices()
	host.auto_run = true
	main.call("start_duel")
	fake.press_key(KEY_ESCAPE)
	host._process(DT)
	assert_true(host.is_paused())
	assert_eq(_screen(), MainScript.Screen.PAUSED)
	assert_eq(_top(), _pause_menu())
	assert_true(_pause_menu().visible)


func test_losing_focus_opens_the_pause_menu() -> void:
	main.call("start_duel")
	host.step(10)
	var services: Node = get_tree().root.get_node("GameServices")
	(services.get("feed") as InputFeed).focus_lost.emit()
	assert_true(host.is_paused())
	assert_eq(_top(), _pause_menu())


func test_it_shows_its_kanji_and_six_entries_with_resume_focused() -> void:
	await _paused_duel()
	var kanji: Label = _pause_menu().find_child("Kanji", true, false)
	assert_not_null(kanji)
	assert_eq(kanji.text, "休止")
	assert_eq(_entry_texts(), ["Resume", "Move list", "Controls", "Settings", "Restart", "Quit to menu"] as Array[String])
	assert_eq(_focused(), _pause_menu().resume_button)


# ------------------------------------------------------------------ entries

func test_resume_and_back_close_it() -> void:
	await _paused_duel()
	_pause_menu().resume_button.pressed.emit()
	assert_false(host.is_paused(), "Resume")
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_false(_pause_menu().visible)
	host.pause()
	await get_tree().process_frame
	_press_key(KEY_ESCAPE)
	assert_false(host.is_paused(), "Back")


func test_move_list_opens_on_the_weapon_held_and_back_returns_to_the_pause() -> void:
	await _paused_duel()
	var how: HowToPlayScreen = main.get("how_to_play")
	_pause_menu().move_list_button.grab_focus()
	_pause_menu().move_list_button.pressed.emit()
	assert_eq(_top(), how)
	assert_eq(how.tab, how.tab_weapons.find(&"katana"), "your katana's moves")
	assert_true(host.is_paused())
	await get_tree().process_frame
	_press_key(KEY_ESCAPE)
	assert_eq(_top(), _pause_menu(), "Back returns to the pause")
	assert_true(host.is_paused(), "and doesn't resume")
	await get_tree().process_frame
	assert_eq(_focused(), _pause_menu().move_list_button, "on the entry that opened it")


func test_move_list_when_disarmed_opens_bare_hands() -> void:
	await _paused_duel()
	host.fighter(0).armed = false
	_pause_menu().move_list_button.pressed.emit()
	var how: HowToPlayScreen = main.get("how_to_play")
	assert_eq(how.tab, how.tab_weapons.find(&"fists"))


func test_move_list_in_watch_opens_the_rules() -> void:
	main.call("start_watch")
	host.step(10)
	host.pause()
	_pause_menu().move_list_button.pressed.emit()
	assert_eq((main.get("how_to_play") as HowToPlayScreen).tab, 0)


func test_controls_and_settings_open_over_the_pause_and_back_returns() -> void:
	await _paused_duel()
	for entry: String in ["controls", "settings"]:
		var page: MenuPage = main.get("%s_screen" % entry)
		var button: Button = _pause_menu().get("%s_button" % entry)
		button.pressed.emit()
		assert_eq(_top(), page, entry)
		assert_eq(_screen(), MainScript.Screen.PAUSED, "%s keeps the match paused" % entry)
		page.back_requested.emit()
		assert_eq(_top(), _pause_menu(), "Back from %s" % entry)
		assert_true(host.is_paused())


func test_restart_replays_the_match_with_the_next_seed() -> void:
	await _paused_duel()
	var before: MatchConfig = host.config
	_pause_menu().restart_button.pressed.emit()
	assert_false(host.is_paused())
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_eq(_top(), null, "no menu over the new match")
	assert_eq(host.step_count, 0, "a fresh match")
	assert_eq(host.config.mode, before.mode)
	assert_eq(host.config.sides[0].weapon_id, before.sides[0].weapon_id)
	assert_eq(host.config.sides[1].weapon_id, before.sides[1].weapon_id)
	assert_ne(host.config.world_seed, before.world_seed, "the next seed")


func test_restart_in_training_keeps_the_refill_setting_and_the_behaviour() -> void:
	var cfg: MatchConfig = MatchConfig.default_training(3)
	cfg.arena_id = ArenaScenes.STANDIN
	main.call("start_match", cfg)
	host.set_refill(false)
	host.set_training_behaviour(&"thrust")
	host.pause()
	_pause_menu().restart_button.pressed.emit()
	assert_eq(host.config.mode, MatchConfig.TRAINING)
	assert_false(host.refill(), "still off after Restart")
	assert_eq(host.training_behaviour(), &"thrust", "the dummy still thrusts")
	assert_eq(host.fighter(1).weapon.id, &"katana", "with the Katana it swapped to")


func test_a_new_training_from_the_menu_starts_afresh() -> void:
	var cfg: MatchConfig = MatchConfig.default_training(3)
	cfg.arena_id = ArenaScenes.STANDIN
	main.call("start_match", cfg)
	host.set_refill(false)
	host.set_training_behaviour(&"block")
	main.call("quit_to_menu")
	main.call("start_match", cfg.with_seed(4))
	assert_true(host.refill(), "refill on")
	assert_eq(host.training_behaviour(), &"idle", "Stand still")


func test_quit_to_menu_returns_to_the_main_menu_over_the_duel() -> void:
	await _paused_duel()
	_pause_menu().quit_button.pressed.emit()
	assert_eq(_screen(), MainScript.Screen.MENU)
	assert_true(host.attract, "the duel behind the menus plays again")
	assert_false(host.is_paused())


func test_the_rules_never_step_while_any_pause_screen_is_open() -> void:
	await _paused_duel()
	var frame: int = host.world.frame
	assert_eq(host.step(5), 0, "the pause")
	for entry: String in ["move_list", "controls", "settings"]:
		(_pause_menu().get("%s_button" % entry) as Button).pressed.emit()
		assert_eq(host.step(5), 0, entry)
		assert_eq(host.advance(1.0), 0, "%s, with the clock" % entry)
		_top().back_requested.emit()
	assert_eq(host.world.frame, frame)


# ------------------------------------------------------------------ the pause press in sub-screens

func test_esc_in_a_sub_screen_goes_back_without_resuming() -> void:
	_fake_devices()
	host.auto_run = true
	main.call("start_duel")
	host.pause()
	_pause_menu().settings_button.pressed.emit()
	assert_false(host.pause_press_resumes, "a sub-screen holds the pause press")
	# Esc is Back on the page, and the host sees it down the same frame
	fake.press_key(KEY_ESCAPE)
	_press_key(KEY_ESCAPE)
	host._process(DT)
	assert_eq(_top(), _pause_menu(), "Back to the pause")
	assert_true(host.is_paused(), "not resumed")
	assert_true(host.pause_press_resumes)
	fake.release_key(KEY_ESCAPE)
	host._process(DT)
	fake.press_key(KEY_ESCAPE)
	host._process(DT)
	assert_false(host.is_paused(), "Esc on the pause itself resumes")


func test_start_in_a_sub_screen_does_not_resume() -> void:
	_fake_devices()
	fake.plug_pad(0)
	host.auto_run = true
	main.call("start_duel")
	host.pause()
	_pause_menu().controls_button.pressed.emit()
	fake.press_button(0, JOY_BUTTON_START)
	host._process(DT)
	assert_true(host.is_paused())
	assert_eq(_top(), main.get("controls_screen"))


# ------------------------------------------------------------------ profiles

func test_a_profile_picked_in_the_pause_takes_effect_on_resume() -> void:
	var profiles: ControlProfiles = get_tree().root.get_node("GameServices").get("profiles")
	var first: int = profiles.active
	var added: ControlProfile = profiles.add_profile()
	var added_at: int = profiles.profiles.find(added)
	profiles.set_active(first)
	await _paused_duel()
	assert_ne(host.input.profile_of(0), added)
	_pause_menu().controls_button.pressed.emit()
	var controls: ControlsScreen = main.get("controls_screen")
	controls.profile_row.set_index(added_at)
	controls.profile_row.changed.emit(added_at)
	assert_eq(profiles.active_profile(), added, "picked in the pause's Controls")
	controls.back_requested.emit()
	main.call("resume")
	assert_eq(host.input.profile_of(0), added, "in use after resume")
	profiles.delete_profile(added_at)
	profiles.set_active(first)


# ------------------------------------------------------------------ walks

func test_a_keyboard_alone_walks_the_pause_and_its_sub_screens() -> void:
	await _paused_duel()
	var pages: Array[MenuPage] = [main.get("how_to_play"), main.get("controls_screen"), main.get("settings_screen")]
	for i: int in pages.size():
		_press_key(KEY_DOWN)
		await get_tree().process_frame
		_press_key(KEY_ENTER)
		assert_eq(_top(), pages[i], "Enter opens %s" % pages[i].name)
		await get_tree().process_frame
		_press_key(KEY_ESCAPE)
		assert_eq(_top(), _pause_menu(), "Esc returns from %s" % pages[i].name)
		await get_tree().process_frame
	_press_key(KEY_UP)
	_press_key(KEY_UP)
	_press_key(KEY_UP)
	await get_tree().process_frame
	assert_eq(_focused(), _pause_menu().resume_button)
	_press_key(KEY_ENTER)
	assert_false(host.is_paused(), "Enter on Resume")


func test_a_controller_alone_walks_the_pause_and_its_sub_screens() -> void:
	await _paused_duel()
	var pages: Array[MenuPage] = [main.get("how_to_play"), main.get("controls_screen"), main.get("settings_screen")]
	for i: int in pages.size():
		_press_pad(JOY_BUTTON_DPAD_DOWN)
		await get_tree().process_frame
		_press_pad(JOY_BUTTON_A)
		assert_eq(_top(), pages[i], "A opens %s" % pages[i].name)
		await get_tree().process_frame
		_press_pad(JOY_BUTTON_B)
		assert_eq(_top(), _pause_menu(), "B returns from %s" % pages[i].name)
		await get_tree().process_frame
	_press_pad(JOY_BUTTON_DPAD_DOWN)
	_press_pad(JOY_BUTTON_DPAD_DOWN)
	await get_tree().process_frame
	assert_eq(_focused(), _pause_menu().quit_button)
	_press_pad(JOY_BUTTON_A)
	assert_eq(_screen(), MainScript.Screen.MENU, "A on Quit to menu")
