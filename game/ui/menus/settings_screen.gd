class_name SettingsScreen
extends MenuScreen
## The Settings screen (port of showSettings() in v0.1-web-mvp:src/ui/menus.ts): the
## graphics preset, reduce flashes and shaking, button hints, and the master,
## effects and music volumes. Each row applies and saves its change at once;
## Back returns to the page that opened it (the main menu or the pause menu).
##
## The rows act on a GameSettings saved to a path: GameServices' settings in
## the player's file by default (GameSettings.save_path_for_run, so a test
## run never writes it); tests hand it their own.

## A setting changed (and was saved).
signal settings_changed

## The presets in the row's order, best first, as the demo's High and Fast.
const PRESETS: Array[StringName] = [&"ultra", &"high", &"medium", &"low"]
## The rows' label column (px): wide enough for "Reduce flashes and shaking".
const LABEL_WIDTH: float = 340.0

var settings: GameSettings
var save_path: String
var graphics: OptionRow
var flashes: OptionRow
var hints: OptionRow
var master: SliderRow
var effects: SliderRow
var music: SliderRow


func _init(p_settings: GameSettings = null, p_save_path: String = "") -> void:
	super()
	settings = p_settings if p_settings != null else GameServices.settings
	save_path = p_save_path if p_save_path != "" else GameSettings.save_path_for_run(GameSettings.PATH)
	add_label("Saved on this computer", UiTheme.EYEBROW, 15)
	add_heading("Settings")
	var names: Array[String] = []
	for id: StringName in PRESETS:
		names.append(GraphicsPreset.load_id(id).display_name)
	graphics = add_options("Graphics", names, 0, _on_graphics)
	flashes = add_options("Reduce flashes and shaking", ["Off", "On"] as Array[String], 0, _on_flashes)
	hints = add_options("Button hints on screen", ["On", "Off"] as Array[String], 0, _on_hints)
	add_label("Volume", UiTheme.EYEBROW, 15)
	master = add_slider("Master", 0, _on_volume.bind("master"))
	effects = add_slider("Effects", 0, _on_volume.bind("effects"))
	music = add_slider("Music", 0, _on_volume.bind("music"))
	# one label width, so the chips and sliders line up under each other
	for row: Control in [graphics, flashes, hints, master, effects, music]:
		(row.get("title") as Label).custom_minimum_size.x = LABEL_WIDTH
	refresh()


## Sets every row from the settings (quietly), as when the screen opens.
func refresh() -> void:
	graphics.set_index(maxi(0, PRESETS.find(settings.graphics_preset_id)))
	flashes.set_index(1 if settings.reduce_flashes else 0)
	hints.set_index(0 if settings.button_hints else 1)
	master.set_value(settings.master_volume)
	effects.set_value(settings.effects_volume)
	music.set_value(settings.music_volume)


func open() -> void:
	refresh()
	super()


func _on_graphics(index: int) -> void:
	settings.set_graphics_preset(PRESETS[index])
	if settings == GameServices.settings:
		GameServices.apply_graphics()
	_save()


func _on_flashes(index: int) -> void:
	settings.reduce_flashes = index == 1
	_save()


func _on_hints(index: int) -> void:
	settings.button_hints = index == 0
	_save()


func _on_volume(value: int, key: String) -> void:
	settings.set("%s_volume" % key, value)
	settings.apply_volumes()
	_save()


func _save() -> void:
	settings.save(save_path)
	settings.changed.emit()
	settings_changed.emit()
