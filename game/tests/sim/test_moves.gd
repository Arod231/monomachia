extends GutTest
## Checks every field of every weapon and move against the TypeScript data after
## finalizeMoves (game/tests/fixtures/moves.json, written by
## scripts/sim-fixtures.ts), apart from the rebuild's deliberate changes (the
## changes table, the moves the new strings added or moved, and the fields the
## demo didn't have). The fixture has the TS camelCase keys; a missing key was
## undefined in the TS and must hold the port's sentinel. It also checks the
## values the fields may hold, and that a release variant keeps its move's
## frames.

## The sentinel each optional field holds when the TS leaves it undefined
## (see attack_def.gd).
const UNSET: Dictionary = {
	"min_range": 0.0,
	"lunge": 0.0,
	"lunge_start": 0,
	"lunge_end": AttackDef.UNSET,
	"unblockable": false,
	"counter": &"",
	"jumpable": false,
	"undodgeable": false,
	"power": false,
	"chain_light": &"",
	"chain_heavy": &"",
	"dodge_cancel_from": AttackDef.UNSET,
	"multi_hit": 0,
	"multi_interval": AttackDef.UNSET,
	"airborne": false,
	"guard_crush": NAN,
	"special": &"",
	"chargeable": false,
	"sound": &"",
	"invuln": [],
	"hop": 0.0,
	"charge_move": false, # the rebuild's, not the TS's (9.3): only the Iai, an added move, has it
	"release_variant": &"", # the rebuild's, not the TS's (9.4): only the Iai has one
	"lunge_along_dodge": false, # the rebuild's, not the TS's (11.3): only Passing Cut, an added move, has it
}

## The demo's data that the rebuild changed on purpose, one row per rule: a
## move of this kind whose field held "was" in the TS (the port's sentinel
## where the TS left it unset) now holds "now", a value or a function of the
## move's TS record (with its MOVE_CHANGES applied). Every move and field no
## row here or in MOVE_CHANGES covers still matches the demo. (A static var,
## as a const can't hold a function.)
static var changes: Array[Dictionary] = [
	# 8.7: the lights' default hitstun (bare hands keep their own 16)
	{"field": "hitstun", "kind": "light", "was": 18, "now": 14},
	# 8.8: heavies dodge-cancel from startup + active + half the recovery,
	# rounded up (the demo gave them no cancel)
	{
		"field": "dodge_cancel_from", "kind": "heavy", "was": AttackDef.UNSET,
		"now": func(ts: Dictionary) -> int: return int(ts["startup"]) + int(ts["active"]) + ceili(float(ts["recovery"]) / 2.0),
	},
]

## The demo's moves the new strings changed, one row per field: the move (by
## its id now) whose field held "was" in the TS now holds "now". They apply
## before the rules' rows, so a rule computed from the move (the heavies'
## dodge cancel) uses its new numbers.
const MOVE_CHANGES: Array[Dictionary] = [
	# 9.1: the Katana's four-light string; Right Cut ends on Heaven Splitter,
	# Crown Cut ends the string, and the two heavy follow-ups start sooner
	# (their lunges end two frames after their cuts start, as before)
	{"move": "k_l1", "field": "chain_heavy", "was": "k_h1f", "now": "k_h2"},
	{"move": "k_l4", "field": "chain_heavy", "was": "k_h2", "now": ""},
	{"move": "k_h1f", "field": "startup", "was": 18, "now": 16},
	{"move": "k_h1f", "field": "lunge_end", "was": 20, "now": 18},
	{"move": "k_h2", "field": "startup", "was": 24, "now": 22},
	{"move": "k_h2", "field": "lunge_end", "was": 26, "now": 24},
	# 10.1: the Greatsword's L-L-H; Backswing starts sooner (its lunge and
	# dodge cancel keeping pace), both lights end on Overhead Strike, which
	# Crushing Blow becomes, with no light follow-up
	{"move": "g_l1", "field": "chain_heavy", "was": "g_h2", "now": "g_h1"},
	{"move": "g_l2", "field": "startup", "was": 13, "now": 11},
	{"move": "g_l2", "field": "lunge_end", "was": 14, "now": 12},
	{"move": "g_l2", "field": "dodge_cancel_from", "was": 25, "now": 23},
	{"move": "g_l2", "field": "chain_heavy", "was": "g_h2", "now": "g_h1"},
	{"move": "g_h1", "field": "name", "was": "Crushing Blow", "now": "Overhead Strike"},
	{"move": "g_h1", "field": "type", "was": "slash", "now": "overhead"},
	{"move": "g_h1", "field": "anim", "was": "diagDown", "now": "overhead"},
	{"move": "g_h1", "field": "chain_light", "was": "g_l2", "now": ""},
	# 11.1: the Daggers' four lights dodge-cancel from their first recovery
	# frame and stun for 10, so the next can be blocked or parried; Twin Rip
	# loses its heavy follow-up, and Twin Fang its light one, the loop back to
	# Quick Slice, which broke continuity
	{"move": "d_l1", "field": "dodge_cancel_from", "was": 13, "now": 10},
	{"move": "d_l2", "field": "dodge_cancel_from", "was": 13, "now": 10},
	{"move": "d_l3", "field": "dodge_cancel_from", "was": 16, "now": 13},
	{"move": "d_l4", "field": "dodge_cancel_from", "was": AttackDef.UNSET, "now": 15},
	{"move": "d_l3", "field": "chain_heavy", "was": "d_h1", "now": ""},
	{"move": "d_h1", "field": "chain_light", "was": "d_l1", "now": ""},
	{"move": "d_l1", "field": "hitstun", "was": 18, "now": 10},
	{"move": "d_l2", "field": "hitstun", "was": 18, "now": 10},
	{"move": "d_l3", "field": "hitstun", "was": 18, "now": 10},
	{"move": "d_l4", "field": "hitstun", "was": 18, "now": 10},
	# 11.2: Twin Fang dashes 1.4 m, and the spin after it is Spinning Backhand
	{"move": "d_h1", "field": "lunge", "was": 0.8, "now": 1.4},
	{"move": "d_h2", "field": "name", "was": "Gutting Spiral", "now": "Spinning Backhand"},
	# authored animation 9: Right Cut baked from Attack1H01_R first touches a
	# defender at the duelling distance on frame 13, its last but one active
	# frame, where its lunge now ends (test_duel_reach)
	{"move": "k_l1", "field": "lunge_end", "was": 12, "now": 13},
	# authored animation 10: Return Cut (Attack1H03_R) and Crown Cut
	# (Attack2H02) reach less far than their cones; their lunges grow so a
	# push of at most 15 cm puts 17.5 cm into a defender at the duelling
	# distance, Crown Cut's ending on its first touch, frame 15
	{"move": "k_l2", "field": "lunge", "was": 0.35, "now": 0.45},
	{"move": "k_l4", "field": "lunge", "was": 0.5, "now": 0.7},
	{"move": "k_l4", "field": "lunge_end", "was": 16, "now": 15},
	# authored animation 11: the heavies' clips reach far less than their
	# cones, so their lunges carry them to a touch from the heavies' test
	# distance (3.0 m): Rising Heaven (Attack1H05_R) and Heaven Splitter
	# (Attack2H04)
	{"move": "k_h1f", "field": "lunge", "was": 0.5, "now": 1.2},
	{"move": "k_h2", "field": "lunge", "was": 0.7, "now": 0.95},
	# authored animation 12: the movement attacks' clips reach less far than
	# their cones, so their lunges carry them to a touch from their test
	# distances (the sprint attacks 4.0 and 5.0 m, the dodge attacks 2.5, the
	# back attacks 3.0 and 4.5)
	{"move": "k_sl", "field": "lunge", "was": 1.6, "now": 1.7},
	{"move": "k_sh", "field": "lunge", "was": 2.6, "now": 2.9},
	{"move": "k_dl", "field": "lunge", "was": 0.4, "now": 0.5},
	{"move": "k_dh", "field": "lunge", "was": 0.3, "now": 0.5},
	{"move": "k_bl", "field": "lunge", "was": 0.8, "now": 1.25},
	{"move": "k_bh", "field": "lunge", "was": 2.2, "now": 2.3},
	# authored animation 13: the unblockables' clips (AttackPolearm01 and
	# Attack2H03) reach less far than their cones, so their lunges carry them
	# to a touch from the unblockables' test distance (3.5 m)
	{"move": "k_thrust", "field": "lunge", "was": 1.0, "now": 1.4},
	{"move": "k_sweep", "field": "lunge", "was": 0.4, "now": 1.4},
	# authored animation 18: the Greatsword's lights (Attack2H01 and its
	# mirror) reach less far than their cones, so their lunges grow so a push
	# of at most 15 cm puts 17.5 cm into a defender at the duelling distance
	# (3.0 m), Heavy Swing's ending on its first touch, frame 16; Overhead
	# Strike (Attack2H02) reaches 3.5 m with a longer lunge, and its clip ends
	# 3 frames sooner (Piercing Lunge, an added move, is in its strings test)
	{"move": "g_l1", "field": "lunge", "was": 0.4, "now": 0.45},
	{"move": "g_l1", "field": "lunge_end", "was": 15, "now": 16},
	{"move": "g_l2", "field": "lunge", "was": 0.4, "now": 0.55},
	{"move": "g_h1", "field": "lunge", "was": 0.7, "now": 1.05},
	{"move": "g_h1", "field": "recovery", "was": 32, "now": 29},
	# authored animation 19: the Greatsword's movement attacks and Guard
	# Crusher reach less far on their clips than their cones, so their lunges
	# carry them to a touch from their test distances (sprint 4.5 and 5.5 m,
	# back 3.5 and 5.0, the ability 3.0); the bashes strike with the left
	# shoulder
	{"move": "g_sl", "field": "lunge", "was": 2.2, "now": 3.35},
	{"move": "g_sh", "field": "lunge", "was": 3.0, "now": 3.15},
	{"move": "g_bl", "field": "lunge", "was": 0.9, "now": 1.15},
	{"move": "g_bh", "field": "lunge", "was": 2.2, "now": 2.35},
	{"move": "g_crush", "field": "lunge", "was": 1.6, "now": 1.85},
	# authored animation 20: Reaping Sweep (AttackPolearm04's spin) and
	# Mountain Slam (AttackPolearm03) reach less far than their cones, so
	# their lunges carry them to a touch from the unblockables' test distance
	# (4.0 m; Low Sweep, an added move, is in its strings test)
	{"move": "g_sweep", "field": "lunge", "was": 0.3, "now": 1.65},
	{"move": "g_slam", "field": "lunge", "was": 0.6, "now": 1.35},
	# authored animation 21: the Daggers' lights (Attack1H01_R and _L,
	# AttackDW01 and 02) reach further on their clips than their cones put
	# them, the whole dagger inside a defender at the duelling distance (2.0
	# m), so their lunges shorten to put 17.5 cm in, each ending on its first
	# touch; Spinning Backhand's spin (AttackPolearm04) falls short of 2.5 m,
	# so its lunge grows
	{"move": "d_l1", "field": "lunge", "was": 0.3, "now": 0.15},
	{"move": "d_l1", "field": "lunge_end", "was": AttackDef.UNSET, "now": 8},
	{"move": "d_l2", "field": "lunge", "was": 0.3, "now": 0.17},
	{"move": "d_l2", "field": "lunge_end", "was": AttackDef.UNSET, "now": 8},
	{"move": "d_l3", "field": "lunge", "was": 0.4, "now": 0.38},
	{"move": "d_l3", "field": "lunge_end", "was": AttackDef.UNSET, "now": 11},
	{"move": "d_l4", "field": "lunge", "was": 0.6, "now": 0.35},
	{"move": "d_l4", "field": "lunge_end", "was": AttackDef.UNSET, "now": 13},
	{"move": "d_h2", "field": "lunge", "was": 0.4, "now": 1.1},
	# authored animation 22: Slide Slash (Attack1H01_R's cut over
	# RunSlide01), Reverse Spin (AttackPolearm04 mirrored) and Flick
	# (AttackPunch02_L) reach less far than their cones, so their lunges carry
	# them to a touch from their test distances (sprint 3.5 m, dodge 2.0, back
	# 2.5)
	{"move": "d_sl", "field": "lunge", "was": 2.0, "now": 2.2},
	{"move": "d_dh", "field": "lunge", "was": 0.0, "now": 0.45},
	{"move": "d_bl", "field": "lunge", "was": 0.5, "now": 0.95},
	# authored animation 23: Needle Thrust (AttackPolearm01, its pull-back
	# held) reaches less far than its cone, so its lunge carries it to a touch
	# from the unblockables' test distance (3.0 m)
	{"move": "d_needle", "field": "lunge", "was": 0.8, "now": 1.15},
	# authored animation 24: the punches. Bare hands' lights are measured by
	# how deep the fist goes (15-20 cm at 1.6 m; its knuckles are shorter than
	# the rule's 15-20 cm of blade), each lunge ending on its first touch:
	# Hook's looping AttackPunch01_L steps in by itself; Lunging Palm's
	# AttackPunch01_R falls short of 3.6 m
	{"move": "f_l1", "field": "lunge_end", "was": AttackDef.UNSET, "now": 6},
	{"move": "f_l2", "field": "lunge", "was": 0.3, "now": 0.27},
	{"move": "f_l2", "field": "lunge_end", "was": AttackDef.UNSET, "now": 7},
	{"move": "f_l3", "field": "lunge", "was": 0.3, "now": 0.07},
	{"move": "f_l3", "field": "lunge_end", "was": AttackDef.UNSET, "now": 9},
	{"move": "f_bh", "field": "lunge", "was": 1.8, "now": 1.9},
	# authored animation 25: the kicks and Breaker Palm. Snap Kick and Axe
	# Kick kick with the left leg (AttackKick01_L), which the bake reads from
	# the side; Breaker Palm's crouch-and-uppercut falls short of 4.1 m
	{"move": "f_bl", "field": "hand", "was": &"R", "now": &"L"},
	{"move": "f_jh", "field": "hand", "was": &"R", "now": &"L"},
	{"move": "f_breaker", "field": "lunge", "was": 2.5, "now": 2.95},
]

## Moves the new strings added, with no demo move to compare with: each
## weapon's strings test checks them against the spec's table. A move that
## took a removed demo move's id is in REMOVED too.
const ADDED: Array[StringName] = [
	&"k_l3", # 9.1: Kesa Cut, the third light
	&"k_iai", # 9.2: the Iai Slash (vertical), the heavy
	&"k_iai_h", # 9.4: the Iai Slash (horizontal), its release variant
	&"k_rdraw", # 9.5: Returning Draw, the horizontal Iai's heavy follow-up
	&"g_h2", # 10.2: Low Sweep, Overhead Strike's heavy follow-up, under Earthbreaker's id
	&"g_dl", # 10.3: Piercing Lunge, the light out of a dodge, under Pommel Strike's id
	&"g_dh", # 10.3: Skewer, the heavy out of a dodge, under Cyclone's id
	&"d_dl", # 11.3: Passing Cut, the light out of a dodge, under Ghost Cut's id
]

## Demo moves the new strings removed (one whose id a new move took is in
## ADDED too).
const REMOVED: Array[StringName] = [
	&"k_h1", # 9.2: Kesa Giri, the heavy before the Iai Slash
	&"g_h2", # 10.2: Earthbreaker, whose id Low Sweep took
	&"g_dl", # 10.3: Pommel Strike, whose id Piercing Lunge took
	&"g_dh", # 10.3: Cyclone, whose id Skewer took
	&"d_dl", # 11.3: Ghost Cut, whose id Passing Cut took
]

## Demo moves the new strings gave a new id: their id now -> the demo's.
const MOVED: Dictionary[StringName, StringName] = {
	&"k_l4": &"k_l3", # 9.1: Crown Cut, now the fourth light
}

## Weapon fields the new strings changed, one row per field: the weapon's
## field held "was" in the TS and now holds "now".
const WEAPON_CHANGES: Array[Dictionary] = [
	{"weapon": "katana", "field": "heavy_start", "was": "k_h1", "now": "k_iai"}, # 9.2: the Iai Slash
]

## Fields the demo didn't have that its moves now hold: the strings and
## continuity tests check them. (charge_move, release_variant and
## lunge_along_dodge, which no demo move holds, are in UNSET instead, so a demo
## move given one fails here.)
const REBUILD_FIELDS: Array[String] = ["side_start", "side_end"]

## The swing (task 7), which the swing tests check as moves get one.
const SWING_FIELDS: Array[String] = ["swing"]
## Weapon fields the demo didn't have: tests/sim/test_duel_reach.gd checks the
## duelling distances, and tests/content/test_strike_segments.gd the rest
## against the models.
const WEAPON_REBUILD_FIELDS: Array[String] = ["duel_distance", "blade", "foot", "off_hand_grip"]

var _fx: Dictionary


func before_all() -> void:
	_fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/moves.json"))


## Brings a GDScript or JSON value to a common form: numbers as float, names as
## String, arrays as plain Arrays.
static func _norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT:
			return float(v)
		TYPE_STRING_NAME:
			return String(v)
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY:
			var out: Array = []
			for e: Variant in v:
				out.append(_norm(e))
			return out
	return v


static func _same(a: Variant, b: Variant) -> bool:
	var na: Variant = _norm(a)
	var nb: Variant = _norm(b)
	if typeof(na) == TYPE_FLOAT and typeof(nb) == TYPE_FLOAT and is_nan(na) and is_nan(nb):
		return true # the NAN sentinel
	return typeof(na) == typeof(nb) and na == nb


## The value a move's field should hold: its TS value (or sentinel), or a
## changes row's.
static func _wanted(ts: Dictionary, field: String, ts_value: Variant) -> Variant:
	for row: Dictionary in changes:
		if row["field"] == field and _same(ts.get("kind"), row["kind"]) and _same(ts_value, row["was"]):
			var now: Variant = row["now"]
			return (now as Callable).call(ts) if now is Callable else now
	return ts_value


## The TS record of the demo move now called id, with its id now and its
## MOVE_CHANGES applied.
static func _rebuilt(ts: Dictionary, id: StringName) -> Dictionary:
	var out: Dictionary = ts.duplicate()
	out["id"] = String(id)
	for row: Dictionary in MOVE_CHANGES:
		if row["move"] == String(id):
			out[String(row["field"]).to_camel_case()] = row["now"]
	return out


## The value a weapon's field should hold: its TS value, or its
## WEAPON_CHANGES row's.
static func _weapon_wanted(wid: String, field: String, ts_value: Variant) -> Variant:
	# a weapon's reach is its light starter's swing's once it has a hand-keyed
	# one (7.13); one baked from a clip leaves the authored reach (authored
	# animation 20)
	var w: WeaponDef = Moves.WEAPONS.get(StringName(wid))
	var starter: AttackDef = w.moves[w.light_start] if w != null else null
	if field == "reach" and starter != null and starter.swing != null and starter.swing.clips.is_empty():
		return (w.moves[w.light_start] as AttackDef).swing.reach
	for row: Dictionary in WEAPON_CHANGES:
		if row["weapon"] == wid and row["field"] == field:
			return row["now"]
	return ts_value


## Compares one AttackDef with its TS record; returns the differences.
func _diff_move(where: String, m: AttackDef, ts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if m == null:
		return ["%s: missing in GDScript" % where]
	var seen: Dictionary = {}
	for key: String in ts:
		var snake: String = key.to_snake_case()
		seen[snake] = true
		if not AttackDef.KEYS.has(snake):
			out.append("%s: TS field %s has no AttackDef field" % [where, key])
		else:
			var want: Variant = _wanted(ts, snake, ts[key])
			if not _same(m.get(snake), want):
				out.append("%s.%s: got %s, want %s" % [where, snake, m.get(snake), want])
	for snake: String in AttackDef.KEYS:
		if seen.has(snake) or REBUILD_FIELDS.has(snake) or SWING_FIELDS.has(snake):
			continue
		if not UNSET.has(snake):
			out.append("%s.%s: unset in TS but finalizeMoves should set it" % [where, snake])
		else:
			var want: Variant = _wanted(ts, snake, UNSET[snake])
			if not _same(m.get(snake), want):
				out.append("%s.%s: got %s, want %s (the TS left it unset)" % [where, snake, m.get(snake), want])
	return out


func test_every_attack_def_field_is_a_key() -> void:
	var props: Array[String] = []
	for p: Dictionary in AttackDef.new().get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props.append(String(p["name"]))
	assert_eq(props, AttackDef.KEYS)
	var wprops: Array[String] = []
	for p: Dictionary in WeaponDef.new().get_property_list():
		# authored_reach is the record's reach, kept for derive_reach()
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and String(p["name"]) != "authored_reach":
			wprops.append(String(p["name"]))
	assert_eq(wprops, WeaponDef.KEYS)


func test_registry_matches_the_typescript() -> void:
	var ts_weapons: Dictionary = _fx["WEAPONS"]
	assert_eq(_norm(Moves.WEAPONS.keys()), ts_weapons.keys())
	assert_eq(_norm(Moves.PLAYABLE_WEAPONS), _fx["PLAYABLE_WEAPONS"])
	var ts_lunge: Dictionary = _fx["COUNTER_LUNGE"]
	assert_eq(_norm(Moves.COUNTER_LUNGE.keys()), ts_lunge.keys())
	for w: StringName in Moves.COUNTER_LUNGE:
		assert_eq(String(Moves.COUNTER_LUNGE[w]), String(ts_lunge[String(w)]))
	assert_same(Moves.WEAPONS[&"katana"], Moves.KATANA)
	assert_same(Moves.WEAPONS[&"greatsword"], Moves.GREATSWORD)
	assert_same(Moves.WEAPONS[&"daggers"], Moves.DAGGERS)
	assert_same(Moves.WEAPONS[&"fists"], Moves.FISTS)


func test_every_weapon_field_matches_the_typescript() -> void:
	var ts_weapons: Dictionary = _fx["WEAPONS"]
	for wid: String in ts_weapons:
		var ts: Dictionary = ts_weapons[wid]
		var w: WeaponDef = Moves.WEAPONS.get(StringName(wid), null)
		assert_not_null(w, wid)
		if w == null:
			continue
		var diffs: Array[String] = []
		for key: String in ts:
			var snake: String = key.to_snake_case()
			if not WeaponDef.KEYS.has(snake):
				diffs.append("%s: TS field %s has no WeaponDef field" % [wid, key])
			elif snake != "moves":
				var want: Variant = _weapon_wanted(wid, snake, ts[key])
				if not _same(w.get(snake), want):
					diffs.append("%s.%s: got %s, want %s" % [wid, snake, w.get(snake), want])
		for snake: String in WeaponDef.KEYS:
			if not ts.has(snake.to_camel_case()) and not WEAPON_REBUILD_FIELDS.has(snake):
				diffs.append("%s.%s: not in the TS weapon" % [wid, snake])
		assert_eq(diffs, [] as Array[String], wid)


func test_every_move_of_every_weapon_matches_the_typescript() -> void:
	var ts_weapons: Dictionary = _fx["WEAPONS"]
	var compared: int = 0
	for wid: String in ts_weapons:
		var ts_moves: Dictionary = ts_weapons[wid]["moves"]
		var w: WeaponDef = Moves.WEAPONS[StringName(wid)]
		var demo_ids: Array = []
		for id: StringName in w.moves:
			if not ADDED.has(id):
				demo_ids.append(String(MOVED.get(id, id)))
		var kept: Array = ts_moves.keys().filter(func(id: String) -> bool: return not REMOVED.has(StringName(id)))
		assert_eq(demo_ids, kept, "%s: the demo's moves, in order, besides the added and removed ones" % wid)
		var diffs: Array[String] = []
		for id: StringName in w.moves:
			var demo_id: String = String(MOVED.get(id, id))
			if ADDED.has(id) or not ts_moves.has(demo_id):
				continue
			diffs.append_array(_diff_move("%s.%s" % [wid, id], w.moves[id], _rebuilt(ts_moves[demo_id], id)))
			compared += 1
		assert_eq(diffs, [] as Array[String], wid)
	# the demo's 18 katana + 16 greatsword + 18 daggers + 15 fists, less the removed
	assert_eq(compared, 67 - REMOVED.size())


func test_every_move_change_starts_from_the_demos_value() -> void:
	var ts_weapons: Dictionary = _fx["WEAPONS"]
	for row: Dictionary in MOVE_CHANGES:
		var id := StringName(row["move"])
		var field: String = row["field"]
		var demo: Variant = "no demo move"
		for wid: String in ts_weapons:
			var demo_id: String = String(MOVED.get(id, id))
			if Moves.WEAPONS[StringName(wid)].moves.has(id) and not ADDED.has(id) and ts_weapons[wid]["moves"].has(demo_id):
				demo = ts_weapons[wid]["moves"][demo_id].get(field.to_camel_case(), UNSET.get(field))
		assert_true(_same(demo, row["was"]), "%s.%s: the row says the demo had %s; it had %s" % [id, field, row["was"], demo])


func test_every_weapon_change_starts_from_the_demos_value() -> void:
	var ts_weapons: Dictionary = _fx["WEAPONS"]
	for row: Dictionary in WEAPON_CHANGES:
		var field: String = row["field"]
		var demo: Variant = ts_weapons.get(row["weapon"], {}).get(field.to_camel_case(), "no demo field")
		assert_true(_same(demo, row["was"]), "%s.%s: the row says the demo had %s; it had %s" % [row["weapon"], field, row["was"], demo])


func test_every_release_variant_has_its_moves_frames() -> void:
	# a variant swaps in mid-move, on the same attack state, so it must keep
	# its move's frames and lunge
	var variants: int = 0
	for wid: StringName in Moves.WEAPONS:
		var moves: Dictionary[StringName, AttackDef] = Moves.WEAPONS[wid].moves
		for id: StringName in moves:
			var m: AttackDef = moves[id]
			if m.release_variant == &"":
				continue
			variants += 1
			var v: AttackDef = moves.get(m.release_variant, null)
			assert_not_null(v, "%s.%s's release variant %s is one of its moves" % [wid, id, m.release_variant])
			if v == null:
				continue
			assert_eq(
				[v.startup, v.active, v.recovery, v.lunge, v.lunge_start, v.lunge_end],
				[m.startup, m.active, m.recovery, m.lunge, m.lunge_start, m.lunge_end],
				"%s.%s and its variant %s: frames and lunge" % [wid, id, v.id],
			)
	assert_gt(variants, 0, "the Iai has a variant")


func test_every_ultimate_hit_matches_the_typescript() -> void:
	var ts_hits: Dictionary = _fx["ULT_HITS"]
	assert_eq(_norm(Moves.ULT_HITS.keys()), ts_hits.keys())
	var diffs: Array[String] = []
	for mid: String in ts_hits:
		diffs.append_array(_diff_move("ULT_HITS.%s" % mid, Moves.ULT_HITS.get(StringName(mid), null), ts_hits[mid]))
	assert_eq(diffs, [] as Array[String])
	assert_eq(ts_hits.size(), 6)


func test_finalize_keeps_u_impale_dodgeable() -> void:
	var impale: AttackDef = Moves.ULT_HITS[&"u_impale"]
	assert_true(impale.unblockable)
	assert_false(impale.undodgeable)
	assert_true(Moves.ULT_HITS[&"u_burst"].undodgeable)
	assert_true(Moves.KATANA.moves[&"k_thrust"].undodgeable)
	assert_eq(Moves.ULT_HITS[&"u_moon_v"].trail, &"danger")
	assert_eq(Moves.ULT_HITS[&"u_tempest"].trail, &"ult")


func test_values_are_in_their_unions() -> void:
	var all: Array[AttackDef] = []
	for w: WeaponDef in Moves.WEAPONS.values():
		all.append_array(w.moves.values())
		assert_true(WeaponDef.WEAPON_IDS.has(w.id), String(w.id))
		assert_true(WeaponDef.ULTIMATE_IDS.has(w.ultimate), String(w.ultimate))
		assert_true(WeaponDef.WEAPON_CLASSES.has(w.cls), String(w.cls))
	all.append_array(Moves.ULT_HITS.values())
	for m: AttackDef in all:
		assert_true(AttackDef.ATTACK_KINDS.has(m.kind), "%s kind" % m.id)
		assert_true(AttackDef.ATTACK_TYPES.has(m.type), "%s type" % m.id)
		assert_true(AttackDef.HANDS.has(m.hand), "%s hand" % m.id)
		assert_true(AttackDef.TRAILS.has(m.trail), "%s trail" % m.id)
		assert_true(m.counter == &"" or AttackDef.COUNTER_KINDS.has(m.counter), "%s counter" % m.id)
		assert_true(m.sound == &"" or AttackDef.HIT_SOUNDS.has(m.sound), "%s sound" % m.id)
		assert_true(m.special == &"" or AttackDef.SPECIALS.has(m.special), "%s special" % m.id)
		assert_true(m.side_start == &"" or AttackDef.SIDES.has(m.side_start), "%s side_start" % m.id)
		assert_true(m.side_end == &"" or AttackDef.SIDES.has(m.side_end), "%s side_end" % m.id)


func test_get_move_falls_back_to_ultimate_hits() -> void:
	assert_same(Moves.get_move(Moves.KATANA, &"k_l1"), Moves.KATANA.moves[&"k_l1"])
	assert_same(Moves.get_move(Moves.FISTS, &"u_burst"), Moves.ULT_HITS[&"u_burst"])
	assert_eq(Moves.KATANA.moves[&"k_l1"].total_frames(), 30)


func test_get_move_reports_an_unknown_move() -> void:
	assert_null(Moves.get_move(Moves.KATANA, &"g_l1"))
	assert_push_error("Unknown move g_l1 for katana")
