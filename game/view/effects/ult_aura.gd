class_name UltAura
extends RefCounted
## The ultimate-ready aura (milestone-1 task 100, the owner's choice of Oct
## 7): while a fighter's ultimate is ready and it isn't knocked out (on()),
## embers rise off its body in its side's colour (feed(), on the effects'
## clock, once per rules frame, scattered by the frame), a heat-haze shimmer
## veils it and a faint rim glow in its side's colour runs along its
## silhouette (FighterView.show_aura(): shaders/heat_haze.gdshader and
## ult_rim.gdshader). It is steady, so Reduce flashes keeps it whole.

## Per rules frame, this many embers (before the preset's scale).
const EMBERS_PER_FRAME: int = 3
## How far round the body (m) the embers rise from.
const EMBER_RADIUS: float = 0.3
## Mixed into the side's colour, so the embers glow hot.
const EMBER_HOT: Color = Color(1.0, 0.62, 0.25)
## The rim's strength.
const RIM: float = 1.1

## The last rules frame fed, per side (-1 for none).
var _fed: Dictionary[int, int] = {}


## Whether fighter `f` shows the aura: its ultimate ready, and not knocked out.
static func on(f: Fighter) -> bool:
	return f != null and f.can_ult() and f.state != &"ko"


## The rim's strength when the aura is `shown`; Reduce flashes (`reduced`)
## keeps it, since it is steady.
static func rim(shown: bool, _reduced: bool) -> float:
	return RIM if shown else 0.0


## Throws side `side`'s embers in `color` for fighter `f` for each rules
## frame it has stepped with the aura on since the last call.
func feed(effects: CombatEffects, side: int, f: Fighter, color: Color) -> void:
	if f == null or f.world == null:
		return
	var frame: int = f.world.frame
	var last: int = _fed.get(side, -1)
	_fed[side] = frame
	if not on(f) or last < 0 or frame <= last:
		return
	for fr: int in range(maxi(last + 1, frame - 8), frame + 1):
		embers(effects, side, Vector3(f.pos.x, f.pos.y, f.pos.z), color, fr)


## One rules frame `fr` of side `side`'s embers round a fighter standing at
## `at`, in `color`.
static func embers(effects: CombatEffects, side: int, at: Vector3, color: Color, fr: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([side, fr, &"ult_aura"])
	for k: int in EMBERS_PER_FRAME:
		var a: float = rng.randf() * TAU
		var from: Vector3 = at + Vector3(cos(a) * EMBER_RADIUS, rng.randf_range(0.1, 1.5), sin(a) * EMBER_RADIUS)
		effects.burst(from, {
			"count": 1, "color": color.lightened(0.35).lerp(EMBER_HOT, rng.randf_range(0.35, 0.6)), "size": 0.065, "size_end": 0.015,
			"life": 45, "life_jitter": 0.4, "speed": 0.7, "dir": Vector3(cos(a) * 0.2, 1.0, sin(a) * 0.2), "spread": 25.0,
		}, float(fr), rng.randi())


## Forgets what was fed (a new round, a new match).
func clear() -> void:
	_fed.clear()
