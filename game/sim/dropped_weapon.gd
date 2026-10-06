class_name DroppedWeapon
extends RefCounted
## A weapon knocked out of a fighter's hands, flying or stuck in the ground.
## Began as the port of the DroppedWeapon class in
## v0.1-web-mvp:src/sim/world.ts.
##
## Since milestone-1 task 86 it draws nothing from the world's generator and
## never bounces: it flies a fixed arc from the hands along its heading
## (heading()), DISARM_FLIGHT metres or less so that it lands inside the walls
## (landing()), tumbling forward, and sticks blade-first STUCK_WEAPON_LEAN
## from vertical, leaning back toward where it came from. The same disarm
## lands it in the same place every run.

## Turns it tumbles in flight, ending at the stuck angle.
const FLIGHT_TURNS: float = 1.5

## Stuck in the ground: it has landed, and can be pulled out.
var grounded: bool = false
var owner: int
var weapon_id: StringName
## Where the flight starts (in the victim's hands) and where the weapon sticks
## (on the ground).
var from: V3
var to: V3
var flight_frames: int = 1
## Rules frames flown so far.
var flown: int = 0
## In flight, the middle of the weapon; stuck, where its blade enters the
## ground.
var pos: V3
## The flight's heading, as a fighter's yaw (0 faces +Z, positive turns toward
## +X).
var yaw: float = 0.0
## The weapon's turn about the axis across its flight: 0 is blade up, PI blade
## down; stuck, PI less STUCK_WEAPON_LEAN, the blade pointing down and ahead
## and the hilt back toward where it came from.
var pitch: float = 0.0


## A copy of the dropped weapon's fields (milestone-1 task 5).
func snapshot() -> Dictionary:
	return SimState.capture(self)


## Puts a snapshot() back (milestone-1 task 134).
func restore(s: Dictionary) -> void:
	SimState.apply(self, s)


## A dropped weapon rebuilt from a snapshot().
static func from_snapshot(s: Dictionary) -> DroppedWeapon:
	var w: DroppedWeapon = DroppedWeapon.new(0, &"", V3.make(), V3.make(), 0.0)
	w.restore(s)
	return w


## A weapon flying from `p_from` to stick at `p_to` (y 0), heading `p_yaw`.
func _init(p_owner: int, p_weapon_id: StringName, p_from: V3, p_to: V3, p_yaw: float) -> void:
	owner = p_owner
	weapon_id = p_weapon_id
	from = p_from
	to = V3.make(p_to.x, 0.0, p_to.z)
	yaw = p_yaw
	var d: float = SimMath.len2(to.x - from.x, to.z - from.z)
	flight_frames = maxi(1, SimMath.js_round(d / SimConst.DISARM_FLIGHT_SPEED / SimConst.DT))
	pos = V3.make(from.x, from.y, from.z)
	pitch = _stuck_pitch() - FLIGHT_TURNS * TAU


## A weapon already stuck at `at`, heading `p_yaw` (for shots and tests).
static func stuck_at(p_owner: int, p_weapon_id: StringName, at: V3, p_yaw: float) -> DroppedWeapon:
	var w: DroppedWeapon = DroppedWeapon.new(p_owner, p_weapon_id, at, at, p_yaw)
	w.flown = w.flight_frames
	w.pos = V3.make(w.to.x, 0.0, w.to.z)
	w.pitch = _stuck_pitch()
	w.grounded = true
	return w


## The heading a disarmed weapon flies along: the blade's motion at contact,
## the blow's for a knock (`reason` &"blocked": `by` struck) and the attacker's
## own reversed for a deflect (parried or redirected: the victim struck);
## straight away from `by` when the striking blade has no swing or moves
## slower than DISARM_BLADE_MIN_SPEED across the ground. Read before the
## disarm ends the attacks.
static func heading(victim: Fighter, by: Fighter, reason: StringName) -> V2:
	var knock: bool = reason == &"blocked"
	var motion: V2 = _blade_motion(by if knock else victim)
	if motion != null:
		return SimMath.norm2(motion.x, motion.z) if knock else SimMath.norm2(-motion.x, -motion.z)
	return SimMath.norm2(victim.pos.x - by.pos.x, victim.pos.z - by.pos.z)


## Where a weapon flying from (x, z) along `dir` sticks: DISARM_FLIGHT metres
## on, shortened along its flight to the ring STUCK_WEAPON_MARGIN inside the
## wall, or, starting beyond that ring, pulled back onto it.
static func landing(x: float, z: float, dir: V2) -> V2:
	var ring: float = SimConst.ARENA_RADIUS - SimConst.STUCK_WEAPON_MARGIN
	var reach: float = SimConst.DISARM_FLIGHT
	var ex: float = x + dir.x * reach
	var ez: float = z + dir.z * reach
	var er: float = SimMath.len2(ex, ez)
	if er <= ring:
		return V2.make(ex, ez)
	var sr: float = SimMath.len2(x, z)
	if sr < ring:
		# |s + dir t| = ring, its positive root
		var b: float = x * dir.x + z * dir.z
		var t: float = -b + sqrt(b * b - (sr * sr - ring * ring))
		return V2.make(x + dir.x * t, z + dir.z * t)
	return inside_ring(ex, ez)


## (x, z), pulled back onto the ring STUCK_WEAPON_MARGIN inside the wall when
## beyond it.
static func inside_ring(x: float, z: float) -> V2:
	var ring: float = SimConst.ARENA_RADIUS - SimConst.STUCK_WEAPON_MARGIN
	var r: float = SimMath.len2(x, z)
	return V2.make(x * ring / r, z * ring / r) if r > ring else V2.make(x, z)


## Flies one rules frame. Returns true on the frame it sticks.
func step() -> bool:
	if grounded:
		return false
	flown += 1
	var s: float = float(flown) / float(flight_frames)
	if flown >= flight_frames:
		pos = V3.make(to.x, 0.0, to.z)
		pitch = _stuck_pitch()
		grounded = true
		return true
	var d: float = SimMath.len2(to.x - from.x, to.z - from.z)
	var peak: float = SimConst.DISARM_FLIGHT_PEAK * d / SimConst.DISARM_FLIGHT
	pos = V3.make(
		SimMath.lerp(from.x, to.x, s),
		SimMath.lerp(from.y, 0.0, s) + 4.0 * peak * s * (1.0 - s),
		SimMath.lerp(from.z, to.z, s),
	)
	pitch = _stuck_pitch() - FLIGHT_TURNS * TAU * (1.0 - s)
	return false


static func _stuck_pitch() -> float:
	return PI - SimConst.STUCK_WEAPON_LEAN


## The fastest striking part's motion over the last tick across the ground,
## or null when f has no swing or it moves slower than DISARM_BLADE_MIN_SPEED.
static func _blade_motion(f: Fighter) -> V2:
	if f == null or f.atk == null:
		return null
	var best: V2 = null
	var best_len: float = SimConst.DISARM_BLADE_MIN_SPEED * SimConst.DT
	for b: BladeSegment in f.atk.blades:
		var mx: float = b.tip.x - b.prev_tip.x
		var mz: float = b.tip.z - b.prev_tip.z
		var l: float = SimMath.len2(mx, mz)
		if l >= best_len:
			best_len = l
			best = V2.make(mx, mz)
	return best
