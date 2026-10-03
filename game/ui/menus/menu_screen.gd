class_name MenuScreen
extends Control
## A plain full-screen menu panel for the playable skeleton (task 22 brings
## the real menus): a title, some text and a column of buttons, centred over
## the live duel behind it. The UI theme (ui/theme/ink_wash.tres) draws the
## panel, the headings (UiTheme.DISPLAY) and the buttons (UiTheme.MENU_ENTRY).
##
## Navigable with the keyboard (arrows or W/S, Enter or Space, Esc or
## Backspace for back), the mouse, and a controller (D-pad or left stick, A to
## choose, B for back). Godot's ui_* actions cover the arrows, Enter and the
## stick; this adds W/S and the controller's A and B buttons, which the
## default ui_accept and ui_cancel lack.
##
## The menus act in _unhandled_input(), after the GUI, and never take an
## event in _input(): the InputFeed (GameServices) sees every event in
## _input(), and a node that takes one there hides it from the feed.
##
## Sounds (GameServices.play_ui): ui_move when the focus moves from one of its
## buttons to another (keys, controller or mouse; opening the screen is
## silent), ui_select when a button is pressed, ui_back on Back.

## Back (Esc, Backspace, controller B) was pressed while the screen is open.
signal back_requested

var panel: PanelContainer
var box: VBoxContainer
var buttons: Array[Button] = []
## The button that last lost the focus, while the focus is between buttons.
var _left: Button = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)


## A label in one of the theme's variations (UiTheme), under the last.
func add_label(text: String, variation: StringName = &"", font_size: int = 0) -> Label:
	var l: Label = UiTheme.label(text, variation, font_size)
	box.add_child(l)
	return l


## The screen's title, in the display font.
func add_heading(text: String, font_size: int = 52) -> Label:
	return add_label(text, UiTheme.DISPLAY, font_size)


## A button with an optional smaller line under its label.
func add_button(text: String, sub: String, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text if sub == "" else "%s\n%s" % [text, sub]
	b.theme_type_variation = UiTheme.MENU_ENTRY
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380.0, 72.0 if sub != "" else 52.0)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(GameServices.play_ui.bind(&"ui_select"))
	b.pressed.connect(on_pressed)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(_on_button_focused.bind(b))
	b.focus_exited.connect(func() -> void: _left = b)
	box.add_child(b)
	buttons.append(b)
	_link_focus()
	return b


## Shows the screen and focuses its first button.
func open() -> void:
	visible = true
	_left = null
	if not buttons.is_empty() and is_inside_tree():
		buttons[0].grab_focus.call_deferred()


func close() -> void:
	visible = false


func focused_button() -> Button:
	if not is_inside_tree():
		return null
	var f: Control = get_viewport().gui_get_focus_owner()
	return f as Button if f is Button and buttons.has(f) else null


func _on_button_focused(b: Button) -> void:
	if _left != null and _left != b:
		GameServices.play_ui(&"ui_move")
	_left = null


func _link_focus() -> void:
	for i: int in buttons.size():
		var b: Button = buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if _is_back(event):
		get_viewport().set_input_as_handled()
		GameServices.play_ui(&"ui_back")
		back_requested.emit()
		return
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		if jb.pressed and jb.button_index == JOY_BUTTON_A:
			var b: Button = focused_button()
			if b != null:
				get_viewport().set_input_as_handled()
				b.pressed.emit()
			return
	if event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and (k.physical_keycode == KEY_W or k.physical_keycode == KEY_S):
			var b: Button = focused_button()
			if b == null and not buttons.is_empty():
				buttons[0].grab_focus()
			elif b != null:
				var i: int = buttons.find(b)
				var step: int = -1 if k.physical_keycode == KEY_W else 1
				buttons[(i + step + buttons.size()) % buttons.size()].grab_focus()
			get_viewport().set_input_as_handled()
	# a focus lost to a click outside comes back on the next move
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if focused_button() == null and not buttons.is_empty():
			buttons[0].grab_focus()
			get_viewport().set_input_as_handled()


static func _is_back(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey:
		var k: InputEventKey = event
		return k.pressed and not k.echo and k.physical_keycode == KEY_BACKSPACE
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		return jb.pressed and jb.button_index == JOY_BUTTON_B
	return false
