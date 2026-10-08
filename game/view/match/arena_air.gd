class_name ArenaAir
extends RefCounted
## What the fight blows across an arena (milestone-1 task 115; the owner's
## answer of Oct 8): the grass near a swing, a step or a fall bends away and
## springs back over about a second, and the banners billow through the one
## wind (Wind, task 52) from the big pushes: the ultimates, Moonsplitter's
## wave and a K.O. fall near the wall. It takes each drawn frame's FloorStir
## (its pushes, sweeps, bursts and wave fronts) and keeps them in the global
## air_pushes texture that air_push.gdshaderinc reads (in surface_sway, the
## grass's and banners' shader), each marked with when it was made on the
## wind's clock (Wind.time):
## - the latest SLOTS pushes, a push within SPACING of its radius and GAP
##   seconds of a newer one adding nothing, so a walk leaves a trail of
##   pushes rather than one a frame; strengths become m/s of wind
##   (AIR_SPEED for each of FloorStir's units, a walk's 1);
## - up to WAVES of Moonsplitter's waves, each held from its launch to LIFE
##   after it has flown its range, the shader sweeping its front across the
##   grass.
## A push's reach through the air (FloorStir.Push.air) is what lets the big
## ones reach the banners. The texture lists the live pushes first and how
## many there are (row 3, texel WAVES), so the grass's shader stops at the
## last, and it's rewritten only when something changed. Picture only.

const GLOBAL: StringName = &"air_pushes"
## Slots (AIR_SLOTS and AIR_WAVES in air_push.gdshaderinc).
const SLOTS: int = 32
const WAVES: int = 2
## How long a push lasts after it's made, or a wave after it's flown (s;
## AIR_LIFE).
const LIFE: float = 1.4
const SPACING: float = 0.5
const GAP: float = 0.12
## m/s of wind for each unit of FloorStir's strength.
const AIR_SPEED: float = 1.5
## A sweep pushes round its blade's tip, this far (m), this hard.
const SWEEP_RADIUS: float = 0.7
const SWEEP_STRENGTH: float = 1.2
## A moving push under this speed (m/s) pushes nothing: standing about.
const STILL: float = 0.3
## A wave's strength (m/s of wind).
const WAVE_STRENGTH: float = 4.5

## Each push: [x, z, radius, strength, made, vx, vz, air radius].
var _slots: Array[PackedFloat32Array] = []
## Each wave: [ox, oz, dx, dz, launched, speed, horizontal, strength, until],
## and which front it follows.
var _waves: Array[PackedFloat32Array] = []
var _wave_keys: Array[String] = []
var _image: Image
var texture: ImageTexture
## Whether the texture still shows something live (a push or a wave), so a
## quiet frame after it needs one more write to clear it.
var _shown: bool = false


func _init() -> void:
	_image = Image.create(SLOTS, 4, false, Image.FORMAT_RGBAF)
	_image.fill(Color(0, 0, 0, 0))
	texture = ImageTexture.create_from_image(_image)
	for i: int in SLOTS:
		_slots.append(PackedFloat32Array([0, 0, 0, 0, -1e9, 0, 0, 0]))
	for k: int in WAVES:
		_waves.append(PackedFloat32Array([0, 0, 0, 0, -1e9, 0, 0, 0, -1e9]))
		_wave_keys.append("")


## Hands the texture to the shaders.
func apply() -> void:
	RenderingServer.global_shader_parameter_set(GLOBAL, texture)


## Takes a frame's stir at `now` (the wind's clock, s).
func take(stir: FloorStir, now: float) -> void:
	var changed: bool = not stir.fronts.is_empty()
	for b: FloorStir.Push in stir.bursts:
		changed = _add(b.at, b.radius, b.strength, now, Vector3.ZERO, b.air, true) or changed
	for p: FloorStir.Push in stir.pushes:
		var speed: float = Vector2(p.velocity.x, p.velocity.z).length()
		if speed >= STILL:
			changed = _add(p.at, p.radius, p.strength * minf(1.0, speed / 3.0), now, p.velocity, p.air, false) or changed
	for s: FloorStir.Sweep in stir.sweeps:
		changed = _add(Vector3(s.b.x, 0.0, s.b.z), SWEEP_RADIUS, SWEEP_STRENGTH, now, s.vb, SWEEP_RADIUS, false) or changed
	for f: FloorStir.Front in stir.fronts:
		_follow(f, now)
	if changed or _shown:
		_write(now)


## Every slot empty (a new match).
func clear() -> void:
	for s: PackedFloat32Array in _slots:
		s[3] = 0.0
		s[4] = -1e9
	for k: int in WAVES:
		_waves[k][7] = 0.0
		_waves[k][8] = -1e9
		_wave_keys[k] = ""
	_write(0.0)


## The pushes alive at `now`: [{at, radius, strength (m/s), air}], for tests.
func alive(now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: PackedFloat32Array in _slots:
		if s[3] > 0.0 and now - s[4] <= LIFE:
			out.append({"at": Vector3(s[0], 0.0, s[1]), "radius": s[2], "strength": s[3], "air": s[7]})
	return out


## The waves held at `now`: [{origin, ahead, launched, horizontal}], for tests.
func waves(now: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: PackedFloat32Array in _waves:
		if w[7] > 0.0 and now <= w[8]:
			out.append({"origin": Vector3(w[0], 0.0, w[1]), "ahead": Vector3(w[2], 0.0, w[3]), "launched": w[4], "horizontal": w[6] > 0.5})
	return out


## Whether it took the push.
func _add(at: Vector3, radius: float, strength: float, now: float, velocity: Vector3, air: float, always: bool) -> bool:
	if not always:
		for s: PackedFloat32Array in _slots:
			if s[3] > 0.0 and now - s[4] < GAP and Vector2(s[0] - at.x, s[1] - at.z).length() < SPACING * maxf(radius, s[2]):
				return false
	var slot: PackedFloat32Array = _slots[_free(now)]
	slot[0] = at.x
	slot[1] = at.z
	slot[2] = radius
	slot[3] = strength * AIR_SPEED
	slot[4] = now
	slot[5] = velocity.x
	slot[6] = velocity.z
	slot[7] = maxf(air, radius)
	return true


## An empty or spent slot, else the oldest.
func _free(now: float) -> int:
	var best: int = 0
	for i: int in SLOTS:
		if _slots[i][3] <= 0.0 or now - _slots[i][4] > LIFE:
			return i
		if _slots[i][4] < _slots[best][4]:
			best = i
	return best


## A wave's front this frame: its slot (a new one at launch) keeps its front
## where the rules have it.
func _follow(f: FloorStir.Front, now: float) -> void:
	var key: String = "%.3f %.3f %.3f %.3f %s" % [f.origin.x, f.origin.z, f.ahead.x, f.ahead.z, f.kind]
	var k: int = _wave_keys.find(key)
	if k < 0:
		k = 0
		for j: int in WAVES:
			if now > _waves[j][8]:
				k = j
				break
			if _waves[j][4] < _waves[k][4]:
				k = j
		_wave_keys[k] = key
	var w: PackedFloat32Array = _waves[k]
	var speed: float = World.WAVE_SPEED
	w[0] = f.origin.x
	w[1] = f.origin.z
	w[2] = f.ahead.x
	w[3] = f.ahead.z
	w[4] = now - f.s / speed
	w[5] = speed
	w[6] = 1.0 if f.kind == &"horizontal" else 0.0
	w[7] = WAVE_STRENGTH
	w[8] = w[4] + World.WAVE_RANGE / speed + LIFE


func _write(now: float) -> void:
	var live: int = 0
	for s: PackedFloat32Array in _slots:
		if s[3] > 0.0 and now - s[4] <= LIFE:
			_image.set_pixel(live, 0, Color(s[0], s[1], s[2], s[3]))
			_image.set_pixel(live, 1, Color(s[4], s[5], s[6], s[7]))
			live += 1
	for i: int in range(live, SLOTS):
		_image.set_pixel(i, 0, Color(0, 0, 0, 0))
	var waving: bool = false
	for k: int in WAVES:
		var w: PackedFloat32Array = _waves[k]
		var on: float = w[7] if now <= w[8] else 0.0
		waving = waving or on > 0.0
		_image.set_pixel(k, 2, Color(w[0], w[1], w[2], w[3]))
		_image.set_pixel(k, 3, Color(w[4], w[5], w[6], on))
	_image.set_pixel(WAVES, 3, Color(live, 0, 0, 0))
	texture.update(_image)
	_shown = live > 0 or waving
