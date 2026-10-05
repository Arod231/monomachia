class_name CombatEffects
extends Node3D
## The match's combat effects (plan task 18): glow flashes, rings and
## particles, each drawn from a fixed pool (one MultiMesh per kind), so an
## effect never adds a node, and a match leaves nothing behind.
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
## Particle counts follow the graphics preset, dropping at most by half on
## Low so hits still read (set_preset()).
##
## It also keeps the blades' brush-stroke trails (WeaponTrail), one per side
## and hand, fed by MatchView every drawn frame (feed_trail()) and aged on
## the same clock.

## The pools, by name, for drawn().
const FLASHES: StringName = &"Flashes"
const RINGS: StringName = &"Rings"
const PARTICLES: StringName = &"Particles"

## How many of each the pools hold; past that, the oldest go.
const FLASH_CAPACITY: int = 64
const RING_CAPACITY: int = 32
const PARTICLE_CAPACITY: int = 1200
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

const GLOW_SHADER: Shader = preload("res://shaders/particle_glow.gdshader")
const RING_SHADER: Shader = preload("res://shaders/effect_ring.gdshader")

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


## The host whose clock the effects keep (MatchView sets it).
var host: MatchHost
## The share of each burst's particles drawn (set_preset()).
var particle_scale: float = 1.0
## Multiplies how bright flashes and rings are (18.11's reduce flashes).
var flash_scale: float = 1.0
## The clock at the last update().
var now: float = 0.0

var _flashes: Array[Fx] = []
var _rings: Array[Fx] = []
var _particles: Array[Particle] = []
## The blades' trails: side * 2 + hand (TrailState.RIGHT or LEFT).
var trails: Array[WeaponTrail] = []
var _pools: Dictionary[StringName, MultiMeshInstance3D] = {}
var _buffers: Dictionary[StringName, PackedFloat32Array] = {}


func _init() -> void:
	name = "Effects"
	_add_pool(FLASHES, FLASH_CAPACITY, _glow_material(FLASH_ENERGY), false)
	_add_pool(RINGS, RING_CAPACITY, _ring_material(), true)
	_add_pool(PARTICLES, PARTICLE_CAPACITY, _glow_material(PARTICLE_ENERGY), false)
	for side: int in 2:
		for hand: String in ["R", "L"]:
			var trail: WeaponTrail = WeaponTrail.new()
			trail.name = "Trail%d%s" % [side, hand]
			add_child(trail)
			trails.append(trail)


# ------------------------------------------------------------------ clock and preset

## The world frame on show: the frame before the host's last step plus its
## alpha (held at 1 through hit-stop), or the last update's clock when there
## is no match.
func clock() -> float:
	if host == null or not host.is_started() or host.world == null:
		return now
	return float(host.world.frame) - 1.0 + host.alpha()


## Takes a graphics preset's particle ratio, at least MIN_PARTICLE_SCALE.
func set_preset(preset: GraphicsPreset) -> void:
	particle_scale = maxf(preset.particle_ratio, MIN_PARTICLE_SCALE) if preset != null else 1.0


## How many particles a burst of `count` draws at the current preset: at
## least one.
func scaled_count(count: int) -> int:
	return maxi(1, roundi(float(count) * particle_scale)) if count > 0 else 0


# ------------------------------------------------------------------ spawning

## Spawns the table's effects for rules event `e` at its "pos", born on world
## frame `frame` (the frame the event happened on). An event without a
## contact point spawns nothing.
func on_event(e: Dictionary, frame: int) -> void:
	var p: Variant = e.get("pos", null)
	if not p is Dictionary:
		return
	var at: Vector3 = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
	for fx: Dictionary in EffectTable.resolve(e):
		match fx["kind"]:
			EffectTable.FLASH:
				flash(at, fx["color"], fx["size"], fx["life"], float(frame))


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


## Lays down side `side`'s blade in hand `hand` (TrailState.RIGHT or
## LEFT) for its trail at clock `t`: the trailing span from `inner` to
## `tip`, with TrailState's strength and kind.
func feed_trail(side: int, hand: int, t: float, inner: Vector3, tip: Vector3, strength: float, kind: StringName) -> void:
	trails[side * 2 + hand].feed(t, inner, tip, strength, kind)


## The trail of side `side`'s hand `hand`.
func trail(side: int, hand: int) -> WeaponTrail:
	return trails[side * 2 + hand]


## Removes every effect (round start, a new match).
func clear() -> void:
	for tr: WeaponTrail in trails:
		tr.clear()
	_flashes.clear()
	_rings.clear()
	_particles.clear()
	for pool: StringName in _pools:
		_pools[pool].multimesh.visible_instance_count = 0


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

	for tr: WeaponTrail in trails:
		tr.update(t)


## How many instances a pool draws now.
func drawn(pool: StringName) -> int:
	return _pools[pool].multimesh.visible_instance_count


func flash_count() -> int:
	return _flashes.size()


func ring_count() -> int:
	return _rings.size()


func particle_count() -> int:
	return _particles.size()


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


## Particle i at the last update: "pos", "size", "color" (its alpha the
## fade), "born".
func particle_state(i: int) -> Dictionary:
	var p: Particle = _particles[i]
	var age: float = maxf(0.0, now - p.born)
	var k: float = clampf(age / p.life, 0.0, 1.0)
	var c: Color = p.color
	c.a *= 1.0 - k * k
	return {"pos": p.pos_at(age * SimConst.DT), "size": lerpf(p.size, p.size_end, k), "color": c, "born": p.born}


# ------------------------------------------------------------------ inside

func _progress(born: float, life: float) -> float:
	return clampf(maxf(0.0, now - born) / life, 0.0, 1.0)


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


static func _ring_material() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = RING_SHADER
	m.set_shader_parameter(&"energy", RING_ENERGY)
	return m
