extends GutTest
## Swing data (task 7.2): the per-weapon swing files load into each move's
## swing, and a bad file is refused whole, with an error.

const EPS: float = 1e-12
const FIXTURE: String = "res://tests/fixtures/swings/swing_test.json"
const R2: float = 0.7071067811865475 # 1 / sqrt(2)


## Two synthetic moves of 12 frames (4 / 2 / 6) and a third with no swing.
static func _moves() -> Dictionary[StringName, AttackDef]:
	var base: Dictionary = {"kind": &"light", "type": &"slash", "startup": 4, "active": 2, "recovery": 6, "damage": 5, "posture": 5}
	var records: Dictionary = {}
	for id: StringName in [&"t_cut", &"t_stabs", &"t_plain"]:
		var r: Dictionary = base.duplicate()
		r["id"] = id
		r["name"] = String(id)
		records[id] = r
	return AttackDef.finalize_moves(records)


func _assert_v3(v: V3, x: float, y: float, z: float, what: String) -> void:
	assert_almost_eq(v.x, x, EPS, "%s.x" % what)
	assert_almost_eq(v.y, y, EPS, "%s.y" % what)
	assert_almost_eq(v.z, z, EPS, "%s.z" % what)


func test_a_swing_file_loads_into_its_keys() -> void:
	var swings: Dictionary[StringName, Swing] = SwingFile.read(FIXTURE, _moves())
	assert_eq(swings.keys(), [&"t_cut", &"t_stabs"], "one swing per move in the file")
	var cut: Swing = swings[&"t_cut"]
	assert_eq(cut.parts(), [&"right_hand", &"body"] as Array[StringName], "the tracks, in the file's order")

	var hand: Array[Swing.KeyPose] = cut.track(&"right_hand")
	assert_eq(hand.size(), 3)
	assert_eq(hand[0].frame, 0)
	_assert_v3(hand[0].grip, 0.1, 1.1, 0.35, "grip 0")
	_assert_v3(hand[0].blade, 0.0, 0.6, 0.8, "blade 0 is unit length")
	_assert_v3(hand[0].edge, 0.0, 0.8, -0.6, "edge 0 is squared onto the blade")
	_assert_v3(hand[0].pole, 0.0, 0.0, 0.0, "no pole tweak")
	assert_eq(hand[0].ease, 0.0)
	assert_eq(hand[1].frame, 4)
	_assert_v3(hand[1].pole, 0.1, 0.2, -0.05, "pole 1")
	assert_eq(hand[1].ease, 1.0, "ease defaults to 1")
	assert_eq(hand[2].frame, 12, "a key may sit on the move's last frame")
	_assert_v3(hand[2].blade, -R2, -R2, 0.0, "blade 2")
	_assert_v3(hand[2].edge, R2, -R2, 0.0, "edge 2")

	var body: Array[Swing.KeyPose] = cut.track(&"body")
	assert_eq(body.size(), 2)
	assert_eq([body[0].torso, body[0].pelvis], [0.0, 0.0])
	_assert_v3(body[0].pelvis_shift, 0.0, 0.0, 0.0, "no pelvis shift")
	assert_eq([body[1].frame, body[1].torso, body[1].pelvis, body[1].ease], [4, 50.0, 25.0, 0.0])
	_assert_v3(body[1].pelvis_shift, 0.0, -0.05, -0.12, "pelvis shift 1")

	var stabs: Swing = swings[&"t_stabs"]
	assert_eq(stabs.parts(), [&"left_hand", &"right_hand"] as Array[StringName])
	assert_eq(stabs.track(&"left_hand")[0].frame, 2)
	assert_eq(stabs.track(&"body"), [] as Array[Swing.KeyPose], "no body track")


func test_the_weapons_guard_loads_and_its_swings_share_it() -> void:
	var swings: Dictionary[StringName, Swing] = SwingFile.read(FIXTURE, _moves())
	var guard: Dictionary[StringName, Swing.KeyPose] = swings[&"t_cut"].guard
	assert_eq(guard.keys(), [&"right_hand", &"left_hand", &"body"])
	_assert_v3(guard[&"right_hand"].grip, 0.05, 1.1, 0.3, "right grip")
	_assert_v3(guard[&"right_hand"].blade, 0.0, 0.6, 0.8, "right blade")
	_assert_v3(guard[&"right_hand"].edge, 0.0, 0.8, -0.6, "right edge")
	_assert_v3(guard[&"left_hand"].pole, 0.0, -0.1, 0.0, "left pole")
	assert_eq([guard[&"body"].torso, guard[&"body"].pelvis], [5.0, 10.0], "the guard's coil")
	assert_same(swings[&"t_stabs"].guard, guard, "one guard for the weapon")


func test_attach_puts_each_swing_on_its_move() -> void:
	var moves: Dictionary[StringName, AttackDef] = _moves()
	SwingFile.attach(FIXTURE, moves)
	assert_eq(moves[&"t_cut"].swing.parts(), [&"right_hand", &"body"] as Array[StringName], "t_cut")
	assert_eq(moves[&"t_stabs"].swing.parts(), [&"left_hand", &"right_hand"] as Array[StringName], "t_stabs")
	assert_null(moves[&"t_plain"].swing, "a move the file leaves out has no swing")


func test_a_weapon_without_a_swing_file_has_no_swings() -> void:
	var moves: Dictionary[StringName, AttackDef] = _moves()
	SwingFile.attach("res://tests/fixtures/swings/no_such_weapon.json", moves)
	for id: StringName in moves:
		assert_null(moves[id].swing, String(id))


func test_a_move_record_can_carry_a_swing() -> void:
	var swing: Swing = Swing.new()
	var moves: Dictionary[StringName, AttackDef] = AttackDef.finalize_moves({
		&"t_cut": {"id": &"t_cut", "name": "Test Cut", "kind": &"light", "startup": 4, "active": 2, "recovery": 6, "swing": swing},
	})
	assert_same(moves[&"t_cut"].swing, swing)


## A valid file for t_cut (12 frames: 4 / 2 / 6), as data to spoil one field
## at a time.
static func _good() -> Dictionary:
	return {
		"guard": {
			"right_hand": {"grip": [0.05, 1.1, 0.3], "blade": [0, 1, 0], "edge": [1, 0, 0]},
			"body": {"torso": 0, "pelvis": 0},
		},
		"swings": {"t_cut": {"tracks": {
			"right_hand": [
				{"frame": 0, "grip": [0.1, 1.1, 0.35], "blade": [0, 1, 0], "edge": [1, 0, 0]},
				{"frame": 6, "grip": [0.0, 1.2, 0.5], "blade": [0, 0, 1], "edge": [0, -1, 0], "ease": 0},
			],
			"body": [{"frame": 0, "torso": 0, "pelvis": 0}],
		}}},
	}


## Parses `data` as a swing file, expecting it refused with an error holding
## `fragment` (any other error fails the test).
func _assert_refused(data: Variant, fragment: String, what: String) -> void:
	var text: String = data if data is String else JSON.stringify(data)
	var swings: Dictionary[StringName, Swing] = SwingFile.parse(text, _moves(), "bad.json")
	assert_eq(swings.size(), 0, "%s: refused" % what)
	assert_push_error(fragment, what)


func test_the_good_file_is_accepted() -> void:
	assert_eq(SwingFile.parse(JSON.stringify(_good()), _moves(), "good.json").keys(), [&"t_cut"])


func test_unsorted_keys_are_refused() -> void:
	var d: Dictionary = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"].reverse()
	_assert_refused(d, "bad.json: t_cut.right_hand key 1 (frame 0): keys are unsorted", "reversed keys")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][1]["frame"] = 0
	_assert_refused(d, "keys are unsorted", "two keys on one frame")


func test_frames_outside_the_move_are_refused() -> void:
	var d: Dictionary = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][1]["frame"] = 13
	_assert_refused(d, "t_cut.right_hand key 1 (frame 13): frame is past the move, whose last frame is 12", "frame 13")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["body"][0]["frame"] = -1
	_assert_refused(d, "t_cut.body key 0 (frame -1): frame is negative", "frame -1")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0]["frame"] = 2.5
	_assert_refused(d, "t_cut.right_hand key 0: frame must be a whole number", "frame 2.5")


func test_unknown_fields_are_refused() -> void:
	var d: Dictionary = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0]["grips"] = [0, 1, 0]
	_assert_refused(d, "t_cut.right_hand key 0: unknown field grips", "a misspelt key field")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0]["torso"] = 10
	_assert_refused(d, "t_cut.right_hand key 0: unknown field torso", "a body field on a hand key")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["body"][0]["grip"] = [0, 1, 0]
	_assert_refused(d, "t_cut.body key 0: unknown field grip", "a hand field on a body key")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["tail"] = d["swings"]["t_cut"]["tracks"]["body"]
	_assert_refused(d, "t_cut.tail: unknown part", "an unknown part")
	d = _good()
	d["swings"]["t_cut"]["speed"] = 2
	_assert_refused(d, "t_cut: unknown field speed", "an unknown swing field")
	d = _good()
	d["swings"]["t_nope"] = d["swings"]["t_cut"]
	_assert_refused(d, "t_nope: not a move of this weapon", "an unknown move")


func test_other_mistakes_are_refused() -> void:
	var d: Dictionary = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0].erase("grip")
	_assert_refused(d, "t_cut.right_hand key 0: missing grip", "no grip")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["body"][0].erase("pelvis")
	_assert_refused(d, "t_cut.body key 0: missing pelvis", "no pelvis coil")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0]["grip"] = [0.1, 1.1]
	_assert_refused(d, "grip must be three numbers", "a short vector")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0]["pole"] = [0, "up", 0]
	_assert_refused(d, "pole must be three numbers", "a vector with a word in it")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["body"][0]["torso"] = "40"
	_assert_refused(d, "torso must be a number", "a coil written as text")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0]["blade"] = [0, 0, 0]
	_assert_refused(d, "blade has no direction", "a zero blade")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0]["edge"] = [0, -2, 0]
	_assert_refused(d, "edge runs along the blade", "an edge along the blade")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][1]["ease"] = -0.5
	_assert_refused(d, "ease must not be negative", "a negative ease")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["body"] = []
	_assert_refused(d, "t_cut.body: a track must be a list of keys", "an empty track")
	d = _good()
	d["swings"]["t_cut"]["tracks"] = {}
	_assert_refused(d, "t_cut: needs tracks", "no tracks")
	_assert_refused("[]", "the file must be an object holding guard and swings", "a list for a file")
	_assert_refused("{\"t_cut\": ", "bad.json: line", "broken JSON")


func test_guard_mistakes_are_refused() -> void:
	var d: Dictionary = _good()
	d.erase("guard")
	_assert_refused(d, "bad.json: needs a guard, an object of parts", "no guard")
	d = _good()
	d.erase("swings")
	_assert_refused(d, "bad.json: needs swings, an object of moves", "no swings")
	d = _good()
	d["guard"].erase("body")
	_assert_refused(d, "t_cut.body: the guard has no body for the entry and exit", "a part the guard lacks")
	d = _good()
	d["guard"]["right_hand"]["frame"] = 0
	_assert_refused(d, "guard.right_hand: unknown field frame", "a guard key with a frame")
	d = _good()
	d["guard"]["right_hand"].erase("edge")
	_assert_refused(d, "guard.right_hand: missing edge", "a guard key without an edge")
	d = _good()
	d["guard"]["tail"] = d["guard"]["body"]
	_assert_refused(d, "guard.tail: unknown part", "an unknown guard part")
	d = _good()
	d["notes"] = "hi"
	_assert_refused(d, "bad.json: unknown field notes", "an unknown top-level field")


## A track that strikes is keyed from the last startup frame through the last
## active frame, so the frames that sweep for hits never depend on the entry.
func test_a_striking_track_must_key_the_frames_that_can_hit() -> void:
	var d: Dictionary = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][0]["frame"] = 5
	_assert_refused(d, "t_cut.right_hand: the first key is at frame 5; it must be at frame 4 or before", "a track starting in the active frames")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["right_hand"][1]["frame"] = 5
	_assert_refused(d, "t_cut.right_hand: the last key is at frame 5; it must be at frame 6 or after", "a track ending in the active frames")
	d = _good()
	d["swings"]["t_cut"]["tracks"]["body"][0]["frame"] = 9
	assert_eq(SwingFile.parse(JSON.stringify(d), _moves(), "good.json").keys(), [&"t_cut"], "the body track may start late")


func test_one_mistake_refuses_the_whole_file() -> void:
	var d: Dictionary = _good()
	d["swings"]["t_stabs"] = {"tracks": {"right_hand": [{"frame": 99, "grip": [0, 1, 0], "blade": [0, 0, 1], "edge": [0, -1, 0]}]}}
	var path: String = "user://swing_test_one_mistake.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var moves: Dictionary[StringName, AttackDef] = _moves()
	SwingFile.attach(path, moves)
	assert_push_error("t_stabs.right_hand key 0 (frame 99): frame is past the move")
	assert_null(moves[&"t_cut"].swing, "t_cut's good swing isn't loaded either")
	assert_null(moves[&"t_stabs"].swing)
	DirAccess.remove_absolute(path)


## Each weapon's moves carry exactly the swings in its file, read without an
## error. No weapon has a file until task 7.17 gives the Katana's lights theirs.
func test_each_weapon_carries_the_swings_in_its_file() -> void:
	for wid: StringName in Moves.WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[wid]
		var path: String = SwingFile.path_for(wid)
		assert_eq(path, "res://sim/moves/swings/%s.json" % wid)
		var in_file: Dictionary[StringName, Swing] = {}
		if FileAccess.file_exists(path):
			in_file = SwingFile.read(path, w.moves)
		for id: StringName in w.moves:
			assert_eq(w.moves[id].swing != null, in_file.has(id), "%s.%s has a swing only if its file gives it one" % [wid, id])
			if in_file.has(id):
				assert_eq(w.moves[id].swing.parts(), in_file[id].parts(), "%s.%s" % [wid, id])
