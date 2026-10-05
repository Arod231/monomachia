extends GutTest
## Watch through the select (task 23.5): two computer sides with the skill
## picked for each, the side-on Watch camera, no human input sampled (Esc
## still pauses), the HUD's Watch form, and results naming the winner in
## the side's colour, with the side's seal in a mirror match.

const MainScript := preload("res://scenes/main.gd")
## Twelve minutes of rules time, as the soak run allows.
const MATCH_LIMIT: int = 60 * 60 * 12

var fake: FakeDeviceState


func _host() -> MatchHost:
	var host: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	fake = FakeDeviceState.new()
	host.input = InputDevices.new(fake)
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	return host


func _watch(rogue_mirror: bool = false, seed_value: int = 11) -> MatchConfig:
	return MatchConfig.make(
		MatchConfig.WATCH,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"rogue" if rogue_mirror else &"hunter", &"daggers", 1, &"hard"),
		seed_value,
		ArenaScenes.STANDIN,
	)


func test_the_watch_select_starts_two_computers_with_their_skills_on_the_watch_camera() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	var host: MatchHost = main.get_node("MatchHost")
	host.auto_run = false
	main.call("open_select", MatchConfig.WATCH)
	var select: FighterSelect = main.get("select")
	assert_true(select.skill_row.visible, "the red fighter has a skill row")
	select.skill_row.set_index(0)
	select._on_skill(0)
	select.confirm.pressed.emit()
	assert_true(select.skill_row.visible, "and the blue")
	select.skill_row.set_index(2)
	select._on_skill(2)
	select.confirm.pressed.emit()
	assert_eq(int(main.get("screen")), MainScript.Screen.PLAYING)
	assert_eq(host.config.mode, MatchConfig.WATCH)
	assert_eq(host.config.human_count(), 0)
	for i: int in 2:
		assert_eq(host.config.sides[i].controller, MatchSide.COMPUTER, "side %d" % i)
		assert_true(host.brain(i) is AIBrain, "side %d has a computer brain" % i)
	assert_eq([host.config.sides[0].difficulty, host.config.sides[1].difficulty], [&"easy", &"hard"])
	assert_eq((host.get_node("View") as MatchView).camera.mode, CameraRig.Mode.WATCH)


func test_watch_samples_no_human_input() -> void:
	# two Watch matches from the same seed, one with keys and buttons held
	# down all through: they play out the same
	var quiet: MatchHost = _host()
	quiet.start(_watch())
	var busy: MatchHost = _host()
	busy.start(_watch())
	assert_eq(busy.player_of_side(0), -1)
	assert_eq(busy.player_of_side(1), -1)
	for step: int in 600:
		if step % 6 == 0:
			for key: Key in [KEY_J, KEY_K, KEY_L, KEY_SPACE, KEY_W, KEY_A]:
				fake.press_key(key)
			fake.press_button(0, JOY_BUTTON_A)
			fake.press_button(0, JOY_BUTTON_RIGHT_SHOULDER)
		elif step % 6 == 3:
			for key: Key in [KEY_J, KEY_K, KEY_L, KEY_SPACE, KEY_W, KEY_A]:
				fake.release_key(key)
			fake.release_button(0, JOY_BUTTON_A)
			fake.release_button(0, JOY_BUTTON_RIGHT_SHOULDER)
		quiet.step(1)
		busy.step(1)
	for i: int in 2:
		var a: Fighter = quiet.fighter(i)
		var b: Fighter = busy.fighter(i)
		assert_eq([b.pos.x, b.pos.z, b.hp, b.state], [a.pos.x, a.pos.z, a.hp, a.state], "fighter %d untouched by the keys" % i)


func test_esc_still_pauses_watch() -> void:
	var host: MatchHost = _host()
	host.auto_run = true
	host.start(_watch())
	fake.press_key(KEY_ESCAPE)
	host._process(SimConst.DT)
	assert_true(host.is_paused())


func test_the_hud_takes_its_watch_form() -> void:
	var host: MatchHost = _host()
	host.start(_watch())
	host.step(Match.INTRO_FRAMES + 2)
	var hud: MatchHud = host.get_node("Hud")
	hud._process(0.0)
	assert_eq(hud._me(), -1, "nobody is you")
	assert_false(hud.training_panel.visible)
	assert_eq(hud.prompts.get_child_count(), 0, "no prompts")
	assert_false(hud.weapon_marker.visible, "no marker")
	for i: int in 2:
		assert_false(hud._plates[i].text.contains("(You)"))


func test_a_watched_match_ends_on_results_naming_the_winner_in_its_colour() -> void:
	var host: MatchHost = _host()
	host.start(_watch())
	var steps: int = 0
	while not host.is_finished() and steps < MATCH_LIMIT:
		host.step(1)
		steps += 1
	assert_true(host.is_finished(), "the match ended")
	var r: MatchResults = host.results()
	assert_true(r.winner == 0 or r.winner == 1)
	assert_false(r.for_one_player(), "no Victory or Defeat in Watch")
	assert_eq(r.title(), "%s wins" % ["Rogue", "Hunter"][r.winner])
	var screen: ResultsScreen = ResultsScreen.new()
	add_child_autofree(screen)
	screen.show_results(r)
	var headline: Label = screen.find_child("Headline", true, false)
	assert_eq(headline.text, r.title())
	assert_eq(headline.get_theme_color(&"font_color"), ResultsScreen.side_color(r.palettes[r.winner]))


func test_a_mirror_match_puts_the_side_s_seal_on_the_winner() -> void:
	var r: MatchResults = MatchResults.new()
	r.mode = MatchConfig.WATCH
	r.names = ["Rogue", "Rogue"] as Array[String]
	r.winner = 1
	assert_eq(r.title(), "Rogue 青 wins")
	r.winner = 0
	assert_eq(r.title(), "Rogue 赤 wins")
	r.names = ["Rogue", "Hunter"] as Array[String]
	assert_eq(r.title(), "Rogue wins", "no seal when the names differ")
	assert_eq(MatchResults.side_name(["Hunter", "Hunter"] as Array[String], 1), "Hunter 青")
	assert_eq(MatchResults.side_name(["Hunter", "Rogue"] as Array[String], 1), "Rogue")
