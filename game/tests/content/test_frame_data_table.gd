extends GutTest
## The committed frame-data table (game/sim/moves/frame_data.json, FrameDataTable,
## milestone-1 task 16), read as data, as CI reads it: complete (every move
## and every rules-length clip that exists has a row and a source), generated
## (each row's digest matches it and its swing file), and its "not keyed yet"
## list holding only the clips the plan adds. The local re-bake against the
## clips is test_swing_bake.gd's test_local_every_move_matches_a_fresh_bake.

const HEX: String = "0123456789abcdef"


func _table() -> FrameDataTable:
	var t: FrameDataTable = FrameDataTable.read()
	assert_eq(t.errors, PackedStringArray(), "the table reads cleanly")
	return t


func _swing_records(wid: StringName) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SwingFile.path_for(wid)))
	return (data as Dictionary).get("swings", {}) if data is Dictionary else {}


func _is_sha(s: Variant) -> bool:
	return s is String and (s as String).length() == 64 and Array((s as String).split("")).all(func(c: String) -> bool: return HEX.contains(c))


func test_every_move_of_every_weapon_has_a_row_with_its_source() -> void:
	var t: FrameDataTable = _table()
	var manifest: ClipManifest = ClipManifest.read()
	for wid: StringName in Moves.WEAPONS:
		var weapon: WeaponDef = Moves.WEAPONS[wid]
		for id: StringName in weapon.moves:
			var row: Dictionary = t.row(wid, id)
			assert_false(row.is_empty(), "%s.%s has a row" % [wid, id])
			if row.is_empty():
				continue
			assert_true(FrameDataRows.BAND_KINDS.has(StringName(row["kind"])), "%s.%s: a band kind" % [wid, id])
			assert_false((row["chain"] as Array).is_empty(), "%s.%s: its source clip" % [wid, id])
			for part: Dictionary in row["chain"]:
				var clip := StringName(part["clip"])
				assert_true(manifest.clips.has(clip) or ClipChain.is_cc0(clip), "%s.%s: %s is a clip" % [wid, id, clip])
			assert_true(_is_sha(row["source_sha256"]), "%s.%s: its source's checksum" % [wid, id])
			var total: int = int(row["startup"]) + int(row["active"]) + int(row["recovery"])
			assert_gt(int(row["startup"]), 0, "%s.%s startup" % [wid, id])
			assert_gt(int(row["active"]), 0, "%s.%s active" % [wid, id])
			assert_eq((row["travel"] as Array).size(), total + 1, "%s.%s: travel on every rules frame" % [wid, id])
		var listed: Array = (t.moves.get(String(wid), {}) as Dictionary).keys()
		for id: Variant in listed:
			assert_true(weapon.moves.has(StringName(id)), "%s.%s: a row for a move that exists" % [wid, id])


func test_the_stand_ins_give_the_katanas_and_bare_hands_frame_data_today() -> void:
	var t: FrameDataTable = _table()
	var stand_ins: int = 0
	for wid: StringName in [&"katana", &"fists"]:
		var weapon: WeaponDef = Moves.WEAPONS[wid]
		for id: StringName in weapon.moves:
			var row: Dictionary = t.row(wid, id)
			if not row.get("stand_in", false):
				continue
			stand_ins += 1
			var m: AttackDef = weapon.moves[id]
			assert_eq([int(row["startup"]), int(row["active"]), int(row["recovery"])], [m.startup, m.active, m.recovery], "%s.%s" % [wid, id])
			var cancel: Array = row.get("dodge_cancel", [])
			assert_eq(int(cancel[0]) if not cancel.is_empty() else AttackDef.UNSET, m.dodge_cancel_from, "%s.%s dodge cancel" % [wid, id])
			for follow: StringName in [m.chain_light, m.chain_heavy]:
				if follow != &"":
					assert_eq(int(row["branches"][String(follow)][0]), m.startup + m.active + 2, "%s.%s -> %s: today's branch point" % [wid, id, follow])
	assert_eq(stand_ins, 21, "the Katana's and bare hands' moves but the Counter Lunges and the keyed (the light string, tasks 31 and 32; Breaker Palm, task 99; bare hands' eight movement attacks, tasks 93 and 94; Crescent Coil, KE task 16)")


func test_each_move_has_its_band_kind() -> void:
	var katana: WeaponDef = Moves.WEAPONS[&"katana"]
	var fists: WeaponDef = Moves.WEAPONS[&"fists"]
	var want: Dictionary = {
		&"k_l1": &"string_light", &"k_l2": &"string_light", &"k_l4": &"string_light", &"k_h2": &"string_heavy",
		&"k_iai": &"iai_draw", &"k_iai_h": &"iai_draw", &"k_h1f": &"iai_follow_up", &"k_rdraw": &"iai_follow_up",
		&"k_sl": &"sprint_light", &"k_sh": &"sprint_heavy", &"k_dl": &"dodge_light", &"k_dh": &"dodge_heavy",
		&"k_bl": &"backstep_light", &"k_bh": &"backstep_heavy", &"k_jl": &"jump_light", &"k_jh": &"jump_heavy",
		&"k_flash": &"block_ability", &"k_thrust": &"unblockable", &"k_sweep": &"unblockable", &"k_lunge": &"counter_lunge",
		# a grip's own string hits take its rows (KE task 11); the stand-ins
		# every grip plays keep the shared one
		&"k_1l1": &"string_light_1h", &"k_1l2": &"string_light_1h", &"k_1l3": &"string_light_1h", &"k_1l4": &"string_light_1h",
		&"k_2l1": &"string_light_2h", &"k_2l2": &"string_light_2h", &"k_l3": &"string_light",
		# a grip's last hit takes its own kind (KE task 12, D16)
		&"k_1l5": &"string_last_1h",
		# a grip's own heavy, keyed for it, takes its own kind (KE task 16);
		# Heaven Splitter keeps the shared one until its re-key
		&"k_coil": &"grip_heavy_1h",
	}
	for id: StringName in want:
		assert_eq(FrameDataRows.kind_of(katana, id), want[id], String(id))
	assert_eq(FrameDataRows.kind_of(fists, &"f_l1"), &"string_light")
	assert_eq(FrameDataRows.kind_of(fists, &"f_h1"), &"string_heavy", "Roundhouse, chargeable but no stance")
	assert_eq(FrameDataRows.kind_of(fists, &"f_breaker"), &"ultimate")
	var t: FrameDataTable = _table()
	for wid: StringName in Moves.WEAPONS:
		for id: StringName in (Moves.WEAPONS[wid] as WeaponDef).moves:
			var row: Dictionary = t.row(wid, id)
			if not row.is_empty():
				assert_eq(StringName(row["kind"]), FrameDataRows.kind_of(Moves.WEAPONS[wid], id), "%s.%s's row" % [wid, id])


func test_a_keyed_chargeable_move_s_row_gives_the_frame_its_charge_holds_on() -> void:
	var t: FrameDataTable = _table()
	var row: Dictionary = t.row(&"katana", &"k_coil")
	assert_true(row.has("hold"), "Crescent Coil holds at its coil (KE task 16)")
	if not row.has("hold"):
		return
	var coil: AttackDef = Moves.KATANA.moves[&"k_coil"]
	assert_eq(coil.charge_hold, int(row["hold"]), "the rules hold its charge there")
	assert_between(coil.charge_hold, Fighter.CHARGE_CHECK_FRAME + 1, coil.startup - 1, "in its wind-up, past today's frame 9")
	assert_eq((Moves.KATANA.moves[&"k_iai"] as AttackDef).charge_hold, AttackDef.UNSET, "the Iai keeps frame 9")
	assert_false(t.row(&"katana", &"k_1l1").has("hold"), "nothing that doesn't charge")


func test_every_rules_length_clip_and_gait_has_a_row() -> void:
	var t: FrameDataTable = _table()
	var manifest: ClipManifest = ClipManifest.read()
	var wanted: Array[StringName] = FrameDataRows.rules_length_clips(manifest)
	assert_true(wanted.has(&"Stun01") and wanted.has(&"CombatDeath01") and wanted.has(&"Knockdown01_Fall"), "the state clips")
	for id: StringName in wanted:
		var row: Dictionary = t.clips.get(String(id), {})
		assert_false(row.is_empty(), "%s has a row" % id)
		if row.is_empty():
			continue
		assert_gt(int(row["frames"]), 0, "%s: its length" % id)
		assert_eq(int(row["markers"]["settle"]), manifest.clips[id].markers["settle"] * 2, "%s: its settle in rules frames" % id)
		assert_true(_is_sha(row["source_sha256"]), "%s: its source's checksum" % id)
	assert_eq(t.clips.size(), wanted.size(), "no row for a clip that sets no length")
	for id: StringName in FrameDataRows.gait_clips():
		var row: Dictionary = t.gaits.get(String(id), {})
		assert_false(row.is_empty(), "%s has a row" % id)
		if not row.is_empty():
			assert_gt(float(row["speed"]), 0.0, "%s: its measured speed" % id)
			assert_true(_is_sha(row["source_sha256"]), "%s: its source's checksum" % id)
	assert_eq(t.gaits.size(), FrameDataRows.gait_clips().size())


func test_the_not_keyed_yet_list_holds_only_clips_this_plan_adds() -> void:
	var t: FrameDataTable = _table()
	for name: String in t.not_keyed_yet:
		assert_true(FrameDataRows.NOT_KEYED_YET.has(name), "%s is one of the plan's" % name)
	assert_eq(t.not_keyed_yet.size(), FrameDataRows.NOT_KEYED_YET.size(), "none keyed yet")


func test_every_rows_digest_matches_it_and_its_swing() -> void:
	var t: FrameDataTable = _table()
	for wid: StringName in Moves.WEAPONS:
		var swings: Dictionary = _swing_records(wid)
		for id: Variant in t.moves.get(String(wid), {}):
			var row: Dictionary = t.moves[String(wid)][id]
			assert_eq(row["digest"], FrameDataTable.digest(row, swings.get(id)), "%s.%s: generated, not edited (node scripts/godot.mjs bake)" % [wid, id])
	for section: Dictionary in [t.gaits, t.clips]:
		for id: Variant in section:
			assert_eq(section[id]["digest"], FrameDataTable.digest(section[id], null), "%s: generated" % id)


func test_a_hand_edit_to_a_row_or_its_swing_fails_the_digest() -> void:
	var t: FrameDataTable = _table()
	var row: Dictionary = t.row(&"katana", &"k_l1")
	var swing: Dictionary = (_swing_records(&"katana")["k_l1"] as Dictionary).duplicate(true)
	assert_eq(row["digest"], FrameDataTable.digest(row, swing))
	var edited: Dictionary = row.duplicate(true)
	edited["startup"] = int(row["startup"]) - 1
	assert_ne(edited["digest"], FrameDataTable.digest(edited, swing), "a frame edited in the table")
	var keys: Array = swing["tracks"]["right_hand"]["keys"]
	keys[0]["grip"][0] = float(keys[0]["grip"][0]) + 0.01
	assert_ne(row["digest"], FrameDataTable.digest(row, swing), "a key edited in the swing file")


## The per-move checklist's item 5 (milestone-1 task 40), recorded for every
## keyed move and every clip row: a keyed move's row is generated from its
## source clip (a chain, a checksum, no stand-in, the digest matching), its
## travel is on every rules frame and the rules move it by that travel, not a
## lunge; a state clip's row records its length and settle from its markers.
func test_every_keyed_move_and_clip_row_has_its_travel_and_length_in_the_table() -> void:
	var t: FrameDataTable = _table()
	var manifest: ClipManifest = ClipManifest.read()
	for m: Array in ChecklistResults.keyed_moves():
		var wid: StringName = m[0]
		var id: StringName = m[1]
		var problems: Array[String] = []
		var row: Dictionary = t.row(wid, id)
		var def: AttackDef = (Moves.WEAPONS[wid] as WeaponDef).moves[id]
		if row.is_empty():
			problems.append("no row in the table")
		else:
			if row.get("stand_in", false):
				problems.append("a stand-in's frames")
			if (row["chain"] as Array).is_empty() or not _is_sha(row["source_sha256"]):
				problems.append("no source clip or checksum")
			if (row["travel"] as Array).size() != int(row["startup"]) + int(row["active"]) + int(row["recovery"]) + 1:
				problems.append("travel not on every rules frame")
			if row["digest"] != FrameDataTable.digest(row, _swing_records(wid).get(String(id))):
				problems.append("edited by hand")
		if not def.by_travel:
			problems.append("moved by a lunge, not its travel")
		ChecklistResults.record_problems(5, id, problems)
		assert_eq(problems, [] as Array[String], "%s.%s" % [wid, id])
	var rows: Dictionary[StringName, Array] = ChecklistResults.clip_rows()
	for row_id: StringName in rows:
		var by_clip: Dictionary = {}
		for clip: StringName in rows[row_id]:
			var problems: Array[String] = []
			var row: Dictionary = t.clips.get(String(clip), {})
			if row.is_empty() or not manifest.clips.has(clip):
				problems.append("no row in the table")
			elif int(row["frames"]) <= 0 or int(row["markers"]["settle"]) != manifest.clips[clip].markers["settle"] * 2 \
					or not _is_sha(row["source_sha256"]) or row["digest"] != FrameDataTable.digest(row, null):
				problems.append("its length or settle not generated from its markers")
			by_clip[clip] = problems
			assert_eq(problems, [] as Array[String], "%s" % clip)
		ChecklistResults.record_clips(5, row_id, by_clip)
