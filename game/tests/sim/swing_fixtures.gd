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
	move = timed(move)
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
	move = timed(move)
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
	move = timed(move)
	var frames: Array[int] = []
	frames.assign(degs.keys())
	frames.sort()
	var keys: Array[Swing.KeyPose] = []
	for f: int in frames:
		keys.append(level_pose(f, height, degs[f], 0.0 if still.has(f) else 1.0, radius))
	var s: Swing = Swing.new(move.total_frames(), {RIGHT: slash_guard()} as Dictionary[StringName, Swing.KeyPose])
	s.add_track(RIGHT, keys)
	return s


## Weapon `id` built afresh with no swing on any move: its swing file's baked
## swings (authored animation, task 9 on) left off, for tests of moves
## without one.
static func without_swings(id: StringName) -> WeaponDef:
	var w: WeaponDef = weapon(id, {} as Dictionary[StringName, Swing])
	for m: AttackDef in w.moves.values():
		m.swing = null
	w.derive_reach()
	return w


## The frames of the moves milestone 1 has re-keyed as they were as
## stand-ins, from the frame-data table before their re-key: [startup, active,
## recovery, dodge cancel [from, to] (empty for none), branches]. Right Cut
## and Return Cut, task 31; Kesa Cut and Crown Cut, task 32; Running Draw,
## Leaping Cleave, Wind Cut and Whirl Cut, task 75.
const STAND_IN_FRAMES: Dictionary = {
	&"k_l1": [11, 3, 16, [20, 30], {&"k_l2": [16, 30], &"k_h2": [16, 30]}],
	&"k_l2": [10, 3, 16, [19, 29], {&"k_l3": [15, 29], &"k_h1f": [15, 29]}],
	&"k_l3": [11, 3, 17, [20, 31], {&"k_l4": [16, 31], &"k_h2": [16, 31]}],
	&"k_l4": [14, 4, 22, [26, 40], {}],
	&"k_sl": [12, 4, 18, [], {}],
	&"k_sh": [20, 5, 26, [38, 51], {}],
	&"k_dl": [9, 3, 16, [18, 28], {}],
	&"k_dh": [18, 6, 24, [36, 48], {}],
}


## The lunges and hops of the moves whose re-key retired them (their records
## no longer have them; the clip's travel leads them): Running Draw and
## Leaping Cleave, Wind Cut and Whirl Cut, task 75.
const STAND_IN_LUNGES: Dictionary = {
	&"k_sl": {"lunge": 1.7, "lunge_end": 15},
	&"k_sh": {"lunge": 2.9, "lunge_start": 4, "lunge_end": 22, "hop": 5.0},
	&"k_dl": {"lunge": 0.5},
	&"k_dh": {"lunge": 0.5},
}


## Makes `m` play as a stand-in, as moves did before their family re-keyed
## them: on stand-in markers with today's hit values (ProtectedTimings),
## lunging by its record (or the lunge its re-key retired, STAND_IN_LUNGES)
## with no travel and a run's speed carried in (AttackDef.by_travel off), on
## the frames it had then (STAND_IN_FRAMES).
static func _as_stand_in(m: AttackDef) -> void:
	if not m.real_markers and not m.by_travel:
		return
	m.real_markers = false
	m.by_travel = false
	m.travel = PackedFloat64Array()
	var t: ProtectedTimings = ProtectedTimings.today()
	m.hitstun = t.hitstun(m.kind, m.id)
	m.blockstun = t.blockstun(m.kind)
	m.hitstop = t.hitstop(m.kind)
	if STAND_IN_FRAMES.has(m.id):
		var f: Array = STAND_IN_FRAMES[m.id]
		m.startup = f[0]
		m.active = f[1]
		m.recovery = f[2]
		m.dodge_cancel_from = f[3][0] if not f[3].is_empty() else AttackDef.UNSET
		m.dodge_cancel_to = f[3][1] if not f[3].is_empty() else AttackDef.UNSET
		m.branches = {}
		for follow: StringName in f[4]:
			m.branches[follow] = PackedInt32Array(f[4][follow])
	if STAND_IN_LUNGES.has(m.id):
		var l: Dictionary = STAND_IN_LUNGES[m.id]
		m.lunge = l["lunge"]
		m.lunge_start = l.get("lunge_start", 0)
		m.lunge_end = l.get("lunge_end", AttackDef.UNSET)
		m.hop = l.get("hop", 0.0)


## `move` as a made-up swing times it: on the frames it had as a stand-in
## where its family has re-keyed it (STAND_IN_FRAMES) and it still has the
## re-key's frames, as weapon() plays it; a move given frames of its own keeps
## them.
static func timed(move: AttackDef) -> AttackDef:
	if not STAND_IN_FRAMES.has(move.id) or not Moves.WEAPONS.has(move.weapon):
		return move
	var keyed: AttackDef = (Moves.WEAPONS[move.weapon] as WeaponDef).moves.get(move.id)
	if keyed == null or [move.startup, move.active, move.recovery] != [keyed.startup, keyed.active, keyed.recovery]:
		return move
	var f: Array = STAND_IN_FRAMES[move.id]
	var m: AttackDef = AttackDef.new()
	m.id = move.id
	m.kind = move.kind
	m.startup = f[0]
	m.active = f[1]
	m.recovery = f[2]
	return m


## Weapon `id` built afresh with its moves `ids` played as stand-ins
## (_as_stand_in()) with no swing (their re-keyed clips' swings don't fit
## their stand-in frames; the cone strikes for them). For the rules tests of
## a stand-in's lunge and carry once the light the light button throws (Right
## Cut, task 31) is re-keyed.
static func stand_ins(id: StringName, ids: Array[StringName]) -> WeaponDef:
	var w: WeaponDef = weapon(id, {} as Dictionary[StringName, Swing])
	for move_id: StringName in ids:
		var m: AttackDef = w.moves[move_id]
		_as_stand_in(m)
		m.swing = null
	w.derive_reach()
	return w


## A fresh copy of weapon `id` (katana, greatsword, daggers or fists) with
## each move of `swings` given its swing, and its reaches derived from them
## (WeaponDef.derive_reach()). A move given a swing here plays as a stand-in
## on the frames it had as one (_as_stand_in()), whatever its family's re-key
## gave it: the swing is made up, not its clip's, as the tests of the swing
## machinery were written for.
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
		var m: AttackDef = w.moves[move_id]
		_as_stand_in(m)
		m.swing = swings[move_id]
	w.derive_reach()
	return w
