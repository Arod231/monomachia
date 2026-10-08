class_name ShrineFallenPetals
extends MultiMeshInstance3D
## The Shrine's fallen petals (milestone-1 task 137; the owner's ask, Oct 7):
## glowing lavender petals fall from the wisteria's canopy into the arena on
## the wind, settle on the floor and stay, and the fighters push them about.
##
## - Falling: LAND_RATE petals a second (at the preset's full count) set off
##   under the canopy, FALL_FROM metres up and upwind, drifting down on the
##   layout's wind at a petal's fall speed (SINK, as the canopy's own
##   petals), fluttering and tumbling as they go, and land where they were
##   aimed: DRIFT_SHARE of them at the foot of the parapet (within
##   DRIFT_DEPTH, most of them downwind), JOINT_SHARE in the paving's ring
##   joints, the rest anywhere on the floor, so the cover builds to drifts
##   (the owner's choice, Oct 8: a light scatter in round 1, drifts by round
##   3, the open floor still stone).
## - On the floor: they stay, carrying from round to round, until a new match
##   clears them (clear()), up to MAX_PETALS (the preset thins it:
##   set_ratio(), group look_floor_petals); past that the oldest go first.
##   Each lands glowing neon lavender and dims over SETTLE_GLOW_TIME to a
##   soft glow (SETTLED_GLOW), and flares again when kicked up.
## - Stirred (stir(), a FloorStir each drawn frame from the match view):
##   pushed out of a moving fighter's way by its speed, blown out by a
##   burst, swept along a blade's path where it passes low; kicked petals
##   lift a little, drift on the air, slide to a stop and settle again,
##   piling against the parapet's foot. Only stirred and falling petals cost
##   anything a frame: the settled ones sit in a grid of CELL-metre cells
##   until something reaches them.
## - Match point: they turn blood red with the canopy (set_doom(); the
##   owner's choice, Oct 8).
## Picture only: the match view reads the match and stirs them; nothing here
## reaches the rules. Their glow and size are the shader's
## (fallen_petal.gdshader), the glow's start in each petal's custom data.

const SHADER: Shader = preload("res://shaders/fallen_petal.gdshader")
const GROUP: StringName = GraphicsApplier.GROUP_FLOOR_PETALS

const MAX_PETALS: int = 1500
const LAND_RATE: float = 8.0
const SETTLE_GLOW_TIME: float = 10.0
const SETTLED_GLOW: float = 0.35
const DRIFT_DEPTH: float = 0.45
const DRIFT_SHARE: float = 0.35
const JOINT_SHARE: float = 0.25
## How far either side of downwind (degrees, one standard deviation) the
## parapet's drifts gather; DOWNWIND_SHARE of them gather there, the rest
## anywhere round it.
const DRIFT_SPREAD: float = 40.0
const DOWNWIND_SHARE: float = 0.75
const FALL_FROM := Vector2(6.0, 9.0)
const SINK := Vector2(0.35, 0.7)
## A petal's length (m, from x to y), and how high it lies over the floor
## (m), so petals on petals don't flicker.
const SIZE := Vector2(0.07, 0.12)
const REST := Vector2(0.003, 0.014)
## How far a falling petal sways from its path (m), and how fast it tumbles
## (turns a second, from x to y).
const FLUTTER: float = 0.25
const TUMBLE := Vector2(0.4, 1.2)
## A petal in the air takes the wind's speed and its fall speed at this rate
## (1/s); one sliding on the floor stops at FRICTION (1/s), and settles
## below SETTLE_SPEED (m/s).
const AIR_DRAG: float = 3.0
const FRICTION: float = 5.0
const SETTLE_SPEED: float = 0.05
## How a stir throws a petal: outward at PUSH_OUT times a pusher's speed and
## along with it at PUSH_ALONG times, at BURST_SPEED times a burst's
## strength, along a blade at SWEEP_ALONG times its speed within
## SWEEP_RADIUS of it, each fading to nothing at the reach's edge; a share
## LIFT of the throw goes upward. A throw under KICK_MIN (m/s) leaves a
## settled petal be.
const PUSH_OUT: float = 1.0
const PUSH_ALONG: float = 0.6
const BURST_SPEED: float = 2.5
const SWEEP_ALONG: float = 0.35
const SWEEP_RADIUS: float = 0.35
const LIFT: float = 0.35
const KICK_MIN: float = 0.08
## How high over the floor (m) a fighter's feet and a burst reach petals in
## the air; a blade reaches SWEEP_RADIUS round itself.
const REACH_UP: float = 0.6
const CELL: float = 0.5

enum { FREE, AIR, SLIDE, SETTLED }

var _layout: ShrineLayout
var _wind := Vector3.ZERO
## Where petals may lie: inside the parapet's inner face, all round.
var _radius: float = 0.0
var _rng: RandomNumberGenerator
var _material: ShaderMaterial
var _cap: int = MAX_PETALS
var _time: float = 0.0
var _spawn_due: float = 0.0
## Slots in use (0.._used - 1, filled in order) and the next to recycle once
## every slot is used.
var _used: int = 0
var _next: int = 0
var _stirred: int = 0
## Whether new petals keep falling (the tests and shot scenes may stop them).
var raining: bool = true

var _state := PackedByteArray()
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _sink := PackedFloat32Array()
var _size := PackedFloat32Array()
var _rest := PackedFloat32Array()
var _yaw := PackedFloat32Array()
var _tilt := PackedFloat32Array()
var _tumble := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _glow_from := PackedFloat32Array()
var _cell_of := PackedInt32Array()
## The petals in the air or sliding.
var _moving := PackedInt32Array()
## The settled petals in each grid cell.
var _cells: Array[Array] = []
var _cells_across: int = 0
var _stirs: Array[FloorStir] = []


## The Shrine's fallen petals over def's floor, falling on layout's wind, as
## a new node named FallenPetals.
static func build(layout: ShrineLayout, def: ArenaDef) -> ShrineFallenPetals:
	var p := ShrineFallenPetals.new()
	p.name = "FallenPetals"
	p._setup(layout, def)
	return p


func _setup(layout: ShrineLayout, def: ArenaDef) -> void:
	_layout = layout
	_wind = Vector3(layout.wind.x, 0.0, layout.wind.y)
	_radius = def.wall_inner_radius() - 0.03
	_rng = layout.random_stream(&"fallen_petals")
	_state.resize(MAX_PETALS)
	_pos.resize(MAX_PETALS)
	_vel.resize(MAX_PETALS)
	_sink.resize(MAX_PETALS)
	_size.resize(MAX_PETALS)
	_rest.resize(MAX_PETALS)
	_yaw.resize(MAX_PETALS)
	_tilt.resize(MAX_PETALS)
	_tumble.resize(MAX_PETALS)
	_phase.resize(MAX_PETALS)
	_glow_from.resize(MAX_PETALS)
	_cell_of.resize(MAX_PETALS)
	_cells_across = ceili(_radius * 2.0 / CELL)
	_cells.resize(_cells_across * _cells_across)
	for i: int in _cells.size():
		_cells[i] = []
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"settle_time", SETTLE_GLOW_TIME)
	_material.set_shader_parameter(&"settled_glow", SETTLED_GLOW)
	_material.set_shader_parameter(&"glow_color", ShrineWisteria.PETAL_GLOW)
	_material.set_shader_parameter(&"doom_color", ShrineWisteria.DOOM_PETAL_GLOW)
	_material.set_shader_parameter(&"doom", 0.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = plane
	mm.instance_count = MAX_PETALS
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# far enough out and up for a petal setting off upwind under the canopy
	var reach: float = _radius + _wind.length() * FALL_FROM.y / SINK.x + 2.0
	custom_aabb = AABB(Vector3(-reach, -0.5, -reach), Vector3(reach * 2.0, FALL_FROM.y + 2.0, reach * 2.0))
	add_to_group(GROUP)


# ------------------------------------------------------------------ the match's seams

## Takes a drawn frame's stirring, applied at the next advance().
func stir(s: FloorStir) -> void:
	if s != null and not s.is_empty():
		_stirs.append(s)


## A clean floor (a new match): no petals lying or falling.
func clear() -> void:
	for i: int in _used:
		_state[i] = FREE
	for c: Array in _cells:
		c.clear()
	_moving.clear()
	_stirs.clear()
	_used = 0
	_next = 0
	_spawn_due = 0.0
	multimesh.visible_instance_count = 0


## The share of MAX_PETALS the preset draws (GraphicsPreset.floor_petal_ratio);
## petals past the new count go at once.
func set_ratio(ratio: float) -> void:
	_cap = clampi(roundi(MAX_PETALS * ratio), 0, MAX_PETALS)
	if _used <= _cap:
		return
	for i: int in range(_cap, _used):
		if _state[i] == SETTLED:
			_unfile(i)
		_state[i] = FREE
	var kept := PackedInt32Array()
	for i: int in _moving:
		if i < _cap:
			kept.append(i)
	_moving = kept
	_used = _cap
	_next = 0 if _cap == 0 else _next % _cap
	multimesh.visible_instance_count = _used


## Match point's blood red, 0 (lavender) to 1.
func set_doom(t: float) -> void:
	_material.set_shader_parameter(&"doom", t)


## Moves the petals on by dt seconds: the stirring since the last advance,
## new petals setting off, the falling and kicked ones on their way.
func advance(dt: float) -> void:
	_time += dt
	_material.set_shader_parameter(&"now", _time)
	for s: FloorStir in _stirs:
		_apply(s)
	_stirs.clear()
	if _cap > 0 and raining:
		_spawn_due += LAND_RATE * (float(_cap) / MAX_PETALS) * dt
		while _spawn_due >= 1.0:
			_spawn_due -= 1.0
			_launch(_take_slot())
	_move(dt)


# ------------------------------------------------------------------ reading them

## Petals lying or falling.
func count() -> int:
	return _used


func cap() -> int:
	return _cap


func falling_count() -> int:
	var n: int = 0
	for i: int in _moving:
		if _state[i] == AIR:
			n += 1
	return n


func settled_count() -> int:
	return _used - _moving.size()


## Where each settled petal lies.
func settled_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i: int in _used:
		if _state[i] == SETTLED:
			out.append(_pos[i])
	return out


## How many times the fighters have kicked a settled petal up.
func stirred_count() -> int:
	return _stirred


## Petal i's glow, 1 at its brightest, SETTLED_GLOW once long settled (as
## the shader draws it).
func glow(i: int) -> float:
	if _state[i] != SETTLED:
		return 1.0
	return lerpf(1.0, SETTLED_GLOW, smoothstep(0.0, SETTLE_GLOW_TIME, _time - _glow_from[i]))


func material() -> ShaderMaterial:
	return _material


## Lays a petal on the floor at `at`, settled (as a petal that has landed
## there), and returns its slot.
func drop(at: Vector3) -> int:
	var i: int = _take_slot()
	_new_petal(i)
	_pos[i] = Vector3(at.x, _rest[i], at.z)
	_settle(i)
	_draw(i)
	return i


# ------------------------------------------------------------------ the petals' lives

## A slot for a new petal: the next free one, or once all are used, the
## oldest petal's.
func _take_slot() -> int:
	if _used < _cap:
		_used += 1
		multimesh.visible_instance_count = _used
		return _used - 1
	var i: int = _next
	_next = (_next + 1) % _cap
	if _state[i] == SETTLED:
		_unfile(i)
	else:
		var at: int = _moving.find(i)
		if at >= 0:
			_moving.remove_at(at)
	return i


func _new_petal(i: int) -> void:
	_sink[i] = _rng.randf_range(SINK.x, SINK.y)
	_size[i] = _rng.randf_range(SIZE.x, SIZE.y)
	_rest[i] = _rng.randf_range(REST.x, REST.y)
	_yaw[i] = _rng.randf() * TAU
	_tilt[i] = _rng.randf_range(-0.25, 0.25)
	_tumble[i] = _rng.randf_range(TUMBLE.x, TUMBLE.y) * TAU * (1.0 if _rng.randf() < 0.5 else -1.0)
	_phase[i] = _rng.randf() * TAU
	_glow_from[i] = _time


## Sends petal i falling from the canopy toward where it'll land.
func _launch(i: int) -> void:
	_new_petal(i)
	var target: Vector3 = _landing()
	var height: float = _rng.randf_range(FALL_FROM.x, FALL_FROM.y)
	var fall_time: float = (height - _rest[i]) / _sink[i]
	var v := Vector3(_wind.x, -_sink[i], _wind.z)
	_vel[i] = v
	_pos[i] = Vector3(target.x, _rest[i], target.z) - v * fall_time
	_state[i] = AIR
	_moving.append(i)


## Where a new petal aims to land: at the parapet's foot, in a ring joint or
## anywhere on the floor.
func _landing() -> Vector3:
	var pick: float = _rng.randf()
	var angle: float
	var r: float
	if pick < DRIFT_SHARE:
		var downwind: float = rad_to_deg(atan2(_wind.x, _wind.z))
		angle = downwind + _rng.randfn(0.0, DRIFT_SPREAD) if _rng.randf() < DOWNWIND_SHARE else _rng.randf() * 360.0
		r = _radius - minf(absf(_rng.randfn(0.0, DRIFT_DEPTH * 0.5)), DRIFT_DEPTH * 1.5)
	elif pick < DRIFT_SHARE + JOINT_SHARE:
		angle = _rng.randf() * 360.0
		var rings: int = maxi(1, floori((_radius - _layout.centre_radius) / _layout.ring_width) + 1)
		r = minf(_layout.centre_radius + _rng.randi_range(0, rings - 1) * _layout.ring_width + _rng.randfn(0.0, 0.03), _radius)
	else:
		angle = _rng.randf() * 360.0
		r = sqrt(_rng.randf()) * _radius
	return ShrineLayout.polar(angle, r)


func _settle(i: int) -> void:
	_state[i] = SETTLED
	_vel[i] = Vector3.ZERO
	_glow_from[i] = _time
	var c: int = _cell(_pos[i])
	_cell_of[i] = c
	_cells[c].append(i)


func _unfile(i: int) -> void:
	_cells[_cell_of[i]].erase(i)


func _cell(p: Vector3) -> int:
	var x: int = clampi(floori((p.x + _radius) / CELL), 0, _cells_across - 1)
	var z: int = clampi(floori((p.z + _radius) / CELL), 0, _cells_across - 1)
	return x + z * _cells_across


## The settled petals in the cells round a circle at `at` of `radius`.
func _settled_near(at: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0: int = clampi(floori((at.x - radius + _radius) / CELL), 0, _cells_across - 1)
	var x1: int = clampi(floori((at.x + radius + _radius) / CELL), 0, _cells_across - 1)
	var z0: int = clampi(floori((at.z - radius + _radius) / CELL), 0, _cells_across - 1)
	var z1: int = clampi(floori((at.z + radius + _radius) / CELL), 0, _cells_across - 1)
	for z: int in range(z0, z1 + 1):
		for x: int in range(x0, x1 + 1):
			for i: int in _cells[x + z * _cells_across]:
				out.append(i)
	return out


## Throws the petals a stir reaches.
func _apply(s: FloorStir) -> void:
	for p: FloorStir.Push in s.pushes:
		var speed: float = p.velocity.length()
		if speed < KICK_MIN:
			continue
		_throw_round(p.at, p.radius, REACH_UP, func(out: Vector3, fade: float) -> Vector3:
			return (out * speed * PUSH_OUT + p.velocity * PUSH_ALONG) * fade * p.strength)
	for p: FloorStir.Push in s.bursts:
		_throw_round(p.at, p.radius, REACH_UP, func(out: Vector3, fade: float) -> Vector3:
			return out * BURST_SPEED * p.strength * fade)
	for w: FloorStir.Sweep in s.sweeps:
		for k: int in 6:
			var t: float = k / 5.0
			var at: Vector3 = w.a.lerp(w.b, t)
			if at.y >= FloorStirrer.SWEEP_HEIGHT:
				continue
			var v: Vector3 = w.va.lerp(w.vb, t)
			var level := Vector3(v.x, 0.0, v.z)
			if level.length() < FloorStirrer.SWEEP_SPEED:
				continue
			var low: float = 1.0 - at.y / FloorStirrer.SWEEP_HEIGHT
			_throw_round(at, SWEEP_RADIUS, at.y + SWEEP_RADIUS, func(_out: Vector3, fade: float) -> Vector3:
				return level * SWEEP_ALONG * low * fade)


## Throws every petal within radius of at (level distance) and no higher
## than top over the floor by throw(out, fade): out the level direction away
## from at, fade 1 at the centre to 0 at the edge.
func _throw_round(at: Vector3, radius: float, top: float, throw: Callable) -> void:
	var near: PackedInt32Array = _settled_near(at, radius)
	near.append_array(_moving)
	for i: int in near:
		if _pos[i].y > top:
			continue
		var d := Vector3(_pos[i].x - at.x, 0.0, _pos[i].z - at.z)
		var dist: float = d.length()
		if dist >= radius:
			continue
		var out: Vector3 = d / dist if dist > 1e-4 else Vector3(cos(_phase[i]), 0.0, sin(_phase[i]))
		var push: Vector3 = throw.call(out, 1.0 - dist / radius)
		if push.length() < KICK_MIN:
			continue
		_kick(i, push)


func _kick(i: int, push: Vector3) -> void:
	if _state[i] == SETTLED:
		_unfile(i)
		_moving.append(i)
		_stirred += 1
	_vel[i] += push + Vector3.UP * push.length() * LIFT
	_state[i] = AIR
	_glow_from[i] = _time


## Moves the petals in the air and sliding on by dt, settling those that
## stop.
func _move(dt: float) -> void:
	var still := PackedInt32Array()
	var air: float = 1.0 - exp(-AIR_DRAG * dt)
	var slow: float = exp(-FRICTION * dt)
	for i: int in _moving:
		var p: Vector3 = _pos[i]
		var v: Vector3 = _vel[i]
		if _state[i] == AIR:
			v += (Vector3(_wind.x, -_sink[i], _wind.z) - v) * air
			p += v * dt
			if p.y <= _rest[i]:
				p.y = _rest[i]
				v.y = 0.0
				_state[i] = SLIDE
		else:
			v *= slow
			p += v * dt
		# the parapet stops them: they pile at its foot
		var level := Vector2(p.x, p.z)
		if _state[i] != AIR and level.length() > _radius:
			level = level.normalized() * _radius
			p = Vector3(level.x, p.y, level.y)
			var outward := Vector3(level.x, 0.0, level.y).normalized()
			v -= outward * maxf(v.dot(outward), 0.0)
		_pos[i] = p
		_vel[i] = v
		_glow_from[i] = _time
		if _state[i] == SLIDE and v.length() < SETTLE_SPEED:
			_settle(i)
		else:
			still.append(i)
		_draw(i)
	_moving = still


## Puts petal i where it is in the multimesh: tumbling and swaying as it
## falls, lying flat (a little tilted) on the floor.
func _draw(i: int) -> void:
	var p: Vector3 = _pos[i]
	var b: Basis
	if _state[i] == AIR:
		var up: float = clampf(p.y - _rest[i], 0.0, 1.0)
		var t: float = _time + _phase[i]
		p += Vector3(sin(t * 1.7), 0.0, cos(t * 1.3 + _phase[i])) * FLUTTER * up
		b = Basis(Vector3.UP, _yaw[i] + t * 0.6) * Basis(Vector3.RIGHT, sin(t * absf(_tumble[i])) * 1.2 * up + _tilt[i])
	else:
		b = Basis(Vector3.UP, _yaw[i]) * Basis(Vector3.RIGHT, _tilt[i])
	multimesh.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * _size[i]), p))
	multimesh.set_instance_custom_data(i, Color(_glow_from[i], _phase[i] / TAU, 0.0, 0.0))
