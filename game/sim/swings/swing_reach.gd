class_name SwingReach
extends RefCounted
## Reach and arc derived from a move's swing (task 7.13), worked out once
## when the weapon is built (WeaponDef.derive_reach()) and kept on the swing,
## so the computer opponent and the move list read the real blade's reach
## from the moment a move has a swing. AttackDef.reach() and .reach_arc()
## give them, or the authored range and arc for a move without one.
## - Reach: how far the blade reaches across the ground from the fighter's
##   feet through the active frames, plus half the thickness its sweep tests,
##   without the lunge: the demo's meaning of a move's range (from the
##   attacker's centre to the target's surface).
## - Arc: twice the blade's widest bearing from the facing through the active
##   frames, so 360 for a blade that passes behind, as a spin's does.
## The active frames' sweeps run from the blade at the last frame of the
## startup to the last active frame, each end in a straight line between
## ticks (see BladeSweep), so their furthest and widest points are corners of
## the ticks' segments, unless a sweep passes behind the fighter.


## Where a move's swing touches a defender on one tick (first_contact(),
## touches()).
class Contact:
	## the attack frame of the touch
	var frame: int = 0
	## how far inside the defender's capsule its blade went deepest that tick
	## (BladeSweep.depth)
	var depth: float = 0.0
	## the most blade inside the capsule at any moment of the tick
	## (BladeSweep.length_inside), which the reach tests measure (task 7.14)
	var length_inside: float = 0.0


## A strike part shorter than this (m) is measured by how deep it goes
## rather than how much of it is inside (inside()): the reach rule's 15-20 cm
## of blade can't fit along a fist's knuckles (bare hands, authored-animation
## task 24).
const SHORT_PART: float = 0.15


## How far touch `c` of `weapon`'s main strike part went in, as the reach
## rule reads it: the most blade inside the defender, or for a part shorter
## than SHORT_PART (a fist across its knuckles) how deep it went.
static func inside(c: Contact, weapon: WeaponDef) -> float:
	return c.depth if measures_depth(weapon) else c.length_inside


## Whether `weapon`'s main strike part (its blade, or bare hands' fist) is
## shorter than SHORT_PART.
static func measures_depth(weapon: WeaponDef) -> bool:
	return weapon.blade != null and V3.length(V3.sub(weapon.blade.tip, weapon.blade.base)) < SHORT_PART


## Where `def`'s swing on `weapon` first touches a defender with `body`
## standing `distance` m away (centre to centre, at least the fighters' two
## radii) at `bearing` degrees to the right of the attacker's facing, the
## attack started from standing: the attack frame of the first tick on which
## its blades' sweeps touch the defender's hurt capsule, of those that check
## for hits (World.checks_frame()), and how deep, or null for none. It plays
## the attacker as Fighter does, each frame: the lunge along the facing
## (stopping with the bodies 0.25 m apart), then the turn toward the defender
## at the move's tracking rates, then the blades. A hop, an air attack and a
## lunge along the dodge are played on the ground along the facing.
static func first_contact(def: AttackDef, weapon: WeaponDef, distance: float, bearing: float, body: FighterBody) -> Contact:
	var found: Array[Contact] = _play(def, weapon, distance, bearing, body, true)
	return null if found.is_empty() else found[0]


## Every tick on which `def`'s swing touches the defender, played as
## first_contact() plays it (task 7.14), in order: on each tick that checks
## for hits, the deepest touch of its striking tracks. The game stops
## checking after a hit; this goes on through the active frames.
static func touches(def: AttackDef, weapon: WeaponDef, distance: float, bearing: float, body: FighterBody) -> Array[Contact]:
	return _play(def, weapon, distance, bearing, body, false)


static func _play(def: AttackDef, weapon: WeaponDef, distance: float, bearing: float, body: FighterBody,
		first_only: bool) -> Array[Contact]:
	var out: Array[Contact] = []
	var pos: V3 = V3.make()
	var yaw: float = 0.0
	var off: float = bearing * SimMath.DEG
	var target: V3 = SimMath.local_to_world(pos, yaw, V3.make(distance * JsMath.sin(off), 0.0, distance * JsMath.cos(off)))
	var capsule: SimCapsule = body.hurt_capsule(target)
	var lunge: float = def.lunge_from(distance)
	var last: Dictionary[StringName, Array] = {}
	for f: int in def.startup + def.active + 1:
		# Fighter._update_attack(): the lunge, as _advance() takes it
		var share: float = def.lunge_share(f)
		if lunge > 0.0 and share > 0.0:
			var room: float = maxf(0.0, SimMath.dist2(pos, target) - (SimConst.FIGHTER_RADIUS * 2.0 + 0.25))
			var step: float = minf(lunge * share, room)
			var dir: V2 = SimMath.fwd(yaw)
			pos = V3.make(pos.x + dir.x * step, pos.y, pos.z + dir.z * step)
		# Fighter._update_facing(): the startup's and the active frames' tracking
		var rate: float = def.track_startup if f <= def.startup else def.track_active
		yaw = SimMath.turn_toward(yaw, SimMath.yaw_to(pos, target), rate * SimConst.DT)
		# Fighter.place_blades() and blade_touch(): the deepest touch
		var deepest: BladeSweep = null
		for part: StringName in def.swing.parts():
			var segment: StrikeSegment = Swing.strike_segment(part, weapon)
			if segment == null:
				continue
			var pose: Swing.Sample = def.swing.tick(part, f)
			var base: V3 = SimMath.local_to_world(pos, yaw, pose.place(segment.base))
			var tip: V3 = SimMath.local_to_world(pos, yaw, pose.place(segment.tip))
			if last.has(part) and World.checks_frame(def, f):
				var touch: BladeSweep = BladeSweep.touch(last[part][0], last[part][1], base, tip,
						BladeSegment.half_thickness_for(segment, def), capsule)
				if touch != null and (deepest == null or touch.depth > deepest.depth):
					deepest = touch
			last[part] = [base, tip]
		if deepest != null:
			var c: Contact = Contact.new()
			c.frame = f
			c.depth = deepest.depth
			c.length_inside = deepest.length_inside
			out.append(c)
			if first_only:
				break
	return out


## The reach of `def`'s swing on `weapon` (the weapon whose moves hold it):
## the furthest point of its striking tracks' segments, across the ground
## from the feet, at the ticks from the last of the startup to the last
## active one, plus the half-thickness its sweep tests.
static func reach(def: AttackDef, weapon: WeaponDef) -> float:
	var out: float = 0.0
	for part: StringName in def.swing.parts():
		var segment: StrikeSegment = Swing.strike_segment(part, weapon)
		if segment == null:
			continue
		var half: float = BladeSegment.half_thickness_for(segment, def)
		for ends: Array[V3] in _ticks(def, part, segment):
			for p: V3 in ends:
				out = maxf(out, JsMath.hypot(p.x, p.z) + half)
	return out


## The arc of `def`'s swing on `weapon`, in degrees: twice the widest bearing
## from the facing of its striking tracks' sweeps through the active frames.
static func arc(def: AttackDef, weapon: WeaponDef) -> float:
	var widest: float = 0.0
	for part: StringName in def.swing.parts():
		var segment: StrikeSegment = Swing.strike_segment(part, weapon)
		if segment == null:
			continue
		var ticks: Array[Array] = _ticks(def, part, segment)
		for ends: Array[V3] in ticks:
			for p: V3 in ends:
				widest = maxf(widest, absf(JsMath.atan2(p.x, p.z)) / SimMath.DEG)
		for i: int in range(1, ticks.size()):
			var b0: V3 = ticks[i - 1][0]
			var t0: V3 = ticks[i - 1][1]
			var b1: V3 = ticks[i][0]
			var t1: V3 = ticks[i][1]
			if _behind(b0, t0, t1) or _behind(b0, t1, b1):
				return 360.0
	return 2.0 * widest


## Puts the derived reach and arc on `def`'s swing (WeaponDef.derive_reach()).
static func derive(def: AttackDef, weapon: WeaponDef) -> void:
	def.swing.reach = reach(def, weapon)
	def.swing.arc = arc(def, weapon)


## The striking segment of `part` at each tick from the last of the startup
## to the last active one, as [base, tip] in the fighter's space: (right, up,
## forward) from the feet. The keys cover these frames, so the entry doesn't
## change them.
static func _ticks(def: AttackDef, part: StringName, segment: StrikeSegment) -> Array[Array]:
	var out: Array[Array] = []
	for f: int in range(def.startup, def.startup + def.active + 1):
		var pose: Swing.Sample = def.swing.tick(part, f)
		out.append([pose.place(segment.base), pose.place(segment.tip)] as Array[V3])
	return out


## Whether the triangle p, q, r, seen from above, reaches straight behind the
## fighter: an edge crosses the line back from the feet, or it holds the feet.
static func _behind(p: V3, q: V3, r: V3) -> bool:
	if _crosses_behind(p, q) or _crosses_behind(q, r) or _crosses_behind(r, p):
		return true
	var s1: float = _side(p, q)
	var s2: float = _side(q, r)
	var s3: float = _side(r, p)
	return (s1 > 0.0 and s2 > 0.0 and s3 > 0.0) or (s1 < 0.0 and s2 < 0.0 and s3 < 0.0)


## Whether the edge p to q, seen from above, crosses the line straight back
## from the feet (right 0, forward below 0). An end on that line has a
## bearing of 180 of its own.
static func _crosses_behind(p: V3, q: V3) -> bool:
	if (p.x > 0.0 and q.x > 0.0) or (p.x < 0.0 and q.x < 0.0) or p.x == q.x:
		return false
	var t: float = p.x / (p.x - q.x)
	return p.z + (q.z - p.z) * t < 0.0


## Which side of the edge p to q the feet are on, seen from above.
static func _side(p: V3, q: V3) -> float:
	return p.x * q.z - p.z * q.x
