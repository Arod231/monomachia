class_name SimEvents
extends RefCounted
## Port of v0.1-web-mvp:src/sim/events.ts and the OutcomeKind type in src/sim/worldTypes.ts.
##
## Everything noteworthy that happens in the simulation is emitted as an event.
## The renderer, audio and HUD consume them; tests assert on them.
##
## Port notes:
## - An event is a Dictionary with exactly the TS keys (String keys, "t" first).
##   "t" and every string-union value (kind, reason, sound, weapon, ult...) is a
##   StringName equal to the TS literal; move ids ("attack") are the move's
##   StringName id. Numbers stay int where the TS value is always a whole number
##   of frames or an id, float otherwise; booleans are bool.
## - In many variants "f" is a fighter id (0 or 1), not a frame.
## - Every Vec3 value is converted with vec3() when the event is emitted, so
##   an event never holds a live V3 that the rules keep changing.
## - Arrays stay Arrays ("wins": [int, int]).
## - Godot compares Dictionaries strictly by type (1 != 1.0 and &"a" != "a"
##   inside ==), so compare events field by field, not with ==.
## - The WorldLike and DroppedWeaponLike interfaces in worldTypes.ts only break
##   an import cycle in TS; GDScript has no such cycle problem, so the port
##   uses World and DroppedWeapon directly.
##
## The variants, as { key: type } (Vec3 means a {"x","y","z"} Dictionary):
##   swing:         f: int, attack: StringName, heavy: bool, weapon: StringName (WeaponId)
##   telegraph:     f: int, kind: StringName (CounterKind or &"ult"), attack: StringName
##   hit:           attacker: int, target: int, attack: StringName, damage: float, posture: float,
##                  pos: Vec3, heavy: bool, sound: StringName (HitSound), backstab: bool (optional in TS, always set)
##   block:         attacker: int, target: int, attack: StringName, posture: float, pos: Vec3, heavy: bool
##   parry:         parrier: int, attacker: int, pos: Vec3, kind: &"parry" | &"flash" | &"redirect",
##                  timing: int (frames between the block press and impact, for training feedback), window: int
##   counter:       kind: &"stomp" | &"leap" | &"evade", by: int, on: int, pos: Vec3
##   evade:         f: int, attacker: int
##   disarm:        victim: int, by: int, pos: Vec3, reason: &"parried" | &"blocked" | &"redirect"
##   stagger:       f: int
##   dodge:         f: int, back: bool
##   jump:          f: int
##   land:          f: int
##   step:          f: int
##   ko:            loser: int, winner: int
##   ultReady:      f: int
##   ultStart:      f: int, ult: StringName
##   ultChoice:     f: int
##   ultWave:       f: int, kind: &"vertical" | &"horizontal", pos: Vec3, yaw: float
##   ultDash:       f: int
##   ultImpale:     f: int, target: int
##   ultBurst:      f: int, pos: Vec3
##   ultLightning:  f: int, from: Vec3, to: Vec3
##   recall:        f: int
##   pickup:        f: int
##   weaponBounce:  owner: int, pos: Vec3, speed: float
##   counterReady:  f: int
##   backstabReady: f: int
##   whiff:         f: int, attack: StringName
##   parryEarly:    f: int, frames: int (declared in TS, never emitted)
##   roundStart:    round: int
##   fight:         round: int
##   roundOver:     winner: int, wins: [int, int], perfect: bool
##   matchOver:     winner: int
##   knockdown:     f: int (the downed fighter), attacker: int (authored animation, task 16)
##   standup:       f: int (the knockdown over, the fighter free again; task 16)
##   recallBurst:   f: int (the recaller), on: int (the opponent), hit: bool, reach: float,
##                  pos: Vec3 (the recall's power-up burst, authored animation task 30b)

## Every SimEvent "t" value, in the order of the TS union.
const TYPES: Array[StringName] = [
	&"swing",
	&"telegraph",
	&"hit",
	&"block",
	&"parry",
	&"counter",
	&"evade",
	&"disarm",
	&"stagger",
	&"dodge",
	&"jump",
	&"land",
	&"step",
	&"ko",
	&"ultReady",
	&"ultStart",
	&"ultChoice",
	&"ultWave",
	&"ultDash",
	&"ultImpale",
	&"ultBurst",
	&"ultLightning",
	&"recall",
	&"pickup",
	&"weaponBounce",
	&"counterReady",
	&"backstabReady",
	&"whiff",
	&"parryEarly",
	&"roundStart",
	&"fight",
	&"roundOver",
	&"matchOver",
	&"knockdown",
	&"standup",
	&"recallBurst",
]

## worldTypes.ts OutcomeKind: what World.evaluate decides for one attack.
const OUTCOME_KINDS: Array[StringName] = [
	&"miss",
	&"jumped",
	&"evade",
	&"parry",
	&"flash",
	&"redirect",
	&"stomp",
	&"leap",
	&"evadeCounter",
	&"block",
	&"disarm",
	&"hit",
]


## A Vec3 as it goes into an event: a fresh {"x", "y", "z"} Dictionary.
static func vec3(v: V3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}
