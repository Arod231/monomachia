class_name BindingLabels
extends RefCounted
## Display names for binding tokens: key names, mouse buttons, and PlayStation,
## Xbox or generic controller names. Port of bindingLabel() in
## src/input/bindings.ts and the token choice of Game.label() in src/game.ts.

## Indexed by JoyButton (SDL layout). Cross is "×", where the demo has "✕":
## the bundled UI fonts have no "✕" (task 22.1).
const PS_BUTTONS: Array[String] = [
	"×", "○", "□", "△", "Create", "PS", "Options", "L3", "R3", "L1", "R1",
	"D-pad ↑", "D-pad ↓", "D-pad ←", "D-pad →", "Mic", "Paddle 1", "Paddle 2", "Paddle 3", "Paddle 4", "Touchpad",
]
const XBOX_BUTTONS: Array[String] = [
	"A", "B", "X", "Y", "View", "Guide", "Menu", "LS", "RS", "LB", "RB",
	"D-pad ↑", "D-pad ↓", "D-pad ←", "D-pad →", "Share", "P1", "P2", "P3", "P4", "Touchpad",
]

const KEY_NAMES: Dictionary = {
	KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_META: "Win",
	KEY_SPACE: "Space",
	KEY_ESCAPE: "Esc",
	KEY_ENTER: "Enter",
	KEY_TAB: "Tab",
	KEY_BACKSPACE: "Backspace",
	KEY_DELETE: "Del",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
	KEY_CAPSLOCK: "Caps",
	KEY_SEMICOLON: ";",
	KEY_APOSTROPHE: "'",
	KEY_COMMA: ",",
	KEY_PERIOD: ".",
	KEY_SLASH: "/",
	KEY_BRACKETLEFT: "[",
	KEY_BRACKETRIGHT: "]",
	KEY_BACKSLASH: "\\",
	KEY_MINUS: "-",
	KEY_EQUAL: "=",
	KEY_QUOTELEFT: "`",
	KEY_KP_ENTER: "Num Enter",
	KEY_KP_ADD: "Num +",
	KEY_KP_SUBTRACT: "Num -",
	KEY_KP_MULTIPLY: "Num *",
	KEY_KP_DIVIDE: "Num /",
	KEY_KP_PERIOD: "Num .",
}


## The name of one token; style is a PadStyle constant (used for controller
## tokens only).
static func token_label(token: String, style: int = PadStyle.GENERIC) -> String:
	match InputToken.kind(token):
		InputToken.KEY:
			return key_name(InputToken.code(token), InputToken.key_location(token))
		InputToken.MOUSE:
			return mouse_name(InputToken.code(token))
		InputToken.JOY_BUTTON:
			return button_name(InputToken.code(token), style)
		InputToken.JOY_AXIS:
			return axis_name(InputToken.code(token), InputToken.axis_sign(token) > 0.0, style)
	return token


## The label for an action, from its token list: the first token that is not a
## stick direction and not excluded, or else the first token; "" when the
## action has no binding. (Triggers count as buttons here: the demo's triggers
## were buttons.)
static func first_label(tokens: Array, style: int = PadStyle.GENERIC, exclude: Dictionary = {}) -> String:
	if tokens.is_empty():
		return ""
	for token: String in tokens:
		if not InputToken.is_stick(token) and not exclude.has(token):
			return token_label(token, style)
	return token_label(String(tokens[0]), style)


## location: a KeyLocation; one key of a pair is named "L-Shift" or "R-Ctrl".
static func key_name(physical_keycode: int, location: int = KEY_LOCATION_UNSPECIFIED) -> String:
	if location == KEY_LOCATION_LEFT:
		return "L-" + key_name(physical_keycode)
	if location == KEY_LOCATION_RIGHT:
		return "R-" + key_name(physical_keycode)
	if KEY_NAMES.has(physical_keycode):
		return KEY_NAMES[physical_keycode]
	if physical_keycode >= KEY_A and physical_keycode <= KEY_Z:
		return char(physical_keycode)
	if physical_keycode >= KEY_0 and physical_keycode <= KEY_9:
		return char(physical_keycode)
	if physical_keycode >= KEY_KP_0 and physical_keycode <= KEY_KP_9:
		return "Num %d" % (physical_keycode - KEY_KP_0)
	var s: String = OS.get_keycode_string(physical_keycode)
	return s if s != "" else "Key %d" % physical_keycode


static func mouse_name(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return "Left Click"
		MOUSE_BUTTON_RIGHT:
			return "Right Click"
		MOUSE_BUTTON_MIDDLE:
			return "Middle Click"
		MOUSE_BUTTON_XBUTTON1:
			return "Mouse 4"
		MOUSE_BUTTON_XBUTTON2:
			return "Mouse 5"
	return "Mouse %d" % button


static func button_name(button: int, style: int) -> String:
	if style == PadStyle.PLAYSTATION and button >= 0 and button < PS_BUTTONS.size():
		return PS_BUTTONS[button]
	if style == PadStyle.XBOX and button >= 0 and button < XBOX_BUTTONS.size():
		return XBOX_BUTTONS[button]
	if button >= JOY_BUTTON_DPAD_UP and button <= JOY_BUTTON_DPAD_RIGHT:
		return XBOX_BUTTONS[button]
	return "Button %d" % button


static func axis_name(axis: int, positive: bool, style: int) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "Stick →" if positive else "Stick ←"
		JOY_AXIS_LEFT_Y:
			return "Stick ↓" if positive else "Stick ↑"
		JOY_AXIS_RIGHT_X:
			return "R-Stick →" if positive else "R-Stick ←"
		JOY_AXIS_RIGHT_Y:
			return "R-Stick ↓" if positive else "R-Stick ↑"
		JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT:
			if positive:
				return _trigger_name(axis == JOY_AXIS_TRIGGER_RIGHT, style)
	return "Axis %d%s" % [axis, "+" if positive else "-"]


static func _trigger_name(right: bool, style: int) -> String:
	match style:
		PadStyle.PLAYSTATION:
			return "R2" if right else "L2"
		PadStyle.XBOX:
			return "RT" if right else "LT"
	return "Right trigger" if right else "Left trigger"
