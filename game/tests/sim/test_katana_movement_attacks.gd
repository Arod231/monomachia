extends GutTest
## The Katana's movement attacks re-keyed (milestone-1 tasks 75 and 76,
## family 5): each on its own re-keyed clip's real markers, moved by the
## clip's travel with the rules' lunge and hop retired, its damage and
## posture as they were (the owner's answer of Oct 8: balance waits on family
## 5's review, task 78) and its hitstun and hit-stop the frozen protected
## timings, as the pilot's were. One clip each for both grips (KE D14): the
## lights one-handed, the heavies two-handed (the owner's answer of Oct 8).
## The bands and distances are test_move_bands.gd's.

## id: [startup, active, recovery (rules frames), damage, posture, the least
## the clip carries it forward by its last active frame (m), its clip,
## one-handed]
const KEYED: Dictionary[StringName, Array] = {
	&"k_sl": [27, 4, 35, 8, 9, 2.0, &"RunningDraw", true], # Running Draw, a cut at a run
	&"k_sh": [47, 4, 42, 15, 18, 3.0, &"LeapingCleave", false], # Leaping Cleave, a long leap
	&"k_dl": [26, 3, 31, 6, 7, 0.8, &"WindCut", true], # Wind Cut, a step into a lunge
	&"k_dh": [41, 6, 42, 12, 14, 0.8, &"WhirlCut", false], # Whirl Cut, drifting in through a full turn
	&"k_bl": [26, 3, 31, 6, 8, 1.5, &"RisingCut", true], # Rising Cut, a bound in off the back foot
	&"k_bh": [43, 4, 41, 12, 14, 2.0, &"LungingCut", false], # Lunging Cut, a long lunge
	&"k_jl": [14, 4, 12, 6, 7, 0.4, &"AerialCut", true], # Aerial Cut, carried forward through the flight
	&"k_jh": [20, 5, 19, 13, 16, 0.4, &"FallingCrown", false], # Falling Crown, diving forward
}
## The heavies, which keep a dodge cancel in the second half of their recovery.
const HEAVIES: Array[StringName] = [&"k_sh", &"k_dh", &"k_bh", &"k_jh"]
## The jump attacks, which land into their landing recovery (task 59).
const JUMPS: Array[StringName] = [&"k_jl", &"k_jh"]

const H := preload("res://tests/sim/sim_helpers.gd")


func after_each() -> void:
	H.dispose_all()


func test_each_plays_its_keyed_clip_s_markers() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_eq([m.startup, m.active, m.recovery], KEYED[id].slice(0, 3), "%s (%s)" % [m.name, id])
		assert_true(m.real_markers, "%s: real markers" % m.name)


func test_each_keeps_its_damage_and_posture() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_eq([m.damage, m.posture], [float(KEYED[id][3]), float(KEYED[id][4])], m.name)


func test_each_moves_by_its_clip_s_travel_with_no_lunge_or_hop() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_true(m.by_travel, "%s: led by its clip" % m.name)
		assert_eq(m.lunge_from(4.0), 0.0, "%s: no lunge" % m.name)
		assert_eq(m.hop, 0.0, "%s: no hop, the clip leaps" % m.name)
		var forward: float = 0.0
		for f: int in m.startup + m.active + 1:
			forward += m.travel_at(f)[0]
		assert_gt(forward, float(KEYED[id][5]), "%s: carried forward by its last active frame (%.2f m)" % [m.name, forward])


func test_each_turns_no_more_than_a_few_degrees() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		var turned: float = 0.0
		for f: int in m.total_frames() + 1:
			turned += m.travel_at(f)[2]
		assert_between(turned, -8.0, 8.0, "%s turns %.1f degrees" % [m.name, turned])


func test_each_takes_the_frozen_protected_timings() -> void:
	var t: ProtectedTimings = ProtectedTimings.for_weapon(&"katana")
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_eq(m.hitstun, t.hitstun(m.kind, id), "%s: hitstun" % m.name)
		assert_eq(m.hitstop, t.hitstop(m.kind), "%s: hit-stop" % m.name)


func test_the_heavies_keep_a_dodge_cancel_late_in_their_recovery() -> void:
	for id: StringName in HEAVIES:
		var m: AttackDef = Moves.KATANA.moves[id]
		var recovery_from: int = m.startup + m.active
		assert_between(m.dodge_cancel_from, recovery_from + m.recovery / 2 - 2, m.startup + m.active + m.recovery, "%s: from the second half of its recovery" % m.name)


func test_the_jump_attacks_fit_the_airtime_and_land_into_their_keyed_landing() -> void:
	# a keyed jump attack's recovery is its landing: it holds its last active
	# pose to the touchdown, then plays its recovery (task 59), so its row's
	# landing is that recovery; each is carried forward through its flight
	# (its clip's travel), the jump arc under it
	for id: StringName in JUMPS:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_true(m.airborne and m.fits_airtime(), "%s: a jump attack that fits the airtime" % m.name)
		assert_eq(m.landing, m.recovery, "%s: lands into its own recovery" % m.name)
		assert_eq(m.landing_recovery(), KEYED[id][2], m.name)


func test_each_plays_one_clip_for_both_grips_the_lights_one_handed() -> void:
	var clips: MoveClips = MoveClips.read(ClipManifest.read())
	for id: StringName in KEYED:
		var e: MoveClips.Entry = clips.of(&"katana")[id]
		assert_eq(e.clips, [KEYED[id][6]] as Array[StringName], "%s: its own clip" % id)
		assert_eq(Moves.KATANA.moves[id].grip, &"", "%s: no grip of its own, played from either" % id)
		assert_eq(StateClips.shared().one_handed(&"katana", KEYED[id][6]), KEYED[id][7],
			"%s: %s" % [id, "one-handed, the off hand off the grip" if KEYED[id][7] else "two-handed, the off hand on the grip"])


# ------------------------------------------------------------------ sound and effects' hooks (task 77)

## Fighter 0 of a Katana world, 6 m apart, plays `id` (a jump attack out of
## a jump, pressed on its third step; the others started at once) for
## `steps` steps. Returns its events, each with the step it came on ("step")
## and the attacker's feet then ("at"), and the attack's frame then
## ("frame", -1 outside it).
func _play(id: StringName, steps: int) -> Array[Dictionary]:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var a: Fighter = W.fighters[0]
	var jump: bool = JUMPS.has(id)
	if not jump:
		assert_true(a.start_attack(id), String(id))
	var out: Array[Dictionary] = []
	for i: int in steps:
		var inp: RawInput = H.idle()
		if jump and i == 0:
			inp = H.move(0.0, 0.0, Btn.JUMP)
		elif jump and i == 3:
			inp = H.move(0.0, 0.0, Btn.LIGHT if id == &"k_jl" else Btn.HEAVY)
		W.step([inp, H.idle()])
		for e: Dictionary in W.drain_events():
			if int(e.get("f", -1)) == 0:
				var row: Dictionary = e.duplicate()
				row["step"] = i
				row["at"] = Vector3(a.pos.x, a.pos.y, a.pos.z)
				row["frame"] = a.atk.frame if a.state == &"attack" and a.atk != null else -1
				out.append(row)
	if jump:
		assert_eq(out.filter(func(e: Dictionary) -> bool: return e["t"] == &"swing" and e["attack"] == id).size(), 1, "%s thrown out of the jump" % id)
	return out


static func _of(events: Array[Dictionary], t: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(events.filter(func(e: Dictionary) -> bool: return e["t"] == t))
	return out


## Each swing says it is a movement attack (task 77: the Hunter's coat
## whooshes with it); a string's swing doesn't.
func test_each_swings_as_a_movement_attack() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.KATANA.moves[id]
		var swings: Array[Dictionary] = _of(_play(id, m.startup + 8), &"swing")
		assert_eq(swings.size(), 1, "%s swings once" % m.name)
		if swings.size() == 1:
			assert_true(bool(swings[0].get("movement", false)), "%s: a movement attack" % m.name)
	var light: Array[Dictionary] = _of(_play(&"k_l1", 40), &"swing")
	assert_false(bool(light[0].get("movement", true)), "Right Cut: a string's")


## Leaping Cleave comes down to the ground as its leap lands (task 77): a
## touchdown at the attacker's feet on its keyed frame, as the clip's travel
## stops with the feet planted again; once.
func test_leaping_cleave_touches_down_where_its_leap_lands() -> void:
	var m: AttackDef = Moves.KATANA.moves[&"k_sh"]
	assert_between(m.touchdown, m.startup + 1, m.startup + m.active + 2, "as the cut comes down")
	assert_lt(m.travel_at(m.touchdown)[0], m.travel_at(m.touchdown - 1)[0] * 0.5, "the leap's travel stops there (the feet down)")
	var downs: Array[Dictionary] = _of(_play(&"k_sh", m.total_frames()), &"touchdown")
	assert_eq(downs.size(), 1, "once")
	if downs.size() == 1:
		var e: Dictionary = downs[0]
		assert_eq(e["frame"], m.touchdown, "on its frame")
		assert_eq([e["attack"], e["weapon"], e["heavy"]], [&"k_sh", &"katana", true])
		var at: Vector3 = e["at"]
		assert_almost_eq(Vector3(float(e["pos"]["x"]), float(e["pos"]["y"]), float(e["pos"]["z"])), Vector3(at.x, 0.0, at.z), Vector3.ONE * 1e-6, "at its feet")


## Falling Crown comes down as it lands (task 77): the touchdown with the
## jump's landing, at its feet on the ground; Aerial Cut lands without one.
func test_falling_crown_touches_down_as_it_lands_and_aerial_cut_doesn_t() -> void:
	var m: AttackDef = Moves.KATANA.moves[&"k_jh"]
	assert_eq(m.touchdown, AttackDef.TOUCHDOWN_ON_LANDING)
	var events: Array[Dictionary] = _play(&"k_jh", 80)
	var downs: Array[Dictionary] = _of(events, &"touchdown")
	var lands: Array[Dictionary] = _of(events, &"land")
	assert_eq(downs.size(), 1, "once")
	assert_eq(lands.size(), 1, "it lands")
	if downs.size() == 1 and lands.size() == 1:
		assert_eq(downs[0]["step"], lands[0]["step"], "as it lands")
		assert_eq(float(downs[0]["pos"]["y"]), 0.0, "on the ground")
		assert_gt(int(downs[0]["frame"]), m.startup, "the blade already down")
	var aerial: Array[Dictionary] = _play(&"k_jl", 80)
	assert_eq(_of(aerial, &"land").size(), 1, "Aerial Cut lands")
	assert_eq(_of(aerial, &"touchdown").size(), 0, "without a touchdown")


func test_the_other_six_never_touch_down() -> void:
	for id: StringName in [&"k_sl", &"k_dl", &"k_dh", &"k_bl", &"k_bh"]:
		var m: AttackDef = Moves.KATANA.moves[id]
		assert_eq(m.touchdown, AttackDef.UNSET, m.name)
		assert_eq(_of(_play(id, m.total_frames()), &"touchdown").size(), 0, m.name)
	assert_eq(Moves.KATANA.moves[&"k_jl"].touchdown, AttackDef.UNSET, "Aerial Cut")
