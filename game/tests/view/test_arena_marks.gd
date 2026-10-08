extends GutTest
## The arena's reactions (milestone-1 task 115; the owner's answers of Oct
## 8): cut marks where a blade's tip dips to the floor or reaches the
## parapet, a gash where a weapon sticks, Moonsplitter's groove and cracks
## along its path and its sparks and scorch on the parapet and pillars, the
## ultimates' and Breaker Palm's scorch, dust for every fall, landing and
## stomp and cracks only under the heaviest, all lasting the match up to the
## preset's cap, the oldest fading; grass and banners pushed (ArenaAir). And
## none of it touches the rules.

var marks: ArenaMarks
var effects: CombatEffects


func before_each() -> void:
	marks = ArenaMarks.new()
	add_child_autofree(marks)
	effects = CombatEffects.new()
	add_child_autofree(effects)
	marks.wall_radius = 15.075
	marks.floor_radius = 15.075
	marks.wall_top = 1.05
	marks.pillars = PackedVector4Array([Vector4(0.0, 19.0, 0.45, 5.0)])


func _side(at: Vector3, state: StringName = &"free", phase: StringName = &"", blades: Array = []) -> Dictionary:
	return {"at": at, "state": state, "phase": phase, "blades": blades}


func _frame(sides: Array[Dictionary], t: float, waves: Array[SlashWave] = []) -> void:
	marks.frame(sides, waves, 1.0, effects, t)
	marks.update(t)


func _vec(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


func test_a_stuck_weapon_gashes_the_floor_and_raises_dust() -> void:
	var puffs: int = effects.drawn(CombatEffects.PUFFS)
	marks.on_event({"t": &"weaponStuck", "owner": 0, "pos": _vec(Vector3(2.0, 0.0, 1.0))}, Callable(), effects, 10.0)
	effects.update(10.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.GASH), 1)
	var d: Decal = marks.decals_of(ArenaMarks.Kind.GASH)[0]
	assert_almost_eq(d.global_position, Vector3(2.0, 0.0, 1.0), Vector3.ONE * 0.01, "where it stuck")
	assert_eq(d.cull_mask & FighterModel.LAYERS, 0, "never on a fighter")
	assert_gt(effects.drawn(CombatEffects.PUFFS), puffs, "dust")


func test_only_the_heaviest_blows_crack_the_floor() -> void:
	var at := Vector3(1.0, 0.0, 0.0)
	var other := _side(Vector3(-3.0, 0.0, 0.0))
	# a jump's landing: dust, no crack
	_frame([_side(at + Vector3.UP, &"jump"), other], 1.0)
	_frame([_side(at, &"land"), other], 2.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CRACK), 0, "a landing raises dust only")
	# a stomp, as its foot comes down
	_frame([_side(at, &"stomp"), other], 3.0)
	_frame([_side(at + Vector3.UP * 0.3, &"stomp"), other], 4.0)
	_frame([_side(at, &"stomp"), other], 5.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CRACK), 1, "the stomp")
	# the leap counter's landing
	_frame([_side(at + Vector3.UP, &"leap"), other], 6.0)
	_frame([_side(at, &"free"), other], 7.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CRACK), 2, "the leap's landing")
	# a knockdown's slam
	_frame([_side(at, &"knockdown", &"fall"), other], 8.0)
	_frame([_side(at, &"knockdown", &"ground"), other], 9.0)
	_frame([_side(at, &"knockdown", &"ground"), other], 10.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CRACK), 3, "a knockdown's slam, once")


func test_the_ultimates_bursts_scorch_and_crack_and_breaker_palm_scorches() -> void:
	marks.on_event({"t": &"ultBurst", "f": 0, "pos": _vec(Vector3(1.0, 1.2, 1.0))}, Callable(), effects, 1.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.SCORCH), 1)
	assert_eq(marks.count_of(ArenaMarks.Kind.CRACK), 1)
	var palm := {"t": &"hit", "attacker": 0, "target": 1, "attack": &"f_breaker", "pos": _vec(Vector3(-1.0, 1.0, 0.0)), "heavy": true}
	marks.on_event(palm, func(_s: int) -> Vector3: return Vector3(-1.0, 0.0, 0.0), effects, 2.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.SCORCH), 2, "Breaker Palm")
	assert_eq(marks.count_of(ArenaMarks.Kind.CRACK), 1, "which doesn't crack")
	marks.on_event({"t": &"ultLightning", "f": 0, "from": _vec(Vector3(0, 1, 0)), "to": _vec(Vector3(4, 1, 0))}, Callable(), effects, 3.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.SCORCH), 3, "the lightning's path")


func test_a_blade_tip_on_the_floor_cuts_along_its_path_until_it_lifts() -> void:
	var other := _side(Vector3(-3.0, 0.0, 0.0))
	var blade := func(tip: Vector3) -> Array:
		return [PackedVector3Array([tip + Vector3(0.0, 0.9, 0.0), tip])]
	_frame([_side(Vector3.ZERO, &"attack", &"", blade.call(Vector3(1.0, 0.5, 0.0))), other], 1.0)
	_frame([_side(Vector3.ZERO, &"attack", &"", blade.call(Vector3(1.0, 0.03, 0.0))), other], 2.0)
	_frame([_side(Vector3.ZERO, &"attack", &"", blade.call(Vector3(1.0, 0.02, 0.6))), other], 3.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CUT), 1, "one cut while it stays down")
	var cut: Decal = marks.decals_of(ArenaMarks.Kind.CUT)[0]
	assert_almost_eq(cut.size.z, 0.6, 0.05, "as long as the tip's path")
	assert_almost_eq(cut.global_position, Vector3(1.0, 0.0, 0.3), Vector3.ONE * 0.02)
	_frame([_side(Vector3.ZERO, &"attack", &"", blade.call(Vector3(1.0, 0.4, 0.6))), other], 4.0)
	_frame([_side(Vector3.ZERO, &"attack", &"", blade.call(Vector3(-1.0, 0.02, 0.6))), other], 5.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CUT), 2, "a new cut where it dips again")
	# a blade low outside an attack (held at rest, a knockdown) cuts nothing
	_frame([_side(Vector3.ZERO, &"free", &"", blade.call(Vector3(2.0, 0.02, 0.0))), other], 6.0)
	_frame([_side(Vector3.ZERO, &"free", &"", blade.call(Vector3(2.0, 0.02, 0.5))), other], 7.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CUT), 2)


func test_a_blade_tip_reaching_the_parapet_cuts_it_and_throws_sparks() -> void:
	var other := _side(Vector3(-3.0, 0.0, 0.0))
	var sparks: int = effects.drawn(CombatEffects.SPARKS)
	var at := Vector3(14.4, 0.0, 0.0)
	_frame([_side(at, &"attack", &"", [PackedVector3Array([Vector3(14.6, 1.0, 0.0), Vector3(14.9, 0.8, 0.0)])]), other], 1.0)
	_frame([_side(at, &"attack", &"", [PackedVector3Array([Vector3(14.6, 1.0, 0.0), Vector3(15.2, 0.7, 0.3)])]), other], 2.0)
	effects.update(2.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CUT), 1)
	var cut: Decal = marks.decals_of(ArenaMarks.Kind.CUT)[0]
	assert_almost_eq(Vector2(cut.global_position.x, cut.global_position.z).length(), 15.075, 0.02, "on the parapet's face")
	assert_almost_eq(cut.global_basis.y.normalized().dot(Vector3.LEFT), 1.0, 0.05, "facing into the arena")
	assert_gt(effects.drawn(CombatEffects.SPARKS), sparks, "sparks off the stone")


func _wave(kind: StringName, ox: float, oz: float, dx: float, dz: float) -> SlashWave:
	return SlashWave.new(null, kind, ox, oz, dx, dz)


func test_moonsplitters_vertical_wave_grooves_and_cracks_its_path_and_scorches_what_it_meets() -> void:
	var wave: SlashWave = _wave(&"vertical", 0.0, 0.0, 0.0, 1.0)
	var sparks: int = effects.drawn(CombatEffects.SPARKS)
	for s: int in 34:
		wave.s = s
		_frame([], float(s), [wave])
	effects.update(34.0)
	assert_eq(marks.count_of(ArenaMarks.Kind.GROOVE), 1, "one groove is one mark")
	var pieces: Array[Decal] = marks.decals_of(ArenaMarks.Kind.GROOVE)
	assert_gt(pieces.size(), 4, "laid along the floor")
	for d: Decal in pieces:
		assert_lt(Vector2(d.global_position.x, d.global_position.z).length(), 15.075, "only over the floor")
		assert_almost_eq(absf(d.global_position.x), 0.0, 0.01, "along its path")
	assert_gt(marks.count_of(ArenaMarks.Kind.CRACK), 1, "cracking the floor as it goes")
	assert_eq(marks.count_of(ArenaMarks.Kind.SCORCH), 2, "the parapet and the pillar in its path")
	assert_gt(effects.drawn(CombatEffects.SPARKS), sparks)
	assert_gt(pieces[0].emission_energy, 0.0, "its core glowing")
	_frame([], 34.0 + ArenaMarks.GROOVE_GLOW_FRAMES)
	assert_eq(pieces[0].emission_energy, 0.0, "a moment")
	assert_eq(marks.count_of(ArenaMarks.Kind.GROOVE), 1, "and the groove stays")


func test_the_horizontal_wave_scorches_the_parapet_and_pillars_but_grooves_nothing() -> void:
	var wave: SlashWave = _wave(&"horizontal", 0.0, -10.0, 0.0, 1.0)
	for s: int in 44:
		wave.s = s
		_frame([], float(s), [wave])
	assert_eq(marks.count_of(ArenaMarks.Kind.GROOVE), 0)
	assert_eq(marks.count_of(ArenaMarks.Kind.CRACK), 0)
	assert_eq(marks.count_of(ArenaMarks.Kind.SCORCH), 2)


func test_marks_last_up_to_the_cap_the_oldest_fading() -> void:
	marks.cap = 4
	for i: int in 6:
		marks.on_event({"t": &"weaponStuck", "owner": 0, "pos": _vec(Vector3(i, 0.0, 0.0))}, Callable(), effects, float(i))
		marks.update(float(i))
	assert_eq(marks.count(), 6, "the oldest are fading")
	var first: Decal = marks.decals_of(ArenaMarks.Kind.GASH)[0]
	marks.update(6.0 + ArenaMarks.FADE_FRAMES * 0.5)
	assert_lt(first.modulate.a, 0.9, "the first is fading")
	marks.update(10.0 + ArenaMarks.FADE_FRAMES)
	assert_eq(marks.count(), 4)
	assert_eq(marks.decals_of(ArenaMarks.Kind.GASH)[0].global_position.x, 2.0, "the newest stay")


func test_a_new_match_clears_them_and_off_draws_none() -> void:
	marks.on_event({"t": &"weaponStuck", "owner": 0, "pos": _vec(Vector3.ZERO)}, Callable(), effects, 1.0)
	marks.new_match()
	assert_eq(marks.count(), 0)
	marks.enabled = false
	marks.on_event({"t": &"weaponStuck", "owner": 0, "pos": _vec(Vector3.ZERO)}, Callable(), effects, 2.0)
	assert_eq(marks.count(), 0)


func test_the_presets_caps() -> void:
	var caps := {&"ultra": 96, &"high": 96, &"medium": 48, &"low": 24}
	for id: StringName in caps:
		var p: GraphicsPreset = GraphicsPreset.load_id(id)
		assert_eq(p.arena_marks, caps[id], String(id))
		marks.set_preset(p)
		assert_eq(marks.cap, caps[id])


func test_the_shrines_surfaces() -> void:
	var shrine := (load("res://arenas/moonlit_shrine/moonlit_shrine.tscn") as PackedScene).instantiate() as MoonlitShrine
	add_child_autofree(shrine)
	var s: Dictionary = shrine.reaction_surfaces()
	assert_almost_eq(float(s["wall_radius"]), shrine.def.wall_inner_radius(), 0.001)
	assert_almost_eq(float(s["wall_top"]), shrine.def.wall_height, 0.001)
	var pillars: PackedVector4Array = s["pillars"]
	assert_eq(pillars.size(), shrine.layout.pillars.size())
	for i: int in pillars.size():
		var node := shrine.find_child("Pillar%d" % i, true, false) as Node3D
		assert_not_null(node, "pillar %d" % i)
		assert_almost_eq(Vector2(pillars[i].x, pillars[i].y), Vector2(node.global_position.x, node.global_position.z), Vector2.ONE * 0.01)
	# the stone they land on carries the marks' layer, the fighters never
	var parapet := shrine.find_child("Parapet", true, false) as VisualInstance3D
	assert_ne(parapet.layers & LookPalette.MARKS_LAYER, 0, "the parapet takes marks")


## A seeded duel on the Shrine with the reactions on or off; [the state
## hash, the view].
func _duel(on: bool, frames: int) -> Array:
	var host: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	var view := host.get_node("View") as MatchView
	host.start(MatchConfig.make(MatchConfig.DUEL, MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"hard"), 23, &"moonlit_shrine"))
	view.arena_marks.enabled = on
	for i: int in frames:
		host.step(1)
		view.render(1.0 / 60.0)
	return [host.world.state_hash(), view]


func test_the_rules_are_identical_with_the_reactions_off() -> void:
	var on: Array = _duel(true, 3600)
	var off: Array = _duel(false, 3600)
	assert_eq(on[0], off[0], "the same match")
	assert_gt((on[1] as MatchView).arena_marks.count(), 0, "a minute's fight leaves marks")
	assert_eq((off[1] as MatchView).arena_marks.count(), 0)


# ------------------------------------------------------------------ the air (ArenaAir)

func _stir() -> FloorStir:
	return FloorStir.new()


func test_a_step_a_low_swing_and_a_fall_push_the_grass_for_about_a_second() -> void:
	var air := ArenaAir.new()
	var stir := _stir()
	stir.push(Vector3(1.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), 0.6, 1.5)
	stir.sweep(Vector3(0.0, 0.5, 0.0), Vector3(0.5, 0.2, 0.5), Vector3.ZERO, Vector3(4.0, 0.0, 0.0))
	stir.burst(Vector3(-2.0, 0.0, 0.0), 1.3, 2.4)
	air.take(stir, 10.0)
	assert_eq(air.alive(10.0).size(), 3)
	assert_eq(air.alive(10.0 + ArenaAir.LIFE + 0.01).size(), 0, "gone in about a second")
	# a walk leaves a trail, not a push a frame
	var walk := _stir()
	walk.push(Vector3(1.05, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), 0.6, 1.5)
	air.take(walk, 10.016)
	assert_eq(air.alive(10.016).size(), 3, "too close to the last")
	air.take(walk, 10.2)
	assert_eq(air.alive(10.2).size(), 4)
	# standing still pushes nothing
	var still := _stir()
	still.push(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, 0.4, 1.0)
	air.take(still, 11.0)
	assert_eq(air.alive(11.0).size(), 4)
	air.clear()
	assert_eq(air.alive(11.0).size(), 0)


func test_only_the_big_pushes_reach_the_banners() -> void:
	var stirrer := FloorStirrer.new()
	var at_of := func(_s: int) -> Vector3: return Vector3(14.0, 0.0, 0.0)
	stirrer.on_event({"t": &"ko", "loser": 0, "winner": 1}, at_of)
	stirrer.on_event({"t": &"ultBurst", "f": 0, "pos": {"x": 0.0, "y": 1.2, "z": 0.0}}, at_of)
	stirrer.on_event({"t": &"hit", "attacker": 0, "target": 1, "heavy": true}, at_of)
	var stir: FloorStir = stirrer.frame(0.016, [])
	var air: Dictionary = {}
	for b: FloorStir.Push in stir.bursts:
		air[b.radius] = b.air
	assert_gt(float(air[FloorStirrer.KO_BURST.x]), 4.0, "a K.O. near the wall")
	assert_gt(float(air[FloorStirrer.ULT_BURST.x]), 20.0, "an ultimate, across the arena")
	assert_eq(float(air[FloorStirrer.HEAVY_HIT_BURST.x]), FloorStirrer.HEAVY_HIT_BURST.x, "not a hit")


func test_moonsplitters_wave_sweeps_the_grass_from_launch_to_after_its_flight() -> void:
	var stirrer := FloorStirrer.new()
	var wave := SlashWave.new(null, &"horizontal", 0.0, -10.0, 0.0, 1.0)
	wave.s = 6.0
	var stir: FloorStir = stirrer.frame(0.016, [], [wave], 1.0)
	assert_eq(stir.fronts.size(), 1)
	assert_almost_eq(stir.fronts[0].s, 6.0, 0.001)
	var air := ArenaAir.new()
	air.take(stir, 20.0)
	var held: Array[Dictionary] = air.waves(20.0)
	assert_eq(held.size(), 1)
	assert_almost_eq(float(held[0]["launched"]), 20.0 - 6.0 / World.WAVE_SPEED, 0.001, "its front where the rules have it")
	assert_true(held[0]["horizontal"])
	wave.s = 12.0
	air.take(stirrer.frame(0.016, [], [wave], 1.0), 20.2)
	assert_eq(air.waves(20.2).size(), 1, "the same wave")
	assert_eq(air.waves(20.0 + World.WAVE_RANGE / World.WAVE_SPEED + ArenaAir.LIFE + 0.1).size(), 0)


func test_the_grass_and_banners_read_the_air() -> void:
	var code: String = (load("res://shaders/surface_sway.gdshader") as Shader).code
	assert_string_contains(code, "air_push.gdshaderinc")
	assert_string_contains(code, "air_push(")
	assert_true(ProjectSettings.has_setting("shader_globals/air_pushes"), "a global the arena sets")
	var shrine := (load("res://arenas/moonlit_shrine/moonlit_shrine.tscn") as PackedScene).instantiate() as MoonlitShrine
	add_child_autofree(shrine)
	var stir := _stir()
	stir.burst(Vector3.ZERO, 3.0, 4.0)
	shrine.stir_floor(stir)
	assert_eq(shrine.air.alive(shrine.layout.wind.time).size(), 1, "the Shrine's floor stir reaches its air")
