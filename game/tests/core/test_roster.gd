extends GutTest
## The roster filter (milestone-1 task 4): the menus offer only the Hunter and
## the Katana, and `--full-roster` brings back the Rogue, the Greatsword and
## the Twin Daggers. No default, drill or random pick reaches a hidden
## fighter or weapon without the flag.

const MS := preload("res://core/match_selection.gd")
const PATH: String = "user://test_roster_select.cfg"
const HIDDEN_FIGHTERS: Array[StringName] = [&"rogue"]
const HIDDEN_WEAPONS: Array[StringName] = [&"greatsword", &"daggers"]


func before_each() -> void:
	Roster.full = false
	_remove()


func after_each() -> void:
	Roster.reset()
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _host() -> MatchHost:
	var host: MatchHost = MatchHost.new()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	autofree(host)
	return host


func _assert_offered(cfg: MatchConfig, what: String) -> void:
	for i: int in 2:
		var s: MatchSide = cfg.sides[i]
		assert_false(HIDDEN_FIGHTERS.has(s.fighter_id), "%s side %d: %s" % [what, i, s.fighter_id])
		assert_false(HIDDEN_WEAPONS.has(s.weapon_id), "%s side %d: %s" % [what, i, s.weapon_id])


func test_the_flag_is_read_from_the_command_line() -> void:
	assert_true(Roster.requested(PackedStringArray(["--path", "game", "--full-roster"])))
	assert_false(Roster.requested(PackedStringArray(["--swing-debug"])))


func test_without_the_flag_only_the_hunter_and_the_katana_are_offered() -> void:
	assert_eq(Roster.fighters(), [&"hunter"] as Array[StringName])
	assert_eq(Roster.weapons(), [&"katana"] as Array[StringName])
	for id: StringName in HIDDEN_FIGHTERS:
		assert_false(Roster.offers_fighter(id), String(id))
	for id: StringName in HIDDEN_WEAPONS:
		assert_false(Roster.offers_weapon(id), String(id))


func test_the_flag_brings_all_three_back() -> void:
	Roster.full = true
	assert_eq(Roster.fighters(), [&"rogue", &"hunter"] as Array[StringName])
	assert_eq(Roster.weapons(), Moves.PLAYABLE_WEAPONS)
	assert_true(Roster.behaviours().has(&"slam"))


func test_the_slam_drill_goes_while_the_greatsword_is_hidden() -> void:
	var offered: Array[StringName] = Roster.behaviours()
	assert_false(offered.has(&"slam"))
	var expected: Array[StringName] = TrainingBrain.BEHAVIOURS.filter(func(b: StringName) -> bool: return b != &"slam")
	assert_eq(offered, expected, "every other drill stays, in order")


func test_no_default_match_reaches_a_hidden_fighter_or_weapon() -> void:
	_assert_offered(MatchConfig.default_duel(), "default duel")
	_assert_offered(MatchConfig.default_training(), "default training")
	_assert_offered(MatchConfig.default_watch(), "default watch")
	_assert_offered(MatchConfig.attract(), "attract")
	for mode: StringName in MatchConfig.MODES:
		_assert_offered(MS.lock_in(MS.default_draft(mode), 1), "%s draft" % mode)


func test_no_random_pick_reaches_a_hidden_weapon() -> void:
	var d: MS.Draft = MS.default_draft(MatchConfig.DUEL)
	MS.set_random_weapon(d, 1, true)
	assert_false(MS.offers_random(MatchConfig.DUEL, 1), "one weapon offered: nothing to leave to chance")
	for s: int in range(1, 40):
		_assert_offered(MS.lock_in(d, s), "seed %d" % s)


func test_saved_hidden_picks_give_that_mode_its_default() -> void:
	Roster.full = true
	var a: MS = MS.new(PATH)
	MS.set_fighter(a.draft(MatchConfig.DUEL), 0, &"rogue")
	MS.set_weapon(a.draft(MatchConfig.WATCH), 1, &"daggers")
	MS.set_difficulty(a.draft(MatchConfig.TRAINING), 1, &"hard")
	assert_eq(a.save(), OK)
	Roster.full = false
	var b: MS = MS.new(PATH)
	b.load_saved()
	assert_eq(b.draft(MatchConfig.DUEL).to_dict(), MS.default_draft(MatchConfig.DUEL).to_dict(), "a hidden fighter")
	assert_eq(b.draft(MatchConfig.WATCH).to_dict(), MS.default_draft(MatchConfig.WATCH).to_dict(), "a hidden weapon")
	assert_eq(b.draft(MatchConfig.TRAINING).sides[1].difficulty, &"hard", "an offered draft is kept")
	Roster.full = true
	b.load_saved()
	assert_eq(b.draft(MatchConfig.WATCH).sides[1].weapon_id, &"daggers", "the flag keeps them")


func test_no_drill_swaps_the_dummy_to_a_hidden_weapon() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.default_training(3))
	host.step(Match.INTRO_FRAMES + 5)
	watch_signals(host)
	for b: StringName in TrainingBrain.BEHAVIOURS:
		host.set_training_behaviour(b)
		assert_eq(host.fighter(1).weapon.id, &"katana", "%s keeps the Katana" % b)
	assert_signal_not_emitted(host, "loadout_changed")
	assert_ne(host.training_behaviour(), &"slam", "the slam drill is refused")


func test_with_the_flag_the_slam_drill_brings_the_greatsword() -> void:
	Roster.full = true
	var host: MatchHost = _host()
	host.start(MatchConfig.default_training(3))
	host.step(Match.INTRO_FRAMES + 5)
	host.set_training_behaviour(&"slam")
	assert_eq(host.training_behaviour(), &"slam")
	assert_eq(host.fighter(1).weapon.id, &"greatsword")
