extends GutTest
## One wind (milestone-1 task 52, Wind): the Shrine's night has one wind, a
## steady breeze with soft gusts rolling downwind, and everything the wind
## moves reads it: the clouds, the wisteria's branches and racemes, the
## falling and fallen petals, the embers and ash, the grass, the banners, the
## mist and the fighters' scarf and sageo. Presentation only: a seeded match
## plays the same whatever the wind.

const SCENE := "res://arenas/moonlit_shrine/moonlit_shrine.tscn"
const WIND_INCLUDE := "res://shaders/wind.gdshaderinc"

var arena: MoonlitShrine


func before_all() -> void:
	arena = (load(SCENE) as PackedScene).instantiate()
	add_child(arena)


func after_all() -> void:
	arena.free()


func after_each() -> void:
	# a test that blew its own wind leaves the arena's
	Wind.active = arena.layout.wind if is_instance_valid(arena) else null


func _reads_the_wind(m: Material, what: String) -> void:
	var sm := m as ShaderMaterial
	assert_not_null(sm, "%s is a shader" % what)
	if sm != null:
		assert_true(sm.shader.code.contains(WIND_INCLUDE) or _includes_wind(sm.shader.code), "%s reads the one wind" % what)


## Whether code includes a shader include that itself includes the wind.
func _includes_wind(code: String) -> bool:
	for line: String in code.split("\n"):
		if line.begins_with("#include"):
			var path: String = line.get_slice("\"", 1)
			var inner: String = FileAccess.get_file_as_string(path)
			if inner.contains(WIND_INCLUDE) or _includes_wind(inner):
				return true
	return false


# ------------------------------------------------------------------ the wind

func test_a_steady_breeze_with_soft_gusts() -> void:
	var w := Wind.new()
	var lowest: float = INF
	var highest: float = -INF
	for k: int in 400:
		var g: float = w.gust_at(Vector3(k * 0.7, 0.0, k * 0.3), k * 0.13)
		lowest = minf(lowest, g)
		highest = maxf(highest, g)
	assert_almost_eq(lowest, 1.0 - Wind.LULL, 0.05, "easing a little between gusts")
	assert_between(highest, 1.0 + w.gust * 0.85, 1.0 + w.gust + 0.001, "lifting by up to the gust")
	assert_almost_eq(w.velocity().length(), w.speed, 0.0001, "the breeze")
	var at := Vector3(3.0, 1.0, -2.0)
	assert_almost_eq(w.at(at, 2.0), w.velocity() * w.gust_at(at, 2.0), Vector2.ONE * 0.0001)


## A gust front rolls downwind: where the wind blows strongest now, it blows
## strongest a little downwind a moment later.
func test_the_gusts_roll_downwind() -> void:
	var w := Wind.new()
	var dir := Vector3(w.direction.x, 0.0, w.direction.y).normalized()
	var peak_at: float = 0.0
	var best: float = -INF
	for k: int in 140:
		var s: float = k * 0.1
		var g: float = w.gust_at(dir * s, 0.0)
		if g > best:
			best = g
			peak_at = s
	var later: float = 0.5
	var moved: float = w.gust_spacing / w.gust_period * later
	assert_almost_eq(w.gust_at(dir * (peak_at + moved), later), best, 0.01, "the front, carried downwind")


func test_its_clock_and_its_shader_globals() -> void:
	var w := Wind.new()
	w.advance(1.5)
	w.advance(0.5)
	assert_almost_eq(w.time, 2.0, 0.0001)
	var globals: Dictionary = w.shader_globals()
	assert_eq(globals[Wind.GLOBAL_WIND], Vector4(w.direction.normalized().x, w.direction.normalized().y, w.speed, w.gust))
	assert_eq(globals[Wind.GLOBAL_SHAPE], Vector2(w.gust_period, w.gust_spacing))
	assert_eq(globals[Wind.GLOBAL_TIME], 2.0)
	for key: StringName in globals:
		assert_true(ProjectSettings.has_setting("shader_globals/%s" % key), "%s is a global uniform" % key)


## The shaders' gust is the script's: the same lull, fronts and ripple.
func test_the_shaders_gust_mirrors_the_scripts() -> void:
	var code: String = FileAccess.get_file_as_string(WIND_INCLUDE)
	assert_true(code.contains("WIND_LULL = %s" % str(Wind.LULL)), "the lull")
	assert_true(code.contains("pow(0.5 + 0.5 * sin(6.2831853 * phase), 4.0)"), "the fronts")
	assert_true(code.contains("phase * 2.37 + 0.31"), "the ripple")
	var script: String = (load("res://view/look/wind.gd") as Script).source_code
	assert_true(script.contains("pow(0.5 + 0.5 * sin(TAU * phase), 4.0)"))
	assert_true(script.contains("phase * 2.37 + 0.31"))


# ------------------------------------------------------------------ the readers

func test_the_shrines_wind_is_the_layouts_and_everyones() -> void:
	assert_true(arena.layout.wind is Wind)
	assert_eq(Wind.active, arena.layout.wind, "the fighters' springs feel it too")


func test_the_clouds_and_mist_drift_on_it() -> void:
	for part: String in ["World/CloudSea", "World/CloudVeil", "World/CloudVolume"]:
		_reads_the_wind((arena.get_node(part) as GeometryInstance3D).material_override, part)
	_reads_the_wind((arena.get_node("MistBanks") as FogVolume).material, "the mist banks")


func test_the_grass_and_banners_sway_on_it() -> void:
	var banners: Array[Node] = arena.find_children("Cloth", "MeshInstance3D", true, false)
	assert_gt(banners.size(), 0)
	for cloth: Node in banners:
		_reads_the_wind((cloth as MeshInstance3D).get_active_material(0), "%s's cloth" % cloth.get_parent().name)
	var grass: Array[Node] = arena.find_child("Grass", true, false).find_children("*", "MultiMeshInstance3D", true, false)
	assert_gt(grass.size(), 0)
	for tufts: Node in grass:
		_reads_the_wind((tufts as GeometryInstance3D).material_override, "the grass")


## The racemes and the outer branches sway; the trunk and thick limbs keep
## still (their sway grows from nothing near the trunk's axis).
func test_the_wisterias_branches_and_racemes_sway_on_it() -> void:
	var grove: Node = arena.find_child("Wisteria", true, false)
	var bark: Array[Node] = grove.find_children("*_Bark", "MeshInstance3D", true, false)
	var blossoms: Array[Node] = grove.find_children("*_Blossom", "MeshInstance3D", true, false)
	assert_gt(bark.size(), 0)
	assert_gt(blossoms.size(), 0)
	_reads_the_wind((bark[0] as MeshInstance3D).material_override, "the bark")
	_reads_the_wind((blossoms[0] as MeshInstance3D).material_override, "the racemes")
	var m := (bark[0] as MeshInstance3D).material_override as ShaderMaterial
	assert_true(LookMaterials.is_physical(m), "the bark stays a look surface")
	var sway: String = FileAccess.get_file_as_string("res://shaders/wisteria_sway.gdshaderinc")
	assert_true(sway.contains("smoothstep(branch_from, branch_to, length(at.xz))"), "still at the trunk, free at the tips")


func test_the_petals_embers_and_ash_ride_it() -> void:
	var breeze: Vector2 = arena.layout.wind.velocity()
	var fallen := arena.get_node("FallenPetals") as ShrineFallenPetals
	assert_eq(fallen.wind(), arena.layout.wind, "the fallen petals ride it, gusts and all")
	var grove: Node = arena.find_child("Wisteria", true, false)
	var falling: Array[Node] = grove.find_children("Petals*", "GPUParticles3D", false, false)
	assert_gt(falling.size(), 0)
	for p: Node in falling:
		var d: Vector3 = ((p as GPUParticles3D).process_material as ParticleProcessMaterial).direction
		assert_almost_eq(Vector2(d.x, d.z).normalized(), breeze.normalized(), Vector2.ONE * 0.001, "%s fall downwind" % p.name)
	for p: Node in arena.get_node("Particles").find_children("*", "GPUParticles3D", true, false):
		var m := (p as GPUParticles3D).process_material as ParticleProcessMaterial
		var v: Vector3 = m.direction.normalized() * (m.initial_velocity_min + m.initial_velocity_max) * 0.5
		assert_almost_eq(Vector2(v.x, v.z), breeze, Vector2.ONE * 0.01, "%s drift at the breeze" % p.name)


## The scarf's tails lean downwind with the wind (and the sageo stirs a
## little less), more in a stronger wind.
func test_the_scarf_and_sageo_lean_downwind() -> void:
	var f: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	f.autoplay_idle = false
	add_child_autofree(f)
	assert_not_null(f.scarf_springs, "the Hunter's scarf has its springs")
	var gale := Wind.new()
	gale.direction = Vector2(1.0, 0.0)
	gale.speed = 1.0
	gale.gust = 0.0
	Wind.active = gale
	f._process(0.016)
	var lean: Vector3 = f.scarf_springs.get_gravity_direction(0)
	assert_gt(lean.x, 0.5, "the tails trail visibly downwind")
	assert_lt(lean.y, 0.0, "and still hang")
	var saya: Saya = Saya.build(Color.RED)
	add_child_autofree(saya)
	saya._process(0.016)
	var stir: Vector3 = saya.springs.get_gravity_direction(0)
	assert_gt(stir.x, 0.05, "the sageo stirs")
	assert_lt(stir.x, lean.x, "less than the scarf")
	gale.speed = 2.0
	f._process(0.016)
	assert_gt(f.scarf_springs.get_gravity_direction(0).x, lean.x, "more in a stronger wind")


# ------------------------------------------------------------------ the rules

## A seeded computer-against-computer duel on the Shrine, stepped and drawn
## frame by frame in a wind blowing toward direction at speed with gust.
## Returns the world's state hash. The layout is shared: its wind is put
## back after.
func _duel(direction: Vector2, speed: float, gust: float, frames: int) -> String:
	var host: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	var view := host.get_node("View") as MatchView
	host.start(MatchConfig.make(MatchConfig.DUEL, MatchSide.computer(&"hunter", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"katana", 1, &"hard"), 11, &"moonlit_shrine"))
	var shrine := view.arena as MoonlitShrine
	var wind: Wind = shrine.layout.wind
	var saved: Array = [wind.direction, wind.speed, wind.gust]
	wind.direction = direction
	wind.speed = speed
	wind.gust = gust
	wind.apply()
	for i: int in frames:
		host.step(1)
		view.render(1.0 / 60.0)
		wind.advance(1.0 / 60.0)
		shrine.advance_floor(1.0 / 60.0)
	var hash: String = host.world.state_hash()
	wind.direction = saved[0]
	wind.speed = saved[1]
	wind.gust = saved[2]
	wind.apply()
	return hash


func test_a_seeded_match_plays_the_same_whatever_the_wind() -> void:
	var calm := Wind.new()
	var breeze: String = _duel(calm.direction, calm.speed, calm.gust, 1200)
	var gale: String = _duel(Vector2(0.3, 0.95), 6.0, 1.5, 1200)
	assert_eq(breeze, gale, "the wind never touches the rules")
