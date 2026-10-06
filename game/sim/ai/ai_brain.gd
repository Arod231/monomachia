class_name AIBrain
extends RefCounted
## Port of v0.1-web-mvp:src/sim/ai/brain.ts.
##
## Computer opponent. It plays through a virtual controller (RawInput), so it is
## bound by exactly the same rules, timings and cooldowns as a human player.
##
## Port notes:
## - Difficulty is a StringName (&"easy", &"normal", &"hard"). AIParams is the
##   inner class AIBrain.AIParams; DIFFICULTY maps a Difficulty to its params.
## - Plan is a StringName equal to the TS literal (&"none", &"parry"...).
## - A Tap's optional mx and my are has_mx / has_my flags plus the value.
## - seenAtk and seenWave hold the AttackState and SlashWave objects and are
##   compared by identity (== on Objects), as in the TS.
## - Every Rng call happens in the same order as in the TS: where the TS draws
##   twice inside one expression or argument list (left to right), the draws
##   are split into locals in that order, and every TS short-circuit (&&, ||,
##   ?:) that guards a draw is kept as one.
## - Math.round is SimMath.js_round; Math.hypot(x, z) is JsMath.hypot(x, z).
## - dispose() is new: it breaks the reference to the fighter (me), which
##   points back through the world. Call it when the brain is no longer needed.
## - threatens() is the rebuild's (task 7.13): the reach test _respond_to()
##   made inline, now reading AttackDef.reach(), a swing's reach once a move
##   has one.
## - Waiting out a knockdown (_think_neutral() and _output()) is authored
##   animation's (task 16).
## - The Greatsword's lift off the shoulder (authored-animation task 15) is
##   in its estimates: frames_to_impact() for an opponent's attack, and for
##   its own the follow-up and charge timings and the reach it attacks from
##   (_lift_drift()).


## Difficulty: &"easy" | &"normal" | &"hard"
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"hard"]


class AIParams:
	## frames before the AI notices a new attack
	var reaction: float = 0.0
	var reaction_jitter: float = 0.0
	var parry: float = 0.0
	var block: float = 0.0
	var counter: float = 0.0
	var dodge: float = 0.0
	var aggression: float = 0.0
	## +/- frames of timing error on parries and counters
	var timing_error: int = 0
	var use_ult: float = 0.0
	## chance to raise a pre-emptive guard when inside the opponent's reach
	var guard: float = 0.0
	## The finisher prompt (milestone-1 task 107, the spec's computer's
	## finisher rates table): the share of prompts pressed, and the window's
	## frames the press falls in (1 the first after the prompt opens).
	var finisher: float = 0.0
	var finisher_from: int = 1
	var finisher_to: int = SimConst.FINISHER_PROMPT_FRAMES

	## These params pressing `rate` of finisher prompts on a frame from
	## `from` to `to` of the window.
	func finishing(rate: float, from: int, to: int) -> AIParams:
		finisher = rate
		finisher_from = from
		finisher_to = to
		return self

	static func make(
		p_reaction: float,
		p_reaction_jitter: float,
		p_parry: float,
		p_block: float,
		p_counter: float,
		p_dodge: float,
		p_aggression: float,
		p_timing_error: int,
		p_use_ult: float,
		p_guard: float,
	) -> AIParams:
		var p: AIParams = AIParams.new()
		p.reaction = p_reaction
		p.reaction_jitter = p_reaction_jitter
		p.parry = p_parry
		p.block = p_block
		p.counter = p_counter
		p.dodge = p_dodge
		p.aggression = p_aggression
		p.timing_error = p_timing_error
		p.use_ult = p_use_ult
		p.guard = p_guard
		return p

	## { ...params }: a field-by-field copy, so a caller can override some fields.
	func copy() -> AIParams:
		return make(reaction, reaction_jitter, parry, block, counter, dodge, aggression, timing_error, use_ult, guard).finishing(
			finisher, finisher_from, finisher_to
		)


# Columns: reaction, reactionJitter, parry, block, counter, dodge, aggression,
# timingError, useUlt, guard; then the finisher prompt's share and frames
# (P55: Easy 30% in the window's second half, Normal 60% anywhere in it, Hard
# 90% in its first 6 frames).
static var DIFFICULTY: Dictionary[StringName, AIParams] = {
	&"easy": AIParams.make(27, 8, 0.08, 0.35, 0.1, 0.15, 0.35, 5, 0.5, 0.3).finishing(0.3, 10, 18),
	&"normal": AIParams.make(18, 6, 0.3, 0.45, 0.35, 0.2, 0.55, 3, 0.8, 0.55).finishing(0.6, 1, 18),
	&"hard": AIParams.make(11, 4, 0.55, 0.35, 0.6, 0.25, 0.72, 2, 1, 0.7).finishing(0.9, 1, 6),
}


class Tap:
	var btn: int
	var from: int
	var to: int
	var has_mx: bool = false
	var mx: float = 0.0
	var has_my: bool = false
	var my: float = 0.0


## Plan: &"none" | &"parry" | &"block" | &"dodge" | &"counter" | &"flash" | &"evade"
const PLANS: Array[StringName] = [&"none", &"parry", &"block", &"dodge", &"counter", &"flash", &"evade"]

var rng: Rng
var _taps: Array[Tap] = []
var _hold_mask: int = 0
var _move_x: float = 0.0
var _move_y: float = 0.0

var _seen_atk: AttackState = null
var _seen_wave: SlashWave = null
var _seen_ult: bool = false
var _react_at: int = -1
var _plan: StringName = &"none"
var _plan_until: int = -1

var _next_think: int = 0
var _attack_cooldown_until: int = 0
var _combo_left: int = 0
var _combo_btn: int = Btn.LIGHT
var _next_combo_press: int = 0
var _charge_until: int = -1
var _strafe: int = 1
var _strafe_until: int = 0
var _recover_posture: bool = false
var _last_opp_blocking_frames: int = 0
var _spacing_bias: float = 0.0
var _guard_until: int = 0
var _guard_roll: int = 0
## The finisher prompt (milestone-1 task 107): the world frame the last prompt
## seen opened on, and the frame its press is planned for (-1: let it pass).
var _prompt_seen: int = -1
var _finish_at: int = -1
## Whether this brain presses finisher prompts at all (Training's dummy
## doesn't).
var finishes: bool = true

var me: Fighter
var params: AIParams


func _init(p_me: Fighter, p_params: AIParams, seed_value: int = 99) -> void:
	me = p_me
	params = p_params
	rng = Rng.new(seed_value)


## Not copied field by field: the fighter (a link the restore keeps), and the
## attack and wave last seen, which the brain compares with the world's by
## identity: the snapshot holds whether the seen attack is the opponent's
## current one, and the seen wave's index among the world's waves (-1 for
## none).
const SNAPSHOT_SKIP: Array[StringName] = [&"me", &"_seen_atk", &"_seen_wave"]


## A copy of the brain's state (milestone-1 task 5), its generator included.
func snapshot() -> Dictionary:
	var s: Dictionary = SimState.capture(self, SNAPSHOT_SKIP)
	s[&"_seen_atk"] = me != null and _seen_atk != null and me.opp.atk == _seen_atk
	s[&"_seen_wave"] = _w().waves.find(_seen_wave) if me != null and _seen_wave != null else -1
	return s


## Puts a snapshot() back (milestone-1 task 6), after the world has been
## restored: the seen attack and wave become the restored world's objects.
func restore(s: Dictionary) -> void:
	var fields: Dictionary = s.duplicate()
	for n: StringName in SNAPSHOT_SKIP:
		fields.erase(n)
	SimState.apply(self, fields)
	_seen_atk = me.opp.atk if bool(s[&"_seen_atk"]) else null
	var wave: int = s[&"_seen_wave"]
	_seen_wave = _w().waves[wave] if wave >= 0 else null


func _w() -> World:
	return me.world


## Breaks the reference to the fighter. The brain can't think afterwards.
func dispose() -> void:
	me = null
	_seen_atk = null
	_seen_wave = null
	_taps = []


# ------------------------------------------------------------------ output helpers

## len is `length` here (len is a GDScript built-in). mx and my are optional,
## as in the TS: null (undefined) leaves the stick alone.
func _tap(btn: int, at: int, length: int = 2, mx: Variant = null, my: Variant = null) -> void:
	var t: Tap = Tap.new()
	t.btn = btn
	t.from = at
	t.to = at + length - 1
	if mx != null:
		t.has_mx = true
		t.mx = float(mx)
	if my != null:
		t.has_my = true
		t.my = float(my)
	_taps.append(t)


func _output(frame: int) -> RawInput:
	var buttons: int = _hold_mask
	var mx: float = _move_x
	var my: float = _move_y
	for t: Tap in _taps:
		if frame >= t.from and frame <= t.to:
			buttons |= 1 << t.btn
			if t.has_mx:
				mx = t.mx
			if t.has_my:
				my = t.my
	var kept: Array[Tap] = []
	for t: Tap in _taps:
		if t.to >= frame:
			kept.append(t)
	_taps = kept
	# A downed opponent can't be hit (task 16): no attack goes in, even one
	# planned before they fell, until their stand-up's guard window. A charge
	# already held stays held.
	if me.opp != null and me.opp.is_downed():
		var charging: bool = me.state == &"attack" and me.atk != null and me.atk.charging
		buttons &= ~((1 << Btn.LIGHT) | (1 << Btn.ULTIMATE) | (0 if charging else 1 << Btn.HEAVY))
	return RawInput.make(mx, my, buttons)


## Convert a desired world direction into opponent-relative stick axes.
## Returns { mx, my } as a V2 (x = mx, z = my).
func _stick_toward(x: float, z: float) -> V2:
	var to: V2 = SimMath.norm2(me.opp.pos.x - me.pos.x, me.opp.pos.z - me.pos.z)
	var d: V2 = SimMath.norm2(x - me.pos.x, z - me.pos.z)
	var rx: float = -to.z
	var rz: float = to.x
	return V2.make(d.x * rx + d.z * rz, d.x * to.x + d.z * to.z)


# ------------------------------------------------------------------ main

## The next step's input. While a finisher prompt is open for this fighter,
## it decides once whether to press it (params.finisher, from its own
## generator), then either presses heavy alone on the frame drawn, or plays on
## without a heavy press that would take the prompt.
func think() -> RawInput:
	var W: World = _w()
	if W.prompt_by != me.id:
		return _think()
	if _prompt_seen != W.prompt_at:
		_prompt_seen = W.prompt_at
		_finish_at = -1
		if finishes and rng.chance(params.finisher):
			_finish_at = W.prompt_at + rng.int(params.finisher_from, params.finisher_to)
	if _finish_at >= 0:
		_reset()
		return RawInput.make(0.0, 0.0, (1 << Btn.HEAVY) if W.frame + 1 == _finish_at else 0)
	var out: RawInput = _think()
	out.buttons &= ~(1 << Btn.HEAVY)
	return out


func _think() -> RawInput:
	var W: World = _w()
	var frame: int = W.frame + 1 # the frame this input will be read on
	var opp: Fighter = me.opp

	if me.state == &"intro" or me.state == &"victory" or me.state == &"ko":
		_reset()
		return _output(frame)

	_perceive(frame)

	if _plan != &"none" and frame > _plan_until:
		_plan = &"none"
		_hold_mask &= ~(1 << Btn.BLOCK)

	# Plans (defence) take priority over everything else.
	if _plan != &"none":
		if _plan == &"block":
			_hold_mask |= 1 << Btn.BLOCK
			_move_x = 0.0
			_move_y = 0.0
		return _output(frame)

	# Charging a heavy.
	if _charge_until > 0:
		if frame < _charge_until and me.state == &"attack":
			_hold_mask |= 1 << Btn.HEAVY
			return _output(frame)
		_charge_until = -1
		_hold_mask &= ~(1 << Btn.HEAVY)

	# Continue a combo string.
	if _combo_left > 0 and me.state == &"attack":
		if frame >= _next_combo_press:
			_tap(_combo_btn, frame, 2)
			_combo_left -= 1
			_next_combo_press = frame + 8
		return _output(frame)
	if me.state != &"attack":
		_combo_left = 0

	if frame < _next_think:
		return _output(frame)
	_next_think = frame + 3

	var d: float = SimMath.dist2(me.pos, opp.pos)
	_hold_mask &= ~(1 << Btn.HEAVY)

	# Ultimate.
	if me.can_ult() and rng.chance(params.use_ult * 0.2) and _ult_makes_sense(d):
		_hold_mask = 0
		if me.weapon.ultimate == &"moonsplitter" and me.armed:
			# choose vertical or horizontal by tilting during the sheathe
			var horiz: bool = rng.chance(0.5)
			_tap(Btn.ULTIMATE, frame, 2)
			_move_x = 1.0 if horiz else 0.0
			_move_y = 0.0 if horiz else 1.0
			_next_think = frame + 36
			return _output(frame)
		_tap(Btn.ULTIMATE, frame, 2)
		if not me.armed:
			# Recall when the weapon is far, otherwise the posture blow when close
			var w: DroppedWeapon = W.weapon_of(me.id)
			var choice: int = Btn.LIGHT if w != null and d > 2.5 else Btn.HEAVY
			_tap(choice, frame + 6, 2)
		elif me.weapon.ultimate == &"impaler":
			var lift: int = me.shoulder_lift()
			for k: int in range(50, 90, 4):
				_tap(Btn.HEAVY, frame + lift + k, 2)
		_next_think = frame + 30
		return _output(frame)

	if not me.armed:
		return _think_disarmed(frame, d)
	if not opp.armed and W.weapon_of(opp.id) != null:
		return _think_guard_weapon(frame, d)
	return _think_neutral(frame, d)


func _reset() -> void:
	_taps = []
	_hold_mask = 0
	_move_x = 0.0
	_move_y = 0.0
	_plan = &"none"
	_combo_left = 0
	_charge_until = -1
	_seen_atk = null
	_seen_ult = false


func _ult_makes_sense(d: float) -> bool:
	var opp: Fighter = me.opp
	if opp.state == &"ko" or opp.is_invulnerable():
		return false
	if not me.armed:
		return true
	match me.weapon.ultimate:
		&"moonsplitter":
			return d > 2.5 and d < 14.0
		&"impaler":
			return d > 2.5 and d < 12.0 and opp.state != &"dodge"
		&"tempest":
			return d < 10.0
		_:
			return true


# ------------------------------------------------------------------ perception & defence

func _perceive(frame: int) -> void:
	var opp: Fighter = me.opp
	var P: AIParams = params

	# Incoming katana wave.
	for w: SlashWave in _w().waves:
		if w.owner == opp and w != _seen_wave:
			_seen_wave = w
			var along: float = (me.pos.x - w.ox) * w.dx + (me.pos.z - w.oz) * w.dz
			var arrive: int = frame + maxi(0, SimMath.js_round(((along - w.s) / 30.0) * 60.0))
			if rng.chance(P.counter + 0.15):
				if w.kind == &"horizontal":
					_tap(Btn.JUMP, maxi(frame, arrive - 8), 2)
				else:
					_tap(Btn.DODGE, maxi(frame, arrive - 6), 2, 1, 0)
				_set_plan(&"evade", arrive + 6)

	# Opponent ultimates that are dodged rather than parried.
	if opp.state == &"ult" and opp.ult != null and not _seen_ult:
		if opp.ult.kind == &"impaler" and opp.ult.phase == &"dash":
			_seen_ult = true
			if rng.chance(P.dodge + P.counter * 0.5):
				_tap(Btn.DODGE, frame + SimMath.js_round(P.reaction / 3.0), 2, 1 if rng.chance(0.5) else -1, 0)
				_set_plan(&"evade", frame + 20)
	if opp.state != &"ult":
		_seen_ult = false

	if opp.state != &"attack" or opp.atk == null:
		return
	var atk: AttackState = opp.atk
	if atk != _seen_atk:
		_seen_atk = atk
		_react_at = frame + maxi(1, SimMath.js_round(P.reaction + rng.range(-P.reaction_jitter, P.reaction_jitter)))
	if _react_at < 0 or frame < _react_at or atk.charging:
		return
	_react_at = -1
	_respond_to(atk.def, frame, frames_to_impact(atk))


func _set_plan(p: StringName, until: int) -> void:
	_plan = p
	_plan_until = until
	_combo_left = 0
	_charge_until = -1
	_hold_mask &= ~(1 << Btn.HEAVY)


## const err = () => this.rng.int(-P.timingError, P.timingError)
func _err() -> int:
	return rng.int(-params.timing_error, params.timing_error)


## The parryTap closure in respondTo.
func _parry_tap(window: int, frame: int, impact: int) -> void:
	var r: int = rng.int(1, window - 2)
	var e: int = _err()
	var k: int = maxi(0, mini(window - 1, r + e))
	_hold_mask &= ~(1 << Btn.BLOCK)
	_tap(Btn.BLOCK, maxi(frame, impact - k), 3)
	_set_plan(&"parry", impact + 4)


## Whether the computer answers an attack `def` started `d` m away (centre to
## centre): within its reach (AttackDef.reach(), its swing's once it has one;
## task 7.13), a fighter's radius, its lunge and 0.6 m, or at any distance for
## an unblockable, whose counter it may try.
static func threatens(def: AttackDef, d: float) -> bool:
	return d <= def.reach() + SimConst.FIGHTER_RADIUS + def.lunge + 0.6 or def.counter != &""


## The frames from now until the attack's first active frame: the rest of its
## startup, and the rest of its lift off the shoulder for a Greatsword attack
## started shouldered (authored-animation task 15).
static func frames_to_impact(atk: AttackState) -> int:
	return atk.def.startup + 1 - atk.frame + atk.lift_left


## to_impact: frames_to_impact() of the attack.
func _respond_to(def: AttackDef, frame: int, to_impact: int) -> void:
	var opp: Fighter = me.opp
	var P: AIParams = params
	if def.damage <= 0.0:
		return # stances
	var impact: int = frame + to_impact
	if impact < frame:
		return # too late
	if not threatens(def, SimMath.dist2(me.pos, opp.pos)):
		return
	if me.state == &"attack" or me.state == &"hitstun" or me.state == &"stunned":
		return

	var armed: bool = me.armed
	var window: int = me.moveset().parry_window

	if def.counter != &"":
		if rng.chance(P.counter):
			if def.counter == &"thrust":
				var r: int = rng.int(3, 9)
				_tap(Btn.DODGE, maxi(frame, impact - r + _err()), 2, 0, 1)
			elif def.counter == &"sweep":
				var r: int = rng.int(7, 13)
				_tap(Btn.JUMP, maxi(frame, impact - r + _err()), 2)
			else:
				var r: int = rng.int(2, 8)
				_tap(Btn.DODGE, maxi(frame, impact - r + _err()), 2, 0, 0)
			_set_plan(&"counter", impact + 14)
			return
		if rng.chance(P.parry * 0.6):
			_parry_tap(window, frame, impact)
			return
		if rng.chance(P.dodge + 0.25):
			_tap(Btn.DODGE, maxi(frame, impact - 16), 2, 0, -1)
			_set_plan(&"dodge", impact + 10)
		return

	# Katana Flash stance, if equipped, as an occasional answer to heavies.
	if armed and me.abilities.has(&"k_flash") and def.kind == &"heavy" and rng.chance(P.parry * 0.5):
		var slot: int = Btn.LIGHT if me.abilities[0] == &"k_flash" else Btn.HEAVY
		var at: int = maxi(frame, impact - rng.int(4, 14))
		_tap(Btn.BLOCK, at, 3)
		_tap(slot, at + 1, 2)
		_set_plan(&"flash", impact + 6)
		return

	var parry_chance: float = minf(0.9, P.parry + 0.25) if opp.posture_full() and armed else P.parry
	if rng.chance(parry_chance):
		_parry_tap(window, frame, impact)
		return
	if armed and rng.chance(P.block / (1.0 - P.parry)):
		_hold_mask |= 1 << Btn.BLOCK
		_set_plan(&"block", impact + def.active + 4)
		return
	if rng.chance(P.dodge * (1.0 if armed else 2.5)):
		var side: int = 1 if rng.chance(0.5) else -1
		var back: bool = rng.chance(0.4)
		_tap(Btn.DODGE, maxi(frame, impact - rng.int(3, 8)), 2, 0 if back else side, -1 if back else 0)
		_set_plan(&"dodge", impact + 8)


# ------------------------------------------------------------------ neutral game

func _think_neutral(frame: int, d: float) -> RawInput:
	var opp: Fighter = me.opp
	var P: AIParams = params
	var w: WeaponDef = me.moveset()
	var reach: float = w.reach + SimConst.FIGHTER_RADIUS

	# Posture management: back off and hold block to drain when the meter runs high.
	if me.posture > 62.0 and not _recover_posture and rng.chance(0.3):
		_recover_posture = true
	if _recover_posture:
		if me.posture < 25.0 or (opp.state == &"attack" and d < reach + 1.0):
			_recover_posture = false
		else:
			_hold_mask |= 1 << Btn.BLOCK
			_move_x = 0.0
			_move_y = -0.8 if d < 3.5 else 0.0
			return _output(frame)
	_hold_mask &= ~(1 << Btn.BLOCK)

	# Track how much the opponent turtles.
	_last_opp_blocking_frames = (
		_last_opp_blocking_frames + 3 if opp.blocking else maxi(0, _last_opp_blocking_frames - 2)
	)

	var punish: bool = (
		[&"recoil", &"stunned", &"stagger", &"disarmStagger", &"pickup"].has(opp.state)
		or (opp.state == &"attack" and opp.attack_phase() == &"recovery" and opp.atk.frame > 0)
	)
	var can_act: bool = me.state == &"free" or me.state == &"step" or me.state == &"parryAnim" or me.state == &"land"
	# wait out a knockdown: close in, but attack only once they rise in guard
	if opp.is_downed():
		can_act = false

	# With a full meter, a parried attack would disarm us: only attack into openings.
	var risky: bool = me.posture_full() or (me.posture > 80.0 and not punish)
	var opp_swinging: bool = opp.state == &"attack" and opp.attack_phase() != &"recovery"
	if (
		can_act
		and frame >= _attack_cooldown_until
		and not (risky and not punish and rng.chance(0.75))
		and not (opp_swinging and not punish and rng.chance(0.7))
	):
		# Counter-lunge window after an evade counter
		if frame <= me.counter_lunge_until + 1:
			_tap(Btn.LIGHT, frame, 2)
			_attack_cooldown_until = frame + 20
			return _output(frame)
		if punish and d < reach + 0.9:
			var length: int = rng.int(2, 3)
			var finish_heavy: bool = rng.chance(0.35)
			_start_combo(frame, length, finish_heavy)
			_attack_cooldown_until = frame + 12
			return _output(frame)
		if d < reach - _lift_drift() + 0.25 and rng.chance(0.08 + P.aggression * 0.25):
			_pick_attack(frame, d)
			return _output(frame)
		# sprint attack from mid range
		if d > 4.5 and d < 7.5 and rng.chance(0.03 * P.aggression):
			_hold_mask |= 1 << Btn.SPRINT
			_move_x = 0.0
			_move_y = 1.0
			_tap(Btn.LIGHT if rng.chance(0.6) else Btn.HEAVY, frame + 16, 2)
			_attack_cooldown_until = frame + 50
			_next_think = frame + 18
			return _output(frame)
	_hold_mask &= ~(1 << Btn.SPRINT)

	# Pre-emptive guard inside the opponent's reach (light attacks are too fast to react to).
	var threat: float = opp.moveset().reach + SimConst.FIGHTER_RADIUS + 0.9
	if me.armed and d < threat and opp.state != &"ko":
		if frame > _guard_until and frame > _guard_roll:
			var want_guard: float = P.guard + (0.25 if risky else 0.0)
			if rng.chance(want_guard):
				_guard_until = frame + rng.int(24, 72)
			_guard_roll = frame + rng.int(18, 40)
	else:
		_guard_until = 0
	if frame < _guard_until:
		_hold_mask |= 1 << Btn.BLOCK

	# Footsies: keep preferred distance and circle.
	if frame > _strafe_until:
		_strafe = 1 if rng.chance(0.5) else -1
		if rng.chance(0.25):
			_strafe = 0
		_strafe_until = frame + rng.int(40, 110)
		_spacing_bias = rng.range(-0.4, 0.6)
	var want: float = reach - 0.1 + _spacing_bias - P.aggression * 0.5
	var my: float = 0.0
	if d > want + 0.4:
		my = 1.0
	elif d < want - 0.5:
		my = -0.8
	if d > 8.0:
		_hold_mask |= 1 << Btn.SPRINT
	_move_x = _strafe * 0.8
	_move_y = my
	return _output(frame)


## How far the opponent can back off while the computer heaves its Greatsword
## off the shoulder: the reach it attacks from shrinks by this
## (authored-animation task 15).
func _lift_drift() -> float:
	return SimConst.MOVE_RUN_BACK * me.opp.speed_mult() * float(me.shoulder_lift()) * SimConst.DT


func _start_combo(frame: int, length: int, finish_heavy: bool) -> void:
	# the follow-up presses wait out the first attack's lift off the shoulder
	var lift: int = me.shoulder_lift()
	_tap(Btn.LIGHT, frame, 2)
	_combo_left = length - 1
	_combo_btn = Btn.LIGHT
	_next_combo_press = frame + lift + 8
	if finish_heavy and length > 1:
		# replace the last press with a heavy
		_combo_left = length - 2
		_tap(Btn.HEAVY, frame + lift + 8 * (length - 1), 2)
	_move_x = 0.0
	_move_y = 0.0


func _pick_attack(frame: int, _d: float) -> void:
	var opp: Fighter = me.opp
	var P: AIParams = params
	var w: WeaponDef = me.moveset()
	var turtling: bool = _last_opp_blocking_frames > 30 or opp.blocking
	var no_abilities: Array[StringName] = [&"", &""]
	var abilities: Array[StringName] = me.abilities if me.armed else no_abilities
	var unblock_slot: int = -1
	for i: int in abilities.size():
		var ab_id: StringName = abilities[i]
		if ab_id != &"" and w.moves.has(ab_id) and w.moves[ab_id].unblockable:
			unblock_slot = i
			break
	var r: float = rng.next()
	_move_x = 0.0
	_move_y = 0.0
	_hold_mask &= ~(1 << Btn.BLOCK)
	_guard_until = 0
	var break_chance: float = 0.7 if opp.posture_full() else (0.45 if turtling else 0.12)

	if unblock_slot >= 0 and r < break_chance:
		_tap(Btn.BLOCK, frame, 3)
		_tap(Btn.LIGHT if unblock_slot == 0 else Btn.HEAVY, frame + 1, 2)
		_attack_cooldown_until = frame + 40
		return
	var crush_slot: int = abilities.find(&"g_crush")
	if crush_slot >= 0 and turtling and r < 0.6:
		_tap(Btn.BLOCK, frame, 3)
		_tap(Btn.LIGHT if crush_slot == 0 else Btn.HEAVY, frame + 1, 2)
		_attack_cooldown_until = frame + 30
		return
	if r < 0.55:
		var length: int = rng.int(1, 3)
		var finish_heavy: bool = rng.chance(0.25)
		_start_combo(frame, length, finish_heavy)
		_attack_cooldown_until = frame + 24 + SimMath.js_round((1.0 - P.aggression) * 40.0)
	elif r < 0.8:
		_tap(Btn.HEAVY, frame, 2)
		if rng.chance(0.3):
			_tap(Btn.HEAVY, frame + me.shoulder_lift() + 30, 2)
		_attack_cooldown_until = frame + 40 + SimMath.js_round((1.0 - P.aggression) * 40.0)
	elif r < 0.88 and me.armed:
		# charged heavy
		_hold_mask |= 1 << Btn.HEAVY
		_charge_until = frame + rng.int(30, 160) + me.shoulder_lift()
		_attack_cooldown_until = frame + 90
	else:
		# dodge then attack
		var side: int = 1 if rng.chance(0.5) else -1
		_tap(Btn.DODGE, frame, 2, side, 0.3)
		_tap(Btn.LIGHT if rng.chance(0.6) else Btn.HEAVY, frame + 14, 2)
		_attack_cooldown_until = frame + 45
	# void d (the parameter is _d)


# ------------------------------------------------------------------ disarm situations

func _think_disarmed(frame: int, d: float) -> RawInput:
	var opp: Fighter = me.opp
	var W: World = _w()
	var wpn: DroppedWeapon = W.weapon_of(me.id)
	if wpn != null and wpn.grounded:
		var my_d: float = SimMath.dist2(me.pos, wpn.pos)
		var opp_d: float = SimMath.dist2(opp.pos, wpn.pos)
		if my_d <= SimConst.PICKUP_RANGE - 0.15:
			if me.state == &"free" or me.state == &"step":
				_move_x = 0.0
				_move_y = 0.0
				_tap(Btn.INTERACT, frame, 2)
				_next_think = frame + 10
			return _output(frame)
		# go for it if we are not badly blocked
		if my_d < opp_d + 2.5 or opp.state == &"stunned" or opp.state == &"recoil" or rng.chance(0.3):
			var s: V2 = _stick_toward(wpn.pos.x, wpn.pos.z)
			_move_x = s.x
			_move_y = s.z
			if my_d > 4.0:
				_hold_mask |= 1 << Btn.SPRINT
			else:
				_hold_mask &= ~(1 << Btn.SPRINT)
			# hop around the guard occasionally
			if opp_d < my_d and d < 2.2 and rng.chance(0.08):
				_tap(Btn.DODGE, frame, 2, 1 if s.x > 0.0 else -1, 0.2)
			return _output(frame)
	_hold_mask &= ~(1 << Btn.SPRINT)
	# Brawl.
	return _think_neutral(frame, d)


func _think_guard_weapon(frame: int, d: float) -> RawInput:
	var opp: Fighter = me.opp
	var wpn: DroppedWeapon = _w().weapon_of(opp.id)
	# stand between the opponent and their weapon, and punish attempts
	var gx: float = wpn.pos.x + (opp.pos.x - wpn.pos.x) * 0.35
	var gz: float = wpn.pos.z + (opp.pos.z - wpn.pos.z) * 0.35
	var to_guard: float = JsMath.hypot(gx - me.pos.x, gz - me.pos.z)
	if opp.state == &"pickup" and d < me.moveset().reach + 1.5:
		_start_combo(frame, 3, true)
		return _output(frame)
	if to_guard > 1.0 and d > 2.2:
		var s: V2 = _stick_toward(gx, gz)
		_move_x = s.x
		_move_y = s.z
		_hold_mask &= ~(1 << Btn.BLOCK)
		return _output(frame)
	return _think_neutral(frame, d)
