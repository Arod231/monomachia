extends GutTest
## Moonsplitter's wave on screen (MoonWave, milestone-1 task 100): each wave
## the rules hold stands where they put it on every frame, the vertical tall
## in its lane, the horizontal a low sheet across the whole arena; a light
## travels with it; it sheds mist and petals behind it once per rules frame;
## it goes when the rules' wave does.

const W_STEP: float = World.WAVE_SPEED * SimConst.DT


func after_each() -> void:
	SimHelpers.dispose_all()


func _waves() -> MoonWave:
	var m: MoonWave = MoonWave.new()
	add_child_autofree(m)
	return m


func _effects() -> CombatEffects:
	var fx: CombatEffects = CombatEffects.new()
	add_child_autofree(fx)
	return fx


static func _step(W: World) -> void:
	W.step([SimHelpers.idle(), SimHelpers.idle()])


func test_the_wave_stands_where_the_rules_put_it_on_every_frame() -> void:
	for kind: StringName in [&"vertical", &"horizontal"]:
		var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 9.0)
		var a: Fighter = W.fighters[0]
		a.yaw = 0.4
		W.spawn_wave(a, kind)
		var m: MoonWave = _waves()
		var seen: int = 0
		while not W.waves.is_empty() and seen < 200:
			var w: SlashWave = W.waves[0]
			for alpha: float in [0.0, 0.5, 1.0]:
				m.sync(W, alpha)
				assert_eq(m.shown(), 1, "%s: one wave on screen" % kind)
				var node: Node3D = m.node_of(w)
				var s: float = maxf(0.0, w.s - W_STEP * (1.0 - alpha))
				var want: Vector3 = Vector3(w.ox + w.dx * s, 0.0, w.oz + w.dz * s)
				var at: Vector3 = node.global_position
				assert_almost_eq(Vector2(at.x, at.z).distance_to(Vector2(want.x, want.z)), 0.0, 1e-4,
					"%s frame %d alpha %.1f: where the rules put it" % [kind, W.frame, alpha])
				var ahead: Vector3 = node.global_basis.z.normalized()
				assert_almost_eq(Vector2(ahead.x, ahead.z).dot(Vector2(w.dx, w.dz)), 1.0, 1e-4, "%s: facing the way it flies" % kind)
				var light: OmniLight3D = m.light_of(w)
				assert_almost_eq(light.global_position.distance_to(at + Vector3(0.0, light.position.y, 0.0)), 0.0, 1e-4, "its light travels with it")
			_step(W)
			seen += 1
		m.sync(W, 1.0)
		assert_eq(m.shown(), 0, "%s: gone with the rules' wave" % kind)
		assert_gt(seen, 10, "%s flew for a while" % kind)


func test_the_vertical_stands_tall_in_its_lane_and_the_horizontal_spans_the_arena_at_knee_height() -> void:
	var v: AABB = MoonWave.mesh_for(&"vertical").get_aabb()
	assert_gt(v.size.y, 2.2, "tall")
	assert_lte(v.size.x, 2.0 * 0.95 + 1e-3, "inside its lane (the rules' 0.95 m either side)")
	assert_gt(v.size.x, 1.0, "filling it")
	var h: AABB = MoonWave.mesh_for(&"horizontal").get_aabb()
	assert_gt(h.size.x, 4.0 * SimConst.ARENA_RADIUS, "across the whole arena, from wherever it starts")
	assert_lt(h.end.y, 1.0, "low")
	assert_gt(h.end.y, 0.4, "up to the knee")
	assert_gte(h.position.y, 0.0, "off the floor")


func test_it_fades_in_as_it_leaves_and_out_at_the_end_of_its_flight() -> void:
	assert_lt(MoonWave.fade(0.0), 0.2, "faint as it leaves the blade")
	assert_almost_eq(MoonWave.fade(5.0), 1.0, 1e-6, "whole in flight")
	assert_almost_eq(MoonWave.fade(World.WAVE_RANGE), 0.0, 1e-6, "gone at the end of its range")


func test_the_light_dims_under_reduce_flashes() -> void:
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 9.0)
	W.spawn_wave(W.fighters[0], &"vertical")
	for k: int in 6:
		_step(W)
	var m: MoonWave = _waves()
	m.sync(W, 1.0)
	var full: float = m.light_of(W.waves[0]).light_energy
	assert_gt(full, 0.5, "it lights the floor and the fighters")
	m.light_scale = CombatEffects.REDUCED_LIGHT
	m.sync(W, 1.0)
	assert_almost_eq(m.light_of(W.waves[0]).light_energy, full * CombatEffects.REDUCED_LIGHT, 1e-4)


func test_it_sheds_mist_and_petals_once_per_rules_frame() -> void:
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 9.0)
	var fx: CombatEffects = _effects()
	var m: MoonWave = _waves()
	m.shed(fx, W)
	assert_eq(fx._particles.size(), 0, "nothing with no wave")
	W.spawn_wave(W.fighters[0], &"horizontal")
	_step(W)
	m.shed(fx, W)
	var once: int = fx._particles.size()
	assert_gt(once, 0, "mist and petals behind it")
	m.shed(fx, W)
	assert_eq(fx._particles.size(), once, "a frame drawn again sheds nothing more")
	_step(W)
	_step(W)
	m.shed(fx, W)
	assert_gt(fx._particles.size(), once, "frames missed between draws shed too")
	# the same frame sheds the same
	var W2: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 9.0)
	W2.spawn_wave(W2.fighters[0], &"horizontal")
	var a: CombatEffects = _effects()
	var b: CombatEffects = _effects()
	MoonWave.shed_frame(a, W2.waves[0], W2.frame)
	MoonWave.shed_frame(b, W2.waves[0], W2.frame)
	assert_eq(a._particles.size(), b._particles.size())
	assert_eq(a._particles[0].p0, b._particles[0].p0, "scattered by the frame")
