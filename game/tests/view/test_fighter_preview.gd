extends GutTest
## The fighter select's 3D preview (task 22.7): a SubViewport with its own
## world showing the side's fighter in its palette with its weapon, playing
## the match's combat idle and slowly turning; a Random weapon cycles the
## three; swapping leaves no nodes behind.

var select: FighterSelect


func before_each() -> void:
	FrozenStateClips.install()
	select = FighterSelect.new()
	add_child_autofree(select)


func after_each() -> void:
	FrozenStateClips.restore()


func _open(mode: StringName) -> MatchSelection.Draft:
	var d: MatchSelection.Draft = MatchSelection.default_draft(mode)
	select.start(d)
	select.open()
	await get_tree().process_frame
	return d


func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		get_viewport().push_input(e)


func _preview() -> FighterPreview:
	return select.preview


func test_the_preview_stands_on_the_right_in_its_own_world() -> void:
	await _open(MatchConfig.DUEL)
	var p: FighterPreview = _preview()
	assert_not_null(p)
	assert_true(select.preview_slot.is_ancestor_of(p), "in the right-hand slot")
	assert_true(p.viewport.own_world_3d, "its own world, apart from the duel behind")
	assert_true(p.viewport.transparent_bg, "no backdrop: the veil shows through")
	assert_true(p.stretch, "the viewport fills the slot")
	assert_not_null(p.viewport.get_camera_3d())


func test_it_shows_the_hovered_fighter() -> void:
	await _open(MatchConfig.DUEL)
	assert_eq(_preview().view.fighter_id, &"rogue")
	_key(KEY_RIGHT)
	assert_eq(_preview().view.fighter_id, &"hunter")
	_key(KEY_LEFT)
	assert_eq(_preview().view.fighter_id, &"rogue")


func test_it_follows_the_side_shown() -> void:
	var d: MatchSelection.Draft = MatchSelection.default_draft(MatchConfig.WATCH)
	MatchSelection.set_fighter(d, 0, &"rogue")
	MatchSelection.set_fighter(d, 1, &"hunter")
	select.start(d)
	assert_eq(_preview().view.fighter_id, &"rogue")
	select.show_side(1)
	assert_eq(_preview().view.fighter_id, &"hunter")
	select.step_back()
	assert_eq(_preview().view.fighter_id, &"rogue")


func test_the_second_side_of_a_mirror_match_wears_the_second_palette() -> void:
	var d: MatchSelection.Draft = MatchSelection.default_draft(MatchConfig.WATCH)
	MatchSelection.set_fighter(d, 0, &"hunter")
	MatchSelection.set_fighter(d, 1, &"hunter")
	select.start(d)
	assert_eq(_preview().view.palette, 0)
	select.show_side(1)
	assert_eq(_preview().view.fighter_id, &"hunter")
	assert_eq(_preview().view.palette, 1)
	assert_eq(_preview().view.side_color(), LookPalette.side_color(1))


func test_it_holds_the_chosen_weapon() -> void:
	await _open(MatchConfig.DUEL)
	var p: FighterPreview = _preview()
	assert_eq(p.view.model.weapon_look.id, select.draft.sides[0].weapon_id)
	for w: StringName in [&"greatsword", &"daggers", &"katana"]:
		MatchSelection.set_weapon(select.draft, 0, w)
		select.refresh()
		assert_eq(p.weapon_shown, w)
		assert_eq(p.view.model.weapon_look.id, w)
		assert_eq(p.fighter().weapon.id, w, "the rules' fighter holds it too")
		assert_eq(p.view.model.weapons.size(), 2 if w == &"daggers" else 1)


func test_a_weapon_card_picked_in_the_panel_reaches_the_preview() -> void:
	await _open(MatchConfig.DUEL)
	var cards: WeaponCardRow = select.loadout_panel.cards
	cards.card_of(&"greatsword").pressed.emit()
	assert_eq(_preview().weapon_shown, &"greatsword")


func test_it_plays_the_matchs_combat_idle_for_the_weapon() -> void:
	await _open(MatchConfig.DUEL)
	var p: FighterPreview = _preview()
	for w: StringName in [&"katana", &"greatsword", &"daggers"]:
		MatchSelection.set_weapon(select.draft, 0, w)
		select.refresh()
		p.advance(0.25)
		assert_not_null(p.view.shot, "the clip director picks the clips")
		assert_eq(p.view.shot.idle, ClipDirector.idle_clip(p.fighter(), p.view.director), "%s: the match's idle" % w)
		assert_eq(p.fighter().state, &"free", "%s: standing in guard" % w)
		assert_false(p.fighter().shouldered, "%s: in guard, not on the shoulder" % w)


func test_the_idle_runs_on_while_the_preview_shows() -> void:
	await _open(MatchConfig.DUEL)
	var p: FighterPreview = _preview()
	var before: int = p.world.frame
	p.advance(0.5)
	assert_eq(p.world.frame - before, 30, "half a second is 30 rules frames")
	assert_eq(p.fighter().pos.x, 0.0, "the fighter stays on its spot")
	assert_eq(p.fighter().pos.z, 0.0)


func test_it_turns_slowly_all_the_way_round() -> void:
	await _open(MatchConfig.DUEL)
	var p: FighterPreview = _preview()
	var start: float = p.turn
	p.advance(3.0)
	assert_almost_eq(p.turn - start, TAU * 3.0 / 12.0, 0.001, "a revolution every 12 s")
	assert_almost_eq(p.pivot.rotation.y, wrapf(p.turn, -PI, PI), 0.001)


func test_a_random_weapon_cycles_the_three() -> void:
	var d: MatchSelection.Draft = MatchSelection.default_draft(MatchConfig.DUEL)
	MatchSelection.set_random_weapon(d, 1, true)
	select.start(d)
	select.show_side(1)
	var p: FighterPreview = _preview()
	var seen: Dictionary[StringName, bool] = {}
	seen[p.weapon_shown] = true
	var first: StringName = p.weapon_shown
	p.advance(1.4)
	assert_eq(p.weapon_shown, first, "held for 1.5 s")
	p.advance(0.2)
	assert_ne(p.weapon_shown, first, "then the next")
	for _i: int in 2:
		seen[p.weapon_shown] = true
		p.advance(1.5)
	seen[p.weapon_shown] = true
	assert_eq(seen.size(), 3, "all three weapons shown")
	assert_eq(p.view.model.weapon_look.id, p.weapon_shown)


func test_picking_a_weapon_ends_the_cycle() -> void:
	var d: MatchSelection.Draft = MatchSelection.default_draft(MatchConfig.DUEL)
	MatchSelection.set_random_weapon(d, 1, true)
	select.start(d)
	select.show_side(1)
	MatchSelection.set_weapon(select.draft, 1, &"daggers")
	select.refresh()
	var p: FighterPreview = _preview()
	assert_eq(p.weapon_shown, &"daggers")
	p.advance(4.0)
	assert_eq(p.weapon_shown, &"daggers")


func test_twenty_changes_leave_no_orphan_nodes() -> void:
	await _open(MatchConfig.DUEL)
	var p: FighterPreview = _preview()
	p.advance(0.1)
	await get_tree().process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var nodes: int = p.viewport.get_child_count()
	var fighters: Array[StringName] = [&"rogue", &"hunter"]
	var weapons: Array[StringName] = [&"katana", &"greatsword", &"daggers"]
	for i: int in 20:
		if i % 2 == 0:
			MatchSelection.set_fighter(select.draft, 0, fighters[(i / 2) % 2])
		else:
			MatchSelection.set_weapon(select.draft, 0, weapons[i % 3])
		select.refresh()
		p.advance(0.05)
	await get_tree().process_frame
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans, "no orphan nodes")
	assert_eq(p.viewport.get_child_count(), nodes, "nothing piles up in the stage")
	assert_eq(p.view.find_children("*", "FighterModel", true, false).size(), 1, "one model")


func test_a_hidden_select_stops_the_preview() -> void:
	await _open(MatchConfig.DUEL)
	var p: FighterPreview = _preview()
	select.hide()
	var before: int = p.world.frame
	var turn: float = p.turn
	for _i: int in 3:
		await get_tree().process_frame
	assert_eq(p.world.frame, before, "no rules steps while hidden")
	assert_eq(p.turn, turn, "no turning while hidden")
	assert_eq(p.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	select.show()
	await get_tree().process_frame
	assert_ne(p.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
