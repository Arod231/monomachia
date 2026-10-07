class_name HudBadge
extends Control
## The 奥義 ultimate badge beside the pips (milestone-1 task 54, the mood
## board's UI A): a round black lacquer disc with a gold rim and the kanji
## brushed in pale gold, in the demo's three states: hidden until the
## ultimate is ready; then lit, on a pulsing gold glow; once used (while
## still low), dimmed and struck through.

## One glow pulse, in seconds, and the glow's reach and strength at its
## faintest and brightest (the demo's ultglow).
const PULSE: float = 1.0
const GLOW_REACH: float = 6.0
const GLOW_ALPHA_MIN: float = 0.12
const GLOW_ALPHA_MAX: float = 0.32
## A used badge's opacity (the demo's .ult.used).
const USED_ALPHA: float = 0.4
const FONT_SIZE: int = 17
## The disc's room round the kanji.
const PADDING: float = 7.0
## The disc's heart, a warm lacquer catching the light (the mock-up's
## radial-gradient(#2a1a10, #050505)).
const HEART: Color = Color("#2a1a10")

var state: HudState.Badge = HudState.Badge.HIDDEN:
	set(v):
		if v != state:
			state = v
			_refresh()
var _text: Label
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = UiTheme.label("奥義", UiTheme.KANJI, FONT_SIZE)
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_constant_override("shadow_outline_size", 0)
	add_child(_text)
	var side: float = maxf(_text.get_minimum_size().x, _text.get_minimum_size().y) + PADDING * 2.0
	custom_minimum_size = Vector2(side, side)
	_refresh()


## Names the badge and its text for side i (for tests and the scene tree).
func name_for_side(i: int) -> void:
	name = "Badge%d" % i
	_text.name = "BadgeText%d" % i


## The rim's colour: bright gold while ready, dim gold otherwise.
func rim_color() -> Color:
	return UiPalette.GOLD_BRIGHT if state == HudState.Badge.READY else UiPalette.GOLD_DIM


func _process(delta: float) -> void:
	if state == HudState.Badge.READY:
		_time += delta
		queue_redraw()


func _refresh() -> void:
	modulate.a = 0.0 if state == HudState.Badge.HIDDEN else (USED_ALPHA if state == HudState.Badge.USED else 1.0)
	_text.add_theme_color_override("font_color", UiPalette.GOLD_PALE if state == HudState.Badge.READY else UiPalette.GOLD_DIM)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	if state == HudState.Badge.READY:
		var pulse: float = 0.5 - 0.5 * cos(_time * TAU / PULSE)
		draw_circle(c, r + GLOW_REACH, Color(UiPalette.GOLD_BRIGHT, lerpf(GLOW_ALPHA_MIN, GLOW_ALPHA_MAX, pulse)))
	draw_circle(c, r, UiPalette.LACQUER)
	draw_circle(c, r * 0.65, HEART.lerp(UiPalette.LACQUER, 0.3))
	draw_circle(c, r * 0.35, HEART)
	draw_arc(c, r, 0.0, TAU, 48, rim_color(), 1.0, true)
	if state == HudState.Badge.USED:
		draw_line(Vector2(c.x - r * 0.75, c.y), Vector2(c.x + r * 0.75, c.y), rim_color(), 2.0)
