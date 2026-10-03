extends GutTest
## The fighter view playing the clip director's answer (authored-animation
## task 8): the idle by weapon class, an attack with a baked swing on its clip
## with the crossfades, the weapon fixed in the Hunter's hand or posed on the
## path, and the "animation packs missing" note. Without the packs (forced
## here, and on CI) the fallback clips play; the Hunter's clip-held weapon
## needs the packs and runs locally.

const CD := preload("res://tests/view/test_clip_director.gd")
const SF := preload("res://tests/sim/swing_fixtures.gd")


func after_each() -> void:
	ClipLibraries.force_missing = false
	SimHelpers.dispose_all()


func _view(fighter_id: StringName, weapon: WeaponDef) -> FighterView:
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(fighter_id, 0, weapon.id, 0)
	v.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	return v


## The Katana with its first light baked from `clips` (CD._baked()).
static func _katana(clips: Array[StringName]) -> WeaponDef:
	var base: AttackDef = Moves.KATANA.moves[&"k_l1"]
	return SF.weapon(&"katana", {&"k_l1": CD._baked(base, clips)} as Dictionary[StringName, Swing])


## Shows `v` for `f` and poses its skeleton once: the weapons' transforms
## and each bone's pose at the end of the stack.
func _show(v: FighterView, f: Fighter) -> Array[Transform3D]:
	v.update_from(f, Vector3.ZERO, 0.0, 1.0, 1.0 / 60.0, 0.0)
	var sk: Skeleton3D = v.model.skeleton
	var poses: Array[Transform3D] = []
	var grab: Callable = func() -> void:
		for i: int in sk.get_bone_count():
			poses.append(sk.get_bone_global_pose(i))
	(sk.get_node(^"RigCarry") as SkeletonModifier3D).modification_processed.connect(grab, CONNECT_ONE_SHOT)
	sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	return poses


func _authored(v: FighterView) -> float:
	return v.locomotion.tree.get("parameters/authored/blend_amount")


func test_the_attack_plays_its_fallback_clip_without_the_packs() -> void:
	ClipLibraries.force_missing = true
	var k: WeaponDef = _katana([&"Attack1H01_R"])
	var W: World = SimHelpers.make_world(k, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"hunter", k)
	assert_false(v.director.libraries)
	for i: int in 3:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		_show(v, f)
	assert_eq(v.shot.idle, "ual/Sword_Idle", "the fallback idle")
	assert_eq(_authored(v), 0.0, "the legs alone")
	W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
	var amounts: Array[float] = []
	var swing: Swing = f.atk.def.swing
	while f.state == &"attack":
		_show(v, f)
		amounts.append(_authored(v))
		var clip: AnimationNodeAnimation = (v.locomotion.tree.tree_root as AnimationNodeBlendTree).get_node(&"clip_a")
		if amounts[-1] > 0.0:
			assert_eq(clip.animation, &"ual/Sword_Attack", "frame %d: the swing's fallback clip" % f.atk.frame)
		assert_false(v.model.rig.is_fixed(), "the fallback's weapon is posed, not in the clip's hand")
		if f.atk.frame >= 8:
			var want: Vector3 = SwingPlayer.to_skeleton(swing.tick(&"right_hand", f.atk.frame - 1).grip)
			assert_lt(v.model.weapons[0].transform.origin.distance_to(want), 0.01, "frame %d: posed on the baked path" % f.atk.frame)
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	assert_eq(amounts[0], 0.0, "the first frame starts the crossfade")
	assert_eq(amounts[3], 1.0, "all of it 3 frames in")
	var after: Array[float] = []
	for i: int in 7:
		_show(v, f)
		after.append(_authored(v))
		W.step([SimHelpers.idle(), SimHelpers.idle()])
	assert_gt(after[0], 0.0, "fading back to the legs")
	assert_eq(after[6], 0.0, "the legs alone 6 frames on")


func test_the_view_stands_in_the_classs_idle_and_holds_planted_feet() -> void:
	var W: World = SimHelpers.make_world(Moves.GREATSWORD, Moves.KATANA, 3.0)
	var f: Fighter = W.fighters[0]
	var v: FighterView = _view(&"rogue", Moves.GREATSWORD)
	_show(v, f)
	var idle: String = ("HumanF/CombatIdle2H01" if ClipLibraries.available() else "ual/Sword_Idle")
	assert_eq(String(v.locomotion.idle_clip()), idle, "the Greatsword's idle under the legs")
	assert_same(v.model.rig.foot_lock, v.foot_lock, "the foot lock under the clips")
	for i: int in 4:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		_show(v, f)
	assert_true(v.foot_lock.holds("Right") and v.foot_lock.holds("Left"), "standing: both feet held")


func test_local_the_hunter_holds_the_weapon_in_the_clips_hand() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var k: WeaponDef = _katana([&"Attack1H01_R"])
	k.moves[&"k_l1"].swing.reach_offset = V3.make(0.0, 0.0, 0.05)
	for id: StringName in FighterLook.IDS:
		var W: World = SimHelpers.make_world(k, Moves.KATANA, 3.0)
		var f: Fighter = W.fighters[0]
		var v: FighterView = _view(id, k)
		_show(v, f)
		W.step([SimHelpers.btn(Btn.LIGHT), SimHelpers.idle()])
		for i: int in 6:
			_show(v, f)
			W.step([SimHelpers.idle(), SimHelpers.idle()])
		var poses: Array[Transform3D] = _show(v, f)
		var clip: AnimationNodeAnimation = (v.locomotion.tree.tree_root as AnimationNodeBlendTree).get_node(&"clip_a")
		assert_eq(String(clip.animation), "%s/Attack1H01_R" % ClipLibraries.FIGHTER_SETS[id], "%s plays the clip of its own set" % id)
		if id == &"hunter":
			assert_true(v.model.rig.is_fixed(), "the Hunter: the weapon rides the clip's hand")
			assert_true(v.model.rig.body.hips_offset.is_equal_approx(SwingPlayer.to_skeleton(k.moves[&"k_l1"].swing.reach_at(SwingPlayer.swing_frame(f, 1.0)))),
				"its reach correction carries the body")
			var hand: Vector3 = poses[v.model.skeleton.find_bone("RightHand")] * v.model.rig.fist("Right").origin
			assert_lt(hand.distance_to(v.model.weapons[0].transform.origin), 0.01, "the hand on the handle")
		else:
			assert_false(v.model.rig.is_fixed(), "the Rogue: the weapon posed on the shared path")


func test_the_hud_notes_the_missing_packs() -> void:
	ClipLibraries.force_missing = true
	var host: MatchHost = (load("res://view/match/match_host.tscn") as PackedScene).instantiate()
	host.auto_run = false
	host.use_services = false
	host.input = InputDevices.new(FakeDeviceState.new())
	host.profiles = ControlProfiles.new()
	add_child_autofree(host)
	var hud: MatchHud = host.get_node("Hud")
	host.start(MatchConfig.make(MatchConfig.WATCH, MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
		MatchSide.computer(&"hunter", &"daggers", 1, &"hard"), 7, ArenaScenes.STANDIN))
	assert_eq(hud.packs_note(), ClipLibraries.MISSING_NOTE, "the note shows")
	ClipLibraries.force_missing = false
	if ClipLibraries.available():
		host.start(MatchConfig.make(MatchConfig.WATCH, MatchSide.computer(&"rogue", &"katana", 0, &"hard"),
			MatchSide.computer(&"hunter", &"daggers", 1, &"hard"), 7, ArenaScenes.STANDIN))
		assert_eq(hud.packs_note(), "", "with the packs, no note")
