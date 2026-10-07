extends RefCounted
## The spec's table of test distances (task 7.14): how far apart, centre to
## centre, each kind of move is tested from, played from standing at a
## standing defender (SwingReach). The string's lights are tested at their
## weapon's duelling distance (WeaponDef.duel_distance) in
## test_duel_reach.gd, and every other move with a swing must touch the
## defender from its kind's distance in test_move_reach.gd.
##
## A kind's distance is the duelling distance plus how much further the
## demo's moves of that kind reached from standing (range, a fighter's radius
## and the lunge) than their weapon's first light, the median over the four
## weapons to the half-metre. So each kind keeps its place in its weapon's
## range as the real blades replace the demo's cones.

## Each kind's distance beyond the duelling distance (m).
const OFFSET: Dictionary[StringName, float] = {
	&"string_light": 0.0,
	&"heavy": 0.5,
	&"sprint_light": 1.5,
	&"sprint_heavy": 2.5,
	&"dodge": 0.0,
	&"back_light": 0.5,
	&"back_heavy": 2.0,
	&"jump": -0.5,
	&"counter_lunge": 2.0,
	&"unblockable": 1.0,
	&"ability": 0.0,
	&"ultimate": 2.5,
}
## Moves the spec gives a distance of their own (m): the Iai Slashes reach
## about 3.6 m, 4.1 m with the 1.3 m blade (KE task 2).
const OWN: Dictionary[StringName, float] = {&"k_iai": 4.1, &"k_iai_h": 4.1}


## The kind of move `id` is on weapon `w`, for its row of the table: by the
## slot it is played from, else a counter lunge, a block ability (unblockable
## or not), an ultimate (Breaker Palm), a light of the string or a heavy (the
## heavy string, its variants and its follow-ups).
static func kind_of(w: WeaponDef, id: StringName) -> StringName:
	var m: AttackDef = w.moves[id]
	if id == w.sprint_light:
		return &"sprint_light"
	if id == w.sprint_heavy:
		return &"sprint_heavy"
	if id == w.dodge_light or id == w.dodge_heavy:
		return &"dodge"
	if id == w.back_light:
		return &"back_light"
	if id == w.back_heavy:
		return &"back_heavy"
	if id == w.jump_light or id == w.jump_heavy:
		return &"jump"
	if m.special == &"counterLunge":
		return &"counter_lunge"
	if w.abilities.has(id):
		return &"unblockable" if m.unblockable else &"ability"
	if m.kind == &"ultimate":
		return &"ultimate"
	if m.kind == &"light":
		return &"string_light"
	return &"heavy"


## How far apart (m, centre to centre) move `id` of weapon `w` is tested from.
static func distance(w: WeaponDef, id: StringName) -> float:
	if OWN.has(id):
		return OWN[id]
	return w.duel_distance + OFFSET[kind_of(w, id)]


## Whether move `def` strikes at all: zero-damage stances (Flash, Shadow
## Step) don't, as World._resolve_combat() skips them.
static func strikes(def: AttackDef) -> bool:
	return def.damage > 0.0 or def.posture > 0.0
