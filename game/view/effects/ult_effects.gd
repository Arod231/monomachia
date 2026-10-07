class_name UltEffects
extends RefCounted
## The disarmed ultimate's effects (milestone-1 task 100, the owner's choices
## of Oct 7; design.md's mood board: a spirit shockwave, taking no side's
## colour), drawn with CombatEffects like RecallAura, so they add no node and
## keep the effect clock:
##
## - The choice (feed()): while the fighter chooses, heat haze rises off it
##   (pale, slow, swelling clouds) and petals lift off the ground round it
##   and turn in the air, once per rules frame, scattered by the frame.
## - Breaker Palm's blow (on_event(), on its hit or block): a pale-gold flash
##   at the contact with a white core, and a ring of distortion rolling out
##   from it, facing the camera.
##
## The recall's burst is RecallAura's. Under Reduce flashes every flash here
## is dimmed (CombatEffects.flash_scale) and slowed (flash_slow), as are the
## recall's.

const PALE_GOLD: Color = Color(1.0, 0.88, 0.58)
const WHITE: Color = Color(1.0, 0.98, 0.92)
const HAZE: Color = Color(0.5, 0.47, 0.45, 0.045)
const PETAL: Color = Color(0.82, 0.66, 0.95)
const PETAL_PALE: Color = Color(0.96, 0.86, 0.92)
## Per rules frame of the choice: haze clouds and lifted petals.
const HAZE_PER_FRAME: int = 1
const PETALS_PER_FRAME: int = 2
## How far round the fighter (m) the petals lift from.
const PETAL_RADIUS: float = 1.1

## The last rules frame fed, per side (-1 for none).
var _fed: Dictionary[int, int] = {}


## Throws side `side`'s choice haze and petals for fighter `f` for each rules
## frame it has stepped in the choice since the last call (none outside it).
func feed(effects: CombatEffects, side: int, f: Fighter) -> void:
	if f == null or f.world == null:
		return
	var frame: int = f.world.frame
	var last: int = _fed.get(side, -1)
	_fed[side] = frame
	if f.state != &"ultChoice" or last < 0 or frame <= last:
		return
	for fr: int in range(maxi(last + 1, frame - f.sf), frame + 1):
		choice_frame(effects, side, Vector3(f.pos.x, 0.0, f.pos.z), fr)


## One rules frame `fr` of the choice's haze and petals round a fighter
## standing at `at`.
static func choice_frame(effects: CombatEffects, side: int, at: Vector3, fr: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([side, fr, &"ult_choice"])
	var born: float = float(fr)
	for k: int in HAZE_PER_FRAME:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(0.1, 0.5)
		effects.burst(at + Vector3(cos(a) * r, rng.randf_range(0.2, 1.4), sin(a) * r), {
			"count": 1, "color": HAZE, "size": 0.35, "size_end": 0.9, "life": 40, "life_jitter": 0.3,
			"speed": 0.5, "dir": Vector3.UP, "spread": 25.0,
		}, born, rng.randi())
	for k: int in PETALS_PER_FRAME:
		var a: float = rng.randf() * TAU
		var r: float = PETAL_RADIUS * sqrt(rng.randf())
		effects.burst(at + Vector3(cos(a) * r, 0.05, sin(a) * r), {
			"count": 1, "color": PETAL.lerp(PETAL_PALE, rng.randf()), "size": 0.07, "size_end": 0.05,
			"life": 60, "life_jitter": 0.25, "speed": 1.8, "dir": Vector3(-sin(a) * 0.5, 1.0, cos(a) * 0.5), "spread": 20.0,
			"gravity": 1.4, "floor": 0.02,
		}, born, rng.randi())


## Spawns the effects of rules event `e` on world frame `frame` if it is one
## of the disarmed ultimate's (Breaker Palm's hit or block); true when it was.
static func on_event(effects: CombatEffects, e: Dictionary, frame: int) -> bool:
	if (e.get("t") != &"hit" and e.get("t") != &"block") or e.get("attack", &"") != &"f_breaker" or not e.get("pos") is Dictionary:
		return false
	var p: Dictionary = e["pos"]
	var at: Vector3 = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
	var born: float = float(frame)
	var slow: float = effects.flash_slow
	effects.flash(at, PALE_GOLD, 2.2, roundi(20 * slow), born)
	effects.flash(at, WHITE, 0.9, roundi(8 * slow), born)
	effects.distortion(at, 0.2, 2.6, roundi(22 * slow), born, 1.0, 0.35)
	return true


## Forgets what was fed (a new round, a new match).
func clear() -> void:
	_fed.clear()
