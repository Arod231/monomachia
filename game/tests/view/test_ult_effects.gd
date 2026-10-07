extends GutTest
## The disarmed ultimate's effects (UltEffects, milestone-1 task 100): the
## choice's heat haze and lifted petals, Breaker Palm's pale-gold flash and
## ring of distortion, and the recall burst's larger ring; under Reduce
## flashes their flashes dimmed (CombatEffects.flash_scale) and slowed
## (flash_slow).


func after_each() -> void:
	SimHelpers.dispose_all()


func _effects() -> CombatEffects:
	var fx: CombatEffects = CombatEffects.new()
	add_child_autofree(fx)
	return fx


static func _step(W: World) -> void:
	W.step([SimHelpers.idle(), SimHelpers.idle()])


static func _palm_hit(frame: int) -> Dictionary:
	return {"t": &"hit", "attacker": 0, "target": 1, "attack": &"f_breaker", "heavy": true, "sound": &"fist",
		"pos": {"x": 0.0, "y": 1.3, "z": 1.0}, "f": frame}


func test_the_choice_lifts_haze_and_petals_once_per_rules_frame_only_while_choosing() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var fx: CombatEffects = _effects()
	var ult: UltEffects = UltEffects.new()
	ult.feed(fx, 0, f)
	_step(W)
	ult.feed(fx, 0, f)
	assert_eq(fx._particles.size(), 0, "nothing outside the choice")
	f.armed = false
	f.set_state(&"ultChoice", SimConst.ULT_CHOICE_FRAMES)
	_step(W)
	ult.feed(fx, 0, f)
	var once: int = fx._particles.size()
	assert_gt(once, 0, "haze and petals")
	var lifted: int = 0
	for p: CombatEffects.Particle in fx._particles:
		if p.v.y > 0.0:
			lifted += 1
	assert_gt(lifted, 0, "lifted off the ground")
	ult.feed(fx, 0, f)
	assert_eq(fx._particles.size(), once, "a frame drawn again throws nothing more")


func test_breaker_palm_s_blow_flashes_pale_gold_with_a_ring_of_distortion() -> void:
	var fx: CombatEffects = _effects()
	assert_true(UltEffects.on_event(fx, _palm_hit(30), 30), "its hit")
	assert_gt(fx.flash_count(), 0, "a flash")
	var gold: Color = fx._flashes[0].color
	assert_gt(gold.r, gold.b, "pale gold")
	assert_gt(gold.g, gold.b)
	assert_eq(fx.distortion_count(), 1, "a ring of distortion")
	var d: Dictionary = fx.distortion_state(0)
	assert_almost_eq((d["pos"] as Vector3).distance_to(Vector3(0.0, 1.3, 1.0)), 0.0, 1e-6, "at the contact")
	assert_false(UltEffects.on_event(_effects(), {"t": &"hit", "attack": &"f_dh", "pos": {"x": 0.0, "y": 1.0, "z": 0.0}}, 1),
		"any other blow is the table's")


func test_reduce_flashes_dims_and_slows_its_flash() -> void:
	var fx: CombatEffects = _effects()
	UltEffects.on_event(fx, _palm_hit(30), 30)
	var life: float = fx._flashes[0].life
	var slow: CombatEffects = _effects()
	slow.flash_scale = 0.4
	slow.flash_slow = CombatEffects.REDUCED_SLOW
	UltEffects.on_event(slow, _palm_hit(30), 30)
	assert_almost_eq(slow._flashes[0].life, life * CombatEffects.REDUCED_SLOW, 1.0, "slowed")
	slow.update(31.0)
	fx.update(31.0)
	assert_lt(float(slow.flash_state(0)["alpha"]) * slow.flash_scale, float(fx.flash_state(0)["alpha"]), "dimmed")


func test_the_recall_burst_s_ring_is_larger() -> void:
	var fx: CombatEffects = _effects()
	var reach: float = 2.5
	RecallAura.burst(fx, {"t": &"recallBurst", "f": 0, "on": 1, "hit": true, "reach": reach, "pos": {"x": 0.0, "y": 1.0, "z": 0.0}}, 10)
	var widest: float = 0.0
	for r: CombatEffects.Fx in fx._rings:
		widest = maxf(widest, r.size_end)
	assert_gt(widest, reach * 2.0, "the shockwave rolls well past the reach")
	assert_eq(fx.distortion_count(), 1, "a ring of distortion with it")
