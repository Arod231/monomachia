class_name Wind
extends Resource
## The one wind of an arena's night (milestone-1 task 52; spec stories 153
## and 154): it moves the clouds, the wisteria's racemes and outer branches,
## the falling and fallen petals, the embers and ash, the grass, the banners
## and the Hunter's scarf (and the Katana's sageo) alike. Presentation only:
## the rules never read it. Milestone 1 has only the clear night, so there is
## no weather here, only today's breeze.
##
## A steady breeze (direction, speed) with soft gusts (the owner's choice, Oct
## 8): fronts gust_spacing metres apart roll downwind across the arena, one
## passing a spot every gust_period seconds, lifting the wind there by up to
## gust (as a share of the breeze) and easing it a little between them.
## gust_at() is the wind's strength at a place and time as a share of the
## breeze, at() its velocity there.
##
## The shaders read it as global uniforms (wind.gdshaderinc, which mirrors
## gust_at()): apply() sets them, and the arena calls it as it builds and
## advance() each frame, which also keeps the wind's own time (the shaders'
## wind_time). The arena that owns the night makes its wind the active one
## (Wind.active), for what doesn't belong to the arena: the fighters' scarf
## and sageo springs.

## The global shader uniforms (project.godot's shader_globals).
const GLOBAL_WIND: StringName = &"wind"
const GLOBAL_SHAPE: StringName = &"wind_shape"
const GLOBAL_TIME: StringName = &"wind_time"
## How much the wind falls short of the breeze between gusts, as a share.
const LULL: float = 0.25

## The arena's wind now: set by the arena that owns the night, null when no
## arena is up.
static var active: Wind

## Level, a unit vector (x and z): where the wind blows toward.
@export var direction: Vector2 = Vector2(-0.945, -0.326)
## The breeze, m/s.
@export var speed: float = 0.58
## How much a gust lifts the wind, as a share of the breeze.
@export_range(0.0, 2.0) var gust: float = 0.6
## Seconds between gusts at one spot, and metres between gust fronts.
@export var gust_period: float = 5.0
@export var gust_spacing: float = 14.0

## The wind's own clock, seconds (advance()).
var time: float = 0.0


## The breeze's velocity, level (x and z), m/s.
func velocity() -> Vector2:
	return direction.normalized() * speed


## The wind's strength at world point at as a share of the breeze, at time t
## (the wind's own time when not given): about 1 - LULL between gusts and up
## to 1 + gust as a front passes.
func gust_at(at: Vector3, t: float = NAN) -> float:
	if is_nan(t):
		t = time
	var dir: Vector2 = direction.normalized()
	var phase: float = (at.x * dir.x + at.z * dir.y) / gust_spacing - t / gust_period
	var front: float = pow(0.5 + 0.5 * sin(TAU * phase), 4.0)
	var ripple: float = 0.5 + 0.5 * sin(TAU * (phase * 2.37 + 0.31))
	return 1.0 - LULL + (gust + LULL) * front * (0.75 + 0.25 * ripple)


## The wind's velocity at world point at, time t, level (x and z), m/s.
func at(point: Vector3, t: float = NAN) -> Vector2:
	return velocity() * gust_at(point, t)


## Moves the wind's clock on by delta seconds and sets the shaders' time.
func advance(delta: float) -> void:
	time += delta
	RenderingServer.global_shader_parameter_set(GLOBAL_TIME, time)


## Sets the shaders' global wind: (direction x, direction z, speed, gust),
## (gust_period, gust_spacing) and the time.
func apply() -> void:
	var globals: Dictionary[StringName, Variant] = shader_globals()
	for key: StringName in globals:
		RenderingServer.global_shader_parameter_set(key, globals[key])


## Blows on a chain of springs (the scarf's tails, the sageo) hanging at
## world point at: each chain's gravity, `gravity` m/s² down, gains `catch`
## m/s² downwind for each m/s of the active wind there (gusts and all), so the
## cloth leans and streams with it. With no active wind (no arena up: a
## preview, a test) the springs are left as they are.
static func blow_springs(sim: SpringBoneSimulator3D, gravity: float, catch: float, at: Vector3) -> void:
	if active == null:
		return
	var v: Vector2 = active.at(at)
	var force: Vector3 = Vector3.DOWN * gravity + Vector3(v.x, 0.0, v.y) * catch
	for i: int in sim.setting_count:
		sim.set_gravity(i, force.length())
		sim.set_gravity_direction(i, force.normalized())


## The global uniforms' values for this wind.
func shader_globals() -> Dictionary[StringName, Variant]:
	var dir: Vector2 = direction.normalized()
	return {
		GLOBAL_WIND: Vector4(dir.x, dir.y, speed, gust),
		GLOBAL_SHAPE: Vector2(gust_period, gust_spacing),
		GLOBAL_TIME: time,
	}
