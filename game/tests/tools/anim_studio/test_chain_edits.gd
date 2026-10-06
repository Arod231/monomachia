extends GutTest
## The chain panel's model (ChainEdits, milestone-1 task 27): parts and
## source-frame ranges round-trip through ClipChain's syntax, a reordered or
## changed chain is one edit of the move's "clips", and the panel adds no
## speed and no held frames, while today's holds are kept as written.


static func _entry(wid: StringName, id: StringName) -> MoveClips.Entry:
	return MoveClips.read(ClipManifest.read()).of(wid)[id]


func test_every_part_shape_round_trips() -> void:
	var entries: Array = ["Attack1H01_R", "SheatheHips01_R@3", "SheatheHips01_R@3-12", "AttackPolearm01@8*4", "ual/Sword_Dash", "ual/Shield_Dash@0.5-6"]
	var rows: Array[ChainEdits.Row] = ChainEdits.rows_of(entries)
	assert_eq(rows.map(func(r: ChainEdits.Row) -> String: return r.text()), entries)
	assert_true(rows[3].is_held(), "a hold is kept as it is")
	assert_eq(rows[2].from, 3.0)
	assert_eq(rows[2].to, 12.0)
	assert_true(is_nan(rows[1].to), "to the clip's end")
	assert_eq(rows[5].clip, "ual/Shield_Dash")


func test_part_text_writes_whole_frames_without_a_decimal() -> void:
	assert_eq(ChainEdits.part_text("A", 0.0, NAN), "A")
	assert_eq(ChainEdits.part_text("A", 4.0, NAN), "A@4")
	assert_eq(ChainEdits.part_text("A", 4.0, 10.5), "A@4-10.5")


func test_reordering_writes_the_chain_in_its_new_order() -> void:
	var s: EditSession = EditSession.new()
	var e: MoveClips.Entry = _entry(&"katana", &"k_iai")
	var rows: Array[ChainEdits.Row] = ChainEdits.rows_of(ChainEdits.current(s, MoveClips.PATH, &"katana", e))
	rows.reverse()
	var r: MarkerEdits.Result = ChainEdits.set_chain(s, MoveClips.PATH, &"katana", e, rows, ClipManifest.read())
	assert_eq(r.error, "")
	assert_eq(r.edits.size(), 1)
	assert_eq(r.edits[0].key_path, ["katana", "moves", "k_iai", "clips"] as Array[String], "only the clips")
	s.apply(r.edits, r.label)
	var reversed: Array[String] = []
	for c: StringName in e.clips:
		reversed.push_front(String(c))
	assert_eq(ChainEdits.current(s, MoveClips.PATH, &"katana", e), reversed)


func test_a_held_part_is_kept_and_none_is_added() -> void:
	var s: EditSession = EditSession.new()
	var e: MoveClips.Entry = _entry(&"katana", &"k_thrust")
	var rows: Array[ChainEdits.Row] = ChainEdits.rows_of(ChainEdits.current(s, MoveClips.PATH, &"katana", e))
	rows[2].from = 9.0
	var r: MarkerEdits.Result = ChainEdits.set_chain(s, MoveClips.PATH, &"katana", e, rows, ClipManifest.read())
	assert_eq(r.error, "")
	assert_eq(r.edits[0].after, ["AttackPolearm01@0-8", "AttackPolearm01@8*4", "AttackPolearm01@9"], "the hold written back as it was")
	var new_hold: ChainEdits.Row = ChainEdits.Row.new()
	new_hold.held = "AttackPolearm01@2*3"
	rows.append(new_hold)
	assert_eq(ChainEdits.set_chain(s, MoveClips.PATH, &"katana", e, rows, ClipManifest.read()).error, "the chain panel makes no held frames")


func test_a_saved_chain_has_no_speed_or_hold() -> void:
	# a chain built in the panel: parts and ranges, nothing else (on Crown
	# Cut, a stand-in with a retime's speed)
	var s: EditSession = EditSession.new()
	var e: MoveClips.Entry = _entry(&"katana", &"k_l4")
	var a: ChainEdits.Row = ChainEdits.Row.new()
	a.clip = "Attack1H01_R"
	a.to = 20.0
	var b: ChainEdits.Row = ChainEdits.Row.new()
	b.clip = "ual/Sword_Light_A"
	var r: MarkerEdits.Result = ChainEdits.set_chain(s, MoveClips.PATH, &"katana", e, [a, b] as Array[ChainEdits.Row], ClipManifest.read())
	assert_eq(r.error, "")
	for edit: EditSession.Edit in r.edits:
		assert_eq(edit.key_path[-1], "clips", "no speed edit")
		for part: Variant in edit.after:
			assert_false(str(part).contains("*"), "no hold: %s" % part)
	s.apply(r.edits, r.label)
	var text: String = s.text_for(MoveClips.PATH, s.original(MoveClips.PATH))
	assert_true(text.contains("\"k_l4\": {\"clips\": [\"Attack1H01_R@0-20\", \"ual/Sword_Light_A\"], \"speed\": 1.55"), "the speed left as it was, for task 19")


func test_a_bad_part_is_refused() -> void:
	var s: EditSession = EditSession.new()
	var e: MoveClips.Entry = _entry(&"katana", &"k_l1")
	var m: ClipManifest = ClipManifest.read()
	var row: ChainEdits.Row = ChainEdits.Row.new()
	row.clip = "NoSuchClip"
	assert_string_contains(ChainEdits.set_chain(s, MoveClips.PATH, &"katana", e, [row] as Array[ChainEdits.Row], m).error, "not a clip")
	row.clip = "Attack1H01_R"
	row.from = 10.0
	row.to = 4.0
	assert_string_contains(ChainEdits.set_chain(s, MoveClips.PATH, &"katana", e, [row] as Array[ChainEdits.Row], m).error, "must come after")
	assert_eq(ChainEdits.set_chain(s, MoveClips.PATH, &"katana", e, [] as Array[ChainEdits.Row], m).error, "a chain needs a part")
	var same: Array[ChainEdits.Row] = ChainEdits.rows_of(ChainEdits.current(s, MoveClips.PATH, &"katana", e))
	assert_eq(ChainEdits.set_chain(s, MoveClips.PATH, &"katana", e, same, m).edits.size(), 0, "no change, no edit")
