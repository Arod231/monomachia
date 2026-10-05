class_name TrainingBrain
extends RefCounted
## Port of v0.1-web-mvp:src/sim/ai/training.ts.
##
## Training dummy: repeats one chosen behaviour so the player can practise
## parry timing and the three unblockable counters.
##
## Port notes:
## - TrainingBehaviour is a StringName equal to the TS literal (BEHAVIOURS).
## - abilityFor is the static ability_for(); its null is &"".
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

## TrainingBehaviour
const BEHAVIOURS: Array[StringName] = [
	&"idle", &"block", &"lights", &"heavies", &"thrust", &"sweep", &"slam", &"random", &"fight",
]


## The id of f's weapon ability with the given counter kind, or &"" (TS null).
static func ability_for(f: Fighter, kind: StringName) -> StringName:
	return weapon_ability_for(f.weapon, kind)


## The id of weapon w's ability with the given counter kind, or &"".
static func weapon_ability_for(w: WeaponDef, kind: StringName) -> StringName:
	for ab_id: StringName in w.abilities:
		if w.moves.has(ab_id) and w.moves[ab_id].counter == kind:
			return ab_id
	return &""


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
	# put the practised unblockable on the light slot
	if b == &"thrust" or b == &"sweep" or b == &"slam":
		var ab_id: StringName = ability_for(me, b)
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


func think() -> RawInput:
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
				for k: StringName in [&"thrust", &"sweep", &"slam"]:
					if ability_for(me, k) != &"":
						opts.append(k)
				b = opts[_pick % opts.size()]
				_pick += 1
				if b == &"thrust" or b == &"sweep" or b == &"slam":
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
					if p % 2 == 0:
						_tap(Btn.HEAVY, frame + 34)
					_next = frame + 120
				&"thrust", &"sweep", &"slam":
					_tap(Btn.BLOCK, frame, 3)
					_tap(Btn.LIGHT, frame + 1, 2)
					_next = frame + 130
	if _drill == &"lights" and _light_follow_up_due(frame):
		_tap(Btn.LIGHT, frame)
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


## kind: &"thrust" | &"sweep" | &"slam"
func _set_behaviour_keep_random(kind: StringName) -> void:
	var ab_id: StringName = ability_for(me, kind)
	if ab_id == &"":
		return
	var other: StringName = _other_ability(ab_id)
	var arr: Array[StringName] = [ab_id, other]
	me.abilities = arr
