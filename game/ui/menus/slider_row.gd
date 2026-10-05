class_name SliderRow
extends PanelContainer
## A menu row with a slider (the demo's volume sliders): a label, the slider
## and its value. A single item on its MenuPage: left and right move the
## value by one step, and the mouse drags the slider. Lit like a menu entry
## while focused (UiTheme.MENU_ROW_LIT).
##
## Emits changed when the value changes by the player's hand (keys, a
## controller or the mouse), not when set_value() is called.

signal changed(value: int)

var title: Label
var slider: HSlider
var readout: Label
var value: int = 0
var _quiet: bool = false


func _init(p_title: String, p_value: int, p_min: int = 0, p_max: int = 100, p_step: int = 5) -> void:
	theme_type_variation = UiTheme.MENU_ROW
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	title = UiTheme.label(p_title, UiTheme.EYEBROW, 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.custom_minimum_size = Vector2(190.0, 0.0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	slider = HSlider.new()
	slider.min_value = p_min
	slider.max_value = p_max
	slider.step = p_step
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(220.0, 0.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider)
	row.add_child(slider)
	readout = UiTheme.label("", UiTheme.MUTED, 18)
	readout.custom_minimum_size = Vector2(44.0, 0.0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	focus_entered.connect(func() -> void: theme_type_variation = UiTheme.MENU_ROW_LIT)
	focus_exited.connect(func() -> void: theme_type_variation = UiTheme.MENU_ROW)
	set_value(p_value)


## Sets the value (clamped and snapped to a step) without emitting changed.
func set_value(v: int) -> void:
	_quiet = true
	slider.value = v
	_quiet = false
	value = int(slider.value)
	readout.text = str(value)


## Left (-1) or right (+1) by one step. Returns whether the value moved.
func nav_step(dir: int) -> bool:
	var before: int = value
	slider.value = value + dir * slider.step
	return value != before


func _on_slider(v: float) -> void:
	value = int(v)
	readout.text = str(value)
	if not _quiet:
		changed.emit(value)
