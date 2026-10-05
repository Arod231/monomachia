class_name FramesAndBands
extends RefCounted
## The Studio's frames-and-bands view as data (milestone-1 task 25): a
## move's generated frame data (its row of the frame-data table) against its
## kind's timing band, and the distance band's hit-or-miss check, the band
## tests' own (MoveBands), so the Studio shows exactly what CI checks. The
## editor's side panel lists `fields` and `distance`; its timeline draws
## `bars` and `startup_band` on the rules ruler, which starts at the move's
## wind-up marker (`windup`), two rules frames to a source frame.

## One number of the timing band: its value in the row (null when the row
## lacks it), the band and whether it is in it.
class Field:
	var name: String = ""
	var value: Variant = null
	var band: Array = []
	var ok: bool = false

	## "startup 11 (24-30)": how the panel shows it.
	func text() -> String:
		var shown: String = "—" if value == null else str(int(value))
		return "%s %s (%d-%d)" % [name.replace("_", " "), shown, band[0], band[1]]


## A span of the move on the rules ruler: the startup, the active frames or
## the recovery, in rules frames from the wind-up.
class Bar:
	var name: String = ""
	var from: int = 0
	var to: int = 0


var weapon: StringName = &""
var move: StringName = &""
var kind: StringName = &""
## The move's row of the frame-data table.
var row: Dictionary = {}
## The source frame rules frame 0 sits on: the move's wind-up marker.
var windup: float = 0.0
var fields: Array[Field] = []
var bars: Array[Bar] = []
## Where the first active frame should fall (rules frames from the wind-up):
## the startup's band; empty without one.
var startup_band: Array = []
var distance: Array[MoveBands.DistanceLine] = []
## Whether the move waits for its family's re-key (the band tests skip it).
var waiting: bool = false
## Why there's no band to show, or "" when there is one.
var no_band: String = ""


## The view of move `id` of weapon `w`: its frame-data table `row`, its
## markers (MoveClips.Entry.markers, for the wind-up) and the band tables.
static func build(w: WeaponDef, id: StringName, p_row: Dictionary, markers: Dictionary, bands: MoveBands) -> FramesAndBands:
	var v: FramesAndBands = FramesAndBands.new()
	v.weapon = w.id
	v.move = id
	v.row = p_row
	v.windup = float(markers.get("windup", 0.0))
	if p_row.is_empty():
		v.no_band = "no row in the frame-data table"
		return v
	v.kind = StringName(str(p_row.get("kind", "")))
	var at: int = 0
	for name: String in ["startup", "active", "recovery"]:
		var bar: Bar = Bar.new()
		bar.name = name
		bar.from = at
		at += int(p_row.get(name, 0))
		bar.to = at
		v.bars.append(bar)
	if MoveBands.MILESTONE_2_KINDS.has(v.kind):
		v.no_band = "no band test until milestone 2"
		return v
	var band: Dictionary = bands.timing_band(w.id, v.kind)
	if band.is_empty():
		v.no_band = "no timing band for %s" % v.kind
		return v
	v.waiting = bands.is_waiting(w.id, id)
	v.startup_band = band.get("startup", [])
	for name: String in MoveBands.TIMING_FIELDS:
		if not band.has(name):
			continue
		var f: Field = Field.new()
		f.name = name
		f.band = band[name]
		f.value = MoveBands.timing_value(p_row, name)
		f.ok = f.value != null and int(f.value) >= f.band[0] and int(f.value) <= f.band[1]
		v.fields.append(f)
	v.distance = bands.distance_check(w, id, v.kind)
	return v


## Whether every number lands in its band and every distance line holds.
func in_band() -> bool:
	return no_band == "" and fields.all(func(f: Field) -> bool: return f.ok) \
			and distance.all(func(l: MoveBands.DistanceLine) -> bool: return l.ok)


## The one-line verdict the editor shows: in band, or out of band and what
## CI makes of it.
func verdict() -> String:
	if no_band != "":
		return no_band
	if in_band():
		return "in band" + (" (still on the waiting list)" if waiting else "")
	return "out of band: waiting for its family" if waiting else "out of band: CI will fail"


## The source frame rules frame `rules` falls on.
func to_source(rules: float) -> float:
	return windup + rules / MoveClips.RULES_PER_SOURCE


## The rules frame (from the wind-up) source frame `source` falls on.
func to_rules(source: float) -> float:
	return (source - windup) * MoveClips.RULES_PER_SOURCE
