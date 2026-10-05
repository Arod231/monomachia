class_name FadedLoop
extends Node
## One looping stream that never starts or stops cold. The music tracks and
## the arena ambience start mid-signal (the tail of the last bar wraps into the
## first), so a cold start or stop clicks.
##
## The fades are Godot's own: the mixer ramps any change of a sound's volume
## across one mix of 512 frames (10.7 ms at 48 kHz, 11.6 ms at 44.1 kHz), and
## [method AudioStreamPlayer.stop] fades out across one mix the same way. The
## one thing it doesn't fade is a start: a new sound's first mix plays at its
## full volume. So [method play] starts the stream at [constant SILENT_DB] and
## waits for its first mix (its position moves), then [method advance] raises
## it to [member volume_db], and the mixer ramps it up. That also covers a
## loop that has to rise and another that has to fall in the same mix: do both
## inside [signal rising]. (servers/audio/audio_server.cpp, Godot 4.7.2.)

## The loop has been mixed once and its volume is going up now. Handlers run
## with the mixer held, so whatever they change lands in the same mix.
signal rising

## Silent enough not to hear, without the -inf of zero gain.
const SILENT_DB := -80.0

## The bus the loop plays on.
@export var bus: StringName = &"Music"
## The loop's level once it has risen (dB), on top of its bus.
@export var volume_db: float = 0.0
## Run [method advance] every frame; tests turn it off to step it themselves.
@export var auto_run := true

var player: AudioStreamPlayer

var _risen := false
## The playback position right after play(): when it moves, the mixer has
## played the loop once.
var _start_position := 0.0


func _init() -> void:
	# Music and ambience carry on through pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "Player"
	add_child(player)


func _process(_delta: float) -> void:
	if auto_run:
		advance()


## Starts [param stream] from its beginning, silent, to rise after its first
## mix. Whatever the loop played before stops with the mixer's fade.
func play(stream: AudioStream) -> void:
	_risen = false
	player.bus = bus
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	_start_position = player.get_playback_position()


## Fades the loop out over one mix, then the mixer drops it.
func stop() -> void:
	_risen = false
	player.stop()


## True from [method play] until [method stop], silent start included.
func is_playing() -> bool:
	return player.playing


## True once the loop has risen, until it stops.
func is_audible() -> bool:
	return _risen and player.playing


## Raises the loop once the mixer has played it. Call it every frame (it runs
## by itself unless [member auto_run] is off).
func advance() -> void:
	if _risen or not player.playing or player.get_playback_position() == _start_position:
		return
	AudioServer.lock()
	_risen = true
	player.volume_db = volume_db
	rising.emit()
	AudioServer.unlock()
