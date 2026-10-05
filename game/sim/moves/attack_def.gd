class_name AttackDef
extends RefCounted
## Port of the attack half of v0.1-web-mvp:src/sim/moves/types.ts (AttackDef, finalizeMoves,
## totalFrames). The weapon half is in weapon_def.gd.
##
## Data definitions for attacks and weapons. Every move in the game is a record
## of numbers, so new weapons are mostly "filling in a form".
##
## Port notes:
## - Move files write each move as a Dictionary literal with the TS keys in
##   snake_case; finalize_moves() applies the TS defaults to those records and
##   builds the AttackDef objects, so "unset" is a missing key until then.
##   The rebuild changed two defaults on purpose: lights' hitstun is 14 (the
##   TS gave 18), and heavies dodge-cancel from the middle of their recovery
##   (the TS gave them no cancel).
## - Optional TS fields that finalizeMoves does not fill keep a sentinel after
##   it, chosen so the TS tests read the same way:
##     min_range 0.0, lunge 0.0, hop 0.0 (the TS only tests them for truthiness
##       or uses `?? 0`);
##     lunge_start 0 (TS `lungeStart ?? 0`);
##     multi_hit 0 (TS truthiness);
##     counter, chain_light, chain_heavy, special, sound &"" (TS truthiness or
##       `?? 'blade'` for sound; '' is not a member of those unions);
##     invuln an empty array (TS undefined; its type [number, number] rules
##       out an explicit []);
##     the booleans false.
##   Where the TS tells undefined apart from every number (`??` or
##   `!== undefined`), the sentinel is a value no move can hold, and the
##   readers compare with it, so a zero or negative value still counts as set:
##     lunge_end, dodge_cancel_from (but see heavies below), multi_interval:
##       UNSET (an int);
##     guard_crush: NAN (`not is_nan(guard_crush)` is the TS `!== undefined`).
##   finalize_moves always sets hand, track_startup, track_active, hitstun,
##   blockstun, hitstop, trail, (for unblockables) undodgeable and (for
##   heavies) dodge_cancel_from; before it,
##   the ints read UNSET, the floats NAN and the names &"".
## - undodgeable is tri-state in the TS: u_impale is unblockable but explicitly
##   dodgeable. finalize_moves sees that as a present "undodgeable": false key.
## - String unions are StringNames equal to the TS literals:
##     AttackType: slash overhead thrust sweep slam spin bash stab punch kick
##     CounterKind: thrust sweep slam
##     Hand: R L both
##     AttackKind: light heavy ability special ultimate
##     HitSound: blade colossal dagger fist
##     special: flash shadowStep counterLunge breakerPalm
##     trail: normal danger ult
##     side_start, side_end: left right centre
## - side_start, side_end, charge_move, release_variant and
##   lunge_along_dodge are the rebuild's (the demo had none of them): the
##   sides are &"" on moves outside a string, charge_move is false and
##   release_variant &"" on every move but the Iai Slash, and
##   lunge_along_dodge is false on every move but Passing Cut.
## - lunge_from(), lunge_share(), reach() and reach_arc() are the rebuild's
##   (task 7.13): the first two are Fighter's lunge sums, shared with
##   SwingReach.first_contact(); the others give a swing's reach and arc.
## - Since milestone-1 task 17 a weapon's moves take their frame data from
##   the frame-data table (FrameDataTable, generated from their clips):
##   finalize_moves() given the weapon fills startup, active, recovery, the
##   dodge-cancel window, the travel and whether its markers are real
##   (TABLE_FIELDS) from each move's row, and a record with a row must set
##   none of them. A record without a row (the ultimates' scripted hits, test
##   moves) keeps its own.

const ATTACK_TYPES: Array[StringName] = [
	&"slash", &"overhead", &"thrust", &"sweep", &"slam", &"spin", &"bash", &"stab", &"punch", &"kick",
]
const COUNTER_KINDS: Array[StringName] = [&"thrust", &"sweep", &"slam"]
const HANDS: Array[StringName] = [&"R", &"L", &"both"]
const ATTACK_KINDS: Array[StringName] = [&"light", &"heavy", &"ability", &"special", &"ultimate"]
const HIT_SOUNDS: Array[StringName] = [&"blade", &"colossal", &"dagger", &"fist"]
const SPECIALS: Array[StringName] = [&"flash", &"shadowStep", &"counterLunge", &"breakerPalm"]
const TRAILS: Array[StringName] = [&"normal", &"danger", &"ult"]
const SIDES: Array[StringName] = [&"left", &"right", &"centre"]

## An int field the TS leaves undefined (no move can hold it). Unset floats are NAN.
const UNSET: int = -0x7FFFFFFFFFFFFFFF - 1

var id: StringName = &""
var name: String = ""
var kind: StringName = &""
var type: StringName = &""
## Animation archetype key used by the renderer
var anim: StringName = &""
var hand: StringName = &""
var startup: int = 0
var active: int = 0
var recovery: int = 0
var damage: float = 0.0
var posture: float = 0.0
## metres of pushback on a clean hit
var knockback: float = 0.0
## reach from the attacker's centre to the target's surface (m)
var range: float = 0.0
var min_range: float = 0.0
## full cone angle in degrees
var arc: float = 0.0
## metres travelled forward between lungeStart and lungeEnd
var lunge: float = 0.0
var lunge_start: int = 0
var lunge_end: int = UNSET
## turn rate while winding up (rad/s)
var track_startup: float = NAN
## turn rate while active (rad/s)
var track_active: float = NAN
var hitstun: int = UNSET
var blockstun: int = UNSET
var hitstop: int = UNSET
var unblockable: bool = false
var counter: StringName = &""
var jumpable: bool = false
var undodgeable: bool = false
## counts as a "power attack" for the disarm rules
var power: bool = false
var chain_light: StringName = &""
var chain_heavy: StringName = &""
## a dodge cancels the recovery from this frame (every heavy gets one; the
## fighter opens it later by half any extra recovery, and not in the air)
var dodge_cancel_from: int = UNSET
## the dodge-cancel window's last frame, from the frame-data table (UNSET
## without one); the rules read it from milestone-1 task 20
var dodge_cancel_to: int = UNSET
var multi_hit: int = 0
var multi_interval: int = UNSET
## performed in the air (jump attacks)
var airborne: bool = false
## posture multiplier through a block (overrides the defender's mitigation)
var guard_crush: float = NAN
var special: StringName = &""
## heavy starters can be held to charge
var chargeable: bool = false
var sound: StringName = &""
## visual trail colour class
var trail: StringName = &""
## i-frames during the move (frames from start, inclusive range); empty = none
var invuln: PackedInt32Array = PackedInt32Array()
## vertical hop applied at lungeStart (m/s), for leaping attacks
var hop: float = 0.0
## the side the weapon starts and ends the move on (SIDES), so a follow-up
## can start where the move before it ends (string continuity)
var side_start: StringName = &""
var side_end: StringName = &""
## a charge the fighter can walk during, at the blocking walk's speed, and
## that a dodge cancels (the Iai stance)
var charge_move: bool = false
## the move a chargeable heavy turns into, on the same attack state, when it
## is drawn (a tap as its sheathe ends, a held one as its stance ends) with the
## stick held left or right (the horizontal Iai); it must keep this move's
## frames and lunge
var release_variant: StringName = &""
## a dodge attack that lunges on along the dodge before it, not along the
## facing (Passing Cut)
var lunge_along_dodge: bool = false
## the body's travel over each frame of the move from the frame-data table,
## [forward m, sideways m, turn degrees] per frame from frame 0, flattened
## (FrameDataTable); empty without a row. The rules move by it from
## milestone-1 task 21
var travel: PackedFloat64Array = PackedFloat64Array()
## whether the move's markers are its clip's own, from the frame-data table
## (its row not a stand-in): its clip then plays at 1.0x from its wind-up
## start (milestone-1 task 19). false for a stand-in, waiting for its family
## to re-key it, and for a record without a row
var real_markers: bool = false
## the path the weapon travels through the move (task 7, the rebuild's), put
## on it from the weapon's swing file when the weapon is built
## (WeaponDef.from_dict); null until the move has one. A record may also
## carry a Swing, as test moves do.
var swing: Swing = null

## Every key a move record may have: the fields above, in order.
const KEYS: Array[String] = [
	"id", "name", "kind", "type", "anim", "hand", "startup", "active", "recovery", "damage",
	"posture", "knockback", "range", "min_range", "arc", "lunge", "lunge_start", "lunge_end",
	"track_startup", "track_active", "hitstun", "blockstun", "hitstop", "unblockable", "counter",
	"jumpable", "undodgeable", "power", "chain_light", "chain_heavy", "dodge_cancel_from",
	"dodge_cancel_to", "multi_hit", "multi_interval", "airborne", "guard_crush", "special", "chargeable",
	"sound", "trail", "invuln", "hop", "side_start", "side_end", "charge_move",
	"release_variant", "lunge_along_dodge", "travel", "real_markers", "swing",
]
## The fields a weapon's move takes from its row of the frame-data table.
const TABLE_FIELDS: Array[String] = ["startup", "active", "recovery", "dodge_cancel_from", "dodge_cancel_to", "travel", "real_markers"]


## Builds an AttackDef from a move record (snake_case keys). Missing keys keep
## the sentinels above. Does not apply the defaults: see finalize_moves().
static func from_dict(d: Dictionary) -> AttackDef:
	for key: Variant in d:
		if not KEYS.has(String(key)):
			push_error("AttackDef: unknown key %s in move %s" % [key, d.get("id", "?")])
	var m: AttackDef = AttackDef.new()
	m.id = StringName(d.get("id", &""))
	m.name = String(d.get("name", ""))
	m.kind = StringName(d.get("kind", &""))
	m.type = StringName(d.get("type", &""))
	m.anim = StringName(d.get("anim", &""))
	m.hand = StringName(d.get("hand", &""))
	m.startup = int(d.get("startup", 0))
	m.active = int(d.get("active", 0))
	m.recovery = int(d.get("recovery", 0))
	m.damage = float(d.get("damage", 0.0))
	m.posture = float(d.get("posture", 0.0))
	m.knockback = float(d.get("knockback", 0.0))
	m.range = float(d.get("range", 0.0))
	m.min_range = float(d.get("min_range", 0.0))
	m.arc = float(d.get("arc", 0.0))
	m.lunge = float(d.get("lunge", 0.0))
	m.lunge_start = int(d.get("lunge_start", 0))
	m.lunge_end = int(d.get("lunge_end", UNSET))
	m.track_startup = float(d.get("track_startup", NAN))
	m.track_active = float(d.get("track_active", NAN))
	m.hitstun = int(d.get("hitstun", UNSET))
	m.blockstun = int(d.get("blockstun", UNSET))
	m.hitstop = int(d.get("hitstop", UNSET))
	m.unblockable = bool(d.get("unblockable", false))
	m.counter = StringName(d.get("counter", &""))
	m.jumpable = bool(d.get("jumpable", false))
	m.undodgeable = bool(d.get("undodgeable", false))
	m.power = bool(d.get("power", false))
	m.chain_light = StringName(d.get("chain_light", &""))
	m.chain_heavy = StringName(d.get("chain_heavy", &""))
	m.dodge_cancel_from = int(d.get("dodge_cancel_from", UNSET))
	m.dodge_cancel_to = int(d.get("dodge_cancel_to", UNSET))
	m.multi_hit = int(d.get("multi_hit", 0))
	m.multi_interval = int(d.get("multi_interval", UNSET))
	m.airborne = bool(d.get("airborne", false))
	m.guard_crush = float(d.get("guard_crush", NAN))
	m.special = StringName(d.get("special", &""))
	m.chargeable = bool(d.get("chargeable", false))
	m.sound = StringName(d.get("sound", &""))
	m.trail = StringName(d.get("trail", &""))
	m.invuln = PackedInt32Array(d.get("invuln", []))
	m.hop = float(d.get("hop", 0.0))
	m.side_start = StringName(d.get("side_start", &""))
	m.side_end = StringName(d.get("side_end", &""))
	m.charge_move = bool(d.get("charge_move", false))
	m.release_variant = StringName(d.get("release_variant", &""))
	m.lunge_along_dodge = bool(d.get("lunge_along_dodge", false))
	m.travel = PackedFloat64Array(d.get("travel", PackedFloat64Array()))
	m.real_markers = bool(d.get("real_markers", false))
	m.swing = d.get("swing", null)
	return m


## Fill in derived defaults so move files can stay terse.
## Takes { id: move record } and returns { id: AttackDef } in the same order.
## Each `not m.has(key)` is the TS `m.key === undefined`. Given the
## weapon, a move with a row in the frame-data table takes its TABLE_FIELDS
## from it (milestone-1 task 17); its record setting one is an error.
static func finalize_moves(moves: Dictionary, weapon: StringName = &"") -> Dictionary[StringName, AttackDef]:
	var out: Dictionary[StringName, AttackDef] = {}
	for move_id: Variant in moves:
		var m: Dictionary = (moves[move_id] as Dictionary).duplicate()
		var row: Dictionary = FrameDataTable.shared().row(weapon, StringName(move_id)) if weapon != &"" else {}
		if not row.is_empty():
			_take_row(m, row, StringName(move_id))
		var is_unblockable: bool = bool(m.get("unblockable", false))
		var move_kind: StringName = StringName(m.get("kind", &""))
		if not m.has("track_startup"):
			m["track_startup"] = 5.0 if is_unblockable else 7.0
		if not m.has("track_active"):
			m["track_active"] = 1.2
		if not m.has("hitstun"):
			# lights 14 (the demo's 18), so a defender can block or parry the next light
			m["hitstun"] = (
				14 if move_kind == &"light" else (26 if move_kind == &"heavy" else (40 if move_kind == &"ultimate" else 24))
			)
		if move_kind == &"heavy" and not m.has("dodge_cancel_from"):
			# heavies dodge-cancel in the second half of their recovery (the demo's had none)
			m["dodge_cancel_from"] = int(m["startup"]) + int(m["active"]) + ceili(int(m["recovery"]) / 2.0)
		if not m.has("blockstun"):
			m["blockstun"] = 10 if move_kind == &"light" else (16 if move_kind == &"heavy" else 14)
		if not m.has("hitstop"):
			m["hitstop"] = 4 if move_kind == &"light" else (7 if move_kind == &"heavy" else 6)
		if is_unblockable and not m.has("undodgeable"):
			m["undodgeable"] = true
		if is_unblockable and not m.has("trail"):
			m["trail"] = &"danger"
		if move_kind == &"ultimate" and not m.has("trail"):
			m["trail"] = &"ult"
		if not m.has("trail"):
			m["trail"] = &"normal"
		if not m.has("hand"):
			m["hand"] = &"R"
		out[StringName(move_id)] = from_dict(m)
	return out


## Puts a move's row of the frame-data table into its record `m`.
static func _take_row(m: Dictionary, row: Dictionary, move_id: StringName) -> void:
	for field: String in TABLE_FIELDS:
		if m.has(field):
			push_error("%s sets %s; its frame data come from the frame-data table" % [move_id, field])
	m["startup"] = int(row["startup"])
	m["active"] = int(row["active"])
	m["recovery"] = int(row["recovery"])
	var cancel: Array = row.get("dodge_cancel", [])
	if not cancel.is_empty():
		m["dodge_cancel_from"] = int(cancel[0])
		m["dodge_cancel_to"] = int(cancel[1])
	else:
		m.erase("dodge_cancel_from")
	var travel: PackedFloat64Array = PackedFloat64Array()
	for step: Variant in row["travel"]:
		travel.append(float(step[0]))
		travel.append(float(step[1]))
		travel.append(float(step[2]))
	m["travel"] = travel
	m["real_markers"] = not bool(row.get("stand_in", false))


## totalFrames(m)
func total_frames() -> int:
	return startup + active + recovery


## The lunge the move covers when started `distance` m from its target
## (centre to centre): a counter lunge closes the gap to 0.6 m between the
## bodies (7 m at most), any other move covers its own lunge. Fighter's
## start_attack() and SwingReach.first_contact() (task 7.13) both use it.
func lunge_from(distance: float) -> float:
	if special == &"counterLunge":
		return SimMath.clamp(distance - SimConst.FIGHTER_RADIUS * 2.0 - 0.6, 0.0, 7.0)
	return lunge


## The share of its lunge the move covers on attack frame `f`: easing in and
## out from lunge_start to lunge_end (the end of the active frames when
## unset), and 0 outside them. Fighter's _update_attack() and
## SwingReach.first_contact() (task 7.13) both use it.
func lunge_share(f: int) -> float:
	var ls: int = lunge_start
	var le: int = lunge_end if lunge_end != UNSET else startup + active
	if f <= ls or f > le:
		return 0.0
	var n: float = float(maxi(1, le - ls))
	return SimMath.ease_in_out(float(f - ls) / n) - SimMath.ease_in_out(float(f - 1 - ls) / n)


## The move's reach (m from the attacker's centre to the target's surface,
## without the lunge) and arc (degrees) for the computer opponent and the
## move list: its swing's (task 7.13) when it has one, else the authored
## range and arc. The counters' cones and in_volume() keep the authored ones.
func reach() -> float:
	return swing.reach if swing != null else range


func reach_arc() -> float:
	return swing.arc if swing != null else arc
