extends GutTest
## The node that hands every input event to the input layer: it sees events
## before a focused Control can take them (menus), and on losing focus it
## releases the held keys and tells the host to pause.


## A focused menu item that takes every event, as Buttons take ui_accept and
## the viewport takes focus moves.
class Taker:
	extends Control

	func _gui_input(_event: InputEvent) -> void:
		accept_event()


## Records what reaches _unhandled_input().
class UnhandledSpy:
	extends Node

	var seen: Array[InputEvent] = []

	func _unhandled_input(event: InputEvent) -> void:
		seen.append(event)


var fake: FakeDeviceState
var input: InputDevices
var feed: InputFeed


func before_each() -> void:
	fake = FakeDeviceState.new()
	input = InputDevices.new(fake)
	feed = InputFeed.new(input)
	add_child_autofree(feed)


func _focused_taker() -> Taker:
	var taker: Taker = Taker.new()
	taker.focus_mode = Control.FOCUS_ALL
	add_child_autofree(taker)
	taker.grab_focus()
	return taker


func test_sees_events_a_focused_control_takes() -> void:
	var taker: Taker = _focused_taker()
	assert_true(taker.has_focus())
	var spy: UnhandledSpy = UnhandledSpy.new()
	add_child_autofree(spy)
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	get_viewport().push_input(button)
	assert_eq(spy.seen.size(), 0, "the menu item took the event")
	assert_eq(input.last_used, InputDevices.LastUsed.PAD, "the feed saw it first")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_DOWN
	key.pressed = true
	get_viewport().push_input(key)
	assert_eq(spy.seen.size(), 0)
	assert_eq(input.last_used, InputDevices.LastUsed.KEYBOARD)


func test_forwards_key_sides_to_the_device_state() -> void:
	var state: GodotDeviceState = GodotDeviceState.new()
	input = InputDevices.new(state)
	feed.input = input
	var shift: InputEventKey = InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.location = KEY_LOCATION_LEFT
	shift.pressed = true
	get_viewport().push_input(shift)
	var held: bool = state.is_key_pressed(KEY_SHIFT, KEY_LOCATION_LEFT)
	var right: bool = state.is_key_pressed(KEY_SHIFT, KEY_LOCATION_RIGHT)
	state.release_keys()
	assert_true(held)
	assert_false(right)


func test_runs_while_the_game_is_paused() -> void:
	assert_eq(feed.process_mode, Node.PROCESS_MODE_ALWAYS)


## The demo paused on window blur and cleared its keys (spec story 10).
func test_losing_focus_releases_the_keys_and_asks_for_a_pause() -> void:
	watch_signals(feed)
	fake.press_key(KEY_SHIFT, KEY_LOCATION_LEFT)
	fake.press_key(KEY_W)
	fake.press_mouse(MOUSE_BUTTON_LEFT)
	var profile: ControlProfile = ControlProfile.create()
	input.set_single_player(profile)
	assert_ne(input.sample(0).buttons, 0)
	feed.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_signal_emitted(feed, "focus_lost")
	var raw: RawInput = input.sample(0)
	assert_eq(raw.buttons, 0, "keys and mouse buttons released")
	assert_eq(raw.my, 0.0)
