@tool
class_name LacquerPanel
extends StyleBox
## A panel in black urushi lacquer (the mood board's UI A, milestone-1 task
## 53): a fill shading from the warm lacquer at the top left to the black at
## the bottom right, a gold hairline round the edge, a fainter second
## hairline inset inside it, a soft shadow under it, and, when flourish is
## on, a small gold maki-e flourish in each corner: three autumn grasses
## fanning out from the corner inside the inner hairline. The theme's
## panels use it (UiTheme.build()).

@export var fill_top: Color = UiPalette.LACQUER_WARM
@export var fill_bottom: Color = UiPalette.LACQUER
@export var edge_color: Color = UiPalette.GOLD
@export var inner_color: Color = Color(UiPalette.GOLD, 0.4)
## How far inside the edge the inner hairline runs, in pixels.
@export var inner_inset: float = 6.0
@export var flourish: bool = true
@export var flourish_color: Color = UiPalette.GOLD
## The flourish's reach along each edge from the inner hairline's corner.
@export var flourish_size: float = 34.0
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.6)
@export var shadow_size: float = 30.0
@export var shadow_offset: Vector2 = Vector2(0.0, 20.0)

## The shadow's steps, faintest outermost.
const SHADOW_STEPS: int = 6
## The grasses, in a corner's frame (x along the top edge, y down the side,
## both inward, as shares of flourish_size): each from its base to its tip,
## bowing toward its control point, its width at the base in pixels.
const GRASSES: Array[Dictionary] = [
	{"base": Vector2(0.0, 0.0), "control": Vector2(0.55, 0.05), "tip": Vector2(1.0, 0.22), "width": 2.4},
	{"base": Vector2(0.0, 0.0), "control": Vector2(0.38, 0.30), "tip": Vector2(0.62, 0.62), "width": 2.0},
	{"base": Vector2(0.0, 0.0), "control": Vector2(0.05, 0.55), "tip": Vector2(0.22, 1.0), "width": 2.4},
]
## Points along each grass.
const GRASS_STEPS: int = 10
## How far inside the inner hairline the grasses start, so their bases
## clear it.
const GRASS_CLEAR: float = 3.0


func _get_draw_rect(rect: Rect2) -> Rect2:
	if shadow_size <= 0.0 or shadow_color.a <= 0.0:
		return rect
	return rect.merge(Rect2(rect.position + shadow_offset, rect.size).grow(shadow_size))


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if shadow_size > 0.0 and shadow_color.a > 0.0:
		for k: int in SHADOW_STEPS:
			var grow: float = shadow_size * float(SHADOW_STEPS - k) / SHADOW_STEPS
			var c: Color = Color(shadow_color, shadow_color.a / SHADOW_STEPS)
			RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(rect.position + shadow_offset, rect.size).grow(grow), c)
	var corners: PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var shades: PackedColorArray = [fill_top, fill_top.lerp(fill_bottom, 0.5), fill_bottom, fill_top.lerp(fill_bottom, 0.5)]
	RenderingServer.canvas_item_add_polygon(to_canvas_item, corners, shades)
	_hairline(to_canvas_item, rect, edge_color)
	if inner_inset > 0.0 and inner_color.a > 0.0:
		_hairline(to_canvas_item, rect.grow(-inner_inset), inner_color)
	if flourish:
		for grass: PackedVector2Array in flourish_strokes(rect):
			RenderingServer.canvas_item_add_polygon(to_canvas_item, grass, [flourish_color])


func _hairline(item: RID, r: Rect2, color: Color) -> void:
	var pts: PackedVector2Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	RenderingServer.canvas_item_add_polyline(item, pts, [color], 1.0)


## The flourish's grasses in the panel's rect: one polygon per grass, three
## in each corner, mirrored so every corner's grasses fan inward from the
## inner hairline's corner.
func flourish_strokes(rect: Rect2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var inner: Rect2 = rect.grow(-inner_inset - GRASS_CLEAR)
	var origins: Array[Vector2] = [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	var signs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for k: int in 4:
		for grass: Dictionary in GRASSES:
			var poly: PackedVector2Array = grass_polygon(grass)
			for i: int in poly.size():
				poly[i] = origins[k] + poly[i] * signs[k]
			out.append(poly)
	return out


## One grass in a corner's frame, in pixels: a quadratic curve from its base
## to its tip, tapering from its width to a point.
func grass_polygon(grass: Dictionary) -> PackedVector2Array:
	var a: Vector2 = (grass["base"] as Vector2) * flourish_size
	var c: Vector2 = (grass["control"] as Vector2) * flourish_size
	var b: Vector2 = (grass["tip"] as Vector2) * flourish_size
	var width: float = grass["width"]
	var left: PackedVector2Array = []
	var right: PackedVector2Array = []
	for i: int in GRASS_STEPS + 1:
		var t: float = float(i) / GRASS_STEPS
		var p: Vector2 = a.lerp(c, t).lerp(c.lerp(b, t), t)
		var d: Vector2 = ((c - a) * (1.0 - t) + (b - c) * t).normalized()
		var n: Vector2 = Vector2(-d.y, d.x) * width * 0.5 * (1.0 - t)
		left.append(p + n)
		if i < GRASS_STEPS:
			right.append(p - n)
	right.reverse()
	return left + right
