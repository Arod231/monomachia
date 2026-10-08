extends GutTest
## The Shrine's fallen petals (milestone-1 task 137, ShrineFallenPetals):
## glowing lavender petals fall from the canopy into the arena on the wind,
## settle on the floor and build up into drifts over the match (cleared at a
## new match), and the fighters' steps, rolls, swings and blows push them
## about (FloorStir); picture only, thinned per preset.

const DT: float = 1.0 / 30.0

var def: ArenaDef = load("res://arenas/moonlit_shrine/moonlit_shrine.tres")
var layout: ShrineLayout = load("res://arenas/moonlit_shrine/moonlit_shrine_layout.tres")


func _petals() -> ShrineFallenPetals:
	var p: ShrineFallenPetals = ShrineFallenPetals.build(layout, def)
	autofree(p)
	return p


func _run(p: ShrineFallenPetals, seconds: float, stir: FloorStir = null) -> void:
	for i: int in roundi(seconds / DT):
		if stir != null:
			p.stir(stir)
		p.advance(DT)


## The settled petals within radius of at (level distance).
func _near(p: ShrineFallenPetals, at: Vector3, radius: float) -> int:
	var n: int = 0
	for q: Vector3 in p.settled_positions():
		if Vector2(q.x - at.x, q.z - at.z).length() < radius:
			n += 1
	return n


## A patch of count settled petals scattered within radius of centre, with
## no more falling.
func _patch(p: ShrineFallenPetals, centre: Vector3, radius: float, count: int) -> void:
	p.raining = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in count:
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * radius
		p.drop(centre + Vector3(cos(a) * r, 0.0, sin(a) * r))


func test_petals_fall_on_the_wind_and_settle_on_the_floor_inside_the_parapet() -> void:
	var p: ShrineFallenPetals = _petals()
	assert_eq(p.count(), 0, "a clean floor at first")
	_run(p, 6.0)
	assert_gt(p.falling_count(), 10, "petals falling into the arena")
	assert_eq(p.settled_count(), 0, "none down yet: they fall from the canopy")
	_run(p, 40.0)
	assert_gt(p.settled_count(), 150, "they settle and stay")
	for q: Vector3 in p.settled_positions():
		assert_lt(Vector2(q.x, q.z).length(), def.wall_inner_radius(), "on the floor inside the parapet")
		assert_between(q.y, 0.0, 0.03, "lying on the floor")


func test_the_cover_builds_over_the_rounds_into_drifts_and_clears_at_a_new_match() -> void:
	var p: ShrineFallenPetals = _petals()
	_run(p, 60.0)
	var round_one: int = p.settled_count()
	_run(p, 120.0)
	var round_three: int = p.settled_count()
	assert_between(round_one, 250, 700, "a light scatter by the end of round 1")
	assert_between(round_three, 1100, ShrineFallenPetals.MAX_PETALS, "drifts by round 3, about 1,500 at most")
	# drifts against the parapet: far more petals at its foot than its share
	# of the floor's area
	var foot: float = def.wall_inner_radius() - ShrineFallenPetals.DRIFT_DEPTH
	var at_foot: int = 0
	for q: Vector3 in p.settled_positions():
		if Vector2(q.x, q.z).length() > foot:
			at_foot += 1
	var area_share: float = 1.0 - pow(foot / def.wall_inner_radius(), 2.0)
	assert_gt(float(at_foot) / round_three, area_share * 2.0, "drifted against the parapet")
	p.clear()
	assert_eq(p.count(), 0, "a new match: a clean floor")
	assert_eq(p.multimesh.visible_instance_count, 0, "nothing drawn")


func test_the_cover_stops_at_its_cap_and_recycles_the_oldest_petals() -> void:
	var p: ShrineFallenPetals = _petals()
	_run(p, 400.0)
	assert_lte(p.count(), ShrineFallenPetals.MAX_PETALS, "never past the cap")
	assert_gt(p.falling_count(), 10, "and still falling")


func test_the_presets_thin_the_petals() -> void:
	var p: ShrineFallenPetals = _petals()
	p.set_ratio(0.3)
	assert_eq(p.cap(), roundi(ShrineFallenPetals.MAX_PETALS * 0.3))
	_run(p, 400.0)
	assert_lte(p.count(), p.cap(), "thinned")
	p.set_ratio(0.1)
	assert_lte(p.count(), p.cap(), "thinning again drops the extras")
	assert_eq(p.multimesh.visible_instance_count, p.count())
	for id: StringName in GraphicsPreset.IDS:
		assert_between(GraphicsPreset.load_id(id).floor_petal_ratio, 0.05, 1.0, "%s thins the floor's petals" % id)
	var low_preset: GraphicsPreset = GraphicsPreset.load_id(&"low")
	assert_lt(low_preset.floor_petal_ratio, GraphicsPreset.load_id(&"medium").floor_petal_ratio, "Low the thinnest")
	assert_eq(GraphicsPreset.load_id(&"high").floor_petal_ratio, 1.0, "High has them all")
	var low := ShrineFallenPetals.build(layout, def)
	autofree(low)
	GraphicsApplier.apply_to_tree(low_preset, low)
	assert_eq(low.cap(), roundi(ShrineFallenPetals.MAX_PETALS * low_preset.floor_petal_ratio), "the applier sets it")


func test_a_fighter_walking_through_pushes_the_petals_away() -> void:
	var p: ShrineFallenPetals = _petals()
	var centre := Vector3(2.0, 0.0, 1.0)
	_patch(p, centre, 1.2, 200)
	var before: int = _near(p, centre, 0.3)
	assert_gt(before, 5, "a patch to walk through")
	var walk := FloorStir.new()
	walk.push(centre, Vector3(2.0, 0.0, 0.0), 0.4, 1.0)
	_run(p, 0.2, walk)
	_run(p, 2.0)
	assert_lt(_near(p, centre, 0.3), before * 0.3, "pushed out of the fighter's way")
	assert_eq(p.count(), 200, "pushed, not removed")


func test_a_fighter_standing_still_leaves_them_be() -> void:
	var p: ShrineFallenPetals = _petals()
	var centre := Vector3(-3.0, 0.0, 0.0)
	_patch(p, centre, 1.0, 120)
	var before: PackedVector3Array = p.settled_positions()
	var stand := FloorStir.new()
	stand.push(centre, Vector3.ZERO, 0.4, 1.0)
	_run(p, 1.0, stand)
	assert_eq(p.settled_positions(), before, "nothing moved")


func test_a_roll_scatters_them_wider_than_a_walk() -> void:
	var walked: ShrineFallenPetals = _petals()
	var rolled: ShrineFallenPetals = _petals()
	var centre := Vector3(0.0, 0.0, -2.0)
	_patch(walked, centre, 2.0, 300)
	_patch(rolled, centre, 2.0, 300)
	var walk := FloorStir.new()
	walk.push(centre, Vector3(0.0, 0.0, 1.5), FloorStirrer.WALK_RADIUS, FloorStirrer.WALK_STRENGTH)
	var roll := FloorStir.new()
	roll.push(centre, Vector3(0.0, 0.0, 5.0), FloorStirrer.ROLL_RADIUS, FloorStirrer.ROLL_STRENGTH)
	_run(walked, 0.1, walk)
	_run(rolled, 0.1, roll)
	_run(walked, 2.0)
	_run(rolled, 2.0)
	assert_lt(_near(rolled, centre, 0.7), _near(walked, centre, 0.7), "a roll clears a wider patch")


func test_a_low_fast_swing_sweeps_them_and_a_high_one_doesnt() -> void:
	var low: ShrineFallenPetals = _petals()
	var high: ShrineFallenPetals = _petals()
	var centre := Vector3(4.0, 0.0, 4.0)
	_patch(low, centre, 1.0, 200)
	_patch(high, centre, 1.0, 200)
	var under := FloorStir.new()
	under.sweep(centre + Vector3(-0.5, 0.15, 0.0), centre + Vector3(0.5, 0.1, 0.0), Vector3(0.0, 0.0, 9.0), Vector3(0.0, 0.0, 12.0))
	var over := FloorStir.new()
	over.sweep(centre + Vector3(-0.5, 1.4, 0.0), centre + Vector3(0.5, 1.5, 0.0), Vector3(0.0, 0.0, 9.0), Vector3(0.0, 0.0, 12.0))
	var high_before: PackedVector3Array = high.settled_positions()
	_run(low, 0.1, under)
	_run(high, 0.1, over)
	_run(low, 2.0)
	assert_lt(_near(low, centre, 0.3), _near(high, centre, 0.3) * 0.5, "swept along the blade's path")
	assert_eq(high.settled_positions(), high_before, "a swing at the chest leaves the floor be")


func test_a_blow_bursts_them_away_from_where_it_lands() -> void:
	var p: ShrineFallenPetals = _petals()
	var centre := Vector3(-1.0, 0.0, 5.0)
	_patch(p, centre, 1.5, 250)
	var before: int = _near(p, centre, 0.5)
	var blow := FloorStir.new()
	blow.burst(centre, 1.2, 2.0)
	p.stir(blow)
	p.advance(DT)
	_run(p, 2.0)
	assert_lt(_near(p, centre, 0.5), before * 0.3, "blown clear")


func test_kicked_petals_flare_and_settle_back_to_a_soft_glow() -> void:
	var p: ShrineFallenPetals = _petals()
	var at := Vector3(1.0, 0.0, 1.0)
	var i: int = p.drop(at)
	_run(p, ShrineFallenPetals.SETTLE_GLOW_TIME + 1.0)
	assert_eq(p.glow(i), ShrineFallenPetals.SETTLED_GLOW, "dimmed to a soft glow once settled")
	var kick := FloorStir.new()
	kick.burst(at, 1.0, 2.0)
	p.stir(kick)
	p.advance(DT)
	assert_eq(p.glow(i), 1.0, "kicked up, it flares again")
	_run(p, 2.0)
	assert_between(p.glow(i), ShrineFallenPetals.SETTLED_GLOW, 1.0, "dimming again once down")


func test_at_match_point_the_floor_s_petals_turn_blood_red() -> void:
	var p: ShrineFallenPetals = _petals()
	p.set_doom(1.0)
	assert_eq(p.material().get_shader_parameter(&"doom"), 1.0, "the floor's petals turn with the canopy")
	p.set_doom(0.0)
	assert_eq(p.material().get_shader_parameter(&"doom"), 0.0)


func test_the_shrine_lays_them_on_its_floor_and_passes_on_the_stirring() -> void:
	var arena: MoonlitShrine = (load("res://arenas/moonlit_shrine/moonlit_shrine.tscn") as PackedScene).instantiate()
	add_child_autofree(arena)
	var p := arena.get_node("FallenPetals") as ShrineFallenPetals
	assert_not_null(p, "the Shrine's fallen petals")
	assert_true(p.multimesh.use_custom_data, "each petal carries its glow")
	assert_eq(p.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "glowing, they cast no shadow")
	var at := Vector3(0.0, 0.0, 3.0)
	_patch(p, at, 1.0, 80)
	var stir := FloorStir.new()
	stir.burst(at, 1.2, 2.0)
	arena.stir_floor(stir)
	arena.advance_floor(DT)
	_run(p, 2.0)
	assert_lt(_near(p, at, 0.4), 10, "the arena passes the match's stirring on")
	arena.set_match_point(true)
	arena._process(DOOM_STEP)
	assert_gt(float(p.material().get_shader_parameter(&"doom")), 0.0, "match point reaches the floor")
	arena.clear_floor()
	assert_eq(p.count(), 0, "a new match clears it")


const DOOM_STEP: float = 1.0


## A seeded computer-against-computer duel on the Shrine, in the match
## scene, its rules stepped and drawn frame by frame for `frames`; with the
## fallen petals or without them (thinned to none), and with a carpet of
## them laid across the middle of the floor first when `carpet` (so the
## fighters walk through some whichever way the duel goes). Returns [the
## world's state hash, the match view].
func _duel(petals: bool, frames: int, carpet: bool = false) -> Array:
	var host: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	var view := host.get_node("View") as MatchView
	host.start(MatchConfig.make(MatchConfig.DUEL, MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"), 11, &"moonlit_shrine"))
	var fallen := view.arena.get_node("FallenPetals") as ShrineFallenPetals
	fallen.set_ratio(1.0 if petals else 0.0)
	if carpet:
		_patch(fallen, Vector3(1.0, 0.0, 0.0), 4.5, 1200)
	for i: int in frames:
		host.step(1)
		view.render(1.0 / 60.0)
		(view.arena as MoonlitShrine).advance_floor(1.0 / 60.0)
	return [host.world.state_hash(), view]


func test_the_match_view_stirs_the_floor_and_a_new_match_clears_it() -> void:
	var got: Array = _duel(true, 1500, true)
	var view: MatchView = got[1]
	var fallen := view.arena.get_node("FallenPetals") as ShrineFallenPetals
	assert_gt(fallen.count(), 0, "petals lying in the arena")
	assert_gt(fallen.stirred_count(), 0, "the fighters stirred them")
	view.host.start(view.host.config)
	assert_eq(fallen.count(), 0, "a new match: a clean floor")


func test_a_seeded_match_plays_the_same_with_the_petals_on_or_off() -> void:
	var on: Array = _duel(true, 1500)
	var off: Array = _duel(false, 1500)
	assert_eq(on[0], off[0], "the petals never touch the rules")
	assert_eq(((off[1] as MatchView).arena.get_node("FallenPetals") as ShrineFallenPetals).count(), 0, "none drawn when off")
