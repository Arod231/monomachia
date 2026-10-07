extends GutTest
## The shot director (milestone-1 task 97; spec stories 133, 135, P37, P38):
## rules events in, the chosen cinematic shot out, played from its data on
## the presentation side: the ultimates once they connect (never their
## wind-up), both finishers, the match-winning KO, the recall a push-in
## only; a shot hands back by its length or the victim's stun.

const EPS: float = 1e-4


func after_each() -> void:
	SimHelpers.dispose_all()


func _world() -> World:
	return SimHelpers.make_world(Moves.KATANA, Moves.KATANA)


func _hit(W: World, attack: StringName, by: int = 0) -> Dictionary:
	return {"t": &"hit", "attacker": by, "target": 1 - by, "attack": attack, "heavy": true, "sound": &"blade",
		"pos": {"x": 0.0, "y": 1.2, "z": 0.0}}


## The victim of a hit, stunned `frames` from now, as the rules leave it.
func _stun(W: World, side: int, frames: int) -> void:
	W.fighters[side].enter_hitstun(frames)


# ------------------------------------------------------------------ the data

func test_every_slot_has_a_shot_that_loads_with_a_path_a_lens_and_its_effects() -> void:
	for id: StringName in ShotDirector.SLOTS:
		var shot: ShotData = ShotDirector.load_shot(id)
		assert_not_null(shot, "%s has a shot" % id)
		if shot == null:
			continue
		assert_eq(shot.id, id)
		assert_gt(shot.times.size(), 1, "%s: a path of keys" % id)
		assert_eq(shot.positions.size(), shot.times.size(), "%s: a position a key" % id)
		assert_eq(shot.looks.size(), shot.times.size(), "%s: a look point a key" % id)
		assert_eq(shot.fovs.size(), shot.times.size(), "%s: a lens a key" % id)
		assert_eq(shot.times[0], 0.0, "%s starts at 0" % id)
		for i: int in range(1, shot.times.size()):
			assert_gt(shot.times[i], shot.times[i - 1], "%s: keys in order" % id)
		for f: float in shot.fovs:
			assert_between(f, 20.0, 80.0, "%s: a lens" % id)
		assert_true(shot.about in [ShotData.ATTACKER, ShotData.WINNER], "%s is about a fighter" % id)
		assert_true(shot.depth_of_field or not shot.depth_of_field, "%s: names its depth of field" % id)


func test_a_shot_samples_its_keys_and_eases_between_them() -> void:
	var shot: ShotData = ShotData.new()
	shot.times = PackedFloat32Array([0.0, 1.0, 2.0])
	shot.positions = PackedVector3Array([Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(2, 1, 0)])
	shot.looks = PackedVector3Array([Vector3(0, 1, 5), Vector3(0, 1, 5), Vector3(0, 1, 5)])
	shot.fovs = PackedFloat32Array([50.0, 40.0, 40.0])
	assert_almost_eq(shot.length(), 2.0, EPS)
	var a: Dictionary = shot.sample(0.0)
	assert_almost_eq((a["pos"] as Vector3).distance_to(Vector3(0, 1, 0)), 0.0, EPS, "the first key")
	assert_almost_eq(float(a["fov"]), 50.0, EPS)
	var mid: Dictionary = shot.sample(1.0)
	assert_almost_eq((mid["pos"] as Vector3).distance_to(Vector3(1, 1, 0)), 0.0, EPS, "through each key")
	var half: Dictionary = shot.sample(0.5)
	assert_between((half["pos"] as Vector3).x, 0.3, 0.7, "between them")
	assert_between(float(half["fov"]), 40.0, 50.0)
	var end: Dictionary = shot.sample(9.0)
	assert_almost_eq((end["pos"] as Vector3).distance_to(Vector3(2, 1, 0)), 0.0, EPS, "held at the last key")


func test_a_shot_s_keys_are_in_the_frame_of_the_fighter_it_is_about() -> void:
	# origin at its feet, +Z toward its opponent, +X to its left
	var shot: ShotData = ShotData.new()
	shot.times = PackedFloat32Array([0.0, 1.0])
	shot.positions = PackedVector3Array([Vector3(1.0, 1.5, -2.0), Vector3(1.0, 1.5, -2.0)])
	shot.looks = PackedVector3Array([Vector3(0.0, 1.0, 3.0), Vector3(0.0, 1.0, 3.0)])
	shot.fovs = PackedFloat32Array([45.0, 45.0])
	var v: Dictionary = shot.view_at(0.0, Vector3(5.0, 0.0, 5.0), Vector3(5.0, 0.0, 9.0))
	assert_almost_eq((v["pos"] as Vector3).distance_to(Vector3(6.0, 1.5, 3.0)), 0.0, EPS, "facing +Z")
	var turned: Dictionary = shot.view_at(0.0, Vector3(0.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0))
	# facing +X: its left is -Z
	assert_almost_eq((turned["pos"] as Vector3).distance_to(Vector3(-2.0, 1.5, -1.0)), 0.0, EPS, "facing +X")
	assert_almost_eq((turned["look"] as Vector3).distance_to(Vector3(3.0, 1.0, 0.0)), 0.0, EPS)


# ------------------------------------------------------------------ the choice

func test_an_ultimate_s_wind_up_has_no_shot() -> void:
	var W: World = _world()
	assert_true(ShotDirector.choose({"t": &"ultStart", "f": 0, "ult": &"moonsplitter"}, W).is_empty())
	assert_true(ShotDirector.choose({"t": &"ultWave", "f": 0, "kind": &"vertical"}, W).is_empty(), "nor its wave crossing the stage")


func test_moonsplitter_and_breaker_palm_get_their_shots_once_they_connect() -> void:
	var W: World = _world()
	for attack: StringName in [&"u_moon_v", &"u_moon_h"]:
		_stun(W, 1, 75)
		var c: Dictionary = ShotDirector.choose(_hit(W, attack), W)
		assert_eq(c.get("shot"), &"moonsplitter", attack)
		assert_eq(int(c["about"]), 0, "about the fighter who cast it")
		assert_eq(int(c["cap"]), 75, "handed back by the victim's stun")
	_stun(W, 0, 54)
	var bp: Dictionary = ShotDirector.choose(_hit(W, &"f_breaker", 1), W)
	assert_eq(bp.get("shot"), &"breaker_palm")
	assert_eq(int(bp["about"]), 1)
	assert_eq(int(bp["cap"]), 54)
	assert_true(ShotDirector.choose(_hit(W, &"k_l1"), W).is_empty(), "a plain hit has none")
	assert_true(ShotDirector.choose({"t": &"block", "attacker": 0, "target": 1, "attack": &"u_moon_v", "heavy": true}, W).is_empty(), "a blocked one has none")


func test_an_ultimate_that_knocks_out_has_no_stun_to_hand_back_by() -> void:
	var W: World = _world()
	W.fighters[1].hp = 0.0
	W.fighters[1].to_ko()
	assert_eq(int(ShotDirector.choose(_hit(W, &"u_moon_v"), W)["cap"]), -1)


func test_the_recall_gets_a_push_in_and_no_shot() -> void:
	var W: World = _world()
	var c: Dictionary = ShotDirector.choose({"t": &"recallBurst", "f": 0, "on": 1, "hit": true, "pos": {"x": 0.0, "y": 1.0, "z": 0.0}}, W)
	assert_false(c.has("shot"))
	assert_almost_eq(float(c["push_in"]), ShotDirector.RECALL_PUSH_IN, EPS)
	assert_gt(ShotDirector.RECALL_PUSH_IN, 0.0)


func test_each_finisher_gets_its_own_shot() -> void:
	var W: World = _world()
	var katana: Dictionary = ShotDirector.choose({"t": &"finisher", "f": 1, "victim": 0, "kind": &"katana", "from_strike": false}, W)
	assert_eq(katana.get("shot"), &"finisher_katana")
	assert_eq(int(katana["about"]), 1)
	assert_eq(int(katana["cap"]), -1, "it plays through Warrior Slain")
	var fists: Dictionary = ShotDirector.choose({"t": &"finisher", "f": 0, "victim": 1, "kind": &"fists", "from_strike": true}, W)
	assert_eq(fists.get("shot"), &"finisher_fists")


func test_only_the_match_winning_ko_gets_the_ko_shot() -> void:
	var W: World = _world()
	var n: int = SimConst.ROUNDS_TO_WIN
	var wins: Dictionary = ShotDirector.choose({"t": &"roundOver", "winner": 1, "wins": [1, n], "perfect": false}, W)
	assert_eq(wins.get("shot"), &"match_ko")
	assert_eq(int(wins["about"]), 1, "about the winner")
	assert_true(ShotDirector.choose({"t": &"roundOver", "winner": 1, "wins": [1, n - 1], "perfect": false}, W).is_empty(),
		"a KO that only ends a round stays on the gameplay camera")
	assert_true(ShotDirector.choose({"t": &"roundOver", "winner": -1, "wins": [n, n], "perfect": false}, W).is_empty(), "a double KO")
	assert_true(ShotDirector.choose({"t": &"ko", "loser": 0, "winner": 1, "finisher": false}, W).is_empty(), "the KO itself waits for the round's score")


# ------------------------------------------------------------------ playing

func test_a_round_ending_finisher_plays_its_shot_through_and_a_match_winning_one_replaces_the_ko_shot() -> void:
	var W: World = _world()
	var d: ShotDirector = ShotDirector.new()
	d.on_event({"t": &"finisher", "f": 0, "victim": 1, "kind": &"katana", "from_strike": false}, W)
	assert_eq(d.playing_id(), &"finisher_katana")
	d.on_event({"t": &"ko", "loser": 1, "winner": 0, "finisher": true}, W)
	d.on_event({"t": &"roundOver", "winner": 0, "wins": [SimConst.ROUNDS_TO_WIN, 0], "perfect": false}, W)
	assert_eq(d.playing_id(), &"finisher_katana", "the finisher's shot stands in for the KO shot")


func test_the_match_winning_ko_takes_over_from_an_ultimate_s_shot() -> void:
	var W: World = _world()
	var d: ShotDirector = ShotDirector.new()
	d.on_event(_hit(W, &"u_moon_h"), W)
	assert_eq(d.playing_id(), &"moonsplitter")
	d.on_event({"t": &"roundOver", "winner": 0, "wins": [SimConst.ROUNDS_TO_WIN, 1], "perfect": false}, W)
	assert_eq(d.playing_id(), &"match_ko")
	assert_eq(d.about, 0)


func test_a_shot_runs_on_real_time_and_ends_at_its_length() -> void:
	var W: World = _world()
	var d: ShotDirector = ShotDirector.new()
	d.on_event({"t": &"roundOver", "winner": 1, "wins": [0, SimConst.ROUNDS_TO_WIN], "perfect": false}, W)
	var length: float = ShotDirector.load_shot(&"match_ko").length()
	# the world stands still (the KO's slow motion, hit-stop): the shot goes on
	for i: int in 30:
		d.advance(1.0 / 60.0, W.frame)
	assert_almost_eq(d.elapsed, 0.5, 1e-4, "half a second of real time")
	assert_true(d.active())
	while d.elapsed + 1.0 / 60.0 <= length:
		d.advance(1.0 / 60.0, W.frame)
	assert_true(d.active(), "until its last key")
	d.advance(1.0 / 30.0, W.frame)
	assert_false(d.active(), "then back to the gameplay camera")
	assert_eq(d.playing_id(), &"")


func test_an_ultimate_s_shot_hands_back_when_the_victim_s_stun_ends() -> void:
	var W: World = _world()
	var d: ShotDirector = ShotDirector.new()
	_stun(W, 1, 20)
	d.on_event(_hit(W, &"u_moon_v"), W)
	assert_lt(20.0 / 60.0, ShotDirector.load_shot(&"moonsplitter").length(), "the stun is shorter than the shot")
	var start: int = W.frame
	d.advance(1.0 / 60.0, start + 19)
	assert_true(d.active(), "while the stun lasts")
	d.advance(1.0 / 60.0, start + 20)
	assert_false(d.active(), "no later than its end, in the world's frames")


func test_a_new_round_ends_any_shot_and_the_recall_starts_none() -> void:
	var W: World = _world()
	var d: ShotDirector = ShotDirector.new()
	d.on_event(_hit(W, &"f_breaker"), W)
	assert_true(d.active())
	d.on_event({"t": &"roundStart", "round": 2}, W)
	assert_false(d.active())
	d.on_event({"t": &"recallBurst", "f": 0, "on": 1, "hit": true, "pos": {"x": 0.0, "y": 1.0, "z": 0.0}}, W)
	assert_false(d.active())


func test_the_view_follows_the_fighter_the_shot_is_about() -> void:
	var W: World = _world()
	var d: ShotDirector = ShotDirector.new()
	d.on_event(_hit(W, &"f_breaker", 1), W)
	var shot: ShotData = ShotDirector.load_shot(&"breaker_palm")
	var at: Array[Vector3] = [Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)]
	var v: Dictionary = d.view(at)
	var want: Dictionary = shot.view_at(0.0, at[1], at[0])
	assert_almost_eq((v["pos"] as Vector3).distance_to(want["pos"]), 0.0, EPS, "side 1's frame, toward side 0")
	assert_almost_eq(float(v["fov"]), float(want["fov"]), EPS)
	assert_eq(v["depth_of_field"], shot.depth_of_field)
