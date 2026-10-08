class_name FrameDataGenerator
extends RefCounted
## The frame-data generator (milestone-1 task 15): today's bake (SwingBake)
## turned round. Where the bake retimed a clip onto hand-typed frame data,
## this reads a clip (or a chain of clips) at 1.0x with its markers and gives
## back what they make:
## - startup, active and recovery in rules frames, the dodge-cancel window
##   and each follow-up's branch point and window (MoveClips.frame_data(),
##   two rules frames to a source frame from the wind-up start);
## - the clip's time at every rules frame of the move, 0 to the last;
## - each part's pose at every rules frame (a swing's baked tracks), either
##   as the clip has it in place or relative to the moving body;
## - the body's travel over every rules frame (forward, sideways, turn), from
##   the hips and the foot plants (travel()).
## It is a pure function of what it is given: a sampled clip (a Callable
## giving the parts' poses at a clip time, in the fighter's own (right, up,
## forward) frame, as ClipPoser.pose() does), its length, the move's markers
## (MoveClips.Entry.markers: source frames from the chain's start) and each
## foot's contacts in the chain's source frames (ClipManifest.Clip.
## foot_contacts, laid along the chain). There is no speed: a clip plays at
## its own. The one exception is a move whose markers are stand-ins
## (MoveClips.Entry.markers_stand_in, the owner's word of Oct 5): its frame
## data come from the markers, equal to today's, but its clip is sampled as
## it plays today (`retime`, its ClipTiming), so it hits as now until its
## family re-keys it.
##
## Travel is what the body does over the ground. While a foot is planted it
## stays put in the world, so the fighter's root moves against the way the
## planted foot slides in the clip (both feet planted: their average), and
## turns against the way it turns; with no foot planted the root carries on
## straight ahead at the speed it last went forward (none at the start),
## holding its heading: a planted foot's last sideways slide and twist aren't
## carried, since retargeting onto the game's bodies bends a push-off's last
## slide a little, and a leap would drift and turn on it all through the
## flight (milestone-1 task 93). The hips' own shift in the clip
## rides on top: a frame's travel is the root's move plus the hips' move
## across the ground. A swing sampled relative to the moving body has the
## hips' shift across the ground taken out, so the clip's path is the swing's
## plus the travel: nothing counted twice.

## Decimal places travel is written to: metres, degrees.
const PLACES: int = 4
const DEGREE_PLACES: int = 2


## What generate() gives back.
class Result:
	var startup: int = 0
	var active: int = 0
	var recovery: int = 0
	## The dodge cancel's first and last rules frames, or empty for none.
	var dodge_cancel: PackedInt32Array = PackedInt32Array()
	## Follow-up -> [its branch point, the last frame of its window] (rules
	## frames): pressed before the branch point it starts there, pressed
	## inside the window it starts at once; the window runs to the move's
	## last frame.
	var branches: Dictionary[StringName, PackedInt32Array] = {}
	## The clip's time (s) at each rules frame, 0 to total().
	var times: PackedFloat64Array = PackedFloat64Array()
	## Each part's pose at each rules frame (Array[Swing.Sample]), by part,
	## in Swing.PARTS' order.
	var tracks: Dictionary[StringName, Array] = {}
	## Whether the tracks are relative to the moving body (else in place).
	var relative: bool = false
	## The body's move over each rules frame (from the frame before; frame 0
	## none), in the fighter's frame of that moment: metres forward, metres
	## to the right, degrees turned to the right.
	var forward: PackedFloat64Array = PackedFloat64Array()
	var sideways: PackedFloat64Array = PackedFloat64Array()
	var turn: PackedFloat64Array = PackedFloat64Array()

	func total() -> int:
		return startup + active + recovery

	## The travel as the table writes it: one [forward, sideways, turn] per
	## rules frame, rounded.
	func travel_record() -> Array:
		var out: Array = []
		for f: int in forward.size():
			out.append([snappedf(forward[f], pow(10.0, -PLACES)), snappedf(sideways[f], pow(10.0, -PLACES)),
				snappedf(turn[f], pow(10.0, -DEGREE_PLACES))])
		return out


## The markers a move has to have, in the order they fall.
const NEEDED: Array[String] = ["windup", "active_start", "active_end", "settle"]


## Generates a move from its sampled clip: `pose` takes a clip time (s) and
## gives the parts' poses then (each of `parts`, and both feet and the body
## for the travel), `length` is the clip's (s), `markers` the move's
## (source frames from the chain's start: NEEDED, maybe "dodge_cancel",
## "dodge_cancel_end" and "branch"), `contacts` each foot's [plant, lift]
## spans in the chain's source frames ({"left": [...], "right": [...]}).
## With `relative` the tracks are sampled relative to the moving body; with
## `retime` (a stand-in's) the clip is sampled on today's timing, whose
## frames must be the markers'. Null, with an error per mistake, for a
## missing or misplaced marker, a settle past the clip's end, a retime of
## other frames, or a part the poses lack.
static func generate(pose: Callable, length: float, markers: Dictionary, contacts: Dictionary,
		parts: Array[StringName], errors: Array[String], relative: bool = false, retime: ClipTiming = null) -> Result:
	var before: int = errors.size()
	for name: String in NEEDED:
		var v: Variant = markers.get(name)
		if not (v is float or v is int):
			errors.append("no %s marker" % name)
	if errors.size() != before:
		return null
	for i: int in range(1, NEEDED.size()):
		if float(markers[NEEDED[i]]) <= float(markers[NEEDED[i - 1]]):
			errors.append("the %s marker must come after the %s marker" % [NEEDED[i], NEEDED[i - 1]])
	var end: float = length * ClipManifest.SOURCE_FPS
	if float(markers["settle"]) > end + 1e-6:
		errors.append("the settle marker (%s) is past the clip's end (frame %s)" % [
			ClipTiming.frame_text(float(markers["settle"])), ClipTiming.frame_text(snappedf(end, 0.01))])
	if errors.size() != before:
		return null
	var fd: Dictionary = MoveClips.frame_data(markers)
	var out: Result = Result.new()
	out.startup = fd["startup"]
	out.active = fd["active"]
	out.recovery = fd["recovery"]
	if fd["dodge_cancel_from"] != AttackDef.UNSET:
		out.dodge_cancel = PackedInt32Array([fd["dodge_cancel_from"], fd["dodge_cancel_to"]])
	for follow: Variant in fd["branch"]:
		out.branches[StringName(follow)] = PackedInt32Array([fd["branch"][follow], out.total()])
	if retime != null and retime.total() != out.total():
		errors.append("today's timing has %d frames, the markers %d" % [retime.total(), out.total()])
		return null
	var windup: float = float(markers["windup"])
	var wanted: Array[StringName] = []
	for part: StringName in Swing.PARTS:
		if parts.has(part):
			wanted.append(part)
			out.tracks[part] = []
	var feet: Array[Dictionary] = []
	var hips: Array[V3] = []
	for f: int in out.total() + 1:
		var time: float = retime.clip_time(float(f)) if retime != null else (windup + f / ClipTiming.RULES_FPS * ClipManifest.SOURCE_FPS) / ClipManifest.SOURCE_FPS
		out.times.append(time)
		var poses: Dictionary = pose.call(time)
		for part: StringName in wanted + ([&"left_foot", &"right_foot", &"body"] as Array[StringName]):
			if not poses.has(part):
				errors.append("the sampled clip has no %s" % part)
				return null
		for part: StringName in wanted:
			out.tracks[part].append(poses[part])
		feet.append({"left": poses[&"left_foot"], "right": poses[&"right_foot"]})
		hips.append((poses[&"body"] as Swing.Sample).pelvis_shift)
	travel(out, feet, hips, contacts)
	if relative:
		out.relative = true
		for part: StringName in out.tracks:
			var samples: Array = out.tracks[part]
			for f: int in samples.size():
				samples[f] = _without_ground_shift(part, samples[f], V3.sub(_ground(hips[f]), _ground(hips[0])))
	return out


## Fills r's travel from each rules frame's feet ({"left", "right"}:
## Swing.Sample, the ankle and the way to the toes) and hips' shift, over
## r.times, by the foot contacts.
static func travel(r: Result, feet: Array[Dictionary], hips: Array[V3], contacts: Dictionary) -> void:
	r.forward = PackedFloat64Array([0.0])
	r.sideways = PackedFloat64Array([0.0])
	r.turn = PackedFloat64Array([0.0])
	var root: V3 = V3.make()
	var root_turn: float = 0.0
	for f: int in range(1, r.times.size()):
		var a: float = r.times[f - 1] * ClipManifest.SOURCE_FPS
		var b: float = r.times[f] * ClipManifest.SOURCE_FPS
		var slide: V3 = V3.make()
		var twist: float = 0.0
		var planted: int = 0
		for side: String in ClipManifest.FEET:
			if not planted_over(contacts.get(side, []), a, b):
				continue
			var was: Swing.Sample = feet[f - 1][side]
			var now: Swing.Sample = feet[f][side]
			slide = V3.add(slide, V3.sub(_ground(now.grip), _ground(was.grip)))
			twist += wrapf(_yaw(now.blade) - _yaw(was.blade), -180.0, 180.0)
			planted += 1
		if planted > 0:
			root = V3.scale(slide, -1.0 / planted)
			root_turn = -twist / planted
		else:
			root = V3.make(0.0, 0.0, root.z)
			root_turn = 0.0
		var move: V3 = V3.add(root, V3.sub(_ground(hips[f]), _ground(hips[f - 1])))
		r.forward.append(move.z)
		r.sideways.append(move.x)
		r.turn.append(root_turn)


## A looping gait clip's ground speed over one loop at 1.0x, as its planted
## feet sweep back under it (the clip plays in place), sampled on every
## rules frame: {"speed": m/s, "heading": degrees to the right of forward,
## "stride": m over one loop}; zeros with no foot ever planted.
static func gait(pose: Callable, length: float, contacts: Dictionary) -> Dictionary:
	var frames: int = floori(length * ClipTiming.RULES_FPS)
	var sweep: V3 = V3.make()
	var planted_frames: int = 0
	var was: Dictionary = pose.call(0.0).duplicate()
	for f: int in range(1, frames + 1):
		var now: Dictionary = pose.call(f / ClipTiming.RULES_FPS).duplicate()
		var slide: V3 = V3.make()
		var planted: int = 0
		for side: String in ClipManifest.FEET:
			if planted_over(contacts.get(side, []), (f - 1) * 0.5, f * 0.5):
				var part: StringName = StringName(side + "_foot")
				slide = V3.add(slide, V3.sub(_ground((now[part] as Swing.Sample).grip), _ground((was[part] as Swing.Sample).grip)))
				planted += 1
		if planted > 0:
			sweep = V3.add(sweep, V3.scale(slide, -1.0 / planted))
			planted_frames += 1
		was = now
	if planted_frames == 0:
		return {"speed": 0.0, "heading": 0.0, "stride": 0.0}
	var speed: float = V3.length(sweep) / (planted_frames / ClipTiming.RULES_FPS)
	return {"speed": speed, "heading": rad_to_deg(atan2(sweep.x, sweep.z)), "stride": speed * length}


## Whether a foot with `spans` ([plant, lift] source frames) is planted from
## source frame `a` to `b`.
static func planted_over(spans: Array, a: float, b: float) -> bool:
	for s: Variant in spans:
		if float(s[0]) <= minf(a, b) + 1e-6 and float(s[1]) >= maxf(a, b) - 1e-6:
			return true
	return false


## Each foot's contacts in a chain's source frames: each part's clip's
## contacts (`contacts_of`: clip id -> ClipManifest.Clip.foot_contacts),
## shifted to where the part plays in the chain and cut to its span; a held
## part (ClipChain's "*") holds its frame, planted if a contact holds it.
static func chain_contacts(parts: Array[ClipChain.Part], contacts_of: Dictionary) -> Dictionary:
	var out: Dictionary = {"left": [], "right": []}
	for p: ClipChain.Part in parts:
		var own: Dictionary = contacts_of.get(p.id, {})
		for side: String in ClipManifest.FEET:
			for s: Variant in own.get(side, []):
				var from: float = maxf(float(s[0]), p.from)
				var to: float = minf(float(s[1]), p.from + (p.length if p.hold <= 0.0 else 0.0))
				if p.hold > 0.0:
					if float(s[0]) <= p.from and float(s[1]) >= p.from:
						(out[side] as Array).append([p.start, p.start + p.length])
					continue
				if to < from:
					continue
				(out[side] as Array).append([p.start + from - p.from, p.start + to - p.from])
	for side: String in ClipManifest.FEET:
		(out[side] as Array).sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	return out


## A sample with the hips' shift across the ground (`shift`) taken out: a
## limb's grip, or the body's pelvis shift.
static func _without_ground_shift(part: StringName, s: Swing.Sample, shift: V3) -> Swing.Sample:
	var out: Swing.Sample = Swing.Sample.new()
	out.grip = V3.sub(s.grip, shift) if part != &"body" else s.grip
	out.blade = s.blade
	out.edge = s.edge
	out.pole = s.pole
	out.torso = s.torso
	out.pelvis = s.pelvis
	out.pelvis_shift = V3.sub(s.pelvis_shift, shift) if part == &"body" else s.pelvis_shift
	return out


static func _ground(v: V3) -> V3:
	return V3.make(v.x, 0.0, v.z)


## A direction's heading in degrees, positive toward the fighter's right.
static func _yaw(v: V3) -> float:
	return rad_to_deg(atan2(v.x, v.z))
