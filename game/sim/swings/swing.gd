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

const PARTS: Array[StringName] = [&"right_hand", &"left_hand", &"right_foot", &"left_foot", &"body"]


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
## weapon's blade (bare hands' fist), a foot bare hands' foot; null for the
## body, which doesn't strike, or a foot on a weapon with no kicks.
static func strike_segment(part: StringName, weapon: WeaponDef) -> StrikeSegment:
	match part:
		&"right_hand", &"left_hand":
			return weapon.blade
		&"right_foot", &"left_foot":
			return weapon.foot
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
var _tracks: Dictionary[StringName, Array] = {}
var _ticks: Dictionary[StringName, Array] = {}


func _init(p_last_frame: int = 0, p_guard: Dictionary[StringName, KeyPose] = {}) -> void:
	last_frame = p_last_frame
	guard = p_guard


## Adds the track for `part` (one of PARTS), its keys sorted by frame, and
## works out its poses at every whole frame, entered from the guard.
func add_track(part: StringName, keys: Array[KeyPose]) -> void:
	_tracks[part] = keys
	var ticks: Array[Sample] = []
	for f: int in last_frame + 1:
		ticks.append(SwingSampler.sample(keys, part, float(f), guard.get(part), guard.get(part), last_frame))
	_ticks[part] = ticks


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
	return SwingSampler.sample(track(part), part, t, entry(part, chained_from), guard.get(part), last_frame)
