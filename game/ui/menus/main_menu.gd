class_name MainMenu
extends MenuScreen
## The main menu over the live duel, as the demo's: MONOMACHIA in gold and
## "一騎討ち · Single combat" over a panel of entries, each with its sublabel
## on the right, at the left of the screen so the fighters on the menu orbit
## stay in view. Entries are added as their screens land (main.gd); Back goes
## to the title (the page under it on the ScreenStack).


func _init() -> void:
	super()
	# the logo and tagline above the panel, the three together on the left
	remove_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = 110.0
	column.grow_horizontal = Control.GROW_DIRECTION_END
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var logo: Label = UiTheme.label("MONOMACHIA", UiTheme.DISPLAY, 64)
	logo.name = "Logo"
	logo.add_theme_color_override("font_color", UiPalette.GOLD)
	logo.add_theme_constant_override("shadow_outline_size", 12)
	column.add_child(logo)
	column.add_child(UiTheme.label("一騎討ち · Single combat", UiTheme.EYEBROW, 18))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 14.0)
	column.add_child(gap)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(500.0, 0.0)
	box.add_theme_constant_override("separation", 6)
	column.add_child(panel)
