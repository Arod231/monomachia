extends GutTest
## FighterView, a side's real fighter in the match: placed where the rules
## put it, its model kept across matches, its weapon posed from the stick
## pose with both hands on the grips through whole attacks, the crouch over
## planted feet, the KO fall, disarming, and the flashes and glows as
## overlays (the legs and the clip on the rules' clock: test_locomotion.gd).

const NEAR: float = 0.01


func after_each() -> void:
	SimHelpers.dispose_all()


func _world(w1: WeaponDef = Moves.KATANA, w2: WeaponDef = Moves.KATANA) -> World:
	return SimHelpers.make_world(w1, w2)


func _view(fighter_id: StringName, weapon: WeaponDef, palette: int = 0) -> FighterView:
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(fighter_id, palette, weapon.id, 0)
	v.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	return v


func _update(v: FighterView, f: Fighter, alpha: float = 1.0) -> void:
	v.update_from(f, Vector3.ZERO, 0.0, alpha, 1.0 / 60.0, 0.0)


func _step(W: World, n: int = 1) -> void:
	for i: int in n:
		W.step([SimHelpers.idle(), SimHelpers.idle()])


## Steps the model's skeleton once and returns every bone's pose in skeleton
## space at the end of the modifier stack.
func _posed(v: FighterView) -> Array[Transform3D]:
	var sk: Skeleton3D = v.model.skeleton
	var poses: Array[Transform3D] = []
	var grab: Callable = func() -> void:
		poses.clear()
		for i: int in sk.get_bone_count():
			poses.append(sk.get_bone_global_pose(i))
	(sk.get_node(^"RigCarry") as SkeletonModifier3D).modification_processed.connect(grab, CONNECT_ONE_SHOT)
	sk.advance(1.0 / 60.0)
	if poses.is_empty():
		await wait_process_frames(1)
	return poses


func _bone(v: FighterView, poses: Array[Transform3D], bone: String) -> Transform3D:
	return poses[v.model.skeleton.find_bone(bone)]


## How far each gripping hand's fist is from its grip point (the worst), in
## a posed skeleton.
func _grip_miss(v: FighterView, poses: Array[Transform3D]) -> float:
	var worst: float = 0.0
	for side: String in FighterRig.SIDES:
		if v.model.rig.drives(side):
			var fist: Vector3 = _bone(v, poses, side + "Hand") * v.model.rig.fist(side).origin
			worst = maxf(worst, fist.distance_to(v.model.rig.grip_point(side)))
	return worst


## The inside angle at an elbow, in degrees (180 is a locked arm).
func _elbow(v: FighterView, poses: Array[Transform3D], side: String) -> float:
	var shoulder: Vector3 = _bone(v, poses, side + "UpperArm").origin
	var elbow: Vector3 = _bone(v, poses, side + "LowerArm").origin
	var wrist: Vector3 = _bone(v, poses, side + "Hand").origin
	return rad_to_deg((shoulder - elbow).angle_to(wrist - elbow))


func test_it_stands_where_the_rules_put_it() -> void:
	var W: World = _world()
	var v: FighterView = _view(&"rogue", Moves.KATANA)
	v.update_from(W.fighters[0], Vector3(1.0, 0.0, 2.0), 0.5, 1.0, 0.016, 0.0)
	assert_eq(v.position, Vector3(1.0, 0.0, 2.0))
	assert_almost_eq(v.rotation.y, 0.5, 1e-6)
	assert_not_null(v.last_pose)
	assert_eq(v.model.get_parent(), v)


## Rematches keep the model: a new palette or weapon goes on the same one,
## and only a new fighter builds another.
func test_the_model_is_kept_while_the_fighter_is_the_same() -> void:
	var v: FighterView = _view(&"hunter", Moves.GREATSWORD, 1)
	var model: FighterModel = v.model
	assert_eq(model.palette, 1)
	assert_eq(model.weapon_look.id, &"greatsword")
	v.setup(&"hunter", 0, &"daggers", 1)
	assert_eq(v.model, model, "the same model")
	assert_eq(model.palette, 0, "in the new palette")
	assert_eq(model.weapons.size(), 2, "holding the new weapon")
	v.setup(&"rogue", 0, &"daggers", 1)
	assert_ne(v.model, model, "a new fighter builds a new model")
	assert_eq(v.model.look.id, &"rogue")
	await wait_process_frames(1)
	assert_false(is_instance_valid(model), "the old one is freed")


## Each fighter with each weapon in its guard: the weapon is posed along the
## stick pose's blade, and both hands are on its grips.
func test_the_guard_puts_the_weapon_in_both_hands() -> void:
	for id: StringName in FighterLook.IDS:
		for weapon: WeaponDef in [Moves.KATANA, Moves.GREATSWORD, Moves.DAGGERS]:
			var W: World = _world(weapon)
			var v: FighterView = _view(id, weapon)
			_update(v, W.fighters[0])
			var hands: Array[StickPose.Hand] = [v.last_pose.right, v.last_pose.left]
			for i: int in v.model.weapons.size():
				assert_true(v.model.rig.is_posed(i))
				assert_almost_eq(v.model.weapons[i].transform.basis.y, hands[i].dir, Vector3.ONE * 1e-4, "%s %s: along the stick" % [id, weapon.id])
			assert_true(v.model.rig.drives("Right") and v.model.rig.drives("Left"), "%s %s: both hands on it" % [id, weapon.id])
			var poses: Array[Transform3D] = await _posed(v)
			assert_lt(_grip_miss(v, poses), NEAR, "%s %s: the grips land" % [id, weapon.id])


## Through every frame of a light and a heavy attack the hands stay on the
## grips and the elbows never lock: stick poses out of reach are pulled in.
func test_whole_attacks_keep_the_weapon_in_the_hands() -> void:
	for weapon: WeaponDef in [Moves.KATANA, Moves.GREATSWORD, Moves.DAGGERS]:
		for button: int in [Btn.LIGHT, Btn.HEAVY]:
			var W: World = _world(weapon)
			var f: Fighter = W.fighters[0]
			var v: FighterView = _view(&"hunter", weapon)
			W.step([SimHelpers.btn(button), SimHelpers.idle()])
			var frames: int = 0
			var worst: float = 0.0
			var straightest: float = 0.0
			while f.state == &"attack" and frames < 200:
				_update(v, f)
				var poses: Array[Transform3D] = await _posed(v)
				worst = maxf(worst, _grip_miss(v, poses))
				for side: String in FighterRig.SIDES:
					if v.model.rig.drives(side):
						straightest = maxf(straightest, _elbow(v, poses, side))
				W.step([SimHelpers.btn(button) if f.atk != null and f.atk.charging else SimHelpers.idle(), SimHelpers.idle()])
				frames += 1
			gut.p("%s %s: %d frames, grips within %.1f mm, elbows at most %.0f deg" % [weapon.id, "light" if button == Btn.LIGHT else "heavy", frames, worst * 1000.0, straightest])
			assert_gt(frames, 5, "%s attacked" % weapon.id)
			assert_lt(worst, NEAR, "%s: the hands stay on the grips" % weapon.id)
			assert_lt(straightest, 175.0, "%s: the elbows never lock" % weapon.id)


## A slash's edge leads the sweep; a thrust's, with no sideways sweep, faces
## down and forward like the guard's.
func test_the_edge_leads_the_strike() -> void:
	var blade: Vector3 = Vector3(1.0, 0.0, 0.2).normalized()
	var edge: Vector3 = FighterView.edge_for(blade, Vector3(-0.9, 0.0, 0.8))
	assert_almost_eq(edge.dot(blade), 0.0, 1e-5, "square to the blade")
	assert_gt(edge.z, 0.9, "facing the way the tip sweeps")
	var thrust: Vector3 = FighterView.edge_for(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 0.6))
	assert_almost_eq(thrust, Vector3(0.0, -1.0, 0.0), Vector3.ONE * 1e-5, "a thrust's edge faces down")
	var guard: Vector3 = FighterView.edge_for(Vector3(0.0, 0.6, 0.8), Vector3.ZERO)
	assert_lt(guard.y, -0.5, "a guard's edge faces down")


## A crouch drops the hips; the feet stay planted, the knees bending
## instead: in the Katana's guard stance where the stance has them, and with
## the Greatsword where the clip has them.
func test_a_crouch_lowers_the_hips_over_planted_feet() -> void:
	for weapon: WeaponDef in [Moves.KATANA, Moves.GREATSWORD]:
		var W: World = _world(weapon)
		var f: Fighter = W.fighters[0]
		var v: FighterView = _view(&"rogue", weapon)
		_update(v, f)
		var standing: Array[Transform3D] = await _posed(v)
		f.state = &"land"
		_update(v, f)
		assert_almost_eq(v.last_pose.crouch, 0.18, 1e-6)
		var crouched: Array[Transform3D] = await _posed(v)
		assert_almost_eq(_bone(v, standing, "Hips").origin.y - _bone(v, crouched, "Hips").origin.y, 0.18, 0.005, "%s: the hips drop by the crouch" % weapon.id)
		for side: String in FighterRig.SIDES:
			var planted: Vector3 = _bone(v, standing, side + "Foot").origin
			if weapon == Moves.GREATSWORD:
				planted = v.model.rig.body.clip_feet[side].origin
			assert_lt(_bone(v, crouched, side + "Foot").origin.distance_to(planted), NEAR, "%s: %s foot planted" % [weapon.id, side])
			assert_gt(_bone(v, crouched, side + "LowerLeg").origin.z, _bone(v, standing, side + "LowerLeg").origin.z, "%s: %s knee bends forward" % [weapon.id, side])


## A KO lets go of the pose and plays the fall from the KO on, dimmed.
func test_a_ko_falls_with_the_death_clip() -> void:
	var W: World = _world()
	var b: Fighter = W.fighters[1]
	var v: FighterView = _view(&"rogue", Moves.KATANA)
	b.to_ko()
	_step(W, 12)
	_update(v, b, 0.5)
	var ap: AnimationPlayer = v.model.animation_player
	assert_eq(ap.current_animation, "ual/" + String(FighterView.DEATH_CLIP))
	assert_almost_eq(ap.current_animation_position, (b.sf - 1 + 0.5) / 60.0, 1e-4, "timed from the KO")
	assert_false(v.model.rig.drives("Right"), "the arms go with the fall")
	var head: MeshInstance3D = v.model.skeleton.get_node(^"Head")
	assert_not_null(head.material_overlay, "a knocked-out fighter dims")


func test_a_disarmed_fighter_holds_nothing_until_rearmed() -> void:
	var W: World = _world(Moves.DAGGERS)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", Moves.DAGGERS)
	f.armed = false
	_update(v, f)
	assert_eq(v.model.weapons.size(), 0, "empty hands")
	assert_false(v.model.rig.drives("Right"))
	f.armed = true
	_update(v, f)
	assert_eq(v.model.weapons.size(), 2, "the daggers back in hand")
	assert_true(v.model.rig.drives("Left"))


## A hit flashes the body through an overlay that fades on the rules'
## frames, over toon materials left as they were; an unblockable's wind-up
## lights the blade.
func test_flashes_and_glows_are_overlays() -> void:
	var W: World = _world(Moves.GREATSWORD)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", Moves.GREATSWORD)
	var head: MeshInstance3D = v.model.skeleton.get_node(^"Head")
	var skin: Material = head.get_active_material(0)
	v.flash(Color.RED, 0.5, W.frame)
	_update(v, f)
	var overlay: StandardMaterial3D = head.material_overlay
	assert_not_null(overlay, "lit")
	assert_almost_eq(overlay.albedo_color.a, 0.5, 1e-6)
	assert_eq(head.get_active_material(0), skin, "the toon skin is untouched")
	_step(W, 5)
	_update(v, f)
	assert_null(head.material_overlay, "faded out five frames on")
	var blade: MeshInstance3D = v.model.weapons[0].get_node(^"Mesh")
	assert_null(blade.material_overlay)
	f.start_attack(&"g_sweep")
	_step(W)
	_update(v, f)
	var glow: StandardMaterial3D = blade.material_overlay
	assert_not_null(glow, "the unblockable glows")
	assert_eq(glow.blend_mode, BaseMaterial3D.BLEND_MODE_ADD)
	assert_gt(glow.albedo_color.r, glow.albedo_color.g * 3.0, "red")


func test_the_floor_ring_wears_the_side_colour() -> void:
	var v: FighterView = _view(&"rogue", Moves.KATANA, 1)
	var ring: MeshInstance3D = v.get_node(^"FloorMarks/SideRing")
	assert_eq((ring.material_override as StandardMaterial3D).albedo_color, LookPalette.side_color(1).lightened(0.2))
	assert_eq(v.side_color(), LookPalette.SIDE_COLORS[1])
