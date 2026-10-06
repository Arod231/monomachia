extends GutTest
## The editor's Chain panel and Save (milestone-1 task 27), headless: a
## move's parts listed with their ranges, today's holds and speed read-only,
## a part moved down as a pending edit the fighter plays at once, and Save
## (the button or Ctrl+S) writing a fixture copy and showing its report. The
## committed data files stay as they are.

const SCENE: String = "res://tools/anim_studio/studio.tscn"
const COPY: String = "user://test_studio_chain_and_save.json"

var _moves_text: String = ""


func before_all() -> void:
	_moves_text = FileAccess.get_file_as_string(MoveClips.PATH)


func before_each() -> void:
	var f: FileAccess = FileAccess.open(COPY, FileAccess.WRITE)
	f.store_string(_moves_text)
	f.close()


func after_each() -> void:
	assert_eq(FileAccess.get_file_as_string(MoveClips.PATH), _moves_text, "the committed move-clip table is untouched")


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY))


func _open(id: StringName) -> StudioEditor:
	var studio: AnimStudio = (load(SCENE) as PackedScene).instantiate() as AnimStudio
	add_child_autofree(studio)
	await get_tree().process_frame
	studio.open_editor(studio.catalogue.find(StudioCatalogue.KIND_MOVE, id))
	return studio.editor


## Points the editor's edits at the fixture copy and its save at a generator
## that finds no clip libraries (so it writes the data and regenerates
## nothing).
func _to_copy(editor: StudioEditor) -> void:
	editor.moves_file = COPY
	editor.saver = StudioSaver.new()
	editor.saver.table_path = "user://no_table.json"
	editor.saver.generated_files = PackedStringArray()
	editor.saver.regenerate = func(_p: Node) -> Dictionary: return {"code": 2}


func test_the_chain_panel_lists_the_parts_and_shows_the_speed_read_only() -> void:
	var editor: StudioEditor = await _open(&"k_iai")
	var panel: Node = editor.get_node("%ChainPanel")
	assert_eq((panel.get_node("Part0/Clip") as LineEdit).text, "SheatheHips01_R")
	assert_eq((panel.get_node("Part0/From") as SpinBox).value, 3.0)
	assert_eq((panel.get_node("Part0/To") as LineEdit).text, "12")
	assert_eq((panel.get_node("Part1/To") as LineEdit).text, "", "to the clip's end")
	assert_not_null(panel.get_node_or_null("AddPart"))
	assert_eq(editor.get_node("%SpeedLabel").text, "speed 1.3 (goes with the stand-ins)")


func test_a_hold_shows_read_only() -> void:
	var editor: StudioEditor = await _open(&"k_thrust")
	var held: Label = editor.get_node("%ChainPanel").get_node("Part1").get_child(0)
	assert_eq(held.text, "AttackPolearm01@8*4 · hold (goes with the stand-ins)")


func test_moving_a_part_down_is_a_pending_edit() -> void:
	var editor: StudioEditor = await _open(&"k_iai")
	_to_copy(editor)
	editor.open(editor.entry)
	var down: Button = editor.get_node("%ChainPanel").get_node("Part0").get_child(4)
	assert_eq(down.text, "↓")
	down.pressed.emit()
	assert_eq(ChainEdits.current(editor.session, COPY, &"katana", editor.move_entry), ["Attack1H04_R@2", "SheatheHips01_R@3-12"] as Array[String])
	assert_string_ends_with(editor.get_node("%EditorTitle").text, "· unsaved")


## Only with the packs: without them both chains fall back to the same
## stand-in clip, so the fighter's chain can't show the change.
func test_local_the_fighter_plays_the_pending_chain() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var editor: StudioEditor = await _open(&"k_iai")
	_to_copy(editor)
	editor.open(editor.entry)
	var before: Array[String] = editor.poser.chain.duplicate()
	(editor.get_node("%ChainPanel").get_node("Part0").get_child(4) as Button).pressed.emit()
	assert_ne(editor.poser.chain, before, "the fighter plays the pending chain")


func test_save_writes_the_copy_and_shows_the_report() -> void:
	var editor: StudioEditor = await _open(&"k_iai")
	_to_copy(editor)
	editor.open(editor.entry)
	var rows: Array[ChainEdits.Row] = editor.chain_rows()
	rows[0].from = 4.0
	assert_eq(editor.set_chain(rows).error, "")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_S
	key.ctrl_pressed = true
	key.pressed = true
	editor._unhandled_key_input(key)
	assert_not_null(editor.last_save, "Ctrl+S saved")
	assert_eq(editor.last_save.written, PackedStringArray([COPY]))
	assert_true(FileAccess.get_file_as_string(COPY).contains("\"SheatheHips01_R@4-12\""))
	var report: String = editor.get_node("%SaveReport").text
	assert_string_contains(report, "saved test_studio_chain_and_save.json")
	assert_string_contains(report, "table not regenerated: no clip libraries")
	assert_eq(editor.session.dirty_files(), PackedStringArray(), "nothing pending")


func test_a_bad_part_is_refused_and_says_why() -> void:
	var editor: StudioEditor = await _open(&"k_iai")
	var rows: Array[ChainEdits.Row] = editor.chain_rows()
	rows[0].clip = "NoSuchClip"
	assert_string_contains(editor.set_chain(rows).error, "not a clip")
	assert_string_contains(editor.get_node("%MarkerStatus").text, "not a clip")
	assert_eq(editor.session.dirty_files(), PackedStringArray())
