extends SceneTree
## Builds the Katana model in code (the weapon pack has no katana) and writes
## res://weapons/katana/katana_mesh.res and res://weapons/katana/katana.tscn
## (the mesh plus its BladeBase, BladeTip and OffHandGrip markers).
##
## Run: node scripts/godot.mjs script res://tools/build_katana.gd
##
## The model, in weapon space (see WeaponLook): origin at the centre of the
## right hand's grip, +Y toward the tip, +X toward the edge.
## - Blade: 0.72 m from the guard, single-edged, curved in one smooth arc:
##   the centre line bends back (toward -X) by SORI * s^2 along its length
##   fraction s, so the edge is on the convex side and the arc's depth
##   against the straight line from guard to point (the sori) is SORI / 4,
##   about 1.8 cm, deepest at the middle. Shinogi-zukuri cross-section,
##   3.2 cm wide at the base tapering to 2.2 cm. The last KISSAKI metres are
##   the point section (kissaki): there the edge turns at a clear angle
##   (the yokote) and sweeps round (the fukura) to a point set slightly in
##   from the back, and the section thins, so the point reads as a stubby,
##   defined tip rather than a needle.
## - Habaki: a gold collar at the blade's base.
## - Tsuba: a round, slightly oval dark-iron guard with a bronze rim.
## - Tsuka: a 0.26 m grip (guard to pommel) with a dark wrap over ray skin,
##   a bronze collar (fuchi) at the guard and a small pommel cap (kashira).
##
## Surfaces: 0 blade, 1 habaki, 2 tsuba, 3 tsuba rim, 4 wrap, 5 fittings.

const MESH_PATH: String = "res://weapons/katana/katana_mesh.res"
const SCENE_PATH: String = "res://weapons/katana/katana.tscn"
const MATERIALS: Array[String] = [
	"res://weapons/katana/materials/blade.tres",
	"res://weapons/katana/materials/habaki.tres",
	"res://weapons/katana/materials/tsuba.tres",
	"res://weapons/katana/materials/tsuba_rim.tres",
	"res://weapons/katana/materials/wrap.tres",
	"res://weapons/katana/materials/fittings.tres",
]

const BLADE_LENGTH: float = 0.72
const GRIP_LENGTH: float = 0.26
## The tsuba's grip-side face, 5 cm above the right hand's centre.
const GUARD_Y: float = 0.05
const TSUBA_THICKNESS: float = 0.007
const HABAKI_LENGTH: float = 0.033
## How far the point sits behind the straight line of the grip.
const SORI: float = 0.07
const BLADE_WIDTH_BASE: float = 0.032
const BLADE_WIDTH_TIP: float = 0.022
const BLADE_THICKNESS_BASE: float = 0.0075
const BLADE_THICKNESS_TIP: float = 0.0052
## Centre of the left hand on a two-handed grip.
const OFF_HAND_Y: float = -0.15
## Length of the point section, and how sharply the edge turns where it
## starts (the slope of the edge line there, against the blade's width).
const KISSAKI: float = 0.05
const YOKOTE_TURN: float = 0.4
const BLADE_SEGMENTS: int = 40
const KISSAKI_SEGMENTS: int = 14

const BLADE_ROOT_Y: float = GUARD_Y + TSUBA_THICKNESS
const POMMEL_Y: float = GUARD_Y - GRIP_LENGTH


func _initialize() -> void:
	var mats: Array[Material] = []
	for path: String in MATERIALS:
		mats.append(load(path))
	var mesh: ArrayMesh = build_mesh(mats)
	var err: Error = ResourceSaver.save(mesh, MESH_PATH)
	if err != OK:
		printerr("build_katana: cannot save %s (%s)" % [MESH_PATH, error_string(err)])
		quit(1)
		return
	mesh.take_over_path(MESH_PATH)
	var root: Node3D = Node3D.new()
	root.name = &"Katana"
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = &"Mesh"
	mi.mesh = mesh
	root.add_child(mi)
	mi.owner = root
	var base_s: float = HABAKI_LENGTH / BLADE_LENGTH
	_add_marker(root, WeaponLook.BLADE_BASE, Vector3(blade_mid_x(base_s), BLADE_ROOT_Y + HABAKI_LENGTH, 0.0))
	_add_marker(root, WeaponLook.BLADE_TIP, tip_point())
	_add_marker(root, WeaponLook.OFF_HAND_GRIP, Vector3(0.0, OFF_HAND_Y, 0.0))
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	err = ResourceSaver.save(packed, SCENE_PATH)
	root.free()
	if err != OK:
		printerr("build_katana: cannot save %s (%s)" % [SCENE_PATH, error_string(err)])
		quit(1)
		return
	var tris: int = 0
	for s: int in mesh.get_surface_count():
		tris += mesh.surface_get_array_len(s) / 3
	print("build_katana: %d triangles; saved %s and %s" % [tris, MESH_PATH, SCENE_PATH])
	quit(0)


static func _add_marker(root: Node3D, marker_name: StringName, pos: Vector3) -> void:
	var m: Marker3D = Marker3D.new()
	m.name = marker_name
	m.position = pos
	root.add_child(m)
	m.owner = root


## Length fraction where the point section starts.
static func yokote_s() -> float:
	return 1.0 - KISSAKI / BLADE_LENGTH


static func blade_width(s: float) -> float:
	return lerpf(BLADE_WIDTH_BASE, BLADE_WIDTH_TIP, minf(s / yokote_s(), 1.0))


## The point, in weapon space.
static func tip_point() -> Vector3:
	var p: Array[Array] = blade_section(1.0)
	return (p[0][0] as Vector3) + Vector3(0.0, BLADE_ROOT_Y + BLADE_LENGTH, 0.0)


## X of the blade's back (mune) at length fraction s.
static func blade_back_x(s: float) -> float:
	return -SORI * s * s - 0.45 * blade_width(s)


static func blade_mid_x(s: float) -> float:
	return blade_back_x(s) + 0.5 * blade_width(s)


## The blade's cross-section at length fraction s: [position, uv.x] pairs,
## from the edge round the back. uv.x is 0 at the edge and 1 at the back.
static func blade_section(s: float, width_scale: float = 1.0, thickness_scale: float = 1.0) -> Array[Array]:
	var w: float = blade_width(s) * width_scale
	var t: float = lerpf(BLADE_THICKNESS_BASE, BLADE_THICKNESS_TIP, s) * thickness_scale
	# In the point section (u from 0 at the yokote to 1 at the point) the
	# edge turns in at YOKOTE_TURN and sweeps round to meet the back, which
	# leans a little toward the edge; the ridge runs out and the section thins.
	var u: float = clampf((s - yokote_s()) / (1.0 - yokote_s()), 0.0, 1.0)
	var edge: float = 1.0 - YOKOTE_TURN * u - (1.0 - YOKOTE_TURN) * pow(u, 2.6)
	var lean: float = 0.12 * u * u
	var thin: float = 1.0 - 0.65 * u - 0.35 * u * u * u
	# A wider section (the habaki) stays centred on the blade.
	var back: float = blade_back_x(s) - 0.5 * (w - blade_width(s)) + lean * w
	var edge_d: float = maxf((edge - lean) * w, 0.0)
	var ridge_d: float = minf(0.30 * (1.0 - 0.6 * u) * w, edge_d)
	var spine_d: float = minf(0.06 * w, edge_d)
	# (distance from the back, thickness offset, uv.x)
	var profile: Array[Vector3] = [
		Vector3(edge_d, 0.0, 0.0), Vector3(ridge_d, 0.5 * t * thin, 0.7), Vector3(spine_d, 0.36 * t * thin, 0.95),
		Vector3(0.0, 0.0, 1.0), Vector3(spine_d, -0.36 * t * thin, 0.95), Vector3(ridge_d, -0.5 * t * thin, 0.7),
	]
	var out: Array[Array] = []
	for p: Vector3 in profile:
		out.append([Vector3(back + p.x, 0.0, p.y), p.z])
	return out


static func build_mesh(mats: Array[Material]) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh = _blade(mesh)
	mesh = _habaki(mesh)
	# Tsuba plate and its raised rim.
	var st: SurfaceTool = _begin()
	_tube(st, [_ellipse(GUARD_Y, 0.041, 0.037, 40), _ellipse(GUARD_Y + TSUBA_THICKNESS, 0.041, 0.037, 40)], [0.0, 1.0], true, true)
	mesh = st.commit(mesh)
	st = _begin()
	_tube(st, [_ellipse(GUARD_Y - 0.0012, 0.0416, 0.0376, 40), _ellipse(GUARD_Y + TSUBA_THICKNESS + 0.0012, 0.0416, 0.0376, 40)], [0.0, 1.0], false, false)
	mesh = st.commit(mesh)
	# Wrapped grip, slightly waisted.
	st = _begin()
	var rings: Array[PackedVector3Array] = []
	var vs: Array[float] = []
	var top: float = GUARD_Y - 0.012
	var bottom: float = POMMEL_Y + 0.015
	for i: int in 19:
		var f: float = i / 18.0
		var waist: float = sin(PI * f) * 0.0012
		rings.append(_ellipse(lerpf(top, bottom, f), 0.0158 - waist, 0.0125 - waist, 24))
		vs.append(f)
	_tube(st, rings, vs, false, false)
	mesh = st.commit(mesh)
	# Fittings: fuchi at the guard, kashira capping the pommel.
	st = _begin()
	_tube(st, [_ellipse(GUARD_Y - 0.013, 0.0166, 0.0133, 24), _ellipse(GUARD_Y, 0.0168, 0.0135, 24)], [0.0, 1.0], false, false)
	_tube(st, [_ellipse(POMMEL_Y, 0.0150, 0.0118, 24), _ellipse(POMMEL_Y + 0.017, 0.0163, 0.0130, 24)], [0.0, 1.0], true, false)
	mesh = st.commit(mesh)
	for i: int in mesh.get_surface_count():
		mesh.surface_set_material(i, mats[i])
		mesh.surface_set_name(i, mats[i].resource_name)
	return mesh


static func _begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _blade(mesh: ArrayMesh) -> ArrayMesh:
	var st: SurfaceTool = _begin()
	var rings: Array[Array] = []
	var stations: Array[float] = []
	for i: int in BLADE_SEGMENTS:
		stations.append(yokote_s() * i / BLADE_SEGMENTS)
	for i: int in KISSAKI_SEGMENTS + 1:
		stations.append(lerpf(yokote_s(), 1.0, i / float(KISSAKI_SEGMENTS)))
	for s: float in stations:
		var ring: Array[Array] = blade_section(s)
		for p: Array in ring:
			p[0] = (p[0] as Vector3) + Vector3(0.0, BLADE_ROOT_Y - 0.003 + s * (BLADE_LENGTH + 0.003), 0.0)
		rings.append(ring)
	for k: int in rings.size() - 1:
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		var s0: float = stations[k]
		var s1: float = stations[k + 1]
		var centre: Vector3 = ((r0[0][0] as Vector3) + (r0[3][0] as Vector3)) * 0.5
		for j: int in 6:
			var j2: int = (j + 1) % 6
			var a: Vector3 = r0[j][0]
			var b: Vector3 = r0[j2][0]
			var c: Vector3 = r1[j2][0]
			var d: Vector3 = r1[j][0]
			var mid: Vector3 = (a + b + c + d) * 0.25
			var outward: Vector3 = mid - Vector3(centre.x, mid.y, centre.z)
			var ua: Vector2 = Vector2(r0[j][1], s0)
			var ub: Vector2 = Vector2(r0[j2][1], s0)
			var uc: Vector2 = Vector2(r1[j2][1], s1)
			var ud: Vector2 = Vector2(r1[j][1], s1)
			_tri(st, a, b, c, ua, ub, uc, outward)
			if (c - d).length() > 1e-6 or k < rings.size() - 2:
				_tri(st, a, c, d, ua, uc, ud, outward)
	return st.commit(mesh)


static func _habaki(mesh: ArrayMesh) -> ArrayMesh:
	var st: SurfaceTool = _begin()
	var lower: Array[Array] = blade_section(0.0, 1.35, 2.2)
	var upper: Array[Array] = blade_section(0.0, 1.3, 1.9)
	var a_ring: Array[Vector3] = []
	var b_ring: Array[Vector3] = []
	for p: Array in lower:
		a_ring.append((p[0] as Vector3) + Vector3(0.001, BLADE_ROOT_Y, 0.0))
	for p: Array in upper:
		b_ring.append((p[0] as Vector3) + Vector3(0.001, BLADE_ROOT_Y + HABAKI_LENGTH, 0.0))
	var centre: Vector3 = (a_ring[0] + a_ring[3]) * 0.5
	var top_centre: Vector3 = Vector3(centre.x, BLADE_ROOT_Y + HABAKI_LENGTH, 0.0)
	for j: int in 6:
		var j2: int = (j + 1) % 6
		var outward: Vector3 = (a_ring[j] + a_ring[j2]) * 0.5 - centre
		outward.y = 0.0
		_tri(st, a_ring[j], a_ring[j2], b_ring[j2], Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), outward)
		_tri(st, a_ring[j], b_ring[j2], b_ring[j], Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), outward)
		_tri(st, b_ring[j], b_ring[j2], top_centre, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.5), Vector3.UP)
	return st.commit(mesh)


## Adds a flat-shaded triangle facing `outward` (Godot's front faces wind
## clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, outward: Vector3) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.dot(outward) < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		var tu: Vector2 = ub
		ub = uc
		uc = tu
		n = -n
	n = n.normalized()
	for pair: Array in [[a, ua], [b, ub], [c, uc]]:
		st.set_normal(n)
		st.set_uv(pair[1])
		st.add_vertex(pair[0])


## A ring of seg+1 points (the last repeats the first) around the Y axis.
static func _ellipse(y: float, rx: float, rz: float, seg: int) -> PackedVector3Array:
	var ring: PackedVector3Array = PackedVector3Array()
	for i: int in seg + 1:
		var an: float = TAU * i / seg
		ring.append(Vector3(cos(an) * rx, y, sin(an) * rz))
	return ring


## A smooth-shaded tube through the rings, with optional flat end caps.
static func _tube(st: SurfaceTool, rings: Array, vs: Array, cap_first: bool, cap_last: bool) -> void:
	var seg: int = (rings[0] as PackedVector3Array).size() - 1
	for k: int in rings.size() - 1:
		var r0: PackedVector3Array = rings[k]
		var r1: PackedVector3Array = rings[k + 1]
		for i: int in seg:
			var q: Array[Vector3] = [r0[i], r0[i + 1], r1[i + 1], r1[i]]
			var uvq: Array[Vector2] = [
				Vector2(i / float(seg), vs[k]), Vector2((i + 1) / float(seg), vs[k]),
				Vector2((i + 1) / float(seg), vs[k + 1]), Vector2(i / float(seg), vs[k + 1]),
			]
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				var a: int = tri[0]
				var b: int = tri[1]
				var c: int = tri[2]
				if (q[c] - q[a]).cross(q[b] - q[a]).dot(Vector3(q[a].x, 0.0, q[a].z)) < 0.0:
					var tmp: int = b
					b = c
					c = tmp
				for v: int in [a, b, c]:
					st.set_normal(Vector3(q[v].x, 0.0, q[v].z).normalized())
					st.set_uv(uvq[v])
					st.add_vertex(q[v])
	for cap: Array in [[cap_first, 0, -1.0], [cap_last, rings.size() - 1, 1.0]]:
		if not cap[0]:
			continue
		var r: PackedVector3Array = rings[cap[1]]
		var centre: Vector3 = Vector3(0.0, r[0].y, 0.0)
		for i: int in seg:
			_tri(st, centre, r[i], r[i + 1], Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), Vector3(0.0, cap[2], 0.0))
