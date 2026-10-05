extends GutTest
## Rebinding capture on the Controls screen (22.11): choosing a slot listens
## for a key, a mouse button, a controller button, a trigger or a stick
## direction; the result goes into the active profile and is saved. Esc
## cancels, Backspace or Delete clears, 5 seconds with no input cancels, and
## Back is ignored while listening. Outside a capture, Delete, Backspace or
## Y/△ clears the focused slot. Every event the capture takes still reaches
## the input feed first. The screen saves to a test path and reads a fake
## device state.

const PATH: String = "user://test_controls_capture.cfg"

var state: FakeDeviceState
var input: InputDevices
var profiles: ControlProfiles
var screen: ControlsScreen
var stack: ScreenStack
var opener: MenuScreen
var now: int = 0


func before_each() -> void:
	now = 0
	state = FakeDeviceState.new()
	input = InputDevices.new(state)
	profiles = ControlProfiles.new()
	opener = MenuScreen.new()
	opener.add_button("Controls", "", func() -> void: pass)
	add_child_autofree(opener)
	screen = ControlsScreen.new(profiles, PATH, input)
	screen.clock = func() -> int: return now
	add_child_autofree(screen)
	stack = ScreenStack.new()
	stack.reset([opener] as Array[MenuPage])
	stack.push(screen)
	await get_tree().process_frame


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Events update the fake state first, as Godot's Input does before the scene
## sees them.
func _send(e: InputEvent) -> void:
	state.apply(e)
	get_viewport().push_input(e)


func _key(key: Key, down: bool = true, up: bool = true) -> void:
	for pressed: bool in [true, false]:
		if (pressed and not down) or (not pressed and not up):
			continue
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = pressed
		_send(e)


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = button
		e.pressed = down
		_send(e)


func _axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	_send(e)


func _mouse(button: MouseButton) -> void:
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = Vector2(5.0, 5.0)
		_send(e)


func _slot(action: String, slot: int) -> Button:
	return screen.slot_buttons[action][slot]


## Focuses a slot and chooses it with Enter, as a player would.
func _choose(action: String, slot: int) -> void:
	_slot(action, slot).grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	await get_tree().process_frame


func _saved(tab: String, action: String) -> Array[String]:
	return ControlProfiles.load_from(PATH).active_profile().slots(tab, action)


func _to_pad_tab() -> void:
	state.plug_pad(0, "Xbox Wireless Controller", {"vendor_id": 0x045E})
	screen.tab = ControlProfile.PAD
	screen.refresh()


func test_choosing_a_slot_listens_for_a_key() -> void:
	await _choose("light", 0)
	assert_true(screen.is_listening())
	assert_eq(screen.slot_text("light", 0), ControlsScreen.LISTEN_KEY)
	assert_eq(_slot("light", 0).get_theme_color(&"font_color"), UiPalette.GOLD, "lit while it listens")


func test_binding_a_key_saves_it_in_the_active_profile() -> void:
	await _choose("light", 0)
	_key(KEY_K)
	await get_tree().process_frame
	assert_false(screen.is_listening())
	assert_eq(profiles.active_profile().slots(ControlProfile.KB, "light")[0], InputToken.key(KEY_K))
	assert_eq(_saved(ControlProfile.KB, "light")[0], InputToken.key(KEY_K))
	assert_eq(screen.slot_text("light", 0), "K")
	assert_false(_slot("light", 0).has_theme_color_override(&"font_color"), "unlit once bound")
	assert_eq(screen.focused_item(), _slot("light", 0), "the focus stays on the slot")


func test_binding_a_mouse_button() -> void:
	await _choose("heavy", 1)
	_mouse(MOUSE_BUTTON_MIDDLE)
	await get_tree().process_frame
	assert_eq(_saved(ControlProfile.KB, "heavy")[1], InputToken.mouse(MOUSE_BUTTON_MIDDLE))


func test_a_token_moves_off_its_old_action() -> void:
	var j: String = InputToken.key(KEY_J)
	assert_has(profiles.active_profile().slots(ControlProfile.KB, "light"), j)
	await _choose("heavy", 0)
	_key(KEY_J)
	await get_tree().process_frame
	assert_eq(_saved(ControlProfile.KB, "heavy")[0], j)
	assert_does_not_have(_saved(ControlProfile.KB, "light"), j)
	assert_eq(screen.slot_text("light", 1), ControlsTable.EMPTY)


func test_esc_cancels_and_back_is_ignored_while_listening() -> void:
	var before: Array[String] = profiles.active_profile().slots(ControlProfile.KB, "light")
	await _choose("light", 0)
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert_false(screen.is_listening())
	assert_eq(stack.top(), screen, "Esc cancelled the capture, not the screen")
	assert_eq(profiles.active_profile().slots(ControlProfile.KB, "light"), before)
	assert_false(FileAccess.file_exists(PATH), "nothing saved")
	assert_eq(screen.slot_text("light", 0), "Left Click")
	# Back works again once the capture is over
	_key(KEY_ESCAPE)
	assert_eq(stack.top(), opener)


func test_a_controller_back_on_the_keyboard_tab_is_ignored_while_listening() -> void:
	state.plug_pad(0, "Xbox Wireless Controller", {"vendor_id": 0x045E})
	await _choose("light", 0)
	_pad(JOY_BUTTON_B)
	await get_tree().process_frame
	assert_true(screen.is_listening())
	assert_eq(stack.top(), screen)


func test_backspace_and_delete_clear_while_listening() -> void:
	await _choose("light", 0)
	_key(KEY_BACKSPACE)
	await get_tree().process_frame
	assert_false(screen.is_listening())
	assert_eq(_saved(ControlProfile.KB, "light"), [InputToken.key(KEY_J)] as Array[String], "the slot after moves up")
	await _choose("light", 0)
	_key(KEY_DELETE)
	await get_tree().process_frame
	assert_eq(_saved(ControlProfile.KB, "light"), [] as Array[String])
	assert_eq(stack.top(), screen)


func test_five_seconds_with_no_input_cancels() -> void:
	await _choose("light", 0)
	now = ControlsScreen.CAPTURE_TIMEOUT_MS - 1
	await get_tree().process_frame
	assert_true(screen.is_listening())
	now = ControlsScreen.CAPTURE_TIMEOUT_MS + 1
	await get_tree().process_frame
	assert_false(screen.is_listening())
	assert_eq(screen.slot_text("light", 0), "Left Click")
	assert_false(FileAccess.file_exists(PATH))


func test_every_event_still_reaches_the_input_feed() -> void:
	state.plug_pad(0, "Xbox Wireless Controller", {"vendor_id": 0x045E})
	await _choose("light", 0)
	assert_eq(input.last_used, InputDevices.LastUsed.KEYBOARD)
	_pad(JOY_BUTTON_X)
	assert_eq(input.last_used, InputDevices.LastUsed.PAD, "the feed saw the button the capture ignored")


func test_binding_a_controller_button() -> void:
	_to_pad_tab()
	await _choose("light", 0)
	assert_eq(screen.slot_text("light", 0), ControlsScreen.LISTEN_PAD)
	_pad(JOY_BUTTON_X)
	await get_tree().process_frame
	assert_eq(_saved(ControlProfile.PAD, "light")[0], InputToken.joy_button(JOY_BUTTON_X))
	assert_eq(screen.slot_text("light", 0), "X")


func test_a_controller_capture_waits_for_the_buttons_to_be_let_go() -> void:
	_to_pad_tab()
	_slot("light", 0).grab_focus()
	await get_tree().process_frame
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_A
	down.pressed = true
	_send(down)
	await get_tree().process_frame
	assert_true(screen.is_listening())
	assert_eq(screen.slot_text("light", 0), ControlsScreen.LISTEN_RELEASE)
	var up := InputEventJoypadButton.new()
	up.button_index = JOY_BUTTON_A
	up.pressed = false
	_send(up)
	await get_tree().process_frame
	assert_eq(screen.slot_text("light", 0), ControlsScreen.LISTEN_PAD)
	assert_true(screen.is_listening(), "letting go of A binds nothing")


func test_controller_b_binds_on_the_controller_tab() -> void:
	_to_pad_tab()
	await _choose("dodge", 0)
	_pad(JOY_BUTTON_B)
	await get_tree().process_frame
	assert_eq(_saved(ControlProfile.PAD, "dodge")[0], InputToken.joy_button(JOY_BUTTON_B))
	assert_eq(stack.top(), screen)


func test_binding_a_trigger() -> void:
	_to_pad_tab()
	await _choose("block", 1)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await get_tree().process_frame
	assert_eq(_saved(ControlProfile.PAD, "block")[1], InputToken.joy_axis(JOY_AXIS_TRIGGER_RIGHT, true))


func test_binding_a_stick_direction() -> void:
	_to_pad_tab()
	await _choose("heavy", 1)
	_axis(JOY_AXIS_RIGHT_X, -0.9)
	await get_tree().process_frame
	assert_eq(_saved(ControlProfile.PAD, "heavy")[1], InputToken.joy_axis(JOY_AXIS_RIGHT_X, false))


func test_delete_clears_a_focused_slot_without_a_capture() -> void:
	_slot("light", 0).grab_focus()
	await get_tree().process_frame
	_key(KEY_DELETE)
	assert_false(screen.is_listening())
	assert_eq(_saved(ControlProfile.KB, "light"), [InputToken.key(KEY_J)] as Array[String])
	assert_eq(stack.top(), screen)


func test_backspace_clears_a_focused_slot_but_still_goes_back_elsewhere() -> void:
	_slot("light", 1).grab_focus()
	await get_tree().process_frame
	_key(KEY_BACKSPACE)
	assert_eq(_saved(ControlProfile.KB, "light"), [InputToken.mouse(MOUSE_BUTTON_LEFT)] as Array[String])
	assert_eq(stack.top(), screen)
	screen.tabs.grab_focus()
	await get_tree().process_frame
	_key(KEY_BACKSPACE)
	assert_eq(stack.top(), opener, "Backspace off the slots is Back")


func test_controller_y_clears_a_focused_slot() -> void:
	_to_pad_tab()
	_slot("light", 0).grab_focus()
	await get_tree().process_frame
	var before: Array[String] = profiles.active_profile().slots(ControlProfile.PAD, "light")
	_pad(JOY_BUTTON_Y)
	assert_false(screen.is_listening())
	assert_eq(_saved(ControlProfile.PAD, "light"), before.slice(1))


func test_leaving_the_screen_ends_a_capture() -> void:
	await _choose("light", 0)
	screen.close()
	assert_false(screen.is_listening())
	assert_eq(screen.slot_text("light", 0), "Left Click")
