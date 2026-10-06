class_name TrainingBrain
extends RefCounted
## Port of v0.1-web-mvp:src/sim/ai/training.ts.
##
## Training dummy: repeats one chosen behaviour so the player can practise
## parry timing and the unblockable counters. It performs each unblockable
## through its route (UnblockableRoutes, milestone-1 task 83).
##
## Port notes:
## - TrainingBehaviour is a StringName equal to the TS literal (BEHAVIOURS).
## - Fighter.abilities is always replaced with a new array, never changed in
##   place: by default it is the weapon's own default_abilities array.
## - dispose() is new: it disposes the sparring brain and drops the fighter.
## - practice_distance() is the rebuild's (task 7.13): the demo's distances
##   until the weapon's light starter has a swing, then the weapon's reach.
##
## Since the port (plan task 8.10), two demo bugs are fixed:
## - random picks its drill from a tally of its own. The demo shared one with
##   the heavy follow-up, so of four drills the third never came up;
## - lights presses for each light follow-up once the attack can take it,
##   instead of at fixed times, so the whole light string comes out. The demo's
##   third press came a frame too late for the Katana's Crown Cut.
## Since milestone-1 task 17 heavies presses its heavy follow-up the same
## way, once the heavy can take it: at the demo's fixed 34 frames it came
## before the startup of a heavy whose clip at 1.0x runs longer (the
## Greatsword's Overhead Strike), and was lost.
## Since milestone-1 task 83 a heavy with a second draw (the Katana's Iai,
## drawn horizontally with the stick held sideways) runs a four-turn cycle:
## the first draw with its follow-up, the second draw alone, the first alone,
## the second with its follow-up; other heavies take theirs every other turn.

## TrainingBehaviour
const BEHAVIOURS: Array[StringName] = [
	&"idle", &"block", &"lights", &"heavies", &"thrust", &"sweep", &"slam", &"random", &"fight",
]


## { btn, from, to }
class Tap:
	var btn: int
	var from: int
	var to: int


var behaviour: StringName = &"idle"
var _spar: AIBrain
var _next: int = 0
var _taps: Array[Tap] = []
var _hold: int = 0
## Heavies turns so far: every other one gets its follow-up.
var _heavy_turns: int = 0
## Whether this heavies turn's follow-up is still to be pressed.
var _heavy_follow_up: bool = false
## Whether this heavies turn holds the stick sideways for the second draw.
var _heavy_sideways: bool = false
## Picks random's next drill.
var _pick: int = 0
## The drill the current cycle runs (&"" before the first).
var _drill: StringName = &""

var me: Fighter


## Not copied field by field: the fighter (a link the restore keeps) and the
## sparring brain, which snapshots itself.
const SNAPSHOT_SKIP: Array[StringName] = [&"me", &"_spar"]


func _init(p_me: Fighter) -> void:
	me = p_me
	_spar = AIBrain.new(me, AIBrain.DIFFICULTY[&"normal"], 5)
	# the dummy never finishes the player (milestone-1 task 107)
	_spar.finishes = false


## A copy of the dummy's state (milestone-1 task 5), its sparring brain's
## included.
func snapshot() -> Dictionary:
	var s: Dictionary = SimState.capture(self, SNAPSHOT_SKIP)
	s[&"_spar"] = _spar.snapshot()
	return s


## Puts a snapshot() back (milestone-1 task 6), after the world.
func restore(s: Dictionary) -> void:
	var fields: Dictionary = s.duplicate()
	fields.erase(&"_spar")
	SimState.apply(self, fields)
	_spar.restore(s[&"_spar"])


## Breaks the references to the fighter. The brain can't think afterwards.
func dispose() -> void:
	_spar.dispose()
	me = null


func set_behaviour(b: StringName) -> void:
	behaviour = b
	_next = 0
	_taps = []
	_hold = 0
	_drill = &""
	_pick = 0
	_heavy_turns = 0
	_heavy_follow_up = false
	_heavy_sideways = false
	# put the practised unblockable on the light slot
	if UnblockableRoutes.DRILLS.has(b):
		var ab_id: StringName = UnblockableRoutes.move_for(me.weapon, b)
		if ab_id != &"":
			var other: StringName = _other_ability(ab_id)
			var arr: Array[StringName] = [ab_id, other]
			me.abilities = arr
	else:
		me.abilities = me.weapon.default_abilities.duplicate()


## this.me.weapon.abilities.find((x) => x !== id) ?? id
func _other_ability(ab_id: StringName) -> StringName:
	for x: StringName in me.weapon.abilities:
		if x != ab_id:
			return x
	return ab_id


func _tap(btn: int, at: int, length: int = 2) -> void:
	var t: Tap = Tap.new()
	t.btn = btn
	t.from = at
	t.to = at + length - 1
	_taps.append(t)


## The distance the dummy keeps from the player with weapon `w` (centre to
## centre): the weapon's reach once that comes from its light starter's
## swing (task 7.13), and the demo's distances until then.
static func practice_distance(w: WeaponDef) -> float:
	var starter: AttackDef = w.moves.get(w.light_start)
	if starter != null and starter.swing != null:
		return w.reach
	return 2.6 if w.id == &"greatsword" else (1.8 if w.id == &"daggers" else 2.2)


## The next step's input. While a finisher prompt is open for the dummy, it
## presses no heavy that would take it: the dummy never finishes the player
## (milestone-1 task 107).
func think() -> RawInput:
	var out: RawInput = _think()
	if me.world.prompt_by == me.id:
		out.buttons &= ~(1 << Btn.HEAVY)
	return out


func _think() -> RawInput:
	if behaviour == &"fight":
		return _spar.think()
	var frame: int = me.world.frame + 1
	var mx: float = 0.0
	var my: float = 0.0
	var buttons: int = _hold
	var d: float = SimMath.dist2(me.pos, me.opp.pos)
	var want: float = practice_distance(me.weapon)
	var free: bool = me.state == &"free" or me.state == &"step"

	if behaviour == &"block":
		buttons |= 1 << Btn.BLOCK
	elif behaviour != &"idle":
		# keep a practice distance
		if free:
			if d > want + 0.6:
				my = 1.0
			elif d < want - 0.7:
				my = -0.7
		if free and frame >= _next and absf(d - want) < 0.9:
			var b: StringName = behaviour
			if b == &"random":
				var opts: Array[StringName] = [&"lights", &"heavies"]
				opts.append_array(UnblockableRoutes.kinds(me.weapon))
				b = opts[_pick % opts.size()]
				_pick += 1
				if UnblockableRoutes.DRILLS.has(b):
					_set_behaviour_keep_random(b)
			_drill = b
			match b:
				&"lights":
					_tap(Btn.LIGHT, frame)
					_next = frame + 110
				&"heavies":
					_tap(Btn.HEAVY, frame)
					var p: int = _heavy_turns
					_heavy_turns += 1
					if _second_draw() != &"":
						_heavy_sideways = p % 2 == 1
						_heavy_follow_up = p % 4 == 0 or p % 4 == 3
					else:
						_heavy_follow_up = p % 2 == 0
					_next = frame + 120
				&"thrust", &"sweep", &"slam":
					_tap(Btn.BLOCK, frame, 3)
					_tap(Btn.LIGHT, frame + 1, 2)
					_next = frame + 130
	if _drill == &"lights" and _light_follow_up_due(frame):
		_tap(Btn.LIGHT, frame)
	# the stick held sideways until the heavy is drawn as its second draw
	if _drill == &"heavies" and _heavy_sideways and me.atk != null and me.atk.def.id == me.weapon.heavy_start:
		mx = 1.0
	if _drill == &"heavies" and _heavy_follow_up and _heavy_follow_up_due():
		_tap(Btn.HEAVY, frame)
		_heavy_follow_up = false
	for t: Tap in _taps:
		if frame >= t.from and frame <= t.to:
			buttons |= 1 << t.btn
	var kept: Array[Tap] = []
	for t: Tap in _taps:
		if t.to >= frame:
			kept.append(t)
	_taps = kept
	return RawInput.make(mx, my, buttons)


## True when the dummy's light has a light follow-up it takes on the next
## step and no press for it is already on the way.
func _light_follow_up_due(frame: int) -> bool:
	var a: AttackState = me.atk
	if a == null or not me.takes_follow_up_at(a.frame + 1):
		return false
	if a.def.kind != &"light" or a.def.chain_light == &"":
		return false
	for t: Tap in _taps:
		if t.btn == Btn.LIGHT and t.to >= frame:
			return false
	return true


## True when the dummy's heavy has a heavy follow-up it takes on the next
## step.
func _heavy_follow_up_due() -> bool:
	var a: AttackState = me.atk
	return a != null and me.takes_follow_up_at(a.frame + 1) and a.def.kind == &"heavy" and a.def.chain_heavy != &""


## The heavy starter's second draw (AttackDef.release_variant), or &"".
func _second_draw() -> StringName:
	var start: AttackDef = me.weapon.moves.get(me.weapon.heavy_start)
	return start.release_variant if start != null else &""


## kind: one of UnblockableRoutes.DRILLS
func _set_behaviour_keep_random(kind: StringName) -> void:
	var ab_id: StringName = UnblockableRoutes.move_for(me.weapon, kind)
	if ab_id == &"":
		return
	var other: StringName = _other_ability(ab_id)
	var arr: Array[StringName] = [ab_id, other]
	me.abilities = arr
