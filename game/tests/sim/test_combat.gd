extends GutTest
## Port of tests/combat.test.ts. Same tests, same assertions; toBeCloseTo(x) is
## assert_almost_eq(.., x, CLOSE) and toBeCloseTo(x, 0) uses 0.5.

const H := preload("res://tests/sim/sim_helpers.gd")
## toBeCloseTo's default precision (2 digits)
const CLOSE: float = 0.005

## helpers.ts idle as an input function: run() treats a null Callable as idle
var IDLE: Callable = Callable()


func after_each() -> void:
	H.dispose_all()


# A katana light (startup 11) started on step 0 becomes active on world frame 13.

# ------------------------------------------------------------------ attacks

func test_a_light_attack_hits_an_idle_opponent_for_its_hp_and_posture_damage() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(W, 30, H.tap_at(0, Btn.LIGHT), IDLE, r)
	var b: Fighter = W.fighters[1]
	assert_true(r.has(&"hit"))
	assert_almost_eq(b.hp, 94.0, CLOSE)
	assert_almost_eq(b.posture, 7.0 * SimConst.HIT_POSTURE_MULT, CLOSE)


func test_misses_when_the_opponent_is_out_of_range() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var r: H.Rec = H.Rec.new()
	H.run(W, 40, H.tap_at(0, Btn.LIGHT), IDLE, r)
	assert_false(r.has(&"hit"))
	assert_true(r.has(&"whiff"))
	assert_eq(W.fighters[1].hp, 100.0)


func test_light_attacks_chain_into_a_combo_string() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	# press light repeatedly
	H.run(W, 90, func(i: int) -> RawInput: return H.btn(Btn.LIGHT) if i % 8 == 0 else H.idle(), IDLE, r)
	var hits: Array = r.all(&"hit").map(func(e: Dictionary) -> Variant: return e["attack"])
	assert_eq(hits.slice(0, 3), [&"k_l1", &"k_l2", &"k_l3"])


func test_a_heavy_held_for_2_5_s_releases_by_itself_as_a_stronger_power_attack() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(W, 220, func(_i: int) -> RawInput: return H.btn(Btn.HEAVY), IDLE, r)
	var hit: Dictionary = r.find(&"hit")
	assert_false(hit.is_empty())
	assert_eq(hit.get("attack"), &"k_iai") # the Iai Slash since 9.2 (the demo's Kesa Giri, also 13 damage)
	assert_almost_eq(float(hit.get("damage", NAN)), 13.0 * 1.8, CLOSE)


# ------------------------------------------------------------------ blocking and parrying

func test_blocking_stops_hp_damage_but_takes_reduced_posture_damage() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(W, 30, H.tap_at(0, Btn.LIGHT), func(_i: int) -> RawInput: return H.btn(Btn.BLOCK), r)
	var b: Fighter = W.fighters[1]
	assert_true(r.has(&"block"))
	assert_eq(b.hp, 100.0)
	assert_almost_eq(b.posture, 7.0 * Moves.KATANA.block_mitigation, CLOSE)


func test_a_well_timed_block_press_parries_attacker_recoils_and_takes_parry_posture() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	# impact on frame 13; press on step 8 -> frame 9 (4 frames early, inside the 9-frame window)
	H.run(W, 20, H.tap_at(0, Btn.LIGHT), H.tap_at(8, Btn.BLOCK), r)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var p: Dictionary = r.find(&"parry")
	assert_false(p.is_empty())
	assert_eq(p.get("kind"), &"parry")
	assert_eq(p.get("timing"), 4)
	assert_eq(b.hp, 100.0)
	assert_almost_eq(a.posture, SimConst.PARRY_POSTURE, CLOSE)
	assert_eq(a.state, &"recoil")


func test_pressing_block_too_early_only_blocks() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(W, 30, H.tap_at(0, Btn.LIGHT), func(i: int) -> RawInput: return H.btn(Btn.BLOCK) if i >= 1 else H.idle(), r)
	assert_false(r.has(&"parry"))
	assert_true(r.has(&"block"))


func test_mashing_block_shrinks_the_parry_window() -> void:
	var W: World = H.make_world()
	var b: Fighter = W.fighters[1]
	# three presses 4 frames apart
	H.run(W, 12, IDLE, func(i: int) -> RawInput: return H.btn(Btn.BLOCK) if i % 4 == 0 else H.idle())
	assert_eq(b.parry_window_at_press, Moves.KATANA.parry_window - 2 * 3)


func test_the_greatsword_has_a_larger_parry_window_than_the_daggers() -> void:
	assert_gt(Moves.GREATSWORD.parry_window, Moves.KATANA.parry_window)
	assert_gt(Moves.KATANA.parry_window, Moves.DAGGERS.parry_window)


func test_you_cannot_block_an_attack_coming_from_behind() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var b: Fighter = W.fighters[1]
	H.run(W, 1)
	b.yaw = 0.0 # turn away from the attacker
	b.blind_until = 1000000000
	H.run(W, 30, H.tap_at(0, Btn.LIGHT), func(_i: int) -> RawInput: return H.btn(Btn.BLOCK), r)
	assert_true(r.has(&"hit"))


# ------------------------------------------------------------------ posture and disarm

func test_a_parried_attacker_with_a_full_posture_meter_is_disarmed_and_loses_no_hp() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var a: Fighter = W.fighters[0]
	a.posture = SimConst.POSTURE_MAX
	H.run(W, 30, H.tap_at(0, Btn.LIGHT), H.tap_at(8, Btn.BLOCK), r)
	assert_true(r.has(&"disarm"))
	assert_false(a.armed)
	assert_eq(a.hp, 100.0)
	assert_eq(a.posture, 0.0)
	assert_not_null(W.weapon_of(0))


func test_blocking_an_unblockable_takes_the_full_hit() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	# katana heavy ability = Piercing Thrust
	H.run(
		W,
		45,
		func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(),
		func(_i: int) -> RawInput: return H.btn(Btn.BLOCK),
		r,
	)
	assert_true(r.has(&"telegraph"))
	assert_true(r.has(&"hit"))
	assert_almost_eq(W.fighters[1].hp, 88.0, CLOSE)


func test_blocking_an_unblockable_with_a_full_meter_disarms_the_blocker() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var keep_full: Callable = func(_i: int) -> RawInput:
		# recent pressure: the meter is full and has not had time to drain
		W.fighters[1].posture = SimConst.POSTURE_MAX
		W.fighters[1].last_posture_damage = W.frame
		return H.btn(Btn.BLOCK)
	H.run(W, 45, func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(), keep_full, r)
	assert_true(r.has(&"disarm"))
	assert_false(W.fighters[1].armed)
	assert_eq(W.fighters[1].hp, 100.0)


func test_blocking_a_full_charge_power_attack_with_a_full_meter_disarms() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	W.fighters[1].posture = SimConst.POSTURE_MAX
	# attacker holds heavy for the whole charge; defender holds block but must not drain posture:
	# keep hitting posture to full each frame to simulate pressure
	var pressure: Callable = func(_i: int) -> RawInput:
		W.fighters[1].posture = SimConst.POSTURE_MAX
		W.fighters[1].last_posture_damage = W.frame
		return H.btn(Btn.BLOCK)
	H.run(W, 220, func(_i: int) -> RawInput: return H.btn(Btn.HEAVY), pressure, r)
	assert_true(r.has(&"disarm"))


## The drain closure in the next test: posture drained in 60 frames of holding block.
func _drain(hp: float, moving: bool) -> float:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 5.0)
	var b: Fighter = W.fighters[1]
	b.posture = 60.0
	b.hp = hp
	H.run(
		W,
		60,
		IDLE,
		func(_i: int) -> RawInput: return H.move(1.0, 0.0, Btn.BLOCK) if moving else H.btn(Btn.BLOCK),
	)
	return 60.0 - b.posture


func test_holding_block_while_standing_drains_posture_faster_than_while_moving_and_slower_at_low_hp() -> void:
	var stand_full: float = _drain(100.0, false)
	var move_full: float = _drain(100.0, true)
	var stand_low: float = _drain(30.0, false)
	assert_gt(stand_full, move_full)
	assert_gt(stand_full, stand_low)
	assert_almost_eq(stand_full, SimConst.POSTURE_RECOVER_STAND, 0.5)


func test_posture_does_not_drain_while_not_blocking() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 5.0)
	var b: Fighter = W.fighters[1]
	b.posture = 60.0
	H.run(W, 120)
	assert_eq(b.posture, 60.0)


# ------------------------------------------------------------------ dodging and the unblockable counters

func test_dodge_invincibility_lets_a_normal_attack_pass_through() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(
		W,
		30,
		H.tap_at(0, Btn.LIGHT),
		func(i: int) -> RawInput: return H.move(0.0, 1.0, Btn.DODGE) if i == 7 else H.idle(),
		r,
	)
	assert_true(r.has(&"evade"))
	assert_eq(W.fighters[1].hp, 100.0)


func test_dodge_invincibility_does_not_work_against_unblockables() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 1.6)
	var r: H.Rec = H.Rec.new()
	H.run(
		W,
		45,
		func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.LIGHT) if i == 0 else H.idle(),
		func(i: int) -> RawInput: return H.move(1.0, 0.0, Btn.DODGE) if i == 24 else H.idle(),
		r,
	)
	assert_true(r.has(&"hit"))


func test_dodging_into_a_thrust_triggers_the_stomp_counter() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(
		W,
		45,
		func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(),
		func(i: int) -> RawInput: return H.move(0.0, 1.0, Btn.DODGE) if i == 20 else H.idle(),
		r,
	)
	var c: Dictionary = r.find(&"counter")
	assert_false(c.is_empty())
	assert_eq(c.get("kind"), &"stomp")
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	assert_eq(b.hp, 100.0)
	assert_gte(a.posture, 30.0)


func test_jumping_over_a_sweep_triggers_the_leap_counter() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 2.2)
	var r: H.Rec = H.Rec.new()
	H.run(
		W,
		50,
		func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.LIGHT) if i == 0 else H.idle(),
		func(i: int) -> RawInput: return H.btn(Btn.JUMP) if i == 20 else H.idle(),
		r,
	)
	var c: Dictionary = r.find(&"counter")
	assert_false(c.is_empty())
	assert_eq(c.get("kind"), &"leap")
	assert_eq(W.fighters[1].hp, 100.0)
	assert_gte(W.fighters[0].posture, 30.0)


func test_back_dashing_an_overhead_slam_triggers_the_evade_counter_and_a_counter_lunge() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 2.4)
	var r: H.Rec = H.Rec.new()
	H.run(
		W,
		40,
		func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(),
		func(i: int) -> RawInput: return H.btn(Btn.DODGE) if i == 28 else H.idle(),
		r,
	)
	var c: Dictionary = r.find(&"counter")
	assert_false(c.is_empty())
	assert_eq(c.get("kind"), &"evade")
	assert_eq(W.fighters[1].hp, 100.0)
	# follow up with light: the special lunge
	var r2: H.Rec = H.Rec.new()
	H.run(W, 40, IDLE, func(i: int) -> RawInput: return H.btn(Btn.LIGHT) if i == 2 else H.idle(), r2)
	var hit: Dictionary = r2.find(&"hit")
	assert_eq(hit.get("attack"), &"k_lunge")


# ------------------------------------------------------------------ disarmed mode

func test_a_disarmed_fighter_cannot_block() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	W.fighters[1].armed = false
	H.run(W, 30, H.tap_at(0, Btn.LIGHT), func(_i: int) -> RawInput: return H.btn(Btn.BLOCK), r)
	assert_true(r.has(&"hit"))
	assert_almost_eq(W.fighters[1].hp, 94.0, CLOSE)


func test_a_timed_block_press_while_disarmed_is_a_redirect_counter() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	b.armed = false
	H.run(W, 20, H.tap_at(0, Btn.LIGHT), H.tap_at(8, Btn.BLOCK), r)
	var p: Dictionary = r.find(&"parry")
	assert_eq(p.get("kind"), &"redirect")
	assert_eq(a.state, &"stunned")
	assert_almost_eq(a.posture, 35.0, CLOSE)


func test_a_redirect_against_a_full_posture_attacker_disarms_them() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	b.armed = false
	a.posture = SimConst.POSTURE_MAX
	H.run(W, 20, H.tap_at(0, Btn.LIGHT), H.tap_at(8, Btn.BLOCK), r)
	assert_false(a.armed)


func test_a_disarmed_fighter_can_pick_their_weapon_back_up() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 4.0)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	a.posture = 100.0
	a.disarm(b, &"parried")
	H.run(W, 120) # weapon lands, stagger ends
	var w: DroppedWeapon = W.weapon_of(0)
	assert_true(w.grounded)
	a.pos = V3.make(w.pos.x, 0.0, w.pos.z)
	H.run(W, 30, H.tap_at(0, Btn.INTERACT))
	assert_true(a.armed)
	assert_null(W.weapon_of(0))


func test_disarmed_fighters_move_faster_and_dodge_farther() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var a: Fighter = W.fighters[0]
	var start: float = a.pos.x
	H.run(W, 30, func(i: int) -> RawInput: return H.move(1.0, 0.0, Btn.DODGE) if i == 0 else H.idle())
	var armed_dist: float = absf(a.pos.x - start)
	var W2: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var a2: Fighter = W2.fighters[0]
	a2.armed = false
	var s2: float = a2.pos.x
	H.run(W2, 30, func(i: int) -> RawInput: return H.move(1.0, 0.0, Btn.DODGE) if i == 0 else H.idle())
	var dis_dist: float = absf(a2.pos.x - s2)
	assert_gt(dis_dist, armed_dist * 1.3)


## Fighter 0 thrusts `move` (its weapon `w`); fighter 1 dodges into it after
## `lead` frames. Returns [world, gap when the stomp began, frames run].
func _stomped(w: WeaponDef, move: StringName, lead: int, gap: float = 2.2) -> Array:
	var abilities: Array = [&"k_flash", &"k_thrust"] if w == Moves.KATANA else ([&"d_needle"] if w == Moves.DAGGERS else [])
	var W: World = H.make_world(w, Moves.KATANA, gap, {"a": abilities})
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	W.step([H.idle(), H.idle()])
	assert_true(a.start_attack(move), "%s starts" % move)
	var began: float = -1.0
	for i: int in 90:
		W.step([H.idle(), H.move(0.0, 1.0, Btn.DODGE) if i == lead else H.idle()])
		if b.state == &"stomp" and began < 0.0:
			began = SimMath.dist2(a.pos, b.pos)
		if began >= 0.0 and b.state == &"stomp" and b.sf >= 12:
			break
	return [W, began]


func test_a_stomp_lands_on_the_blades_tip_at_the_thrusters_pin_distance() -> void:
	# the defender dodges in this many frames before the thrust's startup
	# ends (its frames the table's, milestone-1 task 17)
	var cases: Array = [[Moves.KATANA, &"k_thrust", 6], [Moves.DAGGERS, &"d_needle", 8], [Moves.GREATSWORD, &"g_dh", 8]]
	for c: Array in cases:
		var w: WeaponDef = c[0]
		var r: Array = _stomped(w, c[1], (w.moves[c[1]] as AttackDef).startup - int(c[2]))
		var W: World = r[0]
		var a: Fighter = W.fighters[0]
		var b: Fighter = W.fighters[1]
		assert_gt(float(r[1]), 0.0, "%s: the dodge into the thrust stomps it" % c[1])
		assert_eq(a.state, &"stunned")
		assert_eq(a.stun_cause, &"stomp", "the thruster's stun is the stomp's")
		var pin: float = SimConst.STOMP_PIN_DIST[w.id]
		assert_almost_eq(SimMath.dist2(a.pos, b.pos), pin, 0.05, "%s: the fighters %.2f m apart, the foot on the blade's tip" % [w.id, pin])


func test_a_thruster_stomped_up_close_is_jolted_back() -> void:
	# dodging in early: the defender runs into the thruster before the thrust lands
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.2, {"a": [&"k_flash", &"k_thrust"]})
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	W.step([H.idle(), H.idle()])
	a.start_attack(&"k_thrust")
	var at: Vector2 = Vector2.ZERO
	var b_at: Vector2 = Vector2.ZERO
	for i: int in 90:
		W.step([H.idle(), H.move(0.0, 1.0, Btn.DODGE) if i == 12 else H.idle()])
		if b.state == &"stomp" and b.sf <= 1 and at == Vector2.ZERO:
			at = Vector2(a.pos.x, a.pos.z)
			b_at = Vector2(b.pos.x, b.pos.z)
		if b.state == &"stomp" and b.sf >= 12:
			break
	assert_ne(at, Vector2.ZERO, "stomped")
	assert_lt(at.distance_to(b_at), SimConst.STOMP_PIN_DIST[&"katana"] - 0.3, "it began up close")
	var away: Vector2 = (at - b_at).normalized()
	assert_gt((Vector2(a.pos.x, a.pos.z) - at).dot(away), 0.3, "the thruster was jolted back, away from the stomp")
	assert_lt(Vector2(b.pos.x, b.pos.z).distance_to(b_at), 0.3, "the stomper hopped about in place")


func test_other_stuns_have_no_stomp_cause() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	a.enter_stun(SimConst.STOMP_STUN, &"stunned", &"stomp")
	a.enter_stun(SimConst.LEAP_STUN)
	assert_eq(a.stun_cause, &"", "a later stun clears the cause")
