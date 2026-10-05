extends GutTest
## Training's parry timing feedback (task 23.4): on your parry, the frames
## before impact and the window; "Too early" when you are hit or block within
## 20 frames after your window closed; "Too late" when block is pressed
## within 14 frames after a hit or block. The drills script a real world: the
## dummy's light against your block presses, timed from the impact frame the
## rules give (measured from an unparried run, not a fixed frame count), so
## they hold when the frame data comes from the clips.

const H := preload("res://tests/sim/sim_helpers.gd")
const DIM: int = HudToasts.Tone.DIM
## The step the dummy starts its light on, leaving room for early presses.
const LEAD: int = 40


func after_each() -> void:
	H.dispose_all()


## A drill: the dummy (side 1) taps light on step LEAD; you (side 0)
## tap block on world frame `press_at` (or never), holding it from
## `hold_from` to `hold_to` (world frames, inclusive) when given. Returns
## { "toasts": every toast the feedback and HudToasts gave in Training,
## "impact": the world frame of the first hit or block on you, "events" }.
func _drill(press_at: int = -1, hold_from: int = -1, hold_to: int = -1, frames: int = LEAD + 60) -> Dictionary:
	var W: World = H.make_world()
	var me: Fighter = W.fighters[0]
	var fb: ParryFeedback = ParryFeedback.new()
	var toasts: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var impact: int = -1
	for i: int in frames:
		var next: int = W.frame + 1
		var mine: RawInput = H.idle()
		if next == press_at or (next >= hold_from and next <= hold_to):
			mine = H.btn(Btn.BLOCK)
		W.step([mine, H.btn(Btn.LIGHT) if i == LEAD else H.idle()])
		for e: Dictionary in W.drain_events():
			events.append(e)
			if impact < 0 and (e["t"] == &"hit" or e["t"] == &"block" or e["t"] == &"parry") and int(e.get("target", e.get("parrier", -1))) == 0:
				impact = W.frame
			toasts.append_array(HudToasts.for_event(e, 0, true, ["Rogue", "Hunter"], "Left Click"))
			toasts.append_array(fb.on_event(e, 0, me, W.frame))
		toasts.append_array(fb.after_step(me, W.frame))
	return {"toasts": toasts, "impact": impact, "events": events}


## The world frame the dummy's light lands on you, unparried.
func _impact() -> int:
	var d: Dictionary = _drill()
	assert_gt(int(d["impact"]), 0, "the light lands")
	return int(d["impact"])


func _window() -> int:
	return Moves.KATANA.parry_window


func _texts(d: Dictionary) -> Array:
	var out: Array = []
	for t: Dictionary in d["toasts"]:
		out.append([t["text"], t["sub"]])
	return out


func _find(d: Dictionary, text: String) -> Dictionary:
	for t: Dictionary in d["toasts"]:
		if t["text"] == text:
			return t
	return {}


func test_a_parry_in_the_window_says_how_many_frames_before_impact_and_the_window() -> void:
	var f: int = _impact()
	var d: Dictionary = _drill(f - 3)
	var t: Dictionary = _find(d, "Parry")
	assert_false(t.is_empty(), "parried: %s" % [_texts(d)])
	assert_eq(t["sub"], "3 frames before impact · window %d" % _window())
	assert_eq(t["tone"], HudToasts.Tone.GOLD)
	assert_true(_find(d, "Too early").is_empty())
	assert_true(_find(d, "Too late").is_empty())


func test_one_frame_reads_in_the_singular() -> void:
	var f: int = _impact()
	var d: Dictionary = _drill(f - 1)
	assert_eq(_find(d, "Parry").get("sub"), "1 frame before impact · window %d" % _window())


func test_the_number_comes_from_the_parry_event() -> void:
	assert_eq(ParryFeedback.timing_line({"timing": 0, "window": 4}), "0 frames before impact · window 4")
	assert_eq(ParryFeedback.timing_line({"timing": 7, "window": 12}), "7 frames before impact · window 12")


func test_a_press_5_frames_before_the_window_is_too_early() -> void:
	var f: int = _impact()
	var d: Dictionary = _drill(f - _window() - 5)
	assert_true(_find(d, "Parry").is_empty(), "no parry")
	var t: Dictionary = _find(d, "Too early")
	assert_false(t.is_empty(), "too early: %s" % [_texts(d)])
	assert_eq(t["sub"], "Parry pressed 5 frames too early")
	assert_eq(t["tone"], DIM)


func test_too_early_also_on_a_block() -> void:
	# the press 5 frames before the window, block held on to the impact
	var f: int = _impact()
	var press: int = f - _window() - 5
	var d: Dictionary = _drill(press, press, f + 2)
	var blocked: bool = false
	for e: Dictionary in d["events"]:
		blocked = blocked or e["t"] == &"block"
	assert_true(blocked, "blocked")
	assert_eq(_find(d, "Too early").get("sub"), "Parry pressed 5 frames too early")


func test_too_early_counts_20_frames_past_the_window_and_no_more() -> void:
	var f: int = _impact()
	assert_eq(_find(_drill(f - _window() - 1), "Too early").get("sub"), "Parry pressed 1 frame too early")
	assert_eq(_find(_drill(f - _window() - 20), "Too early").get("sub"), "Parry pressed 20 frames too early")
	assert_true(_find(_drill(f - _window() - 21), "Too early").is_empty(), "21 frames is just a hit")


func test_a_press_3_frames_after_a_block_is_too_late() -> void:
	# block held through the impact and let go after it, then pressed again
	# 3 frames after it (blockstun takes a guard press)
	var f: int = _impact()
	var d: Dictionary = _drill(f + 3, f - 30, f)
	var blocked: bool = false
	for e: Dictionary in d["events"]:
		blocked = blocked or e["t"] == &"block"
	assert_true(blocked, "blocked: %s" % [_texts(d)])
	var t: Dictionary = _find(d, "Too late")
	assert_false(t.is_empty(), "too late: %s" % [_texts(d)])
	assert_eq(t["sub"], "Parry pressed 3 frames after impact")
	assert_eq(t["tone"], DIM)


func test_too_late_counts_14_frames_and_no_more() -> void:
	var fb: ParryFeedback = ParryFeedback.new()
	var W: World = H.make_world()
	var me: Fighter = W.fighters[0]
	fb.on_event({"t": &"block", "attacker": 1, "target": 0}, 0, me, 100)
	me.block_press_frame = 114
	assert_eq(fb.after_step(me, 114).size(), 1, "14 frames after")
	assert_eq(fb.after_step(me, 115).size(), 0, "told once")
	fb.on_event({"t": &"hit", "attacker": 1, "target": 0}, 0, me, 200)
	me.block_press_frame = 199
	assert_eq(fb.after_step(me, 214).size(), 0, "a press before the impact isn't late")
	assert_eq(fb.after_step(me, 215).size(), 0, "past 14 frames it stops watching")
	me.block_press_frame = 215
	assert_eq(fb.after_step(me, 215).size(), 0, "a press 15 frames after says nothing")


func test_the_dummy_being_hit_says_nothing() -> void:
	var fb: ParryFeedback = ParryFeedback.new()
	var W: World = H.make_world()
	var me: Fighter = W.fighters[0]
	me.block_press_frame = 90
	me.parry_window_at_press = 9
	assert_eq(fb.on_event({"t": &"hit", "attacker": 0, "target": 1}, 0, me, 100), [])
	me.block_press_frame = 102
	assert_eq(fb.after_step(me, 102), [], "no watch started for the dummy's hit")


func test_a_clean_parry_says_neither_early_nor_late() -> void:
	var f: int = _impact()
	var d: Dictionary = _drill(f - 2)
	assert_eq(_find(d, "Parry").get("sub"), "2 frames before impact · window %d" % _window())
	assert_true(_find(d, "Too early").is_empty())
	assert_true(_find(d, "Too late").is_empty())


func test_clear_forgets_the_watch() -> void:
	var fb: ParryFeedback = ParryFeedback.new()
	var W: World = H.make_world()
	var me: Fighter = W.fighters[0]
	fb.on_event({"t": &"hit", "attacker": 1, "target": 0}, 0, me, 100)
	fb.clear()
	me.block_press_frame = 103
	assert_eq(fb.after_step(me, 103), [])


# ------------------------------------------------------------------ in the HUD

var host: MatchHost
var hud: MatchHud


func _start(mode: StringName) -> void:
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
		cfg = MatchConfig.make(
			mode,
			MatchSide.human(&"rogue", &"katana", 0),
			MatchSide.computer(&"hunter", &"daggers", 1, &"hard"),
			7,
			ArenaScenes.STANDIN,
		)
	host.start(cfg)
	host.step(Match.INTRO_FRAMES + 2)


func _hud_texts() -> Array:
	var out: Array = []
	for t: Dictionary in hud.toasts.entries():
		out.append([t["text"], t["sub"]])
	return out


## Sets your last block press `ago` frames before now, with window `win`.
func _pressed(ago: int, win: int = 9) -> void:
	var me: Fighter = host.fighter(0)
	me.block_press_frame = host.world.frame - ago
	me.parry_window_at_press = win


func test_the_hud_toasts_the_parry_timing_in_training() -> void:
	_start(MatchConfig.TRAINING)
	hud.toasts.clear()
	hud._on_sim_event({"t": &"parry", "parrier": 0, "attacker": 1, "kind": &"parry", "timing": 4, "window": 9})
	assert_eq(_hud_texts(), [["Parry", "4 frames before impact · window 9"]])


func test_the_hud_toasts_too_early_and_too_late_in_training() -> void:
	_start(MatchConfig.TRAINING)
	hud.toasts.clear()
	_pressed(9 + 6)
	hud._on_sim_event({"t": &"hit", "attacker": 1, "target": 0, "backstab": false})
	assert_eq(_hud_texts(), [["Too early", "Parry pressed 6 frames too early"]])
	hud.toasts.clear()
	_pressed(-2)
	hud._on_stepped(host.step_count)
	assert_eq(_hud_texts(), [["Too late", "Parry pressed 2 frames after impact"]])


func test_nothing_shows_outside_training() -> void:
	_start(MatchConfig.DUEL)
	hud.toasts.clear()
	hud._on_sim_event({"t": &"parry", "parrier": 0, "attacker": 1, "kind": &"parry", "timing": 4, "window": 9})
	assert_eq(_hud_texts(), [["Parry", ""]], "a Duel's parry has no timing")
	hud.toasts.clear()
	_pressed(9 + 6)
	hud._on_sim_event({"t": &"hit", "attacker": 1, "target": 0, "backstab": false})
	_pressed(-2)
	hud._on_stepped(host.step_count)
	assert_eq(_hud_texts(), [], "no Too early or Too late in a Duel")


func test_a_new_match_forgets_the_watch() -> void:
	_start(MatchConfig.TRAINING)
	hud._on_sim_event({"t": &"hit", "attacker": 1, "target": 0, "backstab": false})
	host.start(MatchConfig.default_training(4))
	hud.toasts.clear()
	_pressed(-1)
	hud._on_stepped(host.step_count)
	assert_eq(_hud_texts(), [])
