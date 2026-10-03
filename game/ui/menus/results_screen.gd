class_name ResultsScreen
extends MenuScreen
## The results after a match: who won, the rounds won, and the demo's seven
## per-fighter stats, with Rematch and Main menu.

signal rematch
signal main_menu

var _title: Label
var _rounds: Label
var _grid: GridContainer
var results: MatchResults


func _init() -> void:
	super()
	_title = add_heading("Victory", 64)
	_rounds = add_label("", UiTheme.MUTED, 26)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 36)
	_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_grid)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 12.0)
	box.add_child(gap)
	add_button("Rematch", "", func() -> void: rematch.emit())
	add_button("Main menu", "", func() -> void: main_menu.emit())
	back_requested.connect(func() -> void: main_menu.emit())


## Fills the screen from a match's results.
func show_results(r: MatchResults) -> void:
	results = r
	_title.text = r.title()
	if r.winner >= 0 and r.player_side >= 0 and r.mode == MatchConfig.DUEL:
		_title.add_theme_color_override("font_color", UiPalette.GOLD if r.winner == r.player_side else UiPalette.HP_HI)
	else:
		_title.remove_theme_color_override("font_color")
	_rounds.text = "Rounds  %d – %d   ·   %d fought" % [r.wins[0], r.wins[1], r.rounds]
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cell("", UiTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	for i: int in 2:
		var side: Label = _cell("%s\n%s" % [r.names[i], r.weapons[i]], UiTheme.DISPLAY, HORIZONTAL_ALIGNMENT_CENTER)
		side.add_theme_color_override("font_color", LookPalette.SIDE_COLORS[i].lightened(0.35))
	_cell("Rounds won", UiTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(str(r.wins[0]), &"", HORIZONTAL_ALIGNMENT_CENTER)
	_cell(str(r.wins[1]), &"", HORIZONTAL_ALIGNMENT_CENTER)
	for row: Array in MatchResults.STATS:
		_cell(String(row[1]), UiTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		_cell(r.stat_text(0, row[0]), &"", HORIZONTAL_ALIGNMENT_CENTER)
		_cell(r.stat_text(1, row[0]), &"", HORIZONTAL_ALIGNMENT_CENTER)
	open()


func _cell(text: String, variation: StringName, align: HorizontalAlignment) -> Label:
	var l: Label = UiTheme.label(text, variation, 22)
	l.horizontal_alignment = align
	l.custom_minimum_size = Vector2(150.0, 0.0)
	_grid.add_child(l)
	return l
