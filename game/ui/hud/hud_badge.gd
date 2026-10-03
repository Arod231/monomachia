class_name HudBadge
extends Control
## The 奥義 ultimate badge beside the pips, in the demo's three states:
## hidden until the ultimate is ready; then light gold on a pulsing glow;
## once used (while still low), dimmed and struck through.

## The demo's ready colour (.ult.ready).
const READY_COLOR: Color = Color("#ffd27a")
## One glow pulse, in seconds, and the glow's reach and strength at its
## faintest and brightest (the demo's ultglow).
const PULSE: float = 1.0
const GLOW_REACH: float = 5.0
const GLOW_ALPHA_MIN: float = 0.12
const GLOW_ALPHA_MAX: float = 0.3
## A used badge's opacity (the demo's .ult.used).
const USED_ALPHA: float = 0.4
const PADDING: Vector2 = Vector2(9.0, 3.0)

var state: HudState.Badge = HudState.Badge.HIDDEN:
	set(v):
		if v != state:
			state = v
			_refresh()
var _text: Label
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = UiTheme.label("奥義", UiTheme.DISPLAY, 16)
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	custom_minimum_size = _text.get_minimum_size() + PADDING * 2.0
	_refresh()


## Names the badge and its text for side i (for tests and the scene tree).
func name_for_side(i: int) -> void:
	name = "Badge%d" % i
	_text.name = "BadgeText%d" % i


func _process(delta: float) -> void:
	if state == HudState.Badge.READY:
		_time += delta
		queue_redraw()


func _refresh() -> void:
	modulate.a = 0.0 if state == HudState.Badge.HIDDEN else (USED_ALPHA if state == HudState.Badge.USED else 1.0)
	_text.add_theme_color_override("font_color", READY_COLOR if state == HudState.Badge.READY else UiPalette.GOLD_DIM)
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var edge: Color = READY_COLOR if state == HudState.Badge.READY else UiPalette.GOLD_DIM
	if state == HudState.Badge.READY:
		var pulse: float = 0.5 - 0.5 * cos(_time * TAU / PULSE)
		draw_rect(r.grow(GLOW_REACH), Color(READY_COLOR, lerpf(GLOW_ALPHA_MIN, GLOW_ALPHA_MAX, pulse)))
	draw_rect(r, edge, false, 1.0)
	if state == HudState.Badge.USED:
		draw_line(Vector2(PADDING.x * 0.5, size.y * 0.5), Vector2(size.x - PADDING.x * 0.5, size.y * 0.5), edge, 2.0)
