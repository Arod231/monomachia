extends GutTest
## The fighter scenes: they load and assemble without errors, their skeleton
## is the retargeted humanoid one, the shared clips drive it, they have a
## rig that fills the right hands and two palettes, the body is cut down to
## the head, the headwear and skin are in place, and every weapon is
## carried without its blade running into the fighter's own body. The rig's
## IK and grip are tested in tests/view/test_fighter_rig.gd.

const BONE_MAP: String = "res://assets/quaternius/ual_bone_map.tres"
## Profile bones with no Quaternius source bone.
const UNMAPPED: Array[StringName] = [&"LeftEye", &"RightEye", &"Jaw"]


func _fighter(id: StringName) -> FighterModel:
	var f: FighterModel = FighterLook.instantiate_fighter(id)
	add_child_autofree(f)
	return f


func test_there_are_two_fighters() -> void:
	assert_eq(FighterLook.IDS.size(), 2)
	assert_has(FighterLook.IDS, &"rogue")
	assert_has(FighterLook.IDS, &"hunter")


func test_every_fighter_scene_loads_and_assembles() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		assert_not_null(f.look, "%s has a look" % id)
		assert_eq(f.look.id, id)
		assert_not_null(f.skeleton, "%s has a skeleton" % id)
		var meshes: Array[Node] = f.skeleton.find_children("*", "MeshInstance3D", true, false)
		# Outfit parts (several meshes each), hair, head, eyes and eyebrows.
		assert_gt(meshes.size(), f.look.outfit_parts.size() + f.look.hair.size() + 2, "%s has all its parts" % id)
		for node: Node in meshes:
			var mi: MeshInstance3D = node
			if mi.get_parent() is BoneAttachment3D:
				continue
			assert_eq(mi.get_node(mi.skeleton), f.skeleton, "%s: %s is skinned to the fighter's skeleton" % [id, mi.name])


func test_the_bone_map_maps_53_humanoid_bones() -> void:
	var bone_map: BoneMap = load(BONE_MAP)
	var profile: SkeletonProfile = bone_map.profile
	assert_eq(profile.bone_size, 56)
	var mapped: int = 0
	for i: int in profile.bone_size:
		if bone_map.get_skeleton_bone_name(profile.get_bone_name(i)) != &"":
			mapped += 1
	assert_eq(mapped, 53)


func test_every_fighter_skeleton_has_all_53_humanoid_bones() -> void:
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		var found: int = 0
		for i: int in profile.bone_size:
			var bone: StringName = profile.get_bone_name(i)
			if UNMAPPED.has(bone):
				continue
			assert_gt(f.skeleton.find_bone(bone), -1, "%s has bone %s" % [id, bone])
			found += 1
		assert_eq(found, 53, id)
		assert_eq(f.skeleton.get_bone_count(), 65, "%s keeps the 65-bone Quaternius skeleton" % id)


func test_the_skeleton_is_the_unique_node_the_clips_address() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		assert_eq(f.get_node(^"%GeneralSkeleton"), f.skeleton, id)


func test_the_shared_clips_drive_every_fighter() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		var ap: AnimationPlayer = f.animation_player
		assert_true(ap.has_animation("ual/" + String(f.look.idle_clip)), "%s idle clip" % id)
		assert_true(ap.has_animation("ual/" + String(f.look.walk_clip)), "%s walk clip" % id)
		var thigh: int = f.skeleton.find_bone(&"LeftUpperLeg")
		var rest: Quaternion = f.skeleton.get_bone_rest(thigh).basis.get_rotation_quaternion()
		f.play(f.look.walk_clip, 0.0)
		ap.seek(0.3, true)
		var posed: Quaternion = f.skeleton.get_bone_pose_rotation(thigh)
		assert_gt(rad_to_deg(posed.angle_to(rest)), 5.0, "%s's walk clip moves the thigh" % id)


func test_every_fighter_has_a_rig_on_its_skeleton() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		assert_not_null(f.rig, "%s has a rig" % id)
		assert_eq(f.rig.skeleton, f.skeleton)
		assert_eq(f.hand_grip, f.rig.hand_grip)
		assert_eq(f.hand_grip.get_parent(), f.skeleton, "%s closes its hands on its skeleton" % id)
		assert_eq(f.weapon_root.transform, f.skeleton.transform, "%s holds weapons in the skeleton's space" % id)


## Weapons are posed in fighter space, not put in hand sockets: one model
## per hand that holds one, in the weapon root; posed, the main hand grips
## the first and the off hand the second of a pair or the OffHandGrip of a
## two-handed weapon.
func test_attaching_weapons_fills_the_right_hands() -> void:
	var f: FighterModel = _fighter(&"rogue")
	var held: Array[Node3D] = f.attach_weapon(WeaponLook.load_id(&"daggers"))
	assert_eq(held.size(), 2, "one dagger per hand")
	for w: Node3D in held:
		assert_eq(w.get_parent(), f.weapon_root)
	assert_true(f.hand_grip.right_hand and f.hand_grip.left_hand, "carried, both hands close")
	for i: int in 2:
		f.pose_weapon(i, Transform3D(Basis(), Vector3(0.2 - 0.4 * i, 1.1, 0.3)))
	assert_true(f.rig.drives("Right") and f.rig.drives("Left"), "posed, the IK places both hands")
	held = f.attach_weapon(WeaponLook.load_id(&"greatsword"))
	assert_eq(held.size(), 1)
	assert_eq(f.weapon_root.get_child_count(), 1, "the daggers were removed")
	assert_true(f.hand_grip.right_hand)
	assert_false(f.hand_grip.left_hand, "carried, the off hand is free")
	f.pose_weapon(0, Transform3D(Basis(), Vector3(0.0, 1.1, 0.3)))
	assert_true(f.rig.drives("Left"), "posed, the off hand goes to OffHandGrip")
	assert_true(f.hand_grip.left_hand)
	f.carry_weapons()
	assert_false(f.rig.drives("Right") or f.rig.drives("Left"), "carried again, no IK")
	f.detach_weapons()
	assert_false(f.hand_grip.right_hand or f.hand_grip.left_hand, "empty hands open")


func test_signature_weapons() -> void:
	assert_eq((load(FighterLook.path_for(&"rogue")) as FighterLook).signature_weapon, &"daggers")
	assert_eq((load(FighterLook.path_for(&"hunter")) as FighterLook).signature_weapon, &"greatsword")


func test_every_fighter_has_two_different_palettes() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		assert_eq(f.look.palettes.size(), 2, id)
		var a: FighterPalette = f.look.palettes[0]
		var b: FighterPalette = f.look.palettes[1]
		assert_not_null(a.outfit_albedo, "%s palette A is baked" % id)
		assert_not_null(b.outfit_albedo, "%s palette B is baked" % id)
		assert_ne(a.outfit_albedo, b.outfit_albedo)
		f.apply_palette(0)
		assert_eq(_outfit_texture(f), a.outfit_albedo, "%s wears palette A" % id)
		f.apply_palette(1)
		assert_eq(_outfit_texture(f), b.outfit_albedo, "%s wears palette B" % id)


func test_a_palette_change_is_remembered_across_a_rebuild() -> void:
	var f: FighterModel = _fighter(&"rogue")
	f.apply_palette(1)
	assert_eq(f.palette, 1, "apply_palette records the palette")
	f.rebuild()
	assert_eq(_outfit_texture(f), f.look.palettes[1].outfit_albedo, "the rebuilt model keeps palette B")


func test_a_rebuilt_fighter_idles_again() -> void:
	var f: FighterModel = _fighter(&"hunter")
	f.rebuild()
	assert_true(f.animation_player.is_playing(), "the new player idles")
	assert_eq(f.animation_player.current_animation, "ual/" + String(f.idle_clip()))


func test_a_fighter_made_in_code_takes_a_weapon_before_entering_the_tree() -> void:
	var f: FighterModel = FighterModel.new()
	f.look = load(FighterLook.path_for(&"rogue"))
	autofree(f)
	var held: Array[Node3D] = f.attach_weapon(WeaponLook.load_id(&"katana"))
	assert_eq(held.size(), 1, "attach_weapon builds the model first")
	assert_eq(held[0].get_parent(), f.weapon_root)


func test_detaching_from_an_unbuilt_fighter_is_harmless() -> void:
	var f: FighterModel = FighterModel.new()
	autofree(f)
	f.detach_weapons()
	assert_eq(f.weapons.size(), 0)


func _outfit_texture(f: FighterModel) -> Texture2D:
	for node: Node in f.skeleton.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		for s: int in mi.mesh.get_surface_count():
			var override: Material = mi.get_surface_override_material(s)
			if override is ShaderMaterial and StringName(override.resource_name) == f.look.outfit_material:
				return (override as ShaderMaterial).get_shader_parameter(&"albedo_texture")
	return null


## The fighter's own surfaces (not a held weapon's): [MeshInstance3D,
## surface index] pairs.
func _surfaces(f: FighterModel) -> Array[Array]:
	var out: Array[Array] = []
	for node: Node in f.skeleton.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if f.weapons.any(func(w: Node3D) -> bool: return w.is_ancestor_of(mi)):
			continue
		for s: int in mi.mesh.get_surface_count():
			out.append([mi, s])
	return out


func test_every_fighter_surface_is_toon_outlined_and_on_the_fighter_layer() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		for pal: int in 2:
			f.apply_palette(pal)
			for entry: Array in _surfaces(f):
				var mi: MeshInstance3D = entry[0]
				var m: Material = mi.get_active_material(entry[1])
				var what: String = "%s palette %d: %s surface %d" % [id, pal, mi.name, entry[1]]
				assert_true(ToonMaterials.is_toon(m), "%s is toon" % what)
				assert_eq(ToonMaterials.outline_kind_of(m), ToonMaterials.OutlineKind.FIGHTER, "%s is outlined as a fighter" % what)
				assert_true(ToonMaterials.is_outlined(m), what)
				assert_eq(mi.layers, 1 | LookPalette.FIGHTER_LAYER, "%s is on the fighter layer" % what)


func test_no_fighter_material_misses_a_texture() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		for entry: Array in _surfaces(f):
			var mi: MeshInstance3D = entry[0]
			var mat: ShaderMaterial = mi.get_active_material(entry[1]) as ShaderMaterial
			assert_not_null(mat, "%s %s surface %d has a toon material" % [id, mi.name, entry[1]])
			if mat == null:
				continue
			assert_not_null(mat.get_shader_parameter(&"albedo_texture"), "%s %s (%s) has its base colour" % [id, mi.name, mat.resource_name])
			if float(mat.get_shader_parameter(&"normal_strength")) > 0.0:
				assert_not_null(mat.get_shader_parameter(&"normal_texture"), "%s %s (%s) has its normal map" % [id, mi.name, mat.resource_name])


func test_the_body_is_cut_down_to_the_head_and_neck() -> void:
	for id: StringName in FighterLook.IDS:
		var look: FighterLook = load(FighterLook.path_for(id))
		var body_scene: Node = look.body_scene.instantiate()
		var body: MeshInstance3D = null
		for node: Node in body_scene.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			if body == null or mi.mesh.surface_get_array_len(0) > body.mesh.surface_get_array_len(0):
				body = mi
		var head_binds: Array[int] = []
		for i: int in body.skin.get_bind_count():
			if body.skin.get_bind_name(i) in [&"Head", &"Neck"]:
				head_binds.append(i)
		var arrays: Array = look.head_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / verts.size()
		var lowest: float = 1.0
		for v: int in verts.size():
			var w: float = 0.0
			for k: int in per:
				if head_binds.has(bones[v * per + k]):
					w += weights[v * per + k]
			lowest = minf(lowest, w)
		assert_gt(lowest, 0.499, "%s: every head vertex is mostly on the head and neck" % id)
		var full_tris: int = body.mesh.surface_get_array_index_len(0) / 3
		var head_tris: int = look.head_mesh.surface_get_array_index_len(0) / 3
		assert_between(head_tris, 1000, full_tris / 3, "%s: the head keeps %d of %d triangles" % [id, head_tris, full_tris])
		body_scene.free()


func _mesh_names(f: FighterModel) -> PackedStringArray:
	var names: PackedStringArray = []
	for node: Node in f.find_children("*", "MeshInstance3D", true, false):
		names.append(String(node.name))
	return names


## A mesh instance's vertices in fighter space, rest pose.
static func _rest_points(f: FighterModel, mi: MeshInstance3D) -> PackedVector3Array:
	var sk: Skeleton3D = f.skeleton
	var xf: Transform3D = sk.transform * mi.transform
	var attachment: BoneAttachment3D = mi.get_parent() as BoneAttachment3D
	if attachment != null:
		xf = sk.transform * sk.get_bone_global_rest(sk.find_bone(attachment.bone_name)) * mi.transform
	var out: PackedVector3Array = PackedVector3Array()
	for s: int in mi.mesh.get_surface_count():
		for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


static func _bounds(points: PackedVector3Array) -> AABB:
	var box: AABB = AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	return box


func test_the_rogue_wears_a_face_mask_and_no_pauldron() -> void:
	var f: FighterModel = _fighter(&"rogue")
	assert_false(Array(_mesh_names(f)).any(func(n: String) -> bool: return n.contains("Pauldron")), "the Rogue wears no pauldron")
	var wrap: MeshInstance3D = f.skeleton.get_node_or_null(^"HeadWrap")
	assert_not_null(wrap, "the Rogue wears a face mask")
	if wrap == null:
		return
	var head: MeshInstance3D = f.skeleton.get_node(^"Head")
	assert_eq(wrap.skin, head.skin, "the mask is skinned like the head")
	assert_eq(wrap.get_node(wrap.skeleton), f.skeleton)
	var eyes: AABB = _bounds(_rest_points(f, f.skeleton.get_node(^"Eyes")))
	var mask: AABB = _bounds(_rest_points(f, wrap))
	assert_lt(mask.end.y, eyes.get_center().y, "the mask stays below the eyes")
	assert_gt(mask.end.z, eyes.end.z, "the mask covers the nose, in front of the eyes")


func test_the_hunter_wears_a_tricorn_and_a_scarf_and_no_hood() -> void:
	var f: FighterModel = _fighter(&"hunter")
	assert_false(Array(_mesh_names(f)).any(func(n: String) -> bool: return n.contains("Hood")), "the Hunter wears no hood")
	assert_not_null(f.skeleton.get_node_or_null(^"HeadWrap"), "the Hunter wears a scarf")
	var hat: MeshInstance3D = f.skeleton.get_node_or_null(^"HeadAttachment/Hat")
	assert_not_null(hat, "the Hunter wears a hat")
	if hat == null:
		return
	assert_eq((hat.get_parent() as BoneAttachment3D).bone_name, "Head", "the hat rides on the head")
	var head: AABB = _bounds(_rest_points(f, f.skeleton.get_node(^"Head")))
	var eyes: AABB = _bounds(_rest_points(f, f.skeleton.get_node(^"Eyes")))
	var box: AABB = _bounds(_rest_points(f, hat))
	assert_gt(box.position.y, eyes.get_center().y, "the hat sits above the eyes")
	assert_gt(box.end.y, head.end.y + 0.01, "the crown clears the top of the head")
	assert_gt(box.size.x, head.size.x + 0.1, "the brim spreads well past the head")


func test_headwear_takes_the_palette_colour() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		var wrap: MeshInstance3D = f.skeleton.get_node(^"HeadWrap")
		for pal: int in 2:
			f.apply_palette(pal)
			var mat: ShaderMaterial = wrap.get_active_material(0) as ShaderMaterial
			assert_eq(mat.get_shader_parameter(&"base_color"), f.look.palettes[pal].headwear_color, "%s headwear in palette %d" % [id, pal])
			assert_not_null(mat.get_shader_parameter(&"albedo_texture"), "%s headwear is textured" % id)


func test_the_skin_is_baked_and_matt() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		assert_not_null(f.look.skin_albedo, "%s has a baked skin" % id)
		var mat: ShaderMaterial = (f.skeleton.get_node(^"Head") as MeshInstance3D).get_active_material(0) as ShaderMaterial
		assert_eq(mat.get_shader_parameter(&"albedo_texture"), f.look.skin_albedo, "%s wears the baked skin" % id)
		assert_eq(float(mat.get_shader_parameter(&"specular_strength")), 0.0, "%s's skin has no highlight" % id)
	assert_gt((load(FighterLook.path_for(&"hunter")) as FighterLook).scars.size(), 1, "the Hunter is scarred")


func test_every_fighter_has_a_hold_for_every_weapon_with_a_known_clip() -> void:
	for id: StringName in FighterLook.IDS:
		var f: FighterModel = _fighter(id)
		for w: StringName in WeaponLook.IDS:
			var hold: WeaponHold = f.look.hold_for(w)
			assert_not_null(hold, "%s holds the %s" % [id, w])
			f.attach_weapon(WeaponLook.load_id(w))
			assert_true(f.animation_player.has_animation("ual/" + String(f.idle_clip())), "%s idles with the %s in %s" % [id, w, f.idle_clip()])


func test_the_rogue_holds_her_daggers_reversed_with_set_wrists() -> void:
	var f: FighterModel = _fighter(&"rogue")
	f.attach_weapon(WeaponLook.load_id(&"daggers"))
	# Reversed: the blade leaves the fist on the little-finger side (the
	# fist's -Y).
	assert_lt(f.hold.grip_transform().basis.y.dot(Vector3.UP), -0.5, "the blade points out of the little-finger side")
	assert_true(f.hand_grip.wrists.has("Right") and f.hand_grip.wrists.has("Left"), "both wrists are set")
	f.detach_weapons()
	assert_true(f.hand_grip.wrists.is_empty(), "letting go frees the wrists")


func test_the_hunter_idles_ready_for_a_fight() -> void:
	var f: FighterModel = _fighter(&"hunter")
	assert_ne(f.look.idle_clip, &"Idle", "not the relaxed idle")
	f.attach_weapon(WeaponLook.load_id(&"greatsword"))
	assert_true(f.hold.reverse_grip, "the greatsword trails from the fist")


## Distance from p to the segment ab.
static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## No held blade runs into its fighter's own torso or thighs in the idle
## pose: points along each blade (past the hand) stay outside a capsule
## round the spine (hips to neck) and round each thigh.
func test_no_blade_points_into_its_fighter() -> void:
	const TORSO: float = 0.12
	const THIGH: float = 0.075
	for id: StringName in FighterLook.IDS:
		for w: StringName in WeaponLook.IDS:
			var f: FighterModel = _fighter(id)
			var held: Array[Node3D] = f.attach_weapon(WeaponLook.load_id(w))
			f.play_idle(0.0)
			f.animation_player.seek(0.5, true)
			f.animation_player.pause()
			await wait_physics_frames(3)
			var sk: Skeleton3D = f.skeleton
			var to_sk: Transform3D = sk.global_transform.affine_inverse()
			var at: Callable = func(bone: StringName) -> Vector3:
				return sk.get_bone_global_pose(sk.find_bone(bone)).origin
			for blade: Node3D in held:
				var base: Vector3 = to_sk * WeaponLook.marker(blade, WeaponLook.BLADE_BASE).global_position
				var tip: Vector3 = to_sk * WeaponLook.marker(blade, WeaponLook.BLADE_TIP).global_position
				var nearest: float = INF
				var nearest_leg: float = INF
				for k: int in range(2, 11):
					var p: Vector3 = base.lerp(tip, k / 10.0)
					nearest = minf(nearest, _to_segment(p, at.call(&"Hips"), at.call(&"Neck")))
					for side: String in ["Left", "Right"]:
						nearest_leg = minf(nearest_leg, _to_segment(p, at.call(StringName(side + "UpperLeg")), at.call(StringName(side + "LowerLeg"))))
				gut.p("%s %s %s: blade %.2f m from the spine, %.2f m from a thigh" % [id, w, blade.get_parent().name, nearest, nearest_leg])
				assert_gt(nearest, TORSO, "%s's %s (%s) stays out of the torso" % [id, w, blade.get_parent().name])
				assert_gt(nearest_leg, THIGH, "%s's %s (%s) stays out of the thighs" % [id, w, blade.get_parent().name])
