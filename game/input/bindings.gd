class_name Bindings
extends RefCounted
## The 14 control actions and the default binding sets. Port of ACTIONS,
## DEFAULT_KB, DEFAULT_PAD, FIGHTSTICK_PAD, KB_ARROWS and tokensOf in
## v0.1-web-mvp:src/input/bindings.ts, translated to Godot codes (see InputToken).
##
## A binding set is a Dictionary from action id to an Array of up to SLOTS
## token strings. The default sets are functions that return a fresh copy, so
## a profile can change its own without touching the defaults.

## Slots per action on the Controls screen.
const SLOTS: int = 2

const ACTIONS: Array[String] = [
	"up", "down", "left", "right",
	"light", "heavy", "block", "dodge", "jump", "interact", "ultimate", "sprint", "grip",
	"pause",
]

## Names shown on the Controls screen.
const ACTION_LABELS: Dictionary = {
	"up": "Move toward opponent",
	"down": "Move away",
	"left": "Circle left",
	"right": "Circle right",
	"light": "Light attack",
	"heavy": "Heavy attack",
	"block": "Block / Parry",
	"dodge": "Dodge / Backstep",
	"jump": "Jump",
	"interact": "Pick up weapon",
	"ultimate": "Ultimate",
	"sprint": "Sprint (hold)",
	"grip": "Switch grip",
	"pause": "Pause",
}

## Small print under some action names.
const ACTION_HINTS: Dictionary = {
	"heavy": "hold to charge",
	"block": "hold / tap on impact",
	"ultimate": "or light + heavy together",
	"sprint": "or double-tap a direction",
	"grip": "one hand or two",
}

## The rule buttons each action holds (movement and pause are not buttons).
const ACTION_BUTTON: Dictionary = {
	"light": Btn.LIGHT,
	"heavy": Btn.HEAVY,
	"block": Btn.BLOCK,
	"dodge": Btn.DODGE,
	"jump": Btn.JUMP,
	"interact": Btn.INTERACT,
	"ultimate": Btn.ULTIMATE,
	"sprint": Btn.SPRINT,
	"grip": Btn.GRIP,
}

## Where the controller's Ultimate sat before the grip took Y (KE task 6): a
## profile saved then moves it to L2 as it loads (ControlProfile).
const OLD_PAD_ULTIMATE: String = "b:%d" % JOY_BUTTON_Y

static var _arrows: Dictionary = {}
static var _arrows_tokens: Dictionary = {}


## Keyboard and mouse, Souls-style (DEFAULT_KB). Sprint has no key: double-tap
## a direction. R switches the grip (KE task 6). Block is the left Shift only, as in the demo, so on a shared
## keyboard player 2 can't block for player 1 with right Shift.
static func default_kb() -> Dictionary:
	return {
		"up": [_k(KEY_W), _k(KEY_UP)],
		"down": [_k(KEY_S), _k(KEY_DOWN)],
		"left": [_k(KEY_A), _k(KEY_LEFT)],
		"right": [_k(KEY_D), _k(KEY_RIGHT)],
		"light": [InputToken.mouse(MOUSE_BUTTON_LEFT), _k(KEY_J)],
		"heavy": [InputToken.mouse(MOUSE_BUTTON_RIGHT), _k(KEY_K)],
		"block": [InputToken.key(KEY_SHIFT, KEY_LOCATION_LEFT), _k(KEY_L)],
		"dodge": [_k(KEY_SPACE)],
		"jump": [_k(KEY_F), _k(KEY_I)],
		"interact": [_k(KEY_E)],
		"ultimate": [_k(KEY_Q), _k(KEY_U)],
		"sprint": [],
		"grip": [_k(KEY_R)],
		"pause": [_k(KEY_ESCAPE), _k(KEY_P)],
	}


## Controller (DEFAULT_PAD): R1 light, R2 heavy, L1 block, circle dodge, cross
## jump, square pick up, triangle grip and L2 ultimate (where Elden Ring puts
## them, KE task 6; the ultimate was on triangle before), L3 sprint, Options
## pause. The D-pad and the left stick both move.
static func default_pad() -> Dictionary:
	var pad: Dictionary = _pad_movement()
	pad.merge({
		"light": [_b(JOY_BUTTON_RIGHT_SHOULDER)],
		"heavy": [_trigger(JOY_AXIS_TRIGGER_RIGHT)],
		"block": [_b(JOY_BUTTON_LEFT_SHOULDER)],
		"dodge": [_b(JOY_BUTTON_B)],
		"jump": [_b(JOY_BUTTON_A)],
		"interact": [_b(JOY_BUTTON_X)],
		"ultimate": [_trigger(JOY_AXIS_TRIGGER_LEFT)],
		"sprint": [_b(JOY_BUTTON_LEFT_STICK)],
		"grip": [_b(JOY_BUTTON_Y)],
		"pause": [_b(JOY_BUTTON_START)],
	})
	return pad


## 8-button fight stick (FIGHTSTICK_PAD): top row square, triangle, R1, L1;
## bottom row cross, circle, R2, L2 (the grip; KE task 6), and sprint on L3,
## the spare most sticks carry.
static func fight_stick_pad() -> Dictionary:
	var pad: Dictionary = _pad_movement()
	pad.merge({
		"light": [_b(JOY_BUTTON_X)],
		"heavy": [_b(JOY_BUTTON_Y)],
		"block": [_b(JOY_BUTTON_RIGHT_SHOULDER)],
		"dodge": [_b(JOY_BUTTON_B)],
		"jump": [_b(JOY_BUTTON_A)],
		"interact": [_trigger(JOY_AXIS_TRIGGER_RIGHT)],
		"ultimate": [_b(JOY_BUTTON_LEFT_SHOULDER)],
		"sprint": [_b(JOY_BUTTON_LEFT_STICK)],
		"grip": [_trigger(JOY_AXIS_TRIGGER_LEFT)],
		"pause": [_b(JOY_BUTTON_START)],
	})
	return pad


## The fixed right-hand layout for Versus player 2 on a shared keyboard
## (KB_ARROWS): arrows move; J K L light, heavy, block; ; dodge; I jump;
## O pick up; U ultimate; Y grip; Backspace pause; numpad 4 5 6 0 8 9 7 1 and
## Enter also work. Not remappable.
static func kb_arrows() -> Dictionary:
	return {
		"up": [_k(KEY_UP)],
		"down": [_k(KEY_DOWN)],
		"left": [_k(KEY_LEFT)],
		"right": [_k(KEY_RIGHT)],
		"light": [_k(KEY_J), _k(KEY_KP_4)],
		"heavy": [_k(KEY_K), _k(KEY_KP_5)],
		"block": [_k(KEY_L), _k(KEY_KP_6)],
		"dodge": [_k(KEY_SEMICOLON), _k(KEY_KP_0)],
		"jump": [_k(KEY_I), _k(KEY_KP_8)],
		"interact": [_k(KEY_O), _k(KEY_KP_9)],
		"ultimate": [_k(KEY_U), _k(KEY_KP_7)],
		"sprint": [],
		"grip": [_k(KEY_Y), _k(KEY_KP_1)],
		"pause": [_k(KEY_BACKSPACE), _k(KEY_KP_ENTER)],
	}


## A shared, read-only copy of kb_arrows() for per-tick sampling.
static func arrows_set() -> Dictionary:
	if _arrows.is_empty():
		_arrows = kb_arrows()
	return _arrows


## Every token of the arrow layout: what player 1 on keyboard and mouse ignores
## while player 2 uses it.
static func arrows_tokens() -> Dictionary:
	if _arrows_tokens.is_empty():
		_arrows_tokens = tokens_of(kb_arrows())
	return _arrows_tokens


## tokensOf(): the set of tokens in a binding set, as token -> true.
static func tokens_of(bindings: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for action: String in bindings:
		var list: Array = bindings[action]
		for token: String in list:
			out[token] = true
	return out


## A deep copy of a binding set.
static func copy_set(bindings: Dictionary) -> Dictionary:
	return bindings.duplicate(true)


static func _pad_movement() -> Dictionary:
	return {
		"up": [_b(JOY_BUTTON_DPAD_UP), InputToken.joy_axis(JOY_AXIS_LEFT_Y, false)],
		"down": [_b(JOY_BUTTON_DPAD_DOWN), InputToken.joy_axis(JOY_AXIS_LEFT_Y, true)],
		"left": [_b(JOY_BUTTON_DPAD_LEFT), InputToken.joy_axis(JOY_AXIS_LEFT_X, false)],
		"right": [_b(JOY_BUTTON_DPAD_RIGHT), InputToken.joy_axis(JOY_AXIS_LEFT_X, true)],
	}


static func _k(physical_keycode: int) -> String:
	return InputToken.key(physical_keycode)


static func _b(button: int) -> String:
	return InputToken.joy_button(button)


static func _trigger(axis: int) -> String:
	return InputToken.joy_axis(axis, true)
