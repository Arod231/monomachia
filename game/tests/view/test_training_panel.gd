extends GutTest
## Training on the menu and its controls (task 23.3), through main.tscn:
## Training on the main menu through the select (the dummy picks fighter
## and weapon only); the on-screen panel (bottom left: "Dummy · <weapon>",
## the nine behaviour chips and refill), driven by keys 1-9 and 0, unless the
## digit is bound in the player's profile, and by clicks; and the pause
## menu's two Training rows for controllers.

const MainScript := preload("res://scenes/main.gd")

var main: Node
var host: MatchHost
var fake: FakeDeviceState


func before_each() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	host = main.get_node("MatchHost")
	host.auto_run = false
	# the host's own devices and profiles, so a test can bind a digit
	fake = FakeDeviceState.new()
	host.input = InputDevices.new(fake)
	host.profiles = ControlProfiles.new()


func _screen() -> int:
	return int(main.get("screen"))


func _panel() -> TrainingPanel:
	return (host.get_node("Hud") as MatchHud).training_panel


func _pause_menu() -> PauseScreen:
	return main.get("pause_menu")


func _training(dummy_weapon: StringName = &"greatsword") -> void:
	var cfg: MatchConfig = MatchConfig.default_training(3)
	cfg.sides[1].weapon_id = dummy_weapon
	cfg.arena_id = ArenaScenes.STANDIN
	main.call("start_match", cfg)
	host.step(Match.INTRO_FRAMES + 5)


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


func _lit() -> Array[StringName]:
	var lit: Array[StringName] = []
	for i: int in _panel().chips.size():
		if _panel().is_lit(i):
			lit.append(_panel().behaviours[i])
	return lit


# ------------------------------------------------------------------ the menu and the select

func test_training_is_on_the_main_menu_after_duel_and_opens_its_select() -> void:
	main.call("show_main_menu")
	var menu: MenuScreen = main.get("main_menu")
	var texts: Array[String] = []
	for b: Button in menu.buttons:
		texts.append(b.text)
	assert_eq(texts.find("Training"), texts.find("Duel") + 1, "after Duel")
	menu.buttons[texts.find("Training")].pressed.emit()
	assert_eq(_screen(), MainScript.Screen.SELECT)
	assert_eq((main.get("select") as FighterSelect).draft.mode, MatchConfig.TRAINING)


func test_the_dummy_side_picks_fighter_and_weapon_only_with_the_explanation() -> void:
	main.call("open_select", MatchConfig.TRAINING)
	var select: FighterSelect = main.get("select")
	select.show_side(1)
	var loadout: LoadoutPanel = select.loadout_panel
	assert_false(select.skill_row.visible, "no difficulty")
	assert_false(loadout.slots[0].visible, "no block abilities")
	assert_true(loadout.cards.visible, "the weapon cards")
	assert_true(loadout.dummy_note.visible)
	assert_string_contains(loadout.dummy_note.text, "number keys")
	select.show_side(0)
	assert_false(loadout.dummy_note.visible, "only on the dummy's side")


func test_training_starts_from_the_select_with_the_dummy_side_s_choices() -> void:
	main.call("open_select", MatchConfig.TRAINING)
	var select: FighterSelect = main.get("select")
	MatchSelection.set_weapon(select.draft, 1, &"daggers")
	MatchSelection.set_fighter(select.draft, 1, &"rogue")
	select.show_side(1)
	select.confirm.pressed.emit()
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_eq(host.config.mode, MatchConfig.TRAINING)
	assert_eq(host.config.sides[1].controller, MatchSide.DUMMY)
	assert_eq(host.fighter(1).weapon.id, &"daggers")
	assert_eq(host.config.sides[1].fighter_id, &"rogue")
	assert_true(_panel().visible)


# ------------------------------------------------------------------ the panel

func test_the_panel_shows_in_training_only() -> void:
	main.call("start_duel")
	assert_false(_panel().visible, "not in a Duel")
	_training()
	assert_true(_panel().visible)
	assert_eq(_panel().heading.text, "Dummy · Greatsword")
	var texts: Array[String] = []
	for c: Button in _panel().chips:
		texts.append(c.text)
	# no Slam while the Greatsword is hidden (milestone-1 task 4)
	assert_eq(texts, ["1 Stand still", "2 Block", "3 Light chains", "4 Heavies", "5 Thrust", "6 Sweep", "7 Mixed attacks", "8 Spar"] as Array[String])
	assert_string_contains(_panel().hint.text, "Keys 1–8")
	assert_eq(_panel().refill_chip.text, "0 Refill health: on")
	assert_eq(_lit(), [&"idle"] as Array[StringName], "Stand still lit")
	main.call("quit_to_menu")
	assert_false(_panel().visible, "gone with the match")


func test_digit_keys_change_the_behaviour_and_refill() -> void:
	_training()
	_press_key(KEY_3)
	assert_eq(host.training_behaviour(), &"lights")
	assert_eq(_lit(), [&"lights"] as Array[StringName])
	_press_key(KEY_5)
	assert_eq(host.training_behaviour(), &"thrust")
	assert_eq(_panel().heading.text, "Dummy · Katana", "the heading follows the swap")
	_press_key(KEY_8)
	assert_eq(host.training_behaviour(), &"fight")
	_press_key(KEY_9)
	assert_eq(host.training_behaviour(), &"fight", "9 has no drill")
	_press_key(KEY_0)
	assert_false(host.refill())
	assert_eq(_panel().refill_chip.text, "0 Refill health: off")
	assert_false(_panel().refill_lit())
	_press_key(KEY_0)
	assert_true(host.refill())


func test_a_digit_bound_in_the_profile_is_ignored() -> void:
	host.profiles.active_profile().kb["jump"].append(InputToken.key(KEY_4))
	_training()
	_press_key(KEY_4)
	assert_eq(host.training_behaviour(), &"idle", "4 jumps instead")
	_press_key(KEY_2)
	assert_eq(host.training_behaviour(), &"block", "the others still work")


func test_clicks_change_the_behaviour_and_refill() -> void:
	_training()
	_panel().chips[6].pressed.emit()
	assert_eq(host.training_behaviour(), &"random")
	assert_eq(_lit(), [&"random"] as Array[StringName])
	_panel().refill_chip.pressed.emit()
	assert_false(host.refill())


func test_the_chips_never_take_the_focus() -> void:
	_training()
	for c: Button in _panel().chips + [_panel().refill_chip]:
		assert_eq(c.focus_mode, Control.FOCUS_NONE, c.text)


func test_keys_do_nothing_while_paused_or_outside_training() -> void:
	_training()
	host.pause()
	assert_false(_panel().visible, "hidden under the pause, which has its own rows")
	_press_key(KEY_3)
	assert_eq(host.training_behaviour(), &"idle", "paused")
	main.call("resume")
	assert_true(_panel().visible, "back on resume")
	main.call("start_duel")
	_press_key(KEY_0)
	assert_true(host.refill(), "a Duel has no refill to turn off")


# ------------------------------------------------------------------ the pause's Training rows

func test_the_pause_shows_dummy_and_refill_rows_in_training_only() -> void:
	main.call("start_duel")
	host.pause()
	assert_false(_pause_menu().dummy_row.visible, "not in a Duel")
	assert_false(_pause_menu().refill_row.visible)
	main.call("resume")
	_training()
	host.set_training_behaviour(&"heavies")
	host.set_refill(false)
	host.pause()
	await get_tree().process_frame
	assert_true(_pause_menu().dummy_row.visible)
	assert_eq(_pause_menu().dummy_row.index, TrainingBrain.BEHAVIOURS.find(&"heavies"), "on the dummy's behaviour")
	assert_eq(_pause_menu().refill_row.index, 1, "refill Off")
	assert_eq(get_viewport().gui_get_focus_owner(), _pause_menu().resume_button, "Resume still first")


func test_a_controller_changes_the_dummy_from_the_pause() -> void:
	_training()
	host.pause()
	await get_tree().process_frame
	_press_pad(JOY_BUTTON_DPAD_UP)
	_press_pad(JOY_BUTTON_DPAD_UP)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), _pause_menu().dummy_row, "up from Resume")
	_press_pad(JOY_BUTTON_DPAD_RIGHT)
	_press_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(host.training_behaviour(), &"lights", "right twice from Stand still")
	_press_pad(JOY_BUTTON_DPAD_DOWN)
	_press_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_false(host.refill(), "refill Off")
	main.call("resume")
	assert_eq(_lit(), [&"lights"] as Array[StringName], "the panel follows")
	assert_eq(_panel().refill_chip.text, "0 Refill health: off")
