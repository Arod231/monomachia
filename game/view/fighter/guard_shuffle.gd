class_name GuardShuffle
extends RefCounted
## The guard shuffle step: how the feet of a fighter in its guard stance
## (GuardStance) move as it walks, in place of the walking clips: the
## animation spike critique's fix 9 (docs/research/animation-spike). The lead
## foot steps first and the trailing foot closes after it, the feet never
## cross, and every step comes back to the stance's width and angles.
## Locomotion steps it on the rules' frames and FighterView puts the feet on
## the leg IK (place()).
##
## - Each foot has its stance spot and angle in the fighter's own frame
##   (GuardStance.FEET, FOOT_YAW). A planted foot stays where it stands on
##   the ground, as it was turned, while the fighter moves and turns over
##   it, so it doesn't slide; its offset from its spot grows as the fighter
##   travels.
## - A planted foot steps when it has fallen behind its spot the way the
##   spot moves by as far as its steps land ahead (ahead(); DRIFT for the
##   first step from rest), or stands SIDE_OFF to the side of it, or is
##   turned TURN_OFF from the stance's angle, or comes LANE_LIFT near the
##   mid-line; at rest, when it stands REST_OFF off its spot. One foot steps
##   at a time, and moving, the feet take turns: the lead first (lead), the
##   foot on the side the fighter travels to, counting across ACROSS times
##   over along, since the stance is narrower than it is long. Forward, forward-right, right
##   and back-right lead with the right foot; back, back-left, left and
##   forward-left with the left.
## - A step lands ahead of its spot by half the way the spot moves while the
##   foot stands (ahead()), so each foot stands about its spot, at most
##   LEAD_MOST off it and at the stance's angle. The landing is kept LANE
##   clear of the mid-line, then and after the drift to come. While a foot
##   swings, its offset moves in the fighter's frame from where it lifted to
##   where it lands, so the swing never crosses the mid-line either. It
##   lifts LIFT at most, halfway, less for a short step.
## - The cadence comes from the speed: each foot steps once a cycle, the
##   fighter travelling step_length() a cycle, longer the faster it goes.
##   A swing takes half the cycle, SWING_FRAMES_MIN to SWING_FRAMES_MAX
##   frames (swing_frames()), so a slow walk pauses between steps and a fast
##   one doesn't. Moving across, the swings are shorter and a foot stands no
##   longer than the fighter takes to travel LANE_TRAVEL across, so it
##   doesn't drift to the mid-line.
## - The pelvis bobs with the stance's spread: lower as the feet open, higher
##   as they close (bob, BOB_PER_SPREAD). The weapon follows the bob on a
##   critically damped spring (weapon_bob, BOB_SPRING): it lags a little.
## - Where the feet can't stand planted (step()'s `anchored` false: in the
##   air, an attack, a dodge, a stun, or faster than RIDE_SPEED), they ride
##   with the fighter at their offsets, and still step back to their spots.
## - It moves once per rules frame (step()), so it holds still in hit-stop
##   and pause, and shows between frames by the host's alpha (show()).
## - The feet that came down on the ground in a frame (landed) are where the
##   fighter's footsteps fall (see Locomotion.footfalls).
## - A strike (plan task 14.13: a swing played in the guard, see Strike and
##   strike_for()) plants the feet and steps them in time with the rules'
##   lunge instead: the foot that leads the lunge's way lifts so that it
##   lands on the first active frame, ahead of its spot by what is left of
##   the lunge then, and the other follows, landing REAR_FRAMES later.
##   Otherwise the feet stand where they are through the strike: no step is
##   taken to tidy them until it ends.
##
## Positions are in the rules' world, on the ground (y = 0); the fighter's
## frame is skeleton space: +Z forward, +X to its left.

const SIDES: Array[String] = ["Right", "Left"]
## How far the fighter travels a cycle of both feet's steps (m): STEP_LENGTH
## and STEP_PER_SPEED more for every m/s.
const STEP_LENGTH: float = 0.2
const STEP_PER_SPEED: float = 0.12
## How far across the fighter travels while a foot stands, at most (m):
## moving across, the planted foot drifts toward the mid-line meanwhile.
const LANE_TRAVEL: float = 0.16
## The shortest and longest swing (rules frames).
const SWING_FRAMES_MIN: int = 5
const SWING_FRAMES_MAX: int = 12
## How far behind its spot a planted foot falls before the first step from
## rest (m).
const DRIFT: float = 0.02
## How far to the side of its spot's way a planted foot may stand (m).
const SIDE_OFF: float = 0.06
## At rest, how far off its spot a planted foot may stand (m).
const REST_OFF: float = 0.02
## How far a planted foot may be turned from the stance's angle (radians).
const TURN_OFF: float = 12.0 * PI / 180.0
## Below this speed (m/s) a spot isn't moving.
const MOVING: float = 0.05
## How far a step lands from the mid-line at least, and stays from it while
## planted (m); and how near a planted foot may come before it steps.
const LANE: float = 0.05
const LANE_LIFT: float = 0.03
## The furthest a step lands off its spot (m): the front foot's reach.
const LEAD_MOST: float = 0.13
## How high a step lifts the foot (m), for a step LIFT_STEP long or longer.
const LIFT: float = 0.04
const LIFT_STEP: float = 0.3
## Above this speed (m/s) the feet ride with the fighter.
const RIDE_SPEED: float = 6.0
## How far ahead (s) a swing's pace looks at the speed the fighter is
## speeding up to: setting off from rest the rules reach the guard's walk in
## 4 frames, and a step paced for the speed at its first frame would leave
## the other foot standing out of reach behind.
const PACE_AHEAD: float = 0.05
## How much more the lead counts a way across than along.
const ACROSS: float = 2.0
## How much more one foot must lead before it takes over the lead (m).
const LEAD_HYSTERESIS: float = 0.02
## A strike's steps: the leading foot's swing takes STRIKE_SWING_MOST frames
## at most (it lifts no earlier than the lunge starts) and STRIKE_SWING_LEAST
## at least; the other lands REAR_FRAMES after it; a landing is at most
## STRIKE_AHEAD_MOST off its spot, whatever is left of the lunge.
const STRIKE_SWING_MOST: int = 10
const STRIKE_SWING_LEAST: int = 4
const REAR_FRAMES: int = 6
const STRIKE_AHEAD_MOST: float = 0.25
## How far the pelvis drops per metre the feet spread past the stance's
## (m/m), and the most it moves either way (m).
const BOB_PER_SPREAD: float = 0.06
const BOB_MOST: float = 0.02
## The stiffness of the spring the weapon follows the bob on (1/s).
const BOB_SPRING: float = 45.0


## One foot.
class Foot:
	var side: String
	## Its stance spot in the fighter's frame (on the ground) and its angle
	## (radians, positive to the fighter's left).
	var spot: Vector3
	var spot_turn: float
	## Where it is from its spot, in the fighter's frame (m), and its turn
	## from the stance's angle (radians), after the last rules frame.
	var offset: Vector3 = Vector3.ZERO
	var turn: float = 0.0
	## In the air, stepping: the offset and turn it lifted at, how far
	## through the swing it is (0 to 1), and how many frames it has swung (or
	## swung last).
	var swinging: bool = false
	var from: Vector3 = Vector3.ZERO
	var from_turn: float = 0.0
	var progress: float = 0.0
	var frames: int = 0
	## How fast its spot moves, in the fighter's frame (m/s), and how fast
	## it would move PACE_AHEAD on at the speed-up it has (for the swing's
	## pace).
	var drift: Vector3 = Vector3.ZERO
	var heading_for: Vector3 = Vector3.ZERO
	## Where it is in the world (on the ground), which way it points (world
	## yaw) and how high it is off the ground (m): after the last rules frame,
	## after the one before, and as last shown.
	var at: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var height: float = 0.0
	var prev_at: Vector3 = Vector3.ZERO
	var prev_yaw: float = 0.0
	var prev_height: float = 0.0
	var shown_at: Vector3 = Vector3.ZERO
	var shown_yaw: float = 0.0
	var shown_height: float = 0.0
	## How many steps it has finished.
	var steps: int = 0
	## A strike's step (see Strike): how many frames it swings, and where it
	## lands from its spot, in the fighter's frame; 0 frames for a step of
	## the shuffle's own.
	var planned_frames: int = 0
	var planned_land: Vector3 = Vector3.ZERO
	## Where its spot was in the world on the last frame.
	var _spot_was: Vector3 = Vector3.ZERO

	func _init(p_side: String) -> void:
		side = p_side
		spot = Vector3(GuardStance.FEET[side].x, 0.0, GuardStance.FEET[side].z)
		spot_turn = deg_to_rad(GuardStance.FOOT_YAW[side])

	## Which side of the mid-line it keeps to: -1 right (-X), +1 left.
	func sign() -> float:
		return -1.0 if side == "Right" else 1.0


## The steps of a strike, by side: the attack frame each foot lifts on and
## lands on, and where it lands from its spot (in the fighter's frame), and
## the attack's frame this step. A side not listed stays planted.
class Strike:
	var frame: int = 0
	var lifts: Dictionary[String, int] = {}
	var lands: Dictionary[String, int] = {}
	var ahead: Dictionary[String, Vector3] = {}


var feet: Dictionary[String, Foot] = {}
## The foot that steps first, moving.
var lead: String = "Right"
## The feet ride with the fighter (see step()).
var riding: bool = false
## The feet ("Right", "Left") that came down on the ground in the last
## step(): landed, not riding.
var landed: Array[String] = []
## The pelvis's bob (m, up) and the weapon's, after the last rules frame and
## the one before, how fast the weapon's moves, and as shown.
var bob: float = 0.0
var weapon_bob: float = 0.0
var weapon_bob_rate: float = 0.0
var prev_bob: float = 0.0
var prev_weapon_bob: float = 0.0
var shown_bob: float = 0.0
var shown_weapon_bob: float = 0.0

## Where the fighter is in the world and which way it faces: after the last
## rules frame, after the one before, and as shown. The feet are shown
## from it (place()).
var body: Vector3 = Vector3.ZERO
var body_yaw: float = 0.0
var prev_body: Vector3 = Vector3.ZERO
var prev_body_yaw: float = 0.0
var shown_body: Vector3 = Vector3.ZERO
var shown_body_yaw: float = 0.0

## The fighter on the ground on the last frame.
var _pos: Vector3 = Vector3.ZERO
## The foot that stepped last while moving, or "" at rest.
var _last: String = ""
var _rest_spread: float = 0.0


func _init() -> void:
	for side: String in SIDES:
		feet[side] = Foot.new(side)
	_rest_spread = feet["Right"].spot.distance_to(feet["Left"].spot)


## The way a fighter facing `yaw` faces, as a rotation from its frame to the
## world.
static func facing(yaw: float) -> Basis:
	return Basis(Vector3.UP, yaw)


## How far the fighter travels a cycle of both feet's steps at `speed` (m/s).
static func step_length(speed: float) -> float:
	return STEP_LENGTH + STEP_PER_SPEED * speed


## How many frames a swing lasts while the spot moves at `drift` (in the
## fighter's frame, m/s): half a cycle, within SWING_FRAMES_MIN and
## SWING_FRAMES_MAX, and no longer than the fighter takes to travel
## LANE_TRAVEL across.
static func swing_frames(drift: Vector3) -> int:
	var speed: float = drift.length()
	if speed < MOVING:
		return SWING_FRAMES_MAX
	var fps: float = float(SimConst.FPS)
	var frames: int = clampi(floori(fps * step_length(speed) / (2.0 * speed)), SWING_FRAMES_MIN, SWING_FRAMES_MAX)
	var across: float = absf(drift.x)
	if across > MOVING:
		frames = mini(frames, maxi(SWING_FRAMES_MIN, floori(fps * LANE_TRAVEL / across)))
	return frames


## How far ahead of its spot a step lands while the spot moves at `drift`,
## and how far behind it the foot falls before it steps again (m): half the
## way the spot moves while the foot stands. It stands the rest of the cycle
## after its swing, and no longer than the fighter takes to travel
## LANE_TRAVEL across, but at least while the other foot swings and the
## frame it lands on (the next foot lifts then).
static func ahead(drift: Vector3) -> float:
	var speed: float = drift.length()
	if speed < MOVING:
		return 0.0
	var swing: float = float(swing_frames(drift)) / float(SimConst.FPS)
	var shortest: float = swing + 1.0 / float(SimConst.FPS)
	var stand: float = maxf(step_length(speed) / speed - swing, shortest)
	var across: float = absf(drift.x)
	if across > MOVING:
		stand = maxf(minf(stand, LANE_TRAVEL / across), shortest)
	return speed * stand / 2.0


## The steps of a strike by move `def` lunging `lunge_total` metres the way
## `way` (in the fighter's frame, on the ground; straight ahead unless the
## lunge runs along a dodge), at attack frame `frame`: the foot further that
## way (across counting ACROSS times over along) lifts so that it lands on
## the first active frame, ahead of its spot by what the lunge has left to
## go then (eased as the rules ease it), and the other lands REAR_FRAMES
## after it, as far ahead as the lunge has left then. No lunge, no steps.
static func strike_for(def: AttackDef, lunge_total: float, way: Vector3, frame: int) -> Strike:
	var out: Strike = Strike.new()
	out.frame = frame
	if lunge_total <= 0.0 or way.length() < 1e-6:
		return out
	way = way.normalized()
	var score: Dictionary[String, float] = {}
	for side: String in SIDES:
		var spot: Vector3 = GuardStance.FEET[side]
		score[side] = spot.x * ACROSS * way.x + spot.z * way.z
	var front: String = "Right" if score["Right"] >= score["Left"] else "Left"
	var rear: String = _other(front)
	var contact: int = def.startup + 1
	var lift: int = maxi(maxi(def.lunge_start, contact - STRIKE_SWING_MOST), 1)
	lift = maxi(mini(lift, contact - STRIKE_SWING_LEAST), 1)
	out.lifts[front] = lift
	out.lands[front] = contact
	out.lifts[rear] = contact
	out.lands[rear] = contact + REAR_FRAMES
	for side: String in SIDES:
		var left: float = _lunge_left(def, lunge_total, out.lands[side])
		out.ahead[side] = way * minf(left, STRIKE_AHEAD_MOST)
	return out


## How far a lunge of `lunge_total` by move `def` has still to go after attack
## frame `frame` (m), as the rules ease it (Fighter._update_attack()).
static func _lunge_left(def: AttackDef, lunge_total: float, frame: int) -> float:
	var ls: int = def.lunge_start
	var le: int = def.lunge_end if def.lunge_end != AttackDef.UNSET else def.startup + def.active
	var n: float = float(maxi(1, le - ls))
	var done: float = SimMath.ease_in_out(clampf(float(frame - ls) / n, 0.0, 1.0))
	return lunge_total * (1.0 - done)


## Stands the feet on their spots under a fighter at `pos` facing `yaw`,
## planted.
func reset(pos: Vector3, yaw: float) -> void:
	_pos = Vector3(pos.x, 0.0, pos.z)
	body = pos
	body_yaw = yaw
	prev_body = pos
	prev_body_yaw = yaw
	_last = ""
	riding = false
	for foot: Foot in feet.values():
		foot.offset = Vector3.ZERO
		foot.turn = 0.0
		foot.swinging = false
		foot.planned_frames = 0
		foot.drift = Vector3.ZERO
		foot.heading_for = Vector3.ZERO
		foot.at = _pos + facing(yaw) * foot.spot
		foot.yaw = yaw + foot.spot_turn
		foot.height = 0.0
		foot._spot_was = foot.at
		foot.prev_at = foot.at
		foot.prev_yaw = foot.yaw
		foot.prev_height = 0.0
	bob = 0.0
	weapon_bob = 0.0
	weapon_bob_rate = 0.0
	prev_bob = 0.0
	prev_weapon_bob = 0.0
	show(1.0)


## Moves on one rules frame, the fighter now at `pos` facing `yaw`: planted
## feet stand where they are when `anchored` (the fighter on the ground,
## walking or standing) and the fighter is slower than RIDE_SPEED, else
## they ride with it; swings move on; then a foot that needs to step starts,
## or, in a `strike`, the foot it lifts on this frame.
func step(pos: Vector3, yaw: float, anchored: bool, strike: Strike = null) -> void:
	prev_body = body
	prev_body_yaw = body_yaw
	body = pos
	body_yaw = yaw
	landed.clear()
	var ground: Vector3 = Vector3(pos.x, 0.0, pos.z)
	var to_frame: Basis = facing(yaw).inverse()
	var moved: Vector3 = to_frame * (ground - _pos) * float(SimConst.FPS)
	riding = not anchored or moved.length() > RIDE_SPEED
	for foot: Foot in feet.values():
		foot.prev_at = foot.at
		foot.prev_yaw = foot.yaw
		foot.prev_height = foot.height
		var spot_at: Vector3 = ground + facing(yaw) * foot.spot
		var drift: Vector3 = to_frame * (spot_at - foot._spot_was) * float(SimConst.FPS)
		# speeding up, the pace is for the speed it is heading for
		var speed_up: Vector3 = (drift - foot.drift) * float(SimConst.FPS)
		foot.heading_for = drift + speed_up * PACE_AHEAD
		if foot.heading_for.length() < drift.length():
			foot.heading_for = drift
		foot.drift = drift
		foot._spot_was = spot_at
		var lift: float = 0.0
		var moves: bool = foot.swinging or riding
		if foot.swinging:
			# on through the swing at the pace the speed now asks for, so a
			# step taken setting off keeps up as the fighter speeds up
			var pace: int = foot.planned_frames if foot.planned_frames > 0 else swing_frames(foot.heading_for)
			foot.frames += 1
			# a strike's step counts whole frames, so it lands on the one planned
			if foot.planned_frames > 0:
				foot.progress = minf(1.0, float(foot.frames) / float(pace))
			else:
				foot.progress = minf(1.0, foot.progress + 1.0 / float(pace))
			var t: float = foot.progress
			var land: Vector3 = foot.planned_land if foot.planned_frames > 0 else _landing(foot)
			var e: float = smoothstep(0.0, 1.0, t)
			foot.offset = foot.from.lerp(land, e)
			foot.turn = lerpf(foot.from_turn, 0.0, e)
			var length: float = foot.from.distance_to(land) + foot.drift.length() * float(pace) / float(SimConst.FPS)
			lift = LIFT * clampf(length / LIFT_STEP, 0.3, 1.0) * sin(PI * t)
			if t >= 1.0:
				foot.swinging = false
				foot.planned_frames = 0
				foot.offset = land
				foot.turn = 0.0
				foot.steps += 1
				lift = 0.0
				if not riding:
					landed.append(foot.side)
		elif not riding:
			# where it stands, seen from the fighter now
			foot.offset = to_frame * (foot.at - ground) - foot.spot
			foot.turn = wrapf(foot.yaw - yaw - foot.spot_turn, -PI, PI)
		# a foot that swung this frame, landing or not, or rides, is where its
		# offset puts it
		if moves:
			foot.at = ground + facing(yaw) * (foot.spot + foot.offset)
			foot.yaw = yaw + foot.spot_turn + foot.turn
		foot.height = (pos.y if riding else 0.0) + lift
	_pos = ground
	_update_lead(moved)
	if strike != null:
		for side: String in SIDES:
			var foot: Foot = feet[side]
			# (a plan with no steps, held by a charge or with no lunge, lifts nothing)
			if not foot.swinging and strike.lifts.has(side) and strike.lifts[side] == strike.frame:
				_lift(foot)
				foot.planned_frames = maxi(1, strike.lands[side] - strike.lifts[side])
				foot.planned_land = strike.ahead[side]
	elif not feet["Right"].swinging and not feet["Left"].swinging:
		var side: String = _next_step()
		if side != "":
			_lift(feet[side])
	_step_bob()


## Starts `foot`'s swing from where it stands.
func _lift(foot: Foot) -> void:
	foot.swinging = true
	foot.planned_frames = 0
	foot.from = foot.offset
	foot.from_turn = foot.turn
	foot.progress = 0.0
	foot.frames = 0


## Shows the fighter, the feet and the bob `alpha` of the way from the frame
## before to the last, as the match shows the fighter (MatchHost's
## display_position() and display_yaw()).
func show(alpha: float) -> void:
	shown_body = prev_body.lerp(body, alpha)
	shown_body_yaw = lerp_angle(prev_body_yaw, body_yaw, alpha)
	for foot: Foot in feet.values():
		foot.shown_at = foot.prev_at.lerp(foot.at, alpha)
		foot.shown_yaw = lerp_angle(foot.prev_yaw, foot.yaw, alpha)
		foot.shown_height = lerpf(foot.prev_height, foot.height, alpha)
	shown_bob = lerpf(prev_bob, bob, alpha)
	shown_weapon_bob = lerpf(prev_weapon_bob, weapon_bob, alpha)


## Puts the shown feet on `rig`'s foot targets, in the frame of the shown
## fighter turned `spin` more (the stand-in poses' spin): each ankle where
## its foot is, at the rest pose's height plus its lift, turned as it
## points. Where the fighter is drawn, the planted feet stand still on the
## ground with it as long as it is drawn where the rules have it.
func place(rig: FighterRig, spin: float = 0.0) -> void:
	var turned: float = shown_body_yaw + spin
	var to_skeleton: Transform3D = Transform3D(facing(turned), shown_body).affine_inverse()
	for side: String in SIDES:
		var foot: Foot = feet[side]
		var p: Vector3 = to_skeleton * foot.shown_at
		rig.foot_position[side] = Vector3(p.x, rig.rest_foot(side).y + foot.shown_height - shown_body.y, p.z)
		rig.foot_yaw[side] = wrapf(foot.shown_yaw - turned, -PI, PI)


## Where a swinging foot lands, from its spot in the fighter's frame: ahead
## by ahead(), at most LEAD_MOST, kept LANE clear of the mid-line then and
## after the drift while it stands; its spot when riding or at rest.
func _landing(foot: Foot) -> Vector3:
	var u: Vector3 = foot.drift
	var speed: float = u.length()
	if riding or speed < MOVING:
		return Vector3.ZERO
	var lead_by: float = ahead(u)
	var stand: float = 2.0 * lead_by / speed
	var land: Vector3 = u / speed * minf(lead_by, LEAD_MOST)
	var s: float = foot.sign()
	var clear: float = (foot.spot.x + land.x) * s
	var clear_after: float = (foot.spot.x + land.x - u.x * stand) * s
	var short: float = maxf(LANE - clear, LANE - clear_after)
	if short > 0.0:
		land.x += short * s
		# within reach still, giving up some of the way along rather than
		# the lane
		if land.length() > LEAD_MOST and absf(land.x) < LEAD_MOST:
			land.z = signf(land.z) * sqrt(LEAD_MOST * LEAD_MOST - land.x * land.x)
	return land


## Whether a planted foot should step: moving, fallen behind its spot by
## ahead() (DRIFT for the first step from rest), to the side of its way,
## turned, or near the mid-line; at rest or riding, off its spot or turned.
func _needs_step(foot: Foot) -> bool:
	var u: Vector3 = foot.drift
	var speed: float = u.length()
	if riding or speed < MOVING:
		return foot.offset.length() > REST_OFF or absf(foot.turn) > TURN_OFF
	var way: Vector3 = u / speed
	var along: float = foot.offset.dot(way)
	var aside: float = (foot.offset - way * along).length()
	var behind: float = DRIFT if _last == "" else maxf(ahead(u), DRIFT)
	return along < -behind or aside > SIDE_OFF or absf(foot.turn) > TURN_OFF or _near_mid_line(foot)


## Whether a planted foot is LANE_LIFT near the mid-line, or drifting toward
## it and a frame from coming within LANE.
func _near_mid_line(foot: Foot) -> bool:
	var clear: float = (foot.spot.x + foot.offset.x) * foot.sign()
	var toward: float = foot.drift.x * foot.sign() / float(SimConst.FPS)
	return clear < LANE_LIFT or (toward > 0.0 and clear - toward < LANE)


## The foot to step next, or "": one near the mid-line first; moving, the
## feet take turns, the lead first (and the lead goes on its turn when the
## other foot needs to step and it is behind its spot); at rest, the one
## furthest off.
func _next_step() -> String:
	var needs: Array[String] = []
	for side: String in SIDES:
		if _needs_step(feet[side]):
			needs.append(side)
	if needs.is_empty():
		if not riding and _still():
			_last = ""
		return ""
	for side: String in needs:
		if not riding and _near_mid_line(feet[side]):
			return _took(side)
	if riding or _still():
		var off: String = needs[0]
		for side: String in needs:
			if feet[side].offset.length() > feet[off].offset.length():
				off = side
		return _took(off)
	var trail: String = _other(lead)
	var turn: String = trail if _last == lead else lead
	if needs.has(turn):
		return _took(turn)
	var foot: Foot = feet[turn]
	if turn == lead and foot.offset.dot(foot.drift) < 0.0:
		return _took(turn)
	return _took(needs[0])


func _took(side: String) -> String:
	_last = side
	return side


## True when neither spot moves.
func _still() -> bool:
	return feet["Right"].drift.length() < MOVING and feet["Left"].drift.length() < MOVING


## Takes the lead from the way the fighter moves (`moved`, in its frame,
## m/s): the foot further that way, across counting ACROSS times over along.
func _update_lead(moved: Vector3) -> void:
	if moved.length() < MOVING:
		return
	var way: Vector3 = moved.normalized()
	var score: Dictionary[String, float] = {}
	for side: String in SIDES:
		var spot: Vector3 = feet[side].spot
		score[side] = spot.x * ACROSS * way.x + spot.z * way.z
	var other: String = _other(lead)
	if score[other] > score[lead] + LEAD_HYSTERESIS:
		lead = other


static func _other(side: String) -> String:
	return "Left" if side == "Right" else "Right"


## The bob for the feet as they are, and the weapon's spring after it.
func _step_bob() -> void:
	prev_bob = bob
	prev_weapon_bob = weapon_bob
	var right: Foot = feet["Right"]
	var left: Foot = feet["Left"]
	var spread: float = (right.spot + right.offset).distance_to(left.spot + left.offset)
	bob = clampf(-BOB_PER_SPREAD * (spread - _rest_spread), -BOB_MOST, BOB_MOST)
	var s: Vector2 = Locomotion.spring(weapon_bob, weapon_bob_rate, bob, BOB_SPRING, 1.0 / float(SimConst.FPS))
	weapon_bob = s.x
	weapon_bob_rate = s.y
