extends RefCounted
# Builds a katana mesh in code.
# Local frame: origin at the tsuba (blade side face), +Y = blade direction (toward the tip),
# +X = cutting edge direction, Z = X x Y. The blade curves toward -X (the back), edge on the convex side.
# Surfaces: 0 blade, 1 habaki, 2 tsuba, 3 tsuka (wrapped grip), 4 fittings (fuchi, kashira).

const BLADE_LEN := 0.74
const GRIP_LEN := 0.26
const TSUBA_T := 0.007

static func _blade_ring(s: float, scale_w: float = 1.0, scale_t: float = 1.0) -> Array:
	var w := lerpf(0.031, 0.025, s) * scale_w
	var t := lerpf(0.0078, 0.0055, s) * scale_t
	var xc := -0.02 * s * s
	var u := clampf((s - 0.9) / 0.1, 0.0, 1.0)
	var kf := sqrt(maxf(0.0, 1.0 - u * u))
	var tf := 1.0 - u * 0.85
	var back := xc - w * 0.45
	# (x from the back line, z, uv.x): edge, shinogi+, mune+, mune peak, mune-, shinogi-
	var prof := [[w, 0.0, 0.0], [0.30 * w, 0.5 * t, 0.7], [0.06 * w, 0.36 * t, 0.95], [0.0, 0.0, 1.0], [0.06 * w, -0.36 * t, 0.95], [0.30 * w, -0.5 * t, 0.7]]
	var pts := []
	for p in prof:
		pts.append([Vector3(back + p[0] * kf, 0.0, p[1] * tf), p[2]])
	return pts

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, outward: Vector3) -> void:
	# Godot front faces are clockwise; keep the normal pointing outward
	var n := (c - a).cross(b - a)
	if n.dot(outward) < 0.0:
		var tmp := b; b = c; c = tmp
		var tu := ub; ub = uc; uc = tu
		n = -n
	n = n.normalized()
	st.set_normal(n); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(n); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(n); st.set_uv(uc); st.add_vertex(c)

static func _ellipse_ring(y: float, rx: float, rz: float, seg: int) -> Array:
	var r := []
	for i in seg + 1:
		var an := TAU * i / seg
		r.append(Vector3(cos(an) * rx, y, sin(an) * rz))
	return r

static func _tube(st: SurfaceTool, rings: Array, vs: Array, seg: int, cap_bottom: bool, cap_top: bool) -> void:
	# smooth-shaded elliptic tube along Y
	for k in rings.size() - 1:
		var r0: Array = rings[k]; var r1: Array = rings[k + 1]
		for i in seg:
			var q := [r0[i], r0[i + 1], r1[i + 1], r1[i]]
			var uvq := [Vector2(i / float(seg), vs[k]), Vector2((i + 1) / float(seg), vs[k]), Vector2((i + 1) / float(seg), vs[k + 1]), Vector2(i / float(seg), vs[k + 1])]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = q[tri[0]]; var b: Vector3 = q[tri[1]]; var c: Vector3 = q[tri[2]]
				var ua: Vector2 = uvq[tri[0]]; var ub: Vector2 = uvq[tri[1]]; var uc: Vector2 = uvq[tri[2]]
				if (c - a).cross(b - a).dot(Vector3(a.x, 0, a.z)) < 0.0:
					var tmp := b; b = c; c = tmp
					var tu := ub; ub = uc; uc = tu
				for pv in [[a, ua], [b, ub], [c, uc]]:
					var p: Vector3 = pv[0]
					st.set_normal(Vector3(p.x, 0, p.z).normalized())
					st.set_uv(pv[1])
					st.add_vertex(p)
	for cap in [[cap_bottom, 0, -1.0], [cap_top, rings.size() - 1, 1.0]]:
		if not cap[0]:
			continue
		var r: Array = rings[cap[1]]
		var cy: float = r[0].y
		var ctr := Vector3(0, cy, 0)
		for i in seg:
			_tri(st, ctr, r[i], r[i + 1], Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), Vector3(0, cap[2], 0))

static func build_mesh(mats: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	# 0 blade (flat facets)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_seg := 48
	var rings := []
	for i in n_seg + 1:
		var s := i / float(n_seg)
		var r := _blade_ring(s)
		for p in r:
			p[0].y = 0.004 + s * (BLADE_LEN - 0.004)
		rings.append([r, s])
	for k in n_seg:
		var r0: Array = rings[k][0]; var r1: Array = rings[k + 1][0]
		var s0: float = rings[k][1]; var s1: float = rings[k + 1][1]
		var ctr: Vector3 = (r0[0][0] + r0[3][0]) * 0.5
		for j in 6:
			var j2 := (j + 1) % 6
			var a: Vector3 = r0[j][0]; var b: Vector3 = r0[j2][0]; var c: Vector3 = r1[j2][0]; var d: Vector3 = r1[j][0]
			var mid := (a + b + c + d) * 0.25
			var outward := mid - Vector3(ctr.x, mid.y, ctr.z)
			var ua := Vector2(r0[j][1], s0); var ub := Vector2(r0[j2][1], s0); var uc := Vector2(r1[j2][1], s1); var ud := Vector2(r1[j][1], s1)
			_tri(st, a, b, c, ua, ub, uc, outward)
			if (c - d).length() > 1e-6 or k < n_seg - 1:
				_tri(st, a, c, d, ua, uc, ud, outward)
	mesh = st.commit(mesh)
	# 1 habaki (brass collar around the blade base)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hb0 := _blade_ring(0.0, 1.35, 2.2)
	var hb1 := _blade_ring(0.0, 1.3, 1.9)
	var ha := []; var hbb := []
	for p in hb0: ha.append(p[0] + Vector3(0.001, 0.0, 0))
	for p in hb1: hbb.append(p[0] + Vector3(0.001, 0.034, 0))
	var hc: Vector3 = (ha[0] + ha[3]) * 0.5
	for j in 6:
		var j2 := (j + 1) % 6
		var outward: Vector3 = (ha[j] + ha[j2]) * 0.5 - hc
		outward.y = 0
		_tri(st, ha[j], ha[j2], hbb[j2], Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), outward)
		_tri(st, ha[j], hbb[j2], hbb[j], Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), outward)
		_tri(st, hbb[j], hbb[j2], Vector3(hc.x, 0.034, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.5), Vector3.UP)
	mesh = st.commit(mesh)
	# 2 tsuba (round guard, slightly oval)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tr := []
	for y in [-TSUBA_T, 0.0]:
		tr.append(_ellipse_ring(y, 0.041, 0.037, 40))
	_tube(st, tr, [0.0, 1.0], 40, true, true)
	# a raised rim
	var rim := [_ellipse_ring(-TSUBA_T - 0.0012, 0.0415, 0.0375, 40), _ellipse_ring(0.0012, 0.0415, 0.0375, 40)]
	_tube(st, rim, [0.0, 1.0], 40, false, false)
	mesh = st.commit(mesh)
	# 3 tsuka (wrapped grip): slightly waisted ellipse
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gr := []; var gv := []
	var gseg := 18
	for i in gseg + 1:
		var s := i / float(gseg)
		var y := -TSUBA_T - 0.012 - s * (GRIP_LEN - 0.03)
		var waist := sin(PI * s) * 0.0012
		gr.append(_ellipse_ring(y, 0.0158 - waist, 0.0125 - waist, 24))
		gv.append(s)
	_tube(st, gr, gv, 24, false, false)
	mesh = st.commit(mesh)
	# 4 fittings: fuchi (collar at the guard) and kashira (pommel cap)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st, [_ellipse_ring(-TSUBA_T - 0.013, 0.0166, 0.0133, 24), _ellipse_ring(-TSUBA_T, 0.0168, 0.0135, 24)], [0.0, 1.0], 24, false, false)
	var yk := -TSUBA_T - 0.012 - (GRIP_LEN - 0.03)
	_tube(st, [_ellipse_ring(yk - 0.016, 0.0150, 0.0118, 24), _ellipse_ring(yk + 0.001, 0.0163, 0.0130, 24)], [0.0, 1.0], 24, true, false)
	mesh = st.commit(mesh)
	# store an averaged (smooth) normal per position in COLOR for the inverted-hull outline,
	# because the blade facets have split normals that would tear the hull open
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(i)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var acc := {}
		for v in pos.size():
			var key := Vector3i((pos[v] * 20000.0).round())
			acc[key] = acc.get(key, Vector3.ZERO) + nrm[v]
		var cols := PackedColorArray()
		cols.resize(pos.size())
		for v in pos.size():
			var sn: Vector3 = (acc[Vector3i((pos[v] * 20000.0).round())] as Vector3).normalized()
			cols[v] = Color(sn.x * 0.5 + 0.5, sn.y * 0.5 + 0.5, sn.z * 0.5 + 0.5)
		arr[Mesh.ARRAY_COLOR] = cols
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(i, mats[i])
	return out

static func default_materials() -> Array:
	var blade := ShaderMaterial.new()
	blade.shader = load("res://src/shaders/blade.gdshader")
	var habaki := StandardMaterial3D.new()
	habaki.albedo_color = Color(0.72, 0.55, 0.25)
	habaki.metallic = 0.8
	habaki.roughness = 0.35
	var tsuba := StandardMaterial3D.new()
	tsuba.albedo_color = Color(0.09, 0.085, 0.08)
	tsuba.metallic = 0.6
	tsuba.roughness = 0.55
	var tsuka := ShaderMaterial.new()
	tsuka.shader = load("res://src/shaders/tsuka.gdshader")
	var fit := StandardMaterial3D.new()
	fit.albedo_color = Color(0.12, 0.1, 0.09)
	fit.metallic = 0.6
	fit.roughness = 0.45
	return [blade, habaki, tsuba, tsuka, fit]

static func build(mats: Array = []) -> MeshInstance3D:
	if mats.is_empty():
		mats = default_materials()
	var mi := MeshInstance3D.new()
	mi.name = "Katana"
	mi.mesh = build_mesh(mats)
	return mi
