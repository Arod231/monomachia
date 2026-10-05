class_name RecallAura
extends RefCounted
## The recall's power-up aura and burst (authored-animation task 30b, the
## owner's design after a Super Saiyan power-up), drawn with CombatEffects'
## glows, rings and particles, so it adds no node and is timed on the effect
## clock like every other effect: it holds in hit-stop and pause, and a shot
## at a given frame always looks the same (each frame's particles are
## scattered by a seed made from the frame and the side).
##
## - The aura (feed()): through the recall, every rules frame throws golden
##   flame particles that rise and thin from round the fighter's feet and
##   body, a soft golden glow pulses at its chest, and every few frames a
##   white wind streak (a thin tilted ring) whips round it. It swells toward
##   the burst (frame 16) and dies away over the rest.
## - The burst (burst(), on the rules' recallBurst event, hit or not): a
##   golden flare and a white core at the chest, a golden shockwave along the
##   ground out past the recalled weapon's reach with a white one inside it,
##   and a spray of golden sparks.
##
## MatchView feeds it every drawn frame and calls burst() from its events.

const GOLD: Color = Color(1.0, 0.76, 0.22)
const PALE_GOLD: Color = Color(1.0, 0.9, 0.55)
const WHITE: Color = Color(1.0, 0.98, 0.92)
## The flames: per rules frame at the aura's height, this many particles
## (fewer as it builds and dies away).
const FLAMES_PER_FRAME: int = 12
## How far round the body (m) the flames rise from.
const FLAME_RADIUS: float = 0.36
## A wind streak every this many rules frames.
const STREAK_EVERY: int = 3

## The last rules frame fed, per side (-1 for none).
var _fed: Dictionary[int, int] = {}


## How strong the aura is `sf` frames into the recall (0 to 1): building to
## the burst, then dying away.
static func strength(sf: int) -> float:
	var burst: float = float(SimConst.RECALL_BURST_FRAME)
	if sf <= SimConst.RECALL_BURST_FRAME:
		return lerpf(0.35, 1.0, smoothstep(0.0, burst, float(sf)))
	return 1.0 - smoothstep(burst, float(SimConst.RECALL_FRAMES), float(sf))


## Throws side `side`'s aura for fighter `f` for each rules frame it has
## stepped in its recall since the last call (none outside it).
func feed(effects: CombatEffects, side: int, f: Fighter) -> void:
	if f == null or f.world == null:
		return
	var frame: int = f.world.frame
	var last: int = _fed.get(side, -1)
	_fed[side] = frame
	if f.state != &"recall" or last < 0 or frame <= last:
		return
	for fr: int in range(maxi(last + 1, frame - f.sf), frame + 1):
		throw(effects, side, Vector3(f.pos.x, f.pos.y, f.pos.z), f.sf - (frame - fr), fr)


## One rules frame `fr` of the aura, `sf` frames into the recall, for a
## fighter standing at `at`.
static func throw(effects: CombatEffects, side: int, at: Vector3, sf: int, fr: int) -> void:
	var s: float = strength(sf)
	if s <= 0.0:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([side, fr, &"recall_aura"])
	var born: float = float(fr)
	var flames: int = maxi(1, roundi(FLAMES_PER_FRAME * s))
	for k: int in flames:
		var a: float = rng.randf() * TAU
		var up: float = rng.randf_range(0.05, 1.1)
		var from: Vector3 = at + Vector3(cos(a) * FLAME_RADIUS, up, sin(a) * FLAME_RADIUS)
		effects.burst(from, {
			"count": 1, "color": GOLD.lerp(PALE_GOLD, rng.randf()), "size": 0.34 * (0.6 + 0.4 * s), "size_end": 0.04,
			"life": 22, "life_jitter": 0.3, "speed": 2.0 + 2.2 * s, "dir": Vector3(cos(a) * 0.15, 1.0, sin(a) * 0.15), "spread": 10.0,
			"gravity": -5.0,
		}, born, rng.randi())
	if fr % 2 == 0:
		effects.flash(at + Vector3(0.0, 1.0, 0.0), Color(GOLD, 0.75 * s), 1.4 + 0.9 * s, 8, born)
	if fr % STREAK_EVERY == 0:
		var tilt: float = rng.randf() * TAU
		var normal: Vector3 = Vector3(cos(tilt) * 0.55, 1.0, sin(tilt) * 0.55)
		effects.ring(at + Vector3(0.0, rng.randf_range(0.4, 1.3), 0.0), Color(WHITE, 0.85 * s), 0.3, 0.7 + 0.3 * s, 9, born, 0.05, normal)


## The burst for the rules' recallBurst event `e` on world frame `frame`.
static func burst(effects: CombatEffects, e: Dictionary, frame: int) -> void:
	var p: Dictionary = e["pos"]
	var chest: Vector3 = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
	var ground: Vector3 = Vector3(chest.x, 0.04, chest.z)
	var reach: float = float(e.get("reach", 2.5))
	var born: float = float(frame)
	effects.flash(chest, GOLD, 2.8, 24, born)
	effects.flash(chest, WHITE, 1.4, 10, born)
	effects.ring(ground, GOLD, 0.3, reach + 0.5, 18, born, 0.14, Vector3.UP)
	effects.ring(ground, WHITE, 0.2, reach * 0.8, 12, born, 0.08, Vector3.UP)
	effects.ring(chest, Color(WHITE, 0.8), 0.4, 1.6, 10, born, 0.06)
	effects.burst(chest, {
		"count": 44, "color": GOLD, "size": 0.16, "size_end": 0.02, "life": 24, "life_jitter": 0.5,
		"speed": 7.0, "speed_jitter": 0.4, "gravity": 6.0, "floor": 0.02,
	}, born, hash([frame, &"recall_burst"]))


## Forgets what was fed (a new round, a new match).
func clear() -> void:
	_fed.clear()
