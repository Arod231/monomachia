extends GutTest
## The Controls screen's binding table (task 22.10): the tabs opening on the
## last device used, the controller status line, the 13 actions with two
## slots named in the detected style, Reset and the fight-stick layout saved
## at once, and walks with keys and with a controller. The screen saves to a
## test path and reads a fake device state.

const PATH: String = "user://test_controls_screen.cfg"

var state: FakeDeviceState
var input: InputDevices
var profiles: ControlProfiles
var screen: ControlsScreen
var stack: ScreenStack


func before_each() -> void:
	state = FakeDeviceState.new()
	input = InputDevices.new(state)
	profiles = ControlProfiles.new()
	screen = ControlsScreen.new(profiles, PATH, input)
	add_child_autofree(screen)
	stack = ScreenStack.new()
	stack.push(screen)
	await get_tree().process_frame


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


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


func _reopen() -> void:
	stack.clear()
	stack.push(screen)


func _used_pad() -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	input.note_event(e)


func test_it_opens_on_the_keyboard_tab_with_the_profiles_keys() -> void:
	assert_eq(screen.tab, ControlProfile.KB)
	assert_eq(screen.tabs.index, 0)
	assert_eq(screen.focused_item(), screen.tabs)
	assert_eq(screen.profile_row.chips[screen.profile_row.index].text, "Player 1")
	assert_eq(screen.status.text, ControlsTable.KB_NOTE)
	assert_eq([screen.slot_text("light", 0), screen.slot_text("light", 1)], ["Left Click", "J"])
	assert_eq([screen.slot_text("dodge", 0), screen.slot_text("dodge", 1)], ["Space", "—"])
	assert_false(screen.fight_stick_button.visible, "the fight stick is the controller tab's")


func test_every_action_has_two_slots_with_their_names_from_the_table() -> void:
	assert_eq(screen.slot_buttons.size(), 13)
	for r: ControlsTable.Row in ControlsTable.rows(profiles.active_profile(), ControlProfile.KB, PadStyle.GENERIC):
		assert_eq([screen.slot_text(r.action, 0), screen.slot_text(r.action, 1)], r.slots, r.action)


func test_it_opens_on_the_controller_tab_after_a_controller_was_used() -> void:
	state.plug_pad(0, "DualSense Wireless Controller", {"vendor_id": 0x054C})
	_used_pad()
	_reopen()
	assert_eq(screen.tab, ControlProfile.PAD)
	assert_eq(screen.tabs.index, 1)
	assert_eq(screen.status.text, "Controller connected: DualSense Wireless Controller (PlayStation button names)\n" + ControlsTable.PAD_NOTE)
	assert_eq(screen.slot_text("jump", 0), "×")
	assert_eq(screen.slot_text("heavy", 0), "R2")
	assert_true(screen.fight_stick_button.visible)


func test_the_controller_tab_names_xbox_buttons_and_follows_plugging() -> void:
	screen.tabs.grab_focus()
	_key(KEY_RIGHT)
	assert_eq(screen.tab, ControlProfile.PAD)
	assert_eq(screen.status.text, "No controller detected. Connect one and press any button on it.\n" + ControlsTable.PAD_NOTE)
	assert_eq(screen.slot_text("light", 0), "Button 10", "no controller: the generic names")
	state.plug_pad(0, "Xbox Wireless Controller")
	assert_string_contains(screen.status.text, "Xbox Wireless Controller (Xbox button names)")
	assert_eq(screen.slot_text("light", 0), "RB")
	assert_eq(screen.slot_text("heavy", 0), "RT")
	state.unplug_pad(0)
	assert_string_contains(screen.status.text, "No controller detected")


func test_the_table_shows_the_active_profile() -> void:
	var p: ControlProfile = profiles.add_profile()
	p.bind(ControlProfile.KB, "light", 0, InputToken.key(KEY_H))
	_reopen()
	assert_eq(screen.profile_row.chips[screen.profile_row.index].text, "Player 2")
	assert_eq(screen.slot_text("light", 0), "H")


func test_reset_restores_the_tabs_defaults_and_saves() -> void:
	var p: ControlProfile = profiles.active_profile()
	p.bind(ControlProfile.KB, "light", 0, InputToken.key(KEY_H))
	p.bind(ControlProfile.PAD, "light", 0, InputToken.joy_button(JOY_BUTTON_X))
	_reopen()
	assert_eq(screen.slot_text("light", 0), "H")
	screen.reset_button.grab_focus()
	_key(KEY_ENTER)
	assert_eq(screen.slot_text("light", 0), "Left Click")
	var saved: ControlProfiles = ControlProfiles.load_from(PATH)
	assert_eq(saved.active_profile().kb["light"], Bindings.default_kb()["light"])
	assert_eq(saved.active_profile().pad["light"], [InputToken.joy_button(JOY_BUTTON_X)], "the other tab is left alone")


func test_the_fight_stick_layout_changes_the_controller_bindings_and_saves() -> void:
	_used_pad()
	_reopen()
	screen.fight_stick_button.grab_focus()
	_pad(JOY_BUTTON_A)
	assert_eq(profiles.active_profile().pad, Bindings.fight_stick_pad())
	assert_eq(ControlProfiles.load_from(PATH).active_profile().pad, Bindings.fight_stick_pad())
	assert_eq(screen.slot_text("light", 0), "Button 2", "generic names with no controller")
	screen.reset_button.grab_focus()
	_pad(JOY_BUTTON_A)
	assert_eq(ControlProfiles.load_from(PATH).active_profile().pad, Bindings.default_pad())


func test_keys_walk_the_table_by_rows_and_slots() -> void:
	_key(KEY_DOWN)
	assert_eq(screen.focused_item(), screen.slot_buttons["up"][0], "from the tabs into the first slot")
	_key(KEY_DOWN)
	assert_eq(screen.focused_item(), screen.slot_buttons["down"][0], "down keeps the column")
	_key(KEY_RIGHT)
	assert_eq(screen.focused_item(), screen.slot_buttons["down"][1], "right goes to the second slot")
	_key(KEY_UP)
	assert_eq(screen.focused_item(), screen.slot_buttons["up"][1])
	_key(KEY_UP)
	assert_eq(screen.focused_item(), screen.tabs, "past the first row, the tabs")
	screen.slot_buttons["pause"][0].grab_focus()
	_key(KEY_DOWN)
	assert_eq(screen.focused_item(), screen.reset_button, "past the last row, Reset")


func test_a_controller_walks_the_table_and_chooses_a_slot() -> void:
	watch_signals(screen)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(screen.focused_item(), screen.slot_buttons["down"][1])
	_pad(JOY_BUTTON_A)
	assert_signal_emitted_with_parameters(screen, "slot_chosen", [ControlProfile.KB, "down", 1])


func test_back_returns_to_the_opener() -> void:
	var opener: MenuScreen = MenuScreen.new()
	add_child_autofree(opener)
	opener.add_button("Controls", "", func() -> void: pass)
	stack.reset([opener] as Array[MenuPage])
	stack.push(screen)
	_key(KEY_ESCAPE)
	assert_eq(stack.top(), opener)
