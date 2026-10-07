class_name PhysicalReactionLayer
extends SkeletonModifier3D
## The physical reaction layer (milestone-1 task 70; spec stories 96, 98,
## P11): a picture-only layer on the spine, head and arms that a hit or a
## block pushes from where and how hard it landed, so no two hits look
## alike. The second modifier of the fighter's rig (FighterRig), right after
## inertial blending and before the procedural body, foot locking and the
## hands' grip; the rules never read it.
##
## Each bone is a damped spring kicked by the push (response()): it shows
## part of the push at once, swings on to its peak a few frames later,
## overshoots a little on its way back and settles within half a second. A
## push bends each bone it reaches the way the push drives its far end (its
## length crossed with the push's direction), so the chain above a blow is
## carried back with it, and twists it about its length as far as the blow
## landed off that line, by an angle that falls off with the bone's distance
## from the contact. Pushes add up (each bone's turn kept under MAX_ANGLE)
## and are laid over the clip's pose in skeleton space, parent first, as
## BodyLayer lays its turns.
##
## It runs on the world's time, in rules frames (time, which the view sets
## each frame, the step plus alpha, as it does the inertial blend's), and
## the springs are summed in closed form, so hit-stop holds the push at its
## kick, slow motion slows it, and the same frames give the same pose
## however often they are drawn.

## The parts a push reaches: the spine low down, the chest, the neck and
## head, and the arms.
const LOWER_SPINE: int = 1
const UPPER_SPINE: int = 2
const HEAD: int = 4
const ARMS: int = 8
## A hit reaches every part; a block only the arms and the upper spine,
## the guard taking the impact.
const HIT: int = LOWER_SPINE | UPPER_SPINE | HEAD | ARMS
const BLOCK: int = UPPER_SPINE | ARMS

## The bones a push turns: bone -> [part, share of the push it takes, the
## bone it points to (its length runs from it to that bone; none: along its
## own Y)].
const BONES: Dictionary[StringName, Array] = {
	&"Spine": [LOWER_SPINE, 0.5, &"Chest"],
	&"Chest": [UPPER_SPINE, 0.7, &"UpperChest"],
	&"UpperChest": [UPPER_SPINE, 0.8, &"Neck"],
	&"Neck": [HEAD, 0.6, &"Head"],
	&"Head": [HEAD, 1.0, &""],
	&"LeftShoulder": [ARMS, 0.4, &"LeftUpperArm"],
	&"LeftUpperArm": [ARMS, 0.8, &"LeftLowerArm"],
	&"LeftLowerArm": [ARMS, 0.6, &"LeftHand"],
	&"RightShoulder": [ARMS, 0.4, &"RightUpperArm"],
	&"RightUpperArm": [ARMS, 0.8, &"RightLowerArm"],
	&"RightLowerArm": [ARMS, 0.6, &"RightHand"],
}
## The turn (degrees) a unit push gives at its peak to a bone that takes
## all of it, at the contact.
const PEAK_ANGLE: float = 14.0
## How much a blow landing off a bone's line twists it about that line, per
## metre off it.
const TWIST: float = 2.0
## How far from the contact a push reaches: it halves every FALLOFF * ln 2
## metres (m).
const FALLOFF: float = 0.6
## The most any bone is turned by the pushes together (degrees).
const MAX_ANGLE: float = 28.0
## How hard a push is: 1 for a light hit by a medium weapon (the Katana),
## HEAVY times as hard for a heavy, by the attacker's weapon class (its
## weight, as the camera's contact kick goes), and BLOCK_SHARE of that for a
## block.
const HEAVY: float = 1.7
const CLASS_WEIGHT: Dictionary[StringName, float] = {
	&"fists": 0.5, &"small": 0.7, &"medium": 1.0, &"colossal": 1.6,
}
const BLOCK_SHARE: float = 0.45
## The spring (in rules frames): it rings at about OMEGA radians a frame,
## damped by DAMPING, from a kick that shows SNAP of itself at once and
## leaves at KICK_SPEED. NORM scales the response to peak at 1.
const OMEGA: float = 0.2856
const DAMPING: float = 0.1439
const SNAP: float = 0.5
const KICK_SPEED: float = 0.35
## A push is done (and forgotten) this many frames after it lands.
const DONE_AFTER: float = 90.0

## The world's time it is shown at, in rules frames (step + alpha).
var time: float = 0.0

## The pushes under way: {"at": rules frame, "turns": {bone index: Vector3
## rotation vector at the peak (axis times radians), in skeleton space}}.
var _pushes: Array[Dictionary] = []
## Pushes asked for, taken at the next update (they need the pose):
## {"at", "contact", "dir", "strength", "parts", "arms"}.
var _pending: Array[Dictionary] = []

static var _norm: float = 0.0


## The spring's turn `t` rules frames after a unit push: 0 before it, SNAP
## of the peak at once, 1 at its peak a few frames on, a small overshoot
## the other way, and under 3% from half a second on.
static func response(t: float) -> float:
	if t < 0.0:
		return 0.0
	return _raw(t) / _peak()


static func _raw(t: float) -> float:
	var d: float = (KICK_SPEED + DAMPING * SNAP) / OMEGA
	return exp(-DAMPING * t) * (SNAP * cos(OMEGA * t) + d * sin(OMEGA * t))


static func _peak() -> float:
	if _norm <= 0.0:
		var best: float = 0.0
		for i: int in 401:
			best = maxf(best, _raw(10.0 * float(i) / 400.0))
		_norm = best
	return _norm


## How hard a blow pushes: `heavy` or light, by the attacker's weapon class
## (WeaponDef.cls), less for a block.
static func strength(heavy: bool, cls: StringName, block: bool = false) -> float:
	var s: float = float(CLASS_WEIGHT.get(cls, 1.0)) * (HEAVY if heavy else 1.0)
	return s * (BLOCK_SHARE if block else 1.0)


## Pushes the body at world time `at` (rules frames): a blow landing at
## `contact` (skeleton space), driving along `dir` (skeleton space), this
## `strength` (strength()), reaching `parts` (HIT, BLOCK), with `arms` of
## the arms' share (1 in full; less while the fighter's own swing is
## active). Taken at the next update, from the pose then.
func push(at: float, contact: Vector3, dir: Vector3, p_strength: float, parts: int = HIT, arms: float = 1.0) -> void:
	if p_strength <= 0.0 or dir.length() < 1e-6:
		return
	_pending.append({"at": at, "contact": contact, "dir": dir.normalized(), "strength": p_strength, "parts": parts, "arms": arms})


## Forgets every push (a new match, a jump of the playhead).
func clear() -> void:
	_pushes.clear()
	_pending.clear()


## Whether a push is asked for or still moving the body at `time`.
func reacting() -> bool:
	if not _pending.is_empty():
		return true
	for p: Dictionary in _pushes:
		if time - float(p["at"]) < DONE_AFTER:
			return true
	return false


func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	for p: Dictionary in _pending:
		_take(sk, p)
	_pending.clear()
	var kept: Array[Dictionary] = []
	for p: Dictionary in _pushes:
		if time - float(p["at"]) < DONE_AFTER:
			kept.append(p)
	_pushes = kept
	if _pushes.is_empty():
		return
	# every bone's turn now, summed over the pushes
	var turns: Dictionary[int, Vector3] = {}
	for p: Dictionary in _pushes:
		var r: float = response(time - float(p["at"]))
		if r == 0.0:
			continue
		var by_bone: Dictionary = p["turns"]
		for bone: int in by_bone:
			turns[bone] = turns.get(bone, Vector3.ZERO) + (by_bone[bone] as Vector3) * r
	var limit: float = deg_to_rad(MAX_ANGLE)
	# parent first: bones are numbered after their parents
	var order: Array = turns.keys()
	order.sort()
	for bone: int in order:
		var v: Vector3 = turns[bone]
		var angle: float = v.length()
		if angle < 1e-7:
			continue
		BodyLayer.rot_global(sk, bone, Quaternion(v / angle, minf(angle, limit)))


## Turns a push asked for into each bone's turn at its peak, from the pose
## the bones have now.
func _take(sk: Skeleton3D, p: Dictionary) -> void:
	var contact: Vector3 = p["contact"]
	var dir: Vector3 = p["dir"]
	var parts: int = p["parts"]
	var by_bone: Dictionary = {}
	for name: StringName in BONES:
		var part: int = BONES[name][0]
		if parts & part == 0:
			continue
		var bone: int = sk.find_bone(name)
		if bone < 0:
			continue
		var pose: Transform3D = sk.get_bone_global_pose(bone)
		var along: Vector3 = pose.basis.y.normalized()
		var tip: int = sk.find_bone(BONES[name][2])
		if tip >= 0:
			var to_tip: Vector3 = sk.get_bone_global_pose(tip).origin - pose.origin
			if to_tip.length() > 1e-5:
				along = to_tip.normalized()
		var lever: Vector3 = contact - pose.origin
		var off: Vector3 = lever - along * lever.dot(along)
		var turn: Vector3 = along.cross(dir) + along * (TWIST * off.cross(dir).dot(along))
		if turn.length() < 1e-6:
			continue
		var share: float = float(BONES[name][1]) * (float(p["arms"]) if part == ARMS else 1.0)
		var angle: float = deg_to_rad(PEAK_ANGLE) * float(p["strength"]) * share * exp(-lever.length() / FALLOFF)
		if angle > 0.0:
			by_bone[bone] = turn * angle
	if not by_bone.is_empty():
		_pushes.append({"at": float(p["at"]), "turns": by_bone})
