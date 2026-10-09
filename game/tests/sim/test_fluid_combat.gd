extends GutTest
## The fluid combat rules that changed the demo's on purpose (plan task 8),
## one section per rule. Expected numbers come from the spec, not the code.

const H := preload("res://tests/sim/sim_helpers.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")
## toBeCloseTo's default precision (2 digits), as the neighbouring tests use
const CLOSE: float = 0.005

## The spec's arena: a 15 m wall.
const WALL: float = 15.0
## A fighter's body radius, the demo's 0.42 m grown with KE task 3's taller
## bodies.
const FIGHTER_RADIUS: float = 0.5
## Fighters' centres stop a fighter's radius inside the wall.
const CENTRE_LIMIT: float = WALL - FIGHTER_RADIUS
## The Impaler's dash ends 0.7 m inside the wall.
const IMPALER_STOP: float = WALL - 0.7
## Dropped weapons bounce off a ring 0.95 m inside the wall.
## The Impaler dashes 24 m/s: 0.4 m a frame.
const DASH_STEP: float = 0.4

## The spec's blocking walk: 60% of running speed.
const BLOCK_WALK: float = 0.6
## Running speeds (m/s), kept from the demo (story 12), before the weapon's
## speed: the Greatsword moves 10% slower and the Daggers 12% faster.
const RUN_FORWARD: float = 3.9
const RUN_STRAFE: float = 3.5
const RUN_BACK: float = 3.0
const SPRINT: float = 7.2

## The spec's momentum carry: an attack keeps half the speed it starts at.
const MOMENTUM_KEEP: float = 0.5
## Kept from the demo: a running jump flies at strafing speed, and an attack
## on the ground brakes by a fifth of its speed each step after the first.
const JUMP_FLIGHT: float = 3.5
const ATTACK_BRAKE: float = 0.8

## Kept from the demo: a lunge stops with the two bodies this far apart.
const LUNGE_GAP: float = 0.25
## The Iai Slash (the Katana's heavy), tapped, from the spec's Katana notes:
## it lunges over its frames 10 to 25, and its cut lands on frame 24, after
## 23 frames of startup. The lunge is 2.1 m since its clip (authored-animation
## task 11), from 0.4, so its blade reaches as the old 3.6 m cone did.
const IAI_LUNGE: float = 2.1
const IAI_STARTUP: int = 23


func after_each() -> void:
	H.dispose_all()


## How far p is from the arena's centre, on the ground (in doubles: Godot's
## Vector2 is 32-bit).
static func _r(p: V3) -> float:
	return JsMath.hypot(p.x, p.z)


# ------------------------------------------------------------------ arena

func test_backing_away_stops_a_fighters_centre_at_the_15_m_wall() -> void:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.0)
	var a: Fighter = W.fighters[0]
	var furthest: float = 0.0
	for _i: int in 600:
		W.step([H.move(0.0, -1.0), H.idle()])
		furthest = maxf(furthest, _r(a.pos))
	assert_gt(furthest, 12.0, "past the demo's 11.08 m")
	assert_almost_eq(furthest, CENTRE_LIMIT, 1e-9, "no further than the wall less a fighter's radius")
	assert_almost_eq(_r(a.pos), CENTRE_LIMIT, 1e-9, "held against the wall")


func test_the_impaler_dash_stops_0_7_m_inside_the_wall() -> void:
	# The target hangs 2 m up, beyond where the dash should stop: the blade
	# never reaches it, and the dash never passes it.
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	a.pos = V3.make()
	a.hp = 20.0
	b.pos = V3.make(0.0, 2.0, 14.5)
	var dash_frames: int = 0
	var stop_r: float = -1.0
	for i: int in 120:
		b.pos.y = 2.0
		b.vel.y = 0.0
		W.step([H.btn(Btn.ULTIMATE) if i == 0 else H.idle(), H.idle()])
		if a.state == &"ult" and a.ult.phase == &"dash":
			dash_frames = a.ult.pf
		elif dash_frames > 0 and stop_r < 0.0:
			stop_r = _r(a.pos)
	assert_gt(dash_frames, 0, "the Impaler dashed")
	# the last dash frame seen is 39 when its 40 frames run out
	assert_lt(dash_frames, 39, "the stop ends the dash before its frames run out")
	assert_between(stop_r, IMPALER_STOP, IMPALER_STOP + DASH_STEP, "within one dash step past the stop, 0.7 m inside the wall")
	assert_lt(stop_r, CENTRE_LIMIT, "short of the wall itself, so the stop ended it, not the wall")


func test_a_vertical_moonsplitter_hits_across_the_widest_gap() -> void:
	# two fighters with their backs to opposite walls: 29.0 m apart
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.0 * CENTRE_LIMIT)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	a.hp = 20.0
	var r: H.Rec = H.Rec.new()
	var gap_at_release: float = -1.0
	for i: int in 150:
		W.step([H.btn(Btn.ULTIMATE) if i == 0 else H.idle(), H.idle()])
		r.collect(W)
		if gap_at_release < 0.0 and r.has(&"ultWave"):
			gap_at_release = SimMath.dist2(a.pos, b.pos)
	assert_eq(r.find(&"ultWave").get("kind"), &"vertical")
	assert_almost_eq(gap_at_release, 2.0 * CENTRE_LIMIT, 1e-9, "the fighters stand 29.0 m apart")
	assert_almost_eq(b.hp, 70.0, CLOSE, "the wave reaches and hits")


# ------------------------------------------------------------------ helpers

## Fighter 0 on each step of a run: how far it moved along the ground, the
## attack it was in afterwards (&"" outside one) and that attack's frame (-1),
## and how far apart the two fighters' centres stood.
class FighterSteps:
	var moved: PackedFloat64Array = []
	var attack: Array[StringName] = []
	var frame: PackedInt32Array = []
	var apart: PackedFloat64Array = []

	## The step that started attack id, or -1.
	func start_of(id: StringName) -> int:
		for i: int in attack.size():
			if attack[i] == id and (i == 0 or attack[i - 1] != id):
				return i
		return -1

	## How far it moved from step from on, adding up each step (so an orbit
	## counts in full).
	func walked(from: int = 0) -> float:
		var total: float = 0.0
		for d: float in moved.slice(from):
			total += d
		return total


## Runs n steps with fighter 0's input from p0 (step index -> RawInput) and an
## idle Katana opponent gap m away; abilities as H.make_world takes them.
static func _record(weapon: WeaponDef, gap: float, n: int, p0: Callable, abilities: Dictionary = {}) -> FighterSteps:
	var W: World = H.make_world(weapon, Moves.KATANA, gap, abilities)
	var a: Fighter = W.fighters[0]
	var s := FighterSteps.new()
	for i: int in n:
		var x: float = a.pos.x
		var z: float = a.pos.z
		W.step([p0.call(i), H.idle()])
		s.moved.append(JsMath.hypot(a.pos.x - x, a.pos.z - z))
		var attacking: bool = a.state == &"attack" and a.atk != null
		s.attack.append(a.atk.def.id if attacking else &"")
		s.frame.append(a.atk.frame if attacking else -1)
		s.apart.append(JsMath.hypot(a.pos.x - W.fighters[1].pos.x, a.pos.z - W.fighters[1].pos.z))
	return s


static func _total(steps: PackedFloat64Array) -> float:
	var t: float = 0.0
	for d: float in steps:
		t += d
	return t


# ------------------------------------------------------------------ block walk

## How far fighter 0 walks in one second holding inp, once up to speed (20
## steps in), against an idle opponent gap m away.
static func _walk_one_second(weapon: WeaponDef, gap: float, inp: RawInput) -> float:
	return _record(weapon, gap, 80, func(_i: int) -> RawInput: return inp).walked(20)


func test_walking_forward_while_blocking_is_60_percent_of_running() -> void:
	# 8 m apart, so the walker ends more than 4 m short of the opponent
	var weapon_speed: Dictionary[StringName, float] = {&"katana": 1.0, &"greatsword": 0.9, &"daggers": 1.12}
	for id: StringName in weapon_speed:
		var expected: float = RUN_FORWARD * weapon_speed[id] * BLOCK_WALK
		var walked: float = _walk_one_second(Moves.WEAPONS[id], 8.0, H.move(0.0, 1.0, Btn.BLOCK))
		assert_almost_eq(walked, expected, 1e-6, "%s walks forward %.4f m/s blocking" % [id, expected])


func test_strafing_and_backing_away_while_blocking_are_60_percent_of_running() -> void:
	# The strafe orbits the opponent 6 m away (strafes keep their distance
	# inside 9 m). Each step is pulled back onto the circle, which shortens the
	# second's walk by about 3e-5 m, hence the looser tolerance.
	var strafed: float = _walk_one_second(Moves.KATANA, 6.0, H.move(1.0, 0.0, Btn.BLOCK))
	assert_almost_eq(strafed, RUN_STRAFE * BLOCK_WALK, 1e-4, "strafing")
	var backed: float = _walk_one_second(Moves.KATANA, 6.0, H.move(0.0, -1.0, Btn.BLOCK))
	assert_almost_eq(backed, RUN_BACK * BLOCK_WALK, 1e-6, "backing away")


func test_holding_block_stops_a_sprint() -> void:
	# 20 m apart, so the sprint (about 9 m in all) never reaches the opponent
	var sprint: float = _walk_one_second(Moves.KATANA, 20.0, H.move(0.0, 1.0, Btn.SPRINT))
	var blocking: float = _walk_one_second(Moves.KATANA, 20.0, H.move(0.0, 1.0, Btn.SPRINT, Btn.BLOCK))
	assert_almost_eq(sprint, SPRINT, 1e-6, "the sprint button sprints")
	assert_almost_eq(blocking, RUN_FORWARD * BLOCK_WALK, 1e-6, "blocking walks at the blocking walk instead")


# ------------------------------------------------------------------ momentum
# Each run starts 10 m from the opponent, so nobody meets. The carry is a
# stand-in's (a move its family has re-keyed keeps none of a run's speed,
# test_clip_travel.gd), so Right Cut plays as one here.

## The Katana with Right Cut a stand-in again.
static func _stand_in_katana() -> WeaponDef:
	return SF.stand_ins(&"katana", [&"k_l1"] as Array[StringName])


func test_a_light_thrown_at_a_run_keeps_half_the_running_speed() -> void:
	var s: FighterSteps = _record(_stand_in_katana(), 10.0, 40, func(i: int) -> RawInput:
		return H.move(0.0, 1.0, Btn.LIGHT) if i == 30 else H.move(0.0, 1.0))
	var i: int = s.start_of(&"k_l1")
	assert_eq(i, 30, "Right Cut starts on the press")
	assert_almost_eq(s.moved[i - 1], RUN_FORWARD / 60.0, 1e-9, "running at full speed the step before")
	assert_almost_eq(s.moved[i], MOMENTUM_KEEP * s.moved[i - 1], 1e-12, "the step it starts on keeps exactly half")


func test_a_light_thrown_at_a_run_carries_the_attacker_further_than_one_thrown_standing() -> void:
	var standing: FighterSteps = _record(_stand_in_katana(), 10.0, 90, func(i: int) -> RawInput:
		return H.btn(Btn.LIGHT) if i == 0 else H.idle())
	var running: FighterSteps = _record(_stand_in_katana(), 10.0, 120, func(i: int) -> RawInput:
		if i < 30:
			return H.move(0.0, 1.0)
		return H.btn(Btn.LIGHT) if i == 30 else H.idle())
	assert_eq(standing.start_of(&"k_l1"), 0, "the standing Right Cut starts on the press")
	assert_eq(running.start_of(&"k_l1"), 30, "the running one too")
	# The kept speed for one step, then braked each step after:
	# 1.95 m/s x 1/60 s x (1 + 0.8 + 0.8^2 + ...) = 1.95 / 12 m. The cut ends
	# after 60 steps, which leaves next to none of the series out.
	var expected: float = MOMENTUM_KEEP * RUN_FORWARD / 60.0 / (1.0 - ATTACK_BRAKE)
	assert_almost_eq(running.walked(30) - standing.walked(), expected, 0.0005, "the same cut, 16 cm further")


func test_a_jump_attack_keeps_all_its_speed() -> void:
	# the stick is let go in the air, so the flight is straight
	var s: FighterSteps = _record(Moves.KATANA, 10.0, 40, func(i: int) -> RawInput:
		if i < 30:
			return H.move(0.0, 1.0, Btn.JUMP) if i == 29 else H.move(0.0, 1.0)
		return H.btn(Btn.LIGHT) if i == 34 else H.idle())
	var i: int = s.start_of(&"k_jl")
	assert_eq(i, 34, "Aerial Cut starts on the press")
	assert_almost_eq(s.moved[i - 1], JUMP_FLIGHT / 60.0, 1e-9, "flying at the jump's speed the step before")
	assert_almost_eq(s.moved[i], s.moved[i - 1], 1e-12, "the step it starts on keeps it all")


func test_a_hop_attack_keeps_all_its_speed() -> void:
	# Leaping Cleave, the Katana's sprint heavy, hopped forward as a stand-in
	# (its re-key, task 75, leaps by its clip's travel instead)
	var s: FighterSteps = _record(SF.stand_ins(&"katana", [&"k_sh"] as Array[StringName]), 10.0, 40, func(i: int) -> RawInput:
		return H.move(0.0, 1.0, Btn.SPRINT, Btn.HEAVY) if i == 30 else H.move(0.0, 1.0, Btn.SPRINT))
	var i: int = s.start_of(&"k_sh")
	assert_eq(i, 30, "Leaping Cleave starts on the press")
	assert_almost_eq(s.moved[i - 1], SPRINT / 60.0, 1e-9, "sprinting the step before")
	assert_almost_eq(s.moved[i], s.moved[i - 1], 1e-12, "the step it starts on keeps it all")


# ------------------------------------------------------------------ lunge

func test_a_lunge_eases_in_and_out_over_the_same_window_and_distance() -> void:
	# thrown at a standstill 10 m from the opponent, so all its movement is the
	# lunge
	var s: FighterSteps = _record(Moves.KATANA, 10.0, 60, func(i: int) -> RawInput:
		return H.btn(Btn.HEAVY) if i == 0 else H.idle())
	var steps: PackedFloat64Array = []
	var frames: PackedInt32Array = []
	for i: int in s.moved.size():
		if s.attack[i] == &"k_iai" and s.moved[i] > 0.0:
			steps.append(s.moved[i])
			frames.append(s.frame[i])
	assert_eq(frames, PackedInt32Array(range(10, 26)), "it moves on frames 10 to 25 and no others")
	assert_almost_eq(_total(steps), IAI_LUNGE, 1e-9, "2.1 m in all")
	for k: int in 7:
		assert_lt(steps[k], steps[k + 1], "the steps rise to the middle (frame %d)" % frames[k + 1])
		assert_gt(steps[8 + k], steps[9 + k], "then fall (frame %d)" % frames[9 + k])
	var even_step: float = IAI_LUNGE / 16.0
	assert_lt(steps[0], even_step / 4.0, "it starts slower than a quarter of an even step")
	assert_lt(steps[15], even_step / 4.0, "and settles as slowly")


func test_a_lunge_into_a_defender_still_stops_0_25_m_clear_of_their_body() -> void:
	# 1.3 m apart, so the Iai's lunge would carry the attacker into the
	# defender. The gap is measured until the cut lands, which knocks the
	# defender back.
	var s: FighterSteps = _record(Moves.KATANA, 1.3, 30, func(i: int) -> RawInput:
		return H.btn(Btn.HEAVY) if i == 0 else H.idle())
	var closest: float = 1.3
	for i: int in s.apart.size():
		if s.attack[i] == &"k_iai" and s.frame[i] <= IAI_STARTUP:
			closest = minf(closest, s.apart[i])
	assert_almost_eq(closest, 2.0 * FIGHTER_RADIUS + LUNGE_GAP, 1e-9, "stopped with the bodies 0.25 m apart")


# ------------------------------------------------------------------ hitstun

## The spec's light hitstun: 14 frames. The lights with their own: the
## Daggers' four string lights, which follow each other faster, stun for 10
## (11.1: Off-hand Slice lands 11 frames after Quick Slice). Both Counter
## Lunges, on real markers, take their weapon's retuned light hitstun
## (milestone-1 task 22), as do the Katana string's four lights once re-keyed
## (tasks 31 and 32), bare hands' Jab, Cross and Hook (task 89; Jab and
## Cross kept 16 until then) and the grips' own hits (KE tasks 11-14).
const LIGHT_HITSTUN: int = 14
const OWN_HITSTUN: Dictionary[StringName, int] = {
	&"f_l1": 18, &"f_l2": 18, &"f_l3": 18, &"d_l1": 10, &"d_l2": 10, &"d_l3": 10, &"d_l4": 10,
	&"k_lunge": 24, &"f_lunge": 18,
	&"k_l1": 24, &"k_l2": 24, &"k_l3": 24, &"k_l4": 24, &"k_1l1": 24, &"k_1l2": 24, &"k_1l3": 24, &"k_1l4": 24, &"k_1l5": 24, &"k_2l1": 24, &"k_2l2": 24, &"k_2l3": 24, &"k_2l4": 24, &"k_2l5": 24,
	# bare hands' re-keyed movement lights take the retuned timings (tasks 93, 94)
	&"f_sl": 18, &"f_dl": 18, &"f_bl": 18, &"f_jl": 18,
	# and the Katana's (tasks 75 and 76)
	&"k_sl": 24, &"k_dl": 24, &"k_bl": 24, &"k_jl": 24,
}


## A light string's run: its events, the step of each hit, and when the
## defender came out of hitstun.
class LightStringRun:
	extends SimHelpers.Rec
	var hit_steps: PackedInt32Array = []
	## The first step the defender is out of hitstun after being hit, or -1.
	var free_step: int = -1
	var attacker_recoiled: bool = false


## A Katana throws Right Cut and Return Cut at an idle Katana defender, which
## presses block only on step press (-1 for never).
static func _right_cut_then_return_cut(press: int) -> LightStringRun:
	var W: World = H.make_world()
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var r := LightStringRun.new()
	var was_hit: bool = false
	for i: int in 120:
		# the second press, as Right Cut lands, is taken as Return Cut at its
		# branch point
		var p0: RawInput = H.btn(Btn.LIGHT) if i == 0 or i == 30 else H.idle()
		W.step([p0, H.btn(Btn.BLOCK) if i == press else H.idle()])
		var hits_before: int = r.count(&"hit")
		r.collect(W)
		if r.count(&"hit") > hits_before:
			r.hit_steps.append(i)
		if b.state == &"hitstun":
			was_hit = true
		elif was_hit and r.free_step < 0:
			r.free_step = i
		r.attacker_recoiled = r.attacker_recoiled or a.state == &"recoil"
	return r


func test_a_defender_hit_by_right_cut_can_parry_return_cut() -> void:
	var probe: LightStringRun = _right_cut_then_return_cut(-1)
	var hits: Array = probe.all(&"hit").map(func(e: Dictionary) -> Variant: return e["attack"])
	assert_eq(hits, [&"k_l1", &"k_l2"], "an idle defender takes both cuts")
	# re-keyed (task 31), Return Cut lands far enough after Right Cut that the
	# retuned hitstun (24) leaves the defender free before it (FollowUpCheck)
	assert_eq(probe.hit_steps.size(), 2)
	assert_between(probe.free_step, probe.hit_steps[0] + 1, probe.hit_steps[1] - 1, "out of hitstun before Return Cut lands")
	# pressing block a step before hitstun ends: the press waits in the buffer
	var r: LightStringRun = _right_cut_then_return_cut(probe.free_step - 1)
	assert_eq(r.count(&"hit"), 1, "only Right Cut lands")
	assert_eq(r.count(&"parry"), 1, "Return Cut is parried")
	assert_eq(r.find(&"parry").get("kind"), &"parry", "a plain parry")
	assert_true(r.attacker_recoiled, "and the attacker recoils")


func test_every_light_without_its_own_hitstun_has_14() -> void:
	var wrong: Array[String] = []
	var lights: int = 0
	for w: WeaponDef in Moves.WEAPONS.values():
		for m: AttackDef in w.moves.values():
			if m.kind != &"light":
				continue
			lights += 1
			var want: int = OWN_HITSTUN.get(m.id, LIGHT_HITSTUN)
			if m.hitstun != want:
				wrong.append("%s %d, want %d" % [m.id, m.hitstun, want])
	assert_gt(lights, 20, "every weapon's lights, bare hands included")
	assert_eq(wrong, [] as Array[String])


# ------------------------------------------------------------------ heavy dodge cancel

## The Iai Slash, tapped: 23 frames of startup (IAI_STARTUP), 4 active and
## 24 of recovery. The spec's heavy cancel opens at startup + active + half
## the recovery, rounded up: frame 39 of 51.
const IAI_ACTIVE: int = 4
const IAI_RECOVERY: int = 24
const IAI_CANCEL: int = IAI_STARTUP + IAI_ACTIVE + 12
const IAI_LAST_FRAME: int = IAI_STARTUP + IAI_ACTIVE + IAI_RECOVERY - 1
## Kept from the demo: a press waits 8 frames in the input buffer.
const INPUT_BUFFER: int = 8


## An attack and a dodge pressed during it: whether the press was made and
## whether in the air, the attack frame the dodge (or, with the stick let go
## by then, the backstep) started on (-1 if it never did), and the attack's
## last frame.
class CancelRun:
	extends SimHelpers.Rec
	var attack: StringName = &""
	var pressed: bool = false
	var pressed_in_the_air: bool = false
	var last_frame: int = -1
	var dodge_frame: int = -1
	## Whether the fighter was in the air as the step the dodge started began.
	var dodged_in_the_air: bool = false


## Fighter 0 holds start for hold steps, then presses dodge (to the side) so
## that the press first counts on its attack's frame press_on; the opponent
## holds defend throughout.
static func _cancel_run(W: World, start: RawInput, hold: int, press_on: int, defend: RawInput) -> CancelRun:
	var a: Fighter = W.fighters[0]
	var r := CancelRun.new()
	for i: int in 400:
		var p0: RawInput = start if i < hold else H.idle()
		var in_the_air: bool = a.pos.y > 0.001
		if not r.pressed and a.state == &"attack" and a.atk.frame == press_on - 1:
			p0 = H.move(1.0, 0.0, Btn.DODGE)
			r.pressed = true
			r.pressed_in_the_air = in_the_air
		W.step([p0, defend])
		r.collect(W)
		if a.state == &"attack":
			r.attack = a.atk.def.id
			r.last_frame = a.atk.frame
		elif r.attack != &"":
			if a.state == &"dodge" or a.state == &"backstep":
				r.dodge_frame = r.last_frame + 1
				r.dodged_in_the_air = in_the_air
			break
	return r


## The Iai Slash tapped at an opponent 10 m away (a whiff) or blocking 2.2 m
## away.
static func _iai(press_on: int, blocked: bool) -> CancelRun:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 2.2 if blocked else 10.0)
	return _cancel_run(W, H.btn(Btn.HEAVY), 1, press_on, H.btn(Btn.BLOCK) if blocked else H.idle())


func test_a_whiffed_heavy_dodge_cancels_in_the_second_half_of_its_recovery() -> void:
	var early: CancelRun = _iai(IAI_CANCEL - INPUT_BUFFER - 1, false)
	assert_eq(early.attack, &"k_iai")
	assert_true(early.pressed)
	assert_eq(early.dodge_frame, -1, "a dodge pressed too early for the buffer to carry never comes")
	assert_eq(early.last_frame, IAI_LAST_FRAME, "and the cut runs to its end")
	assert_eq(_iai(IAI_CANCEL - INPUT_BUFFER, false).dodge_frame, IAI_CANCEL, "a buffered press fires as the cancel opens")
	assert_eq(_iai(IAI_CANCEL + 6, false).dodge_frame, IAI_CANCEL + 6, "later presses fire at once")


func test_a_blocked_heavy_dodge_cancels_the_same_way() -> void:
	var early: CancelRun = _iai(IAI_CANCEL - INPUT_BUFFER - 1, true)
	assert_true(early.has(&"block"), "the cut is blocked")
	assert_true(early.pressed)
	assert_eq(early.dodge_frame, -1, "no cancel before the second half")
	assert_eq(early.last_frame, IAI_LAST_FRAME)
	var late: CancelRun = _iai(IAI_CANCEL - INPUT_BUFFER, true)
	assert_true(late.has(&"block"))
	assert_eq(late.dodge_frame, IAI_CANCEL, "the cancel opens on the same frame")


## The Iai Slash held for hold steps (its charge starts at step 10), pressing
## dodge so the press first counts on frame press_on.
static func _charged_iai(hold: int, press_on: int) -> CancelRun:
	var W: World = H.make_world(Moves.KATANA, Moves.KATANA, 10.0)
	return _cancel_run(W, H.btn(Btn.HEAVY), hold, press_on, H.idle())


func test_a_charged_heavy_opens_its_cancel_later_by_half_its_extra_recovery() -> void:
	# held past the charge's 2.5 s: 16 frames of extra recovery (the demo's),
	# so the cancel opens 8 frames later
	var full: int = IAI_CANCEL + 8
	var early: CancelRun = _charged_iai(170, full - INPUT_BUFFER - 1)
	assert_eq(early.last_frame, IAI_LAST_FRAME + 16, "a full charge adds 16 frames of recovery")
	assert_eq(early.dodge_frame, -1, "the uncharged cut's cancel frame isn't open")
	assert_eq(_charged_iai(170, full - INPUT_BUFFER).dodge_frame, full, "it opens 8 frames later")
	# held for 112 steps: 103 frames of charge add 11 frames of recovery, and
	# half of 11, rounded up, is 6
	var partial: int = IAI_CANCEL + 6
	early = _charged_iai(112, partial - INPUT_BUFFER - 1)
	assert_eq(early.last_frame, IAI_LAST_FRAME + 11, "103 frames of charge add 11 frames of recovery")
	assert_eq(early.dodge_frame, -1, "rounding down would open it a frame sooner")
	assert_eq(_charged_iai(112, partial - INPUT_BUFFER).dodge_frame, partial, "it opens 6 frames later")


func test_mountain_slam_cannot_be_dodge_cancelled() -> void:
	# a block ability: a dodge late in its recovery (frame 62 of its clip's
	# 74, the table's) does nothing
	var slam: AttackDef = Moves.GREATSWORD.moves[&"g_slam"]
	assert_gt(slam.total_frames(), 62, "frame 62 is in its recovery")
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 10.0, {"a": [&"g_slam", &"g_sweep"]})
	var r: CancelRun = _cancel_run(W, H.btn(Btn.BLOCK, Btn.LIGHT), 1, 62, H.idle())
	assert_eq(r.attack, &"g_slam")
	assert_true(r.pressed)
	assert_eq(r.dodge_frame, -1, "a dodge late in its recovery does nothing")
	assert_eq(r.last_frame, slam.total_frames() - 1, "the slam runs to its end")


func test_a_jump_heavy_cannot_dodge_cancel_in_the_air() -> void:
	# bare hands' Axe Kick, keyed (milestone-1 task 94), holds its strike to the
	# touchdown and opens its cancel in its landing recovery (task 59), so a
	# dodge at the cancel frame comes on the ground (the stand-in opened it in
	# the air, as the Daggers' Dive Stab did until task 17)
	var kick: AttackDef = Moves.FISTS.moves[&"f_jh"]
	var W: World = H.make_world(Moves.FISTS, Moves.KATANA, 10.0)
	W.step([H.btn(Btn.JUMP), H.idle()])
	var r: CancelRun = _cancel_run(W, H.btn(Btn.HEAVY), 1, kick.dodge_cancel_from, H.idle())
	assert_eq(r.attack, &"f_jh")
	assert_false(r.pressed_in_the_air, "thrown straight after the jump, it has landed by its cancel frame")
	assert_eq(r.dodge_frame, kick.dodge_cancel_from, "the dodge comes at the cancel frame")
	assert_false(r.dodged_in_the_air, "once the fighter has landed")


# ------------------------------------------------------------------ colossal slide

## The spec's colossal slide, as the plan sets it: 0.35 m over the first 10
## recovery frames, eased out.
const SLIDE: float = 0.35
const SLIDE_FRAMES: int = 10
## Heavy Swing's last active frame and the frame it dodge-cancels from, its
## frame data the table's (milestone-1 task 17; 18 and 26 while the move data
## set them).
static var SWING_ACTIVE_END: int = (Moves.GREATSWORD.moves[&"g_l1"] as AttackDef).startup + (Moves.GREATSWORD.moves[&"g_l1"] as AttackDef).active
static var SWING_CANCEL: int = (Moves.GREATSWORD.moves[&"g_l1"] as AttackDef).dodge_cancel_from


## How far fighter 0 moves on each of attack id's recovery frames (frames
## past startup + active), in order.
static func _recovery_steps(s: FighterSteps, id: StringName, played: WeaponDef = null) -> PackedFloat64Array:
	var def: AttackDef = played.moves.get(id) if played != null else null
	for w: WeaponDef in Moves.WEAPONS.values():
		if def == null:
			def = w.moves.get(id)
	var out: PackedFloat64Array = []
	for i: int in s.moved.size():
		if s.attack[i] == id and s.frame[i] > def.startup + def.active:
			out.append(s.moved[i])
	return out


## Asserts attack id ran past the slide's frames and moved no more than allow
## in its recovery (leftover momentum aside, nothing).
func _assert_no_slide(s: FighterSteps, id: StringName, what: String, allow: float = 0.0, played: WeaponDef = null) -> void:
	var steps: PackedFloat64Array = _recovery_steps(s, id, played)
	assert_gt(steps.size(), SLIDE_FRAMES, "%s's recovery outlasts the slide's frames" % what)
	assert_lte(_total(steps), allow, "%s doesn't slide" % what)


func test_a_whiffed_greatsword_swing_slides_into_its_recovery() -> void:
	var tap_light := func(i: int) -> RawInput: return H.btn(Btn.LIGHT) if i == 0 else H.idle()
	var swing: PackedFloat64Array = _recovery_steps(_record(Moves.GREATSWORD, 10.0, 60, tap_light), &"g_l1")
	assert_gt(swing.size(), SLIDE_FRAMES, "Heavy Swing's recovery outlasts the slide")
	assert_almost_eq(_total(swing), SLIDE, 1e-9, "it slides 0.35 m")
	for k: int in SLIDE_FRAMES - 1:
		assert_gt(swing[k], swing[k + 1], "easing out (recovery frame %d)" % (k + 2))
	assert_eq(_total(swing.slice(SLIDE_FRAMES)), 0.0, "all of it in the first 10 recovery frames")
	var katana: WeaponDef = _stand_in_katana()
	var cut: FighterSteps = _record(katana, 10.0, 90, tap_light)
	assert_eq(cut.start_of(&"k_l1"), 0)
	_assert_no_slide(cut, &"k_l1", "a Katana Right Cut (lunging, as a stand-in)", 0.0, katana)


func test_the_slide_runs_after_a_hit_and_after_a_block() -> void:
	# 1.76 m from the defender the swing lands, and the knockback, or the
	# block's pushback, carries the defender out of the slide's way (from
	# 1.66 m Heavy Swing's longer lunge, authored animation 18, ends 5 cm
	# nearer, where the block's pushback leaves the slide 1 cm short; both
	# 0.16 m further than before KE task 3's wider bodies)
	for run: Array in [[H.idle(), &"hit"], [H.btn(Btn.BLOCK), &"block"]]:
		var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 1.76)
		var a: Fighter = W.fighters[0]
		var r: H.Rec = H.Rec.new()
		var start_z: float = NAN
		var end_z: float = NAN
		for i: int in 60:
			W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), run[0]])
			r.collect(W)
			if a.state != &"attack":
				break
			if a.atk.frame == SWING_ACTIVE_END:
				start_z = a.pos.z
			elif a.atk.frame == SWING_ACTIVE_END + SLIDE_FRAMES:
				end_z = a.pos.z
		assert_true(r.has(run[1]), "the swing lands: %s" % run[1])
		assert_almost_eq(end_z - start_z, SLIDE, 1e-9, "and slides 0.35 m after the %s" % run[1])


func test_the_slide_stops_short_of_a_defender() -> void:
	# Heavy Swing whiffs from 10 m. As its active frames end, the defender is
	# put 1.36 m in front, inside the 0.35 m slide. (A block can't show this:
	# its pushback, 0.36 m, outruns the slide.)
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 10.0)
	var a: Fighter = W.fighters[0]
	var b: Fighter = W.fighters[1]
	var closest: float = INF
	for i: int in 50:
		W.step([H.btn(Btn.LIGHT) if i == 0 else H.idle(), H.idle()])
		if a.state != &"attack":
			break
		if a.atk.frame == SWING_ACTIVE_END:
			b.pos = V3.make(a.pos.x, 0.0, a.pos.z + 1.36)
		elif a.atk.frame > SWING_ACTIVE_END:
			closest = minf(closest, SimMath.dist2(a.pos, b.pos))
	assert_almost_eq(closest, 2.0 * FIGHTER_RADIUS + LUNGE_GAP, 1e-9, "it stops with the bodies 0.25 m apart")


func test_a_dodge_cancel_ends_the_slide() -> void:
	# The dodge goes to the side, so forward movement after it starts would be
	# the slide's.
	var W: World = H.make_world(Moves.GREATSWORD, Moves.KATANA, 10.0)
	var a: Fighter = W.fighters[0]
	var start_z: float = NAN
	var dodge_z: float = NAN
	var last_frame: int = -1
	var dodge_frame: int = -1
	for i: int in 60:
		var p0: RawInput = H.btn(Btn.LIGHT) if i == 0 else H.idle()
		if a.state == &"attack" and a.atk.frame == SWING_CANCEL - 1:
			p0 = H.move(1.0, 0.0, Btn.DODGE)
		W.step([p0, H.idle()])
		if a.state == &"attack":
			last_frame = a.atk.frame
			if last_frame == SWING_ACTIVE_END:
				start_z = a.pos.z
		elif a.state == &"dodge" and dodge_frame < 0:
			dodge_frame = last_frame + 1
			dodge_z = a.pos.z
	assert_eq(dodge_frame, SWING_CANCEL, "the dodge cancels the swing on its 8th recovery frame, inside the slide")
	assert_between(dodge_z - start_z, 0.3, SLIDE - 0.001, "most of the slide had run, but not all")
	assert_almost_eq(a.pos.z, dodge_z, 1e-9, "and nothing carries the fighter forward after the dodge starts")


func test_jump_attacks_and_bashes_dont_slide() -> void:
	# a jump straight up, then Aerial Chop
	var chop: FighterSteps = _record(Moves.GREATSWORD, 10.0, 90, func(i: int) -> RawInput:
		return H.btn(Btn.JUMP) if i == 0 else (H.btn(Btn.LIGHT) if i == 2 else H.idle()))
	assert_eq(chop.start_of(&"g_jl"), 2)
	_assert_no_slide(chop, &"g_jl", "Aerial Chop")
	# Guard Crusher, a block ability
	var crush: FighterSteps = _record(Moves.GREATSWORD, 10.0, 60, func(i: int) -> RawInput:
		return H.btn(Btn.BLOCK, Btn.LIGHT) if i == 0 else H.idle(), {"a": [&"g_crush", &"g_slam"]})
	assert_eq(crush.start_of(&"g_crush"), 0)
	_assert_no_slide(crush, &"g_crush", "Guard Crusher")
	# Shoulder Charge out of a sprint: only what is left of the sprint's
	# momentum, braked each frame, carries it (under 1 cm)
	var charge: FighterSteps = _record(Moves.GREATSWORD, 14.0, 70, func(i: int) -> RawInput:
		return H.move(0.0, 1.0, Btn.SPRINT, Btn.LIGHT) if i == 20 else (H.move(0.0, 1.0, Btn.SPRINT) if i < 20 else H.idle()))
	assert_eq(charge.start_of(&"g_sl"), 20)
	_assert_no_slide(charge, &"g_sl", "Shoulder Charge", 0.01)


func test_piercing_lunge_out_of_a_dodge_slides_as_a_stab() -> void:
	# a dodge to the right, then a light: Piercing Lunge, a stab, where the
	# demo's dodge light, Pommel Strike, was a bash and didn't slide
	var lunge: FighterSteps = _record(Moves.GREATSWORD, 10.0, 80, func(i: int) -> RawInput:
		return H.move(1.0, 0.0, Btn.DODGE) if i == 0 else (H.btn(Btn.LIGHT) if i == 26 else H.idle()))
	assert_gt(lunge.start_of(&"g_dl"), 0)
	assert_almost_eq(_total(_recovery_steps(lunge, &"g_dl")), SLIDE, 1e-9, "it slides 0.35 m in its recovery")
