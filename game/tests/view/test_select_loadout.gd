extends GutTest
## The loadout panel in the fighter select (task 22.6): each side's weapon
## and block abilities picked in the select's left column with keys and with
## a controller, the picks carried into the locked-in match; Random for the
## Duel opponent, and no abilities for the training dummy.

var select: FighterSelect
var locked: Array[MatchSelection.Draft] = []


func before_each() -> void:
	locked.clear()
	select = FighterSelect.new()
	add_child_autofree(select)
	select.locked_in.connect(func(d: MatchSelection.Draft) -> void: locked.append(d))


func _open(mode: StringName) -> void:
	select.start(MatchSelection.default_draft(mode))
	select.open()
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


func _down_to(item: Control, step: Callable) -> void:
	for _i: int in 10:
		if select.focused_item() == item:
			return
		step.call()
	assert_eq(select.focused_item(), item, "reached %s" % item.name)


func _panel() -> LoadoutPanel:
	return select.loadout_panel


func test_the_panel_sits_in_the_left_column_and_follows_the_side() -> void:
	await _open(MatchConfig.DUEL)
	assert_true(select.loadout.is_ancestor_of(_panel()))
	assert_eq(_panel().draft, select.draft, "it edits the select's own draft")
	assert_eq(_panel().cards.choice, &"katana")
	select.show_side(1)
	assert_eq(_panel().side_index, 1)
	assert_eq(_panel().cards.choice, &"greatsword", "the opponent's weapon")
	assert_true(_panel().cards.card_of(WeaponCardRow.RANDOM).visible, "the Duel opponent may be random")
	select.show_side(0)
	assert_false(_panel().cards.card_of(WeaponCardRow.RANDOM).visible)


func test_the_focus_runs_grid_then_loadout_then_the_rows() -> void:
	await _open(MatchConfig.WATCH)
	var order: Array[Control] = [select.grid, _panel().cards, _panel().slots[0], _panel().slots[1], select.skill_row]
	for item: Control in order:
		assert_eq(select.focused_item(), item, "at %s" % item.name)
		_key(KEY_DOWN)


func test_keys_pick_a_loadout_that_reaches_the_match() -> void:
	await _open(MatchConfig.DUEL)
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	assert_eq(select.draft.sides[0].weapon_id, &"greatsword")
	assert_eq(select.draft.sides[0].resolved_abilities(), [&"g_sweep", &"g_slam"] as Array[StringName], "a card resets the abilities")
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	assert_eq(select.draft.sides[0].resolved_abilities(), [&"g_crush", &"g_sweep"] as Array[StringName], "Slam swapped Sweep down, then Crush")
	_key(KEY_DOWN)
	_key(KEY_LEFT)
	assert_eq(select.draft.sides[0].resolved_abilities(), [&"g_sweep", &"g_crush"] as Array[StringName], "picking the other slot's swaps")
	_down_to(select.confirm, _key.bind(KEY_DOWN))
	_key(KEY_ENTER)
	await get_tree().process_frame
	_down_to(select.confirm, _key.bind(KEY_DOWN))
	_key(KEY_ENTER)
	assert_eq(locked.size(), 1)
	var cfg: MatchConfig = MatchSelection.lock_in(locked[0], 4)
	assert_eq(cfg.sides[0].weapon_id, &"greatsword")
	assert_eq(cfg.sides[0].resolved_abilities(), [&"g_sweep", &"g_crush"] as Array[StringName])
	assert_eq(cfg.problem(), "")


func test_a_controller_picks_the_opponents_loadout() -> void:
	await _open(MatchConfig.DUEL)
	_down_to(select.confirm, _pad.bind(JOY_BUTTON_DPAD_DOWN))
	_pad(JOY_BUTTON_A)
	await get_tree().process_frame
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(select.draft.sides[1].weapon_id, &"daggers")
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(select.draft.sides[1].resolved_abilities(), [&"d_sweep", &"d_needle"] as Array[StringName])
	_down_to(select.confirm, _pad.bind(JOY_BUTTON_DPAD_DOWN))
	_pad(JOY_BUTTON_A)
	assert_eq(locked.size(), 1)
	assert_eq(locked[0].sides[1].weapon_id, &"daggers")


func test_random_for_the_duel_opponent_hides_the_blurb_and_picks_at_lock_in() -> void:
	await _open(MatchConfig.DUEL)
	select.show_side(1)
	await get_tree().process_frame
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	assert_eq(_panel().cards.choice, WeaponCardRow.RANDOM)
	assert_true(select.draft.random_weapon[1])
	assert_false(_panel().blurb.visible)
	assert_false(_panel().slots[0].visible)
	_key(KEY_DOWN)
	assert_eq(select.focused_item(), select.skill_row, "the hidden slots are skipped")
	_down_to(select.confirm, _key.bind(KEY_DOWN))
	_key(KEY_ENTER)
	var picked: Dictionary = {}
	for s: int in 40:
		picked[MatchSelection.lock_in(locked[0], s).sides[1].weapon_id] = true
	assert_eq(picked.size(), Moves.PLAYABLE_WEAPONS.size(), "seeds pick every weapon")


func test_the_training_dummy_picks_a_weapon_but_no_abilities() -> void:
	await _open(MatchConfig.TRAINING)
	assert_true(_panel().slots[0].visible, "you pick yours")
	select.show_side(1)
	await get_tree().process_frame
	assert_false(_panel().slots[0].visible)
	assert_false(_panel().slots[1].visible)
	assert_false(_panel().cards.card_of(WeaponCardRow.RANDOM).visible)
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	assert_eq(select.draft.sides[1].weapon_id, &"daggers")
	_key(KEY_DOWN)
	assert_ne(select.focused_item(), _panel().slots[0])


func test_leaving_without_locking_in_changes_nothing() -> void:
	var d: MatchSelection.Draft = MatchSelection.default_draft(MatchConfig.DUEL)
	select.start(d)
	select.open()
	await get_tree().process_frame
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	assert_eq(select.draft.sides[0].weapon_id, &"greatsword")
	assert_eq(d.sides[0].weapon_id, &"katana", "the opened draft is untouched")
