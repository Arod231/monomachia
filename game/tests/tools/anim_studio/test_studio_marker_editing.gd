extends GutTest
## Marker editing in the Studio's editor (milestone-1 task 26), headless: a
## marker set in the Markers panel or dragged on the timeline becomes a
## pending edit (the timeline, the title and the gallery's "unsaved" badge
## follow), undo and redo take it back and forth, an out-of-order marker is
## refused with the reason shown, and a move with stand-in markers asks
## first. Nothing is written: the data files stay as they are.

const SCENE: String = "res://tools/anim_studio/studio.tscn"

var _moves_text: String = ""
var _manifest_text: String = ""


func before_all() -> void:
	_moves_text = FileAccess.get_file_as_string(MoveClips.PATH)
	_manifest_text = FileAccess.get_file_as_string(ClipManifest.PATH)


func after_each() -> void:
	assert_eq(FileAccess.get_file_as_string(MoveClips.PATH), _moves_text, "the move-clip table is untouched")
	assert_eq(FileAccess.get_file_as_string(ClipManifest.PATH), _manifest_text, "the manifest is untouched")


func _open(kind: StringName, id: StringName) -> AnimStudio:
	var studio: AnimStudio = (load(SCENE) as PackedScene).instantiate() as AnimStudio
	add_child_autofree(studio)
	await get_tree().process_frame
	studio.open_editor(studio.catalogue.find(kind, id))
	return studio


func test_a_marker_set_in_the_panel_is_a_pending_edit_with_undo_and_redo() -> void:
	var studio: AnimStudio = await _open(StudioCatalogue.KIND_MOVE, &"g_l1")
	var editor: StudioEditor = studio.editor
	var box: SpinBox = editor.get_node("%MarkersPanel").get_node("Marker_active_start")
	assert_eq(box.value, 16.0)
	box.value = 16.5
	assert_eq(editor.timeline.markers["active_start"], 16.5, "the timeline follows")
	assert_eq(editor.session.dirty_files(), PackedStringArray([MoveClips.PATH]))
	assert_string_ends_with(editor.get_node("%EditorTitle").text, "· unsaved")
	assert_true(studio.catalogue.find(StudioCatalogue.KIND_MOVE, &"g_l1").badges[&"unsaved"], "the gallery's badge")
	(editor.get_node("%UndoButton") as Button).pressed.emit()
	assert_eq(editor.timeline.markers["active_start"], 16.0, "undone")
	assert_false(studio.catalogue.find(StudioCatalogue.KIND_MOVE, &"g_l1").badges[&"unsaved"])
	(editor.get_node("%RedoButton") as Button).pressed.emit()
	assert_eq(editor.timeline.markers["active_start"], 16.5, "redone")


func test_a_marker_dragged_on_the_timeline_snaps_to_a_whole_frame() -> void:
	var studio: AnimStudio = await _open(StudioCatalogue.KIND_MOVE, &"g_l1")
	var tl: StudioTimeline = studio.editor.timeline
	tl.size = Vector2(1000.0, tl.custom_minimum_size.y)
	assert_true(tl.markers_editable)
	# The active start (16), not a late marker: without the packs the timeline
	# shows the 22-frame stand-in clip, so the source's later frames are off it.
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(tl.x_of(16.0), StudioTimeline.RULER_H + 5.0)
	tl._gui_input(press)
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = Vector2(tl.x_of(17.3), StudioTimeline.RULER_H + 5.0)
	tl._gui_input(move)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	tl._gui_input(release)
	assert_eq(tl.markers["active_start"], 17.0, "the active start dragged to 17")
	assert_eq(studio.editor.playback.frame, 0.0, "a marker drag doesn't scrub")
	assert_eq(StudioTimeline.snap(33.3, true), 33.5, "Alt snaps to halves")


func test_an_out_of_order_marker_is_refused_and_says_why() -> void:
	var studio: AnimStudio = await _open(StudioCatalogue.KIND_MOVE, &"g_l1")
	var editor: StudioEditor = studio.editor
	editor.set_marker("active_start", 19.0)
	assert_string_contains(editor.get_node("%MarkerStatus").text, "must come after")
	assert_eq(editor.session.dirty_files(), PackedStringArray(), "nothing pending")
	assert_eq(editor.timeline.markers["active_start"], 16.0)


func test_a_stand_in_move_asks_before_its_markers_become_real() -> void:
	# Leaping Cleave, still a stand-in (active 10-12.5)
	var studio: AnimStudio = await _open(StudioCatalogue.KIND_MOVE, &"k_sh")
	var editor: StudioEditor = studio.editor
	editor.set_marker("active_start", 12.0)
	var question: ConfirmationDialog = editor.get_node("StandInQuestion")
	assert_true(question.visible, "it asks")
	assert_eq(question.dialog_text, MarkerEdits.STAND_IN_QUESTION)
	assert_eq(editor.session.dirty_files(), PackedStringArray(), "nothing yet")
	question.confirmed.emit()
	assert_eq(editor.timeline.markers["active_start"], 12.0)
	assert_false(MarkerEdits.is_stand_in(editor.session, editor.moves_file, &"katana", &"k_sh", true), "real markers now")
	editor.undo()
	assert_true(MarkerEdits.is_stand_in(editor.session, editor.moves_file, &"katana", &"k_sh", true), "undo puts the stand-ins back")
	editor.set_marker("active_start", 12.0)
	question.canceled.emit()
	assert_eq(editor.timeline.markers["active_start"], 10.0, "no keeps them")


func test_a_clip_s_own_markers_are_edited_in_whole_frames() -> void:
	var studio: AnimStudio = await _open(StudioCatalogue.KIND_SOURCE, &"Attack1H01_R")
	var editor: StudioEditor = studio.editor
	assert_eq(editor.clip_id, &"Attack1H01_R")
	var before: float = editor.timeline.markers["contact"]
	editor.set_marker("contact", before + 1.0)
	assert_eq(editor.timeline.markers["contact"], before + 1.0)
	assert_eq(editor.session.dirty_files(), PackedStringArray([ClipManifest.PATH]))
	editor.set_marker("contact", before + 1.5)
	assert_string_contains(editor.last_error, "whole source frame")


func test_a_state_of_several_clips_has_no_markers_to_edit() -> void:
	var studio: AnimStudio = await _open(StudioCatalogue.KIND_STATE, &"knockdown")
	assert_false(studio.editor.timeline.markers_editable)
	assert_eq(studio.editor.set_marker("contact", 3.0).error, "nothing here has markers to edit")
