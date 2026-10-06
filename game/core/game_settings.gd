class_name GameSettings
extends RefCounted
## The player's settings, saved to user://settings.cfg (a ConfigFile): the
## graphics preset, the master, effects and music volumes, and the reduce
## flashes and button hints switches. GameServices owns the one the
## game uses, and applies its preset and volumes at start.
##
## Nothing here saves or applies by itself: after a change, call save(), and
## apply_volumes() for a volume, as ControlProfiles does.
##
## The volumes run 0-100 in steps of 5 and sit on top of the bus layout's own
## levels (default_bus_layout.tres): at 100 a bus plays at its layout level,
## below that it is turned down by linear_to_db(volume / 100), and at 0 it is
## muted. Master drives the Master bus, effects the SFX, UI and Ambience buses,
## and music the Music bus.
##
## The first launch (no preset saved, or one the game doesn't know) picks the
## preset from the graphics card (GraphicsPreset.for_card(), milestone-1 task
## 29); a run that asks for the defaults gets Ultra, the reference.
##
## File layout:
##   [graphics]  preset="ultra"
##   [audio]     master=80  effects=90  music=100
##   [display]   reduce_flashes=false  button_hints=true

## A setting changed: the Settings screen emits it after each change it
## saves, so what follows the settings applies them again at once (the
## match view's Reduce flashes, even behind the pause menu).
signal changed

const PATH: String = "user://settings.cfg"
const SECTION_GRAPHICS: String = "graphics"
const SECTION_AUDIO: String = "audio"
const SECTION_DISPLAY: String = "display"
## The buses each volume drives.
const VOLUME_BUSES: Dictionary = {
	"master": [&"Master"],
	"effects": [&"SFX", &"UI", &"Ambience"],
	"music": [&"Music"],
}
## When this environment variable is set, the run ignores the saved files and
## uses the defaults (these settings, and ControlProfiles.load_for_run's one
## fresh profile). godot.mjs sets it for test and shot runs, so what a
## player saved on this machine can't change them.
const DEFAULTS_ENV: String = "MONOMACHIA_DEFAULT_SETTINGS"

## The id of the chosen GraphicsPreset, always one of GraphicsPreset.IDS: an
## unknown id is ignored.
var graphics_preset_id: StringName = GraphicsPreset.DEFAULT_ID:
	set(id):
		if GraphicsPreset.IDS.has(id):
			graphics_preset_id = id


## The volumes, 0-100: any value is clamped and snapped to a step of 5.
var master_volume: int = 80:
	set(value):
		master_volume = snap_volume(value)
var effects_volume: int = 90:
	set(value):
		effects_volume = snap_volume(value)
var music_volume: int = 100:
	set(value):
		music_volume = snap_volume(value)

## Reduce flashes and shaking (18.11, MatchView.apply_reduce_flashes): the
## camera's shake scaled to 0.15, no field-of-view kicks, and flashes (the
## effects' glows and rings and the fighters' body flashes) dimmed to 0.45.
## Milestone 1's push-in and new effects follow it as they land.
var reduce_flashes: bool = false
## Button hints on screen: off hides the HUD's prompts (24.4).
var button_hints: bool = true


## A volume clamped to 0-100 and snapped to the nearest step of 5.
static func snap_volume(value: float) -> int:
	return clampi(roundi(value / 5.0) * 5, 0, 100)


## The chosen graphics preset.
func graphics_preset() -> GraphicsPreset:
	return GraphicsPreset.load_id(graphics_preset_id)


## Chooses a graphics preset by id. Returns false, and changes nothing, for an
## unknown id.
func set_graphics_preset(id: StringName) -> bool:
	graphics_preset_id = id
	return graphics_preset_id == id


## Sets every bus a volume drives to its layout level turned down by the
## volume, muting it at 0. Applying again doesn't stack.
func apply_volumes() -> void:
	var volumes := {"master": master_volume, "effects": effects_volume, "music": music_volume}
	for key: String in VOLUME_BUSES:
		var volume: int = volumes[key]
		for bus: StringName in VOLUME_BUSES[key]:
			var index := AudioServer.get_bus_index(bus)
			if index < 0:
				continue
			AudioServer.set_bus_mute(index, volume == 0)
			AudioServer.set_bus_volume_db(index, layout_volume_db(bus) + (linear_to_db(volume / 100.0) if volume > 0 else 0.0))


## A bus's level in the project's bus layout file (dB), whatever the bus is
## set to now; 0 for a bus the layout lacks.
static func layout_volume_db(bus: StringName) -> float:
	var path: String = ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres")
	var layout := load(path) as AudioBusLayout
	if layout == null:
		return 0.0
	var i := 0
	while layout.get("bus/%d/name" % i) != null:
		if StringName(layout.get("bus/%d/name" % i)) == bus:
			return float(layout.get("bus/%d/volume_db" % i))
		i += 1
	return 0.0


func save(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_GRAPHICS, "preset", String(graphics_preset_id))
	cfg.set_value(SECTION_AUDIO, "master", master_volume)
	cfg.set_value(SECTION_AUDIO, "effects", effects_volume)
	cfg.set_value(SECTION_AUDIO, "music", music_volume)
	cfg.set_value(SECTION_DISPLAY, "reduce_flashes", reduce_flashes)
	cfg.set_value(SECTION_DISPLAY, "button_hints", button_hints)
	return cfg.save(path)


## Loads the saved settings. A missing or unreadable file gives the defaults,
## and so does any saved value that isn't one the game knows, except the
## graphics preset: without a known one saved, it is the one card_name (this
## machine's graphics card by default) maps to.
static func load_from(path: String = PATH, card_name: String = RenderingServer.get_video_adapter_name()) -> GameSettings:
	var settings := GameSettings.new()
	settings.graphics_preset_id = GraphicsPreset.for_card(card_name)
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(path) or cfg.load(path) != OK:
		return settings
	var preset: Variant = cfg.get_value(SECTION_GRAPHICS, "preset", "")
	if preset is String or preset is StringName:
		settings.set_graphics_preset(StringName(preset))
	for key: String in VOLUME_BUSES:
		if not cfg.has_section_key(SECTION_AUDIO, key):
			continue
		var volume: Variant = cfg.get_value(SECTION_AUDIO, key)
		if volume is int or volume is float:
			settings.set("%s_volume" % key, volume)
	for key: String in ["reduce_flashes", "button_hints"]:
		if not cfg.has_section_key(SECTION_DISPLAY, key):
			continue
		var on: Variant = cfg.get_value(SECTION_DISPLAY, key)
		if on is bool:
			settings.set(key, on)
	return settings


## Where a run saves a file the player keeps at `path` (user://settings.cfg,
## user://controls.cfg): there, except in a run that asks for the defaults
## (DEFAULTS_ENV, test and shot runs), which saves beside it under a
## "test_run_" name so it never changes what the player saved.
static func save_path_for_run(path: String, use_defaults: bool = OS.has_environment(DEFAULTS_ENV)) -> String:
	return path.get_base_dir().path_join("test_run_" + path.get_file()) if use_defaults else path


## The settings a run starts with: the defaults when the run asks for them
## (DEFAULTS_ENV is set), the saved ones otherwise.
static func load_for_run(use_defaults: bool = OS.has_environment(DEFAULTS_ENV), path: String = PATH) -> GameSettings:
	return GameSettings.new() if use_defaults else load_from(path)
