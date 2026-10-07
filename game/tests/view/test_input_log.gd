extends GutTest
## The computer's snapshot, the input log and replays (milestone-1 task 6,
## stories 24 and 26): the match host saved and restored mid-match steps on
## as before against the computer at each difficulty, and a recorded match
## replays to the same winner and hash, Training's panel actions included.

## Twelve minutes of rules time, as the soak allows.
const MATCH_LIMIT: int = 60 * 60 * 12
const DIR: String = "user://test_replays"

var fake: FakeDeviceState


func before_each() -> void:
	_clear_dir()


func after_each() -> void:
	_clear_dir()


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/" + f))


func _host() -> MatchHost:
	var host: MatchHost = MatchHost.new()
	host.auto_run = false
	host.use_services = false
	fake = FakeDeviceState.new()
	host.input = InputDevices.new(fake)
	host.profiles = ControlProfiles.new()
	autofree(host)
	return host


static func _config(mode: StringName, seed_value: int, difficulty: StringName = &"hard") -> MatchConfig:
	var cfg: MatchConfig
	match mode:
		MatchConfig.DUEL:
			cfg = MatchConfig.default_duel(seed_value)
		MatchConfig.TRAINING:
			cfg = MatchConfig.default_training(seed_value)
		_:
			cfg = MatchConfig.default_watch(seed_value)
			cfg.sides[0].difficulty = difficulty
	cfg.sides[1].difficulty = difficulty
	cfg.arena_id = ArenaScenes.STANDIN
	return cfg


## Steps a host to the end of its match (or the limit) and a little past.
static func _play_out(host: MatchHost) -> void:
	var steps: int = 0
	while host.sim_match.phase != &"matchEnd" and steps < MATCH_LIMIT:
		host.step(1)
		steps += 1
	host.step(30)


# ------------------------------------------------------------------ the computer's snapshot

func test_a_match_against_the_computer_restores_and_steps_on_at_each_difficulty() -> void:
	for difficulty: StringName in AIBrain.DIFFICULTIES:
		var host: MatchHost = _host()
		host.start(_config(MatchConfig.WATCH, 31, difficulty))
		host.step(Match.INTRO_FRAMES + 250)
		var saved: Dictionary = host.snapshot()
		var hashes: Array[String] = []
		for i: int in 900:
			host.step(1)
			hashes.append(host.state_hash())
		host.restore(saved)
		assert_eq(host.state_hash(), SimState.state_hash(saved), "%s: the restored host hashes as saved" % difficulty)
		var first_diff: int = -1
		for i: int in 900:
			host.step(1)
			if first_diff < 0 and host.state_hash() != hashes[i]:
				first_diff = i + 1
		assert_eq(first_diff, -1, "%s: the brains think on as before (first difference %d steps on)" % [difficulty, first_diff])


func test_training_s_dummy_restores_with_its_sparring_brain() -> void:
	var host: MatchHost = _host()
	host.start(_config(MatchConfig.TRAINING, 8))
	host.step(Match.INTRO_FRAMES + 10)
	host.set_training_behaviour(&"fight")
	host.step(200)
	var saved: Dictionary = host.snapshot()
	var hashes: Array[String] = []
	for i: int in 600:
		host.step(1)
		hashes.append(host.state_hash())
	host.restore(saved)
	var same: bool = true
	for i: int in 600:
		host.step(1)
		same = same and host.state_hash() == hashes[i]
	assert_true(same, "the sparring dummy fights on as before")


# ------------------------------------------------------------------ recording and replaying

func test_a_recorded_match_replays_to_the_same_winner_and_hash() -> void:
	var a: MatchHost = _host()
	a.start(_config(MatchConfig.WATCH, 17))
	_play_out(a)
	var log_a: InputLog = a.input_log
	a.stop()
	assert_eq(log_a.end_steps, log_a.step_count(), "the log ends where the match was left")
	assert_eq(log_a.end_winner, a.sim_match.match_winner)
	assert_gt(log_a.checkpoints.size(), 10, "a checkpoint every %d steps" % InputLog.CHECKPOINT_EVERY)
	var b: MatchHost = _host()
	watch_signals(b)
	assert_true(b.start_replay(log_a))
	assert_true(b.is_replaying())
	assert_null(b.input_log, "a replay isn't recorded")
	b.step(log_a.step_count() + 5)
	assert_signal_emitted(b, "replay_checked")
	var args: Array = get_signal_parameters(b, "replay_checked")
	assert_true(args[0], args[1])
	assert_eq(b.sim_match.match_winner, log_a.end_winner)
	assert_eq(b.rules_hash(), log_a.end_hash)
	assert_eq(b.step_count, log_a.step_count(), "the replay holds still when its log runs out")


func test_a_human_s_inputs_replay_exactly() -> void:
	var a: MatchHost = _host()
	a.start(_config(MatchConfig.DUEL, 9))
	fake.plug_pad(0)
	a.step(Match.INTRO_FRAMES + 20)
	# the stick at an odd angle and a few presses: values that must come back
	# exactly from the file
	fake.set_axis(0, JOY_AXIS_LEFT_X, 0.7071067811865476)
	fake.set_axis(0, JOY_AXIS_LEFT_Y, -0.3333333333333333)
	a.step(40)
	fake.press_key(KEY_J)
	a.step(3)
	fake.release_key(KEY_J)
	a.step(20)
	# the grip switched mid-match (KE task 6)
	fake.press_key(KEY_R)
	a.step(2)
	fake.release_key(KEY_R)
	a.step(28)
	fake.set_axis(0, JOY_AXIS_LEFT_X, 0.0)
	fake.press_key(KEY_SPACE)
	a.step(2)
	fake.release_key(KEY_SPACE)
	a.step(300)
	var log_a: InputLog = a.input_log
	a.stop()
	var moved: bool = false
	var gripped: bool = false
	for i: int in log_a.step_count():
		if log_a.input(i, 0).mx != 0.0:
			moved = true
		if log_a.input(i, 0).buttons & Btn.bit(Btn.GRIP):
			gripped = true
	assert_true(moved, "the human side's stick is in the log")
	assert_true(gripped, "and the grip press")
	var path: String = DIR + "/human.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	assert_eq(log_a.save(path), OK)
	var loaded: InputLog = InputLog.load_file(path)
	assert_eq(loaded.inputs, log_a.inputs, "every number comes back from the file")
	assert_eq(loaded.config.to_dict(), log_a.config.to_dict())
	assert_eq(loaded.checkpoints, log_a.checkpoints)
	var b: MatchHost = _host()
	watch_signals(b)
	b.start_replay(loaded)
	b.step(loaded.step_count() + 1)
	assert_true(get_signal_parameters(b, "replay_checked")[0], str(get_signal_parameters(b, "replay_checked")[1]))


func test_training_s_panel_actions_replay_at_their_step() -> void:
	var a: MatchHost = _host()
	a.start(_config(MatchConfig.TRAINING, 6))
	a.step(Match.INTRO_FRAMES + 30)
	a.set_training_behaviour(&"lights")
	a.step(200)
	a.set_refill(false)
	a.set_training_behaviour(&"fight")
	a.step(400)
	var log_a: InputLog = a.input_log
	a.stop()
	assert_eq(log_a.actions.size(), 3)
	assert_eq(log_a.actions[0], {"step": Match.INTRO_FRAMES + 30, "behaviour": "lights"})
	var b: MatchHost = _host()
	watch_signals(b)
	b.start_replay(log_a)
	b.set_training_behaviour(&"block") # ignored: the replay plays the log's
	b.step(log_a.step_count() + 1)
	assert_true(get_signal_parameters(b, "replay_checked")[0], str(get_signal_parameters(b, "replay_checked")[1]))
	assert_eq(b.training_behaviour(), &"fight")
	assert_false(b.refill())


func test_a_replay_that_drifts_names_where() -> void:
	var a: MatchHost = _host()
	a.start(_config(MatchConfig.WATCH, 23))
	a.step(Match.INTRO_FRAMES + 600)
	var log_a: InputLog = a.input_log
	a.stop()
	# side 0's light button flipped from step 301 to 500, where it fights
	for step: int in range(300, 500):
		var at: int = step * InputLog.PER_STEP + 2
		log_a.inputs[at] = float(int(log_a.inputs[at]) ^ (1 << Btn.LIGHT))
	var b: MatchHost = _host()
	watch_signals(b)
	b.start_replay(log_a)
	b.step(log_a.step_count() + 1)
	var args: Array = get_signal_parameters(b, "replay_checked")
	assert_false(args[0])
	var said: String = args[1]
	assert_string_contains(said, "drifted from the log by step ")
	var step: int = int(said.trim_prefix("replay: drifted from the log by step ").get_slice(" ", 0))
	assert_true(step > 300 and step <= 540 and step % InputLog.CHECKPOINT_EVERY == 0, "the first checkpoint after the change: %d" % step)


func test_the_attract_duel_isn_t_recorded() -> void:
	var host: MatchHost = _host()
	host.start(_config(MatchConfig.WATCH, 3), true)
	assert_null(host.input_log)


func test_each_match_played_is_saved_and_the_newest_ten_kept() -> void:
	var host: MatchHost = _host()
	host.record_dir = DIR
	for i: int in 12:
		host.start(_config(MatchConfig.WATCH, 40 + i))
		host.step(5)
	host.stop()
	var files: PackedStringArray = DirAccess.get_files_at(DIR)
	assert_eq(files.size(), InputLog.KEEP)
	for f: String in files:
		assert_true(f.begins_with("replay-") and f.ends_with("-watch.json") or f.contains("-watch-"), f)
	var any: InputLog = InputLog.load_file(DIR + "/" + files[0])
	assert_not_null(any)
	assert_eq(any.step_count(), 5)


func test_the_replay_flag_names_a_log() -> void:
	assert_eq(InputLog.requested(PackedStringArray(["--path", "game", "--replay=C:/logs/a.json"])), "C:/logs/a.json")
	assert_eq(InputLog.requested(PackedStringArray(["--swing-debug"])), "")


func test_a_log_of_another_format_is_refused() -> void:
	assert_null(InputLog.from_dict({"format": 99}))
	assert_push_error("format 99", "the reason is reported")


## Format 2 (milestone-1 task 28) packs the inputs' bytes with gzip before
## base64: a match's inputs repeat a lot, so the worst-case replay's log went
## from 955 KB to a few dozen.
func test_the_inputs_are_saved_compressed_and_format_1_still_reads() -> void:
	var log_a: InputLog = InputLog.make(_config(MatchConfig.WATCH, 1))
	for i: int in 3000:
		log_a.record([RawInput.make(0.25, -1.0, 4), RawInput.make(0.0, 0.0, 0)] as Array[RawInput])
	var d: Dictionary = log_a.to_dict()
	assert_eq(d["format"], 2)
	assert_eq(d["inputs_bytes"], 3000 * InputLog.PER_STEP * 8)
	assert_lt(str(d["inputs"]).length(), 3000, "packed")
	var back: InputLog = InputLog.from_dict(d)
	assert_not_null(back)
	assert_eq(back.inputs, log_a.inputs)
	var old: Dictionary = d.duplicate()
	old["format"] = 1
	old["inputs"] = Marshalls.raw_to_base64(log_a.inputs.to_byte_array())
	old.erase("inputs_bytes")
	var from_old: InputLog = InputLog.from_dict(old)
	assert_not_null(from_old, "a log saved before task 28 still loads")
	assert_eq(from_old.inputs, log_a.inputs)
	var broken: Dictionary = d.duplicate()
	broken["inputs_bytes"] = int(d["inputs_bytes"]) + 8
	assert_null(InputLog.from_dict(broken), "a size that doesn't match is refused")
	assert_push_error("unpack", "the reason is reported")


## Godot's text-to-float parsing isn't exact: about one in six of the
## computer's stick values came back from JSON numbers one unit in the last
## place off, which drifted a replayed smoke run by step 1380. The inputs are
## saved as the doubles' bytes, so every value comes back exactly.
func test_every_input_value_comes_back_from_the_file_exactly() -> void:
	var cfg: MatchConfig = _config(MatchConfig.WATCH, 1)
	var log_a: InputLog = InputLog.make(cfg)
	var rng: Rng = Rng.new(5)
	var awkward: float = -0.11267151457891295
	log_a.record([RawInput.make(awkward, 0.9936322910425637, 5), RawInput.make(-0.0, 1e-300, 0)] as Array[RawInput])
	for i: int in 2000:
		log_a.record([
			RawInput.make(JsMath.sin(rng.next() * TAU), JsMath.cos(rng.next() * TAU), i % 512),
			RawInput.make(rng.range(-1.0, 1.0), rng.range(-1.0, 1.0), 0),
		] as Array[RawInput])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var path: String = DIR + "/exact.json"
	assert_eq(log_a.save(path), OK)
	var b: InputLog = InputLog.load_file(path)
	assert_eq(b.step_count(), 2001)
	assert_eq(b.input(0, 0).mx, awkward, "a value JSON's numbers can't carry")
	var differ: int = 0
	for i: int in log_a.inputs.size():
		if b.inputs[i] != log_a.inputs[i]:
			differ += 1
	assert_eq(differ, 0, "every number comes back exactly")
