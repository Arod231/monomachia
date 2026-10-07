extends GutTest
## The recalled weapon's flight (RecallFlight, milestone-1 task 99): stuck
## through the roar, torn out of the ground, then arcing spinning to the
## open hand, arriving on the rules' burst frame.

const FROM: Vector3 = Vector3(2.0, 0.0, 1.0)
const HAND: Vector3 = Vector3(-0.3, 1.1, 0.2)


func test_it_stays_stuck_through_the_roar() -> void:
	for t: float in [0.0, 2.0, RecallFlight.TEAR_FROM]:
		var a: Dictionary = RecallFlight.at(FROM, HAND, t)
		assert_eq(a["pos"], FROM, "frame %s: where it stuck" % t)
		assert_eq(a["out"], 0.0, "frame %s: still in the ground" % t)
		assert_eq(a["spin"], 0.0)


func test_it_tears_out_lifting_clear() -> void:
	var a: Dictionary = RecallFlight.at(FROM, HAND, RecallFlight.TEAR_END)
	assert_eq(a["out"], 1.0, "out of the ground")
	assert_almost_eq((a["pos"] as Vector3).y, FROM.y + RecallFlight.RISE, 1e-6, "lifted")
	assert_eq(a["spin"], 0.0, "not yet spinning")


func test_it_arcs_spinning_to_the_hand_arriving_on_the_burst_frame() -> void:
	var arrive: float = float(SimConst.RECALL_BURST_FRAME)
	var a: Dictionary = RecallFlight.at(FROM, HAND, arrive)
	assert_almost_eq((a["pos"] as Vector3).distance_to(HAND), 0.0, 1e-6, "in the hand on frame 16")
	assert_almost_eq(float(a["spin"]), TAU * RecallFlight.SPINS, 1e-6, "turned end over end")
	var last: float = INF
	var highest: float = -INF
	for i: int in range(int(RecallFlight.TEAR_END) + 1, int(arrive) + 1):
		var at: Vector3 = RecallFlight.at(FROM, HAND, float(i))["pos"]
		var left: float = Vector2(at.x - HAND.x, at.z - HAND.z).length()
		assert_lt(left, last, "frame %d: closing on the hand" % i)
		last = left
		highest = maxf(highest, at.y)
	var straight: float = maxf(FROM.y + RecallFlight.RISE, HAND.y)
	assert_gt(highest, straight, "an arc over the straight line")
