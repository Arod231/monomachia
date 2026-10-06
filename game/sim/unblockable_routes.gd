class_name UnblockableRoutes
extends RefCounted
## The routes table (milestone-1 task 83): how a fighter performs each
## unblockable, by its counter kind. Training's dummy drills from it, its
## weapon swap and the menus ask it which weapons can drill what. It replaces
## TrainingBrain.weapon_ability_for and TrainingUpkeep.can_perform.
##
## Every route of milestone 1 is a block ability: the dummy puts it on the
## light slot and starts it with block and light. The Greatsword's heavy
## unblockables (Low Sweep, Skewer) join as routes of their own with the
## Greatsword in milestone 2; its slam row stays, drilled only with
## `--full-roster`.

## The drills that practise an unblockable, in TrainingBrain.BEHAVIOURS
## order; each is named for the counter kind it practises.
const DRILLS: Array[StringName] = [&"thrust", &"sweep", &"slam"]

## weapon id -> { counter kind: the move that performs it }, in DRILLS order.
const TABLE: Dictionary = {
	&"katana": {&"thrust": &"k_thrust", &"sweep": &"k_sweep"},
	&"greatsword": {&"sweep": &"g_sweep", &"slam": &"g_slam"},
	&"daggers": {&"thrust": &"d_needle", &"sweep": &"d_sweep"},
}


## The move weapon w performs the unblockable of counter kind `kind` with,
## or &"" when it has none.
static func move_for(w: WeaponDef, kind: StringName) -> StringName:
	var routes: Dictionary = TABLE.get(w.id, {})
	return routes.get(kind, &"")


## The counter kinds weapon w has a route for, in DRILLS order.
static func kinds(w: WeaponDef) -> Array[StringName]:
	var out: Array[StringName] = []
	var routes: Dictionary = TABLE.get(w.id, {})
	for k: StringName in DRILLS:
		if routes.has(k):
			out.append(k)
	return out


## Whether weapon w can perform a dummy behaviour (TrainingBrain.BEHAVIOURS):
## an unblockable drill needs its route, every other behaviour any weapon.
static func can_perform(w: WeaponDef, behaviour: StringName) -> bool:
	return not DRILLS.has(behaviour) or move_for(w, behaviour) != &""
