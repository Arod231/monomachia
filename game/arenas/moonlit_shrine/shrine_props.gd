class_name ShrineProps
extends RefCounted
## Procedural shrine props, each added to a MeshKitSet at a transform so many
## props share one mesh per material. Each prop function builds one kind that
## ShrineLayout.prop_scenes can replace with bought art (lantern, torii,
## pillar, pagoda, temple_hall; the wisteria are ShrineWisteria's); the
## sacred rope is part of
## the gates.

const LANTERN_GLOW: Shader = preload("res://shaders/lantern_glow.gdshader")

## A stone lantern's fire, in the lantern's own space: the middle of its
## lit paper box. Bought lanterns keep their fire at the same height, since
## the lights and halos go there.
const LANTERN_FIRE := Vector3(0.0, 2.12, 0.0)


## Materials for every kit key the platform, its props and the backdrop's
## buildings use: physically based (LookMaterials), the lanterns' glow its
## own.
static func materials() -> Dictionary[StringName, Material]:
	var glow := ShaderMaterial.new()
	glow.shader = LANTERN_GLOW
	return {
		&"landing": LookMaterials.prop(LookPalette.STONE_LIGHT),
		&"parapet": LookMaterials.prop(LookPalette.STONE),
		&"stone": LookMaterials.prop(LookPalette.STONE_LIGHT),
		&"stone_dark": LookMaterials.prop(LookPalette.STONE_DARK),
		&"pebbles": LookMaterials.prop(LookPalette.STONE_DARK),
		&"lacquer": LookMaterials.prop(LookPalette.LACQUER),
		&"black_lacquer": LookMaterials.prop(LookPalette.INK_SOFT),
		&"rope": LookMaterials.prop(LookPalette.ROPE),
		&"paper": LookMaterials.prop(LookPalette.PAPER),
		&"wood": LookMaterials.prop(LookPalette.WOOD_DARK.lightened(0.05)),
		&"roof": LookMaterials.prop(LookPalette.INK_SOFT.lightened(0.04)),
		&"glow": glow,
		&"window": distant_glow_material(),
	}


## Lit windows and lanterns far away: the lanterns' glow, dimmer and
## steadier.
static func distant_glow_material() -> ShaderMaterial:
	var window := ShaderMaterial.new()
	window.shader = LANTERN_GLOW
	window.set_shader_parameter(&"energy", 2.2)
	window.set_shader_parameter(&"flicker", 0.12)
	return window


## A square stone lantern (about 3.2 m) standing on xform, with lit paper
## round its fire (LANTERN_FIRE). Each lantern's paper flickers at its own
## phase, kept in the glow's vertex colour alpha.
static func lantern(kits: MeshKitSet, xform: Transform3D, rng: RandomNumberGenerator) -> void:
	var stone: MeshKit = kits.kit(&"stone")
	stone.color = Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.15))
	stone.box(xform * Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(1.0, 0.3, 1.0))
	stone.box(xform * Transform3D(Basis(), Vector3(0, 0.36, 0)), Vector3(0.78, 0.12, 0.78))
	stone.cylinder(xform * Transform3D(Basis(), Vector3(0, 0.42, 0)), 0.2, 0.17, 1.25, 10)
	stone.box(xform * Transform3D(Basis(), Vector3(0, 1.77, 0)), Vector3(0.86, 0.2, 0.86))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			stone.box(xform * Transform3D(Basis(), LANTERN_FIRE + Vector3(0.26 * sx, 0, 0.26 * sz)), Vector3(0.11, 0.5, 0.11))
	stone.box(xform * Transform3D(Basis(), Vector3(0, 2.4, 0)), Vector3(0.7, 0.07, 0.7))
	stone.roof(xform * Transform3D(Basis(), Vector3(0, 2.44, 0)), 0.64, 0.64, 0.5, 0.15, 4, 0.07)
	stone.lathe(xform * Transform3D(Basis(), Vector3(0, 2.92, 0)), PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.1, 0.03), Vector2(0.13, 0.12), Vector2(0.07, 0.22), Vector2(0.0, 0.3),
	]), 8, false)
	var glow: MeshKit = kits.kit(&"glow")
	glow.color = Color(1, 1, 1, rng.randf())
	for i: int in 4:
		var b := Basis(Vector3.UP, i * PI * 0.5)
		glow.box(xform * Transform3D(b, LANTERN_FIRE + b * Vector3(0, 0, 0.22)), Vector3(0.4, 0.4, 0.03))


## A torii gate standing on xform, its passage along local z.
static func torii(kits: MeshKitSet, xform: Transform3D, height: float, span: float) -> void:
	var lacquer: MeshKit = kits.kit(&"lacquer")
	var black: MeshKit = kits.kit(&"black_lacquer")
	var half: float = span * 0.5
	for s: float in [-1.0, 1.0]:
		lacquer.cylinder(xform * Transform3D(Basis(), Vector3(half * s, 0, 0)), 0.28, 0.23, height + 0.2, 16)
		black.cylinder(xform * Transform3D(Basis(), Vector3(half * s, 0, 0)), 0.36, 0.34, 0.55, 16)
		black.cylinder(xform * Transform3D(Basis(), Vector3(half * s, 0.55, 0)), 0.34, 0.3, 0.12, 16)
	# The tie beam (nuki), the lintel under the top and the curved top (kasagi).
	var nuki_y: float = height * 0.76
	_beam(lacquer, xform, PackedVector3Array([Vector3(-half - 0.9, nuki_y, 0), Vector3(half + 0.9, nuki_y, 0)]), 0.17, 0.19)
	_beam(lacquer, xform, PackedVector3Array([Vector3(-half - 1.25, height + 0.02, 0), Vector3(half + 1.25, height + 0.02, 0)]), 0.2, 0.17)
	var kasagi := PackedVector3Array()
	var reach: float = half + 1.7
	for i: int in 15:
		var x: float = lerpf(-reach, reach, i / 14.0)
		kasagi.append(Vector3(x, height + 0.42 + 0.5 * pow(absf(x) / reach, 2.6), 0))
	_beam(black, xform, kasagi, 0.3, 0.2)
	# The strut and the name plaque between the tie beam and the top.
	lacquer.box(xform * Transform3D(Basis(), Vector3(0, (nuki_y + height) * 0.5, 0)), Vector3(0.3, height - nuki_y, 0.22))
	black.box(xform * Transform3D(Basis(), Vector3(0, (nuki_y + height) * 0.5 + 0.02, 0)), Vector3(0.62, 0.86, 0.3))


## A sacred straw rope (shimenawa) sagging from a to b, with paper streamers.
static func shimenawa(kits: MeshKitSet, a: Vector3, b: Vector3, sag: float, streamers: int, thickness: float) -> void:
	var rope: MeshKit = kits.kit(&"rope")
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var n: int = 16
	for i: int in n + 1:
		var t: float = float(i) / n
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
		radii.append(thickness * (1.0 + 0.18 * sin(t * 40.0)) * (1.0 - 0.35 * absf(t * 2.0 - 1.0)))
	rope.tube(pts, radii, 7)
	var paper: MeshKit = kits.kit(&"paper")
	var along: Vector3 = (b - a).normalized()
	var face := Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized())
	for k: int in streamers:
		var t: float = (k + 1.0) / (streamers + 1.0)
		var top: Vector3 = a.lerp(b, t) + Vector3.DOWN * (sag * 4.0 * t * (1.0 - t) + thickness)
		_streamer(paper, Transform3D(face, top), 0.045)
		rope.box(Transform3D(face, top + Vector3.DOWN * 0.12 + along * 0.11), Vector3(0.025, 0.22, 0.025))


## A zigzag paper streamer (shide) hanging from top, its pieces stepping
## sideways by step along local x.
static func _streamer(paper: MeshKit, top: Transform3D, step: float) -> void:
	for piece: int in 4:
		var off: float = step if piece % 2 == 0 else -step
		paper.box(top * Transform3D(Basis(), Vector3(off, -0.07 - piece * 0.12, 0)), Vector3(0.09, 0.12, 0.012))


## A round stone pillar on a base, either whole (a capital, and a rope with
## streamers round it) or broken (a jagged top, and a fallen drum beside it).
static func pillar(kits: MeshKitSet, xform: Transform3D, height: float, broken: bool, rng: RandomNumberGenerator) -> void:
	var stone: MeshKit = kits.kit(&"stone")
	stone.color = Color(1, 1, 1).darkened(rng.randf_range(0.05, 0.2))
	stone.box(xform * Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(1.15, 0.3, 1.15))
	if not broken:
		stone.cylinder(xform * Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.43, 0.38, height - 0.55, 16)
		stone.box(xform * Transform3D(Basis(), Vector3(0, height - 0.12, 0)), Vector3(1.0, 0.25, 1.0))
		var ring_y: float = height * 0.62
		kits.kit(&"rope").torus(xform * Transform3D(Basis(), Vector3(0, ring_y, 0)), 0.43, 0.075, 18, 6)
		var paper: MeshKit = kits.kit(&"paper")
		for i: int in 3:
			var a: float = TAU * (i + 0.2) / 3.0
			var b := Basis(Vector3.UP, a)
			_streamer(paper, xform * Transform3D(b, b * Vector3(0, ring_y - 0.05, 0.47)), 0.04)
		return
	var top: float = height - 0.35
	var r: float = 0.4
	stone.cylinder(xform * Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.43, r, top - 0.3, 16)
	# The jagged break: a ring of uneven points, walled down to the shaft's
	# top and closed over a centre just below them.
	var segs: int = 16
	var centre: Vector3 = xform * Vector3(0, top - 0.05, 0)
	var rim: Array[Vector3] = []
	for i: int in segs:
		var a: float = TAU * i / segs
		rim.append(xform * Vector3(cos(a) * r, top + rng.randf_range(-0.25, 0.3), sin(a) * r))
	for i: int in segs:
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		var p0: Vector3 = xform * Vector3(cos(a0) * r, top, sin(a0) * r)
		var p1: Vector3 = xform * Vector3(cos(a1) * r, top, sin(a1) * r)
		var r0: Vector3 = rim[i]
		var r1: Vector3 = rim[(i + 1) % segs]
		stone.quad(p0, p1, r1, r0)
		var n: Vector3 = (centre - r0).cross(r1 - r0).normalized()
		stone.tri(r0, r1, centre, n, n, n)
	# A fallen drum lying on the ground nearby.
	var fall_angle: float = rng.randf_range(0, TAU)
	var dist: float = rng.randf_range(1.1, 1.6)
	var lie := Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3.FORWARD, PI * 0.5)
	stone.cylinder(xform * Transform3D(lie, Vector3(cos(fall_angle) * dist, 0.38, sin(fall_angle) * dist) + lie * Vector3(0, -0.6, 0)),
		0.4, 0.4, rng.randf_range(0.8, 1.3), 14)


## A pagoda of tiers storeys on xform, about width wide at the base, with
## lit windows on some storeys.
static func pagoda(kits: MeshKitSet, xform: Transform3D, tiers: int, width: float, rng: RandomNumberGenerator) -> void:
	var wood: MeshKit = kits.kit(&"wood")
	var roof: MeshKit = kits.kit(&"roof")
	var window: MeshKit = kits.kit(&"window")
	wood.box(xform * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(width * 1.25, 1.2, width * 1.25))
	var y: float = 1.2
	for t: int in tiers:
		var w: float = width * (1.0 - t * 0.13)
		var storey: float = width * 0.42
		wood.box(xform * Transform3D(Basis(), Vector3(0, y + storey * 0.5, 0)), Vector3(w, storey, w))
		if rng.randf() < 0.75:
			window.box(xform * Transform3D(Basis(), Vector3(0, y + storey * 0.5, w * 0.5 + 0.05)), Vector3(w * 0.3, storey * 0.4, 0.1))
		if rng.randf() < 0.5:
			window.box(xform * Transform3D(Basis(), Vector3(w * 0.5 + 0.05, y + storey * 0.5, 0)), Vector3(0.1, storey * 0.4, w * 0.3))
		y += storey
		roof.roof(xform * Transform3D(Basis(), Vector3(0, y, 0)), w * 0.95, w * 0.95, storey * 0.55, w * 0.18, 4, w * 0.05)
		y += storey * 0.3
	roof.cylinder(xform * Transform3D(Basis(), Vector3(0, y, 0)), width * 0.05, width * 0.02, width * 0.9, 6)


## A temple hall on a stone base, width wide and depth deep, with a long hip
## roof and a lit window at the front (+Z).
static func temple_hall(kits: MeshKitSet, xform: Transform3D, width: float, depth: float) -> void:
	kits.kit(&"stone_dark").box(xform * Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(width * 1.15, 1.2, depth * 1.2))
	kits.kit(&"wood").box(xform * Transform3D(Basis(), Vector3(0, 1.2 + width * 0.15, 0)), Vector3(width, width * 0.3, depth))
	kits.kit(&"window").box(xform * Transform3D(Basis(), Vector3(0, 1.2 + width * 0.14, depth * 0.5 + 0.05)), Vector3(width * 0.55, width * 0.12, 0.1))
	kits.kit(&"roof").roof(xform * Transform3D(Basis(), Vector3(0, 1.2 + width * 0.3, 0)), width * 0.68, depth * 0.72,
		width * 0.32, width * 0.08, 4, width * 0.03)


## A box-section beam along points (in xform's space), half-depth hw and
## half-height hh, with its top facing +Y.
static func _beam(kit: MeshKit, xform: Transform3D, points: PackedVector3Array, hw: float, hh: float) -> void:
	var count: int = points.size()
	# Each point's four corners: [-side -up, -side +up, +side -up, +side +up].
	var corners: Array[PackedVector3Array] = []
	for k: int in count:
		var t: Vector3 = points[mini(k + 1, count - 1)] - points[maxi(k - 1, 0)]
		t = t.normalized()
		var up: Vector3 = (Vector3.UP - t * t.dot(Vector3.UP)).normalized()
		var side: Vector3 = t.cross(up)
		var p: Vector3 = points[k]
		corners.append(PackedVector3Array([
			xform * (p - side * hw - up * hh), xform * (p - side * hw + up * hh),
			xform * (p + side * hw - up * hh), xform * (p + side * hw + up * hh),
		]))
	for k: int in count - 1:
		var a: PackedVector3Array = corners[k]
		var b: PackedVector3Array = corners[k + 1]
		kit.quad(a[1], b[1], b[3], a[3])  # top
		kit.quad(a[2], b[2], b[0], a[0])  # bottom
		kit.quad(a[3], b[3], b[2], a[2])  # +side
		kit.quad(a[0], b[0], b[1], a[1])  # -side
	var s: PackedVector3Array = corners[0]
	kit.quad(s[1], s[3], s[2], s[0])
	var e: PackedVector3Array = corners[count - 1]
	kit.quad(e[3], e[1], e[0], e[2])


static func _transform_points(xform: Transform3D, points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in points:
		out.append(xform * p)
	return out
