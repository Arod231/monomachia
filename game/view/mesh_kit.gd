class_name MeshKit
extends RefCounted
## Builds static meshes from simple shapes (boxes, discs, cylinders, lathes,
## tubes, tori, spheres and noisy rocks, curved roofs, free grids) into one
## ArrayMesh, so a prop made of many parts is a single draw call. Every piece
## carries a vertex colour, for materials with use_vertex_color.
##
## Front faces are clockwise, as Godot expects. A mirroring transform (negative
## determinant) would turn them inside out, so builders don't use one.
## commit(true) also bakes smoothed normals into CUSTOM0 for the outline
## shader, so hard-edged pieces (boxes, stepped lanterns) get an unbroken
## inverted-hull line.
##
## Usage:
##   var kit := MeshKit.new()
##   kit.color = Color(0.42, 0.4, 0.38)
##   kit.box(Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(1, 1, 1))
##   var mesh: ArrayMesh = kit.commit(true)

## Positions that round to the same point of this grid (2 mm) share one
## smoothed outline normal.
const WELD_STEPS_PER_METRE: float = 500.0
## The furthest a hull may push a vertex, in outline widths. A box corner
## needs sqrt(3); a sharper edge would need more and would spike.
const MAX_MITER: float = 3.0

var color: Color = Color.WHITE
var _st: SurfaceTool
var _count: int = 0


func _init() -> void:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## True until a shape adds a triangle.
func is_empty() -> bool:
	return _count == 0


## One triangle, clockwise seen from the front. Normals given per vertex.
func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		uva: Vector2 = Vector2.ZERO, uvb: Vector2 = Vector2.ZERO, uvc: Vector2 = Vector2.ZERO) -> void:
	_vertex(a, na, uva, color)
	_vertex(b, nb, uvb, color)
	_vertex(c, nc, uvc, color)


## A flat quad a-b-c-d, clockwise seen from the front.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		n = (d - a).cross(c - a)
	n = n.normalized()
	tri(a, b, c, n, n, n, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
	tri(a, c, d, n, n, n, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))


## A box of the given size centred on xform.origin.
func box(xform: Transform3D, size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	var p: Array[Vector3] = []
	for i: int in 8:
		var v := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		p.append(xform * v)
	# corners: bit0 = +x, bit1 = +y, bit2 = +z
	quad(p[2], p[3], p[7], p[6])  # top
	quad(p[4], p[5], p[1], p[0])  # bottom
	quad(p[6], p[7], p[5], p[4])  # +z
	quad(p[3], p[2], p[0], p[1])  # -z
	quad(p[7], p[3], p[1], p[5])  # +x
	quad(p[2], p[6], p[4], p[0])  # -x


## A flat disc (or ring, with inner_radius) facing local +y, split into rings
## so long-distance fog and vertex varyings stay smooth.
func disc(xform: Transform3D, radius: float, segments: int = 64, rings: int = 4, inner_radius: float = 0.0) -> void:
	for j: int in rings:
		var r0: float = lerpf(inner_radius, radius, float(j) / rings)
		var r1: float = lerpf(inner_radius, radius, float(j + 1) / rings)
		for i: int in segments:
			var a0: float = TAU * i / segments
			var a1: float = TAU * (i + 1) / segments
			var v00: Vector3 = xform * Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var v01: Vector3 = xform * Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var v10: Vector3 = xform * Vector3(cos(a0) * r1, 0, sin(a0) * r1)
			var v11: Vector3 = xform * Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			quad(v00, v10, v11, v01)


## A capped, smooth-shaded cylinder or frustum standing on xform.origin,
## height along local +y.
func cylinder(xform: Transform3D, r_bottom: float, r_top: float, height: float, segments: int = 12) -> void:
	lathe(xform, PackedVector2Array([Vector2(r_bottom, 0.0), Vector2(r_top, height)]), segments)


## A surface of revolution. profile holds (radius, y) points from bottom to top.
## caps closes the bottom and top with discs when the end radius is > 0.
func lathe(xform: Transform3D, profile: PackedVector2Array, segments: int = 16, caps: bool = true,
		smooth: bool = true) -> void:
	var rings: int = profile.size()
	var basis_n: Basis = xform.basis.inverse().transposed()
	for j: int in rings - 1:
		var p0: Vector2 = profile[j]
		var p1: Vector2 = profile[j + 1]
		var slope := Vector2(p1.y - p0.y, -(p1.x - p0.x)).normalized()  # (radial, y) outward normal
		for i: int in segments:
			var a0: float = TAU * i / segments
			var a1: float = TAU * (i + 1) / segments
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v10 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v01 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var n00: Vector3
			var n10: Vector3
			if smooth:
				n00 = Vector3(cos(a0) * slope.x, slope.y, sin(a0) * slope.x)
				n10 = Vector3(cos(a1) * slope.x, slope.y, sin(a1) * slope.x)
			else:
				var am: float = (a0 + a1) * 0.5
				n00 = Vector3(cos(am) * slope.x, slope.y, sin(am) * slope.x)
				n10 = n00
			var w00: Vector3 = xform * v00
			var w10: Vector3 = xform * v10
			var w01: Vector3 = xform * v01
			var w11: Vector3 = xform * v11
			var m00: Vector3 = (basis_n * n00).normalized()
			var m10: Vector3 = (basis_n * n10).normalized()
			var u0: float = float(i) / segments
			var u1: float = float(i + 1) / segments
			tri(w00, w11, w01, m00, m10, m00, Vector2(u0, p0.y), Vector2(u1, p1.y), Vector2(u0, p1.y))
			tri(w00, w10, w11, m00, m10, m10, Vector2(u0, p0.y), Vector2(u1, p0.y), Vector2(u1, p1.y))
	if caps:
		var bottom: Vector2 = profile[0]
		var top: Vector2 = profile[rings - 1]
		if bottom.x > 0.0001:
			_cap(xform, bottom.x, bottom.y, segments, false)
		if top.x > 0.0001:
			_cap(xform, top.x, top.y, segments, true)


## A lathe's flat end: a disc of radius r at height y, facing up or down.
func _cap(xform: Transform3D, r: float, y: float, segments: int, up: bool) -> void:
	var n: Vector3 = (xform.basis.inverse().transposed() * (Vector3.UP if up else Vector3.DOWN)).normalized()
	var c: Vector3 = xform * Vector3(0, y, 0)
	for i: int in segments:
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		var v0: Vector3 = xform * Vector3(cos(a0) * r, y, sin(a0) * r)
		var v1: Vector3 = xform * Vector3(cos(a1) * r, y, sin(a1) * r)
		if up:
			tri(c, v0, v1, n, n, n)
		else:
			tri(c, v1, v0, n, n, n)


## An open tube along a polyline, with a radius per point (tapers, roots, rope).
func tube(points: PackedVector3Array, radii: PackedFloat32Array, segments: int = 6) -> void:
	var count: int = points.size()
	if count < 2:
		return
	var frames: Array[Basis] = []
	var side := Vector3.ZERO
	var last_t := Vector3.ZERO
	for k: int in count:
		# Each ring halves the angle at its joint (a mitre), so a short segment
		# beside a long one isn't squashed flat.
		var into: Vector3 = (points[k] - points[k - 1]).normalized() if k > 0 else Vector3.ZERO
		var onward: Vector3 = (points[k + 1] - points[k]).normalized() if k < count - 1 else Vector3.ZERO
		var t: Vector3 = (into + onward).normalized()
		if k == 0:
			side = (Vector3.RIGHT if absf(t.y) > 0.95 else Vector3.UP).cross(t).normalized()
		else:
			# Carry the frame round each bend by the smallest rotation, so the
			# tube never twists or pinches, however sharp the turn.
			side = (Quaternion(last_t, t) * side).normalized()
		frames.append(Basis(side, t.cross(side).normalized(), t))
		last_t = t
	for k: int in count - 1:
		var b0: Basis = frames[k]
		var b1: Basis = frames[k + 1]
		for i: int in segments:
			var a0: float = TAU * i / segments
			var a1: float = TAU * (i + 1) / segments
			var d00: Vector3 = b0.x * cos(a0) + b0.y * sin(a0)
			var d10: Vector3 = b0.x * cos(a1) + b0.y * sin(a1)
			var d01: Vector3 = b1.x * cos(a0) + b1.y * sin(a0)
			var d11: Vector3 = b1.x * cos(a1) + b1.y * sin(a1)
			var v00: Vector3 = points[k] + d00 * radii[k]
			var v10: Vector3 = points[k] + d10 * radii[k]
			var v01: Vector3 = points[k + 1] + d01 * radii[k + 1]
			var v11: Vector3 = points[k + 1] + d11 * radii[k + 1]
			tri(v00, v01, v11, d00, d01, d11)
			tri(v00, v11, v10, d00, d11, d10)


## A torus lying in the local xz plane.
func torus(xform: Transform3D, ring_radius: float, tube_radius: float, segments: int = 16, sides: int = 6) -> void:
	var basis_n: Basis = xform.basis.inverse().transposed()
	for i: int in segments:
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		for j: int in sides:
			var b0: float = TAU * j / sides
			var b1: float = TAU * (j + 1) / sides
			var pts: Array[Vector3] = []
			var nrm: Array[Vector3] = []
			for ab: Vector2 in [Vector2(a0, b0), Vector2(a1, b0), Vector2(a1, b1), Vector2(a0, b1)]:
				var dir := Vector3(cos(ab.x), 0.0, sin(ab.x))
				var n: Vector3 = dir * cos(ab.y) + Vector3.UP * sin(ab.y)
				pts.append(xform * (dir * ring_radius + n * tube_radius))
				nrm.append((basis_n * n).normalized())
			tri(pts[0], pts[1], pts[2], nrm[0], nrm[1], nrm[2])
			tri(pts[0], pts[2], pts[3], nrm[0], nrm[2], nrm[3])


## A UV sphere (scale the transform for ellipsoids). noise displaces the
## surface along the normal by up to noise_amount (for rocks and foliage).
func sphere(xform: Transform3D, radius: float, segments: int = 12, rings: int = 8,
		noise: FastNoiseLite = null, noise_amount: float = 0.0) -> void:
	var grid: Array[PackedVector3Array] = []
	for j: int in rings + 1:
		var row := PackedVector3Array()
		var phi: float = PI * j / rings
		for i: int in segments + 1:
			var theta: float = TAU * (i % segments) / segments
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var r: float = radius
			if noise != null:
				r += noise.get_noise_3dv(xform * (d * radius)) * noise_amount
			row.append(d * r)
		grid.append(row)
	grid_surface(xform, grid, true)


## Adds a grid of local points as a smooth-shaded surface: rows of equal
## length, with normals from each point's neighbours. With closed_u each row
## wraps round, its last point repeating its first. colors, if given, holds
## one colour per point; otherwise the kit's colour is used. Builders that
## compute their own lattice (the crag, the cloud sea) call it too.
func grid_surface(xform: Transform3D, grid: Array[PackedVector3Array], closed_u: bool,
		colors: Array[PackedColorArray] = []) -> void:
	var rows: int = grid.size()
	var cols: int = grid[0].size()
	var normals: Array[PackedVector3Array] = []
	for j: int in rows:
		var nrow := PackedVector3Array()
		for i: int in cols:
			var il: int = i - 1
			var ir: int = i + 1
			if closed_u:
				il = (i - 1 + cols - 1) % (cols - 1)
				ir = (i + 1) % (cols - 1)
			else:
				il = maxi(il, 0)
				ir = mini(ir, cols - 1)
			var ju: int = maxi(j - 1, 0)
			var jd: int = mini(j + 1, rows - 1)
			var du: Vector3 = grid[j][ir] - grid[j][il]
			var dv: Vector3 = grid[jd][i] - grid[ju][i]
			# At a pole (a row collapsed to one point) borrow the next row's du.
			if du.length_squared() < 1e-12:
				du = grid[jd][ir] - grid[jd][il]
			if du.length_squared() < 1e-12:
				du = grid[ju][ir] - grid[ju][il]
			var n: Vector3 = du.cross(dv)
			if n.length_squared() < 1e-12:
				n = Vector3.UP
			nrow.append(n.normalized())
		normals.append(nrow)
	var basis_n: Basis = xform.basis.inverse().transposed()
	for j: int in rows - 1:
		for i: int in cols - 1:
			var a: Vector3 = xform * grid[j][i]
			var b: Vector3 = xform * grid[j][i + 1]
			var c: Vector3 = xform * grid[j + 1][i + 1]
			var d: Vector3 = xform * grid[j + 1][i]
			var na: Vector3 = (basis_n * normals[j][i]).normalized()
			var nb: Vector3 = (basis_n * normals[j][i + 1]).normalized()
			var nc: Vector3 = (basis_n * normals[j + 1][i + 1]).normalized()
			var nd: Vector3 = (basis_n * normals[j + 1][i]).normalized()
			var uv_a := Vector2(float(i) / (cols - 1), float(j) / (rows - 1))
			var uv_c := Vector2(float(i + 1) / (cols - 1), float(j + 1) / (rows - 1))
			var uv_b := Vector2(uv_c.x, uv_a.y)
			var uv_d := Vector2(uv_a.x, uv_c.y)
			var ca: Color = color
			var cb: Color = color
			var cc: Color = color
			var cd: Color = color
			if not colors.is_empty():
				ca = colors[j][i]
				cb = colors[j][i + 1]
				cc = colors[j + 1][i + 1]
				cd = colors[j + 1][i]
			_vertex(a, na, uv_a, ca)
			_vertex(c, nc, uv_c, cc)
			_vertex(b, nb, uv_b, cb)
			_vertex(a, na, uv_a, ca)
			_vertex(d, nd, uv_d, cd)
			_vertex(c, nc, uv_c, cc)


## A hip roof with a concave profile and upturned corners, like a pagoda or
## stone-lantern roof. Base square of half-size half_w x half_d at y = 0,
## apex at y = height; the eaves lift by uplift at the corners.
func roof(xform: Transform3D, half_w: float, half_d: float, height: float, uplift: float = 0.2,
		steps: int = 5, thickness: float = 0.08) -> void:
	var sides: Array[Array] = [
		[Vector3(-half_w, 0, half_d), Vector3(half_w, 0, half_d)],
		[Vector3(half_w, 0, half_d), Vector3(half_w, 0, -half_d)],
		[Vector3(half_w, 0, -half_d), Vector3(-half_w, 0, -half_d)],
		[Vector3(-half_w, 0, -half_d), Vector3(-half_w, 0, half_d)],
	]
	var apex := Vector3(0, height, 0)
	var ridge: float = maxf(half_w - half_d, 0.0)
	var cols: int = 6
	for side: Array in sides:
		var e0: Vector3 = side[0]
		var e1: Vector3 = side[1]
		var grid: Array[PackedVector3Array] = []
		for j: int in steps + 1:
			var v: float = float(j) / steps
			var row := PackedVector3Array()
			for i: int in cols + 1:
				var u: float = float(i) / cols
				var e: Vector3 = e0.lerp(e1, u)
				# The apex stretches into a ridge on long roofs.
				var top := Vector3(clampf(e.x, -ridge, ridge), height, 0.0) if half_w >= half_d else apex
				var p: Vector3 = e.lerp(top, v)
				# Concave profile: the roof sags between eave and apex.
				p.y = height * pow(v, 1.7) + _eave_lift(u, uplift) * (1.0 - v)
				row.append(p)
			grid.append(row)
		grid_surface(xform, grid, false)
	# Underside, so the roof reads solid from below.
	var a: Vector3 = xform * Vector3(-half_w, -thickness, half_d)
	var b: Vector3 = xform * Vector3(half_w, -thickness, half_d)
	var c: Vector3 = xform * Vector3(half_w, -thickness, -half_d)
	var d: Vector3 = xform * Vector3(-half_w, -thickness, -half_d)
	quad(a, b, c, d)
	# Eave fascia strips.
	for side: Array in sides:
		var e0: Vector3 = side[0]
		var e1: Vector3 = side[1]
		for i: int in cols:
			var u0: float = float(i) / cols
			var u1: float = float(i + 1) / cols
			var p0: Vector3 = e0.lerp(e1, u0)
			var p1: Vector3 = e0.lerp(e1, u1)
			quad(xform * (p0 + Vector3(0, _eave_lift(u0, uplift), 0)), xform * (p1 + Vector3(0, _eave_lift(u1, uplift), 0)),
				xform * (p1 + Vector3(0, -thickness, 0)), xform * (p0 + Vector3(0, -thickness, 0)))


## How far a roof's eave lifts at u along one side: uplift at the corners
## (u = 0 and 1), nothing at the middle.
static func _eave_lift(u: float, uplift: float) -> float:
	return uplift * pow(absf(u * 2.0 - 1.0), 3.0)


func _vertex(v: Vector3, n: Vector3, uv: Vector2, c: Color) -> void:
	_st.set_color(c)
	_st.set_normal(n)
	_st.set_uv(uv)
	_st.add_vertex(v)
	_count += 1


## Finishes the mesh. With outline_normals, smoothed normals are baked into
## CUSTOM0 for the outline shader.
func commit(outline_normals: bool = false) -> ArrayMesh:
	var m: ArrayMesh = _st.commit()
	if outline_normals and m.get_surface_count() > 0:
		m = _with_outline_normals(m)
	return m


## Returns a copy of mesh whose surfaces carry smoothed normals in CUSTOM0.
## xyz is the direction to push each position: the sum of the distinct
## normals met there, so a face split into more triangles doesn't pull it its
## way. w is how far to push, in outline widths, so that every face there
## moves out by the whole width (sqrt(3) at a box corner), at most MAX_MITER.
## Made for MeshKit's own static meshes: blend shapes and skinning flags are
## not carried over.
static func _with_outline_normals(source: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var distinct: Dictionary[Vector3i, PackedVector3Array] = {}
		for i: int in verts.size():
			var key: Vector3i = _weld_key(verts[i])
			var found: PackedVector3Array = distinct.get(key, PackedVector3Array())
			var known: bool = false
			for m: Vector3 in found:
				known = known or m.dot(norms[i]) > 0.9999
			if not known:
				found.append(norms[i])
				distinct[key] = found
		var pushes: Dictionary[Vector3i, Vector4] = {}
		for key: Vector3i in distinct:
			var sum := Vector3.ZERO
			for m: Vector3 in distinct[key]:
				sum += m
			var dir: Vector3 = sum.normalized()
			# The face the direction leans away from most needs the longest push.
			var least: float = 1.0
			for m: Vector3 in distinct[key]:
				least = minf(least, dir.dot(m))
			var miter: float = MAX_MITER if least * MAX_MITER <= 1.0 else 1.0 / least
			pushes[key] = Vector4(dir.x, dir.y, dir.z, miter)
		var custom := PackedFloat32Array()
		custom.resize(verts.size() * 4)
		for i: int in verts.size():
			var push: Vector4 = pushes[_weld_key(verts[i])]
			if Vector3(push.x, push.y, push.z) == Vector3.ZERO:
				# Opposite faces cancelled out: push along this one alone.
				push = Vector4(norms[i].x, norms[i].y, norms[i].z, 1.0)
			custom[i * 4] = push.x
			custom[i * 4 + 1] = push.y
			custom[i * 4 + 2] = push.z
			custom[i * 4 + 3] = push.w
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		var flags: int = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(s, source.surface_get_material(s))
	return out


static func _weld_key(v: Vector3) -> Vector3i:
	return Vector3i((v * WELD_STEPS_PER_METRE).round())


## A MultiMeshInstance3D drawing mesh at every transform, tinted by colors
## when there is one per transform.
static func multimesh(source: Mesh, transforms: Array[Transform3D], material: Material,
		colors: PackedColorArray = PackedColorArray()) -> MultiMeshInstance3D:
	if not colors.is_empty() and colors.size() != transforms.size():
		push_error("MeshKit.multimesh: %d transforms but %d colours" % [transforms.size(), colors.size()])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() == transforms.size() and not colors.is_empty()
	mm.mesh = source
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	return node


## A MeshInstance3D for mesh with material, casting shadows or not.
static func instance(source: Mesh, material: Material, cast_shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = source
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
