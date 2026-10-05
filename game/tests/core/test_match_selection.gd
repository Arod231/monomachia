extends GutTest
## MatchSelection (22.4): the fighter select's drafts, their rules, lock in
## and the saved last picks.

const MS := preload("res://core/match_selection.gd")
const PATH: String = "user://test_last_select.cfg"


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_every_mode_s_default_makes_a_match() -> void:
	for mode: StringName in MatchConfig.MODES:
		var cfg: MatchConfig = MS.lock_in(MS.default_draft(mode), 5)
		assert_eq(cfg.problem(), "", "%s: %s" % [mode, cfg.problem()])
		assert_eq(cfg.mode, mode)
		assert_eq(cfg.arena_id, ArenaScenes.MOONLIT_SHRINE)
		assert_eq(cfg.world_seed, 5)


func test_the_defaults_are_the_demo_s() -> void:
	var duel: MatchConfig = MS.lock_in(MS.default_draft(MatchConfig.DUEL), 1)
	assert_eq([duel.sides[0].fighter_id, duel.sides[0].weapon_id, duel.sides[0].controller],
		[&"rogue", &"katana", MatchSide.HUMAN])
	assert_eq([duel.sides[1].fighter_id, duel.sides[1].weapon_id, duel.sides[1].controller, duel.sides[1].difficulty],
		[&"hunter", &"greatsword", MatchSide.COMPUTER, &"normal"])
	var training: MatchConfig = MS.lock_in(MS.default_draft(MatchConfig.TRAINING), 1)
	assert_eq(training.sides[1].controller, MatchSide.DUMMY)
	assert_eq(training.sides[1].weapon_id, &"greatsword")
	var watch: MatchConfig = MS.lock_in(MS.default_draft(MatchConfig.WATCH), 1)
	assert_eq(watch.human_count(), 0)
	assert_eq(watch.sides[1].weapon_id, &"daggers")
	var versus: MatchConfig = MS.lock_in(MS.default_draft(MatchConfig.VERSUS), 1)
	assert_eq(versus.human_count(), 2)
	assert_eq([versus.sides[0].device, versus.sides[1].device], [InputDevices.KBM, InputDevices.PAD0])


func test_the_default_duel_and_watch_match_main_s() -> void:
	assert_eq(MS.lock_in(MS.default_draft(MatchConfig.DUEL), 3).to_dict(), MatchConfig.default_duel(3).to_dict())
	assert_eq(MS.lock_in(MS.default_draft(MatchConfig.WATCH), 3).to_dict(), MatchConfig.default_watch(3).to_dict())


func test_default_training_is_the_rogue_against_the_dummy() -> void:
	var cfg: MatchConfig = MatchConfig.default_training(4)
	assert_eq(cfg.problem(), "")
	assert_eq(cfg.mode, MatchConfig.TRAINING)
	assert_eq(cfg.sides[0].controller, MatchSide.HUMAN)
	assert_eq(cfg.sides[1].controller, MatchSide.DUMMY)
	assert_eq(cfg.world_seed, 4)
	assert_eq(MS.lock_in(MS.default_draft(MatchConfig.TRAINING), 4).to_dict(), cfg.to_dict())


func test_a_weapon_change_resets_the_side_s_abilities() -> void:
	var d: MS.Draft = MS.default_draft(MatchConfig.DUEL)
	MS.set_ability(d, 0, 0, Moves.WEAPONS[&"katana"].abilities[2])
	MS.set_weapon(d, 0, &"daggers")
	assert_eq(d.sides[0].weapon_id, &"daggers")
	assert_eq(d.sides[0].resolved_abilities(), Moves.WEAPONS[&"daggers"].default_abilities)
	MS.set_ability(d, 0, 1, Moves.WEAPONS[&"daggers"].abilities[2])
	MS.set_weapon(d, 0, &"daggers")
	assert_eq(d.sides[0].abilities[1], Moves.WEAPONS[&"daggers"].abilities[2], "the same weapon keeps them")


func test_picking_the_other_slot_s_ability_swaps_them() -> void:
	var d: MS.Draft = MS.default_draft(MatchConfig.DUEL)
	var pair: Array[StringName] = d.sides[0].resolved_abilities()
	MS.set_ability(d, 0, 0, pair[1])
	assert_eq(d.sides[0].abilities, [pair[1], pair[0]] as Array[StringName])
	var third: StringName = Moves.WEAPONS[&"katana"].abilities.filter(func(a: StringName) -> bool: return not pair.has(a))[0]
	MS.set_ability(d, 0, 1, third)
	assert_eq(d.sides[0].abilities, [pair[1], third] as Array[StringName])
	assert_eq(MS.lock_in(d, 1).problem(), "")


func test_a_mirror_match_dresses_the_second_fighter_in_the_second_palette() -> void:
	var d: MS.Draft = MS.default_draft(MatchConfig.DUEL)
	MS.set_fighter(d, 1, &"rogue")
	var cfg: MatchConfig = MS.lock_in(d, 1)
	assert_eq(cfg.sides[0].fighter_id, cfg.sides[1].fighter_id)
	assert_eq([cfg.sides[0].palette, cfg.sides[1].palette], [0, 1])
	MS.set_fighter(d, 0, &"hunter")
	MS.set_fighter(d, 1, &"hunter")
	cfg = MS.lock_in(d, 1)
	assert_eq([cfg.sides[0].palette, cfg.sides[1].palette], [0, 1])


func test_a_random_weapon_is_picked_from_the_seed_at_lock_in() -> void:
	var d: MS.Draft = MS.default_draft(MatchConfig.DUEL)
	MS.set_random_weapon(d, 1, true)
	var seen: Dictionary[StringName, bool] = {}
	for s: int in range(1, 60):
		var a: MatchConfig = MS.lock_in(d, s)
		var b: MatchConfig = MS.lock_in(d, s)
		assert_eq(a.sides[1].weapon_id, b.sides[1].weapon_id, "the same seed, the same pick")
		assert_eq(a.problem(), "")
		assert_eq(a.sides[1].resolved_abilities(), Moves.WEAPONS[a.sides[1].weapon_id].default_abilities)
		seen[a.sides[1].weapon_id] = true
	assert_eq(seen.size(), Moves.PLAYABLE_WEAPONS.size(), "every weapon comes up")
	assert_true(d.random_weapon[1], "the draft stays random")
	MS.set_weapon(d, 1, &"daggers")
	assert_false(d.random_weapon[1], "a chosen weapon ends it")


func test_random_applies_only_to_the_duel_opponent() -> void:
	var d: MS.Draft = MS.default_draft(MatchConfig.WATCH)
	d.random_weapon = [true, true]
	var cfg: MatchConfig = MS.lock_in(d, 9)
	assert_eq([cfg.sides[0].weapon_id, cfg.sides[1].weapon_id], [&"katana", &"daggers"])


func test_a_random_arena_is_one_of_the_selectable() -> void:
	var d: MS.Draft = MS.default_draft(MatchConfig.DUEL)
	MS.set_arena(d, MS.RANDOM)
	for s: int in range(1, 10):
		assert_true(ArenaScenes.SELECTABLE.has(MS.lock_in(d, s).arena_id))


func test_the_selectable_arenas_are_the_real_ones() -> void:
	assert_eq(ArenaScenes.SELECTABLE, [ArenaScenes.MOONLIT_SHRINE] as Array[StringName])
	assert_false(ArenaScenes.SELECTABLE.has(ArenaScenes.STANDIN))
	for id: StringName in ArenaScenes.SELECTABLE:
		assert_ne(ArenaScenes.def(id).display_name, "", "%s has a name for the select" % id)


func test_saved_picks_come_back() -> void:
	var a: MS = MS.new(PATH)
	var duel: MS.Draft = a.draft(MatchConfig.DUEL)
	MS.set_fighter(duel, 0, &"hunter")
	MS.set_weapon(duel, 0, &"daggers")
	MS.set_ability(duel, 0, 0, Moves.WEAPONS[&"daggers"].abilities[2])
	MS.set_difficulty(duel, 1, &"hard")
	MS.set_random_weapon(duel, 1, true)
	MS.set_arena(duel, MS.RANDOM)
	MS.set_weapon(a.draft(MatchConfig.WATCH), 0, &"greatsword")
	assert_eq(a.save(), OK)
	var b: MS = MS.new(PATH)
	assert_true(b.load_saved())
	for mode: StringName in MatchConfig.MODES:
		assert_eq(b.draft(mode).to_dict(), a.draft(mode).to_dict(), String(mode))


func test_no_file_gives_the_defaults() -> void:
	var s: MS = MS.new(PATH)
	assert_false(s.load_saved())
	for mode: StringName in MatchConfig.MODES:
		assert_eq(s.draft(mode).to_dict(), MS.default_draft(mode).to_dict())


func test_a_corrupt_file_gives_the_defaults() -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[duel\ndraft = {{{ not a config")
	f.close()
	var s: MS = MS.new(PATH)
	assert_false(s.load_saved())
	assert_engine_error("ConfigFile parse error", "Godot reports the broken file")
	for mode: StringName in MatchConfig.MODES:
		assert_eq(s.draft(mode).to_dict(), MS.default_draft(mode).to_dict(), String(mode))


func test_a_broken_draft_gives_that_mode_its_default() -> void:
	var a: MS = MS.new(PATH)
	MS.set_weapon(a.draft(MatchConfig.WATCH), 1, &"greatsword")
	a.save()
	var f: ConfigFile = ConfigFile.new()
	f.load(PATH)
	var duel: Dictionary = f.get_value("duel", "draft")
	(duel["sides"] as Array)[0]["weapon_id"] = "odachi"
	f.set_value("duel", "draft", duel)
	f.set_value("training", "draft", "not a draft")
	var versus: Dictionary = f.get_value("versus", "draft")
	versus["mode"] = "watch"
	f.set_value("versus", "draft", versus)
	f.save(PATH)
	var b: MS = MS.new(PATH)
	b.load_saved()
	assert_eq(b.draft(MatchConfig.DUEL).to_dict(), MS.default_draft(MatchConfig.DUEL).to_dict(), "an unknown weapon")
	assert_eq(b.draft(MatchConfig.TRAINING).to_dict(), MS.default_draft(MatchConfig.TRAINING).to_dict(), "not a draft")
	assert_eq(b.draft(MatchConfig.VERSUS).to_dict(), MS.default_draft(MatchConfig.VERSUS).to_dict(), "another mode's")
	assert_eq(b.draft(MatchConfig.WATCH).sides[1].weapon_id, &"greatsword", "the good one is kept")


func test_without_persist_nothing_is_read_or_written() -> void:
	var a: MS = MS.new(PATH)
	MS.set_weapon(a.draft(MatchConfig.DUEL), 0, &"daggers")
	a.save()
	var off: MS = MS.new(PATH, false)
	assert_false(off.load_saved(), "the file is left unread")
	assert_eq(off.draft(MatchConfig.DUEL).sides[0].weapon_id, &"katana")
	MS.set_weapon(off.draft(MatchConfig.DUEL), 0, &"greatsword")
	assert_eq(off.save(), OK)
	var b: MS = MS.new(PATH)
	b.load_saved()
	assert_eq(b.draft(MatchConfig.DUEL).sides[0].weapon_id, &"daggers", "and unwritten")


func test_a_copy_is_independent() -> void:
	var d: MS.Draft = MS.default_draft(MatchConfig.DUEL)
	var c: MS.Draft = d.copy()
	MS.set_weapon(c, 0, &"daggers")
	assert_eq(d.sides[0].weapon_id, &"katana")
