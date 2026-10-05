extends Node
## The game's flow for the playable skeleton (task 22 replaces the menus):
## title -> main menu (Duel, Training, Versus, Watch, How to play, Controls,
## Settings, Quit)
## -> the fighter select (each mode) -> a match -> results (Rematch,
## Change fighters, Main menu), with a pause menu during play (PauseScreen:
## Resume, Move list, Controls, Settings, Restart, Quit to menu), which Back,
## Start or the pause binding also closes. The pages sit on a ScreenStack:
## Back on a page goes to the page that opened it (the main menu's to the
## title, a screen opened from the pause's to the pause). While a screen is
## open over the pause, the pause binding, Esc and Start don't resume (Esc is
## that screen's Back).
## A computer duel plays behind the title
## and the menus, seen from the orbiting menu camera; its restarts and the
## matches draw their seeds from one sequence (_next_seed).
##
## The music (GameServices): the title, the menus and the results play the
## menu track, a played match the battle track, and the played match's rules
## events reach the music director, so a round call with a fighter on two wins
## switches to match point. The duel behind the menus never changes the track.
## The music stops when these screens go.
##
## The fighter select starts from the mode's last picks (MatchSelection,
## saved at lock in to user://last_select.cfg; test and shot runs, which set
## GameSettings.DEFAULTS_ENV, neither read nor write it). start_duel() and
## start_watch() skip the select with the demo's defaults: the Rogue with the
## katana (you) against the Hunter with the greatsword (Normal), and katana
## against daggers, both Normal.
##
## With --smoke on the command line the game plays a Watch match to the
## results at once and quits with its outcome (see SmokeRun).

enum Screen { TITLE, MENU, PLAYING, PAUSED, RESULTS, SELECT }

## The arena the duel behind the menus and the matches started without the
## select are fought in. Tests set the stand-in before the scene enters the
## tree, and any arena but the default then replaces the select's pick too.
@export var arena_id: StringName = MatchConfig.DEFAULT_ARENA

@onready var host: MatchHost = $MatchHost
@onready var ui: CanvasLayer = $Menus

var screen: Screen = Screen.TITLE
var title: TitleScreen
var main_menu: MenuScreen
var pause_menu: PauseScreen
var results_screen: ResultsScreen
var select: FighterSelect
## The fighter select's drafts and last picks.
var selection: MatchSelection
var how_to_play: HowToPlayScreen
var controls_screen: ControlsScreen
var settings_screen: SettingsScreen
## The menus' pages, the open one on top.
var stack: ScreenStack = ScreenStack.new()
## The last match played, for Rematch.
var last_config: MatchConfig
## The demo's per-match seed sequence (see MatchConfig.next_seed).
var _seed: int = 1
## The --smoke run, when the flag is given.
var _smoke: SmokeRun


func _ready() -> void:
	title = TitleScreen.new()
	title.name = "Title"
	ui.add_child(title)
	title.proceed.connect(show_main_menu)

	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	main_menu.add_button("Duel", "vs computer", open_select.bind(MatchConfig.DUEL))
	main_menu.add_button("Training", "parries and counters", open_select.bind(MatchConfig.TRAINING))
	main_menu.add_button("Versus", "two players, one screen", open_select.bind(MatchConfig.VERSUS))
	main_menu.add_button("Watch", "computer vs computer", open_select.bind(MatchConfig.WATCH))
	main_menu.add_button("How to play", "rules and move lists", show_how_to_play)
	main_menu.add_button("Controls", "keys and buttons", show_controls)
	main_menu.add_button("Settings", "picture and sound", show_settings)
	main_menu.add_button("Quit", "to the desktop", quit_game)
	ui.add_child(main_menu)

	pause_menu = PauseScreen.new()
	pause_menu.name = "Pause"
	pause_menu.resume_requested.connect(resume)
	pause_menu.move_list.connect(show_move_list)
	pause_menu.controls.connect(show_controls)
	pause_menu.settings.connect(show_settings)
	pause_menu.restart.connect(restart)
	pause_menu.quit_to_menu.connect(quit_to_menu)
	pause_menu.dummy_behaviour.connect(func(b: StringName) -> void: host.set_training_behaviour(b))
	pause_menu.refill_set.connect(func(on: bool) -> void: host.set_refill(on))
	ui.add_child(pause_menu)

	results_screen = ResultsScreen.new()
	results_screen.name = "Results"
	results_screen.rematch.connect(rematch)
	results_screen.change_fighters.connect(change_fighters)
	results_screen.main_menu.connect(quit_to_menu)
	ui.add_child(results_screen)

	selection = MatchSelection.new(MatchSelection.PATH, not OS.has_environment(GameSettings.DEFAULTS_ENV))
	selection.load_saved()
	select = FighterSelect.new()
	select.name = "Select"
	select.locked_in.connect(_on_locked_in)
	ui.add_child(select)

	how_to_play = HowToPlayScreen.new()
	how_to_play.name = "HowToPlay"
	ui.add_child(how_to_play)
	controls_screen = ControlsScreen.new()
	controls_screen.name = "Controls"
	ui.add_child(controls_screen)
	settings_screen = SettingsScreen.new()
	settings_screen.name = "Settings"
	ui.add_child(settings_screen)
	stack.changed.connect(_on_stack_changed)

	host.match_finished.connect(_on_match_finished)
	host.pause_changed.connect(_on_pause_changed)
	host.sim_event.connect(_on_sim_event)
	host.training_changed.connect(_show_pause_training)
	# the attract restarts draw from the same seed sequence as the matches
	host.seed_source = _next_seed
	start_attract()
	show_title()
	# _process only ticks a smoke run.
	set_process(false)
	if SmokeRun.requested(OS.get_cmdline_args() + OS.get_cmdline_user_args()):
		_smoke = SmokeRun.new(self)
		_smoke.start()
		set_process(true)


func _exit_tree() -> void:
	GameServices.stop_music()


func _process(_delta: float) -> void:
	if _smoke == null or _smoke.tick() == SmokeRun.Status.RUNNING:
		return
	print(_smoke.report())
	get_tree().quit(_smoke.exit_code())
	_smoke = null
	set_process(false)


func _next_seed() -> int:
	_seed = MatchConfig.next_seed(_seed)
	return _seed


## Follows the stack's top page into `screen` (Back can change it).
func _on_stack_changed(top: MenuPage) -> void:
	if top == title:
		screen = Screen.TITLE
	elif top == main_menu:
		screen = Screen.MENU
	elif top == pause_menu:
		screen = Screen.PAUSED
	elif top == results_screen:
		screen = Screen.RESULTS
	elif top == select:
		screen = Screen.SELECT
	# A screen over the pause takes Esc as its Back: the host mustn't resume
	# on it. Back on the pause again, the keys still down from that Back
	# count as already pressed.
	host.pause_press_resumes = top == pause_menu or not host.is_paused()
	if top == pause_menu and host.input != null:
		host.input.rearm_pause()


# ------------------------------------------------------------------ screens

func start_attract() -> void:
	host.start(_in_arena(MatchConfig.attract(_next_seed())), true)


func show_title() -> void:
	stack.reset([title] as Array[MenuPage])
	GameServices.play_menu_music()


## The main menu, over the title (where its Back goes).
func show_main_menu() -> void:
	stack.reset([title, main_menu] as Array[MenuPage])
	GameServices.play_menu_music()


## How to play opens over the page that chose it; Back returns there.
func show_how_to_play() -> void:
	stack.push(how_to_play)


## Controls and Settings open over the page that chose them; Back returns
## there.
func show_controls() -> void:
	stack.push(controls_screen)


func show_settings() -> void:
	stack.push(settings_screen)


## The pause's Move list: How to play over the pause, on the tab of the
## weapon the player holds (bare hands while disarmed); Watch, with no
## player, and Versus, with two (either may have paused), open it on the
## Rules.
func show_move_list() -> void:
	stack.push(how_to_play)
	var me: int = host.config.first_human_side() if host.config != null else -1
	if host.config != null and host.config.mode == MatchConfig.VERSUS:
		me = -1
	if me >= 0:
		how_to_play.show_weapon(host.fighter(me).moveset().id)


## Opens the fighter select for a mode over the page on top, on the mode's
## last picks; Back from its first side returns to that page.
func open_select(mode: StringName) -> void:
	select.start(selection.draft(mode))
	stack.push(select)
	GameServices.play_menu_music()


## Lock in: the picks are kept (and saved) for next time, and the match starts
## with the next seed.
func _on_locked_in(draft: MatchSelection.Draft) -> void:
	selection.drafts[draft.mode] = draft
	selection.save()
	var cfg: MatchConfig = MatchSelection.lock_in(draft, _next_seed())
	if arena_id != MatchConfig.DEFAULT_ARENA:
		cfg.arena_id = arena_id
	start_match(cfg)


## A Duel with the demo's defaults, without the select.
func start_duel() -> void:
	start_match(_in_arena(MatchConfig.default_duel(_next_seed())))


## A Watch match with the demo's defaults, without the select.
func start_watch() -> void:
	start_match(_in_arena(MatchConfig.default_watch(_next_seed())))


func _in_arena(cfg: MatchConfig) -> MatchConfig:
	cfg.arena_id = arena_id
	return cfg


## Plays a match from a config. A config the host refuses (it reports why)
## goes back to the main menu instead. Returns whether the match started.
func start_match(cfg: MatchConfig) -> bool:
	if not host.start(cfg):
		quit_to_menu()
		return false
	stack.clear()
	last_config = cfg
	screen = Screen.PLAYING
	GameServices.play_match_music()
	return true


func rematch() -> void:
	if last_config == null:
		return
	start_match(last_config.with_seed(_next_seed()))


## The pause's Restart: the same match again with the next seed, at once.
## Training keeps its refill setting and the dummy's behaviour (a new
## Training from the menu starts on Stand still with refill on).
func restart() -> void:
	var refill: bool = host.refill()
	var behaviour: StringName = host.training_behaviour()
	rematch()
	host.set_refill(refill)
	if behaviour != &"":
		host.set_training_behaviour(behaviour)


## From the results: the select for the mode just played, on its last picks,
## over the main menu (where its Back goes), with the duel behind the menus
## playing again.
func change_fighters() -> void:
	var mode: StringName = last_config.mode if last_config != null else MatchConfig.DUEL
	quit_to_menu()
	open_select(mode)


## Back to the match from the pause menu (Resume, Back). The host's
## pause_changed closes the menu, as it does when Start resumes.
func resume() -> void:
	host.resume()


func quit_to_menu() -> void:
	host.stop()
	start_attract()
	show_main_menu()


func quit_game() -> void:
	get_tree().quit()


func _on_pause_changed(paused: bool) -> void:
	if paused:
		_show_pause_training()
		stack.reset([pause_menu] as Array[MenuPage])
	elif screen == Screen.PAUSED:
		stack.clear()
		screen = Screen.PLAYING


## The pause's Training rows follow the dummy's behaviour and the refill
## (shown only in Training).
func _show_pause_training() -> void:
	var b: StringName = host.training_behaviour() if host.is_started() else &""
	pause_menu.show_training(b != &"", b if b != &"" else &"idle", host.refill())


func _on_match_finished(results: MatchResults) -> void:
	results_screen.show_results(results)
	stack.reset([results_screen] as Array[MenuPage])
	GameServices.play_menu_music()


func _on_sim_event(e: Dictionary) -> void:
	if not host.attract:
		GameServices.music_event(e)
