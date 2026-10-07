extends GutTest
## MeshKit's shapes and MeshKitSet: every triangle faces outward (Godot's front
## faces are clockwise), and a set makes one mesh per non-empty kit.


## The direction a triangle's front face looks: clockwise seen from the front.
static func _front(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (c - a).cross(b - a)


## Counts the triangles of mesh that face the wrong way: against their own
## vertex normals, or towards the inside. inside_of maps a point on the
## surface to a point inside the shape. Zero-area triangles are skipped.
func _wrong_way(mesh: ArrayMesh, inside_of: Callable) -> int:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bad: int = 0
	for i: int in range(0, verts.size(), 3):
		var face: Vector3 = _front(verts[i], verts[i + 1], verts[i + 2])
		if face.length_squared() < 1e-12:
			continue
		var mid: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		var out: Vector3 = mid - (inside_of.call(mid) as Vector3)
		if face.dot(norms[i] + norms[i + 1] + norms[i + 2]) <= 0.0 or face.dot(out) <= 0.0:
			bad += 1
	return bad


## The point on the polyline nearest to p.
static func _nearest_on_path(points: PackedVector3Array, p: Vector3) -> Vector3:
	var best: Vector3 = points[0]
	for k: int in points.size() - 1:
		var q: Vector3 = Geometry3D.get_closest_point_to_segment(p, points[k], points[k + 1])
		if q.distance_squared_to(p) < best.distance_squared_to(p):
			best = q
	return best


func test_every_shape_faces_outward() -> void:
	var raised := Transform3D(Basis(), Vector3(0, 1, 0))
	var tilted := Transform3D(Basis(Vector3(1, 1, 0).normalized(), 0.7), Vector3(2, 0, -1))
	var squashed := Transform3D(Basis.from_scale(Vector3(2, 0.5, 1)), Vector3.ZERO)
	var on_end := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	var vase := PackedVector2Array([Vector2(0.4, 0), Vector2(0.6, 1), Vector2(0.3, 2)])
	var rock_noise := FastNoiseLite.new()
	rock_noise.seed = 7
	var straight := PackedVector3Array([Vector3.ZERO, Vector3(0, 1, 0), Vector3(0, 2, 0)])
	var bent := PackedVector3Array([Vector3.ZERO, Vector3(0.5, 1, 0), Vector3(1, 2, 0.5)])
	# Turns by more than a right angle, from a short segment into a long one.
	var sharp := PackedVector3Array([Vector3.ZERO, Vector3(0, 1, 0), Vector3(5, 0, 0)])
	var origin := func(_p: Vector3) -> Vector3: return Vector3.ZERO
	var mid_height := func(_p: Vector3) -> Vector3: return Vector3(0, 1, 0)
	var below := func(p: Vector3) -> Vector3: return p - Vector3.UP
	var cases: Array[Array] = [
		["box", func(k: MeshKit) -> void: k.box(raised, Vector3(1, 2, 3)), mid_height],
		["tilted box", func(k: MeshKit) -> void: k.box(tilted, Vector3(1, 2, 3)),
			func(_p: Vector3) -> Vector3: return tilted.origin],
		["frustum", func(k: MeshKit) -> void: k.cylinder(Transform3D.IDENTITY, 0.5, 0.3, 2.0, 12), mid_height],
		["lathe with caps", func(k: MeshKit) -> void: k.lathe(Transform3D.IDENTITY, vase, 10), mid_height],
		["flat-shaded lathe", func(k: MeshKit) -> void: k.lathe(Transform3D.IDENTITY, vase, 8, true, false), mid_height],
		["closed lathe", func(k: MeshKit) -> void: k.lathe(Transform3D.IDENTITY,
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0.5), Vector2(0.5, 1.5), Vector2(0, 2)]), 10), mid_height],
		["squashed lathe", func(k: MeshKit) -> void: k.lathe(squashed, vase, 10),
			func(_p: Vector3) -> Vector3: return Vector3(0, 0.5, 0)],
		["sphere", func(k: MeshKit) -> void: k.sphere(Transform3D.IDENTITY, 1.0, 12, 8), origin],
		["ellipsoid", func(k: MeshKit) -> void: k.sphere(Transform3D(Basis.from_scale(Vector3(2, 1, 0.5)), Vector3.ZERO), 1.0), origin],
		["noisy rock", func(k: MeshKit) -> void: k.sphere(Transform3D.IDENTITY, 1.0, 12, 8, rock_noise, 0.15), origin],
		["torus", func(k: MeshKit) -> void: k.torus(Transform3D.IDENTITY, 1.0, 0.2, 16, 6),
			func(p: Vector3) -> Vector3: return Vector3(p.x, 0, p.z).normalized()],
		["straight tube", func(k: MeshKit) -> void: k.tube(straight, PackedFloat32Array([0.3, 0.25, 0.2]), 8),
			func(p: Vector3) -> Vector3: return _nearest_on_path(straight, p)],
		["bent tube", func(k: MeshKit) -> void: k.tube(bent, PackedFloat32Array([0.3, 0.2, 0.1]), 8),
			func(p: Vector3) -> Vector3: return _nearest_on_path(bent, p)],
		["sharply turned tube", func(k: MeshKit) -> void: k.tube(sharp, PackedFloat32Array([0.1, 0.1, 0.1]), 6),
			func(p: Vector3) -> Vector3: return _nearest_on_path(sharp, p)],
		["disc", func(k: MeshKit) -> void: k.disc(Transform3D.IDENTITY, 2.0, 16, 3), below],
		["ring", func(k: MeshKit) -> void: k.disc(Transform3D.IDENTITY, 2.0, 16, 3, 1.0), below],
		["disc on end", func(k: MeshKit) -> void: k.disc(on_end, 2.0, 16, 3),
			func(p: Vector3) -> Vector3: return p - on_end.basis * Vector3.UP],
		["long roof", func(k: MeshKit) -> void: k.roof(Transform3D.IDENTITY, 1.0, 0.6, 0.6, 0.15),
			func(_p: Vector3) -> Vector3: return Vector3(0, -0.04, 0)],
		["deep roof", func(k: MeshKit) -> void: k.roof(Transform3D.IDENTITY, 0.6, 1.0, 0.6, 0.15),
			func(_p: Vector3) -> Vector3: return Vector3(0, -0.04, 0)],
	]
	for case: Array in cases:
		var kit := MeshKit.new()
		(case[1] as Callable).call(kit)
		assert_false(kit.is_empty(), "%s adds triangles" % case[0])
		assert_eq(_wrong_way(kit.commit(), case[2]), 0, "%s: triangles facing the wrong way" % case[0])


## Each ring of a tube keeps its radius round a sharp turn. Its frame used to
## collapse there, pinching the ring to a point; the facing test above checks
## that the tube doesn't twist either.
func test_a_tube_keeps_its_radius_round_a_sharp_turn() -> void:
	var points := PackedVector3Array([Vector3.ZERO, Vector3(0, 1, 0), Vector3(5, 0, 0)])
	var radii := PackedFloat32Array([0.1, 0.1, 0.1])
	var kit := MeshKit.new()
	kit.tube(points, radii, 6)
	var verts: PackedVector3Array = kit.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var off_ring: int = 0
	for v: Vector3 in verts:
		var on_ring: bool = false
		for k: int in points.size():
			on_ring = on_ring or absf(v.distance_to(points[k]) - radii[k]) < 1e-4
		if not on_ring:
			off_ring += 1
	assert_eq(off_ring, 0, "vertices off their ring")


func test_a_grid_surface_carries_a_colour_per_point() -> void:
	var rows: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0)]),
		PackedVector3Array([Vector3(0, 0, 1), Vector3(1, 0, 1)]),
	]
	var colours: Array[PackedColorArray] = [
		PackedColorArray([Color.RED, Color.GREEN]),
		PackedColorArray([Color.BLUE, Color.WHITE]),
	]
	var kit := MeshKit.new()
	kit.grid_surface(Transform3D.IDENTITY, rows, false, colours)
	var arrays: Array = kit.commit().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var got: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(verts.size(), 6, "one quad")
	var wrong: int = 0
	for i: int in verts.size():
		var want: Color = colours[int(verts[i].z)][int(verts[i].x)]
		if not got[i].is_equal_approx(want):
			wrong += 1
	assert_eq(wrong, 0, "vertices with another point's colour")


func test_multimesh_draws_the_mesh_at_every_transform_with_its_colour() -> void:
	var spots: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D(Basis(), Vector3(2, 0, 0))]
	var mat := StandardMaterial3D.new()
	var mmi: MultiMeshInstance3D = autofree(MeshKit.multimesh(BoxMesh.new(), spots, mat, PackedColorArray([Color.RED, Color.BLUE])))
	assert_eq(mmi.multimesh.instance_count, 2)
	assert_true(mmi.multimesh.use_colors)
	assert_eq(mmi.material_override, mat)
	var plain: MultiMeshInstance3D = autofree(MeshKit.multimesh(BoxMesh.new(), spots, mat))
	assert_false(plain.multimesh.use_colors, "no colours given")


func test_multimesh_reports_colours_that_do_not_match_the_transforms() -> void:
	var spots: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D(Basis(), Vector3(2, 0, 0))]
	var mmi: MultiMeshInstance3D = autofree(MeshKit.multimesh(BoxMesh.new(), spots, null, PackedColorArray([Color.RED])))
	assert_push_error("2 transforms but 1 colours")
	assert_false(mmi.multimesh.use_colors)


func test_a_set_makes_one_mesh_per_non_empty_kit() -> void:
	var kits := MeshKitSet.new()
	kits.kit(&"stone").box(Transform3D.IDENTITY, Vector3.ONE)
	kits.kit(&"stone").box(Transform3D(Basis(), Vector3(3, 0, 0)), Vector3.ONE)
	kits.kit(&"rope_coil").torus(Transform3D.IDENTITY, 1.0, 0.1)
	kits.kit(&"unused")
	var stone := StandardMaterial3D.new()
	var rope := StandardMaterial3D.new()
	var parent: Node3D = add_child_autofree(Node3D.new())
	var made: Array[MeshInstance3D] = kits.finish(parent, {&"stone": stone, &"rope_coil": rope})
	var expected_keys: Array[StringName] = [&"stone", &"rope_coil", &"unused"]
	assert_eq(kits.keys(), expected_keys)
	assert_eq(made.size(), 2, "one mesh per non-empty kit")
	assert_eq(parent.get_child_count(), 2)
	assert_eq(String(made[0].name), "Stone")
	assert_eq(made[0].material_override, stone)
	assert_eq(made[0].mesh.get_surface_count(), 1)
	assert_eq(made[0].mesh.surface_get_array_len(0), 72, "both boxes merged into one surface")
	assert_eq(String(made[1].name), "RopeCoil")
	assert_eq(made[1].material_override, rope)


func test_a_set_drops_shadows_only_where_asked() -> void:
	var kits := MeshKitSet.new()
	kits.kit(&"stone").box(Transform3D.IDENTITY, Vector3.ONE)
	kits.kit(&"glow").box(Transform3D.IDENTITY, Vector3.ONE)
	var mat := StandardMaterial3D.new()
	var no_shadow: Array[StringName] = [&"glow"]
	var parent: Node3D = add_child_autofree(Node3D.new())
	var made: Array[MeshInstance3D] = kits.finish(parent, {&"stone": mat, &"glow": mat}, no_shadow)
	var stone: MeshInstance3D = made[0]
	var glow: MeshInstance3D = made[1]
	assert_eq(stone.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_eq(glow.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


## A kit without a material would draw in the engine's default white.
func test_a_set_reports_a_kit_with_no_material() -> void:
	var kits := MeshKitSet.new()
	kits.kit(&"stone").box(Transform3D.IDENTITY, Vector3.ONE)
	var parent: Node3D = add_child_autofree(Node3D.new())
	var made: Array[MeshInstance3D] = kits.finish(parent, {})
	assert_push_error("no material for kit stone")
	assert_eq(made.size(), 1, "still built, so the gap shows")
