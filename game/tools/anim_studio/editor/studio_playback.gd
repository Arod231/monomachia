class_name StudioPlayback
extends RefCounted
## Where the Studio's editor is in the clip it shows (milestone-1 task 25):
## the playhead in source frames (30 a second; one timeline, the rules
## frames shown as a second ruler, two to a source frame), whether it plays
## and loops, and how fast. A pure model with no nodes: the editor advances
## it each frame and poses the fighter at source_time().

## The slowest and fastest the playback runs (times real time).
const MIN_RATE: float = 0.1
const MAX_RATE: float = 2.0

## The playhead (source frames from the chain's start).
var frame: float = 0.0
## The clip's length (source frames): the playhead runs from 0 to here.
var length: float = 0.0
var playing: bool = false
var loop: bool = true
## How fast it plays, times real time (MIN_RATE to MAX_RATE).
var rate: float = 1.0:
	set(v):
		rate = clampf(v, MIN_RATE, MAX_RATE)


## Moves the playhead by `delta` seconds of real time, if playing: at the end
## it wraps round when looping, else stops there.
func advance(delta: float) -> void:
	if not playing or length <= 0.0:
		return
	var f: float = frame + delta * float(ClipManifest.SOURCE_FPS) * rate
	if f >= length:
		if loop:
			f = fposmod(f, length)
		else:
			f = length
			playing = false
	frame = f


## Steps the playhead `n` whole source frames (back for a negative `n`), from
## the whole frame it is on: at an end it stops, or wraps round when looping.
func step(n: int) -> void:
	if length <= 0.0:
		return
	var f: float = roundf(frame) + float(n)
	if loop:
		var whole: float = floorf(length) + 1.0
		f = fposmod(f, whole)
	frame = clampf(f, 0.0, length)


## Puts the playhead at source frame `f`, kept within the clip.
func seek(f: float) -> void:
	frame = clampf(f, 0.0, maxf(length, 0.0))


## The playhead in seconds from the chain's start (what the poser takes).
func source_time() -> float:
	return frame / float(ClipManifest.SOURCE_FPS)
