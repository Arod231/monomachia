extends GutTest
## The arena screenshot rig (tools/shot_scenes/arena_shot.gd), headless: the
## arena put in by id with the real fighters at its spawns, each view's
## camera, the top-down debug overlay and the chosen preset.

const ArenaShot := preload("res://tools/shot_scenes/arena_shot.gd")

var _services: Node


func before_all() -> void:
	_services = get_tree().root.get_node("GameServices")


## The rig applies its preset to the renderer and the viewport: put back the
## one the run started with.
func after_all() -> void:
	GraphicsApplier.apply(_services.call("graphics_preset"), null, get_viewport())


func _rig(view: ArenaShot.View, preset: StringName = &"") -> ArenaShot:
	var rig: ArenaShot = ArenaShot.new()
	rig.arena_id = ArenaScenes.STANDIN
	rig.view = view
	rig.preset_id = preset
	add_child_autofree(rig)
	return rig


func _match_view(rig: ArenaShot) -> MatchView:
	return rig.host.get_node("View") as MatchView


func test_the_real_fighters_stand_on_the_arenas_spawns() -> void:
	var rig: ArenaShot = _rig(ArenaShot.View.GAMEPLAY)
	var view: MatchView = _match_view(rig)
	assert_eq(view.arena.scene_file_path, ArenaScenes.STANDIN_SCENE)
	assert_eq(view.fighters.size(), 2)
	for side: int in 2:
		var spawn: Node3D = view.arena.get_node("Spawn%d" % side)
		assert_almost_eq(view.fighters[side].position, spawn.position, Vector3.ONE * 1e-4, "fighter %d on its spawn" % side)
		assert_not_null(view.fighters[side].model, "fighter %d is a real fighter" % side)
	assert_false(rig.host.get_node("Hud").visible, "no HUD over the arena")


func test_the_gameplay_watch_and_menu_views_are_the_camera_rigs() -> void:
	var modes: Dictionary = {
		ArenaShot.View.GAMEPLAY: CameraRig.Mode.FOLLOW,
		ArenaShot.View.WATCH: CameraRig.Mode.WATCH,
		ArenaShot.View.MENU: CameraRig.Mode.MENU,
	}
	for shot_view: ArenaShot.View in modes:
		var rig: ArenaShot = _rig(shot_view)
		var camera: CameraRig = _match_view(rig).camera
		assert_eq(camera.mode, modes[shot_view])
		assert_true(camera.current, "the match's own camera")
		assert_null(rig.shot_camera, "no camera of the rig's own")
		assert_almost_eq(camera.global_position, camera.rig_position, Vector3.ONE * 1e-4, "snapped to its target")


func test_the_menu_view_stands_menu_time_into_the_orbit() -> void:
	var rig: ArenaShot = _rig(ArenaShot.View.MENU)
	var camera: CameraRig = _match_view(rig).camera
	var target: Dictionary = camera.menu_target(rig.menu_time)
	assert_almost_eq(camera.global_position, target["pos"] as Vector3, Vector3.ONE * 1e-4)


func test_the_establishing_view_looks_at_the_arena_from_beyond_its_edge_and_below_its_floor() -> void:
	var rig: ArenaShot = _rig(ArenaShot.View.ESTABLISHING)
	var camera: Camera3D = rig.shot_camera
	assert_not_null(camera)
	assert_true(camera.current)
	var at: Vector3 = camera.global_position
	assert_almost_eq(Vector2(at.x, at.z).length(), rig.establishing_distance, 1e-3)
	assert_lt(at.y, 0.0, "below the floor")
	assert_gte(camera.far, _match_view(rig).camera.far, "sees as far as the match camera")


func test_the_top_down_view_rings_the_rules_wall_and_marks_spawns_and_gates() -> void:
	var rig: ArenaShot = _rig(ArenaShot.View.TOP_DOWN)
	assert_eq(rig.shot_camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_true(rig.shot_camera.current)
	var overlay: Node3D = rig.get_node("DebugOverlay")
	var wall: AABB = (overlay.get_node("RulesWall") as MeshInstance3D).get_aabb()
	assert_almost_eq(wall.size.x, 2.0 * SimConst.ARENA_RADIUS, 0.01, "the rules' wall")
	var limit: AABB = (overlay.get_node("CentreLimit") as MeshInstance3D).get_aabb()
	assert_almost_eq(limit.size.x, 2.0 * (SimConst.ARENA_RADIUS - SimConst.FIGHTER_RADIUS), 0.01, "where fighters' centres stop")
	assert_null(overlay.get_node_or_null("WallFace"), "the stand-in has no arena data to draw")
	var marks: AABB = (overlay.get_node("Markers") as MeshInstance3D).get_aabb()
	var gate_z: float = absf((_match_view(rig).arena.get_node("Gate1") as Node3D).position.z)
	assert_almost_eq(marks.end.z, gate_z + ArenaShot.GATE_MARK_RADIUS, 0.01, "a ring on each gate")
	assert_almost_eq(marks.position.z, -gate_z - ArenaShot.GATE_MARK_RADIUS, 0.01)


func test_the_chosen_preset_reaches_the_arena() -> void:
	var low: GraphicsPreset = GraphicsPreset.load_id(&"low")
	var rig: ArenaShot = _rig(ArenaShot.View.GAMEPLAY, &"low")
	var ink: InkWashPass = _match_view(rig).arena.find_children("*", "InkWashPass", true, false)[0]
	assert_eq(ink.quality, low.post_quality)
	assert_eq(rig.preset.id, &"low")


func test_without_a_preset_it_shoots_the_saved_one() -> void:
	var rig: ArenaShot = _rig(ArenaShot.View.GAMEPLAY)
	assert_eq(rig.preset.id, (_services.call("graphics_preset") as GraphicsPreset).id)


# ------------------------------------------------------------------ bench

func _bench_rig(entries: Array[String], passes: int = 1, frames: int = 3) -> ArenaShot:
	var rig: ArenaShot = ArenaShot.new()
	rig.arena_id = ArenaScenes.STANDIN
	rig.bench = PackedStringArray(entries)
	rig.bench_passes = passes
	rig.bench_settle = 1
	rig.bench_frames = frames
	add_child_autofree(rig)
	return rig


func _positions(host: MatchHost) -> Array[Vector3]:
	return [host.display_position(0), host.display_position(1)]


func test_the_command_line_sets_up_a_bench() -> void:
	var rig: ArenaShot = ArenaShot.new()
	rig.apply_args(PackedStringArray([
		"--preset=low", "--bench=low;high:outline_props=false", "--bench-passes=2",
		"--bench-frames=120", "--bench-res=1600x900",
	]))
	assert_eq(rig.preset_id, &"low")
	assert_eq(rig.bench, PackedStringArray(["low", "high:outline_props=false"]))
	assert_eq(rig.bench_passes, 2)
	assert_eq(rig.bench_frames, 120)
	assert_eq(rig.bench_resolution, Vector2i(1600, 900))
	rig.free()


func test_the_command_line_backs_a_fighter_against_the_wall() -> void:
	var rig: ArenaShot = ArenaShot.new()
	rig.apply_args(PackedStringArray(["--wall=40"]))
	assert_eq(rig.wall_angle_deg, 40.0)
	rig.apply_args(PackedStringArray(["--wall=north"]))
	assert_push_error("--wall= takes an angle in degrees")
	assert_eq(rig.wall_angle_deg, 40.0, "left as it was")
	rig.free()


func test_at_the_wall_side_0_is_backed_against_it_facing_side_1() -> void:
	var rig: ArenaShot = ArenaShot.new()
	rig.arena_id = ArenaScenes.STANDIN
	rig.wall_angle_deg = 90.0
	add_child_autofree(rig)
	var r: float = SimConst.ARENA_RADIUS - SimConst.FIGHTER_RADIUS
	var f0: Fighter = rig.host.fighter(0)
	var f1: Fighter = rig.host.fighter(1)
	assert_almost_eq(Vector2(f0.pos.x, f0.pos.z), Vector2(r, 0.0), Vector2.ONE * 1e-6, "side 0 at the wall at 90 degrees (+X)")
	assert_almost_eq(Vector2(f1.pos.x, f1.pos.z), Vector2(r - rig.wall_separation, 0.0), Vector2.ONE * 1e-6, "side 1 further in")
	assert_almost_eq(f0.yaw, SimMath.yaw_to(f0.pos, f1.pos), 1e-6, "facing each other")
	assert_almost_eq(f1.yaw, SimMath.yaw_to(f1.pos, f0.pos), 1e-6)


func test_bad_bench_counts_and_sizes_on_the_command_line_are_reported() -> void:
	var rig: ArenaShot = ArenaShot.new()
	rig.apply_args(PackedStringArray(["--bench-passes=0", "--bench-frames=lots", "--bench-res=1080p"]))
	assert_push_error("--bench-passes=0 takes a whole number")
	assert_push_error("--bench-frames=lots takes a whole number")
	assert_push_error("--bench-res= takes <width>x<height>")
	assert_eq(rig.bench_passes, 3, "left as it was")
	assert_eq(rig.bench_frames, 300)
	assert_eq(rig.bench_resolution, Vector2i(1920, 1080))
	rig.free()


func test_a_bench_entry_is_a_preset_with_overrides() -> void:
	var entry: Dictionary = ArenaShot.bench_entry("high:outline_props=false,particle_ratio=0.5,shadow_atlas_size=2048")
	assert_eq(entry["error"], "")
	var p: GraphicsPreset = entry["preset"]
	assert_eq(p.id, &"high")
	assert_false(p.outline_props)
	assert_almost_eq(p.particle_ratio, 0.5, 1e-6)
	assert_eq(p.shadow_atlas_size, 2048)
	assert_true(GraphicsPreset.load_id(&"high").outline_props, "the saved preset is left as it is")
	assert_eq(entry["label"], "High: outline_props=false, particle_ratio=0.5, shadow_atlas_size=2048")
	assert_eq(ArenaShot.bench_entry("medium")["label"], "Medium")


func test_a_bench_entry_can_hide_parts_of_the_match() -> void:
	var entry: Dictionary = ArenaShot.bench_entry("low:hide=Arena/World,hide=Fighter1")
	assert_eq(entry["error"], "")
	assert_eq(entry["hide"], [^"Arena/World", ^"Fighter1"])


func test_a_bad_bench_entry_says_what_is_wrong() -> void:
	assert_string_contains(ArenaShot.bench_entry("extreme")["error"], "no preset 'extreme'")
	assert_string_contains(ArenaShot.bench_entry("high:bloom=true")["error"], "no preset setting 'bloom'")
	assert_string_contains(ArenaShot.bench_entry("high:outline_props=maybe")["error"], "outline_props")
	assert_string_contains(ArenaShot.bench_entry("high:shadow_atlas_size")["error"], "shadow_atlas_size")


func test_the_bench_interleaves_its_passes() -> void:
	var rig: ArenaShot = ArenaShot.new()
	rig.bench = PackedStringArray(["low", "high"])
	rig.bench_passes = 3
	assert_eq(rig.bench_queue(), PackedStringArray(["low", "high", "low", "high", "low", "high"]))
	rig.free()


func test_frame_times_average_and_95th_percentile() -> void:
	var times := PackedFloat64Array()
	for i: int in range(100, 0, -1):
		times.append(float(i))
	assert_almost_eq(ArenaShot.average(times), 50.5, 1e-9)
	assert_almost_eq(ArenaShot.percentile_95(times), 95.0, 1e-9, "the nearest rank: 95 of 100 frames take this long or less")
	assert_almost_eq(ArenaShot.percentile_95(PackedFloat64Array([4.0, 2.0])), 4.0, 1e-9)


func test_each_bench_entry_replays_the_fight_from_the_same_moment() -> void:
	var rig: ArenaShot = _bench_rig(["low", "high"])
	var host: MatchHost = rig.host
	assert_eq(host.sim_match.phase, &"fight", "past the round's intro")
	assert_eq(host.step_count, Match.INTRO_FRAMES)
	var start: Array[Vector3] = _positions(host)
	assert_eq(rig.preset.id, &"low")
	host.step(40)
	assert_ne(_positions(host), start, "the fighters moved")
	rig.start_bench_entry("high")
	assert_eq(host.step_count, Match.INTRO_FRAMES)
	assert_eq(_positions(host), start, "back where the last entry started")
	assert_eq(rig.preset.id, &"high")
	var camera: CameraRig = _match_view(rig).camera
	assert_eq(camera.mode, CameraRig.Mode.FOLLOW, "still the view's camera")
	var ink: InkWashPass = _match_view(rig).arena.find_children("*", "InkWashPass", true, false)[0]
	assert_eq(ink.quality, GraphicsPreset.load_id(&"high").post_quality, "the entry's preset reaches the arena")


func test_an_entry_hides_what_it_names_and_the_next_shows_it_again() -> void:
	var rig: ArenaShot = _bench_rig(["low:hide=Fighter1", "low"])
	var fighter: Node3D = _match_view(rig).get_node("Fighter1")
	assert_false(fighter.visible)
	rig.start_bench_entry("low")
	assert_true(fighter.visible)
	rig.start_bench_entry("low:hide=Arena/Nothing")
	assert_push_error("no node 'Arena/Nothing'")


func test_entries_that_cannot_run_are_reported_and_dropped_before_timing() -> void:
	var rig: ArenaShot = _bench_rig(["extreme", "low", "low:hide=Nothing", "low"], 2)
	assert_push_error("no preset 'extreme'")
	assert_push_error("no node 'Nothing'")
	assert_push_error("'low': it is listed twice")
	assert_eq(rig.bench, PackedStringArray(["low"]))
	assert_eq(rig.bench_queue(), PackedStringArray(["low", "low"]))


func test_the_bench_plays_the_match_with_its_hud_and_names_the_entry() -> void:
	var rig: ArenaShot = _bench_rig(["medium"], 1, 30)
	var hud: CanvasLayer = rig.host.get_node("Hud")
	assert_true(hud.visible, "the HUD, as a match draws it")
	assert_true(_match_view(rig).is_processing(), "the camera follows the fight")
	assert_eq((rig.get_node("Bench/Entry") as Label).text, "Medium")
	await wait_process_frames(1)
	var steps: int = rig.host.step_count
	var frames: int = Engine.get_process_frames()
	assert_gt(steps, Match.INTRO_FRAMES, "the fight plays")
	await wait_process_frames(3)
	assert_eq(rig.host.step_count - steps, Engine.get_process_frames() - frames, "one rules step a frame")


func test_the_bench_times_every_entry_in_every_pass_and_reports_them() -> void:
	var rig: ArenaShot = _bench_rig(["low", "high"], 2)
	assert_false(rig.shot_ready(), "busy timing")
	var guard: int = 0
	while not rig.shot_ready() and guard < 100:
		await wait_process_frames(1)
		guard += 1
	assert_true(rig.shot_ready(), "done")
	for key: String in ["low", "high"]:
		var passes: Array = rig.bench_results[key]
		assert_eq(passes.size(), 2, "%s timed in both passes" % key)
		for r: Dictionary in passes:
			assert_has(r, "frame_ms")
			assert_has(r, "p95_ms")
			assert_has(r, "gpu_ms")
			assert_has(r, "cpu_ms")
	var lines: PackedStringArray = rig.bench_report()
	assert_eq(lines.size(), 3, "a header and one line per entry")
	assert_string_contains(lines[1], "low")
	assert_string_contains(lines[2], "high")
	assert_string_contains(lines[2], "fps")


func test_without_a_bench_the_shot_is_the_screen() -> void:
	var rig: ArenaShot = _rig(ArenaShot.View.GAMEPLAY)
	assert_null(rig.shot_image())
	assert_null(rig.get_node_or_null("Bench"))
	assert_false(rig.host.get_node("Hud").visible)


func test_the_sheet_puts_the_entries_side_by_side_in_order() -> void:
	var colors: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE]
	var panels: Array[Image] = []
	for c: Color in colors:
		var img: Image = Image.create(40, 20, false, Image.FORMAT_RGBA8)
		img.fill(c)
		panels.append(img)
	var sheet: Image = ArenaShot.sheet(panels, 0.5)
	assert_eq(sheet.get_size(), Vector2i(60, 10))
	for i: int in 3:
		assert_eq(sheet.get_pixel(i * 20 + 10, 5), colors[i], "panel %d" % i)
