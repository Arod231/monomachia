extends GutTest
## The headless check that every sound plays: one seeded computer-vs-computer
## match per pairing of the playable weapons (mirrors included, so a new weapon
## joins by itself), played to the results through the game's main scene with
## its match audio, ambience and music. A match fails it when:
## [br]- a sound file is missing or won't load (the sound players' missing lists);
## [br]- a rules event didn't play every cue the sound bank gives it, delayed
## ones included, or something played that no event asked for;
## [br]- the ambience doesn't play, or a music track the match needs doesn't
## load and play;
## [br]- anything logs an error (GUT fails a test on any unexpected error).

## The longest a match may take (game frames), as in the other whole-match tests.
const MAX_FRAMES := 60 * 60 * 12

var main: Node
var host: MatchHost
var audio: MatchAudio


func before_each() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# The stand-in arena keeps the matches fast; the shrine's bed is the default.
	main.set("arena_id", ArenaScenes.STANDIN)
	add_child_autofree(main)
	host = main.get_node("MatchHost")
	host.auto_run = false
	audio = host.get_node("Audio")
	audio.player.auto_run = false


## Every pairing of the playable weapons, mirrors included.
static func _pairings() -> Array:
	var out := []
	var weapons: Array = Moves.PLAYABLE_WEAPONS
	for i: int in weapons.size():
		for j: int in range(i, weapons.size()):
			out.append([weapons[i], weapons[j]])
	return out


func _services() -> Node:
	return get_tree().root.get_node("GameServices")


static func _count(tally: Dictionary, key: Variant) -> void:
	tally[key] = int(tally.get(key, 0)) + 1


## "cue: expected n, played m" for every cue whose counts differ.
static func _differences(expected: Dictionary, played: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var cues: Array = expected.keys()
	for cue: Variant in played.keys():
		if not cues.has(cue):
			cues.append(cue)
	cues.sort()
	for cue: Variant in cues:
		if int(expected.get(cue, 0)) != int(played.get(cue, 0)):
			out.append("%s: expected %d, played %d" % [cue, int(expected.get(cue, 0)), int(played.get(cue, 0))])
	return out


func test_a_whole_match_plays_every_sound(pair: Array = use_parameters(_pairings())) -> void:
	var fired := {}
	var expected := {}
	var played := {}
	host.sim_event.connect(func(e: Dictionary) -> void:
		if host.attract:
			return
		_count(fired, StringName(e["t"]))
		for cue: Dictionary in SoundBank.cues_for(e):
			_count(expected, cue["cue"]))
	audio.player.played.connect(func(cue: StringName, _voice: Node) -> void:
		if cue != &"footstep":
			_count(played, cue))
	var cfg := MatchConfig.make(MatchConfig.WATCH,
		MatchSide.computer(&"rogue", pair[0], 0, &"hard"),
		MatchSide.computer(&"hunter", pair[1], 1, &"hard"),
		11, ArenaScenes.STANDIN)
	assert_true(main.call("start_match", cfg), "%s against %s" % pair)
	var music: MusicPlayer = _services().get("music")
	var tracks := {}
	var footsteps := [0]
	audio.player.played.connect(func(cue: StringName, _voice: Node) -> void:
		if cue == &"footstep":
			footsteps[0] += 1)
	var frames := 0
	while not host.is_finished() and frames < MAX_FRAMES:
		host.step(3)
		audio.player.advance(3 * SimConst.DT)
		frames += 3
		tracks[music.current_track()] = true
		if frames == 300:
			assert_true(audio.ambience.is_playing(), "the arena's ambience plays")
	assert_true(host.is_finished(), "the match reached the results")
	audio.player.advance(5.0)
	assert_gt(expected.size(), 10, "the match made plenty of sound")
	assert_eq(_differences(expected, played), [] as Array[String], "every event's cues played, and nothing else")
	assert_eq(audio.player.missing, PackedStringArray(), "no sound file missing")
	assert_eq((_services().get("ui_sounds") as SoundPlayer).missing, PackedStringArray())
	assert_gt(footsteps[0], 0, "footsteps")
	for track: StringName in [MusicDirector.BATTLE, MusicDirector.MATCH_POINT]:
		assert_true(tracks.has(track), "the %s track played" % track)
	assert_eq(music.current_track(), MusicDirector.MENU, "the results play the menu track")
	for track: StringName in [MusicDirector.BATTLE, MusicDirector.MATCH_POINT, MusicDirector.MENU]:
		assert_not_null(music.streams.get(track), "the %s track loaded" % track)
	var types: Array = fired.keys()
	types.sort()
	gut.p("%s v %s: %d frames, %d footsteps; events %s" % [pair[0], pair[1], frames, footsteps[0], ", ".join(types.map(func(t: StringName) -> String: return "%s %d" % [t, fired[t]]))])
