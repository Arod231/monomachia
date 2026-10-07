extends GutTest
## The markers frame data will be generated from (milestone-1 task 14), on
## each move's entry in the move-clip table (MoveClips): committed data that
## needs no packs. The Katana's and bare hands' moves carry stand-ins that
## give today's frame data exactly at 1.0x; the hidden weapons' moves and
## both Counter Lunges carry markers at their clips' events, so their frame
## data change when task 17 reads the table.

const TEMP: String = "user://move_markers_test.json"
## The moves whose markers sit at their clips' events (spec P10, P48).
const REAL: Array[StringName] = [&"k_lunge", &"f_lunge"]
## The moves re-keyed since, on real markers placed to their frame counts,
## within half a source frame of their clips' events (the light string: task 31,
## Right Cut and Return Cut; task 32, Kesa Cut and Crown Cut; and Breaker Palm,
## task 99).
const KEYED: Array[StringName] = [&"k_l1", &"k_l2", &"k_l3", &"k_l4", &"f_breaker"]
const REAL_WEAPONS: Array[StringName] = [&"greatsword", &"daggers"]


func _table() -> MoveClips:
	return MoveClips.read(ClipManifest.read())


func _read(data: Dictionary) -> MoveClips:
	var f: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var t: MoveClips = MoveClips.read(ClipManifest.read(), TEMP)
	DirAccess.remove_absolute(TEMP)
	return t


func _real(wid: StringName, id: StringName) -> bool:
	return REAL_WEAPONS.has(wid) or REAL.has(id) or KEYED.has(id)


## Each move's follow-ups (its chain_light and chain_heavy).
func _follow_ups(m: AttackDef) -> Array[StringName]:
	var out: Array[StringName] = []
	for f: StringName in [m.chain_light, m.chain_heavy]:
		if f != &"" and not out.has(f):
			out.append(f)
	return out


func test_every_move_of_every_weapon_has_markers() -> void:
	var t: MoveClips = _table()
	assert_eq(t.errors, PackedStringArray())
	for wid: StringName in Moves.WEAPONS:
		for id: StringName in (Moves.WEAPONS[wid] as WeaponDef).moves:
			var e: MoveClips.Entry = t.of(wid).get(id)
			assert_not_null(e, "%s has an entry" % id)
			if e != null:
				assert_false(e.markers.is_empty(), "%s has markers" % id)


func test_the_katanas_and_bare_hands_moves_are_stand_ins_and_the_rest_are_not() -> void:
	var t: MoveClips = _table()
	for wid: StringName in t.moves:
		for id: StringName in t.of(wid):
			var e: MoveClips.Entry = t.of(wid)[id]
			assert_eq(e.markers_stand_in, not _real(wid, id), "%s.%s" % [wid, id])


func test_stand_in_markers_give_todays_frame_data_exactly() -> void:
	var t: MoveClips = _table()
	for wid: StringName in [&"katana", &"fists"]:
		for id: StringName in t.of(wid):
			var e: MoveClips.Entry = t.of(wid)[id]
			if not e.markers_stand_in:
				continue
			var m: AttackDef = (Moves.WEAPONS[wid] as WeaponDef).moves[id]
			var fd: Dictionary = MoveClips.frame_data(e.markers)
			assert_eq(fd["startup"], m.startup, "%s startup" % id)
			assert_eq(fd["active"], m.active, "%s active" % id)
			assert_eq(fd["recovery"], m.recovery, "%s recovery" % id)
			assert_eq(fd["dodge_cancel_from"], m.dodge_cancel_from, "%s dodge cancel" % id)
			if m.dodge_cancel_from != AttackDef.UNSET:
				assert_eq(fd["dodge_cancel_to"], m.total_frames(), "%s: the window stays open to the move's end" % id)
			for f: StringName in _follow_ups(m):
				# today a follow-up starts two frames after the active frames end
				assert_eq(fd["branch"].get(f), m.startup + m.active + 2, "%s's branch point for %s" % [id, f])


func test_every_follow_up_has_a_branch_point_and_nothing_else_does() -> void:
	var t: MoveClips = _table()
	for wid: StringName in t.moves:
		for id: StringName in t.of(wid):
			var e: MoveClips.Entry = t.of(wid)[id]
			var m: AttackDef = (Moves.WEAPONS[wid] as WeaponDef).moves[id]
			var want: Array = _follow_ups(m)
			var have: Array = (e.markers.get("branch", {}) as Dictionary).keys()
			want.sort()
			have.sort()
			assert_eq(have, want, "%s.%s's branch points" % [wid, id])
			assert_eq(e.markers.has("dodge_cancel"), m.dodge_cancel_from != AttackDef.UNSET, "%s has a dodge-cancel window when it has a dodge cancel" % id)


func test_real_markers_sit_at_the_clips_events() -> void:
	var manifest: ClipManifest = ClipManifest.read()
	var t: MoveClips = MoveClips.read(manifest)
	for wid: StringName in t.moves:
		for id: StringName in t.of(wid):
			if not _real(wid, id):
				continue
			var e: MoveClips.Entry = t.of(wid)[id]
			assert_false(e.markers_stand_in, "%s" % id)
			# the clip's contact markers, to the nearest whole source frame
			var marks: Dictionary = e.marks if not e.marks.is_empty() else MoveClips.markers(e, manifest, PackedFloat64Array([0.0]))
			for pair: Array in [["windup", "windup"], ["active_start", "contact"], ["active_end", "contact_end"], ["settle", "settle"]]:
				assert_almost_eq(e.markers[pair[0]], float(marks[pair[1]]), 0.5, "%s's %s at its %s" % [id, pair[0], pair[1]])
				if not KEYED.has(id):
					assert_eq(e.markers[pair[0]], floorf(e.markers[pair[0]]), "%s's %s on a whole frame" % [id, pair[0]])


func test_frame_data_count_two_rules_frames_a_source_frame_from_the_wind_up() -> void:
	var fd: Dictionary = MoveClips.frame_data({"windup": 4.0, "active_start": 9.5, "active_end": 11.0, "settle": 20.0,
		"dodge_cancel": 14.0, "branch": {&"k_l2": 12.0}})
	assert_eq(fd["startup"], 11)
	assert_eq(fd["active"], 3)
	assert_eq(fd["recovery"], 18)
	assert_eq(fd["dodge_cancel_from"], 20)
	assert_eq(fd["dodge_cancel_to"], 32, "the window's end defaults to the settle")
	assert_eq(fd["branch"], {&"k_l2": 16})
	var none: Dictionary = MoveClips.frame_data({"windup": 0.0, "active_start": 3.0, "active_end": 4.0, "settle": 9.0})
	assert_eq(none["dodge_cancel_from"], AttackDef.UNSET, "no window")
	assert_eq(none["branch"], {})


func test_a_moves_markers_read() -> void:
	var t: MoveClips = _read({"katana": {"guard": "CombatIdle1H01", "moves": {
		"k_l1": {"clips": ["Attack1H01_R"], "markers_stand_in": true, "markers": {"windup": 0, "active_start": 5.5, "active_end": 7,
			"settle": 15, "dodge_cancel": 10, "dodge_cancel_end": 14, "branch": {"k_l2": 8}}},
	}}})
	assert_eq(t.errors, PackedStringArray())
	var e: MoveClips.Entry = t.of(&"katana")[&"k_l1"]
	assert_true(e.markers_stand_in)
	assert_eq(e.markers["active_start"], 5.5)
	assert_eq(e.markers["dodge_cancel_end"], 14.0)
	assert_eq(e.markers["branch"], {&"k_l2": 8.0})


func test_mistakes_in_markers_are_named() -> void:
	var m: Callable = func(extra: Dictionary) -> Dictionary:
		var base: Dictionary = {"windup": 0, "active_start": 5, "active_end": 7, "settle": 15}
		base.merge(extra, true)
		return {"clips": ["Attack1H01_R"], "markers": base}
	var t: MoveClips = _read({"katana": {"guard": "CombatIdle1H01", "moves": {
		"k_l1": m.call({"active_start": 5.25}),
		"k_l2": m.call({"active_end": 4}),
		"k_l3": {"clips": ["Attack1H01_R"], "markers": {"windup": 0, "active_start": 5, "settle": 15, "tempo": 2}},
		"k_l4": m.call({"dodge_cancel": 6}),
		"k_iai": m.call({"dodge_cancel_end": 12}),
		"k_h1f": m.call({"branch": {"g_l1": 8}}),
		"k_h2": m.call({"branch": {"k_l2": 4}}),
		"k_sl": {"clips": ["Attack1H01_R"], "markers_stand_in": true},
	}}})
	var want: Array[String] = [
		"katana.k_l1: marker active_start must be a whole or half source frame",
		"katana.k_l2: marker active_end must come after active_start",
		"katana.k_l3: unknown marker tempo",
		"katana.k_l3: no active_end marker",
		"katana.k_l4: the dodge-cancel window must open from active_end and close by the settle",
		"katana.k_iai: dodge_cancel_end needs a dodge_cancel",
		"katana.k_h1f: branch g_l1 is not a move of the katana",
		"katana.k_h2: branch k_l2 must come after active_start and by the settle",
		"katana.k_sl: markers_stand_in is true or false, and true only with markers",
	]
	for line: String in want:
		assert_has(t.errors, line)
	assert_eq(t.errors.size(), want.size(), str(t.errors))
