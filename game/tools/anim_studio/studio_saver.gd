class_name StudioSaver
extends RefCounted
## The Studio's save (milestone-1 task 27, Studio task 15 slimmed): writes
## the pending edits (markers and chains) and regenerates the frame-data
## table from them, then reports what changed and what is out of band.
##
## - The clobber check: a file whose text on disk differs from the text the
##   session first loaded is refused ("changed on disk since it was
##   opened"), its edits kept.
## - The atomic write: each file's new text goes to <file>.studio-tmp, then
##   over the file; the old texts are kept in memory.
## - The table: the bake runs in-process (bake_swings.gd's bake(), which
##   writes the table and the swing files). Without the clip libraries it
##   can't, so the data are saved and the report says the table wasn't
##   regenerated. If the generator refuses (a marker past its clip's end, a
##   chain that doesn't lay out), every file this save wrote, the table and
##   the swing files are put back byte for byte and the edits stay pending.
## - The report: every move whose row changed (old and new frame data), each
##   one out of band (its timing band from the new row; its distance band
##   with the weapon rebuilt from the new files), marked "waiting for its
##   family" or "CI will fail", and, when rules data changed, that a soak is
##   due before committing.
## The regeneration and the weapon rebuild are Callables, so tests run the
## save on fixture copies with a fake generator.

const BAKE: String = "res://tools/bake_swings.gd"
const TMP_SUFFIX: String = ".studio-tmp"
const CHANGED_ON_DISK: String = "changed on disk since it was opened"
const SOAK_DUE: String = "Rules data changed: run a soak (npm run soak -- 40) before committing."
## The fields of a table row whose change is a rules change.
const ROW_FIELDS: Array[String] = ["kind", "startup", "active", "recovery", "dodge_cancel", "branches"]


## What a save did.
class Result:
	## The files written.
	var written: PackedStringArray = []
	## The files refused, each with why; their edits stay pending.
	var refused: Dictionary = {}
	## Whether the table was regenerated.
	var regenerated: bool = false
	## Why it wasn't, when it wasn't but the data were saved.
	var skipped: String = ""
	## The generator's refusal: the save was undone.
	var errors: PackedStringArray = []
	## "katana.k_l1: 11/3/16 -> 12/3/16", one per move whose row changed.
	var changed: PackedStringArray = []
	## Each band problem of a changed move, marked waiting or CI will fail.
	var out_of_band: PackedStringArray = []
	var soak_due: bool = false

	## The report the editor shows, line by line.
	func report() -> PackedStringArray:
		var out: PackedStringArray = []
		for f: String in written:
			out.append("saved %s" % f.get_file())
		for f: Variant in refused:
			out.append("not saved: %s (%s)" % [str(f).get_file(), refused[f]])
		if not errors.is_empty():
			out.append("the table couldn't be regenerated, so nothing was saved:")
			for e: String in errors:
				out.append("  " + e)
			return out
		if skipped != "":
			out.append("table not regenerated: " + skipped)
		elif regenerated:
			out.append("table regenerated")
		for c: String in changed:
			out.append(c)
		for o: String in out_of_band:
			out.append("out of band: " + o)
		if regenerated and changed.is_empty():
			out.append("no move's frame data changed")
		if soak_due:
			out.append(SOAK_DUE)
		return out


## The frame-data table the report reads (a fixture copy in tests).
var table_path: String = FrameDataTable.PATH
## The files the regeneration writes, put back if it fails.
var generated_files: PackedStringArray = []
var bands: MoveBands = MoveBands.shared()
## (parent: Node) -> {"code": int, "errors": PackedStringArray}: regenerates
## the table (and the swing files). Code 2 is "no clip libraries".
var regenerate: Callable
## (weapon id) -> WeaponDef built from the new files, for the distance check
## of a changed move; null skips it.
var weapon_of: Callable


func _init() -> void:
	generated_files.append(table_path)
	for wid: StringName in Moves.WEAPONS:
		generated_files.append(SwingFile.path_for(wid))
	regenerate = _bake
	weapon_of = fresh_weapon


## Saves `session`'s pending edits, regenerating the table under `parent`.
func save(session: EditSession, parent: Node) -> Result:
	var r: Result = Result.new()
	var texts: Dictionary = {}
	for file: String in session.dirty_files():
		var on_disk: String = FileAccess.get_file_as_string(file)
		if on_disk != session.original(file):
			r.refused[file] = CHANGED_ON_DISK
			continue
		var why: Array[String] = []
		var text: String = session.text_for(file, session.original(file), why)
		if not why.is_empty():
			r.refused[file] = "; ".join(why)
			continue
		texts[file] = text
	if texts.is_empty():
		return r
	var old_generated: Dictionary = _read_all(generated_files)
	var old_rows: Dictionary = FrameDataTable.read(table_path).moves.duplicate(true)
	for file: String in texts:
		var err: String = write_atomic(file, texts[file])
		if err != "":
			_restore(r.written, session)
			r.written = PackedStringArray()
			r.refused[file] = err
			return r
		r.written.append(file)
	var out: Dictionary = regenerate.call(parent)
	var code: int = out.get("code", 0)
	if code == 2:
		r.skipped = "no clip libraries (run node scripts/godot.mjs clips, then save again or run the bake)"
	elif code != 0:
		r.errors = PackedStringArray(out.get("errors", []))
		if r.errors.is_empty():
			r.errors.append("the generator failed (code %d)" % code)
		_restore(r.written, session)
		for f: String in old_generated:
			write_atomic(f, old_generated[f])
		r.written = PackedStringArray()
		return r
	else:
		r.regenerated = true
	for file: String in r.written:
		session.clear(file)
	if r.regenerated:
		FrameDataTable._shared = null
		_compare(r, old_rows, FrameDataTable.read(table_path).moves)
	return r


## Writes `text` to `file` by way of <file>.studio-tmp; "" when it worked,
## else why not.
static func write_atomic(file: String, text: String) -> String:
	var tmp: String = file + TMP_SUFFIX
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "can't write %s" % tmp
	f.store_string(text)
	f.close()
	var from: String = ProjectSettings.globalize_path(tmp)
	var to: String = ProjectSettings.globalize_path(file)
	if DirAccess.rename_absolute(from, to) != OK:
		DirAccess.remove_absolute(to)
		if DirAccess.rename_absolute(from, to) != OK:
			return "can't move %s over %s" % [tmp, file]
	return ""


## Weapon `wid` built afresh from the files as they are now (the table read
## again), with its swings.
static func fresh_weapon(wid: StringName) -> WeaponDef:
	FrameDataTable._shared = null
	match wid:
		&"katana":
			return KatanaMoves.build()
		&"fists":
			return FistsMoves.build()
		&"greatsword":
			return GreatswordMoves.build()
		&"daggers":
			return DaggersMoves.build()
	return null


func _bake(parent: Node) -> Dictionary:
	return (load(BAKE) as GDScript).bake(&"", false, parent)


## Puts each of `files` back as the session first loaded it.
func _restore(files: PackedStringArray, session: EditSession) -> void:
	for f: String in files:
		write_atomic(f, session.original(f))


static func _read_all(files: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for f: String in files:
		if FileAccess.file_exists(f):
			out[f] = FileAccess.get_file_as_string(f)
	return out


## Fills the report's changed moves and their band problems from the rows
## before and after.
func _compare(r: Result, old: Dictionary, now: Dictionary) -> void:
	var rebuilt: Dictionary = {}
	for w: Variant in now:
		var wid: StringName = StringName(str(w))
		for id: Variant in now[w]:
			var row: Dictionary = now[w][id]
			var before: Dictionary = (old.get(w, {}) as Dictionary).get(id, {})
			if _same(before, row):
				continue
			r.soak_due = true
			r.changed.append("%s.%s: %s -> %s" % [wid, id, _frames(before), _frames(row)])
			var kind: StringName = StringName(str(row.get("kind", "")))
			if not bands.timing.has(wid) or MoveBands.MILESTONE_2_KINDS.has(kind):
				continue
			var mark: String = " (waiting for its family)" if bands.is_waiting(wid, StringName(str(id))) else " (CI will fail)"
			var problems: Array[String] = bands.timing_problems(wid, StringName(str(id)), row)
			if weapon_of.is_valid():
				if not rebuilt.has(wid):
					rebuilt[wid] = weapon_of.call(wid)
				var w_def: WeaponDef = rebuilt[wid]
				if w_def != null and w_def.moves.has(StringName(str(id))):
					problems.append_array(bands.distance_problems(w_def, StringName(str(id)), kind))
			for p: String in problems:
				r.out_of_band.append(p + mark)


static func _same(a: Dictionary, b: Dictionary) -> bool:
	for f: String in ROW_FIELDS:
		if JSON.stringify(a.get(f)) != JSON.stringify(b.get(f)):
			return false
	return true


## "11/3/16": startup, active and recovery; "none" for no row.
static func _frames(row: Dictionary) -> String:
	if row.is_empty():
		return "none"
	return "%d/%d/%d" % [int(row.get("startup", 0)), int(row.get("active", 0)), int(row.get("recovery", 0))]
