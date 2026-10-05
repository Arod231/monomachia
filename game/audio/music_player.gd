class_name MusicPlayer
extends Node
## Plays the music director's tracks ([MusicDirector]) on the Music bus,
## through two [FadedLoop]s so no track starts, stops or switches cold.
##
## A switch starts the new track silent on the free loop and keeps the old one
## playing; when the new one rises (one mix later), the old one stops in that
## same mix, so one fades in as the other fades out, with no gap. Switching
## again before the new track rises replaces it, and switching back to the
## old track drops it, so the old one never stops. Playing the track already
## playing does nothing.
##
## It plays only when told to ([method play], or the director it follows,
## [method bind]), and carries on through pauses.

## The bus the tracks play on.
@export var bus: StringName = &"Music"
## Step the loops every frame; tests turn it off to step them themselves.
@export var auto_run := true

## Each track's stream, loaded from its file (MusicDirector.track_path) on
## first use. Setting an entry plays that stream for the track instead.
var streams: Dictionary = {}
## The two loops the tracks take turns on.
var loops: Array[FadedLoop] = []

var _track: StringName = &""
## The loop playing (or starting) the current track.
var _current: FadedLoop
## The loop it replaces, playing on until the current one rises.
var _outgoing: FadedLoop


func _init() -> void:
	# Music carries on through pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for loop_name: String in ["LoopA", "LoopB"]:
		var loop := FadedLoop.new()
		loop.name = loop_name
		loop.auto_run = false
		loop.rising.connect(_on_rising.bind(loop))
		add_child(loop)
		loops.append(loop)
	_current = loops[0]


func _process(_delta: float) -> void:
	if auto_run:
		advance()


## Follows [param director]'s track changes from now on.
func bind(director: MusicDirector) -> void:
	director.track_changed.connect(play)


## The track playing or starting, or &"" when the music is stopped.
func current_track() -> StringName:
	return _track


## Switches to [param track] (a MusicDirector track id).
func play(track: StringName) -> void:
	if track == _track:
		return
	var stream := _stream_for(track)
	if stream == null:
		return
	for loop: FadedLoop in loops:
		loop.bus = bus
	_track = track
	if _outgoing != null and _outgoing.player.stream == stream:
		# Back to the track still playing: drop the one that hasn't risen.
		_current.stop()
		_current = _outgoing
		_outgoing = null
		return
	if _current.is_audible():
		_outgoing = _current
		_current = loops[1] if _current == loops[0] else loops[0]
	_current.play(stream)


## Fades the music out.
func stop() -> void:
	_track = &""
	for loop: FadedLoop in loops:
		loop.stop()
	_outgoing = null


## Raises a track once the mixer has played it. Call it every frame (it runs
## by itself unless [member auto_run] is off).
func advance() -> void:
	for loop: FadedLoop in loops:
		loop.advance()


## Runs with the mixer held, so the old track falls in the mix the new one rises.
func _on_rising(loop: FadedLoop) -> void:
	if loop == _current and _outgoing != null:
		_outgoing.stop()
		_outgoing = null


func _stream_for(track: StringName) -> AudioStream:
	if streams.has(track):
		return streams[track]
	var path := MusicDirector.track_path(track)
	var stream: AudioStream = null
	if not path.is_empty() and ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		push_error("MusicPlayer: no music for track %s" % track)
		return null
	streams[track] = stream
	return stream
