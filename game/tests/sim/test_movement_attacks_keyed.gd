extends GutTest
## Bare hands' movement attacks re-keyed (milestone-1 tasks 93 and 94, family
## 8): each on its own Cascadeur-keyed clip's real markers, moved by the
## clip's travel with the rules' lunge and hop retired, its damage and
## posture raised with its wind-up (the owner's answer of Oct 7: lights
## +20%, heavies +30%, rounded) and its hitstun and hit-stop the frozen
## protected timings, as the pilot's were. The bands and distances are
## test_move_bands.gd's.

const H := preload("res://tests/sim/sim_helpers.gd")

## id: [startup, active, recovery (rules frames), damage, posture, the least
## the clip carries it forward by its last active frame (m)]
const KEYED: Dictionary[StringName, Array] = {
	&"f_sl": [24, 4, 28, 6, 14, 1.5], # Flying Knee, a running leap
	&"f_sh": [36, 6, 34, 9, 23, 1.5], # Dragon Kick, a leap
	&"f_dl": [20, 2, 20, 4, 11, 0.15], # Slip Jab, a short step in
	&"f_dh": [30, 4, 30, 7, 18, 0.2], # Spinning Backfist, drifting in through the turn
	&"f_bl": [20, 4, 22, 4, 12, 0.5], # Snap Kick, a skip in off the back foot
	&"f_bh": [36, 4, 30, 7, 21, 1.5], # Lunging Palm, a long lunge
	&"f_jl": [14, 4, 12, 5, 12, -1.0], # Air Kick, in place: the jump arc carries it
	&"f_jh": [22, 6, 18, 8, 21, -1.0], # Axe Kick, in place
}
## The jump attacks, which land into their landing recovery (task 59).
const JUMPS: Array[StringName] = [&"f_jl", &"f_jh"]


func test_each_plays_its_keyed_clip_s_markers() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.FISTS.moves[id]
		assert_eq([m.startup, m.active, m.recovery], KEYED[id].slice(0, 3), "%s (%s)" % [m.name, id])
		assert_true(m.real_markers, "%s: real markers" % m.name)


func test_each_hits_harder_with_its_longer_wind_up() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.FISTS.moves[id]
		assert_eq([m.damage, m.posture], [float(KEYED[id][3]), float(KEYED[id][4])], m.name)


func test_each_moves_by_its_clip_s_travel_with_no_lunge_or_hop() -> void:
	for id: StringName in KEYED:
		var m: AttackDef = Moves.FISTS.moves[id]
		assert_true(m.by_travel, "%s: led by its clip" % m.name)
		assert_eq(m.lunge_from(4.0), 0.0, "%s: no lunge" % m.name)
		assert_eq(m.hop, 0.0, "%s: no hop, the clip leaps" % m.name)
		var forward: float = 0.0
		for f: int in m.startup + m.active + 1:
			forward += m.travel_at(f)[0]
		if JUMPS.has(id):
			assert_almost_eq(forward, 0.0, 0.05, "%s: in place, the jump arc carries it" % m.name)
		else:
			assert_gt(forward, float(KEYED[id][5]), "%s: carried forward by its last active frame (%.2f m)" % [m.name, forward])


func test_each_turns_no_more_than_a_few_degrees() -> void:
	# a planted foot twisting in the clip reads as a turn, and a leap carries
	# it on through the flight (task 93: Cascadeur keys every planted frame)
	for id: StringName in KEYED:
		var m: AttackDef = Moves.FISTS.moves[id]
		var turned: float = 0.0
		for f: int in m.total_frames() + 1:
			turned += m.travel_at(f)[2]
		assert_between(turned, -8.0, 8.0, "%s turns %.1f degrees" % [m.name, turned])


func test_each_takes_the_frozen_protected_timings() -> void:
	var t: ProtectedTimings = ProtectedTimings.for_weapon(&"fists")
	for id: StringName in KEYED:
		var m: AttackDef = Moves.FISTS.moves[id]
		var kind: StringName = m.kind
		assert_eq(m.hitstun, t.hitstun(kind, id), "%s: hitstun" % m.name)
		assert_eq(m.hitstop, t.hitstop(kind), "%s: hit-stop" % m.name)


func test_a_knee_strike_closes_until_the_bodies_touch() -> void:
	# the owner's answer of Oct 7: a knee reaches about 0.6 m ahead of the hips,
	# short of a defender held 0.25 m off, so a knee strike closes until the
	# bodies meet; every other move keeps the gap
	assert_eq(Moves.FISTS.moves[&"f_sl"].closing_gap(), 0.0, "Flying Knee")
	for id: StringName in [&"f_sh", &"f_dl", &"f_dh", &"f_breaker"]:
		assert_eq(Moves.FISTS.moves[id].closing_gap(), SimConst.CLOSING_GAP, String(id))
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 1.85)
	var a: Fighter = W.fighters[0]
	a.armed = false
	assert_true(a.start_attack(&"f_sl"))
	var closest: float = INF
	for i: int in 30:
		H.run(W, 1)
		closest = minf(closest, SimMath.dist2(a.pos, W.fighters[1].pos))
	assert_almost_eq(closest, SimConst.FIGHTER_RADIUS * 2.0, 0.02, "from the duelling distance the leap carries in until the bodies meet")


func test_the_jump_attacks_land_into_their_keyed_landing() -> void:
	# a keyed jump attack's recovery is its landing: it holds its last active
	# pose to the touchdown, then plays its recovery (task 59), so its row's
	# landing is that recovery
	for id: StringName in JUMPS:
		var m: AttackDef = Moves.FISTS.moves[id]
		assert_true(m.airborne and m.fits_airtime(), "%s: a jump attack that fits the airtime" % m.name)
		assert_eq(m.landing, m.recovery, "%s: lands into its own recovery" % m.name)
		assert_eq(m.landing_recovery(), KEYED[id][2], m.name)
