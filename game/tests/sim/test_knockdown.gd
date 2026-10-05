extends GutTest
## Knockdown (authored-animation plan task 16, spec "Rules changes"): an
## unblockable, a heavy released at full charge and the Greatsword's slams
## knock the defender down on a hit, in place of hitstun. The downed fighter
## falls, lies and stands up on a fixed timer, invulnerable until stand-up
## frame 10, then able to block or parry (but not attack, dodge or move) for
## the stand-up's last 15 frames. Expected numbers come from the spec.

const H := preload("res://tests/sim/sim_helpers.gd")
const CLOSE: float = 0.005

## The spec's provisional phases: fall 20, ground 30, stand-up 25.
const FALL: int = 20
const GROUND: int = 30
const STANDUP: int = 25
const TOTAL: int = FALL + GROUND + STANDUP
## Invulnerable from the fall's first frame until stand-up frame 10.
const INVULN_LAST: int = FALL + GROUND + 10
## The stomp keeps its 70-frame stun.
const STOMP_STUN: int = 70

## Piercing Thrust's numbers (the Katana's block-heavy ability).
const THRUST_DAMAGE: float = 12.0
const THRUST_KNOCKBACK: float = 0.8

var IDLE: Callable = Callable()


func after_each() -> void:
	H.dispose_all()


## Step one frame at a time until `done` (no arguments) is true, at most
## `limit` steps. Returns whether it came true.
static func _run_until(W: World, done: Callable, limit: int, p0: Callable = Callable(), p1: Callable = Callable(), rec: H.Rec = null) -> bool:
	for i: int in limit:
		if done.call():
			return true
		H.run(W, 1, (func(_j: int) -> RawInput: return p0.call(i)) if not p0.is_null() else Callable(),
			(func(_j: int) -> RawInput: return p1.call(i)) if not p1.is_null() else Callable(), rec)
	return done.call()


## Katana against Katana, 2.2 m apart: the attacker's Piercing Thrust knocks
## the idle defender down. Returns the world, stopped on the step the
## knockdown starts (the defender's state frame 0).
func _knocked_down(rec: H.Rec = null) -> World:
	var W: World = H.make_world()
	var b: Fighter = W.fighters[1]
	var thrust: Callable = func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle()
	assert_true(_run_until(W, func() -> bool: return b.state == &"knockdown", 60, thrust, Callable(), rec), "the thrust knocks down")
	return W


## Steps until the downed defender reaches state frame `sf`, the attacker idle
## and the defender's input from `p1` (step index).
func _to_sf(W: World, sf: int, p1: Callable = Callable(), rec: H.Rec = null) -> void:
	var b: Fighter = W.fighters[1]
	assert_true(_run_until(W, func() -> bool: return b.sf >= sf or b.state != &"knockdown", 200, Callable(), p1, rec))
	assert_eq(b.state, &"knockdown", "still down at state frame %d" % sf)
	assert_eq(b.sf, sf)


# ------------------------------------------------------------------ causes

func test_an_unblockable_hit_knocks_down_instead_of_hitstun() -> void:
	var r: H.Rec = H.Rec.new()
	var W: World = _knocked_down(r)
	var b: Fighter = W.fighters[1]
	var kd: Dictionary = r.find(&"knockdown")
	assert_false(kd.is_empty(), "a knockdown event marks the fall")
	assert_eq(kd.get("f"), 1)
	assert_eq(kd.get("attacker"), 0)
	assert_eq(r.find(&"hit").get("attack"), &"k_thrust")
	assert_eq(b.state, &"knockdown")
	assert_eq(b.state_dur, TOTAL)


func test_damage_posture_and_knockback_are_unchanged() -> void:
	var r: H.Rec = H.Rec.new()
	var W: World = _knocked_down(r)
	var b: Fighter = W.fighters[1]
	assert_almost_eq(b.hp, 100.0 - THRUST_DAMAGE, CLOSE)
	assert_almost_eq(float(r.find(&"hit").get("damage")), THRUST_DAMAGE, CLOSE)
	assert_almost_eq(b.posture, 16.0 * SimConst.HIT_POSTURE_MULT, CLOSE)
	assert_almost_eq(b.knock_meters, THRUST_KNOCKBACK, CLOSE, "the knockback of a plain hit")
	assert_eq(b.knock_total, 12)


func test_an_unblockable_through_a_block_knocks_down() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(
		W,
		45,
		func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(),
		func(_i: int) -> RawInput: return H.btn(Btn.BLOCK),
		r,
	)
	assert_true(r.has(&"hit"))
	assert_true(r.has(&"knockdown"))
	assert_eq(W.fighters[1].state, &"knockdown")


func test_a_heavy_released_at_full_charge_knocks_down() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	H.run(W, 200, func(_i: int) -> RawInput: return H.btn(Btn.HEAVY), IDLE, r)
	var hit: Dictionary = r.find(&"hit")
	assert_eq(hit.get("attack"), &"k_iai")
	assert_almost_eq(float(hit.get("damage", NAN)), 13.0 * 1.8, CLOSE, "the full charge's damage")
	assert_true(r.has(&"knockdown"))
	assert_eq(W.fighters[1].state, &"knockdown")


func test_a_partly_charged_heavy_still_puts_the_defender_in_hitstun() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var b: Fighter = W.fighters[1]
	# held 60 frames: well short of the full 150-frame charge
	var hold: Callable = func(i: int) -> RawInput: return H.btn(Btn.HEAVY) if i < 60 else H.idle()
	assert_true(_run_until(W, func() -> bool: return r.has(&"hit"), 120, hold, Callable(), r))
	assert_false(r.has(&"knockdown"))
	assert_eq(b.state, &"hitstun")


func test_mountain_slam_knocks_down() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 2.4)
	var r: H.Rec = H.Rec.new()
	H.run(W, 50, func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(), IDLE, r)
	assert_eq(r.find(&"hit").get("attack"), &"g_slam")
	assert_true(r.has(&"knockdown"))
	assert_eq(W.fighters[1].state, &"knockdown")


func test_leaping_smash_knocks_down() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 7.0)
	var r: H.Rec = H.Rec.new()
	var sprint_heavy: Callable = func(i: int) -> RawInput:
		return H.move(0.0, 1.0, Btn.SPRINT, Btn.HEAVY) if i == 12 else (H.move(0.0, 1.0, Btn.SPRINT) if i < 12 else H.idle())
	H.run(W, 70, sprint_heavy, IDLE, r)
	assert_eq(r.find(&"hit").get("attack"), &"g_sh")
	assert_true(r.has(&"knockdown"))
	assert_eq(W.fighters[1].state, &"knockdown")


func test_meteor_drop_knocks_down() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 2.2)
	var r: H.Rec = H.Rec.new()
	var jump_heavy: Callable = func(i: int) -> RawInput:
		return H.btn(Btn.JUMP) if i == 0 else (H.btn(Btn.HEAVY) if i == 6 else H.idle())
	H.run(W, 60, jump_heavy, IDLE, r)
	assert_eq(r.find(&"hit").get("attack"), &"g_jh")
	assert_true(r.has(&"knockdown"))
	assert_eq(W.fighters[1].state, &"knockdown")


func test_a_plain_heavy_does_not_knock_down() -> void:
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 2.2)
	var r: H.Rec = H.Rec.new()
	H.run(W, 40, H.tap_at(0, Btn.HEAVY), IDLE, r)
	assert_eq(r.find(&"hit").get("attack"), &"g_h1")
	assert_false(r.has(&"knockdown"))
	assert_eq(W.fighters[1].state, &"hitstun")


func test_an_ultimate_hit_does_not_knock_down() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var r: H.Rec = H.Rec.new()
	W.fighters[0].hp = 20.0
	var b: Fighter = W.fighters[1]
	assert_true(_run_until(W, func() -> bool: return r.has(&"hit"), 80, H.tap_at(0, Btn.ULTIMATE), Callable(), r))
	assert_eq(r.find(&"hit").get("attack"), &"u_moon_v")
	assert_false(r.has(&"knockdown"))
	assert_eq(b.state, &"hitstun")


# ------------------------------------------------------------------ not on a block, a parry, a counter or a KO

func test_a_blocked_full_charge_heavy_does_not_knock_down() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var b: Fighter = W.fighters[1]
	assert_true(_run_until(
		W, func() -> bool: return r.has(&"block"), 220,
		func(_i: int) -> RawInput: return H.btn(Btn.HEAVY),
		func(_i: int) -> RawInput: return H.btn(Btn.BLOCK), r,
	))
	assert_false(r.has(&"knockdown"))
	assert_eq(b.state, &"blockstun")


func test_a_parried_unblockable_does_not_knock_down() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	# the press 3 frames before the thrust lands, well inside the 9-frame window
	var parry: Callable = func(_i: int) -> RawInput:
		var due: bool = a.state == &"attack" and a.atk != null and a.atk.frame == a.atk.def.startup - 2
		return H.btn(Btn.BLOCK) if due else H.idle()
	H.run(W, 45, func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(), parry, r)
	assert_eq(r.find(&"parry").get("kind"), &"parry")
	assert_false(r.has(&"hit"))
	assert_false(r.has(&"knockdown"))
	assert_ne(b.state, &"knockdown")


func test_a_knocking_out_hit_plays_the_ko_instead() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var b: Fighter = W.fighters[1]
	b.hp = 5.0
	H.run(W, 45, func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(), IDLE, r)
	assert_true(r.has(&"hit"))
	assert_true(r.has(&"ko"))
	assert_false(r.has(&"knockdown"))
	assert_eq(b.state, &"ko")


func test_the_stomp_still_stuns_for_70_and_doesnt_knock_down() -> void:
	var W: World = H.make_world()
	var r: H.Rec = H.Rec.new()
	var a: Fighter = W.fighters[0]
	H.run(
		W,
		45,
		func(i: int) -> RawInput: return H.btn(Btn.BLOCK, Btn.HEAVY) if i == 0 else H.idle(),
		func(i: int) -> RawInput: return H.move(0.0, 1.0, Btn.DODGE) if i == 20 else H.idle(),
		r,
	)
	var c: Dictionary = r.find(&"counter")
	assert_eq(c.get("kind"), &"stomp")
	assert_false(r.has(&"knockdown"))
	assert_eq(a.state, &"stunned")
	assert_eq(a.state_dur, STOMP_STUN)


# ------------------------------------------------------------------ the downed fighter

func test_the_downed_fighter_is_invulnerable_until_stand_up_frame_10() -> void:
	var W: World = _knocked_down()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var light: AttackDef = Moves.KATANA.moves[&"k_l1"]
	# an undodgeable move too: being down isn't dodge invincibility
	var moon: AttackDef = Moves.ULT_HITS[&"u_moon_v"]
	assert_true(b.is_invulnerable(), "from the fall's first frame")
	for sf: int in range(1, TOTAL):
		_to_sf(W, sf)
		if sf <= INVULN_LAST:
			assert_true(b.is_invulnerable(), "invulnerable at state frame %d" % sf)
			assert_ne(W.evaluate(a, b, light, true), &"hit", "a light can't hit at state frame %d" % sf)
			assert_ne(W.evaluate(a, b, moon, true), &"hit", "nor an undodgeable at state frame %d" % sf)
		else:
			assert_false(b.is_invulnerable(), "open again at state frame %d" % sf)
			assert_eq(W.evaluate(a, b, light, true), &"hit", "a light hits an unguarded rise at state frame %d" % sf)


func test_a_light_swung_into_a_downed_fighter_passes_through() -> void:
	var r: H.Rec = H.Rec.new()
	var W: World = _knocked_down()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	_to_sf(W, 30)
	# stand the attacker right in front of them, free to swing
	a.set_state(&"free")
	a.pos = V3.make(b.pos.x, 0.0, b.pos.z - 1.6)
	a.yaw = 0.0
	W.drain_events()
	H.run(W, 14, H.tap_at(0, Btn.LIGHT), IDLE, r)
	assert_true(r.has(&"swing"))
	assert_false(r.has(&"hit"))
	assert_almost_eq(b.hp, 100.0 - THRUST_DAMAGE, CLOSE)
	assert_eq(b.state, &"knockdown")


func test_in_the_guard_window_a_light_is_blocked() -> void:
	var r: H.Rec = H.Rec.new()
	var W: World = _knocked_down()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var hold_block: Callable = func(_i: int) -> RawInput: return H.btn(Btn.BLOCK)
	# the light lands 12 frames after the press: on state frame 63
	_to_sf(W, INVULN_LAST - 9, hold_block)
	a.set_state(&"free")
	a.pos = V3.make(b.pos.x, 0.0, b.pos.z - 1.6)
	a.yaw = 0.0
	b.yaw = PI
	W.drain_events()
	H.run(W, 16, H.tap_at(0, Btn.LIGHT), hold_block, r)
	assert_true(r.has(&"block"), "the rising fighter blocks")
	assert_false(r.has(&"hit"))


func test_in_the_guard_window_the_fighter_can_block_or_parry() -> void:
	var W: World = _knocked_down()
	var b: Fighter = W.fighters[1]
	_to_sf(W, INVULN_LAST)
	assert_false(b.is_guard_capable(), "no guard while invulnerable")
	var hold_block: Callable = func(_i: int) -> RawInput: return H.btn(Btn.BLOCK)
	_to_sf(W, INVULN_LAST + 1, hold_block)
	assert_true(b.is_guard_capable())
	assert_true(b.blocking, "holding block blocks")
	assert_true(b.parry_active(), "the first block press opens a parry window")


func test_in_the_guard_window_the_fighter_cant_attack_dodge_or_move() -> void:
	var W: World = _knocked_down()
	var b: Fighter = W.fighters[1]
	_to_sf(W, INVULN_LAST)
	var at: V3 = V3.make(b.pos.x, b.pos.y, b.pos.z)
	var inputs: Array[RawInput] = [
		H.btn(Btn.LIGHT), H.btn(Btn.HEAVY), H.move(1.0, 0.0, Btn.DODGE), H.btn(Btn.JUMP),
		H.move(0.0, 1.0), H.move(0.0, 1.0, Btn.SPRINT), H.btn(Btn.LIGHT), H.btn(Btn.DODGE),
	]
	var mash: Callable = func(i: int) -> RawInput: return inputs[i % inputs.size()]
	for sf: int in range(INVULN_LAST + 1, TOTAL):
		_to_sf(W, sf, mash)
		assert_eq(b.state, &"knockdown", "still standing up at state frame %d" % sf)
		assert_almost_eq(b.pos.x, at.x, CLOSE)
		assert_almost_eq(b.pos.z, at.z, CLOSE)


func test_the_fighter_is_free_on_the_last_frame() -> void:
	var r: H.Rec = H.Rec.new()
	var W: World = _knocked_down()
	var b: Fighter = W.fighters[1]
	_to_sf(W, TOTAL - 1, Callable(), r)
	assert_false(r.has(&"standup"))
	H.run(W, 1, IDLE, IDLE, r)
	assert_eq(b.state, &"free", "free on frame 75")
	var up: Dictionary = r.find(&"standup")
	assert_false(up.is_empty(), "a standup event marks the end")
	assert_eq(up.get("f"), 1)
	# and acts on the next
	H.run(W, 1, IDLE, H.tap_at(0, Btn.LIGHT), r)
	assert_eq(b.state, &"attack")


func test_the_knockdown_phases() -> void:
	var W: World = _knocked_down()
	var b: Fighter = W.fighters[1]
	var expect: Callable = func(sf: int) -> StringName:
		return &"fall" if sf <= FALL else (&"ground" if sf <= FALL + GROUND else &"standUp")
	for sf: int in range(1, TOTAL):
		_to_sf(W, sf)
		assert_eq(b.knockdown_phase(), expect.call(sf), "phase at state frame %d" % sf)
	H.run(W, 1)
	assert_eq(b.knockdown_phase(), &"")


# ------------------------------------------------------------------ the computer opponent

## A brain on the attacker, right in front of a defender knocked down this
## step: the attack presses it makes over `frames` steps.
func _brain_presses(down: bool, frames: int) -> Array[int]:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 1.6)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var params: AIBrain.AIParams = AIBrain.DIFFICULTY[&"hard"].copy()
	params.aggression = 1.0
	params.guard = 0.0
	var brain: AIBrain = AIBrain.new(a, params, 5)
	if down:
		b.enter_knockdown()
	var presses: Array[int] = []
	for i: int in frames:
		var inp: RawInput = brain.think()
		if inp.buttons & ((1 << Btn.LIGHT) | (1 << Btn.HEAVY) | (1 << Btn.ULTIMATE)):
			presses.append(b.sf if down else i)
		W.step([inp, RawInput.empty()])
		if down and b.state != &"knockdown":
			break
	brain.dispose()
	return presses


func test_the_computer_attacks_a_standing_opponent_at_close_range() -> void:
	assert_false(_brain_presses(false, INVULN_LAST).is_empty(), "the same brain attacks when nobody is down")


func test_the_computer_waits_out_a_knockdown_until_the_guard_window() -> void:
	var presses: Array[int] = _brain_presses(true, TOTAL + 10)
	for sf: int in presses:
		assert_gt(sf, INVULN_LAST, "no attack pressed before the guard window (state frame %d)" % sf)


## The KO keeps its final blow's weight and side (authored-animation task
## 28, for the death clip): a heavy from the front, a light from behind.
func test_a_ko_keeps_the_final_blows_weight_and_side() -> void:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	b.to_ko(a, true)
	assert_eq([b.ko_heavy, b.ko_from_behind], [true, false], "a heavy from the front")
	b.yaw = wrapf(b.yaw + PI, -PI, PI)
	b.to_ko(a, false)
	assert_eq([b.ko_heavy, b.ko_from_behind], [false, true], "a light from behind")
	b.to_ko()
	assert_eq([b.ko_heavy, b.ko_from_behind], [false, false], "no blow (the round's end)")
	# a blow that knocks out records it
	var W2: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.2)
	W2.fighters[1].hp = 1.0
	var rec: H.Rec = H.Rec.new()
	H.run(W2, 40, H.tap_at(0, Btn.LIGHT), Callable(), rec)
	assert_eq(W2.fighters[1].state, &"ko", "Right Cut knocks out")
	assert_eq([W2.fighters[1].ko_heavy, W2.fighters[1].ko_from_behind], [false, false], "a light, from the front")
