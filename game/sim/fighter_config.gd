class_name FighterConfig
extends RefCounted
## Port of the FighterConfig interface in v0.1-web-mvp:src/sim/fighter.ts: what a fighter is
## built from.
##
## Port notes: the optional TS fields need sentinels. An empty abilities array
## means undefined (the Fighter then uses weapon.default_abilities), and an
## empty name means undefined (the Fighter then uses weapon.name).
## `fighter_id` is the rebuild's (task 7.5): which fighter's body the rules
## use (FighterBody), empty for the default body.

var weapon: WeaponDef
## [string, string], or empty for undefined
var abilities: Array[StringName] = []
## empty for undefined
var name: String = ""
## a MatchSide.fighter_id, or empty for the default body
var fighter_id: StringName = &""


## { weapon, abilities?, name?, fighter_id? }. abilities may be any Array of
## ids (String or StringName); it is copied into a typed array.
static func make(
	p_weapon: WeaponDef, p_abilities: Array = [], p_name: String = "", p_fighter_id: StringName = &""
) -> FighterConfig:
	var c: FighterConfig = FighterConfig.new()
	c.weapon = p_weapon
	c.abilities.assign(p_abilities)
	c.name = p_name
	c.fighter_id = p_fighter_id
	return c
