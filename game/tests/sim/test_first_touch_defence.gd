extends GutTest
## The computer defends from the swing's first touch (milestone-1 task 24):
## AIBrain times its defence by when the attacker's blade will first touch
## it (SwingReach, played on from the attack's frame, on the table's frames)
## and ignores a move that can't reach it from where it stands, unblockables
## included. Right Cut is made a slow, wide level slash here, on a fresh
## Katana, so where the defender stands decides how late the blade arrives.

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
const CUT: StringName = &"k_l1"
## The slash's frames: a startup the computer can react inside, and active
## frames long enough that a touch on the far side comes 8 frames later.
const STARTUP: int = 24
const ACTIVE: int = 10
const GAP: float = 1.4


func after_each() -> void:
	H.dispose_all()


## A fresh Katana whose Right Cut is a level slash from 60° right to 60°
## left over its ACTIVE frames, with no lunge and no turn toward the target,
## so the bearing it is thrown at decides when it touches.
static func _slash(unblockable: bool = false) -> WeaponDef:
	var w: WeaponDef = SF.weapon(&"katana", {})
	var cut: AttackDef = w.moves[CUT]
	cut.startup = STARTUP
	cut.active = ACTIVE
	cut.recovery = 20
	cut.lunge = 0.0
	cut.track_startup = 0.0
	cut.track_active = 0.0
	if unblockable:
		cut.unblockable = true
		cut.counter = &"thrust"
	cut.swing = SF.level_slash(cut)
	w.derive_reach()
	return w


## A world where fighter 0 (with `w`) faces straight ahead and fighter 1
## stands `distance` m away at `bearing` degrees to its right.
static func _world(w: WeaponDef, distance: float, bearing: float) -> World:
	var W: World = H.make_world(w, Moves.KATANA, distance)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var off: float = bearing * SimMath.DEG
	b.pos = SimMath.local_to_world(a.pos, a.yaw, V3.make(distance * JsMath.sin(off), 0.0, distance * JsMath.cos(off)))
	b.yaw = SimMath.yaw_to(b.pos, a.pos)
	return W


## The attack frame Right Cut first touches fighter 1 in a stepped world, or -1.
static func _stepped_touch(w: WeaponDef, distance: float, bearing: float) -> int:
	var W: World = _world(w, distance, bearing)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	for i: int in STARTUP + ACTIVE + 4:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		if a.state == &"attack" and a.atk.frame > STARTUP and a.atk.frame <= STARTUP + ACTIVE:
			if a.blade_touch(b.hurt_capsule()) != null:
				return a.atk.frame
	return -1


func test_the_computer_predicts_the_first_touch_from_any_frame_of_the_swing() -> void:
	var w: WeaponDef = _slash()
	for bearing: float in [45.0, -45.0]:
		var want: int = _stepped_touch(w, GAP, bearing)
		assert_gt(want, STARTUP, "%d°: the slash touches" % bearing)
		var W: World = _world(w, GAP, bearing)
		var a: Fighter = W.fighters[0]
		for i: int in STARTUP:
			W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
			assert_eq(AIBrain.frames_to_touch(a, W.fighters[1]), want - a.atk.frame, "%d°, frame %d: the frames to its touch" % [bearing, a.atk.frame])
	assert_gt(_stepped_touch(w, GAP, -45.0) - _stepped_touch(w, GAP, 45.0), 5, "the far side is touched well after the near")


func test_a_move_that_cant_reach_is_ignored_unblockables_too() -> void:
	for unblockable: bool in [false, true]:
		var w: WeaponDef = _slash(unblockable)
		var W: World = _world(w, 3.0, 0.0)
		W.step([H.btn(Btn.LIGHT), H.idle()])
		assert_eq(_stepped_touch(w, 3.0, 0.0), -1, "it doesn't reach from 3 m")
		assert_eq(AIBrain.frames_to_touch(W.fighters[0], W.fighters[1]), -1, "unblockable %s: nothing to defend" % unblockable)


## Over `runs` seeded runs, how many times a Hard computer standing at
## `bearing` parries the slash.
static func _parries(bearing: float, runs: int) -> int:
	var n: int = 0
	for seed_value: int in runs:
		var w: WeaponDef = _slash()
		var W: World = _world(w, GAP, bearing)
		# Hard's defence, without its own attacks or a raised guard to muddle it
		var hard: AIBrain.AIParams = AIBrain.DIFFICULTY[&"hard"].copy()
		hard.aggression = 0.0
		hard.guard = 0.0
		var brain: AIBrain = AIBrain.new(W.fighters[1], hard, 1000 + seed_value)
		var parried: bool = false
		for i: int in STARTUP + ACTIVE + 4:
			# only its guard: its footwork would take it out of the slash's way
			var guard: RawInput = RawInput.make(0.0, 0.0, brain.think().buttons & (1 << Btn.BLOCK))
			W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), guard])
			for e: Dictionary in W.drain_events():
				if e["t"] == &"parry":
					parried = true
		brain.dispose()
		n += 1 if parried else 0
	return n


func test_hard_parries_a_late_touching_swing_about_as_often_as_an_early_one() -> void:
	var runs: int = 60
	var early: int = _parries(45.0, runs)
	var late: int = _parries(-45.0, runs)
	assert_gt(early, runs / 4, "it parries the early touch (%d of %d)" % [early, runs])
	assert_gt(late, runs / 4, "and the late one (%d of %d)" % [late, runs])
	assert_lt(absi(early - late), runs / 5, "about as often: %d and %d of %d" % [early, late, runs])
