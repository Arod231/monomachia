extends GutTest
## Controller style detection and the names shown for bindings: PlayStation,
## Xbox and generic controllers, keys and mouse buttons, and the demo's rule
## for which binding a prompt names.

var fake: FakeDeviceState
var input: InputDevices
var p1: ControlProfile
var p2: ControlProfile


func before_each() -> void:
	fake = FakeDeviceState.new()
	input = InputDevices.new(fake)
	p1 = ControlProfile.create("Player 1")
	p2 = ControlProfile.create("Player 2")


func _versus(d1: String, d2: String) -> void:
	var devices: Array[String] = [d1, d2]
	var profiles: Array[ControlProfile] = [p1, p2]
	input.set_versus(devices, profiles)


func _press_event(button: int) -> InputEventJoypadButton:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = button as JoyButton
	e.pressed = true
	return e


func test_detects_playstation_controllers() -> void:
	assert_eq(PadStyle.detect("", {"vendor_id": 0x054C}), PadStyle.PLAYSTATION, "Sony vendor id")
	assert_eq(PadStyle.detect("", {"vendor_id": "1356"}), PadStyle.PLAYSTATION, "vendor id as a decimal string")
	assert_eq(PadStyle.detect("", {"vendor_id": "0x054c"}), PadStyle.PLAYSTATION, "vendor id as a hex string")
	assert_eq(PadStyle.detect("PS5 Controller"), PadStyle.PLAYSTATION)
	assert_eq(PadStyle.detect("PS4 Controller"), PadStyle.PLAYSTATION)
	assert_eq(PadStyle.detect("DualSense Wireless Controller"), PadStyle.PLAYSTATION)
	assert_eq(PadStyle.detect("Wireless Controller"), PadStyle.PLAYSTATION)
	assert_eq(PadStyle.detect("Generic", {"raw_name": "Qanba Obsidian"}), PadStyle.PLAYSTATION, "raw name")


func test_detects_xbox_controllers_before_playstation_names() -> void:
	assert_eq(PadStyle.detect("", {"vendor_id": 0x045E}), PadStyle.XBOX, "Microsoft vendor id")
	assert_eq(PadStyle.detect("", {"vendor_id": "1118"}), PadStyle.XBOX)
	assert_eq(PadStyle.detect("Xbox Series X Controller"), PadStyle.XBOX)
	assert_eq(PadStyle.detect("Xbox 360 Controller"), PadStyle.XBOX)
	assert_eq(PadStyle.detect("Xbox Wireless Controller"), PadStyle.XBOX, "not the PlayStation's 'Wireless Controller'")
	assert_eq(PadStyle.detect("XInput Controller"), PadStyle.XBOX)


func test_other_controllers_are_generic() -> void:
	assert_eq(PadStyle.detect("Nintendo Switch Pro Controller", {"vendor_id": "1406"}), PadStyle.GENERIC)
	assert_eq(PadStyle.detect(""), PadStyle.GENERIC)
	assert_eq(PadStyle.display_name(PadStyle.PLAYSTATION), "PlayStation")
	assert_eq(PadStyle.display_name(PadStyle.XBOX), "Xbox")
	assert_eq(PadStyle.display_name(PadStyle.GENERIC), "generic")


func test_playstation_and_xbox_labels_for_each_action() -> void:
	fake.plug_pad(0, "PS5 Controller", {"vendor_id": "1356"})
	fake.plug_pad(1, "Xbox Series X Controller", {"vendor_id": "1118"})
	_versus(InputDevices.PAD0, InputDevices.PAD1)
	var expected: Dictionary = {
		"up": ["D-pad ↑", "D-pad ↑"],
		"down": ["D-pad ↓", "D-pad ↓"],
		"left": ["D-pad ←", "D-pad ←"],
		"right": ["D-pad →", "D-pad →"],
		"light": ["R1", "RB"],
		"heavy": ["R2", "RT"],
		"block": ["L1", "LB"],
		"dodge": ["○", "B"],
		"jump": ["×", "A"],
		"interact": ["□", "X"],
		"ultimate": ["△", "Y"],
		"sprint": ["L3", "LS"],
		"pause": ["Options", "Menu"],
	}
	for action: String in Bindings.ACTIONS:
		assert_eq(input.label(action, 0), expected[action][0], "PlayStation " + action)
		assert_eq(input.label(action, 1), expected[action][1], "Xbox " + action)
	assert_eq(input.pad_style_for(InputDevices.PAD0), PadStyle.PLAYSTATION)
	assert_eq(input.pad_style_for(InputDevices.PAD1), PadStyle.XBOX)
	assert_eq(input.pad_name(0), "PS5 Controller")


func test_fight_stick_labels() -> void:
	p1.use_fight_stick_layout()
	fake.plug_pad(0, "PS4 Controller")
	_versus(InputDevices.PAD0, InputDevices.KBM)
	assert_eq(input.label("light", 0), "□")
	assert_eq(input.label("heavy", 0), "△")
	assert_eq(input.label("block", 0), "R1")
	assert_eq(input.label("interact", 0), "R2")
	assert_eq(input.label("ultimate", 0), "L1")
	assert_eq(input.label("sprint", 0), "L2")


func test_keyboard_labels_for_each_action() -> void:
	input.set_single_player(p1)
	var expected: Dictionary = {
		"up": "W", "down": "S", "left": "A", "right": "D",
		"light": "Left Click", "heavy": "Right Click", "block": "L-Shift", "dodge": "Space",
		"jump": "F", "interact": "E", "ultimate": "Q", "sprint": "", "pause": "Esc",
	}
	for action: String in Bindings.ACTIONS:
		assert_eq(input.label(action, 0), expected[action], action)


func test_single_player_labels_follow_the_last_device_used() -> void:
	fake.plug_pad(0, "DualSense Wireless Controller")
	input.set_single_player(p1)
	assert_eq(input.label("light"), "Left Click")
	input.note_event(_press_event(JOY_BUTTON_A))
	assert_eq(input.last_used, InputDevices.LastUsed.PAD)
	assert_eq(input.label("light"), "R1")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	input.note_event(key)
	assert_eq(input.label("light"), "Left Click")
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.3
	input.note_event(motion)
	assert_eq(input.last_used, InputDevices.LastUsed.KEYBOARD, "a small stick drift doesn't count")
	motion.axis_value = -0.7
	input.note_event(motion)
	assert_eq(input.label("jump"), "×")
	fake.unplug_pad(0)
	assert_eq(input.label("jump"), "F", "keyboard names once no controller is connected")


func test_arrow_layout_labels() -> void:
	_versus(InputDevices.KBM, InputDevices.KB_ARROWS)
	var expected: Dictionary = {
		"up": "↑", "down": "↓", "left": "←", "right": "→",
		"light": "J", "heavy": "K", "block": "L", "dodge": ";",
		"jump": "I", "interact": "O", "ultimate": "U", "sprint": "", "pause": "Backspace",
	}
	for action: String in Bindings.ACTIONS:
		assert_eq(input.label(action, 1), expected[action], action)


func test_player_1_labels_skip_keys_the_arrow_layout_uses() -> void:
	p1.bind(ControlProfile.KB, "jump", 0, InputToken.key(KEY_I))
	p1.bind(ControlProfile.KB, "jump", 1, InputToken.key(KEY_F))
	assert_eq(p1.slots(ControlProfile.KB, "jump"), [InputToken.key(KEY_I), InputToken.key(KEY_F)] as Array[String])
	_versus(InputDevices.KBM, InputDevices.KB_ARROWS)
	assert_eq(input.label("jump", 0), "F", "I belongs to player 2")
	p1.clear_slot(ControlProfile.KB, "jump", 1)
	assert_eq(input.label("jump", 0), "I", "falls back to the first binding when every one is excluded")
	fake.plug_pad(0)
	_versus(InputDevices.KBM, InputDevices.PAD0)
	assert_eq(input.label("jump", 0), "I", "no exclusion against a controller")


func test_first_label_prefers_a_binding_that_is_not_a_stick_direction() -> void:
	var stick_first: Array = [InputToken.joy_axis(JOY_AXIS_LEFT_Y, false), InputToken.joy_button(JOY_BUTTON_DPAD_UP)]
	assert_eq(BindingLabels.first_label(stick_first, PadStyle.XBOX), "D-pad ↑")
	assert_eq(BindingLabels.first_label([InputToken.joy_axis(JOY_AXIS_LEFT_Y, false)], PadStyle.XBOX), "Stick ↑")
	assert_eq(BindingLabels.first_label([InputToken.joy_axis(JOY_AXIS_TRIGGER_RIGHT, true), InputToken.joy_button(JOY_BUTTON_A)], PadStyle.XBOX),
		"RT", "a trigger counts as a button")
	assert_eq(BindingLabels.first_label([]), "")


func test_key_names() -> void:
	var cases: Dictionary = {
		KEY_W: "W", KEY_1: "1", KEY_SHIFT: "Shift", KEY_SPACE: "Space", KEY_ESCAPE: "Esc",
		KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→", KEY_SEMICOLON: ";",
		KEY_BACKSPACE: "Backspace", KEY_KP_4: "Num 4", KEY_KP_0: "Num 0", KEY_KP_ENTER: "Num Enter",
		KEY_F1: "F1", KEY_TAB: "Tab", KEY_BRACKETLEFT: "[", KEY_QUOTELEFT: "`",
	}
	for code: int in cases:
		assert_eq(BindingLabels.token_label(InputToken.key(code)), cases[code], OS.get_keycode_string(code))


func test_mouse_names() -> void:
	assert_eq(BindingLabels.token_label(InputToken.mouse(MOUSE_BUTTON_LEFT)), "Left Click")
	assert_eq(BindingLabels.token_label(InputToken.mouse(MOUSE_BUTTON_RIGHT)), "Right Click")
	assert_eq(BindingLabels.token_label(InputToken.mouse(MOUSE_BUTTON_MIDDLE)), "Middle Click")
	assert_eq(BindingLabels.token_label(InputToken.mouse(MOUSE_BUTTON_XBUTTON1)), "Mouse 4")
	assert_eq(BindingLabels.token_label(InputToken.mouse(MOUSE_BUTTON_XBUTTON2)), "Mouse 5")


func test_controller_names_by_style() -> void:
	var a: String = InputToken.joy_button(JOY_BUTTON_A)
	assert_eq(BindingLabels.token_label(a, PadStyle.PLAYSTATION), "×")
	assert_eq(BindingLabels.token_label(a, PadStyle.XBOX), "A")
	assert_eq(BindingLabels.token_label(a, PadStyle.GENERIC), "Button 0")
	var back: String = InputToken.joy_button(JOY_BUTTON_BACK)
	assert_eq(BindingLabels.token_label(back, PadStyle.PLAYSTATION), "Create")
	assert_eq(BindingLabels.token_label(back, PadStyle.XBOX), "View")
	var r3: String = InputToken.joy_button(JOY_BUTTON_RIGHT_STICK)
	assert_eq(BindingLabels.token_label(r3, PadStyle.PLAYSTATION), "R3")
	assert_eq(BindingLabels.token_label(r3, PadStyle.XBOX), "RS")
	assert_eq(BindingLabels.token_label(InputToken.joy_button(JOY_BUTTON_DPAD_DOWN), PadStyle.GENERIC), "D-pad ↓")
	var lt: String = InputToken.joy_axis(JOY_AXIS_TRIGGER_LEFT, true)
	assert_eq(BindingLabels.token_label(lt, PadStyle.PLAYSTATION), "L2")
	assert_eq(BindingLabels.token_label(lt, PadStyle.XBOX), "LT")
	assert_eq(BindingLabels.token_label(lt, PadStyle.GENERIC), "Left trigger")


func test_stick_names() -> void:
	assert_eq(BindingLabels.token_label("a:0-"), "Stick ←")
	assert_eq(BindingLabels.token_label("a:0+"), "Stick →")
	assert_eq(BindingLabels.token_label("a:1-"), "Stick ↑")
	assert_eq(BindingLabels.token_label("a:1+"), "Stick ↓")
	assert_eq(BindingLabels.token_label("a:2+"), "R-Stick →")
	assert_eq(BindingLabels.token_label("a:3-"), "R-Stick ↑")
	assert_eq(BindingLabels.token_label("a:7+"), "Axis 7+")


## The demo named the two sides of a key pair (KEY_NAMES ShiftLeft "L-Shift").
func test_key_names_with_a_side() -> void:
	assert_eq(BindingLabels.token_label(InputToken.key(KEY_SHIFT, KEY_LOCATION_LEFT)), "L-Shift")
	assert_eq(BindingLabels.token_label(InputToken.key(KEY_SHIFT, KEY_LOCATION_RIGHT)), "R-Shift")
	assert_eq(BindingLabels.token_label(InputToken.key(KEY_CTRL, KEY_LOCATION_LEFT)), "L-Ctrl")
	assert_eq(BindingLabels.token_label(InputToken.key(KEY_CTRL, KEY_LOCATION_RIGHT)), "R-Ctrl")
	assert_eq(BindingLabels.token_label(InputToken.key(KEY_ALT, KEY_LOCATION_LEFT)), "L-Alt")
	assert_eq(BindingLabels.token_label(InputToken.key(KEY_ALT, KEY_LOCATION_RIGHT)), "R-Alt")
	assert_eq(BindingLabels.token_label(InputToken.key(KEY_SHIFT)), "Shift", "either Shift")
