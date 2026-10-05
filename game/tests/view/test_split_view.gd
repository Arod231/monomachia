extends GutTest
## Versus split screen (task 23.6): two side-by-side views of one world, each
## with its own CameraRig following its player toward the other; shake and
## field-of-view kicks reach both, the graphics preset applies to both, the
## shrine's underside is decided per camera, and one listener, between the
## fighters and facing side-on, hears the 3D sound. The other modes keep one
## view, and rematches leave no stray viewports.

var host: MatchHost
var view: MatchView
var audio: MatchAudio


## An arena that records which cameras asked about its underside.
class FakeArena:
	extends Node3D
	var culled: Array[Camera3D] = []

	func cull_below_deck(camera: Camera3D) -> void:
		culled.append(camera)


func before_each() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	view = host.get_node("View")
	audio = host.get_node("Audio")


func _versus(seed_value: int = 9) -> MatchConfig:
	return MatchConfig.make(
		MatchConfig.VERSUS,
		MatchSide.human(&"rogue", &"katana", 0, InputDevices.KBM),
		MatchSide.human(&"hunter", &"greatsword", 1, InputDevices.PAD0),
		seed_value,
		ArenaScenes.STANDIN,
	)


func _mode(mode: StringName) -> MatchConfig:
	match mode:
		MatchConfig.TRAINING:
			var cfg: MatchConfig = MatchConfig.default_training(3)
			cfg.arena_id = ArenaScenes.STANDIN
			return cfg
		MatchConfig.WATCH:
			return MatchConfig.make(mode, MatchSide.computer(&"rogue", &"katana", 0), MatchSide.computer(&"hunter", &"daggers", 1), 3, ArenaScenes.STANDIN)
	return MatchConfig.make(mode, MatchSide.human(&"rogue", &"katana", 0), MatchSide.computer(&"hunter", &"daggers", 1), 3, ArenaScenes.STANDIN)


func _start(cfg: MatchConfig) -> void:
	assert_true(host.start(cfg), "started: %s" % cfg.problem())
	host.step(Match.INTRO_FRAMES + 30)
	view.render(1.0 / 60.0)


func _viewports() -> Array[Node]:
	return view.find_children("*", "SubViewport", true, false)


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func test_versus_builds_two_cameras_following_each_player() -> void:
	_start(_versus())
	assert_eq(view.cameras.size(), 2)
	assert_not_null(view.split)
	assert_eq(view.cameras[0], view.camera, "player 1's camera is the view's camera")
	for i: int in 2:
		var cam: CameraRig = view.cameras[i]
		assert_eq(cam.mode, CameraRig.Mode.FOLLOW, "camera %d follows" % i)
		assert_eq(cam.get_viewport(), view.split.viewports[i], "camera %d in its own half" % i)
		assert_true(cam.current, "camera %d draws its half" % i)
		# over its own player's shoulder: nearer its player than the other
		var mine: Vector3 = host.display_position(i)
		var theirs: Vector3 = host.display_position(1 - i)
		var at: Vector2 = _flat(cam.global_position)
		assert_lt(at.distance_to(_flat(mine)), at.distance_to(_flat(theirs)), "camera %d behind its player" % i)


func test_both_halves_draw_the_one_world() -> void:
	_start(_versus())
	var world: World3D = view.get_viewport().find_world_3d()
	for vp: SubViewport in view.split.viewports:
		assert_eq(vp.find_world_3d(), world, "%s shares the match's world" % vp.name)
		assert_false(vp.own_world_3d)
	assert_null(view.get_viewport().get_camera_3d(), "the root view draws no 3D under the halves")


func test_the_halves_sit_side_by_side_under_the_hud() -> void:
	_start(_versus())
	await get_tree().process_frame
	var left: Control = view.split.containers[0]
	var right: Control = view.split.containers[1]
	var screen: Vector2 = view.get_viewport().get_visible_rect().size
	assert_almost_eq(left.size.x, right.size.x, 1.0, "two equal halves")
	assert_lt(left.global_position.x, right.global_position.x, "player 1 on the left")
	assert_almost_eq(left.size.x + right.size.x + view.split.divider.size.x, screen.x, 1.0, "they fill the width")
	assert_almost_eq(left.size.y, screen.y, 1.0, "the full height")
	assert_true(view.split.viewports[0].size.x > 0)
	var hud: MatchHud = host.get_node("Hud")
	assert_lt(view.split.layer, hud.layer, "the HUD draws over the halves")


func test_the_other_modes_keep_one_view() -> void:
	for mode: StringName in [MatchConfig.DUEL, MatchConfig.TRAINING, MatchConfig.WATCH]:
		_start(_mode(mode))
		assert_eq(view.cameras.size(), 1, String(mode))
		assert_null(view.split, String(mode))
		assert_eq(_viewports().size(), 0, "%s: no extra viewports" % mode)
		assert_eq(view.camera.get_viewport(), view.get_viewport(), "%s: the camera draws the screen" % mode)
		assert_true(view.camera.current, String(mode))


func test_rematches_leave_no_stray_viewports() -> void:
	_start(_versus())
	var split: SplitView = view.split
	for k: int in 3:
		_start(_versus(20 + k))
		assert_eq(view.split, split, "a rematch keeps the split")
		assert_eq(_viewports().size(), 2, "still two viewports")
	_start(_mode(MatchConfig.DUEL))
	await get_tree().process_frame
	assert_eq(_viewports().size(), 0, "a Duel after Versus leaves none")
	assert_eq(view.find_children("*", "CameraRig", true, false).size(), 1, "one camera")
	assert_eq(view.camera.get_parent(), view, "the camera back on the view")
	assert_true(view.camera.current)
	_start(_versus())
	assert_eq(_viewports().size(), 2, "and Versus again builds two")
	assert_eq(view.find_children("*", "CameraRig", true, false).size(), 2)


func test_shake_and_kicks_reach_both_cameras() -> void:
	_start(_versus())
	for cam: CameraRig in view.cameras:
		cam.shake = 0.0
		cam.fov_kick = 0.0
	view._on_sim_event({"t": &"parry", "parrier": 0, "attacker": 1, "kind": &"parry", "timing": 3, "window": 9, "pos": {"x": 0.0, "y": 1.0, "z": 0.0}})
	for i: int in 2:
		assert_gt(view.cameras[i].shake, 0.0, "camera %d shakes" % i)
		assert_gt(view.cameras[i].fov_kick, 0.0, "camera %d kicks" % i)


func test_reduce_flashes_reaches_both_cameras() -> void:
	var s: GameSettings = GameSettings.new()
	view.use_settings(s)
	_start(_versus())
	s.reduce_flashes = true
	view.apply_reduce_flashes()
	for i: int in 2:
		assert_eq(view.cameras[i].shake_scale, MatchView.REDUCED_SHAKE, "camera %d" % i)
		assert_eq(view.cameras[i].fov_kick_scale, 0.0, "camera %d" % i)


func test_no_ko_orbit_in_either_half() -> void:
	_start(_versus())
	view._on_sim_event({"t": &"ko", "loser": 1, "winner": 0})
	for i: int in 2:
		assert_eq(view.cameras[i].ko_orbit, 0.0, "camera %d" % i)


func test_the_arena_s_camera_data_reaches_both() -> void:
	_start(_versus())
	for i: int in 2:
		assert_eq(view.cameras[i].far, view.camera.far, "camera %d" % i)
		assert_eq(view.cameras[i].arena_max_radius, view.camera.arena_max_radius, "camera %d" % i)


func test_the_graphics_preset_applies_to_both_halves() -> void:
	_start(_versus())
	var preset: GraphicsPreset = GameServices.graphics_preset()
	for vp: SubViewport in view.split.viewports:
		assert_eq(vp.msaa_3d, preset.msaa_3d, vp.name)
		assert_eq(vp.scaling_3d_scale, preset.render_scale, vp.name)
		assert_true(vp.is_in_group(GraphicsApplier.VIEWPORTS_GROUP), "%s follows Settings" % vp.name)
	var low: GraphicsPreset = GraphicsPreset.load_id(&"low")
	GraphicsApplier.apply_to_group(low, get_tree())
	for vp: SubViewport in view.split.viewports:
		assert_eq(vp.scaling_3d_scale, low.render_scale, "%s took the new preset" % vp.name)
	GraphicsApplier.apply_to_group(preset, get_tree())


func test_each_camera_decides_the_shrine_s_underside() -> void:
	_start(_versus())
	var fake: FakeArena = FakeArena.new()
	view.set_arena(fake, &"fake")
	view.render(1.0 / 60.0)
	assert_true(fake.culled.has(view.cameras[0]), "player 1's camera")
	assert_true(fake.culled.has(view.cameras[1]), "player 2's camera")


func test_one_listener_hears_3d_sound_from_between_the_fighters() -> void:
	_start(_versus())
	for vp: SubViewport in view.split.viewports:
		assert_false(vp.audio_listener_enable_3d, "%s doesn't listen" % vp.name)
	audio.follow_camera()
	assert_true(audio.listener.is_current(), "MatchAudio's listener is the one")
	var a: Vector3 = host.display_position(0)
	var b: Vector3 = host.display_position(1)
	var at: Vector3 = audio.listener.global_position
	assert_almost_eq(_flat(at).distance_to(_flat(a)), _flat(at).distance_to(_flat(b)), 0.01, "as far from each fighter")
	# side-on: player 1's fighter on the listener's left, player 2's on its right
	var local_a: Vector3 = audio.listener.global_transform.affine_inverse() * a
	var local_b: Vector3 = audio.listener.global_transform.affine_inverse() * b
	assert_lt(local_a.x, 0.0, "player 1 to the left")
	assert_gt(local_b.x, 0.0, "player 2 to the right")
	assert_almost_eq(local_a.z, local_b.z, 0.01, "both straight across")


func test_outside_versus_the_listener_follows_the_camera() -> void:
	_start(_mode(MatchConfig.DUEL))
	audio.follow_camera()
	assert_true(audio.listener.global_transform.is_equal_approx(view.camera.global_transform))


func test_the_versus_listener_sits_between_the_fighters() -> void:
	var xf: Transform3D = MatchAudio.versus_listener(Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 1.25)
	assert_almost_eq(xf.origin.x, 0.0, 0.0001, "midway along")
	assert_almost_eq(xf.origin.y, 1.25, 0.0001, "at chest height")
	assert_almost_eq(xf.basis.x.normalized().dot(Vector3.RIGHT), 1.0, 0.0001, "its right toward player 2")
