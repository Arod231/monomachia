extends GutTest
## The computer plays both grips (KE task 9, D8, stories 39 and 40). It picks
## its grip by the situation, posture first (the owner's word, Oct 7): low on
## posture (over the brain's recovery line) one-handed; else an opponent
## guarding a lot or inside two-handed reach two-handed; at range one-handed;
## otherwise it keeps its grip. Easy stays one-handed, Normal switches by
## situation, and Hard also switches mid-string, mixing the two strings. A
## string's heavy ending is the held grip's heavy, which Normal and Hard
## sometimes charge.

const H := preload("res://tests/sim/sim_helpers.gd")

const ONE: StringName = WeaponGrip.ONE_HANDED
const TWO: StringName = WeaponGrip.TWO_HANDED
## The brain's posture recovery line, which the grip choice reads too.
const LOW_POSTURE: float = 62.0
const SEEDS: int = 8


func after_each() -> void:
	H.dispose_all()


## Inside two-handed reach: the two-handed string's first hit's, from centre
## to centre.
static func _two_handed_reach() -> float:
	var w: WeaponDef = Moves.KATANA
	return (w.moves[w.grip(TWO).hit(1)] as AttackDef).reach() + SimConst.FIGHTER_RADIUS


## Fighter 1 of a Katana world, free, `gap` m from fighter 0, holding `grip`.
static func _fighter(gap: float, grip: StringName, posture: float = 0.0) -> Fighter:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, gap)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	var me: Fighter = W.fighters[1]
	me.grip = grip
	me.posture = posture
	return me


# ------------------------------------------------------------------ the choice

func test_low_on_posture_goes_one_handed_before_anything_else() -> void:
	var me: Fighter = _fighter(1.0, TWO, LOW_POSTURE + 1.0)
	assert_eq(AIBrain.wanted_grip(me, 1.0, true), ONE, "close and against a guard, yet low on posture: one-handed")
	me.posture = LOW_POSTURE
	assert_eq(AIBrain.wanted_grip(me, 1.0, false), TWO, "at the line itself the posture isn't low")


func test_an_opponent_guarding_a_lot_or_close_brings_two_hands() -> void:
	var me: Fighter = _fighter(1.0, ONE)
	var close: float = _two_handed_reach() - 0.05
	assert_eq(AIBrain.wanted_grip(me, close, false), TWO, "inside two-handed reach")
	var between: float = _two_handed_reach() + 0.45
	assert_eq(AIBrain.wanted_grip(me, between, true), TWO, "against a guard, just outside reach")
	assert_eq(AIBrain.wanted_grip(me, 6.0, true), TWO, "against a guard, even at range")


func test_at_range_it_goes_one_handed_and_in_between_it_keeps_its_grip() -> void:
	var me: Fighter = _fighter(1.0, TWO)
	assert_eq(AIBrain.wanted_grip(me, 6.0, false), ONE, "at range")
	assert_eq(AIBrain.wanted_grip(me, _two_handed_reach() + 0.45, false), &"", "just outside reach: keep")


func test_bare_hands_and_a_weapon_without_grips_choose_nothing() -> void:
	var me: Fighter = _fighter(1.0, ONE, LOW_POSTURE + 10.0)
	me.armed = false
	assert_eq(AIBrain.wanted_grip(me, 6.0, false), &"", "bare hands")
	var W: World = H.make_world(Moves.GREATSWORD, Moves.GREATSWORD, 1.0)
	assert_eq(AIBrain.wanted_grip(W.fighters[1], 6.0, true), &"", "the Greatsword has no grips")


func test_the_follow_up_it_presses_for_is_the_rules_one_the_grip_s_heavy_included() -> void:
	var me: Fighter = _fighter(2.0, TWO)
	var crown: StringName = Moves.KATANA.grip(TWO).hit(4)
	me.start_attack(crown, -1, null, 4)
	assert_eq(me.follow_up(true)[0], &"k_h2", "after the two-handed hit 4, Heaven Splitter")
	assert_eq(me.follow_up(false)[0], Moves.KATANA.grip(TWO).hit(5), "and the light: hit 5")
	assert_false((me.follow_up(true)[1] as PackedInt32Array).is_empty(), "with its window")
	me.grip = ONE
	assert_eq(me.follow_up(true)[0], &"k_coil", "one-handed, Crescent Coil")
	me.start_attack(Moves.KATANA.grip(ONE).hit(5), -1, null, 5)
	assert_eq(me.follow_up(false)[0], &"", "no light after the last hit")
	me.set_state(&"free")
	assert_eq(me.follow_up(false)[0], &"", "nothing outside an attack")


# ------------------------------------------------------------------ in play

## A computer at `difficulty` (fighter 1, seeded) against fighter 0, who
## holds block when `guarding`, for `frames` steps. Returns
## [the grips it switched to, its string hits as [hit, grip] in the order
## they started, the grip heavies it charged].
static func _play(difficulty: StringName, seed_value: int, gap: float, guarding: bool = false,
		frames: int = 900, first_grip: StringName = ONE, weapon: WeaponDef = Moves.KATANA) -> Array:
	var W: World = H.make_world(weapon, weapon, gap)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	var me: Fighter = W.fighters[1]
	if weapon.grips.size() > 0:
		me.grip = first_grip
	var ai: AIBrain = AIBrain.new(me, AIBrain.DIFFICULTY[difficulty], seed_value)
	var switched: Array[StringName] = []
	var hits: Array = []
	var charged: Array[StringName] = []
	var last_atk: AttackState = null
	var counted: AttackState = null
	for _i: int in frames:
		W.fighters[0].hp = 100.0
		W.fighters[0].posture = 0.0
		me.posture = minf(me.posture, 40.0)
		var opp_in: RawInput = H.move(0.0, 0.0, Btn.BLOCK) if guarding else H.idle()
		W.step([opp_in, ai.think()])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"grip" and e["f"] == 1:
				switched.append(e["grip"])
		if me.state == &"attack" and me.atk != null and me.atk != last_atk:
			last_atk = me.atk
			if me.string_count > 0:
				hits.append([me.string_count, me.grip])
		if me.state == &"attack" and me.atk != null and me.atk.charging and me.atk != counted:
			counted = me.atk
			charged.append(me.atk.def.id)
		if W.fighters[0].state == &"ko":
			W.fighters[0].set_state(&"free")
	ai.dispose()
	return [switched, hits, charged]


## Strings whose next hit came from the other grip: hit n in one grip, then
## hit n + 1 in the other.
static func _mixed(hits: Array) -> int:
	var n: int = 0
	for i: int in range(1, hits.size()):
		if hits[i][0] == hits[i - 1][0] + 1 and hits[i][1] != hits[i - 1][1]:
			n += 1
	return n


func test_easy_stays_one_handed() -> void:
	for seed_value: int in SEEDS:
		for gap: float in [1.6, 6.0]:
			var run: Array = _play(&"easy", seed_value + 1, gap, true)
			assert_eq(run[0], [] as Array[StringName], "seed %d from %.1f m: no switch" % [seed_value + 1, gap])


func test_normal_goes_two_handed_up_close_and_one_handed_at_range() -> void:
	var close: Array = _play(&"normal", 5, 1.6, false, 30, ONE)
	assert_eq(close[0].slice(0, 1), [TWO] as Array[StringName], "close: two hands within half a second")
	var far: Array = _play(&"normal", 5, 7.0, false, 30, TWO)
	assert_eq(far[0].slice(0, 1), [ONE] as Array[StringName], "at range: one hand within half a second")


func test_normal_never_mixes_a_string_and_hard_does() -> void:
	var normal: int = 0
	var hard: int = 0
	var strings: int = 0
	for seed_value: int in SEEDS:
		var n: Array = _play(&"normal", 100 + seed_value, 1.8)
		normal += _mixed(n[1])
		var h: Array = _play(&"hard", 100 + seed_value, 1.8)
		hard += _mixed(h[1])
		strings += h[1].filter(func(x: Array) -> bool: return x[0] >= 2).size()
	gut.p("hard: %d mixed hand-offs in %d follow-up hits" % [hard, strings])
	assert_eq(normal, 0, "Normal switches only outside a string")
	assert_gt(hard, 0, "Hard mixes the strings")


func test_normal_and_hard_charge_grip_heavies_off_the_branches_and_easy_never() -> void:
	var grip_heavies: Array[StringName] = [&"k_coil", &"k_h2"]
	var charged: Dictionary[StringName, int] = {&"easy": 0, &"normal": 0, &"hard": 0}
	for difficulty: StringName in charged:
		# twice the seeds, and longer runs: the Iai's long tail (KE task 18)
		# leaves fewer string heavies in a run
		for seed_value: int in SEEDS * 2:
			var run: Array = _play(difficulty, 200 + seed_value, 1.8, true, 2700)
			for id: StringName in run[2]:
				if grip_heavies.has(id):
					charged[difficulty] += 1
	gut.p("charged grip heavies: %s" % [charged])
	assert_eq(charged[&"easy"], 0, "Easy taps them")
	assert_gt(charged[&"normal"], 0, "Normal charges some")
	assert_gt(charged[&"hard"], 0, "Hard charges some")


func test_a_weapon_without_grips_never_presses_the_grip() -> void:
	for seed_value: int in 4:
		var run: Array = _play(&"hard", seed_value + 1, 2.0, true, 600, ONE, Moves.GREATSWORD)
		assert_eq(run[0], [] as Array[StringName], "seed %d" % [seed_value + 1])


func test_the_same_seed_switches_the_same_way() -> void:
	var a: Array = _play(&"hard", 9, 1.8)
	var b: Array = _play(&"hard", 9, 1.8)
	assert_eq(a, b)
