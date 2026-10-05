extends Node
## Screenshot scenes for the menu screens of tasks 22.6-22.12, over the duel
## behind the menus. Each .tscn next to this script picks one `shot`; render
## one with
##   node scripts/godot.mjs shots res://tools/shot_scenes/<name>.tscn <out.png>
##
## "settings" is the Settings screen; "controls_kb" and "controls_pad" the
## Controls table's two tabs (the controller tab with a PlayStation pad
## plugged in a fake device state, so its names show), and "controls_listening"
## a keyboard slot listening for a key (22.11); "controls_profiles" the profile
## row with three profiles and "controls_rename" Rename opened from a
## controller, with its letter grid (22.12); "results_defeat" and
## "results_watch" the results of a played Duel the player lost and of a
## Watch match; "loadout_<weapon>" the fighter select on your side of a Duel
## with that weapon, and "loadout_random" on the opponent's side left to
## Random; "pause" the pause menu over a Duel mid-fight (22.15), and
## "pause_move_list", "pause_controls" and "pause_settings" its screens
## opened over it; "pause_training" the pause over Training, with its two
## rows (23.3), and "select_training" the select on the training dummy's
## side, with its note; "select_versus" the Versus select on Player 2's step
## (22.16), a PlayStation controller plugged in a fake device state, and
## "select_versus_warning" the same with Player 2 set to a second controller
## that isn't connected, its warning shown. The screens save to throwaway
## paths, never the player's.

@export_enum(
	"settings", "controls_kb", "controls_pad", "controls_listening", "controls_profiles", "controls_rename",
	"results_defeat", "results_watch",
	"loadout_katana", "loadout_greatsword", "loadout_daggers", "loadout_random",
	"pause", "pause_move_list", "pause_controls", "pause_settings", "pause_training", "select_training",
	"select_versus", "select_versus_warning",
) var shot: String = "settings"
## Frames to let the renderer settle before the capture.
@export var settle_frames: int = 10

var main: Node
var host: MatchHost
var _ready_flag: bool = false


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	host = main.get_node("MatchHost")
	host.auto_run = false
	var stack: ScreenStack = main.get("stack")
	var ui: CanvasLayer = main.get_node("Menus")
	match shot:
		"settings":
			_menus_behind()
			var s: SettingsScreen = SettingsScreen.new(GameSettings.new(), "user://shot_settings.cfg")
			ui.add_child(s)
			stack.push(s)
		"controls_kb", "controls_pad", "controls_listening", "controls_profiles", "controls_rename":
			_menus_behind()
			var state: FakeDeviceState = FakeDeviceState.new()
			var input: InputDevices = InputDevices.new(state)
			if shot == "controls_pad" or shot == "controls_rename":
				state.plug_pad(0, "DualSense Wireless Controller", {"vendor_id": 0x054C})
				var press: InputEventJoypadButton = InputEventJoypadButton.new()
				press.button_index = JOY_BUTTON_A
				press.pressed = true
				input.note_event(press)
			var store: ControlProfiles = ControlProfiles.new()
			if shot == "controls_profiles" or shot == "controls_rename":
				store.add_profile()
				store.add_profile()
				store.rename(0, "Kenji")
			var c: ControlsScreen = ControlsScreen.new(store, "user://shot_controls.cfg", input)
			ui.add_child(c)
			stack.push(c)
			if shot == "controls_listening":
				# the heavy attack's second slot waiting for a key (22.11)
				c.start_capture(ControlProfile.KB, "heavy", 1)
				(c.slot_buttons["heavy"][1] as Button).grab_focus()
			elif shot == "controls_profiles":
				# three profiles, Player 3 active: Delete shows
				c.profile_row.grab_focus()
			elif shot == "controls_rename":
				# Rename opened from a controller: the letter grid, the cursor on R
				c.rename_button.pressed.emit()
				c.letter_grid.cursor = Vector2i(1, 7)
		"loadout_katana", "loadout_greatsword", "loadout_daggers", "loadout_random":
			_menus_behind()
			main.call("open_select", MatchConfig.DUEL)
			var select: FighterSelect = main.get("select")
			if shot == "loadout_random":
				MatchSelection.set_random_weapon(select.draft, 1, true)
				select.show_side(1)
			else:
				MatchSelection.set_weapon(select.draft, 0, StringName(shot.trim_prefix("loadout_")))
				select.show_side(0)
		"pause", "pause_move_list", "pause_controls", "pause_settings":
			var duel: MatchConfig = MatchConfig.default_duel(7)
			duel.arena_id = main.get("arena_id")
			main.call("start_match", duel)
			host.step(Match.INTRO_FRAMES + 150)
			host.pause()
			match shot:
				"pause_move_list":
					(main.get("pause_menu") as PauseScreen).move_list_button.pressed.emit()
				"pause_controls":
					(main.get("pause_menu") as PauseScreen).controls_button.pressed.emit()
				"pause_settings":
					(main.get("pause_menu") as PauseScreen).settings_button.pressed.emit()
		"pause_training":
			var training: MatchConfig = MatchConfig.default_training(7)
			training.arena_id = main.get("arena_id")
			main.call("start_match", training)
			host.step(Match.INTRO_FRAMES + 60)
			host.set_training_behaviour(&"random")
			host.pause()
		"select_training":
			_menus_behind()
			main.call("open_select", MatchConfig.TRAINING)
			(main.get("select") as FighterSelect).show_side(1)
		"select_versus", "select_versus_warning":
			_menus_behind()
			var pads: FakeDeviceState = FakeDeviceState.new()
			pads.plug_pad(0, "PS5 Controller")
			var select: FighterSelect = main.get("select")
			select.input = InputDevices.new(pads)
			main.call("open_select", MatchConfig.VERSUS)
			select.show_side(1)
			if shot == "select_versus_warning":
				MatchSelection.set_device(select.draft, 1, InputDevices.PAD1)
				select.show_side(1)
		"results_defeat", "results_watch":
			var cfg: MatchConfig = MatchConfig.default_duel(7) if shot == "results_defeat" else MatchConfig.default_watch(7)
			cfg.arena_id = main.get("arena_id")
			main.call("start_match", cfg)
			while not host.is_finished():
				host.step(1)
			host.step(30)
	var view: MatchView = host.get_node("View")
	view.snap_camera()
	view.set_process(false)
	_ready_flag = true


## The main menu over the duel, as the screens open from it.
func _menus_behind() -> void:
	main.call("show_main_menu")
	host.step(420)
