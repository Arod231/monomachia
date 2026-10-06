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
			&"weapon_clatter"]:
		used.append(extra)
	for cue_name: StringName in SoundBank.CUES:
		assert_true(used.has(cue_name) or direct.has(cue_name), "cue %s is never played" % cue_name)


func test_hit_sound_follows_the_event_sound_field() -> void:
	assert_eq(_cue_names({"t": "hit", "sound": "blade", "heavy": false}), [&"hit_blade"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "blade", "heavy": true}), [&"hit_blade_heavy"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "dagger", "heavy": true}), [&"hit_dagger"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "fist", "heavy": false}), [&"hit_fist"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "fist", "heavy": true}), [&"hit_fist_heavy"] as Array[StringName])
	assert_eq(_cue_names({"t": "hit", "sound": "colossal", "heavy": true}), [&"hit_colossal", &"crunch"] as Array[StringName])


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
