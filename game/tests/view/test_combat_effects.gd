extends GutTest
## The combat effects layer (plan task 18.1; milestone-1 task 37): pooled
## flashes, rings, particles, sparks and puffs and the contact lights on the
## effect clock (the world's frame plus the host's alpha), the event table
## (sparks by outcome and weapon pair), the preset's particle counts and
## lights, Reduce flashes, and clearing at round start.

const DT: float = SimConst.DT

var effects: CombatEffects


func before_each() -> void:
	effects = CombatEffects.new()
	add_child_autofree(effects)


# ------------------------------------------------------------------ the pools on their own

func test_a_flash_grows_and_fades_over_its_life() -> void:
	effects.flash(Vector3(1.0, 1.2, 0.0), Color(1.0, 0.5, 0.25), 1.0, 10, 20.0)
	effects.update(20.0)
	var first: Dictionary = effects.flash_state(0)
	assert_eq(first["pos"], Vector3(1.0, 1.2, 0.0), "at the contact point")
	assert_almost_eq(float(first["alpha"]), 0.9, 1e-6, "bright when born")
	effects.update(25.0)
	var mid: Dictionary = effects.flash_state(0)
	assert_gt(float(mid["size"]), float(first["size"]), "it grows")
	assert_almost_eq(float(mid["alpha"]), 0.45, 1e-6, "and fades")
	effects.update(30.0)
	assert_eq(effects.flash_count(), 0, "gone at the end of its life")


func test_a_flash_born_after_the_clock_waits_at_its_start() -> void:
	effects.flash(Vector3.ZERO, Color.WHITE, 1.0, 10, 20.0)
	effects.update(19.0)
	assert_almost_eq(float(effects.flash_state(0)["alpha"]), 0.9, 1e-6, "an age below zero counts as zero")


func test_a_ring_widens_from_its_start_radius_to_its_end() -> void:
	effects.ring(Vector3(0.0, 1.0, 0.0), Color.WHITE, 0.2, 1.2, 12, 0.0)
	effects.update(0.0)
	assert_almost_eq(float(effects.ring_state(0)["radius"]), 0.2, 1e-6)
	effects.update(6.0)
	var r: float = float(effects.ring_state(0)["radius"])
	assert_gt(r, 0.2)
	assert_lt(r, 1.2)
	assert_true(effects.ring_state(0)["faces_camera"], "a ring with no normal faces the camera")
	effects.ring(Vector3.ZERO, Color.WHITE, 0.3, 2.6, 12, 0.0, 0.2, Vector3.UP)
	effects.update(6.0)
	assert_false(effects.ring_state(1)["faces_camera"], "a ground ring lies flat")
	effects.update(12.0)
	assert_eq(effects.ring_count(), 0)


func _spark_burst(count: int) -> Dictionary:
	return {"count": count, "color": Color(1.0, 0.7, 0.3), "size": 0.05, "life": 20, "speed": 4.0, "gravity": 9.8, "floor": 0.0}


func test_a_burst_is_the_same_from_the_same_seed() -> void:
	var other: CombatEffects = CombatEffects.new()
	add_child_autofree(other)
	effects.burst(Vector3(0.0, 1.2, 0.0), _spark_burst(12), 0.0, 77)
	other.burst(Vector3(0.0, 1.2, 0.0), _spark_burst(12), 0.0, 77)
	effects.update(5.5)
	other.update(5.5)
	assert_eq(effects.particle_count(), 12)
	for i: int in 12:
		assert_eq(effects.particle_state(i)["pos"], other.particle_state(i)["pos"], "particle %d" % i)
	other.clear()
	other.burst(Vector3(0.0, 1.2, 0.0), _spark_burst(12), 0.0, 78)
	other.update(5.5)
	assert_ne(effects.particle_state(0)["pos"], other.particle_state(0)["pos"], "another seed scatters differently")


func test_particles_fly_from_the_contact_fall_and_settle_on_the_floor() -> void:
	var at: Vector3 = Vector3(0.5, 1.2, -0.5)
	# at most 6 m/s, so even one thrown straight up lands within 1.4 s (84 frames)
	var spec: Dictionary = _spark_burst(30)
	spec["life"] = 90
	spec["life_jitter"] = 0.0
	effects.burst(at, spec, 0.0, 5)
	effects.update(0.0)
	for i: int in 30:
		assert_almost_eq(effects.particle_state(i)["pos"], at, Vector3.ONE * 1e-6, "born at the contact")
	effects.update(3.0)
	var moved: int = 0
	for i: int in 30:
		if (effects.particle_state(i)["pos"] as Vector3).distance_to(at) > 0.05:
			moved += 1
	assert_eq(moved, 30, "flying out")
	var lowest: float = INF
	for k: int in 86:
		effects.update(float(k))
		for i: int in 30:
			lowest = minf(lowest, (effects.particle_state(i)["pos"] as Vector3).y)
	assert_gte(lowest, 0.0, "never under the floor")
	var settled: Array[Vector3] = []
	for i: int in 30:
		var p: Vector3 = effects.particle_state(i)["pos"]
		assert_eq(p.y, 0.0, "landed")
		settled.append(p)
	effects.update(89.0)
	for i: int in 30:
		assert_eq(effects.particle_state(i)["pos"], settled[i], "a particle on the floor stays put")
	effects.update(90.0)
	assert_eq(effects.particle_count(), 0, "gone at the end of their life")


## Every preset keeps Ultra's particles (milestone-1 task 29: Low drops only
## atmosphere), so a made-up preset with fewer shows the scaling.
func _with_particles(ratio: float) -> GraphicsPreset:
	var p: GraphicsPreset = GraphicsPreset.ultra().duplicate() as GraphicsPreset
	p.particle_ratio = ratio
	return p


func test_particle_counts_follow_the_preset_dropping_at_most_by_half() -> void:
	for id: StringName in GraphicsPreset.IDS:
		effects.clear()
		effects.set_preset(GraphicsPreset.load_id(id))
		assert_eq(effects.burst(Vector3.ZERO, _spark_burst(40), 0.0, 1), 40, "%s draws them all" % id)
	var counts: Dictionary[float, int] = {}
	for ratio: float in [0.6, 0.3]:
		effects.clear()
		effects.set_preset(_with_particles(ratio))
		counts[ratio] = effects.burst(Vector3.ZERO, _spark_burst(40), 0.0, 1)
		assert_eq(effects.particle_count(), counts[ratio])
	assert_eq(counts[0.6], 24, "its ratio (0.6)")
	assert_eq(counts[0.3], 20, "half, not its ambient ratio (0.3)")
	effects.clear()
	assert_eq(effects.burst(Vector3.ZERO, _spark_burst(1), 0.0, 1), 1, "never rounded down to nothing")


func test_full_pools_drop_their_oldest_effects() -> void:
	for i: int in CombatEffects.FLASH_CAPACITY + 3:
		effects.flash(Vector3(float(i), 0.0, 0.0), Color.WHITE, 1.0, 100, float(i))
	effects.update(10.0)
	assert_eq(effects.flash_count(), CombatEffects.FLASH_CAPACITY)
	assert_eq(effects.flash_state(0)["pos"], Vector3(3.0, 0.0, 0.0), "the three oldest went")
	effects.burst(Vector3.ZERO, _spark_burst(CombatEffects.PARTICLE_CAPACITY + 10), 0.0, 1)
	assert_eq(effects.particle_count(), CombatEffects.PARTICLE_CAPACITY)


func test_the_pools_draw_only_what_lives() -> void:
	effects.flash(Vector3.ZERO, Color.WHITE, 1.0, 10, 0.0)
	effects.burst(Vector3.ZERO, _spark_burst(7), 0.0, 1)
	effects.update(1.0)
	assert_eq(effects.drawn(CombatEffects.FLASHES), 1)
	assert_eq(effects.drawn(CombatEffects.RINGS), 0)
	assert_eq(effects.drawn(CombatEffects.PARTICLES), 7)
	effects.clear()
	assert_eq(effects.drawn(CombatEffects.FLASHES), 0, "cleared at once")
	assert_eq(effects.drawn(CombatEffects.PARTICLES), 0)
	assert_eq(effects.get_child_count(), 12, "five pools, three lights and four smears, however many effects")


# ------------------------------------------------------------------ the table

const KATANAS: Dictionary = {"weapon": &"katana", "defender_weapon": &"katana"}
const AT: Dictionary = {"x": 0.0, "y": 1.2, "z": 0.0}


## An event of type `t` between two Katanas at AT, with `extra` fields.
func _event(t: StringName, extra: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"t": t, "pos": AT}
	e.merge(KATANAS)
	e.merge(extra, true)
	return e


func _kinds(e: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for fx: Dictionary in EffectTable.resolve(e):
		out.append(fx["kind"])
	return out


func _fx(e: Dictionary, kind: StringName) -> Dictionary:
	for fx: Dictionary in EffectTable.resolve(e):
		if fx["kind"] == kind:
			return fx
	return {}


## Sparks by outcome and weight, steel on steel (spec P39): a block a small
## spray, a heavy block more, a parry a shower with a white-hot point, a
## Flash a brighter, longer burst; each with its contact light.
func test_the_table_throws_sparks_by_outcome_and_weight() -> void:
	var block: Dictionary = _event(&"block", {"heavy": false})
	var heavy_block: Dictionary = _event(&"block", {"heavy": true})
	var parry: Dictionary = _event(&"parry", {"kind": &"parry"})
	var flash: Dictionary = _event(&"parry", {"kind": &"flash"})
	for e: Dictionary in [block, heavy_block, parry, flash]:
		assert_eq(_kinds(e), [EffectTable.FLASH, EffectTable.SPARKS, EffectTable.LIGHT] as Array[StringName],
			"%s %s: the hot point, the sparks and their light" % [e["t"], e.get("kind", "heavy" if e.get("heavy") else "light")])
	var counts: Array[int] = []
	for e: Dictionary in [block, heavy_block, parry, flash]:
		counts.append(EffectTable.count_of(e, EffectTable.SPARKS))
	assert_eq(counts, [12, 22, 30, 48] as Array[int], "more sparks from a block to a heavy block, a parry and a Flash")
	assert_gt(float(_fx(flash, EffectTable.SPARKS)["life"]), float(_fx(parry, EffectTable.SPARKS)["life"]), "a Flash's burst lasts longer")
	assert_gt(float(_fx(flash, EffectTable.FLASH)["size"]), float(_fx(parry, EffectTable.FLASH)["size"]), "and its point is bigger")
	assert_gt(float(_fx(parry, EffectTable.FLASH)["size"]), float(_fx(heavy_block, EffectTable.FLASH)["size"]), "a parry's white-hot point outshines a block's")
	var energies: Array[float] = []
	for e: Dictionary in [block, heavy_block, parry, flash]:
		energies.append(float(_fx(e, EffectTable.LIGHT)["energy"]))
	for i: int in 3:
		assert_lt(energies[i], energies[i + 1], "each lights brighter than the last")
	assert_eq(_fx(parry, EffectTable.SPARKS)["aim"], EffectTable.AIM_SWEEP, "a parry's sparks fly along the parried blade")
	assert_eq(_fx(block, EffectTable.SPARKS)["aim"], EffectTable.AIM_OFF_GUARD, "a block's off the guard")


## Steel on steel only: a redirect, or a bare hand on a blade, throws a dull
## puff and no sparks; a hit throws nothing (blood covers it).
func test_bare_hands_puff_and_hits_throw_nothing() -> void:
	var fist_block: Dictionary = _event(&"block", {"weapon": &"fists", "defender_weapon": &"katana"})
	var fist_parried: Dictionary = _event(&"parry", {"kind": &"parry", "weapon": &"fists", "defender_weapon": &"katana"})
	var redirect: Dictionary = _event(&"parry", {"kind": &"redirect", "weapon": &"katana", "defender_weapon": &"fists"})
	for e: Dictionary in [fist_block, fist_parried, redirect]:
		assert_eq(_kinds(e), [EffectTable.PUFF] as Array[StringName], "%s: a puff" % e.get("kind", e["t"]))
		assert_eq(EffectTable.count_of(e, EffectTable.SPARKS), 0, "no sparks")
	assert_eq(_kinds(_event(&"parry", {"kind": &"redirect"})), [EffectTable.PUFF] as Array[StringName], "a redirect never sparks")
	assert_false(EffectTable.has(&"hit"), "a hit throws nothing: blood covers it")
	assert_eq(EffectTable.resolve(_event(&"hit", {"heavy": true, "sound": &"blade"})).size(), 0)
	# the other pairs are steel too until milestone 2 brings their weapons
	assert_eq(EffectTable.count_of(_event(&"block", {"weapon": &"greatsword"}), EffectTable.SPARKS), 12)
	assert_eq(EffectTable.count_of({"t": &"block", "pos": AT}, EffectTable.SPARKS), 12, "an event naming no weapons counts as steel")


func test_the_counter_and_disarm_keep_their_flashes_for_now() -> void:
	assert_eq(EffectTable.resolve({"t": &"counter"})[0]["life"], 16)
	assert_eq(EffectTable.resolve({"t": &"disarm"})[0]["size"], 1.3)
	assert_eq(EffectTable.resolve({"t": &"swing"}).size(), 0, "an event the table doesn't list spawns nothing")


func test_an_event_spawns_its_table_effects_at_its_contact_point() -> void:
	effects.on_event(_event(&"block", {"heavy": true, "pos": {"x": 1.0, "y": 1.3, "z": 2.0}}), 40)
	effects.update(40.0)
	assert_eq(effects.flash_count(), 1, "the hot point")
	assert_eq(effects.flash_state(0)["pos"], Vector3(1.0, 1.3, 2.0))
	assert_eq(effects.spark_count(), 22)
	assert_eq(effects.light_count(), 1)
	assert_eq(effects.light_state(0)["pos"], Vector3(1.0, 1.3, 2.0))
	effects.on_event({"t": &"block", "heavy": true}, 41)
	assert_eq(effects.flash_count(), 1, "an event without a contact point spawns nothing")
	effects.on_event(_event(&"parry", {"kind": &"redirect", "defender_weapon": &"fists"}), 42)
	effects.update(42.0)
	assert_gt(effects.puff_count(), 0, "a redirect's puff")


# ------------------------------------------------------------------ sparks, puffs and lights

func _sparks_from(at: Vector3, dir: Vector3, count: int = 30, seed: int = 9) -> void:
	effects.sparks(at, dir, {"count": count, "speed": 5.5, "spread": 40.0, "life": 16}, 0.0, seed)


## Sparks leave the contact along the throw's direction, streak along their
## flight, cool from white-yellow to red, fall and die on the stone.
func test_sparks_streak_along_their_flight_cool_fall_and_die_on_the_floor() -> void:
	var at: Vector3 = Vector3(0.0, 1.3, 0.0)
	_sparks_from(at, Vector3.RIGHT)
	# shown on the contact's own frame (held through its hit-stop), the burst
	# is already leaving the steel
	effects.update(0.0)
	for i: int in effects.spark_count():
		var st0: Dictionary = effects.spark_state(i)
		assert_gt((st0["pos"] + (st0["streak"] as Vector3) * 0.5 - at).length(), 0.02, "spark %d already flying" % i)
	effects.update(2.0)
	var right: int = 0
	for i: int in effects.spark_count():
		var st: Dictionary = effects.spark_state(i)
		var head: Vector3 = st["pos"] + (st["streak"] as Vector3) * 0.5
		if head.x - at.x > 0.03:
			right += 1
		var flight: Vector3 = (head - at).normalized()
		assert_gt((st["streak"] as Vector3).normalized().dot(flight), 0.8, "spark %d streaks along its flight" % i)
		assert_gt((st["streak"] as Vector3).length(), CombatEffects.SPARK_WIDTH, "a streak, not a dot, in flight")
	assert_eq(right, 30, "every spark thrown toward the throw")
	var hot: Color = effects.spark_state(0)["color"]
	effects.update(13.0)
	var cooler: Color = effects.spark_state(0)["color"]
	assert_gt(hot.g, cooler.g, "it cools toward orange and red")
	assert_lt(cooler.a, hot.a, "and fades")
	# thrown sideways from 1.3 m, each lands within about half a second
	var lowest: float = INF
	for k: int in 40:
		effects.update(float(k))
		for i: int in effects.spark_count():
			lowest = minf(lowest, (effects.spark_state(i)["pos"] as Vector3).y - absf((effects.spark_state(i)["streak"] as Vector3).y) * 0.5)
	assert_gte(lowest, -1e-4, "never under the floor")
	effects.update(40.0)
	assert_eq(effects.spark_count(), 0, "all dead on the stone")
	assert_eq(effects.drawn(CombatEffects.SPARKS), 0)


func test_sparks_are_the_same_from_the_same_seed_and_follow_the_preset() -> void:
	var other: CombatEffects = CombatEffects.new()
	add_child_autofree(other)
	_sparks_from(Vector3(0.0, 1.2, 0.0), Vector3.UP, 20, 4)
	other.sparks(Vector3(0.0, 1.2, 0.0), Vector3.UP, {"count": 20, "speed": 5.5, "spread": 40.0, "life": 16}, 0.0, 4)
	effects.update(3.5)
	other.update(3.5)
	for i: int in 20:
		assert_eq(effects.spark_state(i)["pos"], other.spark_state(i)["pos"], "spark %d" % i)
	effects.clear()
	effects.set_preset(_with_particles(0.3))
	assert_eq(effects.sparks(Vector3.ZERO, Vector3.UP, {"count": 40}, 0.0, 1), 20, "half on a preset with fewer particles")
	effects.clear()
	effects.set_preset(GraphicsPreset.ultra())
	effects.sparks(Vector3.ZERO, Vector3.UP, {"count": CombatEffects.SPARK_CAPACITY + 5}, 0.0, 1)
	assert_eq(effects.spark_count(), CombatEffects.SPARK_CAPACITY, "the pool keeps its newest")


## Reduce flashes (18.11) dims the sparks with the flashes and halves the
## contact light.
func test_reduce_flashes_dims_the_sparks_and_halves_the_light() -> void:
	_sparks_from(Vector3(0.0, 1.2, 0.0), Vector3.UP, 1)
	effects.contact_light(Vector3(0.0, 1.2, 0.0), 2.0, 3.0, 6, 0.0)
	effects.update(0.0)
	var full: float = effects.light_state(0)["energy"]
	assert_almost_eq(full, 2.0, 1e-6, "its peak at the contact")
	effects.flash_scale = 0.35
	effects.light_scale = CombatEffects.REDUCED_LIGHT
	effects.update(0.0)
	assert_almost_eq(float(effects.light_state(0)["energy"]), full * 0.5, 1e-6, "halved")
	assert_eq(CombatEffects.REDUCED_LIGHT, 0.5)


## A contact light lights the fighters and blades for a few frames, fading,
## on the presets that allow it (Ultra and High); three at most.
func test_a_contact_light_fades_over_its_life_where_the_preset_allows() -> void:
	effects.set_preset(GraphicsPreset.load_id(&"ultra"))
	effects.contact_light(Vector3(1.0, 1.2, 0.0), 2.0, 3.0, 6, 10.0)
	effects.update(10.0)
	assert_eq(effects.lights_shown(), 1, "lit at the contact")
	var node: OmniLight3D = effects.light_nodes()[0]
	assert_eq(node.position, Vector3(1.0, 1.2, 0.0))
	assert_almost_eq(node.light_energy, 2.0, 1e-6)
	assert_almost_eq(node.omni_range, 3.0, 1e-6)
	assert_false(node.shadow_enabled, "no shadow: a flicker of light, not a lamp")
	effects.update(13.0)
	assert_lt(node.light_energy, 1.0, "fading")
	effects.update(16.0)
	assert_eq(effects.lights_shown(), 0, "gone at the end of its life")
	for id: StringName in GraphicsPreset.IDS:
		effects.clear()
		effects.set_preset(GraphicsPreset.load_id(id))
		effects.contact_light(Vector3.ZERO, 1.0, 2.0, 6, 0.0)
		effects.update(0.0)
		assert_eq(effects.lights_shown(), 1 if id == &"ultra" or id == &"high" else 0, "%s's contact light" % id)
	effects.clear()
	effects.set_preset(GraphicsPreset.ultra())
	for k: int in 5:
		effects.contact_light(Vector3(float(k), 1.0, 0.0), 1.0, 2.0, 6, 0.0)
	effects.update(0.0)
	assert_eq(effects.lights_shown(), CombatEffects.LIGHT_CAPACITY, "three at most")
	assert_eq(effects.light_nodes()[0].position, Vector3(4.0, 1.0, 0.0), "the newest shows")


func test_a_puff_drifts_grows_and_thins_out_dull() -> void:
	effects.puff(Vector3(0.0, 1.2, 0.0), {"count": 6, "size": 0.16, "life": 22}, 0.0, 3)
	effects.update(2.0)
	var early: Dictionary = effects.puff_state(0)
	effects.update(14.0)
	var late: Dictionary = effects.puff_state(0)
	assert_gt(float(late["size"]), float(early["size"]), "it grows")
	assert_lt((late["color"] as Color).a, (early["color"] as Color).a, "and thins out")
	assert_lt((late["pos"] as Vector3).distance_to(Vector3(0.0, 1.2, 0.0)), 0.5, "drifting slowly")
	var dust: Color = early["color"]
	assert_lt(maxf(dust.r, maxf(dust.g, dust.b)), 0.6, "dull, no glow")
	assert_lt(dust.s, 0.3, "grey-brown")
	effects.update(30.0)
	assert_eq(effects.puff_count(), 0)


func test_the_sparks_pool_draws_streaks_and_the_puffs_soft_clouds() -> void:
	_sparks_from(Vector3(0.0, 1.2, 0.0), Vector3.UP, 5)
	effects.puff(Vector3.ZERO, {"count": 3}, 0.0, 1)
	effects.update(1.0)
	assert_eq(effects.drawn(CombatEffects.SPARKS), 5)
	assert_eq(effects.drawn(CombatEffects.PUFFS), 3)
	var sparks: MultiMeshInstance3D = effects.get_node(String(CombatEffects.SPARKS))
	var code: String = (sparks.material_override as ShaderMaterial).shader.code
	assert_true(code.contains("blend_add"), "sparks glow")
	var puffs: MultiMeshInstance3D = effects.get_node(String(CombatEffects.PUFFS))
	assert_true((puffs.material_override as ShaderMaterial).shader.code.contains("blend_mix"), "a puff is dull dust")
	effects.clear()
	assert_eq(effects.drawn(CombatEffects.SPARKS), 0)
	assert_eq(effects.drawn(CombatEffects.PUFFS), 0)
	assert_eq(effects.lights_shown(), 0)


# ------------------------------------------------------------------ in the match, on its clock

var host: MatchHost
var view: MatchView


func _start_match() -> void:
	host = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	view = host.get_node("View")
	# Training: the player stands still with no input and the dummy stands
	# idle, so nothing but the test moves the clock's hit-stop or slow motion
	var cfg: MatchConfig = MatchConfig.default_training(3)
	cfg.arena_id = ArenaScenes.STANDIN
	host.start(cfg)
	host.step(Match.INTRO_FRAMES + 5)


func _parry_at_centre() -> void:
	host.sim_event.emit({"t": &"parry", "parrier": 1, "attacker": 0, "kind": &"parry", "pos": {"x": 0.0, "y": 1.25, "z": 0.0}})


func _age() -> float:
	return view.effects.clock() - view.effects.flash_state(0)["born"]


func test_the_view_owns_one_effects_layer_bound_to_its_host() -> void:
	_start_match()
	assert_not_null(view.effects)
	assert_eq(view.effects.host, host)
	assert_eq(view.effects.get_parent(), view)


func test_the_effect_clock_is_the_frame_shown() -> void:
	_start_match()
	host.advance(DT * 0.5)
	var shown: float = float(host.world.frame) - 1.0 + host.alpha()
	assert_almost_eq(view.effects.clock(), shown, 1e-6, "the world frame before the last step plus the host's alpha")


func test_a_contact_flash_holds_through_its_hit_stop() -> void:
	_start_match()
	host.world.hitstop = 10
	_parry_at_centre()
	view.render(0.0)
	var start_size: float = view.effects.flash_state(0)["size"]
	host.step(10)
	view.render(0.0)
	assert_eq(host.world.hitstop, 0)
	assert_almost_eq(float(view.effects.flash_state(0)["size"]), start_size, 1e-6, "frozen with the rules")
	host.step(5)
	view.render(0.0)
	assert_gt(float(view.effects.flash_state(0)["size"]), start_size, "and grows once the frame moves")


func test_effects_stand_still_while_paused() -> void:
	_start_match()
	_parry_at_centre()
	for k: int in 3:
		host.advance(DT)
	view.render(0.0)
	host.pause()
	var age: float = _age()
	var size: float = view.effects.flash_state(0)["size"]
	for k: int in 10:
		host.advance(DT)
		view.render(DT)
	assert_almost_eq(_age(), age, 1e-6, "no older while paused")
	assert_almost_eq(float(view.effects.flash_state(0)["size"]), size, 1e-6)


func test_effects_run_at_0_3x_in_the_ko_slow_motion() -> void:
	_start_match()
	host.world.request_slowmo(200, 0.3)
	view.effects.flash(Vector3(0.0, 1.25, 0.0), Color.WHITE, 0.3, 40, float(host.world.frame))
	view.render(0.0)
	var age: float = _age()
	for k: int in 20:
		host.advance(DT)
	view.render(0.0)
	assert_almost_eq(_age() - age, 6.0, 1.0, "20 frames of wall time age it about 6 frames")


func test_round_start_clears_the_effects() -> void:
	_start_match()
	_parry_at_centre()
	view.effects.burst(Vector3.ZERO, _spark_burst(10), float(host.world.frame), 1)
	view.render(0.0)
	assert_eq(view.effects.flash_count(), 1)
	host.sim_event.emit({"t": &"roundStart", "round": 2})
	assert_eq(view.effects.flash_count(), 0)
	assert_eq(view.effects.particle_count(), 0)


func test_a_preset_applied_to_the_tree_reaches_the_effects() -> void:
	GraphicsApplier.apply_to_tree(_with_particles(0.3), effects)
	assert_eq(effects.particle_scale, 0.5)
	GraphicsApplier.apply_to_tree(GraphicsPreset.load_id(&"low"), effects)
	assert_eq(effects.particle_scale, 1.0)
