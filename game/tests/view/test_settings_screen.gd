extends GutTest
## The Settings screen (task 22.9): graphics, reduce flashes and shaking,
## button hints and the three volume sliders, each applied and saved at once,
## walked with keys and with a controller. The screen saves to a test path,
## never the player's file.

const PATH: String = "user://test_settings_screen.cfg"

var settings: GameSettings
var screen: SettingsScreen
var stack: ScreenStack


func before_each() -> void:
	settings = GameSettings.new()
	screen = SettingsScreen.new(settings, PATH)
	add_child_autofree(screen)
	stack = ScreenStack.new()
	stack.push(screen)
	await get_tree().process_frame


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	# the buses as GameServices set them at start (test runs use the defaults)
	GameServices.settings.apply_volumes()


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


func _saved() -> GameSettings:
	return GameSettings.load_from(PATH)


func test_the_rows_in_order_open_on_graphics_and_show_the_settings() -> void:
	assert_eq(screen.items, [screen.graphics, screen.flashes, screen.hints, screen.master, screen.effects, screen.music] as Array[Control])
	assert_eq(screen.focused_item(), screen.graphics)
	assert_eq(screen.graphics.chips.map(func(c: Button) -> String: return c.text), ["High", "Medium", "Low"])
	assert_eq(screen.graphics.index, 0, "High, the default")
	assert_eq(screen.flashes.index, 0, "Off")
	assert_eq(screen.hints.index, 0, "On")
	assert_eq([screen.master.value, screen.effects.value, screen.music.value], [80, 90, 100])


func test_the_rows_follow_saved_settings_when_it_opens() -> void:
	settings.set_graphics_preset(&"low")
	settings.reduce_flashes = true
	settings.button_hints = false
	settings.music_volume = 35
	stack.clear()
	stack.push(screen)
	assert_eq(screen.graphics.index, 2)
	assert_eq(screen.flashes.index, 1)
	assert_eq(screen.hints.index, 1)
	assert_eq(screen.music.value, 35)


func test_graphics_changes_and_saves_at_once() -> void:
	_key(KEY_RIGHT)
	assert_eq(settings.graphics_preset_id, &"medium")
	assert_eq(_saved().graphics_preset_id, &"medium")
	_key(KEY_RIGHT)
	assert_eq(_saved().graphics_preset_id, &"low")
	_key(KEY_RIGHT)
	assert_eq(_saved().graphics_preset_id, &"high", "wraps round")


func test_reduce_flashes_and_button_hints_change_and_save_at_once() -> void:
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	assert_true(settings.reduce_flashes)
	assert_true(_saved().reduce_flashes)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	assert_false(settings.button_hints, "OK steps on too")
	assert_false(_saved().button_hints)
	_key(KEY_LEFT)
	assert_true(_saved().button_hints)


func test_sliders_step_by_five_and_apply_and_save_at_once() -> void:
	for i: int in 3:
		_key(KEY_DOWN)
	assert_eq(screen.focused_item(), screen.master)
	_key(KEY_LEFT)
	assert_eq(settings.master_volume, 75)
	assert_eq(_saved().master_volume, 75)
	var bus: int = AudioServer.get_bus_index(&"Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), GameSettings.layout_volume_db(&"Master") + linear_to_db(0.75), 0.01, "applied to the bus")
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	assert_eq(_saved().effects_volume, 95)
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	assert_eq(_saved().music_volume, 100, "already at the top")
	_key(KEY_LEFT)
	assert_eq(_saved().music_volume, 95)
	assert_eq(screen.music.readout.text, "95")


func test_a_controller_walks_and_changes_the_rows() -> void:
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_RIGHT)
	assert_true(_saved().reduce_flashes)
	_pad(JOY_BUTTON_DPAD_UP)
	_pad(JOY_BUTTON_A)
	assert_eq(_saved().graphics_preset_id, &"medium")
	for i: int in 5:
		_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(_saved().music_volume, 95)


func test_each_change_is_reported() -> void:
	watch_signals(screen)
	_key(KEY_RIGHT)
	_key(KEY_DOWN)
	_key(KEY_RIGHT)
	assert_signal_emit_count(screen, "settings_changed", 2)


func test_back_returns_to_the_opener() -> void:
	var opener: MenuScreen = MenuScreen.new()
	add_child_autofree(opener)
	opener.add_button("Settings", "", func() -> void: pass)
	stack.reset([opener] as Array[MenuPage])
	stack.push(screen)
	_key(KEY_ESCAPE)
	assert_eq(stack.top(), opener)
	stack.push(screen)
	_pad(JOY_BUTTON_B)
	assert_eq(stack.top(), opener)


## On the game's own settings a new preset reaches the root viewport at once.
func test_a_preset_change_on_the_games_settings_applies_to_the_viewport() -> void:
	var before: StringName = GameServices.settings.graphics_preset_id
	var game: SettingsScreen = SettingsScreen.new(GameServices.settings, PATH)
	add_child_autofree(game)
	stack.push(game)
	await get_tree().process_frame
	for id: StringName in [&"low", &"medium", &"high"]:
		game.graphics.set_index(posmod(SettingsScreen.PRESETS.find(id) - 1, SettingsScreen.PRESETS.size()))
		_key(KEY_RIGHT)
		assert_eq(GameServices.settings.graphics_preset_id, id)
		var preset: GraphicsPreset = GraphicsPreset.load_id(id)
		assert_almost_eq(get_tree().root.scaling_3d_scale, preset.render_scale, 0.001, String(id))
		assert_eq(get_tree().root.msaa_3d, preset.msaa_3d, String(id))
	GameServices.settings.set_graphics_preset(before)
	GameServices.apply_graphics()
