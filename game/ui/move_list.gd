class_name MoveList
extends RefCounted
## A weapon's move list, read from its move data (22.13), for the How to play
## screen's weapon tabs (22.14) and the pause menu's move list (22.15). No
## nodes: plain rows the screens lay out.
##
## Every move a fighter can reach with the weapon is one row, in sections:
## - Strings: walked from the light and heavy starters through each move's
##   light and heavy follow-ups and the Iai's draw to the side (its release
##   variant). A move's input is the shortest way in, named in action words
##   ("Light → Light → Heavy"); the other moves that lead into it are in
##   also_after. Rows read light first, then each branch: a move's light
##   follow-up, its release variant, then its heavy follow-up.
## - Movement attacks: sprint, dodge, backstep and jump with light and heavy.
## - Block abilities: every ability the weapon offers (the loadout picks two).
## - Counter: the counter lunge after a slam is back-dashed.
## - Ultimate: the weapon's scripted ultimate, its hits added up; bare hands
##   choose Recall (light) or Breaker Palm (heavy) instead.
##
## Reach is the move's own (AttackDef.reach(): its swing's once it has one,
## else the authored range); a row with no number holds NAN.

enum Section { STRING, MOVEMENT, ABILITY, COUNTER, ULTIMATE }

const SECTION_NAMES: Array[String] = ["Strings", "Movement attacks", "Block abilities", "Counter", "Ultimate"]

const ARROW: String = " → "
const LIGHT: String = "Light"
const HEAVY: String = "Heavy"
## A heavy drawn with the stick held left or right (a release variant).
const TO_THE_SIDE: String = " + left/right"
const ULTIMATE_INPUT: String = "Light + heavy at 25% health"
## Bare hands' ultimate choice that brings the weapon back: no move of its own.
const RECALL: StringName = &"recall"

## The scripted ultimates' hits in Moves.ULT_HITS, in order, with how many
## times each lands when all of it connects, and a word on how it plays.
static var ULTIMATES: Dictionary[StringName, Dictionary] = {
	&"moonsplitter": {
		"hits": [[&"u_moon_v", 1]],
		"note": "a wave across the arena; with left or right it runs low, to be jumped",
	},
	&"impaler": {
		"hits": [[&"u_impale", 1], [&"u_burst", 1]],
		"note": "dashes in and impales, then bursts",
	},
	&"tempest": {
		"hits": [[&"u_tempest", SimConst.TEMPEST_SPINS], [&"u_tempest_final", 1]],
		"note": "flashes in for %d spins and a finisher; each can be parried" % SimConst.TEMPEST_SPINS,
	},
}

## Key steps that order a string's rows: a light follow-up, the release
## variant, then the heavy follow-up.
const _STEP_LIGHT: int = 0
const _STEP_VARIANT: int = 1
const _STEP_HEAVY: int = 2


class Row:
	extends RefCounted
	var section: Section = Section.STRING
	## The input in action words.
	var input: String = ""
	## The move's id; the ultimate's id for a scripted ultimate, RECALL for
	## Recall.
	var move_id: StringName = &""
	var name: String = ""
	var damage: float = NAN
	var posture: float = NAN
	## m from the attacker's centre to the target's surface.
	var reach: float = NAN
	var unblockable: bool = false
	## The counter that beats it (thrust, sweep, slam), or &"".
	var counter: StringName = &""
	## The names of the other moves it follows from, in row order.
	var also_after: PackedStringArray = []
	## A short word on how it's done or what it does, or "".
	var note: String = ""
	## A scripted ultimate's hits, in order (a hit that lands n times is in n
	## times); empty for other rows.
	var hits: Array[AttackDef] = []
	## Sorts the rows within a section.
	var key: PackedInt32Array = []


static func rows(w: WeaponDef) -> Array[Row]:
	var out: Array[Row] = _walk(w)
	out.sort_custom(_before)
	_fill_also_after(w, out)
	out.append_array(_ultimate_rows(w))
	return out


## Breadth first from every way into a move, so each move is reached first by
## its shortest input; a release variant takes its move's place in the queue.
static func _walk(w: WeaponDef) -> Array[Row]:
	var queue: Array[Row] = []
	var roots: Array = [
		[Section.STRING, w.light_start, LIGHT],
		[Section.STRING, w.heavy_start, HEAVY],
		[Section.MOVEMENT, w.sprint_light, "Sprint + light"],
		[Section.MOVEMENT, w.sprint_heavy, "Sprint + heavy"],
		[Section.MOVEMENT, w.dodge_light, "Dodge + light"],
		[Section.MOVEMENT, w.dodge_heavy, "Dodge + heavy"],
		[Section.MOVEMENT, w.back_light, "Backstep + light"],
		[Section.MOVEMENT, w.back_heavy, "Backstep + heavy"],
		[Section.MOVEMENT, w.jump_light, "Jump + light"],
		[Section.MOVEMENT, w.jump_heavy, "Jump + heavy"],
	]
	for ability: StringName in w.abilities:
		roots.append([Section.ABILITY, ability, "Block + light or heavy"])
	roots.append([Section.COUNTER, Moves.COUNTER_LUNGE.get(w.id, &""), "Back-dash a slam" + ARROW + LIGHT])
	for i: int in roots.size():
		var root: Array = roots[i]
		queue.append(_row(w, root[0], root[1], [root[2]] as Array[String], PackedInt32Array([i])))
	var out: Array[Row] = []
	var seen: Dictionary = {}
	while not queue.is_empty():
		var r: Row = queue.pop_front()
		if r == null or seen.has(r.move_id):
			continue
		seen[r.move_id] = true
		out.append(r)
		var m: AttackDef = w.moves[r.move_id]
		var tokens: Array[String] = _tokens(r)
		if m.release_variant != &"":
			var drawn: Array[String] = tokens.duplicate()
			drawn[-1] += TO_THE_SIDE
			queue.push_front(_row(w, r.section, m.release_variant, drawn, _key(r, _STEP_VARIANT)))
		if m.chain_light != &"":
			queue.append(_row(w, r.section, m.chain_light, _then(tokens, LIGHT), _key(r, _STEP_LIGHT)))
		if m.chain_heavy != &"":
			queue.append(_row(w, r.section, m.chain_heavy, _then(tokens, HEAVY), _key(r, _STEP_HEAVY)))
	return out


## A row for a move, or null when the weapon has no such move.
static func _row(w: WeaponDef, section: Section, move_id: StringName, tokens: Array[String], key: PackedInt32Array) -> Row:
	if move_id == &"" or not w.moves.has(move_id):
		return null
	var m: AttackDef = w.moves[move_id]
	var r: Row = Row.new()
	r.section = section
	r.move_id = move_id
	r.input = ARROW.join(tokens)
	r.key = key
	r.name = m.name
	r.damage = m.damage
	r.posture = m.posture
	r.reach = m.reach()
	r.unblockable = m.unblockable
	r.counter = m.counter
	if m.chargeable:
		r.note = "hold to charge; walk in the stance" if m.charge_move else "hold to charge"
	return r


static func _tokens(r: Row) -> Array[String]:
	var out: Array[String] = []
	out.assign(r.input.split(ARROW))
	return out


static func _then(tokens: Array[String], next: String) -> Array[String]:
	var out: Array[String] = tokens.duplicate()
	out.append(next)
	return out


static func _key(r: Row, step: int) -> PackedInt32Array:
	var k: PackedInt32Array = r.key.duplicate()
	k.append(step)
	return k


## Section order, then within a section by key: a move before its follow-ups,
## light before the release variant before heavy.
static func _before(a: Row, b: Row) -> bool:
	if a.section != b.section:
		return a.section < b.section
	for i: int in mini(a.key.size(), b.key.size()):
		if a.key[i] != b.key[i]:
			return a.key[i] < b.key[i]
	return a.key.size() < b.key.size()


## Every other listed move whose light or heavy follow-up a row is, in row
## order (the move its input comes through is left out).
static func _fill_also_after(w: WeaponDef, out: Array[Row]) -> void:
	var by_id: Dictionary = {}
	for r: Row in out:
		by_id[r.move_id] = r
	for r: Row in out:
		var m: AttackDef = w.moves[r.move_id]
		for next: StringName in [m.chain_light, m.chain_heavy]:
			if next == &"" or not by_id.has(next):
				continue
			var target: Row = by_id[next]
			var via: PackedInt32Array = target.key.slice(0, target.key.size() - 1)
			if target.section != r.section or via != r.key:
				target.also_after.append(r.name)


static func _ultimate_rows(w: WeaponDef) -> Array[Row]:
	var out: Array[Row] = []
	if w.ultimate == &"disarmed":
		var recall: Row = Row.new()
		recall.section = Section.ULTIMATE
		recall.move_id = RECALL
		recall.name = "Recall"
		recall.input = ULTIMATE_INPUT + ARROW + LIGHT
		recall.note = "your weapon flies back to your hand"
		out.append(recall)
		for move_id: StringName in w.moves:
			var m: AttackDef = w.moves[move_id]
			if m.kind == &"ultimate":
				var palm: Row = _row(w, Section.ULTIMATE, move_id, [ULTIMATE_INPUT, HEAVY] as Array[String], PackedInt32Array())
				out.append(palm)
		return out
	if not ULTIMATES.has(w.ultimate):
		return out
	var spec: Dictionary = ULTIMATES[w.ultimate]
	var u: Row = Row.new()
	u.section = Section.ULTIMATE
	u.move_id = w.ultimate
	u.input = ULTIMATE_INPUT
	u.note = spec["note"]
	u.damage = 0.0
	u.posture = 0.0
	for entry: Array in spec["hits"]:
		var hit: AttackDef = Moves.ULT_HITS[entry[0]]
		for n: int in int(entry[1]):
			u.hits.append(hit)
			u.damage += hit.damage
			u.posture += hit.posture
	u.name = u.hits[0].name
	u.unblockable = u.hits[0].unblockable
	out.append(u)
	return out
