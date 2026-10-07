extends GutTest
## The results screen (task 22.8): the kanji and headline, the rounds, the
## seven stats per side in each side's colour, and Rematch, Change fighters
## and Main menu, walked with keys and with a controller.

var screen: ResultsScreen
var stack: ScreenStack


func before_each() -> void:
	screen = ResultsScreen.new()
	add_child_autofree(screen)
	stack = ScreenStack.new()


func _results(mode: StringName = MatchConfig.DUEL, winner: int = 1, player_side: int = 0) -> MatchResults:
	var r: MatchResults = MatchResults.new()
	r.mode = mode
	r.winner = winner
	r.player_side = player_side
	r.wins.assign([1, 3] if winner == 1 else [3, 2])
	r.rounds = 4 if winner == 1 else 5
	r.names = ["Rogue", "Hunter"] as Array[String]
	r.weapons = ["Katana", "Greatsword"] as Array[String]
	r.stats = [
		{"hits_landed": 12, "damage_dealt": 140.4, "blocks": 9, "parries": 3, "counters": 1, "disarms": 0, "ultimates": 1},
		{"hits_landed": 20, "damage_dealt": 301.6, "blocks": 4, "parries": 0, "counters": 2, "disarms": 1, "ultimates": 0},
	] as Array[Dictionary]
	return r


func _show(r: MatchResults) -> void:
	screen.show_results(r)
	stack.reset([screen] as Array[MenuPage])
	await get_tree().process_frame


func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		get_viewport().push_input(e)


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		get_viewport().push_input(e)


func _kanji() -> Label:
	return screen.find_child("Kanji", true, false) as Label


func _headline() -> Label:
	return screen.find_child("Headline", true, false) as Label


func test_a_lost_duel_shows_defeat_with_its_kanji() -> void:
	await _show(_results(MatchConfig.DUEL, 1, 0))
	assert_eq(_kanji().text, "敗北")
	assert_eq(_kanji().theme_type_variation, UiTheme.KANJI)
	assert_eq(_headline().text, "Defeat")
	assert_eq(_headline().get_theme_color(&"font_color"), UiPalette.CRIMSON)


func test_a_won_duel_shows_victory_in_gold() -> void:
	await _show(_results(MatchConfig.DUEL, 0, 0))
	assert_eq(_kanji().text, "勝利")
	assert_eq(_headline().text, "Victory")
	assert_eq(_headline().get_theme_color(&"font_color"), UiPalette.GOLD)


## Training speaks to its one player too: its headline takes the same colours
## as its title and kanji.
func test_training_shows_victory_and_defeat_in_gold_and_red() -> void:
	await _show(_results(MatchConfig.TRAINING, 0, 0))
	assert_eq([_kanji().text, _headline().text], ["勝利", "Victory"])
	assert_eq(_headline().get_theme_color(&"font_color"), UiPalette.GOLD)
	await _show(_results(MatchConfig.TRAINING, 1, 0))
	assert_eq(_headline().text, "Defeat")
	assert_eq(_headline().get_theme_color(&"font_color"), UiPalette.CRIMSON)


func test_watch_and_versus_name_the_winner_in_their_colour() -> void:
	for mode: StringName in [MatchConfig.WATCH, MatchConfig.VERSUS]:
		await _show(_results(mode, 1, -1 if mode == MatchConfig.WATCH else 0))
		assert_eq(_kanji().text, "決着", String(mode))
		assert_eq(_headline().text, "Hunter wins", String(mode))
		assert_eq(_headline().get_theme_color(&"font_color"), ResultsScreen.side_color(1), String(mode))


func test_a_mirror_match_s_winner_carries_the_side_s_seal() -> void:
	var r: MatchResults = _results(MatchConfig.WATCH, 1, -1)
	r.names = ["Hunter", "Hunter"] as Array[String]
	await _show(r)
	assert_eq(_headline().text, "Hunter 青 wins")
	assert_eq(_headline().get_theme_color(&"font_color"), ResultsScreen.side_color(r.palettes[1]))


func test_a_draw_says_so() -> void:
	await _show(_results(MatchConfig.DUEL, -1, 0))
	assert_eq(_kanji().text, "引分")
	assert_eq(_headline().text, "Draw")


func test_the_rounds_and_seven_stats_per_side_in_each_sides_colour() -> void:
	var r: MatchResults = _results()
	await _show(r)
	assert_eq(screen.cell("rounds", 0).text, "1")
	assert_eq(screen.cell("rounds", 1).text, "3")
	var expected: Dictionary = {
		"hits_landed": ["12", "20"], "damage_dealt": ["140", "302"], "blocks": ["9", "4"], "parries": ["3", "0"],
		"counters": ["1", "2"], "disarms": ["0", "1"], "ultimates": ["1", "0"],
	}
	assert_eq(MatchResults.STATS.size(), 7)
	for row: Array in MatchResults.STATS:
		for side: int in 2:
			var c: Label = screen.cell(row[0], side)
			assert_eq(c.text, expected[row[0]][side], "%s side %d" % [row[0], side])
			assert_eq(c.get_theme_color(&"font_color"), ResultsScreen.side_color(side), "%s side %d's colour" % [row[0], side])
	var side_name: Label = screen.find_child("Side1", true, false) as Label
	assert_eq(side_name.text, "Hunter\nGreatsword")
	assert_eq(side_name.get_theme_color(&"font_color"), ResultsScreen.side_color(1))


## A mirror match's second side wears another palette, and the table follows.
func test_the_colours_follow_each_sides_palette() -> void:
	var r: MatchResults = _results()
	r.palettes = [0, 2] as Array[int]
	await _show(r)
	assert_eq(screen.cell("hits_landed", 1).get_theme_color(&"font_color"), ResultsScreen.side_color(2))
	assert_ne(ResultsScreen.side_color(2), ResultsScreen.side_color(1))


func test_showing_new_results_replaces_the_old_table() -> void:
	await _show(_results())
	var count: int = screen.find_child("Stats", true, false).get_child_count()
	await _show(_results(MatchConfig.DUEL, 0, 0))
	await get_tree().process_frame
	assert_eq(screen.find_child("Stats", true, false).get_child_count(), count)
	assert_eq(screen.cell("rounds", 0).text, "3")


func test_the_entries_are_rematch_change_fighters_and_main_menu() -> void:
	await _show(_results())
	assert_eq(screen.buttons.map(func(b: Button) -> String: return b.text), ["Rematch", "Change fighters", "Main menu"])
	assert_eq(screen.focused_item(), screen.rematch_button, "Rematch first")


func test_keys_choose_each_entry() -> void:
	await _show(_results())
	watch_signals(screen)
	_key(KEY_ENTER)
	assert_signal_emit_count(screen, "rematch", 1)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	assert_signal_emit_count(screen, "change_fighters", 1)
	_key(KEY_DOWN)
	_key(KEY_SPACE)
	assert_signal_emit_count(screen, "main_menu", 1)
	_key(KEY_ESCAPE)
	assert_signal_emit_count(screen, "main_menu", 2, "Back goes to the main menu")
	assert_eq(stack.top(), screen, "and leaves the stack to main.gd")


func test_a_controller_chooses_each_entry() -> void:
	await _show(_results())
	watch_signals(screen)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_A)
	assert_signal_emit_count(screen, "change_fighters", 1)
	_pad(JOY_BUTTON_DPAD_UP)
	_pad(JOY_BUTTON_A)
	assert_signal_emit_count(screen, "rematch", 1)
	_pad(JOY_BUTTON_B)
	assert_signal_emit_count(screen, "main_menu", 1)
