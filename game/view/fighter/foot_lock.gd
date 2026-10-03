class_name FootLock
extends RefCounted
## Foot locking (authored-animation task 8, the owner's choice at task 1's
## gate): under a clip, a planted foot stays where it landed, so the creep of
## up to 6 cm the retarget leaves in planted feet (where the hip joints sit
## on the pelvis differs between the rigs) goes. FighterRig asks it for each
## foot's target before the leg IK, with the clip's ankles in world space, so
## a foot stays put on the ground while the fighter's root moves.
##
## Per foot, stepped once per rules frame (a frame seen again changes
## nothing, so hit-stop and pause hold it):
## - planted: the clip's ankle within PLANT_HEIGHT of its rest height (within
##   LIFT_HEIGHT once held, so a foot doesn't flicker); the foot is held where
##   it was planted;
## - released: the clip lifts it, carries it SLIDE from where it is held (a
##   step or a slide meant by the clip), the leg can't reach it (REACH of the
##   leg's length from the hip), or locking is switched off (enabled); the
##   hold then eases out over EASE_FRAMES, the foot going back onto the clip.
## A foot planted again while easing out is held where it shows, so it never
## jumps.

## How far (m) above its rest height a clip's ankle counts as planted, and
## how far above it a held foot is let go.
const PLANT_HEIGHT: float = 0.03
const LIFT_HEIGHT: float = 0.06
## How far (m) the clip may carry a held foot before it is let go.
const SLIDE: float = 0.15
## How many rules frames a released hold takes to ease out.
const EASE_FRAMES: int = 4
## The share of the leg's length beyond which a held foot is out of reach.
const REACH: float = 0.995

## Whether planted feet are held; off, every hold eases out.
var enabled: bool = true
## Each held foot's place (world space), by side ("Right", "Left").
var held: Dictionary[String, Vector3] = {}
## How much each foot is held (0 to 1), by side.
var hold: Dictionary[String, float] = {}
## Each ankle's height in the rest pose (m above the ground), by side.
var rest_height: Dictionary[String, float] = {}
var _frame: int = -1


func _init(p_rest_height: Dictionary[String, float]) -> void:
	rest_height = p_rest_height


## Steps the holds to rules frame `frame`: `feet`, the clip's ankles, and
## `hips`, the hip joints (world space), and `legs`, each leg's length (m),
## by side. A frame seen before changes nothing.
func update(frame: int, feet: Dictionary[String, Vector3], hips: Dictionary[String, Vector3], legs: Dictionary[String, float]) -> void:
	if frame == _frame:
		return
	var steps: int = 1 if _frame < 0 else clampi(frame - _frame, 1, EASE_FRAMES)
	_frame = frame
	for side: String in feet:
		var foot: Vector3 = feet[side]
		var share: float = hold.get(side, 0.0)
		var holding: bool = held.has(side) and share >= 1.0
		var limit: float = LIFT_HEIGHT if holding else PLANT_HEIGHT
		var planted: bool = enabled and foot.y <= rest_height.get(side, 0.0) + limit
		if planted and holding:
			var at: Vector3 = held[side]
			planted = at.distance_to(foot) <= SLIDE and hips[side].distance_to(at) <= legs[side] * REACH
		if planted:
			if not holding:
				# held where it shows: on the clip, or part way back to an old hold
				held[side] = target(side, foot)
			hold[side] = 1.0
		elif share > 0.0:
			share -= float(steps) / float(EASE_FRAMES)
			if share <= 0.0:
				hold.erase(side)
				held.erase(side)
			else:
				hold[side] = share


## Where foot `side` goes (world space) when the clip has it at `clip_foot`:
## its hold, blended back onto the clip as the hold eases out.
func target(side: String, clip_foot: Vector3) -> Vector3:
	if not held.has(side):
		return clip_foot
	return clip_foot.lerp(held[side], hold.get(side, 0.0))


## Whether foot `side` is fully held now.
func holds(side: String) -> bool:
	return held.has(side) and hold.get(side, 0.0) >= 1.0


## Lets every foot go at once (a new round, a whole-body clip).
func clear() -> void:
	held.clear()
	hold.clear()
	_frame = -1
