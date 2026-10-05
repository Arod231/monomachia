class_name MenuData
extends RefCounted
## What the menus say about each weapon and block ability, beyond the rules'
## own names and blurbs: the loadout panel's kanji, class, stat bars and
## ultimate per weapon, a description per ability, and the training dummy's
## behaviours as Training's panel and pause rows name them. Port of
## WEAPON_INFO, ABILITY_INFO and TRAINING_BEHAVIOURS in v0.1-web-mvp:src/ui/data.ts. An ability's name is its move's name in
## the rules (Moves), so the two can't drift apart.

## The stat bars on a weapon card, in order.
const STATS: Array[StringName] = [&"speed", &"power", &"posture", &"reach", &"parry"]
## Each bar's caption on the card. Posture is the posture damage the weapon
## deals.
const STAT_LABELS: Dictionary[StringName, String] = {
	&"speed": "Speed",
	&"power": "Power",
	&"posture": "Posture",
	&"reach": "Reach",
	&"parry": "Parry",
}

## The badges over the two ability slots: the buttons that fire each.
const SLOT_BADGES: Array[String] = ["Hold block + light", "Hold block + heavy"]


## One weapon's card: its kanji, weapon class (from the rules, as the
## demo's "Medium"), five stat bars (0-1) and ultimate.
class WeaponInfo:
	var kanji: String
	var weapon_class: String
	## stat (STATS) -> 0..1
	var stats: Dictionary
	var ultimate: String
	var ultimate_desc: String

	func _init(id: StringName, p_kanji: String, p_stats: Array[float], p_ultimate: String, p_desc: String) -> void:
		kanji = p_kanji
		weapon_class = String((Moves.WEAPONS[id] as WeaponDef).cls).capitalize()
		stats = {}
		for i: int in STATS.size():
			stats[STATS[i]] = p_stats[i]
		ultimate = p_ultimate
		ultimate_desc = p_desc


static var _weapons: Dictionary = {}

const ABILITY_DESCRIPTIONS: Dictionary[StringName, String] = {
	&"k_flash": "Parry stance with a wide window. Stuns the attacker.",
	&"k_thrust": "Unblockable thrust. Counter: dodge into it.",
	&"k_sweep": "Unblockable low cut. Counter: jump.",
	&"g_sweep": "Unblockable wide sweep. Counter: jump.",
	&"g_slam": "Unblockable overhead slam. Counter: back-dash.",
	&"g_crush": "Shoulder bash that crushes posture through a block.",
	&"d_sweep": "Dashing low sweep, unblockable. Counter: jump.",
	&"d_shadow": "Blink behind them. Your next light attack backstabs.",
	&"d_needle": "Quick unblockable thrust. Counter: dodge into it.",
}


## Each training dummy behaviour's name.
const BEHAVIOUR_NAMES: Dictionary[StringName, String] = {
	&"idle": "Stand still",
	&"block": "Block",
	&"lights": "Light chains",
	&"heavies": "Heavies",
	&"thrust": "Thrust",
	&"sweep": "Sweep",
	&"slam": "Slam",
	&"random": "Mixed attacks",
	&"fight": "Spar",
}


## The names of the behaviours the roster offers (Roster.behaviours()), in
## that order: the panel's keys 1 on.
static func behaviour_names() -> Array[String]:
	var names: Array[String] = []
	for b: StringName in Roster.behaviours():
		names.append(BEHAVIOUR_NAMES.get(b, String(b)))
	return names


## A playable weapon's card, or null (bare hands, an unknown id).
static func weapon(id: StringName) -> WeaponInfo:
	if _weapons.is_empty():
		_weapons = {
			&"katana": WeaponInfo.new(
				&"katana", "刀", [0.65, 0.55, 0.55, 0.6, 0.6], "Moonsplitter",
				"Sheathe, then release a stage-length slash. Tilt up/down for vertical, left/right for horizontal (it can be jumped)."
			),
			&"greatsword": WeaponInfo.new(
				&"greatsword", "大剣", [0.3, 0.95, 0.9, 0.85, 0.85], "Impaler",
				"Take aim and dash across the stage. On impact, press heavy to detonate a burst of energy."
			),
			&"daggers": WeaponInfo.new(
				&"daggers", "双短刀", [0.95, 0.45, 0.3, 0.35, 0.35], "Lightning Tempest",
				"Flash to the opponent and spin through six strikes. Each spin can be parried."
			),
		}
	return _weapons.get(id, null)


## An ability's name: its move's name in whichever playable weapon has it, or
## the id when no weapon does.
static func ability_name(id: StringName) -> String:
	for w: StringName in Moves.PLAYABLE_WEAPONS:
		var def: WeaponDef = Moves.WEAPONS[w]
		if def.abilities.has(id) and def.moves.has(id):
			return def.moves[id].name
	return String(id)


## An ability's description, or "".
static func ability_desc(id: StringName) -> String:
	return ABILITY_DESCRIPTIONS.get(id, "")
