extends GutTest
## The sound check (tools/sound_check.tscn), the owner's listening tool: it
## steps through every rules event's cues, the menu sounds, one hit at growing
## distances, the footsteps at each pace, the arena's ambience, the three music
## tracks with their switches, and the ducking. These tests run it to the end
## on their own clock.

const DT := 0.05
## Far longer than the whole run takes (s).
const MAX_SECONDS := 900.0
## What the music plays through each step of the Music section, in order (the
## empty name is silence), and through the ducking step.
const MUSIC_STEPS: Array = [
	[&"menu"],
	[&"menu", &"battle"],
	[&"battle", &"match_point"],
	[&"match_point", &"menu"],
	[&"menu", &""],
]
const DUCKING_STEP: Array = [&"battle", &""]

var check: SoundCheck
var started: Array[int] = []
## Per step: the cues it played, the tracks it went through (repeats dropped),
## the ambience file it played ("" for none), and the 3D voices' distances
## from the camera.
var played: Array = []
var tracks: Array = []
var ambience: Array[String] = []
var distances: Array = []
## The run's clock (s); per step, each sound it played with the time it ends;
## and the sounds still playing when their step ended.
var now := 0.0
var ends: Array = []
var cut: Array[String] = []


func before_each() -> void:
	check = (load("res://tools/sound_check.tscn") as PackedScene).instantiate()
	check.auto_run = false
	add_child_autofree(check)
	started.clear()
	played.clear()
	tracks.clear()
	ambience.clear()
	distances.clear()
	for i: int in check.steps.size():
		played.append([])
		tracks.append([])
		ambience.append("")
		distances.append([])
		ends.append([])
	check.step_started.connect(_on_step_started)
	check.player.played.connect(_on_played)


func _current() -> int:
	return started[-1]


func _on_step_started(i: int) -> void:
	if not started.is_empty():
		_check_played_out(started[-1])
	started.append(i)


## Notes each sound of step [param i] that is still playing now.
func _check_played_out(i: int) -> void:
	for e: Array in ends[i]:
		if float(e[1]) > now + 0.001:
			cut.append("%s: %s ends %.2f s later" % [check.steps[i]["label"], e[0], float(e[1]) - now])
	ends[i].clear()


func _on_played(cue: StringName, voice: Node) -> void:
	played[_current()].append(cue)
	var stream: AudioStream = voice.get("stream")
	ends[_current()].append([cue, now + stream.get_length() / float(voice.get("pitch_scale"))])
	if voice is AudioStreamPlayer3D:
		distances[_current()].append((voice as Node3D).global_position.distance_to(check.camera.global_position))


## Notes what the music and the ambience are doing now.
func _note() -> void:
	var i := _current()
	var track := check.music.current_track()
	if tracks[i].is_empty() or tracks[i][-1] != track:
		tracks[i].append(track)
	if check.ambience.is_playing():
		ambience[i] = check.ambience.player.stream.resource_path


func _advance(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not check.is_finished():
		now += DT
		check.advance(DT)
		t += DT
		_note()


func _run_to_end() -> void:
	check.start(0)
	_note()
	_advance(MAX_SECONDS)


func _steps_in(section: String) -> Array[int]:
	var out: Array[int] = []
	for i: int in check.steps.size():
		if check.steps[i]["section"] == section:
			out.append(i)
	return out


## The cues a step asks for: its events' cues (see SoundBank.cues_for) and its
## single cues, sorted.
static func _expected_cues(step: Dictionary) -> Array:
	var out := []
	for action: Dictionary in step["actions"]:
		if action.has("event"):
			for cue: Dictionary in SoundBank.cues_for(action["event"]):
				out.append(cue["cue"])
		elif action.has("cue"):
			out.append(action["cue"])
	out.sort()
	return out


static func _cue_names(event: Dictionary) -> Array:
	var out := []
	for cue: Dictionary in SoundBank.cues_for(event):
		out.append(cue["cue"])
	return out


## One event for each mix of the fields the sound bank picks cues by.
static func _variations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weapons: Array = Moves.PLAYABLE_WEAPONS.duplicate()
	weapons.append(&"fists")
	for heavy: bool in [false, true]:
		for weapon: StringName in weapons:
			out.append({"t": &"swing", "weapon": weapon, "heavy": heavy})
		for sound: StringName in AttackDef.HIT_SOUNDS:
			out.append({"t": &"hit", "sound": sound, "heavy": heavy})
		out.append({"t": &"block", "heavy": heavy})
	for kind: StringName in AttackDef.COUNTER_KINDS:
		out.append({"t": &"telegraph", "kind": kind})
	for kind: StringName in [&"parry", &"flash", &"redirect"]:
		out.append({"t": &"parry", "kind": kind})
	for kind: StringName in [&"stomp", &"leap", &"evade"]:
		out.append({"t": &"counter", "kind": kind})
	out.append({"t": &"weaponStuck", "owner": 1})
	return out


static func _key(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.pressed = true
	return e


func test_it_runs_through_every_step_in_order_to_the_end() -> void:
	_run_to_end()
	assert_true(check.is_finished(), "the run ends")
	assert_gt(check.steps.size(), 40, "plenty of steps")
	var expected: Array[int] = []
	for i: int in check.steps.size():
		expected.append(i)
	assert_eq(started, expected, "each step once, in order")
	assert_true(check.player.is_quiet(), "nothing left playing")
	assert_eq(check.music.current_track(), &"", "the music stopped")
	assert_false(check.ambience.is_playing(), "the ambience stopped")
	assert_eq(check.player.missing, PackedStringArray(), "no sound missing")


func test_every_step_plays_the_cues_it_asks_for_delayed_ones_included() -> void:
	_run_to_end()
	for i: int in check.steps.size():
		var got: Array = played[i].duplicate()
		got.sort()
		assert_eq(got, _expected_cues(check.steps[i]), "step %d, %s" % [i, check.steps[i]["label"]])


func test_it_plays_every_event_that_has_sounds() -> void:
	var types := {}
	for step: Dictionary in check.steps:
		for action: Dictionary in step["actions"]:
			if action.has("event"):
				types[StringName(action["event"]["t"])] = true
	for type: StringName in SoundBank.EVENTS:
		if not (SoundBank.EVENTS[type] as Array).is_empty():
			assert_true(types.has(type), "a step plays %s" % type)


func test_it_plays_every_variation_the_sound_bank_tells_apart() -> void:
	var heard := []
	for step: Dictionary in check.steps:
		for action: Dictionary in step["actions"]:
			if action.has("event"):
				heard.append(_cue_names(action["event"]))
	for e: Dictionary in _variations():
		assert_has(heard, _cue_names(e), "a step plays %s" % e)


func test_every_sound_plays_out_before_the_next_step_starts() -> void:
	_run_to_end()
	_check_played_out(started[-1])
	assert_eq(cut, [] as Array[String])


func test_it_plays_every_cue_in_the_bank() -> void:
	_run_to_end()
	var heard := {}
	for list: Array in played:
		for cue: StringName in list:
			heard[cue] = true
	for cue: StringName in SoundBank.CUES:
		if SoundBank.CUES[cue].get("loop", false):
			assert_has(ambience, SoundBank.paths_for(cue)[0], "the %s loop plays" % cue)
		else:
			assert_true(heard.has(cue), "%s plays" % cue)


func test_the_music_plays_the_three_tracks_and_their_switches() -> void:
	_run_to_end()
	var music := _steps_in("Music")
	assert_eq(music.size(), MUSIC_STEPS.size(), "the music steps")
	for k: int in mini(music.size(), MUSIC_STEPS.size()):
		assert_eq(tracks[music[k]], MUSIC_STEPS[k], check.steps[music[k]]["label"])
	var ducking := _steps_in("Ducking")
	assert_eq(ducking.size(), 1)
	for i: int in check.steps.size():
		if ducking.has(i):
			assert_eq(tracks[i], DUCKING_STEP, check.steps[i]["label"])
		elif not music.has(i):
			assert_eq(tracks[i], [&""], "no music under %s" % check.steps[i]["label"])


func test_the_ambience_plays_in_its_step_and_under_the_ducking_only() -> void:
	_run_to_end()
	var with_bed := _steps_in("Ambience") + _steps_in("Ducking")
	assert_eq(with_bed.size(), 2)
	for i: int in check.steps.size():
		if with_bed.has(i):
			assert_eq(ambience[i], SoundBank.paths_for(&"ambience_shrine")[0], check.steps[i]["label"])
		else:
			assert_eq(ambience[i], "", "no ambience under %s" % check.steps[i]["label"])


func test_the_distance_step_plays_one_hit_at_each_distance() -> void:
	_run_to_end()
	var steps := _steps_in("Distance")
	assert_eq(steps.size(), 1)
	if steps.size() == 1:
		var got: Array = distances[steps[0]]
		assert_eq(got.size(), SoundCheck.DISTANCES.size(), "one 3D hit per distance")
		for k: int in mini(got.size(), SoundCheck.DISTANCES.size()):
			assert_almost_eq(float(got[k]), SoundCheck.DISTANCES[k], 0.01, "hit %d" % k)


func test_each_step_starts_from_silence() -> void:
	var music := _steps_in("Music")
	var bed: int = _steps_in("Ambience")[0]
	check.start(music[0])
	assert_eq(check.music.current_track(), &"menu")
	check._unhandled_input(_key(KEY_UP))
	assert_eq(_current(), bed)
	assert_eq(check.music.current_track(), &"", "the music stopped")
	assert_true(check.ambience.is_playing(), "the bed plays")
	check._unhandled_input(_key(KEY_DOWN))
	assert_eq(_current(), music[0])
	assert_false(check.ambience.is_playing(), "the bed stopped")


func test_right_and_left_step_and_drop_what_was_waiting() -> void:
	var ko := -1
	for i: int in check.steps.size():
		if check.steps[i]["label"].begins_with("ko"):
			ko = i
	assert_gt(ko, 0, "a KO step")
	check.start(ko)
	# Stay on each step, so Left comes back to the KO.
	check._unhandled_input(_key(KEY_SPACE))
	check._unhandled_input(_key(KEY_RIGHT))
	assert_eq(started, [ko, ko + 1])
	_advance(3.0)
	assert_false(played[ko].has(&"gong"), "the KO's gong was dropped")
	check._unhandled_input(_key(KEY_LEFT))
	assert_eq(_current(), ko)
	_advance(3.0)
	assert_has(played[ko], &"gong", "the KO's gong rings when the step plays through")


func test_up_and_down_jump_between_sections() -> void:
	var music := _steps_in("Music")
	check.start(music[1])
	check._unhandled_input(_key(KEY_DOWN))
	assert_eq(_current(), _steps_in("Ducking")[0], "down: the next section")
	check._unhandled_input(_key(KEY_UP))
	assert_eq(_current(), music[0], "up from a section's start: the previous section")
	check.start(music[2])
	check._unhandled_input(_key(KEY_UP))
	assert_eq(_current(), music[0], "up from inside a section: its start")
	check.start(0)
	check._unhandled_input(_key(KEY_UP))
	assert_eq(_current(), 0, "up from the first section stays")


func test_enter_replays_the_step_and_space_holds_it() -> void:
	check.start(0)
	var first: Array = played[0].duplicate()
	assert_false(first.is_empty())
	check._unhandled_input(_key(KEY_ENTER))
	assert_eq(started, [0, 0], "replayed")
	assert_eq(played[0], first + first, "its cues again")
	check._unhandled_input(_key(KEY_SPACE))
	_advance(30.0)
	assert_eq(started, [0, 0], "held on the step")
	check._unhandled_input(_key(KEY_SPACE))
	_advance(DT)
	assert_eq(_current(), 1, "moves on once released")
