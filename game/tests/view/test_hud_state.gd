extends GutTest
## The HUD's top bar (task 24.1): what each side's bars, pips and ultimate
## badge show for a fighter's HP, posture, wins and ultimate (HudState, pure),
## the HP lag band's hold and drain (HudLag), the bars' slanted shape
## (HudBar), and the top bar built from them in the match scene: the 赤 and
## 青 seals, the names and weapons, the bars, pips, badges, the disarmed tag
## and the round kanji.

var host: MatchHost
var hud: MatchHud


func _state(hp: float = 100.0, posture: float = 0.0, wins: int = 0, can_ult: bool = false, ult_used: bool = false, armed: bool = true) -> HudState:
	return HudState.of(hp, posture, wins, can_ult, ult_used, armed)


func test_a_fresh_fighter_shows_full_hp_no_posture_no_pips_and_no_badge() -> void:
	var s: HudState = _state()
	assert_eq(s.hp, 1.0)
	assert_false(s.low)
	assert_eq(s.posture, 0.0)
	assert_eq(s.posture_level, HudState.Posture.CALM)
	assert_eq(s.pips, 0)
	assert_eq(s.badge, HudState.Badge.HIDDEN)
	assert_false(s.disarmed)


## The demo pulses HP at a quarter or less, while the fighter still stands.
func test_hp_runs_low_at_a_quarter_or_less_while_standing() -> void:
	assert_true(_state(25.0).low)
	assert_true(_state(1.0).low)
	assert_false(_state(26.0).low)
	assert_false(_state(0.0).low, "a KO'd fighter's empty bar doesn't pulse")
	assert_eq(_state(-5.0).hp, 0.0, "the bar never goes below empty")


## The demo's posture bar turns hot at 70% and full (blinking red) at the top.
func test_posture_turns_hot_at_seventy_percent_and_full_at_the_top() -> void:
	assert_eq(_state(100.0, 69.0).posture_level, HudState.Posture.CALM)
	assert_eq(_state(100.0, 70.0).posture_level, HudState.Posture.HOT)
	assert_eq(_state(100.0, 99.0).posture_level, HudState.Posture.HOT)
	assert_eq(_state(100.0, 99.95).posture_level, HudState.Posture.FULL, "within a thousandth of the top counts as full")
	assert_eq(_state(100.0, 100.0).posture_level, HudState.Posture.FULL)
	assert_almost_eq(_state(100.0, 40.0).posture, 0.4, 0.0001)


func test_a_pip_lights_for_each_round_won_up_to_three() -> void:
	assert_eq(_state(100.0, 0.0, 2).pips, 2)
	assert_eq(_state(100.0, 0.0, 5).pips, 3)


## The badge is hidden until the ultimate is ready, glows while it is, and
## shows struck through once used while still low (KO'd included).
func test_the_ultimate_badge_is_hidden_ready_or_used() -> void:
	assert_eq(_state(25.0, 0.0, 0, true).badge, HudState.Badge.READY)
	assert_eq(_state(20.0, 0.0, 0, false, true).badge, HudState.Badge.USED)
	assert_eq(_state(0.0, 0.0, 0, false, true).badge, HudState.Badge.USED)
	assert_eq(_state(60.0, 0.0, 0, false, true).badge, HudState.Badge.HIDDEN, "healed above a quarter after using it")
	assert_eq(_state(60.0).badge, HudState.Badge.HIDDEN)


func test_a_disarmed_fighter_is_tagged() -> void:
	assert_true(_state(100.0, 0.0, 0, false, false, false).disarmed)


func test_the_state_reads_a_fighter() -> void:
	var f: Fighter = Fighter.new(0, FighterConfig.make(Moves.KATANA))
	f.hp = 20.0
	f.posture = 75.0
	var s: HudState = HudState.of_fighter(f, 1)
	assert_almost_eq(s.hp, 0.2, 0.0001)
	assert_eq(s.posture_level, HudState.Posture.HOT)
	assert_eq(s.pips, 1)
	assert_eq(s.badge, HudState.Badge.READY, "at a fifth of HP, unused")


func test_rounds_are_counted_in_kanji() -> void:
	assert_eq(HudState.round_kanji(1), "一")
	assert_eq(HudState.round_kanji(3), "三")
	assert_eq(HudState.round_kanji(9), "九")
	assert_eq(HudState.round_kanji(10), "一", "the demo's nine kanji go round again")


## The white band under HP holds where the HP was for 0.45 s, then drains at
## 0.6 of the bar a second until it meets the HP; a heal moves it at once.
func test_the_lag_band_holds_then_drains_to_the_hp() -> void:
	var lag: HudLag = HudLag.new()
	lag.step(1.0, 0.1)
	assert_eq(lag.value, 1.0)
	lag.step(0.5, 0.4)
	assert_eq(lag.value, 1.0, "held 0.4 s")
	lag.step(0.5, 0.1)
	assert_almost_eq(lag.value, 0.94, 0.0001, "0.5 s in: past the hold, a tenth of a second drained")
	for i: int in 20:
		lag.step(0.5, 0.1)
	assert_eq(lag.value, 0.5, "stops at the HP")
	lag.step(0.8, 0.1)
	assert_eq(lag.value, 0.8, "a heal moves it at once")
	lag.step(0.7, 0.3)
	lag.step(0.6, 0.3)
	assert_almost_eq(lag.value, 0.62, 0.0001, "a second hit keeps the hold running from the first: 0.6 s held, 0.3 s drained")


## The HP bar's inner end is cut back 10 px at its foot, as the demo's; the
## right-hand bar is the mirror image.
func test_a_slanted_bar_cuts_its_inner_end() -> void:
	var bar: HudBar = HudBar.new()
	bar.size = Vector2(100.0, 20.0)
	bar.slant = 10.0
	assert_eq(bar.part(1.0), PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 0), Vector2(90, 20), Vector2(0, 20)]))
	assert_eq(bar.part(0.95), PackedVector2Array([Vector2(0, 0), Vector2(95, 0), Vector2(95, 10), Vector2(90, 20), Vector2(0, 20)]), "past the cut's foot: the slant clips it")
	assert_eq(bar.part(0.5), PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(50, 20), Vector2(0, 20)]), "short of the cut: square")
	bar.reversed = true
	assert_eq(bar.part(0.5), PackedVector2Array([Vector2(100, 20), Vector2(50, 20), Vector2(50, 0), Vector2(100, 0)]), "from the right")
	bar.free()


# ------------------------------------------------------------------ the top bar

func _start_hud() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	host.start(MatchConfig.make(
		MatchConfig.DUEL,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"daggers", 1, &"hard"),
		7,
		ArenaScenes.STANDIN,
	))
	host.step(2)
	hud._process(1.0 / 60.0)


func _node(node_name: String) -> Node:
	return hud.find_child(node_name, true, false)


func _text(node_name: String) -> String:
	var l: Label = _node(node_name) as Label
	return l.text if l != null else "(no %s)" % node_name


func test_the_top_bar_has_the_seals_names_weapons_and_round_kanji() -> void:
	_start_hud()
	assert_eq(_text("Seal0"), "赤")
	assert_eq(_text("Seal1"), "青")
	assert_eq(_text("Plate0"), host.fighter(0).name)
	assert_eq(_text("Weapon1"), Moves.WEAPONS[&"daggers"].name)
	assert_eq(_text("RoundKanji"), "一")
	assert_eq(_text("RoundLabel"), "Round 1")
	assert_eq(_text("BadgeText1"), "奥義")
	assert_false((_node("Tag0") as Label).visible)


func test_the_top_bar_follows_the_fighters() -> void:
	_start_hud()
	var a: Fighter = host.fighter(0)
	var b: Fighter = host.fighter(1)
	a.hp = 60.0
	b.hp = 20.0
	b.posture = SimConst.POSTURE_MAX
	host.sim_match.wins[0] = 2
	hud._process(1.0 / 60.0)
	assert_eq(hud.side_state(1).posture_level, HudState.Posture.FULL)
	assert_almost_eq((_node("Hp0") as HudBar).value, 0.6, 0.0001)
	assert_eq((_node("Hp0") as HudBar).lag, 1.0, "the lag band holds where the HP was")
	assert_eq((_node("Posture1") as HudBar).value, 1.0)
	assert_eq((_node("Pips0") as HudPips).lit, 2)
	assert_eq((_node("Pips1") as HudPips).lit, 0)
	assert_eq((_node("Badge1") as HudBadge).state, HudState.Badge.READY)
	assert_eq((_node("Badge0") as HudBadge).state, HudState.Badge.HIDDEN)
	b.ult_used = true
	a.armed = false
	hud._process(1.0 / 60.0)
	assert_eq((_node("Badge1") as HudBadge).state, HudState.Badge.USED)
	assert_true((_node("Tag0") as Label).visible, "the disarmed tag")
	assert_eq(_text("Tag0"), "Disarmed")


## Full posture blinks its fill (half of each 0.35 s at 0.45 opacity), as
## the demo's; the bar's edge and ground stay.
func test_full_posture_blinks_its_fill() -> void:
	_start_hud()
	host.fighter(1).posture = SimConst.POSTURE_MAX
	var bar: HudBar = _node("Posture1") as HudBar
	var alphas: Array[float] = []
	for i: int in 21:
		hud._process(1.0 / 60.0)
		alphas.append(snappedf(bar.fill_color.a, 0.01))
	assert_has(alphas, 1.0)
	assert_has(alphas, MatchHud.POSTURE_BLINK_ALPHA)
	assert_eq(bar.modulate.a, 1.0, "only the fill blinks")
