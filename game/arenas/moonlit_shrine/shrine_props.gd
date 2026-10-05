class_name ShrineProps
extends RefCounted
## Procedural shrine props, each added to a MeshKitSet at a transform so many
## props share one mesh per material. Each prop function builds one kind that
## ShrineLayout.prop_scenes can replace with bought art (lantern, torii,
## pillar, pine, dead_tree, pagoda, temple_hall); the sacred rope is part of
## the gates.

const LANTERN_GLOW: Shader = preload("res://shaders/lantern_glow.gdshader")

## A stone lantern's fire, in the lantern's own space: the middle of its
## lit paper box. Bought lanterns keep their fire at the same height, since
## the lights and halos go there.
const LANTERN_FIRE := Vector3(0.0, 2.12, 0.0)


## Materials for every kit key the platform, its props and the backdrop's
## buildings use. outlined = false gives far scenery's, which never draw an
## outline.
static func materials(outlined: bool = true) -> Dictionary[StringName, Material]:
	var glow := ShaderMaterial.new()
	glow.shader = LANTERN_GLOW
	return {
		&"landing": ToonMaterials.prop(LookPalette.STONE_LIGHT, 0.4, outlined),
		&"parapet": ToonMaterials.prop(LookPalette.STONE, 0.35, outlined),
		&"stone": ToonMaterials.prop(LookPalette.STONE_LIGHT, 0.4, outlined),
		&"stone_dark": ToonMaterials.prop(LookPalette.STONE_DARK, 0.3, outlined),
		&"pebbles": ToonMaterials.prop(LookPalette.STONE_DARK, 0.3, false),
		&"lacquer": ToonMaterials.prop(LookPalette.LACQUER, 0.3, outlined),
		&"black_lacquer": ToonMaterials.prop(LookPalette.INK_SOFT, 0.0, outlined),
		&"rope": ToonMaterials.prop(LookPalette.ROPE, 0.25, outlined),
		&"paper": ToonMaterials.prop(LookPalette.PAPER, 0.0, false),
		&"bark": ToonMaterials.prop(LookPalette.WOOD_DARK, 0.2, outlined),
		&"pine": ToonMaterials.prop(LookPalette.PINE, 0.35, outlined),
		&"wood": ToonMaterials.prop(LookPalette.WOOD_DARK.lightened(0.05), 0.2, outlined),
		&"roof": ToonMaterials.prop(LookPalette.INK_SOFT.lightened(0.04), 0.1, outlined),
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


## A Japanese black pine: a twisted trunk leaning toward local +x, and flat
## cloud pads of needles.
static func pine(kits: MeshKitSet, xform: Transform3D, scale: float, rng: RandomNumberGenerator) -> void:
	var bark: MeshKit = kits.kit(&"bark")
	var needles: MeshKit = kits.kit(&"pine")
	var trunk := PackedVector3Array()
	var radii := PackedFloat32Array()
	var steps: int = 8
	var height: float = 5.0 * scale
	for k: int in steps + 1:
		var t: float = float(k) / steps
		var lean: float = 1.6 * scale * t * t
		trunk.append(Vector3(lean + sin(t * 5.0 + rng.randf()) * 0.25 * scale, t * height, cos(t * 4.0) * 0.3 * scale))
		radii.append(lerpf(0.26, 0.07, t) * scale)
	bark.tube(_transform_points(xform, trunk), radii, 8)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 1.4
	var pads: Array[Vector3] = [trunk[steps] + Vector3(0, 0.2 * scale, 0)]
	for k: int in range(3, steps):
		var base: Vector3 = trunk[k]
		var a: float = rng.randf_range(0, TAU)
		var length: float = rng.randf_range(1.0, 2.1) * scale * (1.2 - float(k) / steps)
		var tip: Vector3 = base + Vector3(cos(a) * length, rng.randf_range(-0.2, 0.4) * scale, sin(a) * length)
		var mid: Vector3 = base.lerp(tip, 0.5) + Vector3(0, 0.15 * scale, 0)
		bark.tube(_transform_points(xform, PackedVector3Array([base, mid, tip])),
			PackedFloat32Array([radii[k] * 0.55, radii[k] * 0.4, radii[k] * 0.25]), 6)
		pads.append(tip)
	for p: Vector3 in pads:
		var size: float = rng.randf_range(0.75, 1.15) * scale
		for j: int in 3:
			var off := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.05, 0.15), rng.randf_range(-0.5, 0.5)) * size
			needles.color = Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.25))
			var b := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(1.25, 0.36, 1.0) * size * (1.0 - j * 0.2))
			needles.sphere(xform * Transform3D(b, p + off), 1.0, 12, 6, noise, 0.18)


## A dead tree: a gnarled trunk splitting into bare branches.
static func dead_tree(kits: MeshKitSet, xform: Transform3D, scale: float, rng: RandomNumberGenerator) -> void:
	_branch(kits.kit(&"bark"), xform, Vector3.ZERO, Vector3(0.15, 1.0, 0.05).normalized(), 2.6 * scale, 0.22 * scale, 4, rng)


## One bent branch from start along dir, then 2 or 3 thinner ones from its
## end, depth more times.
static func _branch(kit: MeshKit, xform: Transform3D, start: Vector3, dir: Vector3, length: float, radius: float,
		depth: int, rng: RandomNumberGenerator) -> void:
	var bend := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.3, 0.3))
	var mid: Vector3 = start + (dir + bend * 0.5).normalized() * length * 0.5
	var end: Vector3 = mid + (dir + bend).normalized() * length * 0.5
	kit.tube(_transform_points(xform, PackedVector3Array([start, mid, end])),
		PackedFloat32Array([radius, radius * 0.8, radius * 0.6]), 6 if depth > 1 else 4)
	if depth <= 0:
		return
	var children: int = 2 if rng.randf() < 0.6 else 3
	var out_dir: Vector3 = (end - mid).normalized()
	for i: int in children:
		var axis := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		if axis == Vector3.ZERO:
			axis = Vector3.RIGHT
		var child_dir: Vector3 = out_dir.rotated(axis, rng.randf_range(0.35, 0.85))
		_branch(kit, xform, end, child_dir, length * rng.randf_range(0.55, 0.75), radius * 0.6, depth - 1, rng)


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
