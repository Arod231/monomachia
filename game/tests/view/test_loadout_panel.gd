extends GutTest
## The fighter select's loadout panel (task 22.6), on a page of its own: the
## weapon cards with their kanji, class and stat bars, Random for the Duel
## opponent, the blurb and ultimate, and the two ability slots with their
## descriptions; picks reported for the select to apply, walked with keys and
## with a controller.

var page: MenuScreen
var panel: LoadoutPanel
var side: MatchSide
var picks: Array = []


func before_each() -> void:
	picks.clear()
	page = MenuScreen.new()
	add_child_autofree(page)
	panel = LoadoutPanel.new()
	page.box.add_child(panel)
	for c: Control in panel.items():
		page.add_item(c)
	panel.weapon_chosen.connect(func(id: StringName) -> void: picks.append(["weapon", id]))
	panel.random_chosen.connect(func() -> void: picks.append(["random"]))
	panel.ability_chosen.connect(func(slot: int, id: StringName) -> void: picks.append(["ability", slot, id]))
	side = MatchSide.human(&"rogue", &"katana")
	panel.show_side(side)
	page.open()
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


func _card_texts(id: StringName) -> Array[String]:
	var out: Array[String] = []
	for l: Node in panel.cards.card_of(id).find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func test_one_card_per_playable_weapon_with_kanji_class_name_and_stat_bars() -> void:
	assert_eq(panel.cards.choices, Moves.PLAYABLE_WEAPONS)
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		var info: MenuData.WeaponInfo = MenuData.weapon(id)
		var texts: Array[String] = _card_texts(id)
		assert_has(texts, "%s · %s" % [info.kanji, info.weapon_class], String(id))
		assert_has(texts, Moves.WEAPONS[id].name, String(id))
		for stat: StringName in MenuData.STATS:
			assert_has(texts, MenuData.STAT_LABELS[stat], "%s %s caption" % [id, stat])
			var bar: StatBar = panel.cards.card_of(id).find_child("Stat_%s" % stat, true, false)
			assert_eq(bar.value, info.stats[stat], "%s %s bar" % [id, stat])


func test_the_sides_weapon_is_lit_with_its_blurb_and_ultimate() -> void:
	assert_eq(panel.cards.choice, &"katana")
	assert_eq(panel.cards.card_of(&"katana").theme_type_variation, UiTheme.OPTION_ON)
	assert_eq(panel.cards.card_of(&"daggers").theme_type_variation, UiTheme.OPTION)
	assert_eq(panel.blurb.text, Moves.WEAPONS[&"katana"].blurb)
	assert_eq(panel.ultimate_name.text, "Ultimate · Moonsplitter")
	assert_eq(panel.ultimate_desc.text, MenuData.weapon(&"katana").ultimate_desc)


func test_the_slots_offer_the_weapons_three_abilities_with_the_chosen_ones_described() -> void:
	for slot: int in 2:
		var row: OptionRow = panel.slots[slot]
		assert_eq(row.title.text, MenuData.SLOT_BADGES[slot])
		assert_eq(row.chips.map(func(c: Button) -> String: return c.text), ["Flash", "Piercing Thrust", "Swallow Sweep"])
	assert_eq([panel.slots[0].index, panel.slots[1].index], [0, 1], "the defaults: Flash and Piercing Thrust")
	assert_eq(panel.slot_descs[0].text, MenuData.ability_desc(&"k_flash"))
	assert_eq(panel.slot_descs[1].text, MenuData.ability_desc(&"k_thrust"))


func test_showing_another_weapon_and_loadout_follows_it() -> void:
	side.weapon_id = &"greatsword"
	side.abilities = [&"g_crush", &"g_sweep"] as Array[StringName]
	panel.show_side(side)
	assert_eq(panel.cards.choice, &"greatsword")
	assert_eq(panel.ultimate_name.text, "Ultimate · Impaler")
	assert_eq(panel.slots[0].chips.map(func(c: Button) -> String: return c.text), ["Reaping Sweep", "Mountain Slam", "Guard Crusher"])
	assert_eq([panel.slots[0].index, panel.slots[1].index], [2, 0])
	assert_eq(panel.slot_descs[0].text, MenuData.ability_desc(&"g_crush"))


func test_keys_pick_weapons_and_abilities() -> void:
	assert_eq(page.focused_item(), panel.cards, "the cards come first")
	_key(KEY_RIGHT)
	assert_eq(picks, [["weapon", &"greatsword"]])
	_key(KEY_LEFT)
	_key(KEY_LEFT)
	assert_eq(picks.back(), ["weapon", &"daggers"], "wraps round")
	_key(KEY_DOWN)
	assert_eq(page.focused_item(), panel.slots[0])
	_key(KEY_RIGHT)
	assert_eq(picks.back(), ["ability", 0, &"k_thrust"])
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	assert_eq(picks.back(), ["ability", 1, &"k_sweep"], "OK steps on")


func test_a_controller_picks_weapons_and_abilities() -> void:
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(picks, [["weapon", &"greatsword"]])
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(picks.back(), ["ability", 1, &"k_flash"])


func test_clicking_a_card_picks_it() -> void:
	panel.cards.card_of(&"daggers").pressed.emit()
	assert_eq(picks, [["weapon", &"daggers"]])
	assert_eq(page.focused_item(), panel.cards)
	panel.cards.card_of(&"daggers").pressed.emit()
	assert_eq(picks.size(), 1, "the lit card again picks nothing")


func test_random_is_offered_only_when_asked_and_hides_the_rest() -> void:
	assert_false(panel.cards.card_of(WeaponCardRow.RANDOM).visible)
	panel.show_side(side, false, true)
	assert_true(panel.cards.card_of(WeaponCardRow.RANDOM).visible)
	assert_eq(panel.cards.choices.back(), WeaponCardRow.RANDOM)
	panel.cards.grab_focus()
	_key(KEY_LEFT)
	assert_eq(picks, [["random"]], "left from the first card wraps to Random")
	panel.show_side(side, true, true)
	assert_eq(panel.cards.choice, WeaponCardRow.RANDOM)
	for c: Control in [panel.blurb, panel.ultimate_name, panel.ultimate_desc, panel.abilities_title, panel.slots[0], panel.slots[1]]:
		assert_false(c.visible, "%s hidden under Random" % c.name)
	_key(KEY_DOWN)
	assert_eq(page.focused_item(), panel.cards, "the hidden slots are skipped")


func test_random_is_ignored_where_it_isnt_offered() -> void:
	panel.show_side(side, true, false)
	assert_eq(panel.cards.choice, &"katana")
	assert_true(panel.blurb.visible)


func test_the_training_dummy_gets_no_ability_slots() -> void:
	panel.show_side(side, false, false, false)
	assert_true(panel.blurb.visible, "the blurb still shows")
	for c: Control in [panel.abilities_title, panel.slots[0], panel.slots[1], panel.slot_descs[0], panel.slot_descs[1]]:
		assert_false(c.visible, "%s hidden for the dummy" % c.name)


# ------------------------------------------------------------------ editing a draft

func _edit(mode: StringName, side_index: int) -> MatchSelection.Draft:
	var d: MatchSelection.Draft = MatchSelection.default_draft(mode)
	panel.edit(d, side_index)
	panel.cards.grab_focus()
	return d


func test_a_card_changes_the_weapon_and_resets_its_abilities() -> void:
	var d: MatchSelection.Draft = _edit(MatchConfig.DUEL, 0)
	MatchSelection.set_ability(d, 0, 0, &"k_sweep")
	panel.edit(d, 0)
	watch_signals(panel)
	_key(KEY_RIGHT)
	assert_eq(d.sides[0].weapon_id, &"greatsword")
	assert_eq(d.sides[0].resolved_abilities(), [&"g_sweep", &"g_slam"] as Array[StringName], "the greatsword's pair")
	assert_signal_emit_count(panel, "changed", 1)
	assert_eq(panel.ultimate_name.text, "Ultimate · Impaler", "shown again")
	_key(KEY_LEFT)
	assert_eq(d.sides[0].resolved_abilities(), [&"k_flash", &"k_thrust"] as Array[StringName], "back to the katana's pair, not the old picks")


func test_picking_the_other_slots_ability_swaps_them_through_the_panel() -> void:
	var d: MatchSelection.Draft = _edit(MatchConfig.DUEL, 0)
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	assert_eq(d.sides[0].resolved_abilities(), [&"k_thrust", &"k_flash"] as Array[StringName], "Thrust into slot 1 swaps Flash down")
	assert_eq([panel.slots[0].index, panel.slots[1].index], [1, 0], "both rows show the swap")
	assert_eq(panel.slot_descs[1].text, MenuData.ability_desc(&"k_flash"))
	_key(KEY_DOWN)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(d.sides[0].resolved_abilities(), [&"k_flash", &"k_sweep"] as Array[StringName], "a controller picks too: Thrust swaps back, then Sweep")


func test_the_duel_opponent_can_leave_the_weapon_to_chance() -> void:
	var d: MatchSelection.Draft = _edit(MatchConfig.DUEL, 1)
	assert_true(panel.cards.card_of(WeaponCardRow.RANDOM).visible)
	_key(KEY_LEFT)
	_key(KEY_LEFT)
	assert_eq(panel.cards.choice, WeaponCardRow.RANDOM, "left of the katana, round to Random")
	assert_true(d.random_weapon[1])
	assert_false(panel.blurb.visible, "Random hides the blurb")
	_key(KEY_RIGHT)
	assert_false(d.random_weapon[1], "a weapon card ends it")
	assert_eq(d.sides[1].weapon_id, &"katana")
	assert_true(panel.blurb.visible)


func test_only_the_duel_opponent_is_offered_random() -> void:
	for mode: StringName in MatchConfig.MODES:
		for i: int in 2:
			_edit(mode, i)
			assert_eq(panel.cards.card_of(WeaponCardRow.RANDOM).visible, mode == MatchConfig.DUEL and i == 1, "%s side %d" % [mode, i])


func test_the_training_dummy_side_has_no_ability_slots() -> void:
	_edit(MatchConfig.TRAINING, 1)
	assert_false(panel.slots[0].visible)
	assert_false(panel.abilities_title.visible)
	_edit(MatchConfig.TRAINING, 0)
	assert_true(panel.slots[0].visible, "the player in Training picks")
	_edit(MatchConfig.WATCH, 1)
	assert_true(panel.slots[1].visible, "a computer fighter picks")
