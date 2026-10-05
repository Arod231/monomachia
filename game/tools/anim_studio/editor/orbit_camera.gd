class_name OrbitCamera
extends Camera3D
## The Studio editor's camera (milestone-1 task 25): it circles a point on
## the fighter. Right-drag orbits, middle-drag pans, the wheel zooms; the
## presets look from the front, the side, the top and the match's angle
## (behind the fighter's right shoulder, For Honor's framing). The fighter
## faces +Z: a yaw of 0 looks at its front.

## Yaw and pitch (degrees) and distance (m) of each preset.
const PRESETS: Dictionary[StringName, Vector3] = {
	&"front": Vector3(0.0, 6.0, 4.0),
	&"side": Vector3(-90.0, 6.0, 4.0),
	&"top": Vector3(0.0, 80.0, 4.5),
	&"match": Vector3(196.0, 14.0, 3.6),
}
const DEFAULT_TARGET: Vector3 = Vector3(0.0, 0.95, 0.0)
## Degrees of orbit per pixel dragged, metres of pan per pixel per metre of
## distance, and the zoom per wheel step.
const ORBIT_SPEED: float = 0.4
const PAN_SPEED: float = 0.0015
const ZOOM_STEP: float = 1.1
const MIN_DISTANCE: float = 0.8
const MAX_DISTANCE: float = 20.0

var target: Vector3 = DEFAULT_TARGET
var yaw: float = 30.0
var pitch: float = 10.0
var distance: float = 4.0


func _ready() -> void:
	fov = 40.0
	_apply()


## Looks from preset `name` (PRESETS) at the fighter.
func use_preset(name: StringName) -> void:
	var p: Vector3 = PRESETS[name]
	yaw = p.x
	pitch = p.y
	distance = p.z
	target = DEFAULT_TARGET
	_apply()


## Turns round the target by `dx`, `dy` pixels of drag.
func orbit(dx: float, dy: float) -> void:
	yaw = fposmod(yaw - dx * ORBIT_SPEED, 360.0)
	pitch = clampf(pitch + dy * ORBIT_SPEED, -80.0, 85.0)
	_apply()


## Slides the target across the view by `dx`, `dy` pixels of drag.
func pan(dx: float, dy: float) -> void:
	var b: Basis = global_transform.basis if is_inside_tree() else transform.basis
	target += (-b.x * dx + b.y * dy) * PAN_SPEED * distance
	_apply()


## Moves in (`steps` > 0) or out by wheel steps.
func zoom(steps: float) -> void:
	distance = clampf(distance / pow(ZOOM_STEP, steps), MIN_DISTANCE, MAX_DISTANCE)
	_apply()


## Acts on a mouse event over the viewport; true when it used it.
func handle(event: InputEvent) -> bool:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.0)
			return true
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(-1.0)
			return true
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			orbit(motion.relative.x, motion.relative.y)
			return true
		if motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			pan(motion.relative.x, motion.relative.y)
			return true
	return false


func _apply() -> void:
	var y: float = deg_to_rad(yaw)
	var p: float = deg_to_rad(pitch)
	position = target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * distance
	var up: Vector3 = Vector3.UP if absf(pitch) < 89.0 else Vector3.FORWARD
	if position.distance_to(target) > 0.001:
		transform = transform.looking_at(target, up)
