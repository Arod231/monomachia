class_name DeviceState
extends RefCounted
## What the input layer reads from the machine: which keys, mouse buttons and
## controller buttons are held, where the controller axes sit, and which
## controllers are connected. An interface: GodotDeviceState reads Godot's
## Input singleton, and FakeDeviceState is set by hand in tests.

## A controller was plugged in (connected = true) or unplugged.
@warning_ignore("unused_signal")
signal joy_connection_changed(device: int, connected: bool)


## A key, by physical keycode (its position on a US QWERTY keyboard).
## location: a KeyLocation; LEFT or RIGHT asks for one key of a pair (Shift,
## Ctrl, Alt, Meta), UNSPECIFIED for either.
func is_key_pressed(_physical_keycode: int, _location: int = KEY_LOCATION_UNSPECIFIED) -> bool:
	return false


## Sees every input event after Godot's Input has (see InputFeed). A state
## that tracks more than Input does, such as which Shift key is down, updates
## itself here.
func note_event(_event: InputEvent) -> void:
	pass


## Forgets every held key, as when the window loses focus (Godot's Input
## releases its own keys then, but not what note_event() tracked).
func release_keys() -> void:
	pass


## A MouseButton (1 left, 2 right, 3 middle, 8 and 9 the side buttons).
func is_mouse_pressed(_button: int) -> bool:
	return false


## A JoyButton on the controller with this device id.
func joy_button_pressed(_device: int, _button: int) -> bool:
	return false


## A JoyAxis value from -1 to 1 (triggers 0 to 1), with no dead zone.
func joy_axis(_device: int, _axis: int) -> float:
	return 0.0


## Device ids of the connected controllers, lowest first.
func connected_joypads() -> Array[int]:
	return []


## The controller's name, for example "PS5 Controller".
func joy_name(_device: int) -> String:
	return ""


## Input.get_joy_info(): raw_name, vendor_id, product_id and so on.
func joy_info(_device: int) -> Dictionary:
	return {}


## Whether Godot knows the controller's button layout (Input.is_joy_known):
## an unknown one may need its buttons set by hand on the Controls screen.
func joy_known(_device: int) -> bool:
	return true
