class_name BusCapture
extends RefCounted
## Test helper: records what a bus mixes, sample by sample, so audio tests can
## measure fades and clicks in the real mix. The dummy driver of headless runs
## still mixes (4096 frames about every 93 ms), so this works without a sound
## card. Attach it, play, wait for frames, then read [member frames].
##
## [method level_stream] makes a looping stream that holds one level, so a
## gain change shows up directly as the captured value.

## The source sample rate of [method level_stream].
const RATE := 44100

var frames := PackedVector2Array()
var _bus_index: int = -1
var _effect: AudioEffectCapture


## Puts a capture effect first on [param bus], or last when
## [param after_effects], to hear what the bus's own effects made of it.
func attach(bus: StringName, after_effects := false) -> BusCapture:
	_bus_index = AudioServer.get_bus_index(bus)
	_effect = AudioEffectCapture.new()
	_effect.buffer_length = 4.0
	AudioServer.add_bus_effect(_bus_index, _effect, -1 if after_effects else 0)
	return self


## Takes the capture effect off its bus.
func detach() -> void:
	if _effect == null:
		return
	for i: int in AudioServer.get_bus_effect_count(_bus_index):
		if AudioServer.get_bus_effect(_bus_index, i) == _effect:
			AudioServer.remove_bus_effect(_bus_index, i)
			break
	_effect = null


## Moves what the bus has mixed since the last call into [member frames].
func collect() -> int:
	var available := _effect.get_frames_available()
	if available > 0:
		frames.append_array(_effect.get_buffer(available))
	return frames.size()


## Forgets everything captured so far, including what is still waiting.
func clear() -> void:
	collect()
	frames.clear()


## True once the bus has mixed past [param seen] frames in all and the last
## of them is silent: a sound stopped before then has played out its fade, so
## it can't spill into the next capture.
func silent_after(seen: int) -> bool:
	return collect() > seen and frames[frames.size() - 1].is_zero_approx()


## The left channel from [param from] on.
func left(from: int = 0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i: int in range(from, frames.size()):
		out.append(frames[i].x)
	return out


## The biggest change from one sample to the next in [param samples]: a click
## is a jump; a fade over n samples moves at most its range / n per sample.
static func biggest_step(samples: PackedFloat32Array) -> float:
	var step := 0.0
	for i: int in range(1, samples.size()):
		step = maxf(step, absf(samples[i] - samples[i - 1]))
	return step


## The index of the first sample at or above [param level] from [param from],
## or -1.
static func first_at_or_above(samples: PackedFloat32Array, level: float, from: int = 0) -> int:
	for i: int in range(from, samples.size()):
		if samples[i] >= level:
			return i
	return -1


## The index of the first sample at or below [param level] from [param from],
## or -1.
static func first_at_or_below(samples: PackedFloat32Array, level: float, from: int = 0) -> int:
	for i: int in range(from, samples.size()):
		if samples[i] <= level:
			return i
	return -1


## Milliseconds that [param count] samples last at the mix rate.
static func ms(count: int) -> float:
	return 1000.0 * count / AudioServer.get_mix_rate()


## A seamless stereo loop of a tenth of a second that holds [param level],
## imported the way the game's music is, so a stretch of it reads as that level.
static func level_stream(level: float) -> AudioStreamWAV:
	var count := RATE / 10
	var bytes := PackedByteArray()
	bytes.resize(44 + count * 4)
	bytes.encode_u32(0, 0x46464952) # "RIFF"
	bytes.encode_u32(4, 36 + count * 4)
	bytes.encode_u32(8, 0x45564157) # "WAVE"
	bytes.encode_u32(12, 0x20746d66) # "fmt "
	bytes.encode_u32(16, 16)
	bytes.encode_u16(20, 1) # PCM
	bytes.encode_u16(22, 2) # stereo
	bytes.encode_u32(24, RATE)
	bytes.encode_u32(28, RATE * 4)
	bytes.encode_u16(32, 4)
	bytes.encode_u16(34, 16)
	bytes.encode_u32(36, 0x61746164) # "data"
	bytes.encode_u32(40, count * 4)
	var value := roundi(level * 32767.0)
	for i: int in count * 2:
		bytes.encode_s16(44 + i * 2, value)
	return AudioStreamWAV.load_from_buffer(bytes, {"edit/loop_mode": 2, "edit/loop_begin": 0, "edit/loop_end": -1})
