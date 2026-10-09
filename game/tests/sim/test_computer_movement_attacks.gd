extends GutTest
## The computer's backstep, dodge and jump attacks with the Katana (milestone-1
## task 76, the owner's answer of Oct 8: teach the computer where the per-move
## checklist's item 15 fails). Re-keyed, the Katana's movement attacks are led
## by their clips, so an armed computer throws them as bare hands do (tasks 93
## and 94): it counters out of an evade with them, from about their own bands'
## touch, and now and then jumps in or backsteps out for them; a jump attack
## coming in through the air is answered from as near as its flight carries
## it, as its swing alone, played on the ground, can't say.

const H := preload("res://tests/sim/sim_helpers.gd")


func after_each() -> void:
	H.dispose_all()


func test_the_katana_s_movement_attacks_are_led_by_their_clips_and_the_stand_ins_aren_t() -> void:
	assert_true(AIBrain.movement_led_by_clip(Moves.KATANA), "Rising Cut, Lunging Cut, Aerial Cut and Falling Crown, re-keyed")
	assert_false(AIBrain.movement_led_by_clip(Moves.GREATSWORD), "the Greatsword's, stand-ins until milestone 2")
	assert_false(AIBrain.movement_led_by_clip(Moves.DAGGERS), "the Daggers'")


func test_the_katana_counters_from_about_its_bands_touch() -> void:
	var bands: MoveBands = MoveBands.read()
	assert_eq(AIBrain.LED_BACK_LIGHT_FROM, float(bands.distance_band(&"katana", &"backstep_light")["touches"]), "Rising Cut")
	assert_eq(AIBrain.LED_BACK_HEAVY_FROM, float(bands.distance_band(&"katana", &"backstep_heavy")["touches"]), "Lunging Cut")
	assert_lte(AIBrain.LED_DODGE_ATTACK_FROM, float(bands.distance_band(&"katana", &"dodge_light")["touches"]), "Wind Cut and Whirl Cut")
	assert_gt(AIBrain.LED_BACK_LIGHT_FROM, AIBrain.BACK_LIGHT_FROM, "further out than bare hands' Snap Kick")


## A Katana jumping in at the defender (stick forward, as the computer
## does) from `gap` m and pressing `b` on step 3; the defender idle. Returns
## [the step the attack starts, frames_to_touch() then, the step it hits (-1
## for none)].
func _jump_in(b: int, gap: float) -> Array:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, gap)
	var a: Fighter = W.fighters[0]
	var start: int = -1
	var told: int = -2
	var hit: int = -1
	for i: int in 50:
		var inp: RawInput = H.move(0.0, 1.0)
		if i == 0:
			inp = H.move(0.0, 1.0, Btn.JUMP)
		elif i == 3:
			inp = H.move(0.0, 1.0, b)
		W.step([inp, H.idle()])
		if start < 0 and a.state == &"attack":
			start = i
			told = AIBrain.frames_to_touch(a, W.fighters[1])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"hit" and hit < 0:
				hit = i
	return [start, told, hit]


func test_a_jump_attack_coming_in_through_the_air_is_answered() -> void:
	for c: Array in [[Btn.LIGHT, "Aerial Cut"], [Btn.HEAVY, "Falling Crown"]]:
		var r: Array = _jump_in(c[0], 3.4)
		assert_gt(r[2], 0, "%s, jumped in from 3.4 m, hits" % c[1])
		assert_gte(r[1], 0, "%s: the defender sees it will touch" % c[1])
		if r[1] >= 0 and r[2] > 0:
			assert_between(r[0] + r[1], r[2] - 4, r[2] + 1, "%s: about when it does (told step %d, hit step %d)" % [c[1], r[0] + r[1], r[2]])
