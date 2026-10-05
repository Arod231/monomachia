extends GutTest
## The move-clip table (MoveClips): committed data that needs no packs. Each
## weapon's guard clip and each fitted move's clips and speed, checked
## against the rules' moves and the clip manifest.

const TEMP: String = "user://move_clips_test.json"


func _read(data: Dictionary) -> MoveClips:
	var f: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var t: MoveClips = MoveClips.read(ClipManifest.read(), TEMP)
	DirAccess.remove_absolute(TEMP)
	return t


func test_the_table_reads_cleanly() -> void:
	var t: MoveClips = MoveClips.read(ClipManifest.read())
	assert_eq(t.errors, PackedStringArray(), "no mistakes in the table")
	for wid: StringName in Moves.WEAPONS:
		assert_true(t.guards.has(wid), "%s has a guard clip" % wid)


func test_a_fitted_move_reads_its_clips_and_speed() -> void:
	var t: MoveClips = _read({"katana": {"guard": "CombatIdle1H01", "moves": {
		"k_l1": {"clips": ["Attack1H01_R"], "speed": 1.4},
		"k_iai": {"clips": ["CombatIdle1H01", "Attack1H01_R"]},
	}}})
	assert_eq(t.errors, PackedStringArray())
	var e: MoveClips.Entry = t.of(&"katana")[&"k_l1"]
	assert_eq(e.clips, [&"Attack1H01_R"] as Array[StringName])
	assert_eq(e.speed, 1.4)
	assert_true(is_nan((t.of(&"katana")[&"k_iai"] as MoveClips.Entry).speed), "no speed: the bake picks it")
	assert_eq(t.of(&"greatsword"), {}, "a weapon not in the file has no moves")


func test_a_chains_markers_run_from_its_start() -> void:
	var m: ClipManifest = ClipManifest.read()
	var e: MoveClips.Entry = MoveClips.Entry.new()
	e.clips.assign([&"CombatIdle1H01", &"Attack1H01_R"])
	var markers: Dictionary = MoveClips.markers(e, m, PackedFloat64Array([40.0, 31.0]))
	var first: ClipManifest.Clip = m.clips[&"CombatIdle1H01"]
	var last: ClipManifest.Clip = m.clips[&"Attack1H01_R"]
	assert_eq(markers["windup"], float(first.markers["windup"]), "the first clip's wind-up start")
	for name: String in ["contact", "contact_end", "settle"]:
		assert_eq(markers[name], 40.0 + last.markers[name], "the last clip's %s, after the first clip's 40 frames" % name)


func test_a_moves_own_marks_stand_in_for_the_manifests() -> void:
	var t: MoveClips = _read({"katana": {"guard": "CombatIdle1H01", "moves": {
		"k_l3": {"clips": ["Attack2H01"], "speed": 1.3, "marks": {"windup": 8, "contact": 15, "contact_end": 17, "settle": 28}},
	}}})
	assert_eq(t.errors, PackedStringArray())
	var e: MoveClips.Entry = t.of(&"katana")[&"k_l3"]
	assert_eq(MoveClips.markers(e, ClipManifest.read(), PackedFloat64Array([48.0])),
		{"windup": 8.0, "contact": 15.0, "contact_end": 17.0, "settle": 28.0}, "the move's own, not Attack2H01's")


func test_a_chain_of_parts_and_its_sheathed_frames_read() -> void:
	var t: MoveClips = _read({"katana": {"guard": "CombatIdle1H01", "moves": {
		"k_iai": {"clips": ["SheatheHips01_R@3-12", "Attack1H04_R@2"], "speed": 1.3, "sheathed": [8, 9],
			"marks": {"windup": 0, "hold": 9, "contact": 18, "contact_end": 21, "settle": 36}},
	}}})
	assert_eq(t.errors, PackedStringArray())
	var e: MoveClips.Entry = t.of(&"katana")[&"k_iai"]
	assert_eq(e.clips, [&"SheatheHips01_R@3-12", &"Attack1H04_R@2"] as Array[StringName])
	assert_eq(e.sheathed, PackedFloat64Array([8, 9]))
	assert_eq(e.marks["hold"], 9.0, "the hold kept with the marks")
	# without marks of its own: the first part's wind-up, the last's markers
	# after the parts before it
	e.marks = {}
	var m: ClipManifest = ClipManifest.read()
	var markers: Dictionary = MoveClips.markers(e, m, PackedFloat64Array([22.0, 35.0]))
	var last: ClipManifest.Clip = m.clips[&"Attack1H04_R"]
	assert_eq(markers["contact"], 9.0 + float(last.markers["contact"]) - 2.0, "the cut's contact, after the sheathe's 9 frames, from its frame 2")


func test_a_re_keyed_move_has_no_speed() -> void:
	# milestone-1 task 19: a Katana or bare-hands move with real markers plays
	# at 1.0x, so a speed of its own would be a retime; its marks may record
	# where the clip's events fall
	var markers: Dictionary = {"windup": 0, "active_start": 8, "active_end": 10, "settle": 22}
	var t: MoveClips = _read({
		"katana": {"guard": "CombatIdle1H01", "moves": {
			"k_l1": {"clips": ["Attack1H01_R"], "markers": markers},
			"k_l2": {"clips": ["Attack1H01_R"], "speed": 1.4, "markers": markers},
			"k_l3": {"clips": ["Attack1H01_R"], "marks": {"windup": 0, "contact": 8, "contact_end": 10, "settle": 22}, "markers": markers},
			"k_l4": {"clips": ["Attack1H01_R"], "speed": 1.4, "markers": markers, "markers_stand_in": true},
			"k_lunge": {"clips": ["Attack1H04_R@6"], "speed": 1.65, "markers": markers},
		}},
		"fists": {"guard": "CombatIdle01", "moves": {
			"f_l1": {"clips": ["AttackPunch02_L"], "speed": 1.4, "markers": markers},
		}},
		"greatsword": {"guard": "CombatIdle2H01", "moves": {
			"g_l1": {"clips": ["Attack2H01"], "speed": 1.15, "markers": markers},
		}},
	})
	assert_eq(t.errors, PackedStringArray([
		"fists.f_l1: a move with real markers plays at 1.0x, so it has no speed",
		"katana.k_l2: a move with real markers plays at 1.0x, so it has no speed",
	]), "the stand-in keeps its retime; the Counter Lunge and the Greatsword wait for milestone 2")
	assert_true(is_nan((t.of(&"katana")[&"k_l1"] as MoveClips.Entry).speed))


func test_a_charge_may_hold_on_a_loop() -> void:
	var t: MoveClips = _read({
		"katana": {"guard": "CombatIdle1H01", "moves": {
			"k_iai": {"clips": ["SheatheHips01_R@3-12", "Attack1H04_R@2"], "loop": "CombatIdle1H01@0-20"},
			"k_l1": {"clips": ["Attack1H01_R"], "loop": "CombatIdle1H01"},
			"k_l2": {"clips": ["Attack1H01_R"]},
		}},
		"fists": {"guard": "CombatIdle01", "moves": {
			"f_h1": {"clips": ["AttackKick01_R"], "loop": "Nope01"},
		}},
	})
	assert_eq(t.errors, PackedStringArray([
		"fists.f_h1: the loop: Nope01 is not in the clip manifest",
		"katana.k_l1: only a chargeable move has a loop",
	]))
	assert_eq((t.of(&"katana")[&"k_iai"] as MoveClips.Entry).loop, &"CombatIdle1H01@0-20", "the charge's loop")
	assert_eq((t.of(&"katana")[&"k_l2"] as MoveClips.Entry).loop, &"", "none")


func test_mistakes_are_named() -> void:
	var t: MoveClips = _read({
		"spear": {"guard": "CombatIdle1H01", "moves": {}},
		"katana": {"guard": "Nope", "moves": {
			"g_heavy": {"clips": ["Attack1H01_R"]},
			"k_l1": {"clips": ["Nope01"]},
			"k_l2": {"clips": ["Attack1H01_R"], "speed": 2.5},
			"k_l3": {"clips": [], "tempo": 1},
			"k_l4": {"clips": ["Attack1H01_R"], "marks": {"windup": 0, "contact": 8}},
			"k_h1f": {"clips": ["Attack1H01_R@x"]},
			"k_h2": {"clips": ["Attack1H01_R"], "sheathed": [5, 2]},
		}},
	})
	var want: Array[String] = [
		"spear: not a weapon",
		"katana: the guard clip Nope is not in the clip manifest",
		"katana.g_heavy: not a move of the katana",
		"katana.k_l1: Nope01 is not in the clip manifest",
		"katana.k_l2: speed must be a number from 1.0 to 2.0",
		"katana.k_l3: unknown field tempo",
		"katana.k_l3: needs clips, a list of clip ids",
		"katana.k_l4: marks must give windup, contact, contact_end, settle (and may give a hold), each a frame number",
		"katana.k_h1f: Attack1H01_R@x: a chain part is \"id\", \"id@from\" or \"id@from-to\" (source frames, from before to)",
		"katana.k_h2: sheathed must be two source frames, the first before the second",
	]
	for line: String in want:
		assert_has(t.errors, line)
	assert_eq(t.errors.size(), want.size(), str(t.errors))
