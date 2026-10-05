extends GutTest
## The per-move checklist (milestone-1 task 10): docs/reviews/
## milestone-1-checklist.md has a row for every move the frame-data readers
## know (until task 17's list, the Katana's and bare hands' move tables and
## Moonsplitter), and ChecklistResults writes a test run's results where
## scripts/checklist.mjs (npm run checklist) reads them.

const CHECKLIST: String = "res://../docs/reviews/milestone-1-checklist.md"

var _saved_path: String = ""


func before_each() -> void:
	_saved_path = ChecklistResults.path
	ChecklistResults.path = "user://test_checklist/results.json"
	_remove(ChecklistResults.path)


func after_each() -> void:
	_remove(ChecklistResults.path)
	ChecklistResults.path = _saved_path


static func _remove(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## The ids of the checklist's rows: the backticked id ending each table
## row's first cell.
static func _row_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(CHECKLIST).simplify_path())
	var re: RegEx = RegEx.create_from_string("^\\| [^|]*`([^`]+)` \\|")
	for line: String in text.split("\n"):
		var m: RegExMatch = re.search(line)
		if m != null:
			ids.append(m.get_string(1))
	return ids


func test_every_milestone_1_move_has_a_row() -> void:
	var ids: PackedStringArray = _row_ids()
	assert_gt(ids.size(), 50, "the checklist reads")
	var moves: Array[StringName] = []
	for weapon: WeaponDef in [Moves.KATANA, Moves.FISTS]:
		for id: StringName in weapon.moves:
			moves.append(id)
	moves.append(Moves.KATANA.ultimate)
	for id: StringName in moves:
		assert_true(ids.has(String(id)), "%s has a row" % id)
	var seen: Dictionary[String, bool] = {}
	for id: String in ids:
		assert_false(seen.has(id), "%s has one row" % id)
		seen[id] = true


func test_a_result_is_written_for_the_tool() -> void:
	ChecklistResults.record(8, &"k_l1", false, "worst 63.6 cm at frame 18")
	ChecklistResults.record(9, &"k_l1", true)
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(ChecklistResults.path))
	assert_eq(doc, {"results": [
		{"item": 8.0, "row": "k_l1", "passed": false, "note": "worst 63.6 cm at frame 18"},
		{"item": 9.0, "row": "k_l1", "passed": true, "note": ""},
	]})


func test_a_later_result_replaces_its_item_and_row() -> void:
	ChecklistResults.record(8, &"k_l1", false)
	ChecklistResults.record(8, &"k_l2", true)
	ChecklistResults.record(8, &"k_l1", true, "fixed")
	var results: Array = JSON.parse_string(FileAccess.get_file_as_string(ChecklistResults.path))["results"]
	assert_eq(results.size(), 2)
	assert_eq(results[0], {"item": 8.0, "row": "k_l1", "passed": true, "note": "fixed"})
