extends GutTest
## The Animation Studio's shell (docs/specs/animation-studio.md, task 1): the
## scene builds headless with its three areas (gallery, editor, chat panel),
## swaps between the gallery and the editor, collapses the chat panel and
## reports a Hunter/Rogue switch. It needs no clip libraries.

const SCENE: String = "res://tools/anim_studio/studio.tscn"


func _studio() -> AnimStudio:
	var packed: PackedScene = load(SCENE) as PackedScene
	assert_not_null(packed, "the scene loads")
	var studio: AnimStudio = packed.instantiate() as AnimStudio
	add_child_autofree(studio)
	await get_tree().process_frame
	await get_tree().process_frame
	return studio


func test_the_three_areas_exist() -> void:
	var studio: AnimStudio = await _studio()
	assert_not_null(studio.get_node_or_null("%Gallery"), "the gallery area")
	assert_not_null(studio.get_node_or_null("%Editor"), "the editor area")
	assert_not_null(studio.get_node_or_null("%ChatPanel"), "the chat panel")
	assert_not_null(studio.get_node_or_null("%TopBar"), "the top bar")


func test_it_opens_on_the_gallery() -> void:
	var studio: AnimStudio = await _studio()
	assert_true((studio.get_node("%Gallery") as Control).visible, "the gallery shows")
	assert_false((studio.get_node("%Editor") as Control).visible, "the editor is hidden")


func test_open_editor_swaps_to_the_editor_and_show_gallery_swaps_back() -> void:
	var studio: AnimStudio = await _studio()
	studio.open_editor(null)
	assert_false((studio.get_node("%Gallery") as Control).visible, "the gallery hides")
	assert_true((studio.get_node("%Editor") as Control).visible, "the editor shows")
	studio.show_gallery()
	assert_true((studio.get_node("%Gallery") as Control).visible, "the gallery is back")
	assert_false((studio.get_node("%Editor") as Control).visible, "the editor hides again")


func test_the_chat_panel_collapses_and_expands() -> void:
	var studio: AnimStudio = await _studio()
	var chat: Control = studio.get_node("%ChatPanel")
	assert_true(chat.visible, "the chat panel starts open")
	studio.set_chat_collapsed(true)
	assert_false(chat.visible, "collapsed")
	studio.set_chat_collapsed(false)
	assert_true(chat.visible, "open again")


func test_the_body_toggle_reports_the_fighter() -> void:
	var studio: AnimStudio = await _studio()
	assert_eq(studio.fighter_id, &"hunter", "starts on the Hunter")
	watch_signals(studio)
	studio.set_fighter(&"rogue")
	assert_eq(studio.fighter_id, &"rogue", "the Rogue is chosen")
	assert_signal_emitted_with_parameters(studio, "body_changed", [&"rogue"])
	studio.set_fighter(&"rogue")
	assert_signal_emit_count(studio, "body_changed", 1, "choosing the same body again says nothing")
	studio.set_fighter(&"hunter")
	assert_signal_emitted_with_parameters(studio, "body_changed", [&"hunter"])


func test_the_toggle_buttons_choose_the_body() -> void:
	var studio: AnimStudio = await _studio()
	(studio.get_node("%RogueButton") as Button).button_pressed = true
	assert_eq(studio.fighter_id, &"rogue", "the Rogue button picks the Rogue")
	(studio.get_node("%HunterButton") as Button).button_pressed = true
	assert_eq(studio.fighter_id, &"hunter", "the Hunter button picks the Hunter")


func test_the_packs_note_follows_the_libraries() -> void:
	ClipLibraries.force_missing = true
	var studio: AnimStudio = await _studio()
	var note: Label = studio.get_node("%PacksNote")
	assert_true(note.visible, "the note shows without the packs")
	assert_eq(note.text, ClipLibraries.MISSING_NOTE, "it says what the match says")
	ClipLibraries.force_missing = false


func after_each() -> void:
	ClipLibraries.force_missing = false


func test_buttons_and_labels_share_one_font() -> void:
	var studio: AnimStudio = await _studio()
	var button_font: Font = (studio.get_node("%HunterButton") as Button).get_theme_font(&"font")
	var label_font: Font = (studio.get_node("%PacksNote") as Label).get_theme_font(&"font")
	var search_font: Font = ((studio.get_node("%Gallery") as Gallery).get_node("%Search") as LineEdit).get_theme_font(&"font")
	var tabs_font: Font = ((studio.get_node("%Gallery") as Gallery).get_node("%Tabs") as TabContainer).get_theme_font(&"font")
	assert_not_null(button_font, "buttons have a font")
	assert_same(button_font, label_font, "buttons and labels use the same font, not the project's serif")
	assert_same(button_font, search_font, "so does the search box")
	assert_same(button_font, tabs_font, "and the tabs")
