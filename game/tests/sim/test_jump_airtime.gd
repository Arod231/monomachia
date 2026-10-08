extends GutTest
## The jump and its attacks (milestone-1 task 59, spec P53): a jump attack
## starts only while its startup and active frames fit the airtime left, a
## later press is ignored, and landing plays the attack's landing recovery
## instead of skipping its frames. Expected numbers come from the spec.

const H := preload("res://tests/sim/sim_helpers.gd")

## The spec's jump: about 30 frames in the air armed and 35 disarmed, so a
## jump pressed on step 0 touches down on its 30th (35th) step.
const ARMED_TOUCHDOWN: int = 29
const DISARMED_TOUCHDOWN: int = 34
## The spec's band ceilings, which must fit from a press on the jump's first
## airborne step (Falling Crown 28 of 30, Axe Kick 33 of 35).
const KATANA_JUMP_HEAVY_CEILING: Array[int] = [22, 6]
const FISTS_JUMP_HEAVY_CEILING: Array[int] = [27, 6]
## The owner's answer (Oct 7): until its re-key a stand-in jump attack's
## landing recovery is its row's recovery.
## A landing keeps 0.4 of the flight's speed, as the jump's own does.
const LANDING_KEEP: float = 0.4


func after_each() -> void:
	H.dispose_all()


## A world with fighter 0 holding `w` (bare hands: a disarmed Katana
## fighter), 10 m from the opponent, jumping on
## step 0 and pressing `b` on step `at` (none for -1); steps 0 to `steps`
## - 1, recording fighter 0's state and attack frame each step.
func _jump(w: WeaponDef, at: int, b: int, steps: int, mx: float = 0.0, my: float = 0.0) -> Dictionary:
	var W: World = _world(w)
	var f: Fighter = W.fighters[0]
	var states: Array[StringName] = []
	var frames: Array[int] = []
	var speeds: Array[float] = []
	for i: int in steps:
		var inp: RawInput = H.move(mx, my)
		if i == 0:
			inp = H.move(mx, my, Btn.JUMP)
		elif i == at:
			inp = H.move(mx, my, b)
		W.step([inp, H.idle()])
		states.append(f.state)
		frames.append(f.atk.frame if f.atk != null else -1)
		speeds.append(JsMath.hypot(f.vel.x, f.vel.z))
	return {"states": states, "frames": frames, "speeds": speeds, "world": W, "fighter": f}


## A world with fighter 0 holding `w`, or disarmed for bare hands.
func _world(w: WeaponDef) -> World:
	var W: World = H.make_world(Moves.KATANA if w == Moves.FISTS else w, Moves.KATANA, 10.0)
	W.fighters[0].armed = w != Moves.FISTS
	return W


func _first(states: Array[StringName], s: StringName) -> int:
	return states.find(s)


# ------------------------------------------------------------------ the arc

func test_an_armed_jump_touches_down_on_its_30th_step() -> void:
	var r: Dictionary = _jump(Moves.KATANA, -1, -1, 40)
	assert_eq(_first(r["states"], &"land"), ARMED_TOUCHDOWN)


func test_a_disarmed_jump_touches_down_on_its_35th_step() -> void:
	var r: Dictionary = _jump(Moves.FISTS, -1, -1, 45)
	assert_eq(_first(r["states"], &"land"), DISARMED_TOUCHDOWN)


func test_the_band_ceilings_fit_from_the_first_airborne_step_and_no_later() -> void:
	for c: Array in [[Moves.KATANA, KATANA_JUMP_HEAVY_CEILING], [Moves.FISTS, FISTS_JUMP_HEAVY_CEILING]]:
		var probe: AttackDef = AttackDef.new()
		probe.startup = c[1][0]
		probe.active = c[1][1]
		var W: World = _world(c[0])
		var f: Fighter = W.fighters[0]
		W.step([H.btn(Btn.JUMP), H.idle()])
		# a press on step 1 is judged before step 1's flight
		assert_true(f.air_attack_fits(probe), "%s: the ceiling fits from the first airborne step" % c[0].id)
		W.step([H.idle(), H.idle()])
		assert_false(f.air_attack_fits(probe), "%s: a step later it no longer does" % c[0].id)


# ------------------------------------------------------------------ the refusal

func test_a_jump_attack_starts_on_the_last_step_it_fits_and_not_after() -> void:
	# Falling Crown: its last active frame lands on the touchdown step at the
	# latest
	var crown: AttackDef = Moves.KATANA.moves[&"k_jh"]
	var last: int = ARMED_TOUCHDOWN - crown.startup - crown.active
	var fits: Dictionary = _jump(Moves.KATANA, last, Btn.HEAVY, last + 2)
	assert_eq(fits["states"][last], &"attack", "pressed on step %d it starts" % last)
	var late: Dictionary = _jump(Moves.KATANA, last + 1, Btn.HEAVY, ARMED_TOUCHDOWN + 20)
	assert_eq(late["states"][last + 1], &"jump", "a step later it is ignored")
	assert_eq(_first(late["states"], &"land"), ARMED_TOUCHDOWN, "the jump lands as a plain jump")
	assert_eq(_first(late["states"], &"attack"), -1, "and the ignored press starts nothing after the landing")


func test_an_ignored_press_leaves_the_air_attack_unused() -> void:
	# pressed too late for the heavy, the jump light (which fits) still can
	var crown: AttackDef = Moves.KATANA.moves[&"k_jh"]
	var aerial: AttackDef = Moves.KATANA.moves[&"k_jl"]
	var at: int = ARMED_TOUCHDOWN - crown.startup - crown.active + 1
	assert_true(at <= ARMED_TOUCHDOWN - aerial.startup - aerial.active, "the fixture: the light still fits there")
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 10.0)
	var f: Fighter = W.fighters[0]
	for i: int in at + 2:
		var inp: RawInput = H.idle()
		if i == 0:
			inp = H.btn(Btn.JUMP)
		elif i == at:
			inp = H.btn(Btn.HEAVY)
		elif i == at + 1:
			inp = H.btn(Btn.LIGHT)
		W.step([inp, H.idle()])
	assert_eq(f.state, &"attack")
	assert_eq(f.atk.def.id, &"k_jl", "the light starts")


# ------------------------------------------------------------------ the landing

func test_a_landing_skips_none_of_the_attacks_frames() -> void:
	# Aerial Cut pressed on the first airborne step runs past its active
	# frames in the air and on through the touchdown, a frame a step
	var r: Dictionary = _jump(Moves.KATANA, 1, Btn.LIGHT, ARMED_TOUCHDOWN + 20)
	var frames: Array[int] = r["frames"]
	for i: int in range(2, ARMED_TOUCHDOWN + 3):
		assert_eq(r["states"][i], &"attack", "still attacking on step %d" % i)
		assert_eq(frames[i], frames[i - 1] + 1, "one frame on at step %d" % i)


func test_a_jump_attack_holds_in_the_air_until_it_lands() -> void:
	# Aerial Cut's stand-in frames end long before the touchdown: it stays in
	# its attack, not back in the jump
	var aerial: AttackDef = Moves.KATANA.moves[&"k_jl"]
	assert_lt(aerial.total_frames() + 1, ARMED_TOUCHDOWN, "the fixture: its frames end in the air")
	var r: Dictionary = _jump(Moves.KATANA, 1, Btn.LIGHT, ARMED_TOUCHDOWN + 1)
	assert_false(r["states"].has(&"jump") and r["states"].rfind(&"jump") > 1, "never back in the jump after it starts")
	assert_eq(r["states"][ARMED_TOUCHDOWN], &"attack", "attacking as it lands")


func test_landing_plays_the_landing_recovery_then_frees() -> void:
	for c: Array in [[Moves.KATANA, &"k_jl", ARMED_TOUCHDOWN, Btn.LIGHT], [Moves.KATANA, &"k_jh", ARMED_TOUCHDOWN, Btn.HEAVY],
			[Moves.FISTS, &"f_jl", DISARMED_TOUCHDOWN, Btn.LIGHT], [Moves.FISTS, &"f_jh", DISARMED_TOUCHDOWN, Btn.HEAVY]]:
		var def: AttackDef = c[0].moves[c[1]]
		var touchdown: int = c[2]
		var r: Dictionary = _jump(c[0], 1, c[3], touchdown + def.landing_recovery() + 4)
		assert_eq(r["states"][touchdown + def.landing_recovery() - 1], &"attack", "%s: still in its landing recovery" % c[1])
		assert_eq(r["states"][touchdown + def.landing_recovery()], &"free", "%s: free %d steps after the touchdown" % [c[1], def.landing_recovery()])


func test_a_stand_in_lands_into_its_rows_recovery() -> void:
	for id: StringName in [&"k_jl", &"k_jh"]:
		var def: AttackDef = Moves.KATANA.moves[id]
		assert_eq(def.landing_recovery(), def.recovery, "%s" % id)
	for id: StringName in [&"f_jl", &"f_jh"]:
		var def: AttackDef = Moves.FISTS.moves[id]
		assert_eq(def.landing_recovery(), def.recovery, "%s" % id)


func test_a_rows_landing_sets_the_landing_recovery() -> void:
	var def: AttackDef = AttackDef.from_dict({"id": &"t_jl", "recovery": 12, "landing": 15, "airborne": true})
	assert_eq(def.landing_recovery(), 15)


func test_a_jump_attack_lands_with_the_jumps_slowdown() -> void:
	# a running jump's Aerial Cut keeps its flight until the touchdown, then
	# slows as a landing does, and does not slide on at flight speed
	var r: Dictionary = _jump(Moves.KATANA, 1, Btn.LIGHT, ARMED_TOUCHDOWN + 4, 0.0, 1.0)
	var speeds: Array[float] = r["speeds"]
	var flight: float = speeds[ARMED_TOUCHDOWN - 1]
	assert_gt(flight, 1.0, "the fixture: a running jump")
	assert_lte(speeds[ARMED_TOUCHDOWN], flight * LANDING_KEEP + 1e-9, "the touchdown keeps 0.4 of the flight at most")
	assert_lt(speeds[ARMED_TOUCHDOWN + 2], speeds[ARMED_TOUCHDOWN], "and brakes on")


# ------------------------------------------------------------------ the dive

func test_falling_crown_rides_the_jumps_arc() -> void:
	# the dive retired (the owner, Oct 7): pressed on the first airborne step,
	# Falling Crown's fighter rises and falls as a plain jump's does
	var plain: Dictionary = _jump(Moves.KATANA, -1, -1, ARMED_TOUCHDOWN)
	var crown: Dictionary = _jump(Moves.KATANA, 1, Btn.HEAVY, ARMED_TOUCHDOWN)
	assert_eq(_first(crown["states"], &"free"), -1)
	var a: Fighter = plain["fighter"]
	var b: Fighter = crown["fighter"]
	assert_almost_eq(b.pos.y, a.pos.y, 1e-9, "at the same height a step before the touchdown")
