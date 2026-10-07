class_name WeaponMarker
extends VBoxContainer
## The HUD's marker on your dropped weapon (task 24.5): "Your weapon" in
## small spaced capitals with an arrow down at the weapon, MARKER_HEIGHT over
## it, from the disarm on (following it while it flies, as the owner chose
## on Oct 4, 2026) until it is back in hand. Off screen or behind the camera
## it clamps to the screen's edge and points the way with an arrow at its
## side instead. Port of Hud.updateMarker() in src/ui/hud.ts and the demo's
## .marker style; the in-world beam over the weapon is the view's.
##
## place() works out where it goes, with no nodes; show_at() puts it there.
## In Versus (23.7) each player has one, labelled "Player 1's weapon", kept
## to their own half of the split through their own camera (show_in()).

## Side arrows, for at_edge's side.
enum Side { NONE, LEFT, RIGHT }

## How far over the weapon the marker points (m).
const MARKER_HEIGHT: float = 0.6
## The edge margin (px), and the extra margin under the top bar when the
## marker clamps to the top (the demo's 40 and 60).
const PAD: float = 40.0
const TOP_BAR: float = 60.0
## The demo's marker colour.
const COLOR: Color = Color("#ffd29a")
const TEXT_SIZE: int = 13
## The arrows: down 12 wide and 8 tall, sideways 8 wide and 12 tall.
const ARROW: Vector2 = Vector2(12.0, 8.0)

var label: Label
var _down: Arrow
var _left: Arrow
var _right: Arrow
var _row: HBoxContainer


## A small filled triangle pointing down, left or right.
class Arrow:
	extends Control

	var points: int = Side.NONE

	func _init(p_points: int) -> void:
		points = p_points
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = ARROW if points == Side.NONE else Vector2(ARROW.y, ARROW.x)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var s: Vector2 = size
		var tri: PackedVector2Array
		match points:
			Side.LEFT:
				tri = [Vector2(s.x, 0.0), Vector2(s.x, s.y), Vector2(0.0, s.y * 0.5)]
			Side.RIGHT:
				tri = [Vector2(0.0, 0.0), Vector2(0.0, s.y), Vector2(s.x, s.y * 0.5)]
			_:
				tri = [Vector2(0.0, 0.0), Vector2(s.x, 0.0), Vector2(s.x * 0.5, s.y)]
		draw_colored_polygon(tri, COLOR)


func _init() -> void:
	name = "WeaponMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_theme_constant_override("separation", 3)
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)
	_left = Arrow.new(Side.LEFT)
	_left.name = "Left"
	label = UiTheme.label("Your weapon", UiTheme.EYEBROW, TEXT_SIZE)
	label.name = "Label"
	label.add_theme_color_override("font_color", COLOR)
	label.add_theme_color_override("font_outline_color", Color(UiPalette.LACQUER, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right = Arrow.new(Side.RIGHT)
	_right.name = "Right"
	for part: Control in [_left, label, _right]:
		_row.add_child(part)
	_down = Arrow.new(Side.NONE)
	_down.name = "Down"
	add_child(_down)


## Where the marker goes for a point projected to `at` on a screen of
## `screen` size (behind: the point is behind the camera, where a projection
## comes out mirrored): { "pos": the marker's bottom centre, "edge": whether
## it clamped to the edge, "side": the Side its arrow points }. On screen
## (PAD clear of every edge) it stands at the point; otherwise it clamps
## inside the margins (and under the top bar), a point behind first mirrored
## across and dropped to the bottom margin, and points left or right by
## which half it ends on. At an edge its centre also keeps half_width clear
## of the margin, so the whole marker stays on screen (the demo's could hang
## half off it).
static func place(at: Vector2, behind: bool, screen: Vector2, half_width: float = 0.0) -> Dictionary:
	var p: Vector2 = at
	var off: bool = behind or p.x < PAD or p.x > screen.x - PAD or p.y < PAD or p.y > screen.y - PAD
	if not off:
		return {"pos": p, "edge": false, "side": Side.NONE}
	if behind:
		p = Vector2(screen.x - p.x, screen.y - PAD)
	p.x = clampf(p.x, PAD + half_width, screen.x - PAD - half_width)
	p.y = clampf(p.y, PAD + TOP_BAR, screen.y - PAD)
	return {"pos": p, "edge": true, "side": Side.LEFT if p.x < screen.x * 0.5 else Side.RIGHT}


## Puts the marker at place()'s answer for the weapon at `weapon` (its
## position in the world) seen through `camera`, on a screen of `screen`
## size, and shows it.
func show_for(camera: Camera3D, weapon: Vector3, screen: Vector2) -> void:
	show_in(camera, weapon, Rect2(Vector2.ZERO, screen), screen)


## As show_for(), in a region of the screen that `camera` draws into (a
## Versus half, 23.7): the camera's viewport is `viewport_size` pixels, and
## its picture fills `region`. The marker clamps to the region's edges, and
## its side arrow points by the region's halves.
func show_in(camera: Camera3D, weapon: Vector3, region: Rect2, viewport_size: Vector2) -> void:
	var point: Vector3 = weapon + Vector3(0.0, MARKER_HEIGHT, 0.0)
	var at: Vector2 = camera.unproject_position(point) * region.size / viewport_size
	var behind: bool = camera.is_position_behind(point)
	# once to learn which arrow shows, and so the marker's width; then again
	# kept that wide clear of the edge
	show_at(place(at, behind, region.size), region.position)
	if side() != Side.NONE:
		show_at(place(at, behind, region.size, size.x * 0.5), region.position)


## Shows the marker as place() put it: its bottom centre at "pos" (from
## `origin`, a region's corner), the down arrow on screen or the side arrow
## at the edge.
func show_at(where: Dictionary, origin: Vector2 = Vector2.ZERO) -> void:
	var side: int = where["side"]
	_left.visible = side == Side.LEFT
	_right.visible = side == Side.RIGHT
	_down.visible = not bool(where["edge"])
	visible = true
	size = get_combined_minimum_size()
	position = origin + Vector2(where["pos"]) - Vector2(size.x * 0.5, size.y)


## Which way the marker points now (Side.NONE: down at the weapon).
func side() -> int:
	if _left.visible:
		return Side.LEFT
	return Side.RIGHT if _right.visible else Side.NONE


## The point the marker stands on (its bottom centre).
func anchor() -> Vector2:
	return position + Vector2(size.x * 0.5, size.y)
