class_name FakeDeviceState
extends DeviceState
## A device state set by hand, for tests: press keys and buttons, move axes,
## plug and unplug controllers. apply(event) updates it from an InputEvent the
## way Godot's Input does before the event reaches the scene.

## physical keycode -> { KeyLocation: true }: LEFT or RIGHT for one key of a
## pair, UNSPECIFIED for a key pressed with no side (as GodotDeviceState sees
## a key whose event gave no location).
var _keys: Dictionary = {}
var _mouse: Dictionary = {}
## device id -> { "name": String, "info": Dictionary, "buttons": Dictionary, "axes": Dictionary }
var _pads: Dictionary = {}


## Answers as GodotDeviceState does: a side is held when its key is; with no
## side known, a key held without one counts for both sides.
func is_key_pressed(physical_keycode: int, location: int = KEY_LOCATION_UNSPECIFIED) -> bool:
	var held: Dictionary = _keys.get(physical_keycode, {})
	if location == KEY_LOCATION_UNSPECIFIED:
		return not held.is_empty()
	if held.has(KEY_LOCATION_LEFT) or held.has(KEY_LOCATION_RIGHT):
		return held.has(location)
	return held.has(KEY_LOCATION_UNSPECIFIED)


## Forgets every held key and mouse button, as when the window loses focus.
func release_keys() -> void:
	_keys.clear()
	_mouse.clear()


func is_mouse_pressed(button: int) -> bool:
	return _mouse.has(button)


func joy_button_pressed(device: int, button: int) -> bool:
	if not _pads.has(device):
		return false
	var buttons: Dictionary = _pads[device].buttons
	return buttons.has(button)


func joy_axis(device: int, axis: int) -> float:
	if not _pads.has(device):
		return 0.0
	var axes: Dictionary = _pads[device].axes
	return float(axes.get(axis, 0.0))


func connected_joypads() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _pads:
		ids.append(id)
	ids.sort()
	return ids


func joy_name(device: int) -> String:
	return String(_pads[device].name) if _pads.has(device) else ""


func joy_info(device: int) -> Dictionary:
	return (_pads[device].info as Dictionary).duplicate() if _pads.has(device) else {}


# ------------------------------------------------------------------ setters

## location: KEY_LOCATION_LEFT or _RIGHT for one key of a pair.
func press_key(physical_keycode: int, location: int = KEY_LOCATION_UNSPECIFIED) -> void:
	var held: Dictionary = _keys.get_or_add(physical_keycode, {})
	held[location] = true


func release_key(physical_keycode: int, location: int = KEY_LOCATION_UNSPECIFIED) -> void:
	if not _keys.has(physical_keycode):
		return
	var held: Dictionary = _keys[physical_keycode]
	held.erase(location)
	if held.is_empty():
		_keys.erase(physical_keycode)


func press_mouse(button: int) -> void:
	_mouse[button] = true


func release_mouse(button: int) -> void:
	_mouse.erase(button)


## Connects a controller and emits joy_connection_changed (unless notify is
## false: a connection nobody heard).
func plug_pad(device: int, name: String = "Xbox Series X Controller", info: Dictionary = {}, notify: bool = true) -> void:
	_pads[device] = {"name": name, "info": info, "buttons": {}, "axes": {}}
	if notify:
		joy_connection_changed.emit(device, true)


## Disconnects a controller and emits joy_connection_changed.
func unplug_pad(device: int) -> void:
	_pads.erase(device)
	joy_connection_changed.emit(device, false)


func press_button(device: int, button: int) -> void:
	if _pads.has(device):
		var buttons: Dictionary = _pads[device].buttons
		buttons[button] = true


func release_button(device: int, button: int) -> void:
	if _pads.has(device):
		var buttons: Dictionary = _pads[device].buttons
		buttons.erase(button)


func set_axis(device: int, axis: int, value: float) -> void:
	if _pads.has(device):
		var axes: Dictionary = _pads[device].axes
		axes[axis] = value


## Releases every key, mouse button and controller button and centres the axes.
func release_all() -> void:
	_keys.clear()
	_mouse.clear()
	for id: int in _pads:
		(_pads[id].buttons as Dictionary).clear()
		(_pads[id].axes as Dictionary).clear()


## Updates the state from a key, mouse button, joypad button or joypad motion
## event, as Godot's Input does before dispatching it.
func apply(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		# Godot's Input tracks keys by physical keycode only.
		var code: int = key.physical_keycode
		if code == KEY_NONE or key.echo:
			return
		if key.pressed:
			press_key(code, key.location)
		else:
			release_key(code, key.location)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			press_mouse(mb.button_index)
		else:
			release_mouse(mb.button_index)
	elif event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		if jb.pressed:
			press_button(jb.device, jb.button_index)
		else:
			release_button(jb.device, jb.button_index)
	elif event is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = event
		set_axis(jm.device, jm.axis, jm.axis_value)
