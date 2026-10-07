extends GutTest
## Hurt capsules (task 7.5): each fighter's body in the rules data, by
## fighter id, gives the capsule blades are swept against. It stands on the
## feet, 0.42 m in radius up to 2.0 m (KE task 3's taller bodies), follows
## the fighter as they move and rises with them when they jump. A fighter
## built without an id gets the default body.

const H := preload("res://tests/sim/sim_helpers.gd")
const EPS: float = 1e-12


func after_each() -> void:
	H.dispose_all()


func _assert_v3(got: V3, want: V3, what: String) -> void:
	assert_almost_eq(V3.distance(got, want), 0.0, EPS, "%s: got (%s, %s, %s)" % [what, got.x, got.y, got.z])


func test_the_rogue_and_the_hunter_have_bodies() -> void:
	for id: StringName in [&"rogue", &"hunter"]:
		var body: FighterBody = FighterBody.of(id)
		assert_eq(body.id, id)
		assert_eq([body.hurt_radius, body.hurt_height], [0.42, 2.0], "%s: 0.42 m round, up to 2.0 m" % id)


func test_every_fighter_a_side_can_pick_has_a_body() -> void:
	assert_eq(FighterBody.BODIES.keys(), MatchSide.FIGHTER_NAMES.keys())


func test_the_default_body_applies_without_an_id() -> void:
	var body: FighterBody = FighterBody.of(&"")
	assert_eq(body.id, &"")
	assert_eq([body.hurt_radius, body.hurt_height], [0.42, 2.0])
	var W: World = H.make_world()
	for f: Fighter in W.fighters:
		assert_eq(f.body.id, &"", "a config without an id")
		assert_eq([f.body.hurt_radius, f.body.hurt_height], [0.42, 2.0])


func test_an_unknown_id_gets_the_default_body_and_an_error() -> void:
	var body: FighterBody = FighterBody.of(&"ronin")
	assert_push_error("unknown fighter ronin")
	assert_eq([body.id, body.hurt_radius, body.hurt_height], [&"", 0.42, 2.0])


func test_a_config_with_an_id_gets_that_body() -> void:
	var W: World = H.track(World.new(
		FighterConfig.make(Moves.KATANA, [], "", &"rogue"), FighterConfig.make(Moves.DAGGERS, [], "", &"hunter"), 3))
	assert_eq([W.fighters[0].body.id, W.fighters[1].body.id], [&"rogue", &"hunter"])


func test_the_capsule_stands_on_the_feet() -> void:
	var f: Fighter = H.make_world().fighters[0]
	f.pos = V3.make(1.25, 0.0, -3.5)
	var c: SimCapsule = f.hurt_capsule()
	_assert_v3(c.a, V3.make(1.25, 0.42, -3.5), "the axis starts a radius above the feet")
	_assert_v3(c.b, V3.make(1.25, 1.58, -3.5), "and ends a radius below 2.0 m")
	assert_eq(c.radius, 0.42)


func test_the_capsule_follows_a_jump() -> void:
	var W: World = H.make_world()
	var f: Fighter = W.fighters[0]
	var top: float = 0.0
	var airborne_ticks: int = 0
	for i: int in 60:
		W.step([H.btn(Btn.JUMP) if i == 0 else H.idle(), H.idle()])
		var c: SimCapsule = f.hurt_capsule()
		assert_eq([c.a.x, c.a.z, c.b.x, c.b.z], [f.pos.x, f.pos.z, f.pos.x, f.pos.z], "over the feet on tick %d" % i)
		assert_almost_eq(c.a.y, f.pos.y + 0.42, EPS, "the bottom rises with the feet on tick %d" % i)
		assert_almost_eq(c.b.y, f.pos.y + 1.58, EPS, "and the top on tick %d" % i)
		top = maxf(top, f.pos.y)
		if f.pos.y > 0.0:
			airborne_ticks += 1
	assert_gt(top, 0.5, "the fighter jumped")
	assert_gt(airborne_ticks, 10, "for a while")
	assert_eq(f.pos.y, 0.0, "and landed")
	assert_almost_eq(f.hurt_capsule().a.y, 0.42, EPS, "the capsule is back on the ground")
