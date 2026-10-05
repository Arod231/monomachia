extends GutTest
## The recall's power-up aura and burst (RecallAura, authored-animation task
## 30b): the aura swells to the burst and dies away, is thrown once per rules
## frame and only in the recall, the same at the same frame, and the burst
## flares with a shockwave out past the recalled weapon's reach.


func after_each() -> void:
	SimHelpers.dispose_all()


func _effects() -> CombatEffects:
	var fx: CombatEffects = CombatEffects.new()
	add_child_autofree(fx)
	return fx


func test_the_aura_swells_to_the_burst_and_dies_away() -> void:
	var burst: int = SimConst.RECALL_BURST_FRAME
	assert_almost_eq(RecallAura.strength(burst), 1.0, 1e-6, "at its height on the burst")
	assert_gt(RecallAura.strength(0), 0.0, "there from the start")
	for sf: int in range(1, burst + 1):
		assert_gte(RecallAura.strength(sf), RecallAura.strength(sf - 1), "swelling, frame %d" % sf)
	for sf: int in range(burst + 1, SimConst.RECALL_FRAMES + 1):
		assert_lte(RecallAura.strength(sf), RecallAura.strength(sf - 1), "dying away, frame %d" % sf)
	assert_eq(RecallAura.strength(SimConst.RECALL_FRAMES), 0.0, "gone as the recall ends")


func test_it_is_thrown_once_per_rules_frame_and_only_in_the_recall() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var fx: CombatEffects = _effects()
	var aura: RecallAura = RecallAura.new()
	aura.feed(fx, 0, f)
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	aura.feed(fx, 0, f)
	assert_eq(fx._particles.size(), 0, "nothing outside the recall")
	f.armed = false
	f.set_state(&"recall", SimConst.RECALL_FRAMES)
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	aura.feed(fx, 0, f)
	var after_one: int = fx._particles.size()
	assert_gt(after_one, 0, "flames rise")
	aura.feed(fx, 0, f)
	assert_eq(fx._particles.size(), after_one, "a frame drawn again throws nothing more")
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	W.step([SimHelpers.idle(), SimHelpers.idle()])
	aura.feed(fx, 0, f)
	assert_gt(fx._particles.size(), after_one, "frames missed between draws are thrown too")
	var rings: int = 0
	for i: int in 6:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		aura.feed(fx, 0, f)
	rings = fx._rings.size()
	assert_gt(rings, 0, "white wind streaks")


func test_the_same_frame_throws_the_same_flames() -> void:
	var a: CombatEffects = _effects()
	var b: CombatEffects = _effects()
	RecallAura.throw(a, 1, Vector3(1.0, 0.0, 2.0), 10, 300)
	RecallAura.throw(b, 1, Vector3(1.0, 0.0, 2.0), 10, 300)
	assert_eq(a._particles.size(), b._particles.size())
	for i: int in a._particles.size():
		assert_eq(a._particles[i].p0, b._particles[i].p0)
		assert_eq(a._particles[i].v, b._particles[i].v)


func test_the_burst_flares_with_a_shockwave_past_the_reach() -> void:
	var fx: CombatEffects = _effects()
	var e: Dictionary = {"t": &"recallBurst", "f": 0, "on": 1, "hit": true, "reach": 3.0, "pos": {"x": 0.5, "y": 1.0, "z": -1.0}}
	RecallAura.burst(fx, e, 120)
	assert_gte(fx._flashes.size(), 2, "the flare and its core")
	var ground: Array = fx._rings.filter(func(r: CombatEffects.Fx) -> bool: return r.normal == Vector3.UP)
	assert_eq(ground.size(), 2, "two shockwaves along the ground")
	var widest: float = 0.0
	for r: CombatEffects.Fx in ground:
		widest = maxf(widest, r.size_end)
		assert_almost_eq(r.at, Vector3(0.5, 0.04, -1.0), Vector3.ONE * 1e-6, "round the recaller's feet")
	assert_gt(widest, 3.0, "out past the reach")
	assert_gt(fx._particles.size(), 20, "a spray of sparks")
