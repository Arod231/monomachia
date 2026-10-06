extends GutTest
## Counterlab run short (milestone-1 task 83): the Training dummy repeats
## each milestone-1 unblockable through its route against a hard brain that
## always tries the counter, and the brain lands that counter, and only it.
## `npm run counterlab` runs the same cases for a minute each and prints the
## full table.

const H := preload("res://tests/sim/sim_helpers.gd")


func after_each() -> void:
	H.dispose_all()


func test_counterlab_runs_the_stomp_against_the_thrust_and_the_leap_against_the_sweep() -> void:
	var cases: Array = []
	for c: Array in Counterlab.CASES:
		cases.append([c[0], c[1], c[2]])
	assert_eq(cases, [[&"thrust", &"katana", &"stomp"], [&"sweep", &"katana", &"leap"]], "the Katana's two unblockables; the evade waits for milestone 2")


func test_the_countering_brain_lands_each_counter_and_only_it_within_half_a_minute() -> void:
	for c: Array in Counterlab.CASES:
		var tally: Dictionary[String, int] = Counterlab.run(c[0], c[1], 30 * 60)
		var label: String = "%s with the %s" % [c[0], c[1]]
		assert_gte(tally.get("attempts", 0), 3, label + ": the dummy tries it")
		assert_gte(tally.get("counter:" + String(c[2]), 0), 1, label + ": countered by %s at least once (%s)" % [c[2], tally])
		for k: String in tally:
			if k.begins_with("counter:"):
				assert_eq(k, "counter:" + String(c[2]), label + ": no other counter")
