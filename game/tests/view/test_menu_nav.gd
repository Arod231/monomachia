extends GutTest
## MenuNav (22.2): keys and controller events to menu commands, and the
## demo's repeat for a held D-pad or stick (380 ms, then every 120 ms) on a
## fake clock.

const Cmd := MenuNav.Cmd

var now: int = 1000
var nav: MenuNav


func before_each() -> void:
	now = 1000
	nav = MenuNav.new(func() -> int: return now)


func _key(key: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = pressed
	e.echo = echo
	return e


func _pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func test_arrows_and_wasd_move() -> void:
	var expect: Dictionary = {
		KEY_UP: Cmd.UP, KEY_W: Cmd.UP, KEY_DOWN: Cmd.DOWN, KEY_S: Cmd.DOWN,
		KEY_LEFT: Cmd.LEFT, KEY_A: Cmd.LEFT, KEY_RIGHT: Cmd.RIGHT, KEY_D: Cmd.RIGHT,
	}
	for key: Key in expect:
		assert_eq(nav.command(_key(key)), expect[key], OS.get_keycode_string(key))
		assert_eq(nav.command(_key(key, false)), Cmd.NONE, "%s released" % OS.get_keycode_string(key))


func test_wasd_go_by_the_physical_key() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_Z
	e.physical_keycode = KEY_W
	e.pressed = true
	assert_eq(nav.command(e), Cmd.UP, "an AZERTY Z is the W key")


func test_enter_and_space_choose_esc_and_backspace_go_back() -> void:
	assert_eq(nav.command(_key(KEY_ENTER)), Cmd.OK)
	assert_eq(nav.command(_key(KEY_KP_ENTER)), Cmd.OK)
	assert_eq(nav.command(_key(KEY_SPACE)), Cmd.OK)
	assert_eq(nav.command(_key(KEY_ESCAPE)), Cmd.BACK)
	assert_eq(nav.command(_key(KEY_BACKSPACE)), Cmd.BACK)
	assert_eq(nav.command(_key(KEY_J)), Cmd.NONE, "other keys do nothing")


func test_a_held_key_repeats_moves_but_not_choices() -> void:
	assert_eq(nav.command(_key(KEY_DOWN, true, true)), Cmd.DOWN, "the system's key repeat moves")
	assert_eq(nav.command(_key(KEY_ENTER, true, true)), Cmd.NONE, "but never chooses twice")
	assert_eq(nav.command(_key(KEY_ESCAPE, true, true)), Cmd.NONE, "or goes back twice")


func test_a_and_b_choose_and_go_back() -> void:
	assert_eq(nav.command(_pad(JOY_BUTTON_A)), Cmd.OK)
	assert_eq(nav.command(_pad(JOY_BUTTON_A, false)), Cmd.NONE)
	assert_eq(nav.command(_pad(JOY_BUTTON_B)), Cmd.BACK)
	assert_eq(nav.command(_pad(JOY_BUTTON_X)), Cmd.NONE)


func test_the_d_pad_moves_and_repeats_while_held() -> void:
	assert_eq(nav.command(_pad(JOY_BUTTON_DPAD_DOWN)), Cmd.DOWN)
	now += 379
	assert_eq(nav.tick(), Cmd.NONE, "no repeat before 380 ms")
	now += 1
	assert_eq(nav.tick(), Cmd.DOWN, "the first repeat at 380 ms")
	assert_eq(nav.tick(), Cmd.NONE, "once")
	now += 119
	assert_eq(nav.tick(), Cmd.NONE)
	now += 1
	assert_eq(nav.tick(), Cmd.DOWN, "then every 120 ms")
	now += 120
	assert_eq(nav.tick(), Cmd.DOWN)
	assert_eq(nav.command(_pad(JOY_BUTTON_DPAD_DOWN, false)), Cmd.NONE)
	now += 1000
	assert_eq(nav.tick(), Cmd.NONE, "letting go stops it")


func test_the_stick_moves_past_the_threshold_and_repeats() -> void:
	assert_eq(nav.command(_stick(JOY_AXIS_LEFT_Y, -0.5)), Cmd.NONE, "under the threshold")
	assert_eq(nav.command(_stick(JOY_AXIS_LEFT_Y, -0.6)), Cmd.UP)
	assert_eq(nav.command(_stick(JOY_AXIS_LEFT_Y, -0.9)), Cmd.NONE, "leaning further is the same hold")
	now += 380
	assert_eq(nav.tick(), Cmd.UP)
	assert_eq(nav.command(_stick(JOY_AXIS_LEFT_X, 0.95)), Cmd.RIGHT, "a stronger lean to the side turns it")
	now += 379
	assert_eq(nav.tick(), Cmd.NONE, "and starts the repeat over")
	assert_eq(nav.command(_stick(JOY_AXIS_LEFT_X, 0.0)), Cmd.UP, "back to the held up")
	assert_eq(nav.command(_stick(JOY_AXIS_LEFT_Y, 0.1)), Cmd.NONE, "centred")
	now += 1000
	assert_eq(nav.tick(), Cmd.NONE)


func test_the_d_pad_wins_over_the_stick() -> void:
	nav.command(_stick(JOY_AXIS_LEFT_Y, 0.9))
	assert_eq(nav.command(_pad(JOY_BUTTON_DPAD_LEFT)), Cmd.LEFT)
	assert_eq(nav.command(_pad(JOY_BUTTON_DPAD_LEFT, false)), Cmd.DOWN, "the stick still holds down")


func test_reset_forgets_a_held_direction() -> void:
	nav.command(_pad(JOY_BUTTON_DPAD_UP))
	nav.reset()
	now += 1000
	assert_eq(nav.tick(), Cmd.NONE)


func test_which_events_a_menu_takes() -> void:
	assert_true(MenuNav.is_nav_event(_key(KEY_DOWN, false)), "a release")
	assert_true(MenuNav.is_nav_event(_stick(JOY_AXIS_LEFT_X, 0.1)), "a stick inside the dead zone")
	assert_false(MenuNav.is_nav_event(_stick(JOY_AXIS_RIGHT_X, 1.0)), "the right stick")
	assert_false(MenuNav.is_nav_event(_key(KEY_J)))
	assert_false(MenuNav.is_nav_event(_pad(JOY_BUTTON_Y)))
