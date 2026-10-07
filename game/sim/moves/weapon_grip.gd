class_name WeaponGrip
extends RefCounted
## One way a weapon is held, a Grip (KE task 5): the string its lights play,
## hit by hit, and the share of an attack's posture a block takes in it. A
## weapon with grips lists them in WeaponDef.grips, the first the one every
## round starts in (D7); a weapon without keeps one implicit grip and plays
## as before.

const ONE_HANDED: StringName = &"one_handed"
const TWO_HANDED: StringName = &"two_handed"
## A string's hits: it ends after the last (D4).
const STRING_HITS: int = 5

var id: StringName = &""
## The moves the grip's lights play, hit 1 first; a move may stand in for
## more than one hit.
var string: Array[StringName] = []
## The share of an attack's posture damage a block takes in this grip (D2),
## in place of the weapon's block_mitigation.
var block_mitigation: float = 1.0


static func make(p_id: StringName, p_string: Array[StringName], p_block_mitigation: float) -> WeaponGrip:
	var g: WeaponGrip = WeaponGrip.new()
	g.id = p_id
	g.string = p_string.duplicate()
	g.block_mitigation = p_block_mitigation
	return g


## The move that plays hit `n` (1 to STRING_HITS), or &"" past the string.
func hit(n: int) -> StringName:
	return string[n - 1] if n >= 1 and n <= string.size() else &""
