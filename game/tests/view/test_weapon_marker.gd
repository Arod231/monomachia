extends GutTest
## The HUD's marker on your dropped weapon (task 24.5): "Your weapon" with an
## arrow down at the weapon, from the disarm until it is back in hand; off
## screen or behind the camera it clamps to the edge and points the way.
## Only for your own weapon, never in Watch.

const SCREEN: Vector2 = Vector2(1600.0, 900.0)
const LEFT: int = WeaponMarker.Side.LEFT
const RIGHT: int = WeaponMarker.Side.RIGHT
const NONE: int = WeaponMarker.Side.NONE

var host: MatchHost
var hud: MatchHud


func _start(mode: StringName = MatchConfig.DUEL) -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	hud = host.get_node("Hud")
	var first: MatchSide = MatchSide.computer(&"rogue", &"katana", 0) if mode == MatchConfig.WATCH else MatchSide.human(&"rogue", &"katana", 0)
	var second: MatchSide = MatchSide.computer(&"hunter", &"katana", 1, &"easy")
	if mode == MatchConfig.TRAINING:
		second.controller = MatchSide.DUMMY
	host.start(MatchConfig.make(mode, first, second, 5, ArenaScenes.STANDIN))
	host.step(Match.INTRO_FRAMES + 2)


func _place(at: Vector2, behind: bool = false) -> Array:
	var w: Dictionary = WeaponMarker.place(at, behind, SCREEN)
	return [w["pos"], w["edge"], w["side"]]


## A grounded weapon of `owner` at a world position.
func _drop(owner: int, at: Vector3) -> DroppedWeapon:
	host.fighter(owner).armed = false
	var w := DroppedWeapon.new(owner, &"katana", V3.make(at.x, at.y, at.z), V3.make(), Rng.new(2))
	w.grounded = true
	host.world.weapons.append(w)
	return w


func _camera() -> Camera3D:
	return (host.get_node("View") as MatchView).camera


## A point on the floor 4 m ahead of the camera.
func _ahead() -> Vector3:
	var cam: Camera3D = _camera()
	var p: Vector3 = cam.global_position - cam.global_basis.z * 4.0
	p.y = 0.0
	return p


func test_on_screen_it_stands_over_the_point() -> void:
	assert_eq(_place(Vector2(800.0, 500.0)), [Vector2(800.0, 500.0), false, NONE])


func test_off_the_sides_it_clamps_and_points_the_way() -> void:
	assert_eq(_place(Vector2(-300.0, 500.0)), [Vector2(40.0, 500.0), true, LEFT])
	assert_eq(_place(Vector2(2000.0, 300.0)), [Vector2(1560.0, 300.0), true, RIGHT])
	assert_eq(_place(Vector2(30.0, 500.0)), [Vector2(40.0, 500.0), true, LEFT], "inside the margin counts as off")


func test_off_the_top_it_clamps_under_the_top_bar_and_off_the_bottom_to_the_margin() -> void:
	assert_eq(_place(Vector2(700.0, -50.0)), [Vector2(700.0, 100.0), true, LEFT])
	assert_eq(_place(Vector2(1000.0, 1200.0)), [Vector2(1000.0, 860.0), true, RIGHT])


## At an edge the whole marker stays on screen: its centre keeps half its
## width clear of the margin.
func test_at_an_edge_the_whole_marker_stays_on_screen() -> void:
	assert_eq(WeaponMarker.place(Vector2(2000.0, 300.0), false, SCREEN, 60.0)["pos"], Vector2(1500.0, 300.0))
	assert_eq(WeaponMarker.place(Vector2(-300.0, 300.0), false, SCREEN, 60.0)["pos"], Vector2(100.0, 300.0))
	assert_eq(WeaponMarker.place(Vector2(800.0, 450.0), false, SCREEN, 60.0)["pos"], Vector2(800.0, 450.0), "on screen it stands at the point")


## Behind the camera a projection comes out mirrored: the marker mirrors it
## back across and drops to the bottom margin.
func test_behind_the_camera_it_mirrors_and_drops_to_the_bottom() -> void:
	assert_eq(_place(Vector2(300.0, 200.0), true), [Vector2(1300.0, 860.0), true, RIGHT])
	assert_eq(_place(Vector2(1500.0, 400.0), true), [Vector2(100.0, 860.0), true, LEFT])
	assert_eq(_place(Vector2(800.0, 450.0), true)[1], true, "even in the middle")


func test_shown_only_for_your_own_weapon_while_disarmed() -> void:
	_start()
	hud._process(1.0 / 60.0)
	assert_false(hud.weapon_marker.visible, "armed")
	_drop(1, _ahead())
	hud._process(1.0 / 60.0)
	assert_false(hud.weapon_marker.visible, "the opponent's weapon")
	host.world.weapons.clear()
	host.fighter(1).armed = true
	_drop(0, _ahead())
	hud._process(1.0 / 60.0)
	assert_true(hud.weapon_marker.visible, "yours")
	assert_eq(hud.weapon_marker.label.text, "Your weapon")
	host.fighter(0).armed = true
	host.world.weapons.clear()
	hud._process(1.0 / 60.0)
	assert_false(hud.weapon_marker.visible, "back in hand")


## From the disarm on, while the weapon still flies (the owner's choice,
## Oct 4, 2026).
func test_it_shows_from_the_disarm_while_the_weapon_flies() -> void:
	_start()
	host.fighter(0).disarm(host.fighter(1), &"parried")
	var w: DroppedWeapon = host.world.weapon_of(0)
	assert_false(w.grounded, "still flying")
	hud._process(1.0 / 60.0)
	assert_true(hud.weapon_marker.visible)


func test_never_in_watch() -> void:
	_start(MatchConfig.WATCH)
	_drop(0, _ahead())
	_drop(1, _ahead())
	hud._process(1.0 / 60.0)
	assert_false(hud.weapon_marker.visible)


## On screen the marker's arrow points down at the spot 0.6 m over the
## weapon, as the gameplay camera sees it.
func test_it_points_at_the_weapon_through_the_camera() -> void:
	_start()
	var at: Vector3 = _ahead()
	_drop(0, at)
	hud._process(1.0 / 60.0)
	var cam: Camera3D = _camera()
	var expected: Vector2 = cam.unproject_position(at + Vector3(0.0, WeaponMarker.MARKER_HEIGHT, 0.0))
	assert_eq(hud.weapon_marker.side(), NONE, "on screen")
	assert_almost_eq(hud.weapon_marker.anchor().x, expected.x, 1.0)
	assert_almost_eq(hud.weapon_marker.anchor().y, expected.y, 1.0)
	assert_true(hud.weapon_marker.get_node("Down").visible, "the arrow down")


func test_a_weapon_behind_the_camera_clamps_to_the_bottom() -> void:
	_start()
	var cam: Camera3D = _camera()
	var at: Vector3 = cam.global_position + cam.global_basis.z * 3.0
	at.y = 0.0
	_drop(0, at)
	hud._process(1.0 / 60.0)
	var screen: Vector2 = hud.get_viewport().get_visible_rect().size
	assert_ne(hud.weapon_marker.side(), NONE, "points the way")
	assert_almost_eq(hud.weapon_marker.anchor().y, screen.y - WeaponMarker.PAD, 1.0, "on the bottom margin")
	assert_false(hud.weapon_marker.get_node("Down").visible, "no arrow down at the edge")
	var arrow: String = "Left" if hud.weapon_marker.side() == LEFT else "Right"
	assert_true(hud.weapon_marker.get_node("Row/" + arrow).visible)


## Wherever the weapon lies off screen, the marker (text and arrow) is
## inside the screen's margins.
func test_off_screen_the_marker_is_whole_on_screen() -> void:
	_start()
	var cam: Camera3D = _camera()
	var screen: Vector2 = hud.get_viewport().get_visible_rect().size
	var w: DroppedWeapon = _drop(0, Vector3.ZERO)
	for spot: Vector3 in [cam.global_basis.x * 12.0, -cam.global_basis.x * 12.0, cam.global_basis.z * 4.0 + cam.global_basis.x * 3.0, cam.global_basis.z * 4.0 - cam.global_basis.x * 3.0]:
		var at: Vector3 = cam.global_position + spot
		w.pos = V3.make(at.x, 0.0, at.z)
		hud._process(1.0 / 60.0)
		var rect: Rect2 = hud.weapon_marker.get_rect()
		assert_ne(hud.weapon_marker.side(), NONE, "at the edge for %s" % spot)
		assert_true(Rect2(Vector2.ZERO, screen).encloses(rect), "%s inside the screen for %s" % [rect, spot])


## In Training the marker never sits on the panel at the bottom left: a
## weapon anywhere behind the camera (which drops it to the bottom) leaves
## the panel clear.
func test_in_training_the_marker_keeps_off_the_panel() -> void:
	_start(MatchConfig.TRAINING)
	await wait_process_frames(2)
	var cam: Camera3D = _camera()
	var w: DroppedWeapon = _drop(0, Vector3.ZERO)
	assert_true(hud.training_panel.visible)
	for k: int in range(-6, 7):
		var at: Vector3 = cam.global_position + cam.global_basis.z * 3.0 + cam.global_basis.x * float(k)
		w.pos = V3.make(at.x, 0.0, at.z)
		hud._process(1.0 / 60.0)
		assert_false(hud.weapon_marker.get_rect().intersects(hud.training_panel.get_rect()), "clear of the panel at %d m" % k)


func test_the_results_hide_it() -> void:
	_start()
	_drop(0, _ahead())
	hud._process(1.0 / 60.0)
	hud._on_match_finished(host.results())
	assert_false(hud.weapon_marker.visible)
