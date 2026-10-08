extends GutTest
## The frame-data generator (tools/frame_data_generator.gd, milestone-1 task
## 15): a clip and its markers in, at 1.0x, the frame data, the travel and
## the swing out. The travel's arithmetic is checked on a made-up clip whose
## every number is known; the rest on a committed CC0 clip on the Hunter
## (ClipPoser), so CI needs no Iglesias packs.

const CLIP: String = "ual/Sword_Attack"
## Markers inside Sword_Attack (46 source frames).
const MARKERS: Dictionary = {"windup": 2, "active_start": 12, "active_end": 14.5, "settle": 30,
	"dodge_cancel": 20, "branch": {&"k_l2": 16}}
const PARTS: Array[StringName] = [&"right_hand", &"body"]


func _hunter() -> FighterModel:
	var f: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	f.autoplay_idle = false
	add_child_autofree(f)
	f.attach_weapon(WeaponLook.load_id(&"katana"))
	return f


func _sample(grip: V3, blade: V3 = V3.make(0.0, 0.0, 1.0)) -> Swing.Sample:
	var s: Swing.Sample = Swing.Sample.new()
	s.grip = grip
	s.blade = blade
	return s


## A made-up clip, 20 source frames long: the left foot planted for the
## first 10 and sliding back 1 cm a source frame (as a clip with its root's
## travel taken out does), turning 1 degree left a source frame; the right
## foot in the air; the hips moving forward 5 mm a source frame and the hand
## with them.
func _stepping(time: float) -> Dictionary:
	var s: float = time * ClipManifest.SOURCE_FPS
	var planted: float = minf(s, 10.0)
	var heading: float = deg_to_rad(-planted)
	var body: Swing.Sample = Swing.Sample.new()
	body.pelvis_shift = V3.make(0.0, -0.02, 0.005 * s)
	return {
		&"left_foot": _sample(V3.make(0.1, 0.09, 0.2 - 0.01 * planted), V3.make(sin(heading), 0.0, cos(heading))),
		&"right_foot": _sample(V3.make(-0.1, 0.2, 0.3)),
		&"right_hand": _sample(V3.make(-0.3, 1.2, 0.4 + 0.005 * s)),
		&"body": body,
	}


func _generate(pose: Callable, length: float, markers: Dictionary, contacts: Dictionary, relative: bool = false) -> FrameDataGenerator.Result:
	var errors: Array[String] = []
	var r: FrameDataGenerator.Result = FrameDataGenerator.generate(pose, length, markers, contacts, PARTS, errors, relative)
	assert_eq(errors, [] as Array[String])
	return r


func test_the_markers_give_the_frame_data_at_one_times() -> void:
	var r: FrameDataGenerator.Result = _generate(_stepping, 20.0 / 30.0,
		{"windup": 1, "active_start": 4.5, "active_end": 6, "settle": 12, "dodge_cancel": 8, "dodge_cancel_end": 11,
			"branch": {&"k_l2": 7, &"k_h2": 7.5}}, {})
	# two rules frames a source frame, from the wind-up start
	assert_eq([r.startup, r.active, r.recovery, r.total()], [7, 3, 12, 22])
	assert_eq(r.dodge_cancel, PackedInt32Array([14, 20]))
	assert_eq(r.branches, {&"k_l2": PackedInt32Array([12, 22]), &"k_h2": PackedInt32Array([13, 22])},
		"each follow-up from its branch point to the move's last frame")
	assert_eq(r.times.size(), 23, "a time for every rules frame")
	assert_almost_eq(r.times[0], 1.0 / 30.0, 1e-12, "the wind-up start on frame 0")
	assert_almost_eq(r.times[7], 4.5 / 30.0, 1e-12, "a half source frame lands on its rules frame")
	assert_almost_eq(r.times[22], 12.0 / 30.0, 1e-12, "the settle on the last frame")
	assert_eq(r.tracks.keys(), PARTS)
	assert_eq(r.tracks[&"right_hand"].size(), 23)


func test_travel_comes_from_the_planted_foot_and_the_hips_with_none_planted() -> void:
	var r: FrameDataGenerator.Result = _generate(_stepping, 20.0 / 30.0,
		{"windup": 0, "active_start": 4, "active_end": 5, "settle": 20}, {"left": [[0, 10]], "right": []})
	assert_eq(r.forward.size(), r.total() + 1)
	assert_eq([r.forward[0], r.sideways[0], r.turn[0]], [0.0, 0.0, 0.0], "frame 0 doesn't move")
	for f: int in range(1, 21):
		# half a source frame a rules frame: the planted foot slides back 5 mm,
		# so the root goes forward 5 mm; the hips' 2.5 mm is a lean over the
		# planted foot (milestone-1 task 89), not travel
		assert_almost_eq(r.forward[f], 0.005, 1e-9, "frame %d forward" % f)
		assert_almost_eq(r.sideways[f], 0.0, 1e-9, "frame %d sideways" % f)
		assert_almost_eq(r.turn[f], 0.5, 1e-6, "frame %d: the foot turns left, the body right" % f)
	for f: int in range(21, 41):
		# the foot lifted: the root carries on as it last moved, and the
		# hips' move rides on top, but it doesn't turn: the clip shows any
		# turn in the air (milestone-1 task 133)
		assert_almost_eq(r.forward[f], 0.0075, 1e-9, "frame %d forward, carried" % f)
		assert_almost_eq(r.turn[f], 0.0, 1e-6, "frame %d: no turn in the air" % f)
	var still: FrameDataGenerator.Result = _generate(_stepping, 20.0 / 30.0,
		{"windup": 0, "active_start": 4, "active_end": 5, "settle": 20}, {})
	for f: int in range(1, 41):
		assert_almost_eq(still.forward[f], 0.0025, 1e-9, "no foot planted from the start: the hips' move only")


## A made-up spin, 20 source frames long: the left foot planted where it
## stands and turning 3 degrees right a source frame, the hips turning with
## it by `hips` degrees a source frame (a pivot on the foot when they match;
## a clip turning in place, its root's turn taken out, when they stay still).
func _spinning(time: float, hips: float) -> Dictionary:
	var s: float = time * ClipManifest.SOURCE_FPS
	var heading: float = deg_to_rad(3.0 * s)
	var body: Swing.Sample = Swing.Sample.new()
	body.pelvis = wrapf(hips * s, -180.0, 180.0)
	return {
		&"left_foot": _sample(V3.make(0.1, 0.09, 0.2), V3.make(sin(heading), 0.0, cos(heading))),
		&"right_foot": _sample(V3.make(-0.1, 0.2, 0.3)),
		&"right_hand": _sample(V3.make(-0.3, 1.2, 0.4)),
		&"body": body,
	}


func test_a_planted_foot_turning_with_the_hips_is_a_pivot_not_a_turn() -> void:
	var markers: Dictionary = {"windup": 0, "active_start": 4, "active_end": 5, "settle": 20}
	var contacts: Dictionary = {"left": [[0, 20]], "right": []}
	# milestone-1 task 133: the Spinning Heel turns a whole turn on the ball
	# of its planted foot; the clip shows the spin, so the body doesn't turn
	var pivot: FrameDataGenerator.Result = _generate(func(t: float) -> Dictionary: return _spinning(t, 3.0), 20.0 / 30.0, markers, contacts)
	# the hips turning more than the foot (a coil on top) leave no turn either
	var coil: FrameDataGenerator.Result = _generate(func(t: float) -> Dictionary: return _spinning(t, 5.0), 20.0 / 30.0, markers, contacts)
	# a clip turning in place: the planted foot turns, the hips don't, so the
	# body turns the other way
	var in_place: FrameDataGenerator.Result = _generate(func(t: float) -> Dictionary: return _spinning(t, 0.0), 20.0 / 30.0, markers, contacts)
	# the hips turning half as far as the foot: the rest is the body's turn
	var half: FrameDataGenerator.Result = _generate(func(t: float) -> Dictionary: return _spinning(t, 1.5), 20.0 / 30.0, markers, contacts)
	for f: int in range(1, 41):
		assert_almost_eq(pivot.turn[f], 0.0, 1e-6, "frame %d: a pivot" % f)
		assert_almost_eq(coil.turn[f], 0.0, 1e-6, "frame %d: a pivot and a coil" % f)
		assert_almost_eq(in_place.turn[f], -1.5, 1e-6, "frame %d: turning in place" % f)
		assert_almost_eq(half.turn[f], -0.75, 1e-6, "frame %d: half a pivot" % f)


func test_travel_is_not_counted_twice() -> void:
	var markers: Dictionary = {"windup": 0, "active_start": 4, "active_end": 5, "settle": 20}
	var contacts: Dictionary = {"left": [[0, 10]], "right": []}
	var in_place: FrameDataGenerator.Result = _generate(_stepping, 20.0 / 30.0, markers, contacts)
	var moving: FrameDataGenerator.Result = _generate(_stepping, 20.0 / 30.0, markers, contacts, true)
	assert_false(in_place.relative)
	assert_true(moving.relative)
	var travelled: float = 0.0
	var root: float = 0.0
	for f: int in moving.total() + 1:
		travelled += moving.forward[f]
		if f > 0:
			root += 0.005
		var clip: Swing.Sample = in_place.tracks[&"right_hand"][f]
		var rel: Swing.Sample = moving.tracks[&"right_hand"][f]
		# the swing's path plus the body's travel is where the clip puts the
		# hand, its root carried along by the planted foot
		assert_almost_eq(rel.grip.z + travelled, clip.grip.z + root, 1e-9, "frame %d" % f)
		assert_almost_eq(rel.grip.y, clip.grip.y, 1e-12, "frame %d: heights untouched" % f)
		var body: Swing.Sample = moving.tracks[&"body"][f]
		# the hips lean over the planted foot (2.5 mm a rules frame), then,
		# with no foot planted, their move is the travel's
		assert_almost_eq(body.pelvis_shift.z, 0.0025 * mini(f, 20), 1e-9, "frame %d: the hips' lean stays, the travel's goes" % f)
		assert_almost_eq(body.pelvis_shift.y, -0.02, 1e-12, "frame %d: their drop stays" % f)


func test_on_a_cc0_clip_it_is_deterministic_and_relative_plus_travel_is_the_clip() -> void:
	var records: Array = []
	var runs: Array[FrameDataGenerator.Result] = []
	for i: int in 2:
		var poser: ClipPoser = ClipPoser.new(_hunter(), [CLIP])
		var errors: Array[String] = []
		var r: FrameDataGenerator.Result = FrameDataGenerator.generate(poser.pose, poser.length, MARKERS, {}, PARTS, errors, i == 1)
		assert_eq(errors, [] as Array[String])
		runs.append(r)
		records.append([r.startup, r.active, r.recovery, r.dodge_cancel, r.branches, r.travel_record()])
	assert_eq(records[0], records[1], "the same clip and markers give the same frame data and travel")
	assert_eq([runs[0].startup, runs[0].active, runs[0].recovery], [20, 5, 31])
	# no foot planted: the root stays, and the swing plus the travel is the clip
	var fwd: float = 0.0
	var side: float = 0.0
	for f: int in runs[0].total() + 1:
		fwd += runs[1].forward[f]
		side += runs[1].sideways[f]
		var clip: V3 = (runs[0].tracks[&"right_hand"][f] as Swing.Sample).grip
		var rel: V3 = (runs[1].tracks[&"right_hand"][f] as Swing.Sample).grip
		assert_lt(V3.distance(V3.add(rel, V3.make(side, 0.0, fwd)), clip), 1e-6, "frame %d" % f)


func test_a_stand_in_samples_its_clip_on_todays_timing() -> void:
	var errors: Array[String] = []
	var retime: ClipTiming = ClipTiming.make({"windup": 0, "contact": 6, "contact_end": 7.5, "settle": 15}, 1.5, errors)
	assert_eq(errors, [] as Array[String])
	var markers: Dictionary = {"windup": 0, "active_start": 4, "active_end": 5, "settle": 10}
	var r: FrameDataGenerator.Result = FrameDataGenerator.generate(_stepping, 20.0 / 30.0, markers, {}, PARTS, errors, false, retime)
	assert_eq(errors, [] as Array[String])
	assert_eq([r.startup, r.active, r.recovery], [8, 2, 10], "the frame data are the markers'")
	for f: int in r.total() + 1:
		assert_almost_eq(r.times[f], retime.clip_time(float(f)), 1e-12, "frame %d sampled on today's timing" % f)
	var other: ClipTiming = ClipTiming.make({"windup": 0, "contact": 6, "contact_end": 7.5, "settle": 15}, 1.0, errors)
	assert_null(FrameDataGenerator.generate(_stepping, 20.0 / 30.0, markers, {}, PARTS, errors, false, other))
	assert_string_contains(errors[-1], "today's timing has 30 frames, the markers 20")


func test_mistakes_are_refused() -> void:
	var cases: Array = [
		[{"windup": 0, "active_start": 4, "settle": 10}, "no active_end marker"],
		[{"windup": 0, "active_start": 4, "active_end": 3, "settle": 10}, "the active_end marker must come after the active_start marker"],
		[{"windup": 0, "active_start": 4, "active_end": 5, "settle": 25}, "the settle marker (25) is past the clip's end (frame 20)"],
	]
	for c: Array in cases:
		var errors: Array[String] = []
		assert_null(FrameDataGenerator.generate(_stepping, 20.0 / 30.0, c[0], {}, PARTS, errors), str(c[0]))
		assert_eq(errors, [c[1]] as Array[String])
	var errors: Array[String] = []
	assert_null(FrameDataGenerator.generate(_stepping, 20.0 / 30.0, {"windup": 0, "active_start": 4, "active_end": 5, "settle": 10}, {},
		[&"left_hand"] as Array[StringName], errors))
	assert_eq(errors, ["the sampled clip has no left_hand"] as Array[String])


func test_a_chains_foot_contacts_follow_its_parts() -> void:
	var errors: Array[String] = []
	var parts: Array[ClipChain.Part] = ClipChain.lay_out(["A@4-12", "B@2*5", "B@2"], {&"A": 20.0, &"B": 10.0}, errors)
	assert_eq(errors, [] as Array[String])
	var contacts: Dictionary = FrameDataGenerator.chain_contacts(parts, {
		&"A": {"left": [[0, 6], [10, 20]], "right": [[8, 9]]},
		&"B": {"left": [[0, 3]], "right": [[5, 10]]},
	})
	# A plays source 4-12 from chain frame 0; B holds 2 from 8 to 13, then
	# plays 2-10 from 13
	assert_eq(contacts["left"], [[0.0, 2.0], [6.0, 8.0], [8.0, 13.0], [13.0, 14.0]])
	assert_eq(contacts["right"], [[4.0, 5.0], [16.0, 21.0]])
	assert_true(FrameDataGenerator.planted_over(contacts["left"], 8.5, 12.5))
	assert_false(FrameDataGenerator.planted_over(contacts["left"], 1.5, 6.5), "lifted in between")
