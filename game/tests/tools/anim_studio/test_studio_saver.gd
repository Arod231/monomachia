extends GutTest
## The Studio's save (StudioSaver, milestone-1 task 27) at its seam, on
## fixture copies of the move-clip table, the manifest and the frame-data
## table, with a fake generator that writes each move's frame data from its
## markers (MoveClips.frame_data) into the table copy: markers in, the
## regenerated table and the out-of-band report out; a file changed on disk
## refused with its edits kept; a refusing generator undoing the save byte
## for byte; no clip libraries saving the data and saying the table wasn't
## regenerated. No committed file changes.

const DIR: String = "user://test_studio_saver"
const MOVES: String = DIR + "/move_clips.json"
const MANIFEST: String = DIR + "/clip_manifest.json"
const TABLE: String = DIR + "/frame_data.json"

var _calls: int = 0


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for pair: Array in [[MoveClips.PATH, MOVES], [ClipManifest.PATH, MANIFEST], [FrameDataTable.PATH, TABLE]]:
		_write(pair[1], FileAccess.get_file_as_string(pair[0]))
	_calls = 0


func after_all() -> void:
	for p: String in [MOVES, MANIFEST, TABLE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	FrameDataTable._shared = null


static func _write(file: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## A saver over the copies, with `generator` in place of the bake and no
## distance check.
func _saver(generator: Callable) -> StudioSaver:
	var s: StudioSaver = StudioSaver.new()
	s.table_path = TABLE
	s.generated_files = PackedStringArray([TABLE])
	s.regenerate = generator
	s.weapon_of = Callable()
	return s


## The fake generator: each move's startup, active and recovery from its
## markers in the copy of the move-clip table, written into the copy of the
## frame-data table.
func _generate(_parent: Node) -> Dictionary:
	_calls += 1
	var clips: MoveClips = MoveClips.read(ClipManifest.read(MANIFEST), MOVES)
	if not clips.errors.is_empty():
		return {"code": 1, "errors": clips.errors}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	for wid: StringName in clips.moves:
		for id: StringName in clips.of(wid):
			var e: MoveClips.Entry = clips.of(wid)[id]
			if e.markers.is_empty() or not (data["moves"] as Dictionary).has(String(wid)):
				continue
			var fd: Dictionary = MoveClips.frame_data(e.markers)
			var row: Dictionary = data["moves"][String(wid)][String(id)]
			for f: String in ["startup", "active", "recovery"]:
				row[f] = fd[f]
	_write(TABLE, JSON.stringify(data, "\t"))
	return {"code": 0, "errors": PackedStringArray()}


func _refuse(_parent: Node) -> Dictionary:
	_calls += 1
	_write(TABLE, "half written")
	return {"code": 1, "errors": PackedStringArray(["k_l1: the settle is past the clip's end"])}


func _no_libraries(_parent: Node) -> Dictionary:
	_calls += 1
	return {"code": 2, "errors": PackedStringArray(["no clip libraries"])}


## Crown Cut's (a stand-in) active frames moved to source frames 18-19: real
## markers, 16/2/22.
static func _edit_crown_cut(session: EditSession) -> void:
	var e: MoveClips.Entry = MoveClips.read(ClipManifest.read(), MOVES).of(&"katana")[&"k_l4"]
	var r: MarkerEdits.Result = MarkerEdits.set_move_marker(session, MOVES, &"katana", e, "active_start", 18, true)
	session.apply(r.edits, r.label)


func test_markers_in_the_regenerated_table_and_the_out_of_band_report_out() -> void:
	var session: EditSession = EditSession.new()
	_edit_crown_cut(session)
	var r: StudioSaver.Result = _saver(_generate).save(session, self)
	assert_eq(r.written, PackedStringArray([MOVES]))
	assert_true(r.regenerated)
	assert_eq(_calls, 1)
	assert_eq(FrameDataTable.read(TABLE).row(&"katana", &"k_l4")["startup"], 16.0, "the table regenerated")
	assert_eq(r.changed, PackedStringArray(["katana.k_l4: 14/4/22 -> 16/2/22"]))
	assert_has(r.out_of_band, "katana.k_l4 (string_light): startup 16, not 24-30 (waiting for its family)")
	assert_has(r.out_of_band, "katana.k_l4 (string_light): active 2, not 3-6 (waiting for its family)")
	assert_true(r.soak_due)
	assert_has(r.report(), StudioSaver.SOAK_DUE)
	assert_eq(session.dirty_files(), PackedStringArray(), "saved edits aren't pending")
	assert_false(MoveClips.read(ClipManifest.read(), MOVES).of(&"katana")[&"k_l4"].markers_stand_in, "the file says so")
	assert_false(FileAccess.file_exists(MOVES + StudioSaver.TMP_SUFFIX), "the temporary file is gone")


func test_a_move_off_the_waiting_list_is_reported_as_failing_ci() -> void:
	var session: EditSession = EditSession.new()
	_edit_crown_cut(session)
	var saver: StudioSaver = _saver(_generate)
	saver.bands = MoveBands.read()
	saver.bands.waiting[&"katana"].erase(&"k_l4")
	var r: StudioSaver.Result = saver.save(session, self)
	assert_has(r.out_of_band, "katana.k_l4 (string_light): startup 16, not 24-30 (CI will fail)")


func test_a_file_changed_on_disk_is_refused_and_its_edits_kept() -> void:
	var session: EditSession = EditSession.new()
	_edit_crown_cut(session)
	var before: String = session.original(MOVES)
	_write(MOVES, before + " ")
	var r: StudioSaver.Result = _saver(_generate).save(session, self)
	assert_eq(r.refused, {MOVES: StudioSaver.CHANGED_ON_DISK})
	assert_eq(r.written, PackedStringArray())
	assert_eq(_calls, 0, "nothing to regenerate")
	assert_eq(session.dirty_files(), PackedStringArray([MOVES]), "the edits stay pending")
	assert_eq(FileAccess.get_file_as_string(MOVES), before + " ", "the other change is left alone")


func test_a_refusing_generator_undoes_the_save_byte_for_byte() -> void:
	var session: EditSession = EditSession.new()
	_edit_crown_cut(session)
	var moves_text: String = FileAccess.get_file_as_string(MOVES)
	var table_text: String = FileAccess.get_file_as_string(TABLE)
	var r: StudioSaver.Result = _saver(_refuse).save(session, self)
	assert_eq(r.errors, PackedStringArray(["k_l1: the settle is past the clip's end"]))
	assert_eq(r.written, PackedStringArray())
	assert_eq(FileAccess.get_file_as_string(MOVES), moves_text, "the move-clip table put back")
	assert_eq(FileAccess.get_file_as_string(TABLE), table_text, "and the table")
	assert_eq(session.dirty_files(), PackedStringArray([MOVES]), "the edits stay pending")
	assert_string_contains("\n".join(r.report()), "nothing was saved")


func test_without_the_clip_libraries_the_data_are_saved_and_the_report_says_so() -> void:
	var session: EditSession = EditSession.new()
	_edit_crown_cut(session)
	var table_text: String = FileAccess.get_file_as_string(TABLE)
	var r: StudioSaver.Result = _saver(_no_libraries).save(session, self)
	assert_eq(r.written, PackedStringArray([MOVES]))
	assert_false(r.regenerated)
	assert_string_contains(r.skipped, "no clip libraries")
	assert_eq(FileAccess.get_file_as_string(TABLE), table_text, "the table untouched")
	assert_string_contains("\n".join(r.report()), "table not regenerated")


func test_a_chain_and_a_clip_marker_save_together() -> void:
	var session: EditSession = EditSession.new()
	var e: MoveClips.Entry = MoveClips.read(ClipManifest.read(), MOVES).of(&"katana")[&"k_iai"]
	var rows: Array[ChainEdits.Row] = ChainEdits.rows_of(ChainEdits.current(session, MOVES, &"katana", e))
	rows[0].from = 4.0
	var chain: MarkerEdits.Result = ChainEdits.set_chain(session, MOVES, &"katana", e, rows, ClipManifest.read(MANIFEST))
	session.apply(chain.edits, chain.label)
	var base: Dictionary = (ClipManifest.read(MANIFEST).clips[&"Attack1H01_R"] as ClipManifest.Clip).markers
	var clip: MarkerEdits.Result = MarkerEdits.set_clip_marker(session, MANIFEST, &"Attack1H01_R", base, "settle", base["settle"] + 1)
	session.apply(clip.edits, clip.label)
	var r: StudioSaver.Result = _saver(_generate).save(session, self)
	assert_eq(r.written, PackedStringArray([MOVES, MANIFEST]))
	var read: MoveClips.Entry = MoveClips.read(ClipManifest.read(MANIFEST), MOVES).of(&"katana")[&"k_iai"]
	assert_eq(String(read.clips[0]), "SheatheHips01_R@4-12")
	assert_eq(ClipManifest.read(MANIFEST).clips[&"Attack1H01_R"].markers["settle"], base["settle"] + 1)
	assert_eq(r.changed, PackedStringArray(), "no move's markers changed, so no frame data")
	assert_false(r.soak_due)


func test_nothing_pending_saves_nothing() -> void:
	var r: StudioSaver.Result = _saver(_generate).save(EditSession.new(), self)
	assert_eq(r.written, PackedStringArray())
	assert_eq(_calls, 0)
