extends GutTest
## The Katana's saya (authored-animation task 11, from godot-rebuild 14.16;
## modelled in milestone-1 task 47): at the left hip whenever the Katana is
## the weapon, holding the blade through the Iai's sheathe and stance.

const SIDES: Array[String] = ["Right", "Left"]


func _view(fighter_id: StringName, weapon_id: StringName) -> FighterView:
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(fighter_id, 0, weapon_id, 0)
	v.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	return v


func test_the_katana_brings_its_saya_and_the_other_weapons_none() -> void:
	for fighter_id: StringName in [&"hunter", &"rogue"]:
		var v: FighterView = _view(fighter_id, &"katana")
		var saya: Node3D = v.model.rig.saya
		assert_not_null(saya, "%s: a saya with the Katana" % fighter_id)
		assert_eq(v.model.rig.saya_frame, Saya.frame_for(fighter_id), "%s: at its own hip" % fighter_id)
	for wid: StringName in [&"greatsword", &"daggers"]:
		assert_null(_view(&"hunter", wid).model.rig.saya, "none with the %s" % wid)


func test_the_saya_holds_the_whole_blade() -> void:
	var v: FighterView = _view(&"hunter", &"katana")
	var saya: Saya = v.model.rig.saya
	var box: AABB = saya.bounds()
	var blade: PackedVector3Array = WeaponLook.blade_segment(v.model.weapons[0])
	for p: Vector3 in blade:
		assert_true(box.grow(0.001).has_point(p), "the blade's %s inside it" % p)
	assert_between(box.size.y, 1.25, 1.5, "as long as the blade")


func test_through_the_iais_stance_the_blade_is_in_the_saya() -> void:
	var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, 8.0)
	var v: FighterView = _view(&"hunter", &"katana")
	var f: Fighter = W.fighters[0]
	var swing: Swing = Moves.KATANA.moves[&"k_iai"].swing
	assert_eq(swing.sheathed.size(), 2, "the Iai's swing gives its sheathed frames")
	for i: int in 30:
		W.step([SimHelpers.btn(Btn.HEAVY), SimHelpers.idle()])
		v.update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, 1.0, 1.0 / 60.0, 0.0)
	assert_true(f.atk != null and f.atk.charging, "in the stance")
	await PoseCheck.frame_of(v.model)
	var rig: FighterRig = v.model.rig
	assert_true(rig.sheathed, "sheathed")
	assert_true(v.model.weapons[0].transform.is_equal_approx(rig.saya.transform), "the katana in the saya")
	# let go: drawn by the first active frame
	while f.state == &"attack" and f.atk.frame < Moves.KATANA.moves[&"k_iai"].startup + 1:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		v.update_from(f, Vector3(f.pos.x, f.pos.y, f.pos.z), f.yaw, 1.0, 1.0 / 60.0, 0.0)
	await PoseCheck.frame_of(v.model)
	assert_false(rig.sheathed, "drawn")
	assert_false(v.model.weapons[0].transform.is_equal_approx(rig.saya.transform), "the katana out of the saya")
