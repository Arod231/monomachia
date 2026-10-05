extends WeaponStringsTest
## The Daggers' new strings (plan task 11): the spec's Twin Daggers table,
## played through the rules. Expected numbers come from the spec, not the
## code.

## The spec's Twin Daggers table, the rows built so far (see
## WeaponStringsTest.rows): all seven.
const ROWS: Dictionary[StringName, Dictionary] = {
	&"d_l1": {
		"name": "Quick Slice", "frames": [7, 2, 13], "damage": 4, "posture": 4,
		"light": &"d_l2", "heavy": &"d_h1", "sides": [&"right", &"left"],
	},
	&"d_l2": {
		"name": "Off-hand Slice", "frames": [7, 2, 13], "damage": 4, "posture": 4,
		"light": &"d_l3", "heavy": &"d_h1", "sides": [&"left", &"right"],
	},
	&"d_l3": {
		"name": "Twin Rip", "frames": [9, 3, 14], "damage": 6, "posture": 5,
		"light": &"d_l4", "heavy": &"", "sides": [&"centre", &"centre"],
	},
	&"d_l4": {
		"name": "Flurry Finisher", "frames": [11, 3, 18], "damage": 7, "posture": 6,
		"light": &"", "heavy": &"d_h2", "sides": [&"centre", &"centre"],
	},
	&"d_h1": {
		"name": "Twin Fang", "frames": [16, 3, 20], "damage": 10, "posture": 9,
		"light": &"", "heavy": &"d_h2", "sides": [&"centre", &"centre"],
	},
	&"d_h2": {
		"name": "Spinning Backhand", "frames": [18, 5, 22], "damage": 12, "posture": 10,
		"light": &"", "heavy": &"", "sides": [&"centre", &"centre"],
	},
	# out of a dodge, in no string
	&"d_dl": {
		"name": "Passing Cut", "frames": [6, 2, 12], "damage": 5, "posture": 4,
		"light": &"", "heavy": &"", "sides": [&"", &""],
	},
}

## The four lights, in the order the string plays them.
const LIGHTS: Array[StringName] = [&"d_l1", &"d_l2", &"d_l3", &"d_l4"]

## Twin Fang, a dashing double stab, lunges 1.4 m (the spec's table).
const TWIN_FANG_LUNGE: float = 1.4
## Fighters this far apart (m, the plan's notes) leave a lunge room to run its
## whole length: it stops short only 0.25 m from the defender's body.
const FULL_LUNGE_GAP: float = 4.0

## Passing Cut lunges 1.2 m (the plan's notes) on along the dodge before it.
const PASSING_CUT_LUNGE: float = 1.2
## The stick pushed right, left and forward, for a dodge that way.
const STICK_RIGHT: Vector2 = Vector2(1.0, 0.0)
const STICK_LEFT: Vector2 = Vector2(-1.0, 0.0)
const STICK_FORWARD: Vector2 = Vector2(0.0, 1.0)
## Fighter 0 starts facing +z, toward the defender, so its right is -x.
const RIGHT: Vector2 = Vector2(-1.0, 0.0)
## Fighters this far apart (m) leave a forward dodge (3.36 m for the Daggers)
## clear of the defender, and too little room after it for Passing Cut's 1.2 m.
const FORWARD_DODGE_GAP: float = 5.0
## A light up to 12 frames after a dodge ends is still a dodge attack (the
## spec).
const FOLLOW_WINDOW: int = 12
## A fighter's radius (m), and how far apart a lunge stops the bodies (the
## spec's).
const BODY_RADIUS: float = 0.42
const LUNGE_GAP: float = 0.25
## How near a lunge comes to the defender's centre.
const LUNGE_STOP: float = 2.0 * BODY_RADIUS + LUNGE_GAP
## Steps between a backstep and a later dodge: past the backstep's 23 frames
## and the 12 after it.
const LATER: int = 60


func _init() -> void:
	weapon = Moves.DAGGERS
	rows = ROWS


## The spec's first active frame of move id: startup + 1.
func _first_active_frame(id: StringName) -> int:
	return rows[id]["frames"][0] + 1


## The spec's first recovery frame of move id, the frame after its last
## active one: startup + active + 1.
func _first_recovery_frame(id: StringName) -> int:
	var frames: Array = rows[id]["frames"]
	return frames[0] + frames[1] + 1


## n light presses.
static func _lights(n: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(n)
	out.fill(Btn.LIGHT)
	return out


# ------------------------------------------------------------------ the light string

func test_four_lights_alternate_hands_right_left_both_both() -> void:
	var hits: Array[StringName] = _play(_lights(4)).ids(&"hit")
	assert_eq(hits, LIGHTS, "Quick Slice, Off-hand Slice, Twin Rip, Flurry Finisher")
	var hands: Array[StringName] = []
	for id: StringName in hits:
		hands.append(weapon.moves[id].hand)
	assert_eq(hands, [&"R", &"L", &"both", &"both"] as Array[StringName], "right hand, left hand, both, both")


func test_a_heavy_after_one_or_two_lights_is_twin_fang() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	assert_eq(_play([light, heavy]).ids(&"hit"), [&"d_l1", &"d_h1"] as Array[StringName], "L-H: Quick Slice, Twin Fang")
	assert_eq(
		_play([light, light, heavy]).ids(&"hit"),
		[&"d_l1", &"d_l2", &"d_h1"] as Array[StringName],
		"L-L-H: Off-hand Slice, Twin Fang",
	)


func test_a_heavy_in_twin_rip_starts_nothing() -> void:
	_assert_starts_nothing_in(_lights(3), LIGHTS.slice(0, 3), [Btn.HEAVY])


func test_a_light_in_twin_fang_starts_nothing() -> void:
	# the demo's light follow-up looped back to Quick Slice
	_assert_starts_nothing_in([Btn.HEAVY], [&"d_h1"], [Btn.LIGHT])


func test_stopping_after_any_hit_ends_the_string_when_that_move_ends() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	var strings: Array = [
		[light], [light, light], [light, light, light], [light, light, light, light],
		[light, heavy], [light, light, heavy], [heavy],
		[heavy, heavy], [light, heavy, heavy], [light, light, heavy, heavy], [light, light, light, light, heavy],
	]
	for presses: Array in strings:
		var typed: Array[int] = []
		typed.assign(presses)
		_assert_stops_after(typed)


# ------------------------------------------------------------------ Twin Fang and Spinning Backhand

func test_twin_fang_dashes_about_1_4_m() -> void:
	var r: PlayedString = _play([Btn.HEAVY], FULL_LUNGE_GAP)
	var start: int = r.attack.find(&"d_h1")
	assert_gt(start, -1, "Twin Fang starts")
	if start < 0:
		return
	assert_almost_eq(r.walked(start, r.attack.rfind(&"d_h1") + 1), TWIN_FANG_LUNGE, CLOSE, "a 1.4 m dash")


func test_a_heavy_after_twin_fang_or_flurry_finisher_is_spinning_backhand() -> void:
	var light: int = Btn.LIGHT
	var heavy: int = Btn.HEAVY
	assert_eq(
		_play([heavy, heavy]).ids(&"hit"),
		[&"d_h1", &"d_h2"] as Array[StringName],
		"H-H: Twin Fang, Spinning Backhand",
	)
	assert_eq(
		_play([light, light, light, light, heavy]).ids(&"hit"),
		[&"d_l1", &"d_l2", &"d_l3", &"d_l4", &"d_h2"] as Array[StringName],
		"L-L-L-L-H: Flurry Finisher, Spinning Backhand",
	)


func test_spinning_backhand_ends_the_string() -> void:
	_assert_starts_nothing_in([Btn.HEAVY, Btn.HEAVY], [&"d_h1", &"d_h2"], LIGHT_OR_HEAVY)


# ------------------------------------------------------------------ Passing Cut

## Checks that got, how far an attack moved fighter 0 over the ground, is
## want (each part within CLOSE).
func _assert_moved(got: Vector2, want: Vector2, what: String) -> void:
	assert_almost_eq(got.x, want.x, CLOSE, "%s (x)" % what)
	assert_almost_eq(got.y, want.y, CLOSE, "%s (z)" % what)


func test_a_light_out_of_a_dodge_to_the_right_is_passing_cut_carrying_on_1_2_m_to_the_right() -> void:
	var r: PlayedString = _out_of_a_dodge(Btn.LIGHT, Callable(), STICK_RIGHT, WHIFF_GAP)
	assert_eq(r.ids(&"swing"), [&"d_dl"] as Array[StringName], "Passing Cut")
	_assert_moved(r.displacement(&"d_dl"), RIGHT * PASSING_CUT_LUNGE, "1.2 m on to the right")


func test_out_of_a_dodge_to_the_left_passing_cut_carries_on_to_the_left() -> void:
	var r: PlayedString = _out_of_a_dodge(Btn.LIGHT, Callable(), STICK_LEFT, WHIFF_GAP)
	_assert_moved(r.displacement(&"d_dl"), -RIGHT * PASSING_CUT_LUNGE, "1.2 m on to the left")


func test_on_the_follow_windows_last_frame_passing_cut_still_runs_along_the_dodge() -> void:
	var r: PlayedString = _out_of_a_dodge(Btn.LIGHT, Callable(), STICK_RIGHT, WHIFF_GAP, FOLLOW_WINDOW)
	assert_eq(r.ids(&"swing"), [&"d_dl"] as Array[StringName], "still Passing Cut")
	_assert_moved(r.displacement(&"d_dl"), RIGHT * PASSING_CUT_LUNGE, "still 1.2 m on to the right")


func test_passing_cut_runs_along_the_latest_dodge() -> void:
	# a backstep (straight back, so the defender stays dead ahead), then, well
	# after it, a dodge to the right and a light
	var right_after: Callable = _dodge_then(Btn.LIGHT, STICK_RIGHT, WHIFF_GAP)
	var p0: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.DODGE) if i == 0 else right_after.call(i - LATER)
	var r: PlayedString = _run(p0, WHIFF_GAP)
	assert_eq(r.ids(&"swing"), [&"d_dl"] as Array[StringName], "Passing Cut")
	_assert_moved(r.displacement(&"d_dl"), RIGHT * PASSING_CUT_LUNGE, "1.2 m on to the right")


func test_after_a_forward_dodge_passing_cut_stops_0_25_m_short_of_the_defender() -> void:
	var r: PlayedString = _out_of_a_dodge(Btn.LIGHT, Callable(), STICK_FORWARD, FORWARD_DODGE_GAP)
	var start: int = r.attack.find(&"d_dl")
	assert_gt(start, 0, "Passing Cut starts")
	if start <= 0:
		return
	assert_almost_eq(r.closest(start, r.attack.rfind(&"d_dl") + 1), LUNGE_STOP, 1e-9, "stopped with the bodies 0.25 m apart")
	assert_lt(r.displacement(&"d_dl").length(), PASSING_CUT_LUNGE, "short of its 1.2 m")


func test_a_defender_across_its_path_holds_back_only_the_part_closing_on_them() -> void:
	var W: World = H.make_world(weapon, Moves.KATANA, WHIFF_GAP)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var r := PlayedString.new()
	r.step(W, H.move(STICK_RIGHT.x, STICK_RIGHT.y, Btn.DODGE))
	while a.state != &"free" and r.state.size() < STEPS:
		r.step(W, H.idle())
	# the defender 1.2 m away, off the cut's path to the right: 0.6 of each
	# step of the cut closes on them, which leaves it 0.11 m of room, and 0.8
	# runs across the line to them, which nothing holds back
	var off: Vector2 = Vector2(-0.6, -0.8) * 1.2
	b.pos = V3.make(a.pos.x + off.x, 0.0, a.pos.z + off.y)
	r.step(W, H.btn(Btn.LIGHT))
	for i: int in 30:
		r.step(W, H.idle())
	var start: int = r.attack.find(&"d_dl")
	assert_gt(start, 0, "Passing Cut starts")
	if start <= 0:
		return
	var end: int = r.attack.rfind(&"d_dl") + 1
	assert_gt(r.walked(start, end), 0.8 * PASSING_CUT_LUNGE, "it runs on across their path: at least 0.8 of 1.2 m")
	assert_gt(r.closest(start, end), LUNGE_STOP - 1e-9, "never nearer than 0.25 m to their body")


## Plays Passing Cut out of a dodge with the stick at stick, gap m from the
## defender, pressing dodge again so that it first counts on the cut's frame
## pressed, with the stick held to the right from then on (a buffered dodge
## with the stick let go is a backstep).
func _passing_cut_then_dodge_on(stick: Vector2, gap: float, pressed: int) -> PlayedString:
	var W: World = H.make_world(weapon, Moves.KATANA, gap)
	var a: Fighter = W.fighters[0]
	var p0: Callable = _dodge_then(Btn.LIGHT, stick, gap)
	var r := PlayedString.new()
	var dodged: bool = false
	for i: int in STEPS:
		var input: RawInput = p0.call(i)
		if dodged:
			input = H.move(STICK_RIGHT.x, STICK_RIGHT.y)
		elif a.state == &"attack" and a.atk.def.id == &"d_dl" and a.atk.frame == pressed - 1:
			input = H.move(STICK_RIGHT.x, STICK_RIGHT.y, Btn.DODGE)
			dodged = true
		r.step(W, input)
	return r


func test_passing_cut_dodge_cancels_from_its_first_recovery_frame_after_a_hit_and_after_a_whiff() -> void:
	# out of a forward dodge it hits; out of one to the right, far away, it
	# whiffs. A dodge pressed in its active frames waits in the input buffer
	# (over a hit's hit-stop too)
	var cancel: int = _first_recovery_frame(&"d_dl")
	var ways: Array = [[STICK_FORWARD, FORWARD_DODGE_GAP, "after a hit"], [STICK_RIGHT, WHIFF_GAP, "after a whiff"]]
	for way: Array in ways:
		for pressed: int in [_first_active_frame(&"d_dl"), cancel - 1, cancel]:
			var r: PlayedString = _passing_cut_then_dodge_on(way[0], way[1], pressed)
			var hits: Array[StringName] = []
			if way[2] == "after a hit":
				hits.append(&"d_dl")
			assert_eq(r.ids(&"hit"), hits, "%s: it %s" % [way[2], "hits" if hits.size() > 0 else "whiffs"])
			assert_eq(
				[r.ended_on(&"d_dl"), r.state_after(&"d_dl")],
				[cancel, &"dodge"],
				"%s: a dodge pressed on frame %d comes on %d" % [way[2], pressed, cancel],
			)


# ------------------------------------------------------------------ dodge cancels

func test_each_light_dodge_cancels_from_its_first_recovery_frame() -> void:
	# a dodge pressed in its active frames, from the first, waits in the input
	# buffer (over a hit's hit-stop too) and comes on that frame
	for n: int in LIGHTS.size():
		var id: StringName = LIGHTS[n]
		_assert_dodge_cancels_from(_lights(n + 1), id, _first_recovery_frame(id), [_first_active_frame(id)])


# ------------------------------------------------------------------ hitstun

func test_a_defender_pressing_block_as_hitstun_ends_parries_off_hand_slice() -> void:
	var probe: PlayedString = _play(_lights(2))
	var hits: Array[Dictionary] = probe.by_fighter_0(&"hit")
	assert_eq(probe.ids(&"hit"), LIGHTS.slice(0, 2), "an idle defender takes both slices")
	if hits.size() != 2:
		return
	var free_step: int = -1
	for i: int in range(hits[0]["step"], probe.defender_state.size()):
		if probe.defender_state[i] != &"hitstun":
			free_step = i
			break
	# Off-hand Slice lands 11 frames after Quick Slice (the plan's notes), so
	# the string's hitstun leaves the defender one free step before it
	assert_eq(free_step, hits[1]["step"] - 1, "out of hitstun for one step before Off-hand Slice lands")
	# pressing block a step before hitstun ends: the press waits in the buffer
	var r: PlayedString = _play_against(_lights(2), H.tap_at(free_step - 1, Btn.BLOCK))
	assert_eq(r.ids(&"hit"), LIGHTS.slice(0, 1), "only Quick Slice lands")
	var parries: Array[Dictionary] = r.all(&"parry")
	assert_eq(parries.size(), 1, "Off-hand Slice is parried")
	if parries.size() == 1:
		assert_eq([parries[0]["kind"], parries[0]["parrier"]], [&"parry", 1], "a plain parry, by the defender")
	assert_true(r.state.has(&"recoil"), "and the attacker recoils")


# ------------------------------------------------------------------ the spec's table

func test_the_rows_built_so_far_match_the_spec_table() -> void:
	_assert_rows_match_the_spec()
