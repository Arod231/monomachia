extends GutTest
## The move data (game/sim/moves/<weapon>.gd) as the rules build them: every
## field a key, the values in their unions, a release variant keeping its
## move's frames, and, since milestone-1 task 17, every move of every weapon
## taking its startup, active, recovery, dodge cancel and travel from the
## frame-data table (FrameDataTable) while its record sets none of them. The
## parity with the TypeScript demo's data, checked here until then, retired
## with task 17: the clips now decide the frames.

var _weapon_files: Dictionary[StringName, GDScript] = {
	&"katana": KatanaMoves, &"greatsword": GreatswordMoves, &"daggers": DaggersMoves, &"fists": FistsMoves,
}


func test_every_move_takes_its_frames_from_the_table() -> void:
	var table: FrameDataTable = FrameDataTable.shared()
	for wid: StringName in Moves.WEAPONS:
		for id: StringName in (Moves.WEAPONS[wid] as WeaponDef).moves:
			var m: AttackDef = Moves.WEAPONS[wid].moves[id]
			var row: Dictionary = table.row(wid, id)
			assert_false(row.is_empty(), "%s.%s has a row" % [wid, id])
			if row.is_empty():
				continue
			assert_eq([m.startup, m.active, m.recovery], [int(row["startup"]), int(row["active"]), int(row["recovery"])], "%s.%s's frames" % [wid, id])
			var cancel: Array = row.get("dodge_cancel", [])
			if not cancel.is_empty():
				assert_eq([m.dodge_cancel_from, m.dodge_cancel_to], [int(cancel[0]), int(cancel[1])], "%s.%s's dodge cancel" % [wid, id])
			elif m.kind != &"heavy":
				assert_eq(m.dodge_cancel_from, AttackDef.UNSET, "%s.%s has no dodge cancel" % [wid, id])
			assert_eq(m.real_markers, not bool(row.get("stand_in", false)), "%s.%s: real markers unless its row is a stand-in" % [wid, id])
			var branches: Dictionary = row.get("branches", {})
			assert_eq(m.branches.size(), branches.size(), "%s.%s's branch points" % [wid, id])
			for follow: Variant in branches:
				assert_eq(Array(m.branches.get(StringName(follow), PackedInt32Array())), (branches[follow] as Array).map(func(x: Variant) -> int: return int(x)), "%s.%s -> %s" % [wid, id, follow])
			assert_eq(m.travel.size(), 3 * (m.total_frames() + 1), "%s.%s: travel on every frame" % [wid, id])
			var last: Array = (row["travel"] as Array)[-1]
			assert_eq([m.travel[-3], m.travel[-2], m.travel[-1]], [float(last[0]), float(last[1]), float(last[2])], "%s.%s's travel" % [wid, id])


func test_the_move_data_set_no_frames() -> void:
	for wid: StringName in _weapon_files:
		var moves: Dictionary = _weapon_files[wid].get_script_constant_map()["MOVES"]
		for id: Variant in moves:
			for field: String in AttackDef.TABLE_FIELDS:
				assert_false((moves[id] as Dictionary).has(field), "%s.%s sets %s; the table gives it" % [wid, id, field])


func test_a_record_without_a_row_keeps_its_own_frames() -> void:
	var moves: Dictionary[StringName, AttackDef] = AttackDef.finalize_moves({&"t_cut": {"id": &"t_cut", "name": "Test Cut",
		"kind": &"heavy", "type": &"slash", "startup": 10, "active": 3, "recovery": 12, "damage": 5, "posture": 5}}, &"katana")
	var m: AttackDef = moves[&"t_cut"]
	assert_eq([m.startup, m.active, m.recovery], [10, 3, 12], "a test move's frames are its own")
	assert_eq(m.dodge_cancel_from, 19, "a heavy's cancel from the middle of its recovery")
	assert_true(m.travel.is_empty(), "and no travel")
	assert_false(m.real_markers, "nor markers of a clip")


func test_a_record_setting_frames_beside_its_row_is_refused() -> void:
	AttackDef.finalize_moves({&"k_l1": {"id": &"k_l1", "name": "Right Cut", "kind": &"light", "type": &"slash", "startup": 9}}, &"katana")
	assert_push_error("k_l1 sets startup")


func test_every_attack_def_field_is_a_key() -> void:
	var props: Array[String] = []
	for p: Dictionary in AttackDef.new().get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props.append(String(p["name"]))
	assert_eq(props, AttackDef.KEYS)
	var wprops: Array[String] = []
	for p: Dictionary in WeaponDef.new().get_property_list():
		# authored_reach is the record's reach, kept for derive_reach()
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and String(p["name"]) != "authored_reach":
			wprops.append(String(p["name"]))
	assert_eq(wprops, WeaponDef.KEYS)


func test_every_release_variant_has_its_moves_frames() -> void:
	# a variant swaps in mid-move, on the same attack state, so it must keep
	# its move's frames and lunge
	var variants: int = 0
	for wid: StringName in Moves.WEAPONS:
		var moves: Dictionary[StringName, AttackDef] = Moves.WEAPONS[wid].moves
		for id: StringName in moves:
			var m: AttackDef = moves[id]
			if m.release_variant == &"":
				continue
			variants += 1
			var v: AttackDef = moves.get(m.release_variant, null)
			assert_not_null(v, "%s.%s's release variant %s is one of its moves" % [wid, id, m.release_variant])
			if v == null:
				continue
			assert_eq(
				[v.startup, v.active, v.recovery, v.lunge, v.lunge_start, v.lunge_end],
				[m.startup, m.active, m.recovery, m.lunge, m.lunge_start, m.lunge_end],
				"%s.%s and its variant %s: frames and lunge" % [wid, id, v.id],
			)
	assert_gt(variants, 0, "the Iai has a variant")


func test_finalize_keeps_u_impale_dodgeable() -> void:
	var impale: AttackDef = Moves.ULT_HITS[&"u_impale"]
	assert_true(impale.unblockable)
	assert_false(impale.undodgeable)
	assert_true(Moves.ULT_HITS[&"u_burst"].undodgeable)
	assert_true(Moves.KATANA.moves[&"k_thrust"].undodgeable)
	assert_eq(Moves.ULT_HITS[&"u_moon_v"].trail, &"danger")
	assert_eq(Moves.ULT_HITS[&"u_tempest"].trail, &"ult")


func test_values_are_in_their_unions() -> void:
	var all: Array[AttackDef] = []
	for w: WeaponDef in Moves.WEAPONS.values():
		all.append_array(w.moves.values())
		assert_true(WeaponDef.WEAPON_IDS.has(w.id), String(w.id))
		assert_true(WeaponDef.ULTIMATE_IDS.has(w.ultimate), String(w.ultimate))
		assert_true(WeaponDef.WEAPON_CLASSES.has(w.cls), String(w.cls))
	all.append_array(Moves.ULT_HITS.values())
	for m: AttackDef in all:
		assert_true(AttackDef.ATTACK_KINDS.has(m.kind), "%s kind" % m.id)
		assert_true(AttackDef.ATTACK_TYPES.has(m.type), "%s type" % m.id)
		assert_true(AttackDef.HANDS.has(m.hand), "%s hand" % m.id)
		assert_true(AttackDef.TRAILS.has(m.trail), "%s trail" % m.id)
		assert_true(m.counter == &"" or AttackDef.COUNTER_KINDS.has(m.counter), "%s counter" % m.id)
		assert_true(m.sound == &"" or AttackDef.HIT_SOUNDS.has(m.sound), "%s sound" % m.id)
		assert_true(m.special == &"" or AttackDef.SPECIALS.has(m.special), "%s special" % m.id)
		assert_true(m.side_start == &"" or AttackDef.SIDES.has(m.side_start), "%s side_start" % m.id)
		assert_true(m.side_end == &"" or AttackDef.SIDES.has(m.side_end), "%s side_end" % m.id)


func test_get_move_falls_back_to_ultimate_hits() -> void:
	assert_same(Moves.get_move(Moves.KATANA, &"k_l1"), Moves.KATANA.moves[&"k_l1"])
	assert_same(Moves.get_move(Moves.FISTS, &"u_burst"), Moves.ULT_HITS[&"u_burst"])
	assert_eq(Moves.KATANA.moves[&"k_l1"].total_frames(), 60, "Right Cut, re-keyed (task 31): 28, 4 and 28")


func test_get_move_reports_an_unknown_move() -> void:
	assert_null(Moves.get_move(Moves.KATANA, &"g_l1"))
	assert_push_error("Unknown move g_l1 for katana")
