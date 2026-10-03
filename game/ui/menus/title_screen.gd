class_name TitleScreen
extends Control
## The title over the live duel behind it: the name, a line, and "press any
## key or button". Any key, mouse button or controller button goes on.
## Keys and buttons are taken in _unhandled_input() (never in _input(), so the
## InputFeed sees them too); a click lands on the screen itself. Going on
## plays ui_confirm.

signal proceed

var _prompt: Label
var _time: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_bottom = -110.0
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	# the demo's logo is gold, its tagline and prompt spaced-out capitals
	var name_label: Label = UiTheme.label("MONOMACHIA", UiTheme.DISPLAY, 104)
	name_label.add_theme_color_override("font_color", UiPalette.GOLD)
	name_label.add_theme_constant_override("shadow_outline_size", 16)
	column.add_child(name_label)
	column.add_child(UiTheme.label("Single combat", UiTheme.EYEBROW, 24))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 40.0)
	column.add_child(gap)
	_prompt = UiTheme.label("Press any key or button", UiTheme.EYEBROW, 22)
	_prompt.add_theme_color_override("font_color", UiPalette.PAPER)
	column.add_child(_prompt)


func open() -> void:
	visible = true
	_time = 0.0


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_prompt.modulate.a = 0.55 + 0.45 * cos(_time * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if _goes_on(event):
		get_viewport().set_input_as_handled()
		_go_on()


## A click on the title (it stops the mouse, so clicks end here).
func _gui_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and _goes_on(event):
		accept_event()
		_go_on()


func _go_on() -> void:
	GameServices.play_ui(&"ui_confirm")
	proceed.emit()


static func _goes_on(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false
