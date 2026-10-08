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


## Records item `item` for row `row` from a check's problems: passed when
## there are none, else noting the first three.
static func record_problems(item: int, row: StringName, problems: Array) -> void:
	var shown: PackedStringArray = []
	for p: Variant in problems.slice(0, 3):
		shown.append(str(p))
	var note: String = "; ".join(shown)
	if problems.size() > 3:
		note += " (+%d more)" % (problems.size() - 3)
	record(item, row, problems.is_empty(), note)


## Records item `item` once for clip row `row` (one of clip_rows()) from
## each of its clips' problems, by clip: passed when no clip has one, else
## noting the failing clips' first problems.
static func record_clips(item: int, row: StringName, problems_by_clip: Dictionary) -> void:
	var problems: Array[String] = []
	for clip: Variant in problems_by_clip:
		for p: Variant in problems_by_clip[clip]:
			problems.append("%s: %s" % [clip, p])
	record_problems(item, row, problems)


## The moves keyed into their bands so far, as [weapon id, move id]: every
## move of a banded weapon (MoveBands.BANDED) off the bands' waiting list,
## so held to its timing and distance bands. Their checklist rows take the
## tests' results; a move still on its stand-in takes none.
static func keyed_moves() -> Array[Array]:
	var bands: MoveBands = MoveBands.shared()
	var table: FrameDataTable = FrameDataTable.shared()
	var out: Array[Array] = []
	for wid: StringName in [&"katana", &"fists"]:
		for id: StringName in (Moves.WEAPONS[wid] as WeaponDef).moves:
			if bands.is_held(wid, id, StringName(table.row(wid, id).get("kind", ""))):
				out.append([wid, id])
	return out


## The checklist's rows that stand for deflect pairs, each with its pairs
## (StateClips.deflect_pairs entries, as ClipDirector plays them), from the
## state clip table: the light deflect pairs (milestone-1 task 34), the
## redirect's (task 90) and a blade's at a fist or a foot (task 90: each
## limb's recoil with each of the blade's deflects at a limb); a row with no
## pairs is left out.
static func pair_rows() -> Dictionary[StringName, Array]:
	var sc: StateClips = StateClips.read()
	var out: Dictionary[StringName, Array] = {&"clip_deflect_light": sc.deflect_pairs.values()}
	if not sc.deflect_redirect.is_empty():
		out[&"clip_deflect_redirect"] = [sc.deflect_redirect]
	var at_limb: Array = []
	for limb: StringName in sc.limb_recoils:
		for height: StringName in sc.limb_deflects:
			var pair: Dictionary = (sc.limb_recoils[limb] as Dictionary).duplicate()
			pair.merge(sc.limb_deflects[height])
			at_limb.append(pair)
	if not at_limb.is_empty():
		out[&"clip_deflect_limb"] = at_limb
	return out


## The checklist's rows that stand for a group of state clips, each with its
## clips, from the state clip table (StateClips): every deflect pair row's
## clips (pair_rows(): deflect then recoil, each once), the Katana's light hit
## reactions and its light block reaction (milestone-1 tasks 34, 35 and 90).
static func clip_rows() -> Dictionary[StringName, Array]:
	var sc: StateClips = StateClips.read()
	var out: Dictionary[StringName, Array] = {}
	var pairs: Dictionary[StringName, Array] = pair_rows()
	for row: StringName in pairs:
		var clips: Array[StringName] = []
		for pair: Dictionary in pairs[row]:
			for half: StringName in [&"deflect", &"recoil"]:
				if not clips.has(StringName(pair[half])):
					clips.append(StringName(pair[half]))
		out[row] = clips
	var hits: Array[StringName] = []
	for place: StringName in sc.light_hits.get(&"katana", {}):
		hits.append(StringName(sc.light_hits[&"katana"][place]))
	var blocks: Array[StringName] = []
	if sc.light_blocks.has(&"katana"):
		blocks.append(sc.light_blocks[&"katana"])
	out[&"clip_hit_light"] = hits
	out[&"clip_block_light"] = blocks
	return out
