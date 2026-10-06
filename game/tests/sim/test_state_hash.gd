extends GutTest
## The rules' state hash and the replay test (milestone-1 task 5, story 23):
## a seeded match run twice gives the same state hash on every step, the hash
## covers everything the rules own, and changing one rules field changes it.

## Twelve minutes of rules time, as the soak allows.
const MATCH_LIMIT: int = 60 * 60 * 12


func _host() -> MatchHost:
	var host: MatchHost = MatchHost.new()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	autofree(host)
	return host


## A computer-against-computer match at the match seam.
func _watch(seed_value: int, difficulty: StringName = &"hard") -> MatchHost:
	var host: MatchHost = _host()
	var cfg: MatchConfig = MatchConfig.default_watch(seed_value)
	cfg.sides[0].difficulty = difficulty
	cfg.sides[1].difficulty = difficulty
	cfg.arena_id = ArenaScenes.STANDIN
	host.start(cfg)
	return host


func _training() -> MatchHost:
	var host: MatchHost = _host()
	var cfg: MatchConfig = MatchConfig.default_training(4)
	cfg.arena_id = ArenaScenes.STANDIN
	host.start(cfg)
	return host


func test_a_seeded_match_run_twice_gives_the_same_hash_on_every_step() -> void:
	var a: MatchHost = _watch(11)
	var b: MatchHost = _watch(11)
	assert_eq(a.state_hash(), b.state_hash(), "the same start")
	var steps: int = 0
	var first_diff: int = -1
	while a.sim_match.phase != &"matchEnd" and steps < MATCH_LIMIT:
		a.step(1)
		b.step(1)
		steps += 1
		if first_diff < 0 and a.state_hash() != b.state_hash():
			first_diff = steps
	assert_eq(a.sim_match.phase, &"matchEnd", "the match ends inside the limit")
	assert_eq(first_diff, -1, "no step's hash differs (first at step %d)" % first_diff)
	assert_eq(a.sim_match.match_winner, b.sim_match.match_winner)
	var disarms: int = a.world.fighters[0].stats.disarms + a.world.fighters[1].stats.disarms
	assert_gt(disarms, 0, "through a disarm, its weapon flying and sticking (milestone-1 task 86)")


func test_another_seed_soon_gives_another_hash() -> void:
	var a: MatchHost = _watch(11)
	var b: MatchHost = _watch(12)
	a.step(Match.INTRO_FRAMES + 120)
	b.step(Match.INTRO_FRAMES + 120)
	assert_ne(a.state_hash(), b.state_hash())


func test_changing_one_rules_field_changes_the_hash() -> void:
	var host: MatchHost = _watch(5)
	host.step(Match.INTRO_FRAMES + 90)
	var before: String = host.state_hash()
	assert_eq(host.state_hash(), before, "hashing changes nothing")
	var changes: Array[Callable] = [
		func(h: MatchHost) -> void: h.fighter(1).hp -= 0.0001,
		func(h: MatchHost) -> void: h.fighter(1).pos.x += 1e-9,
		func(h: MatchHost) -> void: h.fighter(1).posture += 0.5,
		func(h: MatchHost) -> void: h.fighter(1).input.held ^= 1,
		func(h: MatchHost) -> void: h.fighter(1).stats.hits_landed += 1,
		func(h: MatchHost) -> void: h.world.rng.next(),
		func(h: MatchHost) -> void: h.world.hitstop += 1,
		func(h: MatchHost) -> void: h.sim_match.phase_frames += 1,
		func(h: MatchHost) -> void: (h.brain(0) as AIBrain).rng.next(),
		func(h: MatchHost) -> void: (h.brain(1) as AIBrain)._next_think += 1,
	]
	for i: int in changes.size():
		var h: MatchHost = _watch(5)
		h.step(Match.INTRO_FRAMES + 90)
		assert_eq(h.state_hash(), before, "change %d starts from the same state" % i)
		changes[i].call(h)
		assert_ne(h.state_hash(), before, "change %d shows in the hash" % i)


func test_the_world_s_own_hash_follows_its_fighters_and_generator() -> void:
	var host: MatchHost = _watch(5)
	host.step(Match.INTRO_FRAMES + 30)
	var w: World = host.world
	var before: String = w.state_hash()
	w.fighters[0].yaw += 0.001
	assert_ne(w.state_hash(), before)
	w.fighters[0].yaw -= 0.001
	assert_eq(w.state_hash(), before, "a value put back gives the hash back")
	w.rng.next()
	assert_ne(w.state_hash(), before)


func test_events_are_output_not_state() -> void:
	var host: MatchHost = _watch(5)
	host.step(10)
	var before: String = host.world.state_hash()
	host.world.emit({"t": &"test"})
	assert_eq(host.world.state_hash(), before)


func test_training_s_upkeep_and_dummy_are_in_the_hash() -> void:
	var a: MatchHost = _training()
	a.step(Match.INTRO_FRAMES + 10)
	var before: String = a.state_hash()
	a.set_refill(false)
	assert_ne(a.state_hash(), before, "the refill")
	var b: MatchHost = _training()
	b.step(Match.INTRO_FRAMES + 10)
	b.set_training_behaviour(&"lights")
	assert_ne(b.state_hash(), before, "the dummy's behaviour")


## Every script variable of each rules class is in its snapshot, or named as
## not state by the class (SNAPSHOT_SKIP), so a field added later can't slip
## out of the hash.
func test_every_rules_field_is_in_its_snapshot_or_named_not_state() -> void:
	var host: MatchHost = _training()
	host.step(Match.INTRO_FRAMES + 10)
	var w: World = host.world
	var cases: Array = [
		[w, World.SNAPSHOT_SKIP, w.snapshot()],
		[w.fighters[0], Fighter.SNAPSHOT_SKIP, w.fighters[0].snapshot()],
		[host.sim_match, Match.SNAPSHOT_SKIP, host.sim_match.snapshot()],
		[host.brain(1), TrainingBrain.SNAPSHOT_SKIP, (host.brain(1) as TrainingBrain).snapshot()],
		[host.upkeep(), TrainingUpkeep.SNAPSHOT_SKIP, host.upkeep().snapshot()],
	]
	var ai: AIBrain = AIBrain.new(w.fighters[0], AIBrain.DIFFICULTY[&"normal"], 3)
	cases.append([ai, AIBrain.SNAPSHOT_SKIP, ai.snapshot()])
	var dropped: DroppedWeapon = DroppedWeapon.new(0, &"katana", V3.make(0.0, 1.3, 0.0), V3.make(2.0, 0.0, 1.0), 0.5)
	cases.append([dropped, [] as Array[StringName], dropped.snapshot()])
	var wave: SlashWave = SlashWave.new(w.fighters[0], &"vertical", 0.0, 0.0, 0.0, 1.0)
	cases.append([wave, [] as Array[StringName], wave.snapshot()])
	for c: Array in cases:
		var obj: Object = c[0]
		var skip: Array[StringName] = c[1]
		var snap: Dictionary = c[2]
		for n: StringName in SimState.fields(obj):
			assert_true(snap.has(n) or skip.has(n), "%s.%s is in the snapshot or named not state" % [obj.get_script().get_global_name(), n])
		for n: StringName in skip:
			assert_true(SimState.fields(obj).has(n), "%s skips %s, which it has" % [obj.get_script().get_global_name(), n])
	ai.dispose()
