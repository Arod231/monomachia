extends GutTest
## The HUD's toasts (task 24.3): short feedback under the centre for
## parries, counters, ultimates, backstabs, dazes and, in Training, evades
## and the dummy's behaviour; up to three at once, 69 rules steps each, held
## by a pause and stretched by slow motion. From the player's side they are
## gold or jade for what you did and red for what was done to you; in Watch
## they name the fighter in the side's colour (赤 red, 青 blue).

## The demo's toast colours (.toast.gold, jade, red, dim) and the 青 side's
## blue.
const GOLD: Color = Color("#ffd98a")
const JADE: Color = UiPalette.JADE
const RED: Color = Color("#ff6a4a")
const DIM: Color = UiPalette.PAPER_DIM
const BLUE: Color = Color("#8cbcf0")

var host: MatchHost
var hud: MatchHud


func _start(mode: StringName = MatchConfig.DUEL) -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	var cfg: MatchConfig
	if mode == MatchConfig.TRAINING:
		cfg = MatchConfig.default_training(3)
		cfg.arena_id = ArenaScenes.STANDIN
	else:
		var sides: Array[MatchSide] = [
			MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
			MatchSide.computer(&"hunter", &"daggers", 1, &"hard"),
		]
		if mode == MatchConfig.DUEL:
			sides[0] = MatchSide.human(&"rogue", &"katana", 0)
		cfg = MatchConfig.make(mode, sides[0], sides[1], 7, ArenaScenes.STANDIN)
	host.start(cfg)
	host.step(Match.INTRO_FRAMES + 2)


## The toasts on screen, oldest first, as [text, subline, colour].
func _toasts() -> Array:
	var out: Array = []
	for t: Dictionary in hud.toasts.entries():
		out.append([t["text"], t["sub"], HudToasts.TONE_COLORS[t["tone"]]])
	return out


## The one toast an event gives, after clearing the stack.
func _toast_of(e: Dictionary) -> Array:
	hud.toasts.clear()
	hud._on_sim_event(e)
	var on: Array = _toasts()
	assert_eq(on.size(), 1, "one toast for %s" % e)
	return on[0] if on.size() == 1 else []


func _nothing_for(e: Dictionary) -> void:
	hud.toasts.clear()
	hud._on_sim_event(e)
	assert_eq(_toasts(), [], "no toast for %s" % e)


func _parry(parrier: int, kind: StringName) -> Dictionary:
	return {"t": &"parry", "parrier": parrier, "attacker": 1 - parrier, "kind": kind, "timing": 3, "window": 6}


func _counter(by: int, kind: StringName) -> Dictionary:
	return {"t": &"counter", "kind": kind, "by": by, "on": 1 - by}


func _backstab(attacker: int) -> Dictionary:
	return {"t": &"hit", "attacker": attacker, "target": 1 - attacker, "backstab": true, "heavy": false}


func test_your_parries_are_gold_and_flashes_and_redirects_jade() -> void:
	_start()
	assert_eq(_toast_of(_parry(0, &"parry")), ["Parry", "", GOLD])
	assert_eq(_toast_of(_parry(0, &"flash")), ["Flash", "", JADE])
	assert_eq(_toast_of(_parry(0, &"redirect")), ["Redirect", "", JADE])


func test_their_parries_deflect_your_attack_in_red() -> void:
	_start()
	assert_eq(_toast_of(_parry(1, &"parry")), ["Parry", "Your attack was deflected", RED])
	assert_eq(_toast_of(_parry(1, &"flash")), ["Flash", "Your attack was deflected", RED])
	assert_eq(_toast_of(_parry(1, &"redirect")), ["Redirect", "Your attack was deflected", RED])


func test_counters_tell_you_what_to_do_next() -> void:
	_start()
	var light: String = host.label("light", 0)
	assert_ne(light, "", "the player's light has a name")
	assert_eq(_toast_of(_counter(0, &"evade")), ["Evade counter", "Press %s now to lunge" % light, JADE])
	assert_eq(_toast_of(_counter(0, &"stomp")), ["Stomp counter", "They are stunned: attack", JADE])
	assert_eq(_toast_of(_counter(0, &"leap")), ["Leap counter", "They are stunned: attack", JADE])
	assert_eq(_toast_of(_counter(1, &"stomp")), ["Stomp counter", "You were countered", RED])
	assert_eq(_toast_of(_counter(1, &"evade")), ["Evade counter", "You were countered", RED])


func test_ultimates_backstabs_and_dazes_from_the_player_s_side() -> void:
	_start()
	assert_eq(_toast_of({"t": &"ultReady", "f": 0}), ["Ultimate ready", "Light + Heavy together", GOLD])
	_nothing_for({"t": &"ultReady", "f": 1})
	assert_eq(_toast_of({"t": &"ultStart", "f": 1, "ult": &"tempest"}), ["Ultimate", "Get ready to evade", RED])
	_nothing_for({"t": &"ultStart", "f": 0, "ult": &"moonsplitter"})
	assert_eq(_toast_of({"t": &"backstabReady", "f": 0}), ["Behind them", "Light attack to backstab", JADE])
	_nothing_for({"t": &"backstabReady", "f": 1})
	assert_eq(_toast_of(_backstab(0)), ["Backstab", "", JADE])
	assert_eq(_toast_of(_backstab(1)), ["Backstab", "", RED], "a backstab on you is red")
	_nothing_for({"t": &"hit", "attacker": 0, "target": 1, "backstab": false, "heavy": true})
	assert_eq(_toast_of({"t": &"stagger", "f": 0}), ["Dazed", "Posture broken", RED])
	_nothing_for({"t": &"stagger", "f": 1})


func test_evades_toast_only_in_training() -> void:
	_start()
	_nothing_for({"t": &"evade", "f": 0, "attacker": 1})
	_start(MatchConfig.TRAINING)
	var me: int = host.config.first_human_side()
	assert_eq(_toast_of({"t": &"evade", "f": me, "attacker": 1 - me}), ["Evaded", "", DIM])
	_nothing_for({"t": &"evade", "f": 1 - me, "attacker": me})


## Watch names the fighter, in its side's colour, for both sides, with no
## advice; the player's own prompts (Ultimate ready, Behind them) and
## Training's Evaded don't show.
func test_watch_names_the_fighter_in_the_side_s_colour() -> void:
	_start(MatchConfig.WATCH)
	var a: String = host.fighter(0).name
	var b: String = host.fighter(1).name
	assert_eq(_toast_of(_parry(0, &"parry")), ["%s: Parry" % a, "", RED])
	assert_eq(_toast_of(_parry(1, &"flash")), ["%s: Flash" % b, "", BLUE])
	assert_eq(_toast_of(_parry(1, &"redirect")), ["%s: Redirect" % b, "", BLUE])
	assert_eq(_toast_of(_counter(1, &"evade")), ["%s: Evade counter" % b, "", BLUE])
	assert_eq(_toast_of(_counter(0, &"stomp")), ["%s: Stomp counter" % a, "", RED])
	assert_eq(_toast_of({"t": &"ultStart", "f": 0, "ult": &"moonsplitter"}), ["%s: Ultimate" % a, "", RED])
	assert_eq(_toast_of({"t": &"ultStart", "f": 1, "ult": &"tempest"}), ["%s: Ultimate" % b, "", BLUE])
	assert_eq(_toast_of(_backstab(1)), ["%s: Backstab" % b, "", BLUE])
	assert_eq(_toast_of({"t": &"stagger", "f": 0}), ["%s: Dazed" % a, "", RED])
	_nothing_for({"t": &"ultReady", "f": 0})
	_nothing_for({"t": &"backstabReady", "f": 1})
	_nothing_for({"t": &"evade", "f": 0, "attacker": 1})


## A mirror match names both sides alike; the colour tells them apart.
func test_a_mirror_match_in_watch_tells_the_sides_apart_by_colour() -> void:
	_start(MatchConfig.WATCH)
	var left: Array = _toast_of(_parry(0, &"parry"))
	var right: Array = _toast_of(_parry(1, &"parry"))
	assert_ne(left[2], right[2])


## Training toasts a change of the dummy's behaviour (dim, "Dummy
## behaviour"), from the panel or the pause rows alike, but not the refill.
func test_training_toasts_the_dummy_s_behaviour() -> void:
	_start(MatchConfig.TRAINING)
	hud.toasts.clear()
	host.set_training_behaviour(&"lights")
	assert_eq(_toasts(), [["Light chains", "Dummy behaviour", DIM]])
	host.set_refill(false)
	assert_eq(_toasts().size(), 1, "the refill switch doesn't toast")
	host.set_training_behaviour(&"lights")
	assert_eq(_toasts().size(), 1, "choosing the same behaviour again doesn't toast")
	host.set_training_behaviour(&"slam")
	assert_eq(_toasts()[1], ["Slam", "Dummy behaviour", DIM])


func test_a_fourth_toast_drops_the_oldest() -> void:
	_start(MatchConfig.TRAINING)
	hud.toasts.clear()
	for kind: StringName in [&"stomp", &"leap", &"evade"]:
		hud._on_sim_event(_counter(0, kind))
	hud._on_sim_event(_parry(0, &"parry"))
	var texts: Array = []
	for t: Array in _toasts():
		texts.append(t[0])
	assert_eq(texts, ["Leap counter", "Evade counter", "Parry"])
	assert_eq(hud.toasts.get_child_count(), HudToasts.MAX, "three on screen")


## A toast lasts 69 rules steps (the demo's 1.15 s).
func test_toasts_expire_on_rules_steps() -> void:
	_start(MatchConfig.TRAINING)
	hud.toasts.clear()
	hud._on_sim_event(_parry(0, &"parry"))
	host.step(HudToasts.LIFE - 1)
	assert_eq(_toasts().size(), 1, "on its last step")
	host.step(1)
	assert_eq(_toasts(), [], "gone after 69 steps")
	assert_eq(HudToasts.LIFE, 69)


func test_a_pause_holds_the_toasts() -> void:
	_start(MatchConfig.TRAINING)
	hud.toasts.clear()
	hud._on_sim_event(_parry(0, &"parry"))
	host.step(5)
	hud._process(1.0 / 60.0)
	var age: float = hud.toasts.age(0)
	var look: Vector2 = hud.toasts.look(0)
	host.pause()
	for i: int in 120:
		host.advance(1.0 / 60.0)
		hud._process(1.0 / 60.0)
	assert_eq(_toasts().size(), 1, "still there after two seconds paused")
	assert_eq(hud.toasts.age(0), age)
	assert_eq(hud.toasts.look(0), look)


## A toast taken from the pause menu (the dummy's behaviour) waits paused,
## then runs its 69 steps.
func test_a_toast_made_while_paused_waits_for_the_resume() -> void:
	_start(MatchConfig.TRAINING)
	hud.toasts.clear()
	host.pause()
	host.set_training_behaviour(&"block")
	for i: int in 120:
		host.advance(1.0 / 60.0)
	assert_eq(_toasts().size(), 1)
	host.resume()
	host.step(HudToasts.LIFE)
	assert_eq(_toasts(), [])


func test_slow_motion_stretches_the_toasts() -> void:
	_start(MatchConfig.TRAINING)
	hud.toasts.clear()
	hud._on_sim_event(_parry(0, &"parry"))
	host.world.slowmo_frames = 100000
	host.world.slowmo_scale = 0.3
	for i: int in 120:
		host.advance(1.0 / 60.0)
	assert_eq(_toasts().size(), 1, "two seconds of slow motion is about 36 steps")


## The demo's entrance over 1.1 s (66 steps): fade in while rising 8 px over
## the first 15%, hold to 75%, then fade out rising to -10 px.
func test_the_entrance_rises_in_and_fades_out() -> void:
	assert_eq(HudToasts.look_at(0.0), Vector2(0.0, 8.0))
	assert_eq(HudToasts.look_at(0.15 * 66.0), Vector2(1.0, 0.0))
	assert_almost_eq(HudToasts.look_at(0.075 * 66.0).x, 0.5, 0.0001)
	assert_eq(HudToasts.look_at(0.5 * 66.0), Vector2(1.0, 0.0))
	assert_eq(HudToasts.look_at(0.75 * 66.0), Vector2(1.0, 0.0))
	assert_almost_eq(HudToasts.look_at(0.875 * 66.0).x, 0.5, 0.0001)
	assert_almost_eq(HudToasts.look_at(0.875 * 66.0).y, -5.0, 0.0001)
	assert_eq(HudToasts.look_at(66.0), Vector2(0.0, -10.0))
	assert_eq(HudToasts.look_at(68.0), Vector2(0.0, -10.0), "gone until its last step")


## The stack sits under the centre, newest at the bottom, each toast's text
## in its colour over its subline.
func test_the_stack_draws_each_toast_in_its_colour() -> void:
	# a Duel: in Training your parry has its timing under it (23.4)
	_start()
	hud.toasts.clear()
	hud._on_sim_event(_parry(0, &"parry"))
	hud._on_sim_event(_parry(1, &"parry"))
	host.step(12)
	hud._process(1.0 / 60.0)
	assert_eq(hud.toasts.get_child_count(), 2)
	var first: Control = hud.toasts.get_child(0)
	var second: Control = hud.toasts.get_child(1)
	assert_lt(first.position.y + first.size.y, second.position.y + 0.5, "newest below the oldest")
	assert_eq((first.get_node("Text") as Label).get_theme_color("font_color"), GOLD)
	assert_false((first.get_node("Sub") as Label).visible, "an empty subline takes no room")
	var text: Label = second.get_node("Text")
	var sub: Label = second.get_node("Sub")
	assert_eq(text.text, "Parry")
	assert_eq(text.get_theme_color("font_color"), RED)
	assert_eq(sub.text, "Your attack was deflected")
	assert_true(sub.visible)
	assert_eq(first.modulate.a, 1.0, "in its hold 12 steps in")
	var middle: float = hud.toasts.get_global_rect().get_center().x
	assert_almost_eq(second.get_global_rect().get_center().x, middle, 1.0, "centred")
	assert_almost_eq(hud.toasts.get_global_rect().position.y / hud.get_viewport().get_visible_rect().size.y, 0.58, 0.01, "58% of the way down, as the demo's")


func test_a_new_match_and_the_results_clear_the_toasts() -> void:
	_start()
	hud._on_sim_event(_parry(0, &"parry"))
	hud._on_match_finished(host.results())
	assert_eq(_toasts(), [])
	hud._on_sim_event(_parry(0, &"parry"))
	host.start(host.config)
	assert_eq(_toasts(), [])
