class_name ControlsScreen
extends MenuScreen
## The Controls screen's binding table (port of showControls() in
## v0.1-web-mvp:src/ui/menus.ts): Keyboard-and-mouse and Controller tabs, opening on the
## tab of the last device used; on the controller tab a status line naming the
## connected controller and its button style; the 13 actions with two slots
## each, named in that style (ControlsTable); and Reset to defaults and, on the
## controller tab, the fight-stick layout, each saved at once. Back returns to
## the page that opened it.
##
## Choosing a slot listens for its input (rebinding capture, 22.11, through a
## RebindCapture): on the keyboard tab the next key or mouse button, on the
## controller tab, once every button is let go, the next button, trigger or
## stick direction. The result goes into the active profile, which is saved;
## a token bound here leaves any other action on the tab. Esc cancels and
## Backspace or Delete clears the slot, and 5 seconds with no press cancels,
## so a controller alone can back out. While listening the screen takes every
## event in _input(), ahead of the menu (so Back is ignored), handing each to
## the InputDevices first, as the InputFeed would have. Outside a capture,
## Delete, Backspace or Y/△ clears the focused slot.
## The profile row (22.12) over the tabs picks the active profile (left and
## right, or a click), and its buttons rename it, add a new one ("Player N",
## made active) and delete it, Delete shown only with more than one and
## asking first ("Delete <name>? Press again"; moving away takes it back).
## Rename opens a name field (24 characters; an empty name keeps the old
## one) in place of the table: typed on the keyboard, Enter keeps it and Esc
## cancels; when a controller opened it, or once one is used, a LetterGrid
## shows under it, walked with the D-pad or stick, where A picks a key, B
## deletes a letter and Start is Done. Every change saves, and the table
## follows the active profile.
##
## The screen acts on a ControlProfiles saved to a path and an InputDevices:
## GameServices' by default, saved to the player's file
## (GameSettings.save_path_for_run, so a test run never writes it); tests hand
## it their own.

## A slot was chosen (keys, a controller or a click).
signal slot_chosen(tab: String, action: String, slot: int)
## A profile's bindings changed (and were saved).
signal profiles_changed

const TABS: Array[String] = [ControlProfile.KB, ControlProfile.PAD]
const TAB_NAMES: Array[String] = ["Keyboard & mouse", "Controller"]
## A slot button's least height (px); the theme's padding makes it about 50.
const SLOT_HEIGHT: float = 34.0
## How long a capture waits for a press before it gives up (ms).
const CAPTURE_TIMEOUT_MS: int = 5000
## A listening slot's text: the keyboard tab's, the controller tab's once it
## arms, and the controller tab's while a button is still held.
const LISTEN_KEY: String = "Press a key…"
const LISTEN_PAD: String = "Press a button…"
const LISTEN_RELEASE: String = "Let go of the buttons…"

var profiles: ControlProfiles
var save_path: String
var input: InputDevices
## ControlProfile.KB or PAD.
var tab: String = ControlProfile.KB
## The profile row and its buttons.
var profile_row: OptionRow
var rename_button: Button
var new_button: Button
var delete_button: Button
## The rename field and its letter grid, shown while renaming.
var rename_box: VBoxContainer
var name_edit: LineEdit
var letter_grid: LetterGrid
var renaming: bool = false
var tabs: OptionRow
var status: Label
var table: GridContainer
var scroll: ScrollContainer
## action -> [slot 0 button, slot 1 button]
var slot_buttons: Dictionary = {}
var reset_button: Button
var fight_stick_button: Button
## The row of Reset and Fight stick layout.
var table_actions: HBoxContainer
## The capture listening for a slot's input, or null.
var capture: RebindCapture = null
var capture_action: String = ""
var capture_slot: int = -1
## Returns the time in milliseconds (tests drive a fake clock).
var clock: Callable = Time.get_ticks_msec
## When the capture started or last saw a press.
var _capture_since: int = 0
## Delete was pressed once and asks to be pressed again.
var _delete_armed: bool = false
## Walks the letter grid with the D-pad or stick, with the menus' repeat.
var _grid_nav: MenuNav = MenuNav.new()


func _init(p_profiles: ControlProfiles = null, p_save_path: String = "", p_input: InputDevices = null) -> void:
	super()
	profiles = p_profiles if p_profiles != null else GameServices.profiles
	save_path = p_save_path if p_save_path != "" else GameSettings.save_path_for_run(ControlProfiles.PATH)
	input = p_input if p_input != null else GameServices.input
	add_label("Saved on this computer", UiTheme.EYEBROW, 15)
	add_heading("Controls")
	_build_profile_row()
	tabs = add_options("Device", TAB_NAMES, 0, _on_tab)
	status = add_label("", UiTheme.MUTED, 17)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(760.0, 0.0)
	_build_table()
	table_actions = HBoxContainer.new()
	table_actions.add_theme_constant_override("separation", 12)
	box.add_child(table_actions)
	reset_button = _action_button(table_actions, "Reset to defaults", _on_reset)
	fight_stick_button = _action_button(table_actions, "Fight stick layout", _on_fight_stick)
	input.state.joy_connection_changed.connect(_on_joy_connection_changed)
	slot_chosen.connect(start_capture)
	refresh()


func _build_table() -> void:
	scroll = ScrollContainer.new()
	scroll.name = "Table"
	scroll.custom_minimum_size = Vector2(760.0, 370.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	table = GridContainer.new()
	table.columns = 3
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("h_separation", 12)
	table.add_theme_constant_override("v_separation", 4)
	scroll.add_child(table)
	for r: ControlsTable.Row in ControlsTable.rows(profiles.active_profile(), ControlProfile.KB, PadStyle.GENERIC):
		var action: String = r.action
		var names: VBoxContainer = VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", 0)
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		var label: Label = UiTheme.label(r.label, &"", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		names.add_child(label)
		if r.hint != "":
			var hint: Label = UiTheme.label(r.hint, UiTheme.MUTED, 13)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			names.add_child(hint)
		table.add_child(names)
		var pair: Array[Button] = []
		for slot: int in Bindings.SLOTS:
			var b: Button = Button.new()
			b.name = "%s_%d" % [action, slot]
			b.custom_minimum_size = Vector2(200.0, SLOT_HEIGHT)
			b.add_theme_font_size_override(&"font_size", 18)
			b.clip_text = true
			b.tooltip_text = "%s binding %d" % [r.label, slot + 1]
			b.pressed.connect(func() -> void: slot_chosen.emit(tab, action, slot))
			table.add_child(b)
			add_item(b)
			pair.append(b)
		slot_buttons[action] = pair


func _action_button(row: HBoxContainer, text: String, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 48.0)
	b.pressed.connect(on_pressed)
	row.add_child(b)
	add_item(b)
	return b


## Opens on the tab of the last device used.
func open() -> void:
	tab = ControlsTable.opening_tab(input)
	refresh()
	super()


## Shows the active profile's bindings on the current tab, named in the
## button style of the connected controller, and the lines over the table.
func refresh() -> void:
	tabs.set_index(TABS.find(tab))
	var profile: ControlProfile = profiles.active_profile()
	var names: Array[String] = []
	names.assign(profiles.names())
	if _chip_names() != names:
		profile_row.set_options(names, profiles.active)
	profile_row.set_index(profiles.active)
	delete_button.visible = profiles.can_delete()
	var on_pad: bool = tab == ControlProfile.PAD
	status.text = ControlsTable.status_line(input) + "\n" + ControlsTable.PAD_NOTE if on_pad else ControlsTable.KB_NOTE
	var style: int = input.pad_style() if on_pad else PadStyle.GENERIC
	for r: ControlsTable.Row in ControlsTable.rows(profile, tab, style):
		var pair: Array[Button] = []
		pair.assign(slot_buttons[r.action])
		for slot: int in pair.size():
			pair[slot].text = r.slots[slot]
			pair[slot].remove_theme_color_override(&"font_color")
			pair[slot].remove_theme_color_override(&"font_focus_color")
	fight_stick_button.visible = on_pad
	if is_listening():
		_show_listening()


## Leaving the screen ends a capture and a rename.
func close() -> void:
	if capture != null:
		capture = null
		refresh()
	if renaming:
		_end_rename(false)
	super()


## The screen opens on the device tabs, under the profile row.
func first_item() -> Control:
	return tabs


# ------------------------------------------------------------------ capture

func is_listening() -> bool:
	return capture != null and capture.is_listening()


## Listens for the input to put in a slot (choosing a slot starts it).
func start_capture(p_tab: String, action: String, slot: int) -> void:
	if is_listening():
		return
	capture = RebindCapture.new(p_tab, input.state)
	capture_action = action
	capture_slot = slot
	_capture_since = clock.call()
	_show_listening()


func _show_listening() -> void:
	var text: String = LISTEN_KEY
	if capture.tab == ControlProfile.PAD:
		text = LISTEN_PAD if capture.is_armed() else LISTEN_RELEASE
	# lit gold while it listens, as the demo's .listening slot
	var b: Button = slot_buttons[capture_action][capture_slot]
	b.text = text
	b.add_theme_color_override(&"font_color", UiPalette.GOLD)
	b.add_theme_color_override(&"font_focus_color", UiPalette.GOLD)


## Runs before the menu and the GUI: a capture takes every event, and a
## focused slot takes the presses that clear it.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if capture != null:
		# a handled event never reaches the InputFeed, so feed it here
		input.note_event(event)
		get_viewport().set_input_as_handled()
		if _is_press(event):
			_capture_since = clock.call()
		capture.feed(event)
		_capture_moved()
		return
	if renaming:
		_rename_input(event)
		return
	var at: Vector2i = _slot_of(focused_item())
	if at.x >= 0 and _clears(event):
		input.note_event(event)
		get_viewport().set_input_as_handled()
		profiles.active_profile().clear_slot(tab, Bindings.ACTIONS[at.x], at.y)
		_save()


func _process(delta: float) -> void:
	super(delta)
	if renaming and is_visible_in_tree():
		var held: MenuNav.Cmd = _grid_nav.tick()
		if held != MenuNav.Cmd.NONE:
			letter_grid.move(held)
	if capture == null:
		return
	capture.poll()
	if int(clock.call()) - _capture_since >= CAPTURE_TIMEOUT_MS:
		capture.cancel()
	_capture_moved()


## Shows the capture's progress, or ends it once it has a result: the slot
## keeps the focus, and a binding or a clear is saved.
func _capture_moved() -> void:
	if capture.is_listening():
		_show_listening()
		return
	var done: RebindCapture = capture
	capture = null
	if done.apply_to(profiles.active_profile(), capture_action, capture_slot):
		_save()
	else:
		refresh()


## A key, mouse button or controller button going down.
static func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed()
	return false


## Delete, Backspace or Y/△: clears a focused slot outside a capture.
static func _clears(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k: InputEventKey = event
		var key: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return k.pressed and not k.echo and (key == KEY_DELETE or key == KEY_BACKSPACE)
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		return jb.pressed and jb.button_index == JOY_BUTTON_Y
	return false


## Up and down on the table keep to the slot's column, a row at a time (left
## and right step between the two slots); past the first row up goes to the
## tabs, past the last down to Reset.
func act(cmd: MenuNav.Cmd) -> void:
	var at: Vector2i = _slot_of(focused_item())
	if at.x < 0 or (cmd != MenuNav.Cmd.UP and cmd != MenuNav.Cmd.DOWN):
		super(cmd)
		return
	var row: int = at.x + (-1 if cmd == MenuNav.Cmd.UP else 1)
	if row < 0:
		tabs.grab_focus()
	elif row >= Bindings.ACTIONS.size():
		reset_button.grab_focus()
	else:
		(slot_buttons[Bindings.ACTIONS[row]][at.y] as Button).grab_focus()


## (row, slot) of a slot button, or (-1, -1).
func _slot_of(c: Control) -> Vector2i:
	if not (c is Button):
		return Vector2i(-1, -1)
	for row: int in Bindings.ACTIONS.size():
		var slot: int = (slot_buttons[Bindings.ACTIONS[row]] as Array).find(c)
		if slot >= 0:
			return Vector2i(row, slot)
	return Vector2i(-1, -1)


## A slot's button text, for tests and the capture (22.11).
func slot_text(action: String, slot: int) -> String:
	return (slot_buttons[action][slot] as Button).text


func _on_tab(index: int) -> void:
	tab = TABS[index]
	refresh()


func _on_reset() -> void:
	profiles.active_profile().reset_tab(tab)
	_save()


func _on_fight_stick() -> void:
	profiles.active_profile().use_fight_stick_layout()
	_save()


func _save() -> void:
	profiles.save(save_path)
	refresh()
	profiles_changed.emit()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	refresh()


# ------------------------------------------------------------------ profiles

## The profile row and its buttons on one line, and the rename field under
## them (hidden until Rename).
func _build_profile_row() -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Profiles"
	line.add_theme_constant_override("separation", 12)
	box.add_child(line)
	profile_row = OptionRow.new("Profile", [] as Array[String])
	profile_row.title.custom_minimum_size = Vector2(110.0, 0.0)
	profile_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.changed.connect(_on_pick)
	line.add_child(profile_row)
	add_item(profile_row)
	rename_button = _action_button(line, "Rename", _on_rename)
	new_button = _action_button(line, "New profile", _on_new)
	delete_button = _action_button(line, "Delete", _on_delete)
	delete_button.focus_exited.connect(_disarm_delete)
	rename_box = VBoxContainer.new()
	rename_box.name = "Rename"
	rename_box.visible = false
	rename_box.add_theme_constant_override("separation", 10)
	box.add_child(rename_box)
	name_edit = LineEdit.new()
	name_edit.max_length = ControlProfile.NAME_MAX
	name_edit.custom_minimum_size = Vector2(420.0, 48.0)
	name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_edit.placeholder_text = "Profile name"
	name_edit.text_submitted.connect(func(_text: String) -> void: _end_rename(true))
	rename_box.add_child(name_edit)
	letter_grid = LetterGrid.new()
	letter_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	letter_grid.typed.connect(_on_grid_typed)
	letter_grid.erased.connect(_on_grid_erased)
	letter_grid.done.connect(_end_rename.bind(true))
	rename_box.add_child(letter_grid)


func _chip_names() -> Array[String]:
	var out: Array[String] = []
	for chip: Button in profile_row.chips:
		out.append(chip.text)
	return out


func _on_pick(index: int) -> void:
	profiles.set_active(index)
	_save()


func _on_new() -> void:
	profiles.add_profile()
	_save()


## The first press asks; the second deletes the active profile, and the
## focus goes back to the row.
func _on_delete() -> void:
	if not _delete_armed:
		_delete_armed = true
		delete_button.text = "Delete %s? Press again" % profiles.active_profile().name
		return
	_disarm_delete()
	profiles.delete_profile(profiles.active)
	_save()
	profile_row.grab_focus()


func _disarm_delete() -> void:
	_delete_armed = false
	delete_button.text = "Delete"


## Opens the name field over the table (Rename again keeps the name): with
## the letter grid when a controller was the last device used.
func _on_rename() -> void:
	if renaming:
		_end_rename(true)
		return
	renaming = true
	_grid_nav.reset()
	name_edit.text = profiles.active_profile().name
	letter_grid.cursor = Vector2i.ZERO
	letter_grid.visible = input.last_used == InputDevices.LastUsed.PAD
	rename_box.visible = true
	_show_table(false)
	rename_button.text = "Keep name"
	name_edit.grab_focus()
	name_edit.caret_column = name_edit.text.length()


## Closes the name field, keeping the name (an empty one keeps the old) or
## not; the focus goes back to Rename.
func _end_rename(keep: bool) -> void:
	if not renaming:
		return
	renaming = false
	rename_box.visible = false
	_show_table(true)
	rename_button.text = "Rename"
	if keep:
		profiles.rename(profiles.active, name_edit.text)
		_save()
	if is_visible_in_tree():
		rename_button.grab_focus()


## While renaming: Esc cancels and up and down stay in the field; a
## controller walks the letter grid (showing it), A picks a key, B deletes a
## letter and Start is Done. Other keys type into the field.
func _rename_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event
		var key: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if k.pressed and not k.echo:
				_end_rename(false)
		elif key == KEY_UP or key == KEY_DOWN:
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	input.note_event(event)
	get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		if event.is_pressed():
			_end_rename(true)
		return
	var cmd: MenuNav.Cmd = _grid_nav.command(event)
	if cmd != MenuNav.Cmd.NONE:
		letter_grid.visible = true
	match cmd:
		MenuNav.Cmd.UP, MenuNav.Cmd.DOWN, MenuNav.Cmd.LEFT, MenuNav.Cmd.RIGHT:
			letter_grid.move(cmd)
		MenuNav.Cmd.OK:
			letter_grid.press()
		MenuNav.Cmd.BACK:
			_on_grid_erased()


func _on_grid_typed(text: String) -> void:
	if name_edit.text.length() < ControlProfile.NAME_MAX:
		name_edit.text += text
	name_edit.caret_column = name_edit.text.length()


func _on_grid_erased() -> void:
	name_edit.text = name_edit.text.left(-1)
	name_edit.caret_column = name_edit.text.length()


## The tabs, the status, the table and its buttons: hidden while renaming,
## so the name field and its letter grid stand alone under the profile row.
func _show_table(show: bool) -> void:
	tabs.visible = show
	status.visible = show
	scroll.visible = show
	table_actions.visible = show


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and input != null and input.state != null:
		if input.state.joy_connection_changed.is_connected(_on_joy_connection_changed):
			input.state.joy_connection_changed.disconnect(_on_joy_connection_changed)


## While renaming, no key the name field leaves (Backspace on an empty
## name, say) reaches the menu as Back or a move.
func _unhandled_input(event: InputEvent) -> void:
	if renaming and is_visible_in_tree():
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	super(event)
