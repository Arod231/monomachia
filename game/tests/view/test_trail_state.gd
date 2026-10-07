extends GutTest
## The air smears' rules (plan task 18.2's trail rules, kept for milestone-1
## task 37's air smears): when each hand's blade smears, how strongly, and in
## which tint, read from the rules' state. The tests drive a rules World
## through a Katana light, a Greatsword unblockable, a charged heavy and an
## ultimate, and check the owner's choices: only the striking hands, Flash
## off but Shadow Step on, never bare hands, a plain swing's pale sheen, an
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
	for i: int in 60:
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


func test_bare_hands_never_smear() -> void:
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


func test_nothing_smears_outside_an_attack_or_ultimate() -> void:
	var W: World = H.make_world(Moves.DAGGERS, Moves.KATANA, 6.0)
	for row: Dictionary in _drive(W, 20, func(_i: int) -> RawInput: return H.move(0.0, 1.0)):
		var t: TrailState = row["trail"]
		assert_false(t.on(R) or t.on(L), "walking")
