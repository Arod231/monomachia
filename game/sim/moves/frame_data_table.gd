class_name FrameDataTable
extends RefCounted
## The committed frame-data table (game/sim/moves/frame_data.json,
## milestone-1 task 16), beside the swing files: what the frame-data
## generator (tools/frame_data_generator.gd) read from each clip, written by
## the bake (`node scripts/godot.mjs bake`, tools/bake_swings.gd) in the
## same run as the swing files, since neither the rules nor CI can read the
## clips. It holds:
## - "moves": weapon -> move -> its row: its kind (the timing band's row),
##   its chain (each part's clip and source frames), "stand_in" when its
##   markers are stand-ins, startup, active and recovery in rules frames,
##   the dodge-cancel window ([first, last], absent for none), each
##   follow-up's branch point and window ("branches": {move: [branch, last]}),
##   the travel over each rules frame ([forward m, sideways m, turn degrees]
##   from frame 0), and two checksums: "source_sha256", of the clips' source
##   files, which only the local re-bake can check, and "digest", of the row
##   with its swing file's record (digest()), which CI recomputes so a hand
##   edit to either fails;
## - "gaits": a gait clip -> its measured speed (m/s), heading (degrees to
##   the right of forward), stride (m over one loop), length and foot
##   contacts;
## - "clips": a clip that sets a rules length (today the state clips) -> its
##   length and markers in rules frames;
## - "not_keyed_yet": the rules-length clips this plan adds that have no clip
##   yet, each task that keys one taking it off.
## Gaits and clips carry the same two checksums, their digest over the row
## alone.

const PATH: String = "res://sim/moves/frame_data.json"
const SECTIONS: Array[String] = ["moves", "gaits", "clips", "not_keyed_yet"]

## weapon -> move -> row, as read.
var moves: Dictionary = {}
var gaits: Dictionary = {}
var clips: Dictionary = {}
var not_keyed_yet: Array[String] = []
## What is wrong with the file, one line each; empty when it read cleanly.
var errors: PackedStringArray = []

static var _shared: FrameDataTable = null


## The committed table, read once.
static func shared() -> FrameDataTable:
	if _shared == null:
		_shared = read()
	return _shared


static func read(path: String = PATH) -> FrameDataTable:
	var t: FrameDataTable = FrameDataTable.new()
	if not FileAccess.file_exists(path):
		t.errors.append("%s is missing" % path)
		return t
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		t.errors.append("%s is not a JSON object" % path)
		return t
	for key: Variant in data:
		if key != "about" and not SECTIONS.has(str(key)):
			t.errors.append("unknown section %s" % key)
	for section: String in ["moves", "gaits", "clips"]:
		if not (data as Dictionary).get(section) is Dictionary:
			t.errors.append("no %s" % section)
	if not t.errors.is_empty():
		return t
	t.moves = data["moves"]
	t.gaits = data["gaits"]
	t.clips = data["clips"]
	for name: Variant in (data as Dictionary).get("not_keyed_yet", []):
		t.not_keyed_yet.append(str(name))
	return t


## A move's row, or an empty Dictionary for none.
func row(weapon: StringName, move: StringName) -> Dictionary:
	return (moves.get(String(weapon), {}) as Dictionary).get(String(move), {})


## The digest of a row (its "digest" left out) with its move's record in
## the swing file (null for a row without a swing): SHA-256 over both as
## sorted JSON, so the same data give the same digest however they're laid
## out.
static func digest(p_row: Dictionary, swing_record: Variant) -> String:
	var own: Dictionary = p_row.duplicate(true)
	own.erase("digest")
	var text: String = JSON.stringify(own, "", true) + "\n" + (JSON.stringify(swing_record, "", true) if swing_record != null else "")
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()
