extends GutTest
## The HUD's announcements (task 24.2): each event's kanji, words, subline and
## length, and the entrance (the words fading in over the first 12%, hold,
## fade out from 78% while easing to 0.98; since milestone-1 task 54 the
## kanji are painted in by a brush wipe in place of the demo's scale-in from
## 1.35, which test_hud_style.gd checks), all on the host's rules steps, so a
## pause freezes them and slow motion stretches them.

var host: MatchHost
var hud: MatchHud


func _start(player_side: int = -1) -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	var sides: Array[MatchSide] = [
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"daggers", 1, &"hard"),
	]
	if player_side >= 0:
		sides[player_side] = MatchSide.human(&"rogue" if player_side == 0 else &"hunter", &"katana", player_side)
	var mode: StringName = MatchConfig.DUEL if player_side >= 0 else MatchConfig.WATCH
	host.start(MatchConfig.make(mode, sides[0], sides[1], 7, ArenaScenes.STANDIN))


func _on_screen() -> Array[String]:
	return [hud.announcement_kanji(), hud.announcement_text(), hud.announcement_sub()]


func test_the_entrance_fades_in_holds_and_fades_out() -> void:
	assert_eq(AnnouncementEntrance.alpha(0.0), 0.0)
	assert_eq(AnnouncementEntrance.scale(0.0), 1.0, "no scale-in")
	assert_eq(AnnouncementEntrance.alpha(0.12), 1.0)
	assert_eq(AnnouncementEntrance.scale(0.12), 1.0)
	assert_almost_eq(AnnouncementEntrance.alpha(0.06), 0.5, 0.0001)
	assert_eq(AnnouncementEntrance.scale(0.06), 1.0)
	assert_eq(AnnouncementEntrance.alpha(0.5), 1.0)
	assert_eq(AnnouncementEntrance.alpha(0.78), 1.0)
	assert_eq(AnnouncementEntrance.scale(0.78), 1.0)
	assert_almost_eq(AnnouncementEntrance.alpha(0.89), 0.5, 0.0001)
	assert_eq(AnnouncementEntrance.alpha(1.0), 0.0)
	assert_eq(AnnouncementEntrance.scale(1.0), 0.98)
	assert_eq(AnnouncementEntrance.alpha(1.5), 0.0, "past the end stays gone")


## The round is called as the match starts, and Fight when the intro ends
## (cutting the round call short, as the demo's does).
func test_the_round_call_and_fight() -> void:
	_start()
	assert_eq(_on_screen(), ["第一戦", "Round 1", ""] as Array[String])
	assert_eq(_length(), MatchHud.ROUND_FRAMES)
	host.step(Match.INTRO_FRAMES + 1)
	assert_eq(_on_screen(), ["始め", "Fight", ""] as Array[String])
	assert_eq(_length(), MatchHud.FIGHT_FRAMES)
	host.step(MatchHud.FIGHT_FRAMES)
	assert_eq(hud.announcement_text(), "", "gone after its frames")


func _length() -> int:
	return int(hud.announcement["until"]) - int(hud.announcement["at"])


func test_the_final_round_is_called() -> void:
	_start()
	host.sim_match.wins[0] = 2
	host.sim_match.wins[1] = 2
	hud._on_sim_event({"t": &"roundStart", "round": 5})
	assert_eq(_on_screen(), ["第五戦", "Round 5", "Final round"] as Array[String])


func test_knockouts_and_round_results_from_the_player_s_side() -> void:
	_start(0)
	hud._on_sim_event({"t": &"ko", "winner": 0})
	assert_eq(_on_screen(), ["一本", "K.O.", ""] as Array[String])
	assert_eq(_length(), MatchHud.KO_FRAMES)
	hud._on_sim_event({"t": &"ko", "winner": -1})
	assert_eq(_on_screen(), ["相打ち", "Double K.O.", ""] as Array[String])
	assert_eq(_length(), MatchHud.DOUBLE_KO_FRAMES)
	hud._on_sim_event({"t": &"roundOver", "winner": 0, "perfect": true})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(_on_screen(), ["勝", "You win the round", "Perfect"] as Array[String])
	assert_eq(_length(), MatchHud.ROUND_RESULT_FRAMES)
	hud._on_sim_event({"t": &"roundOver", "winner": 1, "perfect": false})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(_on_screen(), ["敗", "You lose the round", ""] as Array[String])


func test_watch_names_the_round_s_winner_and_disarms_have_no_advice() -> void:
	_start()
	hud._on_sim_event({"t": &"roundOver", "winner": 1, "perfect": false})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(_on_screen(), ["勝", "%s wins the round" % host.fighter(1).name, ""] as Array[String])
	hud._on_sim_event({"t": &"disarm", "victim": 0})
	assert_eq(_on_screen(), ["武器喪失", "Disarmed", ""] as Array[String])
	assert_eq(_length(), MatchHud.DISARM_FRAMES)



## The announcement's words colour, or null when the theme's own.
func _words_color() -> Variant:
	var l: Label = hud.find_child("Announce", true, false)
	return l.get_theme_color(&"font_color") if l.has_theme_color_override(&"font_color") else null


func test_watch_names_the_round_s_winner_in_the_side_s_colour() -> void:
	_start()
	hud._on_sim_event({"t": &"roundOver", "winner": 1, "perfect": false})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(hud.announcement_text(), "Hunter wins the round")
	assert_eq(_words_color(), HudToasts.TONE_COLORS[HudToasts.Tone.BLUE], "青 blue, as its Watch toasts")
	hud._on_sim_event({"t": &"roundOver", "winner": 0, "perfect": true})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(_on_screen(), ["勝", "Rogue wins the round", "Perfect"] as Array[String])
	assert_eq(_words_color(), HudToasts.TONE_COLORS[HudToasts.Tone.RED], "赤 red")
	hud._on_sim_event({"t": &"disarm", "victim": 0})
	assert_null(_words_color(), "the next call in the theme's colour")


func test_a_mirror_match_in_watch_puts_the_seal_on_the_round_s_winner() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	host.start(MatchConfig.make(
		MatchConfig.WATCH,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"rogue", &"daggers", 1, &"hard"),
		7,
		ArenaScenes.STANDIN,
	))
	hud._on_sim_event({"t": &"roundOver", "winner": 1, "perfect": false})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(hud.announcement_text(), "Rogue 青 wins the round")
	assert_eq(_words_color(), HudToasts.TONE_COLORS[HudToasts.Tone.BLUE])


func test_your_own_round_results_keep_the_theme_s_colour() -> void:
	_start(0)
	hud._on_sim_event({"t": &"roundOver", "winner": 1, "perfect": false})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(hud.announcement_text(), "You lose the round")
	assert_null(_words_color())

## A draw is 敗 to the player and 勝 in Watch, as the demo's.
func test_a_draw_is_called() -> void:
	_start(0)
	hud._on_sim_event({"t": &"roundOver", "winner": -1, "perfect": false})
	host.step(MatchHud.ROUND_RESULT_DELAY)
	assert_eq(_on_screen(), ["敗", "Draw", "The round will be replayed"] as Array[String])


func test_a_disarm_tells_the_player_what_to_do() -> void:
	_start(0)
	hud._on_sim_event({"t": &"disarm", "victim": 0})
	assert_eq(_on_screen(), ["武器喪失", "Disarmed", "Retrieve your weapon or fight bare-handed"] as Array[String])
	hud._on_sim_event({"t": &"disarm", "victim": 1})
	assert_eq(hud.announcement_sub(), "Stand between them and their blade")


## A pause holds the announcement where it is, look and all.
## The entrance runs the demo's 1.3 s whatever the call's length: a K.O.
## (120 frames) has faded by frame 78 and stays blank to its end; Fight (54)
## is cut off at full strength.
func test_the_entrance_runs_the_same_length_for_every_on_screen() -> void:
	_start()
	host.step(Match.INTRO_FRAMES + 2)
	hud._on_sim_event({"t": &"ko", "winner": 0})
	host.step(9)
	assert_almost_eq(hud.announcement_look().x, AnnouncementEntrance.alpha(9.0 / 78.0), 0.02, "fading in over the same frames")
	host.step(70)
	assert_eq(hud.announcement_look().x, 0.0, "gone from frame 78")
	assert_eq(hud.announcement_text(), "K.O.", "though the call lasts its 120 frames")
	hud._on_sim_event({"t": &"fight"})
	host.step(MatchHud.FIGHT_FRAMES - 1)
	assert_eq(hud.announcement_look().x, 1.0, "Fight at full strength to its last frame")


func test_a_pause_freezes_the_announcement() -> void:
	_start()
	host.step(3)
	hud._process(1.0 / 60.0)
	var age: float = hud.announcement_age()
	var before: Vector2 = hud.announcement_look()
	assert_lt(before.x, 1.0, "mid-entrance")
	host.pause()
	for i: int in 30:
		host.advance(1.0 / 60.0)
		hud._process(1.0 / 60.0)
	assert_eq(hud.announcement_age(), age)
	assert_eq(hud.announcement_look(), before)
	assert_eq(hud.announcement_text(), "Round 1")


## In slow motion the rules step slower, and the announcement with them.
func test_slow_motion_stretches_the_announcement() -> void:
	_start()
	host.step(1)
	host.world.slowmo_frames = 100000
	host.world.slowmo_scale = 0.3
	for i: int in 60:
		host.advance(1.0 / 60.0)
	assert_eq(hud.announcement_text(), "Round 1", "a second of slow motion is under a third of its 78 frames")
	assert_lt(hud.announcement_age(), 20.0)
	assert_almost_eq(hud.announcement_look().x, 1.0, 0.0001, "still in its hold")
