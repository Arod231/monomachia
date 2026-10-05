extends GutTest
## Marker editing (MarkerEdits, milestone-1 task 26) at the save seam, on
## fixture copies of the move-clip table and the clip manifest: an edit
## writes only its value and the readers read it back, undo restores the
## file byte for byte, an out-of-order marker is refused, and a stand-in
## move asks first and then drops its stand-in flag in the same step. This
## task changes no committed marker.

const DIR: String = "user://test_marker_edits"
const MOVES_FILE: String = DIR + "/move_clips.json"
const MANIFEST_FILE: String = DIR + "/clip_manifest.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for pair: Array in [[MoveClips.PATH, MOVES_FILE], [ClipManifest.PATH, MANIFEST_FILE]]:
		_write(pair[1], FileAccess.get_file_as_string(pair[0]))


func after_all() -> void:
	for p: String in [MOVES_FILE, MANIFEST_FILE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


## [removed, inserted]: what changed between `a` and `b`, as one span.
static func _diff(a: String, b: String) -> Array[String]:
	var start: int = 0
	while start < mini(a.length(), b.length()) and a[start] == b[start]:
		start += 1
	var end_a: int = a.length()
	var end_b: int = b.length()
	while end_a > start and end_b > start and a[end_a - 1] == b[end_b - 1]:
		end_a -= 1
		end_b -= 1
	return [a.substr(start, end_a - start), b.substr(start, end_b - start)] as Array[String]


static func _entry(wid: StringName, id: StringName) -> MoveClips.Entry:
	return MoveClips.read(ClipManifest.read()).of(wid)[id]


static func _write(file: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_a_marker_edit_writes_only_its_value_and_reads_back() -> void:
	# the Heavy Swing's real markers: active start 16 to 16.5
	var s: EditSession = EditSession.new()
	var r: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"greatsword", _entry(&"greatsword", &"g_l1"), "active_start", 16.5)
	assert_eq(r.error, "")
	assert_eq(r.question, "", "real markers ask nothing")
	s.apply(r.edits, r.label)
	var text: String = s.text_for(MOVES_FILE, s.original(MOVES_FILE))
	assert_eq(_diff(s.original(MOVES_FILE), text), ["", ".5"] as Array[String], "only the value changed")
	_write(MOVES_FILE, text)
	var read: MoveClips = MoveClips.read(ClipManifest.read(), MOVES_FILE)
	assert_eq(read.errors, PackedStringArray())
	assert_eq(read.of(&"greatsword")[&"g_l1"].markers["active_start"], 16.5)


func test_undo_restores_the_file_byte_for_byte() -> void:
	var s: EditSession = EditSession.new()
	var r: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"greatsword", _entry(&"greatsword", &"g_l1"), "settle", 33)
	s.apply(r.edits, r.label)
	assert_ne(s.text_for(MOVES_FILE, s.original(MOVES_FILE)), s.original(MOVES_FILE))
	s.undo()
	assert_eq(s.text_for(MOVES_FILE, s.original(MOVES_FILE)), s.original(MOVES_FILE))


func test_an_out_of_order_marker_is_refused() -> void:
	var s: EditSession = EditSession.new()
	var e: MoveClips.Entry = _entry(&"greatsword", &"g_l1")
	var r: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"greatsword", e, "active_start", 19)
	assert_string_contains(r.error, "marker active_end must come after active_start")
	assert_eq(r.edits.size(), 0)
	r = MarkerEdits.set_move_marker(s, MOVES_FILE, &"greatsword", e, "active_end", 16.25)
	assert_eq(r.error, "a marker sits on a whole or half source frame")
	# order is judged with the pending edits made: the settle moved to 25
	# first, a dodge cancel at 26 is past it
	var settle: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"greatsword", e, "settle", 25)
	s.apply(settle.edits, settle.label)
	r = MarkerEdits.set_move_marker(s, MOVES_FILE, &"greatsword", e, "dodge_cancel", 26)
	assert_string_contains(r.error, "dodge-cancel window")


func test_a_branch_point_is_edited_in_place() -> void:
	var s: EditSession = EditSession.new()
	var r: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"greatsword", _entry(&"greatsword", &"g_l1"), "branch g_l2", 20)
	assert_eq(r.error, "")
	s.apply(r.edits, r.label)
	assert_eq(_diff(s.original(MOVES_FILE), s.text_for(MOVES_FILE, s.original(MOVES_FILE))), ["19", "20"] as Array[String])
	var none: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"greatsword", _entry(&"greatsword", &"g_l1"), "branch g_l9", 20)
	assert_string_contains(none.error, "no follow-up")


func test_a_stand_in_asks_first_and_then_becomes_real_markers() -> void:
	var s: EditSession = EditSession.new()
	var e: MoveClips.Entry = _entry(&"katana", &"k_l1")
	assert_true(e.markers_stand_in)
	var asked: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"katana", e, "active_start", 6)
	assert_eq(asked.question, MarkerEdits.STAND_IN_QUESTION)
	assert_eq(asked.edits.size(), 0, "nothing until answered")
	var r: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"katana", e, "active_start", 6, true)
	assert_eq(r.edits.size(), 3, "the speed, the flag and the marker, in one step")
	s.apply(r.edits, r.label)
	var text: String = s.text_for(MOVES_FILE, s.original(MOVES_FILE))
	_write(MOVES_FILE, text)
	var read: MoveClips = MoveClips.read(ClipManifest.read(), MOVES_FILE)
	assert_eq(read.errors, PackedStringArray())
	assert_false(read.of(&"katana")[&"k_l1"].markers_stand_in, "the flag goes")
	assert_true(is_nan(read.of(&"katana")[&"k_l1"].speed), "and its retime's speed: it plays at 1.0x (task 19)")
	assert_eq(read.of(&"katana")[&"k_l1"].markers["active_start"], 6.0)
	var next: MarkerEdits.Result = MarkerEdits.set_move_marker(s, MOVES_FILE, &"katana", e, "active_end", 8)
	assert_eq(next.question, "", "real now, so the next edit asks nothing")
	s.undo()
	assert_eq(s.text_for(MOVES_FILE, s.original(MOVES_FILE)), s.original(MOVES_FILE), "undo puts the stand-ins back")
	assert_eq(MarkerEdits.set_move_marker(s, MOVES_FILE, &"katana", e, "active_end", 8).question, MarkerEdits.STAND_IN_QUESTION)


func test_a_clip_marker_writes_only_its_value_and_keeps_its_order() -> void:
	var s: EditSession = EditSession.new()
	var base: Dictionary = (ClipManifest.read().clips[&"Attack1H01_R"] as ClipManifest.Clip).markers
	var r: MarkerEdits.Result = MarkerEdits.set_clip_marker(s, MANIFEST_FILE, &"Attack1H01_R", base, "contact", base["contact"] + 1)
	assert_eq(r.error, "")
	s.apply(r.edits, r.label)
	var text: String = s.text_for(MANIFEST_FILE, s.original(MANIFEST_FILE))
	var d: Array[String] = _diff(s.original(MANIFEST_FILE), text)
	assert_eq(int(d[1]) - int(d[0]), 1, "one number, one more: %s" % [d])
	_write(MANIFEST_FILE, text)
	var read: ClipManifest = ClipManifest.read(MANIFEST_FILE)
	assert_eq(read.errors, PackedStringArray())
	assert_eq(read.clips[&"Attack1H01_R"].markers["contact"], base["contact"] + 1)
	assert_string_contains(MarkerEdits.set_clip_marker(s, MANIFEST_FILE, &"Attack1H01_R", base, "contact", base["settle"] + 1).error, "comes before")
	assert_string_contains(MarkerEdits.set_clip_marker(s, MANIFEST_FILE, &"Attack1H01_R", base, "contact", 10.5).error, "whole source frame")
	assert_string_contains(MarkerEdits.set_clip_marker(s, MANIFEST_FILE, &"Attack1H01_R", base, "foot", 3).error, "not a clip's marker")
