extends GutTest
## The air smears' rules (plan task 18.2's trail rules, kept for milestone-1
## task 37's air smears): when each hand's blade smears, how strongly, and in
## which tint, read from the rules' state. The tests drive a rules World
## through a Katana light, a Greatsword unblockable, a charged heavy and an
## ultimate, and check the owner's choices: only the striking hands, Flash
## off but Shadow Step on, bare hands only on the moves switched on (along
## the striking limb, milestone-1 task 95), a plain swing's pale sheen, an
## unblockable's red and an ultimate's gold. How fast the tip must move to
## smear is the smear's own (test_air_smear.gd).

const H := preload("res://tests/sim/sim_helpers.gd")
const R: int = TrailState.RIGHT
const L: int = TrailState.LEFT


func after_each() -> void:
	H.dispose_all()


## Steps the world one frame at a time with fighter 0 pressing `input` (a
## Callable of the step index, or idle), and returns, for each step, the
## attack frame and the trail at alpha 1 (the frame just stepped on show).
func _drive(W: World, steps: int, input: Callable = Callable()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f: Fighter = W.fighters[0]
	for i: int in steps:
		H.run(W, 1, (func(_k: int) -> RawInput: return input.call(i)) if not input.is_null() else Callable())
		out.append({
			"state": f.state,
			"frame": f.atk.frame if f.atk != null else -1,
			"charging": f.atk.charging if f.atk != null else false,
			"trail": TrailState.of(f, 1.0),
		})
	return out


func test_a_katana_light_smears_pale_in_its_active_frames_then_fades_in_two() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	assert_true(f.start_attack(&"k_l1"))
	var def: AttackDef = f.atk.def
	var s: int = def.startup
	var a: int = def.active
	var seen_on: int = 0
	for row: Dictionary in _drive(W, s + a + def.recovery):
		var t: TrailState = row["trail"]
		var fr: int = row["frame"]
		if row["state"] != &"attack":
			assert_eq(t.intensity(R), 0.0, "nothing once the attack is over")
			continue
		if fr <= s:
			assert_eq(t.intensity(R), 0.0, "frame %d: not in the wind-up" % fr)
		elif fr <= s + a:
			assert_eq(t.intensity(R), 1.0, "frame %d: on in the active frames" % fr)
			assert_eq(t.kind, TrailState.NORMAL, "white")
			seen_on += 1
		elif fr == s + a + 1:
			assert_almost_eq(t.intensity(R), 0.5, 1e-6, "half faded a frame after")
		else:
			assert_eq(t.intensity(R), 0.0, "frame %d: gone two frames after" % fr)
		assert_eq(t.intensity(L), 0.0, "the katana is one blade, in the right hand")
	assert_eq(seen_on, a, "every active frame")


func test_the_fade_follows_the_host_alpha_between_steps() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	f.start_attack(&"k_l1")
	var end: int = f.atk.def.startup + f.atk.def.active
	while f.atk.frame < end + 1:
		H.run(W, 1)
	# the frame on show is atk.frame - 1 + alpha: halfway from the last active
	# frame to the first frame after it
	assert_almost_eq(TrailState.of(f, 0.5).intensity(R), 0.75, 1e-6)
	assert_almost_eq(TrailState.of(f, 0.0).intensity(R), 1.0, 1e-6)
	H.run(W, 1)
	assert_almost_eq(TrailState.of(f, 0.5).intensity(R), 0.25, 1e-6)


func test_a_greatsword_unblockable_smears_red() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 8.0)
	var f: Fighter = W.fighters[0]
	assert_true(f.start_attack(&"g_sweep"))
	assert_true(f.atk.def.unblockable)
	var on: int = 0
	for row: Dictionary in _drive(W, 60):
		var t: TrailState = row["trail"]
		if t.on(R):
			on += 1
			assert_eq(t.kind, TrailState.DANGER, "red for an unblockable")
	assert_gt(on, 0)


func test_a_charged_heavy_smears_only_once_released() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 8.0)
	var held: int = 50
	var rows: Array[Dictionary] = _drive(W, 120, func(i: int) -> RawInput: return H.btn(Btn.HEAVY) if i < held else H.idle())
	var charged: int = 0
	var on_after: int = 0
	for row: Dictionary in rows:
		var t: TrailState = row["trail"]
		if row["charging"]:
			charged += 1
			assert_false(t.on(R), "no trail while charging")
		elif t.on(R) and row["state"] == &"attack":
			on_after += 1
	assert_gt(charged, 10, "the heavy charged")
	assert_gt(on_after, 0, "and trails once it strikes")


func test_moonsplitter_smears_gold_at_its_release_only() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var f: Fighter = W.fighters[0]
	f.hp = 20.0
	var windup: int = 0
	var release_on: int = 0
	var release_off: int = 0
	H.run(W, 1, func(_i: int) -> RawInput: return H.btn(Btn.ULTIMATE))
	for i: int in SimConst.MOONSPLITTER_WAVE + SimConst.MOONSPLITTER_RECOVERY + 8:
		H.run(W, 1)
		if f.state != &"ult":
			continue
		var t: TrailState = TrailState.of(f, 1.0)
		if f.ult.phase == &"windup":
			windup += 1
			assert_false(t.on(R), "no trail in the wind-up")
		elif f.ult.pf < 6:
			release_on += 1
			assert_true(t.on(R), "the cut at release frame %d" % f.ult.pf)
			assert_eq(t.kind, TrailState.ULT)
		else:
			release_off += 1
			assert_false(t.on(R), "release frame %d: done" % f.ult.pf)
	assert_gt(windup, 0)
	assert_gt(release_on, 0)
	assert_gt(release_off, 0)


func test_an_attack_marked_gold_smears_gold_the_counter_lunge() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var f: Fighter = W.fighters[0]
	var ult_attack: StringName = &""
	for id: StringName in f.moveset().moves:
		if (f.moveset().moves[id] as AttackDef).trail == &"ult":
			ult_attack = id
	assert_eq(ult_attack, &"k_lunge", "the counter lunge trails gold, as in the demo")
	f.start_attack(ult_attack)
	var on: int = 0
	for row: Dictionary in _drive(W, 40):
		var t: TrailState = row["trail"]
		if t.on(R):
			on += 1
			assert_eq(t.kind, TrailState.ULT)
	assert_gt(on, 0)


func test_daggers_smear_only_the_hands_that_strike() -> void:
	var cases: Dictionary[StringName, Array] = {
		&"d_l1": [true, false], # Quick Slice, the right dagger
		&"d_bl": [false, true], # Flick, the left
		&"d_l3": [true, true], # Twin Rip, both
	}
	for id: StringName in cases:
		var W: World = H.make_world(Moves.DAGGERS, Moves.KATANA, 6.0)
		var f: Fighter = W.fighters[0]
		assert_true(f.start_attack(id), String(id))
		var def: AttackDef = f.atk.def
		while f.atk != null and f.atk.frame <= def.startup:
			H.run(W, 1)
		var t: TrailState = TrailState.of(f, 1.0)
		assert_eq([t.on(R), t.on(L)], cases[id], "%s: %s" % [id, def.name])


func test_flash_leaves_no_smear_but_shadow_step_does() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	f.start_attack(&"k_flash")
	var flash_on: int = 0
	for row: Dictionary in _drive(W, 30):
		if (row["trail"] as TrailState).on(R):
			flash_on += 1
	assert_eq(flash_on, 0, "Flash never trails")
	W = H.make_world(Moves.DAGGERS, Moves.KATANA, 6.0)
	f = W.fighters[0]
	assert_true(f.start_attack(&"d_shadow"))
	var shadow_on: int = 0
	for row: Dictionary in _drive(W, 30):
		if (row["trail"] as TrailState).on(R):
			shadow_on += 1
	assert_gt(shadow_on, 0, "Shadow Step trails in its active frames")


func test_bare_hands_smear_only_the_moves_switched_on() -> void:
	# a string's punch keeps no smear (milestone-1 task 95 switches on the
	# eight movement attacks only; tasks 89 and 133 can switch theirs on)
	var W: World = H.make_world(Moves.FISTS, Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	f.start_attack(&"f_l2")
	for row: Dictionary in _drive(W, 30):
		var t: TrailState = row["trail"]
		assert_false(t.on(R) or t.on(L), "the fists weapon")
	W = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	f = W.fighters[0]
	f.armed = false
	f.start_attack(&"f_l2")
	for row: Dictionary in _drive(W, 30):
		var t: TrailState = row["trail"]
		assert_false(t.on(R) or t.on(L), "a disarmed fighter")


## Bare hands' eight movement attacks smear along the striking fist, knee or
## foot (task 95), on its side's smear, fainter on the lights.
const LIMBS: Dictionary[StringName, Array] = {
	&"f_sl": [R, &"right_knee"], &"f_sh": [R, &"right_foot"], &"f_dl": [L, &"left_hand"], &"f_dh": [R, &"right_hand"],
	&"f_bl": [L, &"left_foot"], &"f_bh": [R, &"right_hand"], &"f_jl": [R, &"right_foot"], &"f_jh": [L, &"left_foot"],
}


func test_the_eight_smear_their_striking_limb_fainter_on_the_lights() -> void:
	for id: StringName in LIMBS:
		var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
		var f: Fighter = W.fighters[0]
		f.armed = false
		assert_true(f.start_attack(id), String(id))
		var def: AttackDef = f.atk.def
		var side: int = LIMBS[id][0]
		var most: float = 0.0
		for row: Dictionary in _drive(W, def.startup + def.active + 4):
			var t: TrailState = row["trail"]
			assert_false(t.on(1 - side), "%s: only the striking side" % id)
			if t.on(side):
				assert_eq(t.limb(side), LIMBS[id][1], "%s: along its %s" % [id, LIMBS[id][1]])
			most = maxf(most, t.intensity(side))
		var want: float = TrailState.BARE_LIGHT if def.kind == &"light" else 1.0
		assert_almost_eq(most, want, 0.001, "%s at full strength %.2f" % [id, want])
	assert_lt(TrailState.BARE_LIGHT, 1.0, "a light's smear is fainter")
	assert_gt(TrailState.BARE_LIGHT, 0.0)


func test_a_blade_names_no_limb() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 6.0)
	var f: Fighter = W.fighters[0]
	f.start_attack(&"k_l1")
	for row: Dictionary in _drive(W, 20):
		assert_eq((row["trail"] as TrailState).limb(R), &"", "the blade smears, not a limb")


func test_nothing_smears_outside_an_attack_or_ultimate() -> void:
	var W: World = H.make_world(Moves.DAGGERS, Moves.KATANA, 6.0)
	for row: Dictionary in _drive(W, 20, func(_i: int) -> RawInput: return H.move(0.0, 1.0)):
		var t: TrailState = row["trail"]
		assert_false(t.on(R) or t.on(L), "walking")


# ------------------------------------------------------------------ the Katana's movement attacks (task 77)

## The Katana's eight movement attacks, re-keyed (milestone-1 tasks 75 and
## 76).
const MOVEMENT: Array[StringName] = [&"k_sl", &"k_sh", &"k_dl", &"k_dh", &"k_bl", &"k_bh", &"k_jl", &"k_jh"]


## Fighter 0 of a Katana world plays movement attack `id` (a jump attack out
## of a jump, pressed on its third step) through its last active frame and
## the fade, out of the other's reach (Leaping Cleave touches from 5.8 m);
## the rows as _drive()'s.
func _movement(id: StringName) -> Array[Dictionary]:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 12.0)
	var def: AttackDef = Moves.KATANA.moves[id]
	var jump: bool = def.airborne
	if not jump:
		assert_true(W.fighters[0].start_attack(id), String(id))
	var press: Callable = func(i: int) -> RawInput:
		if jump and i == 0:
			return H.move(0.0, 0.0, Btn.JUMP)
		if jump and i == 3:
			return H.move(0.0, 0.0, Btn.LIGHT if def.kind == &"light" else Btn.HEAVY)
		return H.idle()
	return _drive(W, def.startup + def.active + 8, press)


## Each of the eight smears its blade, pale, in its strike (task 77, the
## owner's answer of Oct 8: the air smears stay as task 37 made them), the
## one blade only, and from its circle's start for Whirl Cut.
func test_the_katana_s_eight_movement_attacks_each_smear_their_blade() -> void:
	for id: StringName in MOVEMENT:
		var def: AttackDef = Moves.KATANA.moves[id]
		var from: int = def.smear_from if def.smear_from != AttackDef.UNSET else def.startup
		var on: int = 0
		var thrown: bool = false
		for row: Dictionary in _movement(id):
			if row["state"] != &"attack" or (row["frame"] as int) < 1:
				continue
			thrown = true
			var t: TrailState = row["trail"]
			var frame: int = row["frame"]
			assert_false(t.on(L), "%s: one blade" % id)
			assert_eq(t.kind, TrailState.NORMAL, "%s: a pale sheen" % id)
			assert_eq(t.limb(R), &"", "%s: the blade, not a limb" % id)
			if frame > from and frame <= def.startup + def.active:
				assert_eq(t.intensity(R), 1.0, "%s frame %d: smears" % [id, frame])
				on += 1
			elif frame <= from:
				assert_false(t.on(R), "%s frame %d: not yet" % [id, frame])
		assert_true(thrown, "%s was thrown" % id)
		assert_eq(on, def.startup + def.active - from, "%s smears through its strike" % id)


## The blade tip's heading round the fighter on swing frame `f` (degrees).
static func _heading(def: AttackDef, f: int) -> float:
	var tip: V3 = def.swing.tick(&"right_hand", f).place(Swing.strike_segment(&"right_hand", Moves.KATANA).tip)
	return rad_to_deg(atan2(tip.x, tip.z))


## Whirl Cut's smear runs the full circle (task 77): from the frame its
## blade passes the front to come round once more, through the strike, the
## blade sweeps at least a whole turn, every frame of it smearing; a smear
## from the strike alone would show a sliver of it.
func test_whirl_cut_s_smear_runs_the_full_circle() -> void:
	var def: AttackDef = Moves.KATANA.moves[&"k_dh"]
	assert_ne(def.smear_from, AttackDef.UNSET, "Whirl Cut smears from its own frame")
	assert_lt(def.smear_from, def.startup, "before its strike")
	var swept: float = 0.0
	var strike: float = 0.0
	for f: int in range(def.smear_from + 1, def.startup + def.active + 1):
		var turn: float = absf(wrapf(_heading(def, f) - _heading(def, f - 1), -180.0, 180.0))
		swept += turn
		if f > def.startup:
			strike += turn
	assert_gte(swept, 360.0, "the smear sweeps the whole circle (%.0f degrees)" % swept)
	assert_lt(strike, 180.0, "where its strike alone sweeps %.0f degrees" % strike)
	# no other move smears before its strike
	for id: StringName in Moves.KATANA.moves:
		if id != &"k_dh":
			assert_eq(Moves.KATANA.moves[id].smear_from, AttackDef.UNSET, String(id))
