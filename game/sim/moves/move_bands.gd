class_name MoveBands
extends RefCounted
## The band tables (game/sim/moves/bands.json, milestone-1 task 18): the
## spec's timing band table and distance band table, one row per move kind
## per weapon (the kinds of the frame-data table, FrameDataRows.kind_of()),
## and the moves still waiting for their family's re-key. The band tests
## (tests/content/test_move_bands.gd) hold every Katana and bare-hands move
## off the waiting list to its kind's bands, and the Studio shows a move
## against them. The rules never read them.

const PATH: String = "res://sim/moves/bands.json"
const SECTIONS: Array[String] = ["timing", "distance", "waiting"]
## A timing band's fields, in the order they are checked and named:
## startup, from_stance (an Iai draw's startup from the stance's release:
## its startup less the charge check), active, recovery, landing (a jump
## attack's recovery once down, a field the frame-data table gains at task
## 59), to_wave (Moonsplitter's frames to its wave) and total (the recall).
const TIMING_FIELDS: Array[String] = ["startup", "from_stance", "active", "recovery", "landing", "to_wave", "total"]
## Kinds with no band test until milestone 2 re-keys them (the spec's P48).
const MILESTONE_2_KINDS: Array[StringName] = [&"counter_lunge"]

## weapon -> kind -> field -> [low, high] in rules frames.
var timing: Dictionary = {}
## weapon -> {"duel": m, "preferred": m, "misses_all": m (optional),
## "kinds": kind -> {"touches": m, "misses": m, "inside": [low, high] m}}.
var distance: Dictionary = {}
## weapon -> Array of the move ids waiting for their family.
var waiting: Dictionary = {}
## What is wrong with the file, one line each; empty when it read cleanly.
var errors: PackedStringArray = []

static var _shared: MoveBands = null


## One line of a move's distance check, as the Studio shows it.
class DistanceLine:
	## How far apart (m, centre to centre).
	var distance: float = 0.0
	## Whether the move must touch from there (else it must miss).
	var must_touch: bool = true
	var ok: bool = false
	## How much blade (or fist) went in (m), where the band asks; -1 if not
	## measured.
	var inside: float = -1.0
	## What happened, or what went wrong.
	var text: String = ""


## The committed band tables, read once.
static func shared() -> MoveBands:
	if _shared == null:
		_shared = read()
	return _shared


static func read(path: String = PATH) -> MoveBands:
	var b: MoveBands = MoveBands.new()
	if not FileAccess.file_exists(path):
		b.errors.append("%s is missing" % path)
		return b
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		b.errors.append("%s is not a JSON object" % path)
		return b
	for key: Variant in data:
		if key != "about" and not SECTIONS.has(str(key)):
			b.errors.append("unknown section %s" % key)
	for section: String in SECTIONS:
		if not (data as Dictionary).get(section) is Dictionary:
			b.errors.append("no %s" % section)
			return b
	b._read_timing(data["timing"])
	b._read_distance(data["distance"])
	for wid: Variant in data["waiting"]:
		var ids: Array[StringName] = []
		for id: Variant in data["waiting"][wid]:
			ids.append(StringName(str(id)))
		b.waiting[StringName(str(wid))] = ids
	return b


func _read_timing(src: Dictionary) -> void:
	for wid: Variant in src:
		var kinds: Dictionary = {}
		for kind: Variant in src[wid]:
			var band: Dictionary = {}
			for field: Variant in src[wid][kind]:
				var at: String = "timing.%s.%s.%s" % [wid, kind, field]
				if not TIMING_FIELDS.has(str(field)):
					errors.append("%s: unknown field" % at)
					continue
				var r: Variant = _range(src[wid][kind][field], at)
				if r != null:
					band[str(field)] = [int(r[0]), int(r[1])]
			kinds[StringName(str(kind))] = band
		timing[StringName(str(wid))] = kinds


func _read_distance(src: Dictionary) -> void:
	for wid: Variant in src:
		var w: Dictionary = src[wid]
		var out: Dictionary = {}
		for key: String in ["duel", "preferred", "misses_all"]:
			if w.has(key):
				out[key] = float(w[key])
		var kinds: Dictionary = {}
		for kind: Variant in w.get("kinds", {}):
			var band: Dictionary = (w["kinds"][kind] as Dictionary).duplicate()
			if band.has("inside"):
				var r: Variant = _range(band["inside"], "distance.%s.%s.inside" % [wid, kind])
				band["inside"] = r if r != null else [0.0, 0.0]
			kinds[StringName(str(kind))] = band
		out["kinds"] = kinds
		distance[StringName(str(wid))] = out


## `v` as [low, high], or null (with the mistake named) when it isn't one.
func _range(v: Variant, at: String) -> Variant:
	if v is Array and (v as Array).size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int) \
			and v[0] <= v[1]:
		return [v[0], v[1]]
	var shown: String = "[%s]" % ", ".join((v as Array).map(_num)) if v is Array else str(v)
	errors.append("%s: %s is not a range low to high" % [at, shown])
	return null


## A number read from JSON as written: 30, not 30.0.
static func _num(x: Variant) -> String:
	return str(int(x)) if (x is float or x is int) and float(x) == floorf(float(x)) else str(x)


## A kind's timing band (field -> [low, high]), or an empty Dictionary.
func timing_band(weapon: StringName, kind: StringName) -> Dictionary:
	return (timing.get(weapon, {}) as Dictionary).get(kind, {})


## A kind's distance band ("touches", "misses", "inside"), or an empty
## Dictionary.
func distance_band(weapon: StringName, kind: StringName) -> Dictionary:
	return ((distance.get(weapon, {}) as Dictionary).get("kinds", {}) as Dictionary).get(kind, {})


## Whether move `id` of `weapon` is still waiting for its family's re-key.
func is_waiting(weapon: StringName, id: StringName) -> bool:
	return (waiting.get(weapon, []) as Array).has(id)


## Whether the band tests hold move `id` of `weapon`, of `kind`, to its
## bands: a weapon with bands (the Katana and bare hands), a kind tested in
## milestone 1, and off the waiting list.
func is_held(weapon: StringName, id: StringName, kind: StringName) -> bool:
	return timing.has(weapon) and not MILESTONE_2_KINDS.has(kind) and not is_waiting(weapon, id)


## What move `id` of `weapon`, as its frame-data table `row` gives it, gets
## wrong against its kind's timing band, one line each; nothing when it lands
## in band.
func timing_problems(weapon: StringName, id: StringName, row: Dictionary) -> Array[String]:
	var at: String = "%s.%s" % [weapon, id]
	if row.is_empty():
		return ["%s: no row in the frame-data table" % at] as Array[String]
	var kind: StringName = StringName(str(row.get("kind", "")))
	at += " (%s)" % kind
	var band: Dictionary = timing_band(weapon, kind)
	if band.is_empty():
		return ["%s: no timing band" % at] as Array[String]
	var out: Array[String] = []
	for field: String in TIMING_FIELDS:
		if not band.has(field):
			continue
		var value: Variant = _timing_value(row, field)
		if value == null:
			out.append("%s: no landing recovery in its row (task 59)" % at if field == "landing" else "%s: no %s in its row" % [at, field])
			continue
		var r: Array = band[field]
		if int(value) < r[0] or int(value) > r[1]:
			out.append("%s: %s %d, not %d-%d" % [at, field.replace("_", " ").replace("from stance", "from the stance"), int(value), r[0], r[1]])
	return out


static func _timing_value(row: Dictionary, field: String) -> Variant:
	match field:
		"from_stance":
			return int(row["startup"]) - Fighter.CHARGE_CHECK_FRAME if row.has("startup") else null
		"total":
			return int(row["startup"]) + int(row["active"]) + int(row["recovery"]) if row.has("recovery") else null
	return row.get(field)


## Move `id` of weapon `w`, of `kind`, played from standing at a defender
## standing at each distance its band names (SwingReach): one line per
## distance. Empty for a move that strikes nothing or a kind with no
## distance to touch from (Moonsplitter's wave, a Counter Lunge).
func distance_check(w: WeaponDef, id: StringName, kind: StringName) -> Array[DistanceLine]:
	var out: Array[DistanceLine] = []
	var m: AttackDef = w.moves[id]
	var band: Dictionary = distance_band(w.id, kind)
	if not band.has("touches") or (m.damage <= 0.0 and m.posture <= 0.0):
		return out
	var own: Dictionary = distance.get(w.id, {})
	if m.swing == null:
		var none: DistanceLine = DistanceLine.new()
		none.text = "no swing"
		out.append(none)
		return out
	var body: FighterBody = FighterBody.of(&"")
	var duel: float = own.get("duel", 0.0)
	var touch_from: Array[float] = [float(band["touches"])]
	for d: float in [duel, float(own.get("preferred", 0.0))]:
		if d > 0.0 and d < touch_from[0] and not touch_from.has(d):
			touch_from.append(d)
	for d: float in touch_from:
		var line: DistanceLine = DistanceLine.new()
		line.distance = d
		var touches: Array[SwingReach.Contact] = SwingReach.touches(m, w, d, 0.0, body)
		line.ok = not touches.is_empty()
		line.text = "touches from %s m" % _m(d) if line.ok else "no touch from %s m" % _m(d)
		if line.ok and band.has("inside") and is_equal_approx(d, duel):
			var r: Array = band["inside"]
			line.inside = 0.0
			for c: SwingReach.Contact in touches:
				line.inside = maxf(line.inside, SwingReach.inside(c, w))
			line.text += ": %.1f cm in" % (line.inside * 100.0)
			if line.inside < r[0] or line.inside > r[1]:
				line.ok = false
				line.text += ", not %d-%d cm" % [roundi(r[0] * 100.0), roundi(r[1] * 100.0)]
		out.append(line)
	var miss_from: Array[float] = [float(band["misses"])]
	if own.has("misses_all") and own["misses_all"] > miss_from[0]:
		miss_from.append(own["misses_all"])
	for d: float in miss_from:
		var line: DistanceLine = DistanceLine.new()
		line.distance = d
		line.must_touch = false
		line.ok = SwingReach.first_contact(m, w, d, 0.0, body) == null
		line.text = "misses from %s m" % _m(d) if line.ok else "touches from %s m, where it must miss" % _m(d)
		out.append(line)
	return out


## What move `id` of weapon `w`, of `kind`, gets wrong against its distance
## band, one line each; nothing when it connects from its band.
func distance_problems(w: WeaponDef, id: StringName, kind: StringName) -> Array[String]:
	var out: Array[String] = []
	for line: DistanceLine in distance_check(w, id, kind):
		if not line.ok:
			out.append("%s.%s (%s): %s" % [w.id, id, kind, line.text])
	return out


## A distance in metres as the spec writes it: 2.5, 3.25, 6.
static func _m(d: float) -> String:
	return String.num(d, 2)
