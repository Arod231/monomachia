class_name InputTracker
extends RefCounted
## Port of v0.1-web-mvp:src/sim/input.ts (the tracker and its direction helpers; the button
## enum is in btn.gd and RawInput in raw_input.gd).
##
## Device-agnostic input as the simulation sees it.
## Keyboards, gamepads and the AI all produce a RawInput each frame; the
## InputTracker turns that into edges, buffered presses, taps and double-taps.
##
## Port notes: dirIndex, dirVector and sameSector are static funcs here.
## Math.hypot, Math.atan2, Math.sin and Math.cos are JsMath's (V8's results).
## dir_vector returns a RawInput with only mx and my set (TS: { mx, my }).
## The getters sprinting and moving are functions. sideways() is the
## rebuild's.


## 8-way direction index: 0 = forward, 1 = forward-right, 2 = right ... 7 = forward-left. -1 = neutral.
static func dir_index(mx: float, my: float) -> int:
	var m: float = JsMath.hypot(mx, my)
	if m < SimConst.DIR_DEADZONE:
		return -1
	var a: float = JsMath.atan2(mx, my) # 0 = forward, +pi/2 = right
	return ((SimMath.js_round(a / (PI / 4.0)) % 8) + 8) % 8


static func dir_vector(d: int) -> RawInput:
	if d < 0:
		return RawInput.make(0.0, 0.0)
	var a: float = float(d) * (PI / 4.0)
	return RawInput.make(JsMath.sin(a), JsMath.cos(a))


static func same_sector(a: int, b: int) -> bool:
	if a < 0 or b < 0:
		return false
	var d: int = absi(a - b) % 8
	return d <= 1 or d >= 7


var held: int = 0
var prev_held: int = 0
var mx: float = 0.0
var my: float = 0.0
var dir: int = -1
var prev_dir: int = -1

var press_frame: PackedInt64Array = _filled_ints(-99999)
var release_frame: PackedInt64Array = _filled_ints(-99999)
var consumed: Array[bool] = _filled_bools(true)
var held_since: PackedInt64Array = _filled_ints(-99999)

# direction tap / double-tap bookkeeping
var dir_activated_frame: int = -99999
var dir_released_frame: int = -99999
var last_released_dir: int = -1
var last_press_duration: int = 999
## true on the frame a direction is freshly pushed from neutral (a "step")
var step_request: bool = false
## latched by double-tap-and-hold; cleared when the stick returns to neutral
var sprint_latched: bool = false

var frame: int = 0


func update(raw: RawInput, p_frame: int) -> void:
	frame = p_frame
	prev_held = held
	held = raw.buttons
	mx = raw.mx
	my = raw.my

	for b: int in Btn.NUM:
		var m: int = 1 << b
		var now: bool = (held & m) != 0
		var before: bool = (prev_held & m) != 0
		if now and not before:
			press_frame[b] = p_frame
			consumed[b] = false
			held_since[b] = p_frame
		elif not now and before:
			release_frame[b] = p_frame

	prev_dir = dir
	dir = dir_index(raw.mx, raw.my)
	step_request = false
	if prev_dir == -1 and dir != -1:
		# fresh push from neutral
		var since_release: int = p_frame - dir_released_frame
		if (
			since_release <= SimConst.DOUBLE_TAP_FRAMES
			and last_press_duration <= SimConst.TAP_MAX_FRAMES
			and same_sector(dir, last_released_dir)
		):
			sprint_latched = true
		dir_activated_frame = p_frame
		step_request = true
	elif prev_dir != -1 and dir == -1:
		dir_released_frame = p_frame
		last_released_dir = prev_dir
		last_press_duration = p_frame - dir_activated_frame
		sprint_latched = false


func is_held(b: int) -> bool:
	return (held & (1 << b)) != 0


## Pressed this exact frame (rising edge).
func pressed_now(b: int) -> bool:
	return (held & (1 << b)) != 0 and (prev_held & (1 << b)) == 0


## An unconsumed press within the buffer window.
func buffered(b: int, window: int = SimConst.INPUT_BUFFER) -> bool:
	return not consumed[b] and frame - press_frame[b] <= window


func consume(b: int) -> void:
	consumed[b] = true


func held_frames(b: int) -> int:
	return frame - held_since[b] if is_held(b) else 0


func sprinting() -> bool:
	return dir != -1 and (sprint_latched or is_held(Btn.SPRINT))


func moving() -> bool:
	return dir != -1


## Whether the stick is held left or right: past the dead zone, and more
## sideways than forward or back. It picks Moonsplitter's horizontal wave and
## the horizontal Iai.
func sideways() -> bool:
	return dir != -1 and absf(mx) > absf(my)


static func _filled_ints(v: int) -> PackedInt64Array:
	var a: PackedInt64Array = PackedInt64Array()
	a.resize(Btn.NUM)
	a.fill(v)
	return a


static func _filled_bools(v: bool) -> Array[bool]:
	var a: Array[bool] = []
	a.resize(Btn.NUM)
	a.fill(v)
	return a
