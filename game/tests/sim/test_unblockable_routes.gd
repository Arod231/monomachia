extends GutTest
## The routes table (milestone-1 task 83): how a fighter performs each
## unblockable, the one place Training's dummy, its weapon swap and the menus
## read it from.

const H := preload("res://tests/sim/sim_helpers.gd")

## Every weapon's unblockables by counter kind: the spec's Katana pair, and
## the hidden weapons' block abilities, whose drills stay behind
## `--full-roster`.
const ROUTES: Dictionary[StringName, Dictionary] = {
	&"katana": {&"thrust": &"k_thrust", &"sweep": &"k_sweep"},
	&"greatsword": {&"sweep": &"g_sweep", &"slam": &"g_slam"},
	&"daggers": {&"thrust": &"d_needle", &"sweep": &"d_sweep"},
}


func after_each() -> void:
	H.dispose_all()


func test_each_weapon_routes_its_unblockables_by_counter_kind() -> void:
	for id: StringName in ROUTES:
		var w: WeaponDef = Moves.WEAPONS[id]
		for kind: StringName in [&"thrust", &"sweep", &"slam"]:
			assert_eq(UnblockableRoutes.move_for(w, kind), ROUTES[id].get(kind, &""), "%s %s" % [id, kind])
		assert_eq(UnblockableRoutes.kinds(w), ROUTES[id].keys() as Array[StringName], "%s's drills, in the drills' order" % id)


func test_bare_hands_route_nothing() -> void:
	assert_eq(UnblockableRoutes.kinds(Moves.FISTS), [] as Array[StringName])
	assert_eq(UnblockableRoutes.move_for(Moves.FISTS, &"thrust"), &"")


func test_every_route_is_an_unblockable_block_ability_of_its_counter_kind() -> void:
	for id: StringName in Moves.WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[id]
		for kind: StringName in UnblockableRoutes.kinds(w):
			var move: StringName = UnblockableRoutes.move_for(w, kind)
			assert_has(w.abilities, move, "%s's %s is one of its block abilities" % [id, move])
			var def: AttackDef = w.moves[move]
			assert_true(def.unblockable, "%s is unblockable" % move)
			assert_eq(def.counter, kind, "%s is countered as a %s" % [move, kind])


func test_every_unblockable_block_ability_has_its_route() -> void:
	for id: StringName in Moves.WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[id]
		for ab: StringName in w.abilities:
			var def: AttackDef = w.moves[ab]
			if def.unblockable and def.counter != &"":
				assert_eq(UnblockableRoutes.move_for(w, def.counter), ab, "%s's %s has a route" % [id, ab])


func test_a_weapon_performs_the_drills_it_has_a_route_for_and_every_other_behaviour() -> void:
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[id]
		for b: StringName in TrainingBrain.BEHAVIOURS:
			var expected: bool = not [&"thrust", &"sweep", &"slam"].has(b) or ROUTES[id].has(b)
			assert_eq(UnblockableRoutes.can_perform(w, b), expected, "%s with the %s" % [b, id])
