extends GutTest
## The Hunter's tricorn and scarf, modelled in Blender (milestone-1 task 46,
## scripts/blender/build_headwear.py) and brought in by the export: the
## tricorn in a jingasa's lacquer with a gold crest and cord ties, on the
## Head bone; the scarf in the palette's dye, on the Neck bone, its two tails
## swung by spring bones.

const HAT: String = "res://assets/exports/headwear/hunter_tricorn.glb"
const SCARF: String = "res://assets/exports/headwear/hunter_scarf.glb"
const TAILS: Array[String] = ["TailL", "TailR"]


func _hunter() -> FighterModel:
	var f: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	f.autoplay_idle = false
	add_child_autofree(f)
	return f


func test_the_hunters_headwear_comes_from_the_export() -> void:
	var look: FighterLook = load(FighterLook.path_for(&"hunter"))
	assert_eq(look.hat_scene.resource_path, HAT)
	assert_eq(look.scarf_scene.resource_path, SCARF)
	assert_null(look.head_wrap, "no scarf cut from the head any more")


func test_the_tricorn_is_lacquered_with_a_gold_crest_and_cords() -> void:
	var f: FighterModel = _hunter()
	var hat: MeshInstance3D = f.skeleton.get_node_or_null(^"HeadAttachment/Hat")
	assert_not_null(hat)
	if hat == null:
		return
	var names: Array[String] = []
	for s: int in hat.mesh.get_surface_count():
		var m: ShaderMaterial = hat.get_active_material(s) as ShaderMaterial
		assert_not_null(m, "surface %d in the look" % s)
		if m == null:
			continue
		names.append(m.resource_name)
		assert_eq(m.get_shader_parameter(&"use_orm_texture"), true, "%s reads its roughness and metalness" % m.resource_name)
	assert_eq(names, ["Tricorn_Lacquer", "Tricorn_Band", "Tricorn_Gold", "Tricorn_Cord"])
	var lacquer: ShaderMaterial = hat.get_active_material(0)
	var c: Color = lacquer.get_shader_parameter(&"base_color")
	assert_lt(c.srgb_to_linear().get_luminance(), 0.05, "black lacquer")
	var gold: ShaderMaterial = hat.get_active_material(2)
	assert_gt((gold.get_shader_parameter(&"base_color") as Color).r, 0.6, "gold")
	# the same on both sides
	f.apply_palette(1)
	assert_eq(hat.get_active_material(0).get_shader_parameter(&"base_color"), c)


func test_the_scarf_hangs_on_the_neck_with_two_spring_tails() -> void:
	var f: FighterModel = _hunter()
	var at: BoneAttachment3D = f.skeleton.get_node_or_null(^"NeckAttachment")
	assert_not_null(at)
	if at == null:
		return
	assert_eq(at.bone_name, "Neck")
	var rig: Skeleton3D = at.find_children("*", "Skeleton3D", true, false)[0]
	assert_ne(rig, f.skeleton, "the scarf's own rig, not the fighter's")
	assert_eq(f.skeleton.get_bone_count(), 65, "the fighter keeps its skeleton")
	for tail: String in TAILS:
		for b: int in 4:
			assert_gt(rig.find_bone("%s%d" % [tail, b]), -1, "%s%d" % [tail, b])
	var sims: Array[Node] = rig.find_children("*", "SpringBoneSimulator3D", false, false)
	assert_eq(sims.size(), 1, "one spring-bone simulator")
	var sim: SpringBoneSimulator3D = sims[0]
	assert_eq(sim.setting_count, 2)
	for i: int in 2:
		assert_eq(sim.get_root_bone_name(i), TAILS[i] + "0")
		assert_eq(sim.get_end_bone_name(i), TAILS[i] + "3")
	assert_gt(sim.find_children("*", "SpringBoneCollisionCapsule3D", false, false).size(), 0, "the tails meet the back")


func test_the_scarf_takes_the_palettes_dye() -> void:
	var f: FighterModel = _hunter()
	var scarf: MeshInstance3D = f.skeleton.get_node(^"NeckAttachment").find_children("Scarf", "MeshInstance3D", true, false)[0]
	for pal: int in 2:
		f.apply_palette(pal)
		var m: ShaderMaterial = scarf.get_active_material(0) as ShaderMaterial
		assert_eq(m.get_shader_parameter(&"base_color"), f.look.palettes[pal].headwear_color)
		assert_not_null(m.get_shader_parameter(&"albedo_texture"), "the seigaiha weave")
	assert_ne(f.look.palettes[0].headwear_color, f.look.palettes[1].headwear_color, "crimson and indigo")


## The tail's tip, read when the scarf's rig has been posed: the spring
## bones' pose holds only until the skeleton restores its own.
var _tip: Vector3 = Vector3.INF


func _watch_tip(rig: Skeleton3D) -> void:
	rig.skeleton_updated.connect(func() -> void:
		_tip = rig.global_transform * rig.get_bone_global_pose(rig.find_bone("TailL3")).origin)


func _settle(frames: int) -> float:
	var last: Vector3 = Vector3.INF
	var moved: float = INF
	for frame: int in frames:
		await get_tree().physics_frame
		await get_tree().process_frame
		if frame >= frames - 10:
			moved = minf(moved, _tip.distance_to(last))
		last = _tip
	return moved


func test_the_tails_settle_at_rest_behind_the_back() -> void:
	var f: FighterModel = _hunter()
	var rig: Skeleton3D = f.skeleton.get_node(^"NeckAttachment").find_children("*", "Skeleton3D", true, false)[0]
	_watch_tip(rig)
	assert_lt(await _settle(180), 0.002, "the tail has come to rest after 3 s")
	var sk: Skeleton3D = f.skeleton
	var neck: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"Neck")).origin
	var chest: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"Chest")).origin
	var fwd: Vector3 = f.global_transform.basis.z
	assert_lt((_tip - chest).dot(fwd), -0.1, "the tail hangs behind the chest")
	assert_lt(_tip.y, neck.y - 0.3, "and well below the neck")


func test_the_tails_swing_under_gravity() -> void:
	var f: FighterModel = _hunter()
	var rig: Skeleton3D = f.skeleton.get_node(^"NeckAttachment").find_children("*", "Skeleton3D", true, false)[0]
	_watch_tip(rig)
	await _settle(60)
	var hanging: Vector3 = _tip
	var sim: SpringBoneSimulator3D = rig.find_children("*", "SpringBoneSimulator3D", false, false)[0]
	for i: int in sim.setting_count:
		sim.set_gravity_direction(i, Vector3.RIGHT)
		sim.set_gravity(i, 9.8)
	await _settle(60)
	assert_gt(_tip.x - hanging.x, 0.2, "a sideways pull swings the tail out")
