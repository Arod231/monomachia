extends GutTest
## The computer's sprint attacks (milestone-1 task 75, the owner's answer of
## Oct 8: teach the computer where the per-move checklist's item 15 fails).
## The Katana's re-keyed sprint attacks keep none of the run's speed and close
## by their own travel until the bodies meet, and their bands have them touch
## from the duelling distance (3.3 m), so the computer sprints in for one
## from there, Leaping Cleave from 4.8 m out (or now and then from closer) and
## Running Draw otherwise; a weapon still on stand-ins sprints in from mid
## range and throws its light or heavy by chance, as before.


func test_the_katana_s_sprint_attacks_are_led_by_their_clips_and_the_stand_ins_aren_t() -> void:
	assert_true(AIBrain.sprint_led_by_clip(Moves.KATANA), "Running Draw, re-keyed")
	assert_false(AIBrain.sprint_led_by_clip(Moves.GREATSWORD), "the Greatsword's, stand-ins until milestone 2")
	assert_false(AIBrain.sprint_led_by_clip(Moves.DAGGERS), "the Daggers'")


func test_the_katana_sprints_in_from_the_duelling_distance() -> void:
	var duel: float = MoveBands.read().distance[&"katana"]["duel"]
	assert_lt(AIBrain.sprint_from(Moves.KATANA), duel, "from the duelling distance, which its sprint attacks touch from")
	assert_eq(AIBrain.sprint_from(Moves.GREATSWORD), 4.5, "a stand-in's from mid range, as before")


func test_the_katana_throws_leaping_cleave_from_far_out_and_running_draw_nearer() -> void:
	var w: WeaponDef = Moves.KATANA
	assert_true(AIBrain.sprint_light(w, 3.5, false, false), "Running Draw from the duelling distance")
	assert_true(AIBrain.sprint_light(w, 4.7, false, false), "and just inside 4.8 m")
	assert_false(AIBrain.sprint_light(w, 5.0, false, true), "Leaping Cleave from 4.8 m out, whatever the coin")
	assert_false(AIBrain.sprint_light(w, 3.5, true, false), "and now and then from closer")


func test_a_stand_in_weapon_throws_its_light_or_heavy_by_chance() -> void:
	assert_true(AIBrain.sprint_light(Moves.GREATSWORD, 6.0, false, true), "its light when the coin comes up")
	assert_false(AIBrain.sprint_light(Moves.GREATSWORD, 4.6, true, false), "its heavy otherwise, at any distance")
