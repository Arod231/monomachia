class_name SwingCheck
extends RefCounted
## Checks a move's swing against a fighter's body (task 7.7), headless: the
## spike critique's first fix. It poses the reference body (ReferenceBody) as
## the swing's body track keys it, solves each arm's elbow, and reports every
## stretch of the swing where:
## - a wrist turns sideways past ±25°;
## - an elbow locks (170° or straighter) or the grip is out of the arm's reach;
## - a blade comes within 5 cm of the body: the torso, the head (with its hood
##   or hat), the thighs or an arm. A blade isn't checked against the fist
##   and forearm that hold it, which its wrist limits keep it clear of;
## - a grip crosses in front of the face during the wind-up.
## It looks at every quarter frame from frame 0 to the last, so the entry, the
## keys and the exit are all covered; check() takes the move the swing
## follows, for a chained entry. Foot and body tracks aren't checked: kicks
## have no wrist, and the body only poses the rest. Sheathed keys (task 7.19)
## will be exempt from the blade checks.
##
## A hand sits on its grip as the fighter rig seats it (FighterRig.seat()):
## the fist (ReferenceBody.wrist_in_fist()) turned round the handle so that
## the hand carries on the line of its forearm, refined over ROLL_PASSES as
## the wrist moves round the handle. So a wrist never bends back or forward;
## how far it turns sideways (toward the thumb, the handle) is what the swing
## sets, and what the check limits. The elbow bends toward its pole, as the
## rig's does: ELBOW_POLES (out, down and back from the shoulder, in arm
## lengths), turned with the torso coil, plus the key's pole tweak, in the
## fighter's space. The rig also swings the collarbone near full reach, so it
## straightens an elbow later than the check does.
##
## A weapon held in both hands (WeaponDef.off_hand_grip) puts the left hand
## on its off-hand grip, seated like the right; such a swing keys no left
## hand. Otherwise each hand track holds its own copy of the weapon (the
## daggers, or a fist), and a hand with no track isn't posed.

const WRIST_DEVIATION: float = 25.0
const ELBOW_LOCKED: float = 170.0
## How far a blade must stay from every proxy (metres).
const CLEARANCE: float = 0.05
## The face: a capsule from the middle of the head's capsule straight ahead,
## an arm's reach long, reaching from the chin to the brow.
const FACE_REACH: float = 0.6
const FACE_RADIUS: float = 0.12
## How many times a hand's turn round the handle is refined, as the rig's is
## (FighterRig.ROLL_PASSES).
const ROLL_PASSES: int = 4
## Each elbow's pole from its shoulder (FighterRig.ELBOW_POLE), (right, up,
## forward) in arm lengths.
const ELBOW_POLES: Dictionary[StringName, Array] = {
	&"right": [0.61, -1.12, -0.72],
	&"left": [-0.61, -1.12, -0.72],
}
## Samples per frame.
const SUBSTEPS: int = 4

const HANDS: Dictionary[StringName, StringName] = {&"right": &"right_hand", &"left": &"left_hand"}


## One arm at one moment: where it reaches and how its joints sit.
class Arm:
	var side: StringName
	var grip: V3
	## The hand's frame: along the hand (wrist to knuckles), out of the thumb
	## side (the handle) and out of the flat of the fist.
	var along: V3
	var thumb: V3
	var flat: V3
	var shoulder: V3
	var elbow: V3 = null
	var wrist: V3
	## How far the grip is past the arm's reach (metres; 0 within it).
	var short: float = 0.0
	## The elbow's angle (180 straight) and the wrist's bend toward the flat
	## and turn toward the thumb, in degrees. The bend is what's left of the
	## hand's turn to its forearm after its passes: a degree or so.
	var elbow_angle: float = 0.0
	var bend: float = 0.0
	var deviation: float = 0.0


## One blade at one moment, in the fighter's space.
class Blade:
	var side: StringName
	var base: V3
	var tip: V3
	var half: float


## The whole check's view of one moment of a swing.
class Moment:
	var t: float
	var body: ReferenceBody
	var arms: Dictionary[StringName, Arm] = {}
	var blades: Array[Blade] = []
	var face: SimCapsule
	## The proxies a blade must keep clear of, by name, besides the arms.
	var proxies: Dictionary[String, SimCapsule] = {}


## Every problem with `move`'s swing on `body`, holding `weapon`, entered
## from the guard, or from `chained_from` (the swing of the move it follows).
## Each names the part, what is wrong, the worst frame and the stretch of
## frames it lasts; none for a move without a swing.
static func check(move: AttackDef, weapon: WeaponDef, body: ReferenceBody, chained_from: Swing = null) -> Array[String]:
	var out: Array[String] = []
	var swing: Swing = move.swing
	if swing == null:
		return out
	if weapon.off_hand_grip != null and swing.parts().has(&"left_hand"):
		out.append("left_hand: a weapon held in both hands keys no left hand; it grips the off-hand grip")
	var found: Dictionary[String, Dictionary] = {}
	for i: int in swing.last_frame * SUBSTEPS + 1:
		var m: Moment = moment(swing, weapon, body, float(i) / SUBSTEPS, chained_from)
		_look(m, move, found)
	var keys: Array = found.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return found[a]["first"] < found[b]["first"] or (found[a]["first"] == found[b]["first"] and a < b))
	for key: String in keys:
		var f: Dictionary = found[key]
		var span: String = "frame %s only" % _frame(f["first"]) if f["first"] == f["last"] \
				else "frames %s to %s" % [_frame(f["first"]), _frame(f["last"])]
		out.append("%s on frame %s (%s)" % [f["text"], _frame(f["worst_t"]), span])
	return out


## The body, the arms and the blades of `swing` at frame `t`.
static func moment(swing: Swing, weapon: WeaponDef, body: ReferenceBody, t: float, chained_from: Swing = null) -> Moment:
	var m: Moment = Moment.new()
	m.t = t
	var coil: Swing.Sample = swing.sample(&"body", t, chained_from)
	var torso: float = coil.torso if coil != null else 0.0
	m.body = body.posed(torso, coil.pelvis if coil != null else 0.0, coil.pelvis_shift if coil != null else V3.make())
	var chest: Quat64 = Quat64.from_axis_angle(V3.normalized(V3.sub(m.body.spine_top, m.body.spine_base)), torso * SimMath.DEG)
	var right: Swing.Sample = swing.sample(&"right_hand", t, chained_from)
	if right != null:
		m.arms[&"right"] = _arm(&"right", right.grip, right.blade, right.edge, right.pole, m.body, chest)
		m.blades.append(_blade(&"right", right, weapon.blade))
	if weapon.off_hand_grip != null:
		if right != null:
			m.arms[&"left"] = _arm(&"left", right.place(weapon.off_hand_grip), right.blade, right.edge, V3.make(), m.body, chest)
	else:
		var left: Swing.Sample = swing.sample(&"left_hand", t, chained_from)
		if left != null:
			m.arms[&"left"] = _arm(&"left", left.grip, left.blade, left.edge, left.pole, m.body, chest)
			m.blades.append(_blade(&"left", left, weapon.blade))
	m.proxies["torso"] = m.body.torso
	m.proxies["head"] = m.body.head
	m.proxies["right thigh"] = m.body.thighs[&"right"]
	m.proxies["left thigh"] = m.body.thighs[&"left"]
	var centre: V3 = V3.lerp(m.body.head.a, m.body.head.b, 0.5)
	m.face = SimCapsule.make(centre, V3.add(centre, V3.make(0.0, 0.0, FACE_REACH)), FACE_RADIUS)
	return m


## The arm on `side` reaching for `grip`, its hand seated on a handle along
## `blade` with its edge `edge`.
static func _arm(side: StringName, grip: V3, blade: V3, edge: V3, pole: V3, body: ReferenceBody, chest: Quat64) -> Arm:
	var a: Arm = Arm.new()
	a.side = side
	a.grip = grip
	a.thumb = blade
	a.shoulder = body.shoulders[side]
	var upper: float = body.upper_arm
	var fore: float = body.forearm
	var p: Array = ELBOW_POLES[side]
	var toward: V3 = V3.add(Quat64.rotate(chest, V3.make(p[0], p[1], p[2])), pole)
	# The fist turns round the handle so that the hand carries on the line of
	# its forearm, as the rig's does (FighterRig.seat()): from the grip, each
	# pass solves the elbow for the last pass's wrist and turns the knuckles
	# toward that forearm, square to the handle, which moves the wrist round
	# the handle. The fist's flat is then blade cross knuckles in (right, up,
	# forward), as the weapon's is blade cross edge.
	var w: V3 = body.wrist_in_fist(side)
	a.wrist = grip
	for i: int in ROLL_PASSES:
		var forearm: V3 = V3.sub(a.wrist, _elbow_at(a.shoulder, a.wrist, toward, upper, fore))
		var square: V3 = V3.sub(forearm, V3.scale(blade, V3.dot(forearm, blade)))
		a.along = V3.normalized(square) if V3.length(square) > 1e-9 else edge
		a.flat = V3.cross(blade, a.along)
		a.wrist = V3.add(grip, V3.add(V3.add(V3.scale(a.along, w.x), V3.scale(a.thumb, w.y)), V3.scale(a.flat, w.z)))
	var reach: V3 = V3.sub(a.wrist, a.shoulder)
	var d: float = V3.length(reach)
	if d >= upper + fore:
		a.short = d - (upper + fore)
		a.elbow_angle = 180.0
		a.elbow = V3.add(a.shoulder, V3.scale(reach, upper / d))
	elif d <= absf(upper - fore):
		a.elbow_angle = 0.0
	else:
		a.elbow_angle = _acos(clampf((upper * upper + fore * fore - d * d) / (2.0 * upper * fore), -1.0, 1.0)) / SimMath.DEG
		a.elbow = _elbow_at(a.shoulder, a.wrist, toward, upper, fore)
	if a.elbow != null:
		var forearm: V3 = V3.normalized(V3.sub(a.wrist, a.elbow))
		var straight: float = V3.dot(forearm, a.along)
		a.bend = JsMath.atan2(V3.dot(forearm, a.flat), straight) / SimMath.DEG
		a.deviation = JsMath.atan2(V3.dot(forearm, a.thumb), straight) / SimMath.DEG
	return a


## Where the elbow goes when the wrist reaches `wrist` from `shoulder`, bent
## toward `toward` (a way from the shoulder), as the rig's arm IK bends it
## (FighterRig.elbow_at()): in the plane of the shoulder, the wrist and that
## way, on its side. A wrist out of reach is taken as far as the arm goes.
static func _elbow_at(shoulder: V3, wrist: V3, toward: V3, upper: float, fore: float) -> V3:
	var reach: V3 = V3.sub(wrist, shoulder)
	var d: float = clampf(V3.length(reach), absf(upper - fore) + 1e-4, upper + fore - 1e-4)
	var u: V3 = V3.normalized(reach)
	var v: V3 = V3.sub(toward, V3.scale(u, V3.dot(toward, u)))
	if V3.length(v) < 1e-9:
		v = V3.sub(V3.make(0.0, -1.0, 0.0), V3.scale(u, -u.y))
	v = V3.normalized(v)
	var along: float = (upper * upper + d * d - fore * fore) / (2.0 * d)
	return V3.add(shoulder, V3.add(V3.scale(u, along), V3.scale(v, sqrt(maxf(upper * upper - along * along, 0.0)))))


static func _blade(side: StringName, sample: Swing.Sample, segment: StrikeSegment) -> Blade:
	var b: Blade = Blade.new()
	b.side = side
	b.base = sample.place(segment.base)
	b.tip = sample.place(segment.tip)
	b.half = segment.thickness / 2.0
	return b


## Notes each problem of the moment `m` in `found`, by part and kind.
static func _look(m: Moment, move: AttackDef, found: Dictionary[String, Dictionary]) -> void:
	for side: StringName in m.arms:
		var a: Arm = m.arms[side]
		var part: String = String(HANDS[side])
		if a.short > 0.0:
			_note(found, part + " reach", m.t, a.short, "%s: the grip is %.1f cm out of the arm's reach" % [part, a.short * 100.0])
		elif a.elbow == null:
			_note(found, part + " fold", m.t, 1.0, "%s: the grip is too near the shoulder for the arm to fold" % part)
		else:
			if a.elbow_angle >= ELBOW_LOCKED:
				_note(found, part + " elbow", m.t, a.elbow_angle,
						"%s: the elbow locks at %.0f° (%.0f° or straighter is locked)" % [part, a.elbow_angle, ELBOW_LOCKED])
			if absf(a.deviation) > WRIST_DEVIATION:
				_note(found, part + " deviation", m.t, absf(a.deviation),
						"%s: the wrist turns %.0f° sideways (the limit is %.0f°)" % [part, absf(a.deviation), WRIST_DEVIATION])
		if m.t <= move.startup:
			var inside: float = SimMath.segment_distance(a.grip, a.grip, m.face.a, m.face.b) - m.face.radius
			if inside < 0.0:
				_note(found, part + " face", m.t, -inside, "%s: the grip crosses in front of the face in the wind-up" % part)
	for b: Blade in m.blades:
		var part: String = String(HANDS[b.side])
		var near: Dictionary[String, SimCapsule] = m.proxies.duplicate()
		for side: StringName in m.arms:
			var a: Arm = m.arms[side]
			if a.elbow == null:
				continue
			near["%s upper arm" % side] = SimCapsule.make(a.shoulder, a.elbow, m.body.upper_arm_radius[side])
			if side != b.side:
				near["%s forearm" % side] = SimCapsule.make(a.elbow, a.wrist, m.body.forearm_radius[side])
		for proxy: String in near:
			var c: SimCapsule = near[proxy]
			var gap: float = SimMath.segment_distance(b.base, b.tip, c.a, c.b) - c.radius - b.half
			if gap < CLEARANCE:
				_note(found, "%s blade %s" % [part, proxy], m.t, -gap,
						"%s: the blade comes within %.1f cm of the %s (it must keep %.0f cm clear)" % [part, gap * 100.0, proxy, CLEARANCE * 100.0])


## Records a problem `key` at `t`, keeping its first and last frames and its
## worst moment (the largest `badness`, described by `text`).
static func _note(found: Dictionary[String, Dictionary], key: String, t: float, badness: float, text: String) -> void:
	if not found.has(key):
		found[key] = {"first": t, "last": t, "worst": badness, "worst_t": t, "text": text}
		return
	var f: Dictionary = found[key]
	f["last"] = t
	if badness > f["worst"]:
		f["worst"] = badness
		f["worst_t"] = t
		f["text"] = text


## A frame for the reports: 8, or 8.25 between frames.
static func _frame(t: float) -> String:
	return "%d" % int(t) if t == floorf(t) else String.num(t, 2)


## acos through JsMath.atan2 and an exact sqrt, as the rules take their trig.
static func _acos(x: float) -> float:
	return JsMath.atan2(sqrt(maxf(0.0, 1.0 - x * x)), x)
