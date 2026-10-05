extends GutTest
## The menus' words and numbers for each weapon and block ability (task
## 22.6): the loadout panel's kanji, class, stat bars and ultimate, and each
## ability's name and description, for every playable weapon.


func test_every_playable_weapon_has_menu_data() -> void:
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		var info: MenuData.WeaponInfo = MenuData.weapon(id)
		assert_not_null(info, "%s has menu data" % id)
		if info == null:
			continue
		assert_ne(info.kanji, "", "%s has a kanji" % id)
		assert_ne(info.weapon_class, "", "%s has a class" % id)
		assert_ne(info.ultimate, "", "%s names its ultimate" % id)
		assert_ne(info.ultimate_desc, "", "%s describes its ultimate" % id)
		assert_eq(info.stats.keys(), MenuData.STATS, "%s has the five stat bars in order" % id)
		for stat: StringName in MenuData.STATS:
			var v: float = info.stats[stat]
			assert_between(v, 0.05, 1.0, "%s %s is a visible bar no longer than full" % [id, stat])


func test_bare_hands_and_unknown_weapons_have_none() -> void:
	assert_null(MenuData.weapon(&"fists"), "bare hands are never picked")
	assert_null(MenuData.weapon(&"spear"))


## The demo's cards (v0.1-web-mvp:src/ui/data.ts WEAPON_INFO).
func test_the_cards_keep_the_demos_words_and_bars() -> void:
	var k: MenuData.WeaponInfo = MenuData.weapon(&"katana")
	assert_eq([k.kanji, k.weapon_class, k.ultimate], ["刀", "Medium", "Moonsplitter"])
	assert_eq(k.stats, {&"speed": 0.65, &"power": 0.55, &"posture": 0.55, &"reach": 0.6, &"parry": 0.6})
	var g: MenuData.WeaponInfo = MenuData.weapon(&"greatsword")
	assert_eq([g.kanji, g.weapon_class, g.ultimate], ["大剣", "Colossal", "Impaler"])
	assert_eq(g.stats, {&"speed": 0.3, &"power": 0.95, &"posture": 0.9, &"reach": 0.85, &"parry": 0.85})
	var d: MenuData.WeaponInfo = MenuData.weapon(&"daggers")
	assert_eq([d.kanji, d.weapon_class, d.ultimate], ["双短刀", "Small", "Lightning Tempest"])
	assert_eq(d.stats, {&"speed": 0.95, &"power": 0.45, &"posture": 0.3, &"reach": 0.35, &"parry": 0.35})


## The card's weapon class is the weapon's class in the rules.
func test_each_class_matches_the_rules_class() -> void:
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[id]
		assert_eq(MenuData.weapon(id).weapon_class.to_lower(), String(w.cls), String(id))


## The ultimate's name is the name of one of the weapon's ultimate moves.
func test_each_ultimate_is_named_as_its_move() -> void:
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		var names: Array[String] = []
		for m: AttackDef in Moves.ULT_HITS.values():
			names.append(m.name)
		assert_has(names, MenuData.weapon(id).ultimate, String(id))


func test_every_block_ability_of_every_weapon_has_a_name_and_description() -> void:
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[id]
		assert_eq(w.abilities.size(), 3, "%s offers three abilities" % id)
		for ability: StringName in w.abilities:
			assert_eq(MenuData.ability_name(ability), w.moves[ability].name, "%s takes its name from the move" % ability)
			assert_ne(MenuData.ability_desc(ability), "", "%s is described" % ability)


func test_an_unknown_ability_shows_its_id_and_no_description() -> void:
	assert_eq(MenuData.ability_name(&"x_nothing"), "x_nothing")
	assert_eq(MenuData.ability_desc(&"x_nothing"), "")


## The demo's descriptions (v0.1-web-mvp:src/ui/data.ts ABILITY_INFO), one per ability.
func test_the_descriptions_keep_the_demos_words() -> void:
	assert_eq(MenuData.ability_desc(&"k_flash"), "Parry stance with a wide window. Stuns the attacker.")
	assert_eq(MenuData.ability_desc(&"g_crush"), "Shoulder bash that crushes posture through a block.")
	assert_eq(MenuData.ability_desc(&"d_shadow"), "Blink behind them. Your next light attack backstabs.")
	assert_eq(MenuData.ABILITY_DESCRIPTIONS.size(), 9)


## The slot badges name the buttons that fire each slot.
func test_the_slot_badges_name_the_buttons() -> void:
	assert_eq(MenuData.SLOT_BADGES, ["Hold block + light", "Hold block + heavy"])
