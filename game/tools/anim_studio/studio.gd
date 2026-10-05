class_name AnimStudio
extends Control
## The Animation Studio: a local dev tool for looking at the game's animations
## and setting their markers (docs/specs/animation-studio.md, slimmed by
## docs/specs/milestone-1.md). A top bar holds the Hunter/Rogue switch and the
## packs-missing note; the area below shows either the gallery or the editor,
## across the whole width. Open it with `node scripts/godot.mjs studio`.
##
## The gallery fills the area (the Hunter/Rogue switch above re-sets up its
## tiles, and a click on a tile opens the editor); the editor (StudioEditor,
## milestone-1 task 25) shows the entry on a timeline with its frames and
## bands, and tasks 26-27 add marker editing, chains and save. The areas keep
## these unique names: %Gallery, %Editor (the editor's panel).

## The gallery-wide body changed: `fighter_id` is &"hunter" (the HumanM clips) or
## &"rogue" (the HumanF clips).
signal body_changed(fighter_id: StringName)

## The body the gallery and editor play on.
var fighter_id: StringName = &"hunter"
## Every animation the Studio shows, read from the data files the game reads.
var catalogue: StudioCatalogue = null
## The catalogue entry open in the editor, or null while the gallery shows.
var current_entry: StudioCatalogue.Entry = null
## The editor, in the editor's panel.
var editor: StudioEditor = null

@onready var _gallery: Gallery = %Gallery
@onready var _editor: Control = %Editor
@onready var _hunter_button: Button = %HunterButton
@onready var _rogue_button: Button = %RogueButton
@onready var _packs_note: Label = %PacksNote


func _ready() -> void:
	_packs_note.text = ClipLibraries.MISSING_NOTE
	_packs_note.visible = not ClipLibraries.available()
	_hunter_button.toggled.connect(_on_body_button.bind(&"hunter"))
	_rogue_button.toggled.connect(_on_body_button.bind(&"rogue"))
	var manifest: ClipManifest = ClipManifest.read()
	catalogue = StudioCatalogue.build(manifest, MoveClips.read(manifest), StateClips.read(), StudioLibraries.keyed().get_animation_list())
	_gallery.setup(catalogue, fighter_id)
	_gallery.opened.connect(open_editor)
	body_changed.connect(_gallery.set_fighter)
	editor = StudioEditor.new()
	editor.name = "StudioEditor"
	_editor.add_child(editor)
	editor.back_requested.connect(show_gallery)
	body_changed.connect(_on_body_changed)
	show_gallery()


## Show the gallery in the central area and close the editor.
func show_gallery() -> void:
	current_entry = null
	if editor != null:
		editor.close()
	_gallery.visible = true
	_editor.visible = false


## Show the editor in the central area for `entry` and hide the gallery.
func open_editor(entry: StudioCatalogue.Entry) -> void:
	current_entry = entry
	_gallery.visible = false
	_editor.visible = true
	if entry != null:
		editor.open(entry, fighter_id)


## Choose the body (&"hunter" or &"rogue"); says so only when it changes.
func set_fighter(id: StringName) -> void:
	if id == fighter_id:
		return
	fighter_id = id
	_hunter_button.set_pressed_no_signal(id == &"hunter")
	_rogue_button.set_pressed_no_signal(id == &"rogue")
	body_changed.emit(id)


## The editor shows its entry on the new body.
func _on_body_changed(id: StringName) -> void:
	if current_entry != null:
		editor.open(current_entry, id)


func _on_body_button(pressed: bool, id: StringName) -> void:
	if pressed:
		set_fighter(id)
