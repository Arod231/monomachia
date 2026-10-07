class_name TrailState
extends RefCounted
## Whether a fighter's blades smear on the frame shown, how strongly (0 to 1)
## for each hand, and in which tint (plan task 18.2's trail rules). Read from
## the rules' state with of(); the air smears (AirSmear, milestone-1 task 37,
## in place of the brush-stroke trails) draw it, as strongly as the tip moves
## fast.
##
## The rules, settled with the owner on Oct 3, 2026:
## - an attack trails in its active frames, then fades over FADE_FRAMES; never
##   while charging, and never for Flash (Shadow Step, the other zero-damage
##   move, does trail);
## - only the hands the move strikes with: its `hand` (R, L or both) for a
##   paired weapon (the daggers), the one blade for any other;
## - red (DANGER) for unblockables, gold (ULT) for moves marked so (the
##   counter lunges) and for the ultimates, a pale sheen (NORMAL) otherwise:
##   the move's `trail`, which the move data fills in that way (the red and
##   gold tints stay on the smears until milestone-1 task 82's 危 and glint
##   take the cue over, the owner's choice, Oct 6);
## - the ultimates trail in the phases the demo's did: the Moonsplitter for the
##   first ULT_RELEASE_FRAMES of its release, the Impaler in its dash, the
##   Tempest in its spin and the second half of its finisher;
## - bare hands never trail: neither the fists weapon nor a disarmed fighter.
##
## Frames are read on the frame shown, `alpha` of the way from the step
## before to the last (MatchHost.alpha()), as the poses are, so a trail
## fades smoothly between steps and stands still in hit-stop.

const RIGHT: int = 0
const LEFT: int = 1

const NORMAL: StringName = &"normal"
const DANGER: StringName = &"danger"
const ULT: StringName = &"ult"

## Frames a trail takes to fade after the last active frame.
const FADE_FRAMES: float = 2.0
## The Moonsplitter's release trails for this many frames.
const ULT_RELEASE_FRAMES: float = 6.0
## The Tempest's finisher trails from this far through its 10 frames.
const TEMPEST_FINAL_FROM: float = 5.0
## Weapons held one in each hand.
const PAIRED: Array[StringName] = [&"daggers"]

var kind: StringName = NORMAL
var _intensity: Array[float] = [0.0, 0.0]


## How strongly hand `hand` (RIGHT or LEFT) trails, 0 to 1.
func intensity(hand: int) -> float:
	return _intensity[hand]


func on(hand: int) -> bool:
	return _intensity[hand] > 0.0


## The trail of fighter `f` on the frame shown, `alpha` of the way from the
## step before to the last.
static func of(f: Fighter, alpha: float) -> TrailState:
	var t: TrailState = TrailState.new()
	if f == null or not f.armed or f.moveset().id == &"fists":
		return t
	var paired: bool = PAIRED.has(f.moveset().id)
	if f.state == &"attack" and f.atk != null:
		var at: AttackState = f.atk
		var def: AttackDef = at.def
		if at.charging or def.special == &"flash":
			return t
		var shown: float = float(at.frame) - 1.0 + alpha
		var k: float = window(shown, float(def.startup), float(def.startup + def.active))
		t.kind = _kind(def)
		var hands: Array[bool] = striking_hands(def.hand, paired)
		for h: int in 2:
			t._intensity[h] = k if hands[h] else 0.0
	elif f.state == &"ult" and f.ult != null:
		var k: float = _ult_on(f.ult, alpha)
		t.kind = ULT
		t._intensity[RIGHT] = k
		t._intensity[LEFT] = k if paired else 0.0
	return t


## 0 up to and including frame `from`, 1 after it until frame `to`, then
## fading to 0 over FADE_FRAMES.
static func window(shown: float, from: float, to: float) -> float:
	if shown <= from:
		return 0.0
	if shown <= to:
		return 1.0
	return clampf(1.0 - (shown - to) / FADE_FRAMES, 0.0, 1.0)


## Which hands (right, left) a move with hand `hand` strikes with.
static func striking_hands(hand: StringName, paired: bool) -> Array[bool]:
	if not paired:
		return [true, false]
	match hand:
		&"L":
			return [false, true]
		&"both":
			return [true, true]
	return [true, false]


static func _kind(def: AttackDef) -> StringName:
	if def.trail == ULT or def.kind == &"ultimate":
		return ULT
	if def.trail == DANGER or def.unblockable:
		return DANGER
	return NORMAL


## 1 in the ultimate's trailing phases, else 0. The phase frame shown is
## pf - 1 + alpha, as an attack's.
static func _ult_on(u: UltState, alpha: float) -> float:
	var shown: float = float(u.pf) - 1.0 + alpha
	match u.kind:
		&"moonsplitter":
			return 1.0 if u.phase == &"release" and shown < ULT_RELEASE_FRAMES else 0.0
		&"impaler":
			return 1.0 if u.phase == &"dash" else 0.0
		&"tempest":
			if u.phase == &"spin":
				return 1.0
			if u.phase == &"final":
				return 1.0 if shown > TEMPEST_FINAL_FROM else 0.0
	return 0.0
