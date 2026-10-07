extends GutTest
## The event-to-sound table: every rules event has an entry, every file it
## names exists and loads, and the demo's sub-selection rules hold.

## The web demo's event list (v0.1-web-mvp:src/sim/events.ts) plus the menu sounds,
## its weaponBounce become weaponStuck (milestone-1 task 86).
const EXPECTED_EVENTS: Array[StringName] = [
	&"swing", &"telegraph", &"hit", &"block", &"parry", &"counter", &"evade", &"disarm",
	&"stagger", &"dodge", &"jump", &"land", &"step", &"ko", &"ultReady", &"ultStart",
	&"ultChoice", &"ultWave", &"ultDash", &"ultImpale", &"ultBurst", &"ultLightning",
	&"recall", &"pickup", &"recallBurst", &"weaponStuck", &"counterReady", &"backstabReady",
	&"roundStart", &"fight", &"roundOver", &"matchOver",
	&"ui_move", &"ui_select", &"ui_back",
]


func _cue_names(event: Dictionary) -> Array[StringName]:
	var names: Array[StringName] = []
	for cue: Dictionary in SoundBank.cues_for(event):
		names.append(cue["cue"])
	return names


func test_every_event_type_has_an_entry() -> void:
	for type: StringName in EXPECTED_EVENTS:
		assert_true(SoundBank.EVENTS.has(type), "no sound bank entry for event %s" % type)


func test_every_event_cue_is_defined() -> void:
	for cue_name: StringName in SoundBank.all_event_cues():
		assert_true(SoundBank.CUES.has(cue_name), "event cue %s is not in CUES" % cue_name)


func test_every_file_exists_and_loads_as_an_audio_stream() -> void:
	var checked := 0
	for cue_name: StringName in SoundBank.CUES:
		var files: Array = SoundBank.CUES[cue_name]["files"]
		assert_gt(files.size(), 0, "cue %s has no files" % cue_name)
		for path: String in SoundBank.paths_for(cue_name):
			assert_true(ResourceLoader.exists(path), "missing sound file %s" % path)
			var stream: Resource = load(path)
			assert_true(stream is AudioStream, "%s does not load as an AudioStream" % path)
			if stream is AudioStream:
				assert_gt((stream as AudioStream).get_length(), 0.0, "%s is empty" % path)
			checked += 1
	assert_gt(checked, 60, "expected the full set of sound files")


func test_every_cue_has_a_valid_bus_and_settings() -> void:
	for cue_name: StringName in SoundBank.CUES:
		var cue: Dictionary = SoundBank.CUES[cue_name]
		assert_has(SoundBank.BUSES, cue["bus"], "cue %s uses an unknown bus" % cue_name)
		assert_true(AudioServer.get_bus_index(cue["bus"]) >= 0, "bus %s is not in the bus layout" % cue["bus"])
		var pitch: Vector2 = cue["pitch"]
		assert_true(pitch.x > 0.0 and pitch.x <= pitch.y, "cue %s has a bad pitch range" % cue_name)
		assert_true(cue["spatial"] is bool)
		assert_true(float(cue["volume_db"]) <= 0.0, "cue %s is boosted above unity" % cue_name)


func test_every_cue_is_used_by_an_event_or_documented_as_direct() -> void:
	# Footsteps follow the walk cycle and the ambience follows the arena, not events.
	var direct: Array[StringName] = [&"footstep", &"ambience_shrine"]
	var used := SoundBank.all_event_cues()
	for extra: StringName in [&"roll", &"whoosh_heavy", &"whoosh_small", &"whoosh_colossal", &"hit_blade", &"hit_dagger",
			&"hit_fist", &"hit_fist_heavy", &"hit_colossal", &"clang_heavy", &"parry_flash", &"parry_redirect",
			&"weapon_clatter", &"clang_katana", &"clang_katana_heavy", &"parry_contact_katana", &"clang_fist", &"redirect_arm"]:
		used.append(extra)
	# the fighters' own cloth and gear, and their voices (task 36, task 114)
	for fighter: StringName in SoundBank.FOLEY:
		for moment: StringName in SoundBank.FOLEY[fighter]:
			used.append_array(SoundBank.FOLEY[fighter][moment])
	for voice: StringName in SoundBank.VOCALS:
		used.append_array(SoundBank.VOCALS[voice].values())
	# the deflect pairs' halves (task 136)
	for direction: StringName in SoundBank.DEFLECT_SOUNDS:
		for half: StringName in [&"deflect", &"recoil"]:
			for cue: Dictionary in SoundBank.deflect_pair_cues(direction, half):
				used.append(cue["cue"])
	for cue_name: StringName in SoundBank.CUES:
		assert_true(used.has(cue_name) or direct.has(cue_name), "cue %s is never played" % cue_name)


func test_hit_sound_follows_the_event_sound_field() -> void:
	assert_eq(_cue_names({"t": "hit", "sound": "blade", "heavy": false}), [&"hit_blade", &"hit_flesh"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "blade", "heavy": true}), [&"hit_blade_heavy", &"hit_flesh", &"crunch"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "dagger", "heavy": true}), [&"hit_dagger", &"hit_flesh", &"crunch"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "fist", "heavy": false}), [&"hit_fist"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "fist", "heavy": true}), [&"hit_fist_heavy"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "colossal", "heavy": true}), [&"hit_colossal", &"hit_flesh", &"crunch"] as Array[StringName])


func test_block_clang_follows_weight() -> void:
	assert_eq(_cue_names({"t": "block", "heavy": false}), [&"clang_light"] as Array[StringName])
	assert_eq(_cue_names({"t": "block", "heavy": true}), [&"clang_heavy"] as Array[StringName])


func test_parry_kinds_have_distinct_rings() -> void:
	assert_eq(_cue_names({"t": "parry", "kind": "parry"}), [&"parry_contact", &"parry_ring"] as Array[StringName])
	assert_eq(_cue_names({"t": "parry", "kind": "flash"}), [&"parry_contact", &"parry_flash"] as Array[StringName])
	assert_eq(_cue_names({"t": "parry", "kind": "redirect"}), [&"parry_redirect"] as Array[StringName])
	# the parry ring is not a block clang
	for file: String in SoundBank.CUES[&"parry_ring"]["files"]:
		assert_false(SoundBank.CUES[&"clang_light"]["files"].has(file))
		assert_false(SoundBank.CUES[&"clang_heavy"]["files"].has(file))


func test_counters_by_kind() -> void:
	assert_eq(_cue_names({"t": "counter", "kind": "stomp"}), [&"crunch", &"clang_heavy", &"taiko_light"] as Array[StringName])
	assert_eq(_cue_names({"t": "counter", "kind": "leap"}), [&"hit_fist_heavy", &"taiko_light"] as Array[StringName])
	assert_eq(_cue_names({"t": "counter", "kind": "evade"}), [&"dodge_swish", &"taiko_light"] as Array[StringName])
	var taiko: Dictionary = SoundBank.cues_for({"t": "counter", "kind": "stomp"})[2]
	assert_almost_eq(float(taiko["delay"]), 0.03, 0.0001)


## A roll and a backstep sound apart (authored-animation task 30): the
## backstep keeps the dash's swish and cloth, a roll tumbles.
func test_a_roll_and_a_backstep_play_different_cues() -> void:
	var roll: Array[StringName] = _cue_names({"t": "dodge", "f": 0, "back": false})
	var backstep: Array[StringName] = _cue_names({"t": "dodge", "f": 0, "back": true})
	assert_eq(roll, [&"roll"] as Array[StringName])
	assert_eq(backstep, [&"dodge_swish", &"dodge_cloth"] as Array[StringName])
	for cue: StringName in roll:
		assert_false(backstep.has(cue))
	assert_eq((SoundBank.CUES[&"roll"]["files"] as Array).size(), 3, "three takes")


func test_swing_whoosh_follows_weapon_and_weight() -> void:
	assert_eq(_cue_names({"t": "swing", "weapon": "katana", "heavy": false}), [&"whoosh_light"] as Array[StringName])
	assert_eq(_cue_names({"t": "swing", "weapon": "katana", "heavy": true}), [&"whoosh_heavy"] as Array[StringName])
	assert_eq(_cue_names({"t": "swing", "weapon": "greatsword", "heavy": false}), [&"whoosh_colossal"] as Array[StringName])
	assert_eq(_cue_names({"t": "swing", "weapon": "daggers", "heavy": false}), [&"whoosh_small"] as Array[StringName])
	assert_eq(_cue_names({"t": "swing", "weapon": "fists", "heavy": true}), [&"whoosh_light"] as Array[StringName])


func test_ultimate_telegraph_is_silent_but_others_warn() -> void:
	assert_eq(_cue_names({"t": "telegraph", "kind": "thrust"}), [&"telegraph"] as Array[StringName])
	assert_eq(_cue_names({"t": "telegraph", "kind": "ult"}), [] as Array[StringName])


## Until task 91 gives it its own sound (milestone-1 task 86).
func test_a_weapon_sticking_in_the_ground_lands_with_the_old_fast_bounce() -> void:
	assert_eq(_cue_names({"t": "weaponStuck", "owner": 0}), [&"weapon_bounce", &"weapon_clatter"] as Array[StringName])
	assert_eq(_cue_names({"t": "weaponBounce", "speed": 9.0}), [] as Array[StringName], "the bounce retired")


func test_event_fields_work_with_string_name_keys() -> void:
	assert_eq(_cue_names({&"t": &"block", &"heavy": true}), [&"clang_heavy"] as Array[StringName])


func test_ko_and_round_call_layers_are_timed() -> void:
	var ko: Array[Dictionary] = SoundBank.cues_for({"t": "ko"})
	assert_eq(ko.size(), 4)
	assert_almost_eq(float(ko[1]["delay"]), 0.1, 0.0001) # the demo's gong after the drum
	var call: Array[Dictionary] = SoundBank.cues_for({"t": "roundStart", "round": 1})
	assert_eq(call[0]["cue"], &"round_roll")
	assert_eq(call[1]["cue"], &"gong")
	assert_gt(float(call[1]["delay"]), 1.0)


func test_unknown_events_play_nothing() -> void:
	assert_eq(SoundBank.cues_for({"t": "noSuchEvent"}).size(), 0)


func test_variation_picker_avoids_repeats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := -1
	for i in 50:
		var picked: Array = SoundBank.pick_variation(&"footstep", rng, last)
		assert_ne(int(picked[1]), last)
		assert_true(str(picked[0]).begins_with(SoundBank.SFX_DIR))
		last = int(picked[1])
		var pitch := SoundBank.random_pitch(&"footstep", rng)
		assert_between(pitch, 0.92, 1.08)


func test_footsteps_have_six_variations() -> void:
	assert_eq((SoundBank.CUES[&"footstep"]["files"] as Array).size(), 6)


func test_ambience_bed_is_a_seamless_stereo_loop() -> void:
	var stream := load(SoundBank.paths_for(&"ambience_shrine")[0]) as AudioStreamWAV
	assert_not_null(stream)
	assert_true(stream.stereo, "ambience should be stereo")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_between(stream.get_length(), 60.0, 90.0)
	assert_eq(stream.loop_begin, 0)
	assert_almost_eq(stream.loop_end, roundi(stream.get_length() * stream.mix_rate), 1)


## The cues an event plays when the fighters on each side are [param cast],
## without their voices (task 114) unless [param voices].
func _cast_names(event: Dictionary, cast: Array, voices: bool = false) -> Array[StringName]:
	var names: Array[StringName] = []
	for cue: Dictionary in SoundBank.cues_for(event, cast):
		if voices or not SoundBank.is_vocal(cue["cue"]):
			names.append(cue["cue"])
	return names


## The cue dictionaries of the fighters' voices an event plays with [param cast].
func _vocals(event: Dictionary, cast: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cue: Dictionary in SoundBank.cues_for(event, cast):
		if SoundBank.is_vocal(cue["cue"]):
			out.append(cue)
	return out


static func _names(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(list)
	return out


## Metal impacts by the pair of weapons that meet (milestone-1 task 36): the
## Katana on the Katana has its own steel.
func test_a_katana_on_katana_block_picks_the_katana_pair_impact() -> void:
	var light := {"t": "block", "heavy": false, "weapon": &"katana", "defender_weapon": &"katana"}
	var heavy := {"t": "block", "heavy": true, "weapon": &"katana", "defender_weapon": &"katana"}
	assert_eq(_cue_names(light), [&"clang_katana"] as Array[StringName])
	assert_eq(_cue_names(heavy), [&"clang_katana_heavy"] as Array[StringName])
	for cue: StringName in [&"clang_katana", &"clang_katana_heavy"]:
		for file: String in SoundBank.CUES[cue]["files"]:
			for generic: StringName in [&"clang_light", &"clang_heavy"]:
				assert_false(SoundBank.CUES[generic]["files"].has(file), "%s is the Katana's own, not %s's" % [file, generic])


## The Katana against bare hands: a fist on the Katana's guard, and a bare
## hand turning the blade aside (the redirect's hand on the arm).
func test_bare_hands_against_the_katana_have_their_own_impacts() -> void:
	assert_eq(_cue_names({"t": "block", "heavy": false, "weapon": &"fists", "defender_weapon": &"katana"}),
		[&"clang_fist"] as Array[StringName])
	assert_eq(_cue_names({"t": "block", "heavy": true, "weapon": &"fists", "defender_weapon": &"katana"}),
		[&"clang_fist"] as Array[StringName])
	assert_eq(_cue_names({"t": "parry", "kind": "redirect", "weapon": &"katana", "defender_weapon": &"fists"}),
		[&"parry_redirect", &"redirect_arm"] as Array[StringName])
	assert_eq(_cue_names({"t": "parry", "kind": "parry", "weapon": &"fists", "defender_weapon": &"katana"}),
		[&"clang_fist", &"parry_ring"] as Array[StringName])


## Every other pair keeps today's clangs until milestone 2 brings its
## weapons to final quality, as does an event that names no weapons.
func test_other_pairs_keep_the_general_clangs() -> void:
	assert_eq(_cue_names({"t": "block", "heavy": false, "weapon": &"greatsword", "defender_weapon": &"katana"}),
		[&"clang_light"] as Array[StringName])
	assert_eq(_cue_names({"t": "block", "heavy": true, "weapon": &"katana", "defender_weapon": &"daggers"}),
		[&"clang_heavy"] as Array[StringName])
	assert_eq(_cue_names({"t": "parry", "kind": "parry", "weapon": &"daggers", "defender_weapon": &"daggers"}),
		[&"parry_contact", &"parry_ring"] as Array[StringName])
	assert_eq(_cue_names({"t": "parry", "kind": "redirect", "weapon": &"greatsword", "defender_weapon": &"fists"}),
		[&"parry_redirect"] as Array[StringName])


## A parry of the Katana by the Katana rings, distinct from a block: the
## pair's own contact under the parry ring (a Flash under its longer ring).
func test_a_katana_parry_plays_the_ring_distinct_from_a_block() -> void:
	var parry := _cue_names({"t": "parry", "kind": "parry", "weapon": &"katana", "defender_weapon": &"katana"})
	var flash := _cue_names({"t": "parry", "kind": "flash", "weapon": &"katana", "defender_weapon": &"katana"})
	var block := _cue_names({"t": "block", "heavy": false, "weapon": &"katana", "defender_weapon": &"katana"})
	assert_eq(parry, [&"parry_contact_katana", &"parry_ring"] as Array[StringName])
	assert_eq(flash, [&"parry_contact_katana", &"parry_flash"] as Array[StringName])
	for cue: StringName in parry:
		assert_false(block.has(cue), "the parry's %s is not the block's" % cue)
	for file: String in SoundBank.CUES[&"parry_contact_katana"]["files"]:
		assert_false(SoundBank.CUES[&"clang_katana"]["files"].has(file))


## Flesh and bone layers keyed to the hit: every blade hit adds the flesh
## layer and a heavy (an ability or ultimate counts) the bone; fists don't
## cut, and the Impaler's ultimate goes through.
func test_a_blade_hit_adds_the_flesh_and_bone_layers() -> void:
	var light := _cue_names({"t": "hit", "sound": "blade", "heavy": false, "weapon": &"katana", "defender_weapon": &"katana"})
	var heavy := _cue_names({"t": "hit", "sound": "blade", "heavy": true, "weapon": &"katana", "defender_weapon": &"fists"})
	assert_eq(light, [&"hit_blade", &"hit_flesh"] as Array[StringName])
	assert_eq(heavy, [&"hit_blade_heavy", &"hit_flesh", &"crunch"] as Array[StringName])
	assert_false(_cue_names({"t": "hit", "sound": "fist", "heavy": true}).has(&"hit_flesh"), "fists draw no blood")
	assert_eq(_cue_names({"t": "ultImpale", "f": 0, "target": 1}), [&"hit_blade_heavy", &"hit_flesh", &"crunch"] as Array[StringName])
	# the cut and the flesh are separate recordings now
	for file: String in SoundBank.CUES[&"hit_flesh"]["files"]:
		assert_false(SoundBank.CUES[&"hit_blade"]["files"].has(file))
		assert_false(SoundBank.CUES[&"hit_blade_heavy"]["files"].has(file))


## The Hunter's own cloth and gear (milestone-1 task 36): under every
## footfall, on each swing, and on dodges, rolls and landings; the Rogue
## keeps the general cloth.
func test_the_hunter_s_cloth_and_gear_movement_has_entries() -> void:
	var hunter: Dictionary = SoundBank.FOLEY[&"hunter"]
	for moment: StringName in [&"step", &"swing", &"dodge", &"roll", &"land"]:
		assert_true(hunter.has(moment), "the Hunter moves at %s" % moment)
		assert_gt((hunter[moment] as Array).size(), 0)
		for cue: StringName in hunter[moment]:
			assert_true(SoundBank.CUES.has(cue), "%s is a cue" % cue)
			assert_eq(SoundBank.CUES[cue]["bus"], SoundBank.BUS_FOLEY, "%s on the foley bus" % cue)
			assert_true(SoundBank.CUES[cue]["spatial"], "%s is placed" % cue)
	var cast: Array = [&"rogue", &"hunter"]
	var swing := {"t": "swing", "f": 1, "weapon": &"katana", "heavy": false}
	assert_eq(_cast_names(swing, cast), _names([&"whoosh_light"] + hunter[&"swing"]))
	assert_eq(_cast_names({"t": "swing", "f": 0, "weapon": &"katana", "heavy": false}, cast),
		[&"whoosh_light"] as Array[StringName], "the Rogue just swings")
	assert_eq(_cast_names({"t": "dodge", "f": 1, "back": true}, cast), _names([&"dodge_swish"] + hunter[&"dodge"]),
		"the Hunter's coat in place of the general cloth")
	assert_eq(_cast_names({"t": "dodge", "f": 0, "back": true}, cast), [&"dodge_swish", &"dodge_cloth"] as Array[StringName])
	assert_eq(_cast_names({"t": "dodge", "f": 1, "back": false}, cast), _names([&"roll"] + hunter[&"roll"]))
	assert_eq(_cast_names({"t": "land", "f": 1}, cast), _names([&"land"] + hunter[&"land"]))
	assert_eq(_cast_names({"t": "land", "f": 0}, cast), [&"land"] as Array[StringName])
	# without a cast (the old callers), nobody's own foley
	assert_eq(_cue_names(swing), [&"whoosh_light"] as Array[StringName])


func test_a_footfall_plays_the_footstep_and_the_hunter_s_cloth_and_gear() -> void:
	assert_eq(SoundBank.footfall_cues(&"rogue"), [&"footstep"] as Array[StringName])
	assert_eq(SoundBank.footfall_cues(&"hunter"), _names([&"footstep"] + SoundBank.FOLEY[&"hunter"][&"step"]))
	assert_eq(SoundBank.footfall_cues(&""), [&"footstep"] as Array[StringName])


## The hooks for the effort vocals (task 114): which events a fighter
## vocalises on, and at what moment.
func test_effort_vocal_hooks() -> void:
	var moments := func(e: Dictionary) -> Array:
		return SoundBank.vocal_moments(e).map(func(m: Dictionary) -> Array: return [m["moment"], m["side"]])
	assert_eq(moments.call({"t": "swing", "f": 1, "heavy": true}), [[&"kiai", 1]])
	assert_eq(moments.call({"t": "swing", "f": 0, "heavy": false}), [[&"exhale", 0]])
	assert_eq(moments.call({"t": "dodge", "f": 0, "back": false}), [[&"breath", 0]])
	assert_eq(moments.call({"t": "land", "f": 1}), [[&"breath", 1]])
	assert_eq(moments.call({"t": "hit", "attacker": 0, "target": 1, "heavy": false}), [[&"pain", 1]])
	assert_eq(moments.call({"t": "hit", "attacker": 0, "target": 1, "heavy": true}), [[&"pain_heavy", 1]])
	assert_eq(moments.call({"t": "ko", "loser": 0, "winner": 1}), [[&"death", 0]])
	assert_eq(moments.call({"t": "ko", "loser": -1, "winner": -1}), [[&"death", 0], [&"death", 1]], "a double K.O.")
	assert_eq(moments.call({"t": "block", "attacker": 0, "target": 1}), [], "nothing on a block")
	# the ultimate's roar (milestone-1 task 98, story 133): Moonsplitter's
	# wind-up and the recall's power-up (task 99)
	assert_eq(moments.call({"t": "ultStart", "f": 1, "ult": &"moonsplitter"}), [[&"roar", 1]])
	assert_eq(moments.call({"t": "recall", "f": 0}), [[&"roar", 0]])
	assert_eq(moments.call({"t": "ultStart", "f": 0, "ult": &"impaler"}), [], "not the other weapons' (milestone 2)")
	# a light's exhale is heard about one time in three
	var exhale: Dictionary = SoundBank.vocal_moments({"t": "swing", "f": 0, "heavy": false})[0]
	assert_almost_eq(float(exhale["chance"]), 1.0 / 3.0, 0.01)


## Placeholder effort vocals (milestone-1 task 114): every fighter speaks
## with the one male voice, which has a cue for every moment, placed at the
## fighter and heard on the combat bus.
func test_every_fighter_has_a_voice_with_every_moment() -> void:
	for fighter: StringName in MatchSide.FIGHTER_NAMES:
		var voice: StringName = SoundBank.voice_of(fighter)
		assert_true(SoundBank.VOCALS.has(voice), "%s speaks" % fighter)
		for moment: StringName in [&"kiai", &"exhale", &"breath", &"pain", &"pain_heavy", &"death", &"roar"]:
			assert_true(SoundBank.VOCALS[voice].has(moment), "%s has a %s" % [voice, moment])
			var cue: StringName = SoundBank.VOCALS[voice][moment]
			assert_true(SoundBank.CUES.has(cue), "%s is a cue" % cue)
			assert_true(SoundBank.is_vocal(cue))
			assert_eq(SoundBank.CUES[cue]["bus"], SoundBank.BUS_COMBAT)
			assert_true(SoundBank.CUES[cue]["spatial"], "%s comes from the fighter" % cue)
			assert_gt((SoundBank.CUES[cue]["files"] as Array).size(), 1, "%s has variations" % cue)
	assert_eq(SoundBank.voice_of(&""), &"", "nobody named, nobody speaks")


func test_the_fighters_vocalise_on_their_moments() -> void:
	var cast: Array = [&"hunter", &"rogue"]
	var names := func(e: Dictionary) -> Array:
		return _vocals(e, cast).map(func(c: Dictionary) -> StringName: return c["cue"])
	assert_eq(names.call({"t": "swing", "f": 0, "heavy": true, "weapon": &"katana"}), [&"vocal_kiai"])
	assert_eq(names.call({"t": "swing", "f": 0, "heavy": false, "weapon": &"katana"}), [&"vocal_exhale"])
	assert_eq(names.call({"t": "dodge", "f": 1, "back": false}), [&"vocal_breath"])
	assert_eq(names.call({"t": "land", "f": 0}), [&"vocal_breath"])
	assert_eq(names.call({"t": "hit", "attacker": 0, "target": 1, "heavy": false, "sound": &"blade"}), [&"vocal_pain"])
	assert_eq(names.call({"t": "hit", "attacker": 1, "target": 0, "heavy": true, "sound": &"blade"}), [&"vocal_pain_heavy"])
	assert_eq(names.call({"t": "ko", "loser": 1, "winner": 0, "finisher": true}), [&"vocal_death"])
	assert_eq(names.call({"t": "block", "attacker": 0, "target": 1, "heavy": true}), [])
	assert_eq(names.call({"t": "ultStart", "f": 0, "ult": &"moonsplitter"}), [&"vocal_roar"])
	assert_eq(names.call({"t": "recall", "f": 1}), [&"vocal_roar"])
	assert_eq(_vocals({"t": "swing", "f": 0, "heavy": true}, []), [] as Array[Dictionary], "no cast, no voices")
	# a light's exhale one time in three; the second side two semitones down
	assert_almost_eq(float(_vocals({"t": "swing", "f": 0, "heavy": false}, cast)[0]["chance"]), 1.0 / 3.0, 0.01)
	assert_eq(float(_vocals({"t": "swing", "f": 0, "heavy": true}, cast)[0]["chance"]), 1.0)
	assert_eq(float(_vocals({"t": "swing", "f": 0, "heavy": true}, cast)[0]["pitch_scale"]), 1.0)
	assert_almost_eq(float(_vocals({"t": "swing", "f": 1, "heavy": true}, cast)[0]["pitch_scale"]), pow(2.0, -2.0 / 12.0), 0.001)


## The deflect pairs' own sounds (milestone-1 task 136), by cut direction:
## every direction a pair can name has both halves, the parrier's deflect a
## steel scrape on the contact frame and a cloth snap as the guard turns,
## the attacker's recoil the thrown-back blade's whoosh and a stagger step,
## each at its frame in the recoil clip.
func test_each_deflect_direction_has_its_deflect_and_recoil_sounds() -> void:
	for direction: StringName in StateClips.DEFLECT_DIRECTIONS:
		assert_true(SoundBank.DEFLECT_SOUNDS.has(direction), "sounds for %s" % direction)
		var deflect := SoundBank.deflect_pair_cues(direction, &"deflect")
		var recoil := SoundBank.deflect_pair_cues(direction, &"recoil")
		assert_eq(deflect.size(), 2, "%s: a scrape and a cloth snap" % direction)
		assert_eq(recoil.size(), 2, "%s: a whoosh and a stagger" % direction)
		assert_eq(String(deflect[0]["cue"]), "deflect_scrape_%s" % direction, "%s's own scrape" % direction)
		assert_eq(int(deflect[0]["frame"]), 0, "%s: the scrape on the contact frame" % direction)
		assert_eq(deflect[0]["place"], &"contact", "where the blades meet")
		assert_eq(deflect[1]["cue"], &"deflect_cloth")
		assert_gt(int(deflect[1]["frame"]), 0, "the guard turns after the contact")
		assert_eq(String(recoil[0]["cue"]), "recoil_whoosh_%s" % direction, "%s's own whoosh" % direction)
		assert_eq(recoil[1]["cue"], &"recoil_stagger")
		assert_eq(recoil[1]["place"], &"feet")
		assert_lt(int(recoil[0]["frame"]), int(recoil[1]["frame"]), "thrown back, then the step")
		for cue: Dictionary in deflect + recoil:
			assert_true(SoundBank.CUES.has(cue["cue"]), "%s is a cue" % cue["cue"])
			assert_has([&"contact", &"chest", &"feet"], cue["place"])
	assert_eq(SoundBank.deflect_pair_cues(&"sideways", &"deflect"), [] as Array[Dictionary], "none for an unknown direction")


## The pairs' frames fall inside the clips they follow: the recoil's within
## its throw-back and settle (its markers, from the contact at 1.0x, in
## rules frames), so the sounds land on what the picture shows.
func test_each_pair_s_sounds_fall_inside_its_clips() -> void:
	var manifest := ClipManifest.read()
	for move: StringName in StateClips.shared().deflect_pairs:
		var pair: Dictionary = StateClips.shared().deflect_pairs[move]
		for half: StringName in [&"deflect", &"recoil"]:
			var markers: Dictionary = manifest.clips[pair[half]].markers
			var frames: int = roundi((float(markers["settle"]) - float(markers["contact"])) * 2.0)
			for cue: Dictionary in SoundBank.deflect_pair_cues(pair[&"direction"], half):
				assert_lt(int(cue["frame"]), frames, "%s's %s %s before its settle" % [move, half, cue["cue"]])


## Today's four lights map onto the four directions (Right Cut right to
## left, Return Cut left to right, Kesa Cut the diagonal, Crown Cut the
## overhead), each sounding apart.
func test_the_four_lights_sound_their_own_directions() -> void:
	var pairs := StateClips.shared().deflect_pairs
	var expected := {&"k_l1": &"right_to_left", &"k_l2": &"left_to_right", &"k_l3": &"diagonal", &"k_l4": &"overhead"}
	for move: StringName in expected:
		assert_eq(pairs[move][&"direction"], expected[move], "%s's direction" % move)
	var scrapes := {}
	var whooshes := {}
	for direction: StringName in StateClips.DEFLECT_DIRECTIONS:
		for file: String in SoundBank.CUES[SoundBank.deflect_pair_cues(direction, &"deflect")[0]["cue"]]["files"]:
			assert_false(scrapes.has(file), "%s is %s's alone" % [file, direction])
			scrapes[file] = true
		for file: String in SoundBank.CUES[SoundBank.deflect_pair_cues(direction, &"recoil")[0]["cue"]]["files"]:
			assert_false(whooshes.has(file), "%s is %s's alone" % [file, direction])
			whooshes[file] = true
	# the horizontal cuts slide longer than the overhead's short bite
	var long_slide := _longest(&"deflect_scrape_right_to_left")
	var bite := _longest(&"deflect_scrape_overhead")
	assert_gt(long_slide, bite + 0.1, "a longer slide on a horizontal cut (%.2f s against %.2f s)" % [long_slide, bite])
	for cue: StringName in [&"deflect_scrape_right_to_left", &"deflect_cloth", &"recoil_whoosh_overhead", &"recoil_stagger"]:
		assert_eq(SoundBank.CUES[cue]["bus"], &"Foley" if cue == &"deflect_cloth" or cue == &"recoil_stagger" else &"Combat")
		assert_true(SoundBank.CUES[cue]["spatial"], "%s plays where it happens" % cue)


func _longest(cue: StringName) -> float:
	var longest := 0.0
	for path: String in SoundBank.paths_for(cue):
		longest = maxf(longest, (load(path) as AudioStream).get_length())
	return longest


## Steel on steel: a parry or a Flash plays its pair's sounds; a redirect
## (a bare hand turning the blade) and a fist on a blade don't.
func test_only_steel_on_steel_parries_sound_their_pair() -> void:
	var parry := {"t": "parry", "kind": "parry", "weapon": &"katana", "defender_weapon": &"katana"}
	assert_true(SoundBank.sounds_deflect_pair(parry))
	assert_true(SoundBank.sounds_deflect_pair({"t": "parry", "kind": "flash", "weapon": &"katana", "defender_weapon": &"katana"}))
	assert_true(SoundBank.sounds_deflect_pair({"t": "parry", "kind": "parry", "weapon": &"greatsword", "defender_weapon": &"katana"}),
		"a parried heavy weapon sounds the pair it borrows")
	assert_false(SoundBank.sounds_deflect_pair({"t": "parry", "kind": "redirect", "weapon": &"katana", "defender_weapon": &"fists"}))
	assert_false(SoundBank.sounds_deflect_pair({"t": "parry", "kind": "parry", "weapon": &"fists", "defender_weapon": &"katana"}))
	assert_false(SoundBank.sounds_deflect_pair({"t": "block", "weapon": &"katana", "defender_weapon": &"katana"}))
	# the parry's own contact and ring stay as they were
	assert_eq(_cue_names(parry), [&"parry_contact_katana", &"parry_ring"] as Array[StringName])
