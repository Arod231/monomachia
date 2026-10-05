extends GutTest
## MenuPage and its rows (22.2), driven by key and controller events through
## the viewport, as a player's reach it, with a fake clock for the repeat.

var page: MenuScreen
var pressed: Array[String] = []
var options: OptionRow
var volume: SliderRow
var option_log: Array[int] = []
var volume_log: Array[int] = []
var now: int = 0
## Every menu sound GameServices plays during a test.
var cues: Array[StringName] = []
var _record: Callable


func before_each() -> void:
	pressed.clear()
	option_log.clear()
	volume_log.clear()
	cues.clear()
	now = 0
	page = MenuScreen.new()
	page.nav.clock = func() -> int: return now
	add_child_autofree(page)
	for label: String in ["One", "Two", "Three"]:
		page.add_button(label, "", func() -> void: pressed.append(label))
	options = page.add_options("Graphics", ["High", "Medium", "Low"] as Array[String], 0,
		func(i: int) -> void: option_log.append(i))
	volume = page.add_slider("Music", 50, func(v: int) -> void: volume_log.append(v))
	_record = func(cue: StringName, _voice: Node) -> void: cues.append(cue)
	_ui_sounds().played.connect(_record)
	page.open()
	await get_tree().process_frame


func after_each() -> void:
	_ui_sounds().played.disconnect(_record)


func _ui_sounds() -> SoundPlayer:
	return get_tree().root.get_node("GameServices").get("ui_sounds")


func _key(key: Key, echo: bool = false) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		e.echo = echo and down
		get_viewport().push_input(e)


func _pad(button: JoyButton, down: bool = true, up: bool = true) -> void:
	for p: bool in [true, false]:
		if (p and not down) or (not p and not up):
			continue
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = p
		get_viewport().push_input(e)


func _stick(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	get_viewport().push_input(e)


func _focused() -> Control:
	return page.focused_item()


func test_opening_focuses_the_first_item_silently() -> void:
	assert_eq(_focused(), page.buttons[0])
	assert_eq(cues, [] as Array[StringName])


func test_up_and_down_walk_the_items_and_wrap_round() -> void:
	_key(KEY_DOWN)
	assert_eq(_focused(), page.buttons[1], "one step, not two (Godot's own focus move is taken)")
	_key(KEY_S)
	_key(KEY_DOWN)
	assert_eq(_focused(), options)
	_key(KEY_DOWN)
	assert_eq(_focused(), volume)
	_key(KEY_DOWN)
	assert_eq(_focused(), page.buttons[0], "wraps to the top")
	_key(KEY_UP)
	assert_eq(_focused(), volume, "and to the bottom")
	_key(KEY_W)
	assert_eq(_focused(), options)
	assert_eq(cues.count(&"ui_move"), 7, "each move sounds")


func test_left_and_right_move_like_up_and_down_on_an_entry() -> void:
	_key(KEY_RIGHT)
	assert_eq(_focused(), page.buttons[1])
	_key(KEY_A)
	assert_eq(_focused(), page.buttons[0])


func test_enter_space_and_a_press_the_focused_entry_once() -> void:
	_key(KEY_ENTER)
	_key(KEY_DOWN)
	_key(KEY_SPACE)
	_key(KEY_DOWN)
	_pad(JOY_BUTTON_A)
	assert_eq(pressed, ["One", "Two", "Three"] as Array[String])
	assert_eq(cues.count(&"ui_select"), 3)


func test_a_held_enter_chooses_once() -> void:
	_key(KEY_ENTER)
	_key(KEY_ENTER, true)
	assert_eq(pressed, ["One"] as Array[String])


func test_esc_backspace_and_b_go_back() -> void:
	watch_signals(page)
	_key(KEY_ESCAPE)
	_key(KEY_BACKSPACE)
	_pad(JOY_BUTTON_B)
	assert_signal_emit_count(page, "back_requested", 3)
	assert_eq(cues, [&"ui_back", &"ui_back", &"ui_back"] as Array[StringName])


func test_the_d_pad_and_stick_move_and_repeat_while_held() -> void:
	_pad(JOY_BUTTON_DPAD_DOWN, true, false)
	assert_eq(_focused(), page.buttons[1])
	now = 379
	page._process(0.016)
	assert_eq(_focused(), page.buttons[1], "held, no repeat before 380 ms")
	now = 380
	page._process(0.016)
	assert_eq(_focused(), page.buttons[2], "the first repeat")
	now = 500
	page._process(0.016)
	assert_eq(_focused(), options, "every 120 ms after")
	_pad(JOY_BUTTON_DPAD_DOWN, false, true)
	now = 2000
	page._process(0.016)
	assert_eq(_focused(), options, "let go")
	_stick(JOY_AXIS_LEFT_Y, -0.8)
	assert_eq(_focused(), page.buttons[2], "the stick moves up")
	_stick(JOY_AXIS_LEFT_Y, -0.9)
	_stick(JOY_AXIS_LEFT_Y, -0.95)
	assert_eq(_focused(), page.buttons[2], "and its small motions while held don't move again")


func test_an_option_row_changes_with_left_and_right_and_wraps() -> void:
	options.grab_focus()
	cues.clear()
	_key(KEY_RIGHT)
	assert_eq(options.index, 1)
	_key(KEY_D)
	_key(KEY_RIGHT)
	assert_eq(options.index, 0, "wraps round")
	_key(KEY_LEFT)
	assert_eq(options.index, 2)
	_pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(options.index, 1, "the D-pad too")
	_pad(JOY_BUTTON_A)
	assert_eq(options.index, 2, "OK steps on")
	assert_eq(option_log, [1, 2, 0, 2, 1, 2] as Array[int])
	assert_eq(_focused(), options, "the focus stays on the row")
	assert_eq(cues.count(&"ui_move"), 6)


func test_an_option_row_lights_the_chosen_chip() -> void:
	options.set_index(2)
	assert_eq(options.chips[2].theme_type_variation, UiTheme.OPTION_ON)
	assert_eq(options.chips[0].theme_type_variation, UiTheme.OPTION)
	assert_eq(option_log, [] as Array[int], "set_index is quiet")


func test_clicking_a_chip_picks_it_and_focuses_the_row() -> void:
	options.chips[1].pressed.emit()
	assert_eq(options.index, 1)
	assert_eq(_focused(), options)
	assert_eq(option_log, [1] as Array[int])


func test_a_focused_row_is_lit() -> void:
	assert_eq(options.theme_type_variation, UiTheme.MENU_ROW)
	options.grab_focus()
	assert_eq(options.theme_type_variation, UiTheme.MENU_ROW_LIT)
	page.buttons[0].grab_focus()
	assert_eq(options.theme_type_variation, UiTheme.MENU_ROW)


func test_a_slider_row_steps_by_five_and_stops_at_its_ends() -> void:
	volume.grab_focus()
	_key(KEY_RIGHT)
	assert_eq(volume.value, 55)
	_key(KEY_LEFT)
	_key(KEY_LEFT)
	assert_eq(volume.value, 45)
	assert_eq(volume.readout.text, "45")
	volume.set_value(100)
	_key(KEY_RIGHT)
	assert_eq(volume.value, 100)
	assert_eq(volume_log, [55, 50, 45] as Array[int], "set_value is quiet, and the end doesn't move")


func test_dragging_the_slider_reports_the_value() -> void:
	volume.slider.value = 70
	assert_eq(volume_log, [70] as Array[int])
	assert_eq(volume.value, 70)


func test_hovering_an_item_focuses_it() -> void:
	page.buttons[2].mouse_entered.emit()
	assert_eq(_focused(), page.buttons[2])
	assert_eq(cues, [&"ui_move"] as Array[StringName])


func test_hidden_and_disabled_items_are_skipped() -> void:
	page.buttons[1].disabled = true
	page.buttons[2].visible = false
	_key(KEY_DOWN)
	assert_eq(_focused(), options)
	_key(KEY_UP)
	assert_eq(_focused(), page.buttons[0])


func test_with_the_focus_lost_a_move_brings_it_back() -> void:
	page.buttons[1].grab_focus()
	page.buttons[1].release_focus()
	_key(KEY_DOWN)
	assert_eq(_focused(), page.buttons[0])
	page.buttons[0].release_focus()
	_pad(JOY_BUTTON_A)
	assert_eq(_focused(), page.buttons[0], "OK brings it back without pressing")
	assert_eq(pressed, [] as Array[String])


func test_a_closed_page_takes_nothing() -> void:
	page.close()
	watch_signals(page)
	_key(KEY_ESCAPE)
	_key(KEY_ENTER)
	assert_signal_not_emitted(page, "back_requested")
	assert_eq(pressed, [] as Array[String])


func test_reopening_returns_to_the_item_it_had() -> void:
	page.buttons[2].grab_focus()
	page.close()
	page.reopen()
	await get_tree().process_frame
	assert_eq(_focused(), page.buttons[2])
	page.close()
	page.open()
	await get_tree().process_frame
	assert_eq(_focused(), page.buttons[0], "open() starts on the first")


func test_the_input_feed_sees_what_the_page_takes() -> void:
	var input: InputDevices = get_tree().root.get_node("GameServices").get("input")
	var before: InputDevices.LastUsed = input.last_used
	input.last_used = InputDevices.LastUsed.KEYBOARD
	_pad(JOY_BUTTON_DPAD_DOWN)
	var seen: InputDevices.LastUsed = input.last_used
	input.last_used = before
	assert_eq(_focused(), page.buttons[1], "the page took the D-pad")
	assert_eq(seen, InputDevices.LastUsed.PAD, "and the feed saw it")
