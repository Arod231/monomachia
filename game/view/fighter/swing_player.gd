class_name SwingPlayer
extends RefCounted
## Plays a move's swing (task 7) on a fighter in the match (plan task 14.10):
## the weapon goes where the rules' swing has it, and the arms reach for it.
## FighterView asks it every frame; it never changes the rules.
##
## - The swing is sampled at the attack's frame as the match shows it: the
##   frame before the last step plus the host's alpha (AttackState.frame - 1
##   + alpha), so it moves between steps as the fighter's position does, and
##   holds still in hit-stop (alpha 1) and through a charge (the attack's
##   frame stands still: the frame itself, as the rules' blade holds it).
##   A follow-up enters from the hand-off of the move it follows, as the
##   rules' does (AttackState.chained_from).
## - Each hand track places a held weapon in skeleton space from its grip,
##   blade and edge: the right hand the weapon (the first of a pair), the
##   left hand the second of a pair. A two-handed weapon's off hand grips its
##   off-hand grip on the rig, as the rules' swing check seats it. A held
##   weapon with no track (one dagger of a swing that moves only the other)
##   stays on the stand-in pose.
## - The key's elbow-pole tweak goes on the rig (FighterRig.pole_tweak), as
##   the swing check bends the elbow.
## - The root stays where the rules put the fighter: the view never adds its
##   own lunge or turn, so the weapon shown is the weapon that hits.
## Moves without a swing, and moves of another moveset than the held
## weapon's, play from StickPose as before.
##
## Chains, entries and exits (plan task 14.11):
## - A weapon with swings stands in its swings' guard (guard_poses()), riding
##   the stance and the lean as the stand-in's guard does; every swing
##   enters from that guard, or from the hand-off of the move it follows,
##   and runs its exit back to it on its last frame.
## - Whenever what poses the weapons changes (a swing starts, a follow-up
##   takes over, a swing ends or is cut off), the poses shown blend from
##   where they were shown last into the new ones over BLEND_FRAMES rules
##   frames: the gap between the two, worked out where the new poses were
##   when the last ones showed, closes as the new poses move on their own,
##   so nothing jumps and a swing's own motion is kept. A gap of nothing,
##   as when an opener starts from the guard it stands in, changes nothing.
##   The blend holds in hit-stop, as the rules' clock does.
##
## The body (plan task 14.12), from the swing's body track (body()):
## - the pelvis coil turns the hips and the torso coil the chest, as the
##   swing check's reference body turns them, and the pelvis shift moves the
##   hips (the weight going over the rear foot in the wind-up and forward
##   into the cut). The keys' ease-0 holds make the cocked hold;
## - the hips lead the chest and the chest leads the arms: the pelvis is
##   sampled PELVIS_LEAD frames ahead of the weapon, the chest CHEST_LEAD, so
##   the turn ripples from the hips out to the blade, which arrives last and
##   stays exactly the rules';
## - the head turns back against the chest by HEAD_COUNTER, to keep the eyes
##   on the opponent;
## - the pelvis dips DIP at the first active frame, easing in and out over
##   DIP_FRAMES either side;
## - the swing's body takes over from the guard stance's turns, lean and
##   lowered pelvis over BLEND_FRAMES as a swing starts, and hands back over
##   as many after it ends, so the body a swing moves is the reference body
##   its swing was checked on; the stance's feet stay planted, and its sink
##   still lowers the pelvis as far as the legs need to reach them.
##
## Swings are in the fighter's own (right, up, forward) frame; skeleton space
## is +X to the fighter's left, +Y up, +Z forward, so a swing's x turns round.

## The hand track that places each held weapon, by its index.
const TRACKS: Array[StringName] = [&"right_hand", &"left_hand"]
## The rig's side for each hand track.
const SIDES: Dictionary[StringName, String] = {&"right_hand": "Right", &"left_hand": "Left"}
## How many rules frames a change of what poses the weapons takes to blend.
const BLEND_FRAMES: float = 4.0
## How many frames ahead of the weapon the pelvis and the chest are sampled.
const PELVIS_LEAD: float = 2.0
const CHEST_LEAD: float = 1.0
## How much of the chest's turn the head turns back.
const HEAD_COUNTER: float = 0.85
## How far the pelvis dips at the first active frame (m), and over how many
## frames either side it eases in and out.
const DIP: float = 0.05
const DIP_FRAMES: float = 4.0


## A swing's body at one moment, and how far it shows.
class Body:
	## How far the swing's body shows over the stance's (0 to 1).
	var weight: float = 0.0
	## The pelvis's and the torso's coil, in degrees, positive toward the
	## fighter's right (as the swing keys them).
	var pelvis: float = 0.0
	var torso: float = 0.0
	## How far the hips move, in skeleton space (m): the pelvis shift and the
	## dip.
	var shift: Vector3 = Vector3.ZERO

	## Lays this body on `layer` at its weight, on top of what it has: the
	## hips turned by the pelvis's coil, the spine turned on to the torso's,
	## the head turned back against the chest, the hips moved.
	func apply(layer: BodyLayer) -> void:
		var hips: float = -deg_to_rad(pelvis)
		var chest: float = -deg_to_rad(torso)
		layer.pelvis_yaw += hips * weight
		layer.spine_yaw += (chest - hips) * weight
		layer.head_yaw -= HEAD_COUNTER * chest * weight
		layer.hips_offset += shift * weight

	func copy() -> Body:
		var b: Body = Body.new()
		b.weight = weight
		b.pelvis = pelvis
		b.torso = torso
		b.shift = shift
		return b


## What posed the weapons last: the attack whose swing played, or null for
## anything else.
var _source: AttackState = null
## The weapons' poses shown last, by index, and the match time they showed
## at (the world's frame plus alpha; -1 before the first).
var _shown: Dictionary[int, Transform3D] = {}
var _time: float = -1.0
var _world: World = null
## The gap being blended out, by weapon index: [the grip's (Vector3), the
## turn's (Quaternion)], and the match time it opened at.
var _gaps: Dictionary[int, Array] = {}
var _gap_time: float = 0.0
## The swing's body shown last (held as it hands back to the stance), how far
## it showed (before easing), and the match time and world it showed at.
var _body: Body = Body.new()
var _body_share: float = 0.0
var _body_time: float = -1.0
var _body_world: World = null


## A point or direction from the fighter's (right, up, forward) frame into
## skeleton space.
static func to_skeleton(v: V3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Whether fighter `f` plays a swing now: attacking with a move of its own
## moveset that has a swing.
static func plays(f: Fighter) -> bool:
	if f.state != &"attack" or f.atk == null or f.atk.def.swing == null:
		return false
	return f.moveset().moves.get(f.atk.def.id) == f.atk.def


## The attack's frame as the match shows it, `alpha` (MatchHost.alpha()) of
## the way from the step before to the last: frame - 1 + alpha, from 0; the
## frame itself while charging, where the rules hold the swing.
static func swing_frame(f: Fighter, alpha: float) -> float:
	if f.atk.charging:
		return float(f.atk.frame)
	return maxf(0.0, float(f.atk.frame) - 1.0 + alpha)


## The swing of the move fighter `f`'s attack follows, or null on a fresh
## start.
static func chained_swing(f: Fighter) -> Swing:
	return f.atk.chained_from.swing if f.atk.chained_from != null else null


## The pose of `part` of fighter `f`'s swing at frame `t`, entered as the
## rules enter it; null when the swing has no such track.
static func sample(f: Fighter, part: StringName, t: float) -> Swing.Sample:
	return f.atk.def.swing.sample(part, t, chained_swing(f))


## A weapon's transform in skeleton space for a hand track's sample (see
## FighterRig.weapon_frame()).
static func weapon_transform(s: Swing.Sample) -> Transform3D:
	return FighterRig.weapon_frame(to_skeleton(s.grip), to_skeleton(s.blade), to_skeleton(s.edge))


## The poses of fighter `f`'s held weapons now, by index, for a model holding
## `count` weapons (two for a pair): each from its hand track, at the frame
## swing_frame() gives for `alpha`. A weapon with no track is left out. Puts
## each track's elbow-pole tweak on `rig` (none for a hand without one).
static func weapon_poses(f: Fighter, alpha: float, count: int, rig: FighterRig) -> Dictionary[int, Transform3D]:
	rig.clear_pole_tweaks()
	var out: Dictionary[int, Transform3D] = {}
	var t: float = swing_frame(f, alpha)
	for i: int in mini(count, TRACKS.size()):
		var s: Swing.Sample = sample(f, TRACKS[i], t)
		if s == null:
			continue
		out[i] = weapon_transform(s)
		rig.pole_tweak[SIDES[TRACKS[i]]] = to_skeleton(s.pole)
	return out


## The body of fighter `f`'s swing at frame `t` (weight 1): the pelvis
## PELVIS_LEAD and the chest CHEST_LEAD frames ahead, and the dip. A swing
## with no body track only dips.
static func body_at(f: Fighter, t: float) -> Body:
	var b: Body = Body.new()
	b.weight = 1.0
	var hips: Swing.Sample = sample(f, &"body", t + PELVIS_LEAD)
	var chest: Swing.Sample = sample(f, &"body", t + CHEST_LEAD)
	if hips != null:
		b.pelvis = hips.pelvis
		b.shift = to_skeleton(hips.pelvis_shift)
	if chest != null:
		b.torso = chest.torso
	b.shift.y -= dip(f.atk.def, t)
	return b


## How far the pelvis dips at frame `t` of move `def` (m): DIP at its first
## active frame, easing to nothing DIP_FRAMES either side.
static func dip(def: AttackDef, t: float) -> float:
	var off: float = absf(t - float(def.startup + 1))
	if off >= DIP_FRAMES:
		return 0.0
	return DIP * 0.5 * (1.0 + cos(PI * off / DIP_FRAMES))


## The swing's body to show for fighter `f` now, `alpha` of the way from the
## step before to the last: while it plays a swing, that swing's body
## (body_at()), its weight rising over BLEND_FRAMES from where it was; after,
## the last one, its weight falling as fast. Eased in and out.
func body(f: Fighter, alpha: float) -> Body:
	var time: float = (float(f.world.frame) if f.world != null else 0.0) + alpha
	if f.world != _body_world or time < _body_time:
		_body_share = 0.0
		_body_time = time
	var dt: float = (time - _body_time) / BLEND_FRAMES
	if plays(f):
		_body = body_at(f, swing_frame(f, alpha))
		_body_share = minf(1.0, _body_share + dt)
	else:
		_body_share = maxf(0.0, _body_share - dt)
	_body_time = time
	_body_world = f.world
	var out: Body = _body.copy()
	out.weight = smoothstep(0.0, 1.0, _body_share)
	return out


## The guard of weapon `w`'s hand-keyed swings (shared by all of them), or
## empty when it has none.
static func guard_of(w: WeaponDef) -> Dictionary[StringName, Swing.KeyPose]:
	for m: AttackDef in w.moves.values():
		# a baked swing's guard is only its file's (authored-animation task 9),
		# a pose-only one's too (task 13): the free state keeps the stand-in
		# guard until the stances are authored
		if m.swing != null and m.swing.clips.is_empty() and not m.swing.is_baked(&"right_hand") and not m.swing.is_baked(&"left_hand"):
			return m.swing.guard
	return {} as Dictionary[StringName, Swing.KeyPose]


## The poses of the held weapons in weapon `w`'s swings' guard, by index,
## for a model holding `count` weapons; empty when it has no swings, and
## without a weapon whose hand the guard doesn't pose.
static func guard_poses(w: WeaponDef, count: int) -> Dictionary[int, Transform3D]:
	var out: Dictionary[int, Transform3D] = {}
	var guard: Dictionary[StringName, Swing.KeyPose] = guard_of(w)
	for i: int in mini(count, TRACKS.size()):
		var k: Swing.KeyPose = guard.get(TRACKS[i])
		if k != null:
			out[i] = FighterRig.weapon_frame(to_skeleton(k.grip), to_skeleton(k.blade), to_skeleton(k.edge))
	return out


## The poses to show for fighter `f`'s held weapons, by index, given the ones
## it should hold now (`poses`: from its swing, or anything else), `alpha`
## of the way from the step before to the last: `poses`, with the gap from
## what was shown before blended out when what poses them has changed (see
## the class notes). A new world shows `poses` as they are.
func show(f: Fighter, alpha: float, poses: Dictionary[int, Transform3D]) -> Dictionary[int, Transform3D]:
	var source: AttackState = f.atk if plays(f) else null
	var time: float = (float(f.world.frame) if f.world != null else 0.0) + alpha
	if f.world != _world or time < _time:
		_shown.clear()
		_gaps.clear()
	elif source != _source:
		_open_gaps(f, alpha, poses, source != null, time - _time)
	var k: float = 0.0
	if not _gaps.is_empty():
		k = 1.0 - smoothstep(0.0, 1.0, (time - _gap_time) / BLEND_FRAMES)
		if k <= 0.0:
			_gaps.clear()
	var out: Dictionary[int, Transform3D] = {}
	for i: int in poses:
		var xf: Transform3D = poses[i]
		if k > 0.0 and _gaps.has(i):
			var turn: Quaternion = Quaternion.IDENTITY.slerp(_gaps[i][1], k)
			xf = Transform3D(Basis(turn * xf.basis.get_rotation_quaternion()), xf.origin + (_gaps[i][0] as Vector3) * k)
		out[i] = xf
	_shown = out.duplicate()
	_source = source
	_time = time
	_world = f.world
	return out


## Opens a gap per weapon shown before: from where the new poses were when
## the last ones showed (`back` match frames ago: a swing's own pose then,
## else the new poses now) to what showed.
func _open_gaps(f: Fighter, alpha: float, poses: Dictionary[int, Transform3D], swung: bool, back: float) -> void:
	_gaps.clear()
	_gap_time = _time
	var then: Dictionary[int, Transform3D] = poses
	if swung:
		then = {}
		var t: float = maxf(0.0, swing_frame(f, alpha) - back)
		for i: int in poses:
			var s: Swing.Sample = sample(f, TRACKS[i], t) if i < TRACKS.size() else null
			then[i] = weapon_transform(s) if s != null else poses[i]
	for i: int in poses:
		if not _shown.has(i):
			continue
		var was: Transform3D = _shown[i]
		var q: Quaternion = was.basis.get_rotation_quaternion() * then[i].basis.get_rotation_quaternion().inverse()
		_gaps[i] = [was.origin - then[i].origin, q.normalized()]


## True when no gap is being blended out.
func settled() -> bool:
	return _gaps.is_empty()
