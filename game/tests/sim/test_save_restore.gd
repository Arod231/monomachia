extends GutTest
## Snapshot and restore (milestone-1 task 134, story 24): the rules saved
## mid-match, restored and stepped again give the same hash as the original
## on every step, at several points of a seeded match, through a disarm (its
## weapon flying and stuck, milestone-1 task 86) and a K.O. The inputs are the ones the match was played with (recorded from the
## computer's brains), so this tests the rules alone; task 6 adds the brains.

## Twelve minutes of rules time, as the soak allows.
const MATCH_LIMIT: int = 60 * 60 * 12
## How many steps past a save point the restored match is compared.
const AFTER: int = 600


## A seeded Hunter-against-Hunter Katana match, played by two Hard brains,
## with each step's inputs and the hash after it.
class Run:
	var world: World
	var sim_match: Match
	## per step: [RawInput, RawInput]
	var inputs: Array[Array] = []
	## after each step (index 0 is after step 1)
	var hashes: Array[String] = []
	## the step count when a snapshot was taken -> [world's, match's]
	var saved: Dictionary[int, Array] = {}
	var first_disarm: int = -1
	var first_ko: int = -1
	## the match's winner as it ended
	var winner: int = -1


static func _world(seed_value: int) -> World:
	return World.new(
		FighterConfig.make(Moves.KATANA, [], "", &"hunter"), FighterConfig.make(Moves.KATANA, [], "", &"hunter"), seed_value
	)


static func _hash(w: World, m: Match) -> String:
	return SimState.state_hash([w.snapshot(), m.snapshot()])


## Plays a match from `seed_value`, saving the rules before the steps named in
## `save_at` (a step count: 0 is before the first step), hashing each step
## unless `hashes` is off.
static func _play(seed_value: int, save_at: Array[int] = [], hashes: bool = true) -> Run:
	var r: Run = Run.new()
	r.world = _world(seed_value)
	r.sim_match = Match.new(r.world)
	var brains: Array[AIBrain] = [
		AIBrain.new(r.world.fighters[0], AIBrain.DIFFICULTY[&"hard"], seed_value + 1),
		AIBrain.new(r.world.fighters[1], AIBrain.DIFFICULTY[&"hard"], seed_value + 2),
	]
	var steps: int = 0
	while r.sim_match.phase != &"matchEnd" and steps < MATCH_LIMIT:
		if save_at.has(steps):
			r.saved[steps] = [r.world.snapshot(), r.sim_match.snapshot()]
		var inputs: Array[RawInput] = [brains[0].think(), brains[1].think()]
		r.inputs.append(inputs)
		r.sim_match.step(inputs)
		steps += 1
		for e: Dictionary in r.world.drain_events():
			if e["t"] == &"disarm" and r.first_disarm < 0:
				r.first_disarm = steps
			elif e["t"] == &"ko" and r.first_ko < 0:
				r.first_ko = steps
		if hashes:
			r.hashes.append(_hash(r.world, r.sim_match))
	r.winner = r.sim_match.match_winner
	for b: AIBrain in brains:
		b.dispose()
	return r


## Restores `r`'s snapshot from step `at` into world `w` and match `m`, steps
## on with the recorded inputs, and returns the first step whose hash differs
## from the original's, or -1. Compares every `every`th step, and the last.
static func _replay_from(r: Run, at: int, w: World, m: Match, steps: int, every: int = 1) -> int:
	w.restore(r.saved[at][0])
	m.restore(r.saved[at][1])
	var last: int = mini(at + steps, r.inputs.size())
	for i: int in range(at, last):
		var inputs: Array[RawInput] = []
		inputs.assign(r.inputs[i])
		m.step(inputs)
		w.drain_events()
		if ((i + 1) % every == 0 or i == last - 1) and _hash(w, m) != r.hashes[i]:
			return i + 1
	return -1


var _run: Run


func before_all() -> void:
	var probe: Run = _play(21, [], false)
	assert_gt(probe.first_disarm, 0, "the seed's match has a disarm")
	assert_gt(probe.first_ko, 0, "and a K.O.")
	# the disarm's step, its weapon in flight past the hit-stop, and stuck
	# (milestone-1 task 86)
	var points: Array[int] = [
		0, 300, probe.first_disarm, probe.first_disarm + 20, probe.first_disarm + 80,
		probe.first_ko, probe.first_ko + Match.ROUND_END_FRAMES / 2,
	]
	_run = _play(21, points)
	assert_eq(_run.inputs.size(), probe.inputs.size(), "saving changes nothing")


func test_a_restored_world_hashes_as_the_saved_one() -> void:
	for at: int in _run.saved:
		var w: World = _world(999)
		var m: Match = Match.new(w)
		w.restore(_run.saved[at][0])
		m.restore(_run.saved[at][1])
		assert_eq(SimState.state_hash([w.snapshot(), m.snapshot()]), SimState.state_hash(_run.saved[at]), "step %d" % at)


func test_a_restored_match_steps_on_as_the_original_at_each_save_point() -> void:
	for at: int in _run.saved:
		# rolled back in the very world that played on past it
		assert_eq(_replay_from(_run, at, _run.world, _run.sim_match, AFTER), -1, "from step %d, in its own world" % at)
		# and into a world built afresh from another seed
		var w: World = _world(999)
		var m: Match = Match.new(w)
		assert_eq(_replay_from(_run, at, w, m, AFTER), -1, "from step %d, in a fresh world" % at)


func test_a_match_restored_before_the_first_step_plays_to_the_same_end() -> void:
	var w: World = _world(5)
	var m: Match = Match.new(w)
	assert_eq(_replay_from(_run, 0, w, m, MATCH_LIMIT, 60), -1)
	assert_eq(m.phase, &"matchEnd")
	assert_eq(m.match_winner, _run.winner)


func test_a_snapshot_shares_nothing_with_the_live_rules() -> void:
	var r: Run = _play(21, [400] as Array[int])
	var saved: Array = r.saved[400]
	var h: String = SimState.state_hash(saved)
	# the match played on past the snapshot: it is as it was
	assert_eq(SimState.state_hash(saved), h)
	r.world.restore(saved[0])
	r.sim_match.restore(saved[1])
	r.world.fighters[0].pos.x += 1.0
	r.world.fighters[0].input.held = 0xFF
	assert_eq(SimState.state_hash(saved), h, "changing the restored rules leaves the snapshot alone")
	r.world.restore(saved[0])
	r.sim_match.restore(saved[1])
	assert_eq(SimState.state_hash([r.world.snapshot(), r.sim_match.snapshot()]), h, "and it restores again")
