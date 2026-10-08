extends GutTest
## MoveList (22.13): every weapon's moves read from its move data into the
## move list's rows. The numbers come from the moves themselves, and a
## made-up weapon shows that a changed or added move changes the rows.


## The first row of move_id, in `section` when one is given.
func _row(rows: Array[MoveList.Row], move_id: StringName, section: int = -1) -> MoveList.Row:
	for r: MoveList.Row in rows:
		if r.move_id == move_id and (section < 0 or int(r.section) == section):
			return r
	return null


func _names(rows: Array[MoveList.Row], section: MoveList.Section) -> Array[String]:
	var out: Array[String] = []
	for r: MoveList.Row in rows:
		if r.section == section:
			out.append(r.name)
	return out


## The pilot's four lights, in neither grip's string since the two-handed
## string's own hits (Right Cut and Return Cut since KE task 13, Kesa Cut and
## Crown Cut since KE task 14): no light reaches them in a match, so the
## list leaves them out.
const OUT_OF_PLAY: Array[StringName] = [&"k_l1", &"k_l2", &"k_l3", &"k_l4"]


func test_every_move_of_every_weapon_appears_once() -> void:
	for id: StringName in WeaponDef.WEAPON_IDS:
		var w: WeaponDef = Moves.WEAPONS[id]
		var counts: Dictionary = {}
		for r: MoveList.Row in MoveList.rows(w):
			if w.moves.has(r.move_id):
				counts[r.move_id] = int(counts.get(r.move_id, 0)) + 1
		for move_id: StringName in w.moves:
			if w.grips.is_empty():
				assert_eq(counts.get(move_id, 0), 1, "%s: %s listed once" % [id, move_id])
			elif OUT_OF_PLAY.has(move_id):
				assert_eq(counts.get(move_id, 0), 0, "%s: %s left out" % [id, move_id])
			else:
				assert_gt(counts.get(move_id, 0), 0, "%s: %s listed" % [id, move_id])


func test_a_weapon_with_grips_lists_each_move_once_a_section_but_its_string_hits() -> void:
	var w: WeaponDef = Moves.KATANA
	var ids: Dictionary = {}
	var counts: Dictionary = {}
	for r: MoveList.Row in MoveList.rows(w):
		assert_false(ids.has(r.id), "%s: one row of that name" % r.id)
		ids[r.id] = true
		if not w.moves.has(r.move_id):
			continue
		var k: String = "%d %s" % [r.section, r.move_id]
		counts[k] = int(counts.get(k, 0)) + 1
	for k: String in counts:
		var move_id: StringName = StringName(k.get_slice(" ", 1))
		var section: int = int(k.get_slice(" ", 0))
		# a move lists once per hit it plays in its grip's string (once each
		# since the two-handed string's own five, KE task 14)
		var string: Array[StringName] = KatanaMoves.ONE_HANDED_STRING if section == MoveList.Section.ONE_HANDED else KatanaMoves.TWO_HANDED_STRING
		var hits: int = string.count(move_id)
		var in_grip: bool = section == MoveList.Section.ONE_HANDED or section == MoveList.Section.TWO_HANDED
		assert_eq(counts[k], hits if in_grip and hits > 0 else 1, k)


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


func test_each_grip_lists_its_string_hit_by_hit_then_its_heavy_branches() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.KATANA)
	for section: MoveList.Section in [MoveList.Section.ONE_HANDED, MoveList.Section.TWO_HANDED]:
		var inputs: Array[String] = []
		for r: MoveList.Row in rows:
			if r.section == section and r.move_id != MoveList.GRIP:
				inputs.append("%s: %s" % [r.input, r.name])
		var heavies: Array[String] = ["Light → Heavy: Crescent Coil"]
		if section == MoveList.Section.TWO_HANDED:
			heavies = ["Light → Heavy: Heaven Splitter", "Light → Heavy → Heavy: Rising Heaven"]
		# the one-handed grip's own five hits (KE tasks 11 and 12)
		var want: Array[String] = [
			"Light: Slanting Cut", "Light → Light: Backhand Rise", "Light → Light → Light: Twisting Rise",
			"Light → Light → Light → Light: Level Cut", "Light → Light → Light → Light → Light: Crouching Crown",
		]
		if section == MoveList.Section.TWO_HANDED:
			want = [
				"Light: Heavy Slant", "Light → Light: Left Rise", "Light → Light → Light: Right Rise",
				"Light → Light → Light → Light: Second Slant", "Light → Light → Light → Light → Light: Kneeling Crown",
			]
		want.append_array(heavies)
		assert_eq(inputs, want, MoveList.SECTION_NAMES[section])
	# every hit branches into the grip's heavy (KE task 7)
	assert_eq(_row(rows, &"k_coil", MoveList.Section.ONE_HANDED).also_after, PackedStringArray(["Backhand Rise", "Twisting Rise", "Level Cut", "Crouching Crown"]))
	assert_eq(_row(rows, &"k_h2", MoveList.Section.TWO_HANDED).also_after, PackedStringArray(["Left Rise", "Right Rise", "Second Slant", "Kneeling Crown"]))
	assert_eq(_row(rows, &"k_2l2", MoveList.Section.TWO_HANDED).also_after, PackedStringArray(["Iai Slash (horizontal)"]), "the horizontal Iai's light plays hit 2")


func test_the_first_grip_s_section_names_the_grip_button() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.KATANA)
	assert_eq(rows[0].section, MoveList.Section.ONE_HANDED)
	assert_eq([rows[0].move_id, rows[0].input, rows[0].name], [MoveList.GRIP, "Grip", "Switch grip"])
	assert_string_contains(rows[0].note, "rounds start one-handed")
	assert_true(is_nan(rows[0].damage))
	assert_null(_row(rows, MoveList.GRIP, MoveList.Section.TWO_HANDED), "named once")
	assert_null(_row(MoveList.rows(Moves.GREATSWORD), MoveList.GRIP), "none for a weapon without grips")


func test_katana_string_inputs_take_the_shortest_way_in() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.KATANA)
	var expect: Dictionary = {
		&"k_iai": "Heavy",
		&"k_iai_h": "Heavy + left/right",
		&"k_rdraw": "Heavy + left/right → Heavy",
		# the vertical Iai's heavy follow-up is the grip's (KE task 7, D5)
		&"k_coil": "Heavy → Heavy, one-handed",
		&"k_h1f": "Heavy → Heavy, two-handed",
	}
	for move_id: StringName in expect:
		var r: MoveList.Row = _row(rows, move_id, MoveList.Section.STRING)
		assert_not_null(r, String(move_id))
		if r != null:
			assert_eq(r.input, expect[move_id], String(move_id))
	assert_null(_row(rows, &"k_2l2", MoveList.Section.STRING), "the lights are in the grips' sections")


func test_other_ways_into_a_follow_up_are_listed() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.KATANA)
	assert_eq(Array(_row(rows, &"k_h1f", MoveList.Section.STRING).also_after), [], "the Iai's: one way in")
	assert_eq(Array(_row(rows, &"k_h1f", MoveList.Section.TWO_HANDED).also_after), [], "Heaven Splitter's: one way in")
	assert_eq(Array(_row(rows, &"k_1l1", MoveList.Section.ONE_HANDED).also_after), [])
	assert_eq(_row(rows, &"k_1l2", MoveList.Section.ONE_HANDED).also_after, PackedStringArray(["Iai Slash (horizontal)"]), "the horizontal Iai's light plays the grip's hit 2")


func test_strings_read_light_first_then_each_heavy_branch() -> void:
	assert_eq(_names(MoveList.rows(Moves.KATANA), MoveList.Section.STRING), [
		"Iai Slash (vertical)", "Iai Slash (horizontal)", "Returning Draw", "Crescent Coil", "Rising Heaven",
	])
	assert_eq(_names(MoveList.rows(Moves.GREATSWORD), MoveList.Section.STRING), [
		"Heavy Swing", "Backswing", "Overhead Strike", "Low Sweep",
	])


func test_a_chargeable_heavy_says_so() -> void:
	var rows: Array[MoveList.Row] = MoveList.rows(Moves.KATANA)
	assert_string_contains(_row(rows, &"k_iai").note, "hold to charge")
	assert_eq(_row(rows, &"k_2l1").note, "")


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
