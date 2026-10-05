extends GutTest
## Reduce flashes and shaking (task 18.11): with the setting on, the camera's
## shake is scaled to 0.15, its field-of-view kicks are off, and flashes (the
## effects' glows and rings, and the fighters' body flashes) are dimmed to
## 0.45 of their brightness at full size (the owner's choice, Oct 4, 2026).
## It applies at match start and whenever the setting changes, even mid-match
## from the pause menu's Settings. (Its saving and loading is
## test_game_settings'.)

var host: MatchHost
var view: MatchView
var settings: GameSettings
var at: Dictionary = {"x": 0.0, "y": 1.25, "z": 0.0}


func before_each() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	add_child_autofree(host)
	view = host.get_node("View")
	settings = GameSettings.new()
	view.use_settings(settings)


func _start() -> void:
	var cfg: MatchConfig = MatchConfig.make(
		MatchConfig.DUEL,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"),
		7,
		ArenaScenes.STANDIN,
	)
	host.start(cfg)


func _parry() -> void:
	host.sim_event.emit({"t": &"parry", "parrier": 1, "attacker": 0, "kind": &"parry", "pos": at, "timing": 2, "window": 6})


## The alpha flash i is drawn with: its colour in the flash pool's instance
## buffer (a transform's 12 floats, then the colour), which the effects hand
## the MultiMesh (headless runs keep no instance colours of their own).
func _drawn_flash_alpha(i: int) -> float:
	view.effects.update(view.effects.clock())
	var buf: PackedFloat32Array = view.effects._buffers[CombatEffects.FLASHES]
	return buf[i * 16 + 15]


func test_off_by_default_nothing_is_reduced() -> void:
	_start()
	assert_false(settings.reduce_flashes)
	assert_eq(view.camera.shake_scale, 1.0)
	assert_eq(view.camera.fov_kick_scale, 1.0)
	assert_eq(view.effects.flash_scale, 1.0)
	_parry()
	assert_almost_eq(view.camera.shake, view.parry_shake, 1e-6)
	assert_eq(view.camera.fov_kick, 3.0)


func test_on_at_match_start_the_scales_are_set() -> void:
	settings.reduce_flashes = true
	_start()
	assert_eq(view.camera.shake_scale, 0.15)
	assert_eq(view.camera.fov_kick_scale, 0.0)
	assert_eq(view.effects.flash_scale, 0.45)


## A parry with it on: no kick, the shake scaled, the glow dimmed but full size.
func test_a_parry_makes_no_kick_a_scaled_shake_and_a_dimmed_flash() -> void:
	settings.reduce_flashes = true
	_start()
	_parry()
	assert_eq(view.camera.fov_kick, 0.0, "no field-of-view kick")
	assert_almost_eq(view.camera.shake, view.parry_shake * 0.15, 1e-6, "the shake scaled to 0.15")
	assert_gt(view.effects.flash_count(), 0, "the parry's glow")
	var dimmed: float = _drawn_flash_alpha(0)
	var state: Dictionary = view.effects.flash_state(0)
	var full: float = (state["color"] as Color).a * float(state["alpha"])
	assert_gt(full, 0.1, "a bright flash to dim")
	assert_almost_eq(dimmed, full * 0.45, 1e-4, "drawn at 0.45 of its brightness")
	var size_on: float = float(view.effects.flash_state(0)["size"])
	settings.reduce_flashes = false
	settings.changed.emit()
	assert_almost_eq(float(view.effects.flash_state(0)["size"]), size_on, 1e-6, "at full size either way")


func test_contact_kicks_and_ultimate_kicks_are_off_too() -> void:
	settings.reduce_flashes = true
	_start()
	host.sim_event.emit({"t": &"hit", "attacker": 0, "target": 1, "heavy": true, "sound": &"blade", "pos": at})
	host.sim_event.emit({"t": &"ultStart", "f": 0, "ult": &"moonsplitter"})
	host.sim_event.emit({"t": &"disarm", "victim": 1, "by": 0, "reason": &"parried", "pos": at})
	assert_eq(view.camera.fov_kick, 0.0)


## The fighters' body flashes (a hit's tint, a disarm's and a K.O.'s white)
## are dimmed to 0.45 as well.
func test_body_flashes_are_dimmed() -> void:
	settings.reduce_flashes = true
	_start()
	var frame: int = host.world.frame
	host.sim_event.emit({"t": &"hit", "attacker": 0, "target": 1, "heavy": false, "sound": &"blade", "pos": at})
	assert_almost_eq(view.fighters[1].flash_left(frame), 0.4 * 0.45, 1e-6, "a light hit's tint")
	host.sim_event.emit({"t": &"ko", "loser": 0, "winner": 1})
	assert_almost_eq(view.fighters[0].flash_left(frame), 0.8 * 0.45, 1e-6, "a K.O.'s white")


func test_body_flashes_are_full_with_it_off() -> void:
	_start()
	var frame: int = host.world.frame
	host.sim_event.emit({"t": &"disarm", "victim": 1, "by": 0, "reason": &"parried", "pos": at})
	assert_almost_eq(view.fighters[1].flash_left(frame), 0.6, 1e-6)


## Changed mid-match (the pause menu's Settings), it applies at once, both ways.
func test_a_change_mid_match_applies_at_once() -> void:
	_start()
	settings.reduce_flashes = true
	settings.changed.emit()
	assert_eq(view.camera.shake_scale, 0.15)
	assert_eq(view.camera.fov_kick_scale, 0.0)
	assert_eq(view.effects.flash_scale, 0.45)
	settings.reduce_flashes = false
	settings.changed.emit()
	assert_eq(view.camera.shake_scale, 1.0)
	assert_eq(view.camera.fov_kick_scale, 1.0)
	assert_eq(view.effects.flash_scale, 1.0)


## The Settings screen tells the settings it changed them, so a match
## behind the pause menu follows.
func test_the_settings_screen_reports_its_changes() -> void:
	var screen: SettingsScreen = SettingsScreen.new(settings, "user://test_reduce_flashes.cfg")
	add_child_autofree(screen)
	watch_signals(settings)
	screen.flashes._on_chip(1)
	assert_true(settings.reduce_flashes)
	assert_signal_emitted(settings, "changed")
	_start()
	assert_eq(view.camera.shake_scale, 0.15, "the match follows")


## Swapping the settings the view follows lets the old ones go, and
## following the same ones again connects once.
func test_use_settings_follows_only_the_new_settings() -> void:
	_start()
	var other: GameSettings = GameSettings.new()
	view.use_settings(other)
	assert_false(settings.changed.is_connected(view.apply_reduce_flashes), "the old settings let go")
	settings.reduce_flashes = true
	settings.changed.emit()
	assert_eq(view.camera.shake_scale, 1.0, "the old settings no longer reach the view")
	view.use_settings(other)
	assert_eq(other.changed.get_connections().size(), 1, "connected once")
	other.reduce_flashes = true
	other.changed.emit()
	assert_eq(view.camera.shake_scale, 0.15)
