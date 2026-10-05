extends GutTest
## The dummy's weapon for a behaviour (task 23.2), in the rules: which weapon
## can perform each behaviour, the owner's order for a swap (the first in the
## select's order that can, back to the picked weapon whenever it can), and a
## clean swap: free, armed, the new weapon's abilities, no dropped weapon and
## no impale left behind.

const H := preload("res://tests/sim/sim_helpers.gd")

## The unblockable counter kind each behaviour practises (the others need none).
const NEEDS: Dictionary[StringName, StringName] = {&"thrust": &"thrust", &"sweep": &"sweep", &"slam": &"slam"}
## The weapons that can perform the unblockable drills (the demo's table).
const CAN: Dictionary[StringName, Array] = {
	&"thrust": [&"katana", &"daggers"],
	&"sweep": [&"katana", &"greatsword", &"daggers"],
	&"slam": [&"greatsword"],
}


func after_each() -> void:
	H.dispose_all()


func _upkeep(dummy_weapon: WeaponDef, player_weapon: WeaponDef = Moves.KATANA, gap: float = 2.2) -> TrainingUpkeep:
	var W: World = H.make_world(player_weapon, dummy_weapon, gap)
	return TrainingUpkeep.new(W)


func test_which_weapons_can_perform_each_behaviour() -> void:
	for b: StringName in TrainingBrain.BEHAVIOURS:
		for w: StringName in Moves.PLAYABLE_WEAPONS:
			var expected: bool = not CAN.has(b) or CAN[b].has(w)
			assert_eq(TrainingUpkeep.can_perform(Moves.WEAPONS[w], b), expected, "%s with the %s" % [b, w])


func test_every_behaviour_on_every_dummy_weapon_gets_a_weapon_that_can_do_it() -> void:
	for picked: StringName in Moves.PLAYABLE_WEAPONS:
		var up: TrainingUpkeep = _upkeep(Moves.WEAPONS[picked])
		for b: StringName in TrainingBrain.BEHAVIOURS:
			var w: WeaponDef = up.weapon_for(b)
			assert_true(TrainingUpkeep.can_perform(w, b), "%s from the %s: the %s" % [b, picked, w.id])
			if TrainingUpkeep.can_perform(Moves.WEAPONS[picked], b):
				assert_eq(w.id, picked, "%s: the picked %s can, so it stays" % [b, picked])


func test_a_swap_takes_the_first_weapon_in_the_select_s_order() -> void:
	assert_eq(_upkeep(Moves.GREATSWORD).weapon_for(&"thrust").id, &"katana", "thrust: the Katana before the Daggers")
	assert_eq(_upkeep(Moves.KATANA).weapon_for(&"slam").id, &"greatsword")
	assert_eq(_upkeep(Moves.DAGGERS).weapon_for(&"slam").id, &"greatsword")


func test_the_picked_weapon_comes_back_when_it_can() -> void:
	var up: TrainingUpkeep = _upkeep(Moves.GREATSWORD)
	up.swap_dummy_weapon(up.weapon_for(&"thrust"))
	assert_eq(up.world.fighters[1].weapon.id, &"katana")
	assert_eq(up.weapon_for(&"lights").id, &"greatsword", "back to the Greatsword picked in the select")
	assert_eq(up.weapon_for(&"slam").id, &"greatsword")


func test_a_swap_leaves_the_dummy_free_armed_with_the_new_abilities() -> void:
	var up: TrainingUpkeep = _upkeep(Moves.GREATSWORD)
	var dummy: Fighter = up.world.fighters[1]
	H.run(up.world, 3, Callable(), func(i: int) -> RawInput: return H.btn(Btn.HEAVY) if i == 0 else H.idle())
	assert_eq(dummy.state, &"attack", "mid-swing")
	up.swap_dummy_weapon(Moves.KATANA)
	assert_eq(dummy.state, &"free")
	assert_null(dummy.atk)
	assert_true(dummy.armed)
	assert_eq(dummy.weapon, Moves.KATANA)
	assert_eq(dummy.abilities, Moves.KATANA.default_abilities)
	H.run(up.world, 10)
	assert_eq(dummy.weapon, Moves.KATANA, "and steps on with it")


func test_a_swap_while_disarmed_leaves_no_dropped_weapon() -> void:
	var up: TrainingUpkeep = _upkeep(Moves.GREATSWORD)
	var dummy: Fighter = up.world.fighters[1]
	dummy.disarm(up.world.fighters[0], &"parried")
	assert_not_null(up.world.weapon_of(1))
	up.swap_dummy_weapon(Moves.KATANA)
	assert_true(dummy.armed)
	assert_null(up.world.weapon_of(1), "the old weapon is gone from the floor")
	assert_eq(dummy.state, &"free", "out of the disarm stagger")


func test_a_swap_mid_impale_lets_the_player_go() -> void:
	var up: TrainingUpkeep = _upkeep(Moves.GREATSWORD, Moves.KATANA, 6.0)
	var W: World = up.world
	var dummy: Fighter = W.fighters[1]
	dummy.hp = 20.0
	var impaled: bool = false
	for i: int in 80:
		W.step([H.idle(), H.btn(Btn.ULTIMATE) if i == 0 else H.idle()])
		if W.fighters[0].state == &"impaled":
			impaled = true
			break
	assert_true(impaled, "the Impaler caught the player")
	up.swap_dummy_weapon(Moves.KATANA)
	assert_ne(W.fighters[0].state, &"impaled", "let go")
	assert_null(W.fighters[0].impaled_by)
	assert_eq(dummy.state, &"free")
	assert_null(dummy.ult)
	H.run(W, 60)
	assert_ne(W.fighters[0].state, &"impaled")
