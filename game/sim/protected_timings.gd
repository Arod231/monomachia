class_name ProtectedTimings
extends RefCounted
## The protected timings (milestone-1 spec, "The protected-timing table";
## milestone-1 task 22): rules numbers that every clip showing them must
## fit, retuned once for the slower pace and then frozen. Changing one needs
## the owner's OK and an entry in the spec; test_protected_timings.gd pins
## them.
##
## Two sets: the Katana's and bare hands' retuned values (P28), and today's,
## which the Greatsword and the Daggers keep until milestone 2 re-keys them
## (P48). The weapon of the move that was hit, blocked, parried or
## countered, or that knocked down or disarmed, picks the set
## (for_weapon(); the owner's choice, Oct 5). They take effect in two parts
## (the owner's choice, Oct 5):
## - a move's own values, its hitstun, blockstun and hit-stop and the
##   full-charge bonus, switch per move as its family re-keys it
##   (for_move(): a Katana or bare-hands move on real markers), so the
##   stand-ins keep today's (AttackDef.finalize_moves() sets them);
## - the outcome values, the counters' stuns, the disarm's stagger and the
##   disarmed fighter's daze, the knockdown's phases and guard window, and
##   the hit-stops of a parry, Flash and redirect, disarm, stomp and leap,
##   switch for every Katana and bare-hands move at once.
## Kept as they were, and pinned with the rest: the parry, Flash and
## redirect windows, the input buffer, the roll and the backstep, the parry
## recoil and the parrier's recovery, the parry-spam shrink and the block's
## hit-stop rule (SimConst and the weapons' records).

## The weapons whose moves take the retuned set: milestone 1's.
const RETUNED_WEAPONS: Array[StringName] = [&"katana", &"fists"]

## A hit's hit-stop on a block: the move's less BLOCK_HITSTOP_CUT, at least
## BLOCK_HITSTOP_MIN (kept as a rule).
const BLOCK_HITSTOP_CUT: int = 2
const BLOCK_HITSTOP_MIN: int = 3

## Today's set (the build's on Oct 4): the Greatsword's and the Daggers'
## (their moves may set their own hitstun, as the Daggers' strings do).
## A move kind other than light, heavy and ultimate counts as an ability.
const TODAY: Dictionary = {
	"hitstun": {&"light": 14, &"heavy": 26, &"ability": 24, &"ultimate": 40},
	"blockstun": {&"light": 10, &"heavy": 16, &"ability": 14, &"ultimate": 14},
	"hitstop": {&"light": 4, &"heavy": 7, &"ability": 6, &"ultimate": 6},
	"move_hitstun": {},
	"charge_hitstun": 12,
	"charge_blockstun": 8,
	"charge_hitstop": 4,
	"parry_hitstop": 8,
	"flash_hitstop": 10,
	"disarm_hitstop": 14,
	"stomp_hitstop": 10,
	"leap_hitstop": 6,
	"stomp_stun": 70,
	"flash_stun": 60,
	"redirect_stun": 50,
	"disarm_stagger": 26,
	"disarmed_daze": 60,
	"knockdown_fall": 20,
	"knockdown_ground": 30,
	"knockdown_rise": 25,
	"knockdown_guard": 15,
}

## The retune (P28): the Katana's set; bare hands' differs only in
## FISTS_HITSTUN. Each hitstun leaves the defender free 2 frames before a
## light follow-up at the band floors, counted as the rules step (the next
## hit lands its startup plus 2 frames after a hit on the last active frame,
## at the earliest branch point: 1 frame after it for a light, 18 for a
## heavy), so a frame more than the spec first counted; blockstun keeps
## today's ratio to recovery (x 1.5); the outcome hit-stops gain 2; the stuns
## keep the punish they buy today.
const RETUNED: Dictionary = {
	"hitstun": {&"light": 24, &"heavy": 41, &"ability": 36, &"ultimate": 60},
	"blockstun": {&"light": 15, &"heavy": 24, &"ability": 21, &"ultimate": 21},
	"hitstop": {&"light": 5, &"heavy": 9, &"ability": 8, &"ultimate": 14},
	"move_hitstun": {&"u_moon_v": 75, &"u_moon_h": 75, &"f_breaker": 54},
	"charge_hitstun": 18,
	"charge_blockstun": 12,
	"charge_hitstop": 4,
	"parry_hitstop": 10,
	"flash_hitstop": 12,
	"disarm_hitstop": 16,
	"stomp_hitstop": 12,
	"leap_hitstop": 8,
	"stomp_stun": 90,
	"flash_stun": 66,
	"redirect_stun": 56,
	"disarm_stagger": 36,
	"disarmed_daze": 66,
	"knockdown_fall": 30,
	"knockdown_ground": 30,
	"knockdown_rise": 40,
	"knockdown_guard": 20,
}

## Bare hands' hitstun, by the same rule from their light floor (18):
## lights 18, Jab and Cross included (no longer guaranteed), and heavies 35.
const FISTS_HITSTUN: Dictionary = {&"light": 18, &"heavy": 35}

static var _today: ProtectedTimings = null
static var _retuned: Dictionary[StringName, ProtectedTimings] = {}

## Whether this is the retuned set, and for which weapon (&"" for today's).
var retuned: bool = false
var weapon: StringName = &""
var _values: Dictionary = {}


## Today's set.
static func today() -> ProtectedTimings:
	if _today == null:
		_today = ProtectedTimings.new()
		_today._values = TODAY
	return _today


## The set a move of `weapon` decides by: the retuned one for the Katana and
## bare hands, today's for the others (and for a move of no weapon).
static func for_weapon(p_weapon: StringName) -> ProtectedTimings:
	if not RETUNED_WEAPONS.has(p_weapon):
		return today()
	if not _retuned.has(p_weapon):
		var t: ProtectedTimings = ProtectedTimings.new()
		t.retuned = true
		t.weapon = p_weapon
		var values: Dictionary = RETUNED.duplicate(true)
		if p_weapon == &"fists":
			(values["hitstun"] as Dictionary).merge(FISTS_HITSTUN, true)
		t._values = values
		_retuned[p_weapon] = t
	return _retuned[p_weapon]


## The set a move's own values come from: its weapon's retuned set once its
## family has re-keyed it (real markers), else today's.
static func for_move(def: AttackDef) -> ProtectedTimings:
	if def.real_markers and RETUNED_WEAPONS.has(def.weapon):
		return for_weapon(def.weapon)
	return today()


## A move kind as the table's rows name it: light, heavy, ultimate, or
## ability for any other.
static func kind_row(kind: StringName) -> StringName:
	return kind if kind == &"light" or kind == &"heavy" or kind == &"ultimate" else &"ability"


## The hitstun a hit of move `id` of `kind` puts the defender in.
func hitstun(kind: StringName, id: StringName = &"") -> int:
	var by_move: Dictionary = _values["move_hitstun"]
	if by_move.has(id):
		return int(by_move[id])
	return int((_values["hitstun"] as Dictionary)[kind_row(kind)])


func blockstun(kind: StringName) -> int:
	return int((_values["blockstun"] as Dictionary)[kind_row(kind)])


func hitstop(kind: StringName) -> int:
	return int((_values["hitstop"] as Dictionary)[kind_row(kind)])


## One of the table's single values ("stomp_stun", "knockdown_rise", ...).
func value(key: String) -> int:
	return int(_values[key])


var charge_hitstun: int:
	get: return value("charge_hitstun")
var charge_blockstun: int:
	get: return value("charge_blockstun")
var charge_hitstop: int:
	get: return value("charge_hitstop")
var parry_hitstop: int:
	get: return value("parry_hitstop")
var flash_hitstop: int:
	get: return value("flash_hitstop")
var disarm_hitstop: int:
	get: return value("disarm_hitstop")
var stomp_hitstop: int:
	get: return value("stomp_hitstop")
var leap_hitstop: int:
	get: return value("leap_hitstop")
var stomp_stun: int:
	get: return value("stomp_stun")
var flash_stun: int:
	get: return value("flash_stun")
var redirect_stun: int:
	get: return value("redirect_stun")
var disarm_stagger: int:
	get: return value("disarm_stagger")
var disarmed_daze: int:
	get: return value("disarmed_daze")
var knockdown_fall: int:
	get: return value("knockdown_fall")
var knockdown_ground: int:
	get: return value("knockdown_ground")
var knockdown_rise: int:
	get: return value("knockdown_rise")
var knockdown_guard: int:
	get: return value("knockdown_guard")


## A knockdown's whole length: its fall, its time down and its rise.
func knockdown_frames() -> int:
	return knockdown_fall + knockdown_ground + knockdown_rise


## The hit-stop of a hit of `move_hitstop` frames that is blocked.
static func block_hitstop(move_hitstop: int) -> int:
	return maxi(BLOCK_HITSTOP_MIN, move_hitstop - BLOCK_HITSTOP_CUT)
