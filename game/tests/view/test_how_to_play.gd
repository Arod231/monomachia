extends GutTest
## The How to play screen (22.14): the rules page and a move-list tab per
## weapon and bare hands, from MoveList; tabs and scrolling with keys only
## and with a controller only; Back returns to the page that opened it.

var opener: MenuScreen
var screen: HowToPlayScreen
var stack: ScreenStack


func before_each() -> void:
	Roster.full = false
	opener = MenuScreen.new()
	opener.add_button("How to play", "", func() -> void: pass)
	add_child_autofree(opener)
	screen = HowToPlayScreen.new()
	add_child_autofree(screen)
	stack = ScreenStack.new()
	stack.reset([opener] as Array[MenuPage])
	stack.push(screen)
	await _frames(2)


func after_each() -> void:
	Roster.reset()


## A screen made with the whole roster (--full-roster).
func _full_screen() -> HowToPlayScreen:
	Roster.full = true
	var s: HowToPlayScreen = HowToPlayScreen.new()
	add_child_autofree(s)
	return s


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		get_viewport().push_input(e)


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		get_viewport().push_input(e)


func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for c: Node in node.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	for c: Node in node.find_children("*", "RichTextLabel", true, false):
		out.append((c as RichTextLabel).get_parsed_text())
	return out


func test_it_opens_on_the_rules_with_the_tabs_focused() -> void:
	# milestone 1 (task 4): only the Katana's and bare hands' tabs
	assert_eq(screen.tabs.chips.map(func(b: Button) -> String: return b.text),
		["Rules", "Katana", "Bare hands"])
	assert_eq(screen.tab, 0)
	assert_eq(screen.focused_item(), screen.tabs)
	assert_true(screen.pages[0].visible)
	for i: int in range(1, screen.pages.size()):
		assert_false(screen.pages[i].visible, "page %d hidden" % i)
	var texts: Array[String] = _texts(screen.pages[0])
	for block: String in ["Win the duel", "Attack", "Defend", "Posture", "Unblockables", "Disarmed", "Ultimate", "Modes"]:
		assert_true(texts.any(func(t: String) -> bool: return t.begins_with(block)), "rule block %s" % block)


func test_the_flag_brings_every_weapon_s_tab_back() -> void:
	var full: HowToPlayScreen = _full_screen()
	assert_eq(full.tabs.chips.map(func(b: Button) -> String: return b.text),
		["Rules", "Katana", "Greatsword", "Daggers", "Bare hands"])
	assert_eq(full.tab_weapons, HowToPlayScreen.TAB_WEAPONS)


func test_the_rules_say_what_this_build_changed() -> void:
	var all: String = " ".join(_texts(screen.pages[0]))
	assert_string_contains(all, "First to %d rounds" % SimConst.ROUNDS_TO_WIN)
	assert_string_contains(all, "%d m across" % roundi(SimConst.ARENA_RADIUS * 2.0))
	assert_string_contains(all, "not guaranteed")
	assert_string_contains(all, "late in its recovery")


func test_each_weapon_tab_shows_its_move_list_rows() -> void:
	var full: HowToPlayScreen = _full_screen()
	for i: int in range(1, full.tab_weapons.size()):
		var w: WeaponDef = Moves.WEAPONS[full.tab_weapons[i]]
		var page: Control = full.pages[i]
		for r: MoveList.Row in MoveList.rows(w):
			var row: Control = page.find_child("Row_%s" % r.move_id, true, false)
			assert_not_null(row, "%s: a row for %s" % [w.id, r.move_id])
			if row == null:
				continue
			var texts: Array[String] = _texts(row)
			assert_has(texts, r.input, "%s input" % r.move_id)
			assert_has(texts, r.name, "%s name" % r.move_id)
			assert_has(texts, HowToPlayScreen.number(r.damage), "%s damage" % r.move_id)
			assert_has(texts, HowToPlayScreen.number(r.posture), "%s posture" % r.move_id)
			assert_has(texts, HowToPlayScreen.metres(r.reach), "%s reach" % r.move_id)


func test_unblockables_carry_a_danger_tag_naming_their_counter() -> void:
	var row: Control = screen.pages[1].find_child("Row_k_thrust", true, false)
	var tag: Label = row.find_child("Tag", true, false)
	assert_not_null(tag)
	assert_eq(tag.text, "unblockable · thrust")
	assert_eq(tag.theme_type_variation, UiTheme.TAG)
	assert_null(screen.pages[1].find_child("Row_k_l1", true, false).find_child("Tag", true, false))


func test_numbers_read_plainly() -> void:
	assert_eq(HowToPlayScreen.number(6.0), "6")
	assert_eq(HowToPlayScreen.number(7.5), "7.5")
	assert_eq(HowToPlayScreen.number(NAN), "—")
	assert_eq(HowToPlayScreen.metres(2.2), "2.2 m")
	assert_eq(HowToPlayScreen.metres(3.0), "3.0 m")
	assert_eq(HowToPlayScreen.metres(0.0), "—")
	assert_eq(HowToPlayScreen.metres(NAN), "—")


func test_an_ultimate_shows_its_hits() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.DAGGERS)
	assert_eq(HowToPlayScreen.hits_text(rows[-1]), "6 × 5 + 8 damage")
	var row: Control = _full_screen().pages[3].find_child("Row_tempest", true, false)
	assert_has(_texts(row), "6 × 5 + 8 damage")
	# one hit: its damage column says it all
	var moon: Control = screen.pages[1].find_child("Row_moonsplitter", true, false)
	assert_does_not_have(_texts(moon), "30 damage")


func _visible_page() -> int:
	for i: int in screen.pages.size():
		if screen.pages[i].visible:
			return i
	return -1


func test_left_and_right_on_the_tabs_switch_pages_with_keys() -> void:
	_key(KEY_RIGHT)
	assert_eq(screen.tab, 1)
	assert_eq(_visible_page(), 1)
	_key(KEY_LEFT)
	_key(KEY_LEFT)
	assert_eq(screen.tab, 2, "wraps round to bare hands")
	assert_eq(_visible_page(), 2)


func test_q_and_e_switch_pages_from_anywhere() -> void:
	screen.back_button.grab_focus()
	await _frames(1)
	_key(KEY_E)
	assert_eq(screen.tab, 1)
	_key(KEY_E)
	assert_eq(screen.tab, 2)
	_key(KEY_Q)
	assert_eq(screen.tab, 1)
	assert_eq(screen.focused_item(), screen.back_button, "the focus stays")


func test_the_shoulder_buttons_switch_pages() -> void:
	_pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(screen.tab, 1)
	_pad(JOY_BUTTON_LEFT_SHOULDER)
	_pad(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(screen.tab, 2)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(screen.tab, 0)


func _scrolls_down_to_back(down: Callable, up: Callable) -> void:
	screen.show_tab(1)
	await _frames(2)
	assert_eq(screen.scroll.scroll_vertical, 0)
	down.call()
	await _frames(1)
	assert_gt(screen.scroll.scroll_vertical, 0, "down scrolls the page")
	assert_eq(screen.focused_item(), screen.tabs, "the focus stays on the tabs")
	var last: int = -1
	for n: int in 200:
		if screen.focused_item() != screen.tabs:
			break
		last = screen.scroll.scroll_vertical
		down.call()
		await _frames(1)
	assert_eq(screen.focused_item(), screen.back_button, "at the bottom, down goes to Back")
	assert_gt(last, 0)
	up.call()
	await _frames(1)
	assert_eq(screen.focused_item(), screen.tabs, "up from Back returns to the tabs")
	up.call()
	await _frames(1)
	assert_lt(screen.scroll.scroll_vertical, last, "up scrolls back")


func test_scrolling_with_keys() -> void:
	await _scrolls_down_to_back(_key.bind(KEY_DOWN), _key.bind(KEY_UP))


func test_scrolling_with_a_controller() -> void:
	await _scrolls_down_to_back(_pad.bind(JOY_BUTTON_DPAD_DOWN), _pad.bind(JOY_BUTTON_DPAD_UP))


func test_a_new_tab_starts_at_the_top() -> void:
	screen.show_tab(1)
	await _frames(2)
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	await _frames(1)
	assert_gt(screen.scroll.scroll_vertical, 0)
	_key(KEY_RIGHT)
	await _frames(1)
	assert_eq(screen.scroll.scroll_vertical, 0)


func test_back_returns_to_the_opener_with_keys() -> void:
	_key(KEY_ESCAPE)
	assert_eq(stack.top(), opener)
	assert_false(screen.visible)


func test_back_returns_to_the_opener_with_a_controller() -> void:
	_pad(JOY_BUTTON_B)
	assert_eq(stack.top(), opener)


func test_the_back_button_returns_to_the_opener() -> void:
	screen.back_button.grab_focus()
	await _frames(1)
	_key(KEY_ENTER)
	assert_eq(stack.top(), opener)


func test_reopening_starts_on_the_rules() -> void:
	screen.show_tab(2)
	_key(KEY_ESCAPE)
	stack.push(screen)
	await _frames(1)
	assert_eq(screen.tab, 0)
	assert_eq(_visible_page(), 0)


func test_the_main_menu_opens_it_and_back_returns() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	var host: MatchHost = main.get_node("MatchHost")
	host.auto_run = false
	main.call("show_main_menu")
	await _frames(1)
	var menu: MenuScreen = main.get("main_menu")
	var entry: Button = null
	for b: Button in menu.buttons:
		if b.text == "How to play":
			entry = b
	assert_not_null(entry, "a How to play entry")
	entry.grab_focus()
	await _frames(1)
	_pad(JOY_BUTTON_A)
	var main_stack: ScreenStack = main.get("stack")
	assert_true(main_stack.top() is HowToPlayScreen)
	await _frames(1)
	_pad(JOY_BUTTON_B)
	assert_eq(main_stack.top(), menu)
