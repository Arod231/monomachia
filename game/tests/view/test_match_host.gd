extends GutTest
## The fixed-step match host: a full computer-against-computer match from a
## MatchConfig, the accumulator (at most six steps a frame, the dropped
## backlog, slow motion), the interpolation fraction held during hit-stop,
## pause, event dispatch in the world's order, and human input.

const DT: float = SimConst.DT
## Twelve minutes of rules time, as the soak run allows.
const MATCH_LIMIT: int = 60 * 60 * 12

var fake: FakeDeviceState


func after_each() -> void:
	Roster.reset()


func _host() -> MatchHost:
	var host: MatchHost = MatchHost.new()
	host.auto_run = false
	host.use_services = false
	fake = FakeDeviceState.new()
	host.input = InputDevices.new(fake)
	host.profiles = ControlProfiles.new()
	autofree(host)
	return host


func _cpu_config(seed_value: int = 7, mode: StringName = MatchConfig.DUEL) -> MatchConfig:
	return MatchConfig.make(
		mode,
		MatchSide.computer(&"rogue", &"katana", 0, &"normal"),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"hard"),
		seed_value,
	)


func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


# ------------------------------------------------------------------ a full match

var _finished_with: Array[MatchResults] = []
var _finish_phase_frames: int = -1


func _on_finished(r: MatchResults, host: MatchHost) -> void:
	_finished_with.append(r)
	_finish_phase_frames = host.sim_match.phase_frames


func test_two_computers_play_a_full_match_to_the_results() -> void:
	var host: MatchHost = _host()
	_finished_with.clear()
	host.match_finished.connect(_on_finished.bind(host))
	host.start(_cpu_config())
	var bad: int = 0
	var steps: int = 0
	while not host.is_finished() and steps < MATCH_LIMIT:
		host.step(1)
		steps += 1
		for i: int in 2:
			if not _finite(host.display_position(i)):
				bad += 1
	assert_true(host.is_finished(), "the match ended within 12 minutes of rules time")
	assert_eq(bad, 0, "no NaN positions")
	assert_eq(_finished_with.size(), 1, "match_finished fires once")
	assert_eq(_finish_phase_frames, MatchHost.RESULTS_DELAY, "results open 140 frames into the match end")
	var r: MatchResults = _finished_with[0]
	assert_true(r.winner == 0 or r.winner == 1, "someone won")
	assert_eq(r.wins[r.winner], 3, "the winner took three rounds")
	assert_lt(r.wins[1 - r.winner], 3)
	assert_gte(r.rounds, 3)
	assert_eq(r.names, ["Rogue", "Hunter"] as Array[String])
	assert_eq(r.weapons, ["Katana", "Greatsword"] as Array[String])
	for side: int in 2:
		assert_eq(r.stats[side].size(), 7, "the demo's seven stats")
	assert_eq(r.mode, MatchConfig.DUEL)
	assert_eq(r.title(), "%s wins" % r.names[r.winner], "no human: the winner by name")
	# the host keeps stepping after the results (fighters in victory), with
	# no second match_finished
	host.step(60)
	assert_eq(_finished_with.size(), 1)


func test_each_side_s_fighter_reaches_the_rules() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config())
	assert_eq([host.fighter(0).body.id, host.fighter(1).body.id], [&"rogue", &"hunter"], "each fighter's body by its id")


func test_the_host_plays_exactly_the_soak_loop() -> void:
	# The same world, match and brains driven by hand as scripts/soak.ts and
	# the demo do: inputs [ai0.think(), ai1.think()], then Match.step.
	var cfg: MatchConfig = _cpu_config(11)
	var host: MatchHost = _host()
	host.start(cfg)
	var W: World = World.new(
		FighterConfig.make(Moves.KATANA, Moves.KATANA.default_abilities, "Rogue"),
		FighterConfig.make(Moves.GREATSWORD, Moves.GREATSWORD.default_abilities, "Hunter"),
		11,
	)
	var M: Match = Match.new(W)
	var ai: Array[AIBrain] = [
		AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"normal"], 11),
		AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"], 11 + 17),
	]
	var diverged: int = -1
	for n: int in 6000:
		M.step([ai[0].think(), ai[1].think()])
		host.step(1)
		for i: int in 2:
			var a: Fighter = W.fighters[i]
			var b: Fighter = host.fighter(i)
			if a.pos.x != b.pos.x or a.pos.z != b.pos.z or a.hp != b.hp or a.state != b.state:
				diverged = n
		if diverged >= 0:
			break
	assert_eq(diverged, -1, "the host's match never diverges from the hand-driven one")
	for brain: AIBrain in ai:
		brain.dispose()
	W.dispose()


# ------------------------------------------------------------------ events

var _recorded: Array[String] = []


func _record(e: Dictionary, host: MatchHost) -> void:
	_recorded.append("%d %s" % [host.step_count, var_to_str(e)])


func test_events_are_dispatched_in_the_world_order() -> void:
	var cfg: MatchConfig = _cpu_config(23)
	var host: MatchHost = _host()
	_recorded.clear()
	host.sim_event.connect(_record.bind(host))
	host.start(cfg)
	host.step(4000)
	# replay: the same world, draining after construction and after every step
	var W: World = World.new(
		FighterConfig.make(Moves.KATANA, Moves.KATANA.default_abilities, "Rogue"),
		FighterConfig.make(Moves.GREATSWORD, Moves.GREATSWORD.default_abilities, "Hunter"),
		23,
	)
	var M: Match = Match.new(W)
	var ai: Array[AIBrain] = [
		AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"normal"], 23),
		AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"], 23 + 17),
	]
	var expected: Array[String] = []
	for e: Dictionary in W.drain_events():
		expected.append("%d %s" % [0, var_to_str(e)])
	for n: int in 4000:
		M.step([ai[0].think(), ai[1].think()])
		for e: Dictionary in W.drain_events():
			expected.append("%d %s" % [n + 1, var_to_str(e)])
	assert_gt(expected.size(), 50, "a busy stretch of fighting")
	assert_eq(_recorded.size(), expected.size(), "every event dispatched once")
	var first_diff: int = -1
	for i: int in mini(_recorded.size(), expected.size()):
		if _recorded[i] != expected[i]:
			first_diff = i
			break
	assert_eq(first_diff, -1, "same events, same order, same steps")
	assert_true(_recorded[0].contains("roundStart"), "the intro's roundStart goes out at start()")
	for brain: AIBrain in ai:
		brain.dispose()
	W.dispose()


var _order: Array[String] = []


func test_stepped_follows_the_step_events() -> void:
	var host: MatchHost = _host()
	_order.clear()
	host.sim_event.connect(func(e: Dictionary) -> void: _order.append("event " + String(e["t"])))
	host.stepped.connect(func(s: int) -> void: _order.append("stepped %d" % s))
	host.start(_cpu_config())
	host.step(Match.FIGHT_CALL_FRAME)
	var i: int = _order.find("event fight")
	assert_gt(i, -1)
	assert_eq(_order[i + 1], "stepped %d" % Match.FIGHT_CALL_FRAME, "stepped comes after that step's events")


# ------------------------------------------------------------------ the clock

func test_one_step_per_sixtieth_of_a_second() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config())
	assert_eq(host.advance(DT * 2.5), 2)
	assert_eq(host.step_count, 2)
	assert_almost_eq(host.alpha(), 0.5, 1e-6)
	assert_eq(host.advance(DT * 0.6), 1, "the half step left over completes")
	assert_almost_eq(host.alpha(), 0.1, 1e-6)


func test_at_most_six_steps_a_frame_and_the_backlog_is_dropped() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config())
	assert_eq(host.advance(DT * 0.7), 0)
	# 0.1 s (the longest frame taken in) plus 0.7 of a step: 6.7 steps' worth
	assert_eq(host.advance(5.0), MatchHost.MAX_STEPS_PER_FRAME, "a long frame takes at most six steps")
	assert_eq(host.accumulated(), 0.0, "and drops what is left")
	assert_eq(host.step_count, 6)
	assert_eq(host.advance(DT * 0.5), 0, "the dropped backlog doesn't come back")


func test_slow_motion_scales_the_accumulator() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config())
	host.world.request_slowmo(100, 0.3)
	var steps: int = 0
	for n: int in 7:
		steps += host.advance(DT)
	assert_eq(steps, 2, "7 frames at 0.3x are 2.1 steps")
	host.world.slowmo_frames = 0
	assert_eq(host.advance(DT), 1, "full speed again")


func test_alpha_holds_still_during_hit_stop() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config())
	host.advance(DT * 1.5)
	assert_almost_eq(host.alpha(), 0.5, 1e-6)
	host.world.hitstop = 3
	assert_eq(host.alpha(), 1.0, "frozen on the impact frame")
	host.advance(DT * 0.25)
	assert_eq(host.alpha(), 1.0, "still frozen as wall time passes")
	var frame: int = host.world.frame
	host.step(3)
	assert_eq(host.world.hitstop, 0)
	assert_eq(host.world.frame, frame, "the three hit-stop steps didn't move the frame")
	assert_eq(host.alpha(), 1.0, "still the impact frame: poses don't step back when the freeze ends")
	host.step(1)
	assert_eq(host.world.frame, frame + 1)
	assert_almost_eq(host.alpha(), 0.75, 1e-6, "back to the accumulator once the frame moves")


func test_a_real_hit_stop_ends_without_stepping_back() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config(5))
	var steps: int = 0
	while host.world.hitstop == 0 and steps < 20000:
		host.step(1)
		steps += 1
	assert_gt(host.world.hitstop, 0, "a clash happened")
	host.advance(DT * 0.4)
	var frame: int = host.world.frame
	while host.world.hitstop > 0:
		host.step(1)
	assert_eq(host.world.frame, frame, "frozen")
	# the attack or reel on screen is the one at the impact frame, not a
	# fraction of a frame before it
	assert_eq(host.alpha(), 1.0)
	for i: int in 2:
		var f: Fighter = host.fighter(i)
		var shown: StickPose.Pose = StickPose.compute(f, host.alpha())
		var impact: StickPose.Pose = StickPose.compute(f, 1.0)
		assert_eq(shown.phase, impact.phase)
		assert_almost_eq(shown.right.pos, impact.right.pos, Vector3.ONE * 1e-6)


func test_a_real_hit_stop_shows_the_impact_frame() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config(5))
	var steps: int = 0
	while host.world.hitstop == 0 and steps < 20000:
		host.step(1)
		steps += 1
	assert_gt(host.world.hitstop, 0, "a clash happened")
	host.advance(DT * 0.4)
	assert_eq(host.alpha(), 1.0)
	for i: int in 2:
		var f: Fighter = host.fighter(i)
		assert_almost_eq(host.display_position(i), Vector3(f.pos.x, f.pos.y, f.pos.z), Vector3.ONE * 1e-5)


func test_display_position_blends_the_last_step() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config(3))
	host.step(Match.INTRO_FRAMES + 30)
	assert_eq(host.advance(DT * 0.5), 0, "half a step waits in the accumulator")
	var steps: int = 0
	# find a step where fighter 0 moves, outside hit-stop
	while steps < 5000:
		var f: Fighter = host.fighter(0)
		var before: Vector3 = Vector3(f.pos.x, f.pos.y, f.pos.z)
		host.step(1)
		var after: Vector3 = Vector3(f.pos.x, f.pos.y, f.pos.z)
		if host.world.hitstop == 0 and before.distance_to(after) > 0.02 and before.distance_to(after) < 1.0:
			assert_almost_eq(host.alpha(), 0.5, 1e-6)
			assert_almost_eq(host.display_position(0), before.lerp(after, 0.5), Vector3.ONE * 1e-5)
			return
		steps += 1
	fail_test("fighter 0 never moved")


# ------------------------------------------------------------------ pause

func test_pause_stops_stepping() -> void:
	var host: MatchHost = _host()
	watch_signals(host)
	host.start(_cpu_config())
	host.step(10)
	host.pause()
	assert_true(host.is_paused())
	assert_signal_emitted_with_parameters(host, "pause_changed", [true])
	assert_eq(host.advance(0.5), 0, "the clock stops")
	assert_eq(host.step(5), 0, "manual steps stop too")
	assert_eq(host.step_count, 10)
	host.resume()
	assert_false(host.is_paused())
	assert_signal_emitted_with_parameters(host, "pause_changed", [false])
	assert_eq(host.step(5), 5)


func test_stop_tells_the_listeners() -> void:
	var host: MatchHost = _host()
	watch_signals(host)
	host.start(_cpu_config())
	host.step(10)
	assert_signal_not_emitted(host, "stopped")
	host.stop()
	assert_false(host.is_started())
	assert_signal_emit_count(host, "stopped", 1)


func test_only_a_match_being_played_pauses() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.attract(), true)
	host.pause()
	assert_false(host.is_paused(), "the duel behind the menus never pauses")


func test_the_pause_binding_pauses_with_the_clock() -> void:
	var host: MatchHost = _host()
	host.auto_run = true
	host.start(MatchConfig.default_duel())
	fake.press_key(KEY_ESCAPE)
	host._process(DT)
	assert_true(host.is_paused(), "Esc pauses")
	host.resume()
	host._process(DT)
	assert_false(host.is_paused(), "Esc still held from the menu doesn't pause again")


# ------------------------------------------------------------------ input

func test_a_human_side_reads_its_device() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.default_duel())
	assert_eq(host.player_of_side(0), 0)
	assert_eq(host.player_of_side(1), -1)
	host.step(Match.INTRO_FRAMES + 1)
	assert_eq(host.fighter(0).state, &"free")
	fake.press_key(KEY_J) # light attack in the default profile
	host.step(2)
	assert_eq(host.fighter(0).state, &"attack", "the key reached the rules")
	assert_eq(host.label("light", 0), "Left Click")
	assert_eq(host.label("light", 1), "", "a computer side has no keys")


func test_the_duel_behind_the_menus_restarts_with_the_next_seed_from_its_source() -> void:
	var host: MatchHost = _host()
	var drawn: Array[int] = []
	host.seed_source = func() -> int:
		drawn.append(4242)
		return 4242
	host.start(MatchConfig.attract(41), true)
	var steps: int = 0
	while host.config.world_seed == 41 and steps < MATCH_LIMIT:
		host.step(1)
		steps += 1
	assert_eq(host.config.world_seed, 4242, "the seed came from the source (main's sequence)")
	assert_eq(drawn.size(), 1, "one seed drawn per restart")
	assert_true(host.attract)
	assert_false(host.is_finished(), "no results for the attract duel")
	assert_lt(host.step_count, 5, "a fresh match")


# ------------------------------------------------------------------ rounds

func test_a_new_round_places_the_fighters_instead_of_blending() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config(7))
	var started: Array[int] = []
	host.sim_event.connect(func(e: Dictionary) -> void:
		if e["t"] == &"roundStart":
			started.append(host.step_count))
	var steps: int = 0
	while started.is_empty() and steps < 30000:
		host.step(1)
		steps += 1
	assert_eq(started.size(), 1, "round 2 started")
	host.advance(DT * 0.3)
	for i: int in 2:
		var f: Fighter = host.fighter(i)
		assert_almost_eq(host.display_position(i), Vector3(f.pos.x, f.pos.y, f.pos.z), Vector3.ONE * 1e-6, "at the spawn at once")
		assert_almost_eq(host.display_yaw(i), f.yaw, 1e-6)


# ------------------------------------------------------------------ menu presses and resume

func _human_free(host: MatchHost) -> void:
	host.start(MatchConfig.default_duel())
	host.step(Match.INTRO_FRAMES + 1)
	assert_eq(host.fighter(0).state, &"free")


func test_a_button_pressed_in_the_pause_menu_does_nothing_on_resume() -> void:
	var host: MatchHost = _host()
	fake.plug_pad(0)
	_human_free(host)
	host.pause()
	# A chooses Resume in the pause menu: A is also jump
	fake.press_button(0, JOY_BUTTON_A)
	host.resume()
	host.step(3)
	assert_eq(host.fighter(0).state, &"free", "no jump from the menu's A")
	host.step(10)
	assert_eq(host.fighter(0).state, &"free", "nor while it stays held")
	fake.release_button(0, JOY_BUTTON_A)
	host.step(1)
	fake.press_button(0, JOY_BUTTON_A)
	host.step(2)
	assert_eq(host.fighter(0).state, &"jump", "a fresh press jumps")


func test_a_button_that_started_the_match_does_nothing_until_let_go() -> void:
	var host: MatchHost = _host()
	# Space (ui_accept) chose Duel: Space is also dodge
	fake.press_key(KEY_SPACE)
	host.start(MatchConfig.default_duel())
	host.step(Match.INTRO_FRAMES + 5)
	assert_eq(host.fighter(0).state, &"free", "no dodge from the menu's Space")
	fake.release_key(KEY_SPACE)
	host.step(1)
	fake.press_key(KEY_SPACE)
	host.step(2)
	assert_ne(host.fighter(0).state, &"free", "a fresh press dodges")


func test_a_block_held_through_the_pause_carries_on() -> void:
	var host: MatchHost = _host()
	_human_free(host)
	fake.press_key(KEY_L) # block in the default profile
	host.step(3)
	assert_true(host.fighter(0).blocking)
	host.pause()
	host.resume()
	host.step(3)
	assert_true(host.fighter(0).blocking, "still blocking after the pause")


func test_start_or_the_pause_binding_closes_the_pause() -> void:
	var host: MatchHost = _host()
	host.auto_run = true
	fake.plug_pad(0)
	host.start(MatchConfig.default_duel())
	fake.press_key(KEY_ESCAPE)
	host._process(DT)
	assert_true(host.is_paused())
	host._process(DT)
	assert_true(host.is_paused(), "Esc still held doesn't resume")
	fake.release_key(KEY_ESCAPE)
	host._process(DT)
	fake.press_button(0, JOY_BUTTON_START)
	host._process(DT)
	assert_false(host.is_paused(), "Start resumes")
	host._process(DT)
	assert_false(host.is_paused(), "and, still held, doesn't pause again")
	fake.release_button(0, JOY_BUTTON_START)
	host._process(DT)
	fake.press_key(KEY_P)
	host._process(DT)
	assert_true(host.is_paused(), "the pause binding pauses")
	fake.release_key(KEY_P)
	host._process(DT)
	fake.press_key(KEY_P)
	host._process(DT)
	assert_false(host.is_paused(), "and resumes")


# ------------------------------------------------------------------ configs, Training and Versus

func test_a_bad_config_starts_nothing() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.attract(3), true)
	var bad: MatchConfig = MatchConfig.default_duel()
	bad.mode = &"ranked"
	assert_false(host.start(bad))
	assert_push_error("bad match config")
	assert_true(host.attract, "the running duel is untouched")
	assert_eq(host.config.world_seed, 3)
	assert_true(host.start(MatchConfig.default_duel()))


func test_training_is_endless_against_the_dummy() -> void:
	var host: MatchHost = _host()
	var dummy: MatchSide = MatchSide.computer(&"hunter", &"greatsword", 1)
	dummy.controller = MatchSide.DUMMY
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"rogue", &"katana", 0), dummy, 5)
	assert_true(host.start(cfg))
	assert_true(host.sim_match.endless)
	assert_eq(host.player_of_side(0), 0)
	assert_eq(host.player_of_side(1), -1, "the dummy needs no device")
	host.step(Match.INTRO_FRAMES + 600)
	assert_eq(host.sim_match.phase, &"fight", "no round ends")
	assert_false(host.is_finished())
	assert_eq(host.sim_match.wins, [0, 0] as Array[int])


func test_training_runs_its_upkeep_inside_the_fixed_step() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.default_training(5))
	host.step(Match.INTRO_FRAMES + 10)
	assert_true(host.refill(), "refill starts on")
	host.fighter(1).hp = 50.0
	host.step(1)
	host.step(TrainingUpkeep.REFILL_AFTER)
	assert_eq(host.fighter(1).hp, 50.0, "not before 90 frames unhurt")
	host.step(5)
	assert_eq(host.fighter(1).hp, 60.0, "2 a step after")
	host.fighter(1).set_state(&"ko")
	host.step(1)
	assert_eq(host.fighter(1).state, &"free", "a K.O. stands up")


func test_training_refill_can_be_turned_off() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.default_training(5))
	host.step(Match.INTRO_FRAMES + 10)
	host.set_refill(false)
	assert_false(host.refill())
	host.fighter(1).hp = 50.0
	host.step(TrainingUpkeep.REFILL_AFTER + 30)
	assert_eq(host.fighter(1).hp, 50.0)
	host.set_refill(true)
	host.step(1)
	assert_eq(host.fighter(1).hp, 52.0, "on again")


func test_a_new_match_starts_with_refill_on() -> void:
	var host: MatchHost = _host()
	host.start(MatchConfig.default_training(5))
	host.set_refill(false)
	host.start(MatchConfig.default_training(6))
	assert_true(host.refill())


func _training(dummy_weapon: StringName) -> MatchHost:
	var host: MatchHost = _host()
	var cfg: MatchConfig = MatchConfig.default_training(5)
	cfg.sides[1].weapon_id = dummy_weapon
	host.start(cfg)
	host.step(Match.INTRO_FRAMES + 5)
	return host


func test_each_behaviour_on_each_dummy_weapon_ends_with_a_weapon_that_can_do_it() -> void:
	Roster.full = true # every weapon, the Slam's Greatsword included
	for picked: StringName in Moves.PLAYABLE_WEAPONS:
		var host: MatchHost = _training(picked)
		for b: StringName in TrainingBrain.BEHAVIOURS:
			host.set_training_behaviour(b)
			assert_eq(host.training_behaviour(), b)
			assert_eq((host.brain(1) as TrainingBrain).behaviour, b)
			var w: WeaponDef = host.fighter(1).weapon
			assert_true(TrainingUpkeep.can_perform(w, b), "%s from the %s: the %s" % [b, picked, w.id])
			host.step(30)
			assert_null(host.world.weapon_of(1), "no dropped weapon left behind")
			assert_true(host.fighter(1).armed)


func test_a_swap_tells_the_views_and_a_return_goes_back_to_the_picked_weapon() -> void:
	var host: MatchHost = _training(&"greatsword")
	watch_signals(host)
	host.set_training_behaviour(&"lights")
	assert_signal_not_emitted(host, "loadout_changed", "the Greatsword can throw lights")
	host.set_training_behaviour(&"thrust")
	assert_signal_emitted_with_parameters(host, "loadout_changed", [1])
	assert_eq(host.fighter(1).weapon.id, &"katana")
	assert_eq(host.fighter(1).abilities[0], &"k_thrust", "the practised thrust on the light slot")
	host.set_training_behaviour(&"heavies")
	assert_eq(host.fighter(1).weapon.id, &"greatsword", "back to the picked Greatsword")
	assert_signal_emit_count(host, "loadout_changed", 2)


func test_the_dummy_behaviour_outside_training_does_nothing() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config(7))
	host.set_training_behaviour(&"slam")
	assert_eq(host.training_behaviour(), &"")
	assert_eq(host.fighter(1).weapon.id, &"greatsword")


func test_only_training_has_upkeep() -> void:
	var host: MatchHost = _host()
	host.start(_cpu_config(7))
	host.step(Match.INTRO_FRAMES + 10)
	host.fighter(1).hp = 50.0
	host.fighter(0).set_state(&"ko")
	host.step(TrainingUpkeep.REFILL_AFTER + 30)
	assert_lt(host.fighter(1).hp, 50.01, "no refill in a Duel")
	assert_eq(host.fighter(0).state, &"ko", "nor getting up")


func test_versus_reads_each_player_from_their_own_device() -> void:
	var host: MatchHost = _host()
	fake.plug_pad(0)
	var cfg: MatchConfig = MatchConfig.make(
		MatchConfig.VERSUS,
		MatchSide.human(&"rogue", &"katana", 0, InputDevices.KBM),
		MatchSide.human(&"hunter", &"greatsword", 1, InputDevices.PAD0),
		9,
	)
	assert_true(host.start(cfg))
	assert_eq(host.player_of_side(0), 0)
	assert_eq(host.player_of_side(1), 1)
	host.step(Match.INTRO_FRAMES + 1)
	fake.press_key(KEY_J) # player 1 light on the keyboard
	host.step(2)
	assert_eq(host.fighter(0).state, &"attack")
	assert_eq(host.fighter(1).state, &"free", "the keyboard doesn't move player 2")
	fake.press_button(0, JOY_BUTTON_RIGHT_SHOULDER) # player 2 light on the controller
	host.step(2)
	assert_eq(host.fighter(1).state, &"attack")


func test_versus_players_cant_share_a_device() -> void:
	var cfg: MatchConfig = MatchConfig.make(
		MatchConfig.VERSUS,
		MatchSide.human(&"rogue", &"katana", 0),
		MatchSide.human(&"hunter", &"greatsword", 1),
	)
	assert_string_contains(cfg.problem(), "device")
	cfg.sides[0].device = InputDevices.PAD0
	cfg.sides[1].device = InputDevices.PAD0
	assert_string_contains(cfg.problem(), "share")
	cfg.sides[1].device = InputDevices.KB_ARROWS
	assert_eq(cfg.problem(), "")
