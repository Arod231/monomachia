class_name HudPips
extends Control
## The round pips: a row of gold-edged diamonds, the leftmost first on both
## sides, one filled and glowing for each round won (the demo's .pip: 11 px
## boxes turned 45°, 6 px apart).

const COUNT: int = SimConst.ROUNDS_TO_WIN
const SIDE: float = 11.0
const GAP: float = 6.0
## Half a diamond's width.
const HALF: float = SIDE * 0.70710678
const GLOW_SCALE: float = 1.6
const GLOW_ALPHA: float = 0.25

var lit: int = 0:
	set(v):
		if v != lit:
			lit = v
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2((COUNT - 1) * (SIDE + GAP) + HALF * 2.0 * GLOW_SCALE, HALF * 2.0 * GLOW_SCALE)


func _draw() -> void:
	for k: int in COUNT:
		var c: Vector2 = Vector2(HALF * GLOW_SCALE + k * (SIDE + GAP), size.y * 0.5)
		var diamond: PackedVector2Array = [c + Vector2(0, -HALF), c + Vector2(HALF, 0), c + Vector2(0, HALF), c + Vector2(-HALF, 0)]
		if k < lit:
			var glow: PackedVector2Array = []
			for p: Vector2 in diamond:
				glow.append(c + (p - c) * GLOW_SCALE)
			draw_colored_polygon(glow, Color(UiPalette.GOLD, GLOW_ALPHA))
			draw_colored_polygon(diamond, UiPalette.GOLD)
		diamond.append(diamond[0])
		draw_polyline(diamond, UiPalette.GOLD, 1.0)
