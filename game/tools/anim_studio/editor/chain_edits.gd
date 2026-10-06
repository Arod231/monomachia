class_name ChainEdits
extends RefCounted
## The chain panel's model (milestone-1 task 27, Studio task 12 slimmed): a
## move's chain as rows of parts and source-frame ranges, written as one
## edit of the move's "clips" in the move-clip table. The panel has no speed
## field and makes no held frames: today's holds ("id@frame*n") and the
## move's speed are shown read-only, going with the stand-ins (task 19), and
## written back untouched.

## One part of a chain.
class Row:
	## The clip: a manifest id, or "ual/<name>" or "keyed/<name>".
	var clip: String = ""
	## Source frames: from (0 for the start) and to (NAN for the clip's end).
	var from: float = 0.0
	var to: float = NAN
	## A held part ("id@frame*n", going with the stand-ins, task 19): kept as written.
	var held: String = ""

	func is_held() -> bool:
		return held != ""

	## The chain entry it writes.
	func text() -> String:
		return held if is_held() else ChainEdits.part_text(clip, from, to)


## The chain entry for `clip` from `from` to `to` (NAN for the clip's end):
## "id", "id@from" or "id@from-to", whole frames without a decimal.
static func part_text(clip: String, from: float, to: float) -> String:
	if from <= 0.0 and is_nan(to):
		return clip
	if is_nan(to):
		return "%s@%s" % [clip, _num(from)]
	return "%s@%s-%s" % [clip, _num(from), _num(to)]


## A chain's entries as rows.
static func rows_of(entries: Array) -> Array[Row]:
	var out: Array[Row] = []
	for e: Variant in entries:
		var text: String = str(e)
		var row: Row = Row.new()
		var slash: int = text.find("/")
		var prefix: String = text.substr(0, slash + 1)
		var part: ClipChain.Part = ClipChain.parse(text.substr(slash + 1), [] as Array[String])
		if part == null:
			row.clip = text
		elif part.hold > 0.0:
			row.held = text
			row.clip = prefix + String(part.id)
		else:
			row.clip = prefix + String(part.id)
			row.from = part.from
			row.to = part.to
		out.append(row)
	return out


## Move `entry`'s chain as the session has it.
static func current(session: EditSession, file: String, wid: StringName, entry: MoveClips.Entry) -> Array[String]:
	var read: Array[String] = []
	for c: StringName in entry.clips:
		read.append(String(c))
	var v: Variant = session.value(file, _path(wid, entry.move), read)
	var out: Array[String] = []
	for c: Variant in v:
		out.append(str(c))
	return out


## Sets move `entry`'s chain to `rows`, checked: each part a clip the game
## has (the manifest's, or a CC0 or keyed clip), its range from before to,
## and no new held part.
static func set_chain(session: EditSession, file: String, wid: StringName, entry: MoveClips.Entry, rows: Array[Row],
		manifest: ClipManifest) -> MarkerEdits.Result:
	var r: MarkerEdits.Result = MarkerEdits.Result.new()
	if rows.is_empty():
		r.error = "a chain needs a part"
		return r
	var before: Array[String] = current(session, file, wid, entry)
	var after: Array[String] = []
	for row: Row in rows:
		if row.is_held():
			if not before.has(row.held):
				r.error = "the chain panel makes no held frames"
				return r
		else:
			var why: String = _check(row, manifest)
			if why != "":
				r.error = why
				return r
		after.append(row.text())
	if after == before:
		return r
	r.edits.append(EditSession.Edit.make(file, _path(wid, entry.move), before, after))
	r.label = "%s chain" % entry.move
	return r


static func _check(row: Row, manifest: ClipManifest) -> String:
	var id: String = row.clip
	var known: bool = id.begins_with("ual/") or id.begins_with("keyed/") or manifest.clips.has(StringName(id))
	if id == "" or not known:
		return "%s is not a clip of the manifest (or ual/, keyed/)" % (id if id != "" else "(no clip)")
	if row.from < 0.0 or row.from * 2.0 != floorf(row.from * 2.0):
		return "a part starts on a whole or half source frame"
	if not is_nan(row.to) and row.to <= row.from:
		return "%s: a part's end must come after its start" % id
	return ""


static func _path(wid: StringName, move: StringName) -> Array[String]:
	return [String(wid), "moves", String(move), "clips"] as Array[String]


static func _num(f: float) -> String:
	return str(int(f)) if f == floorf(f) else str(f)
