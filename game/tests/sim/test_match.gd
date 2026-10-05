extends GutTest
## Port of the "match flow" tests in tests/match.test.ts (the "input tracker"
## tests are in test_input.gd).

const H := preload("res://tests/sim/sim_helpers.gd")


func after_each() -> void:
	H.dispose_all()


## The stepM closure in the first test: n match steps, fighter 0 fed by p0()
## (a null Callable is idle), events collected.
func _step_m(M: Match, W: World, events: Array[Dictionary], n: int, p0: Callable = Callable()) -> void:
	for i: int in n:
		M.step([H.idle() if p0.is_null() else p0.call(), RawInput.empty()])
		events.append_array(W.drain_events())


func test_first_to_3_rounds_wins_the_match() -> void:
	var W: World = H.track(World.new(FighterConfig.make(Moves.KATANA), FighterConfig.make(Moves.KATANA), 3))
	var M: Match = Match.new(W)
	var events: Array[Dictionary] = []
	for round: int in 3:
		_step_m(M, W, events, Match.INTRO_FRAMES + 2)
		assert_eq(M.phase, &"fight")
		# put the fighters close and make the next hit lethal
		var a: Fighter = W.fighters[0]
		var b: Fighter = W.fighters[1]
		a.pos = V3.make(0.0, 0.0, -1.0)
		b.pos = V3.make(0.0, 0.0, 1.0)
		a.yaw = 0.0
		b.hp = 1.0
		var i: Array[int] = [0] # let i = 0, shared with the closure
		var first_light: Callable = func() -> RawInput:
			var first: bool = i[0] == 0
			i[0] += 1
			return H.btn(Btn.LIGHT) if first else H.idle()
		_step_m(M, W, events, 40, first_light)
		assert_eq(M.phase, &"roundEnd")
		_step_m(M, W, events, Match.ROUND_END_FRAMES + 2)
	assert_eq(M.wins, [3, 0] as Array[int])
	assert_eq(M.phase, &"matchEnd")
	assert_true(events.any(func(e: Dictionary) -> bool: return e["t"] == &"matchOver" and e["winner"] == 0))


func test_fighters_cannot_act_during_the_round_intro() -> void:
	var W: World = H.track(World.new(FighterConfig.make(Moves.KATANA), FighterConfig.make(Moves.KATANA), 3))
	var M: Match = Match.new(W)
	for i: int in 30:
		M.step([H.btn(Btn.LIGHT), RawInput.empty()])
	assert_eq(W.fighters[0].state, &"intro")
