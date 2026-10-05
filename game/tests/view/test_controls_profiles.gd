extends GutTest
## The Controls screen's profile row (22.12): pick, rename (typed, or with the
## letter grid when a controller opened Rename), new and delete (pressed twice),
## each saved; Delete hidden with one profile; the table following the active
## profile. The screen saves to a test path and reads a fake device state.

const PATH: String = "user://test_controls_profiles.cfg"

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


func _key(key: Key, unicode: int = 0) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.unicode = unicode if down else 0
		e.pressed = down
		input.note_event(e)
		get_viewport().push_input(e)


func _type(text: String) -> void:
	for ch: String in text:
		var code: int = ch.unicode_at(0)
		var key: Key = OS.find_keycode_from_string(ch.to_upper()) if ch != " " else KEY_SPACE
		_key(key, code)


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		input.note_event(e)
		get_viewport().push_input(e)


func _chips() -> Array[String]:
	var out: Array[String] = []
	for b: Button in screen.profile_row.chips:
		out.append(b.text)
	return out


func _saved() -> ControlProfiles:
	return ControlProfiles.load_from(PATH)


## Two more profiles: Player 2 and Player 3, Player 3 active.
func _three_profiles() -> void:
	screen.new_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	await get_tree().process_frame


func test_the_row_names_the_profiles_and_hides_delete_with_one() -> void:
	assert_eq(_chips(), ["Player 1"])
	assert_eq(screen.profile_row.index, 0)
	assert_false(screen.delete_button.visible)
	assert_true(screen.rename_button.visible)
	assert_true(screen.new_button.visible)
	assert_eq(screen.focused_item(), screen.tabs, "it still opens on the device tabs")


func test_up_from_the_tabs_reaches_the_profile_row() -> void:
	_key(KEY_UP)
	assert_true([screen.rename_button, screen.new_button, screen.delete_button].has(screen.focused_item()))
	for i: int in 4:
		if screen.focused_item() == screen.profile_row:
			break
		_key(KEY_UP)
	assert_eq(screen.focused_item(), screen.profile_row)


func test_new_profile_is_made_active_and_saved() -> void:
	profiles.active_profile().bind(ControlProfile.KB, "light", 0, InputToken.key(KEY_H))
	screen.refresh()
	assert_eq(screen.slot_text("light", 0), "H")
	screen.new_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	assert_eq(_chips(), ["Player 1", "Player 2"])
	assert_eq(screen.profile_row.index, 1)
	assert_eq(profiles.active, 1)
	assert_eq(screen.slot_text("light", 0), "Left Click", "the table follows: Player 2 has the defaults")
	assert_true(screen.delete_button.visible)
	var saved: ControlProfiles = _saved()
	assert_eq(saved.names(), PackedStringArray(["Player 1", "Player 2"]))
	assert_eq(saved.active, 1)


func test_picking_a_profile_makes_it_active_and_saves() -> void:
	await _three_profiles()
	profiles.profiles[0].bind(ControlProfile.KB, "light", 0, InputToken.key(KEY_H))
	screen.profile_row.grab_focus()
	await get_tree().process_frame
	_key(KEY_RIGHT)
	assert_eq(profiles.active, 0, "wraps round from Player 3")
	assert_eq(screen.profile_row.index, 0)
	assert_eq(screen.slot_text("light", 0), "H", "the table follows the active profile")
	assert_eq(_saved().active, 0)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(profiles.active, 1)
	assert_eq(_saved().active, 1)


func test_renaming_with_the_keyboard() -> void:
	screen.rename_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	await get_tree().process_frame
	assert_true(screen.renaming)
	assert_true(screen.name_edit.is_visible_in_tree())
	assert_false(screen.letter_grid.is_visible_in_tree(), "no grid when the keyboard opened it")
	assert_true(screen.name_edit.has_focus())
	assert_eq(screen.name_edit.text, "Player 1")
	screen.name_edit.text = ""
	_type("Kenji")
	assert_eq(screen.name_edit.text, "Kenji")
	_key(KEY_ENTER)
	await get_tree().process_frame
	assert_false(screen.renaming)
	assert_eq(_chips(), ["Kenji"])
	assert_eq(_saved().names(), PackedStringArray(["Kenji"]))
	assert_eq(screen.focused_item(), screen.rename_button)


func test_esc_cancels_a_rename_without_leaving() -> void:
	stack.reset([MenuScreen.new(), screen] as Array[MenuPage])
	await get_tree().process_frame
	screen.rename_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	await get_tree().process_frame
	screen.name_edit.text = "Nobody"
	_key(KEY_UP)
	assert_true(screen.name_edit.has_focus(), "up and down don't leave the name")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert_false(screen.renaming)
	assert_eq(stack.top(), screen, "Esc closed the rename, not the screen")
	assert_eq(_chips(), ["Player 1"])
	assert_false(FileAccess.file_exists(PATH))
	(stack.pages[0] as Node).free()


func test_an_empty_name_keeps_the_old_one() -> void:
	screen.rename_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	await get_tree().process_frame
	screen.name_edit.text = "   "
	_key(KEY_ENTER)
	assert_eq(_chips(), ["Player 1"])


func test_a_controller_renames_with_the_letter_grid() -> void:
	screen.rename_button.grab_focus()
	await get_tree().process_frame
	_pad(JOY_BUTTON_A)
	await get_tree().process_frame
	assert_true(screen.renaming)
	assert_true(screen.letter_grid.is_visible_in_tree(), "a controller opened it: the grid shows")
	var grid: LetterGrid = screen.letter_grid
	assert_eq(grid.cursor, Vector2i.ZERO)
	# erase "Player 1" back to "P"
	for i: int in 7:
		_pad(JOY_BUTTON_B)
	assert_eq(screen.name_edit.text, "P")
	# Shift, then i: down 0 rows to row 0, right to I (column 8)
	grid.cursor = Vector2i(LetterGrid.ROWS.size(), 1)
	_pad(JOY_BUTTON_A)
	assert_true(grid.shift)
	grid.cursor = Vector2i(0, 0)
	for i: int in 8:
		_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(grid.cursor, Vector2i(0, 8))
	_pad(JOY_BUTTON_A)
	assert_eq(screen.name_edit.text, "Pi")
	_pad(JOY_BUTTON_START)
	await get_tree().process_frame
	assert_false(screen.renaming)
	assert_eq(_chips(), ["Pi"])
	assert_eq(_saved().names(), PackedStringArray(["Pi"]))


func test_the_letter_grid_moves_and_wraps() -> void:
	var grid: LetterGrid = screen.letter_grid
	grid.cursor = Vector2i(0, 0)
	grid.move(MenuNav.Cmd.LEFT)
	assert_eq(grid.cursor, Vector2i(0, LetterGrid.ROWS[0].length() - 1), "left wraps round the row")
	grid.move(MenuNav.Cmd.UP)
	assert_eq(grid.cursor, Vector2i(LetterGrid.ROWS.size(), LetterGrid.SPECIALS.size() - 1), "up from the top wraps to the specials, on a key")
	grid.move(MenuNav.Cmd.DOWN)
	assert_eq(grid.cursor.x, 0, "down from the specials wraps to the top")
	grid.cursor = Vector2i(LetterGrid.ROWS.size() - 2, LetterGrid.ROWS[0].length() - 1)
	grid.move(MenuNav.Cmd.DOWN)
	assert_eq(grid.cursor, Vector2i(LetterGrid.ROWS.size() - 1, LetterGrid.ROWS[-1].length() - 1), "a short row keeps the cursor on a key")
	assert_eq(grid.key_text(Vector2i(0, 0)), "A")
	assert_eq(grid.key_text(Vector2i(LetterGrid.ROWS.size(), 0)), LetterGrid.SPACE)


func test_the_grid_shows_once_a_controller_is_used_while_typing() -> void:
	screen.rename_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	await get_tree().process_frame
	assert_false(screen.letter_grid.is_visible_in_tree())
	_pad(JOY_BUTTON_DPAD_DOWN)
	assert_true(screen.letter_grid.is_visible_in_tree())


func test_names_stop_at_24_characters() -> void:
	screen.rename_button.grab_focus()
	await get_tree().process_frame
	_pad(JOY_BUTTON_A)
	await get_tree().process_frame
	for i: int in 30:
		_pad(JOY_BUTTON_A)
	assert_eq(screen.name_edit.text.length(), ControlProfile.NAME_MAX)


func test_delete_asks_first_then_deletes_and_saves() -> void:
	await _three_profiles()
	screen.delete_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	assert_eq(profiles.profiles.size(), 3, "the first press only asks")
	assert_eq(screen.delete_button.text, "Delete Player 3? Press again")
	_key(KEY_ENTER)
	assert_eq(profiles.profiles.size(), 2)
	assert_eq(_chips(), ["Player 1", "Player 2"])
	assert_eq(_saved().names(), PackedStringArray(["Player 1", "Player 2"]))
	assert_eq(screen.delete_button.text, "Delete")


func test_moving_away_takes_back_the_delete_question() -> void:
	await _three_profiles()
	screen.delete_button.grab_focus()
	await get_tree().process_frame
	_pad(JOY_BUTTON_A)
	_pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(screen.delete_button.text, "Delete")
	screen.delete_button.grab_focus()
	await get_tree().process_frame
	_pad(JOY_BUTTON_A)
	assert_eq(profiles.profiles.size(), 3, "asked again, not deleted")


func test_deleting_down_to_one_hides_delete() -> void:
	screen.new_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	screen.delete_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	assert_eq(_chips(), ["Player 1"])
	assert_false(screen.delete_button.visible)
	assert_eq(screen.focused_item(), screen.profile_row, "the focus goes back to the row")


func test_backspace_on_an_empty_name_stays_in_the_rename() -> void:
	var opener: MenuScreen = MenuScreen.new()
	add_child_autofree(opener)
	stack.reset([opener, screen] as Array[MenuPage])
	await get_tree().process_frame
	screen.rename_button.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER)
	await get_tree().process_frame
	screen.name_edit.text = ""
	_key(KEY_BACKSPACE)
	_key(KEY_BACKSPACE)
	assert_true(screen.renaming)
	assert_eq(stack.top(), screen)
