extends GutTest
## The computer and Training finish (milestone-1 task 107, P3 and P55,
## stories 123 and 124). The computer presses the finisher prompt on a share
## of prompts set by its difficulty, at a frame its own generator draws inside
## the window (the spec's computer's finisher rates table); Training's dummy
## never presses, and a finisher in Training plays in full, then its victim
## comes back at once at full HP and posture, re-armed, its weapon gone from
## the floor (the owner's answers, Oct 5).

const H := preload("res://tests/sim/sim_helpers.gd")

## Prompts pressed, and the window's frames pressed in (1 is the first after
## the prompt opens, 18 the last), per difficulty.
const RATES: Dictionary[StringName, float] = {&"easy": 0.3, &"normal": 0.6, &"hard": 0.9}
const FRAMES: Dictionary[StringName, Vector2i] = {&"easy": Vector2i(10, 18), &"normal": Vector2i(1, 18), &"hard": Vector2i(1, 6)}
const TRIALS: int = 300


func after_each() -> void:
	H.dispose_all()


## Opens a prompt for a computer at `difficulty` (fighter 1, seeded
## `seed_value`) and plays it out: the window's frame it started the finisher
## on (1-18), or 0 when it let the prompt pass.
static func _trial(difficulty: StringName, seed_value: int) -> int:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.0)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	var ai: AIBrain = AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[difficulty], seed_value)
	W.fighters[0].hp = 5.0
	W.fighters[0].disarm(W.fighters[1], &"parried")
	W.hitstop = 14
	W.drain_events()
	var at: int = W.frame
	var pressed: int = 0
	for _i: int in 60:
		W.step([H.idle(), ai.think()])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"finisher":
				pressed = W.frame - at
	ai.dispose()
	return pressed


func test_each_difficulty_presses_its_share_of_prompts_inside_its_frames() -> void:
	for difficulty: StringName in RATES:
		var pressed: int = 0
		var frames: Vector2i = FRAMES[difficulty]
		var outside: Array[int] = []
		for seed_value: int in TRIALS:
			var at: int = _trial(difficulty, seed_value + 1)
			if at > 0:
				pressed += 1
				if at < frames.x or at > frames.y:
					outside.append(at)
		var share: float = float(pressed) / float(TRIALS)
		gut.p("%s: %d of %d prompts pressed (%.1f%%)" % [difficulty, pressed, TRIALS, share * 100.0])
		assert_almost_eq(share, RATES[difficulty], 0.07, "%s presses %.0f%% of prompts" % [difficulty, RATES[difficulty] * 100.0])
		assert_eq(outside, [] as Array[int], "%s presses inside frames %d-%d" % [difficulty, frames.x, frames.y])


func test_the_same_seed_makes_the_same_choice() -> void:
	for seed_value: int in [3, 4, 5, 6]:
		assert_eq(_trial(&"normal", seed_value), _trial(&"normal", seed_value), "seed %d" % seed_value)


func test_training_s_dummy_never_presses_the_prompt() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.0)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	var dummy: TrainingBrain = TrainingBrain.new(W.fighters[1])
	dummy.set_behaviour(&"fight")
	var r: H.Rec = H.Rec.new()
	for seed_value: int in 20:
		W.fighters[0].armed = true
		W.fighters[0].set_state(&"free")
		W.fighters[0].hp = 5.0
		W.fighters[0].disarm(W.fighters[1], &"parried")
		for _i: int in 60:
			W.step([H.idle(), dummy.think()])
			r.collect(W)
		W.remove_dropped_weapon(0)
	dummy.dispose()
	assert_eq(r.count(&"finisherPrompt"), 20, "a prompt opened for it each time")
	assert_eq(r.count(&"finisher"), 0, "and it never finished")


func test_a_finisher_in_training_plays_in_full_then_the_victim_comes_back_at_once() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.0)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	var up: TrainingUpkeep = TrainingUpkeep.new(W)
	var dummy: Fighter = W.fighters[1]
	dummy.hp = 5.0
	dummy.posture = 40.0
	dummy.disarm(W.fighters[0], &"parried")
	var r: H.Rec = H.Rec.new()
	var pressed: bool = false
	var ended_at: int = -1
	for i: int in 200:
		var in0: RawInput = H.btn(Btn.HEAVY) if i == 16 else H.idle()
		W.step([in0, H.idle()])
		up.step()
		r.collect(W)
		pressed = pressed or r.has(&"finisher")
		if r.has(&"finisherKill") and W.finisher_by >= 0:
			assert_eq(dummy.state, &"ko", "after the kill it stays down while the finisher plays")
		if pressed and W.finisher_by < 0 and ended_at < 0:
			ended_at = W.frame
			assert_eq(dummy.state, &"free", "back up as the finisher ends")
			assert_eq([dummy.hp, dummy.posture, dummy.armed], [SimConst.HP_MAX, 0.0, true], "at full HP and posture, re-armed")
			assert_null(W.weapon_of(1), "its weapon gone from the floor")
	assert_true(pressed, "the finisher played")
	assert_gt(ended_at, 0, "and ended")
	assert_eq(r.count(&"ko"), 1, "one K.O.")
