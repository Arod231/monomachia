extends GutTest
## The deterministic stuck weapon (milestone-1 task 86, spec P16, stories 25,
## 66, 67): a disarmed weapon flies a fixed arc along the knock or deflect
## direction, shortened to land inside the walls, and sticks blade-first at an
## angle that is rules state, the same way every run.
##
## The owner's numbers (Oct 5): it follows the blade's motion at contact (a
## knock along the blow's, a deflect along the attacker's own reversed),
## straight away from the disarmer when the blade moves under 0.5 m/s across
## the ground or there is no swing; it flies 3.5 m and sticks 25° from
## vertical, leaning back toward where it came from.

const H := preload("res://tests/sim/sim_helpers.gd")

const FLIGHT: float = 3.5
const LEAN: float = 25.0 * PI / 180.0
## The arena's wall (SimConst.ARENA_RADIUS) less the 0.8 m a stuck weapon
## keeps inside it.
const RING: float = 15.0 - 0.8
const DT: float = 1.0 / 60.0


func after_each() -> void:
	H.dispose_all()


## A world with the victim (fighter 0) at `at` and the other fighter 2 m
## further along +z.
func _world(at: Vector2 = Vector2.ZERO, seed_value: int = 7) -> World:
	var W: World = H.track(World.new(FighterConfig.make(Moves.KATANA), FighterConfig.make(Moves.KATANA), seed_value))
	W.fighters[0].pos = V3.make(at.x, 0.0, at.y)
	W.fighters[1].pos = V3.make(at.x, 0.0, at.y + 2.0)
	for f: Fighter in W.fighters:
		f.set_state(&"free")
	return W


## Gives f an attack whose blade tip moved (mx, mz) metres across the ground
## over the last tick.
func _swinging(f: Fighter, mx: float, mz: float) -> void:
	f.start_attack(f.weapon.light_start)
	var s: BladeSegment = BladeSegment.new()
	s.part = &"right_hand"
	s.prev_base = V3.make(f.pos.x, 1.0, f.pos.z)
	s.prev_tip = V3.make(f.pos.x, 1.2, f.pos.z + 0.8)
	s.base = s.prev_base
	s.tip = V3.make(s.prev_tip.x + mx, 1.2, s.prev_tip.z + mz)
	var blades: Array[BladeSegment] = [s]
	f.atk.blades = blades


## Steps the world until the dropped weapon sticks (or 300 steps), keeping
## the events; returns the steps taken.
func _until_stuck(W: World, r: H.Rec = null) -> int:
	for i: int in 300:
		W.step([H.idle(), H.idle()])
		var events: Array[Dictionary] = W.drain_events()
		if r != null:
			r.events.append_array(events)
		if W.weapons[0].grounded:
			return i + 1
	return -1


## Asserts the victim's weapon stuck (wx, wz) from (fx, fz), where the
## victim stood. Doubles throughout: Vector2 is single precision.
func _assert_flew(W: World, fx: float, fz: float, wx: float, wz: float, what: String) -> void:
	var w: DroppedWeapon = W.weapons[0]
	assert_almost_eq(w.pos.x - fx, wx, 1e-9, what + " (x)")
	assert_almost_eq(w.pos.z - fz, wz, 1e-9, what + " (z)")


func test_a_parried_attacker_s_weapon_flies_back_along_its_own_blade_s_motion() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_swinging(a, 0.1, 0.0) # 6 m/s toward +x
	a.disarm(W.fighters[1], &"parried")
	assert_gt(_until_stuck(W), 0, "it sticks")
	_assert_flew(W, 0.0, 0.0, -FLIGHT, 0.0, "3.5 m toward -x, against the blade")


func test_a_redirected_attacker_s_weapon_is_deflected_the_same_way() -> void:
	var W: World = _world()
	var a: Fighter = W.fighters[0]
	_swinging(a, 0.0, 0.1)
	a.disarm(W.fighters[1], &"redirect")
	_until_stuck(W)
	_assert_flew(W, 0.0, 0.0, 0.0, -FLIGHT, "3.5 m toward -z, against the blade")


func test_a_blocked_power_blow_knocks_the_blocker_s_weapon_along_the_blow() -> void:
	var W: World = _world()
	var victim: Fighter = W.fighters[0]
	var attacker: Fighter = W.fighters[1]
	_swinging(attacker, 0.06, 0.08) # 6 m/s, three parts x to four parts z
	victim.disarm(attacker, &"blocked")
	_until_stuck(W)
	_assert_flew(W, 0.0, 0.0, 0.6 * FLIGHT, 0.8 * FLIGHT, "3.5 m along the blow's blade")


func test_with_no_swing_it_flies_straight_away_from_the_disarmer() -> void:
	var W: World = _world()
	W.fighters[0].disarm(W.fighters[1], &"parried")
	_until_stuck(W)
	_assert_flew(W, 0.0, 0.0, 0.0, -FLIGHT, "away from the disarmer, who stands at +z")


func test_a_blade_moving_under_half_a_metre_a_second_counts_as_still() -> void:
	var slow: World = _world()
	_swinging(slow.fighters[0], 0.4 * DT, 0.0)
	slow.fighters[0].disarm(slow.fighters[1], &"parried")
	_until_stuck(slow)
	_assert_flew(slow, 0.0, 0.0, 0.0, -FLIGHT, "0.4 m/s: straight away")
	var fast: World = _world()
	_swinging(fast.fighters[0], 0.6 * DT, 0.0)
	fast.fighters[0].disarm(fast.fighters[1], &"parried")
	_until_stuck(fast)
	_assert_flew(fast, 0.0, 0.0, -FLIGHT, 0.0, "0.6 m/s: against the blade")


func test_it_sticks_in_the_ground_at_25_degrees_leaning_back_toward_where_it_came_from() -> void:
	var W: World = _world()
	W.fighters[0].disarm(W.fighters[1], &"parried")
	W.step([H.idle(), H.idle()])
	assert_false(W.weapons[0].grounded, "it flies first")
	var steps: int = _until_stuck(W)
	assert_between(steps, 1, 60, "and sticks inside a second")
	var w: DroppedWeapon = W.weapons[0]
	assert_eq(w.pos.y, 0.0, "in the ground")
	assert_almost_eq(w.yaw, PI, 1e-9, "facing along its flight, toward -z")
	assert_almost_eq(w.pitch, PI - LEAN, 1e-9, "blade down, 25° from vertical, the hilt back toward the victim")
	var at: V3 = V3.make(w.pos.x, w.pos.y, w.pos.z)
	H.run(W, 120)
	assert_true(w.grounded, "it stays stuck")
	assert_eq([w.pos.x, w.pos.y, w.pos.z, w.pitch], [at.x, at.y, at.z, PI - LEAN], "where it stuck")


func test_near_the_wall_the_flight_is_shortened_to_land_inside() -> void:
	var W: World = _world(Vector2(0.0, 13.0))
	W.fighters[1].pos = V3.make(0.0, 0.0, 11.0)
	W.fighters[0].disarm(W.fighters[1], &"parried")
	var furthest: float = 0.0
	for _i: int in 120:
		W.step([H.idle(), H.idle()])
		furthest = maxf(furthest, JsMath.hypot(W.weapons[0].pos.x, W.weapons[0].pos.z))
	_assert_flew(W, 0.0, 13.0, 0.0, RING - 13.0, "shortened along its flight to the ring")
	assert_lte(furthest, RING + 1e-9, "and never past it in flight")


func test_a_victim_against_the_wall_flying_outward_lands_back_on_the_ring() -> void:
	var W: World = _world(Vector2(0.0, 14.5))
	W.fighters[1].pos = V3.make(0.0, 0.0, 12.5)
	W.fighters[0].disarm(W.fighters[1], &"parried")
	var furthest: float = 0.0
	for _i: int in 120:
		W.step([H.idle(), H.idle()])
		furthest = maxf(furthest, JsMath.hypot(W.weapons[0].pos.x, W.weapons[0].pos.z))
	_assert_flew(W, 0.0, 0.0, 0.0, RING, "on the ring, straight out")
	assert_lte(furthest, RING + 1e-9, "leaving the hands at the ring, never past it")


func test_the_same_disarm_lands_the_same_way_every_run_and_draws_nothing_from_the_world_s_generator() -> void:
	var landings: Array = []
	for seed_value: int in [5, 6]:
		var W: World = _world(Vector2(1.0, -2.0), seed_value)
		var before: Dictionary = W.rng.snapshot()
		_swinging(W.fighters[0], 0.03, -0.05)
		W.fighters[0].disarm(W.fighters[1], &"parried")
		_until_stuck(W)
		var w: DroppedWeapon = W.weapons[0]
		landings.append([w.pos.x, w.pos.y, w.pos.z, w.yaw, w.pitch])
		assert_eq(W.rng.snapshot(), before, "seed %d: the generator untouched" % seed_value)
	assert_eq(landings[0], landings[1], "another seed, the same landing")


func test_it_tells_the_view_when_it_sticks_and_never_bounces() -> void:
	var W: World = _world()
	var r: H.Rec = H.Rec.new()
	W.fighters[0].disarm(W.fighters[1], &"parried")
	r.collect(W)
	H.run(W, 120, Callable(), Callable(), r)
	var w: DroppedWeapon = W.weapons[0]
	var stuck: Array[Dictionary] = r.all(&"weaponStuck")
	assert_eq(stuck.size(), 1, "one weaponStuck")
	assert_eq(stuck[0]["owner"], 0)
	assert_eq([stuck[0]["pos"]["x"], stuck[0]["pos"]["z"]], [w.pos.x, w.pos.z], "where it stuck")
	assert_eq(r.all(&"weaponBounce").size(), 0, "no bounce")
