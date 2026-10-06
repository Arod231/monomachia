extends GutTest
## The whole flow walked twice through main.tscn (task 22.17), once with the
## keyboard alone and once with a controller alone: the title; the main
## menu; How to play and its tabs; Controls with a binding captured;
## Settings; every mode's select to a started match (Duel, Training, Versus
## and Watch); the pause and each of its sub-screens, Restart and Resume;
## and the results with Rematch, Change fighters and Main menu. Every press
## goes both into a fake device state (as Godot's Input sees it before the
## scene does) and into the viewport, so the menus and the match host read
## the same presses.

const MainScript := preload("res://scenes/main.gd")
const DT: float = SimConst.DT

enum Cmd { UP, DOWN, LEFT, RIGHT, OK, BACK, ANY }

const KEYS: Dictionary = {
	Cmd.UP: KEY_UP, Cmd.DOWN: KEY_DOWN, Cmd.LEFT: KEY_LEFT, Cmd.RIGHT: KEY_RIGHT,
	Cmd.OK: KEY_ENTER, Cmd.BACK: KEY_ESCAPE, Cmd.ANY: KEY_A,
}
const BUTTONS: Dictionary = {
	Cmd.UP: JOY_BUTTON_DPAD_UP, Cmd.DOWN: JOY_BUTTON_DPAD_DOWN, Cmd.LEFT: JOY_BUTTON_DPAD_LEFT,
	Cmd.RIGHT: JOY_BUTTON_DPAD_RIGHT, Cmd.OK: JOY_BUTTON_A, Cmd.BACK: JOY_BUTTON_B, Cmd.ANY: JOY_BUTTON_Y,
}

var main: Node
var host: MatchHost
var fake: FakeDeviceState
## Walking with a controller (else the keyboard).
var pad: bool = false
## The profile the walk binds into, and the active one before it.
var _walk_profile: ControlProfile
var _was_active: int = 0


func before_each() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	host = main.get_node("MatchHost")
	host.auto_run = false
	fake = FakeDeviceState.new()
	host.input = InputDevices.new(fake)
	(main.get("select") as FighterSelect).input = host.input
	(main.get("controls_screen") as ControlsScreen).input = host.input
	# the walk binds into a profile of its own, deleted after
	var profiles: ControlProfiles = _profiles()
	_was_active = profiles.active
	_walk_profile = profiles.add_profile()
	profiles.set_active(profiles.profiles.find(_walk_profile))
	(main.get("controls_screen") as ControlsScreen).refresh()


func after_each() -> void:
	var profiles: ControlProfiles = _profiles()
	var at: int = profiles.profiles.find(_walk_profile)
	if at >= 0:
		profiles.delete_profile(at)
	profiles.set_active(_was_active)


func _profiles() -> ControlProfiles:
	return get_tree().root.get_node("GameServices").get("profiles")


# ------------------------------------------------------------------ presses

## Sends an event: the fake state first, as Godot's Input sees it before the
## scene does, then the viewport.
func _send(e: InputEvent) -> void:
	fake.apply(e)
	get_viewport().push_input(e)


func _press_key(key: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = down
		_send(e)


func _press_button(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = button
		e.pressed = down
		_send(e)


## A menu command on the walk's device.
func _do(cmd: Cmd) -> void:
	if pad:
		_press_button(BUTTONS[cmd])
	else:
		_press_key(KEYS[cmd])


func _screen() -> int:
	return int(main.get("screen"))


func _top() -> MenuPage:
	return (main.get("stack") as ScreenStack).top()


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


## Presses `cmd` until `target` has the focus.
func _focus_to(target: Control, cmd: Cmd) -> void:
	for _i: int in 30:
		if _focused() == target:
			return
		_do(cmd)
	assert_eq(_focused(), target, "reached %s" % target.name)


## Walks the main menu to the entry whose label starts with `label`.
func _menu_to(label: String) -> void:
	await get_tree().process_frame
	var menu: MenuScreen = main.get("main_menu")
	var target: Button = null
	for b: Button in menu.buttons:
		if b.text.get_slice("\n", 0) == label:
			target = b
	_focus_to(target, Cmd.DOWN)


## Opens the pause from play: Esc on the keyboard, Start on the controller,
## read by the host from the device state.
func _pause() -> void:
	host.auto_run = true
	if pad:
		fake.press_button(0, JOY_BUTTON_START)
	else:
		fake.press_key(KEY_ESCAPE)
	host._process(DT)
	if pad:
		fake.release_button(0, JOY_BUTTON_START)
	else:
		fake.release_key(KEY_ESCAPE)
	host._process(DT)
	host.auto_run = false
	assert_true(host.is_paused(), "paused")
	assert_eq(_top(), main.get("pause_menu"))
	await get_tree().process_frame


## Plays the match to its results, side 0 kept at 1 HP so it ends soon.
func _play_to_results() -> void:
	var steps: int = 0
	while _screen() != MainScript.Screen.RESULTS and steps < 60 * 60 * 10:
		if host.fighter(0).hp > 1.0:
			host.fighter(0).hp = 1.0
		host.step(1)
		steps += 1
	assert_eq(_screen(), MainScript.Screen.RESULTS)
	await get_tree().process_frame


## Through the select: Next on the first side, Lock in on the second.
func _lock_in() -> void:
	var select: FighterSelect = main.get("select")
	_focus_to(select.confirm, Cmd.DOWN)
	_do(Cmd.OK)
	await get_tree().process_frame
	assert_eq(select.side, 1)
	_focus_to(select.confirm, Cmd.DOWN)
	_do(Cmd.OK)
	await get_tree().process_frame


# ------------------------------------------------------------------ the walk

func _walk() -> void:
	# the title, then the main menu
	_do(Cmd.ANY)
	assert_eq(_screen(), MainScript.Screen.MENU, "any key or button goes on")

	# How to play: every tab, a scroll, and back
	await _menu_to("How to play")
	_do(Cmd.OK)
	var how: HowToPlayScreen = main.get("how_to_play")
	assert_eq(_top(), how)
	await get_tree().process_frame
	# The tabs follow the roster (milestone-1 task 4): the last is bare hands.
	var last: int = how.tab_names.size() - 1
	for i: int in last:
		_do(Cmd.RIGHT)
	assert_eq(how.tab, last, "the last tab")
	assert_eq(how.tab_weapons[last], &"fists", "the last tab is bare hands")
	_do(Cmd.DOWN)
	_do(Cmd.BACK)
	assert_eq(_top(), main.get("main_menu"), "back from How to play")

	# Controls: a binding captured on the walk's own device
	await _menu_to("Controls")
	_do(Cmd.OK)
	var controls: ControlsScreen = main.get("controls_screen")
	assert_eq(_top(), controls)
	await get_tree().process_frame
	if pad:
		_focus_to(controls.tabs, Cmd.DOWN)
		if controls.tab != ControlProfile.PAD:
			_do(Cmd.RIGHT)
		assert_eq(controls.tab, ControlProfile.PAD, "the controller tab")
	var slot: Button = controls.slot_buttons["light"][0]
	_focus_to(slot, Cmd.DOWN)
	_do(Cmd.OK)
	await get_tree().process_frame
	assert_true(controls.is_listening(), "listening")
	if pad:
		_press_button(JOY_BUTTON_X)
	else:
		_press_key(KEY_V)
	await get_tree().process_frame
	assert_false(controls.is_listening())
	var bound: String = InputToken.joy_button(JOY_BUTTON_X) if pad else InputToken.key(KEY_V)
	assert_has(_walk_profile.slots(ControlProfile.PAD if pad else ControlProfile.KB, "light"), bound, "captured")
	_do(Cmd.BACK)
	assert_eq(_top(), main.get("main_menu"), "back from Controls")

	# Settings: a row changed and changed back
	await _menu_to("Settings")
	_do(Cmd.OK)
	var settings: SettingsScreen = main.get("settings_screen")
	assert_eq(_top(), settings)
	await get_tree().process_frame
	var hints: bool = GameServices.settings.button_hints
	_focus_to(settings.hints, Cmd.DOWN)
	_do(Cmd.RIGHT)
	assert_ne(GameServices.settings.button_hints, hints, "Button hints changed")
	_do(Cmd.LEFT)
	assert_eq(GameServices.settings.button_hints, hints, "and back")
	_do(Cmd.BACK)
	assert_eq(_top(), main.get("main_menu"), "back from Settings")

	# a Duel through the select
	await _menu_to("Duel")
	_do(Cmd.OK)
	assert_eq(_screen(), MainScript.Screen.SELECT)
	await get_tree().process_frame
	await _lock_in()
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_eq(host.config.mode, MatchConfig.DUEL)
	host.step(Match.INTRO_FRAMES + 30)

	# the pause and each of its screens, then Restart and Resume
	await _pause()
	var pause: PauseScreen = main.get("pause_menu")
	var pages: Array[MenuPage] = [main.get("how_to_play"), controls, settings]
	var entries: Array[Button] = [pause.move_list_button, pause.controls_button, pause.settings_button]
	for i: int in pages.size():
		_focus_to(entries[i], Cmd.DOWN)
		_do(Cmd.OK)
		assert_eq(_top(), pages[i], "%s over the pause" % pages[i].name)
		await get_tree().process_frame
		_do(Cmd.BACK)
		assert_eq(_top(), pause, "back from %s to the pause" % pages[i].name)
		assert_true(host.is_paused(), "still paused")
		await get_tree().process_frame
	var seed_before: int = host.config.world_seed
	_focus_to(pause.restart_button, Cmd.DOWN)
	_do(Cmd.OK)
	assert_eq(_screen(), MainScript.Screen.PLAYING, "Restart")
	assert_ne(host.config.world_seed, seed_before)
	host.step(Match.INTRO_FRAMES + 30)
	await _pause()
	_focus_to(pause.resume_button, Cmd.UP)
	_do(Cmd.OK)
	assert_false(host.is_paused(), "Resume")

	# the results: Rematch, then Change fighters, back to the main menu
	await _play_to_results()
	var results: ResultsScreen = main.get("results_screen")
	_focus_to(results.rematch_button, Cmd.LEFT)
	_do(Cmd.OK)
	assert_eq(_screen(), MainScript.Screen.PLAYING, "Rematch")
	await _play_to_results()
	_focus_to(results.change_button, Cmd.RIGHT)
	_do(Cmd.OK)
	assert_eq(_screen(), MainScript.Screen.SELECT, "Change fighters")
	assert_eq((main.get("select") as FighterSelect).draft.mode, MatchConfig.DUEL)
	await get_tree().process_frame
	_do(Cmd.BACK)
	assert_eq(_top(), main.get("main_menu"), "back from the select")

	# Training, with the pause's rows, quit to the menu
	await _menu_to("Training")
	_do(Cmd.OK)
	await get_tree().process_frame
	await _lock_in()
	assert_eq(host.config.mode, MatchConfig.TRAINING)
	host.step(Match.INTRO_FRAMES + 30)
	await _pause()
	assert_true(pause.dummy_row.visible, "the dummy's row")
	_focus_to(pause.dummy_row, Cmd.UP)
	var behaviour: StringName = host.training_behaviour()
	_do(Cmd.RIGHT)
	assert_ne(host.training_behaviour(), behaviour, "the dummy's behaviour changed")
	_focus_to(pause.quit_button, Cmd.DOWN)
	_do(Cmd.OK)
	assert_eq(_screen(), MainScript.Screen.MENU, "Quit to menu")

	# Versus: on a controller each player on their own controller
	await _menu_to("Versus")
	_do(Cmd.OK)
	await get_tree().process_frame
	var select: FighterSelect = main.get("select")
	assert_eq(select.draft.mode, MatchConfig.VERSUS)
	if pad:
		_focus_to(select.device_row, Cmd.DOWN)
		while select.draft.sides[0].device != InputDevices.PAD0:
			_do(Cmd.RIGHT)
	_focus_to(select.confirm, Cmd.DOWN)
	_do(Cmd.OK)
	await get_tree().process_frame
	if pad:
		_focus_to(select.device_row, Cmd.DOWN)
		while select.draft.sides[1].device != InputDevices.PAD1:
			_do(Cmd.RIGHT)
	assert_false(select.warning.visible, "no clash")
	_focus_to(select.confirm, Cmd.DOWN)
	_do(Cmd.OK)
	assert_eq(_screen(), MainScript.Screen.PLAYING)
	assert_eq(host.config.mode, MatchConfig.VERSUS)
	var devices: Array = [InputDevices.KBM, InputDevices.KB_ARROWS]
	if pad:
		devices = [InputDevices.PAD0, InputDevices.PAD1]
	assert_eq([host.input.device_of(0), host.input.device_of(1)], devices)
	host.step(Match.INTRO_FRAMES + 30)
	await _pause()
	_focus_to(pause.quit_button, Cmd.DOWN)
	_do(Cmd.OK)
	assert_eq(_screen(), MainScript.Screen.MENU)

	# Watch, to its results and the main menu
	await _menu_to("Watch")
	_do(Cmd.OK)
	await get_tree().process_frame
	await _lock_in()
	assert_eq(host.config.mode, MatchConfig.WATCH)
	await _play_to_results()
	_focus_to(results.menu_button, Cmd.RIGHT)
	_do(Cmd.OK)
	assert_eq(_screen(), MainScript.Screen.MENU, "Main menu")
	assert_eq(_top(), main.get("main_menu"))

	# Quit is reachable too (not pressed: it would leave the game)
	await _menu_to("Quit")
	assert_eq((_focused() as Button).text.get_slice("\n", 0), "Quit")


func test_the_keyboard_alone_walks_the_whole_flow() -> void:
	pad = false
	await _walk()


func test_a_controller_alone_walks_the_whole_flow() -> void:
	pad = true
	fake.plug_pad(0, "PS5 Controller")
	fake.plug_pad(1, "PS5 Controller")
	await _walk()
