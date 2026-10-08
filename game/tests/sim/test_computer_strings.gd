extends GutTest
## The computer plays the Katana's light string through (milestone-1 task
## 40): each follow-up press lands inside the input buffer before the move's
## branch point into it (the table's, task 20), so the re-keyed lights, whose
## startups are near 30 frames, chain as the old quick ones did, and a combo
## can run the whole four-hit string to Crown Cut (which the seeded duels of
## test_keyed_checklist.gd see it use; against a dummy it rarely gets there).

const H := preload("res://tests/sim/sim_helpers.gd")
## The string's first three hits, in either grip (it switches grips as it
## plays, KE task 8; each grip has its own hits since KE tasks 11-14).
const HITS: int = 3


func after_each() -> void:
	H.dispose_all()


## The moves a Hard computer (fighter 0, seeded) swings in `steps` steps at
## a dummy that only stands there, counted by id.
static func _swings(seed_value: int, steps: int) -> Dictionary[StringName, int]:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.5)
	W.fighters[1].hp = 1e9
	var ai: AIBrain = AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"hard"], seed_value)
	var out: Dictionary[StringName, int] = {}
	for i: int in steps:
		W.step([ai.think(), H.idle()])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"swing":
				var id := StringName(str(e["attack"]))
				out[id] = out.get(id, 0) + 1
	ai.dispose()
	return out


func test_a_hard_computer_plays_the_string_on_past_its_opener() -> void:
	var swings: Dictionary[StringName, int] = {}
	for seed_value: int in 3:
		var s: Dictionary[StringName, int] = _swings(70 + seed_value, 1800)
		for id: StringName in s:
			swings[id] = swings.get(id, 0) + s[id]
	var by_hit: Array[int] = [0, 0, 0, 0]
	for id: StringName in swings:
		var n: int = Moves.KATANA.string_position(id)
		if n >= 1 and n <= HITS:
			by_hit[n] += swings[id]
	for n: int in range(1, HITS + 1):
		assert_gt(by_hit[n], 0, "hit %d swung (%s)" % [n, swings])


func test_its_follow_ups_keep_up_with_its_openers() -> void:
	var swings: Dictionary[StringName, int] = _swings(71, 3600)
	# by hit, in either grip: it switches grips as it plays (KE task 8), and
	# the one-handed grip's hits 1 and 2 are its own since KE task 11
	var hits: Array[int] = [0, 0, 0]
	for id: StringName in swings:
		var n: int = Moves.KATANA.string_position(id)
		if n == 1 or n == 2:
			hits[n] += swings[id]
	assert_gt(hits[2], hits[1] / 4, "hit 2 follows often (%s)" % swings)
