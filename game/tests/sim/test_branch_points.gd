extends GutTest
## Follow-ups and dodge cancels open at markers (milestone-1 task 20): a
## follow-up starts at its branch point, from the frame-data table, or at once
## when pressed later inside its window, and none starts outside it; a dodge
## cancel opens and closes at the table's window. Right Cut is given made-up
## windows here, apart from today's formula (the end of the active frames plus
## two), so the tests can tell the table's from it.

const H := preload("res://tests/sim/sim_helpers.gd")
## Right Cut's made-up windows, after its active frames (29-32): its Return
## Cut from frame 36 to 42, a dodge cancel from 38 to 42 (the move lasts 60
## frames, task 31).
const BRANCH: int = 36
const LAST: int = 42
const DODGE_FROM: int = 38

var _saved: Dictionary = {}


func before_each() -> void:
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	_saved = {"branches": cut.branches.duplicate(), "from": cut.dodge_cancel_from, "to": cut.dodge_cancel_to}
	cut.branches[&"k_l2"] = PackedInt32Array([BRANCH, LAST])
	cut.dodge_cancel_from = DODGE_FROM
	cut.dodge_cancel_to = LAST


func after_each() -> void:
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	cut.branches = _saved["branches"]
	cut.dodge_cancel_from = _saved["from"]
	cut.dodge_cancel_to = _saved["to"]
	H.dispose_all()


## Fighter 0 starts Right Cut and presses `b` (none for -1) on its attack
## frame `on`, 10 m from an idle opponent; what it did each step, as
## [state, move id, attack frame].
func _play(b: int, on: int, gap: float = 10.0) -> Array[Array]:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, gap)
	var f: Fighter = W.fighters[0]
	var out: Array[Array] = []
	for i: int in 90:
		var input: RawInput = H.idle()
		if i == 0:
			input = H.btn(Btn.LIGHT)
		elif b >= 0 and f.state == &"attack" and f.atk.def.id == &"k_l1" and f.atk.frame == on - 1:
			# pressed on the step that brings the attack to frame `on`
			input = H.btn(b)
		W.step([input, H.idle()])
		out.append([f.state, f.atk.def.id if f.atk != null else &"", f.atk.frame if f.atk != null else -1])
	return out


## The Right Cut frame the next thing started on (the frame after its last
## seen), and what it was: [frame, state, move].
static func _after_cut(steps: Array[Array]) -> Array:
	var last: int = -1
	for s: Array in steps:
		if s[1] == &"k_l1" and s[0] == &"attack":
			last = s[2]
		elif last >= 0:
			return [last + 1, s[0], s[1]]
	return [-1, &"", &""]


## The Right Cut frame the next thing starts on once it plays out.
static func _played_out() -> int:
	return (Moves.KATANA.moves[&"k_l1"] as AttackDef).total_frames()


func test_a_follow_up_pressed_early_starts_at_its_branch_point() -> void:
	assert_eq(_after_cut(_play(Btn.LIGHT, 30)), [BRANCH, &"attack", &"k_l2"], "pressed on frame 30, Return Cut from 36")


func test_a_follow_up_pressed_inside_its_window_starts_at_once() -> void:
	assert_eq(_after_cut(_play(Btn.LIGHT, 39)), [39, &"attack", &"k_l2"])
	assert_eq(_after_cut(_play(Btn.LIGHT, LAST)), [LAST, &"attack", &"k_l2"], "on its last frame")


func test_no_follow_up_starts_outside_its_window() -> void:
	var after: Array = _after_cut(_play(Btn.LIGHT, LAST + 1))
	assert_eq(after[0], _played_out(), "Right Cut plays out")
	assert_ne(after[2], &"k_l2", "no Return Cut")


func test_stopping_after_a_hit_recovers_normally() -> void:
	var steps: Array[Array] = _play(-1, -1, 2.2)
	var after: Array = _after_cut(steps)
	assert_eq([after[0], after[1]], [_played_out(), &"free"], "the whole move, then free")


func test_a_dodge_cancel_opens_and_closes_at_its_window() -> void:
	# the stick left alone: the dodge is a backstep
	assert_eq(_after_cut(_play(Btn.DODGE, DODGE_FROM)), [DODGE_FROM, &"backstep", &""], "at its start")
	assert_eq(_after_cut(_play(Btn.DODGE, LAST)), [LAST, &"backstep", &""], "on its last frame")
	assert_eq(_after_cut(_play(Btn.DODGE, DODGE_FROM - 4)), [DODGE_FROM, &"backstep", &""], "an early press, buffered, waits for it")
	assert_eq(_after_cut(_play(Btn.DODGE, LAST + 1))[0], _played_out(), "none after it")


func test_the_katana_and_bare_hands_follow_ups_open_at_the_tables_branch_points() -> void:
	_restore()
	for w: WeaponDef in [Moves.KATANA, Moves.FISTS]:
		for id: StringName in w.moves:
			var def: AttackDef = w.moves[id]
			var row: Dictionary = FrameDataTable.shared().row(w.id, id)
			for follow: StringName in [def.chain_light, def.chain_heavy]:
				if follow == &"":
					continue
				var want: Array = ((row.get("branches", {}) as Dictionary).get(String(follow), []) as Array).map(func(x: Variant) -> int: return int(x))
				assert_eq(Array(def.branch_window(follow)), want, "%s -> %s" % [id, follow])


func test_a_move_without_a_row_keeps_todays_formula() -> void:
	var moves: Dictionary[StringName, AttackDef] = AttackDef.finalize_moves({&"t_cut": {"id": &"t_cut", "name": "Test Cut",
		"kind": &"light", "type": &"slash", "startup": 10, "active": 3, "recovery": 12, "damage": 5, "posture": 5,
		"chain_light": &"t_next"}})
	assert_eq(moves[&"t_cut"].branch_window(&"t_next"), PackedInt32Array([15, 25]), "the end of the active frames plus two, to its end")


func _restore() -> void:
	var cut: AttackDef = Moves.KATANA.moves[&"k_l1"]
	cut.branches = _saved["branches"]
	cut.dodge_cancel_from = _saved["from"]
	cut.dodge_cancel_to = _saved["to"]
