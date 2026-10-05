class_name ChecklistResults
extends RefCounted
## Where the tests that check a per-move checklist item move by move record
## each result (milestone-1 task 10), for scripts/checklist.mjs (npm run
## checklist) to write into docs/reviews/milestone-1-checklist.md:
## build/checklist-results.json (gitignored), as
## {"results": [{"item": 8, "row": "k_l1", "passed": true, "note": ""}]}.
## A later result for the same item and row replaces the earlier one.

## The results file; tests point it elsewhere.
static var path: String = ProjectSettings.globalize_path("res://").path_join("../build/checklist-results.json").simplify_path()


## Records that row `row` (a move or clip id) passed or failed item `item`.
static func record(item: int, row: StringName, passed: bool, note: String = "") -> void:
	var results: Array = []
	if FileAccess.file_exists(path):
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if doc is Dictionary and (doc as Dictionary).get("results") is Array:
			results = doc["results"]
	var entry: Dictionary = {"item": item, "row": String(row), "passed": passed, "note": note}
	var at: int = results.find_custom(func(r: Dictionary) -> bool: return int(r["item"]) == item and String(r["row"]) == String(row))
	if at >= 0:
		results[at] = entry
	else:
		results.append(entry)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("ChecklistResults: can't write %s" % path)
		return
	f.store_string(JSON.stringify({"results": results}, "  ") + "\n")
	f.close()
