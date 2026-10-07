class_name HudBar
extends Control
## A meter for the HUD: a lacquer channel, a lag band (the white "damage
## just taken" band under HP) and the fill, in a gold edge (milestone-1 task
## 54: the mood board's lacquered channels). Fills from the left, or
## from the right when reversed (the right-hand fighter's bars). As the
## demo's HP bar, the fill can run from fill_color at the top to fill_bottom
## at the foot, and the bar's inner end can be cut at a slant, which the edge
## leaves open (the demo clips its border there).

@export var value: float = 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var lag: float = 0.0:
	set(v):
		lag = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var reversed: bool = false
@export var fill_color: Color = UiPalette.CRIMSON
## The fill's colour at the foot (the same as fill_color for a flat fill).
@export var fill_bottom: Color = UiPalette.CRIMSON
@export var lag_color: Color = Color(Color("#f3ead8"), 0.85)
@export var back_color: Color = Color(UiPalette.LACQUER, 0.85)
@export var edge_color: Color = UiPalette.GOLD
## How far the foot of the inner end is cut back, in pixels (0: square).
@export var slant: float = 0.0
## Multiplies the fill's colour (the low-HP pulse brightens it).
var brightness: float = 1.0:
	set(v):
		brightness = v
		queue_redraw()


## One colour top to foot.
func set_flat(color: Color) -> void:
	set_fill(color, color)


## The fill's colour at the top and at the foot.
func set_fill(top: Color, bottom: Color) -> void:
	fill_color = top
	fill_bottom = bottom
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(part(1.0), back_color)
	if lag > value and lag * size.x >= 0.5:
		draw_colored_polygon(part(lag), lag_color)
	if value * size.x >= 0.5:
		var pts: PackedVector2Array = part(value)
		var colors: PackedColorArray = []
		for p: Vector2 in pts:
			var c: Color = fill_color.lerp(fill_bottom, p.y / maxf(size.y, 1.0))
			colors.append(Color(c.r * brightness, c.g * brightness, c.b * brightness, c.a))
		draw_polygon(pts, colors)
	draw_polyline(_edge(), edge_color, 1.0)


## The bar's shape from its outer end to frac of the way along, in the
## control's pixels: a box whose inner end follows the slant.
func part(frac: float) -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y
	var x: float = w * frac
	var pts: PackedVector2Array = [Vector2(0.0, 0.0), Vector2(x, 0.0)]
	if slant > 0.0 and x > w - slant:
		pts.append(Vector2(x, h * (w - x) / slant))
		pts.append(Vector2(w - slant, h))
	else:
		pts.append(Vector2(x, h))
	pts.append(Vector2(0.0, h))
	return _mirrored(pts)


## The edge: all round a square bar; open along a slant.
func _edge() -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y
	if slant > 0.0:
		return _mirrored([Vector2(w - slant, h), Vector2(0.0, h), Vector2(0.0, 0.0), Vector2(w, 0.0)])
	return _mirrored([Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h), Vector2(0.0, 0.0)])


func _mirrored(pts: PackedVector2Array) -> PackedVector2Array:
	if reversed:
		for i: int in pts.size():
			pts[i].x = size.x - pts[i].x
		pts.reverse()
	return pts
