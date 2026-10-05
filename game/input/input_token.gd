class_name InputToken
extends RefCounted
## One physical input written as a short string, the unit of a binding.
## Port of the token strings in v0.1-web-mvp:src/input/bindings.ts, with Godot's codes:
##
##   "k:<physical keycode>"   a key by its position on a US QWERTY keyboard (k:87 = W)
##   "k:<keycode><L|R>"       the left or right key of a pair, from InputEventKey.location
##                            (k:4194325L = left Shift); with no mark, either key of the pair
##   "m:<mouse button>"       MouseButton: 1 left, 2 right, 3 middle, 8 and 9 the side buttons
##   "b:<joypad button>"      JoyButton in the SDL layout (b:0 = bottom face button, b:10 = right shoulder)
##   "a:<joypad axis><+|->"   JoyAxis and direction (a:1- = left stick up, a:5+ = right trigger)
##
## Web to Godot: web buttons b4/b5 (L1/R1) are b:9/b:10, b8/b9 (Back/Start) are
## b:4/b:6, b10/b11 (stick clicks) are b:7/b:8, the D-pad b12-b15 is b:11-b:14,
## and the triggers b6/b7 are the axes a:4+ and a:5+. Mouse 0/1/2 (left, middle,
## right) are m:1/m:3/m:2.

const KEY: String = "k"
const MOUSE: String = "m"
const JOY_BUTTON: String = "b"
const JOY_AXIS: String = "a"

const _LEFT: String = "L"
const _RIGHT: String = "R"


## location: a KeyLocation; LEFT or RIGHT marks one key of a pair (Shift, Ctrl,
## Alt, Meta).
static func key(physical_keycode: int, location: int = KEY_LOCATION_UNSPECIFIED) -> String:
	var side: String = _LEFT if location == KEY_LOCATION_LEFT else _RIGHT if location == KEY_LOCATION_RIGHT else ""
	return "k:%d%s" % [physical_keycode, side]


## The KeyLocation a key token names: LEFT or RIGHT, or UNSPECIFIED for any
## other token (either key of a pair).
static func key_location(token: String) -> int:
	if kind(token) != KEY:
		return KEY_LOCATION_UNSPECIFIED
	if token.ends_with(_LEFT):
		return KEY_LOCATION_LEFT
	if token.ends_with(_RIGHT):
		return KEY_LOCATION_RIGHT
	return KEY_LOCATION_UNSPECIFIED


static func mouse(button: int) -> String:
	return "m:%d" % button


static func joy_button(button: int) -> String:
	return "b:%d" % button


## positive: true for the + direction (right, down, trigger pulled).
static func joy_axis(axis: int, positive: bool) -> String:
	return "a:%d%s" % [axis, "+" if positive else "-"]


## "k", "m", "b", "a", or "" when the token is malformed.
static func kind(token: String) -> String:
	if token.length() < 3 or token[1] != ":":
		return ""
	var k: String = token[0]
	if k == KEY or k == MOUSE or k == JOY_BUTTON or k == JOY_AXIS:
		return k
	return ""


## The keycode, mouse button, joypad button or joypad axis.
static func code(token: String) -> int:
	return _number(token).to_int()


## +1.0 or -1.0 for an axis token.
static func axis_sign(token: String) -> float:
	return -1.0 if token.ends_with("-") else 1.0


static func is_valid(token: String) -> bool:
	var k: String = kind(token)
	if k == "":
		return false
	if k == JOY_AXIS:
		var dir: String = token[token.length() - 1]
		if dir != "+" and dir != "-":
			return false
	var body: String = _number(token)
	return body.is_valid_int() and body.to_int() >= 0


## The number in a token: what follows "x:", less an axis direction or a key's
## side mark.
static func _number(token: String) -> String:
	if kind(token) == JOY_AXIS or key_location(token) != KEY_LOCATION_UNSPECIFIED:
		return token.substr(2, token.length() - 3)
	return token.substr(2)


## Keyboard and mouse tokens belong on the keyboard-and-mouse tab.
static func is_keyboard_or_mouse(token: String) -> bool:
	var k: String = kind(token)
	return k == KEY or k == MOUSE


## Joypad button and axis tokens belong on the controller tab.
static func is_joypad(token: String) -> bool:
	var k: String = kind(token)
	return k == JOY_BUTTON or k == JOY_AXIS


static func is_axis(token: String) -> bool:
	return kind(token) == JOY_AXIS


## L2/R2 (LT/RT): an axis that works as a button past a threshold.
static func is_trigger(token: String) -> bool:
	if not is_axis(token):
		return false
	var a: int = code(token)
	return a == JOY_AXIS_TRIGGER_LEFT or a == JOY_AXIS_TRIGGER_RIGHT


## A stick direction (any axis that is not a trigger).
static func is_stick(token: String) -> bool:
	return is_axis(token) and not is_trigger(token)
