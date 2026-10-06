class_name World
extends RefCounted
## Port of v0.1-web-mvp:src/sim/world.ts (DroppedWeapon and SlashWave are in
## dropped_weapon.gd and slash_wave.gd).
##
## The World owns both fighters, dropped weapons and projectiles, and resolves
## every clash between them once per frame.
##
## Port notes:
## - OutcomeKind is a StringName equal to the TS literal (see
##   SimEvents.OUTCOME_KINDS).
## - Events are Dictionaries (see events.gd); events is an Array[Dictionary].
## - The getter timeScale is time_scale().
## - The markDone closure in apply() is the _mark_done() method.
## - Math.hypot, Math.sin, Math.cos and Math.atan2 are JsMath.hypot, .sin, .cos
##   and .atan2 (V8's exact results, see js_math.gd).
## - Scripted-hit callbacks are Callables taking the outcome (StringName).
## - dispose() is new: it breaks the reference cycles (Fighter.opp,
##   Fighter.world, Fighter.impaled_by, SlashWave.owner) so the world can be
##   freed. Call it when a world is no longer needed.
## - step() places each attacking fighter's blades in the world after
##   separating the fighters and before resolving combat (Fighter.place_blades,
##   the rebuild's task 7.9), and evaluate() asks reaches() where the TS asks
##   inVolume: a move with a swing reaches by its blades' sweeps (task 7.10).
##   Their touch's contact rides in HitCtx.contact into apply(), which puts
##   it in hit, block and parry events in place of the midpoint (task 7.11).
## - checks_frame() is the rebuild's (task 7.13): _resolve_combat()'s test of
##   which frames check for hits, shared with SwingReach.first_contact().
## - knocks_down(), the knockdown in apply() and evaluate()'s miss on a
##   downed fighter are authored animation's (task 16).


## { chargeF, backstab }: the context an attack carries into apply().
class HitCtx:
	var charge_f: float = 0.0
	var backstab: bool = false
	## Where the attack's blade met the target this frame, for a move with a
	## swing (the sweep's contact, task 7.11); null puts the hit, block and
	## parry events halfway between the fighters, as the demo did.
	var contact: V3 = null

	static func make(p_charge_f: float, p_backstab: bool) -> HitCtx:
		var c: HitCtx = HitCtx.new()
		c.charge_f = p_charge_f
		c.backstab = p_backstab
		return c


## { a, b, def, cb? }: a queued scripted hit. cb is a null Callable when unset.
class ScriptedHit:
	var a: Fighter
	var b: Fighter
	var def: AttackDef
	var cb: Callable


const WAVE_SPEED: float = 30.0
## Far enough to cross the whole arena: the widest gap between two fighters
## and 3 m more, as the demo's 26 m did at its 11.5 m radius.
const WAVE_RANGE: float = 2.0 * SimConst.ARENA_RADIUS + 3.0

var frame: int = 0
## [Fighter, Fighter]
var fighters: Array[Fighter] = []
var weapons: Array[DroppedWeapon] = []
var waves: Array[SlashWave] = []
var events: Array[Dictionary] = []
var hitstop: int = 0
var slowmo_frames: int = 0
var slowmo_scale: float = 1.0
var ko_resolved: bool = false
## The finisher prompt (milestone-1 task 103, FinisherRules): open for fighter
## prompt_by while >= 0, since world frame prompt_at, for the finisher
## prompt_kind (the disarmer's weapon, or &"fists"), from bare hands' strike
## when prompt_from_strike.
var prompt_by: int = -1
var prompt_at: int = 0
var prompt_kind: StringName = &""
var prompt_from_strike: bool = false
## The finisher being played by fighter finisher_by while >= 0: its kind, its
## frame, and where the finisher stood as it started (the line-up's start).
var finisher_by: int = -1
var finisher_kind: StringName = &""
var finisher_from_strike: bool = false
var finisher_frame: int = 0
var finisher_from_x: float = 0.0
var finisher_from_z: float = 0.0
var rng: Rng
var _scripted_queue: Array[ScriptedHit] = []


func _init(p1: FighterConfig, p2: FighterConfig, seed_value: int = 1) -> void:
	rng = Rng.new(seed_value)
	var a: Fighter = Fighter.new(0, p1)
	var b: Fighter = Fighter.new(1, p2)
	a.opp = b
	b.opp = a
	a.world = self
	b.world = self
	fighters = [a, b]
	reset_round()


# ------------------------------------------------------------------ snapshot

## Not copied field by field: the fighters, dropped weapons, waves and the
## generator snapshot themselves; the events are output, drained every step;
## the scripted-hit queue is empty between steps (fighters queue and the
## world resolves within one).
const SNAPSHOT_SKIP: Array[StringName] = [&"fighters", &"weapons", &"waves", &"events", &"rng", &"_scripted_queue"]


## A copy of everything the world owns (milestone-1 task 5, SimState): its
## fields, both fighters, the dropped weapons, the waves and the generator.
## Taken between steps.
func snapshot() -> Dictionary:
	if not _scripted_queue.is_empty():
		push_error("World.snapshot(): taken mid-step, with scripted hits queued")
	var s: Dictionary = SimState.capture(self, SNAPSHOT_SKIP)
	s[&"fighters"] = [fighters[0].snapshot(), fighters[1].snapshot()]
	var ws: Array[Dictionary] = []
	for w: DroppedWeapon in weapons:
		ws.append(w.snapshot())
	s[&"weapons"] = ws
	var vs: Array[Dictionary] = []
	for v: SlashWave in waves:
		vs.append(v.snapshot())
	s[&"waves"] = vs
	s[&"rng"] = rng.snapshot()
	return s


## SHA-256 over the world's snapshot (milestone-1 task 5): equal on every
## step of two runs of the same seeded match.
func state_hash() -> String:
	return SimState.state_hash(snapshot())


## Puts a snapshot() back (milestone-1 task 134): the world steps on from it
## exactly as it did from the moment it was taken. The fighters are restored
## in place; the dropped weapons and waves are rebuilt; the events and the
## scripted-hit queue start empty. A snapshot can be restored any number of
## times, into this world or another built from the same fighters' configs.
func restore(s: Dictionary) -> void:
	var fields: Dictionary = s.duplicate()
	for n: StringName in [&"fighters", &"weapons", &"waves", &"rng"]:
		fields.erase(n)
	SimState.apply(self, fields)
	for i: int in 2:
		fighters[i].restore(s[&"fighters"][i])
	weapons = []
	for w: Dictionary in s[&"weapons"]:
		weapons.append(DroppedWeapon.from_snapshot(w))
	waves = []
	for v: Dictionary in s[&"waves"]:
		waves.append(SlashWave.from_snapshot(v, self))
	rng.restore(s[&"rng"])
	events = []
	_scripted_queue = []


func time_scale() -> float:
	return slowmo_scale if slowmo_frames > 0 else 1.0


func emit(e: Dictionary) -> void:
	events.append(e)


func drain_events() -> Array[Dictionary]:
	var e: Array[Dictionary] = events
	events = []
	return e


func reset_round() -> void:
	fighters[0].reset_for_round(0.0, -3.2, 0.0)
	fighters[1].reset_for_round(0.0, 3.2, PI)
	weapons = []
	waves = []
	_scripted_queue = []
	hitstop = 0
	slowmo_frames = 0
	ko_resolved = false
	prompt_by = -1
	prompt_kind = &""
	prompt_from_strike = false
	finisher_by = -1
	finisher_kind = &""
	finisher_from_strike = false


func request_slowmo(frames: int, scale: float) -> void:
	slowmo_frames = frames
	slowmo_scale = scale


## Breaks the reference cycles between the world, its fighters and its waves.
## The world can't be stepped afterwards.
func dispose() -> void:
	_scripted_queue = []
	for w: SlashWave in waves:
		w.owner = null
	waves = []
	for f: Fighter in fighters:
		f.opp = null
		f.world = null
		f.impaled_by = null


# ------------------------------------------------------------------ step

## inputs: [RawInput, RawInput]
func step(inputs: Array[RawInput]) -> void:
	for i: int in 2:
		fighters[i].input.update(inputs[i], frame + 1)
	if hitstop > 0:
		hitstop -= 1
		return
	frame += 1
	if slowmo_frames > 0:
		slowmo_frames -= 1

	FinisherRules.step_prompt(self)
	for f: Fighter in fighters:
		f.update()
	FinisherRules.step_finisher(self)
	_flush_scripted_hits()
	_separate()
	for f: Fighter in fighters:
		f.place_blades()
	_resolve_combat()
	_update_waves()
	_update_weapons()
	_clamp_arena()
	_check_ko()


# ------------------------------------------------------------------ geometry

func in_volume(a: Fighter, b: Fighter, def: AttackDef) -> bool:
	var d: float = SimMath.dist2(a.pos, b.pos)
	if d - SimConst.FIGHTER_RADIUS > def.range:
		return false
	if def.min_range != 0.0 and d < def.min_range:
		return false
	if def.arc >= 360.0:
		return true
	var half: float = def.arc / 2.0 + (30.0 if d < 1.3 else 0.0)
	return a.angle_to(b.pos) <= half


## Whether a's attack `def` reaches b this frame. A move with a swing reaches
## when a sweep of its blades touches b's hurt capsule (task 7.10): `touch`
## is that touch, as Fighter.blade_touch() found it, or null for none. A move
## without a swing keeps the demo's cone (in_volume), so the Duel plays as it
## did while swings are authored.
func reaches(a: Fighter, b: Fighter, def: AttackDef, touch: BladeSweep) -> bool:
	if def.swing == null:
		return in_volume(a, b, def)
	return touch != null


static func _skip_separate(f: Fighter) -> bool:
	return f.state == &"leap" or f.state == &"impaled" or f.state == &"ko" or f.state == &"stomp"


func _separate() -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	if _skip_separate(a) or _skip_separate(b):
		return
	if absf(a.pos.y - b.pos.y) > 1.0:
		return
	var dx: float = b.pos.x - a.pos.x
	var dz: float = b.pos.z - a.pos.z
	var d: float = JsMath.hypot(dx, dz)
	var min_d: float = SimConst.FIGHTER_RADIUS * 2.0
	if d >= min_d:
		return
	var n: V2 = V2.make(dx / d, dz / d) if d > 1e-6 else V2.make(1.0, 0.0)
	var push: float = (min_d - d) / 2.0
	a.pos.x -= n.x * push
	a.pos.z -= n.z * push
	b.pos.x += n.x * push
	b.pos.z += n.z * push


func _clamp_arena() -> void:
	var max_r: float = SimConst.ARENA_RADIUS - SimConst.FIGHTER_RADIUS
	for f: Fighter in fighters:
		var r: float = JsMath.hypot(f.pos.x, f.pos.z)
		if r > max_r:
			f.pos.x *= max_r / r
			f.pos.z *= max_r / r


# ------------------------------------------------------------------ combat

func _resolve_combat() -> void:
	# each entry: [a: Fighter, b: Fighter, def: AttackDef, kind: StringName, ctx: HitCtx]
	var outs: Array[Array] = []
	for a: Fighter in fighters:
		if a.state != &"attack" or a.atk == null:
			continue
		var at: AttackState = a.atk
		var def: AttackDef = at.def
		if def.damage <= 0.0 and def.posture <= 0.0:
			continue
		if at.charging:
			continue
		if not checks_frame(def, at.frame):
			continue
		if def.multi_hit != 0:
			if at.hits_done >= def.multi_hit:
				continue
		elif at.hit_done:
			continue
		# a move with a swing reaches by its blades' sweeps (task 7.10), and its
		# events start where they touched (task 7.11)
		var touch: BladeSweep = a.blade_touch(a.opp.hurt_capsule()) if def.swing != null else null
		var ctx: HitCtx = HitCtx.make(at.charge_frac, at.backstab)
		if touch != null:
			ctx.contact = touch.contact
		outs.append([a, a.opp, def, evaluate(a, a.opp, def, false, touch), ctx])
	# decided simultaneously, applied in order: each carries its own context so a
	# trade is fair even though the first application interrupts the second attacker
	for o: Array in outs:
		apply(o[0], o[1], o[2], o[3], false, o[4])


## Whether an attack `def` checks for a hit on its frame `f`: an active frame,
## and for a multi-hit move one of every multi_interval of them (3 by
## default). _resolve_combat() and SwingReach.first_contact() (task 7.13)
## both use it.
static func checks_frame(def: AttackDef, f: int) -> bool:
	if f <= def.startup or f > def.startup + def.active:
		return false
	if def.multi_hit != 0:
		var interval: int = def.multi_interval if def.multi_interval != AttackDef.UNSET else 3
		# JS: x % 0 is NaN, and NaN !== 0, so an interval of 0 skips every frame
		return interval != 0 and (f - def.startup - 1) % interval == 0
	return true


## Decide what an attack does to its target this frame, without changing anything.
## `touch`: for a move with a swing, its blades' touch on b this frame
## (Fighter.blade_touch()), or null for none; a scripted hit needs none.
func evaluate(a: Fighter, b: Fighter, def: AttackDef, scripted: bool, touch: BladeSweep = null) -> StringName:
	if b.state == &"ko" or b.state == &"intro" or b.state == &"victory":
		return &"miss"
	# neither half of a finisher can be hit (milestone-1 task 103)
	if b.state == &"finisher" or b.state == &"finished":
		return &"miss"
	# a downed fighter can't be hit, by anything (task 16)
	if b.is_downed():
		return &"miss"
	if b.state == &"impaled" and not scripted:
		return &"miss"
	var d: float = SimMath.dist2(a.pos, b.pos)
	var ang: float = a.angle_to(b.pos)

	# The three unblockable counters, each with a slightly generous shape.
	if def.counter == &"thrust" and b.is_forward_dodging() and d <= def.range + 1.2 and ang <= def.arc / 2.0 + 35.0:
		return &"stomp"
	if def.counter == &"slam" and b.is_back_dodging() and d <= def.range + 2.6 and ang <= def.arc / 2.0 + 40.0:
		return &"evadeCounter"
	if (
		def.counter == &"sweep"
		and b.pos.y > SimConst.JUMP_CLEAR
		and b.state != &"leap"
		and d <= def.range + 0.8
		and ang <= def.arc / 2.0 + 20.0
	):
		return &"leap"

	if not scripted and not reaches(a, b, def, touch):
		return &"miss"
	if def.jumpable and b.pos.y > SimConst.JUMP_CLEAR:
		return &"jumped"
	if b.is_flash_active() and b.facing_point(a.pos):
		return &"flash"
	if b.state == &"leap" or b.state == &"stomp":
		return &"evade"
	if b.is_invulnerable() and not def.undodgeable:
		return &"evade"
	if b.parry_active() and b.facing_point(a.pos):
		return &"parry" if b.armed else &"redirect"
	if b.armed and b.blocking and b.is_guard_capable() and b.facing_point(a.pos):
		var charge_full: bool = not scripted and (a.atk.charge_frac if a.atk != null else 0.0) >= 1.0
		var power: bool = def.power or def.kind == &"ultimate" or charge_full
		if def.unblockable:
			return &"disarm" if b.posture_full() else &"hit"
		if power and b.posture_full():
			return &"disarm"
		return &"block"
	return &"hit"


## The TS markDone closure in apply().
static func _mark_done(atk: AttackState, def: AttackDef) -> void:
	if atk == null:
		return
	if def.multi_hit != 0:
		atk.hits_done += 1
	else:
		atk.hit_done = true


## Apply an outcome decided by evaluate().
func apply(a: Fighter, b: Fighter, def: AttackDef, kind: StringName, scripted: bool, ctx: HitCtx = null) -> void:
	var atk: AttackState = null if scripted else a.atk
	var contact: V3 = (
		ctx.contact if ctx != null and ctx.contact != null
		else V3.make((a.pos.x + b.pos.x) / 2.0, 1.25, (a.pos.z + b.pos.z) / 2.0)
	)
	var charge_f: float = 0.0
	if ctx != null:
		charge_f = ctx.charge_f
	elif atk != null:
		charge_f = atk.charge_frac
	# the protected timings (milestone-1 task 22): the outcome's by the move's
	# weapon, the move's own (its stuns, hit-stop and charge bonus) by
	# whether its family has re-keyed it
	var pt: ProtectedTimings = ProtectedTimings.for_weapon(def.weapon)
	var own: ProtectedTimings = ProtectedTimings.for_move(def)

	match kind:
		&"miss":
			return
		&"jumped":
			_mark_done(atk, def)
			return
		&"evade":
			if atk != null and not atk.evaded_emitted:
				atk.evaded_emitted = true
				emit({"t": &"evade", "f": b.id, "attacker": a.id})
			return

		&"parry", &"flash", &"redirect":
			_mark_done(atk, def)
			var was_full: bool = a.posture_full()
			var timing: int = frame - b.block_press_frame
			emit({
				"t": &"parry",
				"parrier": b.id,
				"attacker": a.id,
				"pos": SimEvents.vec3(contact),
				"kind": kind,
				"timing": timing,
				"window": b.parry_window_at_press,
			})
			b.stats.parries += 1
			if kind != &"parry":
				b.stats.counters += 1
			b.set_state(&"parryAnim", SimConst.PARRIER_RECOVERY)
			b.blocking = b.armed and b.input.is_held(Btn.BLOCK)
			b.block_press_frame = -99999 # one press, one parry
			var melee: bool = not scripted or def.id == &"u_impale"
			a.release_if_impaling()
			if was_full and a.armed:
				a.disarm(b, &"redirect" if kind == &"redirect" else &"parried", pt)
				hitstop = pt.disarm_hitstop
				return
			if was_full and not a.armed:
				# already bare-handed: a broken posture dazes instead
				a.enter_stun(pt.disarmed_daze, &"stagger")
				a.posture = SimConst.DISARMED_STAGGER_RESET
				emit({"t": &"stagger", "f": a.id})
				hitstop = 10
				return
			a.add_posture(SimConst.REDIRECT_POSTURE if kind == &"redirect" else SimConst.PARRY_POSTURE)
			if melee:
				if kind == &"parry":
					a.enter_recoil(SimConst.PARRY_RECOIL, SimConst.PARRY_RECOIL_GUARD_AFTER)
				else:
					a.enter_stun(pt.flash_stun if kind == &"flash" else pt.redirect_stun)
				a.knock(b.pos.x, b.pos.z, 0.35, 8)
			hitstop = pt.parry_hitstop if kind == &"parry" else pt.flash_hitstop
			return

		&"stomp":
			a.release_if_impaling()
			a.enter_stun(pt.stomp_stun, &"stunned", &"stomp")
			a.add_posture(SimConst.STOMP_POSTURE)
			# the stomp lands on the blade's tip: the thruster is jolted back if
			# the defender is already nearer than that
			var pin: float = SimConst.STOMP_PIN_DIST.get(a.weapon.id if a.weapon != null else &"", SimConst.STOMP_PIN_DIST_DEFAULT)
			var fwd: V2 = SimMath.fwd(a.yaw)
			var gap: float = (b.pos.x - a.pos.x) * fwd.x + (b.pos.z - a.pos.z) * fwd.z
			var push: float = maxf(0.0, pin - gap)
			if push > 0.0:
				a.knock(a.pos.x + fwd.x, a.pos.z + fwd.z, push, SimConst.STOMP_PUSH_FRAMES)
			b.begin_stomp(a, pin, push)
			b.stats.counters += 1
			emit({
				"t": &"counter",
				"kind": &"stomp",
				"by": b.id,
				"on": a.id,
				"pos": SimEvents.vec3(V3.make(a.pos.x, 0.2, a.pos.z)),
			})
			hitstop = pt.stomp_hitstop
			return

		&"leap":
			a.release_if_impaling()
			a.enter_stun(SimConst.LEAP_STUN)
			a.add_posture(SimConst.LEAP_POSTURE)
			b.begin_leap(a)
			b.stats.counters += 1
			emit({
				"t": &"counter",
				"kind": &"leap",
				"by": b.id,
				"on": a.id,
				"pos": SimEvents.vec3(V3.make(a.pos.x, 1.7, a.pos.z)),
			})
			hitstop = pt.leap_hitstop
			return

		&"evadeCounter":
			_mark_done(atk, def)
			if atk != null:
				atk.extra_recovery += SimConst.EVADE_EXTRA_RECOVERY
			a.add_posture(SimConst.EVADE_POSTURE)
			b.counter_lunge_until = frame + SimConst.COUNTER_LUNGE_WINDOW
			b.stats.counters += 1
			emit({
				"t": &"counter",
				"kind": &"evade",
				"by": b.id,
				"on": a.id,
				"pos": SimEvents.vec3(V3.make(a.pos.x, 0.1, a.pos.z)),
			})
			emit({"t": &"counterReady", "f": b.id})
			hitstop = 5
			return

		&"block":
			_mark_done(atk, def)
			var charge_mult: float = 1.0 + 0.8 * charge_f
			var mult: float = def.guard_crush if not is_nan(def.guard_crush) else b.weapon.block_mitigation
			b.add_posture(def.posture * mult * charge_mult)
			b.set_state(&"blockstun", (def.blockstun if def.blockstun != AttackDef.UNSET else 12) + SimMath.js_round(float(own.charge_blockstun) * charge_f))
			b.blocking = true
			b.knock(a.pos.x, a.pos.z, def.knockback * 0.45 * charge_mult, 10)
			b.stats.blocks += 1
			hitstop = ProtectedTimings.block_hitstop(def.hitstop if def.hitstop != AttackDef.UNSET else 4)
			emit({
				"t": &"block",
				"attacker": a.id,
				"target": b.id,
				"attack": def.id,
				"posture": def.posture * mult * charge_mult,
				"pos": SimEvents.vec3(contact),
				"heavy": def.kind != &"light",
			})
			return

		&"disarm":
			_mark_done(atk, def)
			b.disarm(a, &"blocked", pt)
			hitstop = pt.disarm_hitstop
			return

		&"hit":
			_mark_done(atk, def)
			var dmg: float = def.damage * (1.0 + 0.8 * charge_f)
			var backstab: bool = false
			if ctx != null:
				backstab = ctx.backstab
			elif atk != null:
				backstab = atk.backstab
			if backstab:
				dmg *= 1.6
			var post: float = def.posture * SimConst.HIT_POSTURE_MULT * (1.0 + 0.8 * charge_f)
			b.hp = maxf(0.0, b.hp - dmg)
			b.add_posture(post)
			a.stats.hits_landed += 1
			a.stats.damage_dealt += dmg
			emit({
				"t": &"hit",
				"attacker": a.id,
				"target": b.id,
				"attack": def.id,
				"damage": dmg,
				"posture": post,
				"pos": SimEvents.vec3(contact),
				"heavy": def.kind != &"light",
				"sound": def.sound if def.sound != &"" else &"blade",
				"backstab": backstab,
			})
			b.release_if_impaling()
			if b.hp <= 0.0:
				b.to_ko(a, def.kind != &"light")
				b.knock(a.pos.x, a.pos.z, maxf(1.5, def.knockback * 1.5), 20)
			elif not b.armed and b.posture_full() and b.state != &"stagger":
				b.enter_stun(pt.disarmed_daze, &"stagger")
				b.posture = SimConst.DISARMED_STAGGER_RESET
				b.knock(a.pos.x, a.pos.z, def.knockback, 12)
				emit({"t": &"stagger", "f": b.id})
			elif b.state != &"impaled":
				if knocks_down(def, charge_f):
					b.enter_knockdown(pt)
					emit({"t": &"knockdown", "f": b.id, "attacker": a.id})
				else:
					b.enter_hitstun((def.hitstun if def.hitstun != AttackDef.UNSET else 20) + SimMath.js_round(float(own.charge_hitstun) * charge_f))
				b.knock(a.pos.x, a.pos.z, def.knockback * (1.0 + 1.2 * charge_f), 12)
			hitstop = (def.hitstop if def.hitstop != AttackDef.UNSET else 4) + SimMath.js_round(float(own.charge_hitstop) * charge_f)
			return


## Whether a hit from `def` at charge `charge_f` knocks the defender down in
## place of hitstun (task 16): an unblockable, a heavy released at full charge
## (a power attack) or one of the Greatsword's slams (SimConst.KNOCKDOWN_MOVES).
## An ultimate's hits never do, though they count as unblockable.
static func knocks_down(def: AttackDef, charge_f: float) -> bool:
	if def.kind == &"ultimate":
		return false
	return def.unblockable or charge_f >= 1.0 or SimConst.KNOCKDOWN_MOVES.has(def.id)


func resolve_scripted_hit(a: Fighter, b: Fighter, def: AttackDef) -> StringName:
	var kind: StringName = evaluate(a, b, def, true)
	apply(a, b, def, kind, true)
	return kind


## Scripted (ultimate) hits are queued and resolved after BOTH fighters have
## read this frame's input, so neither player gets a one-frame advantage.
## cb takes the outcome (StringName); leave it a null Callable for none.
func queue_scripted_hit(a: Fighter, b: Fighter, def: AttackDef, cb: Callable = Callable()) -> void:
	var h: ScriptedHit = ScriptedHit.new()
	h.a = a
	h.b = b
	h.def = def
	h.cb = cb
	_scripted_queue.append(h)


func _flush_scripted_hits() -> void:
	var q: Array[ScriptedHit] = _scripted_queue
	_scripted_queue = []
	for h: ScriptedHit in q:
		var res: StringName = &"miss" if ko_resolved else resolve_scripted_hit(h.a, h.b, h.def)
		if not h.cb.is_null():
			h.cb.call(res)


# ------------------------------------------------------------------ katana ultimate wave

## kind: &"vertical" | &"horizontal"
func spawn_wave(owner: Fighter, kind: StringName) -> void:
	var d: V2 = SimMath.fwd(owner.yaw)
	waves.append(SlashWave.new(owner, kind, owner.pos.x + d.x * 0.6, owner.pos.z + d.z * 0.6, d.x, d.z))
	emit({
		"t": &"ultWave",
		"f": owner.id,
		"kind": kind,
		"pos": SimEvents.vec3(V3.make(owner.pos.x, 1.0, owner.pos.z)),
		"yaw": owner.yaw,
	})


func _update_waves() -> void:
	if ko_resolved:
		waves = []
		return
	for w: SlashWave in waves:
		var prev: float = w.s
		w.s += WAVE_SPEED * SimConst.DT
		var b: Fighter = w.owner.opp
		if not w.resolved:
			var rx: float = b.pos.x - w.ox
			var rz: float = b.pos.z - w.oz
			var along: float = rx * w.dx + rz * w.dz
			var lateral: float = absf(rx * w.dz - rz * w.dx)
			if along > prev - 0.4 and along <= w.s + 0.3:
				var in_lane: bool = w.kind == &"horizontal" or lateral <= 0.95
				if in_lane:
					var def: AttackDef = Moves.ULT_HITS[&"u_moon_v"] if w.kind == &"vertical" else Moves.ULT_HITS[&"u_moon_h"]
					var res: StringName = resolve_scripted_hit(w.owner, b, def)
					if res != &"miss" and res != &"evade":
						w.resolved = true
					if res == &"parry" or res == &"flash" or res == &"redirect":
						w.alive = false
		if w.s > WAVE_RANGE:
			w.alive = false
	var alive: Array[SlashWave] = []
	for w: SlashWave in waves:
		if w.alive:
			alive.append(w)
	waves = alive


# ------------------------------------------------------------------ dropped weapons

## Knocks victim's weapon out of the hands, flying along `dir`
## (DroppedWeapon.heading()) to stick inside the walls (milestone-1 task 86).
func spawn_dropped_weapon(victim: Fighter, dir: V2) -> void:
	var kept: Array[DroppedWeapon] = []
	for w: DroppedWeapon in weapons:
		if w.owner != victim.id:
			kept.append(w)
	weapons = kept
	var at: V2 = DroppedWeapon.landing(victim.pos.x, victim.pos.z, dir)
	# it leaves the hands no further out than the ring it lands inside, so its
	# whole flight stays inside the walls
	var hands: V2 = DroppedWeapon.inside_ring(victim.pos.x, victim.pos.z)
	weapons.append(
		DroppedWeapon.new(
			victim.id,
			victim.weapon.id,
			V3.make(hands.x, 1.3, hands.z),
			V3.make(at.x, 0.0, at.z),
			JsMath.atan2(dir.x, dir.z),
		)
	)


func weapon_of(owner: int) -> DroppedWeapon:
	for w: DroppedWeapon in weapons:
		if w.owner == owner:
			return w
	return null


func remove_dropped_weapon(owner: int) -> void:
	var kept: Array[DroppedWeapon] = []
	for w: DroppedWeapon in weapons:
		if w.owner != owner:
			kept.append(w)
	weapons = kept


func _update_weapons() -> void:
	for w: DroppedWeapon in weapons:
		if w.step():
			emit({"t": &"weaponStuck", "owner": w.owner, "pos": SimEvents.vec3(w.pos)})


# ------------------------------------------------------------------ round end

func _check_ko() -> void:
	if ko_resolved:
		return
	var f0: Fighter = fighters[0]
	var f1: Fighter = fighters[1]
	var d0: bool = f0.hp <= 0.0
	var d1: bool = f1.hp <= 0.0
	if not d0 and not d1:
		return
	ko_resolved = true
	if d0 and f0.state != &"ko":
		f0.to_ko()
	if d1 and f1.state != &"ko":
		f1.to_ko()
	var winner: int = -1 if d0 and d1 else (1 if d0 else 0)
	emit({"t": &"ko", "loser": -1 if d0 and d1 else (0 if d0 else 1), "winner": winner, "finisher": finisher_by >= 0})
	request_slowmo(50, 0.3)
