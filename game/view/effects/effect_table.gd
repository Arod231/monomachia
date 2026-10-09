class_name EffectTable
extends RefCounted
## Which combat effects each rules event spawns (plan task 18; milestone-1
## task 37). The table is data: an event type maps to a list of effect
## entries, and resolve() turns an event into concrete effects for
## CombatEffects to spawn at the event's "pos". The camera's shake and
## field-of-view kicks, the fighters' body flashes and blood (BloodEffects)
## stay outside it; this table holds what CombatEffects draws.
##
## Milestone-1 task 37 (spec P39, the owner's choices of Oct 6): contact
## reads through realistic sparks, steel on steel only. A block throws a small
## spray, a heavy block more, a parry a shower with a white-hot point, a Flash
## a brighter, longer burst; a redirect, or a bare hand on a blade, throws no
## sparks but a dull puff of dust and cloth; a blade's hit throws none
## (blood covers it). A bare hand's hit throws its own impact (milestone-1
## task 95, spec P36): a bigger puff of dust and cloth off the body, more on
## a heavy, whichever limb struck. A movement attack coming down on the
## ground (milestone-1 task 77: Leaping Cleave and Falling Crown) throws a
## burst of ground dust where it lands, bigger and faster than any blow's,
## spreading over the floor. A warm light at the contact lights the fighters and the blades for a
## few frames where the graphics preset allows (GraphicsPreset.spark_light).
## The toon look's contact flashes retired with it but for the counters' and
## the disarm's, which their families restyle.
##
## An entry is a Dictionary with a "kind" and that kind's fields, and may
## narrow when it applies:
## - "steel": true for steel on steel only (neither weapon the fists), false
##   for a bare hand's contact only; absent for any. An event naming no
##   weapons counts as steel.
## - "bare": true for a bare hand's strike only (the attacker's weapon, the
##   event's "weapon", the fists), whatever it meets.
## - "kinds": the parry kinds (the event's "kind") it applies to.
## - "by_kind": fields that replace the entry's for a parry kind (a Flash's
##   brighter burst).
## - "heavy": fields that replace the entry's on a heavy contact.
## The kinds:
## - &"flash": a glow that grows and fades (CombatEffects.flash()): "color",
##   "size", "life" in world frames. The sparks' white-hot point is one.
## - &"sparks": hot streaks thrown from the contact (CombatEffects.sparks()):
##   "count" (before the preset's scale), "speed" (m/s), "spread" (degrees
##   from the throw's direction), "life" in world frames, "aim" (&"sweep":
##   along the parried blade's sweep, the event's "dir"; &"off_guard": away
##   from the defender's guard toward the attacker).
## - &"puff": a slow, dull cloud of dust and cloth (CombatEffects.puff()):
##   "count", "size" (m across), "life", and "speed" (m/s; a bare hand's
##   hit throws its dust faster, so it scatters off the body rather than
##   hanging as a cloud; CombatEffects.PUFF_SPEED otherwise) and "color"
##   (darker and thinner off a body; CombatEffects.PUFF_COLOR otherwise), and
##   "ground": true for dust off the floor, thrown out over it and up, never
##   down into it.
## - &"light": a warm light at the contact (CombatEffects.contact_light()):
##   "energy", "range" (m), "life".

const FLASH: StringName = &"flash"
const SPARKS: StringName = &"sparks"
const PUFF: StringName = &"puff"
const LIGHT: StringName = &"light"

## The aims a spark burst takes.
const AIM_SWEEP: StringName = &"sweep"
const AIM_OFF_GUARD: StringName = &"off_guard"

## The weapon whose contact is a bare hand's, never steel.
const BARE: StringName = &"fists"

## The dust and cloth knocked off a body by a bare hand's hit: darker and
## thinner than a guard's puff.
const BODY_DUST: Color = Color(0.3, 0.27, 0.24, 0.55)
## The stone floor's dust, kicked up where a movement attack comes down:
## thicker than a guard's puff, as dull.
const GROUND_DUST: Color = Color(0.46, 0.43, 0.39, 0.8)

## The sparks' white-hot point, and their light's warm colour.
const WHITE_HOT: Color = Color(1.0, 0.93, 0.78)
const SPARK_LIGHT: Color = Color(1.0, 0.68, 0.38)

const TABLE: Dictionary[StringName, Array] = {
	&"block": [
		{"kind": FLASH, "steel": true, "color": WHITE_HOT, "size": 0.12, "life": 4, "heavy": {"size": 0.18, "life": 5}},
		{"kind": SPARKS, "steel": true, "count": 12, "speed": 4.0, "spread": 70.0, "life": 13, "aim": AIM_OFF_GUARD,
			"heavy": {"count": 22, "speed": 4.8, "life": 15}},
		{"kind": LIGHT, "steel": true, "energy": 1.2, "range": 2.6, "life": 4, "heavy": {"energy": 1.8, "life": 5}},
		{"kind": PUFF, "steel": false, "count": 6, "size": 0.16, "life": 22, "heavy": {"count": 9, "size": 0.2}},
	],
	&"parry": [
		{"kind": FLASH, "steel": true, "kinds": [&"parry", &"flash"], "color": WHITE_HOT, "size": 0.26, "life": 6,
			"by_kind": {&"flash": {"color": Color(1.0, 0.97, 0.9), "size": 0.4, "life": 9}}},
		{"kind": SPARKS, "steel": true, "kinds": [&"parry", &"flash"], "count": 30, "speed": 5.5, "spread": 55.0, "life": 16,
			"aim": AIM_SWEEP, "by_kind": {&"flash": {"count": 48, "speed": 6.5, "life": 22}}},
		{"kind": LIGHT, "steel": true, "kinds": [&"parry", &"flash"], "energy": 2.2, "range": 3.2, "life": 6,
			"by_kind": {&"flash": {"energy": 3.2, "range": 3.8, "life": 9}}},
		# a redirect turns the blade by the arm, and a fist on a blade is no
		# steel either: a dull puff where they meet
		{"kind": PUFF, "steel": false, "count": 7, "size": 0.18, "life": 24},
		{"kind": PUFF, "steel": true, "kinds": [&"redirect"], "count": 7, "size": 0.18, "life": 24},
	],
	&"hit": [
		{"kind": PUFF, "bare": true, "count": 7, "size": 0.12, "life": 20, "speed": 1.1, "color": BODY_DUST,
			"heavy": {"count": 11, "size": 0.15, "life": 24, "speed": 1.4}},
	],
	&"touchdown": [
		{"kind": PUFF, "count": 30, "size": 0.3, "life": 44, "speed": 3.6, "color": GROUND_DUST, "ground": true},
	],
	&"counter": [
		{"kind": FLASH, "color": Color(0.6, 0.85, 1.0), "size": 0.9, "life": 16},
	],
	&"disarm": [
		{"kind": FLASH, "color": Color.WHITE, "size": 1.3, "life": 20},
	],
}


## True when events of type `t` spawn effects.
static func has(t: StringName) -> bool:
	return TABLE.has(t)


## Whether event `e` is steel meeting steel: neither weapon it names is the
## bare hand (an event naming none counts as steel).
static func steel(e: Dictionary) -> bool:
	return StringName(str(e.get("weapon", ""))) != BARE and StringName(str(e.get("defender_weapon", ""))) != BARE


## Whether event `e` is a bare hand's strike: its attacker's weapon is the
## fists.
static func bare(e: Dictionary) -> bool:
	return StringName(str(e.get("weapon", ""))) == BARE


## The effects event `e` spawns, each a Dictionary with "kind" and its
## concrete fields (the entry's, with a heavy contact's and its parry kind's
## in their place). Empty for an event the table doesn't list.
static func resolve(e: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var is_steel: bool = steel(e)
	var kind: StringName = StringName(str(e.get("kind", "")))
	var heavy: bool = bool(e.get("heavy", false))
	for entry: Dictionary in TABLE.get(e.get("t", &""), []):
		if entry.has("steel") and bool(entry["steel"]) != is_steel:
			continue
		if entry.has("bare") and bool(entry["bare"]) != bare(e):
			continue
		if entry.has("kinds") and not (entry["kinds"] as Array).has(kind):
			continue
		var fx: Dictionary = {}
		for key: String in entry:
			if not ["steel", "kinds", "by_kind", "heavy"].has(key):
				fx[key] = entry[key]
		if heavy and entry.has("heavy"):
			fx.merge(entry["heavy"], true)
		if entry.has("by_kind") and (entry["by_kind"] as Dictionary).has(kind):
			fx.merge(entry["by_kind"][kind], true)
		out.append(fx)
	return out


## How many effects of kind `fx_kind` event `e` spawns (0 without).
static func count_of(e: Dictionary, fx_kind: StringName) -> int:
	var n: int = 0
	for fx: Dictionary in resolve(e):
		if fx["kind"] == fx_kind:
			n += int(fx.get("count", 1))
	return n
