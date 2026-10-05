extends GutTest
## Chains of clip parts (ClipChain), a held clip's timing (ClipTiming's hold)
## and the clip director playing both (authored-animation task 11).

const LENGTHS: Dictionary = {&"Sheathe": 22.0, &"Cut": 35.0}


func _parts(entries: Array) -> Array[ClipChain.Part]:
	return ClipChain.lay_out(entries, LENGTHS, [] as Array[String])


func test_a_part_reads_from_its_entry() -> void:
	var p: ClipChain.Part = ClipChain.parse("Sheathe@3-12", [] as Array[String])
	assert_eq([p.id, p.from, p.to], [&"Sheathe", 3.0, 12.0])
	p = ClipChain.parse("Cut@2", [] as Array[String])
	assert_eq([p.id, p.from], [&"Cut", 2.0])
	assert_true(is_nan(p.to), "to the clip's end")
	p = ClipChain.parse("Cut", [] as Array[String])
	assert_eq([p.id, p.from], [&"Cut", 0.0], "a whole clip")
	for bad: String in ["Cut@x", "Cut@5-2", "@3", "Cut@1-2-3"]:
		var why: Array[String] = []
		assert_null(ClipChain.parse(bad, why), bad)
		assert_eq(why.size(), 1, "%s: one line" % bad)


func test_a_chain_lays_out_its_parts_end_to_end() -> void:
	var parts: Array[ClipChain.Part] = _parts(["Sheathe@3-12", "Cut@2"])
	assert_eq([parts[0].start, parts[0].length, parts[1].start, parts[1].length], [0.0, 9.0, 9.0, 33.0])
	assert_eq(ClipChain.length_of(parts), 42.0)
	var why: Array[String] = []
	assert_true(ClipChain.lay_out(["Cut@2-40"], LENGTHS, why).is_empty(), "a part past its clip's end")
	assert_eq(why.size(), 1)


func test_a_held_part_holds_its_frame() -> void:
	var parts: Array[ClipChain.Part] = _parts(["Cut@0-4", "Cut@4*4", "Cut@4"])
	assert_eq([parts[1].start, parts[1].length, parts[2].start], [4.0, 4.0, 8.0], "held 4 frames between")
	assert_eq(ClipChain.place(parts, 6.0).frame, 4.0, "the frame held")
	assert_eq(ClipChain.place(parts, 9.0).frame, 5.0, "then on from it")
	var why: Array[String] = []
	assert_null(ClipChain.parse("Cut@4*0", why), "a hold of no frames")
	assert_eq(why.size(), 1)


func test_each_part_fades_in_from_the_one_before_held_at_its_end() -> void:
	var parts: Array[ClipChain.Part] = _parts(["Sheathe@3-12", "Cut@2"])
	var at: ClipChain.Place = ClipChain.place(parts, 4.0)
	assert_eq([at.part, at.frame, at.under], [0, 7.0, -1], "inside the first part, nothing under it")
	at = ClipChain.place(parts, 9.0)
	assert_eq([at.part, at.frame, at.under, at.under_frame, at.under_weight], [1, 2.0, 0, 12.0, 1.0],
		"the second starts all under the first's end")
	at = ClipChain.place(parts, 10.5)
	assert_almost_eq(at.under_weight, 0.5, 1e-9, "half way through the fade")
	at = ClipChain.place(parts, 9.0 + ClipChain.BLEND)
	assert_eq([at.under, at.frame], [-1, 5.0], "faded in")


func test_a_hold_lands_on_the_charge_frame_and_the_speed_times_the_rest() -> void:
	var t: ClipTiming = ClipTiming.make({"windup": 0, "hold": 9, "contact": 18, "contact_end": 21, "settle": 36}, 1.3, [] as Array[String])
	assert_eq([t.startup, t.active, t.recovery], [23, 4, 24], "the Iai's frames")
	assert_almost_eq(t.clip_time(float(ClipTiming.HOLD_FRAME)) * 30.0, 9.0, 1e-9, "the held pose on the charge frame")
	assert_almost_eq(t.clip_time(4.5) * 30.0, 4.5, 1e-9, "the wind-up evenly to it")
	assert_almost_eq(t.clip_time(23.0) * 30.0, 18.0, 1e-9, "the contact on the last startup frame")
	assert_eq(t.all_marks(), [0.0, 18.0, 21.0, 36.0, 9.0], "recorded with the hold last")
	var why: Array[String] = []
	assert_null(ClipTiming.make({"windup": 0, "hold": 30, "contact": 18, "contact_end": 21, "settle": 36}, 1.3, why), "a hold after the contact")
	why.clear()
	assert_null(ClipTiming.make({"windup": 0, "hold": 2, "contact": 18, "contact_end": 21, "settle": 36}, 1.3, why), "a wind-up too slow to the hold")
	assert_string_contains(why[0], "the wind-up to the hold plays at")


func test_the_director_plays_a_chains_parts_with_the_fade_under_them() -> void:
	var lengths: Dictionary[String, float] = {"HumanM/Sheathe": 22.0 / 30.0, "HumanM/Cut": 35.0 / 30.0}
	var ctx: ClipDirector.Context = ClipDirector.Context.make(&"hunter", true, lengths)
	var clips: Array[StringName] = [&"Sheathe@3-12", &"Cut@2"]
	var c: ClipDirector.Clip = ClipDirector.chain_clip(clips, &"HumanM", 4.0 / 30.0, ctx)
	assert_eq(c.name, "HumanM/Sheathe")
	assert_almost_eq(c.time * 30.0, 7.0, 1e-6)
	assert_null(c.under)
	c = ClipDirector.chain_clip(clips, &"HumanM", 10.5 / 30.0, ctx)
	assert_eq(c.name, "HumanM/Cut")
	assert_almost_eq(c.time * 30.0, 3.5, 1e-6)
	assert_eq(c.under.name, "HumanM/Sheathe", "the sheathe under it")
	assert_almost_eq(c.under.time * 30.0, 12.0, 1e-6, "held at its end")
	assert_almost_eq(c.under_weight, 0.5, 1e-6)
