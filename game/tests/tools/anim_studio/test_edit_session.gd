extends GutTest
## The Studio's pending edits (EditSession, milestone-1 task 26): edits held
## until saved, undo and redo, the value with edits made, the dirty files,
## and the text a file would be saved as (through SourceEdit).

const A: String = "user://test_edit_session_a.json"
const B: String = "user://test_edit_session_b.json"
const A_TEXT: String = "{\n\t\"x\": {\"speed\": 1.4, \"n\": 3},\n\t\"y\": {\"speed\": 2}\n}\n"
const B_TEXT: String = "{\"clips\": {\"c\": {\"markers\": {\"windup\": 1, \"contact\": 5}}}}\n"


func before_each() -> void:
	for pair: Array in [[A, A_TEXT], [B, B_TEXT]]:
		var f: FileAccess = FileAccess.open(pair[0], FileAccess.WRITE)
		f.store_string(pair[1])
		f.close()


func after_all() -> void:
	for p: String in [A, B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


static func _edit(file: String, path: Array, before: Variant, after: Variant) -> Array[EditSession.Edit]:
	var p: Array[String] = []
	p.assign(path)
	return [EditSession.Edit.make(file, p, before, after)] as Array[EditSession.Edit]


func test_three_edits_to_two_files_undo_and_redo_back_to_the_same_text() -> void:
	var s: EditSession = EditSession.new()
	s.apply(_edit(A, ["x", "speed"], 1.4, 1.5), "x speed")
	s.apply(_edit(B, ["clips", "c", "markers", "contact"], 5, 6), "c contact")
	s.apply(_edit(A, ["y", "speed"], 2, 3), "y speed")
	var a3: String = s.text_for(A, s.original(A))
	var b3: String = s.text_for(B, s.original(B))
	assert_eq(a3, A_TEXT.replace("1.4", "1.5").replace("\"speed\": 2}", "\"speed\": 3}"))
	assert_eq(b3, B_TEXT.replace("\"contact\": 5", "\"contact\": 6"))
	assert_true(s.undo())
	assert_true(s.undo())
	assert_true(s.undo())
	assert_false(s.undo(), "nothing left")
	assert_eq(s.text_for(A, s.original(A)), A_TEXT, "all undone")
	assert_eq(s.text_for(B, s.original(B)), B_TEXT)
	for i: int in 3:
		assert_true(s.redo())
	assert_eq(s.text_for(A, s.original(A)), a3, "all redone")
	assert_eq(s.text_for(B, s.original(B)), b3)


func test_an_edit_after_an_undo_drops_the_redo() -> void:
	var s: EditSession = EditSession.new()
	s.apply(_edit(A, ["x", "n"], 3, 4), "n 4")
	s.undo()
	assert_eq(s.redo_label(), "n 4")
	s.apply(_edit(A, ["x", "n"], 3, 5), "n 5")
	assert_eq(s.redo_label(), "")
	assert_false(s.redo())
	assert_eq(s.undo_label(), "n 5")


func test_value_sees_the_pending_edits_and_a_removal() -> void:
	var s: EditSession = EditSession.new()
	assert_eq(s.value(A, ["x", "n"] as Array[String], 3), 3, "the fallback without edits")
	s.apply(_edit(A, ["x", "n"], 3, 4), "")
	s.apply(_edit(A, ["x", "n"], 4, 7), "")
	assert_eq(s.value(A, ["x", "n"] as Array[String], 3), 7, "the latest")
	s.apply(_edit(A, ["x", "n"], 7, null), "")
	assert_null(s.value(A, ["x", "n"] as Array[String], 3), "removed")
	assert_eq(s.text_for(A, s.original(A)), A_TEXT.replace(", \"n\": 3", ""), "and gone from the text")


func test_steps_made_together_undo_together() -> void:
	var s: EditSession = EditSession.new()
	var both: Array[EditSession.Edit] = []
	both.append_array(_edit(A, ["x", "n"], 3, null))
	both.append_array(_edit(A, ["x", "speed"], 1.4, 1.6))
	s.apply(both, "both")
	s.undo()
	assert_eq(s.text_for(A, s.original(A)), A_TEXT)


func test_dirty_files_touches_and_clear() -> void:
	var s: EditSession = EditSession.new()
	assert_eq(s.dirty_files(), PackedStringArray())
	s.apply(_edit(A, ["x", "n"], 3, 4), "")
	s.apply(_edit(B, ["clips", "c", "markers", "windup"], 1, 0), "")
	assert_eq(s.dirty_files(), PackedStringArray([A, B]))
	assert_true(s.touches(B, ["clips", "c"] as Array[String]))
	assert_false(s.touches(B, ["clips", "d"] as Array[String]))
	assert_false(s.touches(A, ["y"] as Array[String]))
	s.clear(A)
	assert_eq(s.dirty_files(), PackedStringArray([B]))
	s.undo()
	assert_eq(s.dirty_files(), PackedStringArray(), "an undone edit isn't pending")


func test_the_original_text_is_kept_as_first_loaded() -> void:
	var s: EditSession = EditSession.new()
	s.apply(_edit(A, ["x", "n"], 3, 4), "")
	var f: FileAccess = FileAccess.open(A, FileAccess.WRITE)
	f.store_string("changed on disk")
	f.close()
	assert_eq(s.original(A), A_TEXT, "for the save's clobber check")
