class_name HudPips
extends Control
## The round pips (milestone-1 task 54, the mood board's UI A): a row of
## black lacquer discs with a gold rim, the leftmost first on both sides,
## one lit in the side's lacquer, with a soft glow, for each round won.
## MatchHud gives each side its colours.

const COUNT: int = SimConst.ROUNDS_TO_WIN
const RADIUS: float = 7.0
const GAP: float = 6.0
const RIM: Color = UiPalette.GOLD
const GLOW_SCALE: float = 1.6
const GLOW_ALPHA: float = 0.25

## The side's lacquer: a lit disc shades from color at its heart to deep at
## its rim.
var color: Color = UiPalette.CRIMSON:
	set(v):
		color = v
		queue_redraw()
var deep: Color = UiPalette.CRIMSON_DEEP:
	set(v):
		deep = v
		queue_redraw()
var lit: int = 0:
	set(v):
		if v != lit:
			lit = v
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reach: float = RADIUS * GLOW_SCALE
	custom_minimum_size = Vector2((COUNT - 1) * (RADIUS * 2.0 + GAP) + reach * 2.0, reach * 2.0)


## The discs' centres, leftmost first.
func centres() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for k: int in COUNT:
		out.append(Vector2(RADIUS * GLOW_SCALE + k * (RADIUS * 2.0 + GAP), size.y * 0.5))
	return out


## Disc k's colour at its heart: the side's lacquer when lit, else black.
func fill(k: int) -> Color:
	return color if k < lit else UiPalette.LACQUER


func _draw() -> void:
	var c: PackedVector2Array = centres()
	for k: int in COUNT:
		if k < lit:
			draw_circle(c[k], RADIUS * GLOW_SCALE, Color(color, GLOW_ALPHA))
			draw_circle(c[k], RADIUS, deep)
			draw_circle(c[k], RADIUS * 0.6, fill(k))
		else:
			draw_circle(c[k], RADIUS, fill(k))
		draw_arc(c[k], RADIUS, 0.0, TAU, 32, RIM, 1.0, true)
