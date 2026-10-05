extends GutTest
## MoveList (22.13): every weapon's moves read from its move data into the
## move list's rows. The numbers come from the moves themselves, and a
## made-up weapon shows that a changed or added move changes the rows.


func _row(rows: Array[MoveList.Row], move_id: StringName) -> MoveList.Row:
	for r: MoveList.Row in rows:
		if r.move_id == move_id:
			return r
	return null


func _names(rows: Array[MoveList.Row], section: MoveList.Section) -> Array[String]:
	var out: Array[String] = []
	for r: MoveList.Row in rows:
		if r.section == section:
			out.append(r.name)
	return out


func test_every_move_of_every_weapon_appears_once() -> void:
	for id: StringName in WeaponDef.WEAPON_IDS:
		var w: WeaponDef = Moves.WEAPONS[id]
		var counts: Dictionary = {}
		for r: MoveList.Row in MoveList.rows(w):
			if w.moves.has(r.move_id):
				counts[r.move_id] = int(counts.get(r.move_id, 0)) + 1
		for move_id: StringName in w.moves:
			assert_eq(counts.get(move_id, 0), 1, "%s: %s listed once" % [id, move_id])


func test_numbers_are_the_moves_own() -> void:
	for id: StringName in WeaponDef.WEAPON_IDS:
		var w: WeaponDef = Moves.WEAPONS[id]
		for r: MoveList.Row in MoveList.rows(w):
			if not w.moves.has(r.move_id):
				continue
			var m: AttackDef = w.moves[r.move_id]
			assert_eq(r.name, m.name, "%s name" % r.move_id)
			assert_eq(r.damage, m.damage, "%s damage" % r.move_id)
			assert_eq(r.posture, m.posture, "%s posture" % r.move_id)
			assert_eq(r.reach, m.reach(), "%s reach" % r.move_id)
			assert_eq(r.unblockable, m.unblockable, "%s unblockable" % r.move_id)
			assert_eq(r.counter, m.counter, "%s counter" % r.move_id)


func test_katana_string_inputs_take_the_shortest_way_in() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.KATANA)
	var expect: Dictionary = {
		&"k_l1": "Light",
		&"k_l2": "Light → Light",
		&"k_l3": "Light → Light → Light",
		&"k_l4": "Light → Light → Light → Light",
		&"k_h2": "Light → Heavy",
		&"k_iai": "Heavy",
		&"k_iai_h": "Heavy + left/right",
		&"k_rdraw": "Heavy + left/right → Heavy",
		# Heavy → Heavy is shorter than Light → Light → Heavy
		&"k_h1f": "Heavy → Heavy",
	}
	for move_id: StringName in expect:
		assert_eq(_row(rows, move_id).input, expect[move_id], String(move_id))
		assert_eq(_row(rows, move_id).section, MoveList.Section.STRING, String(move_id))


func test_other_ways_into_a_follow_up_are_listed() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.KATANA)
	assert_eq(Array(_row(rows, &"k_h1f").also_after), ["Return Cut"])
	assert_eq(Array(_row(rows, &"k_h2").also_after), ["Kesa Cut", "Rising Heaven"])
	assert_eq(Array(_row(rows, &"k_l1").also_after), [])
	# the horizontal Iai's light goes on into the light string
	assert_eq(Array(_row(rows, &"k_l2").also_after), ["Iai Slash (horizontal)"])


func test_strings_read_light_first_then_each_heavy_branch() -> void:
	assert_eq(_names(MoveList.rows(Moves.KATANA), MoveList.Section.STRING), [
		"Right Cut", "Return Cut", "Kesa Cut", "Crown Cut", "Heaven Splitter",
		"Iai Slash (vertical)", "Iai Slash (horizontal)", "Returning Draw", "Rising Heaven",
	])
	assert_eq(_names(MoveList.rows(Moves.GREATSWORD), MoveList.Section.STRING), [
		"Heavy Swing", "Backswing", "Overhead Strike", "Low Sweep",
	])


func test_a_chargeable_heavy_says_so() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.KATANA)
	assert_string_contains(_row(rows, &"k_iai").note, "hold to charge")
	assert_eq(_row(rows, &"k_l1").note, "")


func test_movement_attacks_abilities_and_the_counter_lunge() -> void:
	var w: WeaponDef = Moves.DAGGERS
	var rows: Array[MoveList.Row] = MoveList.rows(w)
	var expect: Dictionary = {
		w.sprint_light: "Sprint + light", w.sprint_heavy: "Sprint + heavy",
		w.dodge_light: "Dodge + light", w.dodge_heavy: "Dodge + heavy",
		w.back_light: "Backstep + light", w.back_heavy: "Backstep + heavy",
		w.jump_light: "Jump + light", w.jump_heavy: "Jump + heavy",
	}
	for move_id: StringName in expect:
		assert_eq(_row(rows, move_id).input, expect[move_id], String(move_id))
		assert_eq(_row(rows, move_id).section, MoveList.Section.MOVEMENT, String(move_id))
	assert_eq(_names(rows, MoveList.Section.ABILITY), ["Serpent Sweep", "Shadow Step", "Needle Thrust"])
	assert_eq(_row(rows, &"d_needle").input, "Block + light or heavy")
	assert_eq(_row(rows, &"d_lunge").section, MoveList.Section.COUNTER)
	assert_eq(_row(rows, &"d_lunge").input, "Back-dash a slam → Light")
	assert_eq(_names(MoveList.rows(Moves.FISTS), MoveList.Section.ABILITY), [])


func test_each_weapon_lists_its_ultimate_with_every_hit_added_up() -> void:
	var expect: Dictionary = {
		&"katana": ["Moonsplitter", 30.0, 40.0, 1, true],
		&"greatsword": ["Impaler", 35.0, 50.0, 2, true],
		# six spins and the finisher
		&"daggers": ["Lightning Tempest", 38.0, 40.0, 7, false],
	}
	for id: StringName in expect:
		var ults: Array[MoveList.Row] = []
		for r: MoveList.Row in MoveList.rows(Moves.WEAPONS[id]):
			if r.section == MoveList.Section.ULTIMATE:
				ults.append(r)
		assert_eq(ults.size(), 1, "%s: one ultimate row" % id)
		var u: MoveList.Row = ults[0]
		var e: Array = expect[id]
		assert_eq(u.move_id, Moves.WEAPONS[id].ultimate)
		assert_eq(u.input, "Light + heavy at 25% health")
		assert_eq(u.name, e[0])
		assert_eq(u.damage, e[1], "%s damage" % id)
		assert_eq(u.posture, e[2], "%s posture" % id)
		assert_eq(u.hits.size(), e[3], "%s hits" % id)
		assert_eq(u.unblockable, e[4], "%s unblockable" % id)
		assert_true(is_nan(u.reach), "%s: no reach for a scripted ultimate" % id)


func test_bare_hands_choose_recall_or_breaker_palm() -> void:
	var ults: Array[MoveList.Row] = []
	for r: MoveList.Row in MoveList.rows(Moves.FISTS):
		if r.section == MoveList.Section.ULTIMATE:
			ults.append(r)
	assert_eq(ults.size(), 2)
	assert_eq(ults[0].name, "Recall")
	assert_eq(ults[0].input, "Light + heavy at 25% health → Light")
	assert_eq(ults[0].move_id, MoveList.RECALL)
	assert_true(is_nan(ults[0].damage))
	var palm: AttackDef = Moves.FISTS.moves[&"f_breaker"]
	assert_eq(ults[1].name, palm.name)
	assert_eq(ults[1].input, "Light + heavy at 25% health → Heavy")
	assert_eq(ults[1].damage, palm.damage)
	assert_eq(ults[1].posture, palm.posture)


func test_sections_come_in_order() -> void:
	var last: int = -1
	for r: MoveList.Row in MoveList.rows(Moves.KATANA):
		assert_true(int(r.section) >= last, "%s after section %d" % [r.name, last])
		last = int(r.section)


# --- a made-up weapon: the rows follow the data ---

func _weapon(records: Dictionary) -> WeaponDef:
	var w: WeaponDef = WeaponDef.new()
	w.id = &"test"
	w.name = "Test"
	w.moves = AttackDef.finalize_moves(records)
	w.light_start = &"t_l1"
	w.heavy_start = &"t_h1"
	w.ultimate = &"moonsplitter"
	return w


func _records() -> Dictionary:
	var base: Dictionary = {
		"kind": &"light", "type": &"slash", "anim": &"slashRL",
		"startup": 10, "active": 3, "recovery": 16, "damage": 6, "posture": 7, "knockback": 0.3,
		"range": 2.0, "arc": 90,
	}
	var l1: Dictionary = base.duplicate()
	l1.merge({"id": &"t_l1", "name": "First", "chain_light": &"t_l2"}, true)
	var l2: Dictionary = base.duplicate()
	l2.merge({"id": &"t_l2", "name": "Second"}, true)
	var h1: Dictionary = base.duplicate()
	h1.merge({"id": &"t_h1", "name": "Big", "kind": &"heavy", "damage": 12, "posture": 14}, true)
	return {&"t_l1": l1, &"t_l2": l2, &"t_h1": h1}


func test_a_changed_move_changes_its_row() -> void:
	var records: Dictionary = _records()
	assert_eq(_row(MoveList.rows(_weapon(records)), &"t_l2").damage, 6.0)
	records[&"t_l2"]["damage"] = 9
	records[&"t_l2"]["range"] = 2.6
	var r: MoveList.Row = _row(MoveList.rows(_weapon(records)), &"t_l2")
	assert_eq(r.damage, 9.0)
	assert_eq(r.reach, 2.6)


func test_an_added_follow_up_gets_a_row() -> void:
	var records: Dictionary = _records()
	assert_null(_row(MoveList.rows(_weapon(records)), &"t_l3"))
	var l3: Dictionary = records[&"t_l2"].duplicate()
	l3.merge({"id": &"t_l3", "name": "Third", "unblockable": true, "counter": &"thrust"}, true)
	records[&"t_l3"] = l3
	# not listed until a move chains into it
	assert_null(_row(MoveList.rows(_weapon(records)), &"t_l3"))
	records[&"t_l2"]["chain_heavy"] = &"t_l3"
	var r: MoveList.Row = _row(MoveList.rows(_weapon(records)), &"t_l3")
	assert_not_null(r)
	assert_eq(r.input, "Light → Light → Heavy")
	assert_true(r.unblockable)
	assert_eq(r.counter, &"thrust")
	assert_eq(_names(MoveList.rows(_weapon(records)), MoveList.Section.STRING), ["First", "Second", "Third", "Big"])
