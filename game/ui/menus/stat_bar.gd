class_name StatBar
extends Control
## One stat bar on a weapon card (the demo's .stat i): a thin track in the
## panel's line colour with a gold fill to `value` (0-1).

const HEIGHT: float = 6.0

var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(70.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var track: Rect2 = Rect2(Vector2(0.0, (size.y - HEIGHT) * 0.5), Vector2(size.x, HEIGHT))
	draw_rect(track, UiPalette.LINE)
	draw_rect(Rect2(track.position, Vector2(size.x * value, HEIGHT)), UiPalette.GOLD)
