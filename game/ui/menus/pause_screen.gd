class_name PauseScreen
extends MenuScreen
## The pause menu over the frozen match (port of showPause() in
## v0.1-web-mvp:src/ui/menus.ts): 休止 over "Paused", then Resume, Move list, Controls,
## Settings, Restart and Quit to menu. main.gd answers each entry: the three
## middle ones open their screens over this one (Back returns here), Restart
## and Quit to menu act at once. Back resumes, as the pause binding, Esc and
## Start do in the host.
##
## In Training two rows sit at the top of the list, for controller players
## (23.3): the dummy's behaviour (only the chosen one shows, between arrows)
## and Refill health, changed with left and right. The focus still opens on
## Resume; up from it reaches them. show_training() sets them.

signal resume_requested
signal move_list
signal controls
signal settings
signal restart
signal quit_to_menu
## A Training row changed: the dummy's behaviour, or the refill.
signal dummy_behaviour(behaviour: StringName)
signal refill_set(on: bool)

var resume_button: Button
var move_list_button: Button
var controls_button: Button
var settings_button: Button
var restart_button: Button
var quit_button: Button
var dummy_row: OptionRow
var refill_row: OptionRow


func _init() -> void:
	super()
	var kanji: Label = add_label("休止", UiTheme.KANJI, 48)
	kanji.name = "Kanji"
	kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var heading: Label = add_heading("Paused")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dummy_row = add_options("Dummy", MenuData.behaviour_names(), 0, func(i: int) -> void: dummy_behaviour.emit(TrainingBrain.BEHAVIOURS[i]))
	dummy_row.name = "DummyRow"
	dummy_row.show_only_chosen()
	refill_row = add_options("Refill health", ["On", "Off"] as Array[String], 0, func(i: int) -> void: refill_set.emit(i == 0))
	refill_row.name = "RefillRow"
	resume_button = add_button("Resume", "", func() -> void: resume_requested.emit())
	move_list_button = add_button("Move list", "", func() -> void: move_list.emit())
	controls_button = add_button("Controls", "", func() -> void: controls.emit())
	settings_button = add_button("Settings", "", func() -> void: settings.emit())
	restart_button = add_button("Restart", "", func() -> void: restart.emit())
	quit_button = add_button("Quit to menu", "", func() -> void: quit_to_menu.emit())
	back_pops = false
	back_requested.connect(func() -> void: resume_requested.emit())
	show_training(false)


## Shows the Training rows (training) on the dummy's behaviour and the
## refill, or hides them.
func show_training(training: bool, behaviour: StringName = &"idle", refill: bool = true) -> void:
	dummy_row.visible = training
	refill_row.visible = training
	dummy_row.set_index(maxi(0, TrainingBrain.BEHAVIOURS.find(behaviour)))
	refill_row.set_index(0 if refill else 1)


## The page opens on Resume, even with the Training rows above it.
func first_item() -> Control:
	return resume_button
