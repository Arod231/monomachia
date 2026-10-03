extends Node
## The GameServices autoload: what the whole game shares, kept for as long as
## the game runs.
##
## - one GameSettings (the player's settings, user://settings.cfg, or the
##   defaults when the run sets GameSettings.DEFAULTS_ENV). At start it
##   applies their graphics preset to the renderer (the shadow atlas and
##   filtering, which are global) and the root viewport, and their volumes to
##   the buses; scenes apply graphics_preset() to themselves when they load;
## - one ControlProfiles (the saved controls profiles, user://controls.cfg);
## - one InputDevices, which every match samples, with its InputFeed in the
##   tree so labels follow the last device used, even in menus (the shared
##   input home that task 21 asked for; see the recipe in input_devices.gd);
## - the match being played, which it pauses when the window loses focus
##   (spec story 10);
## - the music: one MusicDirector and the MusicPlayer that follows it, so a
##   track plays on from screen to screen. It plays only when the screens ask
##   (play_menu_music, play_match_music), so tests that load this autoload
##   stay silent;
## - the menu sounds (play_ui), from a flat SoundPlayer of its own, so a press
##   that changes screens still sounds.
##
## A match host registers itself with begin_match() while a match is played
## and calls end_match() when it stops. No class_name: the autoload's name is
## the global.

var settings: GameSettings
var profiles: ControlProfiles
var input: InputDevices
var feed: InputFeed
var music_director: MusicDirector
var music: MusicPlayer
var ui_sounds: SoundPlayer

## The host of the match being played, or null. Anything with
## `is_playing() -> bool` and `pause()`.
var _match: Node = null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = GameSettings.load_for_run()
	profiles = ControlProfiles.load_from()
	input = InputDevices.new()
	feed = InputFeed.new(input)
	feed.name = "InputFeed"
	music_director = MusicDirector.new()
	music = MusicPlayer.new()
	music.name = "Music"
	music.bind(music_director)
	ui_sounds = SoundPlayer.new()
	ui_sounds.name = "UiSounds"
	ui_sounds.flat_voices = 4
	ui_sounds.spatial_voices = 0


func _ready() -> void:
	add_child(feed)
	add_child(music)
	add_child(ui_sounds)
	ui_sounds.preload_cues([&"ui_move", &"ui_select", &"ui_confirm", &"ui_back"])
	feed.focus_lost.connect(_on_focus_lost)
	GraphicsApplier.apply(graphics_preset(), null, get_viewport())
	settings.apply_volumes()


## The graphics preset the player chose.
func graphics_preset() -> GraphicsPreset:
	return settings.graphics_preset()


## A match host starts being played (Duel, Training, Watch or Versus; not the
## duel behind the menus).
func begin_match(host: Node) -> void:
	_match = host


## The host stops being played (quit to menu, or freed). Ignored for any other
## host.
func end_match(host: Node) -> void:
	if _match == host:
		_match = null


func current_match() -> Node:
	if _match != null and not is_instance_valid(_match):
		_match = null
	return _match


## The title, the menus and the results: the menu track.
func play_menu_music() -> void:
	music.play(music_director.enter_menu())


## A played match starts: the battle track, until a round call with a
## fighter on two wins switches to match point.
func play_match_music() -> void:
	music.play(music_director.enter_match())


## A rules event of the match being played (never the duel behind the
## menus): the round calls choose between battle and match point.
func music_event(event: Dictionary) -> void:
	music_director.handle_event(event)


## Fades the music out.
func stop_music() -> void:
	music.stop()


## A menu sound, on the UI bus: ui_move (the focus moves), ui_select (a button
## is pressed), ui_confirm (the title goes on) or ui_back.
func play_ui(event: StringName) -> void:
	ui_sounds.play_event({"t": event})


func _on_focus_lost() -> void:
	var host: Node = current_match()
	if host != null and host.call("is_playing"):
		host.call("pause")
