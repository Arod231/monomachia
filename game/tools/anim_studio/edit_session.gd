class_name EditSession
extends RefCounted
## The Studio's pending edits (milestone-1 task 26, Studio task 10): each
## change to a data file, held until it is saved, with undo and redo. A pure
## model: nothing is written here. An edit addresses one value by file and
## key path, as SourceEdit does; text_for() applies a file's pending edits to
## its text through SourceEdit, so every other byte stays as it was. Edits
## made together (a marker and the stand-ins it replaces) undo together.
##
## The session keeps each file's text as first loaded (`loaded`), so a save
## can refuse a file changed on disk since (task 27's clobber check).

## The pending edits changed (an edit, an undo, a redo or a clear).
signal changed()


## One change: the value at `key_path` in `file` goes from `before` to
## `after` (null `before`: it wasn't there; null `after`: it goes).
class Edit:
	var file: String = ""
	var key_path: Array[String] = []
	var before: Variant = null
	var after: Variant = null

	static func make(p_file: String, p_path: Array[String], p_before: Variant, p_after: Variant) -> Edit:
		var e: Edit = Edit.new()
		e.file = p_file
		e.key_path = p_path
		e.before = p_before
		e.after = p_after
		return e


## The groups of edits made, oldest first: each [label, Array[Edit]].
var _done: Array = []
## The groups undone, the latest undone last.
var _undone: Array = []
## Each file's text when first loaded: file -> text.
var loaded: Dictionary[String, String] = {}


## `file`'s text as first loaded in this session (read now if it hasn't
## been).
func original(file: String) -> String:
	if not loaded.has(file):
		loaded[file] = FileAccess.get_file_as_string(file)
	return loaded[file]


## Makes `edits` as one step, labelled `label` (what undo says it undoes).
## Redo history is dropped.
func apply(edits: Array[Edit], label: String) -> void:
	if edits.is_empty():
		return
	for e: Edit in edits:
		original(e.file)
	_done.append([label, edits])
	_undone.clear()
	changed.emit()


## Undoes the latest step; false when there is none.
func undo() -> bool:
	if _done.is_empty():
		return false
	_undone.append(_done.pop_back())
	changed.emit()
	return true


## Makes the latest undone step again; false when there is none.
func redo() -> bool:
	if _undone.is_empty():
		return false
	_done.append(_undone.pop_back())
	changed.emit()
	return true


## What undo and redo would undo or redo ("" for nothing).
func undo_label() -> String:
	return _done[-1][0] if not _done.is_empty() else ""


func redo_label() -> String:
	return _undone[-1][0] if not _undone.is_empty() else ""


## The value at `key_path` in `file` with the pending edits made: the latest
## edit's `after` (null for one removed), else `fallback`.
func value(file: String, key_path: Array[String], fallback: Variant) -> Variant:
	for i: int in range(_done.size() - 1, -1, -1):
		var edits: Array = _done[i][1]
		for j: int in range(edits.size() - 1, -1, -1):
			var e: Edit = edits[j]
			if e.file == file and e.key_path == key_path:
				return e.after
	return fallback


## Whether `file` has an edit at `key_path` or under it.
func touches(file: String, prefix: Array[String]) -> bool:
	for e: Edit in pending(file):
		if e.key_path.slice(0, prefix.size()) == prefix:
			return true
	return false


## The pending edits of `file`, in the order made.
func pending(file: String) -> Array[Edit]:
	var out: Array[Edit] = []
	for group: Array in _done:
		for e: Edit in group[1]:
			if e.file == file:
				out.append(e)
	return out


## The files with pending edits.
func dirty_files() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for group: Array in _done:
		for e: Edit in group[1]:
			if not out.has(e.file):
				out.append(e.file)
	return out


## `text` (the file's text) with `file`'s pending edits made, through
## SourceEdit: each value replaced, added or removed, every other byte kept.
## What fails is pushed into `errors`.
func text_for(file: String, text: String, errors: Array[String] = []) -> String:
	var out: String = text
	for e: Edit in pending(file):
		if e.after == null:
			if SourceEdit.find_value(out, e.key_path, [] as Array[String]).x >= 0:
				out = SourceEdit.remove_key(out, e.key_path, errors)
		else:
			out = SourceEdit.replace_value(out, e.key_path, e.after, errors)
	return out


## Drops `file`'s pending edits (after a save, or a reload), and the steps
## left empty; redo history goes.
func clear(file: String) -> void:
	var kept: Array = []
	for group: Array in _done:
		var rest: Array[Edit] = []
		for e: Edit in group[1]:
			if e.file != file:
				rest.append(e)
		if not rest.is_empty():
			kept.append([group[0], rest])
	_done = kept
	_undone.clear()
	loaded.erase(file)
	changed.emit()
