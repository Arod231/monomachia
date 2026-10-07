extends GutTest
## The Greatsword's shoulder carry (authored-animation plan task 15): an armed
## Greatsword is Shouldered at every round start and after 20 frames in a row
## of moving, any action but standing still or jumping takes it off, and an
## attack started from the shoulder strikes 6 frames later. Expected numbers
## come from the spec (docs/specs/authored-animation.md, "Rules changes"), not
## the code.

const H := preload("res://tests/sim/sim_helpers.gd")

## The spec: shouldered after 20 consecutive frames of moving in the free state.
const MOVE_FRAMES: int = 20
## The spec: an attack from the shoulder adds 6 frames to its startup.
const LIFT: int = 6
## The states that leave the flag as it is: the round intro (where it is
## lifted on), moving (free and step), jumping (jump and land) and victory.
const CARRY_STATES: Array[StringName] = [&"intro", &"free", &"step", &"jump", &"land", &"victory"]

var IDLE: Callable = Callable()


func after_each() -> void:
	H.dispose_all()


# ------------------------------------------------------------------ helpers

## A Greatsword (fighter 0) facing an idle Katana gap m away, shouldered or
## not.
static func _gs(gap: float = 2.2, shouldered: bool = false) -> World:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, gap)
	W.fighters[0].shouldered = shouldered
	return W


## Whether event e is fighter 0's: its own (f) or its attack's (attacker).
static func _mine(e: Dictionary) -> bool:
	return int(e.get("f", e.get("attacker", -1))) == 0


## The steps (indices of n steps) on which fighter 0 emits each event of type
## t, playing p0 (index -> RawInput) against p1 (null: idle).
static func _steps_of(W: World, n: int, t: StringName, p0: Callable, p1: Callable = Callable()) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		var in0: RawInput = H.idle() if p0.is_null() else p0.call(i)
		var in1: RawInput = H.idle() if p1.is_null() else p1.call(i)
		W.step([in0, in1])
		for e: Dictionary in W.drain_events():
			if e["t"] == t and _mine(e):
				out.append(i)
	return out


## The first step fighter 0 emits t on (see _steps_of), or -1.
static func _first(W: World, n: int, t: StringName, p0: Callable, p1: Callable = Callable()) -> int:
	var s: Array[int] = _steps_of(W, n, t, p0, p1)
	return s[0] if not s.is_empty() else -1


## Strafing right (the stick pushed from neutral starts with a step).
static func _strafe(_i: int) -> RawInput:
	return H.move(1.0, 0.0)


## n steps of input `fn` (index -> RawInput) for fighter 0 against an idle
## opponent.
static func _drive(W: World, n: int, fn: Callable) -> void:
	H.run(W, n, fn)


# ------------------------------------------------------------------ on

func test_a_greatsword_starts_every_round_shouldered_and_a_katana_never() -> void:
	var W: World = H.track(World.new(FighterConfig.make(Moves.GREATSWORD), FighterConfig.make(Moves.KATANA), 3))
	assert_true(W.fighters[0].shouldered, "the Greatsword is on the shoulder at the round intro")
	assert_false(W.fighters[1].shouldered, "the Katana is never shouldered")
	W.fighters[0].shouldered = false
	W.reset_round()
	assert_true(W.fighters[0].shouldered, "and back on the shoulder at the next round's start")


func test_the_round_intro_and_its_end_leave_the_greatsword_shouldered() -> void:
	var W: World = H.track(World.new(FighterConfig.make(Moves.GREATSWORD), FighterConfig.make(Moves.KATANA), 3))
	var a: Fighter = W.fighters[0]
	H.run(W, 30)
	assert_eq(a.state, &"intro")
	assert_true(a.shouldered, "shouldered through the intro")
	a.set_state(&"free")
	H.run(W, 10)
	assert_true(a.shouldered, "and still when the fight starts")


func test_twenty_frames_of_walking_shoulder_the_greatsword() -> void:
	var W: World = _gs(4.0)
	var a: Fighter = W.fighters[0]
	_drive(W, 1, _strafe)
	assert_eq(a.state, &"step", "the walk starts with a step, which counts as moving")
	_drive(W, MOVE_FRAMES - 2, _strafe)
	assert_false(a.shouldered, "not after 19 frames of moving")
	_drive(W, 1, _strafe)
	assert_true(a.shouldered, "shouldered on the 20th")


func test_twenty_frames_of_sprinting_shoulder_the_greatsword() -> void:
	var W: World = _gs(9.0)
	var a: Fighter = W.fighters[0]
	var sprint: Callable = func(_i: int) -> RawInput: return H.move(0.0, 1.0, Btn.SPRINT)
	_drive(W, MOVE_FRAMES - 1, sprint)
	assert_true(a.input.sprinting(), "sprinting")
	assert_false(a.shouldered, "not after 19 frames")
	_drive(W, 1, sprint)
	assert_true(a.shouldered, "shouldered on the 20th")


func test_the_twenty_frames_must_come_in_a_row() -> void:
	var W: World = _gs(4.0)
	var a: Fighter = W.fighters[0]
	var walk_stop_walk: Callable = func(i: int) -> RawInput: return H.idle() if i == 15 else H.move(1.0, 0.0)
	_drive(W, 31, walk_stop_walk)
	assert_false(a.shouldered, "15 frames, a stop, then 15 more: not shouldered")
	_drive(W, 5, _strafe)
	assert_true(a.shouldered, "20 in a row after the stop: shouldered")


func test_walking_with_the_guard_up_never_shoulders_it() -> void:
	var W: World = _gs(4.0)
	var a: Fighter = W.fighters[0]
	_drive(W, 60, func(_i: int) -> RawInput: return H.move(1.0, 0.0, Btn.BLOCK))
	assert_true(a.blocking, "walking in guard")
	assert_false(a.shouldered, "a second of it: not shouldered")


func test_only_an_armed_greatsword_is_ever_shouldered() -> void:
	var K: World = H.make_world(Moves.KATANA, Moves.KATANA, 4.0)
	_drive(K, 60, _strafe)
	assert_false(K.fighters[0].shouldered, "a Katana walking a second")
	var W: World = _gs(4.0)
	var a: Fighter = W.fighters[0]
	a.armed = false
	_drive(W, 60, _strafe)
	assert_false(a.shouldered, "a disarmed Greatsword fighter walking a second")


# ------------------------------------------------------------------ left alone

func test_standing_still_leaves_the_flag_as_it_is() -> void:
	var W: World = _gs(4.0, true)
	_drive(W, 120, IDLE)
	assert_true(W.fighters[0].shouldered, "shouldered after two seconds standing")
	var V: World = _gs(4.0, false)
	_drive(V, 120, IDLE)
	assert_false(V.fighters[0].shouldered, "and not shouldered stays so")


func test_jumping_and_landing_leave_the_flag_as_it_is() -> void:
	var W: World = _gs(4.0, true)
	var a: Fighter = W.fighters[0]
	var seen: Array[StringName] = []
	var always: bool = true
	for i: int in 50:
		W.step([H.btn(Btn.JUMP) if i == 0 else H.idle(), H.idle()])
		if not seen.has(a.state):
			seen.append(a.state)
		always = always and a.shouldered
	assert_true(seen.has(&"jump") and seen.has(&"land"), "jumped and landed: %s" % [seen])
	assert_true(always, "shouldered on every frame of it")
	var V: World = _gs(4.0, false)
	_drive(V, 50, H.tap_at(0, Btn.JUMP))
	assert_false(V.fighters[0].shouldered, "a jump doesn't shoulder it either")


# ------------------------------------------------------------------ off

func test_each_action_takes_it_off_the_shoulder_at_once() -> void:
	var actions: Dictionary[String, RawInput] = {
		"a light": H.btn(Btn.LIGHT),
		"a heavy": H.btn(Btn.HEAVY),
		"a block": H.btn(Btn.BLOCK),
		"a dodge": H.move(1.0, 0.0, Btn.DODGE),
		"a backstep": H.btn(Btn.DODGE),
	}
	for what: String in actions:
		var W: World = _gs(4.0, true)
		W.step([actions[what], H.idle()])
		assert_false(W.fighters[0].shouldered, "%s takes it off on its first frame" % what)


func test_a_parry_press_takes_it_off() -> void:
	var W: World = _gs(4.0, true)
	var a: Fighter = W.fighters[0]
	_drive(W, 1, H.tap_at(0, Btn.BLOCK))
	_drive(W, 10, IDLE)
	assert_eq(a.parry_window_at_press, Moves.GREATSWORD.parry_window, "a parry press")
	assert_false(a.shouldered, "takes it off, and it stays off")


func test_being_hit_takes_it_off() -> void:
	var W: World = _gs(2.2, true)
	var a: Fighter = W.fighters[0]
	var hits: Array[int] = []
	for i: int in 60:
		W.step([H.idle(), H.btn(Btn.LIGHT) if i == 0 else H.idle()])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"hit" and e["target"] == 0:
				hits.append(i)
				assert_eq(a.state, &"hitstun", "hit into hitstun")
				assert_false(a.shouldered, "the hit takes it off")
	assert_eq(hits.size(), 1, "the Katana's light hits once")


func test_every_state_but_moving_standing_jumping_and_the_round_flow_takes_it_off() -> void:
	# hitstun, blockstun, parryAnim, pickup, disarmStagger, stunned... and any
	# state added later (the knockdown)
	for s: StringName in Fighter.STATES:
		var W: World = _gs(4.0, true)
		var a: Fighter = W.fighters[0]
		a.set_state(s, 10)
		assert_eq(a.shouldered, CARRY_STATES.has(s), "%s %s it" % [s, "keeps" if CARRY_STATES.has(s) else "takes off"])


func test_a_disarm_takes_it_off_and_a_pick_up_doesnt_put_it_back() -> void:
	var W: World = _gs(2.2, true)
	var a: Fighter = W.fighters[0]
	a.disarm(W.fighters[1], &"parried")
	assert_false(a.shouldered, "disarmed: off")
	a.armed = true
	a.set_state(&"pickup", SimConst.PICKUP_FRAMES)
	_drive(W, SimConst.PICKUP_FRAMES + 2, IDLE)
	assert_eq(a.state, &"free", "picked up and free")
	assert_false(a.shouldered, "not shouldered until it moves again")


# ------------------------------------------------------------------ the lift

## The step fighter 0's first `t` event comes on, playing p0 from a Greatsword
## gap m from an idle Katana, shouldered or not.
func _first_from(shouldered: bool, t: StringName, p0: Callable, gap: float = 2.2, setup: Callable = Callable()) -> int:
	var W: World = _gs(gap, shouldered)
	if not setup.is_null():
		setup.call(W)
	return _first(W, 240, t, p0)


func test_a_light_and_a_heavy_from_the_shoulder_hit_6_frames_later() -> void:
	for b: int in [Btn.LIGHT, Btn.HEAVY]:
		var what: String = "Heavy Swing" if b == Btn.LIGHT else "Overhead Strike"
		var plain: int = _first_from(false, &"hit", H.tap_at(0, b))
		var lifted: int = _first_from(true, &"hit", H.tap_at(0, b))
		assert_true(plain > 0, "%s hits" % what)
		assert_eq(lifted - plain, LIFT, "%s from the shoulder hits 6 frames later" % what)
		var swing_plain: int = _first_from(false, &"swing", H.tap_at(0, b))
		var swing_lifted: int = _first_from(true, &"swing", H.tap_at(0, b))
		assert_eq(swing_lifted - swing_plain, LIFT, "%s swings 6 frames later" % what)


func test_an_attack_from_the_shoulder_keeps_its_active_and_recovery_frames() -> void:
	var ends: Array[int] = []
	for shouldered: bool in [false, true]:
		var W: World = _gs(6.0, shouldered)
		var a: Fighter = W.fighters[0]
		var end: int = -1
		for i: int in 120:
			W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
			if end < 0 and i > 0 and a.state != &"attack":
				end = i
		ends.append(end)
	var def: AttackDef = Moves.GREATSWORD.moves[&"g_l1"]
	assert_eq(ends[0], def.startup + def.active + def.recovery, "Heavy Swing lasts its frames")
	assert_eq(ends[1] - ends[0], LIFT, "and from the shoulder only its 6-frame lift longer")


func test_a_jump_attack_from_the_shoulder_swings_6_frames_later() -> void:
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.JUMP) if i == 0 else (H.btn(Btn.LIGHT) if i == 2 else H.idle())
	var plain: int = _first_from(false, &"swing", p0, 6.0)
	var lifted: int = _first_from(true, &"swing", p0, 6.0)
	assert_true(plain > 0, "Aerial Chop swings")
	assert_eq(lifted - plain, LIFT, "Aerial Chop from the shoulder swings 6 frames later")


func test_a_sprint_attack_from_the_shoulder_swings_6_frames_later() -> void:
	# sprinting 10 frames isn't enough to shoulder it; 25 frames is
	var swings: Array[int] = []
	for run_for: int in [10, 25]:
		var W: World = _gs(12.0)
		var p0: Callable = func(i: int) -> RawInput:
			return H.move(0.0, 1.0, Btn.SPRINT) if i < run_for else (H.btn(Btn.LIGHT) if i == run_for else H.idle())
		var attacks: Array[StringName] = []
		var s: int = -1
		for i: int in 120:
			W.step([p0.call(i), H.idle()])
			if W.fighters[0].atk != null and not attacks.has(W.fighters[0].atk.def.id):
				attacks.append(W.fighters[0].atk.def.id)
			for e: Dictionary in W.drain_events():
				if s < 0 and e["t"] == &"swing" and e["f"] == 0:
					s = i - run_for
		assert_eq(attacks, [&"g_sl"] as Array[StringName], "Shoulder Charge after sprinting %d frames" % run_for)
		swings.append(s)
	assert_eq(swings[1] - swings[0], LIFT, "from the shoulder it swings 6 frames later")


func test_a_block_ability_pressed_with_the_guard_pays_the_whole_lift() -> void:
	var p0: Callable = func(_i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.LIGHT) if _i == 0 else H.btn(Btn.BLOCK)
	var plain: int = _first_from(false, &"swing", p0, 6.0)
	var lifted: int = _first_from(true, &"swing", p0, 6.0)
	assert_true(plain > 0, "Reaping Sweep swings")
	assert_eq(lifted - plain, LIFT, "Reaping Sweep from the shoulder swings 6 frames later")


func test_a_block_ability_pressed_just_after_the_guard_pays_the_rest_of_the_lift() -> void:
	# the guard starts the lift off the shoulder; an ability one frame into it
	# waits for the other five
	var p0: Callable = func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.LIGHT) if i == 1 else H.btn(Btn.BLOCK)
	var plain: int = _first_from(false, &"swing", p0, 6.0)
	var lifted: int = _first_from(true, &"swing", p0, 6.0)
	assert_eq(lifted - plain, LIFT - 1, "Reaping Sweep a frame into the guard swings 5 frames later")
	var late: Callable = func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.LIGHT) if i == LIFT else H.btn(Btn.BLOCK)
	assert_eq(
		_first_from(true, &"swing", late, 6.0), _first_from(false, &"swing", late, 6.0), "and from a raised guard, on time"
	)


func test_the_ultimate_from_the_shoulder_dashes_6_frames_later() -> void:
	var low_hp: Callable = func(W: World) -> void: W.fighters[0].hp = 20.0
	var plain: int = _first_from(false, &"ultDash", H.tap_at(0, Btn.ULTIMATE), 6.0, low_hp)
	var lifted: int = _first_from(true, &"ultDash", H.tap_at(0, Btn.ULTIMATE), 6.0, low_hp)
	assert_true(plain > 0, "the Impaler dashes")
	assert_eq(lifted - plain, LIFT, "from the shoulder, 6 frames later")


func test_the_dodge_cancel_opens_6_frames_later() -> void:
	# dodge pressed on every other step: the dodge comes on the first frame the
	# cancel allows
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.LIGHT) if i == 0 else (H.btn(Btn.DODGE) if i % 2 == 1 else H.idle())
	var plain: int = _first_from(false, &"dodge", p0, 6.0)
	var lifted: int = _first_from(true, &"dodge", p0, 6.0)
	assert_eq(plain, Moves.GREATSWORD.moves[&"g_l1"].dodge_cancel_from,"Heavy Swing's dodge cancel opens on its frame 26")
	assert_eq(lifted - plain, LIFT, "and from the shoulder 6 frames later")


func test_dodge_attacks_never_pay() -> void:
	var p0: Callable = func(i: int) -> RawInput:
		return H.move(1.0, 0.0, Btn.DODGE) if i == 0 else (H.btn(Btn.LIGHT) if i == 14 else H.idle())
	var plain: int = _first_from(false, &"swing", p0, 2.2)
	var lifted: int = _first_from(true, &"swing", p0, 2.2)
	assert_true(plain > 0, "the dodge light swings")
	assert_eq(lifted, plain, "and from the shoulder on time: the dodge took it off")


func test_string_follow_ups_never_pay() -> void:
	# light mashed on every other step: Heavy Swing, then Backswing
	var p0: Callable = func(i: int) -> RawInput: return H.btn(Btn.LIGHT) if i % 2 == 0 and i < 60 else H.idle()
	var plain: Array[int] = _steps_of(_gs(6.0, false), 80, &"swing", p0)
	var lifted: Array[int] = _steps_of(_gs(6.0, true), 80, &"swing", p0)
	assert_true(plain.size() >= 2 and lifted.size() >= 2, "two swings each: %s, %s" % [plain, lifted])
	if plain.size() < 2 or lifted.size() < 2:
		return
	assert_eq(lifted[0] - plain[0], LIFT, "Heavy Swing pays the lift")
	assert_eq(lifted[1] - plain[1], LIFT, "Backswing only follows it, paying nothing more")


# ------------------------------------------------------------------ the computer opponent

func test_the_brains_impact_estimate_includes_the_lift() -> void:
	var W: World = _gs(2.2, true)
	var steps: int = 0
	var estimate: int = -1
	var hit: int = -1
	var active: int = -1
	for i: int in 60:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		if i == 0:
			estimate = AIBrain.frames_to_impact(W.fighters[0].atk)
			steps = i
		for e: Dictionary in W.drain_events():
			if active < 0 and e["t"] == &"swing" and e["f"] == 0:
				# (on its last startup frame)
				active = i + 1
			if hit < 0 and e["t"] == &"hit" and e["attacker"] == 0:
				hit = i
	assert_true(hit > 0, "Heavy Swing hits")
	# (its blade, baked from its clip, first touches on its second active
	# frame; the estimate is to the first, where a hit can start)
	assert_eq(estimate, active - steps, "on its first frame the estimate is the frames to its active frames, lift and all")
	assert_between(hit - active, 0, Moves.GREATSWORD.moves[&"g_l1"].active - 1, "and it hits in them")


func test_a_quick_parrying_brain_parries_heavy_swing_from_the_shoulder() -> void:
	var params: AIBrain.AIParams = AIBrain.DIFFICULTY[&"hard"].copy()
	params.reaction = 1.0
	params.reaction_jitter = 0.0
	params.parry = 1.0
	params.counter = 0.0
	params.block = 0.0
	params.dodge = 0.0
	params.aggression = 0.0
	params.guard = 0.0
	params.timing_error = 0
	params.use_ult = 0.0
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		# at the Greatsword's duelling distance, the brain's attacks held off so
		# it doesn't swing first (the 1.3 m blade's reach covers it, KE task 2)
		var W: World = _gs(Moves.GREATSWORD.duel_distance, true)
		var ai: AIBrain = AIBrain.new(W.fighters[1], params, seed_value)
		ai._attack_cooldown_until = 1 << 30
		var parried: bool = false
		for i: int in 40:
			W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), ai.think()])
			for e: Dictionary in W.drain_events():
				if e["t"] == &"parry" and e["parrier"] == 1:
					parried = true
		ai.dispose()
		assert_true(parried, "seed %d: the brain times its parry to the lifted swing" % seed_value)
