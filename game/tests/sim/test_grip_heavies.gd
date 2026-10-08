extends GutTest
## The grip heavies (KE task 7): a string hit's heavy branch starts the held
## grip's heavy (one-handed Crescent Coil, two-handed Heaven Splitter, whose
## follow-up is Rising Heaven), from every hit of the string, the last too
## (the owner's word); both charge as charged heavies do (D9); heavy from
## neutral stays the Iai in both grips, the vertical Iai's heavy follow-up is
## the grip's (Crescent Coil one-handed, Rising Heaven two-handed) and the
## horizontal one keeps Returning Draw and the grip's hit 2 (D5). Crescent
## Coil is Elden Ring's since KE task 16, holding its charge at its coil;
## Heaven Splitter and Rising Heaven stand in on today's heavy clips until
## their re-key (KE task 17).

const H := preload("res://tests/sim/sim_helpers.gd")
const CLOSE: float = 0.005

const ONE: StringName = WeaponGrip.ONE_HANDED
const TWO: StringName = WeaponGrip.TWO_HANDED
## The spec's charged heavy: a full charge deals 1.8 times the damage, as the
## Iai's does (test_combat).
const FULL_CHARGE_DAMAGE: float = 1.8


# rounds start in the first grip, one-handed: these tests begin there
func before_each() -> void:
	H.grip = &""


func after_each() -> void:
	H.dispose_all()


static func _with_grip(base: RawInput) -> RawInput:
	return RawInput.make(base.mx, base.my, base.buttons | Btn.bit(Btn.GRIP))


## Fighter 0, in `grip`, plays `presses` (Btn.LIGHT or Btn.HEAVY), each the
## step after the attack before it swings, the stick at mx throughout, and
## holds heavy for `hold` steps after a heavy press (0: a tap). Returns the
## moves that swung, in order, and the hits' events.
static func _play(grip: StringName, presses: Array[int], mx: float = 0.0, hold: int = 0, gap: float = 2.2) -> Array:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, gap)
	if grip == TWO:
		W.step([_with_grip(H.idle()), H.idle()])
		W.drain_events()
	var swung: Array[StringName] = []
	var hits: Array[Dictionary] = []
	var pressed: int = 0
	var due: bool = true
	var held_until: int = -1
	for i: int in 420:
		var p0: RawInput = H.move(mx, 0.0)
		if due and pressed < presses.size():
			p0 = H.move(mx, 0.0, presses[pressed])
			if presses[pressed] == Btn.HEAVY and hold > 0:
				held_until = i + hold
			pressed += 1
			due = false
		elif i <= held_until:
			p0 = H.move(mx, 0.0, Btn.HEAVY)
		W.step([p0, H.idle()])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"swing" and e["f"] == 0:
				due = true
				swung.append(e["attack"])
			if e["t"] == &"hit" and e.get("attacker", 0) == 0:
				hits.append(e)
	return [swung, hits]


static func _lights(n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		out.append(Btn.LIGHT)
	return out


# ------------------------------------------------------------------ the grips' heavies

func test_the_katana_declares_each_grip_s_heavies() -> void:
	var w: WeaponDef = Moves.KATANA
	assert_eq([w.grips[0].heavy, w.grips[0].draw_heavy], [&"k_coil", &"k_coil"], "one-handed: Crescent Coil (D13, D5)")
	assert_eq([w.grips[1].heavy, w.grips[1].draw_heavy], [&"k_h2", &"k_h1f"], "two-handed: Heaven Splitter, Rising Heaven off the Iai (D5)")
	var coil: AttackDef = w.moves[&"k_coil"]
	assert_eq(coil.name, "Crescent Coil")
	assert_eq(coil.kind, &"heavy")
	assert_true(coil.chargeable and (w.moves[&"k_h2"] as AttackDef).chargeable, "both grip heavies charge (D9)")
	assert_false((w.moves[&"k_h1f"] as AttackDef).chargeable, "Rising Heaven doesn't")
	# about 85% of its two-handed counterpart, Heaven Splitter's 15 and 18 (D3)
	assert_eq([coil.damage, coil.posture], [13.0, 15.0])


func test_every_string_hit_branches_into_the_held_grip_s_heavy() -> void:
	var heavies: Dictionary = {ONE: &"k_coil", TWO: &"k_h2"}
	for grip: StringName in [ONE, TWO]:
		for n: int in range(1, 6):
			var presses: Array[int] = _lights(n)
			presses.append(Btn.HEAVY)
			var swung: Array[StringName] = (_play(grip, presses)[0] as Array[StringName])
			assert_eq(swung.size(), n + 1, "%s: %d lights then heavy all swing" % [grip, n])
			if swung.size() == n + 1:
				assert_eq(swung[n], heavies[grip], "%s: the heavy after hit %d" % [grip, n])


func test_a_switch_before_the_heavy_picks_the_new_grip_s_heavy() -> void:
	var W: World = H.make_world()
	var swung: Array[StringName] = []
	# heavy pressed once Slanting Cut takes a follow-up, past its startup
	var inputs: Dictionary = {0: H.btn(Btn.LIGHT), 10: _with_grip(H.idle()), 32: H.btn(Btn.HEAVY)}
	for i: int in 200:
		W.step([inputs.get(i, H.idle()), H.idle()])
		for e: Dictionary in W.drain_events():
			if e["t"] == &"swing" and e["f"] == 0:
				swung.append(e["attack"])
	assert_eq(swung, [&"k_1l1", &"k_h2"] as Array[StringName], "one-handed Slanting Cut, then two-handed Heaven Splitter")


func test_heaven_splitter_s_follow_up_is_rising_heaven_and_the_pair_ends() -> void:
	var swung: Array[StringName] = (_play(TWO, [Btn.LIGHT, Btn.HEAVY, Btn.HEAVY, Btn.HEAVY])[0] as Array[StringName])
	assert_eq(swung, [&"k_2l1", &"k_h2", &"k_h1f"] as Array[StringName], "Rising Heaven, then nothing")


func test_rising_heaven_is_optional() -> void:
	var swung: Array[StringName] = (_play(TWO, [Btn.LIGHT, Btn.HEAVY])[0] as Array[StringName])
	assert_eq(swung, [&"k_2l1", &"k_h2"] as Array[StringName])


func test_crescent_coil_takes_no_follow_up() -> void:
	var swung: Array[StringName] = (_play(ONE, [Btn.LIGHT, Btn.HEAVY, Btn.HEAVY, Btn.LIGHT])[0] as Array[StringName])
	assert_eq(swung, [&"k_1l1", &"k_coil"] as Array[StringName])


# ------------------------------------------------------------------ charging

func test_both_grip_heavies_charge_to_a_power_attack() -> void:
	var heavies: Dictionary = {ONE: &"k_coil", TWO: &"k_h2"}
	for grip: StringName in [ONE, TWO]:
		var tapped: Array = _play(grip, [Btn.LIGHT, Btn.HEAVY])
		# held from its press, a branch before the heavy starts, through the
		# wind-up to its hold (KE task 16: Crescent Coil's at its coil) and on
		var held: Array = _play(grip, [Btn.LIGHT, Btn.HEAVY], 0.0, SimConst.CHARGE_MAX + 140)
		var tap_hit: Dictionary = {}
		var held_hit: Dictionary = {}
		for e: Dictionary in tapped[1]:
			if e["attack"] == heavies[grip]:
				tap_hit = e
		for e: Dictionary in held[1]:
			if e["attack"] == heavies[grip]:
				held_hit = e
		assert_false(tap_hit.is_empty(), "%s: the tapped heavy hits" % grip)
		assert_false(held_hit.is_empty(), "%s: the held heavy hits" % grip)
		if tap_hit.is_empty() or held_hit.is_empty():
			continue
		var base: float = (Moves.KATANA.moves[heavies[grip]] as AttackDef).damage
		assert_almost_eq(float(tap_hit["damage"]), base, CLOSE, "%s: a tap deals its own" % grip)
		assert_almost_eq(float(held_hit["damage"]), base * FULL_CHARGE_DAMAGE, CLOSE, "%s: held 2.5 s it releases by itself as a power attack" % grip)


func test_a_charging_grip_heavy_holds_its_frame() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	var charged: bool = false
	for i: int in 120:
		var p0: RawInput = H.btn(Btn.LIGHT) if i == 0 else (H.btn(Btn.HEAVY) if i >= 32 else H.idle())
		W.step([p0, H.idle()])
		if a.state == &"attack" and a.atk.def.id == &"k_coil" and a.atk.charging:
			charged = true
	assert_true(charged, "Crescent Coil holds while heavy is held")
	assert_eq(a.atk.def.id if a.atk != null else &"", &"k_coil", "still coiled")


## Fighter 0 plays Slanting Cut, then Crescent Coil from its branch, heavy
## held `hold` steps from its press; returns the Coil's attack frame each
## step it was charging, and the frame it first swung on (its startup, as
## played).
static func _coil_charge(hold: int) -> Array:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	var charging: Array[int] = []
	var pressed: int = -1
	for i: int in 400:
		var p0: RawInput = H.idle()
		if i == 0:
			p0 = H.btn(Btn.LIGHT)
		elif pressed < 0 and a.state == &"attack" and a.atk.def.id == &"k_1l1" and a.atk.frame >= 32:
			pressed = i
			p0 = H.btn(Btn.HEAVY)
		elif pressed >= 0 and i < pressed + hold:
			p0 = H.btn(Btn.HEAVY)
		W.step([p0, H.idle()])
		if a.state == &"attack" and a.atk.def.id == &"k_coil" and a.atk.charging:
			charging.append(a.atk.frame)
	return charging


# The grip heavies hold their charge at their own pose, Elden Ring's (KE task
# 16): Crescent Coil at its coil over the shoulder, its row's hold frame,
# not today's frame 9, which the Iai keeps.
func test_crescent_coil_holds_its_charge_at_the_coil() -> void:
	var coil: AttackDef = Moves.KATANA.moves[&"k_coil"]
	assert_gt(coil.charge_hold, Fighter.CHARGE_CHECK_FRAME, "past today's frame 9")
	var held: Array[int] = _coil_charge(coil.charge_hold + 60)
	assert_false(held.is_empty(), "held past the coil, it charges")
	if not held.is_empty():
		assert_eq(held[0], coil.charge_hold, "from the coil, on its hold frame")
		assert_eq(held.max(), coil.charge_hold, "and holds that frame while it charges")
	assert_eq(_coil_charge(coil.charge_hold - 4), [] as Array[int], "let go before the coil: a tap, no charge")


## Fighter 0 plays Slanting Cut, then Crescent Coil from its branch, heavy
## held `hold` steps from its press, from the duelling distance; returns
## [whether the Coil hit, how far fighter 0 went from the Coil's first frame
## to its first active frame].
static func _coil_from_the_duel(hold: int) -> Array:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, Moves.KATANA.duel_distance)
	var a: Fighter = W.fighters[0]
	var coil: AttackDef = Moves.KATANA.moves[&"k_coil"]
	var pressed: int = -1
	var from: V3 = null
	var went: float = -1.0
	var hit: bool = false
	for i: int in 500:
		var p0: RawInput = H.idle()
		if i == 0:
			p0 = H.btn(Btn.LIGHT)
		elif pressed < 0 and a.state == &"attack" and a.atk.def.id == &"k_1l1" and a.atk.frame >= 32:
			pressed = i
			p0 = H.btn(Btn.HEAVY)
		elif pressed >= 0 and i < pressed + hold:
			p0 = H.btn(Btn.HEAVY)
		W.step([p0, H.idle()])
		if a.state == &"attack" and a.atk.def.id == &"k_coil":
			if from == null:
				from = V3.make(a.pos.x, a.pos.y, a.pos.z)
			elif went < 0.0 and a.atk.frame == coil.startup + 1:
				went = SimMath.dist2(from, a.pos)
		for e: Dictionary in W.drain_events():
			if e["t"] == &"hit" and e.get("attacker", 0) == 0 and e["attack"] == &"k_coil":
				hit = true
	return [hit, went]


func test_the_tapped_and_the_charged_coil_cut_alike_from_the_duelling_distance() -> void:
	var tapped: Array = _coil_from_the_duel(1)
	var charged: Array = _coil_from_the_duel((Moves.KATANA.moves[&"k_coil"] as AttackDef).charge_hold + 90)
	assert_true(tapped[0], "the tapped Coil lands from the duelling distance")
	assert_true(charged[0], "and the charged one")
	assert_gt(float(tapped[1]), 0.5, "stepping in to its cut")
	assert_almost_eq(float(charged[1]), float(tapped[1]), 0.01, "the charge holds the step, the release takes it as the tap does")


func test_a_tapped_crescent_coil_plays_its_whole_coil() -> void:
	var tapped: Array = _play(ONE, [Btn.LIGHT, Btn.HEAVY])
	var hit_seen: bool = false
	for e: Dictionary in tapped[1]:
		if e["attack"] == &"k_coil":
			hit_seen = true
	assert_true(hit_seen, "the tapped Coil lands from the string's spacing")
	var coil: AttackDef = Moves.KATANA.moves[&"k_coil"]
	assert_between(coil.startup, 84, 96, "Elden Ring's slow coil, about 1.5 s to the cut (the owner's word, Oct 8)")


# ------------------------------------------------------------------ the Iai

func test_heavy_from_neutral_stays_the_iai_in_both_grips() -> void:
	for grip: StringName in [ONE, TWO]:
		var swung: Array[StringName] = (_play(grip, [Btn.HEAVY])[0] as Array[StringName])
		assert_eq(swung, [&"k_iai"] as Array[StringName], grip)


func test_the_vertical_iai_s_heavy_follow_up_is_the_grip_s() -> void:
	assert_eq((_play(ONE, [Btn.HEAVY, Btn.HEAVY])[0] as Array[StringName]), [&"k_iai", &"k_coil"] as Array[StringName], "one-handed: Crescent Coil")
	assert_eq((_play(TWO, [Btn.HEAVY, Btn.HEAVY])[0] as Array[StringName]), [&"k_iai", &"k_h1f"] as Array[StringName], "two-handed: Rising Heaven")


func test_the_horizontal_iai_keeps_returning_draw_and_the_grip_s_hit_2() -> void:
	for grip: StringName in [ONE, TWO]:
		assert_eq((_play(grip, [Btn.HEAVY, Btn.HEAVY], 1.0)[0] as Array[StringName]), [&"k_iai_h", &"k_rdraw"] as Array[StringName], "%s: Returning Draw" % grip)
		var g: WeaponGrip = Moves.KATANA.grip(grip)
		assert_eq((_play(grip, [Btn.HEAVY, Btn.LIGHT, Btn.LIGHT], 1.0)[0] as Array[StringName]), [&"k_iai_h", g.hit(2), g.hit(3)] as Array[StringName], "%s: hit 2, then on to hit 3" % grip)
