extends GutTest
## The contact-sheet tool (tools/shot_scenes/move_sheet.gd), headless: which
## frames a sheet shows, its cameras (the match camera over each fighter's
## shoulder, and three-quarter, close and hand views that keep the attacker in
## their crops), each row's caption with its phase and PoseCheck numbers, the
## layout of header, rows and cells, and the batch's moves and files. Headless
## runs draw nothing, so the cells are blank; the pictures themselves are
## reviewed from `npm run shots`.

const MoveSheet := preload("res://tools/shot_scenes/move_sheet.gd")


func after_each() -> void:
	MoveBench.free_all()


func _sheet(args: PackedStringArray = PackedStringArray()) -> MoveSheet:
	var sheet: MoveSheet = MoveSheet.new()
	sheet.auto_run = false
	sheet.apply_args(args)
	add_child_autofree(sheet)
	return sheet


func _attack(startup: int, active: int, recovery: int) -> AttackDef:
	var def: AttackDef = AttackDef.new()
	def.startup = startup
	def.active = active
	def.recovery = recovery
	return def


static func _feet(f: Fighter) -> Vector3:
	return Vector3(f.pos.x, f.pos.y, f.pos.z)


func _world_grip(sheet: MoveSheet) -> Vector3:
	var model: FighterModel = sheet.bench.view.model
	return model.skeleton.global_transform * model.rig.grip_point("Right")


func _world_bone(sheet: MoveSheet, bone: String) -> Vector3:
	var sk: Skeleton3D = sheet.bench.view.model.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func test_the_key_frames_are_a_moves_landmarks() -> void:
	# start, mid wind-up, the last wind-up frame, contact, the last active
	# frame, mid recovery and the last frame the move shows
	assert_eq(MoveSheet.key_frames(_attack(9, 3, 13)), [1, 5, 9, 10, 12, 19, 24])
	assert_eq(MoveSheet.key_frames(_attack(2, 1, 2)), [1, 2, 3, 4], "a short move's landmarks fall together")


func test_frames_are_chosen_by_number_landmark_or_all() -> void:
	var def: AttackDef = _attack(9, 3, 13)
	assert_eq(MoveSheet.frames_for("keys", def), MoveSheet.key_frames(def))
	assert_eq(MoveSheet.frames_for("contact,1,end", def), [1, 10, 24], "in order")
	assert_eq(MoveSheet.frames_for("windup,cocked,release,follow", def), [5, 9, 12, 19])
	assert_eq(MoveSheet.frames_for("7, 7 ,30,0", def), [7], "repeats and frames the move doesn't show are dropped")
	var all: Array[int] = []
	for f: int in range(1, 25):
		all.append(f)
	assert_eq(MoveSheet.frames_for("all", def), all)


func test_the_arguments_choose_the_fighters_weapon_move_frames_and_views() -> void:
	var sheet: MoveSheet = _sheet(PackedStringArray([
		"--fighter=hunter", "--weapon=greatsword", "--move=g_l1", "--at=contact,end", "--views=hands,defender",
		"--defender=rogue", "--spacing=3",
	]))
	assert_eq(sheet.fighter_id, &"hunter")
	assert_eq(sheet.weapon_id, &"greatsword")
	assert_eq(sheet.move, &"g_l1")
	assert_eq(sheet.at, "contact,end")
	assert_eq(sheet.views, [&"hands", &"defender"] as Array[StringName])
	assert_eq(sheet.defender_id, &"rogue")
	assert_almost_eq(sheet.spacing, 3.0, 1e-6)
	assert_eq(sheet.bench.view.fighter_id, &"hunter")
	assert_eq(sheet.bench.weapon, Moves.GREATSWORD)
	assert_almost_eq(_feet(sheet.bench.defender).distance_to(_feet(sheet.bench.attacker)), 3.0, 1e-4)
	assert_eq(sheet.defender_view.fighter_id, &"rogue")


func test_the_defender_is_the_same_fighter_in_the_other_palette_unless_chosen() -> void:
	var sheet: MoveSheet = _sheet()
	assert_eq(sheet.bench.view.fighter_id, &"rogue")
	assert_eq(sheet.bench.view.palette, 0)
	assert_eq(sheet.defender_view.fighter_id, &"rogue")
	assert_eq(sheet.defender_view.palette, 1)
	assert_almost_eq(sheet.defender_view.position, _feet(sheet.bench.defender), Vector3.ONE * 1e-4, "where the rules have it")


func test_the_gameplay_views_are_the_match_camera_over_each_fighters_shoulder() -> void:
	var sheet: MoveSheet = _sheet()
	var a: Vector3 = _feet(sheet.bench.attacker)
	var d: Vector3 = _feet(sheet.bench.defender)
	var rig: CameraRig = CameraRig.new()
	for spec: Array in [[&"defender", d, a], [&"attacker", a, d]]:
		sheet.aim(spec[0])
		var player: Vector3 = spec[1]
		var opponent: Vector3 = spec[2]
		var target: Dictionary = rig.follow_target(player, opponent, (opponent - player).normalized())
		assert_almost_eq(sheet.camera.global_position, target["pos"] as Vector3, Vector3.ONE * 1e-3, "%s: the match camera's place" % spec[0])
		assert_almost_eq(sheet.camera.fov, rig.base_fov, 1e-3, "%s: the match camera's lens" % spec[0])
		var ahead: Vector3 = -sheet.camera.global_basis.z
		assert_gt(ahead.dot((opponent - sheet.camera.global_position).normalized()), 0.9, "%s: looking at the other fighter" % spec[0])
	rig.free()


## The top of the fighter's head, hood or hat included: the top of
## PoseCheck's head capsule.
func _crown(sheet: MoveSheet, frame: PoseCheck.Frame) -> Vector3:
	var head: PoseCheck.Capsule = sheet.bench.check.capsule("head")
	var ends: PackedVector3Array = head.ends(frame.bones)
	var top: Vector3 = ends[0] if ends[0].y > ends[1].y else ends[1]
	return sheet.bench.view.model.skeleton.global_transform * top + Vector3.UP * head.radius


func test_the_gameplay_views_keep_the_whole_screen_and_the_others_a_centred_square() -> void:
	var screen: Vector2 = Vector2(1600.0, 900.0)
	for view: StringName in [&"defender", &"attacker"]:
		assert_eq(MoveSheet.crop_rect(view, screen), Rect2(0.0, 0.0, 1600.0, 900.0), "%s: the whole screen" % view)
		assert_eq(MoveSheet.cell_size(view), Vector2i(MoveSheet.CELL_HEIGHT * 16 / 9, MoveSheet.CELL_HEIGHT), "%s: 16:9" % view)
	for view: StringName in [&"three_quarter", &"close", &"hands"]:
		assert_eq(MoveSheet.crop_rect(view, screen), Rect2(350.0, 0.0, 900.0, 900.0), "%s: a centred square" % view)
		assert_eq(MoveSheet.cell_size(view), Vector2i(MoveSheet.CELL_HEIGHT, MoveSheet.CELL_HEIGHT), "%s: square" % view)
	assert_eq(MoveSheet.crop_rect(&"defender", Vector2(1200.0, 900.0)), Rect2(0.0, 0.0, 1200.0, 900.0), "never wider than the screen")


func test_the_close_views_keep_the_attacker_in_their_crops() -> void:
	for id: StringName in FighterLook.IDS:
		var sheet: MoveSheet = _sheet(PackedStringArray(["--fighter=" + id]))
		var frame: PoseCheck.Frame = await sheet.bench.frame()
		var size: Vector2 = sheet.get_viewport().get_visible_rect().size
		var crown: Vector3 = _crown(sheet, frame)
		var grip: Vector3 = _world_grip(sheet)
		var feet: Vector3 = _feet(sheet.bench.attacker)
		var points: Dictionary[StringName, Array] = {
			&"three_quarter": [crown, grip, feet],
			&"three_quarter_left": [crown, grip, feet],
			&"close": [crown, grip],
			&"hands": [grip],
		}
		for view: StringName in points:
			sheet.aim(view)
			var crop: Rect2 = MoveSheet.crop_rect(view, size)
			for p: Vector3 in points[view]:
				assert_false(sheet.camera.is_position_behind(p), "%s %s: %s in front" % [id, view, p])
				assert_true(crop.has_point(sheet.camera.unproject_position(p)), "%s %s: %s inside the crop" % [id, view, p])
		sheet.aim(&"hands")
		assert_lt(sheet.camera.global_position.distance_to(grip), 1.2, "%s: the hands close up" % id)
		sheet.aim(&"three_quarter")
		var to_camera: Vector3 = (sheet.camera.global_position - feet) * Vector3(1.0, 0.0, 1.0)
		var forward: Vector3 = (_feet(sheet.bench.defender) - feet).normalized()
		var angle: float = rad_to_deg(forward.angle_to(to_camera.normalized()))
		assert_between(angle, 30.0, 60.0, "%s: three-quarters from the front" % id)
		assert_gt(to_camera.dot(CameraRig.right_of(forward)), 0.0, "%s: on its weapon side" % id)
		sheet.aim(&"three_quarter_left")
		to_camera = (sheet.camera.global_position - feet) * Vector3(1.0, 0.0, 1.0)
		assert_between(rad_to_deg(forward.angle_to(to_camera.normalized())), 30.0, 60.0, "%s: three-quarters from the front, on the left" % id)
		assert_lt(to_camera.dot(CameraRig.right_of(forward)), 0.0, "%s: on its left" % id)
		MoveBench.free_all()


## The feet view looks down on the fighter's feet from in front, square to
## the line between them so neither hides the other, both feet and their
## toes in the crop.
func test_the_feet_view_sees_both_feet_side_by_side() -> void:
	for id: StringName in FighterLook.IDS:
		var sheet: MoveSheet = _sheet(PackedStringArray(["--fighter=" + id, "--drive=guard_forward"]))
		var frame: PoseCheck.Frame = await sheet.bench.frame()
		var sk: Skeleton3D = sheet.bench.view.model.skeleton
		var size: Vector2 = sheet.get_viewport().get_visible_rect().size
		sheet.aim(&"feet")
		var crop: Rect2 = MoveSheet.crop_rect(&"feet", size)
		var ankles: Dictionary[String, Vector3] = {}
		for side: String in ["Right", "Left"]:
			ankles[side] = sk.global_transform * frame.bones[sk.find_bone(side + "Foot")].origin
			for bone: String in ["Foot", "Toes"]:
				var p: Vector3 = sk.global_transform * frame.bones[sk.find_bone(side + bone)].origin
				assert_true(crop.has_point(sheet.camera.unproject_position(p)), "%s: the %s %s inside the crop" % [id, side, bone])
		var line: Vector3 = (ankles["Right"] - ankles["Left"]) * Vector3(1.0, 0.0, 1.0)
		var look: Vector3 = -sheet.camera.global_basis.z * Vector3(1.0, 0.0, 1.0)
		assert_gt(rad_to_deg(line.angle_to(look)), 60.0, "%s: looking across the line between the feet" % id)
		assert_lt(rad_to_deg(line.angle_to(look)), 120.0, "%s: not along it" % id)
		assert_gt(sheet.camera.global_position.y, ankles["Right"].y + 0.5, "%s: from above them" % id)
		MoveBench.free_all()


func test_a_move_sheet_has_a_row_per_chosen_frame_and_a_cell_per_view() -> void:
	var sheet: MoveSheet = _sheet(PackedStringArray(["--at=windup,contact,end", "--views=defender,hands"]))
	var def: AttackDef = Moves.KATANA.moves[&"k_l1"]
	var last: int = def.startup + def.active + def.recovery - 1
	var image: Image = await sheet.render(&"k_l1")
	assert_eq(sheet.rows.size(), 3)
	var contact: MoveSheet.Row = sheet.rows[1]
	assert_string_contains(contact.lines[0], "frame %d of %d" % [def.startup + 1, last])
	assert_string_contains(contact.lines[0], "active, contact")
	assert_string_contains(contact.lines[0], contact.report.summary(), "the PoseCheck numbers")
	assert_eq(contact.lines[1], MoveSheet.verdict(contact.report))
	assert_string_contains(sheet.rows[0].lines[0], "startup")
	assert_string_contains(sheet.rows[2].lines[0], "frame %d of %d" % [last, last])
	assert_string_contains(sheet.rows[2].lines[0], "recovery")
	for row: MoveSheet.Row in sheet.rows:
		assert_eq(row.cells.size(), 2, "a cell per view")
		assert_eq(row.cells[0].get_size(), MoveSheet.cell_size(&"defender"))
		assert_eq(row.cells[1].get_size(), MoveSheet.cell_size(&"hands"))
	assert_string_contains(sheet.title[0], "Right Cut")
	assert_eq(image.get_width(), MoveSheet.cell_size(&"defender").x + MoveSheet.GAP + MoveSheet.cell_size(&"hands").x)
	var row_height: int = MoveSheet.CAPTION_HEIGHT + MoveSheet.cell_size(&"hands").y
	assert_eq(image.get_height(), MoveSheet.HEADER_HEIGHT + 3 * (MoveSheet.GAP + row_height))


func test_the_header_names_the_move_the_defender_the_views_and_the_whole_move() -> void:
	var sheet: MoveSheet = _sheet(PackedStringArray(["--at=contact", "--views=defender,close"]))
	await sheet.render(&"k_l1")
	assert_eq(sheet.title.size(), 5, "a line each")
	assert_string_contains(sheet.title[0], "k_l1 Right Cut")
	assert_string_contains(sheet.title[1], "palette B) at 3.3 m")
	assert_eq(sheet.title[2], "views: gameplay camera behind the defender, close")
	var steps: Array[MoveBench.Step] = await sheet.bench.play(&"k_l1")
	var whole: String = MoveBench.summary(&"k_l1", steps)
	assert_true(sheet.title[3].begins_with("k_l1 %d fr wrist" % steps.size()), "MoveBench's summary of the whole move: " + sheet.title[3])
	assert_false(sheet.title[3].contains("fails"), "...on two lines")
	assert_true(sheet.title[4].begins_with("fails ") and sheet.title[4].contains("/%d: " % steps.size()), sheet.title[4])
	assert_eq(" ".join((sheet.title[3] + " " + sheet.title[4]).split(" ", false)), " ".join(whole.split(" ", false)))
	assert_false(sheet.title[4].contains("{"), "counts written out: " + sheet.title[4])
	var lines: int = sheet.title.size()
	assert_gte(MoveSheet.HEADER_HEIGHT, 2 * MoveSheet.TEXT_MARGIN + lines * MoveSheet.HEADER_FONT * 5 / 4, "room for every line")


func test_a_sheet_lets_go_of_its_world_when_it_leaves() -> void:
	var sheet: MoveSheet = _sheet()
	var world: World = sheet.bench.world
	remove_child(sheet)
	assert_null(world.fighters[0].opp, "the world's fighters let go of each other")
	add_child(sheet)


func test_the_guard_sheet_is_one_row_measured_in_the_guard() -> void:
	var sheet: MoveSheet = _sheet(PackedStringArray(["--views=close"]))
	await sheet.render(&"guard")
	assert_eq(sheet.rows.size(), 1)
	var row: MoveSheet.Row = sheet.rows[0]
	assert_true(row.lines[0].begins_with("guard"), row.lines[0])
	var expected: PoseCheck.Report = sheet.bench.check.measure(await sheet.bench.frame())
	assert_eq(row.report.summary(), expected.summary())
	assert_string_contains(row.lines[0], expected.summary())
	assert_eq(row.lines[1], MoveSheet.verdict(expected))


func test_the_verdict_names_the_failures_or_passes() -> void:
	var report: PoseCheck.Report = PoseCheck.Report.new()
	assert_eq(MoveSheet.verdict(report), "passes PoseCheck")
	report.elbows["Left"] = 180.0
	assert_eq(MoveSheet.verdict(report), "fails: " + ", ".join(report.failures()))
	var lines: PackedStringArray = ["Rogue with the Katana", "passes PoseCheck", "fails 0/29", "fails 3/29: left wrist 3", "fails: left elbow locked at 180°"]
	assert_eq(MoveSheet.tones(lines), [MoveSheet.TEXT_COLOR, MoveSheet.PASS_COLOR, MoveSheet.PASS_COLOR, MoveSheet.FAIL_COLOR, MoveSheet.FAIL_COLOR] as Array[Color])


func test_the_batch_is_the_guard_then_every_move_of_the_weapon() -> void:
	var sheet: MoveSheet = _sheet(PackedStringArray(["--weapon=greatsword", "--move=all"]))
	var expected: Array[StringName] = [MoveSheet.GUARD]
	expected.append_array(Moves.GREATSWORD.moves.keys())
	assert_eq(sheet.batch_moves(), expected)
	assert_eq(MoveSheet.sheet_path("C:/x/shots/katana.png", &"k_l1"), "C:/x/shots/katana_k_l1.png")
	assert_eq(MoveSheet.sheet_path("shots/greatsword", &"guard"), "shots/greatsword_guard.png")


func test_the_batch_saves_a_sheet_per_move_and_makes_their_index() -> void:
	var dir: String = ProjectSettings.globalize_path("user://test_move_sheet")
	DirAccess.make_dir_recursive_absolute(dir)
	var out: String = dir.path_join("katana.png")
	var sheet: MoveSheet = _sheet(PackedStringArray(["--move=all", "--at=contact", "--views=hands", "--out=" + out]))
	var moves: Array[StringName] = sheet.batch_moves()
	for move_id: StringName in moves:
		DirAccess.remove_absolute(MoveSheet.sheet_path(out, move_id))
	var index: Image = await sheet.batch()
	for move_id: StringName in moves:
		var path: String = MoveSheet.sheet_path(out, move_id)
		assert_true(FileAccess.file_exists(path), "%s saved" % path)
		DirAccess.remove_absolute(path)
	var cell: Vector2i = MoveSheet.cell_size(&"hands")
	var index_rows: int = ceili(moves.size() / float(MoveSheet.INDEX_COLUMNS))
	assert_eq(index.get_size(), Vector2i(
		MoveSheet.INDEX_COLUMNS * (cell.x + MoveSheet.GAP) - MoveSheet.GAP,
		MoveSheet.HEADER_HEIGHT + index_rows * (MoveSheet.GAP + MoveSheet.CAPTION_HEIGHT + cell.y)), "a captioned cell per move")
	assert_eq(sheet.title[0], "Rogue (palette A) with the Katana against the Rogue (palette B) at 3.3 m: the guard and every move")


func test_a_drive_is_scripted_input_from_rest() -> void:
	var drive: Array = MoveSheet.DRIVES[&"rest_to_sprint"]["input"]
	var inputs: Array[RawInput] = MoveSheet.drive_inputs(&"rest_to_sprint")
	var total: int = 0
	for segment: Array in drive:
		total += int(segment[0])
	assert_eq(inputs.size(), total)
	assert_eq(inputs[0].my, 0.0, "from rest")
	assert_eq(inputs[-1].my, 1.0, "toward the opponent")
	assert_eq(inputs[-1].buttons, 1 << Btn.SPRINT, "sprinting at the end")
	assert_eq(MoveSheet.drive_frames(25, 10), [1, 10, 20, 25] as Array[int], "the first frame, every tenth and the last")
	assert_eq(MoveSheet.drive_frames(20, 10), [1, 10, 20] as Array[int])


func test_the_strafe_and_backpedal_drives_move_the_way_they_say() -> void:
	# each drive's stick while it moves: [strafe axis (+ right), forward axis]
	var moving: Dictionary[StringName, Vector2] = {
		&"strafe_left": Vector2(-1.0, 0.0),
		&"strafe_right": Vector2(1.0, 0.0),
		&"backpedal": Vector2(0.0, -1.0),
		&"back_left": Vector2(-0.7071, -0.7071),
	}
	for id: StringName in moving:
		var inputs: Array[RawInput] = MoveSheet.drive_inputs(id)
		assert_eq(Vector2(inputs[0].mx, inputs[0].my), Vector2.ZERO, "%s from rest" % id)
		var mid: RawInput = inputs[inputs.size() / 2]
		assert_almost_eq(Vector2(mid.mx, mid.my), moving[id], Vector2.ONE * 1e-4, "%s moves" % id)
		assert_eq(Vector2(inputs[-1].mx, inputs[-1].my), Vector2.ZERO, "%s stops at the end" % id)
		assert_lt(float(MoveSheet.DRIVES[id]["spacing"]), 9.0, "%s: near enough that the rules keep the distance while it orbits" % id)
		assert_true(MoveSheet.VIEW_NAMES.has(MoveSheet.DRIVES[id]["views"][0]), "%s: its own view" % id)


## The guard drives walk the same ways blocking, seen
## from above too, every other frame.
func test_the_guard_drives_walk_blocking() -> void:
	var moving: Dictionary[StringName, Vector2] = {
		&"guard_forward": Vector2(0.0, 1.0),
		&"guard_backpedal": Vector2(0.0, -1.0),
		&"guard_strafe_left": Vector2(-1.0, 0.0),
		&"guard_strafe_right": Vector2(1.0, 0.0),
		&"guard_back_left": Vector2(-0.7071, -0.7071),
	}
	for id: StringName in moving:
		var inputs: Array[RawInput] = MoveSheet.drive_inputs(id)
		assert_eq(Vector2(inputs[0].mx, inputs[0].my), Vector2.ZERO, "%s from rest" % id)
		assert_almost_eq(Vector2(inputs[inputs.size() / 2].mx, inputs[inputs.size() / 2].my), moving[id], Vector2.ONE * 1e-4, "%s moves" % id)
		assert_eq(Vector2(inputs[-1].mx, inputs[-1].my), Vector2.ZERO, "%s stops at the end" % id)
		for r: RawInput in inputs:
			assert_eq(r.buttons, 1 << Btn.BLOCK, "%s: blocking throughout" % id)
		assert_has(MoveSheet.DRIVES[id]["views"], &"feet", "%s: the feet close" % id)
		assert_eq(_sheet(PackedStringArray(["--drive=" + id])).every, 2, "%s: every other frame, unless --every= says" % id)
	assert_eq(_sheet(PackedStringArray(["--drive=guard_forward", "--every=5"])).every, 5, "--every= says")
	assert_eq(_sheet(PackedStringArray(["--drive=run_brake"])).every, 4, "a drive with no every of its own")


## The tap steps drive taps the stick each way for a tap step's 8 frames;
## the Iai walk holds heavy throughout, sheathed, and walks after the
## sheathe.
func test_the_tap_step_and_iai_walk_drives() -> void:
	var taps: Array[RawInput] = MoveSheet.drive_inputs(&"tap_steps")
	var held: Array[Vector2] = []
	var run: int = 0
	for i: int in taps.size():
		var stick: Vector2 = Vector2(taps[i].mx, taps[i].my)
		assert_eq(taps[i].buttons, 0, "nothing pressed")
		if stick != Vector2.ZERO:
			run += 1
			if run == 1:
				held.append(stick)
		else:
			if run > 0:
				assert_eq(run, SimConst.MOVE_STEP_FRAMES, "each tap held a step's frames")
			run = 0
	assert_eq(held, [Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(-1.0, 0.0)] as Array[Vector2], "forward, right, back, left")
	var iai: Array[RawInput] = MoveSheet.drive_inputs(&"iai_walk")
	assert_lt(iai.size(), 150, "let go before the Iai draws by itself (2.5 s)")
	for r: RawInput in iai:
		assert_eq(r.buttons, 1 << Btn.HEAVY, "heavy held throughout")
	assert_eq(Vector2(iai[0].mx, iai[0].my), Vector2.ZERO, "sheathing from rest")


func test_the_side_view_sees_the_whole_fighter_from_its_right() -> void:
	for id: StringName in FighterLook.IDS:
		var sheet: MoveSheet = _sheet(PackedStringArray(["--fighter=" + id]))
		var frame: PoseCheck.Frame = await sheet.bench.frame()
		var feet: Vector3 = _feet(sheet.bench.attacker)
		sheet.aim(&"side")
		var crop: Rect2 = MoveSheet.crop_rect(&"side", sheet.get_viewport().get_visible_rect().size)
		for p: Vector3 in [_crown(sheet, frame), feet, _world_grip(sheet)]:
			assert_true(crop.has_point(sheet.camera.unproject_position(p)), "%s: %s inside the crop" % [id, p])
		var to_camera: Vector3 = ((sheet.camera.global_position - feet) * Vector3(1.0, 0.0, 1.0)).normalized()
		var right: Vector3 = CameraRig.right_of((_feet(sheet.bench.defender) - feet).normalized())
		assert_gt(to_camera.dot(right), 0.99, "%s: side on, from the right" % id)
		MoveBench.free_all()


func test_the_front_view_sees_the_whole_fighter_from_in_front() -> void:
	for id: StringName in FighterLook.IDS:
		var sheet: MoveSheet = _sheet(PackedStringArray(["--fighter=" + id]))
		var frame: PoseCheck.Frame = await sheet.bench.frame()
		var feet: Vector3 = _feet(sheet.bench.attacker)
		sheet.aim(&"front")
		var crop: Rect2 = MoveSheet.crop_rect(&"front", sheet.get_viewport().get_visible_rect().size)
		for p: Vector3 in [_crown(sheet, frame), feet, _world_grip(sheet)]:
			assert_false(sheet.camera.is_position_behind(p), "%s: %s in front" % [id, p])
			assert_true(crop.has_point(sheet.camera.unproject_position(p)), "%s: %s inside the crop" % [id, p])
		var to_camera: Vector3 = ((sheet.camera.global_position - feet) * Vector3(1.0, 0.0, 1.0)).normalized()
		var forward: Vector3 = (_feet(sheet.bench.defender) - feet).normalized()
		assert_between(rad_to_deg(forward.angle_to(to_camera)), 10.0, 30.0, "%s: from in front" % id)
		assert_gt(to_camera.dot(CameraRig.right_of(forward)), 0.0, "%s: a little to its right" % id)
		MoveBench.free_all()


func test_a_drive_strip_has_a_captioned_cell_per_chosen_frame() -> void:
	var sheet: MoveSheet = _sheet(PackedStringArray(["--drive=rest_to_sprint", "--every=20", "--views=side"]))
	assert_eq(sheet.drive, &"rest_to_sprint")
	assert_eq(sheet.every, 20)
	var inputs: Array[RawInput] = MoveSheet.drive_inputs(&"rest_to_sprint")
	var frames: Array[int] = MoveSheet.drive_frames(inputs.size(), 20)
	var image: Image = await sheet.render_drive(&"rest_to_sprint")
	assert_eq(sheet.strip.size(), frames.size(), "a cell per chosen frame")
	assert_gt(sheet.bench.spacing, 20.0, "the opponent far off, out of the way")
	var first: PackedStringArray = sheet.strip[0]
	assert_true(first[0].begins_with("frame 1 · 0.00 m/s · legs "), first[0])
	assert_true(first[1].begins_with("idle 1.00 · phase "), "the Katana standing in its combat idle: %s" % first[1])
	var last: PackedStringArray = sheet.strip[-1]
	assert_true(last[0].begins_with("frame %d · 7.20 m/s · legs +0°" % inputs.size()), last[0])
	var loco: Locomotion = sheet.bench.view.locomotion
	assert_eq(last[1], "%s 1.00 · phase %.2f" % [String(loco.clips[&"sprint"][0]).get_file(), loco.shown_phase])
	assert_string_contains(sheet.title[0], "rest_to_sprint")
	assert_string_contains(sheet.title[2], "strides ahead: walk %.2f m, run %.2f, sprint %.2f" % [
		loco.gaits[loco.clips[&"walk"][0]].stride, loco.gaits[loco.clips[&"run"][0]].stride, loco.gaits[loco.clips[&"sprint"][0]].stride])
	var cell: Vector2i = MoveSheet.cell_size(&"side")
	var rows: int = ceili(frames.size() / float(MoveSheet.STRIP_COLUMNS))
	assert_eq(image.get_size(), Vector2i(
		MoveSheet.STRIP_COLUMNS * (cell.x + MoveSheet.GAP) - MoveSheet.GAP,
		MoveSheet.HEADER_HEIGHT + rows * (MoveSheet.GAP + MoveSheet.STRIP_CAPTION_HEIGHT + cell.y)))


func test_a_strafe_strip_gives_the_legs_way_with_a_block_of_rows_per_view() -> void:
	assert_eq(_sheet(PackedStringArray(["--drive=strafe_left"])).views, [&"front"] as Array[StringName], "the drive's own view")
	var sheet: MoveSheet = _sheet(PackedStringArray(["--drive=strafe_left", "--every=24", "--views=front,side"]))
	var inputs: Array[RawInput] = MoveSheet.drive_inputs(&"strafe_left")
	var frames: Array[int] = MoveSheet.drive_frames(inputs.size(), 24)
	var image: Image = await sheet.render_drive(&"strafe_left")
	assert_almost_eq(sheet.bench.spacing, float(MoveSheet.DRIVES[&"strafe_left"]["spacing"]), 1e-6)
	assert_eq(sheet.strip.size(), frames.size(), "captions per chosen frame")
	var strafing: int = frames.find(72)
	assert_gt(strafing, 0)
	assert_true(sheet.strip[strafing][0].begins_with("frame 72 · 3.50 m/s · legs +9"), "strafing left: %s" % sheet.strip[strafing][0])
	var loco: Locomotion = sheet.bench.view.locomotion
	assert_true(sheet.strip[strafing][1].begins_with(String(loco.clips[&"run"][2]).get_file() if loco.clips[&"run"][2] != "" else String(loco.clips[&"walk"][2]).get_file()), sheet.strip[strafing][1])
	loco.shown_away = deg_to_rad(-170.0)
	assert_string_contains(MoveSheet.drive_caption(9, loco)[0], " · turned away -170°", "a sprint held backwards")
	loco.shown_away = 0.0
	# the front view's cells first, then the side view's
	var cell: Vector2i = MoveSheet.cell_size(&"front")
	var rows: int = 2 * ceili(frames.size() / float(MoveSheet.STRIP_COLUMNS))
	assert_eq(image.get_size(), Vector2i(
		mini(MoveSheet.STRIP_COLUMNS, frames.size()) * (cell.x + MoveSheet.GAP) - MoveSheet.GAP,
		MoveSheet.HEADER_HEIGHT + rows * (MoveSheet.GAP + MoveSheet.STRIP_CAPTION_HEIGHT + cell.y)))
	assert_eq(sheet.title[1].get_slice(" · ", 0), "views: front, side")
	assert_string_contains(sheet.title[1], "legs: the way they travel, + to the left; held: the feet the foot lock holds")


func test_the_brake_drives_run_then_let_go() -> void:
	for id: StringName in [&"run_brake", &"sprint_brake"]:
		var inputs: Array[RawInput] = MoveSheet.drive_inputs(id)
		assert_eq(Vector2(inputs[0].mx, inputs[0].my), Vector2.ZERO, "%s from rest" % id)
		var last_push: int = -1
		for i: int in inputs.size():
			if inputs[i].my > 0.0:
				assert_eq(inputs[i].mx, 0.0, "%s runs straight at the opponent" % id)
				last_push = i
		assert_gt(last_push, 30, "%s runs" % id)
		assert_gte(inputs.size() - 1 - last_push, 24, "%s then lets go long enough to settle" % id)
		for i: int in range(last_push + 1, inputs.size()):
			assert_eq(Vector2(inputs[i].mx, inputs[i].my), Vector2.ZERO, "%s: the stick let go" % id)
		assert_eq(MoveSheet.DRIVES[id]["views"], [&"side"], "%s seen from the side" % id)
		assert_gt(float(MoveSheet.DRIVES[id]["spacing"]), 20.0, "%s: room to run" % id)
	var sprint: Array[RawInput] = MoveSheet.drive_inputs(&"sprint_brake")
	var pushes: Array[RawInput] = sprint.filter(func(r: RawInput) -> bool: return r.my > 0.0)
	assert_eq(pushes[-1].buttons, 1 << Btn.SPRINT, "sprinting when it lets go")


func test_a_strip_caption_gives_the_turn_on_the_spot_and_the_held_feet() -> void:
	var sheet: MoveSheet = _sheet(PackedStringArray(["--drive=run_brake"]))
	var loco: Locomotion = sheet.bench.view.locomotion
	assert_eq(MoveSheet.drive_caption(1, loco)[2], "feet free")
	assert_eq(MoveSheet.drive_caption(1, loco, ["Left", "Right"])[2], "held: left, right")
	loco.shown_turn = 0.5
	loco.turn_left = false
	assert_eq(MoveSheet.drive_caption(1, loco, ["Right"])[2], "turning right 0.50 · held: right")
	loco.shown_turn = 0.0
	assert_gte(MoveSheet.STRIP_CAPTION_HEIGHT, 2 * MoveSheet.TEXT_MARGIN + 3 * MoveSheet.CAPTION_FONT * 5 / 4, "room for three lines")


func test_the_stand_drive_holds_still() -> void:
	var inputs: Array[RawInput] = MoveSheet.drive_inputs(&"stand")
	assert_gte(inputs.size(), 300, "five seconds and more")
	for r: RawInput in inputs:
		assert_eq(Vector2(r.mx, r.my), Vector2.ZERO, "still")
		assert_eq(r.buttons, 0, "nothing pressed")
	assert_eq(MoveSheet.DRIVES[&"stand"]["views"], [&"front", &"side"])
	assert_eq(float(MoveSheet.DRIVES[&"stand"]["spacing"]), PoseCheck.SPACING, "at the duelling distance")


func test_the_sheet_lays_out_its_header_rows_and_cells() -> void:
	var header: Image = Image.create(100, MoveSheet.HEADER_HEIGHT, false, Image.FORMAT_RGBA8)
	header.fill(Color.RED)
	var row: MoveSheet.Row = MoveSheet.Row.new()
	row.caption = Image.create(50, MoveSheet.CAPTION_HEIGHT, false, Image.FORMAT_RGBA8)
	row.caption.fill(Color.BLUE)
	var a: Image = Image.create(30, 20, false, Image.FORMAT_RGBA8)
	a.fill(Color.GREEN)
	var b: Image = Image.create(40, 20, false, Image.FORMAT_RGBA8)
	b.fill(Color.YELLOW)
	row.cells = [a, b]
	var out: Image = MoveSheet.compose(header, [row, row])
	var top: int = MoveSheet.HEADER_HEIGHT + MoveSheet.GAP
	var row_height: int = MoveSheet.CAPTION_HEIGHT + 20
	assert_eq(out.get_size(), Vector2i(100, top + row_height + MoveSheet.GAP + row_height), "as wide as the widest part")
	assert_eq(out.get_pixel(0, 0), Color.RED, "the header on top")
	for i: int in 2:
		var y: int = top + i * (row_height + MoveSheet.GAP)
		assert_eq(out.get_pixel(0, y), Color.BLUE, "row %d's caption" % i)
		assert_eq(out.get_pixel(0, y + MoveSheet.CAPTION_HEIGHT), Color.GREEN, "row %d's first cell" % i)
		assert_eq(out.get_pixel(29, y + MoveSheet.CAPTION_HEIGHT + 19), Color.GREEN)
		assert_eq(out.get_pixel(30 + MoveSheet.GAP, y + MoveSheet.CAPTION_HEIGHT), Color.YELLOW, "row %d's second cell after a gap" % i)
		assert_eq(out.get_pixel(30, y + MoveSheet.CAPTION_HEIGHT), MoveSheet.BACKGROUND, "the gap")


## Each string drive plays the Katana's string as far as it says: each press
## follows the move before, and the string then recovers to the guard.
func test_the_string_drives_play_that_many_lights() -> void:
	var expected: Dictionary[StringName, Array] = {
		&"string_l": [&"k_l1"],
		&"string_ll": [&"k_l1", &"k_l2"],
		&"string_lll": [&"k_l1", &"k_l2", &"k_l3"],
		&"string_llll": [&"k_l1", &"k_l2", &"k_l3", &"k_l4"],
	}
	for id: StringName in expected:
		var W: World = SimHelpers.make_world(Moves.KATANA, Moves.KATANA, MoveSheet.DRIVES[id]["spacing"])
		var f: Fighter = W.fighters[0]
		var played: Array[StringName] = []
		for input: RawInput in MoveSheet.drive_inputs(id):
			W.step([input, SimHelpers.idle()])
			if f.state == &"attack" and (played.is_empty() or played[-1] != f.atk.def.id):
				played.append(f.atk.def.id)
		assert_eq(played, expected[id] as Array[StringName], "%s plays its lights" % id)
		assert_eq(f.state, &"free", "%s ends back in the guard" % id)
	SimHelpers.dispose_all()
