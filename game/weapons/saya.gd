class_name Saya
extends MeshInstance3D
## The Katana's saya (authored-animation task 11, from godot-rebuild 14.16):
## a black lacquered scabbard built in code around the blade it holds. Its
## frame is the sheathed katana's (grip at the origin, blade +Y, edge +X;
## see WeaponLook), so placing the katana at the saya's transform puts the
## blade inside it. FighterModel makes one whenever the Katana is the weapon
## and FighterRig carries it at the left hip (FRAMES), riding the hips.
##
## The shape follows the blade: the weapon's vertices from the blade's base
## to its tip are cut into slices along it, and each slice's outline, grown
## by WALL, is a ring of the saya, closed past the tip.

## Where the saya sits on each fighter, in their Hips bone's frame: the
## katana's frame as the sheathe clip (SheatheHips01_R, frame 12, the blade
## all the way in) leaves it on each body, measured with the weapon fixed in
## the hand (tools: _scratch probes; the numbers are ours, not the pack's),
## each offset grown on KE task 3's taller bodies by as much as the same
## probe's hand moved (the turns kept).
## A fighter without its own uses the Hunter's.
const FRAMES: Dictionary[StringName, Transform3D] = {
	&"hunter": Transform3D(Basis(Vector3(0.2321, -0.7617, 0.6049), Vector3(0.2295, -0.5614, -0.7951), Vector3(0.9452, 0.3234, 0.0445)), Vector3(0.1923, 0.2124, 0.3250)),
	&"rogue": Transform3D(Basis(Vector3(0.2321, -0.7617, 0.6049), Vector3(0.2295, -0.5614, -0.7951), Vector3(0.9452, 0.3234, 0.0445)), Vector3(0.2584, 0.2025, 0.3371)),
}
## How far the saya stands off the blade on every side (m).
const WALL: float = 0.006
## How far it runs past the tip (m), and how far it starts below the blade's
## base, over the habaki (m).
const PAST_TIP: float = 0.02
const OVER_BASE: float = 0.01
## Slices along the blade, and sides of each ring.
const SLICES: int = 24
const SIDES: int = 10
const LACQUER: Color = Color(0.06, 0.05, 0.05)


## The saya for `weapon` (an instance of the Katana's WeaponLook): its mesh
## grown from the blade's vertices, between its blade markers.
static func build(weapon: Node3D) -> Saya:
	var saya: Saya = Saya.new()
	saya.name = &"Saya"
	saya.layers = 1 | LookPalette.FIGHTER_LAYER
	var segment: PackedVector3Array = WeaponLook.blade_segment(weapon)
	var base: Vector3 = segment[0] - (segment[1] - segment[0]).normalized() * OVER_BASE
	var tip: Vector3 = segment[1]
	var axis: Vector3 = (tip - base).normalized()
	var span: float = base.distance_to(tip)
	var side: Vector3 = (Vector3.RIGHT - axis * Vector3.RIGHT.dot(axis)).normalized()
	var flat: Vector3 = axis.cross(side)
	# each slice's extent across the blade (side) and through it (flat)
	var lo: PackedVector2Array = PackedVector2Array()
	var hi: PackedVector2Array = PackedVector2Array()
	for i: int in SLICES:
		lo.append(Vector2(INF, INF))
		hi.append(Vector2(-INF, -INF))
	for v: Vector3 in _vertices(weapon):
		var t: float = (v - base).dot(axis) / span
		if t < 0.0 or t > 1.0:
			continue
		var i: int = mini(int(t * SLICES), SLICES - 1)
		var d: Vector3 = v - base
		var at: Vector2 = Vector2(d.dot(side), d.dot(flat))
		lo[i] = Vector2(minf(lo[i].x, at.x), minf(lo[i].y, at.y))
		hi[i] = Vector2(maxf(hi[i].x, at.x), maxf(hi[i].y, at.y))
	_fill_gaps(lo, hi)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i: int in SLICES + 1:
		var j: int = mini(i, SLICES - 1)
		var along: float = span * float(i) / float(SLICES) + (PAST_TIP if i == SLICES else 0.0)
		var centre: Vector2 = (lo[j] + hi[j]) * 0.5
		var half: Vector2 = (hi[j] - lo[j]) * 0.5 + Vector2(WALL, WALL)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in SIDES:
			var a: float = TAU * float(k) / float(SIDES)
			# a rounded oblong: an ellipse pushed toward its box
			var c: Vector2 = Vector2(cos(a), sin(a))
			var p: Vector2 = Vector2(signf(c.x) * pow(absf(c.x), 0.6), signf(c.y) * pow(absf(c.y), 0.6))
			var q: Vector2 = centre + p * half
			ring.append(base + axis * along + side * q.x + flat * q.y)
		rings.append(ring)
	for i: int in SLICES:
		for k: int in SIDES:
			var n: int = (k + 1) % SIDES
			_quad(st, rings[i][k], rings[i][n], rings[i + 1][n], rings[i + 1][k])
	# the end past the tip, closed
	var end: PackedVector3Array = rings[-1]
	var middle: Vector3 = Vector3.ZERO
	for p: Vector3 in end:
		middle += p
	middle /= float(end.size())
	for k: int in SIDES:
		st.add_vertex(end[k])
		st.add_vertex(end[(k + 1) % SIDES])
		st.add_vertex(middle)
	st.generate_normals()
	saya.mesh = st.commit()
	var lacquer: ShaderMaterial = LookMaterials.weapon(LACQUER, false)
	saya.set_surface_override_material(0, lacquer)
	# kept in the metadata too, as WeaponLook.instantiate() does
	saya.set_meta(&"look_materials", [lacquer] as Array[Material])
	return saya


## The saya's frame on fighter `fighter_id`, in its Hips bone's frame.
static func frame_for(fighter_id: StringName) -> Transform3D:
	return FRAMES.get(fighter_id, FRAMES[&"hunter"])


## Every vertex of `weapon`'s meshes, in the weapon's frame.
static func _vertices(weapon: Node3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var xf: Transform3D = Transform3D.IDENTITY
		var n: Node = mi
		while n != weapon and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for s: int in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	return out


## Slices no vertex fell in take their neighbours' outline.
static func _fill_gaps(lo: PackedVector2Array, hi: PackedVector2Array) -> void:
	for pass_i: int in 2:
		for i: int in lo.size():
			if lo[i].x != INF:
				continue
			var j: int = i - 1 if pass_i == 0 else i + 1
			if j >= 0 and j < lo.size() and lo[j].x != INF:
				lo[i] = lo[j]
				hi[i] = hi[j]
	for i: int in lo.size():
		if lo[i].x == INF:
			lo[i] = Vector2(-0.01, -0.004)
			hi[i] = Vector2(0.01, 0.004)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(p)
