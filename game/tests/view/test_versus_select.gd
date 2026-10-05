extends GutTest
## Versus on the menu (task 22.16): the select's Player 1 and Player 2 steps
## each pick a device ("Plays with": keyboard and mouse, the arrow-key
## layout, controller 1 or 2, a missing controller marked "not connected")
## and a Controls profile; the same device on both sides, or a controller
## that isn't connected, refuses Lock in with a warning (the owner's choice,
## Oct 5, 2026); and a started Versus samples each player from their own
## device with their own profile.

const MainScript := preload("res://scenes/main.gd")

var select: FighterSelect
var fake: FakeDeviceState
var input: InputDevices
var profiles: ControlProfiles
var locked: Array[MatchSelection.Draft] = []


func before_each() -> void:
	locked.clear()
	fake = FakeDeviceState.new()
	input = InputDevices.new(fake)
	profiles = ControlProfiles.new()
	select = FighterSelect.new(input, profiles)
	add_child_autofree(select)
	select.locked_in.connect(func(d: MatchSelection.Draft) -> void: locked.append(d))


func _open(mode: StringName = MatchConfig.VERSUS) -> MatchSelection.Draft:
	var d: MatchSelection.Draft = MatchSelection.default_draft(mode)
	select.start(d)
	select.open()
	await get_tree().process_frame
	return d


func _key(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		get_viewport().push_input(e)


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		get_viewport().push_input(e)


## Moves the focus down to an item with the key or button given.
func _down_to(item: Control, step: Callable) -> void:
	for _i: int in 12:
		if select.focused_item() == item:
			return
		step.call()
	assert_eq(select.focused_item(), item, "reached %s" % item.name)


func _chips(row: OptionRow) -> Array[String]:
	var out: Array[String] = []
	for c: Button in row.chips:
		out.append(c.text)
	return out


func _chosen(row: OptionRow) -> String:
	return row.chips[row.index].text


## Picks a device for the side shown, as a click on its chip would.
func _pick_device(device: String) -> void:
	select.device_row.set_index(FighterSelect.DEVICES.find(device))
	select.device_row.changed.emit(select.device_row.index)


# ------------------------------------------------------------------ the rows

func test_versus_steps_have_the_device_and_profile_rows() -> void:
	await _open()
	for side: int in 2:
		select.show_side(side)
		assert_true(select.device_row.visible, "Plays with on player %d's step" % (side + 1))
		assert_true(select.profile_row.visible, "the profile on player %d's step" % (side + 1))
		assert_false(select.skill_row.visible, "no computer skill")
	assert_eq(select.side_title.text, "Player 2")
	assert_eq(select.device_row.title.text, "Plays with")
	assert_eq(select.profile_row.title.text, "Controls profile")


func test_the_other_modes_have_no_device_or_profile_row() -> void:
	for mode: StringName in [MatchConfig.DUEL, MatchConfig.TRAINING, MatchConfig.WATCH]:
		await _open(mode)
		for side: int in 2:
			select.show_side(side)
			assert_false(select.device_row.visible, "%s side %d" % [mode, side])
			assert_false(select.profile_row.visible, "%s side %d" % [mode, side])
			assert_false(select.warning.visible)


func test_a_missing_controller_is_marked_not_connected() -> void:
	fake.plug_pad(0, "PS5 Controller")
	await _open()
	assert_eq(_chips(select.device_row), ["Keyboard and mouse", "Keyboard: arrows + J K L", "Controller 1", "Controller 2 (not connected)"] as Array[String])
	fake.unplug_pad(0)
	select.show_side(0)
	assert_eq(_chips(select.device_row), ["Keyboard and mouse", "Keyboard: arrows + J K L", "Controller 1 (not connected)", "Controller 2 (not connected)"] as Array[String])


## The demo's defaults: keyboard and mouse against the first controller,
## or against the arrow layout when no controller is connected.
func test_the_defaults_follow_the_controllers_connected() -> void:
	fake.plug_pad(0, "PS5 Controller")
	var d: MatchSelection.Draft = await _open()
	assert_eq(d.sides[0].device, InputDevices.KBM)
	assert_eq(select.draft.sides[1].device, InputDevices.PAD0)
	fake.unplug_pad(0)
	await _open()
	assert_eq(select.draft.sides[0].device, InputDevices.KBM)
	assert_eq(select.draft.sides[1].device, InputDevices.KB_ARROWS)
	select.show_side(1)
	assert_eq(_chosen(select.device_row), "Keyboard: arrows + J K L")


## A pick the player made stays as it is, connected or not (the warning says
## so; see the lock-in tests).
func test_a_picked_controller_is_kept_when_unplugged() -> void:
	var d: MatchSelection.Draft = MatchSelection.default_draft(MatchConfig.VERSUS)
	MatchSelection.set_device(d, 1, InputDevices.PAD1)
	select.start(d)
	assert_eq(select.draft.sides[1].device, InputDevices.PAD1)


func test_the_pickers_write_the_device_and_profile() -> void:
	fake.plug_pad(0, "PS5 Controller")
	fake.plug_pad(1, "Xbox Wireless Controller")
	var second: ControlProfile = profiles.add_profile()
	second.name = "Fight stick"
	profiles.set_active(0)
	await _open()
	var names: Array[String] = []
	for n: String in profiles.names():
		names.append(n)
	assert_eq(_chips(select.profile_row), names)
	assert_eq(select.profile_row.index, 0, "the active profile by default")
	_pick_device(InputDevices.PAD1)
	select.profile_row.set_index(1)
	select.profile_row.changed.emit(1)
	select.show_side(1)
	_pick_device(InputDevices.PAD0)
	select.confirm.pressed.emit()
	assert_eq(locked.size(), 1)
	var cfg: MatchConfig = MatchSelection.lock_in(locked[0], 3)
	assert_eq(cfg.sides[0].device, InputDevices.PAD1)
	assert_eq(cfg.sides[0].profile, 1)
	assert_eq(cfg.sides[1].device, InputDevices.PAD0)
	assert_eq(cfg.sides[1].profile, 0)
	assert_eq(cfg.problem(), "")


# ------------------------------------------------------------------ refusing lock in

func test_a_clash_shows_a_warning_and_refuses_lock_in() -> void:
	fake.plug_pad(0, "PS5 Controller")
	await _open()
	select.show_side(1)
	_pick_device(InputDevices.KBM)
	assert_true(select.warning.visible)
	assert_eq(select.warning.text, "Both players are set to the same device. Pick a different one for Player 2.")
	select.confirm.pressed.emit()
	assert_eq(locked.size(), 0, "no lock in")
	_pick_device(InputDevices.KB_ARROWS)
	assert_false(select.warning.visible, "sharing the keyboard is fine")
	select.confirm.pressed.emit()
	assert_eq(locked.size(), 1)


func test_a_controller_that_isn_t_connected_refuses_lock_in() -> void:
	fake.plug_pad(0, "PS5 Controller")
	await _open()
	select.show_side(1)
	_pick_device(InputDevices.PAD1)
	assert_true(select.warning.visible)
	assert_eq(select.warning.text, "Controller 2 is not connected. Connect it, or pick another device for Player 2.")
	select.confirm.pressed.emit()
	assert_eq(locked.size(), 0, "no lock in")
	fake.plug_pad(1, "Xbox Wireless Controller")
	select.refresh()
	assert_false(select.warning.visible, "connected now")
	select.confirm.pressed.emit()
	assert_eq(locked.size(), 1)


## Player 1's missing controller is named too, and stops Lock in on player
## 2's step.
func test_player_1_s_missing_controller_is_named() -> void:
	await _open()
	_pick_device(InputDevices.PAD0)
	assert_eq(select.warning.text, "Controller 1 is not connected. Connect it, or pick another device for Player 1.")
	select.confirm.pressed.emit()
	assert_eq(select.side, 1, "Next still goes on")
	select.confirm.pressed.emit()
	assert_eq(locked.size(), 0)


# ------------------------------------------------------------------ walks

func test_a_keyboard_walk_picks_the_devices_and_locks_in() -> void:
	await _open()
	assert_eq(select.draft.sides[1].device, InputDevices.KB_ARROWS, "no controller: the arrows")
	_down_to(select.device_row, _key.bind(KEY_DOWN))
	_key(KEY_RIGHT)
	assert_eq(select.draft.sides[0].device, InputDevices.KB_ARROWS, "player 1 on the arrows")
	assert_true(select.warning.visible, "both on the arrows")
	_key(KEY_LEFT)
	assert_eq(select.draft.sides[0].device, InputDevices.KBM)
	_down_to(select.confirm, _key.bind(KEY_DOWN))
	_key(KEY_ENTER)
	await get_tree().process_frame
	assert_eq(select.side, 1)
	_down_to(select.confirm, _key.bind(KEY_DOWN))
	_key(KEY_ENTER)
	assert_eq(locked.size(), 1)
	assert_eq(locked[0].sides[0].device, InputDevices.KBM)
	assert_eq(locked[0].sides[1].device, InputDevices.KB_ARROWS)


func test_a_controller_walk_picks_the_second_controller() -> void:
	fake.plug_pad(0, "PS5 Controller")
	fake.plug_pad(1, "PS5 Controller")
	await _open()
	_pad(JOY_BUTTON_A)
	await get_tree().process_frame
	_down_to(select.confirm, _pad.bind(JOY_BUTTON_DPAD_DOWN))
	_pad(JOY_BUTTON_A)
	await get_tree().process_frame
	assert_eq(select.side, 1)
	_down_to(select.device_row, _pad.bind(JOY_BUTTON_DPAD_DOWN))
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(select.draft.sides[1].device, InputDevices.PAD1)
	_down_to(select.confirm, _pad.bind(JOY_BUTTON_DPAD_DOWN))
	_pad(JOY_BUTTON_A)
	assert_eq(locked.size(), 1)
	assert_eq(locked[0].sides[1].device, InputDevices.PAD1)


# ------------------------------------------------------------------ in the game

func _main() -> Node:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	var host: MatchHost = main.get_node("MatchHost")
	host.auto_run = false
	return main


## Versus sits on the main menu after Training, "two players, one screen".
func test_versus_is_on_the_main_menu_after_training() -> void:
	var main: Node = _main()
	main.call("show_main_menu")
	var menu: MenuScreen = main.get("main_menu")
	var labels: Array[String] = []
	for b: Button in menu.buttons:
		labels.append(b.text.get_slice("\n", 0))
	assert_eq(labels.slice(0, 4), ["Duel", "Training", "Versus", "Watch"] as Array[String])
	var versus: Button = menu.buttons[2]
	assert_eq((versus.get_node("Sub") as Label).text, "two players, one screen")
	versus.pressed.emit()
	var sel: FighterSelect = main.get("select")
	assert_true(sel.visible)
	assert_eq(sel.draft.mode, MatchConfig.VERSUS)
	assert_eq(sel.mode_line.text, "Versus · two players · first to 3 rounds")


## A started Versus samples each player from their own device with their own
## profile: player 1 on keyboard and mouse with a second profile whose light
## is on V, player 2 on the arrow layout.
func test_a_started_versus_samples_each_player_from_their_own_device_and_profile() -> void:
	var main: Node = _main()
	var host: MatchHost = main.get_node("MatchHost")
	var services: Node = get_tree().root.get_node("GameServices")
	var game_profiles: ControlProfiles = services.get("profiles")
	var first: int = game_profiles.active
	var mine: ControlProfile = game_profiles.add_profile()
	mine.kb["light"] = [InputToken.key(KEY_V)]
	game_profiles.set_active(first)
	var mine_at: int = game_profiles.profiles.find(mine)
	host.input = InputDevices.new(fake)
	var sel: FighterSelect = main.get("select")
	sel.input = host.input
	sel.profiles = game_profiles
	main.call("show_main_menu")
	main.call("open_select", MatchConfig.VERSUS)
	assert_eq(sel.draft.sides[1].device, InputDevices.KB_ARROWS)
	sel.profile_row.set_index(mine_at)
	sel.profile_row.changed.emit(mine_at)
	sel.show_side(1)
	sel.confirm.pressed.emit()
	assert_true(host.is_started())
	assert_eq(host.config.mode, MatchConfig.VERSUS)
	assert_eq(host.input.device_of(0), InputDevices.KBM)
	assert_eq(host.input.device_of(1), InputDevices.KB_ARROWS)
	assert_eq(host.input.profile_of(0), mine)
	fake.press_key(KEY_V)
	assert_ne(host.input.sample(0).buttons & Btn.bit(Btn.LIGHT), 0, "V is player 1's light")
	assert_eq(host.input.sample(1).buttons & Btn.bit(Btn.LIGHT), 0, "not player 2's")
	fake.release_key(KEY_V)
	fake.press_key(KEY_J)
	assert_ne(host.input.sample(1).buttons & Btn.bit(Btn.LIGHT), 0, "J is player 2's light")
	assert_eq(host.input.sample(0).buttons & Btn.bit(Btn.LIGHT), 0, "not player 1's")
	fake.release_key(KEY_J)
	game_profiles.delete_profile(mine_at)
	game_profiles.set_active(first)


## In Versus the pause's Move list opens on the Rules: neither player's
## weapon comes first.
func test_the_pause_s_move_list_opens_on_the_rules_in_versus() -> void:
	var main: Node = _main()
	var host: MatchHost = main.get_node("MatchHost")
	host.input = InputDevices.new(fake)
	fake.plug_pad(0, "PS5 Controller")
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.VERSUS, MatchSide.human(&"rogue", &"greatsword", 0, InputDevices.KBM), MatchSide.human(&"hunter", &"daggers", 1, InputDevices.PAD0), 3, ArenaScenes.STANDIN)
	assert_true(main.call("start_match", cfg))
	host.step(30)
	host.pause()
	await get_tree().process_frame
	main.call("show_move_list")
	var how: HowToPlayScreen = main.get("how_to_play")
	assert_true(how.visible)
	assert_eq(how.tabs.index, 0, "the Rules")


## Either player's pause binding pauses Versus: player 2's on the arrow
## layout (Backspace) as well as player 1's.
func test_either_player_pauses_versus() -> void:
	var main: Node = _main()
	var host: MatchHost = main.get_node("MatchHost")
	host.input = InputDevices.new(fake)
	var cfg: MatchConfig = MatchConfig.make(MatchConfig.VERSUS, MatchSide.human(&"rogue", &"katana", 0, InputDevices.KBM), MatchSide.human(&"hunter", &"daggers", 1, InputDevices.KB_ARROWS), 3, ArenaScenes.STANDIN)
	assert_true(main.call("start_match", cfg))
	host.auto_run = true
	host._process(SimConst.DT)
	fake.press_key(KEY_BACKSPACE)
	host._process(SimConst.DT)
	assert_true(host.is_paused(), "player 2's pause binding")
	assert_eq(int(main.get("screen")), MainScript.Screen.PAUSED)
