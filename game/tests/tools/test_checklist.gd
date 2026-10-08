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


func test_a_list_of_problems_records_a_pass_or_its_first_problems() -> void:
	ChecklistResults.record_problems(1, &"k_l1", [])
	ChecklistResults.record_problems(2, &"k_l1", ["too short", "misses", "grazes", "a fourth"])
	var results: Array = JSON.parse_string(FileAccess.get_file_as_string(ChecklistResults.path))["results"]
	assert_eq(results[0], {"item": 1.0, "row": "k_l1", "passed": true, "note": ""})
	assert_eq(results[1], {"item": 2.0, "row": "k_l1", "passed": false, "note": "too short; misses; grazes (+1 more)"})


func test_a_clip_row_records_once_failing_on_any_of_its_clips() -> void:
	ChecklistResults.record_clips(3, &"clip_hit_light", {&"HitLightHighFront": [], &"HitLightLowBack": ["settles 2 frames late"]})
	ChecklistResults.record_clips(4, &"clip_hit_light", {&"HitLightHighFront": [], &"HitLightLowBack": []})
	var results: Array = JSON.parse_string(FileAccess.get_file_as_string(ChecklistResults.path))["results"]
	assert_eq(results.size(), 2)
	assert_eq(results[0], {"item": 3.0, "row": "clip_hit_light", "passed": false, "note": "HitLightLowBack: settles 2 frames late"})
	assert_eq(results[1], {"item": 4.0, "row": "clip_hit_light", "passed": true, "note": ""})


func test_the_keyed_moves_are_the_banded_moves_off_the_waiting_list() -> void:
	var keyed: Array[Array] = ChecklistResults.keyed_moves()
	assert_eq(keyed, [[&"katana", &"k_l1"], [&"katana", &"k_l2"], [&"katana", &"k_l3"], [&"katana", &"k_l4"], [&"fists", &"f_l1"], [&"fists", &"f_l2"], [&"fists", &"f_l3"], [&"fists", &"f_h1"], [&"fists", &"f_h2"], [&"fists", &"f_breaker"]] as Array[Array],
		"the light string, Breaker Palm (task 99) and bare hands' light string and heavies (tasks 89 and 133)")


func test_the_clip_rows_group_the_state_clips_the_families_keyed() -> void:
	var rows: Dictionary[StringName, Array] = ChecklistResults.clip_rows()
	assert_eq(rows.keys(), [&"clip_deflect_light", &"clip_hit_light", &"clip_block_light"])
	assert_eq(rows[&"clip_deflect_light"], [&"RightCutDeflect", &"RightCutRecoil", &"ReturnCutDeflect", &"ReturnCutRecoil",
		&"KesaCutDeflect", &"KesaCutRecoil", &"CrownCutDeflect", &"CrownCutRecoil"], "each light's pair, deflect then recoil")
	assert_eq(rows[&"clip_hit_light"].size(), 8, "the Katana's light hits, every place")
	assert_true(rows[&"clip_hit_light"].has(&"HitLightHighFront"))
	assert_eq(rows[&"clip_block_light"], [&"BlockLightKatana"])


func test_every_row_the_tests_record_is_a_checklist_row() -> void:
	var ids: PackedStringArray = _row_ids()
	for m: Array in ChecklistResults.keyed_moves():
		assert_true(ids.has(String(m[1])), "%s has a row" % m[1])
	for row: StringName in ChecklistResults.clip_rows():
		assert_true(ids.has(String(row)), "%s has a row" % row)
