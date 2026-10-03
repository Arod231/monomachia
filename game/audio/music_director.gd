class_name MusicDirector
extends RefCounted
## Decides which music track should be playing. Plain logic with no nodes: the
## screens tell it where the game is ([method enter_menu], [method enter_match])
## and the match feeds it the rules events; [method current_track] is the
## answer. [MusicPlayer] plays and crossfades the tracks.
##
## Rules (docs/specs/godot-rebuild.md, Sound and Music):
## [br]- menus, character select and results: the menu track (110 BPM);
## [br]- a match: the battle track (140 BPM);
## [br]- from the round call (the roundStart event) of any round in which either
## fighter already has two wins: the match-point track (160 BPM), until the
## match ends.
##
## Every track starts mid-signal, not at silence (the reverb tail of the last
## bar wraps into the first so the loop is seamless), so started or stopped
## cold it clicks: [FadedLoop] fades it in and out over 10-20 ms.

signal track_changed(track: StringName)

const MENU := &"menu"
const BATTLE := &"battle"
const MATCH_POINT := &"match_point"
const TRACK_IDS: Array[StringName] = [MENU, BATTLE, MATCH_POINT]

const MUSIC_DIR := "res://assets/audio/music/"
const TRACKS_JSON := "res://assets/audio/music/tracks.json"

## Round wins that make the next round a match point (first to three wins).
const MATCH_POINT_WINS := 2

var _track: StringName = MENU
var _in_match := false
var _wins: Array[int] = [0, 0]


## The track that should be playing now.
func current_track() -> StringName:
	return _track


## Menus, character select, results.
func enter_menu() -> StringName:
	_in_match = false
	_wins = [0, 0]
	return _switch_to(MENU)


## A new match begins (any mode with rounds: Duel, Versus, Watch, Training).
func enter_match() -> StringName:
	_in_match = true
	_wins = [0, 0]
	return _switch_to(BATTLE)


## The round call, given each fighter's round wins so far.
func round_call(wins: Array) -> StringName:
	if not _in_match:
		_in_match = true
	_wins = [int(wins[0]), int(wins[1])]
	if _wins.max() >= MATCH_POINT_WINS:
		return _switch_to(MATCH_POINT)
	return _switch_to(BATTLE)


## Feeds one rules event; returns the track that should now be playing.
## Uses roundOver (for the wins) and roundStart (the round call).
func handle_event(event: Dictionary) -> StringName:
	var type := str(event.get("t", event.get(&"t", "")))
	match type:
		"roundOver":
			var wins: Variant = event.get("wins", event.get(&"wins", null))
			if wins is Array and (wins as Array).size() == 2:
				_wins = [int(wins[0]), int(wins[1])]
		"roundStart":
			return round_call(_wins)
	return _track


## The file, tempo and length of a track, from tracks.json:
## [code]{"file", "path", "bpm", "bars", "beats_per_bar", "seconds"}[/code].
static func track_info(track: StringName) -> Dictionary:
	var tracks: Dictionary = _load_tracks()
	if not tracks.has(String(track)):
		return {}
	var info: Dictionary = (tracks[String(track)] as Dictionary).duplicate()
	info["path"] = MUSIC_DIR + str(info["file"])
	return info


## The resource path of a track's audio file.
static func track_path(track: StringName) -> String:
	return str(track_info(track).get("path", ""))


## Seconds from [param position] to the next bar line of [param track], so a
## switch can land on the beat.
static func seconds_to_next_bar(track: StringName, position: float) -> float:
	var info := track_info(track)
	if info.is_empty():
		return 0.0
	var bar := 60.0 / float(info["bpm"]) * float(info["beats_per_bar"])
	var into := fposmod(position, bar)
	return 0.0 if is_zero_approx(into) else bar - into


func _switch_to(track: StringName) -> StringName:
	if track != _track:
		_track = track
		track_changed.emit(track)
	return _track


static func _load_tracks() -> Dictionary:
	# Loaded as a JSON resource so it is exported with the game.
	var json := load(TRACKS_JSON) as JSON
	if json == null:
		push_error("MusicDirector: cannot read %s" % TRACKS_JSON)
		return {}
	var data: Variant = json.data
	if not (data is Dictionary) or not (data as Dictionary).has("tracks"):
		push_error("MusicDirector: %s has no tracks" % TRACKS_JSON)
		return {}
	return (data as Dictionary)["tracks"]
