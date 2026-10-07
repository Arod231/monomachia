class_name WeaponDef
extends RefCounted
## Port of the weapon half of v0.1-web-mvp:src/sim/moves/types.ts (WeaponId, UltimateId,
## WeaponClass, WeaponDef). The attack half is in attack_def.gd.
##
## Port notes:
## - String unions are StringNames equal to the TS literals:
##     WeaponId: katana greatsword daggers fists
##     UltimateId: moonsplitter impaler tempest disarmed
##     WeaponClass: small medium colossal fists
## - Move ids (moves keys, the slot ids, abilities) are StringNames.
## - Weapon files write the weapon as a Dictionary literal with the TS keys in
##   snake_case and build it with from_dict().
## - from_dict() also puts the weapon's swings (task 7) on its moves, from its
##   swing file (SwingFile.path_for(id)) when it has one.
## - blade and foot are the rebuild's (task 7.5): what the swings strike with;
##   off_hand_grip too (task 7.7).
## - derive_reach() is the rebuild's (task 7.13): from_dict() ends with it, so
##   each swing carries its reach and arc, and reach comes from the light
##   starter's swing once it has one.
## - duel_distance is the rebuild's (task 7.14): Katana 2.5 m, Greatsword 3.0,
##   Daggers 2.0, bare hands 1.6.
## - grips are the Elden Ring Katana's (KE task 5): WeaponGrip.

const WEAPON_IDS: Array[StringName] = [&"katana", &"greatsword", &"daggers", &"fists"]
const ULTIMATE_IDS: Array[StringName] = [&"moonsplitter", &"impaler", &"tempest", &"disarmed"]
const WEAPON_CLASSES: Array[StringName] = [&"small", &"medium", &"colossal", &"fists"]

var id: StringName = &""
var name: String = ""
var cls: StringName = &""
## movement speed multiplier
var speed_mult: float = 1.0
## dodge distance multiplier
var dodge_mult: float = 1.0
## frames before impact in which a block press parries
var parry_window: int = 0
## fraction of an attack's posture damage taken when blocking
var block_mitigation: float = 1.0
var moves: Dictionary[StringName, AttackDef] = {}
var light_start: StringName = &""
var heavy_start: StringName = &""
var sprint_light: StringName = &""
var sprint_heavy: StringName = &""
var dodge_light: StringName = &""
var dodge_heavy: StringName = &""
var back_light: StringName = &""
var back_heavy: StringName = &""
var jump_light: StringName = &""
var jump_heavy: StringName = &""
## block-ability options: pick 2
var abilities: Array[StringName] = []
## [string, string]
var default_abilities: Array[StringName] = []
var ultimate: StringName = &""
## preferred fighting distance for the AI
var reach: float = 0.0
## The reach the weapon was given, before its light starter's hand-keyed
## swing (if any) replaced it (derive_reach()).
var authored_reach: float = 0.0
## How far apart (m, centre to centre) the weapon duels: its string's lights
## put the last 15-20 cm of blade into a defender standing there, and its
## other moves are tested from distances measured from it (task 7.14; the
## spec's table of test distances)
var duel_distance: float = 0.0
## blurb for menus
var blurb: String = ""
## What a hand track sweeps (task 7.5): the blade, between the weapon model's
## BladeBase and BladeTip markers, or bare hands' fist.
var blade: StrikeSegment = null
## What a foot track sweeps: bare hands' foot; null for a weapon with no
## kicks.
var foot: StrikeSegment = null
## Where the off hand grips a weapon held in both hands, in weapon space (the
## model's OffHandGrip marker; task 7.7); null for one held in one hand.
var off_hand_grip: V3 = null
## The ways the weapon is held (WeaponGrip), the first the one each round
## starts in; empty for a weapon with one implicit grip, whose lights follow
## their moves' light follow-ups (KE task 5).
var grips: Array[WeaponGrip] = []

## Every key a weapon record has: the fields above, in order.
const KEYS: Array[String] = [
	"id", "name", "cls", "speed_mult", "dodge_mult", "parry_window", "block_mitigation", "moves",
	"light_start", "heavy_start", "sprint_light", "sprint_heavy", "dodge_light", "dodge_heavy",
	"back_light", "back_heavy", "jump_light", "jump_heavy", "abilities", "default_abilities",
	"ultimate", "reach", "duel_distance", "blurb", "blade", "foot", "off_hand_grip", "grips",
]


## Builds a WeaponDef from a weapon record (snake_case keys). "moves" must
## already be finalized: the result of AttackDef.finalize_moves(). The swings
## in the weapon's swing file, if it has one, go on its moves.
static func from_dict(d: Dictionary) -> WeaponDef:
	for key: Variant in d:
		if not KEYS.has(String(key)):
			push_error("WeaponDef: unknown key %s in weapon %s" % [key, d.get("id", "?")])
	for key: String in KEYS:
		if not d.has(key):
			push_error("WeaponDef: missing key %s in weapon %s" % [key, d.get("id", "?")])
	var w: WeaponDef = WeaponDef.new()
	w.id = StringName(d["id"])
	w.name = String(d["name"])
	w.cls = StringName(d["cls"])
	w.speed_mult = float(d["speed_mult"])
	w.dodge_mult = float(d["dodge_mult"])
	w.parry_window = int(d["parry_window"])
	w.block_mitigation = float(d["block_mitigation"])
	w.moves = d["moves"]
	SwingFile.attach(SwingFile.path_for(w.id), w.moves)
	w.light_start = StringName(d["light_start"])
	w.heavy_start = StringName(d["heavy_start"])
	w.sprint_light = StringName(d["sprint_light"])
	w.sprint_heavy = StringName(d["sprint_heavy"])
	w.dodge_light = StringName(d["dodge_light"])
	w.dodge_heavy = StringName(d["dodge_heavy"])
	w.back_light = StringName(d["back_light"])
	w.back_heavy = StringName(d["back_heavy"])
	w.jump_light = StringName(d["jump_light"])
	w.jump_heavy = StringName(d["jump_heavy"])
	w.abilities.assign(d["abilities"])
	w.default_abilities.assign(d["default_abilities"])
	w.ultimate = StringName(d["ultimate"])
	w.reach = float(d["reach"])
	w.authored_reach = w.reach
	w.duel_distance = float(d["duel_distance"])
	w.blurb = String(d["blurb"])
	w.blade = d["blade"]
	w.foot = d["foot"]
	w.off_hand_grip = d["off_hand_grip"]
	w.grips.assign(d["grips"])
	w.derive_reach()
	return w


## Works out each swing's reach and arc (SwingReach, task 7.13) and, when the
## light starter has a hand-keyed swing, takes the weapon's reach from it.
## A swing baked from a clip (authored animation) leaves the authored reach:
## a clip's arm reaches less far standing, and its lunge was lengthened to
## keep the reach table's distances, so the weapon still fights from where
## it did (the Greatsword's Heavy Swing reaches 2.42 m standing where its
## authored reach is 2.75; spaced from 2.42 the computer opponent fought
## 33 cm closer and won 7 points fewer, task 20). from_dict() calls it; call
## it again after giving a built weapon's moves swings.
func derive_reach() -> void:
	for m: AttackDef in moves.values():
		if m.swing != null:
			SwingReach.derive(m, self)
	var starter: AttackDef = moves.get(light_start)
	var keyed: bool = starter != null and starter.swing != null and starter.swing.clips.is_empty()
	reach = starter.swing.reach if keyed else authored_reach


## The grip `grip_id`, or null when the weapon has no such grip.
func grip(grip_id: StringName) -> WeaponGrip:
	for g: WeaponGrip in grips:
		if g.id == grip_id:
			return g
	return null


## The grip every round starts in: the first, or &"" for a weapon without
## grips.
func first_grip() -> StringName:
	return grips[0].id if not grips.is_empty() else &""


## Which hit of a string move `move_id` plays (1 for hit 1), in the first
## grip whose string has it; 0 for a move in no string.
func string_position(move_id: StringName) -> int:
	for g: WeaponGrip in grips:
		var at: int = g.string.find(move_id)
		if at >= 0:
			return at + 1
	return 0