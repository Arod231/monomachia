class_name ClipTiming
extends RefCounted
## A clip (or a chain of clips) retimed onto rules frames by its markers
## (ClipManifest.MARKERS, in source frames) at a speed between 1.0 and 2.0
## times its 30 fps: the wind-up start on frame 0, the contact start on the
## last startup frame (the first active frame sweeps from it), the contact
## end on the last active frame and the settle on the move's last frame, the
## clip running at an even speed between them. The bake (SwingBake) samples
## the clip on these frames, and its startup, active and recovery are the
## move's frame data; the clip director plays the clip on the same frames.
##
## A chargeable move's clip may also have a hold marker (task 11): the pose
## the rules hold while it charges, on the charge-check frame (HOLD_FRAME).
## The wind-up runs from frame 0 to it at whatever even speed lands it there
## (from 1.0 to 2.0 too), and the speed given times the rest from it.

const RULES_FPS: float = 60.0
const MIN_SPEED: float = 1.0
const MAX_SPEED: float = 2.0
## The rules frame a hold marker lands on: where a charge holds the attack.
const HOLD_FRAME: int = Fighter.CHARGE_CHECK_FRAME

var speed: float = 1.0
var startup: int = 0
var active: int = 0
var recovery: int = 0
## The rules frames of the four markers: 0, startup, startup + active and
## the last frame.
var frames: PackedInt32Array = PackedInt32Array()
## The four markers, in source frames (ClipManifest.MARKERS' order).
var marks: PackedFloat64Array = PackedFloat64Array()
## The hold marker (source frames), or NAN for none.
var hold: float = NAN


## The timing of a clip with `markers` (source frames by name) at `speed`:
## null, with an error per mistake, when a marker is missing or out of order
## or the speed is outside 1.0-2.0. Each stretch between markers takes at
## least one rules frame.
static func make(markers: Dictionary, p_speed: float, errors: Array[String]) -> ClipTiming:
	var before: int = errors.size()
	if is_nan(p_speed) or p_speed < MIN_SPEED or p_speed > MAX_SPEED:
		errors.append("speed %s is outside %.1f-%.1f" % [p_speed, MIN_SPEED, MAX_SPEED])
	var m: PackedFloat64Array = PackedFloat64Array()
	for name: String in ClipManifest.MARKERS:
		var v: Variant = markers.get(name)
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			errors.append("no %s marker" % name)
			continue
		if not m.is_empty() and float(v) <= m[-1]:
			errors.append("the %s marker (%s) must come after the %s marker (%s)"
					% [name, frame_text(float(v)), ClipManifest.MARKERS[m.size() - 1], frame_text(m[-1])])
		m.append(float(v))
	var hold_at: float = NAN
	if markers.has("hold") and errors.size() == before:
		var h: Variant = markers["hold"]
		if typeof(h) != TYPE_FLOAT and typeof(h) != TYPE_INT or float(h) <= m[0] or float(h) >= m[1]:
			errors.append("the hold marker must come between the windup and contact markers")
		else:
			hold_at = float(h)
			var before_speed: float = (hold_at - m[0]) * RULES_FPS / float(ClipManifest.SOURCE_FPS) / float(HOLD_FRAME)
			if before_speed < MIN_SPEED - 1e-6 or before_speed > MAX_SPEED + 1e-6:
				errors.append("the wind-up to the hold plays at %.2f, outside %.1f-%.1f" % [before_speed, MIN_SPEED, MAX_SPEED])
	if errors.size() != before:
		return null
	var t: ClipTiming = ClipTiming.new()
	t.speed = p_speed
	t.marks = m
	t.hold = hold_at
	var per: float = RULES_FPS / float(ClipManifest.SOURCE_FPS) / p_speed
	# timed from the wind-up start on frame 0, or from the hold on its frame
	var origin_frame: int = 0 if is_nan(hold_at) else HOLD_FRAME
	var origin: float = m[0] if is_nan(hold_at) else hold_at
	var f: PackedInt32Array = PackedInt32Array([0])
	for i: int in range(1, 4):
		f.append(maxi(maxi(f[-1], origin_frame) + 1, origin_frame + roundi((m[i] - origin) * per)))
	t.frames = f
	t.startup = f[1]
	t.active = f[2] - f[1]
	t.recovery = f[3] - f[2]
	return t


## A source frame as it reads: whole frames without a decimal point.
static func frame_text(x: float) -> String:
	return str(int(x)) if x == floorf(x) else str(x)


func total() -> int:
	return startup + active + recovery


## The markers as a swing records them: the four, then the hold if any.
func all_marks() -> Array:
	var out: Array = Array(marks)
	if not is_nan(hold):
		out.append(hold)
	return out


## The clip's time (seconds from its start) at rules frame `f`, which may
## fall between frames: even between the markers' frames, the wind-up start
## before frame 0 and the settle after the last.
func clip_time(f: float) -> float:
	var at: PackedFloat64Array = PackedFloat64Array([float(frames[0])])
	var src: PackedFloat64Array = PackedFloat64Array([marks[0]])
	if not is_nan(hold):
		at.append(float(HOLD_FRAME))
		src.append(hold)
	for i: int in range(1, 4):
		at.append(float(frames[i]))
		src.append(marks[i])
	var source: float = src[0]
	if f >= at[-1]:
		source = src[-1]
	elif f > 0.0:
		var j: int = 0
		while f > at[j + 1]:
			j += 1
		var s: float = (f - at[j]) / (at[j + 1] - at[j])
		source = lerpf(src[j], src[j + 1], s)
	return source / float(ClipManifest.SOURCE_FPS)
