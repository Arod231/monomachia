extends GutTest
## The match's sound (match_host.tscn's Audio): every rules event's cues in a
## played match and on the results screen, silence from the duel behind the
## menus, sound held through a pause, and nothing left playing after a quit;
## the arena's ambience bed under played matches.
## Headless runs use the dummy audio driver, so these tests follow what the
## sound player is asked to play.

var host: MatchHost
var audio: MatchAudio


func before_each() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	audio = host.get_node("Audio")
	audio.player.auto_run = false


## Computer against computer on the stand-in arena.
func _cpu(mode: StringName = MatchConfig.DUEL, seed_value: int = 7) -> MatchConfig:
	return MatchConfig.make(
		mode,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"hard"),
		seed_value,
		ArenaScenes.STANDIN,
	)


## Every cue the match's sound player starts, with its bus; without the
## footsteps, which come from the fighters' movement rather than events, when
## footsteps is false.
func _record(footsteps: bool = true) -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	audio.player.played.connect(func(cue: StringName, voice: Node) -> void:
		if footsteps or cue != &"footstep":
			log.append({"cue": cue, "bus": voice.get("bus")}))
	return log


func _cues(log: Array[Dictionary]) -> Array[StringName]:
	var names: Array[StringName] = []
	for entry: Dictionary in log:
		names.append(entry["cue"])
	return names


func _count(log: Array[Dictionary], cue_name: StringName) -> int:
	return _cues(log).count(cue_name)


func _descendants(node: Node) -> int:
	var n := node.get_child_count()
	for child: Node in node.get_children():
		n += _descendants(child)
	return n


func test_a_played_duel_plays_its_events_cues_in_order_on_their_buses() -> void:
	var events: Array[Dictionary] = []
	host.sim_event.connect(func(e: Dictionary) -> void: events.append(e))
	var log := _record(false)
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 60 * 20)
	var expected: Array[StringName] = []
	var types := {}
	for e: Dictionary in events:
		types[StringName(e["t"])] = true
		for cue: Dictionary in SoundBank.cues_for(e):
			if float(cue["delay"]) == 0.0:
				expected.append(cue["cue"])
	assert_true(types.has(&"roundStart") and types.has(&"swing"), "the round was called and swung in")
	assert_true(types.has(&"hit") or types.has(&"block"), "and something landed")
	assert_eq(_cues(log), expected, "every event's cues, in the world's order")
	for entry: Dictionary in log:
		assert_eq(entry["bus"], SoundBank.CUES[entry["cue"]]["bus"], "%s on its bus" % entry["cue"])


func test_watch_plays_too() -> void:
	var log := _record()
	host.start(_cpu(MatchConfig.WATCH))
	assert_eq(_cues(log), [&"round_roll"] as Array[StringName])


func test_the_duel_behind_the_menus_is_silent() -> void:
	var log := _record()
	var cfg := MatchConfig.attract(5)
	cfg.arena_id = ArenaScenes.STANDIN
	host.start(cfg, true)
	var restarts: Array[int] = []
	host.match_started.connect(func(_c: MatchConfig) -> void: restarts.append(host.step_count))
	while restarts.is_empty() and host.step_count < 60 * 60 * 12:
		host.step(10)
	assert_eq(restarts.size(), 1, "a whole attract duel and its restart")
	host.step(Match.INTRO_FRAMES + 60)
	audio.player.advance(5.0)
	assert_eq(log.size(), 0)
	assert_true(audio.player.is_quiet())


func test_a_pause_holds_the_round_gong() -> void:
	var log := _record()
	host.start(_cpu())
	assert_eq(_cues(log), [&"round_roll"] as Array[StringName])
	host.pause()
	assert_true(audio.player.is_held())
	audio.player.advance(3.0)
	assert_eq(_count(log, &"gong"), 0, "no gong over the pause menu")
	host.resume()
	assert_false(audio.player.is_held())
	audio.player.advance(1.4)
	assert_eq(_count(log, &"gong"), 1, "it rings once the match resumes")


func test_quitting_leaves_nothing_playing() -> void:
	var log := _record()
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 60 * 5)
	assert_false(audio.player.is_quiet())
	var played := log.size()
	assert_true(audio.ambience.is_playing())
	host.stop()
	assert_true(audio.player.is_quiet(), "no voice playing, nothing waiting")
	assert_false(audio.ambience.is_playing(), "the ambience fades out")
	audio.player.advance(3.0)
	assert_eq(log.size(), played)


func test_a_new_match_drops_the_last_one_s_sound() -> void:
	var log := _record()
	host.start(_cpu())
	host.step(30)
	host.start(_cpu(MatchConfig.DUEL, 8))
	audio.player.advance(1.4)
	assert_eq(_count(log, &"round_roll"), 2)
	assert_eq(_count(log, &"gong"), 1, "only the new round's gong rings")


func test_the_results_screen_still_plays() -> void:
	var log := _record()
	host.start(_cpu(MatchConfig.DUEL, 19))
	while not host.is_finished() and host.step_count < 60 * 60 * 12:
		host.step(10)
	assert_true(host.is_finished())
	assert_true(audio.ambience.is_playing(), "the arena's ambience plays on")
	var played := log.size()
	host.sim_event.emit({"t": &"weaponBounce", "owner": 0, "speed": 9.0, "pos": {"x": 1.0, "y": 0.0, "z": 0.0}})
	assert_eq(_cues(log).slice(played), [&"weapon_bounce", &"weapon_clatter"] as Array[StringName])


func test_rematches_and_restarts_leave_no_stray_nodes() -> void:
	host.start(_cpu())
	var baseline := _descendants(audio)
	assert_gt(baseline, 1, "the sound player and its voices")
	for k: int in 3:
		host.step(Match.INTRO_FRAMES + 120)
		if k == 1:
			var cfg := MatchConfig.attract(k + 5)
			cfg.arena_id = ArenaScenes.STANDIN
			host.start(cfg, true)
		else:
			host.start(_cpu(MatchConfig.DUEL, 7 + k))
		await get_tree().process_frame
		assert_eq(_descendants(audio), baseline, "match %d: nothing left behind" % k)


# ------------------------------------------------------------------ the arena's ambience

## An arena's data naming [param cue] as its ambience, read by name.
func _fake_def(cue: StringName) -> Resource:
	var script := GDScript.new()
	script.source_code = "extends Resource
var ambience_id: StringName = &\"%s\"
" % cue
	script.reload()
	return script.new()


func test_a_played_duel_fades_the_arena_s_ambience_in_on_the_ambience_bus() -> void:
	host.start(_cpu())
	var bed := audio.ambience
	assert_true(bed.is_playing())
	assert_eq(bed.player.stream.resource_path, SoundBank.paths_for(MatchAudio.DEFAULT_AMBIENCE)[0],
		"the stand-in names none: the shrine's bed")
	assert_eq(bed.player.bus, &"Ambience")
	assert_eq(bed.volume_db, float(SoundBank.CUES[MatchAudio.DEFAULT_AMBIENCE]["volume_db"]))
	assert_true(await wait_until(bed.is_audible, 2.0), "it rises once mixed")


func test_the_duel_behind_the_menus_has_no_ambience() -> void:
	var cfg := MatchConfig.attract(5)
	cfg.arena_id = ArenaScenes.STANDIN
	host.start(cfg, true)
	assert_false(audio.ambience.is_playing())
	host.start(_cpu())
	host.start(cfg, true)
	assert_false(audio.ambience.is_playing(), "the played match's bed fades out")


func test_the_ambience_plays_on_through_a_pause() -> void:
	host.start(_cpu())
	host.pause()
	assert_true(audio.ambience.is_playing())
	assert_false(audio.ambience.player.stream_paused)
	host.resume()
	assert_true(audio.ambience.is_playing())


func test_a_rematch_keeps_the_ambience_going() -> void:
	host.start(_cpu())
	assert_true(await wait_until(audio.ambience.is_audible, 2.0))
	var position := audio.ambience.player.get_playback_position()
	host.start(_cpu(MatchConfig.DUEL, 8))
	assert_true(audio.ambience.is_audible(), "not restarted from silence")
	assert_gte(audio.ambience.player.get_playback_position(), position)


func test_an_arena_plays_the_ambience_its_data_names() -> void:
	assert_eq(MatchAudio.ambience_cue(ArenaScenes.def(ArenaScenes.MOONLIT_SHRINE)), &"ambience_shrine", "the shrine's")
	assert_eq(MatchAudio.ambience_cue(_fake_def(&"gong")), &"gong")
	assert_eq(MatchAudio.ambience_cue(_fake_def(&"")), MatchAudio.DEFAULT_AMBIENCE, "an arena that names none")
	assert_eq(MatchAudio.ambience_cue(null), MatchAudio.DEFAULT_AMBIENCE, "no data (the stand-in)")
	host.start(_cpu())
	audio.start_ambience(MatchAudio.ambience_cue(_fake_def(&"gong")))
	assert_has(SoundBank.paths_for(&"gong"), audio.ambience.player.stream.resource_path, "a fake arena's cue plays")
	assert_eq(audio.ambience.player.bus, SoundBank.CUES[&"gong"]["bus"], "on its cue's bus")


func test_an_ambience_the_bank_lacks_is_an_error() -> void:
	host.start(_cpu())
	audio.start_ambience(&"no_such_bed")
	assert_push_error("no_such_bed")
	assert_true(audio.ambience.is_playing(), "the bed playing carries on")


# ------------------------------------------------------------------ in 3D

## Every cue started, with where it plays (null when flat); footsteps as for
## _record().
func _record_places(footsteps: bool = true) -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	audio.player.played.connect(func(cue: StringName, voice: Node) -> void:
		if footsteps or cue != &"footstep":
			log.append({"cue": cue, "at": (voice as Node3D).global_position if voice is Node3D else null}))
	return log


func _chest(i: int) -> Vector3:
	var f: Fighter = host.fighter(i)
	return Vector3(f.pos.x, f.pos.y + audio.chest_height, f.pos.z)


func _at(log: Array[Dictionary], cue_name: StringName) -> Variant:
	for entry: Dictionary in log:
		if entry["cue"] == cue_name:
			return entry["at"]
	fail_test("%s never played" % cue_name)
	return null


func _fought() -> void:
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 30)


func test_a_hit_plays_from_a_3d_voice_at_its_contact_point() -> void:
	var log := _record_places()
	_fought()
	host.sim_event.emit({"t": &"hit", "attacker": 1, "target": 0, "pos": {"x": 0.4, "y": 1.3, "z": -0.8},
		"heavy": false, "sound": &"blade"})
	assert_almost_eq(_at(log, &"hit_blade"), Vector3(0.4, 1.3, -0.8), Vector3.ONE * 1e-4)


func test_a_dodge_plays_at_the_dodging_fighter() -> void:
	var log := _record_places()
	_fought()
	host.sim_event.emit({"t": &"dodge", "f": 1, "back": false})
	assert_almost_eq(_at(log, &"dodge_swish"), _chest(1), Vector3.ONE * 1e-4)
	assert_almost_eq(_at(log, &"dodge_cloth"), _chest(1), Vector3.ONE * 1e-4)


func test_the_ko_calls_stay_flat_while_the_body_fall_is_placed() -> void:
	var log := _record_places()
	_fought()
	host.sim_event.emit({"t": &"ko", "loser": 1, "winner": 0})
	audio.player.advance(0.7)
	for call: StringName in [&"taiko_heavy", &"gong", &"boom"]:
		assert_null(_at(log, call), "%s is flat" % call)
	assert_almost_eq(_at(log, &"body_fall"), _chest(1), Vector3.ONE * 1e-4, "the body falls where the loser is")


func test_lightning_sounds_where_it_strikes() -> void:
	var log := _record_places()
	_fought()
	host.sim_event.emit({"t": &"ultLightning", "f": 0, "from": {"x": 0.0, "y": 9.0, "z": 0.0},
		"to": {"x": 2.0, "y": 0.0, "z": -3.0}})
	assert_almost_eq(_at(log, &"lightning"), Vector3(2.0, 0.0, -3.0), Vector3.ONE * 1e-4)


func test_in_a_played_duel_every_placed_cue_plays_where_its_event_happened() -> void:
	var played := _record_places(false)
	var expected: Array[Dictionary] = []
	host.sim_event.connect(func(e: Dictionary) -> void:
		var at: Variant = null
		if e.has("pos"):
			at = Vector3(e["pos"]["x"], e["pos"]["y"], e["pos"]["z"])
		else:
			for key: String in ["f", "attacker", "parrier", "victim", "loser", "owner", "by"]:
				if e.has(key):
					at = _chest(int(e[key]))
					break
		for cue: Dictionary in SoundBank.cues_for(e):
			if float(cue["delay"]) == 0.0:
				var spatial: bool = SoundBank.CUES[cue["cue"]]["spatial"]
				expected.append({"cue": cue["cue"], "at": at if spatial else null}))
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 60 * 20)
	assert_eq(played.size(), expected.size())
	var placed := 0
	for i: int in mini(played.size(), expected.size()):
		assert_eq(played[i]["cue"], expected[i]["cue"])
		if expected[i]["at"] == null:
			assert_null(played[i]["at"], "%s plays flat" % expected[i]["cue"])
		else:
			placed += 1
			assert_almost_eq(played[i]["at"], expected[i]["at"], Vector3.ONE * 1e-4, "%s placed" % expected[i]["cue"])
	assert_gt(placed, 20, "swings, hits and dodges are placed")


func test_the_opponent_s_sounds_come_from_the_opponent_s_side() -> void:
	var log := _record_places()
	_fought()
	var view: MatchView = host.get_node("View")
	for k: int in 30:
		view.render(1.0 / 60.0)
	audio.follow_camera()
	host.sim_event.emit({"t": &"swing", "f": 0, "attack": &"k_l1", "heavy": false, "weapon": &"katana"})
	host.sim_event.emit({"t": &"swing", "f": 1, "attack": &"g_l1", "heavy": false, "weapon": &"greatsword"})
	var to_listener: Transform3D = audio.listener.global_transform.affine_inverse()
	var mine: Vector3 = to_listener * (_at(log, &"whoosh_light") as Vector3)
	var theirs: Vector3 = to_listener * (_at(log, &"whoosh_colossal") as Vector3)
	assert_lt(mine.x, 0.0, "the camera is over the player's right shoulder: the player is on the left")
	assert_lt(theirs.z, mine.z, "the opponent is further ahead")
	assert_gt(theirs.x, mine.x, "and to the right of the player")


func test_the_listener_is_current_and_follows_the_camera() -> void:
	_fought()
	var view: MatchView = host.get_node("View")
	for k: int in 30:
		view.render(1.0 / 60.0)
	assert_true(audio.listener.is_current())
	audio._process(1.0 / 60.0)
	assert_eq(audio.listener.global_transform, view.camera.global_transform)


func test_the_match_s_listener_takes_over_from_another() -> void:
	var other := AudioListener3D.new()
	add_child_autofree(other)
	other.make_current()
	var second: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	second.auto_run = false
	second.use_services = false
	add_child_autofree(second)
	var second_audio: MatchAudio = second.get_node("Audio")
	assert_true(second_audio.listener.is_current())
	assert_false(other.is_current())


# ------------------------------------------------------------------ footsteps

func test_a_foot_down_plays_a_footstep_there() -> void:
	var log := _record_places()
	audio.foot_down(Vector3(1.0, 0.0, -2.0))
	assert_eq(_cues(log), [&"footstep"] as Array[StringName])
	assert_almost_eq(log[0]["at"], Vector3(1.0, 0.0, -2.0), Vector3.ONE * 1e-4)


func test_fighters_moving_in_a_played_duel_step_at_their_feet() -> void:
	var steps: Array[Dictionary] = []
	audio.player.played.connect(func(cue: StringName, voice: Node) -> void:
		if cue != &"footstep":
			return
		var feet: Array[Vector3] = []
		for i: int in 2:
			var f: Fighter = host.fighter(i)
			feet.append(Vector3(f.pos.x, f.pos.y, f.pos.z))
		steps.append({"at": (voice as Node3D).global_position, "feet": feet, "bus": voice.get("bus"),
			"path": (voice.get("stream") as AudioStream).resource_path}))
	host.start(_cpu())
	# stepped without being drawn: the stride count steps for both fighters,
	# the Katana's guard included
	host.step(Match.INTRO_FRAMES + 60 * 20)
	assert_gt(steps.size(), 10, "the fighters close in and circle")
	for i: int in 2:
		assert_true(steps.any(func(s: Dictionary) -> bool: return (s["at"] as Vector3).distance_to(s["feet"][i]) < 1e-4), "fighter %d steps" % i)
	for k: int in steps.size():
		var at: Vector3 = steps[k]["at"]
		var feet: Array[Vector3] = steps[k]["feet"]
		assert_true(at.distance_to(feet[0]) < 1e-4 or at.distance_to(feet[1]) < 1e-4, "step %d is at a fighter's feet" % k)
		assert_eq(steps[k]["bus"], &"Foley")
		if k > 0:
			assert_ne(steps[k]["path"], steps[k - 1]["path"], "step %d repeats the last variation" % k)


func test_a_new_match_starts_every_stride_afresh() -> void:
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 60 * 3)
	host.start(_cpu(MatchConfig.DUEL, 8))
	for i: int in 2:
		assert_eq(audio.footsteps._travel[i], 0.0, "fighter %d's stride" % i)


## A footfall the view reports (the guard shuffle's) plays a footstep where
## the foot came down; the duel behind the menus stays silent.
func test_a_footfall_from_the_view_plays_a_footstep_there() -> void:
	var view: MatchView = host.get_node("View")
	host.start(_cpu())
	var log := _record_places()
	view.footfall.emit(0, Vector3(0.4, 0.0, -1.2))
	assert_eq(_cues(log), [&"footstep"] as Array[StringName])
	assert_almost_eq(log[0]["at"], Vector3(0.4, 0.0, -1.2), Vector3.ONE * 1e-4)
	host.start(_cpu(), true)
	view.footfall.emit(0, Vector3(0.4, 0.0, -1.2))
	assert_eq(log.size(), 1, "nothing behind the menus")


## Walking in its guard, the Katana fighter's footsteps fall where the guard
## shuffle puts its feet down, and the stride count makes none for it.
func test_a_guard_walk_steps_where_the_shuffle_s_feet_land() -> void:
	var fake := FakeDeviceState.new()
	host.input = InputDevices.new(fake)
	host.start(MatchConfig.default_duel())
	var view: MatchView = host.get_node("View")
	host.step(Match.INTRO_FRAMES + 1)
	view.render(1.0 / 60.0)
	var footfalls: Array[Vector3] = []
	view.footfall.connect(func(side: int, at: Vector3) -> void:
		if side == 0:
			footfalls.append(at))
	# the footsteps that aren't the opponent's: its own fall at its feet
	var mine: Array[Vector3] = []
	audio.player.played.connect(func(cue: StringName, voice: Node) -> void:
		if cue != &"footstep":
			return
		var at: Vector3 = (voice as Node3D).global_position
		var other: Fighter = host.fighter(1)
		if at.distance_to(Vector3(other.pos.x, other.pos.y, other.pos.z)) > 1e-4:
			mine.append(at))
	# block and strafe left, round the opponent
	fake.press_key(KEY_L)
	fake.press_key(KEY_A)
	for i: int in 90:
		host.step(1)
		view.render(1.0 / 60.0)
	fake.release_key(KEY_A)
	for i: int in 20:
		host.step(1)
		view.render(1.0 / 60.0)
	assert_true(view.shuffles(0), "the guard's legs")
	gut.p("%d footfalls" % footfalls.size())
	assert_gt(footfalls.size(), 4, "the feet step")
	assert_eq(mine.size(), footfalls.size(), "a footstep for each footfall, and none from the stride count")
	for k: int in mini(mine.size(), footfalls.size()):
		assert_almost_eq(mine[k], footfalls[k], Vector3.ONE * 1e-4, "footstep %d where the foot came down" % k)
