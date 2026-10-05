class_name OptionRow
extends PanelContainer
## A menu row that picks one of a few options (the demo's .seg of .opt
## buttons): a label, then the options as chips, the chosen one lit. It is a
## single item on its MenuPage: left and right (and OK, which steps on) change
## the choice, wrapping round, and a click on a chip picks it. Lit like a
## menu entry while focused (UiTheme.MENU_ROW_LIT).
##
## Emits changed when the choice changes by the player's hand (keys, a
## controller or a click), not when set_index() is called.

signal changed(index: int)

var title: Label
var chips: Array[Button] = []
var index: int = 0
## The row of chips.
var seg: HBoxContainer
## The theme variations of an option and of the chosen one (use_cards()
## turns them into cards).
var chip_style: StringName = UiTheme.OPTION
var chip_on_style: StringName = UiTheme.OPTION_ON
## Shows only the chosen option, between arrows (show_only_chosen()), for a
## long list in a narrow panel.
var only_chosen: bool = false


func _init(p_title: String, options: Array[String], p_index: int = 0) -> void:
	theme_type_variation = UiTheme.MENU_ROW
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	title = UiTheme.label(p_title, UiTheme.EYEBROW, 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.custom_minimum_size = Vector2(190.0, 0.0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	seg = HBoxContainer.new()
	seg.add_theme_constant_override("separation", 6)
	row.add_child(seg)
	set_options(options, p_index)
	focus_entered.connect(func() -> void: theme_type_variation = UiTheme.MENU_ROW_LIT)
	focus_exited.connect(func() -> void: theme_type_variation = UiTheme.MENU_ROW)


## Replaces the options (a list that changes, as the Controls screen's
## profiles), choosing `i`, without emitting changed. The chip sizes and
## styles of use_cards() carry over.
func set_options(options: Array[String], i: int = 0) -> void:
	var chip_size: Vector2 = chips[0].custom_minimum_size if not chips.is_empty() else Vector2.ZERO
	for chip: Button in chips:
		# freed later: a chip's own click may have asked for the new options
		seg.remove_child(chip)
		chip.queue_free()
	chips.clear()
	for n: int in options.size():
		var chip: Button = Button.new()
		chip.text = options[n]
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = chip_size
		chip.pressed.connect(_on_chip.bind(n))
		seg.add_child(chip)
		chips.append(chip)
	set_index(i)


## Chooses an option without emitting changed.
func set_index(i: int) -> void:
	index = clampi(i, 0, chips.size() - 1)
	for c: int in chips.size():
		chips[c].theme_type_variation = chip_on_style if c == index else chip_style
		if only_chosen:
			chips[c].visible = c == index


## Shows only the chosen option, between a ‹ and a › that step it (as left
## and right do), so a long list fits a narrow panel.
func show_only_chosen() -> void:
	if only_chosen:
		return
	only_chosen = true
	for pair: Array in [["‹", -1, 0], ["›", 1, -1]]:
		var arrow: Button = Button.new()
		arrow.name = "Prev" if int(pair[1]) < 0 else "Next"
		arrow.text = pair[0]
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.pressed.connect(func() -> void:
			if not has_focus():
				grab_focus()
			if nav_step(int(pair[1])):
				GameServices.play_ui(&"ui_move"))
		seg.add_child(arrow)
		if int(pair[2]) == 0:
			seg.move_child(arrow, 0)
	set_index(index)


## Shows the options as cards (UiTheme.CARD, the chosen one CARD_ON) of
## at least `min_size`, as the fighter select's grid does.
func use_cards(min_size: Vector2) -> void:
	chip_style = UiTheme.CARD
	chip_on_style = UiTheme.CARD_ON
	for chip: Button in chips:
		chip.custom_minimum_size = min_size
	set_index(index)


## Left (-1) or right (+1), wrapping round. Returns whether the choice moved.
func nav_step(dir: int) -> bool:
	if chips.size() < 2:
		return false
	set_index(posmod(index + dir, chips.size()))
	changed.emit(index)
	return true


## OK steps on to the next option.
func nav_press() -> void:
	if nav_step(1):
		GameServices.play_ui(&"ui_move")


func _on_chip(i: int) -> void:
	if not has_focus():
		grab_focus()
	GameServices.play_ui(&"ui_select")
	if i == index:
		return
	set_index(i)
	changed.emit(index)
