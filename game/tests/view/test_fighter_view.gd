extends GutTest
## FighterView, a side's real fighter in the match: placed where the rules
## put it, its model kept across matches, its weapon posed from the stick
## pose with both hands on the grips through whole attacks, the crouch over
## planted feet, the KO fall, disarming, and the flashes and glows as
## overlays (the legs and the clip on the rules' clock: test_locomotion.gd).

const NEAR: float = 0.01


func before_each() -> void:
	FrozenStateClips.install()


func after_each() -> void:
	FrozenStateClips.restore()
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


## Local-only: through every frame of a light and a heavy attack the Hunter
## holds the weapon in the clip's hand, the off hand on its grip, the elbows
## never locking. The fallback clips can't reach the baked paths.
func test_whole_attacks_keep_the_weapon_in_the_hands() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
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


## A KO plays the director's death (task 28) from the KO on, dimmed: the
## Rogue's own CombatDeath01 for a light from the front, or the CC0 Death01
## without the packs.
func test_a_ko_falls_with_its_death_clip() -> void:
	var W: World = _world()
	var b: Fighter = W.fighters[1]
	var v: FighterView = _view(&"rogue", Moves.KATANA)
	b.to_ko()
	_step(W, 12)
	_update(v, b, 0.5)
	var want: String = "HumanF/CombatDeath01" if v.director.libraries else "ual/Death01"
	assert_eq([v.shot.drive, v.shot.phase, v.shot.clip.name], [ClipDirector.STATE, &"ko", want])
	assert_almost_eq(v.shot.clip.time, float(b.sf) / 60.0, 1e-6, "timed from the KO")
	assert_eq(v.model.rig.leg_weight, 0.0, "the legs go with the fall")
	assert_false(v.foot_lock.enabled, "nothing holds the feet")
	var head: MeshInstance3D = v.model.skeleton.get_node(^"Head")
	assert_not_null(head.material_overlay, "a knocked-out fighter dims")


## A knockdown plays the director's Knockdown01 phases (task 28; the CC0
## stand-ins without the packs), the legs going with the fall.
func test_a_knockdown_falls_lies_and_rises_with_its_clips() -> void:
	var W: World = _world()
	var b: Fighter = W.fighters[1]
	var v: FighterView = _view(&"rogue", Moves.KATANA)
	var packs: bool = v.director.libraries
	b.enter_knockdown()
	_step(W, 11)
	_update(v, b, 0.5)
	assert_eq([v.shot.drive, v.shot.phase, v.shot.clip.name], [ClipDirector.STATE, &"fall", "HumanF/Knockdown01_Fall" if packs else "ual/Hit_Knockback"])
	assert_eq(v.model.rig.leg_weight, 0.0, "the legs go with the fall")
	_step(W, 20)
	_update(v, b, 0.5)
	assert_eq([v.shot.phase, v.shot.clip.name], [&"ground", "HumanF/Knockdown01_Ground" if packs else "ual/LayToIdle"])
	var rise_from: int = b.knockdown_timings().knockdown_fall + b.knockdown_timings().knockdown_ground
	_step(W, rise_from + 10 - b.sf)
	_update(v, b, 1.0)
	assert_eq([v.shot.phase, v.shot.clip.name], [&"standUp", "HumanF/Knockdown01_StandUp" if packs else "ual/LayToIdle"])
	var head: MeshInstance3D = v.model.skeleton.get_node(^"Head")
	assert_null(head.material_overlay, "a knocked-down fighter doesn't dim")


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


## A roll turns the whole model toward the way it rolls, shown between rules
## frames by alpha, and back once it is free (authored-animation task 30).
func test_a_roll_turns_the_model_toward_the_roll() -> void:
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", Moves.KATANA)
	W.step([SimHelpers.move(-1.0, 0.0, Btn.DODGE), SimHelpers.idle()])
	_update(v, f)
	for i: int in 6:
		_step(W)
		_update(v, f)
	assert_eq(f.state, &"dodge")
	assert_almost_eq(v.model.rotation.y, v.shot.turn, 1e-6, "turned by the shot")
	assert_gt(v.model.rotation.y, deg_to_rad(60.0), "toward the left, the way it rolls")
	_update(v, f, 0.5)
	assert_almost_eq(v.model.rotation.y, lerp_angle(v.shot.turn_before, v.shot.turn, 0.5), 1e-6, "between frames by alpha")
	while f.state != &"free":
		_step(W)
		_update(v, f)
	_step(W)
	_update(v, f)
	assert_almost_eq(v.model.rotation.y, 0.0, 1e-6, "facing the opponent again")


## A disarmed fighter picking its weapon up reaches down on Loot01 (task 30)
## with empty hands; the weapon comes back on the pick-up's attach frame, in
## the clip's hand.
func test_a_pick_up_brings_the_weapon_back_into_the_clips_hand() -> void:
	var W: World = _world(Moves.KATANA)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", Moves.KATANA)
	f.armed = false
	f.set_state(&"pickup", SimConst.PICKUP_FRAMES)
	var packs: bool = ClipLibraries.available()
	for sf: int in range(1, SimConst.PICKUP_FRAMES + 1):
		f.sf = sf
		if sf == SimConst.PICKUP_ATTACH_FRAME:
			f.armed = true
		W.frame += 1
		_update(v, f)
		assert_eq(v.shot.drive, ClipDirector.STATE, "frame %d: the pick-up's clip" % sf)
		assert_eq(v.model.weapons.size(), 0 if sf < SimConst.PICKUP_ATTACH_FRAME else 1, "frame %d" % sf)
		if packs:
			assert_eq(v.shot.clip.name.get_file(), "Loot01_Begin" if sf <= SimConst.PICKUP_ATTACH_FRAME else "Loot01_Stop")
		if sf >= SimConst.PICKUP_ATTACH_FRAME:
			assert_true(v.model.rig.is_fixed(), "frame %d: riding the clip's hand" % sf)


# ------------------------------------------------------------------ inertial blending (milestone-1 task 23)

func test_inertial_blending_runs_first_in_the_rig() -> void:
	var v: FighterView = _view(&"hunter", Moves.KATANA)
	var order: Array[StringName] = []
	for child: Node in v.model.skeleton.get_children():
		if child is SkeletonModifier3D:
			order.append(child.name)
	assert_eq(order[0], &"InertialBlend", "right after the clip: %s" % [order])
	for later: StringName in [&"BodyLayer", &"LegIK", &"HandGrip"]:
		assert_gt(order.find(later), 0, "%s after it" % later)
	assert_same(v.model.rig.inertial, v.model.skeleton.get_node(^"InertialBlend"))


# ------------------------------------------------------------------ the physical reaction layer (milestone-1 task 70)

func test_the_reaction_layer_runs_right_after_inertial_blending() -> void:
	var v: FighterView = _view(&"hunter", Moves.KATANA)
	var order: Array[StringName] = []
	for child: Node in v.model.skeleton.get_children():
		if child is SkeletonModifier3D:
			order.append(child.name)
	assert_eq(order[1], &"PhysicalReactionLayer", "after inertial blending: %s" % [order])
	for later: StringName in [&"BodyLayer", &"LegIK", &"HandGrip"]:
		assert_gt(order.find(later), 1, "%s after it" % later)
	assert_same(v.model.rig.reaction, v.model.skeleton.get_node(^"PhysicalReactionLayer"))


func test_the_reaction_layer_runs_on_the_world_s_time_and_a_new_world_clears_it() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", Moves.KATANA)
	_step(W, 3)
	_update(v, f, 0.25)
	assert_almost_eq(v.model.rig.reaction.time, float(W.frame) - 1.0 + 0.25, 1e-9, "the world's frame and alpha")
	v.react(Vector3(0.0, 1.4, 0.2), Vector3(0.0, 1.4, 2.0), 1.0, PhysicalReactionLayer.HIT, 1.0, float(W.frame))
	assert_true(v.model.rig.reaction.reacting())
	var W2: World = _world()
	_update(v, W2.fighters[0])
	assert_false(v.model.rig.reaction.reacting(), "a new match starts still")


func test_a_blow_from_in_front_pushes_the_head_back_wherever_the_fighter_stands() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", Moves.KATANA)
	var at: Vector3 = Vector3(2.0, 0.0, -1.0)
	var yaw: float = 0.7
	v.update_from(f, at, yaw, 1.0, 1.0 / 60.0, 0.0)
	await _posed(v)
	var before: Array[Transform3D] = await _posed(v)
	# the attacker 2 m in front of it (the fighter faces +Z turned by yaw),
	# the blade landing on the chest: on the push's frame (hit-stop holds the
	# world there) the kick shows
	var ahead: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	v.react(at + Vector3(0.0, 1.4, 0.0) + ahead * 0.2, at + Vector3(0.0, 1.4, 0.0) + ahead * 2.0, 1.7,
		PhysicalReactionLayer.HIT, 1.0, float(W.frame))
	v.update_from(f, at, yaw, 1.0, 1.0 / 60.0, 0.0)
	var after: Array[Transform3D] = await _posed(v)
	var head_before: Vector3 = _bone(v, before, "Head").origin
	var head_after: Vector3 = _bone(v, after, "Head").origin
	assert_lt(head_after.z - head_before.z, -0.005, "back, in the fighter's own frame (%s to %s)" % [head_before, head_after])
	assert_almost_eq(head_after.x - head_before.x, 0.0, 0.01, "not to the side")


func test_the_rules_are_the_same_with_the_reaction_layer_off() -> void:
	# picture only: two seeded computer matches, one shown with the layer on
	# and pushed by every hit and block, one with it off, step to the same
	# state
	var hashes: Array[String] = []
	var pushes: Array[int] = []
	for on: bool in [true, false]:
		var W: World = _world()
		var views: Array[FighterView] = [_view(&"hunter", Moves.KATANA), _view(&"rogue", Moves.KATANA, 1)]
		var brains: Array[AIBrain] = [AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"hard"].copy(), 3),
			AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"].copy(), 4)]
		for i: int in 2:
			views[i].model.rig.reaction.active = on
		var pushed: int = 0
		for step: int in 600:
			W.step([brains[0].think(), brains[1].think()])
			for e: Dictionary in W.drain_events():
				var r: Dictionary = MatchView.reaction_of(e, W)
				if not r.is_empty():
					pushed += 1
					views[int(r["side"])].react(r["contact"], r["from"], r["strength"], r["parts"], r["arms"], float(W.frame))
			for i: int in 2:
				_update(views[i], W.fighters[i])
				views[i].model.skeleton.advance(1.0 / 60.0)
		hashes.append(W.state_hash())
		pushes.append(pushed)
	assert_gt(pushes[0], 0, "the match had blows to show")
	assert_eq(hashes[0], hashes[1])


func test_a_hand_off_asks_the_rig_for_its_blend_on_the_world_s_time() -> void:
	var W: World = _world()
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", Moves.KATANA)
	_update(v, f)
	await _posed(v)
	_step(W, 2)
	_update(v, f, 0.5)
	await _posed(v)
	assert_almost_eq(v.model.rig.inertial.time, float(W.frame) - 1.0 + 0.5, 1e-9, "the world's frame and alpha")
	assert_false(v.model.rig.inertial.blending(), "no hand-off yet")
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	_update(v, f, 0.0)
	await _posed(v)
	assert_eq(v.shot.blend, 3, "into an attack")
	assert_true(v.model.rig.inertial.blending(), "the rig blends from the guard")
	for i: int in 4:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		_update(v, f, 0.0)
		await _posed(v)
	assert_false(v.model.rig.inertial.blending(), "done 3 frames on")


func test_the_rules_are_the_same_with_inertial_blending_off() -> void:
	# picture only: two seeded computer matches, one shown with the modifier
	# on and one with it off, step to the same state
	var hashes: Array[String] = []
	for on: bool in [true, false]:
		var W: World = _world()
		var views: Array[FighterView] = [_view(&"hunter", Moves.KATANA), _view(&"rogue", Moves.KATANA, 1)]
		var brains: Array[AIBrain] = [AIBrain.new(W.fighters[0], AIBrain.DIFFICULTY[&"hard"].copy(), 3),
			AIBrain.new(W.fighters[1], AIBrain.DIFFICULTY[&"hard"].copy(), 4)]
		for i: int in 2:
			views[i].model.rig.inertial.active = on
		for step: int in 240:
			W.step([brains[0].think(), brains[1].think()])
			for i: int in 2:
				_update(views[i], W.fighters[i])
				views[i].model.skeleton.advance(1.0 / 60.0)
		hashes.append(W.state_hash())
	assert_eq(hashes[0], hashes[1])


## The hips at the end of the rig's stack, each rules step of Right Cut into
## Return Cut and back to the legs, with inertial blending `on` or off:
## [step, drive, hips].
func _string_hips(on: bool) -> Array[Array]:
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 4.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", Moves.KATANA)
	v.model.rig.inertial.active = on
	var sk: Skeleton3D = v.model.skeleton
	var hips: int = sk.find_bone("Hips")
	var got: Array = []
	(sk.get_node(^"RigCarry") as SkeletonModifier3D).modification_processed.connect(func() -> void:
		got.clear()
		got.append(sk.get_bone_global_pose(hips).origin))
	var out: Array[Array] = []
	# Right Cut, and Return Cut pressed past its startup (task 31's frames),
	# played out to the hand-off back to the legs
	for i: int in 140:
		W.step([SimHelpers.btn(Btn.LIGHT) if i == 12 or i == 42 else SimHelpers.idle(), SimHelpers.idle()])
		_update(v, f)
		got.clear()
		sk.advance(1.0 / 60.0)
		if got.is_empty():
			await wait_process_frames(1)
		out.append([i, v.shot.drive, got[0]])
	return out


func test_the_hand_off_back_to_the_legs_carries_on_from_the_pose_shown() -> void:
	# the stand-in swing body's tail stays off while the blend away from the
	# clip runs (it once dropped the hips 35 cm onto the blended pose)
	var steps: Array[Array] = await _string_hips(true)
	var handed: int = -1
	for i: int in range(1, steps.size()):
		if steps[i][1] == ClipDirector.LEGS and steps[i - 1][1] == ClipDirector.ATTACK:
			handed = i
			break
	assert_gt(handed, 0, "Return Cut hands back to the legs")
	if handed <= 0:
		return
	assert_lt((steps[handed][2] as Vector3).distance_to(steps[handed - 1][2]), 0.01, "the hips where they were shown")
	for i: int in range(handed, mini(handed + 8, steps.size())):
		var rise: float = (steps[i][2] as Vector3).y - (steps[i - 1][2] as Vector3).y
		# rising out of a low follow-through, or settling a little into the
		# guard (Return Cut stands back up before it hands on, task 31)
		assert_true(rise > -0.03 and rise < 0.08, "step %d: the hips carry on smoothly (%.3f m)" % [steps[i][0], rise])
	var cut: Array[Array] = await _string_hips(false)
	assert_gt((cut[handed][2] as Vector3).distance_to(cut[handed - 1][2]), 0.05, "without it the pose jumps")
