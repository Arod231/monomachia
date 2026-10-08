extends GutTest
## The state-clip fit test (the milestone-1 spec's per-move checklist, item
## 3): each reaction a family re-keys fits its protected frames at its own
## speed. It is listed to play at 1.0 from its state's start and hand on
## (StateClips.own_speed), and its settle marker, at 60 rules frames a
## second, lands within a rules frame of its state's end. Reads the
## committed tables only, so it runs on CI.


func test_the_katana_light_reactions_fit_their_protected_frames() -> void:
	var sc: StateClips = StateClips.read()
	var manifest: ClipManifest = ClipManifest.read()
	var pt: ProtectedTimings = ProtectedTimings.for_weapon(&"katana")
	var cases: Array[Array] = []
	for place: StringName in sc.light_hits.get(&"katana", {}):
		cases.append([sc.light_hits[&"katana"][place], pt.hitstun(&"light"), "the %s hit" % place])
	if sc.light_blocks.has(&"katana"):
		cases.append([sc.light_blocks[&"katana"], pt.blockstun(&"light"), "the block"])
	assert_eq(cases.size(), 9, "eight light hits and a light block")
	for c: Array in cases:
		var id: StringName = c[0]
		assert_eq(sc.own_speed.get(id, &""), &"hand_on", "%s plays at its own speed, handing on" % c[2])
		assert_true(manifest.clips.has(id), "%s is in the manifest" % c[2])
		if not manifest.clips.has(id):
			continue
		var settle: int = manifest.clips[id].markers["settle"]
		assert_almost_eq(float(settle) * MoveClips.RULES_PER_SOURCE, float(c[1]), 1.0,
			"%s (%s) settles on rules frame %d of its %d" % [c[2], id, int(settle * MoveClips.RULES_PER_SOURCE), c[1]])


## The jump's clips (milestone-1 task 59): each flight lasts its jump's
## airtime on the rules' arc at 1.0, the spec's 30 frames armed and 35
## disarmed, and each landing the land state's frames, settling within a
## rules frame of each.
func test_the_jump_and_landing_clips_fit_the_arc() -> void:
	var sc: StateClips = StateClips.read()
	var manifest: ClipManifest = ClipManifest.read()
	var cases: Array[Array] = [
		[sc.jump_clip(&"flight", &"katana"), 30, "the Katana's flight"],
		[sc.jump_clip(&"flight", &"fists"), 35, "bare hands' flight"],
		[sc.jump_clip(&"land", &"katana"), SimConst.MOVE_LAND_RECOVERY, "the Katana's landing"],
		[sc.jump_clip(&"land", &"fists"), SimConst.MOVE_LAND_RECOVERY, "bare hands' landing"],
	]
	for c: Array in cases:
		var id: StringName = c[0]
		assert_ne(id, &"", "%s is listed" % c[2])
		assert_eq(sc.own_speed.get(id, &""), &"hand_on", "%s plays at its own speed, handing on" % c[2])
		assert_true(manifest.clips.has(id), "%s is in the manifest" % c[2])
		if not manifest.clips.has(id):
			continue
		var settle: int = manifest.clips[id].markers["settle"]
		assert_almost_eq(float(settle) * MoveClips.RULES_PER_SOURCE, float(c[1]), 1.0,
			"%s (%s) settles on rules frame %d of its %d" % [c[2], id, int(settle * MoveClips.RULES_PER_SOURCE), c[1]])


## Moonsplitter's clips (milestone-1 task 98) fit the rules' timing at 1.0:
## the stance settles on the draw's frame, and each draw's contact lands on
## the wave and its settle on the fighter's release.
func test_moonsplitter_s_clips_fit_its_rules_frames() -> void:
	var sc: StateClips = StateClips.read()
	var manifest: ClipManifest = ClipManifest.read()
	var per: float = MoveClips.RULES_PER_SOURCE
	assert_true(manifest.clips.has(sc.ult_stance), "the stance is in the manifest")
	if manifest.clips.has(sc.ult_stance):
		assert_eq(float(manifest.clips[sc.ult_stance].markers["settle"]) * per, float(SimConst.MOONSPLITTER_DRAW),
			"the stance settles on the draw's frame")
	assert_eq(sc.ult_draws.keys(), [&"vertical", &"horizontal"], "a draw per variant")
	for variant: StringName in sc.ult_draws:
		var id: StringName = sc.ult_draws[variant]
		assert_true(manifest.clips.has(id), "%s is in the manifest" % id)
		if not manifest.clips.has(id):
			continue
		var m: Dictionary = manifest.clips[id].markers
		assert_eq(float(SimConst.MOONSPLITTER_DRAW) + float(m["contact"]) * per, float(SimConst.MOONSPLITTER_WAVE),
			"%s's contact on the wave's frame" % id)
		assert_eq(float(SimConst.MOONSPLITTER_DRAW) + float(m["settle"]) * per,
			float(SimConst.MOONSPLITTER_WAVE + SimConst.MOONSPLITTER_RECOVERY), "%s settles as the fighter is free" % id)
	assert_eq(sc.ult_sheathed.size(), 2, "the saya's frames")
	if sc.ult_sheathed.size() == 2:
		assert_true(sc.ult_sheathed[1] * per <= float(SimConst.MOONSPLITTER_DRAW) + 1.0, "drawn as the draw starts")
