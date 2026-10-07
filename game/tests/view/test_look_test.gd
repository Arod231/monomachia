extends GutTest
## The look test scene (milestone-1 task 30): built headless in its own
## viewport, it has the realistic look's parts and the features Godot check 6
## lists, the fighter plays the light string, the camera is the board's
## Camera 2; since the art conversion (task 43) the game's own Shrine and
## camera are what it shows. How it looks, and the bench, are judged in a
## real window (shots and npm run bench:look).


func _look(extra: Dictionary = {}) -> LookTest:
	var t := LookTest.new()
	t.own_viewport = true
	t.bench_res = Vector2i(64, 64)
	for key: String in extra:
		t.set(key, extra[key])
	add_child_autofree(t)
	return t


static func _geometry(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		out.append(n as GeometryInstance3D)
	return out


## Every material drawn under root.
static func _materials(root: Node) -> Array[Material]:
	var out: Array[Material] = []
	for g: GeometryInstance3D in _geometry(root):
		if g.material_override != null:
			out.append(g.material_override)
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
			var mi: MeshInstance3D = g as MeshInstance3D
			for i: int in mi.mesh.get_surface_count():
				var m: Material = mi.get_surface_override_material(i)
				out.append(m if m != null else mi.mesh.surface_get_material(i))
	return out


static func _toon(m: Material) -> bool:
	if not m is ShaderMaterial or (m as ShaderMaterial).shader == null:
		return false
	return (m as ShaderMaterial).shader.code.contains("void light()")


func test_the_stage_is_physically_based_with_no_ink() -> void:
	var t: LookTest = _look()
	var toon: int = 0
	var lines: int = 0
	var physical: int = 0
	for m: Material in _materials(t.stage):
		if _toon(m):
			toon += 1
		if m != null and m.next_pass != null:
			lines += 1
		if LookMaterials.is_physical(m):
			physical += 1
	assert_eq(toon, 0, "no toon material on the fighter, the Katana or the Shrine")
	assert_eq(lines, 0, "no ink outlines")
	assert_gt(physical, 5, "physically based materials")


func test_the_katana_s_blade_is_steel() -> void:
	var t: LookTest = _look()
	var blade: ShaderMaterial = null
	for m: Material in _materials(t.fighter):
		if m is ShaderMaterial and (m as ShaderMaterial).shader.code.contains("hamon"):
			blade = m as ShaderMaterial
	assert_not_null(blade, "the blade keeps its temper line")
	if blade != null:
		assert_string_contains(blade.shader.code, "uniform float metallic : hint_range(0.0, 1.0) = 1.0;", "metal")
		assert_string_contains(blade.shader.code, "uniform float roughness : hint_range(0.0, 1.0) = 0.2;", "polished")
		assert_false(_toon(blade), "lit physically")


func test_the_environment_is_the_look_s() -> void:
	var t: LookTest = _look()
	var e: Environment = t.environment
	assert_true(e.volumetric_fog_enabled, "volumetric fog")
	assert_eq(e.volumetric_fog_albedo, LookPalette.MIST, "of the mist's colour")
	assert_true(e.ssao_enabled, "ambient occlusion")
	assert_true(e.glow_enabled, "bloom")
	assert_lt(e.glow_bloom, 0.1, "subtle")
	assert_true(e.fog_enabled, "depth fog")
	assert_eq(e.tonemap_mode, Environment.TONE_MAPPER_AGX)
	assert_true(e.adjustment_enabled, "the grade")
	var curve: Gradient = (e.adjustment_color_correction as GradientTexture1D).gradient
	assert_eq(curve.sample(0.0), LookPalette.NIGHT_INK, "black lifted to the night's ink, never pure black")
	assert_same((t.arena.get_node(^"WorldEnvironment") as WorldEnvironment).environment, e)


func test_the_features_the_milestone_needs_are_there() -> void:
	# Godot check 6 (volumetric fog above): decals, GPU particles, temporal
	# anti-aliasing and FSR 2.2, spring bones and skeleton modifiers
	var t: LookTest = _look()
	assert_gte(t.stage.find_children("*", "Decal", true, false).size(), 2, "decals")
	assert_eq(t.arena.find_children("Dust", "GPUParticles3D", false, false).size(), 1, "GPU particles (the Shrine's dust)")
	var vp: Viewport = t.stage.get_viewport()
	assert_eq(vp.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2, "FSR 2.2 at Ultra")
	assert_almost_eq(vp.scaling_3d_scale, 0.67, 0.005, "from 67%")
	var taa: LookTest = _look({"aa": &"taa"})
	assert_true(taa.stage.get_viewport().use_taa, "Godot's TAA with --aa=taa")
	assert_eq(taa.stage.get_viewport().scaling_3d_scale, 1.0, "at full resolution")
	assert_true(t.cord_sim is SpringBoneSimulator3D, "spring bones")
	assert_eq(t.cord.get_bone_count(), LookTest.CORD_SEGMENTS)
	var mods: Array[StringName] = []
	for c: Node in t.fighter.model.skeleton.get_children():
		if c is SkeletonModifier3D:
			mods.append(c.name)
	assert_true(mods.has(&"InertialBlend") and mods.has(&"BodyLayer") and mods.has(&"LegIK"), "the rig's skeleton modifiers: %s" % [mods])


func test_the_key_and_rim_light_only_fighters() -> void:
	var t: LookTest = _look()
	var mine: int = LookPalette.side_layer(t.fighter.side)
	for light: Light3D in [t.key_light, t.rim_light]:
		assert_eq(light.light_cull_mask, mine, "%s touches the fighter only" % light.name)
		assert_true(t.fighter.lights.is_ancestor_of(light), "%s is the fighter's own (task 44)" % light.name)
	var lit: int = 0
	for g: GeometryInstance3D in _geometry(t.fighter):
		if g.layers & mine:
			lit += 1
	assert_gt(lit, 0, "the fighter is on its side's layer")
	for g: GeometryInstance3D in _geometry(t.arena):
		assert_eq(g.layers & LookPalette.SIDE_LAYERS_MASK, 0, "%s isn't" % g.name)


func test_the_camera_is_camera_2() -> void:
	var t: LookTest = _look()
	var c: CameraRig = t.rig_camera
	assert_not_null(c)
	assert_eq([c.follow_back, c.follow_side, c.follow_close_side, c.follow_close_from, c.follow_height, c.base_fov],
		[4.49, 1.1, 1.0, 4.62, 2.01, 55.0], "the board's numbers (1.0 m to the side nudged out, Oct 7), the distances by 1.32 for the 3.3 m duel and the height by 1.15 for the taller bodies (KE tasks 2 and 3), the close swing widened for their shoulders; the game camera's own since task 43")
	# at Camera 2's base distance: 4.49 m back, 1.1 m right, 2.01 m up
	var target: Dictionary = c.follow_target(Vector3.ZERO, Vector3(0.0, 0.0, 4.62), Vector3(0.0, 0.0, 1.0))
	var pos: Vector3 = target["pos"]
	assert_almost_eq(pos.z, -4.49, 0.05, "back")
	assert_almost_eq(absf(pos.x), 1.1, 0.05, "to the side")
	assert_almost_eq(pos.y, 2.01, 0.05, "up")


func test_the_fighter_plays_the_light_string_in_its_corner() -> void:
	var t: LookTest = _look()
	var seen: Array[StringName] = []
	for i: int in 160:
		t._advance()
		var f: Fighter = t.world.fighters[0]
		if f.state == &"attack" and f.atk != null and not seen.has(f.atk.def.id):
			seen.append(f.atk.def.id)
	# the held grip's string (KE task 5), its first hits in turn: the
	# one-handed grip's own since KE task 11
	var f0: Fighter = t.world.fighters[0]
	var string: Array[StringName] = f0.weapon.grip(f0.grip).string if f0.weapon.grip(f0.grip) != null else [] as Array[StringName]
	assert_gte(seen.size(), 3, "the string's lights: %s" % [seen])
	assert_eq(seen, string.slice(0, seen.size()), "the held grip's lights in turn")
	var from_centre: float = Vector2(t.world.fighters[0].pos.x, t.world.fighters[0].pos.z).length()
	assert_gt(from_centre, 6.0, "in a corner, near the wall")


func test_the_cord_swings_on_its_spring_bones() -> void:
	var t: LookTest = _look()
	var sk: Skeleton3D = t.cord
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var tip: int = sk.get_bone_count() - 1
	var got: Array = []
	(t.cord_sim as SkeletonModifier3D).modification_processed.connect(func() -> void:
		got.clear()
		got.append(sk.get_bone_global_pose(tip).origin))
	sk.advance(1.0 / 60.0)
	await wait_process_frames(1)
	var rest: Vector3 = got[0] if not got.is_empty() else Vector3.ZERO
	# the saya swings sideways: the tip trails behind, then swings back
	var parent: Node3D = sk.get_parent() as Node3D
	parent.position += parent.basis.x * 0.3
	var most: float = 0.0
	for i: int in 12:
		got.clear()
		sk.advance(1.0 / 60.0)
		await wait_process_frames(1)
		assert_false(got.is_empty(), "the spring bones ran")
		if not got.is_empty():
			most = maxf(most, (got[0] as Vector3).distance_to(rest))
	assert_gt(most, 0.01, "the tip swung off its pose (%.4f m at most)" % most)


## The pilot's effects in the look (milestone-1 task 37): each light's strike
## leaves its air smear, and a staged contact (--contact=) throws the match's
## sparks, white-hot point and contact light at the blade's tip.
func test_the_lights_smear_and_a_staged_parry_throws_sparks() -> void:
	var t: LookTest = _look({"contact": &"parry"})
	assert_not_null(t.effects)
	assert_true(t.effects.lights_allowed, "Ultra lights the contact")
	var smeared: bool = false
	var sparks: int = 0
	var lit: bool = false
	for i: int in 160:
		t._advance()
		t._show(0.0)
		smeared = smeared or t.effects.smear(0, TrailState.RIGHT).sample_count() > 0
		sparks = maxi(sparks, t.effects.spark_count())
		lit = lit or t.effects.lights_shown() > 0
	assert_true(smeared, "the string's strikes smear")
	assert_gte(sparks, EffectTable.count_of({"t": &"parry", "kind": &"parry"}, EffectTable.SPARKS), "a parry's shower")
	assert_true(lit, "and its light")


func test_a_staged_redirect_puffs_and_none_stages_nothing() -> void:
	var t: LookTest = _look({"contact": &"redirect"})
	var puffs: int = 0
	for i: int in 60:
		t._advance()
		t._show(0.0)
		puffs = maxi(puffs, t.effects.puff_count())
		assert_eq(t.effects.spark_count(), 0, "no steel, no sparks")
	assert_gt(puffs, 0, "a bare hand's puff")
	var plain: LookTest = _look()
	for i: int in 60:
		plain._advance()
		plain._show(0.0)
	assert_eq(plain.effects.spark_count() + plain.effects.puff_count(), 0, "nothing staged without --contact")
	assert_eq(plain.read_args(PackedStringArray(["--contact=clash"])), "--contact takes block, heavy_block, parry, flash or redirect, not clash")
