extends RefCounted
## Synthetic swings for the rule tests (task 7.9 on): keys built by hand, and
## fresh weapons that carry them, so the shared weapons in Moves stay as they
## are. Positions and directions are (right, up, forward) from the fighter's
## feet, as Swing takes them.

const RIGHT: StringName = &"right_hand"


static func _v(a: Array) -> V3:
	return V3.make(a[0], a[1], a[2])


## A hand or foot key at `frame`: the grip, and the blade's and the edge's
## directions (give the edge square to the blade; both are normalized here).
static func key(frame: int, grip: Array, blade: Array, edge: Array, ease: float = 1.0) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.grip = _v(grip)
	k.blade = V3.normalized(_v(blade))
	k.edge = V3.normalized(_v(edge))
	k.ease = ease
	return k


## A body key at `frame`: the torso's and the pelvis's coil, in degrees.
static func body_key(frame: int, torso: float, pelvis: float, ease: float = 1.0) -> Swing.KeyPose:
	var k: Swing.KeyPose = Swing.KeyPose.new()
	k.frame = frame
	k.torso = torso
	k.pelvis = pelvis
	k.ease = ease
	return k


## A copy of `k` at `frame`.
static func _at(k: Swing.KeyPose, frame: int) -> Swing.KeyPose:
	var c: Swing.KeyPose = Swing.KeyPose.new()
	c.frame = frame
	c.grip = k.grip
	c.blade = k.blade
	c.edge = k.edge
	c.pole = k.pole
	c.torso = k.torso
	c.pelvis = k.pelvis
	c.pelvis_shift = k.pelvis_shift
	c.ease = k.ease
	return c


## A swing for `move` that holds each part of `poses` still from start to
## finish: its guard, its keys and so its entry and exit are all that pose.
static func held(move: AttackDef, poses: Dictionary[StringName, Swing.KeyPose]) -> Swing:
	var guard: Dictionary[StringName, Swing.KeyPose] = {}
	for part: StringName in poses:
		guard[part] = _at(poses[part], 0)
	var s: Swing = Swing.new(move.total_frames(), guard)
	for part: StringName in poses:
		s.add_track(part, [_at(poses[part], 0), _at(poses[part], move.total_frames())] as Array[Swing.KeyPose])
	return s


## The guard the level slashes start from and go back to: the right hand
## low in front, the blade forward and up, the edge down.
static func slash_guard() -> Swing.KeyPose:
	return key(0, [0.15, 1.1, 0.35], [0.0, 0.6, 0.8], [0.0, -0.8, 0.6])


## The right hand's pose on a level slash at `height`, `deg` round from
## straight ahead toward the fighter's right: the grip `radius` out from
## between the feet, the blade pointing straight out and the edge leading
## toward the left.
static func level_pose(frame: int, height: float, deg: float, ease: float = 1.0, radius: float = 0.45) -> Swing.KeyPose:
	var a: float = deg * SimMath.DEG
	var s: float = JsMath.sin(a)
	var c: float = JsMath.cos(a)
	return key(frame, [radius * s, height, radius * c], [s, 0.0, c], [-c, 0.0, s], ease)


## A level right-to-left slash for `move` at `height` (from 60° right to 60°
## left; give `from_deg` and `to_deg` the other way round for left to right):
## keyed on every frame from the last of the startup through the last active
## one, so its blade is exactly level at each of them, cocked 4 frames
## before and settling 20° on, 4 frames after. It enters from slash_guard()
## and goes back to it. The grip is `radius` out (a Katana's tip 0.78 m
## further).
static func level_slash(move: AttackDef, height: float = 1.2, from_deg: float = 60.0, to_deg: float = -60.0,
		radius: float = 0.45) -> Swing:
	var S: int = move.startup
	var A: int = move.active
	var degs: Dictionary[int, float] = {maxi(S - 4, 0): from_deg}
	for i: int in A + 1:
		degs[S + i] = from_deg + (to_deg - from_deg) * i / A
	degs[mini(S + A + 4, move.total_frames())] = to_deg + signf(to_deg - from_deg) * 20.0
	return level_swing(move, height, degs, radius, [maxi(S - 4, 0), mini(S + A + 4, move.total_frames())])


## A level swing for `move` at `height`: the right hand keyed at each frame of
## `degs` at its angle (see level_pose()), with ease 0 at the frames of
## `still` and 1 elsewhere, entering from slash_guard() and going back to it.
static func level_swing(move: AttackDef, height: float, degs: Dictionary[int, float], radius: float = 0.45,
		still: Array[int] = []) -> Swing:
	var frames: Array[int] = []
	frames.assign(degs.keys())
	frames.sort()
	var keys: Array[Swing.KeyPose] = []
	for f: int in frames:
		keys.append(level_pose(f, height, degs[f], 0.0 if still.has(f) else 1.0, radius))
	var s: Swing = Swing.new(move.total_frames(), {RIGHT: slash_guard()} as Dictionary[StringName, Swing.KeyPose])
	s.add_track(RIGHT, keys)
	return s


## A fresh copy of weapon `id` (katana, greatsword, daggers or fists) with
## each move of `swings` given its swing, and its reaches derived from them
## (WeaponDef.derive_reach()).
## Weapon `id` built afresh with no swing on any move: its swing file's baked
## swings (authored animation, task 9 on) left off, for tests of moves
## without one.
static func without_swings(id: StringName) -> WeaponDef:
	var w: WeaponDef = weapon(id, {} as Dictionary[StringName, Swing])
	for m: AttackDef in w.moves.values():
		m.swing = null
	w.derive_reach()
	return w


static func weapon(id: StringName, swings: Dictionary[StringName, Swing]) -> WeaponDef:
	var w: WeaponDef
	match id:
		&"katana":
			w = KatanaMoves.build()
		&"greatsword":
			w = GreatswordMoves.build()
		&"daggers":
			w = DaggersMoves.build()
		&"fists":
			w = FistsMoves.build()
	for move_id: StringName in swings:
		(w.moves[move_id] as AttackDef).swing = swings[move_id]
	w.derive_reach()
	return w
