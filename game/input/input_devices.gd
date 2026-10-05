class_name InputDevices
extends RefCounted
## Per-player input: turns the keyboard, mouse and controllers into one
## RawInput per player per tick through each player's controls profile.
## Port of the sampling, controller seats and pause edges of
## v0.1-web-mvp:src/input/devices.ts, plus the device, profile, exclusion and label choices
## of v0.1-web-mvp:src/game.ts. Menu navigation is not here: menus use Godot's ui_* actions.
##
## Devices report held state only: the rules layer's InputTracker turns taps
## into steps and double-tap-and-hold into a sprint.
##
## The host keeps one InputDevices for the whole game, with an InputFeed in the
## tree that hands it every event (labels follow the last device used, even in
## menus) and reports the window losing focus:
##   var input := InputDevices.new()                  # reads Godot's Input
##   var feed := InputFeed.new(input)
##   add_child(feed)
##   feed.focus_lost.connect(pause)                   # pause a match on focus loss
## It sets the players up at match start, then samples every simulation tick:
##   input.set_single_player(profiles.active_profile())          # Duel, Training
##   input.set_versus([InputDevices.KBM, InputDevices.PAD0], [p1, p2])   # Versus
##   var raw: RawInput = input.sample(0)
##   if input.any_pause_pressed(): pause()            # also Esc and Start on any controller
##   prompt.text = "Pick up: " + input.label("interact", 0)
## On resume from the pause menu (whose Controls screen may pick another
## profile) and on leaving a match:
##   input.set_profile(0, profiles.active_profile())  # Duel, Training
##   input.rearm_pause()
##   input.unbind_seats()                             # on quit to menu
##
## Movement on a controller comes from its bindings only. The demo also added
## the D-pad, left stick and hat switches of controllers the browser didn't
## map; Godot already turns hats into D-pad buttons, which the defaults bind.

## Keyboard, mouse and the first controller together (single player).
const ALL: String = "all"
## Keyboard and mouse with the player's profile.
const KBM: String = "kbm"
## The fixed right-hand keyboard layout (Versus player 2 on a shared keyboard).
const KB_ARROWS: String = "kb_arrows"
## The controller in seat 1 or seat 2.
const PAD0: String = "pad0"
const PAD1: String = "pad1"
const DEVICES: Array[String] = [ALL, KBM, KB_ARROWS, PAD0, PAD1]

## A stick axis past this counts; the curve below maps the rest to 0.35..1.
const STICK_DEADZONE: float = 0.25
const STICK_SPAN: float = 0.6
const STICK_FLOOR: float = 0.35
## A trigger (L2/R2, LT/RT) past this counts as held. The demo read triggers as
## buttons, and browsers report a trigger as pressed past XInput's trigger
## threshold, 30/255 (about 0.12), so a light pull starts a heavy and easing
## off keeps a charge until the trigger is nearly let go.
const TRIGGER_THRESHOLD: float = 30.0 / 255.0
## An action value past this holds its rule button.
const HELD: float = 0.5
## Joypad motion past this makes the controller the last device used.
const ACTIVITY_AXIS: float = 0.6

enum LastUsed { KEYBOARD, PAD }

var state: DeviceState
## For labels in single player: keyboard or controller names.
var last_used: LastUsed = LastUsed.KEYBOARD

var _devices: Array[String] = [ALL]
var _profiles: Array[ControlProfile] = [ControlProfile.create()]
var _seated: bool = false
var _seats: Array[int] = [-1, -1]
var _pause_prev: Dictionary = {}


## p_state: a DeviceState; Godot's Input when omitted.
func _init(p_state: DeviceState = null) -> void:
	state = p_state if p_state != null else GodotDeviceState.new()


# ------------------------------------------------------------------ players

## Duel and Training: one player on keyboard, mouse and the first controller.
## Unbinds the controller seats.
func set_single_player(profile: ControlProfile) -> void:
	_devices = [ALL]
	_profiles = [profile]
	_pause_prev.clear()
	unbind_seats()


## Versus: each player reads one device (KBM, KB_ARROWS, PAD0 or PAD1) with
## their own profile. Ties the controller seats to the controllers connected
## now (call it at match start, and again for a rematch).
func set_versus(devices: Array[String], profiles: Array[ControlProfile]) -> void:
	assert(devices.size() == 2 and profiles.size() == 2, "Versus needs two devices and two profiles")
	_devices = devices.duplicate()
	_profiles = profiles.duplicate()
	_pause_prev.clear()
	bind_seats()


## Swaps one player's profile mid-match, touching neither the controller seats
## nor the pause edges. The demo looked profiles up on every tick, so call this
## on resume when the pause menu's Controls screen picked another profile:
##   input.set_profile(0, profiles.active_profile())        # Duel, Training
## A player who isn't set up is ignored.
func set_profile(player: int, profile: ControlProfile) -> void:
	if player >= 0 and player < _profiles.size():
		_profiles[player] = profile


func player_count() -> int:
	return _devices.size()


func device_of(player: int) -> String:
	return _devices[player] if player >= 0 and player < _devices.size() else _devices[0]


func profile_of(player: int) -> ControlProfile:
	return _profiles[player] if player >= 0 and player < _profiles.size() else _profiles[0]


## The tokens a player must ignore because the other player's layout uses
## them: player 1 on keyboard and mouse ignores the whole arrow layout while
## player 2 uses it. As token -> true.
func excluded_tokens(player: int) -> Dictionary:
	if player_count() < 2:
		return {}
	if device_of(player) == KBM and device_of(1 - player) == KB_ARROWS:
		return Bindings.arrows_tokens()
	return {}


## The player's input this tick; empty for a player who isn't set up.
func sample(player: int) -> RawInput:
	if player < 0 or player >= player_count():
		return RawInput.empty()
	return sample_device(profile_of(player), device_of(player), excluded_tokens(player))


## True on the tick the player's pause binding goes down.
func pause_pressed(player: int) -> bool:
	if player < 0 or player >= player_count():
		return false
	return pause_edge(profile_of(player), device_of(player), excluded_tokens(player))


## True on the tick Esc or Start on any connected controller goes down. These
## pause during play whatever the bindings, as in the demo (where Esc was the
## menus' "back" and Start their "pause").
func system_pause_pressed() -> bool:
	var pressed: bool = _edge("sys:esc", state.is_key_pressed(KEY_ESCAPE))
	for id: int in state.connected_joypads():
		if _edge("sys:start:%d" % id, state.joy_button_pressed(id, JOY_BUTTON_START)):
			pressed = true
	return pressed


## The host's pause check during play: pause_pressed() for every player, plus
## system_pause_pressed() (every edge is updated).
func any_pause_pressed() -> bool:
	var pressed: bool = system_pause_pressed()
	for p: int in player_count():
		if pause_pressed(p):
			pressed = true
	return pressed


## On resume: notes each player's pause binding, Esc and every Start button as
## already down, so a button still held from the menu doesn't pause again.
func rearm_pause() -> void:
	any_pause_pressed()


## The name of the input a player presses for an action, for HUD prompts:
## the first binding that is not a stick direction and not excluded, named for
## the player's device (PlayStation, Xbox or generic names on a controller).
func label(action: String, player: int = 0) -> String:
	var device: String = device_of(player)
	var profile: ControlProfile = profile_of(player)
	var on_pad: bool = device == PAD0 or device == PAD1 or (
		device == ALL and last_used == LastUsed.PAD and first_pad() >= 0
	)
	var bindings: Dictionary
	if device == KB_ARROWS:
		bindings = Bindings.arrows_set()
	elif on_pad:
		bindings = profile.pad
	else:
		bindings = profile.kb
	var tokens: Array = bindings.get(action, [])
	var style: int = pad_style_for(device) if on_pad else PadStyle.GENERIC
	return BindingLabels.first_label(tokens, style, excluded_tokens(player))


## Sees every input event: tracks the last device used (for labels in single
## player) and which key of a pair (left or right Shift) is held. An InputFeed
## in the scene tree forwards events here from _input(), before any Control
## can take them.
func note_event(event: InputEvent) -> void:
	state.note_event(event)
	if event is InputEventKey:
		if (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			last_used = LastUsed.KEYBOARD
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			last_used = LastUsed.KEYBOARD
	elif event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			last_used = LastUsed.PAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > ACTIVITY_AXIS:
			last_used = LastUsed.PAD


## Forgets every held key, as when the window loses focus (InputFeed calls
## this; the demo cleared its keys on blur).
func release_keys() -> void:
	state.release_keys()


# ------------------------------------------------------------------ sampling

## One device's input through a profile, ignoring the excluded tokens (see
## excluded_tokens()). The move vector is clamped to length 1; a button action
## holds its rule button past HELD.
func sample_device(profile: ControlProfile, device: String, exclude: Dictionary = {}) -> RawInput:
	var up: float = action_value(profile, "up", device, exclude)
	var down: float = action_value(profile, "down", device, exclude)
	var left: float = action_value(profile, "left", device, exclude)
	var right: float = action_value(profile, "right", device, exclude)
	var mx: float = right - left
	var my: float = up - down
	var m: float = sqrt(mx * mx + my * my)
	if m > 1.0:
		mx /= m
		my /= m
	var buttons: int = 0
	for action: String in Bindings.ACTION_BUTTON:
		if action_value(profile, action, device, exclude) > HELD:
			buttons |= Btn.bit(Bindings.ACTION_BUTTON[action])
	return RawInput.make(mx, my, buttons)


## How far an action is held on a device, 0 to 1: the strongest of its
## bindings. Keys, mouse buttons, controller buttons and triggers past the
## threshold give 1; stick directions follow stick_curve().
func action_value(profile: ControlProfile, action: String, device: String, exclude: Dictionary = {}) -> float:
	var v: float = 0.0
	var kb_set: Dictionary = _keyboard_set(profile, device)
	if not kb_set.is_empty():
		var tokens: Array = kb_set.get(action, [])
		for token: String in tokens:
			if not exclude.has(token):
				v = maxf(v, _keyboard_value(token))
	var pad: int = _pad_of(device)
	if pad >= 0:
		var tokens: Array = profile.pad.get(action, [])
		for token: String in tokens:
			v = maxf(v, _pad_value(token, pad))
	return v


## True when the pause binding goes down (edge per device).
func pause_edge(profile: ControlProfile, device: String, exclude: Dictionary = {}) -> bool:
	return _edge(device, action_value(profile, "pause", device, exclude) > HELD)


## True when held goes from false to true since the last call with this key.
func _edge(key: String, held: bool) -> bool:
	var edge: bool = held and not bool(_pause_prev.get(key, false))
	_pause_prev[key] = held
	return edge


## A stick axis value (0..1 in the bound direction) after the dead zone:
## past 0.25 it maps to min(1, (v - 0.25) / 0.6 + 0.35).
static func stick_curve(v: float) -> float:
	if v <= STICK_DEADZONE:
		return 0.0
	return minf(1.0, (v - STICK_DEADZONE) / STICK_SPAN + STICK_FLOOR)


func _keyboard_set(profile: ControlProfile, device: String) -> Dictionary:
	match device:
		ALL, KBM:
			return profile.kb
		KB_ARROWS:
			return Bindings.arrows_set()
	return {}


func _pad_of(device: String) -> int:
	match device:
		ALL:
			return first_pad()
		PAD0:
			return pad_for(0)
		PAD1:
			return pad_for(1)
	return -1


func _keyboard_value(token: String) -> float:
	match InputToken.kind(token):
		InputToken.KEY:
			return 1.0 if state.is_key_pressed(InputToken.code(token), InputToken.key_location(token)) else 0.0
		InputToken.MOUSE:
			return 1.0 if state.is_mouse_pressed(InputToken.code(token)) else 0.0
	return 0.0


func _pad_value(token: String, pad: int) -> float:
	match InputToken.kind(token):
		InputToken.JOY_BUTTON:
			return 1.0 if state.joy_button_pressed(pad, InputToken.code(token)) else 0.0
		InputToken.JOY_AXIS:
			var v: float = state.joy_axis(pad, InputToken.code(token)) * InputToken.axis_sign(token)
			if InputToken.is_trigger(token):
				return 1.0 if v > TRIGGER_THRESHOLD else 0.0
			return stick_curve(v)
	return 0.0


# ------------------------------------------------------------------ controllers and seats

## The first connected controller (single player), or -1.
func first_pad() -> int:
	var pads: Array[int] = state.connected_joypads()
	return pads[0] if not pads.is_empty() else -1


## Ties seat 1 and seat 2 to the controllers connected now, so unplugging
## controller 1 can never hand player 2's controller to player 1.
func bind_seats() -> void:
	var pads: Array[int] = state.connected_joypads()
	_seated = true
	_seats = [pads[0] if pads.size() > 0 else -1, pads[1] if pads.size() > 1 else -1]


## Back to "first controller, second controller" in connection order.
func unbind_seats() -> void:
	_seated = false
	_seats = [-1, -1]


func seats_bound() -> bool:
	return _seated


## The controller device id for seat 0 or 1, or -1 when none is connected
## there. With seats bound, an empty seat takes the first controller the other
## seat doesn't hold when it is asked for (as padAt() did), so a controller
## plugged in mid-match goes to the seat a player reads, never to an unused
## one. A seat whose controller is unplugged stays empty until that controller
## comes back.
func pad_for(seat: int) -> int:
	if seat < 0 or seat > 1:
		return -1
	var pads: Array[int] = state.connected_joypads()
	if not _seated:
		return pads[seat] if seat < pads.size() else -1
	if _seats[seat] < 0:
		for id: int in pads:
			if id != _seats[1 - seat]:
				_seats[seat] = id
				break
	var device: int = _seats[seat]
	return device if device >= 0 and pads.has(device) else -1


func pad_connected(seat: int) -> bool:
	return pad_for(seat) >= 0


## The controller's name in a seat, or "".
func pad_name(seat: int) -> String:
	var device: int = pad_for(seat)
	return state.joy_name(device) if device >= 0 else ""


## PadStyle of the controller a device reads (seat 2 for PAD1, else seat 1).
func pad_style_for(device: String) -> int:
	var pad: int = pad_for(1) if device == PAD1 else pad_for(0)
	if pad < 0:
		return PadStyle.GENERIC
	return PadStyle.detect(state.joy_name(pad), state.joy_info(pad))


## The first controller's name (the Controls screen), or "".
func first_pad_name() -> String:
	var pad: int = first_pad()
	return state.joy_name(pad) if pad >= 0 else ""


## Whether Godot knows the first controller's button layout; true with none.
func first_pad_known() -> bool:
	var pad: int = first_pad()
	return pad < 0 or state.joy_known(pad)


## PadStyle of the first controller (the Controls screen).
func pad_style() -> int:
	var pad: int = first_pad()
	if pad < 0:
		return PadStyle.GENERIC
	return PadStyle.detect(state.joy_name(pad), state.joy_info(pad))
