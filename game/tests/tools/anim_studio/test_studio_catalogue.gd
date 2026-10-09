extends GutTest
## The Studio's catalogue (tools/anim_studio/studio_catalogue.gd,
## docs/specs/animation-studio.md, task 4): every move, state, ultimate and
## source clip the gallery shows, built from the data the game reads. It needs
## no clip libraries: the badges follow the data and `force_missing`.

const TEMP_MOVES: String = "user://studio_catalogue_move_clips.json"
const TEMP_STATES: String = "user://studio_catalogue_state_clips.json"

var _manifest: ClipManifest
var _table: MoveClips
var _states: StateClips


func before_each() -> void:
	_manifest = ClipManifest.read()
	_table = MoveClips.read(_manifest)
	_states = StateClips.read()


func after_each() -> void:
	ClipLibraries.force_missing = false
	for path: String in [TEMP_MOVES, TEMP_STATES]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _keyed() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(StudioLibraries.keyed().get_animation_list())
	return out


func _build() -> StudioCatalogue:
	return StudioCatalogue.build(_manifest, _table, _states, _keyed())


func _ids(entries: Array[StudioCatalogue.Entry]) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: StudioCatalogue.Entry in entries:
		out.append(e.id)
	return out


func _of_kind(cat: StudioCatalogue, kind: StringName) -> Array[StudioCatalogue.Entry]:
	var out: Array[StudioCatalogue.Entry] = []
	for e: StudioCatalogue.Entry in cat.entries:
		if e.kind == kind:
			out.append(e)
	return out


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- moves -------------------------------------------------------------------


func test_the_shipped_data_reads_cleanly() -> void:
	var cat: StudioCatalogue = _build()
	assert_eq(cat.errors, PackedStringArray(), "the shipped files have no errors")
	for e: StudioCatalogue.Entry in cat.entries:
		assert_false(e.read_only, "%s/%s is editable" % [e.kind, e.id])


func test_every_move_appears_once_in_its_weapons_group_in_table_order() -> void:
	var cat: StudioCatalogue = _build()
	var total: int = 0
	for wid: StringName in _table.moves:
		var listed: Array[StudioCatalogue.Entry] = cat.in_group(wid)
		var want: Array[StringName] = []
		want.assign((_table.moves[wid] as Dictionary).keys())
		assert_eq(_ids(listed), want, "%s: the table's moves in the table's order" % wid)
		total += listed.size()
		for e: StudioCatalogue.Entry in listed:
			assert_eq(e.kind, &"move", "%s is a move" % e.id)
			assert_eq(cat.find(&"move", e.id), e, "%s is found" % e.id)
	assert_eq(total, 81, "81 moves in all (Crescent Coil the 71st, KE task 7; the one-handed string's own five, KE tasks 11 and 12; the two-handed string's own five, KE tasks 13 and 14)")
	assert_eq(_of_kind(cat, &"move").size(), 81, "and none outside a weapon's group")


func test_a_move_entry_carries_the_tables_clips_speed_and_the_rules_name() -> void:
	var cat: StudioCatalogue = _build()
	var e: StudioCatalogue.Entry = cat.find(&"move", &"k_flash")
	var m: MoveClips.Entry = _table.moves[&"katana"][&"k_flash"]
	assert_eq(e.group, &"katana", "the katana's group")
	assert_eq(e.name, (Moves.WEAPONS[&"katana"] as WeaponDef).moves[&"k_flash"].name, "the rules' display name")
	var clips: Array[String] = []
	clips.assign(m.clips)
	assert_eq(e.clips, clips, "a chain keeps its parts")
	assert_eq(e.speed, m.speed, "its speed")


func test_the_bare_hands_group_is_fists() -> void:
	var cat: StudioCatalogue = _build()
	assert_eq(cat.in_group(&"fists").size(), (_table.moves[&"fists"] as Dictionary).size(), "the table's fists key")
	assert_true(cat.in_group(&"bare").is_empty(), "no group is called bare")


# --- states and ultimates ----------------------------------------------------


func test_every_state_and_ult_appears() -> void:
	var cat: StudioCatalogue = _build()
	for id: StringName in [
		&"idle_katana", &"idle_daggers", &"idle_greatsword", &"idle_fists",
		&"hit_light", &"hit_heavy",
		&"guard_katana", &"guard_greatsword", &"guard_daggers", &"guard_fists",
		&"stun", &"carry", &"knockdown",
		&"ko_front_light", &"ko_front_heavy", &"ko_behind_light", &"ko_behind_heavy",
		&"stomp", &"stomp_stun",
	]:
		assert_not_null(cat.find(&"state", id), "state %s" % id)
	for id: StringName in [&"moonsplitter_vertical", &"moonsplitter_horizontal", &"impaler", &"tempest"]:
		assert_not_null(cat.find(&"ult", id), "ult %s" % id)
	assert_eq(cat.in_group(&"ults").size(), 4, "the ults group holds the ultimates")
	for e: StudioCatalogue.Entry in cat.in_group(&"ults"):
		assert_eq(e.kind, &"ult", "%s is an ult" % e.id)


func test_state_entries_play_the_tables_clips() -> void:
	# the frozen copy, so a saved edit of the live table can't change this
	var sc: StateClips = StateClips.read(FrozenStateClips.PATH)
	var cat: StudioCatalogue = StudioCatalogue.build(_manifest, _table, sc, _keyed())
	assert_eq(cat.find(&"state", &"idle_greatsword").clips, ["CombatIdle2H01"] as Array[String], "the greatsword's idle")
	assert_eq(cat.find(&"state", &"guard_katana").clips, ["Parry1H01_R_Loop", "Parry1H01_R_Hit"] as Array[String], "the guard's loop and hit")
	assert_eq(cat.find(&"state", &"knockdown").clips, ["Knockdown01_Fall", "Knockdown01_Ground", "Knockdown01_StandUp@6"] as Array[String], "the knockdown's three phases, the stand-up trimmed as the game plays it")
	assert_eq(cat.find(&"state", &"ko_behind_heavy").clips, ["CombatDeath04"] as Array[String], "a KO")
	assert_eq(cat.find(&"state", &"stomp").clips, ["keyed/Mikiri_Stomp"] as Array[String], "the keyed stomp is named with its library")
	assert_eq(cat.find(&"state", &"stomp_stun").clips, ["keyed/Mikiri_Pinned"] as Array[String], "and its pinned stun")
	assert_null(cat.find(&"state", &"rebound"), "the rebound retired (milestone-1 task 34)")
	assert_null(cat.find(&"state", &"deflect_k_l1"), "and the frozen table has no deflect pairs")
	var live: StudioCatalogue = StudioCatalogue.build(_manifest, _table, StateClips.read(), _keyed())
	assert_eq(live.find(&"state", &"deflect_k_l1").clips, ["RightCutDeflect", "RightCutRecoil"] as Array[String], "a deflect pair: the deflect and the recoil")
	# milestone-1 task 90
	assert_eq(live.find(&"state", &"deflect_redirect").clips, ["RedirectDeflect", "RedirectRecoil"] as Array[String], "the redirect's pair")
	assert_eq(live.find(&"state", &"deflect_foot_low").clips, ["LimbDeflectLow", "FootRecoil"] as Array[String], "a blade's low deflect at a foot")
	assert_eq(live.find(&"state", &"deflect_fist_high").clips, ["LimbDeflectHigh", "FistRecoil"] as Array[String], "and its high one at a fist")
	assert_eq(cat.find(&"ult", &"tempest").clips, ["ual/Sword_Aerial_Combo", "AttackDW02"] as Array[String], "the tempest's spin and final")
	assert_eq(cat.find(&"ult", &"moonsplitter_horizontal").clips, ["MoonsplitterStance", "MoonsplitterDrawHorizontal"] as Array[String], "a moonsplitter variant: the stance, then its draw")


func test_the_roll_and_locomotion_are_source_entries_of_the_states_group() -> void:
	var cat: StudioCatalogue = _build()
	for id: StringName in StudioCatalogue.MOVEMENT_CLIPS:
		var e: StudioCatalogue.Entry = cat.find(&"source", id)
		assert_not_null(e, "%s is listed" % id)
		assert_eq(e.group, &"states", "%s shows with the states" % id)
		assert_eq(e.clips, [String(id)] as Array[String], "%s plays itself" % id)
		assert_eq(e.source.size(), 1, "its one place is the manifest's")
		assert_eq(e.source[0].path, ClipManifest.PATH, "the clip manifest")
		assert_eq(_of_kind(cat, &"source").filter(func(x: StudioCatalogue.Entry) -> bool: return x.id == id).size(), 1, "%s once" % id)
	assert_eq(cat.find(&"source", &"Roll01").name, "Roll", "the roll")


# --- source clips -------------------------------------------------------------


func test_source_covers_the_manifest_the_ual_list_and_the_keyed_library() -> void:
	var cat: StudioCatalogue = _build()
	var sources: Array[StringName] = _ids(_of_kind(cat, &"source"))
	for id: StringName in _manifest.clips:
		assert_has(sources, id, "manifest clip %s" % id)
	var builder: GDScript = load("res://tools/build_animation_library.gd") as GDScript
	var ual: Array = builder.call(&"clip_names")
	assert_gt(ual.size(), 0, "the UAL list is read")
	for clip: StringName in ual:
		assert_has(sources, StringName("ual/%s" % clip), "UAL clip %s" % clip)
	var keyed: Array[StringName] = _keyed()
	assert_gt(keyed.size(), 0, "the keyed library has clips")
	for clip: StringName in keyed:
		assert_has(sources, StringName("keyed/%s" % clip), "keyed clip %s" % clip)
	assert_eq(sources.size(), _manifest.clips.size() + ual.size() + keyed.size(), "and nothing else")
	var seen: Dictionary = {}
	for id: StringName in sources:
		assert_false(seen.has(id), "%s is listed once" % id)
		seen[id] = true


func test_ual_and_keyed_entries_play_their_library() -> void:
	var cat: StudioCatalogue = _build()
	var e: StudioCatalogue.Entry = cat.find(&"source", &"ual/Sword_Idle")
	assert_eq(e.clips, ["ual/Sword_Idle"] as Array[String], "named with the library")
	assert_eq(e.group, &"source", "in the source group")
	assert_eq(e.source[0].path, "res://tools/build_animation_library.gd", "its place is the builder's list")
	assert_eq(e.source[0].key_path, ["LOOPING"] as Array[String], "a looping clip")
	var text: String = FileAccess.get_file_as_string(e.source[0].path)
	assert_true(text.split("\n")[e.source[0].line - 1].contains('&"Sword_Idle"'), "the line holds the clip's name")
	var k: StudioCatalogue.Entry = cat.find(&"source", &"keyed/Mikiri_Stomp")
	assert_eq(k.source[0].path, "res://assets/authored/keys/mikiri_stomp.json", "a keyed clip's place is its key-pose file")


# --- badges ------------------------------------------------------------------


func test_without_the_packs_every_move_carries_the_fallback_badge() -> void:
	ClipLibraries.force_missing = true
	var cat: StudioCatalogue = _build()
	for e: StudioCatalogue.Entry in _of_kind(cat, &"move"):
		assert_true(e.badges[&"fallback"], "%s plays its fallback" % e.id)
	for id: StringName in [&"idle_katana", &"hit_heavy", &"guard_fists", &"stun", &"knockdown", &"ko_front_light"]:
		assert_true(cat.find(&"state", id).badges[&"fallback"], "%s plays its fallback" % id)
	assert_true(cat.find(&"ult", &"impaler").badges[&"fallback"], "an ult plays its fallback")
	# the keyed clips and the pose have none: they play as they are
	assert_false(cat.find(&"state", &"stomp").badges[&"fallback"], "the keyed stomp plays without the packs")
	assert_false(cat.find(&"state", &"carry").badges[&"fallback"], "the carry pose has no fallback")
	assert_false(cat.find(&"source", &"ual/Sword_Idle").badges[&"fallback"], "a source clip isn't a fallback")


func test_every_fallback_badge_comes_with_the_fallback_clips_to_play() -> void:
	ClipLibraries.force_missing = true
	var cat: StudioCatalogue = _build()
	var badged: int = 0
	for e: StudioCatalogue.Entry in cat.entries:
		assert_eq(e.badges[&"fallback"], not e.fallbacks.is_empty(), "%s/%s: the badge says there is a fallback" % [e.kind, e.id])
		if not e.badges[&"fallback"]:
			continue
		badged += 1
		for fb: String in e.fallbacks:
			assert_true(fb.begins_with("ual/"), "%s: %s names the CC0 library" % [e.id, fb])
			assert_true(StudioLibraries.ual().has_animation(fb.get_slice("/", 1)), "%s: %s is in the CC0 library" % [e.id, fb])
		# a move has one fallback, stretched over its whole chain; a state or ult one per part
		if e.kind != &"move" and e.clips.size() > 1:
			assert_eq(e.fallbacks.size(), e.clips.size(), "%s: a fallback for each part" % e.id)
		else:
			assert_eq(e.fallbacks.size(), 1, "%s: one fallback" % e.id)
	assert_gt(badged, 70, "the moves and the states carry them")


func test_fallbacks_are_what_the_director_plays_without_the_packs() -> void:
	# the frozen copy, so a saved edit of the live table can't change this
	var sc: StateClips = StateClips.read(FrozenStateClips.PATH)
	var cat: StudioCatalogue = StudioCatalogue.build(_manifest, _table, sc, _keyed())
	assert_eq(cat.find(&"move", &"k_l1").fallbacks, ["ual/Sword_Light_A"] as Array[String], "a move's own")
	assert_eq(cat.find(&"state", &"idle_fists").fallbacks, ["ual/Idle"] as Array[String], "the idle's by weapon")
	assert_eq(cat.find(&"state", &"hit_heavy").fallbacks, ["ual/Hit_Head"] as Array[String], "the heavy hit's")
	assert_eq(cat.find(&"state", &"guard_daggers").fallbacks, ["ual/Sword_Block", "ual/Sword_Block"] as Array[String], "the guard's one, for the loop and the hit")
	assert_eq(cat.find(&"state", &"knockdown").fallbacks, ["ual/Hit_Knockback", "ual/LayToIdle", "ual/LayToIdle"] as Array[String], "one per knockdown phase")
	assert_eq(cat.find(&"state", &"ko_front_light").fallbacks, ["ual/Death01"] as Array[String], "the KO's")
	assert_eq(cat.find(&"ult", &"tempest").fallbacks, ["ual/Sword_Heavy_Combo", "ual/Sword_Heavy_Combo"] as Array[String], "the tempest's, for the spin and the final")
	assert_true(cat.find(&"state", &"stomp").fallbacks.is_empty(), "a keyed clip plays as it is")
	assert_true(cat.find(&"state", &"carry").fallbacks.is_empty(), "so does the carry pose")


func test_with_the_packs_nothing_carries_the_fallback_badge() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var cat: StudioCatalogue = _build()
	for e: StudioCatalogue.Entry in cat.entries:
		assert_false(e.badges[&"fallback"], "%s/%s plays its own clips" % [e.kind, e.id])


func test_provisional_clips_give_the_provisional_badge() -> void:
	# set here, so the check doesn't follow the flags the manifest ships with
	for c: ClipManifest.Clip in _manifest.clips.values():
		c.provisional = false
	var chain: Array[String] = []
	chain.assign((_table.moves[&"katana"][&"k_iai"] as MoveClips.Entry).clips)
	var part: ClipChain.Part = ClipChain.parse(chain[1], [] as Array[String])
	(_manifest.clips[part.id] as ClipManifest.Clip).provisional = true
	(_manifest.clips[&"Roll01"] as ClipManifest.Clip).provisional = true
	var cat: StudioCatalogue = _build()
	assert_true(cat.find(&"move", &"k_iai").badges[&"provisional"], "a move with a provisional clip in its chain")
	assert_false(cat.find(&"move", &"k_l2").badges[&"provisional"], "a move with none")
	assert_true(cat.find(&"source", part.id).badges[&"provisional"], "the source clip itself")
	assert_true(cat.find(&"source", &"Roll01").badges[&"provisional"], "a movement clip")
	assert_false(cat.find(&"source", &"ual/Sword_Idle").badges[&"provisional"], "a CC0 clip has no markers to be provisional")
	assert_false(cat.find(&"state", &"stomp").badges[&"provisional"], "nor a keyed one")


func test_every_entry_has_the_four_badges_and_starts_clean_of_the_studios() -> void:
	var cat: StudioCatalogue = _build()
	for e: StudioCatalogue.Entry in cat.entries:
		assert_eq(e.badges.size(), 4, "%s has four badges" % e.id)
		for b: StringName in [&"fallback", &"provisional", &"unsaved", &"balance"]:
			assert_true(e.badges.has(b), "%s has %s" % [e.id, b])
		assert_false(e.badges.has(&"corrective"), "%s has no corrective badge: correctives are dropped" % e.id)
		assert_false(e.badges[&"unsaved"] or e.badges[&"balance"], "%s starts clean" % e.id)


# --- where the data is -------------------------------------------------------


func test_a_moves_location_is_its_line_in_move_clips_json() -> void:
	var cat: StudioCatalogue = _build()
	var e: StudioCatalogue.Entry = cat.find(&"move", &"k_l2")
	assert_eq(e.source.size(), 1, "one place")
	var loc: StudioCatalogue.Location = e.source[0]
	assert_eq(loc.path, MoveClips.PATH, "move_clips.json")
	assert_eq(loc.key_path, ["katana", "moves", "k_l2"] as Array[String], "the move's object")
	var lines: PackedStringArray = FileAccess.get_file_as_string(MoveClips.PATH).split("\n")
	assert_true(lines[loc.line - 1].contains('"k_l2"'), "the line is the move's, 1-based")


func test_a_source_clips_location_is_its_line_in_the_manifest() -> void:
	var cat: StudioCatalogue = _build()
	var lines: PackedStringArray = FileAccess.get_file_as_string(ClipManifest.PATH).split("\n")
	for id: StringName in [&"Roll01", &"Attack1H01_R", &"StrafeRun01_Left"]:
		var loc: StudioCatalogue.Location = cat.find(&"source", id).source[0]
		assert_eq(loc.path, ClipManifest.PATH, "the clip manifest")
		assert_eq(loc.key_path, ["clips", String(id)] as Array[String], "the clip's object")
		assert_true(lines[loc.line - 1].contains("\"%s\": {" % id), "%s: line %d is its key" % [id, loc.line])
	for e: StudioCatalogue.Entry in _of_kind(cat, &"source"):
		for loc: StudioCatalogue.Location in e.source:
			assert_gt(loc.line, 0, "%s is placed" % e.id)


func test_a_states_locations_name_its_clips_and_fallbacks() -> void:
	var cat: StudioCatalogue = _build()
	var e: StudioCatalogue.Entry = cat.find(&"state", &"idle_katana")
	assert_eq(e.source.size(), 2, "the clip and its fallback")
	assert_eq(e.source[0].key_path, ["idle", "clips", "katana"] as Array[String], "the clip")
	assert_eq(e.source[1].key_path, ["idle", "fallbacks", "katana"] as Array[String], "the fallback")
	var lines: PackedStringArray = FileAccess.get_file_as_string(StateClips.PATH).split("\n")
	assert_true(lines[e.source[0].line - 1].contains('"katana"'), "the line holds the idle clips")
	for entry: StudioCatalogue.Entry in cat.entries:
		for loc: StudioCatalogue.Location in entry.source:
			assert_gt(loc.line, 0, "%s: %s is found in %s" % [entry.id, loc.key_path, loc.path])


# --- read errors -------------------------------------------------------------


func test_a_mistake_in_move_clips_json_lists_it_and_makes_the_moves_read_only() -> void:
	var text: String = FileAccess.get_file_as_string(MoveClips.PATH)
	var broken: String = text.replace('"k_l1": {"clips"', '"k_l1": {"bogus": 1, "clips"')
	assert_ne(broken, text, "the copy is broken")
	_write(TEMP_MOVES, broken)
	_table = MoveClips.read(_manifest, TEMP_MOVES)
	var cat: StudioCatalogue = _build()
	assert_gt(cat.errors.size(), 0, "the mistake is listed")
	assert_true(cat.errors[0].begins_with("move_clips.json: "), "with its file: %s" % cat.errors[0])
	assert_true(cat.errors[0].contains("bogus"), "and what is wrong")
	var moves: Array[StudioCatalogue.Entry] = _of_kind(cat, &"move")
	assert_gt(moves.size(), 0, "the moves still show")
	for e: StudioCatalogue.Entry in moves:
		assert_true(e.read_only, "%s is read-only" % e.id)
	for e: StudioCatalogue.Entry in cat.entries:
		if e.kind != &"move":
			assert_false(e.read_only, "%s/%s comes from a file that read" % [e.kind, e.id])


func test_a_move_clips_file_that_is_not_an_object_lists_it_and_has_no_moves() -> void:
	_write(TEMP_MOVES, "[1, 2]")
	_table = MoveClips.read(_manifest, TEMP_MOVES)
	var cat: StudioCatalogue = _build()
	assert_gt(cat.errors.size(), 0, "listed")
	assert_true(cat.errors[0].begins_with("move_clips.json: "), "with its file")
	assert_eq(_of_kind(cat, &"move").size(), 0, "nothing of it to show")
	assert_gt(cat.in_group(&"states").size(), 0, "the rest still builds")


func test_a_mistake_in_state_clips_json_makes_the_states_and_ults_read_only() -> void:
	var text: String = FileAccess.get_file_as_string(StateClips.PATH)
	var broken: String = text.replace('"carry": {"pose":', '"carry": {"bogus": 1, "pose":')
	assert_ne(broken, text, "the copy is broken")
	_write(TEMP_STATES, broken)
	_states = StateClips.read(TEMP_STATES)
	var cat: StudioCatalogue = _build()
	assert_gt(cat.errors.size(), 0, "listed")
	assert_true(cat.errors[0].begins_with("state_clips.json: "), "with its file: %s" % cat.errors[0])
	for e: StudioCatalogue.Entry in cat.entries:
		var from_states: bool = e.kind == &"state" or e.kind == &"ult"
		assert_eq(e.read_only, from_states, "%s/%s" % [e.kind, e.id])


func test_a_manifest_with_errors_makes_its_source_entries_read_only() -> void:
	_manifest.errors.append("Roll01: marker settle missing or not a whole frame")
	var cat: StudioCatalogue = _build()
	assert_eq(cat.errors, PackedStringArray(["clip_manifest.json: Roll01: marker settle missing or not a whole frame"]), "listed with its file")
	assert_true(cat.find(&"source", &"Roll01").read_only, "a manifest clip")
	assert_true(cat.find(&"source", &"Walk01_Forward").read_only, "a locomotion clip")
	assert_false(cat.find(&"source", &"ual/Sword_Idle").read_only, "the CC0 list is another file")
	assert_false(cat.find(&"move", &"k_l1").read_only, "so are the moves")
