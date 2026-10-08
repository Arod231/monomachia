class_name FloorStir
extends RefCounted
## What stirs an arena's floor on one drawn frame (milestone-1 task 137):
## pushes (a fighter's feet or body moving over it), sweeps (a blade passing
## low and fast) and bursts (a landing, a fall, a blow). FloorStirrer builds
## one each frame from what the match view shows; an arena whose floor reacts
## (the Shrine's fallen petals) takes it through stir_floor(). Picture only:
## nothing here reaches the rules.


## Something moving over the floor at `at`, at `velocity` (m/s, level),
## reaching `radius` metres round it, `strength` times as hard as a walk; or,
## as a burst, blowing out from `at` once.
class Push:
	var at: Vector3
	var velocity: Vector3
	var radius: float
	var strength: float


## A blade from a to b moving at va (at a) and vb (at b), m/s.
class Sweep:
	var a: Vector3
	var b: Vector3
	var va: Vector3
	var vb: Vector3


var pushes: Array[Push] = []
var sweeps: Array[Sweep] = []
var bursts: Array[Push] = []


func push(at: Vector3, velocity: Vector3, radius: float, strength: float) -> void:
	pushes.append(_push(at, Vector3(velocity.x, 0.0, velocity.z), radius, strength))


func sweep(a: Vector3, b: Vector3, va: Vector3, vb: Vector3) -> void:
	var s := Sweep.new()
	s.a = a
	s.b = b
	s.va = va
	s.vb = vb
	sweeps.append(s)


func burst(at: Vector3, radius: float, strength: float) -> void:
	bursts.append(_push(at, Vector3.ZERO, radius, strength))


func is_empty() -> bool:
	return pushes.is_empty() and sweeps.is_empty() and bursts.is_empty()


static func _push(at: Vector3, velocity: Vector3, radius: float, strength: float) -> Push:
	var p := Push.new()
	p.at = at
	p.velocity = velocity
	p.radius = radius
	p.strength = strength
	return p
