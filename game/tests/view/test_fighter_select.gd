extends GutTest
## FighterSelect (22.5): the sides picked one after the other, the skill and
## arena rows, Back stepping between the sides, and lock in, walked with keys
## and a controller.

var select: FighterSelect
var locked: Array[MatchSelection.Draft] = []
var backs: int = 0


func _open(mode: StringName) -> MatchSelection.Draft:
	var d: MatchSelection.Draft = DemoDraft.of(mode)
	select.start(d)
	select.open()
	await get_tree().process_frame
	return d


func before_each() -> void:
	# the select's mechanics, walked with the whole roster (DemoDraft)
	Roster.full = true
	locked.clear()
	backs = 0
	select = FighterSelect.new()
	add_child_autofree(select)
	select.locked_in.connect(func(d: MatchSelection.Draft) -> void: locked.append(d))
	select.back_requested.connect(func() -> void: backs += 1)


func after_each() -> void:
	Roster.reset()


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


func _focused() -> Control:
	return select.focused_item()


## Moves the focus down to an item with the key or button given.
func _down_to(item: Control, step: Callable) -> void:
	for _i: int in 8:
		if _focused() == item:
			return
		step.call()
	assert_eq(_focused(), item, "reached %s" % item.name)


func test_a_duel_starts_on_your_side_with_the_grid_focused() -> void:
	await _open(MatchConfig.DUEL)
	assert_eq(select.side, 0)
	assert_eq(select.side_title.text, "You")
	assert_eq(select.mode_line.text, "Duel · first to 3 rounds")
	assert_eq(_focused(), select.grid)
	assert_eq(select.fighter_ids[select.grid.index], &"rogue")
	assert_false(select.skill_row.visible, "you are not a computer")
	assert_false(select.arena_row.visible, "the arena comes with the last side")
	assert_eq(select.confirm.text, "Next: Opponent")
	assert_eq(select.loadout_panel.cards.choice, &"katana")


func test_the_opponent_s_side_has_the_skill_and_arena_rows_and_lock_in() -> void:
	await _open(MatchConfig.DUEL)
	select.show_side(1)
	assert_eq(select.side_title.text, "Opponent")
	assert_true(select.skill_row.visible)
	assert_eq(select.skill_row.index, 1, "Normal")
	assert_true(select.arena_row.visible)
	assert_eq(select.arena_row.chips[0].text, "Moonlit Shrine")
	assert_eq(select.arena_row.chips[-1].text, "Random")
	assert_eq(select.confirm.text, "Lock in")
	assert_eq(select.fighter_ids[select.grid.index], &"hunter")


func test_walking_a_duel_with_keys_locks_in_the_picks() -> void:
	var original: MatchSelection.Draft = await _open(MatchConfig.DUEL)
	_key(KEY_RIGHT)
	assert_eq(select.draft.sides[0].fighter_id, &"hunter", "the grid picks as it moves")
	_down_to(select.confirm, _key.bind(KEY_DOWN))
	_key(KEY_ENTER)
	assert_eq(select.side, 1)
	await get_tree().process_frame
	assert_eq(_focused(), select.grid, "the next side starts on its grid")
	_key(KEY_LEFT)
	_down_to(select.skill_row, _key.bind(KEY_DOWN))
	_key(KEY_RIGHT)
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	_down_to(select.confirm, _key.bind(KEY_DOWN))
	_key(KEY_ENTER)
	assert_eq(locked.size(), 1)
	var d: MatchSelection.Draft = locked[0]
	assert_eq([d.sides[0].fighter_id, d.sides[1].fighter_id], [&"hunter", &"rogue"])
	assert_eq(d.sides[1].difficulty, &"hard")
	assert_eq(d.arena, MatchSelection.RANDOM)
	assert_eq(original.sides[0].fighter_id, &"rogue", "the draft it opened on is untouched")
	var cfg: MatchConfig = MatchSelection.lock_in(d, 3)
	assert_eq(cfg.problem(), "")
	assert_eq(cfg.sides[1].controller, MatchSide.COMPUTER)


func test_walking_a_watch_with_a_controller() -> void:
	await _open(MatchConfig.WATCH)
	assert_eq(select.side_title.text, "Red fighter")
	assert_true(select.skill_row.visible, "both sides are computers")
	_down_to(select.skill_row, _pad.bind(JOY_BUTTON_DPAD_DOWN))
	_pad(JOY_BUTTON_DPAD_LEFT)
	_down_to(select.confirm, _pad.bind(JOY_BUTTON_DPAD_DOWN))
	_pad(JOY_BUTTON_A)
	assert_eq(select.side_title.text, "Blue fighter")
	await get_tree().process_frame
	_down_to(select.confirm, _pad.bind(JOY_BUTTON_DPAD_DOWN))
	_pad(JOY_BUTTON_A)
	assert_eq(locked.size(), 1)
	assert_eq([locked[0].sides[0].difficulty, locked[0].sides[1].difficulty], [&"easy", &"normal"])


func test_back_steps_between_the_sides_then_leaves() -> void:
	await _open(MatchConfig.DUEL)
	select.show_side(1)
	_key(KEY_LEFT)
	assert_eq(select.draft.sides[1].fighter_id, &"rogue")
	_pad(JOY_BUTTON_B)
	assert_eq(select.side, 0, "B steps back a side")
	assert_eq(backs, 0)
	select.show_side(1)
	assert_eq(select.fighter_ids[select.grid.index], &"rogue", "the opponent's pick is kept")
	_key(KEY_ESCAPE)
	assert_eq(select.side, 0)
	_key(KEY_BACKSPACE)
	assert_eq(backs, 1, "from the first side Back leaves")
	assert_eq(locked.size(), 0)


func test_the_back_entry_does_the_same() -> void:
	await _open(MatchConfig.DUEL)
	select.show_side(1)
	select.back_entry.pressed.emit()
	assert_eq(select.side, 0)
	select.back_entry.pressed.emit()
	assert_eq(backs, 1)


func test_titles_per_mode() -> void:
	var expect: Dictionary = {
		MatchConfig.DUEL: ["You", "Opponent"],
		MatchConfig.TRAINING: ["You", "Training dummy"],
		MatchConfig.WATCH: ["Red fighter", "Blue fighter"],
		MatchConfig.VERSUS: ["Player 1", "Player 2"],
	}
	for mode: StringName in expect:
		await _open(mode)
		var got: Array[String] = [select.side_title.text]
		select.show_side(1)
		got.append(select.side_title.text)
		assert_eq(got, expect[mode] as Array[String], String(mode))


func test_only_computer_sides_have_a_skill_row() -> void:
	var expect: Dictionary = {
		MatchConfig.DUEL: [false, true],
		MatchConfig.TRAINING: [false, false],
		MatchConfig.WATCH: [true, true],
		MatchConfig.VERSUS: [false, false],
	}
	for mode: StringName in expect:
		await _open(mode)
		var got: Array[bool] = [select.skill_row.visible]
		select.show_side(1)
		got.append(select.skill_row.visible)
		assert_eq(got, expect[mode] as Array[bool], String(mode))


func test_the_picks_it_opens_on_show() -> void:
	var d: MatchSelection.Draft = DemoDraft.of(MatchConfig.DUEL)
	MatchSelection.set_fighter(d, 0, &"hunter")
	MatchSelection.set_weapon(d, 0, &"daggers")
	MatchSelection.set_difficulty(d, 1, &"easy")
	MatchSelection.set_arena(d, MatchSelection.RANDOM)
	select.start(d)
	assert_eq(select.fighter_ids[select.grid.index], &"hunter")
	assert_eq(select.loadout_panel.cards.choice, &"daggers")
	select.show_side(1)
	assert_eq(select.skill_row.index, 0)
	assert_eq(select.arena_row.index, select.arena_row.chips.size() - 1)


func test_a_random_opponent_weapon_reads_random() -> void:
	var d: MatchSelection.Draft = DemoDraft.of(MatchConfig.DUEL)
	MatchSelection.set_random_weapon(d, 1, true)
	select.start(d)
	select.show_side(1)
	assert_eq(select.loadout_panel.cards.choice, WeaponCardRow.RANDOM)


func test_the_preview_side_names_the_fighter() -> void:
	await _open(MatchConfig.DUEL)
	assert_eq(select.preview_name.text, "Rogue")
	_key(KEY_RIGHT)
	assert_eq(select.preview_name.text, "Hunter")


func test_the_select_is_set_in_the_theme() -> void:
	await _open(MatchConfig.DUEL)
	for c: Node in select.find_children("*", "Control", true, false):
		assert_false((c as Control).has_theme_font_override(&"font"), "%s sets its own font" % c.name)
	assert_eq(select.grid.chips[0].theme_type_variation, UiTheme.CARD_ON)
	assert_eq(select.grid.chips[1].theme_type_variation, UiTheme.CARD)


# ------------------------------------------------------------------ milestone 1's roster

## A select made with the milestone's roster (no --full-roster).
func _milestone_select(mode: StringName) -> FighterSelect:
	Roster.full = false
	var s: FighterSelect = FighterSelect.new()
	add_child_autofree(s)
	s.start(MatchSelection.default_draft(mode))
	s.open()
	await get_tree().process_frame
	return s


func test_without_the_flag_the_grid_has_one_hunter_card() -> void:
	var s: FighterSelect = await _milestone_select(MatchConfig.DUEL)
	assert_eq(s.fighter_ids, [&"hunter"] as Array[StringName])
	assert_eq(s.grid.chips.size(), 1)
	assert_eq(s.preview_name.text, "Hunter")


func test_without_the_flag_there_is_one_katana_card_and_no_random() -> void:
	var s: FighterSelect = await _milestone_select(MatchConfig.DUEL)
	s.show_side(1)
	await get_tree().process_frame
	var cards: WeaponCardRow = s.loadout_panel.cards
	assert_eq(cards.choices, [&"katana"] as Array[StringName], "the Duel opponent gets no Random")
	assert_eq(cards.cards.filter(func(c: Button) -> bool: return c.visible).size(), 1)
	assert_eq(cards.choice, &"katana")
