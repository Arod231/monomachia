class_name WeaponTrail
extends MeshInstance3D
## One blade's brush-stroke trail (plan task 18.3): a ribbon over the last
## stretch of the blade (its WeaponLook.trail_width back from the tip),
## swept through the frames it has just passed, tapering and breaking up like
## a dry brush toward the tail, in white, red or gold with an ink edge on the
## tip side (shaders/brush_trail.gdshader).
##
## CombatEffects keeps one per fighter and hand and feeds it every drawn
## frame with the blade's span and TrailState's strength and colour, on the
## effect clock: a sample is kept for LIFE_FRAMES world frames, so the ribbon
## stands still in hit-stop and pause and stretches in the KO's slow motion.
## While the trail is off nothing new is laid down, and what is there fades
## out within LIFE_FRAMES.

## World frames a sample stays (the demo's 0.14 s).
const LIFE_FRAMES: float = 8.0
## The most samples kept (a 240 Hz display lays down four a world frame).
const MAX_SAMPLES: int = 40
## Points laid between two samples along a Catmull-Rom curve, so a fast cut
## sweeps a curve, not a fan of straight spokes.
const SUBDIVISIONS: int = 3
## How far the ribbon's inner edge has closed toward the tip at the tail:
## the stroke tapers to a point.
const TAPER: float = 0.75
## The trail colours (TrailState's kinds), the demo's.
const COLORS: Dictionary[StringName, Color] = {
	TrailState.NORMAL: Color("dfe6ff"),
	TrailState.DANGER: Color("ff3020"),
	TrailState.ULT: Color("ffc040"),
}

const SHADER: Shader = preload("res://shaders/brush_trail.gdshader")


class Sample:
	var t: float = 0.0
	var base: Vector3 = Vector3.ZERO
	var tip: Vector3 = Vector3.ZERO
	var strength: float = 1.0
	var color: Color = Color.WHITE


var _samples: Array[Sample] = []
var _array_mesh: ArrayMesh = ArrayMesh.new()
var _vertices: PackedVector3Array = PackedVector3Array()
var _colors: PackedColorArray = PackedColorArray()
var _uvs: PackedVector2Array = PackedVector2Array()
var _now: float = 0.0

static var _material: ShaderMaterial


func _init() -> void:
	mesh = _array_mesh
	material_override = shared_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the ribbon is rebuilt in world space every frame: never cull it by a
	# stale box
	custom_aabb = AABB(Vector3(-40.0, -10.0, -40.0), Vector3(80.0, 40.0, 80.0))


## The one material every trail shares.
static func shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		LookNoise.apply_to(_material)
	return _material


## The stretch of a blade from `base` to `tip` that trails: `width` back from
## the tip, or the whole blade when it is shorter. [inner end, tip].
static func span(base: Vector3, tip: Vector3, width: float) -> PackedVector3Array:
	var along: Vector3 = base - tip
	var length: float = along.length()
	if length <= 0.0:
		return PackedVector3Array([tip, tip])
	return PackedVector3Array([tip + along / length * minf(width, length), tip])


## Lays down the blade's span (`inner` to `tip`) at effect clock `t`, with
## TrailState's strength and kind. Nothing is laid at strength 0. A second
## sample on the same frame shown replaces the first (hit-stop, pause); a
## clock that went back (a new round) starts the trail over.
func feed(t: float, inner: Vector3, tip: Vector3, strength: float, kind: StringName) -> void:
	if not _samples.is_empty() and t < _samples[-1].t - 1e-4:
		clear()
	if strength <= 0.0:
		return
	var s: Sample = Sample.new()
	s.t = t
	s.base = inner
	s.tip = tip
	s.strength = strength
	s.color = COLORS.get(kind, COLORS[TrailState.NORMAL])
	if not _samples.is_empty() and absf(t - _samples[-1].t) <= 1e-4:
		_samples[-1] = s
		return
	_samples.append(s)
	if _samples.size() > MAX_SAMPLES:
		_samples.remove_at(0)


## Ages the trail to effect clock `t`, drops the samples past LIFE_FRAMES
## and rebuilds the ribbon.
func update(t: float) -> void:
	_now = t
	var kept: Array[Sample] = []
	for s: Sample in _samples:
		if t - s.t < LIFE_FRAMES:
			kept.append(s)
	_samples = kept
	_rebuild()


func clear() -> void:
	_samples.clear()
	_rebuild()


func sample_count() -> int:
	return _samples.size()


## The ribbon's vertices as last built (inner edge and tip side in turn,
## newest first), in world space; empty when nothing shows.
func vertices() -> PackedVector3Array:
	return _vertices


## The vertices' colours (the trail's colour, its alpha the strength fading
## with age), as last built.
func colors() -> PackedColorArray:
	return _colors


func _rebuild() -> void:
	# an idle trail stays empty without touching the mesh every frame
	if _samples.size() < 2 and _vertices.is_empty():
		return
	_array_mesh.clear_surfaces()
	_vertices = PackedVector3Array()
	_colors = PackedColorArray()
	_uvs = PackedVector2Array()
	var n: int = _samples.size()
	if n < 2:
		return
	# newest first, so the head of the stroke is at the blade
	var steps: int = SUBDIVISIONS + 1
	for i: int in range(n - 1, 0, -1):
		for k: int in steps:
			_add_point(i, float(k) / float(steps))
	_add_point(1, 1.0)
	var indices: PackedInt32Array = PackedInt32Array()
	var rows: int = _vertices.size() / 2
	for r: int in rows - 1:
		var a: int = r * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Adds the ribbon's two vertices `u` of the way back from sample i to
## sample i - 1 (Catmull-Rom through the neighbours).
func _add_point(i: int, u: float) -> void:
	var n: int = _samples.size()
	var s1: Sample = _samples[i]
	var s0: Sample = _samples[mini(i + 1, n - 1)]
	var s2: Sample = _samples[maxi(i - 1, 0)]
	var s3: Sample = _samples[maxi(i - 2, 0)]
	var t: float = lerpf(s1.t, s2.t, u)
	var tip: Vector3 = _catmull(s0.tip, s1.tip, s2.tip, s3.tip, u)
	var inner: Vector3 = _catmull(s0.base, s1.base, s2.base, s3.base, u)
	var age: float = clampf((_now - t) / LIFE_FRAMES, 0.0, 1.0)
	inner = inner.lerp(tip, TAPER * age)
	var c: Color = s1.color.lerp(s2.color, u)
	c.a = lerpf(s1.strength, s2.strength, u) * (1.0 - age)
	_vertices.append(inner)
	_vertices.append(tip)
	_colors.append(c)
	_colors.append(c)
	_uvs.append(Vector2(age, 0.0))
	_uvs.append(Vector2(age, 1.0))


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: float) -> Vector3:
	return p1.cubic_interpolate(p2, p0, p3, u)
