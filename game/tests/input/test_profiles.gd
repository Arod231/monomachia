extends GutTest
## Controls profiles: saving and loading, filling in actions an older save
## lacks, renaming, creating and deleting, and the reset and fight-stick
## presets.

const PATH: String = "user://test_controls.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_a_new_store_has_one_default_profile() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	assert_eq(store.profiles.size(), 1)
	assert_eq(store.active, 0)
	assert_eq(store.active_profile().name, "Player 1")
	assert_eq(store.active_profile().kb, Bindings.default_kb())
	assert_eq(store.active_profile().pad, Bindings.default_pad())


func test_save_and_load_round_trip() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	store.active_profile().bind(ControlProfile.KB, "light", 0, InputToken.key(KEY_Z))
	var arcade: ControlProfile = store.add_profile()
	store.rename(1, "Arcade stick")
	arcade.use_fight_stick_layout()
	arcade.clear_slot(ControlProfile.KB, "pause", 1)
	store.add_profile()
	store.set_active(1)
	assert_eq(store.save(PATH), OK)

	var loaded: ControlProfiles = ControlProfiles.load_from(PATH)
	assert_eq(loaded.profiles.size(), 3)
	assert_eq(loaded.active, 1)
	assert_eq(loaded.names(), PackedStringArray(["Player 1", "Arcade stick", "Player 3"]))
	for i: int in 3:
		assert_eq(loaded.profiles[i].to_dict(), store.profiles[i].to_dict(), "profile %d" % i)
	assert_eq(loaded.profiles[0].slots(ControlProfile.KB, "light"), [InputToken.key(KEY_Z), InputToken.key(KEY_J)] as Array[String])
	assert_eq(loaded.active_profile().pad, Bindings.fight_stick_pad())


func test_a_missing_file_gives_one_default_profile() -> void:
	var loaded: ControlProfiles = ControlProfiles.load_from("user://no_such_controls.cfg")
	assert_eq(loaded.profiles.size(), 1)
	assert_eq(loaded.active_profile().to_dict(), ControlProfile.create().to_dict())


func test_an_unreadable_file_gives_one_default_profile() -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("this is [not a config file\n= = =")
	f.close()
	var loaded: ControlProfiles = ControlProfiles.load_from(PATH)
	assert_engine_error("ConfigFile parse error", "Godot reports the bad file")
	assert_eq(loaded.profiles.size(), 1)
	assert_eq(loaded.active_profile().to_dict(), ControlProfile.create().to_dict())


func test_loading_fills_missing_actions_from_the_defaults_and_clamps_active() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "version", 1)
	cfg.set_value("controls", "active", 7)
	# an older save: a few actions, no controller set
	cfg.set_value("profile_0", "name", "Old")
	cfg.set_value("profile_0", "kb", {"up": ["k:87"], "light": ["m:1"], "jump": []})
	# junk tokens, tokens on the wrong tab, duplicates, no name
	cfg.set_value("profile_1", "kb", {"light": ["b:3", "k:74", "zz", 5, "k:74", "k:75", "k:76"], "heavy": "k:75"})
	cfg.set_value("profile_1", "pad", {"light": ["b:10", "k:74", "a:5+", "a:x+"]})
	assert_eq(cfg.save(PATH), OK)

	var loaded: ControlProfiles = ControlProfiles.load_from(PATH)
	assert_eq(loaded.profiles.size(), 2)
	assert_eq(loaded.active, 1, "clamped to the last profile")

	var old: ControlProfile = loaded.profiles[0]
	assert_eq(old.name, "Old")
	assert_eq(old.slots(ControlProfile.KB, "up"), ["k:87"] as Array[String], "saved actions are kept")
	assert_eq(old.slots(ControlProfile.KB, "light"), ["m:1"] as Array[String])
	assert_eq(old.slots(ControlProfile.KB, "jump"), [] as Array[String], "a cleared action stays cleared")
	var kb_defaults: Dictionary = Bindings.default_kb()
	for action: String in ["down", "left", "right", "heavy", "block", "dodge", "interact", "ultimate", "sprint", "grip", "pause"]:
		assert_eq(old.kb[action], kb_defaults[action], "filled in: " + action)
	assert_eq(old.pad, Bindings.default_pad(), "the whole controller set is filled in")

	var junk: ControlProfile = loaded.profiles[1]
	assert_eq(junk.name, "Player 2", "a missing name gets a default one")
	assert_eq(junk.slots(ControlProfile.KB, "light"), ["k:74", "k:75"] as Array[String], "valid, unique, at most 2")
	assert_eq(junk.kb["heavy"], kb_defaults["heavy"], "a value that is not a list is replaced by the default")
	assert_eq(junk.slots(ControlProfile.PAD, "light"), ["b:10", "a:5+"] as Array[String])


## A profile saved before the grip (KE task 6): the old defaults, with the
## Ultimate on pad Y and no grip action.
static func _before_the_grip() -> Dictionary:
	var kb: Dictionary = Bindings.default_kb()
	kb.erase("grip")
	var pad: Dictionary = Bindings.default_pad()
	pad.erase("grip")
	pad["ultimate"] = [InputToken.joy_button(JOY_BUTTON_Y)]
	return {"name": "Old", "kb": kb, "pad": pad}


func test_an_old_profile_gains_the_grip_and_the_ultimate_moves_to_l2() -> void:
	var p: ControlProfile = ControlProfile.from_dict(_before_the_grip())
	assert_eq(p.slots(ControlProfile.PAD, "grip"), [InputToken.joy_button(JOY_BUTTON_Y)] as Array[String], "the grip on Y")
	assert_eq(p.slots(ControlProfile.PAD, "ultimate"), [InputToken.joy_axis(JOY_AXIS_TRIGGER_LEFT, true)] as Array[String], "the Ultimate moved to L2")
	assert_eq(p.slots(ControlProfile.KB, "grip"), [InputToken.key(KEY_R)] as Array[String], "the grip on R")
	assert_eq(p.to_dict(), ControlProfile.create("Old").to_dict(), "an untouched old profile becomes today's defaults")


func test_an_old_profile_s_own_bindings_never_clash_with_the_grip() -> void:
	var d: Dictionary = _before_the_grip()
	# R rebound to jump; Y kept for the Ultimate but L2 already used by block;
	# no other action on Y would be left for the grip
	d["kb"]["jump"] = [InputToken.key(KEY_R)]
	d["pad"]["block"] = [InputToken.joy_axis(JOY_AXIS_TRIGGER_LEFT, true)]
	var p: ControlProfile = ControlProfile.from_dict(d)
	assert_eq(p.slots(ControlProfile.KB, "grip"), [] as Array[String], "R is jump's: the grip is left unbound")
	assert_eq(p.slots(ControlProfile.KB, "jump"), [InputToken.key(KEY_R)] as Array[String], "jump keeps R")
	assert_eq(p.slots(ControlProfile.PAD, "ultimate"), [InputToken.joy_button(JOY_BUTTON_Y)] as Array[String], "L2 is taken: the Ultimate stays on Y")
	assert_eq(p.slots(ControlProfile.PAD, "grip"), [] as Array[String], "and the grip is left unbound")


func test_an_old_profile_with_the_ultimate_moved_away_gives_the_grip_y() -> void:
	var d: Dictionary = _before_the_grip()
	d["pad"]["ultimate"] = [InputToken.joy_button(JOY_BUTTON_RIGHT_STICK)]
	var p: ControlProfile = ControlProfile.from_dict(d)
	assert_eq(p.slots(ControlProfile.PAD, "ultimate"), [InputToken.joy_button(JOY_BUTTON_RIGHT_STICK)] as Array[String], "the player's own choice stays")
	assert_eq(p.slots(ControlProfile.PAD, "grip"), [InputToken.joy_button(JOY_BUTTON_Y)] as Array[String])


func test_a_saved_grip_is_kept_as_it_is() -> void:
	var d: Dictionary = ControlProfile.create().to_dict()
	d["pad"]["grip"] = []
	d["kb"]["grip"] = [InputToken.key(KEY_G)]
	var p: ControlProfile = ControlProfile.from_dict(d)
	assert_eq(p.slots(ControlProfile.PAD, "grip"), [] as Array[String], "a cleared grip stays cleared")
	assert_eq(p.slots(ControlProfile.KB, "grip"), [InputToken.key(KEY_G)] as Array[String])
	assert_eq(p.slots(ControlProfile.PAD, "ultimate"), [InputToken.joy_axis(JOY_AXIS_TRIGGER_LEFT, true)] as Array[String])


func test_loading_clamps_a_negative_or_odd_active_index() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "active", -3)
	cfg.set_value("profile_0", "name", "Only")
	cfg.save(PATH)
	assert_eq(ControlProfiles.load_from(PATH).active, 0)
	cfg.set_value("controls", "active", "two")
	cfg.save(PATH)
	assert_eq(ControlProfiles.load_from(PATH).active, 0)


func test_a_file_with_no_profiles_gives_one_default_profile() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "active", 0)
	cfg.save(PATH)
	var loaded: ControlProfiles = ControlProfiles.load_from(PATH)
	assert_eq(loaded.profiles.size(), 1)
	assert_eq(loaded.active_profile().name, "Player 1")


func test_a_run_asking_for_the_defaults_ignores_the_saved_file() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	store.add_profile()
	store.rename(1, "Arcade stick")
	store.save(PATH)
	var fresh: ControlProfiles = ControlProfiles.load_for_run(true, PATH)
	assert_eq(fresh.names(), PackedStringArray(["Player 1"]))
	assert_eq(fresh.active, 0)
	assert_eq(ControlProfiles.load_for_run(false, PATH).names(), PackedStringArray(["Player 1", "Arcade stick"]))
	assert_true(OS.has_environment(GameSettings.DEFAULTS_ENV), "godot.mjs runs the tests with the defaults")


func test_rename_trims_and_cuts_to_24_characters() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	assert_true(store.rename(0, "  A very long profile name indeed  "))
	assert_eq(store.profiles[0].name, "A very long profile name")
	assert_eq(store.profiles[0].name.length(), 24)
	assert_false(store.rename(0, "    "), "an empty name keeps the old one")
	assert_eq(store.profiles[0].name, "A very long profile name")
	assert_false(store.rename(3, "Nobody"), "out of range")
	assert_true(store.rename(0, "Pad"))
	assert_eq(store.names(), PackedStringArray(["Pad"]))


func test_new_profiles_get_default_bindings_and_become_active() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	store.active_profile().use_fight_stick_layout()
	var p: ControlProfile = store.add_profile()
	assert_eq(p.name, "Player 2")
	assert_eq(store.active, 1)
	assert_eq(store.active_profile(), p)
	assert_eq(p.pad, Bindings.default_pad())


func test_the_last_profile_cannot_be_deleted() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	assert_false(store.can_delete())
	assert_false(store.delete_profile(0))
	assert_eq(store.profiles.size(), 1)


func test_deleting_a_profile_keeps_the_active_one_when_possible() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	store.rename(0, "A")
	store.add_profile()
	store.rename(1, "B")
	store.add_profile()
	store.rename(2, "C")
	assert_eq(store.active_profile().name, "C")
	assert_true(store.delete_profile(0))
	assert_eq(store.names(), PackedStringArray(["B", "C"]))
	assert_eq(store.active_profile().name, "C", "deleting another profile keeps the active one")
	assert_true(store.delete_profile(1))
	assert_eq(store.active_profile().name, "B", "deleting the active last profile selects the one before")
	assert_false(store.delete_profile(0))


func test_deleting_the_active_profile_selects_the_next() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	store.add_profile()
	store.add_profile()
	store.set_active(1)
	assert_true(store.delete_profile(1))
	assert_eq(store.names(), PackedStringArray(["Player 1", "Player 3"]))
	assert_eq(store.active_profile().name, "Player 3")
	assert_false(store.delete_profile(5), "out of range")


func test_profile_at_falls_back_to_the_active_profile() -> void:
	var store: ControlProfiles = ControlProfiles.new()
	store.add_profile()
	assert_eq(store.profile_at(0).name, "Player 1")
	assert_eq(store.profile_at(9).name, "Player 2")
	assert_eq(store.profile_at(-1).name, "Player 2")


func test_reset_restores_one_tab() -> void:
	var p: ControlProfile = ControlProfile.create()
	p.bind(ControlProfile.KB, "light", 0, InputToken.key(KEY_Z))
	p.use_fight_stick_layout()
	p.reset_tab(ControlProfile.KB)
	assert_eq(p.kb, Bindings.default_kb())
	assert_eq(p.pad, Bindings.fight_stick_pad(), "the controller tab is untouched")
	p.reset_tab(ControlProfile.PAD)
	assert_eq(p.pad, Bindings.default_pad())


func test_fight_stick_layout_preset() -> void:
	var p: ControlProfile = ControlProfile.create()
	p.bind(ControlProfile.KB, "light", 0, InputToken.key(KEY_Z))
	p.use_fight_stick_layout()
	assert_eq(p.pad, Bindings.fight_stick_pad())
	assert_eq(p.slots(ControlProfile.KB, "light")[0], InputToken.key(KEY_Z), "the keyboard tab is untouched")


func test_defaults_are_fresh_copies() -> void:
	var p: ControlProfile = ControlProfile.create()
	p.bind(ControlProfile.PAD, "light", 0, InputToken.joy_button(JOY_BUTTON_X))
	assert_eq(Bindings.default_pad()["light"], [InputToken.joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	assert_eq(ControlProfile.create().pad["light"], [InputToken.joy_button(JOY_BUTTON_RIGHT_SHOULDER)])


func test_every_default_set_covers_every_action_with_at_most_two_valid_tokens() -> void:
	var sets: Dictionary = {
		"kb": Bindings.default_kb(), "pad": Bindings.default_pad(),
		"fight stick": Bindings.fight_stick_pad(), "arrows": Bindings.kb_arrows(),
	}
	for set_name: String in sets:
		var bindings: Dictionary = sets[set_name]
		assert_eq(bindings.size(), Bindings.ACTIONS.size(), set_name)
		var seen: Dictionary = {}
		for action: String in Bindings.ACTIONS:
			var tokens: Array = bindings[action]
			assert_true(tokens.size() <= Bindings.SLOTS, "%s %s" % [set_name, action])
			for token: String in tokens:
				assert_true(InputToken.is_valid(token), "%s %s %s" % [set_name, action, token])
				assert_eq(InputToken.is_joypad(token), set_name == "pad" or set_name == "fight stick", token)
				assert_false(seen.has(token), "%s: %s bound twice" % [set_name, token])
				seen[token] = true


## Key tokens can name a side ("k:<code>L" or "k:<code>R"), as the demo's
## ShiftLeft and ShiftRight did.
func test_key_tokens_can_name_a_side() -> void:
	var left: String = InputToken.key(KEY_SHIFT, KEY_LOCATION_LEFT)
	assert_eq(left, "k:%dL" % KEY_SHIFT)
	assert_eq(InputToken.key(KEY_CTRL, KEY_LOCATION_RIGHT), "k:%dR" % KEY_CTRL)
	assert_eq(InputToken.key(KEY_W), "k:%d" % KEY_W)
	assert_true(InputToken.is_valid(left))
	assert_true(InputToken.is_keyboard_or_mouse(left))
	assert_eq(InputToken.code(left), KEY_SHIFT)
	assert_eq(InputToken.key_location(left), KEY_LOCATION_LEFT)
	assert_eq(InputToken.key_location(InputToken.key(KEY_CTRL, KEY_LOCATION_RIGHT)), KEY_LOCATION_RIGHT)
	assert_eq(InputToken.key_location(InputToken.key(KEY_W)), KEY_LOCATION_UNSPECIFIED)
	for bad: String in ["k:L", "k:12X", "k:12LR", "k:-4L", "b:3L"]:
		assert_false(InputToken.is_valid(bad), bad)
	var p: ControlProfile = ControlProfile.from_dict({"kb": {"block": [left, "k:12X"]}})
	assert_eq(p.slots(ControlProfile.KB, "block"), [left] as Array[String], "kept on load")
