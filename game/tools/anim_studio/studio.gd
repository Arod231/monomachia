class_name AnimStudio
extends Control
## The Animation Studio: a local dev tool for looking at and refining the game's
## animations (docs/specs/animation-studio.md). A top bar holds the Hunter/Rogue
## switch and the packs-missing note; the central area shows either the gallery
## or the editor; the chat panel is docked on the right and can be collapsed.
## Open it with `node scripts/godot.mjs studio`.
##
## The gallery fills the central area (the Hunter/Rogue switch above re-sets up
## its tiles, and a click on a tile opens the editor); the editor and chat areas
## are still empty placeholders that later tasks fill. Their nodes keep these
## unique names so those tasks (and the smoke test) can find them: %Gallery,
## %Editor, %ChatPanel.

## The gallery-wide body changed: `fighter_id` is &"hunter" (the HumanM clips) or
## &"rogue" (the HumanF clips).
signal body_changed(fighter_id: StringName)

## The body the gallery and editor play on.
var fighter_id: StringName = &"hunter"
## Every animation the Studio shows, read from the data files the game reads.
var catalogue: StudioCatalogue = null
## The catalogue entry open in the editor, or null while the gallery shows.
var current_entry: StudioCatalogue.Entry = null

@onready var _gallery: Gallery = %Gallery
@onready var _editor: Control = %Editor
@onready var _chat_panel: Control = %ChatPanel
@onready var _chat_toggle: Button = %ChatToggle
@onready var _hunter_button: Button = %HunterButton
@onready var _rogue_button: Button = %RogueButton
@onready var _packs_note: Label = %PacksNote


func _ready() -> void:
	_packs_note.text = ClipLibraries.MISSING_NOTE
	_packs_note.visible = not ClipLibraries.available()
	_hunter_button.toggled.connect(_on_body_button.bind(&"hunter"))
	_rogue_button.toggled.connect(_on_body_button.bind(&"rogue"))
	_chat_toggle.toggled.connect(_on_chat_toggled)
	var manifest: ClipManifest = ClipManifest.read()
	catalogue = StudioCatalogue.build(manifest, MoveClips.read(manifest), StateClips.read(), StudioLibraries.keyed().get_animation_list())
	_gallery.setup(catalogue, fighter_id)
	_gallery.opened.connect(open_editor)
	body_changed.connect(_gallery.set_fighter)
	show_gallery()


## Show the gallery in the central area and close the editor.
func show_gallery() -> void:
	current_entry = null
	_gallery.visible = true
	_editor.visible = false


## Show the editor in the central area for `entry` and hide the gallery.
func open_editor(entry: StudioCatalogue.Entry) -> void:
	current_entry = entry
	_gallery.visible = false
	_editor.visible = true


## Hide or show the chat panel on the right.
func set_chat_collapsed(collapsed: bool) -> void:
	_chat_panel.visible = not collapsed
	_chat_toggle.set_pressed_no_signal(not collapsed)


## Choose the body (&"hunter" or &"rogue"); says so only when it changes.
func set_fighter(id: StringName) -> void:
	if id == fighter_id:
		return
	fighter_id = id
	_hunter_button.set_pressed_no_signal(id == &"hunter")
	_rogue_button.set_pressed_no_signal(id == &"rogue")
	body_changed.emit(id)


func _on_body_button(pressed: bool, id: StringName) -> void:
	if pressed:
		set_fighter(id)


func _on_chat_toggled(open: bool) -> void:
	set_chat_collapsed(not open)
