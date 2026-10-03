extends GutTest
## Rebinding capture on the Controls screen: keys, mouse buttons, controller
## buttons and axes, cancelling, clearing, and one action per input.

var fake: FakeDeviceState
var profile: ControlProfile


func before_each() -> void:
	fake = FakeDeviceState.new()
	profile = ControlProfile.create()


## Updates the fake device state the way Godot's Input does, then hands the
## event to the capture.
func _send(capture: RebindCapture, event: InputEvent) -> RebindCapture.Result:
	fake.apply(event)
	return capture.feed(event)


func _key(code: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = code as Key
	e.pressed = pressed
	e.echo = echo
	return e


func _mouse(button: int, pressed: bool = true) -> InputEventMouseButton:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = button as MouseButton
	e.pressed = pressed
	return e


func _button(device: int, button: int, pressed: bool = true) -> InputEventJoypadButton:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.device = device
	e.button_index = button as JoyButton
	e.pressed = pressed
	return e


func _motion(device: int, axis: int, value: float) -> InputEventJoypadMotion:
	var e: InputEventJoypadMotion = InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis as JoyAxis
	e.axis_value = value
	return e


func test_keyboard_tab_binds_the_next_key_press() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	assert_true(c.is_listening())
	assert_eq(_send(c, _key(KEY_ENTER, false)), RebindCapture.Result.LISTENING, "a release is not a press")
	assert_eq(_send(c, _key(KEY_ENTER, true, true)), RebindCapture.Result.LISTENING, "nor is a key repeat")
	assert_eq(_send(c, _key(KEY_G)), RebindCapture.Result.BOUND)
	assert_eq(c.token, InputToken.key(KEY_G))
	assert_false(c.is_listening())
	assert_eq(_send(c, _key(KEY_H)), RebindCapture.Result.BOUND, "finished captures ignore later events")
	assert_eq(c.token, InputToken.key(KEY_G))


func test_keyboard_tab_uses_the_physical_key() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	var e: InputEventKey = _key(KEY_W)
	e.keycode = KEY_Z # an AZERTY keyboard prints Z on the key where QWERTY has W
	_send(c, e)
	assert_eq(c.token, InputToken.key(KEY_W))


func test_keyboard_tab_binds_a_mouse_button_but_not_the_wheel() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	assert_eq(_send(c, _mouse(MOUSE_BUTTON_WHEEL_UP)), RebindCapture.Result.LISTENING)
	assert_eq(_send(c, _mouse(MOUSE_BUTTON_RIGHT, false)), RebindCapture.Result.LISTENING)
	assert_eq(_send(c, _mouse(MOUSE_BUTTON_XBUTTON1)), RebindCapture.Result.BOUND)
	assert_eq(c.token, InputToken.mouse(MOUSE_BUTTON_XBUTTON1))


func test_keyboard_tab_ignores_controllers() -> void:
	fake.plug_pad(0)
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	assert_eq(_send(c, _button(0, JOY_BUTTON_A)), RebindCapture.Result.LISTENING)
	assert_eq(_send(c, _motion(0, JOY_AXIS_LEFT_X, 1.0)), RebindCapture.Result.LISTENING)


func test_escape_cancels_and_leaves_the_profile_alone() -> void:
	var before: Dictionary = profile.to_dict()
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	assert_eq(_send(c, _key(KEY_ESCAPE)), RebindCapture.Result.CANCELLED)
	assert_false(c.apply_to(profile, "light", 0))
	assert_eq(profile.to_dict(), before)


func test_cancel_from_code() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	c.cancel()
	assert_eq(c.result, RebindCapture.Result.CANCELLED)


func test_backspace_and_delete_clear_the_slot() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	assert_eq(_send(c, _key(KEY_BACKSPACE)), RebindCapture.Result.CLEARED)
	assert_true(c.apply_to(profile, "light", 0))
	assert_eq(profile.slots(ControlProfile.KB, "light"), [InputToken.key(KEY_J)] as Array[String], "slot 2 moves up")
	c = RebindCapture.new(ControlProfile.KB, fake)
	assert_eq(_send(c, _key(KEY_DELETE)), RebindCapture.Result.CLEARED)
	c.apply_to(profile, "light", 0)
	assert_eq(profile.slots(ControlProfile.KB, "light"), [] as Array[String])
	c = RebindCapture.new(ControlProfile.KB, fake)
	_send(c, _key(KEY_DELETE))
	assert_true(c.apply_to(profile, "light", 1), "clearing an empty slot is harmless")
	assert_eq(profile.slots(ControlProfile.KB, "light"), [] as Array[String])


func test_controller_tab_waits_until_every_button_is_released() -> void:
	fake.plug_pad(0)
	fake.press_button(0, JOY_BUTTON_A) # the button that opened the capture
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	assert_false(c.is_armed())
	assert_eq(_send(c, _button(0, JOY_BUTTON_X)), RebindCapture.Result.LISTENING, "A is still held")
	assert_eq(_send(c, _button(0, JOY_BUTTON_X, false)), RebindCapture.Result.LISTENING)
	assert_false(c.is_armed())
	assert_eq(_send(c, _button(0, JOY_BUTTON_A, false)), RebindCapture.Result.LISTENING)
	assert_true(c.is_armed())
	assert_eq(_send(c, _button(0, JOY_BUTTON_B)), RebindCapture.Result.BOUND)
	assert_eq(c.token, InputToken.joy_button(JOY_BUTTON_B))


func test_controller_tab_arms_on_poll_without_events() -> void:
	fake.plug_pad(0)
	fake.press_button(0, JOY_BUTTON_A)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	c.poll()
	assert_false(c.is_armed())
	fake.release_button(0, JOY_BUTTON_A)
	c.poll()
	assert_true(c.is_armed())


func test_controller_tab_arms_at_once_when_nothing_is_held() -> void:
	fake.plug_pad(0)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	assert_true(c.is_armed())
	assert_eq(_send(c, _button(0, JOY_BUTTON_RIGHT_SHOULDER)), RebindCapture.Result.BOUND)
	assert_eq(c.token, InputToken.joy_button(JOY_BUTTON_RIGHT_SHOULDER))


func test_controller_tab_binds_an_axis_moving_from_its_rest_position() -> void:
	fake.plug_pad(0)
	fake.set_axis(0, JOY_AXIS_LEFT_X, 0.1) # a drifting stick
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	assert_true(c.is_armed())
	assert_eq(_send(c, _motion(0, JOY_AXIS_LEFT_X, 0.65)), RebindCapture.Result.LISTENING, "0.55 from rest")
	assert_eq(_send(c, _motion(0, JOY_AXIS_LEFT_X, 0.75)), RebindCapture.Result.BOUND, "0.65 from rest")
	assert_eq(c.token, "a:0+")


func test_controller_tab_binds_stick_up_and_triggers() -> void:
	fake.plug_pad(0)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	_send(c, _motion(0, JOY_AXIS_LEFT_Y, -0.8))
	assert_eq(c.token, "a:1-")
	fake.release_all()
	c = RebindCapture.new(ControlProfile.PAD, fake)
	_send(c, _motion(0, JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(c.token, InputToken.joy_axis(JOY_AXIS_TRIGGER_RIGHT, true))


func test_a_trigger_held_when_the_capture_starts_must_be_released_first() -> void:
	fake.plug_pad(0)
	fake.set_axis(0, JOY_AXIS_TRIGGER_LEFT, 1.0)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	assert_false(c.is_armed())
	assert_eq(_send(c, _motion(0, JOY_AXIS_TRIGGER_LEFT, 0.0)), RebindCapture.Result.LISTENING, "releasing is not binding")
	assert_true(c.is_armed())
	assert_eq(_send(c, _motion(0, JOY_AXIS_TRIGGER_LEFT, 1.0)), RebindCapture.Result.BOUND)
	assert_eq(c.token, "a:4+")


func test_controller_tab_reads_any_controller() -> void:
	fake.plug_pad(0)
	fake.plug_pad(1)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	_send(c, _button(1, JOY_BUTTON_Y))
	assert_eq(c.token, InputToken.joy_button(JOY_BUTTON_Y))


func test_controller_tab_ignores_keys_and_mouse_but_escape_cancels() -> void:
	fake.plug_pad(0)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	assert_eq(_send(c, _key(KEY_W)), RebindCapture.Result.LISTENING)
	assert_eq(_send(c, _mouse(MOUSE_BUTTON_LEFT)), RebindCapture.Result.LISTENING)
	assert_eq(_send(c, _key(KEY_ESCAPE)), RebindCapture.Result.CANCELLED)


func test_controller_tab_clears_with_backspace() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	_send(c, _key(KEY_BACKSPACE))
	assert_true(c.apply_to(profile, "heavy", 0))
	assert_eq(profile.slots(ControlProfile.PAD, "heavy"), [] as Array[String])
	assert_eq(profile.slots(ControlProfile.KB, "heavy").size(), 2, "the keyboard tab is untouched")


func test_binding_a_key_used_elsewhere_moves_it() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	_send(c, _key(KEY_W))
	assert_true(c.apply_to(profile, "down", 0))
	assert_eq(profile.slots(ControlProfile.KB, "down"), [InputToken.key(KEY_W), InputToken.key(KEY_DOWN)] as Array[String])
	assert_eq(profile.slots(ControlProfile.KB, "up"), [InputToken.key(KEY_UP)] as Array[String])
	for action: String in Bindings.ACTIONS:
		if action != "down":
			assert_false(profile.slots(ControlProfile.KB, action).has(InputToken.key(KEY_W)), action)


func test_binding_a_mouse_button_used_elsewhere_moves_it() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	_send(c, _mouse(MOUSE_BUTTON_LEFT))
	c.apply_to(profile, "block", 1)
	assert_eq(profile.slots(ControlProfile.KB, "block"), [InputToken.key(KEY_SHIFT, KEY_LOCATION_LEFT), InputToken.mouse(MOUSE_BUTTON_LEFT)] as Array[String])
	assert_eq(profile.slots(ControlProfile.KB, "light"), [InputToken.key(KEY_J)] as Array[String])


func test_binding_a_controller_input_used_elsewhere_moves_it() -> void:
	fake.plug_pad(0)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	_send(c, _button(0, JOY_BUTTON_RIGHT_SHOULDER))
	c.apply_to(profile, "heavy", 0)
	assert_eq(profile.slots(ControlProfile.PAD, "heavy"), [InputToken.joy_button(JOY_BUTTON_RIGHT_SHOULDER)] as Array[String])
	assert_eq(profile.slots(ControlProfile.PAD, "light"), [] as Array[String])
	fake.release_all()
	c = RebindCapture.new(ControlProfile.PAD, fake)
	_send(c, _motion(0, JOY_AXIS_LEFT_Y, -1.0))
	c.apply_to(profile, "jump", 1)
	assert_eq(profile.slots(ControlProfile.PAD, "jump"), [InputToken.joy_button(JOY_BUTTON_A), "a:1-"] as Array[String])
	assert_eq(profile.slots(ControlProfile.PAD, "up"), [InputToken.joy_button(JOY_BUTTON_DPAD_UP)] as Array[String])


func test_binding_an_empty_second_slot_appends() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	_send(c, _key(KEY_C))
	c.apply_to(profile, "dodge", 1)
	assert_eq(profile.slots(ControlProfile.KB, "dodge"), [InputToken.key(KEY_SPACE), InputToken.key(KEY_C)] as Array[String])
	c = RebindCapture.new(ControlProfile.KB, fake)
	_send(c, _key(KEY_V))
	c.apply_to(profile, "sprint", 1)
	assert_eq(profile.slots(ControlProfile.KB, "sprint"), [InputToken.key(KEY_V)] as Array[String], "no gaps")


func test_moving_a_binding_to_the_other_slot_of_the_same_action() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	_send(c, _mouse(MOUSE_BUTTON_LEFT))
	c.apply_to(profile, "light", 1)
	assert_eq(profile.slots(ControlProfile.KB, "light"), [InputToken.key(KEY_J), InputToken.mouse(MOUSE_BUTTON_LEFT)] as Array[String])


## The demo armed only once every trigger was below the press point (30/255)
## and bound a trigger on a fresh press, so a trigger eased off to just under
## half could not leave the capture unable to bind it.
func test_a_trigger_must_return_past_the_press_point_before_arming() -> void:
	fake.plug_pad(0)
	fake.set_axis(0, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	assert_eq(_send(c, _motion(0, JOY_AXIS_TRIGGER_RIGHT, 0.45)), RebindCapture.Result.LISTENING)
	assert_false(c.is_armed(), "0.45 is still a held trigger")
	assert_eq(_send(c, _motion(0, JOY_AXIS_TRIGGER_RIGHT, 0.05)), RebindCapture.Result.LISTENING)
	assert_true(c.is_armed())
	assert_eq(_send(c, _motion(0, JOY_AXIS_TRIGGER_RIGHT, 0.2)), RebindCapture.Result.BOUND, "a light pull is a press")
	assert_eq(c.token, InputToken.joy_axis(JOY_AXIS_TRIGGER_RIGHT, true))


func test_letting_go_of_a_stick_held_when_the_capture_arms_binds_nothing() -> void:
	fake.plug_pad(0)
	fake.set_axis(0, JOY_AXIS_LEFT_X, -1.0) # held left while the slot was chosen
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	assert_true(c.is_armed())
	assert_eq(_send(c, _motion(0, JOY_AXIS_LEFT_X, 0.0)), RebindCapture.Result.LISTENING, "back to the centre is not a push right")
	assert_eq(_send(c, _motion(0, JOY_AXIS_LEFT_X, 0.1)), RebindCapture.Result.LISTENING, "nor is drift")
	assert_eq(_send(c, _motion(0, JOY_AXIS_LEFT_X, 0.9)), RebindCapture.Result.BOUND)
	assert_eq(c.token, "a:0+")


## Raw (unmapped) controllers can report axes past the SDL layout's 6 and
## buttons past its 26; the demo recorded every axis and checked every button.
func test_raw_controller_axes_and_buttons_past_the_sdl_layout() -> void:
	fake.plug_pad(0, "Raw joystick")
	fake.set_axis(0, 7, -1.0) # rests at -1
	fake.press_button(0, 30)
	var c: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
	assert_false(c.is_armed(), "button 30 is still held")
	assert_eq(_send(c, _button(0, 30, false)), RebindCapture.Result.LISTENING)
	assert_true(c.is_armed())
	assert_eq(_send(c, _motion(0, 7, -0.98)), RebindCapture.Result.LISTENING, "noise at rest")
	assert_eq(_send(c, _motion(0, 7, 1.0)), RebindCapture.Result.BOUND)
	assert_eq(c.token, "a:7+")


## Godot's Input tracks keys by physical keycode only, so a key event without
## one (a synthetic event) could be bound but would never read as held.
func test_a_key_event_without_a_physical_key_is_ignored() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	var e: InputEventKey = InputEventKey.new()
	e.keycode = KEY_X
	e.pressed = true
	assert_eq(_send(c, e), RebindCapture.Result.LISTENING)
	assert_false(fake.is_key_pressed(KEY_X), "the fake tracks physical keys only, as Godot's Input does")
	assert_eq(_send(c, _key(KEY_X)), RebindCapture.Result.BOUND)
	assert_eq(c.token, InputToken.key(KEY_X))


func test_keyboard_tab_records_which_shift_ctrl_or_alt() -> void:
	var c: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
	var e: InputEventKey = _key(KEY_SHIFT)
	e.location = KEY_LOCATION_RIGHT
	_send(c, e)
	assert_eq(c.token, InputToken.key(KEY_SHIFT, KEY_LOCATION_RIGHT))
	assert_true(fake.is_key_pressed(KEY_SHIFT, KEY_LOCATION_RIGHT))
	assert_false(fake.is_key_pressed(KEY_SHIFT, KEY_LOCATION_LEFT))
	c = RebindCapture.new(ControlProfile.KB, fake)
	e = _key(KEY_CTRL)
	e.location = KEY_LOCATION_LEFT
	_send(c, e)
	assert_eq(c.token, InputToken.key(KEY_CTRL, KEY_LOCATION_LEFT))
	c.apply_to(profile, "dodge", 1)
	assert_eq(profile.slots(ControlProfile.KB, "dodge"), [InputToken.key(KEY_SPACE), InputToken.key(KEY_CTRL, KEY_LOCATION_LEFT)] as Array[String])
