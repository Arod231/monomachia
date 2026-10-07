class_name MenuScreen
extends MenuPage
## A menu page laid out as a panel centred over the live duel behind it: a
## heading, some text and a column of entries and rows. The UI theme
## (ui/theme/lacquer_gold.tres) draws the panel, the headings (UiTheme.DISPLAY)
## and the entries (UiTheme.MENU_ENTRY). MenuPage walks it with the keys,
## the mouse or a controller.

var panel: PanelContainer
var box: VBoxContainer
## The entries (add_button), in order.
var buttons: Array[Button] = []


func _init() -> void:
	super()
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


## An entry, with an optional sublabel on its right (the demo's .mbtn small:
## small spaced capitals in the dimmed ivory), named "Sub".
func add_button(text: String, sub: String, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = UiTheme.MENU_ENTRY
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380.0, 56.0)
	if sub != "":
		var small: Label = UiTheme.label(sub, UiTheme.EYEBROW, 13)
		small.name = "Sub"
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		small.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		small.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		small.offset_left = -260.0
		small.offset_right = -18.0
		b.add_child(small)
	b.pressed.connect(on_pressed)
	box.add_child(b)
	buttons.append(b)
	add_item(b)
	return b


## An option row (OptionRow) under the last.
func add_options(title: String, options: Array[String], index: int, on_changed: Callable) -> OptionRow:
	var row: OptionRow = OptionRow.new(title, options, index)
	row.changed.connect(on_changed)
	box.add_child(row)
	add_item(row)
	return row


## A slider row (SliderRow) under the last.
func add_slider(title: String, value: int, on_changed: Callable) -> SliderRow:
	var row: SliderRow = SliderRow.new(title, value)
	row.changed.connect(on_changed)
	box.add_child(row)
	add_item(row)
	return row


## The focused entry, or null.
func focused_button() -> Button:
	var f: Control = focused_item()
	return f as Button if f is Button and buttons.has(f) else null
