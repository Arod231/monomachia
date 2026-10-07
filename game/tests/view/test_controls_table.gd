extends GutTest
## The Controls screen's binding table as data (task 22.10): which tab it
## opens on, the 13 actions with two named slots each in the detected button
## style, and the controller status line.

var state: FakeDeviceState
var input: InputDevices


func before_each() -> void:
	state = FakeDeviceState.new()
	input = InputDevices.new(state)


func _labels(rows: Array[ControlsTable.Row]) -> Dictionary:
	var out: Dictionary = {}
	for r: ControlsTable.Row in rows:
		out[r.action] = r.slots
	return out


func test_the_table_lists_the_fourteen_actions_in_order_with_their_names_and_hints() -> void:
	var rows: Array[ControlsTable.Row] = ControlsTable.rows(ControlProfile.create(), ControlProfile.KB, PadStyle.GENERIC)
	assert_eq(rows.size(), 14, "the grip the fourteenth (KE task 6)")
	var actions: Array[String] = []
	for r: ControlsTable.Row in rows:
		actions.append(r.action)
		assert_eq(r.label, Bindings.ACTION_LABELS[r.action])
		assert_eq(r.hint, Bindings.ACTION_HINTS.get(r.action, ""))
		assert_eq(r.slots.size(), 2, "%s has two slots" % r.action)
	assert_eq(actions, Bindings.ACTIONS)


func test_the_keyboard_tab_names_keys_and_mouse_buttons_and_empty_slots_show_a_dash() -> void:
	var t: Dictionary = _labels(ControlsTable.rows(ControlProfile.create(), ControlProfile.KB, PadStyle.PLAYSTATION))
	assert_eq(t["up"], ["W", "↑"])
	assert_eq(t["light"], ["Left Click", "J"])
	assert_eq(t["block"], ["L-Shift", "L"])
	assert_eq(t["dodge"], ["Space", ControlsTable.EMPTY])
	assert_eq(t["sprint"], [ControlsTable.EMPTY, ControlsTable.EMPTY])
	assert_eq(t["grip"], ["R", ControlsTable.EMPTY])
	assert_eq(t["pause"], ["Esc", "P"])


func test_the_controller_tab_names_buttons_in_the_detected_style() -> void:
	var p: ControlProfile = ControlProfile.create()
	var ps: Dictionary = _labels(ControlsTable.rows(p, ControlProfile.PAD, PadStyle.PLAYSTATION))
	assert_eq(ps["light"], ["R1", ControlsTable.EMPTY])
	assert_eq(ps["heavy"], ["R2", ControlsTable.EMPTY])
	assert_eq(ps["jump"], ["×", ControlsTable.EMPTY])
	assert_eq(ps["dodge"], ["○", ControlsTable.EMPTY])
	assert_eq(ps["pause"], ["Options", ControlsTable.EMPTY])
	assert_eq(ps["up"], ["D-pad ↑", "Stick ↑"])
	var xbox: Dictionary = _labels(ControlsTable.rows(p, ControlProfile.PAD, PadStyle.XBOX))
	assert_eq(xbox["light"], ["RB", ControlsTable.EMPTY])
	assert_eq(xbox["heavy"], ["RT", ControlsTable.EMPTY])
	assert_eq(xbox["jump"], ["A", ControlsTable.EMPTY])
	assert_eq(xbox["pause"], ["Menu", ControlsTable.EMPTY])
	var generic: Dictionary = _labels(ControlsTable.rows(p, ControlProfile.PAD, PadStyle.GENERIC))
	assert_eq(generic["heavy"], ["Right trigger", ControlsTable.EMPTY])


func test_the_table_follows_the_profile() -> void:
	var p: ControlProfile = ControlProfile.create()
	p.bind(ControlProfile.KB, "light", 1, InputToken.key(KEY_H))
	p.use_fight_stick_layout()
	assert_eq(_labels(ControlsTable.rows(p, ControlProfile.KB, PadStyle.GENERIC))["light"], ["Left Click", "H"])
	assert_eq(_labels(ControlsTable.rows(p, ControlProfile.PAD, PadStyle.XBOX))["light"], ["X", ControlsTable.EMPTY])


func test_it_opens_on_the_tab_of_the_last_device_used() -> void:
	assert_eq(ControlsTable.opening_tab(input), ControlProfile.KB)
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	input.note_event(press)
	assert_eq(ControlsTable.opening_tab(input), ControlProfile.PAD)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	input.note_event(key)
	assert_eq(ControlsTable.opening_tab(input), ControlProfile.KB)


func test_the_status_line_names_the_controller_and_its_button_style() -> void:
	assert_eq(ControlsTable.status_line(input), "No controller detected. Connect one and press any button on it.")
	state.plug_pad(0, "PS5 Controller", {"vendor_id": 0x054C})
	assert_eq(ControlsTable.status_line(input), "Controller connected: PS5 Controller (PlayStation button names)")
	state.unplug_pad(0)
	state.plug_pad(1, "Xbox Series X Controller")
	assert_eq(ControlsTable.status_line(input), "Controller connected: Xbox Series X Controller (Xbox button names)")


func test_an_unknown_layout_asks_for_the_buttons_to_be_set() -> void:
	state.plug_pad(0, "Cheap Pad", {}, true, false)
	assert_eq(
		ControlsTable.status_line(input),
		"Controller connected: Cheap Pad (generic button names, unrecognised layout: set buttons below)"
	)


func test_the_keyboard_tab_explains_the_slots() -> void:
	assert_string_contains(ControlsTable.KB_NOTE, "Backspace clears")
	assert_string_contains(ControlsTable.KB_NOTE, "double-tapping")
