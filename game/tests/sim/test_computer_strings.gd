extends GutTest
## The computer plays the Katana's light string through (milestone-1 task
## 40): each follow-up press lands inside the input buffer before the move's
## branch point into it (the table's, task 20), so the re-keyed lights, whose
## startups are near 30 frames, chain as the old quick ones did, and a combo
## can run the whole four-hit string to Crown Cut (which the seeded duels of
## test_keyed_checklist.gd see it use; against a dummy it rarely gets there).

const H := preload("res://tests/sim/sim_helpers.gd")
const STRING: Array[StringName] = [&"k_l1", &"k_l2", &"k_l3"]


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
	for id: StringName in STRING:
		assert_gt(swings.get(id, 0), 0, "%s swung (%s)" % [id, swings])


func test_its_follow_ups_keep_up_with_its_openers() -> void:
	var swings: Dictionary[StringName, int] = _swings(71, 3600)
	assert_gt(swings.get(&"k_l2", 0), swings.get(&"k_l1", 0) / 4, "Return Cut follows often (%s)" % swings)
