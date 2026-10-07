class_name CombatEffects
extends Node3D
## The match's combat effects (plan task 18; milestone-1 task 37): glow
## flashes, rings, particles, sparks and puffs, each drawn from a fixed pool
## (one MultiMesh per kind), and the sparks' contact lights from a small
## fixed set, so an effect never adds a node, and a match leaves nothing
## behind.
##
## Every effect is timed on the effect clock (clock()): the world frame on
## show, which is the frame before the last step plus the host's alpha. It
## stands still through hit-stop and pause and runs at 0.3x in the KO's slow
## motion, as the fighters do, and it is smooth between steps on a fast
## display. An effect's age is the clock minus the frame it was born on, and
## everything about it (size, fade, where a particle has flown) is worked out
## from its age, never stepped, so a shot taken at a given frame always looks
## the same.
##
## MatchView owns one, spawns the event table's effects (EffectTable) from
## on_event(), updates it every drawn frame and clears it at round start.
## Particle and spark counts follow the graphics preset, dropping at most by
## half on Low so contact still reads, and the contact lights show only where
## the preset allows them (GraphicsPreset.spark_light: Ultra and High)
## (set_preset()). Reduce flashes (18.11) dims the flashes, rings and sparks
## (flash_scale) and halves the lights (light_scale); the ultimates' own
## flashes (UltEffects, RecallAura; milestone-1 task 100) are slowed too,
## living flash_slow times as long.
##
## A distortion ring (milestone-1 task 100: Breaker Palm's blow, the recall's
## burst) is a ring that bends the scene behind it as it widens, like a
## shockwave in the air (shaders/effect_distortion.gdshader), from its own
## pool.
##
## Sparks (milestone-1 task 37) are hot streaks thrown from a contact, falling
## under gravity and dying on the floor, drawn along their flight
## (shaders/spark_streak.gdshader) and cooling from white-yellow through
## orange to red as they age. Puffs are a bare hand's dull cloud of dust and
## cloth (shaders/effect_puff.gdshader). A contact light is a warm omni light
## at the contact that fades over a few frames, lighting both fighters and
## the blades.
##
## It also keeps the blades' air smears (AirSmear), one per side and hand,
## fed by MatchView every drawn frame (feed_smear()) and aged on the same
## clock.

## The pools, by name, for drawn().
const FLASHES: StringName = &"Flashes"
const RINGS: StringName = &"Rings"
const PARTICLES: StringName = &"Particles"
const SPARKS: StringName = &"Sparks"
const PUFFS: StringName = &"Puffs"
const DISTORTIONS: StringName = &"Distortions"

## How many of each the pools hold; past that, the oldest go.
const FLASH_CAPACITY: int = 64
const RING_CAPACITY: int = 32
const PARTICLE_CAPACITY: int = 1200
const SPARK_CAPACITY: int = 400
const PUFF_CAPACITY: int = 64
const DISTORTION_CAPACITY: int = 8
## The contact lights: few, since a light costs every surface it touches.
const LIGHT_CAPACITY: int = 3
## The least share of a burst's particles a preset draws (Low's ambient
## ratio is 0.3; combat particles keep at least half).
const MIN_PARTICLE_SCALE: float = 0.5
## A flash's sprite is this many times its size across: the glow's soft halo
## needs the room for its bright core to match the size.
const FLASH_SPRITE: float = 1.6
## How bright the glow shaders draw each kind.
const FLASH_ENERGY: float = 1.6
const RING_ENERGY: float = 2.0
const PARTICLE_ENERGY: float = 2.5
const SPARK_ENERGY: float = 9.0

## Sparks fall at this (m/s²) and land on the floor (y 0), where they die
## within SPARK_FLOOR_LIFE frames.
const SPARK_GRAVITY: float = 9.8
const SPARK_FLOOR_LIFE: float = 5.0
## A spark's streak is as long as it flies in this long (s), a short
## exposure's smear, and never under its width.
const SPARK_EXPOSURE: float = 0.022
const SPARK_WIDTH: float = 0.012
## Frames a spark has flown when it is first shown: the effect clock stands
## still through the contact's hit-stop, so the frozen frame shows the burst
## already leaving the steel, not a knot at the contact.
const SPARK_HEAD_START: float = 1.5
## A spark's heat as it ages: white-yellow, orange, then a dull red.
const SPARK_HOT: Color = Color(1.0, 0.84, 0.5)
const SPARK_WARM: Color = Color(1.0, 0.5, 0.14)
const SPARK_COOL: Color = Color(0.7, 0.16, 0.05)
## A puff's dust: a dull grey-brown that the night's tone dims.
const PUFF_COLOR: Color = Color(0.42, 0.39, 0.35, 0.8)
## How much a puff grows across over its life, and how fast it drifts (m/s).
const PUFF_GROWTH: float = 2.4
const PUFF_SPEED: float = 0.45
## How much of a contact light Reduce flashes leaves.
const REDUCED_LIGHT: float = 0.5
## Under Reduce flashes the ultimates' flashes live this many times as long
## (flash_slow), so they swell and fade gently.
const REDUCED_SLOW: float = 1.6

const GLOW_SHADER: Shader = preload("res://shaders/particle_glow.gdshader")
const RING_SHADER: Shader = preload("res://shaders/effect_ring.gdshader")
const SPARK_SHADER: Shader = preload("res://shaders/spark_streak.gdshader")
const PUFF_SHADER: Shader = preload("res://shaders/effect_puff.gdshader")
const DISTORTION_SHADER: Shader = preload("res://shaders/effect_distortion.gdshader")

## Floats per instance in a pool's buffer: a 3x4 transform, a colour, and
## for rings the custom data (facing the camera, band width).
const _XFORM: int = 12
const _COLOR: int = 4
const _CUSTOM: int = 4


## A flash or a ring, timed in world frames on the effect clock.
class Fx:
	var born: float = 0.0
	var life: float = 1.0
	var at: Vector3 = Vector3.ZERO
	var color: Color = Color.WHITE
	## A flash's size; a ring's radius at birth and at the end.
	var size: float = 1.0
	var size_end: float = 1.0
	## A ring's band, as a share of its radius.
	var band: float = 0.15
	## A ring's normal; zero to face the camera.
	var normal: Vector3 = Vector3.ZERO


## One particle: thrown from p0 at v (m/s), falling at `gravity` (m/s²)
## until it lands at floor_y (if it can), then lying there.
class Particle:
	var born: float = 0.0
	var life: float = 1.0
	var p0: Vector3 = Vector3.ZERO
	var v: Vector3 = Vector3.ZERO
	var gravity: float = 0.0
	var floor_y: float = -INF
	## Seconds after birth that it lands, or INF.
	var t_land: float = INF
	var size: float = 0.05
	var size_end: float = 0.0
	var color: Color = Color.WHITE

	func pos_at(seconds: float) -> Vector3:
		var t: float = minf(seconds, t_land)
		var p: Vector3 = p0 + v * t + Vector3(0.0, -0.5 * gravity * t * t, 0.0)
		if seconds >= t_land:
			p.y = floor_y
		return p


## A contact light, timed in world frames on the effect clock: its energy
## fades with the square of what is left of its life.
class ContactLight:
	var born: float = 0.0
	var life: float = 1.0
	var at: Vector3 = Vector3.ZERO
	var energy: float = 1.0
	var reach: float = 2.5


## The host whose clock the effects keep (MatchView sets it).
var host: MatchHost
## The share of each burst's particles drawn (set_preset()).
var particle_scale: float = 1.0
## Multiplies how bright flashes, rings and sparks are (18.11's reduce
## flashes).
var flash_scale: float = 1.0
## Multiplies how bright the contact lights are (REDUCED_LIGHT under reduce
## flashes).
var light_scale: float = 1.0
## How many times as long the ultimates' flashes live (REDUCED_SLOW under
## Reduce flashes; MatchView sets it).
var flash_slow: float = 1.0
## Whether contact lights show (the preset's spark_light).
var lights_allowed: bool = true
## The clock at the last update().
var now: float = 0.0

var _flashes: Array[Fx] = []
var _rings: Array[Fx] = []
var _particles: Array[Particle] = []
var _sparks: Array[Particle] = []
var _puffs: Array[Particle] = []
var _distortions: Array[Fx] = []
var _lights: Array[ContactLight] = []
## The blades' air smears: side * 2 + hand (TrailState.RIGHT or LEFT).
var smears: Array[AirSmear] = []
## The contact lights' nodes; the newest light shows in the first.
var _light_nodes: Array[OmniLight3D] = []
var _pools: Dictionary[StringName, MultiMeshInstance3D] = {}
var _buffers: Dictionary[StringName, PackedFloat32Array] = {}


func _init() -> void:
	name = "Effects"
	_add_pool(FLASHES, FLASH_CAPACITY, _glow_material(FLASH_ENERGY), false)
	_add_pool(RINGS, RING_CAPACITY, _ring_material(), true)
	_add_pool(PARTICLES, PARTICLE_CAPACITY, _glow_material(PARTICLE_ENERGY), false)
	_add_pool(SPARKS, SPARK_CAPACITY, _shader_material(SPARK_SHADER, SPARK_ENERGY), false)
	_add_pool(PUFFS, PUFF_CAPACITY, _shader_material(PUFF_SHADER, -1.0), false)
	_add_pool(DISTORTIONS, DISTORTION_CAPACITY, _shader_material(DISTORTION_SHADER, -1.0), true)
	for k: int in LIGHT_CAPACITY:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "ContactLight%d" % k
		light.light_color = EffectTable.SPARK_LIGHT
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.0
		light.omni_attenuation = 2.0
		light.visible = false
		add_child(light)
		_light_nodes.append(light)
	for side: int in 2:
		for hand: String in ["R", "L"]:
			var smear: AirSmear = AirSmear.new()
			smear.name = "Smear%d%s" % [side, hand]
			add_child(smear)
			smears.append(smear)


# ------------------------------------------------------------------ clock and preset

## The world frame on show: the frame before the host's last step plus its
## alpha (held at 1 through hit-stop), or the last update's clock when there
## is no match.
func clock() -> float:
	if host == null or not host.is_started() or host.world == null:
		return now
	return float(host.world.frame) - 1.0 + host.alpha()


## Takes a graphics preset's particle ratio, at least MIN_PARTICLE_SCALE,
## and whether it allows the contact lights.
func set_preset(preset: GraphicsPreset) -> void:
	particle_scale = maxf(preset.particle_ratio, MIN_PARTICLE_SCALE) if preset != null else 1.0
	lights_allowed = preset.spark_light if preset != null else true


## How many particles a burst of `count` draws at the current preset: at
## least one.
func scaled_count(count: int) -> int:
	return maxi(1, roundi(float(count) * particle_scale)) if count > 0 else 0


# ------------------------------------------------------------------ spawning

## Spawns the table's effects for rules event `e` at its "pos", born on world
## frame `frame` (the frame the event happened on). An event without a
## contact point spawns nothing. Sparks and puffs are scattered by the
## event's frame, so the same contact always throws them the same way.
func on_event(e: Dictionary, frame: int) -> void:
	var p: Variant = e.get("pos", null)
	if not p is Dictionary:
		return
	var at: Vector3 = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
	for fx: Dictionary in EffectTable.resolve(e):
		match fx["kind"]:
			EffectTable.FLASH:
				flash(at, fx["color"], fx["size"], fx["life"], float(frame))
			EffectTable.SPARKS:
				sparks(at, spark_aim(e, fx["aim"], at), fx, float(frame), frame * 7919 + 1)
			EffectTable.PUFF:
				puff(at, fx, float(frame), frame * 104729 + 3)
			EffectTable.LIGHT:
				contact_light(at, fx["energy"], fx["range"], fx["life"], float(frame))


## Which way a spark burst for event `e` at `at` flies (unit): along the
## parried blade's sweep (the event's "dir") for AIM_SWEEP, else off the
## defender's guard (the event's "target") toward the attacker; tipped up a
## little either way, as sparks leap off the steel. Up when neither can be
## found.
func spark_aim(e: Dictionary, aim: StringName, at: Vector3) -> Vector3:
	var d: Vector3 = Vector3.ZERO
	if aim == EffectTable.AIM_SWEEP and e.get("dir", null) is Dictionary:
		var s: Dictionary = e["dir"]
		d = Vector3(float(s["x"]), float(s["y"]), float(s["z"]))
	elif host != null and host.is_started() and e.has("target"):
		var target: int = int(e["target"])
		if target == 0 or target == 1:
			var f: Fighter = host.fighter(target)
			d = Vector3(at.x - f.pos.x, 0.0, at.z - f.pos.z)
	if d.length() < 1e-6:
		return Vector3.UP
	return (d.normalized() + Vector3(0.0, 0.6, 0.0)).normalized()


## A glow at `at` that grows from 0.55 to 1.3 times `size` across while it
## fades, over `life` frames from `born`.
func flash(at: Vector3, color: Color, size: float, life: int, born: float) -> void:
	var fx: Fx = Fx.new()
	fx.at = at
	fx.color = color
	fx.size = size
	fx.life = float(maxi(1, life))
	fx.born = born
	_push(_flashes, fx, FLASH_CAPACITY)


## A ring at `at` widening from radius r0 to r1 over `life` frames from
## `born`, its band `band` of its radius. With a zero `normal` it faces the
## camera; otherwise it lies square to the normal (Vector3.UP: flat on the
## ground).
func ring(at: Vector3, color: Color, r0: float, r1: float, life: int, born: float,
		band: float = 0.15, normal: Vector3 = Vector3.ZERO) -> void:
	var fx: Fx = Fx.new()
	fx.at = at
	fx.color = color
	fx.size = r0
	fx.size_end = r1
	fx.band = band
	fx.normal = normal.normalized()
	fx.life = float(maxi(1, life))
	fx.born = born
	_push(_rings, fx, RING_CAPACITY)


## A ring of distortion at `at` widening from radius r0 to r1 over `life`
## frames from `born`, bending the scene behind its band (`band` of its
## radius) by `strength` (0 to 1) as it goes; flat to `normal`, or facing
## the camera for none.
func distortion(at: Vector3, r0: float, r1: float, life: int, born: float, strength: float = 1.0,
		band: float = 0.3, normal: Vector3 = Vector3.ZERO) -> void:
	var fx: Fx = Fx.new()
	fx.at = at
	fx.color = Color(1.0, 1.0, 1.0, clampf(strength, 0.0, 1.0))
	fx.size = r0
	fx.size_end = r1
	fx.band = band
	fx.normal = normal.normalized()
	fx.life = float(maxi(1, life))
	fx.born = born
	_push(_distortions, fx, DISTORTION_CAPACITY)


## Throws a burst of particles from `at`, born on `born`, scattered by
## `seed` (the same seed scatters them the same way). `spec`:
## - "count": before the preset's scale (scaled_count());
## - "color", "size" (m across) and "size_end" (default a third of size);
## - "life" in frames, and "life_jitter", a share of it taken off at random
##   (default 0.4);
## - "speed" in m/s and "speed_jitter", a share of it either way (default
##   0.5);
## - "dir" and "spread" (degrees from dir; default no dir, every way);
## - "gravity" in m/s² (default 0) and "floor", the height it lands at
##   (default none).
## Returns how many were thrown.
func burst(at: Vector3, spec: Dictionary, born: float, seed: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var n: int = scaled_count(int(spec.get("count", 0)))
	var size: float = float(spec.get("size", 0.05))
	var life: float = float(spec.get("life", 20))
	var life_jitter: float = float(spec.get("life_jitter", 0.4))
	var speed: float = float(spec.get("speed", 1.0))
	var speed_jitter: float = float(spec.get("speed_jitter", 0.5))
	var dir: Vector3 = (spec.get("dir", Vector3.ZERO) as Vector3).normalized()
	var spread: float = deg_to_rad(float(spec.get("spread", 180.0)))
	var gravity: float = float(spec.get("gravity", 0.0))
	var floor_y: float = float(spec.get("floor", -INF))
	for k: int in n:
		var p: Particle = Particle.new()
		p.born = born
		p.life = maxf(1.0, life * (1.0 - life_jitter * rng.randf()))
		p.p0 = at
		p.v = _scatter(rng, dir, spread) * speed * (1.0 + speed_jitter * rng.randf_range(-1.0, 1.0))
		p.gravity = gravity
		p.floor_y = floor_y
		p.t_land = _landing(p)
		p.size = size
		p.size_end = float(spec.get("size_end", size / 3.0))
		p.color = spec.get("color", Color.WHITE)
		_push(_particles, p, PARTICLE_CAPACITY)
	return n


## Throws a burst of sparks from `at` toward `dir` (unit; zero for every
## way), born on `born`, scattered by `seed` (the same seed throws them the
## same way). `spec` (EffectTable's sparks): "count" before the preset's
## scale, "speed" (m/s, each up to half either way), "spread" (degrees from
## dir), "life" in frames (each up to 40% less). They fall at SPARK_GRAVITY
## and die on the floor within SPARK_FLOOR_LIFE frames. Returns how many
## were thrown.
func sparks(at: Vector3, dir: Vector3, spec: Dictionary, born: float, seed: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var n: int = scaled_count(int(spec.get("count", 0)))
	var speed: float = float(spec.get("speed", 4.0))
	var life: float = float(spec.get("life", 14))
	var spread: float = deg_to_rad(float(spec.get("spread", 60.0)))
	for k: int in n:
		var p: Particle = Particle.new()
		p.born = born
		p.life = maxf(1.0, life * (1.0 - 0.4 * rng.randf()))
		p.p0 = at
		p.v = _scatter(rng, dir, spread) * speed * (1.0 + 0.5 * rng.randf_range(-1.0, 1.0))
		p.gravity = SPARK_GRAVITY
		p.floor_y = 0.0
		p.t_land = _landing(p)
		if p.t_land < INF:
			p.life = minf(p.life, p.t_land / SimConst.DT + SPARK_FLOOR_LIFE)
		p.size = SPARK_WIDTH
		p.color = SPARK_HOT
		_push(_sparks, p, SPARK_CAPACITY)
	return n


## A puff of dust and cloth at `at`, born on `born`, scattered by `seed`:
## "count" soft clouds (before the preset's scale) of about "size" across,
## drifting slowly out and up, growing and thinning out over "life" frames.
## Returns how many.
func puff(at: Vector3, spec: Dictionary, born: float, seed: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var n: int = scaled_count(int(spec.get("count", 0)))
	var size: float = float(spec.get("size", 0.16))
	var life: float = float(spec.get("life", 22))
	for k: int in n:
		var p: Particle = Particle.new()
		p.born = born
		p.life = maxf(1.0, life * (1.0 - 0.3 * rng.randf()))
		p.p0 = at
		p.v = (_scatter(rng, Vector3.ZERO, PI) + Vector3(0.0, 0.4, 0.0)) * PUFF_SPEED * rng.randf_range(0.5, 1.0)
		p.size = size * rng.randf_range(0.7, 1.0)
		p.size_end = p.size * PUFF_GROWTH
		p.color = PUFF_COLOR
		_push(_puffs, p, PUFF_CAPACITY)
	return n


## A warm light at `at` from `born`, `energy` at its peak and reaching
## `reach` metres, fading over `life` frames. The newest takes the oldest's
## place past LIGHT_CAPACITY.
func contact_light(at: Vector3, energy: float, reach: float, life: int, born: float) -> void:
	var l: ContactLight = ContactLight.new()
	l.at = at
	l.energy = energy
	l.reach = reach
	l.life = float(maxi(1, life))
	l.born = born
	_push(_lights, l, LIGHT_CAPACITY)


## Lays down side `side`'s blade in hand `hand` (TrailState.RIGHT or
## LEFT) for its air smear at clock `t`: the smearing span from `inner` to
## `tip` (AirSmear.span()), with TrailState's strength and kind.
func feed_smear(side: int, hand: int, t: float, inner: Vector3, tip: Vector3, strength: float, kind: StringName) -> void:
	smears[side * 2 + hand].feed(t, inner, tip, strength, kind)


## The air smear of side `side`'s hand `hand`.
func smear(side: int, hand: int) -> AirSmear:
	return smears[side * 2 + hand]


## Removes every effect (round start, a new match).
func clear() -> void:
	for sm: AirSmear in smears:
		sm.clear()
	_flashes.clear()
	_rings.clear()
	_particles.clear()
	_sparks.clear()
	_puffs.clear()
	_distortions.clear()
	_lights.clear()
	for pool: StringName in _pools:
		_pools[pool].multimesh.visible_instance_count = 0
	for light: OmniLight3D in _light_nodes:
		light.visible = false


# ------------------------------------------------------------------ drawing

## Ages every effect to clock `t` (in world frames), drops the dead and
## writes the living into the pools.
func update(t: float) -> void:
	now = t
	_flashes = _alive(_flashes, t)
	_rings = _alive(_rings, t)
	var living: Array[Particle] = []
	for p: Particle in _particles:
		if t - p.born < p.life:
			living.append(p)
	_particles = living
	_sparks = _alive_particles(_sparks, t)
	_puffs = _alive_particles(_puffs, t)
	_distortions = _alive(_distortions, t)
	var lit: Array[ContactLight] = []
	for l: ContactLight in _lights:
		if t - l.born < l.life:
			lit.append(l)
	_lights = lit

	var buf: PackedFloat32Array = _buffers[FLASHES]
	for i: int in _flashes.size():
		var s: Dictionary = flash_state(i)
		var d: float = float(s["size"]) * FLASH_SPRITE
		_write(buf, i, 0, Basis.from_scale(Vector3(d, d, d)), s["pos"], _faded(s["color"], float(s["alpha"]) * flash_scale))
	_flush(FLASHES, _flashes.size())

	buf = _buffers[RINGS]
	var stride: int = _XFORM + _COLOR + _CUSTOM
	for i: int in _rings.size():
		var s: Dictionary = ring_state(i)
		var fx: Fx = _rings[i]
		var d: float = float(s["radius"]) * 2.0
		var basis: Basis = Basis.from_scale(Vector3(d, d, d))
		if not s["faces_camera"]:
			basis = _facing(fx.normal) * basis
		_write(buf, i, _CUSTOM, basis, s["pos"], _faded(s["color"], float(s["alpha"]) * flash_scale))
		buf[i * stride + _XFORM + _COLOR] = 1.0 if s["faces_camera"] else 0.0
		buf[i * stride + _XFORM + _COLOR + 1] = fx.band
	_flush(RINGS, _rings.size())

	buf = _buffers[PARTICLES]
	for i: int in _particles.size():
		var s: Dictionary = particle_state(i)
		var d: float = s["size"]
		_write(buf, i, 0, Basis.from_scale(Vector3(d, d, d)), s["pos"], s["color"])
	_flush(PARTICLES, _particles.size())

	buf = _buffers[SPARKS]
	for i: int in _sparks.size():
		var s: Dictionary = spark_state(i)
		var streak: Vector3 = s["streak"]
		var across: Vector3 = Vector3.UP if absf(streak.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		var w: float = s["width"]
		var basis: Basis = Basis(streak, across * w, streak.cross(across).normalized() * w)
		_write(buf, i, 0, basis, s["pos"], _faded(s["color"], flash_scale))
	_flush(SPARKS, _sparks.size())

	buf = _buffers[PUFFS]
	for i: int in _puffs.size():
		var s: Dictionary = puff_state(i)
		var d: float = s["size"]
		_write(buf, i, 0, Basis.from_scale(Vector3(d, d, d)), s["pos"], s["color"])
	_flush(PUFFS, _puffs.size())

	buf = _buffers[DISTORTIONS]
	for i: int in _distortions.size():
		var s: Dictionary = distortion_state(i)
		var fx: Fx = _distortions[i]
		var d: float = float(s["radius"]) * 2.0
		var basis: Basis = Basis.from_scale(Vector3(d, d, d))
		if not s["faces_camera"]:
			basis = _facing(fx.normal) * basis
		_write(buf, i, _CUSTOM, basis, s["pos"], Color(1.0, 1.0, 1.0, float(s["alpha"])))
		buf[i * stride + _XFORM + _COLOR] = 1.0 if s["faces_camera"] else 0.0
		buf[i * stride + _XFORM + _COLOR + 1] = fx.band
	_flush(DISTORTIONS, _distortions.size())

	for k: int in _light_nodes.size():
		var node: OmniLight3D = _light_nodes[k]
		var i: int = _lights.size() - 1 - k
		node.visible = lights_allowed and i >= 0
		if node.visible:
			var s: Dictionary = light_state(i)
			node.position = s["pos"]
			node.light_energy = s["energy"]
			node.omni_range = s["range"]

	for sm: AirSmear in smears:
		sm.update(t)


## How many instances a pool draws now.
func drawn(pool: StringName) -> int:
	return _pools[pool].multimesh.visible_instance_count


func flash_count() -> int:
	return _flashes.size()


func ring_count() -> int:
	return _rings.size()


func particle_count() -> int:
	return _particles.size()


func spark_count() -> int:
	return _sparks.size()


func puff_count() -> int:
	return _puffs.size()


func distortion_count() -> int:
	return _distortions.size()


func light_count() -> int:
	return _lights.size()


## How many contact lights show now (none where the preset allows none).
func lights_shown() -> int:
	var n: int = 0
	for light: OmniLight3D in _light_nodes:
		if light.visible:
			n += 1
	return n


## The contact lights' nodes, for checks.
func light_nodes() -> Array[OmniLight3D]:
	return _light_nodes


## Flash i at the last update: "pos", "size", "color", "alpha", "born".
func flash_state(i: int) -> Dictionary:
	var fx: Fx = _flashes[i]
	var k: float = _progress(fx.born, fx.life)
	return {
		"pos": fx.at, "size": fx.size * (0.55 + 0.75 * k), "color": fx.color,
		"alpha": 0.9 * (1.0 - k), "born": fx.born,
	}


## Ring i at the last update: "pos", "radius", "color", "alpha",
## "faces_camera", "born".
func ring_state(i: int) -> Dictionary:
	var fx: Fx = _rings[i]
	var k: float = _progress(fx.born, fx.life)
	var out: float = 1.0 - (1.0 - k) * (1.0 - k)
	return {
		"pos": fx.at, "radius": lerpf(fx.size, fx.size_end, out), "color": fx.color,
		"alpha": 1.0 - k, "faces_camera": fx.normal == Vector3.ZERO, "born": fx.born,
	}


## Distortion ring i at the last update: "pos", "radius", "alpha" (its
## strength, fading), "faces_camera", "born".
func distortion_state(i: int) -> Dictionary:
	var fx: Fx = _distortions[i]
	var k: float = _progress(fx.born, fx.life)
	var out: float = 1.0 - (1.0 - k) * (1.0 - k)
	return {
		"pos": fx.at, "radius": lerpf(fx.size, fx.size_end, out), "alpha": fx.color.a * (1.0 - k),
		"faces_camera": fx.normal == Vector3.ZERO, "born": fx.born,
	}


## Particle i at the last update: "pos", "size", "color" (its alpha the
## fade), "born".
func particle_state(i: int) -> Dictionary:
	var p: Particle = _particles[i]
	var age: float = maxf(0.0, now - p.born)
	var k: float = clampf(age / p.life, 0.0, 1.0)
	var c: Color = p.color
	c.a *= 1.0 - k * k
	return {"pos": p.pos_at(age * SimConst.DT), "size": lerpf(p.size, p.size_end, k), "color": c, "born": p.born}


## Spark i at the last update: "pos" (its streak's middle), "streak" (from
## its tail to its head along its flight, as long as it flies in
## SPARK_EXPOSURE and never under its width), "width", "color" (its heat as
## it cools, its alpha the fade), "landed", "born".
func spark_state(i: int) -> Dictionary:
	var p: Particle = _sparks[i]
	var age: float = maxf(0.0, now - p.born) + SPARK_HEAD_START
	var k: float = clampf(age / p.life, 0.0, 1.0)
	var seconds: float = age * SimConst.DT
	var landed: bool = seconds >= p.t_land
	var v: Vector3 = Vector3.ZERO if landed else p.v + Vector3(0.0, -p.gravity * seconds, 0.0)
	var streak: Vector3 = v * SPARK_EXPOSURE
	if streak.length() < p.size:
		streak = (v.normalized() if v.length() > 1e-6 else Vector3.RIGHT) * p.size
	var heat: Color = SPARK_HOT.lerp(SPARK_WARM, k * 2.0) if k < 0.5 else SPARK_WARM.lerp(SPARK_COOL, (k - 0.5) * 2.0)
	heat.a = 1.0 - k * k
	return {"pos": p.pos_at(seconds) - streak * 0.5, "streak": streak, "width": p.size, "color": heat,
		"landed": landed, "born": p.born}


## Puff i at the last update: "pos", "size", "color" (its alpha thinning
## out), "born".
func puff_state(i: int) -> Dictionary:
	var p: Particle = _puffs[i]
	var age: float = maxf(0.0, now - p.born)
	var k: float = clampf(age / p.life, 0.0, 1.0)
	var c: Color = p.color
	c.a *= (1.0 - k) * smoothstep(0.0, 0.1, k)
	# the cloud slows as it spreads
	var drift: float = (1.0 - (1.0 - k) * (1.0 - k)) * p.life * SimConst.DT * 0.5
	return {"pos": p.p0 + p.v * drift, "size": lerpf(p.size, p.size_end, sqrt(k)), "color": c, "born": p.born}


## Contact light i at the last update: "pos", "energy" (fading with the
## square of what is left of its life, times light_scale), "range", "born".
func light_state(i: int) -> Dictionary:
	var l: ContactLight = _lights[i]
	var k: float = _progress(l.born, l.life)
	return {"pos": l.at, "energy": l.energy * (1.0 - k) * (1.0 - k) * light_scale, "range": l.reach, "born": l.born}


# ------------------------------------------------------------------ inside

func _progress(born: float, life: float) -> float:
	return clampf(maxf(0.0, now - born) / life, 0.0, 1.0)


static func _alive_particles(list: Array[Particle], t: float) -> Array[Particle]:
	var out: Array[Particle] = []
	for p: Particle in list:
		if t - p.born < p.life:
			out.append(p)
	return out


static func _alive(list: Array[Fx], t: float) -> Array[Fx]:
	var out: Array[Fx] = []
	for fx: Fx in list:
		if t - fx.born < fx.life:
			out.append(fx)
	return out


## Appends to a pool's list, dropping its oldest past `capacity`.
static func _push(list: Array, item: Variant, capacity: int) -> void:
	list.append(item)
	if list.size() > capacity:
		list.remove_at(0)


## A direction within `spread` radians of `dir` (every way when dir is zero),
## spread evenly over the sphere's cap.
static func _scatter(rng: RandomNumberGenerator, dir: Vector3, spread: float) -> Vector3:
	var cos_max: float = cos(minf(spread, PI)) if dir != Vector3.ZERO else -1.0
	var z: float = rng.randf_range(cos_max, 1.0)
	var phi: float = rng.randf() * TAU
	var r: float = sqrt(maxf(0.0, 1.0 - z * z))
	var local: Vector3 = Vector3(r * cos(phi), r * sin(phi), z)
	if dir == Vector3.ZERO:
		return local
	return _facing(dir) * local


## A basis whose +Z is `n`.
static func _facing(n: Vector3) -> Basis:
	var up: Vector3 = Vector3.RIGHT if absf(n.dot(Vector3.UP)) > 0.99 else Vector3.UP
	return Basis.looking_at(-n, up)


## Seconds after birth that a falling particle reaches its floor, or INF.
static func _landing(p: Particle) -> float:
	if p.floor_y == -INF or p.gravity <= 0.0:
		return INF
	var h: float = p.p0.y - p.floor_y
	if h <= 0.0:
		return 0.0
	# p0.y + v.y t - g t² / 2 = floor_y
	var g: float = p.gravity
	return (p.v.y + sqrt(p.v.y * p.v.y + 2.0 * g * h)) / g


static func _faded(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)


func _write(buf: PackedFloat32Array, i: int, custom: int, basis: Basis, at: Vector3, color: Color) -> void:
	var o: int = i * (_XFORM + _COLOR + custom)
	buf[o] = basis.x.x
	buf[o + 1] = basis.y.x
	buf[o + 2] = basis.z.x
	buf[o + 3] = at.x
	buf[o + 4] = basis.x.y
	buf[o + 5] = basis.y.y
	buf[o + 6] = basis.z.y
	buf[o + 7] = at.y
	buf[o + 8] = basis.x.z
	buf[o + 9] = basis.y.z
	buf[o + 10] = basis.z.z
	buf[o + 11] = at.z
	buf[o + 12] = color.r
	buf[o + 13] = color.g
	buf[o + 14] = color.b
	buf[o + 15] = color.a


func _flush(pool: StringName, count: int) -> void:
	var mm: MultiMesh = _pools[pool].multimesh
	if count > 0:
		mm.buffer = _buffers[pool]
	mm.visible_instance_count = count


func _add_pool(pool: StringName, capacity: int, material: Material, custom: bool) -> void:
	var quad: QuadMesh = QuadMesh.new()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	# effects fly anywhere in the arena; skip culling them by a stale box
	mm.custom_aabb = AABB(Vector3(-40.0, -10.0, -40.0), Vector3(80.0, 40.0, 80.0))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = String(pool)
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_pools[pool] = mmi
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(capacity * (_XFORM + _COLOR + (_CUSTOM if custom else 0)))
	_buffers[pool] = buf


static func _glow_material(energy: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter(&"energy", energy)
	return m


## A material on `shader`, with its energy where `energy` is 0 or more.
static func _shader_material(shader: Shader, energy: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader
	if energy >= 0.0:
		m.set_shader_parameter(&"energy", energy)
	return m


static func _ring_material() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = RING_SHADER
	m.set_shader_parameter(&"energy", RING_ENERGY)
	return m
