class_name SoundPlayer
extends Node
## Plays the sound bank's cues (see [SoundBank]) from two fixed pools of
## voices: flat [AudioStreamPlayer]s, and [AudioStreamPlayer3D]s for cues
## marked spatial that are given a position. A full pool steals its oldest
## voice and never grows.
##
## Each play picks a variation that differs from the cue's last one, a pitch in
## the cue's range, the cue's level (plus any extra) and its bus. Streams are
## loaded once per run and shared by every player; a file that won't load, or
## a cue the bank doesn't have, is listed in [member missing] and reported
## once by each player that asks for it.
##
## [method play_event] expands one rules event into its cues (rolling for
## the ones that sound only some of the time, the light swing's exhale) and
## keeps the delayed ones (the KO gong, the round gong) until [method advance] passes
## their delay. A hold ([method set_held]) pauses the playing voices and the
## delay clock, and the cues of events played meanwhile wait for the release;
## [method play_cue] still plays at once.
##
## 3D cues fall off gently with distance (inverse distance from
## [member unit_size]) and are not muffled, so the opponent stays clear; a cue
## nearer than unit_size is boosted by at most [member near_boost_db], so a
## footstep by the camera stays a footstep.
##
## Knows nothing about matches: the match audio and the menus each own one.

## Emitted when a cue starts, with the voice playing it.
signal played(cue: StringName, voice: Node)

## Voices in the flat pool. Set before the player enters the tree.
@export var flat_voices: int = 12
## Voices in the 3D pool. Set before the player enters the tree.
@export var spatial_voices: int = 24
## Advance the delay clock from _process. Tests turn it off and call
## [method advance] themselves.
@export var auto_run: bool = true

@export_group("3D")
## The distance (m) at which a 3D cue plays at its own level; each doubling of
## the distance takes 6 dB off. At 5 m the player's own fighter, about 4.6 m
## from the camera, is at its level and the opponent at duelling distance
## about 3 dB under.
@export var unit_size: float = 5.0
## The most a 3D cue nearer than unit_size is raised above its level (dB).
@export var near_boost_db: float = 3.0

## Picks variations and pitches. Seed it for repeatable runs.
var rng := RandomNumberGenerator.new()
## Paths that failed to load, and cue names the bank doesn't have.
var missing := PackedStringArray()

var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
## When each voice last started (a running count), to find the oldest.
var _started: Dictionary = {}
var _starts := 0
## path -> AudioStream, or null for a file that won't load. Shared, so a new
## match host doesn't load the bank again.
static var _streams: Dictionary = {}
## The variation each cue played last.
var _last: Dictionary = {}
## Cues waiting to start: {cue, at, extra_db, pitch_scale, due}, in the order asked.
var _pending: Array[Dictionary] = []
var _clock := 0.0
var _held := false
var _paused: Array[Node] = []


func _ready() -> void:
	for i in flat_voices:
		var voice := AudioStreamPlayer.new()
		voice.name = "Flat%d" % i
		add_child(voice)
		_flat.append(voice)
	for i in spatial_voices:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Spatial%d" % i
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		# 20500 Hz turns the distance low-pass off.
		voice.attenuation_filter_cutoff_hz = 20500.0
		add_child(voice)
		_spatial.append(voice)


func _process(delta: float) -> void:
	if auto_run:
		advance(delta)


## Plays every cue of one rules event (see [method SoundBank.cues_for]).
## [param position_resolver] takes the event and returns where it happened,
## a [Vector3], or null to play it flat; spatial cues play there.
## [param cast] names each side's fighter, for their own cloth, gear and voice.
func play_event(event: Dictionary, position_resolver: Callable = Callable(), cast: Array = []) -> void:
	var cues := SoundBank.cues_for(event, cast)
	if cues.is_empty():
		return
	var at: Variant = null
	if position_resolver.is_valid():
		at = position_resolver.call(event)
	for cue: Dictionary in cues:
		if float(cue.get("chance", 1.0)) < 1.0 and rng.randf() >= float(cue["chance"]):
			continue
		var delay := float(cue["delay"])
		var pitch_scale := float(cue.get("pitch_scale", 1.0))
		if delay > 0.0 or _held:
			_pending.append({"cue": cue["cue"], "at": at, "extra_db": cue["volume_db"], "pitch_scale": pitch_scale, "due": _clock + delay})
		else:
			play_cue(cue["cue"], at, float(cue["volume_db"]), pitch_scale)


## Starts one cue now and returns its voice, or null if it can't play.
## A spatial cue given a position [param at] plays from a 3D voice there.
## [param extra_db] is added to the cue's own level, and [param pitch_scale]
## multiplies its random pitch (a side's voice, SoundBank.SIDE_PITCH).
func play_cue(cue_name: StringName, at: Variant = null, extra_db: float = 0.0, pitch_scale: float = 1.0) -> Node:
	if not SoundBank.CUES.has(cue_name):
		_report_missing(String(cue_name), "SoundPlayer: no cue %s in the sound bank" % cue_name)
		return null
	var cue: Dictionary = SoundBank.CUES[cue_name]
	var pick := SoundBank.pick_variation(cue_name, rng, int(_last.get(cue_name, -1)))
	var stream := stream_for(str(pick[0]))
	if stream == null:
		return null
	_last[cue_name] = pick[1]
	var level := float(cue["volume_db"]) + extra_db
	var voice: Node
	if bool(cue["spatial"]) and at is Vector3:
		voice = _take(_spatial)
		if voice != null:
			var spatial := voice as AudioStreamPlayer3D
			spatial.global_position = at
			spatial.unit_size = unit_size
			# max_db caps the voice's final level, its own volume included.
			spatial.max_db = clampf(level + near_boost_db, -24.0, 6.0)
	else:
		voice = _take(_flat)
	if voice == null:
		return null
	voice.set("stream", stream)
	voice.set("bus", cue["bus"])
	voice.set("volume_db", level)
	voice.set("pitch_scale", SoundBank.random_pitch(cue_name, rng) * pitch_scale)
	voice.call("play")
	played.emit(cue_name, voice)
	return voice


## Moves the delay clock on and starts the cues now due. Does nothing while
## held.
func advance(delta: float) -> void:
	if _held:
		return
	_clock += delta
	var due: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for cue: Dictionary in _pending:
		if float(cue["due"]) <= _clock:
			due.append(cue)
		else:
			waiting.append(cue)
	if due.is_empty():
		return
	_pending = waiting
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["due"]) < float(b["due"]))
	for cue: Dictionary in due:
		play_cue(cue["cue"], cue["at"], float(cue["extra_db"]), float(cue.get("pitch_scale", 1.0)))


## Holds or releases everything: the playing voices pause and the delay clock
## stops until the release.
func set_held(held: bool) -> void:
	if held == _held:
		return
	_held = held
	if held:
		for voice: Node in _voices():
			if voice.get("playing"):
				voice.set("stream_paused", true)
				_paused.append(voice)
	else:
		for voice: Node in _paused:
			voice.set("stream_paused", false)
		_paused.clear()


func is_held() -> bool:
	return _held


## True when no voice is playing or paused and no cue is waiting.
func is_quiet() -> bool:
	if not _pending.is_empty():
		return false
	for voice: Node in _voices():
		if voice.get("playing") or voice.get("stream_paused"):
			return false
	return true


## Stops every voice, drops the waiting cues and releases the hold.
func stop_all() -> void:
	for voice: Node in _voices():
		voice.set("stream_paused", false)
		voice.call("stop")
	_pending.clear()
	_paused.clear()
	_held = false


## Loads every file of these cues now, so the first play doesn't load.
func preload_cues(cue_names: Array[StringName]) -> void:
	for cue_name: StringName in cue_names:
		if not SoundBank.CUES.has(cue_name):
			_report_missing(String(cue_name), "SoundPlayer: no cue %s in the sound bank" % cue_name)
			continue
		for path: String in SoundBank.paths_for(cue_name):
			stream_for(path)


## The stream at [param path], loaded once and cached; null (listed in
## [member missing]) if it won't load.
func stream_for(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = (load(path) as AudioStream) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _streams[path]
	if stream == null:
		_report_missing(path, "SoundPlayer: cannot load %s" % path)
	return stream


func _voices() -> Array[Node]:
	var voices: Array[Node] = []
	voices.append_array(_flat)
	voices.append_array(_spatial)
	return voices


## A free voice from the pool, else the one that started longest ago; null
## before the pools are made.
func _take(pool: Array) -> Node:
	var chosen: Node = null
	for voice: Node in pool:
		if not voice.get("playing") and not voice.get("stream_paused"):
			chosen = voice
			break
		if chosen == null or int(_started[voice]) < int(_started[chosen]):
			chosen = voice
	if chosen == null:
		return null
	_starts += 1
	_started[chosen] = _starts
	return chosen


func _report_missing(what: String, message: String) -> void:
	if missing.has(what):
		return
	missing.append(what)
	push_error(message)
