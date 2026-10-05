class_name StudioTimeline
extends Control
## The Studio editor's timeline (milestone-1 task 25): one timeline over the
## clip's source frames, from top to bottom:
## - the source ruler, a tick a frame and a number every ten;
## - the markers, each a labelled line (the move's wind-up, active start and
##   end, settle, dodge-cancel window and branch points; a clip's own);
## - the rules ruler (a move's only), starting at its wind-up, two rules
##   frames to a source frame: the generated startup, active and recovery as
##   bars, and the startup's band as the span where the first active frame
##   should fall;
## - each foot's contacts (planted spans), shown, never edited;
## - the playhead across all of them.
## Click or drag anywhere to scrub (`seeked`). With `markers_editable`, a
## marker dragged in the markers row moves (`marker_moved` on release),
## snapped to whole source frames, or halves with Alt held (milestone-1 task
## 26). The editor owns the keys.

## The playhead was put at source frame `frame` by a click or a drag.
signal seeked(frame: float)
## Marker `name` was dragged to source frame `frame`.
signal marker_moved(name: String, frame: float)

const PAD: float = 14.0
const RULER_H: float = 22.0
const MARKERS_H: float = 40.0
const RULES_H: float = 30.0
const FEET_H: float = 26.0
const BAR_COLORS: Dictionary[String, Color] = {
	"startup": Color(0.42, 0.5, 0.66),
	"active": Color(0.82, 0.32, 0.3),
	"recovery": Color(0.78, 0.6, 0.28),
}
const BAND_COLOR: Color = Color(0.35, 0.78, 0.45, 0.35)
const BAND_OUT_COLOR: Color = Color(0.9, 0.35, 0.3, 0.35)
const MARKER_COLOR: Color = Color(0.92, 0.88, 0.62)
const BRANCH_COLOR: Color = Color(0.55, 0.8, 0.95)
const FOOT_COLOR: Color = Color(0.5, 0.62, 0.5)
const PLAYHEAD_COLOR: Color = Color(1.0, 1.0, 1.0)
const TEXT_COLOR: Color = Color(0.85, 0.86, 0.9)
const DIM_COLOR: Color = Color(0.5, 0.52, 0.58)

## The clip's length (source frames).
var length: float = 0.0
## The playhead (source frames).
var frame: float = 0.0
## Marker name -> source frame; a branch point is "branch <move>".
var markers: Dictionary = {}
## "left"/"right" -> [[plant, lift], ...] in source frames.
var feet: Dictionary = {}
## The move's frames and bands, or null for a clip or state.
var view: FramesAndBands = null
## Whether markers can be dragged.
var markers_editable: bool = false
## How near (px) a press must be to a marker to take it.
const GRAB: float = 6.0

var _dragging: bool = false
## The marker being dragged ("" for none) and where it is so far.
var _drag_marker: String = ""
var _drag_frame: float = 0.0


func _ready() -> void:
	custom_minimum_size.y = _height()
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP


## Shows a clip of `p_length` source frames with its markers, feet and (for
## a move) its frames and bands; the playhead goes back to the start.
func set_data(p_length: float, p_markers: Dictionary, p_feet: Dictionary, p_view: FramesAndBands) -> void:
	length = p_length
	markers = p_markers
	feet = p_feet
	view = p_view
	frame = 0.0
	custom_minimum_size.y = _height()
	queue_redraw()


## Moves the playhead without saying so (the editor's own moves).
func set_frame(f: float) -> void:
	frame = f
	queue_redraw()


## The x of source frame `f`.
func x_of(f: float) -> float:
	if length <= 0.0:
		return PAD
	return PAD + f / length * maxf(size.x - 2.0 * PAD, 1.0)


## The source frame at x `x`, within the clip.
func frame_at(x: float) -> float:
	if length <= 0.0:
		return 0.0
	return clampf((x - PAD) / maxf(size.x - 2.0 * PAD, 1.0) * length, 0.0, length)


## A move's markers (MoveClips.Entry.markers) as the timeline's flat list:
## each named marker, and each branch point as "branch <move>".
static func flat_markers(m: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for name: Variant in m:
		if str(name) == "branch":
			for follow: Variant in m[name]:
				out["branch %s" % follow] = float(m[name][follow])
		else:
			out[str(name)] = float(m[name])
	return out


func _height() -> float:
	return RULER_H + MARKERS_H + (RULES_H if view != null else 0.0) + FEET_H + 8.0


## The marker within GRAB px of x `x` (the nearest), or "".
func marker_at(x: float) -> String:
	var best: String = ""
	var best_d: float = GRAB
	for name: Variant in markers:
		var d: float = absf(x_of(markers[name]) - x)
		if d <= best_d:
			best = str(name)
			best_d = d
	return best


## Source frame `f` snapped as a marker drag snaps it: to whole frames, or to
## halves with `halves`.
static func snap(f: float, halves: bool) -> float:
	return roundf(f * 2.0) / 2.0 if halves else roundf(f)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and markers_editable and button.position.y >= RULER_H and button.position.y < RULER_H + MARKERS_H:
			_drag_marker = marker_at(button.position.x)
			if _drag_marker != "":
				_drag_frame = markers[_drag_marker]
				accept_event()
				return
		if not button.pressed and _drag_marker != "":
			var name: String = _drag_marker
			_drag_marker = ""
			queue_redraw()
			marker_moved.emit(name, _drag_frame)
			accept_event()
			return
		_dragging = button.pressed
		if button.pressed:
			_scrub(button.position.x)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _drag_marker != "":
		_drag_frame = snap(frame_at(motion.position.x), motion.alt_pressed)
		queue_redraw()
		accept_event()
		return
	if motion != null and _dragging:
		_scrub(motion.position.x)
		accept_event()


func _scrub(x: float) -> void:
	frame = frame_at(x)
	queue_redraw()
	seeked.emit(frame)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var fs: int = 11
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.14, 0.17))
	var y: float = 0.0
	# the source ruler
	if length > 0.0:
		var every: int = 1 if length <= 120.0 else 5
		for f: int in range(0, int(floorf(length)) + 1, every):
			var x: float = x_of(f)
			var tall: bool = f % 10 == 0
			draw_line(Vector2(x, y + RULER_H - (10.0 if tall else 4.0)), Vector2(x, y + RULER_H), DIM_COLOR if not tall else TEXT_COLOR)
			if tall:
				draw_string(font, Vector2(x + 2.0, y + 11.0), str(f), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT_COLOR)
	y += RULER_H
	# the markers, labels staggered so neighbours don't overlap
	var names: Array = markers.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool: return markers[a] < markers[b])
	var row: int = 0
	for name: Variant in names:
		var x: float = x_of(markers[name])
		var color: Color = BRANCH_COLOR if str(name).begins_with("branch") else MARKER_COLOR
		draw_line(Vector2(x, y), Vector2(x, y + MARKERS_H), color, 1.5)
		draw_string(font, Vector2(x + 3.0, y + 12.0 + 13.0 * row), str(name), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, color)
		row = (row + 1) % 2
	if _drag_marker != "":
		var dx: float = x_of(_drag_frame)
		draw_line(Vector2(dx, y), Vector2(dx, y + MARKERS_H), PLAYHEAD_COLOR, 2.0)
		draw_string(font, Vector2(dx + 3.0, y + MARKERS_H - 3.0), "%s %s" % [_drag_marker, _drag_frame], HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, PLAYHEAD_COLOR)
	y += MARKERS_H
	# the rules ruler: the bars and the startup's band
	if view != null:
		# the startup's band behind the bars: where the first active frame
		# should fall
		if not view.startup_band.is_empty():
			var lo: float = x_of(view.to_source(view.startup_band[0]))
			var hi: float = x_of(view.to_source(view.startup_band[1]))
			var startup_ok: bool = view.fields.is_empty() or view.fields[0].ok
			var band: Rect2 = Rect2(lo, y + 1.0, maxf(hi - lo, 2.0), RULES_H - 2.0)
			draw_rect(band, BAND_COLOR if startup_ok else BAND_OUT_COLOR)
			draw_rect(band, (BAND_COLOR if startup_ok else BAND_OUT_COLOR).lightened(0.4), false, 1.0)
			draw_string(font, Vector2(lo + 2.0, y + 9.0), "startup band", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, TEXT_COLOR)
		for bar: FramesAndBands.Bar in view.bars:
			var x0: float = x_of(view.to_source(bar.from))
			var x1: float = x_of(view.to_source(bar.to))
			draw_rect(Rect2(x0, y + 12.0, maxf(x1 - x0, 1.0), RULES_H - 18.0), BAR_COLORS.get(bar.name, DIM_COLOR))
		var total: int = view.bars[-1].to if not view.bars.is_empty() else 0
		for r: int in range(0, total + 1, 10):
			var x: float = x_of(view.to_source(r))
			draw_line(Vector2(x, y + RULES_H - 6.0), Vector2(x, y + RULES_H), DIM_COLOR)
		y += RULES_H
	# the feet
	for i: int in ClipManifest.FEET.size():
		var side: String = ClipManifest.FEET[i]
		var row_y: float = y + 2.0 + i * (FEET_H * 0.5)
		draw_string(font, Vector2(2.0, row_y + 9.0), side.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, DIM_COLOR)
		for span: Variant in feet.get(side, []):
			var x0: float = x_of(span[0])
			var x1: float = x_of(span[1])
			draw_rect(Rect2(x0, row_y, maxf(x1 - x0, 2.0), FEET_H * 0.5 - 3.0), FOOT_COLOR)
	# the playhead
	var px: float = x_of(frame)
	draw_line(Vector2(px, 0.0), Vector2(px, size.y), PLAYHEAD_COLOR, 2.0)
