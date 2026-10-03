class_name GodotDeviceState
extends DeviceState
## The real device state: reads Godot's Input singleton and forwards its
## joy_connection_changed signal.
##
## Godot's Input keeps one pressed flag per physical keycode, so it can't tell
## left Shift from right Shift, and releasing either drops the flag while the
## other is still held. The left and right keys of a pair are tracked here
## instead, from the events note_event() sees (InputEventKey.location).

## physical keycode -> { KEY_LOCATION_LEFT or _RIGHT: true } for the sides held
var _sides: Dictionary = {}


func _init() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func is_key_pressed(physical_keycode: int, location: int = KEY_LOCATION_UNSPECIFIED) -> bool:
	var sides: Dictionary = _sides.get(physical_keycode, {})
	if location == KEY_LOCATION_UNSPECIFIED:
		return not sides.is_empty() or Input.is_physical_key_pressed(physical_keycode)
	if not sides.is_empty():
		return sides.has(location)
	# No event said which side is down (a tool that sends no key location, or
	# events nobody forwarded): Godot's single flag counts for both sides.
	return Input.is_physical_key_pressed(physical_keycode)


func note_event(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or key.echo or key.physical_keycode == KEY_NONE or key.location == KEY_LOCATION_UNSPECIFIED:
		return
	var code: int = key.physical_keycode
	if key.pressed:
		var sides: Dictionary = _sides.get_or_add(code, {})
		sides[key.location] = true
	elif _sides.has(code):
		var sides: Dictionary = _sides[code]
		sides.erase(key.location)
		if sides.is_empty():
			_sides.erase(code)


func release_keys() -> void:
	_sides.clear()


func is_mouse_pressed(button: int) -> bool:
	return Input.is_mouse_button_pressed(button)


func joy_button_pressed(device: int, button: int) -> bool:
	return Input.is_joy_button_pressed(device, button)


func joy_axis(device: int, axis: int) -> float:
	return Input.get_joy_axis(device, axis)


func connected_joypads() -> Array[int]:
	var pads: Array[int] = Input.get_connected_joypads()
	pads.sort()
	return pads


func joy_name(device: int) -> String:
	return Input.get_joy_name(device)


func joy_info(device: int) -> Dictionary:
	return Input.get_joy_info(device)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	joy_connection_changed.emit(device, connected)
