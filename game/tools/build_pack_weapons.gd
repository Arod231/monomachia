extends SceneTree
## Builds the Greatsword and Dagger models from the weapon pack's FBX files
## (imported with the game's materials, see tools/import_assets.gd) and
## writes, for each, weapons/<id>/<name>_mesh.res and the weapon scene
## weapons/<id>/<name>.tscn with its markers.
##
## Run: node scripts/godot.mjs script res://tools/build_pack_weapons.gd
##
## For each model it:
## - moves it into weapon space (see WeaponLook): the origin where the main
##   hand closes, just under the guard (GRIP_BELOW_GUARD), blade along +Y;
## - scales it to its overall length (both grown by 1.15 with the bodies, as
##   the half-hand offsets below were, KE task 4), and widens and thickens
##   the blade alone by `blade_scale` (the greatsword's blade is broadened so it
##   clearly outclasses the katana, without fattening the grip);
## - widens the bevelled edge band to `edge_band` of the half-width, so the
##   bright edge (steel_edge material) reads against the dark blade body
##   (steel) at every angle and at gameplay distance. The pack's blades are
##   a flat plate (faces facing ±Z) ringed by bevels; the plate's outline is
##   pulled toward the blade's middle and the bevels follow;
## - places BladeBase on top of the guard, BladeTip on the point and, for a
##   two-handed weapon, OffHandGrip near the pommel end of the grip.

const SPECS: Array[Dictionary] = [
	{
		"source": "res://assets/weapons/Sword_Big.fbx",
		"mesh": "res://weapons/greatsword/greatsword_mesh.res",
		"scene": "res://weapons/greatsword/greatsword.tscn",
		"name": "Greatsword",
		"length": 1.978,
		"blade_scale": 1.15,
		"edge_band": 0.3,
		"two_handed": true,
	},
	{
		"source": "res://assets/weapons/Dagger.fbx",
		"mesh": "res://weapons/daggers/dagger_mesh.res",
		"scene": "res://weapons/daggers/dagger.tscn",
		"name": "Dagger",
		"length": 0.46,
		"blade_scale": 1.0,
		"edge_band": 0.35,
		"two_handed": false,
	},
]
## Blade surfaces, by material: the flat plate and its bevelled edges.
const BLADE: String = "steel"
const EDGE: String = "steel_edge"
## The grip surfaces, and the guard and pommel.
const GRIP: Array[String] = ["leather_wrap", "leather_wrap_dark"]
const GUARD: String = "iron"
## The main hand's centre sits this far under the guard (half a hand).
const GRIP_BELOW_GUARD: float = 0.0506
## The off hand's centre sits this far above the grip's pommel end.
const OFF_HAND_ABOVE_END: float = 0.0575


func _initialize() -> void:
	var failed: bool = false
	for spec: Dictionary in SPECS:
		failed = not _build(spec) or failed
	quit(1 if failed else 0)


## Each surface of the source model: [arrays in model space, material].
static func _surfaces(source: String) -> Array[Array]:
	var scene: Node = (load(source) as PackedScene).instantiate()
	var out: Array[Array] = []
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var xf: Transform3D = mi.transform
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i: int in verts.size():
				verts[i] = xf * verts[i]
				norms[i] = (xf.basis * norms[i]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = norms
			out.append([arrays, mi.mesh.surface_get_material(s)])
	scene.free()
	return out


static func _range(surfaces: Array[Array], names: Array[String]) -> Vector2:
	var r: Vector2 = Vector2(INF, -INF)
	for entry: Array in surfaces:
		if (entry[1] as Material).resource_name in names:
			for v: Vector3 in (entry[0] as Array)[Mesh.ARRAY_VERTEX]:
				r = Vector2(minf(r.x, v.y), maxf(r.y, v.y))
	return r


static func _build(spec: Dictionary) -> bool:
	var surfaces: Array[Array] = _surfaces(spec.source)
	var all: Vector2 = _range(surfaces, [BLADE, EDGE, GUARD, GRIP[0], GRIP[1]])
	var grip: Vector2 = _range(surfaces, GRIP)
	var guard_top: float = _range(surfaces, [GUARD]).y
	var scale: float = spec.length / (all.y - all.x)
	var origin_y: float = grip.y - GRIP_BELOW_GUARD / scale
	_widen_edges(surfaces, spec.edge_band)
	var mesh: ArrayMesh = ArrayMesh.new()
	var tip: Vector3 = Vector3(0.0, -INF, 0.0)
	for entry: Array in surfaces:
		var arrays: Array = entry[0]
		var mat: Material = entry[1]
		var blade: bool = mat.resource_name == BLADE or mat.resource_name == EDGE
		var k: float = spec.blade_scale if blade else 1.0
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i: int in verts.size():
			var v: Vector3 = verts[i]
			verts[i] = Vector3(v.x * k, v.y - origin_y, v.z * k) * scale
			norms[i] = Vector3(norms[i].x / k, norms[i].y, norms[i].z / k).normalized()
			if blade and verts[i].y > tip.y:
				tip = verts[i]
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var s: int = mesh.get_surface_count() - 1
		mesh.surface_set_material(s, mat)
		mesh.surface_set_name(s, mat.resource_name)
	var err: Error = ResourceSaver.save(mesh, spec.mesh)
	if err != OK:
		printerr("build_pack_weapons: cannot save %s (%s)" % [spec.mesh, error_string(err)])
		return false
	mesh.take_over_path(spec.mesh)
	var root: Node3D = Node3D.new()
	root.name = spec.name
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = &"Mesh"
	mi.mesh = mesh
	root.add_child(mi)
	mi.owner = root
	_add_marker(root, WeaponLook.BLADE_BASE, Vector3(0.0, (guard_top - origin_y) * scale, 0.0))
	_add_marker(root, WeaponLook.BLADE_TIP, Vector3(tip.x, tip.y, 0.0))
	if spec.two_handed:
		_add_marker(root, WeaponLook.OFF_HAND_GRIP, Vector3(0.0, (grip.x - origin_y) * scale + OFF_HAND_ABOVE_END, 0.0))
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	err = ResourceSaver.save(packed, spec.scene)
	root.free()
	if err != OK:
		printerr("build_pack_weapons: cannot save %s (%s)" % [spec.scene, error_string(err)])
		return false
	print("build_pack_weapons: %s %.2f m (blade to %.3f m); saved %s and %s" % [
		spec.name, (all.y - all.x) * scale, tip.y, spec.mesh, spec.scene])
	return true


static func _add_marker(root: Node3D, marker_name: StringName, pos: Vector3) -> void:
	var m: Marker3D = Marker3D.new()
	m.name = marker_name
	m.position = pos
	root.add_child(m)
	m.owner = root


## Pulls the outline of the blade's flat plate toward the blade's middle, so
## that the bevels round it (which share the outline's vertices) widen to
## `band` of the blade's half-width. The middle at a given height is halfway
## between the plate's outermost vertices near that height.
static func _widen_edges(surfaces: Array[Array], band: float) -> void:
	var plate: PackedVector3Array = PackedVector3Array()
	var outer: PackedVector3Array = PackedVector3Array()
	for entry: Array in surfaces:
		var name: String = (entry[1] as Material).resource_name
		if name == BLADE:
			plate.append_array((entry[0] as Array)[Mesh.ARRAY_VERTEX])
		elif name == EDGE:
			outer.append_array((entry[0] as Array)[Mesh.ARRAY_VERTEX])
	var span: float = 0.0
	for v: Vector3 in outer:
		span = maxf(span, v.y)
	var moved: Dictionary[Vector3i, Vector3] = {}
	for v: Vector3 in plate:
		var key: Vector3i = Vector3i((v * 1e5).round())
		if moved.has(key):
			continue
		# The plate's and the bevels' extent across the blade near v's height.
		var lo: float = INF
		var hi: float = -INF
		var olo: float = INF
		var ohi: float = -INF
		var window: float = span * 0.03
		for p: Vector3 in plate:
			if absf(p.y - v.y) < window:
				lo = minf(lo, p.x)
				hi = maxf(hi, p.x)
		for p: Vector3 in outer:
			if absf(p.y - v.y) < window:
				olo = minf(olo, p.x)
				ohi = maxf(ohi, p.x)
		var mid: float = (lo + hi) * 0.5
		var half_plate: float = (hi - lo) * 0.5
		var half_blade: float = maxf((ohi - olo) * 0.5, half_plate)
		if half_plate < 1e-5:
			moved[key] = v
			continue
		# Shrink the plate so its edge sits `band` in from the blade's edge.
		var want: float = half_blade * (1.0 - band)
		var k: float = minf(1.0, want / half_plate)
		moved[key] = Vector3(mid + (v.x - mid) * k, v.y, v.z)
	for entry: Array in surfaces:
		var name: String = (entry[1] as Material).resource_name
		if name != BLADE and name != EDGE:
			continue
		var arrays: Array = entry[0]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i: int in verts.size():
			var key: Vector3i = Vector3i((verts[i] * 1e5).round())
			if moved.has(key):
				verts[i] = moved[key]
		arrays[Mesh.ARRAY_VERTEX] = verts
		# Moving the plate's outline turns the bevels: recompute their flat
		# normals.
		if name == EDGE:
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for t: int in index.size() / 3:
				var a: int = index[t * 3]
				var b: int = index[t * 3 + 1]
				var c: int = index[t * 3 + 2]
				var n: Vector3 = (verts[c] - verts[a]).cross(verts[b] - verts[a]).normalized()
				if n.dot(norms[a]) < 0.0:
					n = -n
				norms[a] = n
				norms[b] = n
				norms[c] = n
			arrays[Mesh.ARRAY_NORMAL] = norms
