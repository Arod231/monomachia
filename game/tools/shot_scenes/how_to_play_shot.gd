extends Node
## Screenshot scenes for the How to play screen (22.14), over the duel behind
## the menus. Each how_to_play_*.tscn picks a tab; render one with
##   node scripts/godot.mjs shots res://tools/shot_scenes/<name>.tscn <out.png>
## --scroll=<px> scrolls the page first (a weapon's lower sections).

## The tab (HowToPlayScreen.TABS): 0 the rules, 1-4 a weapon's moves.
@export var tab: int = 0
## How far down the page is scrolled (px).
@export var scroll: int = 0
## Frames to let the renderer settle before the capture.
@export var settle_frames: int = 10

var _ready_flag: bool = false


func shot_frames() -> int:
	return settle_frames


func shot_ready() -> bool:
	return _ready_flag


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scroll="):
			scroll = int(a.trim_prefix("--scroll="))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var host: MatchHost = main.get_node("MatchHost")
	host.auto_run = false
	main.call("show_main_menu")
	main.call("show_how_to_play")
	var screen: HowToPlayScreen = main.get("how_to_play")
	screen.show_tab(tab)
	host.step(420)
	var view: MatchView = host.get_node("View")
	view.snap_camera()
	view.set_process(false)
	(host.get_node("Hud") as MatchHud).set_process(false)
	# the page lays out before it can scroll
	await get_tree().process_frame
	await get_tree().process_frame
	screen.scroll.scroll_vertical = scroll
	_ready_flag = true
