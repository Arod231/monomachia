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
	# every cue the bank asks for, a light swing's one-in-three exhale too, so
	# the played cues can be checked one by one against the events
	audio.player.every_time = true


## Computer against computer on the stand-in arena.
func _cpu(mode: StringName = MatchConfig.DUEL, seed_value: int = 7) -> MatchConfig:
	return MatchConfig.make(
		mode,
		MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"hard"),
		seed_value,
		ArenaScenes.STANDIN,
	)


## A footfall's cues: the footstep and the Hunter's cloth and gear under it.
static func _footfall(cue: StringName) -> bool:
	return SoundBank.footfall_cues(&"hunter").has(cue)


## Every cue the match's sound player starts, with its bus; without the
## footsteps (and the cloth and gear under them), which come from the
## fighters' movement rather than events, when footsteps is false.
func _record(footsteps: bool = true) -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	audio.player.played.connect(func(cue: StringName, voice: Node) -> void:
		if footsteps or not _footfall(cue):
			log.append({"cue": cue, "bus": voice.get("bus")}))
	return log


## A deflect pair's own cue (task 136), played on its frame rather than
## with its parry.
static func _pair_cue(cue: StringName) -> bool:
	for direction: StringName in SoundBank.DEFLECT_SOUNDS:
		for half: StringName in [&"deflect", &"recoil"]:
			for c: Dictionary in SoundBank.deflect_pair_cues(direction, half):
				if c["cue"] == cue:
					return true
	return false


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
		for cue: Dictionary in SoundBank.cues_for(e, audio.cast()):
			if float(cue["delay"]) == 0.0:
				expected.append(cue["cue"])
	assert_true(types.has(&"roundStart") and types.has(&"swing"), "the round was called and swung in")
	assert_true(types.has(&"hit") or types.has(&"block"), "and something landed")
	# the deflect pairs' halves play on their own frames (task 136), apart
	# from their parry's cues
	var played: Array[StringName] = []
	played.assign(_cues(log).filter(func(c: StringName) -> bool: return not _pair_cue(c)))
	assert_eq(played, expected, "every event's cues, in the world's order")
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
	host.sim_event.emit({"t": &"weaponStuck", "owner": 0, "pos": {"x": 1.0, "y": 0.0, "z": 0.0}})
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
		if footsteps or not _footfall(cue):
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
	# a roll tumbles (authored-animation task 30); a backstep keeps the swish
	host.sim_event.emit({"t": &"dodge", "f": 1, "back": false})
	assert_almost_eq(_at(log, &"roll"), _chest(1), Vector3.ONE * 1e-4)
	host.sim_event.emit({"t": &"dodge", "f": 1, "back": true})
	assert_almost_eq(_at(log, &"dodge_swish"), _chest(1), Vector3.ONE * 1e-4)
	# fighter 1 is the Hunter, whose own coat takes the general cloth's place
	assert_almost_eq(_at(log, &"hunter_cloth_dodge"), _chest(1), Vector3.ONE * 1e-4)
	host.sim_event.emit({"t": &"dodge", "f": 0, "back": true})
	assert_almost_eq(_at(log, &"dodge_cloth"), _chest(0), Vector3.ONE * 1e-4)


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
		for cue: Dictionary in SoundBank.cues_for(e, audio.cast()):
			if float(cue["delay"]) == 0.0:
				var spatial: bool = SoundBank.CUES[cue["cue"]]["spatial"]
				expected.append({"cue": cue["cue"], "at": at if spatial else null}))
	host.start(_cpu())
	host.step(Match.INTRO_FRAMES + 60 * 20)
	# the deflect pairs' halves are placed on their own frames (task 136; see
	# test_a_parry_plays_its_deflect_pair_s_halves_on_their_frames)
	var kept: Array[Dictionary] = []
	kept.assign(played.filter(func(p: Dictionary) -> bool: return not _pair_cue(p["cue"])))
	gut.p("%d deflect pair cues in the duel" % (played.size() - kept.size()))
	assert_eq(kept.size(), expected.size())
	var placed := 0
	for i: int in mini(kept.size(), expected.size()):
		assert_eq(kept[i]["cue"], expected[i]["cue"])
		if expected[i]["at"] == null:
			assert_null(kept[i]["at"], "%s plays flat" % expected[i]["cue"])
		else:
			placed += 1
			assert_almost_eq(kept[i]["at"], expected[i]["at"], Vector3.ONE * 1e-4, "%s placed" % expected[i]["cue"])
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
	host.step(Match.INTRO_FRAMES + 60 * 30)
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


## A footfall the view reports (the clips' feet) plays a footstep where
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


## The Hunter's own cloth and gear (milestone-1 task 36): under the Hunter's
## footfalls, where the foot came down, and with the Hunter's swing; the
## Rogue steps and swings without them.
func test_the_hunter_s_cloth_and_gear_move_with_the_hunter() -> void:
	var view: MatchView = host.get_node("View")
	host.start(_cpu())
	var log := _record_places()
	view.footfall.emit(1, Vector3(0.4, 0.0, -1.2))
	assert_eq(_cues(log), SoundBank.footfall_cues(&"hunter"))
	for entry: Dictionary in log:
		assert_almost_eq(entry["at"], Vector3(0.4, 0.0, -1.2), Vector3.ONE * 1e-4, "%s at the foot" % entry["cue"])
	log.clear()
	view.footfall.emit(0, Vector3(0.4, 0.0, -1.2))
	assert_eq(_cues(log), [&"footstep"] as Array[StringName], "the Rogue's step")
	log.clear()
	host.sim_event.emit({"t": &"swing", "f": 1, "attack": &"k_l1", "heavy": false, "weapon": &"katana"})
	assert_eq(_cues(log), SoundBank.cues_for({"t": &"swing", "f": 1, "heavy": false, "weapon": &"katana"}, [&"rogue", &"hunter"]).map(
		func(c: Dictionary) -> StringName: return c["cue"]))
	assert_true(_cues(log).has(&"hunter_cloth_swing"), "the Hunter's sleeves snap with the swing")


## Walking in its guard, a drawn fighter's footsteps fall where its clips
## put its feet down (authored-animation task 29), and the stride count makes
## none for it.
func test_a_guard_walk_steps_where_the_clips_feet_land() -> void:
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
	# the footsteps that aren't the opponent's: nearer this fighter (each
	# fighter's fall at its own feet)
	var mine: Array[Vector3] = []
	audio.player.played.connect(func(cue: StringName, voice: Node) -> void:
		if cue != &"footstep":
			return
		var at: Vector3 = (voice as Node3D).global_position
		var me: Fighter = host.fighter(0)
		var other: Fighter = host.fighter(1)
		if at.distance_to(Vector3(me.pos.x, me.pos.y, me.pos.z)) < at.distance_to(Vector3(other.pos.x, other.pos.y, other.pos.z)):
			mine.append(at))
	# block and strafe left, round the opponent
	fake.press_key(KEY_L)
	fake.press_key(KEY_A)
	for i: int in 150:
		host.step(1)
		view.render(1.0 / 60.0)
	fake.release_key(KEY_A)
	for i: int in 20:
		host.step(1)
		view.render(1.0 / 60.0)
	assert_true(view.steps_from_clips(0), "the view keeps up")
	gut.p("%d footfalls" % footfalls.size())
	assert_gt(footfalls.size(), 4, "the feet step")
	assert_eq(mine.size(), footfalls.size(), "a footstep for each footfall, and none from the stride count")
	for k: int in mini(mine.size(), footfalls.size()):
		assert_almost_eq(mine[k], footfalls[k], Vector3.ONE * 1e-4, "footstep %d where the foot came down" % k)


## The deflect pairs' sounds (milestone-1 task 136): fighter 0's attack
## parried by fighter 1 as the world would leave them, the attacker recoiling
## and the parrier in its recovery, with the parry's event.
func _parried(move: StringName = &"k_l1", kind: StringName = &"parry", sweep: V3 = V3.make(0.0, 0.0, 1.0)) -> Dictionary:
	_fought()
	var attacker: Fighter = host.fighter(0)
	var parrier: Fighter = host.fighter(1)
	var contact := V3.make(0.2, 1.4, 0.0)
	attacker.keep_parry(move, 10, contact, sweep, attacker.yaw)
	parrier.keep_parry(move, 10, contact, sweep, attacker.yaw)
	attacker.parry_sweep = sweep # in the attacker's own frame, as sweep_of() gives it
	if kind == &"parry":
		attacker.set_state(&"recoil", SimConst.PARRY_RECOIL)
	else:
		attacker.set_state(&"stunned", 40)
	attacker.stun_cause = &""
	attacker.blocking = false
	parrier.set_state(&"parryAnim", SimConst.PARRIER_RECOVERY)
	var e := {"t": &"parry", "parrier": 1, "attacker": 0, "attack": move, "kind": kind,
		"pos": {"x": 0.2, "y": 1.4, "z": 0.0}, "weapon": &"katana", "defender_weapon": &"katana"}
	host.sim_event.emit(e)
	return e


## The world moves on by `frames` frames (none in a hit-stop) and the sound
## follows, as at the end of each host step.
func _frames_pass(frames: int) -> void:
	for i in frames:
		host.world.frame += 1
		audio.update_pair_sounds()


func test_a_parry_plays_its_deflect_pair_s_halves_on_their_frames() -> void:
	var log := _record_places(false)
	_parried(&"k_l1")
	audio.update_pair_sounds()
	var scrape := &"deflect_scrape_right_to_left"
	assert_almost_eq(_at(log, scrape), Vector3(0.2, 1.4, 0.0), Vector3.ONE * 1e-4, "the scrape where the blades meet, on the contact frame")
	assert_false(_cues(log).has(&"recoil_whoosh_right_to_left"), "the recoil's whoosh waits for its frame")
	var cues := SoundBank.deflect_pair_cues(&"right_to_left", &"deflect") + SoundBank.deflect_pair_cues(&"right_to_left", &"recoil")
	var last := 0
	for cue: Dictionary in cues:
		last = maxi(last, int(cue["frame"]))
	var started := {}
	audio.player.played.connect(func(cue: StringName, _voice: Node) -> void: started[cue] = host.world.frame)
	var parried_at := host.world.frame
	_frames_pass(last)
	for cue: Dictionary in cues:
		if int(cue["frame"]) > 0:
			assert_eq(started.get(cue["cue"], -1) - parried_at, int(cue["frame"]), "%s on its frame" % cue["cue"])
	assert_almost_eq(_at(log, &"recoil_whoosh_right_to_left"), _chest(0), Vector3.ONE * 1e-4, "the whoosh at the attacker")
	assert_almost_eq(_at(log, &"deflect_cloth"), _chest(1), Vector3.ONE * 1e-4, "the cloth snap at the parrier")
	var feet: Vector3 = Vector3(host.fighter(0).pos.x, host.fighter(0).pos.y, host.fighter(0).pos.z)
	assert_almost_eq(_at(log, &"recoil_stagger"), feet, Vector3.ONE * 1e-4, "the stagger at the attacker's feet")
	for cue: Dictionary in cues:
		assert_eq(_count(log, cue["cue"]), 1, "%s once" % cue["cue"])


func test_the_hit_stop_holds_the_pair_s_sounds_as_it_holds_its_clips() -> void:
	var log := _record_places(false)
	_parried(&"k_l1")
	for i in 30:
		audio.update_pair_sounds() # the parry's hit-stop: the world's frame stands
	var pair_cues: Array[StringName] = []
	pair_cues.assign(_cues(log).filter(func(c: StringName) -> bool: return _pair_cue(c)))
	assert_eq(pair_cues, [&"deflect_scrape_right_to_left"] as Array[StringName], "only the contact's scrape through the hit-stop")
	_frames_pass(1)
	assert_true(_cues(log).has(&"recoil_whoosh_right_to_left"), "the whoosh once the clip moves again")


func test_a_move_without_a_pair_sounds_the_pair_it_borrows() -> void:
	var log := _record_places(false)
	_parried(&"no_pair_of_its_own", &"parry", ClipDirector.sweep_of(&"k_l4"))
	_frames_pass(20)
	assert_true(_cues(log).has(&"deflect_scrape_overhead"), "the nearest light's (Crown Cut's) scrape")
	assert_true(_cues(log).has(&"recoil_whoosh_overhead"))


func test_a_flash_sounds_its_pair_under_its_own_ring() -> void:
	var log := _record_places(false)
	_parried(&"k_l3", &"flash")
	_frames_pass(20)
	assert_true(_cues(log).has(&"parry_flash"), "the Flash's own ring")
	assert_true(_cues(log).has(&"deflect_scrape_diagonal"))
	assert_true(_cues(log).has(&"recoil_whoosh_diagonal"), "the stunned attacker plays the recoil")


func test_a_recoil_cut_short_drops_its_later_sounds() -> void:
	var log := _record_places(false)
	_parried(&"k_l2")
	_frames_pass(2)
	host.fighter(0).blocking = true # the guard back up: the recoil hands on
	host.fighter(1).set_state(&"attack", 20) # the parrier swings out of its deflect
	_frames_pass(20)
	assert_false(_cues(log).has(&"recoil_stagger"), "no stagger once the guard is back")
	assert_eq(_count(log, &"recoil_whoosh_left_to_right"), 1, "the whoosh had played")


func test_a_redirect_plays_no_pair() -> void:
	var log := _record_places(false)
	var e := _parried(&"k_l1", &"parry")
	audio.stop_pair_sounds()
	log.clear()
	# a redirect: a bare hand turns the blade aside, no steel on steel
	e["kind"] = &"redirect"
	e["defender_weapon"] = &"fists"
	host.sim_event.emit(e)
	_frames_pass(20)
	assert_true(_cues(log).has(&"parry_redirect"), "the redirect's own sound")
	assert_false(_cues(log).any(func(c: StringName) -> bool: return _pair_cue(c)), "no deflect pair's sounds")


func test_a_parried_attacker_disarmed_plays_no_recoil() -> void:
	var log := _record_places(false)
	_parried(&"k_l1")
	host.fighter(0).stun_cause = &"parried" # the parry broke its posture: disarmed, not recoiling
	audio.update_pair_sounds()
	_frames_pass(20)
	assert_true(_cues(log).has(&"deflect_scrape_right_to_left"), "the parrier still deflects")
	assert_false(_cues(log).has(&"recoil_whoosh_right_to_left"))
	assert_false(_cues(log).has(&"recoil_stagger"))


func test_a_new_match_drops_the_pair_s_waiting_sounds() -> void:
	var log := _record_places(false)
	_parried(&"k_l1")
	audio.update_pair_sounds()
	host.start(_cpu())
	log.clear()
	_frames_pass(20)
	assert_false(_cues(log).any(func(c: StringName) -> bool: return _pair_cue(c)), "nothing of the last match's parry")


# ------------------------------------------------------------------ the Katana's movement attacks (task 77)

## The Hunter with the Katana in Training against the dummy, fighter 0
## driven by the test.
func _training_hunter() -> void:
	var dummy: MatchSide = MatchSide.computer(&"rogue", &"katana", 1)
	dummy.controller = MatchSide.DUMMY
	host.start(MatchConfig.make(MatchConfig.TRAINING, MatchSide.human(&"hunter", &"katana"), dummy, 3, ArenaScenes.STANDIN))
	host.step(Match.INTRO_FRAMES + 5)


## A movement attack's swing whooshes the Hunter's coat at the Hunter (task
## 77, the owner's answer of Oct 8).
func test_the_hunter_s_coat_whooshes_with_a_movement_attack() -> void:
	var log := _record_places(false)
	_training_hunter()
	var f: Fighter = host.fighter(0)
	assert_true(f.start_attack(&"k_bl"))
	host.step(f.atk.def.startup + 1)
	assert_eq(_count(log, &"hunter_cloth_whoosh"), 1, "with Rising Cut's swing")
	assert_almost_eq(_at(log, &"hunter_cloth_whoosh"), _chest(0), Vector3.ONE * 0.2, "at the Hunter")


## Whirl Cut's double whoosh starts on its frame (task 77), at the spinner's
## chest, once, held by a hit-stop as the clip is.
func test_whirl_cut_s_double_whoosh_starts_on_its_frame() -> void:
	var log := _record_places(false)
	_training_hunter()
	var f: Fighter = host.fighter(0)
	var cue: Dictionary = SoundBank.move_cues(&"k_dh")[0]
	var started: Array[int] = []
	audio.player.played.connect(func(name: StringName, _voice: Node) -> void:
		if name == cue["cue"]:
			started.append(f.atk.frame if f.atk != null else -1))
	assert_true(f.start_attack(&"k_dh"))
	host.step(int(cue["frame"]) - 1)
	assert_eq(started, [] as Array[int], "not before its frame")
	host.step(1)
	assert_eq(started, [int(cue["frame"])], "on its frame")
	assert_almost_eq(_at(log, cue["cue"]), _chest(0), Vector3.ONE * 1e-4, "at the spinner's chest")
	host.world.hitstop = 6
	host.step(6)
	host.step(f.atk.def.startup + f.atk.def.active - int(cue["frame"]))
	assert_eq(started.size(), 1, "once")
	assert_eq(_count(log, &"whoosh_heavy"), 1, "and the strike's own whoosh")
