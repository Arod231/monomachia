extends GutTest
## The headless check that every sound plays: one seeded computer-vs-computer
## match per pairing of the playable weapons (mirrors included, so a new weapon
## joins by itself), played to the results through the game's main scene with
## its match audio, ambience and music. A match fails it when:
## [br]- a sound file is missing or won't load (the sound players' missing lists);
## [br]- a rules event didn't play every cue the sound bank gives it for the
## match's fighters, delayed ones included, or something played that no event
## asked for (a cue that sounds only some of the time, a light swing's
## exhale, may play fewer times than asked, never more);
## [br]- the ambience doesn't play, or a music track the match needs doesn't
## load and play;
## [br]- anything logs an error (GUT fails a test on any unexpected error).

## The longest a match may take (game frames): 15 minutes. The other
## whole-match tests allow 12, but the hidden Daggers' mirror, its moves near
## twice as long at 1.0x until milestone 2's retune, runs 6.5 to 11 minutes of
## rules time on Hard (seeds 11-20, measured at milestone-1 task 86), and its
## seed here passed 12 once the disarmed weapon stuck where it flew.
const MAX_FRAMES := 60 * 60 * 15

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


## The cues a footfall plays (the footstep and every fighter's own cloth and
## gear under it), which follow the fighters' feet, not events.
static func _footfall_cues() -> Array[StringName]:
	var out: Array[StringName] = [&"footstep"]
	for fighter: StringName in SoundBank.FOLEY:
		out.append_array(SoundBank.FOLEY[fighter].get(&"step", []))
	return out


## The deflect pairs' cues (milestone-1 task 136), which a steel parry
## plays on their frames as the pair's halves play, not with its event.
static func _pair_cues() -> Array[StringName]:
	var out: Array[StringName] = []
	for direction: StringName in SoundBank.DEFLECT_SOUNDS:
		for half: StringName in [&"deflect", &"recoil"]:
			for c: Dictionary in SoundBank.deflect_pair_cues(direction, half):
				if not out.has(c["cue"]):
					out.append(c["cue"])
	return out


func test_a_whole_match_plays_every_sound(pair: Array = use_parameters(_pairings())) -> void:
	var fired := {}
	var expected := {}
	var sometimes := {}
	var played := {}
	var footfall := _footfall_cues()
	var pair_cues := _pair_cues()
	var pair_played := {}
	var steel_parries := [0]
	host.sim_event.connect(func(e: Dictionary) -> void:
		if host.attract:
			return
		_count(fired, StringName(e["t"]))
		if SoundBank.sounds_deflect_pair(e):
			steel_parries[0] += 1
		for cue: Dictionary in SoundBank.cues_for(e, audio.cast()):
			_count(expected if float(cue["chance"]) >= 1.0 else sometimes, cue["cue"]))
	audio.player.played.connect(func(cue: StringName, _voice: Node) -> void:
		if pair_cues.has(cue):
			_count(pair_played, cue)
		elif not footfall.has(cue):
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
	for cue: Variant in sometimes:
		var extra: int = int(played.get(cue, 0)) - int(expected.get(cue, 0))
		assert_between(extra, 0, int(sometimes[cue]), "%s played no more often than asked" % cue)
		if extra > 0:
			played[cue] = int(played[cue]) - extra
	assert_eq(_differences(expected, played), [] as Array[String], "every event's cues played, and nothing else")
	# each steel parry sounds its pair's halves once at most: a scrape and a
	# cloth snap, a whoosh and a stagger
	var scrapes := 0
	var halves := 0
	for cue: Variant in pair_played:
		halves += int(pair_played[cue])
		if String(cue).begins_with("deflect_scrape_"):
			scrapes += int(pair_played[cue])
	assert_lte(scrapes, steel_parries[0], "a scrape a steel parry at most")
	assert_lte(halves, 4 * steel_parries[0], "four pair cues a steel parry at most")
	if steel_parries[0] > 0:
		assert_gt(scrapes, 0, "%d steel parries sounded their pairs" % steel_parries[0])
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
