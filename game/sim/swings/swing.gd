class_name Swing
extends RefCounted
## A move's swing (task 7): the path its weapon travels through the move, as
## key poses in the fighter's own space. The same path will decide hits and
## drive the animation. Swings are read from the per-weapon files under
## game/sim/moves/swings/ (see SwingFile) into AttackDef.swing.
##
## A swing holds tracks, one per part of the body that it moves (PARTS), and
## each track holds keys sorted by frame. Frames count as AttackState.frame
## does: 0 when the move starts, up to the move's total frames.
## - A hand track moves a weapon (or a fist): each key holds the grip and the
##   weapon's orientation, its blade (weapon +Y) and its edge (weapon +X),
##   plus an optional tweak of the elbow's pole. A bare hand's fist has a
##   weapon's frame (see WeaponLook). A foot track moves a foot the same way:
##   its grip is the ankle, its blade runs along the foot toward the toes and
##   its edge out of the sole (forward and down when standing), and its pole
##   is the knee's. What each track strikes with is the weapon's
##   StrikeSegment (WeaponDef.blade and .foot), in that frame.
## - The body track holds the torso and pelvis coil and the pelvis shift.
## Positions and directions are (right, up, forward) from the fighter's feet,
## as SimMath.local_to_world takes them. A key's ease scales the speed through
## it: 0 stops there (a cocked hold, a settle), 1 is the even default.
##
## A track's keys are the move's main path, ending on its hand-off key. Around
## them (task 7.4):
## - the entry runs from frame 0 to the first key: from the weapon's guard on
##   a fresh start, or from the hand-off key of the move this one follows;
## - the exit runs from the hand-off key back to the guard on the last frame.
## The main path's splines use its own keys only, so it is the same whatever
## the entry, and SwingFile has each striking track key every frame that can
## hit. A swing built without a guard (tests) holds its first and last keys.
##
## SwingSampler gives a track's pose between keys. Each track's poses at the
## whole frames 0 to last_frame, entered from the guard, are worked out once,
## when it is added, and tick() reads them.
##
## A baked track (authored-animation task 6: SwingBake, from a clip) keys
## every frame from 0 to last_frame, so it has no entry or exit: each frame's
## pose is its key, and between frames the poses are blended in a straight
## line (the blade and edge turned between the two), never splined.

## A bash strikes with a shoulder (authored-animation task 19): its track's
## grip is the shoulder joint, its blade the way out along the shoulder line
## and its edge forward (SimConst.SHOULDER_STRIKE_*). A knee strike strikes
## with a knee (task 25): its grip is the knee joint, its blade the way down
## the shin and its edge the shin's front (SimConst.KNEE_STRIKE_*).
const PARTS: Array[StringName] = [&"right_hand", &"left_hand", &"right_foot", &"left_foot", &"right_shoulder", &"left_shoulder", &"right_knee", &"left_knee", &"body"]


## One key pose of a track. Hand and foot keys use frame, grip, blade, edge,
## pole and ease; body keys use frame, torso, pelvis, pelvis_shift and ease.
class KeyPose:
	var frame: int = 0
	## the grip, metres (right, up, forward) from the fighter's feet
	var grip: V3 = V3.make()
	## the blade's direction, unit length
	var blade: V3 = V3.make(0.0, 1.0, 0.0)
	## the edge's direction, unit length and square to the blade
	var edge: V3 = V3.make(1.0, 0.0, 0.0)
	## added to the elbow's (or knee's) default pole direction
	var pole: V3 = V3.make()
	## coil about the spine in degrees, positive turning toward the fighter's right
	var torso: float = 0.0
	var pelvis: float = 0.0
	## metres (right, up, forward) the pelvis moves from its rest
	var pelvis_shift: V3 = V3.make()
	## speed through the key: 0 stops there, 1 is even
	var ease: float = 1.0


## A track's pose at one moment, from SwingSampler. Hand and foot tracks fill
## grip, blade, edge and pole; the body track torso, pelvis and pelvis_shift.
class Sample:
	var grip: V3 = V3.make()
	var blade: V3 = V3.make(0.0, 1.0, 0.0)
	var edge: V3 = V3.make(1.0, 0.0, 0.0)
	var pole: V3 = V3.make()
	var torso: float = 0.0
	var pelvis: float = 0.0
	var pelvis_shift: V3 = V3.make()

	## The point `p`, given in the frame of the part the track moves (a
	## weapon's, a fist's or a foot's: +X the edge, +Y the blade, +Z out of the
	## flat; see StrikeSegment), in the fighter's space (task 7.9). The flat,
	## X cross Y in Godot's axes, is blade cross edge in (right, up, forward).
	func place(p: V3) -> V3:
		var flat: V3 = V3.cross(blade, edge)
		return V3.add(grip, V3.add(V3.add(V3.scale(edge, p.x), V3.scale(blade, p.y)), V3.scale(flat, p.z)))


## What the track for `part` strikes with on `weapon` (task 7.9): a hand the
## weapon's blade (bare hands' fist), a foot bare hands' foot, a shoulder the
## bash's shoulder on any weapon, a knee the knee and shin on any weapon; null
## for the body, which doesn't strike, or a foot on a weapon with no kicks.
static func strike_segment(part: StringName, weapon: WeaponDef) -> StrikeSegment:
	match part:
		&"right_hand", &"left_hand":
			return weapon.blade
		&"right_foot", &"left_foot":
			return weapon.foot
		&"right_shoulder", &"left_shoulder":
			return StrikeSegment.make(V3.make(0.0, SimConst.SHOULDER_STRIKE_BASE, 0.0),
				V3.make(0.0, SimConst.SHOULDER_STRIKE_TIP, 0.0), SimConst.SHOULDER_STRIKE_THICKNESS)
		&"right_knee", &"left_knee":
			return StrikeSegment.make(V3.make(0.0, SimConst.KNEE_STRIKE_BASE, 0.0),
				V3.make(0.0, SimConst.KNEE_STRIKE_TIP, 0.0), SimConst.KNEE_STRIKE_THICKNESS)
	return null


## The move's last frame (its total frames): the tables run from 0 to it.
var last_frame: int = 0
## The weapon's guard: a pose (frame and ease unused) for each part its swings
## move, shared by all of them.
var guard: Dictionary[StringName, KeyPose] = {}
## How far the blade reaches and how wide it sweeps through the active
## frames (m from the feet, without the lunge, and degrees; task 7.13), from
## SwingReach when the weapon is built; -1 until then. AttackDef.reach() and
## .reach_arc() read them.
var reach: float = -1.0
var arc: float = -1.0
## A baked swing's reach correction (authored-animation task 7, SwingBake):
## how far its striking tracks' grips were pushed toward the reach rule
## (metres, right, up, forward; at most 15 cm), already in their keys. It
## eases in over the startup and out over the recovery (reach_weight()); the
## view plays the same push, moving the body above the hips.
var reach_offset: V3 = V3.make()
## The startup and the active frames, which reach_weight() eases by (set by
## SwingFile from the move).
var reach_startup: int = 0
var reach_active: int = 0
## True when the Rogue's HumanF clip strays more than 5 cm from this path in
## the active frames, so she plays the Hunter's HumanM clip for it.
var rogue_humanm: bool = false
## What a baked swing was baked from, for the view to play the same clip on
## the same frames (ClipDirector): the clips (clip-manifest ids, played one
## after another, each maybe part of one: ClipChain), the speed (times their
## 30 fps), the four markers in source frames from the chain's start
## (ClipManifest.MARKERS' order) and a fifth, the hold, for a move whose
## clip holds while it charges (ClipTiming), and the committed CC0 clip
## played without the Iglesias packs (empty for none). Empty for a
## hand-keyed swing.
var clips: Array[StringName] = []
var speed: float = 1.0
var marks: PackedFloat64Array = PackedFloat64Array()
var fallback: StringName = &""
## The attack frames the blade spends in the saya (the Iai's sheathe and
## stance, task 11), first and last: the view shows it there and no hand
## holds it; empty for none. Always before the active frames.
var sheathed: PackedInt32Array = PackedInt32Array()
var _tracks: Dictionary[StringName, Array] = {}
var _ticks: Dictionary[StringName, Array] = {}
var _baked: Dictionary[StringName, bool] = {}


func _init(p_last_frame: int = 0, p_guard: Dictionary[StringName, KeyPose] = {}) -> void:
	last_frame = p_last_frame
	guard = p_guard


## Adds the track for `part` (one of PARTS), its keys sorted by frame, and
## works out its poses at every whole frame, entered from the guard. A baked
## track's keys are one per frame, 0 to last_frame (SwingFile checks them).
func add_track(part: StringName, keys: Array[KeyPose], baked: bool = false) -> void:
	_tracks[part] = keys
	_baked[part] = baked
	var ticks: Array[Sample] = []
	for f: int in last_frame + 1:
		if baked:
			ticks.append(held(keys[mini(f, keys.size() - 1)]))
		else:
			ticks.append(SwingSampler.sample(keys, part, float(f), guard.get(part), guard.get(part), last_frame))
	_ticks[part] = ticks


## A key's own pose, as a sample: a baked track's frames. (Here rather
## than SwingSampler's, so building a weapon with baked swings while the
## scripts load needs no other script.)
static func held(k: KeyPose) -> Sample:
	var out: Sample = Sample.new()
	out.grip = k.grip
	out.blade = k.blade
	out.edge = k.edge
	out.pole = k.pole
	out.torso = k.torso
	out.pelvis = k.pelvis
	out.pelvis_shift = k.pelvis_shift
	return out


## Whether the blade is in the saya on attack frame `f` (sheathed).
func is_sheathed(f: float) -> bool:
	return sheathed.size() == 2 and f >= float(sheathed[0]) and f <= float(sheathed[1])


## Whether the track for `part` was baked from a clip.
func is_baked(part: StringName) -> bool:
	return _baked.get(part, false)


## How much of the reach correction is on at frame `f` (0 to 1): none on
## frame 0, easing in to all of it on the last startup frame, all of it
## through the active frames, and easing out to none on the last frame.
func reach_weight(f: float) -> float:
	return reach_weight_at(f, reach_startup, reach_active, last_frame)


## The reach correction at frame `f` (reach_offset times reach_weight()).
func reach_at(f: float) -> V3:
	return V3.scale(reach_offset, reach_weight(f))


## reach_weight() for a move of these frames.
static func reach_weight_at(f: float, startup: int, active: int, last: int) -> float:
	if f <= 0.0 or f >= float(last):
		return 0.0
	if f < float(startup):
		return smoothstep(0.0, float(startup), f)
	if f <= float(startup + active):
		return 1.0
	return 1.0 - smoothstep(float(startup + active), float(last), f)


## The parts this swing has tracks for, in the order they were added.
func parts() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_tracks.keys())
	return out


## The keys of the track for `part`, or none.
func track(part: StringName) -> Array[KeyPose]:
	if not _tracks.has(part):
		return [] as Array[KeyPose]
	return _tracks[part]


## The hand-off key of `part`: the last key of its track, where a move that
## follows this one enters from. Null when the swing has no such track.
func hand_off(part: StringName) -> KeyPose:
	if not _tracks.has(part):
		return null
	return _tracks[part][-1]


## Where `part` enters from: the hand-off key of `chained_from` (the swing
## of the move this one follows) when it has that part, else the guard's pose.
func entry(part: StringName, chained_from: Swing = null) -> KeyPose:
	if chained_from != null and chained_from.hand_off(part) != null:
		return chained_from.hand_off(part)
	return guard.get(part)


## The pose of `part` at the whole frame `frame`, entered from the guard or,
## following another move, from `chained_from`: from the table, apart from a
## chained entry's frames, which are sampled. Frames past the last hold its
## pose, as do frames before 0. Null when the swing has no such track.
## Shared: don't change it.
func tick(part: StringName, frame: int, chained_from: Swing = null) -> Sample:
	if not _ticks.has(part):
		return null
	var f: int = clampi(frame, 0, last_frame)
	var from: KeyPose = entry(part, chained_from)
	if from != guard.get(part) and f < track(part)[0].frame:
		return SwingSampler.sample(track(part), part, float(f), from, guard.get(part), last_frame)
	return _ticks[part][f]


## The pose of `part` at frame `t`, which may fall between frames (for
## drawing between steps), entered as tick() says. Null when the swing has no
## such track.
func sample(part: StringName, t: float, chained_from: Swing = null) -> Sample:
	if not _tracks.has(part):
		return null
	if _baked[part]:
		return _between(part, t)
	return SwingSampler.sample(track(part), part, t, entry(part, chained_from), guard.get(part), last_frame)


## A baked track's pose at frame `t`: the two frames either side blended in
## a straight line, the blade and edge turned between them and squared.
func _between(part: StringName, t: float) -> Sample:
	var ticks: Array = _ticks[part]
	var c: float = clampf(t, 0.0, float(last_frame))
	var i: int = mini(floori(c), last_frame - 1) if last_frame > 0 else 0
	var s: float = c - float(i)
	var a: Sample = ticks[i]
	if s <= 0.0 or last_frame == 0:
		return a
	var b: Sample = ticks[i + 1]
	var out: Sample = Sample.new()
	out.grip = V3.lerp(a.grip, b.grip, s)
	out.pole = V3.lerp(a.pole, b.pole, s)
	out.torso = lerpf(a.torso, b.torso, s)
	out.pelvis = lerpf(a.pelvis, b.pelvis, s)
	out.pelvis_shift = V3.lerp(a.pelvis_shift, b.pelvis_shift, s)
	out.blade = V3.normalized(V3.lerp(a.blade, b.blade, s))
	if V3.length(out.blade) < 1e-9:
		out.blade = a.blade
	var edge: V3 = V3.lerp(a.edge, b.edge, s)
	var square: V3 = V3.sub(edge, V3.scale(out.blade, V3.dot(edge, out.blade)))
	out.edge = V3.normalized(square) if V3.length(square) > 1e-9 else a.edge
	return out
