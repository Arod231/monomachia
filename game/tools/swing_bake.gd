class_name SwingBake
extends RefCounted
## The bake (authored-animation task 6): a clip, or a chain of clips played
## one after another, into a move's frame data and its baked swing. It is a
## pure function of what it is given: a sampled clip (a Callable giving the
## parts' poses at a clip time, in the fighter's own frame, and the clip's
## length; ClipPoser poses the Hunter for it), the clip's markers in source
## frames (ClipManifest.MARKERS) and a speed between 1.0 and 2.0 times the
## clip's 30 fps. It gives back:
## - the clip retimed onto rules frames (ClipTiming: the markers on the
##   move's frames);
## - each part's pose (grip, blade and edge of a striking hand or foot, the
##   coil and pelvis shift of the body) at every rules frame, from 0 to the
##   move's last: a baked swing (SwingFile reads it as baked tracks);
## - the move's startup, active and recovery frames.
##
## Then (task 7):
## - correct_reach(): where the clip's arm stops short of the reach rule,
##   the striking grips are pushed forward (at most MAX_REACH), easing in over
##   the wind-up and out over the recovery (Swing.reach_weight()); the push is
##   written with the swing, and the view plays the same push, moving the
##   body above the hips (FighterView);
## - drift(): how far the Rogue's HumanF clip strays from the path in the
##   active frames; past ROGUE_DRIFT she plays the Hunter's HumanM clip.
##
## file_text() writes a weapon's swing file with a stable key order and
## fixed decimals, so the same bake writes the same bytes. The bake command
## (tools/bake_swings.gd) runs it for the moves the move-clip table names.

## The speeds pick_speed() tries: ClipTiming.MIN_SPEED to MAX_SPEED in these
## steps.
const SPEED_STEP: float = 0.05
## Decimal places written for metres and directions, and for degrees.
const PLACES: int = 4
const DEGREE_PLACES: int = 2
## The order a key's (or a guard pose's) fields are written in.
const FIELD_ORDER: Array[String] = ["frame", "grip", "blade", "edge", "pole", "torso", "pelvis", "pelvis_shift", "ease"]
## A swing's fields after its tracks, in the order they are written.
const EXTRA_FIELDS: Array[String] = ["clips", "speed", "marks", "fallback", "sheathed", "loop", "reach", "rogue_humanm"]
## The longest reach correction (m): a move that needs more gets another
## clip or a lunge in the rules.
const MAX_REACH: float = SwingFile.MAX_REACH
## The way the reach correction pushes the grips, in the fighter's frame.
const REACH_DIRECTION: Array[float] = [0.0, 0.0, 1.0]
## The blade a light of the string puts into a defender at its weapon's
## duelling distance (m): the rule's 15-20 cm, the correction aiming at the
## middle (test_duel_reach.gd).
const LIGHT_MIN_INSIDE: float = 0.15
const LIGHT_AIM: float = 0.175
const LIGHT_MAX_INSIDE: float = 0.20
## Every other move must touch from its kind's distance (test_move_reach.gd):
## a correction aims this far in.
const TOUCH_AIM: float = 0.05
## How far (m) the Rogue's HumanF clip may stray from the path at an active
## frame before she plays HumanM for the move.
const ROGUE_DRIFT: float = 0.05
## The reach table's test distances (tests/sim/reach_table.gd).
const ReachTable := preload("res://tests/sim/reach_table.gd")


## What a bake gives back.
class Result:
	var timing: ClipTiming
	## The clip's time (s) at each rules frame, 0 to timing.total().
	var times: PackedFloat64Array = PackedFloat64Array()
	## Each part's pose at each rules frame (Array[Swing.Sample]), by part,
	## in Swing.PARTS' order.
	var tracks: Dictionary[StringName, Array] = {}
	## The reach correction in the striking tracks' grips (correct_reach()).
	var reach_offset: V3 = V3.make()
	## The Rogue plays HumanM for this move (drift()).
	var rogue_humanm: bool = false
	## What it was baked from, written with the swing for the view
	## (Swing.clips): set by the bake command.
	var clips: Array[StringName] = []
	var fallback: StringName = &""
	## The attack frames the blade is in the saya (sheathed_frames()), first
	## and last; empty for none.
	var sheathed: PackedInt32Array = PackedInt32Array()
	## The loop a held charge plays (Swing.loop); empty for none.
	var loop: StringName = &""

	## The swing as a swing file holds it: {"tracks": {part: {"baked": true,
	## "keys": [...]}}, "reach": [...], "rogue_humanm": true}, rounded to the
	## decimals written; no reach without a correction, no rogue_humanm when
	## she plays HumanF.
	func record() -> Dictionary:
		var out: Dictionary = {}
		for part: StringName in tracks:
			var keys: Array = []
			var samples: Array = tracks[part]
			for f: int in samples.size():
				var key: Dictionary = {"frame": f}
				key.merge(SwingBake.pose_record(part, samples[f]))
				keys.append(key)
			out[String(part)] = {"baked": true, "keys": keys}
		var swing: Dictionary = {"tracks": out}
		if not clips.is_empty():
			swing["clips"] = clips.map(func(c: StringName) -> String: return String(c))
			swing["speed"] = timing.speed
			swing["marks"] = timing.all_marks()
		if fallback != &"":
			swing["fallback"] = String(fallback)
		if loop != &"":
			swing["loop"] = String(loop)
		if sheathed.size() == 2:
			swing["sheathed"] = Array(sheathed)
		if V3.length(reach_offset) > 0.0:
			swing["reach"] = SwingBake._round(reach_offset)
		if rogue_humanm:
			swing["rogue_humanm"] = true
		return swing


## What correct_reach() found.
class Reach:
	## How far apart (m, centre to centre) the move was tested from.
	var distance: float = 0.0
	## The blade inside the defender it aimed for, and the least it needs (m).
	var aim: float = 0.0
	var minimum: float = 0.0
	## The most blade inside the defender before and after the correction
	## (m); -1 for no touch.
	var before: float = -1.0
	var after: float = -1.0
	## The correction (m, in the fighter's frame).
	var offset: V3 = V3.make()
	## True when even MAX_REACH falls short (the most is applied).
	var short: bool = false
	## True when a light puts more than LIGHT_MAX_INSIDE in before any
	## correction.
	var over: bool = false
	## The attack frame of the first touch after the correction (for the
	## move's lunge end), or -1.
	var first_touch: int = -1


## The attack frames of bake `r` whose clip time falls within source
## frames `from` to `to` (from the chain's start), first and last: where
## the blade is in the saya. Empty when none does.
static func sheathed_frames(r: Result, from: float, to: float) -> PackedInt32Array:
	var first: int = -1
	var last: int = -1
	for f: int in r.times.size():
		var source: float = r.times[f] * float(ClipManifest.SOURCE_FPS)
		if source >= from - 1e-6 and source <= to + 1e-6:
			if first < 0:
				first = f
			last = f
	return PackedInt32Array() if first < 0 else PackedInt32Array([first, last])


## The clip retimed at `speed` by `markers` (ClipTiming.make()): null, with
## an error per mistake.
static func timing(markers: Dictionary, speed: float, errors: Array[String]) -> ClipTiming:
	return ClipTiming.make(markers, speed, errors)


## The speed (ClipTiming.MIN_SPEED to MAX_SPEED in SPEED_STEP steps) whose
## startup lands closest to `startup`, the slowest of those that tie. Bad
## markers give MIN_SPEED.
static func pick_speed(markers: Dictionary, startup: int) -> float:
	var best: float = ClipTiming.MIN_SPEED
	var best_gap: int = 1 << 30
	var steps: int = roundi((ClipTiming.MAX_SPEED - ClipTiming.MIN_SPEED) / SPEED_STEP)
	for i: int in steps + 1:
		var speed: float = snappedf(ClipTiming.MIN_SPEED + SPEED_STEP * i, 0.001)
		var t: ClipTiming = timing(markers, speed, [] as Array[String])
		if t == null:
			return ClipTiming.MIN_SPEED
		var gap: int = absi(t.startup - startup)
		if gap < best_gap:
			best = speed
			best_gap = gap
	return best


## Bakes the sampled clip: `pose` takes a clip time (s) and gives the parts'
## poses then, a Dictionary[StringName, Swing.Sample] holding each of
## `parts`; `length` is the clip's (s). Null, with errors, for a bad marker
## or speed (timing()), a settle past the clip's end, or a part the poses
## lack.
static func bake(pose: Callable, length: float, markers: Dictionary, speed: float, parts: Array[StringName],
		errors: Array[String]) -> Result:
	var t: ClipTiming = timing(markers, speed, errors)
	if t == null:
		return null
	var end: float = length * float(ClipManifest.SOURCE_FPS)
	if t.marks[3] > end + 1e-6:
		errors.append("the settle marker (%s) is past the clip's end (frame %s)" % [ClipTiming.frame_text(t.marks[3]), ClipTiming.frame_text(snappedf(end, 0.01))])
		return null
	var out: Result = Result.new()
	out.timing = t
	var ordered: Array[StringName] = []
	for part: StringName in Swing.PARTS:
		if parts.has(part):
			ordered.append(part)
			out.tracks[part] = []
	for f: int in t.total() + 1:
		var time: float = t.clip_time(float(f))
		out.times.append(time)
		var poses: Dictionary = pose.call(time)
		for part: StringName in ordered:
			if not poses.has(part):
				errors.append("the sampled clip has no %s" % part)
				return null
			out.tracks[part].append(poses[part])
	return out


## Corrects the reach of the bake `r` of `move` (which strikes) on `weapon`: plays it
## from standing at a standing defender (SwingReach.touches(), with r's frames)
## from the reach table's distance for the move, and where its blade falls
## short of the rule (a light of the string: LIGHT_MIN_INSIDE at the duelling
## distance; any other move: a touch), finds the least push of its striking
## grips along REACH_DIRECTION, up to MAX_REACH, that reaches the aim, and
## puts it into r (r.reach_offset and the grips). The push eases in and out
## (Swing.reach_weight_at()). A light already past LIGHT_MAX_INSIDE is
## reported, not pulled back. `distance` (m) overrides the table's.
static func correct_reach(r: Result, move: AttackDef, weapon: WeaponDef, distance: float = -1.0) -> Reach:
	var out: Reach = Reach.new()
	var light: bool = ReachTable.kind_of(weapon, move.id) == &"string_light"
	out.distance = distance if distance > 0.0 else ReachTable.distance(weapon, move.id)
	out.aim = LIGHT_AIM if light else TOUCH_AIM
	out.minimum = LIGHT_MIN_INSIDE if light else 0.0
	var dir: V3 = V3.make(REACH_DIRECTION[0], REACH_DIRECTION[1], REACH_DIRECTION[2])
	var first: Array = _measure(r, move, weapon, out.distance, V3.make())
	out.before = first[0]
	out.after = first[0]
	out.first_touch = first[1]
	out.over = light and out.before > LIGHT_MAX_INSIDE
	if out.before >= out.minimum and out.before >= 0.0:
		return out
	var most: Array = _measure(r, move, weapon, out.distance, V3.scale(dir, MAX_REACH))
	var push: float = MAX_REACH
	if most[0] < out.minimum or most[0] < 0.0:
		out.short = true
	elif most[0] > out.aim:
		# the least push that reaches the aim
		var lo: float = 0.0
		var hi: float = MAX_REACH
		for i: int in 14:
			var mid: float = (lo + hi) * 0.5
			var m: Array = _measure(r, move, weapon, out.distance, V3.scale(dir, mid))
			if m[0] >= out.aim:
				hi = mid
			else:
				lo = mid
		push = snappedf(hi, 0.001)
	out.offset = V3.scale(dir, push)
	var after: Array = _measure(r, move, weapon, out.distance, out.offset)
	out.after = after[0]
	out.first_touch = after[1]
	apply_reach(r, out.offset)
	return out


## Pushes the striking tracks' grips of `r` by `offset` (eased by
## Swing.reach_weight_at()) and records it as r's reach correction.
static func apply_reach(r: Result, offset: V3) -> void:
	var t: ClipTiming = r.timing
	for part: StringName in r.tracks:
		if part == &"body":
			continue
		var samples: Array = r.tracks[part]
		for f: int in samples.size():
			var w: float = Swing.reach_weight_at(float(f), t.startup, t.active, t.total())
			if w <= 0.0:
				continue
			var s: Swing.Sample = samples[f]
			var moved: Swing.Sample = Swing.Sample.new()
			moved.grip = V3.add(s.grip, V3.scale(offset, w))
			moved.blade = s.blade
			moved.edge = s.edge
			moved.pole = s.pole
			samples[f] = moved
	r.reach_offset = V3.add(r.reach_offset, offset)


## How far (m) another sampled clip (`pose`, taking a clip time) strays from
## r's striking grips at the frames that sweep for hits (the last startup
## frame through the last active frame), at its worst.
static func drift(r: Result, pose: Callable) -> float:
	var worst: float = 0.0
	var t: ClipTiming = r.timing
	for f: int in range(t.startup, t.startup + t.active + 1):
		var poses: Dictionary = pose.call(r.times[f])
		for part: StringName in r.tracks:
			if part != &"body":
				worst = maxf(worst, V3.distance((poses[part] as Swing.Sample).grip, (r.tracks[part][f] as Swing.Sample).grip))
	return worst


## r as a Swing the rules read (baked tracks, no guard), its striking grips
## pushed by `offset` as apply_reach() would.
static func swing_of(r: Result, offset: V3 = V3.make()) -> Swing:
	var t: ClipTiming = r.timing
	var swing: Swing = Swing.new(t.total())
	swing.reach_startup = t.startup
	swing.reach_active = t.active
	for part: StringName in r.tracks:
		var keys: Array[Swing.KeyPose] = []
		var samples: Array = r.tracks[part]
		for f: int in samples.size():
			var s: Swing.Sample = samples[f]
			var k: Swing.KeyPose = Swing.KeyPose.new()
			k.frame = f
			k.grip = s.grip
			if part != &"body":
				k.grip = V3.add(s.grip, V3.scale(offset, Swing.reach_weight_at(float(f), t.startup, t.active, t.total())))
			k.blade = s.blade
			k.edge = s.edge
			k.pole = s.pole
			k.torso = s.torso
			k.pelvis = s.pelvis
			k.pelvis_shift = s.pelvis_shift
			keys.append(k)
		swing.add_track(part, keys, true)
	return swing


## A copy of `move` with `timing`'s frames and `swing`: its lunge's start and
## end carried onto the new frames through the marker frames (today's
## startup, active and last frame onto the new ones).
static func retimed(move: AttackDef, timing: ClipTiming, swing: Swing) -> AttackDef:
	var d: AttackDef = AttackDef.new()
	for p: Dictionary in move.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d.set(p["name"], move.get(p["name"]))
	var old: PackedInt32Array = PackedInt32Array([0, move.startup, move.startup + move.active, move.total_frames()])
	d.startup = timing.startup
	d.active = timing.active
	d.recovery = timing.recovery
	d.lunge_start = _carry_frame(move.lunge_start, old, timing.frames)
	if move.lunge_end != AttackDef.UNSET:
		d.lunge_end = _carry_frame(move.lunge_end, old, timing.frames)
	d.swing = swing
	return d


static func _carry_frame(f: int, old: PackedInt32Array, new: PackedInt32Array) -> int:
	if f <= 0:
		return f
	for j: int in 3:
		if f <= old[j + 1]:
			var s: float = float(f - old[j]) / float(maxi(1, old[j + 1] - old[j]))
			return roundi(lerpf(float(new[j]), float(new[j + 1]), s))
	return new[3] + (f - old[3])


## [the most blade inside the defender, or a fist's depth (SwingReach.inside();
## m, -1 for no touch), the attack
## frame of the first touch (-1)] for r on `move` pushed by `offset`.
static func _measure(r: Result, move: AttackDef, weapon: WeaponDef, distance: float, offset: V3) -> Array:
	var def: AttackDef = retimed(move, r.timing, swing_of(r, offset))
	var touches: Array[SwingReach.Contact] = SwingReach.touches(def, weapon, distance, 0.0, FighterBody.of(&""))
	if touches.is_empty():
		return [-1.0, -1]
	var inside: float = 0.0
	for c: SwingReach.Contact in touches:
		inside = maxf(inside, SwingReach.inside(c, weapon))
	return [inside, touches[0].frame]


## Bare hands' kicks that strike with the knee and shin rather than the foot
## (task 25): the Flying Knee.
const KNEE_STRIKES: Array[StringName] = [&"f_sl"]


## The parts a move's swing bakes, beside the body: both hands for a pair
## of weapons (the Daggers); the striking hand, or foot for a kick (the knee
## for a knee strike, KNEE_STRIKES), for bare hands, on the move's side (both
## hands for a move with both); a bash's leading shoulder (task 19); the main
## hand otherwise.
static func parts_for(move: AttackDef, weapon: WeaponDef) -> Array[StringName]:
	var out: Array[StringName] = []
	if move.damage <= 0.0 and move.posture <= 0.0:
		# a pose-only move (Flash, task 13): the body alone, so no blade is
		# placed and it never strikes; the weapon rides the clip's hand
		out.append(&"body")
		return out
	if move.type == &"bash":
		# a bash strikes with the leading shoulder (task 19: the packs' bashes,
		# Shield_Dash and AttackShield01, lead with the left); the weapon
		# rides the clip's hands
		out.append(&"left_shoulder")
	elif weapon.id == &"daggers":
		out.assign([&"right_hand", &"left_hand"])
	elif weapon.id == &"fists":
		var limb: String = "hand"
		if move.type == &"kick":
			limb = "knee" if KNEE_STRIKES.has(move.id) else "foot"
		if move.hand == &"L" or move.hand == &"both":
			out.append(StringName("left_" + limb))
		if move.hand != &"L":
			out.append(StringName("right_" + limb))
		out.sort_custom(func(a: StringName, b: StringName) -> bool: return Swing.PARTS.find(a) < Swing.PARTS.find(b))
	else:
		out.append(&"right_hand")
	out.append(&"body")
	return out


## A pose's fields as a swing file holds them, rounded: a hand or foot's
## grip, blade and edge (and pole, if any), or the body's coils and pelvis
## shift.
static func pose_record(part: StringName, s: Swing.Sample) -> Dictionary:
	if part == &"body":
		var body: Dictionary = {"torso": snappedf(s.torso, pow(10.0, -DEGREE_PLACES)), "pelvis": snappedf(s.pelvis, pow(10.0, -DEGREE_PLACES))}
		if V3.length(s.pelvis_shift) > 0.0:
			body["pelvis_shift"] = _round(s.pelvis_shift)
		return body
	var limb: Dictionary = {"grip": _round(s.grip), "blade": _round(s.blade), "edge": _round(s.edge)}
	if V3.length(s.pole) > 0.0:
		limb["pole"] = _round(s.pole)
	return limb


## The guard of a swing file from one pose of each part (a weapon's idle
## clip's first frame), as the file holds it.
static func guard_record(poses: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for part: StringName in Swing.PARTS:
		if poses.has(part):
			out[String(part)] = pose_record(part, poses[part])
	return out


## A swing file's text: {"guard": {...}, "swings": {move: {"tracks": ...}}}
## with each guard pose and each key on a line of its own, the fields in
## FIELD_ORDER, metres and directions to PLACES decimals and degrees to
## DEGREE_PLACES. Hand-keyed tracks (lists of keys) are written as well as
## baked ones, so a file can be rewritten whole.
static func file_text(guard: Dictionary, swings: Dictionary) -> String:
	var lines: PackedStringArray = ["{", "\t\"guard\": {"]
	var parts: Array = guard.keys()
	for i: int in parts.size():
		lines.append("\t\t\"%s\": %s%s" % [parts[i], _line(guard[parts[i]]), "," if i < parts.size() - 1 else ""])
	lines.append("\t},")
	lines.append("\t\"swings\": {")
	var ids: Array = swings.keys()
	for i: int in ids.size():
		lines.append("\t\t\"%s\": {" % ids[i])
		lines.append("\t\t\t\"tracks\": {")
		var tracks: Dictionary = swings[ids[i]]["tracks"]
		var names: Array = tracks.keys()
		for j: int in names.size():
			var track: Variant = tracks[names[j]]
			var keys: Array = track["keys"] if track is Dictionary else track
			if track is Dictionary:
				lines.append("\t\t\t\t\"%s\": {\"baked\": %s, \"keys\": [" % [names[j], "true" if track["baked"] else "false"])
			else:
				lines.append("\t\t\t\t\"%s\": [" % names[j])
			for k: int in keys.size():
				lines.append("\t\t\t\t\t%s%s" % [_line(keys[k]), "," if k < keys.size() - 1 else ""])
			var comma: String = "," if j < names.size() - 1 else ""
			lines.append("\t\t\t\t]}%s" % comma if track is Dictionary else "\t\t\t\t]%s" % comma)
		var record: Dictionary = swings[ids[i]]
		var extras: Array = EXTRA_FIELDS.filter(func(k: String) -> bool: return record.has(k))
		lines.append("\t\t\t}%s" % ("," if not extras.is_empty() else ""))
		for k: int in extras.size():
			lines.append("\t\t\t\"%s\": %s%s" % [extras[k], _value(extras[k], record[extras[k]]), "," if k < extras.size() - 1 else ""])
		lines.append("\t\t}%s" % ("," if i < ids.size() - 1 else ""))
	lines.append("\t}")
	lines.append("}")
	return "\n".join(lines) + "\n"


## One line of a report: a move's speed and frames against today's.
static func report_line(id: StringName, clips: String, t: ClipTiming, move: AttackDef) -> String:
	return "%s (%s ×%.2f): startup %d (today %d), active %d (%d), recovery %d (%d), total %d (%d)" % [
		id, clips, t.speed, t.startup, move.startup, t.active, move.active, t.recovery, move.recovery,
		t.total(), move.total_frames()]


static func _round(v: V3) -> Array:
	var unit: float = pow(10.0, -PLACES)
	return [snappedf(v.x, unit), snappedf(v.y, unit), snappedf(v.z, unit)]


static func _line(d: Dictionary) -> String:
	var fields: PackedStringArray = []
	var names: Array = FIELD_ORDER.filter(func(f: String) -> bool: return d.has(f))
	for extra: Variant in d:
		if not names.has(str(extra)):
			names.append(str(extra))
	for name: String in names:
		fields.append("\"%s\": %s" % [name, _value(name, d[name])])
	return "{%s}" % ", ".join(fields)


static func _value(field: String, v: Variant) -> String:
	if v is Array:
		return "[%s]" % ", ".join((v as Array).map(func(x: Variant) -> String: return _value(field, x)))
	if typeof(v) == TYPE_BOOL:
		return "true" if v else "false"
	if v is String or v is StringName:
		return JSON.stringify(str(v))
	if field == "frame":
		return str(int(v))
	return _num(float(v), DEGREE_PLACES if field == "torso" or field == "pelvis" else PLACES)


static func _num(x: float, places: int) -> String:
	var v: float = snappedf(x, pow(10.0, -places))
	if v == roundf(v):
		return str(int(v))
	return String.num(v, places)
