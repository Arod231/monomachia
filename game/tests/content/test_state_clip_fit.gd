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
