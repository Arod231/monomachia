extends GutTest
## Behaviour tests for the training dummy (TrainingBrain) and the computer's
## counters.
##
## They check what the dummy and the brain do, by events and states, so they
## keep holding when the rules change. They replace the input hashes that
## pinned both brains to the TypeScript demo (plan task 8.1).

const H := preload("res://tests/sim/sim_helpers.gd")

## The distance the dummy keeps from its opponent, per weapon (TrainingBrain.think).
const PRACTICE_DISTANCE: Dictionary[StringName, float] = {&"katana": 2.2, &"greatsword": 2.6, &"daggers": 1.8}

## [weapon, drill, the unblockable it practises]
const UNBLOCKABLE_DRILLS: Array = [
	[&"katana", &"thrust", &"k_thrust"],
	[&"katana", &"sweep", &"k_sweep"],
	[&"greatsword", &"sweep", &"g_sweep"],
	[&"greatsword", &"slam", &"g_slam"],
	[&"daggers", &"thrust", &"d_needle"],
	[&"daggers", &"sweep", &"d_sweep"],
]

## The unblockables each weapon can be drilled on.
const UNBLOCKABLE_KINDS: Dictionary[StringName, Array] = {
	&"katana": [&"thrust", &"sweep"],
	&"greatsword": [&"sweep", &"slam"],
	&"daggers": [&"thrust", &"sweep"],
}

## Each weapon's whole light string, from its light starter.
const LIGHT_STRINGS: Dictionary[StringName, Array] = {
	&"katana": [&"k_l1", &"k_l2", &"k_l3", &"k_l4"],
	&"greatsword": [&"g_l1", &"g_l2"],
	&"daggers": [&"d_l1", &"d_l2", &"d_l3", &"d_l4"],
}

## [drill, the dummy's weapon, the counter that beats it]
const COUNTERS: Array = [
	[&"slam", &"greatsword", &"evade"],
	[&"thrust", &"katana", &"stomp"],
	[&"sweep", &"greatsword", &"leap"],
]


func after_each() -> void:
	H.dispose_all()


## What one run of the dummy did: every event, each with "at", the world
## frame it came on, and the dummy's inputs, guard and path.
class DummyRun extends SimHelpers.Rec:
	## The dummy's input on each step.
	var inputs: Array[RawInput] = []
	## Whether the dummy was blocking after each step.
	var blocking: Array[bool] = []
	## Where the dummy stood before the first step, on the ground (x, z).
	var start: Vector2
	## Where the dummy stood after each step, on the ground (x, z).
	var path: Array[Vector2] = []

	func collect(W: World) -> void:
		for e: Dictionary in W.drain_events():
			e["at"] = W.frame
			events.append(e)

	## The dummy's (fighter 0's) events of type t.
	func by_dummy(t: StringName) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for e: Dictionary in all(t):
			if e.get("f", -1) == 0:
				out.append(e)
		return out

	## The dummy's swings of one attack.
	func swings_of(attack: StringName) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for e: Dictionary in by_dummy(&"swing"):
			if e["attack"] == attack:
				out.append(e)
		return out

	## The ids of the dummy's swings, in order.
	func swung() -> Array[StringName]:
		var out: Array[StringName] = []
		for e: Dictionary in by_dummy(&"swing"):
			out.append(e["attack"])
		return out


## Steps W `frames` times, the dummy driving fighter 0 and `opponent` (the
## step index -> RawInput) fighter 1. Health, posture and knockdowns reset
## every step, as in counterlab.
static func _run(W: World, dummy: TrainingBrain, frames: int, opponent: Callable) -> DummyRun:
	var run: DummyRun = DummyRun.new()
	run.start = Vector2(W.fighters[0].pos.x, W.fighters[0].pos.z)
	for i: int in frames:
		var in0: RawInput = dummy.think()
		W.step([in0, opponent.call(i)])
		run.collect(W)
		run.inputs.append(in0)
		run.blocking.append(W.fighters[0].blocking)
		run.path.append(Vector2(W.fighters[0].pos.x, W.fighters[0].pos.z))
		for f: Fighter in W.fighters:
			f.hp = 100.0
			f.posture = 0.0
			if f.state == &"ko":
				f.set_state(&"free")
	return run


## Plays the dummy (fighter 0) for `frames` steps at its practice distance
## from fighter 1, which `opponent` drives (idle when null).
static func _play(
	weapon: WeaponDef, behaviour: StringName, frames: int, opponent: Callable = Callable()
) -> DummyRun:
	var W: World = H.make_world(weapon, Moves.KATANA, PRACTICE_DISTANCE[weapon.id])
	var dummy: TrainingBrain = TrainingBrain.new(W.fighters[0])
	dummy.set_behaviour(behaviour)
	if opponent.is_null():
		opponent = func(_i: int) -> RawInput: return H.idle()
	var run: DummyRun = _run(W, dummy, frames, opponent)
	dummy.dispose()
	return run


## Each event's "kind", once, in the order they first came.
static func _kinds(events: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in events:
		if not out.has(e["kind"]):
			out.append(e["kind"])
	return out


## Asserts each event came `gap` or more world frames after the one before.
func _assert_gaps(events: Array[Dictionary], gap: int, what: String) -> void:
	for k: int in range(1, events.size()):
		assert_gte(events[k]["at"] - events[k - 1]["at"], gap, "%s %d comes %d or more frames after the last" % [what, k, gap])


func test_the_idle_dummy_presses_nothing_and_stays_put() -> void:
	var run: DummyRun = _play(Moves.KATANA, &"idle", 300)
	var pressed: int = 0
	for r: RawInput in run.inputs:
		if r.buttons != 0 or r.mx != 0.0 or r.my != 0.0:
			pressed += 1
	assert_eq(pressed, 0, "no button or stick input on any of 300 steps")
	var own: Array = run.events.filter(func(e: Dictionary) -> bool: return e.get("f", -1) == 0)
	assert_eq(own, [], "the dummy does nothing that makes an event")
	assert_eq(run.path.filter(func(p: Vector2) -> bool: return p != run.start), [], "the dummy never moves")


func test_the_blocking_dummy_holds_block_and_blocks_every_light() -> void:
	# the opponent throws a Right Cut every 60 steps, the first well after the
	# dummy's first block press so it is blocked, not parried
	var opponent: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.LIGHT) if i >= 30 and i % 60 == 30 else H.idle()
	var run: DummyRun = _play(Moves.KATANA, &"block", 600, opponent)
	var held: int = 0
	for r: RawInput in run.inputs:
		if r.buttons == 1 << Btn.BLOCK and r.mx == 0.0 and r.my == 0.0:
			held += 1
	assert_eq(held, 600, "block alone is held on every step")
	assert_eq(run.blocking.count(false), 0, "the dummy is blocking after every step")
	var blocked: Array = run.all(&"block").filter(func(e: Dictionary) -> bool: return e["target"] == 0)
	var hit: Array = run.all(&"hit").filter(func(e: Dictionary) -> bool: return e["target"] == 0)
	assert_eq(blocked.size(), 10, "each of the opponent's 10 lights is blocked")
	assert_eq(hit, [], "nothing hits the dummy")


func test_the_lights_dummy_throws_its_weapons_whole_light_string_110_frames_apart() -> void:
	for weapon_id: StringName in LIGHT_STRINGS:
		var string: Array = LIGHT_STRINGS[weapon_id]
		var run: DummyRun = _play(Moves.WEAPONS[weapon_id], &"lights", 660)
		var expected: Array[StringName] = []
		for _s: int in 5:
			expected.append_array(string)
		var swung: Array[StringName] = run.swung()
		assert_eq(swung.slice(0, expected.size()), expected, "%s: the whole light string, five times over" % weapon_id)
		assert_eq(swung.filter(func(id: StringName) -> bool: return not string.has(id)), [], "%s: and nothing else" % weapon_id)
		_assert_gaps(run.swings_of(string[0]), 110, "%s string" % weapon_id)


func test_the_heavies_dummy_adds_the_heavy_follow_up_every_other_time() -> void:
	var run: DummyRun = _play(Moves.KATANA, &"heavies", 720)
	var expected: Array[StringName] = []
	for c: int in 5:
		expected.append(&"k_iai")
		if c % 2 == 0:
			expected.append(&"k_h1f")
	assert_eq(run.swung().slice(0, expected.size()), expected, "the Iai Slash, then Rising Heaven every other time")
	for e: Dictionary in run.by_dummy(&"swing"):
		assert_true(e["heavy"], "%s is a heavy" % e["attack"])
	_assert_gaps(run.swings_of(&"k_iai"), 120, "the Iai Slash")


func test_each_unblockable_drill_repeats_its_unblockable_from_the_light_slot() -> void:
	for drill: Array in UNBLOCKABLE_DRILLS:
		var weapon: WeaponDef = Moves.WEAPONS[drill[0]]
		var behaviour: StringName = drill[1]
		var unblockable: StringName = drill[2]
		var label: String = "%s %s" % [weapon.id, behaviour]
		var W: World = H.make_world(weapon)
		var dummy: TrainingBrain = TrainingBrain.new(W.fighters[0])
		dummy.set_behaviour(behaviour)
		assert_eq(W.fighters[0].abilities[0], unblockable, label + ": the unblockable is on the light slot")
		dummy.dispose()

		var run: DummyRun = _play(weapon, behaviour, 400)
		var telegraphs: Array[Dictionary] = run.by_dummy(&"telegraph")
		assert_gte(telegraphs.size(), 3, label + ": three or more tries in 400 frames")
		for e: Dictionary in telegraphs:
			assert_eq([e["kind"], e["attack"]], [behaviour, unblockable], label + ": every try is the unblockable")
		_assert_gaps(telegraphs, 130, label + " try")
		assert_eq(run.swung().filter(func(id: StringName) -> bool: return id != unblockable), [], label + ": no other swing")


func test_choosing_random_again_starts_it_over_at_lights() -> void:
	var W: World = H.make_world(Moves.KATANA)
	var dummy: TrainingBrain = TrainingBrain.new(W.fighters[0])
	dummy.set_behaviour(&"random")
	for _i: int in 300: # two drills in
		W.step([dummy.think(), H.idle()])
	W.drain_events()
	dummy.set_behaviour(&"random")
	var swung: Array[StringName] = []
	for _i: int in 60:
		W.step([dummy.think(), H.idle()])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"swing" and e["f"] == 0:
				swung.append(e["attack"])
	dummy.dispose()
	assert_eq(swung.slice(0, 1), [&"k_l1"] as Array[StringName], "the first drill is lights again")


func test_an_unblockable_drill_the_weapon_lacks_leaves_the_default_abilities() -> void:
	var W: World = H.make_world(Moves.KATANA)
	var dummy: TrainingBrain = TrainingBrain.new(W.fighters[0])
	dummy.set_behaviour(&"slam")
	assert_eq(W.fighters[0].abilities, Moves.KATANA.default_abilities, "the Katana has no slam to put on a slot")
	dummy.set_behaviour(&"sweep")
	dummy.set_behaviour(&"lights")
	assert_eq(W.fighters[0].abilities, Moves.KATANA.default_abilities, "leaving a drill puts the defaults back")
	dummy.dispose()


func test_the_random_dummy_drills_lights_heavies_and_every_unblockable_its_weapon_has() -> void:
	for weapon_id: StringName in UNBLOCKABLE_KINDS:
		var weapon: WeaponDef = Moves.WEAPONS[weapon_id]
		var run: DummyRun = _play(weapon, &"random", 1800)
		var swung: Array[StringName] = run.swung()
		assert_has(swung, weapon.light_start, "%s: lights" % weapon_id)
		var kinds: Array[StringName] = _kinds(run.by_dummy(&"telegraph"))
		var wanted: Array = UNBLOCKABLE_KINDS[weapon_id]
		assert_eq(kinds.size(), wanted.size(), "%s: as many unblockables as it has: %s" % [weapon_id, kinds])
		for k: StringName in wanted:
			assert_has(kinds, k, "%s: drills %s" % [weapon_id, k])
		# its heavies take the follow-up every other time, first time included,
		# as the heavies drill does (a heavy the run ends on is left out)
		var follow_up: StringName = weapon.moves[weapon.heavy_start].chain_heavy
		var took: Array[bool] = []
		for k: int in swung.size() - 1:
			if swung[k] == weapon.heavy_start:
				took.append(swung[k + 1] == follow_up)
		assert_gte(took.size(), 2, "%s: heavies" % weapon_id)
		for k: int in took.size():
			assert_eq(took[k], k % 2 == 0, "%s: heavy %d %s the follow-up" % [weapon_id, k, "takes" if k % 2 == 0 else "skips"])


## The spar behaviour, `fight` in the code.
func test_the_sparring_dummy_walks_in_attacks_and_defends_like_the_computer() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var dummy: TrainingBrain = TrainingBrain.new(W.fighters[0])
	dummy.set_behaviour(&"fight")
	var ai: AIBrain = AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"normal"], 3)
	var run: DummyRun = _run(W, dummy, 1800, func(_i: int) -> RawInput: return ai.think())
	dummy.dispose()
	ai.dispose()
	# it starts facing +z, and the computer's hits only push it back
	var advanced: float = run.path.map(func(p: Vector2) -> float: return p.y - run.start.y).max()
	assert_gt(advanced, 1.5, "it walks in from 6 m")
	assert_gte(run.by_dummy(&"swing").size(), 10, "it attacks")
	var defended: int = (
		run.all(&"block").filter(func(e: Dictionary) -> bool: return e["target"] == 0).size()
		+ run.all(&"parry").filter(func(e: Dictionary) -> bool: return e["parrier"] == 0).size()
		+ run.by_dummy(&"dodge").size()
	)
	assert_gte(defended, 3, "it blocks, parries or dodges the computer's attacks")
	assert_eq(W.fighters[0].abilities, Moves.KATANA.default_abilities, "it fights with its default abilities")


## counterlab.gd's experiment: the dummy repeats one unblockable for a minute
## against a hard brain that always tries the counter and does nothing else.
func test_a_brain_that_always_tries_the_counter_lands_each_one_within_a_minute() -> void:
	var params: AIBrain.AIParams = AIBrain.DIFFICULTY[&"hard"].copy()
	params.counter = 1.0
	params.parry = 0.0
	params.dodge = 0.0
	params.block = 0.0
	params.aggression = 0.0
	params.guard = 0.0
	for c: Array in COUNTERS:
		var drill: StringName = c[0]
		var counter: StringName = c[2]
		var W: World = H.track(World.new(FighterConfig.make(Moves.WEAPONS[c[1]]), FighterConfig.make(Moves.KATANA), 5))
		for f: Fighter in W.fighters:
			f.set_state(&"free")
		var dummy: TrainingBrain = TrainingBrain.new(W.fighters[0])
		dummy.set_behaviour(drill)
		var ai: AIBrain = AIBrain.new(W.fighters[1], params, 3)
		var run: DummyRun = _run(W, dummy, 60 * 60, func(_i: int) -> RawInput: return ai.think())
		dummy.dispose()
		ai.dispose()
		for e: Dictionary in run.all(&"counter"):
			assert_eq(e["by"], 1, "%s: the brain does the countering" % drill)
		assert_eq(_kinds(run.all(&"counter")), [counter], "%s is countered by %s, and only by it" % [drill, counter])
