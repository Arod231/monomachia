class_name Fighter
extends RefCounted
## Port of v0.1-web-mvp:src/sim/fighter.ts.
##
## A fighter: position, health, posture, and a frame-by-frame state machine.
## Pure simulation — no rendering code — so it can be unit tested.
##
## Port notes:
## - FState is a StringName equal to the TS literal (&"free", &"hitstun",
##   &"parryAnim"...); STATES lists them. AttackState, DodgeState, UltState,
##   FighterStats and FighterConfig are in their own files.
## - The getters moveset, airborne, hpFrac and postureFull are functions:
##   moveset(), airborne(), hp_frac(), posture_full().
## - Private TS methods start with an underscore (updateFree -> _update_free).
## - startAttack's startedBy null is -1; attackPhase's null is &"".
## - opp and world point back at the other fighter and the World: a reference
##   cycle that World.dispose() breaks.
## - Math.hypot, Math.sin, Math.cos and Math.atan2 are JsMath.hypot, .sin, .cos
##   and .atan2 (V8's exact results, see js_math.gd); Math.round is
##   SimMath.js_round; every TS division of two ints is written as a float
##   division.
## - body and hurt_capsule() are the rebuild's (task 7.5), as are
##   place_blades() and blade_segments() (task 7.9) and blade_touch() (7.10).
## - The knockdown state is authored animation's (task 16): enter_knockdown(),
##   knockdown_phase(), is_downed() and knockdown_frames().
## - The Greatsword's shoulder carry (shouldered, shoulder_lift() and the
##   lift on AttackState and UltState) is the authored-animation feature's
##   (its task 15).

## FState
const STATES: Array[StringName] = [
	&"intro",
	&"free",
	&"step",
	&"dodge",
	&"backstep",
	&"jump",
	&"land",
	&"attack",
	&"blockstun",
	&"hitstun",
	&"recoil",
	&"parryAnim",
	&"stunned",
	&"disarmStagger",
	&"stagger",
	&"pickup",
	&"stomp",
	&"leap",
	&"ult",
	&"ultChoice",
	&"recall",
	&"impaled",
	&"ko",
	&"victory",
	&"knockdown",
]

const CHARGE_CHECK_FRAME: int = 9
const GUARD_STATES: Array[StringName] = [&"free", &"step", &"blockstun", &"land", &"parryAnim"]
## The states that leave the shoulder carry as it is: the round intro and
## victory, moving (free, step) and jumping (jump, land). Entering any other
## takes the Greatsword off the shoulder at once.
const CARRY_STATES: Array[StringName] = [&"intro", &"free", &"step", &"jump", &"land", &"victory"]
## The states a grip press switches the grip in (KE task 5): those that act,
## standing, moving or blocking, attacking (the Iai stance too), landing and
## the parry's follow-through. Anywhere else it is dropped, not kept.
const GRIP_STATES: Array[StringName] = [&"free", &"step", &"attack", &"land", &"parryAnim"]

var id: int
var opp: Fighter
var world: World
var input: InputTracker = InputTracker.new()

var weapon: WeaponDef
## [string, string]
var abilities: Array[StringName]
var name: String
var armed: bool = true
## The fighter's body in the rules: its hurt capsule (task 7.5).
var body: FighterBody
## The grip the weapon is held in (WeaponGrip; KE task 5): the weapon's
## first at every round start, after a disarm and on taking a weapon (D7);
## &"" for a weapon without grips.
var grip: StringName = &""
## Which hit of a string the attack under way plays (1 to
## WeaponGrip.STRING_HITS): the next light plays the next hit of whichever
## grip the fighter holds then, so strings mix; 0 outside a string.
var string_count: int = 0

var hp: float = SimConst.HP_MAX
var posture: float = 0.0
var pos: V3 = V3.make()
var vel: V3 = V3.make()
var yaw: float = 0.0

var state: StringName = &"intro"
var sf: int = 0 # frames spent in the current state
var state_dur: int = 0 # duration for timed states
var actionable_after: int = 0 # for scripted states that may be cancelled late

var atk: AttackState = null
var dodge: DodgeState = null
var ult: UltState = null

# guard / parry
var blocking: bool = false
var block_press_frame: int = -99999
var parry_window_at_press: int = 0
var last_block_press: int = -99999
var spam_count: int = 0
var recoil_guard_after: int = 0
var last_posture_damage: int = -99999

# movement bookkeeping
var moving: bool = false
var sprint_frames: int = 0
var dodge_end_frame: int = -99999
var dodge_was_back: bool = false
## the ground direction of the last dodge or backstep (a unit vector, a new
## one each dodge), for an attack that lunges on along it; null before the
## first
var last_dodge_dir: V2 = null
var air_attack_used: bool = false
var step_dir: V2 = V2.make(0.0, 0.0)

# the Greatsword's shoulder carry
## Whether the Greatsword rests on the fighter's shoulder (Shouldered): on at
## every round start and after SimConst.GS_SHOULDER_MOVE_FRAMES frames in a
## row of moving in the free state, off at once on anything but standing
## still or jumping (a raised guard, or entering a state outside
## CARRY_STATES). Only ever true for an armed Greatsword. An attack started
## shouldered pays SimConst.GS_SHOULDER_LIFT_FRAMES (shoulder_lift()).
var shouldered: bool = false
## frames in a row of moving in the free state, toward shouldering
var shoulder_move_frames: int = 0
## frames left of the lift a guard raised from the shoulder started: an
## attack started before it ends (a block ability) waits for the rest
var guard_lift_left: int = 0

# knockback slide
var knock_x: float = 0.0
var knock_z: float = 0.0
var knock_left: int = 0
## What put the fighter in its stun (enter_stun()): &"stomp" for a stomped thrust, else &"".
var stun_cause: StringName = &""
## Whether the knockdown under way takes the retuned phases (a Katana's or
## bare hands' move knocked the fighter down) or today's (milestone-1 task
## 22; ProtectedTimings): its fall, time down, rise and guard window.
var knockdown_retuned: bool = false
## Whether the knockdown under way is the recall burst's (milestone-1 task
## 99): through its fall the fighter is carried back by the blasted fall's
## travel (SimConst.BLASTED_FALL's row of the frame-data table), facing the
## recaller.
var knockdown_blasted: bool = false
## The final blow (to_ko(); authored-animation task 28, for the KO's clip):
## whether it was a heavy, and whether it came from behind the fighter.
var ko_heavy: bool = false
var ko_from_behind: bool = false
## The last parry this fighter took part in, parrier or parried (keep_parry();
## milestone-1 task 34, for the deflect pair the view plays): the parried
## move, the attack frame it met the blade on, the contact point (world) and
## the blade's sweep there, a unit vector in the attacker's own frame
## (right, up, forward). The rules don't read them.
var parry_move: StringName = &""
var parry_frame: int = 0
var parry_pos: V3 = V3.make()
var parry_sweep: V3 = V3.make()
## The last hit or block this fighter took (keep_impact(); milestone-1 task
## 35, for the reaction the view plays): the contact point (world) and
## whether it was a heavy's (any move but a light). The rules don't read them.
var impact_pos: V3 = V3.make()
var impact_heavy: bool = false
var knock_total: int = 0
var knock_meters: float = 0.0

# follow-up windows
var counter_lunge_until: int = -99999
var backstab_until: int = -99999
var blind_until: int = -99999

# ultimates
var ult_used: bool = false
var ult_announced: bool = false
var impaled_by: Fighter = null

# scripted counter movement
var script_from: V3 = V3.make()
var script_to: V3 = V3.make()

var stats: FighterStats = FighterStats.new()


## Not in the snapshot: the links to the world and the opponent, which a
## restore keeps, and impaled_by, which the snapshot holds as a fighter id.
const SNAPSHOT_SKIP: Array[StringName] = [&"opp", &"world", &"impaled_by"]


func _init(p_id: int, cfg: FighterConfig) -> void:
	id = p_id
	weapon = cfg.weapon
	abilities = cfg.abilities if not cfg.abilities.is_empty() else cfg.weapon.default_abilities
	name = cfg.name if cfg.name != "" else cfg.weapon.name
	body = FighterBody.of(cfg.fighter_id)
	grip = weapon.first_grip()


# ------------------------------------------------------------------ snapshot

## A copy of everything the fighter owns (milestone-1 task 5, SimState):
## impaled_by as its fighter id, or -1.
func snapshot() -> Dictionary:
	var s: Dictionary = SimState.capture(self, SNAPSHOT_SKIP)
	s[&"impaled_by"] = impaled_by.id if impaled_by != null else -1
	return s


## Puts a snapshot() back (milestone-1 task 134), keeping the links to the
## world and the opponent; impaled_by is found by its id in the world.
func restore(s: Dictionary) -> void:
	var fields: Dictionary = s.duplicate()
	fields.erase(&"impaled_by")
	SimState.apply(self, fields)
	var by: int = s[&"impaled_by"]
	impaled_by = world.fighters[by] if by >= 0 else null


# ------------------------------------------------------------------ queries

func moveset() -> WeaponDef:
	return weapon if armed else Moves.FISTS


func airborne() -> bool:
	return pos.y > 0.001 or vel.y > 0.0


## The hurt capsule that blades are swept against, where the fighter stands
## now (risen with them in the air).
func hurt_capsule() -> SimCapsule:
	return body.hurt_capsule(pos)


## Each striking track of the attack's swing in the world, at this tick and
## the last (see place_blades()), in the order of the swing's tracks: empty
## outside an attack and for a move without a swing. Shared: don't change
## them.
func blade_segments() -> Array[BladeSegment]:
	if state != &"attack" or atk == null:
		return [] as Array[BladeSegment]
	return atk.blades


## The touch of this tick's blade sweeps on `capsule` (task 7.10): the
## deepest of the striking tracks' (the first on a tie), or null when none
## touches or the attack has no swing.
func blade_touch(capsule: SimCapsule) -> BladeSweep:
	var deepest: BladeSweep = null
	for b: BladeSegment in blade_segments():
		var touch: BladeSweep = BladeSweep.touch(b.prev_base, b.prev_tip, b.base, b.tip, b.half_thickness, capsule)
		if touch != null and (deepest == null or touch.depth > deepest.depth):
			deepest = touch
	return deepest


## Places each striking track of the attack's swing in the world for this
## tick, keeping the last tick's beside it: the track's pose at the attack's
## frame (entered from the move this one follows, if any) at the fighter's
## position and facing. World calls it once the fighters have moved, just
## before hits are decided, so each sweep runs between the places hits are
## decided from. A charge holds the frame, so the pose holds, and frames past
## the swing's end (a charge's extra recovery) hold its last pose. Hit-stop
## skips the whole step, so the segments hold through it. On the attack's
## first tick the last tick's segment is this one's. An unblockable's blades
## sweep SimConst.UNBLOCKABLE_SWEEP_BONUS thicker on every side (task 7.12).
func place_blades() -> void:
	if state != &"attack" or atk == null:
		return
	var def: AttackDef = atk.def
	var last: Array[BladeSegment] = atk.blades
	atk.blades = []
	if def.swing == null:
		return
	# a fist move can be started while armed (start_attack)
	var w: WeaponDef = moveset() if moveset().moves.get(def.id) == def else Moves.FISTS
	var from: Swing = atk.chained_from.swing if atk.chained_from != null else null
	for part: StringName in def.swing.parts():
		var segment: StrikeSegment = Swing.strike_segment(part, w)
		if segment == null:
			continue
		var pose: Swing.Sample = def.swing.tick(part, atk.frame, from)
		var b: BladeSegment = BladeSegment.new()
		b.part = part
		b.base = SimMath.local_to_world(pos, yaw, pose.place(segment.base))
		b.tip = SimMath.local_to_world(pos, yaw, pose.place(segment.tip))
		b.prev_base = b.base
		b.prev_tip = b.tip
		b.half_thickness = BladeSegment.half_thickness_for(segment, def)
		for before: BladeSegment in last:
			if before.part == part:
				b.prev_base = before.base
				b.prev_tip = before.tip
		atk.blades.append(b)


func hp_frac() -> float:
	return hp / SimConst.HP_MAX


func posture_full() -> bool:
	return posture >= SimConst.POSTURE_MAX - 1e-6


func can_ult() -> bool:
	return hp > 0.0 and hp <= SimConst.ULT_HP_THRESHOLD and not ult_used


func is_guard_capable() -> bool:
	if GUARD_STATES.has(state):
		return true
	if state == &"recoil" and sf >= recoil_guard_after:
		return true
	# rising in guard: the stand-up's last frames
	if state == &"knockdown" and not is_downed():
		return true
	return false


func parry_active() -> bool:
	return is_guard_capable() and world.frame - block_press_frame <= parry_window_at_press


func facing_point(p: V3) -> bool:
	return SimMath.angle_between(yaw, SimMath.yaw_to(pos, p)) <= SimConst.GUARD_HALF_ANGLE * SimMath.DEG


func is_invulnerable() -> bool:
	if (state == &"dodge" or state == &"backstep") and dodge != null:
		return sf <= dodge.iframes
	if state == &"attack" and atk != null and not atk.def.invuln.is_empty():
		var a: int = atk.def.invuln[0]
		var b: int = atk.def.invuln[1]
		return atk.frame >= a and atk.frame <= b
	if state == &"recall":
		return sf <= SimConst.RECALL_BURST_FRAME
	if state == &"ult" and ult != null and ult.kind == &"tempest" and ult.phase == &"flash":
		return true
	if state == &"disarmStagger":
		return sf <= 8
	if state == &"leap" or state == &"stomp":
		return true
	if state == &"ko" or state == &"intro" or state == &"victory":
		return true
	if state == &"knockdown":
		return is_downed()
	return false


## The protected timings of the knockdown under way (or the last one).
func knockdown_timings() -> ProtectedTimings:
	return ProtectedTimings.for_weapon(&"katana") if knockdown_retuned else ProtectedTimings.today()


## A knockdown's whole length: its fall, its time on the ground and its
## stand-up.
func knockdown_frames() -> int:
	return knockdown_timings().knockdown_frames()


## Whether the fighter is down: knocked down and not yet in the stand-up's
## guard window, so it can't be hit (not even by an undodgeable move) and
## can't guard.
func is_downed() -> bool:
	return state == &"knockdown" and sf <= knockdown_frames() - knockdown_timings().knockdown_guard


## &"fall" | &"ground" | &"standUp" while knocked down, or &"" otherwise.
func knockdown_phase() -> StringName:
	if state != &"knockdown":
		return &""
	var t: ProtectedTimings = knockdown_timings()
	if sf <= t.knockdown_fall:
		return &"fall"
	if sf <= t.knockdown_fall + t.knockdown_ground:
		return &"ground"
	return &"standUp"


## dodging toward the attacker, early enough to count as "dodging into" a thrust
func is_forward_dodging() -> bool:
	return state == &"dodge" and dodge != null and dodge.forward and sf <= SimConst.MOVE_DODGE_I_FRAMES + 3


## back-dashing (backstep or backward dodge) within its invincible frames
func is_back_dodging() -> bool:
	return (
		(state == &"backstep" or (state == &"dodge" and dodge != null and dodge.back))
		and dodge != null
		and sf <= dodge.iframes + 2
	)


func is_flash_active() -> bool:
	if state != &"attack" or atk == null or atk.def.special != &"flash":
		return false
	var d: AttackDef = atk.def
	return atk.frame > d.startup and atk.frame <= d.startup + d.active


## &"startup" | &"active" | &"recovery", or &"" (TS null) when not attacking.
func attack_phase() -> StringName:
	if state != &"attack" or atk == null:
		return &""
	var d: AttackDef = atk.def
	var f: int = atk.frame
	if atk.charging or f <= d.startup:
		return &"startup"
	if f <= d.startup + d.active:
		return &"active"
	return &"recovery"


## Whether the fighter holds a charge it can walk in (charge_move): the Iai
## stance, sheathed.
func in_stance() -> bool:
	return state == &"attack" and atk != null and atk.charging and atk.def.charge_move


## Whether the attack takes a follow-up press on attack frame f: past its
## startup, with no follow-up queued yet.
func takes_follow_up_at(f: int) -> bool:
	return state == &"attack" and atk != null and atk.queued == &"" and f > atk.def.startup


## The grip the fighter holds its weapon in (KE task 5), or null for bare
## hands and a weapon without grips.
func held_grip() -> WeaponGrip:
	return moveset().grip(grip) if armed else null


## The share of an attack's posture damage a block takes: the grip's (D2),
## or the weapon's for a weapon without grips.
func block_mitigation() -> float:
	var g: WeaponGrip = weapon.grip(grip)
	return g.block_mitigation if g != null else weapon.block_mitigation


## Arms the fighter with `w` (a Training swap), held in its first grip.
func take_weapon(w: WeaponDef) -> void:
	weapon = w
	armed = true
	grip = w.first_grip()


func speed_mult() -> float:
	return moveset().speed_mult * (1.0 if armed else SimConst.DISARMED_MULT_SPEED)


## Whether the fighter carries its weapon on the shoulder while moving: an
## armed Greatsword.
func carries_on_shoulder() -> bool:
	return armed and weapon.id == &"greatsword"


## The frames an attack (or the ultimate) started now would spend heaving the
## Greatsword off the shoulder before its frame 1: GS_SHOULDER_LIFT_FRAMES
## shouldered, the rest of a guard's lift off the shoulder, otherwise 0.
func shoulder_lift() -> int:
	return SimConst.GS_SHOULDER_LIFT_FRAMES if shouldered else guard_lift_left


# ------------------------------------------------------------------ setup

func reset_for_round(x: float, z: float, p_yaw: float) -> void:
	hp = SimConst.HP_MAX
	posture = 0.0
	armed = true
	grip = weapon.first_grip()
	string_count = 0
	pos = V3.make(x, 0.0, z)
	vel = V3.make()
	yaw = p_yaw
	atk = null
	dodge = null
	ult = null
	blocking = false
	ult_used = false
	ult_announced = false
	impaled_by = null
	stun_cause = &""
	ko_heavy = false
	ko_from_behind = false
	parry_move = &""
	parry_frame = 0
	parry_pos = V3.make()
	parry_sweep = V3.make()
	impact_pos = V3.make()
	impact_heavy = false
	counter_lunge_until = -99999
	backstab_until = -99999
	blind_until = -99999
	knock_left = 0
	sprint_frames = 0
	last_posture_damage = -99999
	block_press_frame = -99999
	_off_shoulder()
	shouldered = carries_on_shoulder()
	set_state(&"intro")


func set_state(s: StringName, dur: int = 0) -> void:
	state = s
	sf = 0
	state_dur = dur
	if not CARRY_STATES.has(s):
		_off_shoulder()
	if s != &"attack":
		atk = null
		string_count = 0
	if s != &"dodge" and s != &"backstep":
		dodge = null
	if s != &"ult":
		ult = null
	if s != &"free" and s != &"step" and s != &"blockstun" and s != &"recoil":
		blocking = false


func to_free() -> void:
	if airborne():
		set_state(&"jump")
		air_attack_used = true
	else:
		set_state(&"free")


# ------------------------------------------------------------------ main update

func update() -> void:
	sf += 1
	if guard_lift_left > 0:
		guard_lift_left -= 1
	_handle_guard_press()
	_handle_grip_press()

	match state:
		&"intro", &"victory", &"finisher", &"finished":
			# a finisher's two halves move only as FinisherRules lines them up
			vel.x = 0.0
			vel.z = 0.0
		&"free":
			_update_free()
		&"step":
			_update_step()
		&"dodge", &"backstep":
			_update_dodge()
		&"jump":
			_update_jump()
		&"land":
			if sf >= SimConst.MOVE_LAND_RECOVERY:
				set_state(&"free")
				_brake()
			elif sf >= 2 and try_actions():
				pass
			else:
				_brake()
		&"attack":
			_update_attack()
		&"blockstun":
			blocking = armed and input.is_held(Btn.BLOCK)
			if sf >= state_dur:
				set_state(&"free")
			_brake()
		&"parryAnim":
			blocking = armed and input.is_held(Btn.BLOCK)
			if sf >= state_dur:
				set_state(&"free")
				_brake()
			elif sf >= 3 and try_actions():
				pass
			else:
				_brake()
		&"recoil":
			blocking = armed and sf >= recoil_guard_after and input.is_held(Btn.BLOCK)
			if sf >= state_dur:
				set_state(&"free")
			_brake()
		&"hitstun", &"stunned", &"stagger", &"disarmStagger":
			if sf >= state_dur:
				to_free()
			_brake()
		&"pickup":
			_update_pickup()
		&"stomp":
			_update_stomp()
		&"leap":
			_update_leap()
		&"ult":
			_update_ult()
		&"ultChoice":
			_update_ult_choice()
		&"recall":
			_update_recall()
		&"impaled":
			vel.x = 0.0
			vel.z = 0.0
		&"ko":
			_brake()
		&"knockdown":
			_update_knockdown()

	_integrate()
	_update_facing()
	_update_posture()
	_update_shoulder()
	if can_ult() and not ult_announced:
		ult_announced = true
		world.emit({"t": &"ultReady", "f": id})


# ------------------------------------------------------------------ guard press

func _handle_guard_press() -> void:
	var inp: InputTracker = input
	if not inp.buffered(Btn.BLOCK, 2):
		return
	if not is_guard_capable():
		return
	inp.consume(Btn.BLOCK)
	var W: World = world
	if W.frame - last_block_press < SimConst.PARRY_SPAM_WINDOW:
		spam_count += 1
	else:
		spam_count = 0
	last_block_press = W.frame
	var base: int = moveset().parry_window
	parry_window_at_press = maxi(SimConst.PARRY_MIN_WINDOW, base - spam_count * SimConst.PARRY_SPAM_PENALTY)
	block_press_frame = W.frame
	if shouldered:
		# a parry (or a block) lifts the sword off the shoulder into the guard
		_off_shoulder(SimConst.GS_SHOULDER_LIFT_FRAMES)


# ------------------------------------------------------------------ grip

## A grip press switches to the weapon's other grip at once (KE task 5), in
## the states that act (GRIP_STATES), never changing the move playing; it
## costs nothing (D6). Anywhere else, or with bare hands or a weapon without
## grips, the press is dropped, not buffered. A press during hit-stop counts
## as the step resumes, since the input's frame holds through it.
func _handle_grip_press() -> void:
	var inp: InputTracker = input
	if not inp.buffered(Btn.GRIP, 0):
		return
	inp.consume(Btn.GRIP)
	var w: WeaponDef = moveset()
	if not armed or w.grips.size() < 2 or not GRIP_STATES.has(state):
		return
	var at: int = 0
	for i: int in w.grips.size():
		if w.grips[i].id == grip:
			at = i
	grip = w.grips[(at + 1) % w.grips.size()].id
	world.emit({"t": &"grip", "f": id, "grip": grip})


# ------------------------------------------------------------------ shoulder carry

## The shoulder carry's frame: a raised guard takes the Greatsword off the
## shoulder, and moving in the free state (walking, running, sprinting or
## stepping) puts it back on after GS_SHOULDER_MOVE_FRAMES frames in a row.
## Standing still and jumping leave it as it is; entering any state outside
## CARRY_STATES takes it off (set_state()).
func _update_shoulder() -> void:
	if not carries_on_shoulder():
		_off_shoulder()
		return
	if blocking:
		if shouldered:
			_off_shoulder(SimConst.GS_SHOULDER_LIFT_FRAMES)
		shoulder_move_frames = 0
		return
	if (state == &"free" or state == &"step") and moving:
		shoulder_move_frames += 1
		if shoulder_move_frames >= SimConst.GS_SHOULDER_MOVE_FRAMES:
			shouldered = true
	else:
		shoulder_move_frames = 0


## Takes the Greatsword off the shoulder, with `lift_left` frames still to
## run of the lift it started (a guard raised from the shoulder's).
func _off_shoulder(lift_left: int = 0) -> void:
	shouldered = false
	shoulder_move_frames = 0
	guard_lift_left = lift_left


## The lift an attack started now pays (shoulder_lift()), taking the
## Greatsword off the shoulder.
func _take_shoulder_lift() -> int:
	var lift: int = shoulder_lift()
	_off_shoulder()
	return lift


# ------------------------------------------------------------------ free / movement

func _update_free() -> void:
	if try_actions():
		return
	var inp: InputTracker = input
	blocking = armed and inp.is_held(Btn.BLOCK)
	if inp.step_request and not blocking and not inp.sprinting():
		_start_step()
		return
	_locomotion()


func _start_step() -> void:
	var inp: InputTracker = input
	var d: V2 = world_dir(inp.mx, inp.my)
	step_dir = d
	set_state(&"step", SimConst.MOVE_STEP_FRAMES)
	world.emit({"t": &"step", "f": id})
	_update_step()


func _update_step() -> void:
	if try_actions():
		return
	var inp: InputTracker = input
	if inp.is_held(Btn.BLOCK) and armed:
		set_state(&"free")
		blocking = true
		_locomotion()
		return
	var speed: float = (SimConst.MOVE_STEP_DIST / (SimConst.MOVE_STEP_FRAMES * SimConst.DT)) * speed_mult()
	vel.x = step_dir.x * speed
	vel.z = step_dir.z * speed
	moving = true
	if sf >= state_dur:
		set_state(&"free")
		if not inp.moving():
			vel.x *= 0.25
			vel.z *= 0.25


## Convert stick axes (relative to the opponent) into a world-space unit vector.
func world_dir(mx: float, my: float) -> V2:
	var to: V2 = SimMath.norm2(opp.pos.x - pos.x, opp.pos.z - pos.z)
	var rx: float = -to.z
	var rz: float = to.x
	return SimMath.norm2(to.x * my + rx * mx, to.z * my + rz * mx)


## Walk or run where the stick points. at_block_speed: at the blocking walk's
## speed and never sprinting, as while blocking (the Iai stance).
func _locomotion(at_block_speed: bool = false) -> void:
	var inp: InputTracker = input
	var mx: float = inp.mx
	var my: float = inp.my
	var mag: float = JsMath.hypot(mx, my)
	if mag > 1.0:
		mx /= mag
		my /= mag
	var active: bool = inp.dir != -1
	moving = active
	var tx: float = 0.0
	var tz: float = 0.0
	if active:
		var to: V2 = SimMath.norm2(opp.pos.x - pos.x, opp.pos.z - pos.z)
		var rx: float = -to.z
		var rz: float = to.x
		var block_pace: bool = blocking or at_block_speed
		var sprinting: bool = inp.sprinting() and not block_pace
		var s_f: float = SimConst.MOVE_RUN_FORWARD if my >= 0.0 else SimConst.MOVE_RUN_BACK
		var s_s: float = SimConst.MOVE_RUN_STRAFE
		if sprinting:
			s_f = SimConst.MOVE_SPRINT
			s_s = SimConst.MOVE_SPRINT
		var mult: float = speed_mult()
		if block_pace:
			mult *= SimConst.MOVE_BLOCK_SPEED_MULT
		tx = (to.x * my * s_f + rx * mx * s_s) * mult
		tz = (to.z * my * s_f + rz * mx * s_s) * mult
		if sprinting:
			# sprint at full speed in the held direction
			var n: V2 = SimMath.norm2(tx, tz)
			tx = n.x * SimConst.MOVE_SPRINT * mult
			tz = n.z * SimConst.MOVE_SPRINT * mult
		sprint_frames = sprint_frames + 1 if sprinting else 0
	else:
		sprint_frames = 0
	var dvx: float = tx - vel.x
	var dvz: float = tz - vel.z
	var dl: float = JsMath.hypot(dvx, dvz)
	var rate: float = (SimConst.MOVE_ACCEL if active else SimConst.MOVE_DECEL) * SimConst.DT
	if dl <= rate:
		vel.x = tx
		vel.z = tz
	else:
		vel.x += (dvx / dl) * rate
		vel.z += (dvz / dl) * rate


func _brake() -> void:
	var k: float = maxf(0.0, 1.0 - 12.0 * SimConst.DT)
	vel.x *= k
	vel.z *= k
	moving = false
	sprint_frames = 0


# ------------------------------------------------------------------ actions

func _chord_pressed() -> bool:
	var inp: InputTracker = input
	if not inp.buffered(Btn.LIGHT, SimConst.CHORD_FRAMES) or not inp.buffered(Btn.HEAVY, SimConst.CHORD_FRAMES):
		return false
	return absi(inp.press_frame[Btn.LIGHT] - inp.press_frame[Btn.HEAVY]) <= SimConst.CHORD_FRAMES


## Start whatever action the buffered input asks for. Returns true if one began.
func try_actions() -> bool:
	var inp: InputTracker = input
	var W: World = world
	if can_ult() and (inp.buffered(Btn.ULTIMATE, 4) or _chord_pressed()):
		inp.consume(Btn.ULTIMATE)
		inp.consume(Btn.LIGHT)
		inp.consume(Btn.HEAVY)
		start_ult()
		return true
	if armed and inp.is_held(Btn.BLOCK):
		if inp.buffered(Btn.LIGHT) and _ability(0) != &"":
			inp.consume(Btn.LIGHT)
			start_attack(abilities[0], Btn.LIGHT)
			return true
		if inp.buffered(Btn.HEAVY) and _ability(1) != &"":
			inp.consume(Btn.HEAVY)
			start_attack(abilities[1], Btn.HEAVY)
			return true
	if not armed and inp.buffered(Btn.INTERACT):
		var w: DroppedWeapon = W.weapon_of(id)
		if w != null and w.grounded and SimMath.dist2(w.pos, pos) <= SimConst.PICKUP_RANGE:
			inp.consume(Btn.INTERACT)
			set_state(&"pickup", SimConst.PICKUP_FRAMES)
			vel.x = 0.0
			vel.z = 0.0
			return true
	if inp.buffered(Btn.DODGE):
		inp.consume(Btn.DODGE)
		start_dodge()
		return true
	if inp.buffered(Btn.JUMP) and not airborne():
		inp.consume(Btn.JUMP)
		_start_jump()
		return true
	if inp.buffered(Btn.LIGHT):
		inp.consume(Btn.LIGHT)
		var light: StringName = _context_attack(&"light")
		var g: WeaponGrip = held_grip()
		start_attack(light, Btn.LIGHT, null, 1 if g != null and light == g.hit(1) else 0)
		return true
	if inp.buffered(Btn.HEAVY):
		inp.consume(Btn.HEAVY)
		start_attack(_context_attack(&"heavy"), Btn.HEAVY)
		return true
	return false


## this.abilities[i], or &"" where the TS would read undefined.
func _ability(i: int) -> StringName:
	return abilities[i] if i < abilities.size() else &""


## kind: &"light" | &"heavy"
func _context_attack(kind: StringName) -> StringName:
	var w: WeaponDef = moveset()
	var W: World = world
	var L: bool = kind == &"light"
	if L and W.frame <= counter_lunge_until:
		counter_lunge_until = -99999
		return Moves.COUNTER_LUNGE[w.id]
	if airborne():
		return w.jump_light if L else w.jump_heavy
	if sprint_frames >= SimConst.MOVE_SPRINT_ATTACK_MIN_FRAMES:
		return w.sprint_light if L else w.sprint_heavy
	if W.frame - dodge_end_frame <= SimConst.MOVE_FOLLOW_WINDOW:
		if dodge_was_back:
			return w.back_light if L else w.back_heavy
		return w.dodge_light if L else w.dodge_heavy
	# a light from neutral starts the grip's string (KE task 5)
	var g: WeaponGrip = held_grip()
	if L and g != null:
		return g.hit(1)
	return w.light_start if L else w.heavy_start


## started_by: the Btn that started the move, or -1 (TS null). chained_from:
## the move this one follows, for a follow-up (its swing's entry). hit: the
## hit of its grip's string the move plays (string_count), 0 outside one.
func start_attack(p_id: StringName, started_by: int = -1, chained_from: AttackDef = null, hit: int = 0) -> bool:
	var W: World = world
	var def: AttackDef = moveset().moves.get(p_id, null)
	if def == null and String(p_id).begins_with("f_"):
		def = Moves.FISTS.moves.get(p_id, null)
	if def == null:
		# the move belongs to a weapon we no longer hold (e.g. disarmed mid-combo)
		if state == &"attack":
			to_free()
		return false
	var was_dodging: bool = state == &"dodge" or state == &"backstep"
	if was_dodging:
		dodge_end_frame = W.frame
		dodge_was_back = dodge != null and dodge.back
	var lift: int = _take_shoulder_lift()
	set_state(&"attack")
	blocking = false
	string_count = hit
	var lunge_total: float = def.lunge_from(SimMath.dist2(pos, opp.pos))
	atk = AttackState.new()
	atk.def = def
	atk.chained_from = chained_from
	atk.frame = 0
	atk.hit_done = false
	atk.hits_done = 0
	atk.charging = false
	atk.charge_frames = 0
	atk.charge_frac = 0.0
	atk.queued = &""
	atk.queued_hit = 0
	atk.queued_branch = &""
	atk.lunge_total = lunge_total
	atk.lunge_dir = last_dodge_dir if def.lunge_along_dodge else null
	atk.extra_recovery = 0
	atk.backstab = def.kind == &"light" and W.frame <= backstab_until
	atk.started_by = started_by
	atk.lift = lift
	atk.lift_left = lift
	atk.evaded_emitted = false
	atk.whiff_emitted = false
	atk.landed = -1 if not def.fits_airtime() or airborne() else 0
	if atk.backstab:
		backstab_until = -99999
	if def.airborne:
		air_attack_used = true
	sprint_frames = 0
	if def.counter != &"":
		world.emit({"t": &"telegraph", "f": id, "kind": def.counter, "attack": def.id})
	if def.special == &"shadowStep":
		_plan_shadow_step()
	if def.by_travel and not def.airborne:
		# a move led by its clip keeps none of a run's speed: its travel moves
		# it (milestone-1 task 21)
		vel.x = 0.0
		vel.z = 0.0
	elif not def.airborne and def.hop == 0.0:
		# keep some of the momentum (jump attacks and hop attacks keep it all)
		vel.x *= SimConst.ATTACK_MOMENTUM_KEEP
		vel.z *= SimConst.ATTACK_MOMENTUM_KEEP
	return true


func _plan_shadow_step() -> void:
	var o: V3 = opp.pos
	var dx: float = pos.x - o.x
	var dz: float = pos.z - o.z
	var r0: float = maxf(1.0, JsMath.hypot(dx, dz))
	var a0: float = JsMath.atan2(dx, dz)
	# circle toward the held side, default to the right
	var side: float = -1.0 if input.mx < -0.3 else 1.0
	atk.path_from = AttackState.PathPoint.make(a0, r0)
	atk.path_to = AttackState.PathPoint.make(a0 + side * PI * 0.95, 1.35)


func _update_attack() -> void:
	var a: AttackState = atk
	var def: AttackDef = a.def
	var inp: InputTracker = input
	var W: World = world

	# Light + heavy within a few frames: cancel into the ultimate, which pays
	# what is left of the attack's lift off the shoulder.
	var lifted: int = a.lift - a.lift_left
	if a.frame + lifted <= SimConst.CHORD_FRAMES and a.started_by != -1 and can_ult() and def.kind != &"ability":
		var other: int = Btn.HEAVY if a.started_by == Btn.LIGHT else Btn.LIGHT
		if inp.buffered(other, SimConst.CHORD_FRAMES):
			inp.consume(other)
			start_ult(a.lift_left)
			return

	# Heaving the Greatsword off the shoulder: the attack holds its frame 0.
	if a.lift_left > 0:
		a.lift_left -= 1
		if not def.airborne and not airborne():
			_brake()
		return

	# Charging a heavy. A tapped heavy is drawn here, as its sheathe ends, and a
	# held one as its stance ends, on release or at CHARGE_MAX; the stick then
	# picks the draw.
	if def.chargeable and not a.charging and a.charge_frames == 0 and a.frame == CHARGE_CHECK_FRAME:
		if inp.is_held(Btn.HEAVY):
			a.charging = true
		else:
			def = _pick_draw()
	if a.charging:
		if def.charge_move:
			# a charge the fighter walks in (the Iai stance): a dodge cancels it
			if inp.buffered(Btn.DODGE):
				inp.consume(Btn.DODGE)
				start_dodge()
				return
			_locomotion(true)
		else:
			_brake()
		a.charge_frames += 1
		if not inp.is_held(Btn.HEAVY) or a.charge_frames >= SimConst.CHARGE_MAX:
			a.charging = false
			if a.charge_frames >= SimConst.CHARGE_MAX:
				a.charge_frac = 1.0
			elif a.charge_frames >= SimConst.CHARGE_MIN:
				a.charge_frac = SimMath.clamp(float(a.charge_frames) / float(SimConst.CHARGE_MAX), 0.0, 0.95)
			else:
				a.charge_frac = 0.0
			a.extra_recovery += SimMath.js_round(16.0 * a.charge_frac)
			def = _pick_draw()
		else:
			return

	a.frame += 1
	var f: int = a.frame
	var S: int = def.startup
	var A: int = def.active

	# Lunge along our facing (or on along the last dodge), easing in and out
	# over its window.
	var ls: int = def.lunge_start
	var share: float = def.lunge_share(f)
	if a.lunge_total > 0.0 and share > 0.0:
		if a.lunge_dir != null:
			_advance_along(a.lunge_dir, a.lunge_total * share)
		else:
			_advance(a.lunge_total * share)
	# A move led by its clip moves by its travel instead (milestone-1 task 21).
	if def.by_travel:
		_travel(def.travel_at(f))
	# A colossal swing slides on into its first recovery frames, easing out.
	var into_recovery: int = f - S - A
	if into_recovery > 0 and into_recovery <= SimConst.COLOSSAL_SLIDE_FRAMES and _slides(def):
		var n: float = float(SimConst.COLOSSAL_SLIDE_FRAMES)
		var slid: float = SimMath.ease_out_cubic(float(into_recovery) / n) - SimMath.ease_out_cubic(float(into_recovery - 1) / n)
		_advance(SimConst.COLOSSAL_SLIDE_DIST * slid)
	if def.hop != 0.0 and f == ls + 1 and not airborne():
		vel.y = def.hop
	if def.airborne and not def.fits_airtime() and def.type == &"overhead" and f == S + 1 and airborne():
		vel.y = minf(vel.y, -6.0)
	if (not def.airborne or a.landed >= 0) and not airborne():
		_brake()

	if f == S:
		world.emit({
			"t": &"swing",
			"f": id,
			"attack": def.id,
			"heavy": def.kind != &"light",
			"weapon": moveset().id,
			# the hit sound, by which a leg strike whooshes cloth (task 95)
			"sound": def.sound,
		})

	if def.special == &"shadowStep":
		_update_shadow_step(f)

	# Whiff notice once the active frames pass without contact.
	if f == S + A + 1 and not a.hit_done and def.damage > 0.0 and not a.whiff_emitted:
		a.whiff_emitted = true
		world.emit({"t": &"whiff", "f": id, "attack": def.id})

	# Combo chains: a follow-up pressed after the startup and by the last frame
	# of its window starts at its branch point, or at once if that has passed
	# (the frame-data table's, milestone-1 task 20); any extra recovery (a
	# charge's) moves the window's end on with the move's. A weapon with grips
	# plays its string by count (KE task 5): see _light_follow_up().
	if takes_follow_up_at(f):
		var light: Array = _light_follow_up(def)
		var heavy: StringName = _heavy_follow_up(def)
		if _can_follow(light[0], _window(def, def.chain_light, light[0]), Btn.LIGHT, f):
			inp.consume(Btn.LIGHT)
			a.queued = light[0]
			a.queued_hit = light[1]
			a.queued_branch = def.chain_light if def.chain_light != &"" else light[0]
		elif _can_follow(heavy, _window(def, def.chain_heavy, heavy), Btn.HEAVY, f):
			inp.consume(Btn.HEAVY)
			a.queued = heavy
			a.queued_hit = 0
			a.queued_branch = def.chain_heavy if def.chain_heavy != &"" else heavy
	if a.queued != &"" and f >= def.branch_window(a.queued_branch)[0]:
		start_attack(a.queued, -1, def, a.queued_hit)
		return

	# Dodge-cancel the recovery in the move's window (the table's), opening
	# later by half any extra recovery (a charge's) and closing later by all
	# of it, and never in the air.
	if (
		def.dodge_cancel_from != AttackDef.UNSET
		and f >= def.dodge_cancel_from + ceili(a.extra_recovery / 2.0)
		and (def.dodge_cancel_to == AttackDef.UNSET or f <= def.dodge_cancel_to + a.extra_recovery)
		and not airborne()
		and inp.buffered(Btn.DODGE)
	):
		inp.consume(Btn.DODGE)
		start_dodge()
		return

	if _attack_ends_at(a, f):
		if def.special == &"shadowStep":
			backstab_until = W.frame + 30
		atk = null
		to_free()


## Whether attack `a` ends on its frame `f`: after its recovery, or a
## jump attack (milestone-1 task 59) only once it has landed, its landing
## recovery after its touchdown (or after its last active frame, had it
## landed before then); in the air it holds on, its frames running on.
func _attack_ends_at(a: AttackState, f: int) -> bool:
	var def: AttackDef = a.def
	if def.fits_airtime():
		if a.landed < 0:
			return false
		return f >= maxi(a.landed, def.startup + def.active) + def.landing_recovery() + a.extra_recovery
	return f >= def.startup + def.active + def.recovery + a.extra_recovery


## Whether the attack takes follow-up `follow` (none for &"") pressed with
## button `b` on attack frame `f`: buffered, not held under a block, and by
## the last frame of its `window`.
func _can_follow(follow: StringName, window: PackedInt32Array, b: int, f: int) -> bool:
	if follow == &"" or not input.buffered(b) or (armed and input.is_held(Btn.BLOCK)):
		return false
	return f <= window[1] + atk.extra_recovery


## The light follow-up of move `def`, [move, the string's hit it plays]. A
## weapon with grips plays its string by count (KE task 5): after a string's
## hit n the next light plays hit n + 1 of the grip the fighter holds now,
## wherever hit n came from, and nothing after the last hit (D4); after a
## move outside a string, its light follow-up's place in a string (the
## horizontal Iai's Return Cut, hit 2) in the held grip's string. Otherwise
## the move's own light follow-up, outside a string: [&"", 0] for none.
func _light_follow_up(def: AttackDef) -> Array:
	var g: WeaponGrip = held_grip()
	if g == null:
		return [def.chain_light, 0]
	if string_count > 0:
		var n: int = string_count + 1
		return [g.hit(n), n] if n <= WeaponGrip.STRING_HITS else [&"", 0]
	var at: int = moveset().string_position(def.chain_light)
	return [g.hit(at), at] if at > 0 else [def.chain_light, 0]


## The heavy follow-up of move `def`. A weapon with grips (KE task 7): after
## any hit of a string, the held grip's heavy; after the weapon's heavy
## starter (the vertical Iai), the grip's heavy follow-up of it (D5).
## Otherwise, or where the grip names none, the move's own.
func _heavy_follow_up(def: AttackDef) -> StringName:
	var g: WeaponGrip = held_grip()
	if g != null:
		if string_count > 0 and g.heavy != &"":
			return g.heavy
		if def.id == moveset().heavy_start and def.chain_heavy != &"" and g.draw_heavy != &"":
			return g.draw_heavy
	return def.chain_heavy


## The frames follow-up `follow` of move `def` may start on: those of the
## move's own follow-up `own` (its light or heavy) when it has one, so a
## grip's move in its place keeps the move's branch point, else the move's
## window for `follow` itself.
func _window(def: AttackDef, own: StringName, follow: StringName) -> PackedInt32Array:
	return def.branch_window(own if own != &"" else follow)


## The follow-up the attack playing takes from a heavy press (`heavy`) or a
## light one, and the frames it may start on: [move, window], [&"", []]
## for none or no attack. The computer presses for it as a player would
## (KE task 9), so its strings follow the grip held.
func follow_up(heavy: bool) -> Array:
	if state != &"attack" or atk == null:
		return [&"", PackedInt32Array()]
	var def: AttackDef = atk.def
	var follow: StringName = _heavy_follow_up(def) if heavy else _light_follow_up(def)[0]
	if follow == &"":
		return [&"", PackedInt32Array()]
	return [follow, _window(def, def.chain_heavy if heavy else def.chain_light, follow)]


## As a chargeable heavy is drawn, the stick held sideways (as Moonsplitter
## picks its wave) swaps its release variant in on the same attack state, so
## the frames, lunge and charge carry on: the horizontal Iai. Otherwise the
## move stays. Returns the attack's move.
func _pick_draw() -> AttackDef:
	var variant: AttackDef = moveset().moves.get(atk.def.release_variant, null)
	if variant != null and input.sideways():
		atk.def = variant
	return atk.def


## Whether def slides on into its recovery: a colossal weapon's grounded
## attacks, bashes aside.
func _slides(def: AttackDef) -> bool:
	return moveset().cls == &"colossal" and not def.airborne and def.type != &"bash" and not def.by_travel


## Moves the body by one frame of a clip's travel (AttackDef.travel_at():
## forward and to the right in the frame it faces now, then the turn to the
## right), holding back only the part that closes on the opponent, as a
## lunge does (_advance_along()).
func _travel(step: PackedFloat64Array) -> void:
	var move: V3 = SimMath.local_to_world(V3.make(), yaw, V3.make(step[1], 0.0, step[0]))
	var dist: float = JsMath.hypot(move.x, move.z)
	if dist > 0.0:
		_advance_along(V2.make(move.x / dist, move.z / dist), dist)
	yaw = SimMath.wrap_angle(yaw - step[2] * SimMath.DEG)


## How far we can still close on the opponent before our bodies are 0.25 m
## apart (SimConst.CLOSING_GAP), or touch for a knee strike (AttackDef.closing_gap()).
func _room_to_close() -> float:
	var gap: float = atk.def.closing_gap() if atk != null else SimConst.CLOSING_GAP
	return maxf(0.0, SimMath.dist2(pos, opp.pos) - (SimConst.FIGHTER_RADIUS * 2.0 + gap))


## Advance up to dist along our facing, stopping with our bodies 0.25 m apart.
func _advance(dist: float) -> void:
	var step: float = minf(dist, _room_to_close())
	var dir: V2 = SimMath.fwd(yaw)
	pos.x += dir.x * step
	pos.z += dir.z * step


## Advance dist along dir (a unit vector), holding back only the part that
## closes on the opponent, so that part stops with our bodies 0.25 m apart
## while the part across the line to them carries on.
func _advance_along(dir: V2, dist: float) -> void:
	var to: V2 = SimMath.norm2(opp.pos.x - pos.x, opp.pos.z - pos.z)
	var closing: float = (dir.x * to.x + dir.z * to.z) * dist
	var across_x: float = dir.x * dist - to.x * closing
	var across_z: float = dir.z * dist - to.z * closing
	if closing > 0.0:
		closing = minf(closing, _room_to_close())
	pos.x += across_x + to.x * closing
	pos.z += across_z + to.z * closing


func _update_shadow_step(f: int) -> void:
	var a: AttackState = atk
	var def: AttackDef = a.def
	var S: int = def.startup
	var A: int = def.active
	if f > S and f <= S + A and a.path_from != null and a.path_to != null:
		var t: float = SimMath.ease_out_cubic(float(f - S) / float(A))
		var ang: float = a.path_from.ang + (a.path_to.ang - a.path_from.ang) * t
		var r: float = a.path_from.r + (a.path_to.r - a.path_from.r) * t
		pos.x = opp.pos.x + JsMath.sin(ang) * r
		pos.z = opp.pos.z + JsMath.cos(ang) * r
		yaw = SimMath.yaw_to(pos, opp.pos)
		if f == S + A:
			opp.blind_until = world.frame + 6
			world.emit({"t": &"backstabReady", "f": id})


# ------------------------------------------------------------------ dodge / jump

func start_dodge() -> void:
	var inp: InputTracker = input
	var W: World = world
	var mult: float = moveset().dodge_mult * (1.0 if armed else SimConst.DISARMED_MULT_DODGE)
	var to: V2 = SimMath.norm2(opp.pos.x - pos.x, opp.pos.z - pos.z)
	if inp.dir == -1:
		set_state(&"backstep")
		dodge = DodgeState.make(
			-to.x,
			-to.z,
			SimConst.MOVE_BACKSTEP_DIST * mult,
			SimConst.MOVE_BACKSTEP_FRAMES,
			SimConst.MOVE_BACKSTEP_I_FRAMES,
			SimConst.MOVE_BACKSTEP_RECOVERY,
			true,
			false,
		)
	else:
		var dv: RawInput = InputTracker.dir_vector(inp.dir)
		var d: V2 = world_dir(dv.mx, dv.my)
		set_state(&"dodge")
		dodge = DodgeState.make(
			d.x,
			d.z,
			SimConst.MOVE_DODGE_DIST * mult,
			SimConst.MOVE_DODGE_FRAMES,
			SimConst.MOVE_DODGE_I_FRAMES,
			SimConst.MOVE_DODGE_RECOVERY,
			inp.dir >= 3 and inp.dir <= 5,
			inp.dir == 0 or inp.dir == 1 or inp.dir == 7,
		)
	last_dodge_dir = V2.make(dodge.dir_x, dodge.dir_z)
	vel.x = 0.0
	vel.z = 0.0
	sprint_frames = 0
	W.emit({"t": &"dodge", "f": id, "back": dodge.back})


func _update_dodge() -> void:
	var dg: DodgeState = dodge
	var f: int = sf
	if f <= dg.frames:
		# a roll travels along Roll01's curve, the backstep eases out
		var roll: bool = state == &"dodge"
		var t0: float = SimMath.roll_travel(float(f - 1) / float(dg.frames)) if roll else SimMath.ease_out_cubic(float(f - 1) / float(dg.frames))
		var t1: float = SimMath.roll_travel(float(f) / float(dg.frames)) if roll else SimMath.ease_out_cubic(float(f) / float(dg.frames))
		var step: float = (t1 - t0) * dg.dist
		pos.x += dg.dir_x * step
		pos.z += dg.dir_z * step
		vel.x = 0.0
		vel.z = 0.0
	# follow-up attacks are allowed once the invincible part is over
	if f > dg.iframes:
		var inp: InputTracker = input
		if (
			inp.buffered(Btn.LIGHT)
			or inp.buffered(Btn.HEAVY)
			or (f > dg.frames and (inp.buffered(Btn.DODGE) or inp.buffered(Btn.JUMP)))
		):
			dodge_end_frame = world.frame
			dodge_was_back = dg.back
			if try_actions():
				return
	if f >= dg.frames + dg.recovery:
		dodge_end_frame = world.frame
		dodge_was_back = dg.back
		set_state(&"free")


func _start_jump() -> void:
	var h: float = SimConst.MOVE_JUMP_HEIGHT * (1.0 if armed else SimConst.DISARMED_MULT_JUMP)
	vel.y = sqrt(2.0 * SimConst.GRAVITY * h)
	var inp: InputTracker = input
	if inp.moving():
		var d: V2 = world_dir(inp.mx, inp.my)
		var s: float = (SimConst.MOVE_SPRINT if inp.sprinting() else SimConst.MOVE_RUN_STRAFE) * speed_mult()
		vel.x = d.x * s
		vel.z = d.z * s
	set_state(&"jump")
	air_attack_used = false
	world.emit({"t": &"jump", "f": id})


func _update_jump() -> void:
	var inp: InputTracker = input
	if not air_attack_used:
		# a press too late for the move to fit the airtime left is ignored
		# (milestone-1 task 59)
		if inp.buffered(Btn.LIGHT):
			inp.consume(Btn.LIGHT)
			if _air_move_fits(moveset().jump_light):
				start_attack(moveset().jump_light, Btn.LIGHT)
				return
		if inp.buffered(Btn.HEAVY):
			inp.consume(Btn.HEAVY)
			if _air_move_fits(moveset().jump_heavy):
				start_attack(moveset().jump_heavy, Btn.HEAVY)
				return
	# gentle air steering
	if inp.moving():
		var d: V2 = world_dir(inp.mx, inp.my)
		vel.x += d.x * 6.0 * SimConst.DT
		vel.z += d.z * 6.0 * SimConst.DT
		var s: float = JsMath.hypot(vel.x, vel.z)
		var cap: float = SimConst.MOVE_SPRINT * speed_mult()
		if s > cap:
			vel.x *= cap / s
			vel.z *= cap / s


## Whether jump attack `def` started now fits the airtime left (milestone-1
## task 59, spec P53): its last active frame comes no later than the step
## the fighter touches down on.
func air_attack_fits(def: AttackDef) -> bool:
	return def.startup + def.active < steps_to_land()


## Whether jump attack `def` may start now: one that keeps the airtime rule
## while it fits; the Greatsword's and the Daggers' always (fits_airtime()).
func _air_move_ok(def: AttackDef) -> bool:
	return not def.fits_airtime() or air_attack_fits(def)


func _air_move_fits(move_id: StringName) -> bool:
	var def: AttackDef = moveset().moves.get(move_id, null)
	return def != null and _air_move_ok(def)


## The steps until the fighter touches down on the rules' arc, this one
## counted (the touchdown's included): 1 on the step it lands, 0 on the
## ground. The same steps as _integrate(), so exact.
func steps_to_land() -> int:
	if not airborne():
		return 0
	var y: float = pos.y
	var vy: float = vel.y
	var n: int = 0
	while n == 0 or y > 0.0 or vy >= 0.0:
		vy -= SimConst.GRAVITY * SimConst.DT
		y += vy * SimConst.DT
		n += 1
	return n


# ------------------------------------------------------------------ physics

func _integrate() -> void:
	if state == &"impaled" or state == &"leap" or state == &"stomp":
		return
	var was_air: bool = pos.y > 0.001

	# strafing orbits the opponent: keep distance when moving sideways only
	var keep: float = -1.0
	if (state == &"free" or state == &"step" or in_stance()) and moving and absf(input.my) < 0.25:
		keep = SimMath.dist2(pos, opp.pos)

	pos.x += vel.x * SimConst.DT
	pos.z += vel.z * SimConst.DT

	if keep > 0.0 and keep < 9.0:
		var dx: float = pos.x - opp.pos.x
		var dz: float = pos.z - opp.pos.z
		var d: float = JsMath.hypot(dx, dz)
		if d > 1e-6:
			pos.x = opp.pos.x + (dx / d) * keep
			pos.z = opp.pos.z + (dz / d) * keep

	# knockback slide
	if knock_left > 0:
		var T: int = knock_total
		var k: int = T - knock_left
		var d: float = (knock_meters * 2.0 * float(T - k)) / float(T * (T + 1))
		pos.x += knock_x * d
		pos.z += knock_z * d
		knock_left -= 1

	# vertical
	if was_air or vel.y > 0.0:
		vel.y -= SimConst.GRAVITY * SimConst.DT
		pos.y += vel.y * SimConst.DT
		if pos.y <= 0.0:
			pos.y = 0.0
			var falling: bool = vel.y < 0.0
			vel.y = 0.0
			if falling:
				_on_land()


func _on_land() -> void:
	world.emit({"t": &"land", "f": id})
	if state == &"jump":
		set_state(&"land", SimConst.MOVE_LAND_RECOVERY)
		vel.x *= 0.4
		vel.z *= 0.4
	elif state == &"attack" and atk != null and atk.def.fits_airtime() and atk.landed < 0:
		# a jump attack lands into its landing recovery, skipping none of its
		# frames (milestone-1 task 59), slowing as a jump's landing does
		atk.landed = atk.frame
		vel.x *= 0.4
		vel.z *= 0.4
	elif state == &"attack" and atk != null and atk.def.airborne and not atk.def.fits_airtime():
		# the Greatsword's and the Daggers' (until milestone 2): landing ends
		# the air attack's active part quickly
		var a: AttackState = atk
		var d: AttackDef = a.def
		if a.frame < d.startup + d.active:
			a.frame = maxi(a.frame, d.startup)
			a.lift_left = 0


func _update_facing() -> void:
	var W: World = world
	var target: float = SimMath.yaw_to(pos, opp.pos)
	var rate: float = SimConst.MOVE_TURN_RATE
	match state:
		&"attack":
			var ph: StringName = attack_phase()
			var d: AttackDef = atk.def
			if d.special == &"shadowStep":
				return
			rate = (
				3.0 if atk.charging
				else (d.track_startup if ph == &"startup" else (d.track_active if ph == &"active" else 0.5))
			)
		&"hitstun", &"stunned", &"stagger", &"disarmStagger", &"recoil":
			rate = 2.0
		&"ko", &"impaled", &"leap":
			return
		&"knockdown":
			# down, the body doesn't turn; rising in guard, it turns to face
			if is_downed():
				return
		&"ult":
			var up: StringName = ult.phase if ult != null else &""
			rate = 8.0 if up == &"windup" or up == &"aim" else (0.6 if up == &"dash" else 3.0)
	if W.frame < blind_until:
		rate = 0.0
	yaw = SimMath.turn_toward(yaw, target, rate * SimConst.DT)


func _update_posture() -> void:
	var W: World = world
	if state == &"ko":
		return
	if armed:
		if (
			blocking
			and state == &"free"
			and W.frame - last_posture_damage >= SimConst.POSTURE_RECOVER_DELAY
			and posture > 0.0
		):
			var is_moving: bool = JsMath.hypot(vel.x, vel.z) > 0.3
			var base: float = SimConst.POSTURE_RECOVER_MOVE if is_moving else SimConst.POSTURE_RECOVER_STAND
			var hp_f: float = SimConst.POSTURE_RECOVER_HP_FLOOR + (1.0 - SimConst.POSTURE_RECOVER_HP_FLOOR) * hp_frac()
			posture = maxf(0.0, posture - base * hp_f * SimConst.DT)
	elif (
		W.frame - last_posture_damage >= SimConst.DISARMED_POSTURE_DELAY
		and state != &"stagger"
		and posture > 0.0
	):
		posture = maxf(0.0, posture - SimConst.DISARMED_POSTURE_RECOVER * SimConst.DT)


# ------------------------------------------------------------------ damage & reactions

func add_posture(amount: float) -> void:
	if amount <= 0.0:
		return
	posture = minf(SimConst.POSTURE_MAX, posture + amount)
	last_posture_damage = world.frame


func knock(from_x: float, from_z: float, meters: float, frames: int = 14) -> void:
	var d: V2 = SimMath.norm2(pos.x - from_x, pos.z - from_z)
	knock_x = d.x
	knock_z = d.z
	knock_meters = meters
	knock_total = maxi(2, frames)
	knock_left = knock_total


func enter_hitstun(frames: int) -> void:
	set_state(&"hitstun", frames)
	vel.x = 0.0
	vel.z = 0.0


func enter_stun(frames: int, kind: StringName = &"stunned", cause: StringName = &"") -> void:
	set_state(kind, frames)
	stun_cause = cause
	vel.x = 0.0
	vel.z = 0.0


## Knocked down (task 16), in place of hitstun, by a hit from an unblockable,
## a full charge or a Greatsword slam (World.knocks_down()), its phases those
## of `t`, the protected timings of the move that knocked it down (today's
## when none is given).
func enter_knockdown(t: ProtectedTimings = null) -> void:
	knockdown_retuned = t != null and t.retuned
	knockdown_blasted = false
	set_state(&"knockdown", knockdown_frames())
	vel.x = 0.0
	vel.z = 0.0


## Lies still through the fall and on the ground, then stands up: in the
## stand-up's guard window the fighter may block or parry but not attack,
## dodge or move. Free on the last frame.
func _update_knockdown() -> void:
	_brake()
	if knockdown_blasted and knockdown_phase() == &"fall":
		_travel(FrameDataTable.shared().clip_travel_at(SimConst.BLASTED_FALL, sf))
	blocking = armed and not is_downed() and input.is_held(Btn.BLOCK)
	if sf >= state_dur:
		world.emit({"t": &"standup", "f": id})
		to_free()


## Keeps a parry (parry_move and the rest): move `move` parried on its
## attack frame `at_frame` at `contact`, its blade sweeping `sweep` (world,
## unit) there, the attacker facing `attacker_yaw`.
func keep_parry(move: StringName, at_frame: int, contact: V3, sweep: V3, attacker_yaw: float) -> void:
	parry_move = move
	parry_frame = at_frame
	parry_pos = V3.make(contact.x, contact.y, contact.z)
	var f: V2 = SimMath.fwd(attacker_yaw)
	var r: V2 = SimMath.right(attacker_yaw)
	parry_sweep = V3.make(sweep.x * r.x + sweep.z * r.z, sweep.y, sweep.x * f.x + sweep.z * f.z)


## Keeps a hit or a block taken (impact_pos and impact_heavy) at `contact`.
func keep_impact(contact: V3, heavy: bool) -> void:
	impact_pos = V3.make(contact.x, contact.y, contact.z)
	impact_heavy = heavy


func enter_recoil(frames: int, guard_after: int) -> void:
	set_state(&"recoil", frames)
	recoil_guard_after = guard_after
	vel.x = 0.0
	vel.z = 0.0


## reason: &"parried" | &"blocked" | &"redirect". The stagger is that of `t`,
## the protected timings of the move that disarmed (the parried or blocked
## one), or of this fighter's weapon when none is given.
func disarm(by: Fighter, reason: StringName, t: ProtectedTimings = null) -> void:
	var W: World = world
	# read the blades before the stagger ends the attacks
	var flies: V2 = DroppedWeapon.heading(self, by, reason)
	if t == null:
		t = ProtectedTimings.for_weapon(weapon.id if weapon != null else &"")
	armed = false
	# bare hands have no grip; the weapon comes back in its first (D7)
	grip = weapon.first_grip() if weapon != null else &""
	posture = 0.0
	last_posture_damage = W.frame
	set_state(&"disarmStagger", t.disarm_stagger)
	knock(by.pos.x, by.pos.z, 1.3, 16)
	W.spawn_dropped_weapon(self, flies)
	W.emit({
		"t": &"disarm",
		"victim": id,
		"by": by.id,
		"pos": SimEvents.vec3(V3.make(pos.x, 1.2, pos.z)),
		"reason": reason,
	})
	by.stats.disarms += 1
	FinisherRules.on_disarm(W, self, by, reason)


# ------------------------------------------------------------------ pickup / counters

func _update_pickup() -> void:
	_brake()
	if sf == SimConst.PICKUP_ATTACH_FRAME:
		var w: DroppedWeapon = world.weapon_of(id)
		if w != null and SimMath.dist2(w.pos, pos) <= SimConst.PICKUP_RANGE + 0.5:
			world.remove_dropped_weapon(id)
			armed = true
			world.emit({"t": &"pickup", "f": id})
	if sf >= state_dur:
		set_state(&"free")


## Hops onto the blade of `attacker`'s thrust: landing `pin` m in front of
## where the attacker ends up once jolted back `push` m (World's stomp).
func begin_stomp(attacker: Fighter, pin: float = SimConst.STOMP_PIN_DIST_DEFAULT, push: float = 0.0) -> void:
	set_state(&"stomp", 26)
	actionable_after = 16
	script_from = V3.make(pos.x, 0.0, pos.z)
	var d: V2 = SimMath.fwd(attacker.yaw)
	var reach: float = pin - push
	script_to = V3.make(attacker.pos.x + d.x * reach, 0.0, attacker.pos.z + d.z * reach)
	vel = V3.make()
	pos.y = 0.0


func _update_stomp() -> void:
	var t: float = minf(1.0, float(sf) / 8.0)
	var e: float = SimMath.ease_out_cubic(t)
	pos.x = script_from.x + (script_to.x - script_from.x) * e
	pos.z = script_from.z + (script_to.z - script_from.z) * e
	pos.y = JsMath.sin(t * PI) * 0.35 if sf < 8 else 0.0
	yaw = SimMath.yaw_to(pos, opp.pos)
	if sf >= actionable_after and try_actions():
		return
	if sf >= state_dur:
		set_state(&"free")


## The recall's power-up burst (authored-animation task 30b), as the weapon
## returns: an opponent within the recalled weapon's duelling distance and
## not invulnerable (a dodge's or a knockdown's frames) is blasted
## RECALL_BURST_KNOCKBACK away and knocked down, with no damage or posture; a
## guard doesn't stop it. The burst flares either way (`recallBurst`, with
## whether it hit).
func _recall_burst() -> void:
	var o: Fighter = opp
	var reach: float = weapon.duel_distance if weapon != null else 0.0
	var d: float = Vector2(o.pos.x - pos.x, o.pos.z - pos.z).length()
	var hit: bool = d <= reach and not o.is_invulnerable()
	world.emit({
		"t": &"recallBurst",
		"f": id,
		"on": o.id,
		"hit": hit,
		"reach": reach,
		"pos": SimEvents.vec3(V3.make(pos.x, 1.0, pos.z)),
	})
	if not hit:
		return
	o.release_if_impaling()
	# the recall is bare hands' ultimate: its knockdown takes their phases,
	# blasted: turned to face the recaller and carried back by the blasted
	# fall's travel (task 99)
	o.enter_knockdown(ProtectedTimings.for_weapon(&"fists"))
	o.knockdown_blasted = true
	o.yaw = SimMath.yaw_to(o.pos, pos)
	world.emit({"t": &"knockdown", "f": o.id, "attacker": id})
	world.hitstop = SimConst.RECALL_BURST_HITSTOP


func begin_leap(attacker: Fighter) -> void:
	set_state(&"leap", 32)
	script_from = V3.make(pos.x, pos.y, pos.z)
	var to: V2 = SimMath.norm2(attacker.pos.x - pos.x, attacker.pos.z - pos.z)
	# land a little further out than we started, on the same side
	script_to = V3.make(attacker.pos.x - to.x * 2.4, 0.0, attacker.pos.z - to.z * 2.4)
	vel = V3.make()


func _update_leap() -> void:
	var o: V3 = opp.pos
	var f: int = sf
	var to: V2 = SimMath.norm2(o.x - script_from.x, o.z - script_from.z)
	if f <= 10:
		# spring onto the attacker's shoulders
		var t: float = float(f) / 10.0
		var target: V3 = V3.make(o.x - to.x * 0.55, 1.55, o.z - to.z * 0.55)
		var e: float = SimMath.ease_out_cubic(t)
		pos.x = script_from.x + (target.x - script_from.x) * e
		pos.z = script_from.z + (target.z - script_from.z) * e
		pos.y = script_from.y + (target.y - script_from.y) * e
	else:
		# kick off and arc back down
		var t: float = minf(1.0, float(f - 10) / 22.0)
		var start: V3 = V3.make(o.x - to.x * 0.55, 1.55, o.z - to.z * 0.55)
		pos.x = start.x + (script_to.x - start.x) * t
		pos.z = start.z + (script_to.z - start.z) * t
		pos.y = maxf(0.0, start.y + 1.2 * JsMath.sin(t * PI) * (1.0 - t) - start.y * t * t)
	yaw = SimMath.yaw_to(pos, o)
	if f >= state_dur:
		pos.y = 0.0
		world.emit({"t": &"land", "f": id})
		set_state(&"free")


# ------------------------------------------------------------------ ultimates

## lift: the frames it spends heaving the Greatsword off the shoulder first;
## -1 takes them from the shoulder (shoulder_lift()).
func start_ult(lift: int = -1) -> void:
	var W: World = world
	var lift_frames: int = _take_shoulder_lift() if lift < 0 else lift
	ult_used = true
	stats.ultimates += 1
	vel.x = 0.0
	vel.z = 0.0
	if not armed:
		set_state(&"ultChoice", SimConst.ULT_CHOICE_FRAMES)
		W.emit({"t": &"ultChoice", "f": id})
		W.request_slowmo(SimConst.ULT_CHOICE_FRAMES, 0.35)
		return
	var kind: StringName = weapon.ultimate
	set_state(&"ult")
	ult = UltState.make(
		kind,
		&"windup" if kind == &"moonsplitter" else (&"aim" if kind == &"impaler" else &"flash"),
		0,
		&"vertical",
		0,
		false,
	)
	ult.lift_left = lift_frames
	W.emit({"t": &"ultStart", "f": id, "ult": kind})
	W.emit({"t": &"telegraph", "f": id, "kind": &"ult", "attack": kind})


func _set_ult_phase(p: StringName) -> void:
	ult.phase = p
	ult.pf = 0


func _update_ult() -> void:
	var u: UltState = ult
	if u.lift_left > 0:
		# heaving the Greatsword off the shoulder: the first phase waits
		u.lift_left -= 1
		_brake()
		return
	u.pf += 1
	_brake()
	match u.kind:
		&"moonsplitter":
			_ult_moonsplitter(u)
		&"impaler":
			_ult_impaler(u)
		&"tempest":
			_ult_tempest(u)


func _ult_moonsplitter(u: UltState) -> void:
	var W: World = world
	var inp: InputTracker = input
	if u.phase == &"windup":
		# the stick picks until the draw starts (task 98), so the clip never
		# changes draws mid-cut
		if inp.dir != -1 and u.pf <= SimConst.MOONSPLITTER_DRAW:
			u.variant = &"horizontal" if inp.sideways() else &"vertical"
		if u.pf >= SimConst.MOONSPLITTER_WAVE:
			_set_ult_phase(&"release")
			W.spawn_wave(self, u.variant)
	elif u.phase == &"release":
		if u.pf >= SimConst.MOONSPLITTER_RECOVERY:
			to_free()


func _ult_impaler(u: UltState) -> void:
	var W: World = world
	var o: Fighter = opp
	if u.phase == &"aim":
		if u.pf >= 30:
			_set_ult_phase(&"dash")
			W.emit({"t": &"ultDash", "f": id})
	elif u.phase == &"dash":
		var d: V2 = SimMath.fwd(yaw)
		var speed: float = 24.0 * SimConst.DT
		var gap: float = SimMath.dist2(pos, o.pos)
		pos.x += d.x * speed
		pos.z += d.z * speed
		# contact check: target just ahead of the blade tip
		var dx: float = o.pos.x - pos.x
		var dz: float = o.pos.z - pos.z
		var along: float = dx * d.x + dz * d.z
		var lateral: float = absf(dx * d.z - dz * d.x)
		if along > -0.2 and along < 1.9 and lateral < 0.85 and o.pos.y < 1.5:
			var cb: Callable = func(res: StringName) -> void:
				if state != &"ult" or ult != u or u.phase != &"dash":
					return # parried or disarmed
				if res == &"hit" and o.state == &"ko":
					_set_ult_phase(&"recover")
				elif res == &"hit":
					u.impaled = true
					o.impaled_by = self
					o.set_state(&"impaled")
					o.knock_left = 0
					_set_ult_phase(&"impale")
					W.emit({"t": &"ultImpale", "f": id, "target": o.id})
				elif (
					res == &"parry" or res == &"flash" or res == &"redirect" or res == &"block" or res == &"disarm"
				):
					_set_ult_phase(&"recover")
			W.queue_scripted_hit(self, o, Moves.ULT_HITS[&"u_impale"], cb)
		var r: float = JsMath.hypot(pos.x, pos.z)
		if u.pf >= 40 or r > SimConst.ARENA_RADIUS - SimConst.IMPALER_WALL_MARGIN or (gap < 0.6 and along < -0.5):
			_set_ult_phase(&"recover")
	elif u.phase == &"impale":
		# hold the victim on the blade
		var d: V2 = SimMath.fwd(yaw)
		o.pos.x = pos.x + d.x * 1.3
		o.pos.z = pos.z + d.z * 1.3
		o.pos.y = minf(1.0, o.pos.y + 0.12)
		o.vel = V3.make()
		if u.pf >= 8 and input.buffered(Btn.HEAVY, 10):
			input.consume(Btn.HEAVY)
			_set_ult_phase(&"burst")
			W.emit({"t": &"ultBurst", "f": id, "pos": SimEvents.vec3(V3.make(o.pos.x, 1.2, o.pos.z))})
			release_impaled()
			W.queue_scripted_hit(self, o, Moves.ULT_HITS[&"u_burst"])
			return
		if o.state != &"impaled":
			# something freed the victim (e.g. a KO elsewhere)
			_set_ult_phase(&"recover")
			return
		if u.pf >= 50:
			release_impaled()
			o.enter_hitstun(30)
			o.knock(pos.x, pos.z, 1.2, 12)
			_set_ult_phase(&"recover")
	elif u.phase == &"burst":
		if u.pf >= 24:
			_set_ult_phase(&"recover")
	elif u.phase == &"recover":
		if u.pf >= 30:
			to_free()


func release_impaled() -> void:
	var o: Fighter = opp
	if o.state == &"impaled":
		o.impaled_by = null
		o.pos.y = maxf(o.pos.y, 0.6)
		o.vel.y = 0.0
		o.set_state(&"hitstun", 30)


func _ult_tempest(u: UltState) -> void:
	var W: World = world
	var o: Fighter = opp
	if u.phase == &"flash":
		if u.pf == 1:
			var to: V2 = SimMath.norm2(o.pos.x - pos.x, o.pos.z - pos.z)
			var from_pt: V3 = V3.make(pos.x, 1.0, pos.z)
			script_from = V3.make(pos.x, 0.0, pos.z)
			var gap: float = maxf(0.0, SimMath.dist2(pos, o.pos) - 1.15)
			script_to = V3.make(pos.x + to.x * gap, 0.0, pos.z + to.z * gap)
			W.emit({
				"t": &"ultLightning",
				"f": id,
				"from": SimEvents.vec3(from_pt),
				"to": SimEvents.vec3(V3.make(script_to.x, 1.0, script_to.z)),
			})
		var t: float = minf(1.0, float(u.pf) / 6.0)
		pos.x = script_from.x + (script_to.x - script_from.x) * t
		pos.z = script_from.z + (script_to.z - script_from.z) * t
		if u.pf >= 8:
			_set_ult_phase(&"spin")
	elif u.phase == &"spin":
		# keep close to the target while spinning
		var d: float = SimMath.dist2(pos, o.pos)
		if d > 1.3:
			var to: V2 = SimMath.norm2(o.pos.x - pos.x, o.pos.z - pos.z)
			var s: float = minf(d - 1.2, 0.12)
			pos.x += to.x * s
			pos.z += to.z * s
		if u.pf == 5:
			var cb: Callable = func(res: StringName) -> void:
				if state != &"ult" or ult != u:
					return # parried while our posture was full
				if res == &"disarm" or o.state == &"ko":
					_set_ult_phase(&"recover")
			W.queue_scripted_hit(self, o, Moves.ULT_HITS[&"u_tempest"], cb)
		if u.pf >= 10:
			u.spins += 1
			if u.spins >= SimConst.TEMPEST_SPINS:
				_set_ult_phase(&"final")
			else:
				_set_ult_phase(&"spin")
	elif u.phase == &"final":
		if u.pf == 8:
			W.queue_scripted_hit(self, o, Moves.ULT_HITS[&"u_tempest_final"])
		if u.pf >= 14:
			_set_ult_phase(&"recover")
	elif u.phase == &"recover":
		if u.pf >= 24:
			to_free()


func _update_ult_choice() -> void:
	var inp: InputTracker = input
	_brake()
	if inp.buffered(Btn.HEAVY, 6):
		inp.consume(Btn.HEAVY)
		inp.consume(Btn.LIGHT)
		start_attack(&"f_breaker", -1)
		return
	if inp.buffered(Btn.LIGHT, 6) or sf >= state_dur:
		inp.consume(Btn.LIGHT)
		set_state(&"recall", SimConst.RECALL_FRAMES)
		world.emit({"t": &"recall", "f": id})


func _update_recall() -> void:
	_brake()
	if sf == SimConst.RECALL_BURST_FRAME:
		world.remove_dropped_weapon(id)
		armed = true
		world.emit({"t": &"pickup", "f": id})
		_recall_burst()
	if sf >= state_dur:
		set_state(&"free")


## Knocked out, by a blow from `by` (null for none) that was a heavy when
## `heavy`: the fighter keeps which (ko_heavy, ko_from_behind).
func to_ko(by: Fighter = null, heavy: bool = false) -> void:
	ko_heavy = heavy
	ko_from_behind = by != null and SimMath.angle_between(yaw, SimMath.yaw_to(pos, by.pos)) > PI / 2.0
	hp = 0.0
	release_if_impaling()
	set_state(&"ko")
	vel.x = 0.0
	vel.z = 0.0


func release_if_impaling() -> void:
	if state == &"ult" and ult != null and ult.impaled:
		release_impaled()


## Angle (deg) between our facing and the direction to a point.
func angle_to(p: V3) -> float:
	return absf(SimMath.wrap_angle(SimMath.yaw_to(pos, p) - yaw)) / SimMath.DEG
