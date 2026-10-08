class_name FloorStir
extends RefCounted
## What stirs an arena's floor on one drawn frame (milestone-1 task 137):
## pushes (a fighter's feet or body moving over it), sweeps (a blade passing
## low and fast) and bursts (a landing, a fall, a blow). FloorStirrer builds
## one each frame from what the match view shows; an arena whose floor reacts
## (the Shrine's fallen petals, and since milestone-1 task 115 its grass and
## banners, ArenaAir) takes it through stir_floor(). Moonsplitter's waves in
## flight are its fronts. Picture only: nothing here reaches the rules.


## Something moving over the floor at `at`, at `velocity` (m/s, level),
## reaching `radius` metres round it, `strength` times as hard as a walk; or,
## as a burst, blowing out from `at` once. `air` is how far it reaches
## through the air (the banners on the ledge, ArenaAir): `radius` but for the
## big blows.
class Push:
	var at: Vector3
	var velocity: Vector3
	var radius: float
	var strength: float
	var air: float


## A Moonsplitter wave in flight: from `origin` along `ahead` (level, unit),
## `s` metres out on the frame shown; `kind` &"vertical" or &"horizontal".
class Front:
	var origin: Vector3
	var ahead: Vector3
	var s: float
	var kind: StringName


## A blade from a to b moving at va (at a) and vb (at b), m/s.
class Sweep:
	var a: Vector3
	var b: Vector3
	var va: Vector3
	var vb: Vector3


var pushes: Array[Push] = []
var sweeps: Array[Sweep] = []
var bursts: Array[Push] = []
var fronts: Array[Front] = []


func push(at: Vector3, velocity: Vector3, radius: float, strength: float) -> void:
	pushes.append(_push(at, Vector3(velocity.x, 0.0, velocity.z), radius, strength))


func sweep(a: Vector3, b: Vector3, va: Vector3, vb: Vector3) -> void:
	var s := Sweep.new()
	s.a = a
	s.b = b
	s.va = va
	s.vb = vb
	sweeps.append(s)


## A burst; `air` is its reach through the air (radius when 0).
func burst(at: Vector3, radius: float, strength: float, air: float = 0.0) -> void:
	bursts.append(_push(at, Vector3.ZERO, radius, strength, air))


func front(origin: Vector3, ahead: Vector3, s: float, kind: StringName) -> void:
	var f := Front.new()
	f.origin = origin
	f.ahead = ahead
	f.s = s
	f.kind = kind
	fronts.append(f)


func is_empty() -> bool:
	return pushes.is_empty() and sweeps.is_empty() and bursts.is_empty() and fronts.is_empty()


static func _push(at: Vector3, velocity: Vector3, radius: float, strength: float, air: float = 0.0) -> Push:
	var p := Push.new()
	p.at = at
	p.velocity = velocity
	p.radius = radius
	p.strength = strength
	p.air = maxf(air, radius)
	return p
