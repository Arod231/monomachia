class_name KeyCap
extends PanelContainer
## A key or button name drawn as a key cap (the demo's kbd): the name in
## ivory on black lacquer, in a thin gold-dim border with a heavier bottom edge and
## rounded corners, at least 1.4 of its text's height wide. The HUD's prompts
## (24.4) draw every key they name with one.

## The name shown.
var text: String:
	get:
		return _label.text

var _label: Label


func _init(p_text: String = "", font_size: int = 17) -> void:
	name = "KeyCap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.LACQUER_RAISED
	box.border_color = UiPalette.GOLD_DIM
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.set_corner_radius_all(3)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	add_theme_stylebox_override("panel", box)
	_label = Label.new()
	_label.name = "Name"
	_label.text = p_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", UiPalette.IVORY)
	_label.custom_minimum_size.x = roundf(font_size * 1.4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
