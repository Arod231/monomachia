class_name Moves
extends RefCounted
## Port of v0.1-web-mvp:src/sim/moves/index.ts: the weapon registry and the scripted
## ultimate hits.
##
## Port notes:
## - KATANA, GREATSWORD, DAGGERS and FISTS are built once, when this class
##   loads, so each weapon is a single shared object as in the TS (fighters may
##   compare weapons by identity).
## - The move schema (types.ts) is in attack_def.gd and weapon_def.gd.
## - getMove throws on an unknown id; get_move pushes an error and returns null.

static var KATANA: WeaponDef = KatanaMoves.build()
static var GREATSWORD: WeaponDef = GreatswordMoves.build()
static var DAGGERS: WeaponDef = DaggersMoves.build()
static var FISTS: WeaponDef = FistsMoves.build()

static var WEAPONS: Dictionary[StringName, WeaponDef] = {
	&"katana": KATANA,
	&"greatsword": GREATSWORD,
	&"daggers": DAGGERS,
	&"fists": FISTS,
}

const PLAYABLE_WEAPONS: Array[StringName] = [&"katana", &"greatsword", &"daggers"]

## Counter-lunge follow-up (after the back-dash counter) per weapon.
const COUNTER_LUNGE: Dictionary[StringName, StringName] = {
	&"katana": &"k_lunge",
	&"greatsword": &"g_lunge",
	&"daggers": &"d_lunge",
	&"fists": &"f_lunge",
}

# Hits dealt by scripted ultimates. They run through the same hit pipeline as
# ordinary attacks, so parry/block/i-frame rules apply consistently.
static var ULT_HITS: Dictionary[StringName, AttackDef] = AttackDef.finalize_moves({
	&"u_moon_v": {
		"id": &"u_moon_v", "name": "Moonsplitter", "weapon": &"katana", "kind": &"ultimate", "type": &"slash", "anim": &"ult",
		"startup": 0, "active": 1, "recovery": 0, "damage": 30, "posture": 40, "knockback": 2.2,
		"range": 30, "arc": 360, "unblockable": true, "undodgeable": true, "hitstun": 50, "hitstop": 12,
	},
	&"u_moon_h": {
		"id": &"u_moon_h", "name": "Moonsplitter", "weapon": &"katana", "kind": &"ultimate", "type": &"sweep", "anim": &"ult",
		"startup": 0, "active": 1, "recovery": 0, "damage": 30, "posture": 40, "knockback": 2.2,
		"range": 30, "arc": 360, "unblockable": true, "undodgeable": true, "jumpable": true, "hitstun": 50, "hitstop": 12,
	},
	&"u_impale": {
		"id": &"u_impale", "name": "Impaler", "weapon": &"greatsword", "kind": &"ultimate", "type": &"thrust", "anim": &"ult", "sound": &"colossal",
		"startup": 0, "active": 1, "recovery": 0, "damage": 15, "posture": 20, "knockback": 0,
		"range": 2, "arc": 60, "unblockable": true, "undodgeable": false, "hitstun": 60, "hitstop": 12,
	},
	&"u_burst": {
		"id": &"u_burst", "name": "Impaler Burst", "weapon": &"greatsword", "kind": &"ultimate", "type": &"thrust", "anim": &"ult", "sound": &"colossal",
		"startup": 0, "active": 1, "recovery": 0, "damage": 20, "posture": 30, "knockback": 4.5,
		"range": 3, "arc": 360, "unblockable": true, "undodgeable": true, "hitstun": 55, "hitstop": 14,
	},
	&"u_tempest": {
		"id": &"u_tempest", "name": "Lightning Tempest", "weapon": &"daggers", "kind": &"ultimate", "type": &"spin", "anim": &"ult", "sound": &"dagger",
		"startup": 0, "active": 1, "recovery": 0, "damage": 5, "posture": 5, "knockback": 0.05,
		"range": 2.2, "arc": 360, "hitstun": 16, "blockstun": 12, "hitstop": 3,
	},
	&"u_tempest_final": {
		"id": &"u_tempest_final", "name": "Thunder Finisher", "weapon": &"daggers", "kind": &"ultimate", "type": &"slash", "anim": &"ult", "sound": &"dagger",
		"startup": 0, "active": 1, "recovery": 0, "damage": 8, "posture": 10, "knockback": 2.5,
		"range": 2.4, "arc": 360, "hitstun": 36, "blockstun": 18, "hitstop": 10,
	},
})


static func get_move(weapon: WeaponDef, id: StringName) -> AttackDef:
	var m: AttackDef = weapon.moves.get(id, null)
	if m == null:
		m = ULT_HITS.get(id, null)
	if m == null:
		push_error("Unknown move %s for %s" % [id, weapon.id])
		return null
	return m
