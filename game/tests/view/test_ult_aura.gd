extends GutTest
## The ultimate-ready aura (UltAura, milestone-1 task 100): embers rising off
## the body, a heat-haze shimmer and a faint rim glow in the side's colour,
## while the fighter's ultimate is ready and it isn't knocked out; steady, so
## Reduce flashes keeps it.


func after_each() -> void:
	SimHelpers.dispose_all()


func _effects() -> CombatEffects:
	var fx: CombatEffects = CombatEffects.new()
	add_child_autofree(fx)
	return fx


static func _step(W: World) -> void:
	W.step([SimHelpers.idle(), SimHelpers.idle()])


func test_it_is_on_while_the_ultimate_is_ready_and_the_fighter_stands() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	assert_false(UltAura.on(f), "above 25% HP")
	f.hp = 20.0
	assert_true(UltAura.on(f), "ready")
	f.ult_used = true
	assert_false(UltAura.on(f), "used this round")
	f.ult_used = false
	f.to_ko()
	assert_false(UltAura.on(f), "knocked out")


func test_it_throws_embers_in_the_side_s_colour_once_per_rules_frame_only_while_on() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var fx: CombatEffects = _effects()
	var aura: UltAura = UltAura.new()
	var red: Color = Color(0.85, 0.12, 0.1)
	aura.feed(fx, 0, f, red)
	_step(W)
	aura.feed(fx, 0, f, red)
	assert_eq(fx._particles.size(), 0, "none while it isn't ready")
	f.hp = 20.0
	_step(W)
	aura.feed(fx, 0, f, red)
	var once: int = fx._particles.size()
	assert_gt(once, 0, "embers rise")
	aura.feed(fx, 0, f, red)
	assert_eq(fx._particles.size(), once, "a frame drawn again throws nothing more")
	for p: CombatEffects.Particle in fx._particles:
		assert_gt(p.v.y, 0.0, "rising")
		assert_gt(p.color.r, p.color.b, "warm, in the side's red")
	f.to_ko()
	_step(W)
	aura.feed(fx, 0, f, red)
	assert_eq(fx._particles.size(), once, "none once knocked out")


func test_it_stays_whole_under_reduce_flashes() -> void:
	# steady, so nothing to dim: the same embers, the same rim
	assert_eq(UltAura.rim(true, true), UltAura.rim(true, false))
	assert_gt(UltAura.rim(true, true), 0.0)
	assert_eq(UltAura.rim(false, false), 0.0)


func test_the_fighter_view_shows_the_rim_and_the_haze_only_while_it_is_on() -> void:
	var W: World = SimHelpers.make_world()
	var f: Fighter = W.fighters[0]
	var view: FighterView = FighterView.new()
	add_child_autofree(view)
	view.setup(&"hunter", 0, &"katana", 0)
	view.show_aura(f)
	assert_false(view.aura_shown(), "off at full HP")
	f.hp = 20.0
	view.show_aura(f)
	assert_true(view.aura_shown(), "on when ready")
	assert_true(view.haze.visible, "the heat haze")
	var rim: ShaderMaterial = view.rim_material()
	assert_eq(rim.get_shader_parameter("color"), Color(view.side_color(), 1.0), "the rim in the side's colour")
	f.to_ko()
	view.show_aura(f)
	assert_false(view.aura_shown(), "off once knocked out")
	assert_false(view.haze.visible)
