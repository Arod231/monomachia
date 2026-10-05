extends GutTest
## MatchConfig and MatchSide: the defaults, the checks, and the round trips
## through a Dictionary and through a .tres file.

const TRES_PATH: String = "user://test_match_config.tres"


func after_each() -> void:
	if FileAccess.file_exists(TRES_PATH):
		DirAccess.remove_absolute(TRES_PATH)


func _custom() -> MatchConfig:
	var a: MatchSide = MatchSide.human(&"hunter", &"daggers", 2, InputDevices.KBM)
	a.abilities = [&"d_shadow", &"d_needle"]
	a.profile = 1
	var b: MatchSide = MatchSide.computer(&"rogue", &"greatsword", 3, &"hard")
	return MatchConfig.make(MatchConfig.DUEL, a, b, 123456, &"moonlit_shrine")


func test_the_default_configs_are_valid() -> void:
	assert_eq(MatchConfig.default_duel().problem(), "")
	assert_eq(MatchConfig.default_watch().problem(), "")
	assert_eq(MatchConfig.attract().problem(), "")


func test_the_default_duel_is_the_hunter_katana_mirror_on_normal() -> void:
	var c: MatchConfig = MatchConfig.default_duel()
	assert_eq(c.mode, MatchConfig.DUEL)
	assert_eq(c.sides[0].fighter_id, &"hunter")
	assert_eq(c.sides[0].weapon_id, &"katana")
	assert_eq(c.sides[0].controller, MatchSide.HUMAN)
	assert_eq(c.sides[1].fighter_id, &"hunter")
	assert_eq(c.sides[1].weapon_id, &"katana")
	assert_eq([c.sides[0].palette, c.sides[1].palette], [0, 1], "crimson against indigo")
	assert_eq(c.sides[1].controller, MatchSide.COMPUTER)
	assert_eq(c.sides[1].difficulty, &"normal")
	assert_ne(c.sides[0].palette, c.sides[1].palette, "the two sides wear different palettes")
	assert_eq(c.arena_id, MatchConfig.DEFAULT_ARENA)


func test_round_trips_through_a_dictionary() -> void:
	var c: MatchConfig = _custom()
	var back: MatchConfig = MatchConfig.from_dict(c.to_dict())
	assert_eq(back.to_dict(), c.to_dict())
	assert_eq(back.mode, MatchConfig.DUEL)
	assert_eq(back.world_seed, 123456)
	assert_eq(back.arena_id, &"moonlit_shrine")
	assert_eq(back.sides[0].fighter_id, &"hunter")
	assert_eq(back.sides[0].palette, 2)
	assert_eq(back.sides[0].weapon_id, &"daggers")
	assert_eq(back.sides[0].abilities, [&"d_shadow", &"d_needle"] as Array[StringName])
	assert_eq(back.sides[0].controller, MatchSide.HUMAN)
	assert_eq(back.sides[0].device, InputDevices.KBM)
	assert_eq(back.sides[0].profile, 1)
	assert_eq(back.sides[1].controller, MatchSide.COMPUTER)
	assert_eq(back.sides[1].difficulty, &"hard")


func test_round_trips_through_a_resource_file() -> void:
	var c: MatchConfig = _custom()
	assert_eq(ResourceSaver.save(c, TRES_PATH), OK)
	var loaded: MatchConfig = ResourceLoader.load(TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MatchConfig
	assert_not_null(loaded)
	assert_eq(loaded.to_dict(), c.to_dict())
	assert_eq(loaded.problem(), "")


func test_copy_is_deep() -> void:
	var c: MatchConfig = _custom()
	var d: MatchConfig = c.copy()
	d.sides[0].weapon_id = &"katana"
	d.world_seed = 9
	assert_eq(c.sides[0].weapon_id, &"daggers")
	assert_eq(c.world_seed, 123456)
	var e: MatchConfig = c.with_seed(77)
	assert_eq(e.world_seed, 77)
	assert_eq(c.world_seed, 123456)


func test_resolved_abilities_fall_back_to_the_weapon_defaults() -> void:
	var s: MatchSide = MatchSide.computer(&"rogue", &"katana")
	assert_eq(s.resolved_abilities(), Moves.KATANA.default_abilities)
	s.abilities = [Moves.KATANA.abilities[2], Moves.KATANA.abilities[0]]
	assert_eq(s.resolved_abilities(), s.abilities)


func test_problems_are_reported() -> void:
	var c: MatchConfig = MatchConfig.default_duel()
	c.sides[1].weapon_id = &"spear"
	assert_string_contains(c.problem(), "unknown weapon")
	c = MatchConfig.default_duel()
	c.mode = &"ranked"
	assert_string_contains(c.problem(), "unknown mode")
	c = MatchConfig.default_duel()
	c.sides = [c.sides[0]]
	assert_string_contains(c.problem(), "two sides")
	c = MatchConfig.default_duel()
	c.mode = MatchConfig.VERSUS
	assert_string_contains(c.problem(), "two human sides")
	c = MatchConfig.default_duel()
	c.mode = MatchConfig.WATCH
	assert_string_contains(c.problem(), "no human sides")
	c = MatchConfig.default_duel()
	c.mode = MatchConfig.TRAINING
	assert_string_contains(c.problem(), "dummy")
	c = MatchConfig.default_duel()
	c.sides[0].abilities = [&"g_reap", &"g_slam"]
	assert_string_contains(c.problem(), "katana block ability")
	c = MatchConfig.default_duel()
	c.sides[1].difficulty = &"impossible"
	assert_string_contains(c.problem(), "difficulty")
	c = MatchConfig.default_duel()
	c.sides[0].fighter_id = &"knight"
	assert_string_contains(c.problem(), "unknown fighter")


func test_seeds_follow_the_demo_sequence() -> void:
	# (seed * 1103515245 + 12345) % 2147483647, as v0.1-web-mvp:src/game.ts buildWorld()
	assert_eq(MatchConfig.next_seed(1), 1103527590)
	assert_eq(MatchConfig.next_seed(1103527590), (1103527590 * 1103515245 + 12345) % 2147483647)
