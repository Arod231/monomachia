extends GutTest
## What each device turns into as a RawInput: the default keyboard, mouse,
## controller and fight-stick mappings, the stick curve and clamping, the arrow
## layout and the shared-keyboard exclusion.

const EPS: float = 1e-9
const DIAG: float = 0.7071067811865476

var fake: FakeDeviceState
var input: InputDevices
var profile: ControlProfile


func before_each() -> void:
	fake = FakeDeviceState.new()
	input = InputDevices.new(fake)
	profile = ControlProfile.create()


func _assert_move(raw: RawInput, mx: float, my: float, note: String = "") -> void:
	assert_almost_eq(raw.mx, mx, EPS, "mx " + note)
	assert_almost_eq(raw.my, my, EPS, "my " + note)


func test_keyboard_defaults_hold_each_rule_button() -> void:
	var cases: Array = [
		[KEY_J, Btn.LIGHT], [KEY_K, Btn.HEAVY], [KEY_L, Btn.BLOCK],
		[KEY_SPACE, Btn.DODGE], [KEY_F, Btn.JUMP], [KEY_I, Btn.JUMP], [KEY_E, Btn.INTERACT],
		[KEY_Q, Btn.ULTIMATE], [KEY_U, Btn.ULTIMATE],
	]
	for c: Array in cases:
		fake.release_all()
		fake.press_key(c[0])
		var raw: RawInput = input.sample_device(profile, InputDevices.KBM)
		assert_eq(raw.buttons, Btn.bit(c[1]), OS.get_keycode_string(c[0]))
		_assert_move(raw, 0.0, 0.0)


## The demo bound the left Shift only (ShiftLeft).
func test_left_shift_blocks_and_right_shift_does_not() -> void:
	assert_eq(profile.kb["block"][0], InputToken.key(KEY_SHIFT, KEY_LOCATION_LEFT))
	fake.press_key(KEY_SHIFT, KEY_LOCATION_LEFT)
	assert_eq(input.sample_device(profile, InputDevices.KBM).buttons, Btn.bit(Btn.BLOCK))
	fake.press_key(KEY_SHIFT, KEY_LOCATION_RIGHT)
	fake.release_key(KEY_SHIFT, KEY_LOCATION_LEFT)
	assert_eq(input.sample_device(profile, InputDevices.KBM).buttons, 0, "right Shift is not block")


## Right Shift sits next to the up arrow on many laptops.
func test_player_2_on_the_arrows_pressing_right_shift_does_not_make_player_1_block() -> void:
	var devices: Array[String] = [InputDevices.KBM, InputDevices.KB_ARROWS]
	var profiles: Array[ControlProfile] = [profile, ControlProfile.create("Player 2")]
	input.set_versus(devices, profiles)
	fake.press_key(KEY_SHIFT, KEY_LOCATION_RIGHT)
	assert_eq(input.sample(0).buttons, 0)
	fake.press_key(KEY_SHIFT, KEY_LOCATION_LEFT)
	fake.release_key(KEY_SHIFT, KEY_LOCATION_RIGHT)
	assert_eq(input.sample(0).buttons, Btn.bit(Btn.BLOCK), "releasing right Shift leaves player 1's left Shift held")


func test_mouse_left_is_light_and_right_is_heavy() -> void:
	fake.press_mouse(MOUSE_BUTTON_LEFT)
	assert_eq(input.sample_device(profile, InputDevices.KBM).buttons, Btn.bit(Btn.LIGHT))
	fake.release_all()
	fake.press_mouse(MOUSE_BUTTON_RIGHT)
	assert_eq(input.sample_device(profile, InputDevices.KBM).buttons, Btn.bit(Btn.HEAVY))
	fake.press_mouse(MOUSE_BUTTON_LEFT)
	assert_eq(input.sample_device(profile, InputDevices.KBM).buttons, Btn.bit(Btn.LIGHT) | Btn.bit(Btn.HEAVY))


func test_wasd_and_the_arrow_keys_move() -> void:
	var cases: Array = [
		[KEY_W, 0.0, 1.0], [KEY_S, 0.0, -1.0], [KEY_A, -1.0, 0.0], [KEY_D, 1.0, 0.0],
		[KEY_UP, 0.0, 1.0], [KEY_DOWN, 0.0, -1.0], [KEY_LEFT, -1.0, 0.0], [KEY_RIGHT, 1.0, 0.0],
	]
	for c: Array in cases:
		fake.release_all()
		fake.press_key(c[0])
		var raw: RawInput = input.sample_device(profile, InputDevices.KBM)
		_assert_move(raw, c[1], c[2], OS.get_keycode_string(c[0]))
		assert_eq(raw.buttons, 0)


func test_diagonal_keys_are_clamped_to_length_1() -> void:
	fake.press_key(KEY_W)
	fake.press_key(KEY_D)
	_assert_move(input.sample_device(profile, InputDevices.KBM), DIAG, DIAG)


func test_keyboard_has_no_sprint_key_and_pause_is_not_a_rule_button() -> void:
	assert_eq(profile.kb["sprint"], [])
	fake.press_key(KEY_ESCAPE)
	fake.press_key(KEY_P)
	assert_eq(input.sample_device(profile, InputDevices.KBM).buttons, 0)


func test_controller_defaults_hold_each_rule_button() -> void:
	fake.plug_pad(0)
	var cases: Array = [
		[JOY_BUTTON_RIGHT_SHOULDER, Btn.LIGHT], [JOY_BUTTON_LEFT_SHOULDER, Btn.BLOCK],
		[JOY_BUTTON_B, Btn.DODGE], [JOY_BUTTON_A, Btn.JUMP], [JOY_BUTTON_X, Btn.INTERACT],
		[JOY_BUTTON_Y, Btn.ULTIMATE], [JOY_BUTTON_LEFT_STICK, Btn.SPRINT],
	]
	for c: Array in cases:
		fake.release_all()
		fake.press_button(0, c[0])
		var raw: RawInput = input.sample_device(profile, InputDevices.PAD0)
		assert_eq(raw.buttons, Btn.bit(c[1]), "button %d" % c[0])
	fake.release_all()
	fake.press_button(0, JOY_BUTTON_START)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, 0, "pause is not a rule button")


## The demo read triggers as buttons, and browsers report a trigger as pressed
## past XInput's threshold of 30/255 (about 0.12).
func test_right_trigger_is_heavy_past_the_browser_press_point() -> void:
	fake.plug_pad(0)
	fake.set_axis(0, JOY_AXIS_TRIGGER_RIGHT, 0.1)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, 0)
	fake.set_axis(0, JOY_AXIS_TRIGGER_RIGHT, 30.0 / 255.0)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, 0, "the threshold itself does not count")
	fake.set_axis(0, JOY_AXIS_TRIGGER_RIGHT, 0.12)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, Btn.bit(Btn.HEAVY), "a light pull starts the heavy")
	fake.set_axis(0, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, Btn.bit(Btn.HEAVY))
	fake.set_axis(0, JOY_AXIS_TRIGGER_RIGHT, 0.3)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, Btn.bit(Btn.HEAVY), "easing off keeps the charge")
	fake.set_axis(0, JOY_AXIS_TRIGGER_RIGHT, 0.1)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, 0, "letting go releases it")


func test_dpad_moves() -> void:
	fake.plug_pad(0)
	var cases: Array = [
		[JOY_BUTTON_DPAD_UP, 0.0, 1.0], [JOY_BUTTON_DPAD_DOWN, 0.0, -1.0],
		[JOY_BUTTON_DPAD_LEFT, -1.0, 0.0], [JOY_BUTTON_DPAD_RIGHT, 1.0, 0.0],
	]
	for c: Array in cases:
		fake.release_all()
		fake.press_button(0, c[0])
		_assert_move(input.sample_device(profile, InputDevices.PAD0), c[1], c[2], "button %d" % c[0])


func test_fight_stick_layout() -> void:
	profile.use_fight_stick_layout()
	fake.plug_pad(0)
	var cases: Array = [
		[JOY_BUTTON_X, Btn.LIGHT], [JOY_BUTTON_Y, Btn.HEAVY], [JOY_BUTTON_RIGHT_SHOULDER, Btn.BLOCK],
		[JOY_BUTTON_B, Btn.DODGE], [JOY_BUTTON_A, Btn.JUMP], [JOY_BUTTON_LEFT_SHOULDER, Btn.ULTIMATE],
	]
	for c: Array in cases:
		fake.release_all()
		fake.press_button(0, c[0])
		assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, Btn.bit(c[1]), "button %d" % c[0])
	fake.release_all()
	fake.set_axis(0, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, Btn.bit(Btn.INTERACT), "R2 picks up")
	fake.release_all()
	fake.set_axis(0, JOY_AXIS_TRIGGER_LEFT, 1.0)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, Btn.bit(Btn.SPRINT), "L2 sprints")
	fake.release_all()
	fake.press_button(0, JOY_BUTTON_DPAD_LEFT)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), -1.0, 0.0, "the stick's D-pad mode moves")


func test_stick_curve() -> void:
	assert_eq(InputDevices.stick_curve(0.0), 0.0)
	assert_eq(InputDevices.stick_curve(0.2), 0.0)
	assert_eq(InputDevices.stick_curve(0.25), 0.0, "the dead zone edge does not count")
	assert_almost_eq(InputDevices.stick_curve(0.26), 0.01 / 0.6 + 0.35, EPS)
	assert_almost_eq(InputDevices.stick_curve(0.55), 0.85, EPS)
	assert_almost_eq(InputDevices.stick_curve(0.64), 1.0, EPS)
	assert_eq(InputDevices.stick_curve(0.85), 1.0)
	assert_eq(InputDevices.stick_curve(1.0), 1.0)
	assert_eq(InputDevices.stick_curve(-0.9), 0.0)


func test_left_stick_follows_the_curve_in_both_directions() -> void:
	fake.plug_pad(0)
	fake.set_axis(0, JOY_AXIS_LEFT_X, 0.55)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), 0.85, 0.0, "right")
	fake.set_axis(0, JOY_AXIS_LEFT_X, -0.55)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), -0.85, 0.0, "left")
	fake.set_axis(0, JOY_AXIS_LEFT_X, 0.0)
	fake.set_axis(0, JOY_AXIS_LEFT_Y, -0.55)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), 0.0, 0.85, "stick up moves toward the opponent")
	fake.set_axis(0, JOY_AXIS_LEFT_Y, 0.2)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), 0.0, 0.0, "inside the dead zone")


func test_stick_move_vector_is_clamped_to_length_1() -> void:
	fake.plug_pad(0)
	fake.set_axis(0, JOY_AXIS_LEFT_X, 0.55)
	fake.set_axis(0, JOY_AXIS_LEFT_Y, -0.55)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), DIAG, DIAG, "0.85, 0.85 is longer than 1")
	fake.set_axis(0, JOY_AXIS_LEFT_X, 0.3)
	fake.set_axis(0, JOY_AXIS_LEFT_Y, -0.3)
	var v: float = InputDevices.stick_curve(0.3)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), v, v, "short vectors stay as they are")


func test_dpad_and_stick_both_move() -> void:
	fake.plug_pad(0)
	fake.press_button(0, JOY_BUTTON_DPAD_UP)
	fake.set_axis(0, JOY_AXIS_LEFT_Y, -0.4)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), 0.0, 1.0, "the stronger of the two")
	fake.set_axis(0, JOY_AXIS_LEFT_Y, 0.0)
	fake.set_axis(0, JOY_AXIS_LEFT_X, 1.0)
	_assert_move(input.sample_device(profile, InputDevices.PAD0), DIAG, DIAG, "D-pad up plus stick right")


func test_all_merges_keyboard_mouse_and_the_first_controller() -> void:
	fake.plug_pad(0)
	fake.plug_pad(1)
	fake.press_key(KEY_W)
	fake.press_mouse(MOUSE_BUTTON_LEFT)
	fake.press_button(0, JOY_BUTTON_A)
	fake.press_button(1, JOY_BUTTON_B)
	var raw: RawInput = input.sample_device(profile, InputDevices.ALL)
	assert_eq(raw.buttons, Btn.bit(Btn.LIGHT) | Btn.bit(Btn.JUMP), "the second controller is not read")
	_assert_move(raw, 0.0, 1.0)


func test_single_player_reads_all_devices() -> void:
	fake.plug_pad(0)
	input.set_single_player(profile)
	fake.press_button(0, JOY_BUTTON_A)
	fake.press_key(KEY_K)
	assert_eq(input.sample(0).buttons, Btn.bit(Btn.JUMP) | Btn.bit(Btn.HEAVY))
	assert_eq(input.sample(1).buttons, 0, "no second player")


func test_keyboard_device_ignores_controllers_and_controller_device_ignores_the_keyboard() -> void:
	fake.plug_pad(0)
	fake.press_button(0, JOY_BUTTON_A)
	assert_eq(input.sample_device(profile, InputDevices.KBM).buttons, 0)
	fake.release_all()
	fake.press_key(KEY_J)
	fake.press_mouse(MOUSE_BUTTON_RIGHT)
	assert_eq(input.sample_device(profile, InputDevices.PAD0).buttons, 0)


func test_a_controller_device_with_no_controller_reads_nothing() -> void:
	var raw: RawInput = input.sample_device(profile, InputDevices.PAD1)
	assert_eq(raw.buttons, 0)
	_assert_move(raw, 0.0, 0.0)


func test_arrow_layout() -> void:
	var cases: Array = [
		[KEY_J, Btn.LIGHT], [KEY_KP_4, Btn.LIGHT], [KEY_K, Btn.HEAVY], [KEY_KP_5, Btn.HEAVY],
		[KEY_L, Btn.BLOCK], [KEY_KP_6, Btn.BLOCK], [KEY_SEMICOLON, Btn.DODGE], [KEY_KP_0, Btn.DODGE],
		[KEY_I, Btn.JUMP], [KEY_KP_8, Btn.JUMP], [KEY_O, Btn.INTERACT], [KEY_KP_9, Btn.INTERACT],
		[KEY_U, Btn.ULTIMATE], [KEY_KP_7, Btn.ULTIMATE],
	]
	for c: Array in cases:
		fake.release_all()
		fake.press_key(c[0])
		assert_eq(input.sample_device(profile, InputDevices.KB_ARROWS).buttons, Btn.bit(c[1]), OS.get_keycode_string(c[0]))
	fake.release_all()
	fake.press_key(KEY_UP)
	fake.press_key(KEY_LEFT)
	_assert_move(input.sample_device(profile, InputDevices.KB_ARROWS), -DIAG, DIAG, "arrows move")
	fake.release_all()
	fake.press_key(KEY_W)
	fake.press_key(KEY_SPACE)
	fake.press_mouse(MOUSE_BUTTON_LEFT)
	var raw: RawInput = input.sample_device(profile, InputDevices.KB_ARROWS)
	assert_eq(raw.buttons, 0, "keys and mouse outside the layout")
	_assert_move(raw, 0.0, 0.0)


func test_arrow_layout_pauses_on_backspace_and_numpad_enter() -> void:
	fake.press_key(KEY_BACKSPACE)
	assert_true(input.pause_edge(profile, InputDevices.KB_ARROWS))
	fake.release_all()
	assert_false(input.pause_edge(profile, InputDevices.KB_ARROWS))
	fake.press_key(KEY_KP_ENTER)
	assert_true(input.pause_edge(profile, InputDevices.KB_ARROWS))


func test_arrow_layout_is_fixed() -> void:
	profile.bind(ControlProfile.KB, "light", 0, InputToken.key(KEY_Z))
	profile.clear_slot(ControlProfile.KB, "light", 1)
	fake.press_key(KEY_J)
	assert_eq(input.sample_device(profile, InputDevices.KB_ARROWS).buttons, Btn.bit(Btn.LIGHT))


func test_shared_keyboard_player_1_ignores_the_arrow_layout() -> void:
	var p2: ControlProfile = ControlProfile.create("Player 2")
	var devices: Array[String] = [InputDevices.KBM, InputDevices.KB_ARROWS]
	var profiles: Array[ControlProfile] = [profile, p2]
	input.set_versus(devices, profiles)

	fake.press_key(KEY_J)
	assert_eq(input.sample(0).buttons, 0, "J is player 2's light attack")
	assert_eq(input.sample(1).buttons, Btn.bit(Btn.LIGHT))

	fake.release_all()
	fake.press_key(KEY_UP)
	_assert_move(input.sample(0), 0.0, 0.0, "player 1 ignores the arrows")
	_assert_move(input.sample(1), 0.0, 1.0)

	fake.release_all()
	fake.press_key(KEY_W)
	fake.press_mouse(MOUSE_BUTTON_LEFT)
	fake.press_key(KEY_F)
	var p1: RawInput = input.sample(0)
	_assert_move(p1, 0.0, 1.0, "W still moves player 1")
	assert_eq(p1.buttons, Btn.bit(Btn.LIGHT) | Btn.bit(Btn.JUMP))
	assert_eq(input.sample(1).buttons, 0)
	_assert_move(input.sample(1), 0.0, 0.0)


func test_shared_keyboard_pause_keys_are_split() -> void:
	var devices: Array[String] = [InputDevices.KBM, InputDevices.KB_ARROWS]
	var profiles: Array[ControlProfile] = [profile, ControlProfile.create("Player 2")]
	input.set_versus(devices, profiles)
	fake.press_key(KEY_BACKSPACE)
	assert_false(input.pause_pressed(0))
	assert_true(input.pause_pressed(1))
	fake.press_key(KEY_ESCAPE)
	assert_true(input.pause_pressed(0))
	assert_false(input.pause_pressed(1), "still held")


func test_the_exclusion_holds_every_arrow_layout_key_and_nothing_else() -> void:
	var devices: Array[String] = [InputDevices.KBM, InputDevices.KB_ARROWS]
	var profiles: Array[ControlProfile] = [profile, ControlProfile.create("Player 2")]
	input.set_versus(devices, profiles)
	var ex: Dictionary = input.excluded_tokens(0)
	for code: int in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_I, KEY_O, KEY_U,
			KEY_BACKSPACE, KEY_KP_ENTER, KEY_KP_0, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]:
		assert_true(ex.has(InputToken.key(code)), OS.get_keycode_string(code))
	assert_eq(ex.size(), 20)
	assert_false(ex.has(InputToken.key(KEY_W)))
	assert_eq(input.excluded_tokens(1), {}, "player 2 ignores nothing")


func test_no_exclusion_when_player_2_uses_a_controller() -> void:
	fake.plug_pad(0)
	var devices: Array[String] = [InputDevices.KBM, InputDevices.PAD0]
	var profiles: Array[ControlProfile] = [profile, ControlProfile.create("Player 2")]
	input.set_versus(devices, profiles)
	assert_eq(input.excluded_tokens(0), {})
	fake.press_key(KEY_J)
	fake.press_key(KEY_UP)
	var p1: RawInput = input.sample(0)
	assert_eq(p1.buttons, Btn.bit(Btn.LIGHT))
	_assert_move(p1, 0.0, 1.0)
	assert_eq(input.sample(1).buttons, 0)


func test_every_action_can_be_rebound_on_keyboard_and_controller() -> void:
	fake.plug_pad(0)
	# keyboard: action i on F1 + i
	for i: int in Bindings.ACTIONS.size():
		var action: String = Bindings.ACTIONS[i]
		var capture: RebindCapture = RebindCapture.new(ControlProfile.KB, fake)
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_F1 + i
		key.pressed = true
		capture.feed(key)
		assert_true(capture.apply_to(profile, action, 0), action)
	# controller: action i on button i
	for i: int in Bindings.ACTIONS.size():
		var action: String = Bindings.ACTIONS[i]
		var capture: RebindCapture = RebindCapture.new(ControlProfile.PAD, fake)
		var jb: InputEventJoypadButton = InputEventJoypadButton.new()
		jb.button_index = i as JoyButton
		jb.pressed = true
		capture.feed(jb)
		assert_true(capture.apply_to(profile, action, 0), action)
	for i: int in Bindings.ACTIONS.size():
		var action: String = Bindings.ACTIONS[i]
		for tab: String in [ControlProfile.KB, ControlProfile.PAD]:
			fake.release_all()
			if tab == ControlProfile.KB:
				fake.press_key(KEY_F1 + i)
			else:
				fake.press_button(0, i)
			var device: String = InputDevices.KBM if tab == ControlProfile.KB else InputDevices.PAD0
			assert_eq(input.action_value(profile, action, device), 1.0, "%s on %s" % [action, tab])
			var raw: RawInput = input.sample_device(profile, device)
			if Bindings.ACTION_BUTTON.has(action):
				assert_eq(raw.buttons, Btn.bit(Bindings.ACTION_BUTTON[action]), "%s on %s" % [action, tab])
			elif action == "up":
				_assert_move(raw, 0.0, 1.0, tab)
			elif action == "left":
				_assert_move(raw, -1.0, 0.0, tab)
