extends GutTest
## The bake (tools/swing_bake.gd, authored-animation task 6): markers onto
## rules frames at a speed, the sampled poses into a baked swing that
## SwingFile reads back, and the frame data. The poses come from a CC0 UAL
## clip on the Hunter (ClipPoser), so CI needs no Iglesias packs.

const CLIP: String = "ual/Sword_Attack"
const MM: float = 0.001
## Markers in source frames: a wind-up start, a contact start and end and a
## settle, all inside Sword_Attack (46 frames).
const MARKERS: Dictionary = {"windup": 2, "contact": 12, "contact_end": 17, "settle": 30}


func _hunter(weapon: StringName) -> FighterModel:
	var f: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	f.autoplay_idle = false
	add_child_autofree(f)
	if weapon != &"":
		f.attach_weapon(WeaponLook.load_id(weapon))
	return f


func _bake(poser: ClipPoser, speed: float, parts: Array[StringName]) -> SwingBake.Result:
	var errors: Array[String] = []
	var r: SwingBake.Result = SwingBake.bake(poser.pose, poser.length, MARKERS, speed, parts, errors)
	assert_eq(errors, [] as Array[String])
	return r


## A move with the timing's frames, for SwingFile to read a baked swing on.
static func _moves(t: ClipTiming) -> Dictionary[StringName, AttackDef]:
	return AttackDef.finalize_moves({&"t_cut": {"id": &"t_cut", "name": "Test Cut", "kind": &"light", "type": &"slash",
		"startup": t.startup, "active": t.active, "recovery": t.recovery, "damage": 5, "posture": 5}})


func test_the_markers_land_on_their_rules_frames() -> void:
	var errors: Array[String] = []
	var markers: Dictionary = {"windup": 10, "contact": 20, "contact_end": 26, "settle": 50}
	var t: ClipTiming = SwingBake.timing(markers, 1.25, errors)
	assert_eq(errors, [] as Array[String])
	# 60 rules frames a second, the clip at 30 fps × 1.25: 1.6 rules frames
	# per source frame from the wind-up start
	assert_eq([t.startup, t.active, t.recovery, t.total()], [16, 10, 38, 64])
	assert_eq(t.frames, PackedInt32Array([0, 16, 26, 64]))
	assert_almost_eq(t.clip_time(0.0), 10.0 / 30.0, 1e-12, "the wind-up start on frame 0")
	assert_almost_eq(t.clip_time(16.0), 20.0 / 30.0, 1e-12, "the contact start on the last startup frame")
	assert_almost_eq(t.clip_time(26.0), 26.0 / 30.0, 1e-12, "the contact end on the last active frame")
	assert_almost_eq(t.clip_time(64.0), 50.0 / 30.0, 1e-12, "the settle on the last frame")
	assert_almost_eq(t.clip_time(8.0), 15.0 / 30.0, 1e-12, "even between them")
	assert_almost_eq(t.clip_time(70.0), 50.0 / 30.0, 1e-12, "past the end holds the settle")
	var slow: ClipTiming = SwingBake.timing(markers, 1.0, errors)
	assert_eq([slow.startup, slow.active, slow.recovery], [20, 12, 48], "at the clip's own speed, two rules frames a source frame")
	var fast: ClipTiming = SwingBake.timing(markers, 2.0, errors)
	assert_eq([fast.startup, fast.active, fast.recovery], [10, 6, 24])
	var short: ClipTiming = SwingBake.timing({"windup": 0, "contact": 3, "contact_end": 3.2, "settle": 9}, 2.0, errors)
	assert_eq(short.active, 1, "each stretch takes at least a frame")


func test_the_speed_is_picked_for_the_startup() -> void:
	var markers: Dictionary = {"windup": 10, "contact": 20, "contact_end": 26, "settle": 50}
	assert_eq(SwingBake.pick_speed(markers, 16), 1.25, "the slowest speed with a 16-frame startup")
	assert_eq(SwingBake.pick_speed(markers, 30), 1.0, "too slow for the clip: as slow as it goes")
	var errors0: Array[String] = []
	assert_eq(SwingBake.timing(markers, SwingBake.pick_speed(markers, 4), errors0).startup, 10, "too fast: as few frames as it goes")
	var errors: Array[String] = []
	assert_eq(SwingBake.timing(markers, SwingBake.pick_speed(markers, 13), errors).startup, 13)


func test_bad_markers_and_speeds_are_refused() -> void:
	var errors: Array[String] = []
	assert_null(SwingBake.timing(MARKERS, 0.9, errors))
	assert_eq(errors, ["speed 0.9 is outside 1.0-2.0"] as Array[String])
	errors.clear()
	assert_null(SwingBake.timing(MARKERS, 2.1, errors))
	assert_eq(errors.size(), 1, "too fast")
	errors.clear()
	var missing: Dictionary = MARKERS.duplicate()
	missing.erase("contact_end")
	assert_null(SwingBake.timing(missing, 1.5, errors))
	assert_eq(errors, ["no contact_end marker"] as Array[String])
	errors.clear()
	var unordered: Dictionary = MARKERS.duplicate()
	unordered["contact"] = 1
	assert_null(SwingBake.timing(unordered, 1.5, errors))
	assert_string_contains(errors[0], "the contact marker (1) must come after the windup marker")
	errors.clear()
	var late: Dictionary = MARKERS.duplicate()
	late["settle"] = 999
	var poser: ClipPoser = ClipPoser.new(_hunter(&"katana"), [CLIP])
	assert_null(SwingBake.bake(poser.pose, poser.length, late, 1.5, [&"right_hand"] as Array[StringName], errors))
	assert_string_contains(errors[0], "the settle marker (999) is past the clip's end")


func test_the_samples_match_the_posed_hand() -> void:
	# the Daggers: each in its own hand, no IK, so the bone pose tells where
	# the weapon must be
	var f: FighterModel = _hunter(&"daggers")
	var poser: ClipPoser = ClipPoser.new(f, [CLIP])
	var r: SwingBake.Result = _bake(poser, 1.5, [&"right_hand", &"left_hand", &"body"] as Array[StringName])
	assert_eq(r.tracks.keys(), [&"right_hand", &"left_hand", &"body"])
	assert_eq(r.times.size(), r.timing.total() + 1, "a pose on every rules frame")
	# (not the last frame: the bake posed it last, so the poser gives it from
	# its cache without updating)
	for frame: int in [0, r.timing.startup, r.timing.startup + r.timing.active, r.timing.total() - 1]:
		var bones: Dictionary[String, Transform3D] = {}
		var sk: Skeleton3D = f.skeleton
		var grab: Callable = func() -> void:
			for side: String in FighterRig.SIDES:
				bones[side] = sk.get_bone_global_pose(sk.find_bone(side + "Hand")) * f.rig.fixed_grip(side)
		(sk.get_node(^"RigCarry") as SkeletonModifier3D).modification_processed.connect(grab, CONNECT_ONE_SHOT)
		poser.pose(r.times[frame])
		for side: String in FighterRig.SIDES:
			var part: StringName = &"right_hand" if side == "Right" else &"left_hand"
			var s: Swing.Sample = r.tracks[part][frame]
			var want: Vector3 = bones[side].origin
			var got: Vector3 = SwingPlayer.to_skeleton(s.grip)
			assert_lt(got.distance_to(want), MM, "frame %d %s: grip %.2f mm off the posed hand" % [frame, side, got.distance_to(want) * 1000.0])
			assert_gt(SwingPlayer.to_skeleton(s.blade).dot(bones[side].basis.y.normalized()), 0.99999, "frame %d %s: the blade" % [frame, side])
			assert_gt(SwingPlayer.to_skeleton(s.edge).dot(bones[side].basis.x.normalized()), 0.99999, "frame %d %s: the edge" % [frame, side])
	# the Katana: the weapon read is the one shown, off-hand IK and all
	var k: FighterModel = _hunter(&"katana")
	var kp: ClipPoser = ClipPoser.new(k, [CLIP])
	var kr: SwingBake.Result = _bake(kp, 1.5, [&"right_hand", &"body"] as Array[StringName])
	for frame: int in [3, kr.timing.startup + 1]:
		kp.pose(kr.times[frame])
		var got: Vector3 = SwingPlayer.to_skeleton((kr.tracks[&"right_hand"][frame] as Swing.Sample).grip)
		assert_lt(got.distance_to(k.weapons[0].transform.origin), MM, "the Katana's grip where it is shown")


func test_the_body_reads_the_hips_and_chest() -> void:
	var f: FighterModel = _hunter(&"katana")
	var poser: ClipPoser = ClipPoser.new(f, [CLIP])
	var r: SwingBake.Result = _bake(poser, 1.0, [&"right_hand", &"body"] as Array[StringName])
	# Sword_Attack winds up to the right and lunges into a cut across to the
	# left, the hips dropping low
	var body: Array = r.tracks[&"body"]
	var first: Swing.Sample = body[0]
	var most_left: float = 0.0
	var lowest: float = 0.0
	for s: Swing.Sample in body:
		most_left = minf(most_left, s.torso)
		lowest = minf(lowest, s.pelvis_shift.y)
		assert_lt(absf(s.torso - s.pelvis), 90.0, "the chest stays within a quarter turn of the hips")
	assert_gt(first.torso, 30.0, "wound up to the right")
	assert_gt(first.torso, first.pelvis, "the chest wound further than the hips")
	assert_lt(most_left, -90.0, "cut across to the left")
	assert_lt(lowest, -0.3, "the lunge drops the hips")


func test_the_bake_is_deterministic() -> void:
	var texts: Array[String] = []
	for i: int in 2:
		var poser: ClipPoser = ClipPoser.new(_hunter(&"katana"), [CLIP])
		var r: SwingBake.Result = _bake(poser, 1.35, [&"right_hand", &"body"] as Array[StringName])
		texts.append(SwingBake.file_text(SwingBake.guard_record(poser.pose(0.0)), {"t_cut": r.record()}))
	assert_eq(texts[0], texts[1])


func test_a_baked_file_round_trips() -> void:
	var poser: ClipPoser = ClipPoser.new(_hunter(&"katana"), [CLIP])
	var r: SwingBake.Result = _bake(poser, 1.5, [&"right_hand", &"body"] as Array[StringName])
	var text: String = SwingBake.file_text(SwingBake.guard_record(poser.pose(0.0)), {"t_cut": r.record()})
	var swings: Dictionary[StringName, Swing] = SwingFile.parse(text, _moves(r.timing), "baked.json")
	assert_eq(swings.keys(), [&"t_cut"], "read without an error")
	var swing: Swing = swings[&"t_cut"]
	assert_eq(swing.parts(), [&"right_hand", &"body"] as Array[StringName])
	assert_true(swing.is_baked(&"right_hand"))
	for f: int in r.timing.total() + 1:
		var want: Swing.Sample = r.tracks[&"right_hand"][f]
		var got: Swing.Sample = swing.tick(&"right_hand", f)
		assert_lt(V3.distance(got.grip, want.grip), 1e-4, "frame %d: the grip, to the decimals written" % f)
		assert_gt(V3.dot(got.blade, want.blade), 0.9999, "frame %d: the blade" % f)
		var body: Swing.Sample = swing.tick(&"body", f)
		assert_almost_eq(body.torso, (r.tracks[&"body"][f] as Swing.Sample).torso, 0.01, "frame %d: the torso" % f)
	# rewritten from what was read, the text is the same
	var again: Dictionary = JSON.parse_string(text)
	assert_eq(SwingBake.file_text(again["guard"], again["swings"]), text, "a file rewrites to itself")


func test_the_parts_each_weapon_bakes() -> void:
	var k: WeaponDef = Moves.WEAPONS[&"katana"]
	assert_eq(SwingBake.parts_for(k.moves[k.light_start], k), [&"right_hand", &"body"] as Array[StringName])
	var d: WeaponDef = Moves.WEAPONS[&"daggers"]
	assert_eq(SwingBake.parts_for(d.moves[d.light_start], d), [&"right_hand", &"left_hand", &"body"] as Array[StringName])
	var fists: WeaponDef = Moves.FISTS
	for id: StringName in fists.moves:
		var m: AttackDef = fists.moves[id]
		var parts: Array[StringName] = SwingBake.parts_for(m, fists)
		var limb: String = "hand"
		if m.type == &"kick":
			limb = "knee" if SwingBake.KNEE_STRIKES.has(id) else "foot"
		assert_true(parts.has(StringName(("left_" if m.hand == &"L" else "right_") + limb)), "%s strikes with its %s %s" % [id, m.hand, limb])
		assert_eq(parts[-1], &"body")


func test_a_bash_strikes_with_its_left_shoulder() -> void:
	# task 19: Shoulder Charge and Guard Crusher, the weapon riding the hands
	var g: WeaponDef = Moves.GREATSWORD
	for id: StringName in [&"g_sl", &"g_crush"]:
		assert_eq(SwingBake.parts_for(g.moves[id], g), [&"left_shoulder", &"body"] as Array[StringName], String(id))
	var segment: StrikeSegment = Swing.strike_segment(&"left_shoulder", g)
	assert_eq([segment.base.y, segment.tip.y, segment.thickness],
		[SimConst.SHOULDER_STRIKE_BASE, SimConst.SHOULDER_STRIKE_TIP, SimConst.SHOULDER_STRIKE_THICKNESS], "any weapon's bash shoulder")
	assert_eq(Swing.strike_segment(&"right_shoulder", Moves.KATANA).thickness, SimConst.SHOULDER_STRIKE_THICKNESS)


func test_the_flying_knee_strikes_with_its_knee() -> void:
	# task 25: the knee and shin, down from the knee joint
	var fists: WeaponDef = Moves.FISTS
	assert_eq(SwingBake.parts_for(fists.moves[&"f_sl"], fists), [&"right_knee", &"body"] as Array[StringName])
	assert_eq(SwingBake.parts_for(fists.moves[&"f_bl"], fists), [&"left_foot", &"body"] as Array[StringName], "Snap Kick, the left leg")
	var segment: StrikeSegment = Swing.strike_segment(&"right_knee", fists)
	assert_eq([segment.base.y, segment.tip.y, segment.thickness],
		[SimConst.KNEE_STRIKE_BASE, SimConst.KNEE_STRIKE_TIP, SimConst.KNEE_STRIKE_THICKNESS])


func test_a_knees_sample_is_its_joint_facing_down_the_shin() -> void:
	var f: FighterModel = _hunter(&"katana")
	var poser: ClipPoser = ClipPoser.new(f, ["ual/Sword_Idle"] as Array[String])
	var p: Dictionary = poser.pose(0.2)
	var sk: Skeleton3D = f.skeleton
	for side: String in ["Left", "Right"]:
		var s: Swing.Sample = p[StringName(side.to_lower() + "_knee")]
		var knee: Vector3 = sk.get_bone_global_pose(sk.find_bone(side + "LowerLeg")).origin
		var foot: Vector3 = sk.get_bone_global_pose(sk.find_bone(side + "Foot")).origin
		var want: V3 = ClipPoser.to_fighter(knee)
		assert_lt(V3.length(V3.sub(s.grip, want)), 0.001, "%s knee at its joint" % side)
		var down: V3 = ClipPoser.to_fighter((foot - knee).normalized())
		assert_almost_eq(V3.dot(s.blade, down), 1.0, 0.001, "%s blade down the shin" % side)
		assert_gt(s.edge.z, 0.0, "%s edge to the shin's front" % side)
		assert_almost_eq(V3.dot(s.edge, s.blade), 0.0, 0.001)


func test_a_shoulders_sample_is_its_joint_facing_out_along_the_shoulders() -> void:
	var f: FighterModel = _hunter(&"greatsword")
	var poser: ClipPoser = ClipPoser.new(f, ["ual/Sword_Idle"] as Array[String])
	var p: Dictionary = poser.pose(0.2)
	var sk: Skeleton3D = f.skeleton
	for side: String in ["Left", "Right"]:
		var s: Swing.Sample = p[StringName(side.to_lower() + "_shoulder")]
		var joint: V3 = ClipPoser.to_fighter(sk.get_bone_global_pose(sk.find_bone(side + "UpperArm")).origin)
		# (read after the whole stack; the off hand's IK, after the capture,
		# moves the left shoulder a little)
		assert_almost_eq(V3.length(V3.sub(s.grip, joint)), 0.0, 0.02, "%s: at the joint" % side)
		# out along the shoulder line: to the fighter's left for the left (+X is right)
		assert_true(s.blade.x < -0.5 if side == "Left" else s.blade.x > 0.5, "%s: out along the shoulders (%s)" % [side, s.blade.x])
		assert_gt(s.edge.z, 0.5, "%s: its edge forward" % side)


func test_a_chain_plays_its_clips_one_after_another() -> void:
	var f: FighterModel = _hunter(&"katana")
	var first: float = f.animation_player.get_animation("ual/Sword_Regular_A").length
	var chained: ClipPoser = ClipPoser.new(f, ["ual/Sword_Regular_A", "ual/Sword_Regular_A_Rec"] as Array[String])
	assert_almost_eq(chained.length, first + f.animation_player.get_animation("ual/Sword_Regular_A_Rec").length, 1e-6)
	var later: V3 = (chained.pose(first + 0.3)[&"right_hand"] as Swing.Sample).grip
	var alone: ClipPoser = ClipPoser.new(f, ["ual/Sword_Regular_A_Rec"] as Array[String])
	var want: V3 = (alone.pose(0.3)[&"right_hand"] as Swing.Sample).grip
	assert_lt(V3.distance(later, want), 1e-6, "0.3 s into the second clip")
	var errors: Array[String] = []
	var markers: Dictionary = {"windup": 0, "contact": 6, "contact_end": 10, "settle": 30}
	var r: SwingBake.Result = SwingBake.bake(chained.pose, chained.length, markers, 1.0, [&"right_hand"] as Array[StringName], errors)
	assert_eq(errors, [] as Array[String], "markers on the chain's frames, the settle in the second clip")
	assert_eq(r.timing.total(), 60)


const BakeSwings := preload("res://tools/bake_swings.gd")


func test_local_every_swing_file_matches_a_fresh_bake() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var manifest: ClipManifest = ClipManifest.read()
	var table: MoveClips = MoveClips.read(manifest)
	var checked: int = 0
	for wid: StringName in table.moves:
		if table.of(wid).is_empty():
			continue
		var path: String = SwingFile.path_for(wid)
		var old: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var out: Dictionary = BakeSwings.bake_weapon(wid, table, manifest, self, old)
		assert_eq(out["errors"], [] as Array[String], "%s bakes" % wid)
		assert_eq(out["text"], old, "%s's swing file is what a fresh bake writes (node scripts/godot.mjs bake)" % wid)
		checked += 1
	assert_true(checked <= table.moves.size(), "%d weapons re-baked" % checked)


func test_local_a_move_bakes_from_an_iglesias_clip() -> void:
	if not ClipLibraries.available():
		pending("local-only: no clip libraries (node scripts/godot.mjs clips)")
		return
	var manifest: ClipManifest = ClipManifest.read()
	var path: String = "user://move_clips_bake_test.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"katana": {"guard": "CombatIdle1H01", "moves": {"k_l1": {"clips": ["Attack1H01_R"]}}}}))
	f.close()
	var table: MoveClips = MoveClips.read(manifest, path)
	DirAccess.remove_absolute(path)
	var out: Dictionary = BakeSwings.bake_weapon(&"katana", table, manifest, self, "")
	assert_eq(out["errors"], [] as Array[String])
	assert_eq((out["report"] as PackedStringArray).size(), 1)
	assert_string_contains(out["report"][0], "k_l1 (Attack1H01_R ×")
	assert_string_contains(out["report"][0], "reach from 2.5 m: ", "the reach, measured from the duelling distance")
	assert_string_contains(out["report"][0], "Rogue: HumanF ", "the Rogue's clip, measured")
	var data: Dictionary = JSON.parse_string(out["text"])
	assert_eq(data["guard"].keys(), ["right_hand", "body"], "the guard has the parts the swings move")
	var track: Dictionary = data["swings"]["k_l1"]["tracks"]["right_hand"]
	assert_true(track["baked"])
	var k_l1: AttackDef = (Moves.WEAPONS[&"katana"] as WeaponDef).moves[&"k_l1"]
	var markers: Dictionary = MoveClips.markers(table.of(&"katana")[&"k_l1"], manifest, PackedFloat64Array([0.0]))
	var t: ClipTiming = ClipTiming.make(markers, SwingBake.pick_speed(markers, k_l1.startup), [] as Array[String])
	assert_eq((track["keys"] as Array).size(), t.total() + 1, "a key on every rules frame")
	for key: Dictionary in track["keys"]:
		var grip: Array = key["grip"]
		assert_between(float(grip[1]), 0.3, 2.2, "frame %d: the grip at a hand's height" % key["frame"])
		assert_lt(Vector2(grip[0], grip[2]).length(), 1.4, "frame %d: the grip within an arm's reach and the clip's step" % key["frame"])


# --- task 7: the reach correction and the Rogue's paths -----------------------

func _katana_cut(speed: float) -> Array:
	var f: FighterModel = _hunter(&"katana")
	var poser: ClipPoser = ClipPoser.new(f, [CLIP])
	return [f, poser, _bake(poser, speed, [&"right_hand", &"body"] as Array[StringName])]



func test_the_reach_correction_eases_in_and_out_and_is_zero_outside_the_attack() -> void:
	# startup 10, active 4, last frame 30
	assert_eq(Swing.reach_weight_at(0.0, 10, 4, 30), 0.0, "none on frame 0")
	assert_eq(Swing.reach_weight_at(-3.0, 10, 4, 30), 0.0)
	assert_almost_eq(Swing.reach_weight_at(5.0, 10, 4, 30), 0.5, 1e-9, "easing in over the wind-up")
	for f: int in range(10, 15):
		assert_eq(Swing.reach_weight_at(float(f), 10, 4, 30), 1.0, "all of it on frame %d" % f)
	assert_almost_eq(Swing.reach_weight_at(22.0, 10, 4, 30), 0.5, 1e-9, "easing out over the recovery")
	assert_eq(Swing.reach_weight_at(30.0, 10, 4, 30), 0.0, "none on the last frame")
	assert_eq(Swing.reach_weight_at(40.0, 10, 4, 30), 0.0)


func test_a_short_light_is_pushed_toward_the_reach_rule() -> void:
	var k: WeaponDef = Moves.WEAPONS[&"katana"]
	var cut: AttackDef = k.moves[&"k_l1"]
	var got: Array = _katana_cut(1.5)
	var r: SwingBake.Result = got[2]
	var raw: Array = (r.tracks[&"right_hand"] as Array).duplicate()
	# a distance where the cut puts about 8 cm in: short of the rule's 15
	var near: SwingBake.Reach = SwingBake.correct_reach(r, cut, k, 1.5)
	assert_gt(near.before, SwingBake.LIGHT_MAX_INSIDE, "from 1.5 m it goes deep")
	assert_true(near.over, "a light over 20 cm in is reported")
	assert_eq(V3.length(near.offset), 0.0, "and not pulled back")
	var d: float = 1.5 + near.before - 0.08
	got = _katana_cut(1.5)
	r = got[2]
	var reach: SwingBake.Reach = SwingBake.correct_reach(r, cut, k, d)
	assert_between(reach.before, 0.0, SwingBake.LIGHT_MIN_INSIDE, "short of 15 cm before")
	assert_false(reach.short)
	assert_gt(V3.length(reach.offset), 0.0, "pushed")
	assert_lte(V3.length(reach.offset), SwingBake.MAX_REACH, "at most 15 cm")
	assert_gte(reach.after, SwingBake.LIGHT_AIM - 0.002, "into the rule's band")
	assert_lte(reach.after, SwingBake.LIGHT_MAX_INSIDE)
	assert_eq(V3.length(V3.sub(r.reach_offset, reach.offset)), 0.0, "kept with the swing")
	var t: ClipTiming = r.timing
	for f: int in [0, t.total()]:
		assert_eq(V3.distance((r.tracks[&"right_hand"][f] as Swing.Sample).grip, (raw[f] as Swing.Sample).grip), 0.0, "frame %d untouched" % f)
	var moved: float = V3.distance((r.tracks[&"right_hand"][t.startup + 1] as Swing.Sample).grip, (raw[t.startup + 1] as Swing.Sample).grip)
	assert_almost_eq(moved, V3.length(reach.offset), 1e-9, "all of it in the active frames")
	var swing: Swing = SwingFile.parse(SwingBake.file_text(SwingBake.guard_record(got[1].pose(0.0)), {"t_cut": r.record()}),
		_moves(t), "reach.json")[&"t_cut"]
	assert_lt(V3.distance(swing.reach_offset, reach.offset), 1e-4, "the swing file carries it")
	assert_lt(V3.distance(swing.reach_at(float(t.startup + 1)), reach.offset), 1e-4)


func test_a_move_that_needs_more_than_15_cm_is_reported() -> void:
	var k: WeaponDef = Moves.WEAPONS[&"katana"]
	var r: SwingBake.Result = _katana_cut(1.5)[2]
	# the CC0 cut's tip gets 1.26 m ahead: from the Katana's 2.5 m it can't
	# reach the defender, however far the arm goes
	var reach: SwingBake.Reach = SwingBake.correct_reach(r, k.moves[&"k_l1"], k)
	assert_eq(reach.distance, k.duel_distance, "a light is tested from its duelling distance")
	assert_true(reach.short)
	assert_almost_eq(V3.length(reach.offset), SwingBake.MAX_REACH, 1e-9, "the most is applied")


func test_the_visible_blade_follows_the_corrected_path() -> void:
	var got: Array = _katana_cut(1.5)
	var f: FighterModel = got[0]
	var poser: ClipPoser = got[1]
	var r: SwingBake.Result = got[2]
	SwingBake.apply_reach(r, V3.make(0.0, 0.0, 0.1))
	var swing: Swing = SwingBake.swing_of(r)
	swing.reach_offset = r.reach_offset
	var t: ClipTiming = r.timing
	var sk: Skeleton3D = f.skeleton
	for frame: int in range(t.startup, t.startup + t.active + 1):
		# the view carries the body above the hips by the correction
		f.rig.body.hips_offset = SwingPlayer.to_skeleton(swing.reach_at(float(frame)))
		var hand: Array[Vector3] = []
		var grab: Callable = func() -> void:
			hand.append(sk.get_bone_global_pose(sk.find_bone("RightHand")) * f.rig.fist("Right").origin)
		(sk.get_node(^"RigCarry") as SkeletonModifier3D).modification_processed.connect(grab, CONNECT_ONE_SHOT)
		poser.pose(r.times[frame])
		var shown: Vector3 = f.weapons[0].transform.origin
		var baked: Vector3 = SwingPlayer.to_skeleton((r.tracks[&"right_hand"][frame] as Swing.Sample).grip)
		assert_lt(shown.distance_to(baked), 0.01, "frame %d: the blade shown is the baked path's (%.1f cm)" % [frame, shown.distance_to(baked) * 100.0])
		assert_lt(hand[0].distance_to(shown), 0.01, "frame %d: the hand holds it (%.1f cm)" % [frame, hand[0].distance_to(shown) * 100.0])
	f.rig.body.hips_offset = Vector3.ZERO


func test_the_rogues_drift_and_a_flagged_move_plays_humanm() -> void:
	var got: Array = _katana_cut(1.5)
	var r: SwingBake.Result = got[2]
	assert_eq(SwingBake.drift(r, (got[1] as ClipPoser).pose), 0.0, "the Hunter's own clip is on the path")
	var rogue: FighterModel = FighterLook.instantiate_fighter(&"rogue")
	rogue.autoplay_idle = false
	add_child_autofree(rogue)
	rogue.attach_weapon(WeaponLook.load_id(&"katana"))
	var drift: float = SwingBake.drift(r, ClipPoser.new(rogue, [CLIP]).pose)
	assert_gt(drift, 0.0, "the Rogue's smaller body holds the blade elsewhere")
	assert_lt(drift, 0.3)
	var swing: Swing = SwingBake.swing_of(r)
	assert_eq(ClipLibraries.set_for(&"rogue", swing), &"HumanF", "on the path: her own clip")
	assert_eq(ClipLibraries.set_for(&"hunter", swing), &"HumanM")
	swing.rogue_humanm = true
	assert_eq(ClipLibraries.set_for(&"rogue", swing), &"HumanM", "flagged: the Hunter's clip")
	assert_eq(ClipLibraries.set_for(&"hunter", swing), &"HumanM")
	assert_eq(ClipLibraries.set_for(&"rogue"), &"HumanF", "a move without a swing: her own")
	r.rogue_humanm = true
	var record: Dictionary = r.record()
	assert_true(record["rogue_humanm"])
	var read: Swing = SwingFile.parse(SwingBake.file_text(SwingBake.guard_record((got[1] as ClipPoser).pose(0.0)), {"t_cut": record}),
		_moves(r.timing), "rogue.json")[&"t_cut"]
	assert_true(read.rogue_humanm, "the swing file carries the flag")
