class_name EffectTable
extends RefCounted
## Which combat effects each rules event spawns (plan task 18). The table is
## data: an event type maps to a list of effect entries, and resolve() turns
## an event into concrete effects for CombatEffects to spawn at the event's
## "pos". The camera's shake and field-of-view kicks and the fighters' body
## flashes stay in MatchView; this table holds what CombatEffects draws.
##
## An entry is a Dictionary with a "kind" and that kind's fields:
## - &"flash": a glow sprite that grows and fades (CombatEffects.flash()).
##   "color" (a Color, or "color_by" naming an event field and a Dictionary
##   from its values to colours, with "color" as the fallback), "size" (a
##   float, or "size_heavy" too for heavy contacts), "life" in world frames.
##
## Today it holds the contact flashes task 6 drew; 18.4 on add sparks, ink
## splashes, rings and the rest.

const FLASH: StringName = &"flash"

const TABLE: Dictionary[StringName, Array] = {
	&"hit": [
		{"kind": FLASH, "color": Color(1.0, 0.55, 0.3), "size": 0.45, "size_heavy": 0.7, "life": 10},
	],
	&"block": [
		{"kind": FLASH, "color": Color(1.0, 0.88, 0.6), "size": 0.45, "size_heavy": 0.6, "life": 10},
	],
	&"parry": [
		{
			"kind": FLASH, "color": Color(1.0, 0.95, 0.75), "size": 1.0, "life": 18,
			"color_by": &"kind",
			"colors": {&"flash": Color(0.6, 0.85, 1.0), &"redirect": Color(0.48, 1.0, 0.84)},
		},
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


## The effects event `e` spawns, each a Dictionary with "kind" and concrete
## values: for a flash, "color", "size" and "life". Empty for an event the
## table doesn't list.
static func resolve(e: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in TABLE.get(e.get("t", &""), []):
		match entry["kind"]:
			FLASH:
				out.append({
					"kind": FLASH,
					"color": _color(entry, e),
					"size": float(entry["size_heavy"]) if e.get("heavy", false) and entry.has("size_heavy") else float(entry["size"]),
					"life": int(entry["life"]),
				})
	return out


static func _color(entry: Dictionary, e: Dictionary) -> Color:
	if entry.has("color_by"):
		var colors: Dictionary = entry["colors"]
		var key: Variant = e.get(entry["color_by"], null)
		if colors.has(key):
			return colors[key]
	return entry["color"]
