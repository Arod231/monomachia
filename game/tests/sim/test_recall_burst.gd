extends GutTest
## The recall's power-up burst (authored-animation task 30b, the owner's
## design, Oct 4, 2026): on the recall's frame 16, as the weapon returns to
## the hand, an opponent within the recalled weapon's duelling distance is
## blasted 2.0 m away and knocked down. No damage or posture; a block or a
## parry doesn't stop it, the invulnerability of a dodge or a knockdown
## does.

const H := preload("res://tests/sim/sim_helpers.gd")

## helpers.ts idle as an input function: run() treats a null Callable as idle
var IDLE: Callable = Callable()


func after_each() -> void:
	H.dispose_all()


## A world with fighter 0 holding `weapon`, `gap` from the opponent,
## disarmed and starting its recall.
static func _recalling(weapon: WeaponDef, gap: float) -> World:
	var W: World = H.make_world(weapon, Moves.KATANA, gap)
	var a: Fighter = W.fighters[0]
	a.armed = false
	a.set_state(&"recall", SimConst.RECALL_FRAMES)
	return W


static func _gap(W: World) -> float:
	var a: V3 = W.fighters[0].pos
	var b: V3 = W.fighters[1].pos
	return Vector2(b.x - a.x, b.z - a.z).length()


func test_the_constants() -> void:
	assert_eq(SimConst.RECALL_FRAMES, 26)
	assert_eq(SimConst.RECALL_BURST_FRAME, 16, "as the weapon returns")
	assert_eq(SimConst.RECALL_BURST_KNOCKBACK, 2.0, "twice a heavy's 1.0")


func test_an_opponent_in_reach_is_blasted_2_m_away_and_knocked_down() -> void:
	var W: World = _recalling(Moves.KATANA, 2.4)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var before: float = _gap(W)
	var hp: float = b.hp
	var posture: float = b.posture
	var r: H.Rec = H.Rec.new()
	H.run(W, SimConst.RECALL_BURST_FRAME - 1, IDLE, IDLE, r)
	assert_false(r.has(&"recallBurst"), "not before frame 16")
	assert_false(a.armed)
	H.run(W, 1, IDLE, IDLE, r)
	assert_true(a.armed, "the weapon back in hand")
	var burst: Dictionary = r.find(&"recallBurst")
	assert_eq(burst.get("f"), 0)
	assert_eq(burst.get("on"), 1)
	assert_true(burst.get("hit"), "within the Katana's 2.5 m")
	assert_eq(b.state, &"knockdown", "knocked down")
	assert_true(r.has(&"knockdown"))
	H.run(W, 30, IDLE, IDLE, r)
	assert_almost_eq(_gap(W) - before, SimConst.RECALL_BURST_KNOCKBACK, 0.05, "blasted 2.0 m away")
	assert_eq(b.hp, hp, "no damage")
	assert_eq(b.posture, posture, "no posture")
	assert_eq(r.count(&"recallBurst"), 1, "once")


func test_out_of_reach_the_burst_flares_and_misses() -> void:
	var W: World = _recalling(Moves.KATANA, 2.6)
	var b: Fighter = W.fighters[1]
	var r: H.Rec = H.Rec.new()
	H.run(W, SimConst.RECALL_FRAMES + 2, IDLE, IDLE, r)
	var burst: Dictionary = r.find(&"recallBurst")
	assert_false(burst.get("hit"), "past 2.5 m")
	assert_ne(b.state, &"knockdown")
	assert_false(r.has(&"knockdown"))


func test_the_reach_is_the_recalled_weapons_duelling_distance() -> void:
	for c: Array in [[Moves.GREATSWORD, 2.9, true], [Moves.GREATSWORD, 3.1, false], [Moves.DAGGERS, 1.9, true], [Moves.DAGGERS, 2.1, false]]:
		var weapon: WeaponDef = c[0]
		var W: World = _recalling(weapon, c[1])
		var r: H.Rec = H.Rec.new()
		H.run(W, SimConst.RECALL_BURST_FRAME, IDLE, IDLE, r)
		assert_eq(r.find(&"recallBurst").get("hit"), c[2], "%s at %.1f m (reach %.1f)" % [weapon.id, c[1], weapon.duel_distance])


func test_a_block_does_not_stop_it() -> void:
	var W: World = _recalling(Moves.KATANA, 2.0)
	var b: Fighter = W.fighters[1]
	var r: H.Rec = H.Rec.new()
	H.run(W, SimConst.RECALL_BURST_FRAME, IDLE, func(_i: int) -> RawInput: return H.btn(Btn.BLOCK), r)
	assert_true(r.find(&"recallBurst").get("hit"), "through the guard")
	assert_eq(b.state, &"knockdown")
	assert_false(r.has(&"block"))
	assert_false(r.has(&"parry"))


func test_a_dodges_invulnerability_avoids_it() -> void:
	var W: World = _recalling(Moves.KATANA, 2.0)
	var b: Fighter = W.fighters[1]
	var r: H.Rec = H.Rec.new()
	# the opponent dodges sideways a few frames before the burst, so its
	# i-frames cover frame 16
	var dodge_on: int = SimConst.RECALL_BURST_FRAME - 6
	H.run(W, SimConst.RECALL_BURST_FRAME, IDLE, func(i: int) -> RawInput: return H.move(1.0, 0.0, Btn.DODGE) if i == dodge_on else H.idle(), r)
	assert_eq(b.state, &"dodge")
	assert_false(r.find(&"recallBurst").get("hit"), "dodged")
	assert_ne(b.state, &"knockdown")


func test_a_knocked_down_opponent_is_not_hit_again() -> void:
	var W: World = _recalling(Moves.KATANA, 2.0)
	var b: Fighter = W.fighters[1]
	b.enter_knockdown()
	var r: H.Rec = H.Rec.new()
	H.run(W, SimConst.RECALL_BURST_FRAME, IDLE, IDLE, r)
	assert_false(r.find(&"recallBurst").get("hit"), "down and invulnerable")
