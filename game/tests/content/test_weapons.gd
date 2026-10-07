extends GutTest
## The weapon models: each loads, follows the weapon-space convention
## (origin at the main grip, blade along +Y), has its markers, and has the
## size the spec gives it, and its blade reads: a dark body with a bright
## edge, the greatsword clearly the biggest, the katana curved with a
## defined point.

## Overall length in metres (pommel to tip), with a tolerance: the
## Greatsword and the Daggers grew by 1.15 with the bodies (KE task 4).
const LENGTHS: Dictionary[StringName, float] = {&"katana": 1.6, &"greatsword": 1.98, &"daggers": 0.46}
const LENGTH_TOLERANCE: float = 0.05


func _instance(id: StringName) -> Node3D:
	var look: WeaponLook = WeaponLook.load_id(id)
	var w: Node3D = look.scene.instantiate()
	add_child_autofree(w)
	return w


func test_every_playable_weapon_has_a_look() -> void:
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		assert_has(WeaponLook.IDS, id)
	for id: StringName in WeaponLook.IDS:
		var look: WeaponLook = WeaponLook.load_id(id)
		assert_not_null(look, "%s loads" % id)
		assert_eq(look.id, id)
		assert_not_null(look.scene, "%s has a scene" % id)


func test_every_weapon_has_blade_markers_with_the_tip_beyond_the_base() -> void:
	for id: StringName in WeaponLook.IDS:
		var w: Node3D = _instance(id)
		var base: Marker3D = WeaponLook.marker(w, WeaponLook.BLADE_BASE)
		var tip: Marker3D = WeaponLook.marker(w, WeaponLook.BLADE_TIP)
		assert_not_null(base, "%s has BladeBase" % id)
		assert_not_null(tip, "%s has BladeTip" % id)
		if base == null or tip == null:
			continue
		assert_gt(tip.position.length(), base.position.length(), "%s: the tip is farther from the grip than the base" % id)
		assert_gt(base.position.y, 0.0, "%s: the blade starts above the grip (+Y)" % id)
		assert_gt(tip.position.y, base.position.y, "%s: the blade runs along +Y" % id)


func test_two_handed_weapons_have_an_off_hand_grip_below_the_main_one() -> void:
	for id: StringName in WeaponLook.IDS:
		var look: WeaponLook = WeaponLook.load_id(id)
		var off_hand: Marker3D = WeaponLook.marker(_instance(id), WeaponLook.OFF_HAND_GRIP)
		if look.two_handed:
			assert_not_null(off_hand, "%s has OffHandGrip" % id)
			if off_hand != null:
				assert_between(off_hand.position.y, -0.35, -0.1, "%s: the off hand sits below the main hand" % id)
		else:
			assert_null(off_hand, "%s is one-handed" % id)


func test_handedness() -> void:
	assert_true(WeaponLook.load_id(&"katana").two_handed)
	assert_true(WeaponLook.load_id(&"greatsword").two_handed)
	assert_false(WeaponLook.load_id(&"daggers").two_handed)
	assert_true(WeaponLook.load_id(&"daggers").paired, "one dagger in each hand")


func test_weapons_have_their_size() -> void:
	for id: StringName in WeaponLook.IDS:
		var bounds: AABB = _bounds(_instance(id))
		assert_almost_eq(bounds.size.y, LENGTHS[id], LENGTH_TOLERANCE, "%s is %.2f m long" % [id, bounds.size.y])
		assert_lt(bounds.position.y, 0.0, "%s: the grip origin is inside the model" % id)
		assert_gt(bounds.end.y, 0.0, "%s: the grip origin is inside the model" % id)


func test_the_katana_blade_is_1_3_m_and_curved_back() -> void:
	var w: Node3D = _instance(&"katana")
	var tip: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_TIP).position
	var base: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_BASE).position
	assert_almost_eq((tip - base).length(), 1.3, 0.005, "blade from the habaki to the point (KE task 2)")
	assert_lt(tip.x, -0.02, "the point curves back, away from the edge (+X)")
	var mesh: Mesh = (w.get_node(^"Mesh") as MeshInstance3D).mesh
	assert_eq(mesh.get_surface_count(), 6, "blade, habaki, tsuba, rim, wrap, fittings")
	for s: int in mesh.get_surface_count():
		assert_not_null(mesh.surface_get_material(s), "katana surface %d has a material" % s)


## Each look's grip radius, which the fists close on, is the model's: the
## mean of the handle's two half-widths, within 3 mm, where each hand grips
## (the origin, and OffHandGrip on a two-handed weapon).
func test_the_grip_radius_is_the_handle_s() -> void:
	for id: StringName in WeaponLook.IDS:
		var look: WeaponLook = WeaponLook.load_id(id)
		var w: Node3D = _instance(id)
		var grips: Array[float] = [0.0]
		var off_hand: Marker3D = WeaponLook.marker(w, WeaponLook.OFF_HAND_GRIP)
		if off_hand != null:
			grips.append(off_hand.position.y)
		for y: float in grips:
			var half: Vector2 = _half_widths(w, y)
			var radius: float = (half.x + half.y) * 0.5
			assert_almost_eq(look.grip_radius, radius, 0.003, "%s: the handle at %.2f m is %.1f cm thick" % [id, y, radius * 200.0])


## The largest |x| and |z| of a weapon's vertices within 2 cm of height y.
static func _half_widths(w: Node3D, y: float) -> Vector2:
	var half: Vector2 = Vector2.ZERO
	for node: Node in w.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		for s: int in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				var p: Vector3 = mi.transform * v
				if absf(p.y - y) < 0.02:
					half = Vector2(maxf(half.x, absf(p.x)), maxf(half.y, absf(p.z)))
	return half


## Every surface of a weapon instance is physically based, a weapon's, with
## no outline, and on the fighters' render layer, so the fighters' lights
## find it.
func _assert_physical(w: Node3D, id: StringName) -> void:
	for node: Node in w.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		assert_eq(mi.layers & LookPalette.FIGHTER_LAYER, LookPalette.FIGHTER_LAYER, "%s %s is on the fighter layer" % [id, mi.name])
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			var what: String = "%s %s" % [id, mi.mesh.surface_get_name(s)]
			assert_true(LookMaterials.is_physical(m), "%s is physically based" % what)
			assert_eq(LookMaterials.surface_of(m), LookMaterials.Surface.WEAPON, "%s is a weapon's surface" % what)
			assert_null(m.next_pass, "%s has no outline" % what)


func test_an_instanced_weapon_is_in_the_realistic_look() -> void:
	for id: StringName in WeaponLook.IDS:
		var w: Node3D = WeaponLook.load_id(id).instantiate()
		add_child_autofree(w)
		_assert_physical(w, id)
		var mi: MeshInstance3D = w.get_node(^"Mesh")
		for s: int in mi.mesh.get_surface_count():
			var source: Material = mi.mesh.surface_get_material(s)
			var m: ShaderMaterial = mi.get_active_material(s)
			if source is BaseMaterial3D:
				assert_eq(m.get_shader_parameter(&"base_color"), (source as BaseMaterial3D).albedo_color, "%s %s keeps its colour" % [id, source.resource_name])
				var metal: bool = float(m.get_shader_parameter(&"metallic")) > 0.0
				assert_eq(metal, (source as BaseMaterial3D).metallic > 0.0, "%s %s: metal only where the model's is" % [id, source.resource_name])
			else:
				assert_eq(m.shader, (source as ShaderMaterial).shader, "%s %s keeps its own shader" % [id, source.resource_name])


func test_the_katana_keeps_its_temper_line_and_its_wrap_in_the_realistic_look() -> void:
	var w: Node3D = WeaponLook.load_id(&"katana").instantiate()
	add_child_autofree(w)
	var mi: MeshInstance3D = w.get_node(^"Mesh")
	var blade: ShaderMaterial = mi.get_active_material(0)
	var wrap: ShaderMaterial = mi.get_active_material(4)
	for m: ShaderMaterial in [blade, wrap]:
		assert_false(m.shader.code.contains("void light()"), "%s is lit physically" % m.resource_name)
	assert_eq(blade.resource_name, "blade")
	assert_eq(wrap.resource_name, "wrap")
	assert_lt(_shading(blade, &"roughness"), 0.3, "the blade is polished steel")
	assert_eq(_shading(blade, &"metallic"), 1.0, "and metal")
	assert_gt(_shading(wrap, &"roughness"), 0.5, "the silk wrap is rough")


## A float uniform of m: the material's value, or the default its shader's
## code gives it (-1 when it has none).
static func _shading(m: ShaderMaterial, param: StringName) -> float:
	var v: Variant = m.get_shader_parameter(param)
	if v != null:
		return float(v)
	var found: RegExMatch = RegEx.create_from_string("uniform\\s+float\\s+%s\\b[^=;]*=\\s*([0-9.]+)" % param).search(m.shader.code)
	return float(found.get_string(1)) if found != null else -1.0


## The bounds of every mesh of a weapon instance, in its own space.
static func _bounds(w: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for node: Node in w.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != w:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var box: AABB = xf * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## The index of the surface with this name, or -1.
static func _surface(mesh: Mesh, surface_name: String) -> int:
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_name(s) == surface_name:
			return s
	return -1


static func _area(mesh: Mesh, s: int) -> float:
	var arrays: Array = mesh.surface_get_arrays(s)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var total: float = 0.0
	for t: int in index.size() / 3:
		total += 0.5 * (v[index[t * 3 + 1]] - v[index[t * 3]]).cross(v[index[t * 3 + 2]] - v[index[t * 3]]).length()
	return total


static func _luminance(mat: Material) -> float:
	return (mat as BaseMaterial3D).albedo_color.get_luminance()


func test_pack_blades_have_a_dark_body_and_a_bright_edge_band() -> void:
	for id: StringName in [&"greatsword", &"daggers"]:
		var mesh: Mesh = (_instance(id).get_node(^"Mesh") as MeshInstance3D).mesh
		var body: int = _surface(mesh, "steel")
		var edge: int = _surface(mesh, "steel_edge")
		assert_true(body >= 0 and edge >= 0, "%s has a blade body and an edge" % id)
		if body < 0 or edge < 0:
			continue
		assert_lt(_luminance(mesh.surface_get_material(body)), 0.25, "%s's blade body is dark" % id)
		assert_gt(_luminance(mesh.surface_get_material(edge)) - _luminance(mesh.surface_get_material(body)), 0.5, "%s's edge is much brighter than its body" % id)
		var share: float = _area(mesh, edge) / (_area(mesh, edge) + _area(mesh, body))
		assert_gt(share, 0.2, "%s's edge band is wide enough to read (%.0f%% of the blade)" % [id, share * 100.0])


func test_the_katana_blade_has_a_bright_temper_line_on_a_dark_body() -> void:
	var mesh: Mesh = (_instance(&"katana").get_node(^"Mesh") as MeshInstance3D).mesh
	var blade: ShaderMaterial = mesh.surface_get_material(0) as ShaderMaterial
	assert_not_null(blade, "the katana blade has its shader")
	var steel: Color = blade.get_shader_parameter("steel")
	var hamon: Color = blade.get_shader_parameter("hamon")
	assert_lt(steel.get_luminance(), 0.25, "the blade body is dark")
	assert_gt(hamon.get_luminance() - steel.get_luminance(), 0.5, "the temper line is much brighter")


func test_the_greatsword_outclasses_the_katana() -> void:
	var great: AABB = _bounds(_instance(&"greatsword"))
	var katana: AABB = _bounds(_instance(&"katana"))
	# at least 25 cm longer since it grew with the bodies (KE task 4), as the
	# Katana's 1.3 m blade (KE task 2) had nearly caught it up
	assert_gt(great.size.y, katana.size.y + 0.25, "at least 25 cm longer (%.2f m against %.2f)" % [great.size.y, katana.size.y])
	var mesh: Mesh = (_instance(&"greatsword").get_node(^"Mesh") as MeshInstance3D).mesh
	var widest: float = 0.0
	for s: int in [_surface(mesh, "steel"), _surface(mesh, "steel_edge")]:
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if v.y > 0.4 and v.y < 1.0:
				widest = maxf(widest, absf(v.x) * 2.0)
	assert_gt(widest, 0.032 * 3.0, "its blade is several katana blades wide (%.3f m)" % widest)


## The katana's back line: the deepest point of its curve against the
## straight line from the blade's base to its point (the sori), and the
## point's width 2 cm from its end (a needle would be a few millimetres).
func test_the_katana_curves_in_one_arc_and_has_a_defined_point() -> void:
	var w: Node3D = _instance(&"katana")
	var mesh: Mesh = (w.get_node(^"Mesh") as MeshInstance3D).mesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var back: Array[Vector3] = []
	for i: int in verts.size():
		if uvs[i].x > 0.99 and absf(verts[i].z) < 1e-4:
			back.append(verts[i])
	back.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	var a: Vector3 = back[0]
	var b: Vector3 = back[back.size() - 1]
	var deepest: float = 0.0
	var deepest_at: float = 0.0
	for p: Vector3 in back:
		var t: float = (p.y - a.y) / (b.y - a.y)
		var chord_x: float = lerpf(a.x, b.x, t)
		if p.x - chord_x > deepest:
			deepest = p.x - chord_x
			deepest_at = t
	assert_between(deepest, 0.015, 0.021, "the sori is %.1f cm" % (deepest * 100.0))
	assert_between(deepest_at, 0.35, 0.65, "the curve is deepest near the middle (at %.0f%%)" % (deepest_at * 100.0))
	var tip: Vector3 = WeaponLook.marker(w, WeaponLook.BLADE_TIP).position
	var lo: float = INF
	var hi: float = -INF
	for v: Vector3 in verts:
		if absf(v.y - (tip.y - 0.02)) < 0.0025:
			lo = minf(lo, v.x)
			hi = maxf(hi, v.x)
	assert_gt(hi - lo, 0.009, "2 cm from its end the point is still %.1f cm wide" % ((hi - lo) * 100.0))
	# The blade's cross-section nearest 10 cm above the grip.
	var ring_y: float = verts[0].y
	for v: Vector3 in verts:
		if absf(v.y - 0.1) < absf(ring_y - 0.1):
			ring_y = v.y
	var base_lo: float = INF
	var base_hi: float = -INF
	for v: Vector3 in verts:
		if absf(v.y - ring_y) < 1e-4:
			base_lo = minf(base_lo, v.x)
			base_hi = maxf(base_hi, v.x)
	assert_almost_eq(base_hi - base_lo, 0.032, 0.002, "the blade is 3.2 cm wide at its base")
