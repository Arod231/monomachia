extends GutTest
## GameSettings: the player's settings, saved to a ConfigFile: the graphics
## preset (Ultra, the reference, by default; without a known one saved, the
## first launch picks it from the graphics card, milestone-1 task 29) and the
## master, effects and music volumes (80, 90 and 100 by default, 0-100 in steps
## of 5), applied to the buses on top of the bus layout's own levels. Test and
## shot runs ask for the defaults. These tests save to a test path, never the
## player's file.

const PATH: String = "user://test_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	# The buses as GameServices set them at start (test runs use the defaults).
	GameSettings.new().apply_volumes()


func _saved_low() -> void:
	var settings := GameSettings.new()
	settings.set_graphics_preset(&"low")
	settings.save(PATH)


func test_the_graphics_preset_is_ultra_by_default() -> void:
	var settings := GameSettings.new()
	assert_eq(settings.graphics_preset_id, &"ultra")
	assert_eq(settings.graphics_preset().id, &"ultra")
	assert_eq(GameSettings.PATH, "user://settings.cfg")


func test_the_first_launch_picks_the_preset_from_the_graphics_card() -> void:
	assert_eq(GameSettings.load_from(PATH, "NVIDIA GeForce RTX 3080").graphics_preset_id, &"ultra")
	assert_eq(GameSettings.load_from(PATH, "AMD Radeon(TM) Graphics").graphics_preset_id, &"low", "the laptop")
	assert_eq(GameSettings.load_from(PATH, "A card from the future").graphics_preset_id, &"medium")
	assert_eq(GameSettings.load_from(PATH).graphics_preset_id, GraphicsPreset.for_card(RenderingServer.get_video_adapter_name()),
		"this machine's card by default")


func test_a_saved_preset_wins_over_the_card() -> void:
	_saved_low()
	assert_eq(GameSettings.load_from(PATH, "NVIDIA GeForce RTX 4090").graphics_preset_id, &"low")


func test_the_preset_saves_and_loads() -> void:
	var settings := GameSettings.new()
	assert_true(settings.set_graphics_preset(&"low"))
	assert_eq(settings.graphics_preset().id, &"low")
	assert_eq(settings.save(PATH), OK)
	assert_eq(GameSettings.load_from(PATH).graphics_preset_id, &"low")


func test_an_unknown_preset_is_refused_however_it_is_set() -> void:
	var settings := GameSettings.new()
	settings.set_graphics_preset(&"medium")
	assert_false(settings.set_graphics_preset(&"extreme"))
	assert_eq(settings.graphics_preset_id, &"medium", "unchanged")
	settings.graphics_preset_id = &"extreme"
	assert_eq(settings.graphics_preset_id, &"medium", "assigning it directly changes nothing either")
	assert_eq(settings.graphics_preset().id, &"medium")


func test_an_unknown_saved_preset_picks_from_the_card() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(GameSettings.SECTION_GRAPHICS, "preset", "extreme")
	cfg.save(PATH)
	assert_eq(GameSettings.load_from(PATH, "NVIDIA GeForce RTX 3070").graphics_preset_id, &"high")
	cfg.set_value(GameSettings.SECTION_GRAPHICS, "preset", 3)
	cfg.save(PATH)
	assert_eq(GameSettings.load_from(PATH, "NVIDIA GeForce RTX 3070").graphics_preset_id, &"high", "not even a string")


func test_an_unreadable_file_gives_the_defaults() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[graphics\npreset = = \n")
	f.close()
	assert_eq(GameSettings.load_from(PATH, "Intel(R) UHD Graphics 620").graphics_preset_id, &"low", "picked from the card")
	assert_engine_error("ConfigFile parse error")


func test_a_run_asking_for_the_defaults_ignores_the_saved_file() -> void:
	_saved_low()
	assert_eq(GameSettings.load_for_run(true, PATH).graphics_preset_id, &"ultra", "the reference")
	assert_eq(GameSettings.load_for_run(false, PATH).graphics_preset_id, &"low")
	assert_true(OS.has_environment(GameSettings.DEFAULTS_ENV), "godot.mjs runs the tests with the defaults")


# ------------------------------------------------------------------ volumes

const VOLUME_BUSES: Dictionary = {
	&"Master": "master_volume",
	&"SFX": "effects_volume",
	&"UI": "effects_volume",
	&"Ambience": "effects_volume",
	&"Music": "music_volume",
}


func _bus_db(bus: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _muted(bus: StringName) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))


func test_the_volumes_start_at_80_90_and_100() -> void:
	var settings := GameSettings.new()
	assert_eq(settings.master_volume, 80)
	assert_eq(settings.effects_volume, 90)
	assert_eq(settings.music_volume, 100)


func test_the_volumes_save_and_load() -> void:
	var settings := GameSettings.new()
	settings.master_volume = 35
	settings.effects_volume = 0
	settings.music_volume = 55
	settings.set_graphics_preset(&"low")
	assert_eq(settings.save(PATH), OK)
	var loaded := GameSettings.load_from(PATH)
	assert_eq([loaded.master_volume, loaded.effects_volume, loaded.music_volume], [35, 0, 55])
	assert_eq(loaded.graphics_preset_id, &"low", "alongside the graphics preset")
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	assert_eq(cfg.get_value(GameSettings.SECTION_AUDIO, "music"), 55, "in the file's [audio] section")


func test_volumes_clamp_to_0_100_and_snap_to_steps_of_5() -> void:
	var settings := GameSettings.new()
	settings.master_volume = 103
	assert_eq(settings.master_volume, 100)
	settings.master_volume = -7
	assert_eq(settings.master_volume, 0)
	settings.effects_volume = 42
	assert_eq(settings.effects_volume, 40)
	settings.effects_volume = 43
	assert_eq(settings.effects_volume, 45)
	settings.music_volume = 2
	assert_eq(settings.music_volume, 0)


func test_saved_volumes_out_of_range_snap_and_unreadable_ones_fall_back() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(GameSettings.SECTION_AUDIO, "master", 203)
	cfg.set_value(GameSettings.SECTION_AUDIO, "effects", 61.0)
	cfg.set_value(GameSettings.SECTION_AUDIO, "music", "loud")
	cfg.save(PATH)
	var loaded := GameSettings.load_from(PATH)
	assert_eq(loaded.master_volume, 100)
	assert_eq(loaded.effects_volume, 60)
	assert_eq(loaded.music_volume, 100, "not a number: the default")


func test_a_file_without_volumes_gives_the_default_volumes() -> void:
	_saved_low()
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.erase_section(GameSettings.SECTION_AUDIO)
	cfg.save(PATH)
	var loaded := GameSettings.load_from(PATH)
	assert_eq([loaded.master_volume, loaded.effects_volume, loaded.music_volume], [80, 90, 100])
	assert_eq(loaded.graphics_preset_id, &"low")


func test_at_100_every_bus_plays_at_its_layout_level() -> void:
	var settings := GameSettings.new()
	settings.master_volume = 100
	settings.effects_volume = 100
	settings.music_volume = 100
	settings.apply_volumes()
	for bus: StringName in VOLUME_BUSES:
		assert_almost_eq(_bus_db(bus), GameSettings.layout_volume_db(bus), 1e-4, "%s at its layout level" % bus)
		assert_false(_muted(bus))
	assert_almost_eq(_bus_db(&"Music"), _bus_db(&"Master") - 6.0, 1e-4, "the music sits 6 dB under the rest")


func test_each_volume_drives_its_own_buses() -> void:
	for name: String in ["master_volume", "effects_volume", "music_volume"]:
		var settings := GameSettings.new()
		settings.master_volume = 100
		settings.effects_volume = 100
		settings.music_volume = 100
		settings.set(name, 50)
		settings.apply_volumes()
		for bus: StringName in VOLUME_BUSES:
			var expected := GameSettings.layout_volume_db(bus) + (linear_to_db(0.5) if VOLUME_BUSES[bus] == name else 0.0)
			assert_almost_eq(_bus_db(bus), expected, 1e-4, "%s at 50: %s" % [name, bus])


func test_applying_again_does_not_stack() -> void:
	var settings := GameSettings.new()
	settings.music_volume = 50
	settings.apply_volumes()
	settings.apply_volumes()
	assert_almost_eq(_bus_db(&"Music"), GameSettings.layout_volume_db(&"Music") + linear_to_db(0.5), 1e-4)


func test_a_volume_of_0_mutes_its_buses_and_raising_it_unmutes_them() -> void:
	var settings := GameSettings.new()
	settings.effects_volume = 0
	settings.apply_volumes()
	for bus: StringName in [&"SFX", &"UI", &"Ambience"]:
		assert_true(_muted(bus), "%s muted" % bus)
	assert_false(_muted(&"Music"))
	assert_false(_muted(&"Master"))
	settings.effects_volume = 5
	settings.apply_volumes()
	for bus: StringName in [&"SFX", &"UI", &"Ambience"]:
		assert_false(_muted(bus), "%s back" % bus)
		assert_almost_eq(_bus_db(bus), GameSettings.layout_volume_db(bus) + linear_to_db(0.05), 1e-4)


func test_the_layout_levels_come_from_the_bus_layout_file() -> void:
	assert_eq(GameSettings.layout_volume_db(&"Music"), -6.0)
	assert_eq(GameSettings.layout_volume_db(&"Master"), 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), -30.0)
	assert_eq(GameSettings.layout_volume_db(&"Music"), -6.0, "whatever the bus is set to now")


## Reduce flashes and shaking (off) and button hints (on), the Settings
## screen's two switches (task 22.9; the effects (18.11) and the prompts
## (24.4) read them).
func test_reduce_flashes_starts_off_and_button_hints_on() -> void:
	var settings := GameSettings.new()
	assert_false(settings.reduce_flashes)
	assert_true(settings.button_hints)
	assert_false(GameSettings.load_from(PATH).reduce_flashes, "a missing file too")
	assert_true(GameSettings.load_from(PATH).button_hints)


func test_reduce_flashes_and_button_hints_save_and_load() -> void:
	var settings := GameSettings.new()
	settings.reduce_flashes = true
	settings.button_hints = false
	assert_eq(settings.save(PATH), OK)
	var loaded := GameSettings.load_from(PATH)
	assert_true(loaded.reduce_flashes)
	assert_false(loaded.button_hints)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	assert_eq(cfg.get_value(GameSettings.SECTION_DISPLAY, "reduce_flashes"), true, "in the file's [display] section")
	assert_eq(cfg.get_value(GameSettings.SECTION_DISPLAY, "button_hints"), false)


func test_unreadable_switches_fall_back_to_their_defaults() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(GameSettings.SECTION_DISPLAY, "reduce_flashes", "yes")
	cfg.set_value(GameSettings.SECTION_DISPLAY, "button_hints", 0)
	cfg.save(PATH)
	var loaded := GameSettings.load_from(PATH)
	assert_false(loaded.reduce_flashes, "not a bool: the default")
	assert_true(loaded.button_hints, "not a bool: the default")


## The Blood setting (milestone-1 task 38): On, Reduced or Off, On by
## default, saved in [display] and read back; anything else is On.
func test_blood_starts_on() -> void:
	assert_eq(GameSettings.new().blood, GameSettings.BLOOD_ON)
	assert_eq(GameSettings.load_from(PATH).blood, GameSettings.BLOOD_ON, "a missing file too")
	assert_eq(GameSettings.BLOOD_LEVELS, [GameSettings.BLOOD_ON, GameSettings.BLOOD_REDUCED, GameSettings.BLOOD_OFF] as Array[StringName])


func test_blood_saves_and_loads() -> void:
	for level: StringName in GameSettings.BLOOD_LEVELS:
		var settings := GameSettings.new()
		settings.blood = level
		assert_eq(settings.save(PATH), OK)
		assert_eq(GameSettings.load_from(PATH).blood, level)
		var cfg := ConfigFile.new()
		cfg.load(PATH)
		assert_eq(cfg.get_value(GameSettings.SECTION_DISPLAY, "blood"), String(level), "in the file's [display] section")


func test_an_unknown_blood_level_is_on() -> void:
	var settings := GameSettings.new()
	settings.blood = &"gallons"
	assert_eq(settings.blood, GameSettings.BLOOD_ON, "an unknown level is ignored")
	var cfg := ConfigFile.new()
	cfg.set_value(GameSettings.SECTION_DISPLAY, "blood", "gallons")
	cfg.save(PATH)
	assert_eq(GameSettings.load_from(PATH).blood, GameSettings.BLOOD_ON)
