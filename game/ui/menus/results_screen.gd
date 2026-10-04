class_name ResultsScreen
extends MenuScreen
## The results after a match (port of showResults() in v0.1-web-mvp:src/ui/menus.ts): the
## kanji over the headline (Victory, Defeat, or the winner's name in Watch and
## Versus), the rounds, and the demo's seven per-fighter stats with each side
## in its colour; then Rematch, Change fighters and Main menu. Back goes to
## the main menu.

signal rematch
signal change_fighters
signal main_menu

var _kanji: Label
var _title: Label
var _rounds: Label
var _grid: GridContainer
var results: MatchResults
var rematch_button: Button
var change_button: Button
var menu_button: Button


func _init() -> void:
	super()
	_kanji = add_label("", UiTheme.KANJI, 48)
	_kanji.name = "Kanji"
	_title = add_heading("Victory", 58)
	_title.name = "Headline"
	_rounds = add_label("", UiTheme.MUTED, 26)
	_grid = GridContainer.new()
	_grid.name = "Stats"
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 36)
	_grid.add_theme_constant_override("v_separation", 2)
	box.add_child(_grid)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 4.0)
	box.add_child(gap)
	rematch_button = add_button("Rematch", "", func() -> void: rematch.emit())
	change_button = add_button("Change fighters", "", func() -> void: change_fighters.emit())
	menu_button = add_button("Main menu", "", func() -> void: main_menu.emit())
	# the entries side by side, as the demo's button row: left and right walk
	# them as up and down do
	var entries: HBoxContainer = HBoxContainer.new()
	entries.name = "Entries"
	entries.alignment = BoxContainer.ALIGNMENT_CENTER
	entries.add_theme_constant_override("separation", 10)
	box.add_child(entries)
	for b: Button in buttons:
		b.reparent(entries)
		b.custom_minimum_size.x = 0.0
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_pops = false
	back_requested.connect(func() -> void: main_menu.emit())


## A side's colour on this screen: its palette's colour, lightened to read on
## the dark panel.
static func side_color(palette: int) -> Color:
	return LookPalette.side_color(palette).lightened(0.35)


## Fills the screen from a match's results (its ScreenStack opens it).
func show_results(r: MatchResults) -> void:
	results = r
	_kanji.text = r.kanji()
	_title.text = r.title()
	if r.winner >= 0 and r.for_one_player():
		_title.add_theme_color_override("font_color", UiPalette.GOLD if r.winner == r.player_side else UiPalette.HP_HI)
	elif r.winner >= 0:
		_title.add_theme_color_override("font_color", side_color(r.palettes[r.winner]))
	else:
		_title.remove_theme_color_override("font_color")
	_rounds.text = "Rounds  %d – %d   ·   %d fought" % [r.wins[0], r.wins[1], r.rounds]
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cell("", UiTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	for i: int in 2:
		var side: Label = _cell("%s\n%s" % [r.names[i], r.weapons[i]], UiTheme.DISPLAY, HORIZONTAL_ALIGNMENT_CENTER)
		side.name = "Side%d" % i
		side.add_theme_color_override("font_color", side_color(r.palettes[i]))
	_row("Rounds won", [str(r.wins[0]), str(r.wins[1])])
	for row: Array in MatchResults.STATS:
		_row(String(row[1]), [r.stat_text(0, row[0]), r.stat_text(1, row[0])], String(row[0]))


## The stat cell of a side in the row named `field` (or "rounds"), for tests.
func cell(field: String, side: int) -> Label:
	return _grid.get_node_or_null("%s_%d" % [field, side]) as Label


func _row(label: String, values: Array[String], field: String = "rounds") -> void:
	_cell(label, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	for i: int in 2:
		var v: Label = _cell(values[i], &"", HORIZONTAL_ALIGNMENT_CENTER)
		v.name = "%s_%d" % [field, i]
		v.add_theme_color_override("font_color", side_color(results.palettes[i]))


func _cell(text: String, variation: StringName, align: HorizontalAlignment) -> Label:
	var l: Label = UiTheme.label(text, variation, 22)
	l.horizontal_alignment = align
	l.custom_minimum_size = Vector2(150.0, 0.0)
	_grid.add_child(l)
	return l
