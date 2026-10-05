class_name MenuNav
extends RefCounted
## Turns key and controller events into menu commands, for MenuPage.
##
## Keys: the arrows and W/A/S/D move, Enter and Space choose, Esc and
## Backspace go back. A held key repeats at the system's key repeat (its echo
## events). Controller: the D-pad and the left stick move, A chooses, B goes
## back. A held D-pad or stick repeats as the demo's did: the first repeat
## 380 ms after the press, then one every 120 ms (devices.ts, poll()).
##
## The repeat runs on `clock` (milliseconds), so tests can drive it with a
## fake clock; the page calls tick() every frame.

enum Cmd { NONE, UP, DOWN, LEFT, RIGHT, OK, BACK }

## The first repeat of a held D-pad or stick, after the press.
const FIRST_REPEAT_MS: int = 380
## Each repeat after the first.
const NEXT_REPEAT_MS: int = 120
## How far the left stick must lean for a direction (the demo's 0.55).
const STICK_THRESHOLD: float = 0.55

const DIRECTION_KEYS: Dictionary[Key, Cmd] = {
	KEY_UP: Cmd.UP, KEY_W: Cmd.UP,
	KEY_DOWN: Cmd.DOWN, KEY_S: Cmd.DOWN,
	KEY_LEFT: Cmd.LEFT, KEY_A: Cmd.LEFT,
	KEY_RIGHT: Cmd.RIGHT, KEY_D: Cmd.RIGHT,
}
const OK_KEYS: Array[Key] = [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const BACK_KEYS: Array[Key] = [KEY_ESCAPE, KEY_BACKSPACE]
const DPAD: Dictionary[JoyButton, Cmd] = {
	JOY_BUTTON_DPAD_UP: Cmd.UP,
	JOY_BUTTON_DPAD_DOWN: Cmd.DOWN,
	JOY_BUTTON_DPAD_LEFT: Cmd.LEFT,
	JOY_BUTTON_DPAD_RIGHT: Cmd.RIGHT,
}

## Returns the time in milliseconds.
var clock: Callable = Time.get_ticks_msec

## The D-pad buttons held, by command.
var _dpad: Dictionary[Cmd, bool] = {}
var _stick: Vector2 = Vector2.ZERO
## The controller direction held, and when it next repeats.
var _held: Cmd = Cmd.NONE
var _repeat_at: int = 0


func _init(p_clock: Callable = Callable()) -> void:
	if p_clock.is_valid():
		clock = p_clock


## Forgets what the controller holds (a page opening or closing).
func reset() -> void:
	_dpad.clear()
	_stick = Vector2.ZERO
	_held = Cmd.NONE


## Whether a menu would take this event: every key, D-pad, A, B and left
## stick event, including those that give no command (a release, a stick
## still held). The page takes them all, so Godot's own focus moves and
## button presses never act on them as well.
static func is_nav_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: Key = _key_of(event as InputEventKey)
		return DIRECTION_KEYS.has(key) or OK_KEYS.has(key) or BACK_KEYS.has(key)
	if event is InputEventJoypadButton:
		var b: JoyButton = (event as InputEventJoypadButton).button_index
		return DPAD.has(b) or b == JOY_BUTTON_A or b == JOY_BUTTON_B
	if event is InputEventJoypadMotion:
		var axis: JoyAxis = (event as InputEventJoypadMotion).axis
		return axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y
	return false


## The command an event gives now (Cmd.NONE for most), keeping track of the
## controller's held direction for tick().
func command(event: InputEvent) -> Cmd:
	if event is InputEventKey:
		var k: InputEventKey = event
		if not k.pressed:
			return Cmd.NONE
		var key: Key = _key_of(k)
		if DIRECTION_KEYS.has(key):
			return DIRECTION_KEYS[key]
		if k.echo:
			return Cmd.NONE
		if OK_KEYS.has(key):
			return Cmd.OK
		if BACK_KEYS.has(key):
			return Cmd.BACK
		return Cmd.NONE
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		if DPAD.has(jb.button_index):
			_dpad[DPAD[jb.button_index]] = jb.pressed
			return _controller_moved()
		if not jb.pressed:
			return Cmd.NONE
		if jb.button_index == JOY_BUTTON_A:
			return Cmd.OK
		if jb.button_index == JOY_BUTTON_B:
			return Cmd.BACK
		return Cmd.NONE
	if event is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = event
		if jm.axis == JOY_AXIS_LEFT_X:
			_stick.x = jm.axis_value
		elif jm.axis == JOY_AXIS_LEFT_Y:
			_stick.y = jm.axis_value
		else:
			return Cmd.NONE
		return _controller_moved()
	return Cmd.NONE


## The repeat of a held D-pad or stick direction when one is due, else
## Cmd.NONE. Called every frame.
func tick() -> Cmd:
	if _held == Cmd.NONE:
		return Cmd.NONE
	var now: int = clock.call()
	if now < _repeat_at:
		return Cmd.NONE
	_repeat_at = now + NEXT_REPEAT_MS
	return _held


## A new direction from the D-pad or stick moves at once and starts the
## repeat; letting go stops it.
func _controller_moved() -> Cmd:
	var dir: Cmd = _controller_direction()
	if dir == _held:
		return Cmd.NONE
	_held = dir
	if dir == Cmd.NONE:
		return Cmd.NONE
	_repeat_at = int(clock.call()) + FIRST_REPEAT_MS
	return dir


## The D-pad wins over the stick; a stick leaning both ways moves along its
## stronger axis.
func _controller_direction() -> Cmd:
	for c: Cmd in [Cmd.UP, Cmd.DOWN, Cmd.LEFT, Cmd.RIGHT]:
		if _dpad.get(c, false):
			return c
	if absf(_stick.y) >= absf(_stick.x):
		if _stick.y <= -STICK_THRESHOLD:
			return Cmd.UP
		if _stick.y >= STICK_THRESHOLD:
			return Cmd.DOWN
	else:
		if _stick.x <= -STICK_THRESHOLD:
			return Cmd.LEFT
		if _stick.x >= STICK_THRESHOLD:
			return Cmd.RIGHT
	return Cmd.NONE


## The key a key event means: its physical key (layout-free W/A/S/D), or its
## key code when an event carries no physical key.
static func _key_of(k: InputEventKey) -> Key:
	return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
