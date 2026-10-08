class_name Locomotion
extends RefCounted
## The legs under a fighter in the match: an AnimationTree on its model
## blending the idle (the clip director's combat idle for the weapon class)
## with the packs' directional walk, run and sprint clips by the rules'
## velocity in the fighter's facing space (authored-animation task 29),
## advanced by the rules' clock. FighterView updates it every frame; it never
## changes the rules.
##
## - **The ways.** Eight ways round the fighter, every 45° (WAYS, positive
##   to its left), on the rules' gait clips (Gaits.CLIPS): forward and the
##   four diagonals walk on Walk01 and run on Run01 (the backward runs
##   re-keyed slower, RunBackward*), sideways on StrafeWalk01 and
##   StrafeRun01 (the right ones the left mirrored), and the forward five
##   sprint on Sprint01. The legs travel between the two ways round the
##   fighter's travel, weighted by how near each is (way_weights()). Without
##   the packs, the CC0 library's walks in eight ways, Jog_Fwd and Sprint
##   (FALLBACK_CLIPS).
## - **The speeds.** The blend is anchored on speeds (gait_weights()): idle
##   at rest, the walk at its clips' own pace, the run and the sprint at the
##   rules' speeds that way, which are the run and sprint clips' own measured
##   speeds (Gaits.speed(), milestone-1 task 55), both scaled by the weapon
##   and when disarmed; each blends linearly into the next. A way with no
##   clip at a gait (no sprint goes backwards) plays the gait below it.
## - **One shared step phase.** Every clip plays from it, so the feet stay in
##   step whatever the blend: at phase 0 the left foot is at mid-stance in
##   every clip, and at about 0.5 the right. The phase moves the blended
##   stride per cycle (stride()), so the planted foot keeps pace with the
##   ground. Since task 55 the rules move a fighter at its clips' own speeds,
##   so a gait plays its clips at 1.0× (the stride-matched playback rate of
##   PR #21, which sped clips up or down to the rules' own speeds, is
##   retired); only a blend between gaits of different cycle lengths runs
##   between their rates, in step. Each fighter's strides, ways, mid-stances
##   and foot contacts are measured from its own clips by FootPhase, once per
##   fighter and clip.
## - The phase moves once per rules frame, by the speed after that frame
##   (ground_speed(): walking and running on the ground only, so a dodge, an
##   attack's lunge or a jump keeps the legs on the idle; the Iai stance
##   walks). In between, the shown phase and blend go from the frame before by
##   the host's alpha, as the position does. The world's frame stands still in
##   hit-stop and while paused, and so do the legs.
## - **Setting off and stopping** cross over between the idle and the moving
##   clips over MOVING_FRAMES (the spec's locomotion crossfade), on rules
##   frames: the rules' tap step reaches its speed in one frame, and the
##   combat idles stand wider and lower than the walks.
## - **A tap step** (the owner's choice, Oct 4) is one walking step: half a
##   cycle of the walk the way the step goes, over the step's frames.
## - **A sprint held backwards** (further than AWAY_AT from straight ahead;
##   the owner's choice, Oct 4) turns the whole body away to sprint on
##   Sprint01 (away, on a spring), and back to face the opponent when the
##   sprint ends. FighterView turns the model by shown_away.
## - **Turning on the spot.** Standing, once the rules' facing has turned
##   TURN_AT from where the feet were set, the legs step round on Turn01 Left
##   or Right (the packs' turn in place: on our rig its turn is in the root,
##   which the import strips, so the legs step and the rules turn the body),
##   over TURN_FRAMES. Turn01 stands upright with its feet together, so it is
##   laid on the idle's legs as a difference (additive(): its motion from its
##   own first frame), keeping the combat idle's wide stance while its feet
##   lift and step; the foot lock replants them.
## - **Footsteps** fall where the clips' feet come down (footfalls): the
##   shared phase passing a foot's contact while the legs walk or run, at
##   that foot.
##
## The same tree plays the clip director's authored clips over the legs'
## blend (authored-animation task 8; set_authored()): the clip that drives
## and the one it fades in from, at the times the director gives, blended
## between them and over the legs. The tree holds the Iglesias clip
## libraries as well as the CC0 one when they are there, so a clip is named
## by its library ("HumanM/CombatIdle1H01", "ual/Sword_Idle"); a bare name is
## the CC0 library's.
##
## (Before task 29 the legs were the CC0 forward clips turned toward travel
## at the hips, with a lean, and the Katana stood in a guard stance on the
## guard shuffle; all of that is retired.)

## The eight ways round the fighter, every WAY_STEP radians from straight
## ahead, positive to its left: forward, forward-left, left, back-left,
## back, back-right, right, forward-right.
const WAYS: int = 8
const WAY_STEP: float = PI / 4.0
## The gaits, in blend order after idle.
const GAITS: Array[StringName] = [&"walk", &"run", &"sprint"]
## The packs' clip for each gait and way (clip-manifest ids; "" for none):
## the rules' (milestone-1 task 55).
const PACK_CLIPS: Dictionary[StringName, Array] = Gaits.CLIPS
## Without the packs: the CC0 library's (UAL2's eight walks, UAL's jog and
## sprint ahead).
const FALLBACK_CLIPS: Dictionary[StringName, Array] = {
	&"walk": ["Walk_Fwd", "Walk_Fwd_L", "Walk_L", "Walk_Bwd_L", "Walk_Bwd", "Walk_Bwd_R", "Walk_R", "Walk_Fwd_R"],
	&"run": ["Jog_Fwd", "", "", "", "", "", "", ""],
	&"sprint": ["Sprint", "", "", "", "", "", "", ""],
}
## The packs' turns on the spot, to the left and to the right, and the
## library their differences (additive()) are kept in, in the tree.
const TURN_CLIPS: Array[StringName] = [&"Turn01_Left", &"Turn01_Right"]
const ADDITIVE_LIBRARY: StringName = &"loco_add"
## The fighter states in which the legs walk and run with the speed (and
## the Iai stance: walks()).
const MOVING_STATES: Array[StringName] = [&"free", &"step"]
## Below this ground speed (m/s) the travel has no way to it: the legs keep
## the way they had.
const TURN_MIN_SPEED: float = 0.1
## A sprint held further than this from straight ahead (radians, either way;
## past the sideways sprints) turns the body away from the opponent.
const AWAY_AT: float = 112.5 * PI / 180.0
## How stiff the spring the body's turn away follows is (1/s): critically
## damped, about a third of a second.
const AWAY_SPRING: float = 12.0
## Standing, how far the facing turns (radians) from where the feet were set
## before the legs step round (Turn01), and over how many rules frames the
## turn plays (its 30 source frames at 2.0), faded in and out over TURN_FADE.
const TURN_AT: float = 30.0 * PI / 180.0
const TURN_FRAMES: int = 30
const TURN_FADE: int = 6
## How many moving clips the tree shows at once: two ways by two gaits.
const SLOTS: int = 4
## How many rules frames the legs take to go from the idle to the moving
## clips or back (StateClips.fades' locomotion).
const MOVING_FRAMES: int = 6

## Each fighter's gaits (FighterLook id + "|" + the clip's name in the
## model's player -> FootPhase.Gait), measured once.
static var _measured: Dictionary[String, FootPhase.Gait] = {}

var model: FighterModel
var tree: AnimationTree
var fighter_id: StringName = &""
## The clips by gait and way, as names in the tree ("" for none), and their
## gaits.
var clips: Dictionary[StringName, Array] = {}
var gaits: Dictionary[String, FootPhase.Gait] = {}
## The turns on the spot as names in the tree, or empty without the packs.
var turn_clips: Array[String] = []
## The shared step phase (0..1) after the last rules frame, and after the
## one before.
var phase: float = 0.0
var prev_phase: float = 0.0
## The ground speed (m/s) after the last rules frame, and after the one before.
var speed: float = 0.0
var prev_speed: float = 0.0
## The way the legs travel (radians from the body's straight ahead, positive
## to its left) after the last rules frame and the one before.
var way: float = 0.0
var prev_way: float = 0.0
## The fighter's running and sprinting speeds that way, the run's and
## sprint's anchors.
var run_speed: float = 0.0
var sprint_speed: float = 0.0
## The body turned away from the opponent for a sprint held backwards
## (radians, positive to the left), after the last rules frame and the one
## before, and how fast it turns (rad/s).
var away: float = 0.0
var prev_away: float = 0.0
var away_rate: float = 0.0
## How much the moving clips show over the idle (0 to 1), after the last rules
## frame and the one before, eased toward the blend's (MOVING_FRAMES); and the
## last blend that moved, which a stop fades out of.
var moving: float = 0.0
var prev_moving: float = 0.0
var _last_moving: Dictionary = {}
## Standing: the facing the feet were last set at, and the turn on the spot
## playing (its rules frames in; -1 for none) and which way (left).
var set_yaw: float = 0.0
var turn_frame: int = -1
var turn_left: bool = true
## What was shown last: the phase, the idle's weight, the moving clips and
## their weights ([name, weight], heaviest first), the turn on the spot's
## weight, and the body's turn away.
var shown_phase: float = 0.0
var shown_idle: float = 1.0
var shown_clips: Array = []
var shown_turn: float = 0.0
var shown_away: float = 0.0
## Where the legs' feet came down on the ground in the rules frames the last
## update() moved on (the footfalls). A tap step makes none, since the step
## has its own scuff.
var footfalls: Array[Vector3] = []

var _root: AnimationNodeBlendTree
## The rules frame the phase is at; -1 before the first update.
var _frame: int = -1
var _idle_clip: StringName = &""
## The authored clips to show (set_authored()): each slot's animation and
## time, how much of them is the driving clip (a) rather than the one fading
## out (b), and how much they show over the legs' blend.
var _authored: Array = ["", 0.0, "", 0.0]
var _clip_share: float = 0.0
var _authored_amount: float = 0.0
## How much the legs walk under the authored clips, which then show on the
## upper body only (the Iai's stance walked in, task 11).
var _legs_free: float = 0.0
## The tree's slots for the director's clips: a and b, and the same again
## for the upper-body blend.
const AUTHORED_SLOTS: Array[StringName] = [&"clip_a", &"clip_b", &"clip_a_upper", &"clip_b_upper"]
## Bones the upper-body blend leaves to the legs' blend.
const LEG_BONES: Array[String] = ["Root", "Hips", "UpperLeg", "LowerLeg", "Foot", "Toes"]


## Whether the upper-body blend leaves bone `bone` to the legs' blend.
static func is_leg_bone(bone: String) -> bool:
	return LEG_BONES.any(func(leg: String) -> bool: return bone == leg or bone.ends_with(leg))


## `libraries`: whether the Iglesias clip libraries are there (else the CC0
## fallback plays).
func _init(p_model: FighterModel, p_fighter_id: StringName, libraries: bool = ClipLibraries.available()) -> void:
	model = p_model
	fighter_id = p_fighter_id
	run_speed = run_speed_at(0.0)
	sprint_speed = Gaits.sprint_speed()
	_build(libraries)
	for gait: StringName in GAITS:
		for clip: String in clips[gait]:
			if clip != "" and not gaits.has(clip):
				gaits[clip] = gait_of(model, fighter_id, clip)


## The gait of clip `clip` (a name in the model's player) for fighter
## `p_fighter_id` (measured on `p_model` the first time). A clip on the
## Hunter's set (HumanM) that the frame-data table measured takes the table's
## speed and stride (milestone-1 task 55): the rules move the fighter at that
## speed, so the clip plays at 1.0x; FootPhase's own measure (the feet's
## speed at mid-stance) keeps the mid-stances and contacts the shared phase
## runs on, and the speed and stride of every other clip (the CC0 fallback,
## the Rogue's HumanF set).
static func gait_of(p_model: FighterModel, p_fighter_id: StringName, clip: String) -> FootPhase.Gait:
	var key: String = "%s|%s" % [p_fighter_id, clip]
	if not _measured.has(key):
		var g: FootPhase.Gait = FootPhase.measure(p_model, StringName(clip))
		var row: Variant = FrameDataTable.shared().gaits.get(clip.trim_prefix("HumanM/")) if clip.begins_with("HumanM/") else null
		if row is Dictionary:
			g.speed = float(row["speed"])
			g.stride = float(row["stride"])
		_measured[key] = g
	return _measured[key]


## The two ways round legs travelling `p_way` (radians, positive to the
## left) and how much of each: (the way before, the way after, the share of
## the way after), the ways as indices into WAYS.
static func way_weights(p_way: float) -> Vector3:
	var at: float = fposmod(p_way, TAU) / WAY_STEP
	if absf(at - roundf(at)) < 1e-6:
		at = fposmod(roundf(at), float(WAYS))
	var before: int = floori(at) % WAYS
	return Vector3(before, (before + 1) % WAYS, at - floorf(at))


## The weights of idle, walk, run and sprint at `p_speed`: idle at rest, the
## walk at `walk`, the run at `run` and the sprint at `sprint` (and past it),
## each blending linearly into the next.
static func gait_weights(p_speed: float, walk: float, run: float, sprint: float) -> PackedFloat32Array:
	var w: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var anchors: Array[float] = [0.0, walk, run, sprint]
	if p_speed <= 0.0:
		w[0] = 1.0
		return w
	for i: int in 3:
		if p_speed < anchors[i + 1]:
			var t: float = (p_speed - anchors[i]) / maxf(1e-6, anchors[i + 1] - anchors[i])
			w[i] = 1.0 - t
			w[i + 1] = t
			return w
	w[3] = 1.0
	return w


## The rules' running speed travelling `p_way` from the way the fighter faces
## (radians, positive to the left), before the weapon's scaling: the run
## clips' own measured speeds round that way, blended (Gaits.speed()).
static func run_speed_at(p_way: float) -> float:
	return Gaits.speed(&"run", p_way)


## The blend at legs' way `p_way` and speed `p_speed`, with walk, run and
## sprint anchors `walk`, `run` and `sprint`, over clip table `table` (gait
## -> eight names, "" for none): idle's weight, then each moving clip's, as
## {name: weight}; a way with no clip at a gait gives its share to the gait
## below.
static func blend(p_way: float, p_speed: float, walk: float, run: float, sprint: float, table: Dictionary[StringName, Array]) -> Dictionary:
	var ways: Vector3 = way_weights(p_way)
	var g: PackedFloat32Array = gait_weights(p_speed, walk, run, sprint)
	var out: Dictionary = {"": g[0]}
	for k: int in 2:
		var d: int = int(ways.x) if k == 0 else int(ways.y)
		var dw: float = 1.0 - ways.z if k == 0 else ways.z
		if dw <= 0.0:
			continue
		for gi: int in 3:
			var w: float = g[gi + 1] * dw
			if w <= 1e-9:
				continue
			var at: int = gi
			while at > 0 and String(table[GAITS[at]][d]) == "":
				at -= 1
			var clip: String = table[GAITS[at]][d]
			if clip == "":
				# no walk that way (the fallback): the nearest way round with one
				clip = _nearest(table[GAITS[at]], d)
			out[clip] = float(out.get(clip, 0.0)) + w
	return out


## The clip of `row` (eight ways, "" for none) nearest way `d`, or "".
static func _nearest(row: Array, d: int) -> String:
	for off: int in range(1, WAYS / 2 + 1):
		for sgn: int in [1, -1]:
			var c: String = row[(d + sgn * off + WAYS) % WAYS]
			if c != "":
				return c
	return ""


## The speed the legs walk and run at: the rules' ground speed while the
## fighter walks or runs on the ground (walks()), else 0.
static func ground_speed(f: Fighter) -> float:
	if not walks(f):
		return 0.0
	return Vector2(f.vel.x, f.vel.z).length()


## Whether fighter `f` walks or runs on the ground at will: free, stepping
## or in the Iai stance (MOVING_STATES, Fighter.in_stance()).
static func walks(f: Fighter) -> bool:
	return (MOVING_STATES.has(f.state) or f.in_stance()) and not f.airborne()


## The way fighter `f` travels over the ground from the way it faces
## (radians, 0 straight ahead, positive to its left).
static func travel(f: Fighter) -> float:
	return wrapf(atan2(f.vel.x, f.vel.z) - f.yaw, -PI, PI)


## How far fighter `f`'s body turns away from the opponent (radians), now
## that its legs' body is turned `now`: toward its travel while it sprints
## held further than AWAY_AT from straight ahead, else 0. Taken the short way
## round from `now`, so a sprint straight back doesn't flip sides.
static func away_target(f: Fighter, now: float) -> float:
	if f.sprint_frames <= 0 or not walks(f) or f.state == &"step":
		return 0.0
	if Vector2(f.vel.x, f.vel.z).length() <= TURN_MIN_SPEED:
		return 0.0
	var t: float = travel(f)
	if absf(t) <= AWAY_AT:
		return 0.0
	return now + wrapf(t - now, -PI, PI)


## A critically damped spring of stiffness `omega` (1/s) at `x`, moving at
## `rate`, `dt` seconds on toward `target`: (x, rate) then. Exact, so two
## half steps land where one whole step does.
static func spring(x: float, rate: float, target: float, omega: float, dt: float) -> Vector2:
	var d: float = x - target
	var c: float = rate + omega * d
	var e: float = exp(-omega * dt)
	return Vector2(target + (d + c * dt) * e, (rate - omega * c * dt) * e)


## The rules frame the legs were last moved on (-1 before the first update).
func rules_frame() -> int:
	return _frame


## The clip the idle shows (the one last passed to update()).
func idle_clip() -> StringName:
	return _idle_clip


## Seconds into moving clip `clip` (a name in the tree) at shared phase `p`.
func clip_time(clip: String, p: float) -> float:
	var g: FootPhase.Gait = gaits[clip]
	return fposmod(p + g.left_stance, 1.0) * g.length


## The walk's pace, the run's anchor at legs' way `p_way`: the walk clips' own
## speeds, between the two ways round it.
func walk_speed(p_way: float) -> float:
	var ways: Vector3 = way_weights(p_way)
	var row: Array = clips[&"walk"]
	var a: String = row[int(ways.x)] if row[int(ways.x)] != "" else _nearest(row, int(ways.x))
	var b: String = row[int(ways.y)] if row[int(ways.y)] != "" else _nearest(row, int(ways.y))
	return lerpf(gaits[a].speed, gaits[b].speed, ways.z)


## The blend (as blend() gives it) for the legs at way `p_way` and speed
## `p_speed`, with the run's anchor at `run` and the sprint's at `sprint`.
func blend_at(p_way: float, p_speed: float, run: float, sprint: float) -> Dictionary:
	return blend(p_way, p_speed, minf(walk_speed(p_way), run * 0.95), run, sprint, clips)


## How far the body travels per cycle in blend `b` (as blend() gives it): the
## moving clips' strides weighted; the nearest walk's below the walk.
func stride(b: Dictionary, p_way: float) -> float:
	var s: float = 0.0
	var w: float = 0.0
	for clip: String in b:
		if clip != "":
			s += float(b[clip]) * gaits[clip].stride
			w += float(b[clip])
	if w <= 1e-6:
		var row: Array = clips[&"walk"]
		var d: int = int(way_weights(p_way).x)
		return gaits[row[d] if row[d] != "" else _nearest(row, d)].stride
	return s / w


## Each foot's contact (shared phase), left then right, in blend `b`: the
## heaviest moving clip's.
func contacts(b: Dictionary) -> Vector2:
	var best: String = ""
	for clip: String in b:
		if clip != "" and (best == "" or float(b[clip]) > float(b[best])):
			best = clip
	if best == "":
		return Vector2(0.0, 0.5)
	return Vector2(gaits[best].left_contact, gaits[best].right_contact)


## The way fighter `f`'s legs travel now, from the body turned `p_away`: its
## travel, or a tap step's way, or the way they had when it stands.
func legs_way(f: Fighter, p_away: float) -> float:
	if f.state == &"step" and not f.airborne():
		return wrapf(atan2(f.step_dir.x, f.step_dir.z) - f.yaw - p_away, -PI, PI)
	if ground_speed(f) > TURN_MIN_SPEED:
		return wrapf(travel(f) - p_away, -PI, PI)
	return way


## Moves the phase on for each rules frame `f` has stepped since the last
## call, then shows the blend at `alpha` between the last two frames, with the
## idle `idle_clip` at `idle_seconds`.
func update(f: Fighter, idle_clip: StringName, idle_seconds: float, alpha: float) -> void:
	var mult: float = f.speed_mult()
	var frame: int = f.world.frame if f.world != null else _frame
	footfalls.clear()
	if _frame < 0 or frame < _frame:
		# the first update, or a new world: start from where the legs are
		_frame = frame
		away = away_target(f, 0.0)
		prev_away = away
		away_rate = 0.0
		way = legs_way(f, away)
		prev_way = way
		speed = ground_speed(f)
		prev_speed = speed
		prev_phase = phase
		set_yaw = f.yaw
		turn_frame = -1
		moving = 1.0 - float(blend_at(way, speed, run_speed, sprint_speed).get("", 1.0))
		prev_moving = moving
	elif frame > _frame:
		var n: int = frame - _frame
		var dt: float = 1.0 / float(SimConst.FPS)
		for i: int in n:
			prev_away = away
			var turned: Vector2 = spring(away, away_rate, away_target(f, away), AWAY_SPRING, dt)
			away = turned.x
			away_rate = turned.y
		var s: float = ground_speed(f)
		prev_way = way
		way = legs_way(f, away)
		run_speed = run_speed_at(wrapf(way + away, -PI, PI)) * mult
		sprint_speed = Gaits.sprint_speed() * mult
		var stepping: bool = f.state == &"step" and not f.airborne()
		var b: Dictionary = blend_at(way, s, run_speed, sprint_speed)
		if stepping:
			b = blend_at(way, walk_speed(way), run_speed, sprint_speed)
		var step: float = 0.5 / float(SimConst.MOVE_STEP_FRAMES) if stepping else s / stride(b, way) / float(SimConst.FPS)
		var feet: Vector2 = contacts(b)
		var stepped: bool = not stepping and walks(f) and float(b.get("", 1.0)) <= 0.5
		var target: float = 1.0 - float(b.get("", 1.0))
		for i: int in n:
			prev_moving = moving
			moving = move_toward(moving, target, 1.0 / float(MOVING_FRAMES))
			prev_phase = phase
			phase = fposmod(phase + step, 1.0)
			if stepped and step > 0.0:
				for k: int in 2:
					if fposmod(feet[k] - prev_phase, 1.0) < step:
						footfalls.append(_foot_on_ground(f, "Left" if k == 0 else "Right"))
		_turn_on_the_spot(f, s, stepping, n)
		prev_speed = speed if n == 1 else s
		speed = s
		if stepping:
			prev_speed = walk_speed(way)
			speed = prev_speed
		_frame = frame
	# the short way round
	shown_phase = fposmod(prev_phase + wrapf(phase - prev_phase, -0.5, 0.5) * alpha, 1.0)
	shown_away = lerpf(prev_away, away, alpha)
	var shown_way: float = lerp_angle(prev_way, way, alpha)
	var shown_blend: Dictionary = blend_at(shown_way, lerpf(prev_speed, speed, alpha), run_speed, sprint_speed)
	# the moving clips scaled to how far the legs have set off (a stop fades
	# out of the last ones that moved)
	var shown_moving: float = smoothstep(0.0, 1.0, lerpf(prev_moving, moving, alpha))
	var share: float = 1.0 - float(shown_blend.get("", 0.0))
	if share > 1e-5:
		_last_moving = shown_blend
	else:
		shown_blend = _last_moving
		share = 1.0 - float(shown_blend.get("", 0.0))
	shown_idle = 1.0 - shown_moving
	shown_clips.clear()
	for clip: String in shown_blend:
		if clip != "" and share > 1e-5 and float(shown_blend[clip]) * shown_moving / share > 1e-5:
			shown_clips.append([clip, float(shown_blend[clip]) * shown_moving / share])
	shown_clips.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	shown_turn = 0.0
	if turn_frame >= 0:
		var t: float = float(turn_frame) + alpha
		shown_turn = smoothstep(0.0, 1.0, minf(t, float(TURN_FRAMES) - t) / float(TURN_FADE))
	_show(idle_clip, idle_seconds)


## Standing still: once the facing has turned TURN_AT from where the feet
## were set, the legs step round on the spot (Turn01) over TURN_FRAMES; the
## feet are set afresh as it starts. Moving, the feet are set as they go.
func _turn_on_the_spot(f: Fighter, s: float, stepping: bool, frames: int) -> void:
	if turn_frame >= 0:
		turn_frame += frames
		if turn_frame >= TURN_FRAMES:
			turn_frame = -1
	var standing: bool = walks(f) and not stepping and s <= TURN_MIN_SPEED
	if not standing:
		set_yaw = f.yaw
		turn_frame = -1
		return
	var turned: float = wrapf(f.yaw - set_yaw, -PI, PI)
	if turn_frame < 0 and absf(turned) > TURN_AT and not turn_clips.is_empty():
		turn_frame = 0
		turn_left = turned > 0.0
		set_yaw = f.yaw


## Where fighter `f`'s foot `side` stands on the ground: its ankle as the
## model was last posed, at ground level.
func _foot_on_ground(f: Fighter, side: String) -> Vector3:
	var sk: Skeleton3D = model.skeleton
	var at: Vector3 = Vector3(f.pos.x, f.pos.y, f.pos.z)
	if sk.is_inside_tree():
		at = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(side + "Foot")).origin
	return Vector3(at.x, f.pos.y, at.z)


# ------------------------------------------------------------------ the tree

## idle and SLOTS moving clips, each through a seek, chained by Blend2s
## (moving_0 = Blend2(idle, slot_0), moving_1 = Blend2(moving_0, slot_1) ...),
## then the turn on the spot over the legs (legs = Blend2(moving_3, turn),
## filtered to the leg bones), and the director's clips over all of it.
func _build(libraries: bool) -> void:
	tree = AnimationTree.new()
	tree.name = &"Locomotion"
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.add_animation_library(FighterModel.LIBRARY, FighterModel.ANIMATION_LIBRARY)
	var keyed: AnimationLibrary = KeyedClips.load_library()
	if keyed != null:
		tree.add_animation_library(KeyedClips.LIBRARY, keyed)
	var set_name: StringName = ClipLibraries.FIGHTER_SETS.get(fighter_id, &"HumanM")
	if libraries and ClipLibraries.available():
		for s: StringName in ClipLibraries.SETS:
			var lib: AnimationLibrary = ClipLibraries.load_set(s)
			tree.add_animation_library(s, lib)
			# the gaits are measured on the model's own player
			if not model.animation_player.has_animation_library(s):
				model.animation_player.add_animation_library(s, lib)
	else:
		libraries = false
	clips.clear()
	for gait: StringName in GAITS:
		var row: Array = []
		for id: String in (PACK_CLIPS if libraries else FALLBACK_CLIPS)[gait]:
			if id == "":
				row.append("")
			elif libraries:
				row.append("%s/%s" % [set_name, id])
			else:
				row.append("%s/%s" % [FighterModel.LIBRARY, id])
		clips[gait] = row
	turn_clips.clear()
	if libraries:
		var added: AnimationLibrary = AnimationLibrary.new()
		for id: StringName in TURN_CLIPS:
			var turn: Animation = tree.get_animation("%s/%s" % [set_name, id])
			if turn == null:
				continue
			added.add_animation(id, additive(turn, model.skeleton))
			turn_clips.append("%s/%s" % [ADDITIVE_LIBRARY, id])
		tree.add_animation_library(ADDITIVE_LIBRARY, added)
	_root = AnimationNodeBlendTree.new()
	var idle: StringName = model.idle_clip()
	_idle_clip = idle
	var first: String = _anim_name(idle)
	_add_clip(&"idle", first)
	var under: StringName = _seek(&"idle")
	for k: int in SLOTS:
		var slot: StringName = StringName("slot_%d" % k)
		_add_clip(slot, String(clips[&"walk"][0]))
		var moving: StringName = StringName("moving_%d" % k)
		_root.add_node(moving, AnimationNodeBlend2.new())
		_root.connect_node(moving, 0, under)
		_root.connect_node(moving, 1, _seek(slot))
		under = moving
	# the turn on the spot added over the legs alone
	_add_clip(&"turn", turn_clips[0] if not turn_clips.is_empty() else first)
	var legs: AnimationNodeAdd2 = AnimationNodeAdd2.new()
	legs.filter_enabled = true
	var prefix: String = _skeleton_path(tree.get_animation(first))
	var sk: Skeleton3D = model.skeleton
	for b: int in sk.get_bone_count():
		var bone: String = sk.get_bone_name(b)
		if is_leg_bone(bone) and bone != "Root":
			legs.set_filter_path(NodePath("%s:%s" % [prefix, bone]), true)
	_root.add_node(&"legs", legs)
	_root.connect_node(&"legs", 0, under)
	_root.connect_node(&"legs", 1, _seek(&"turn"))
	# the director's clips: a (driving) over b (fading out), over the legs;
	# twice, as a node feeds only one other, for the upper-body blend too
	for slot: StringName in AUTHORED_SLOTS:
		_add_clip(slot, first)
	_root.add_node(&"ab", AnimationNodeBlend2.new())
	_root.connect_node(&"ab", 0, _seek(&"clip_b"))
	_root.connect_node(&"ab", 1, _seek(&"clip_a"))
	_root.add_node(&"ab_upper", AnimationNodeBlend2.new())
	_root.connect_node(&"ab_upper", 0, _seek(&"clip_b_upper"))
	_root.connect_node(&"ab_upper", 1, _seek(&"clip_a_upper"))
	# the clips over the legs' blend on the upper body only, for legs that walk
	# under them (set_authored()'s legs_free)
	var upper: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	upper.filter_enabled = true
	for b: int in sk.get_bone_count():
		var bone: String = sk.get_bone_name(b)
		if not is_leg_bone(bone):
			upper.set_filter_path(NodePath("%s:%s" % [prefix, bone]), true)
	_root.add_node(&"upper", upper)
	_root.connect_node(&"upper", 0, &"legs")
	_root.connect_node(&"upper", 1, &"ab_upper")
	_root.add_node(&"authored", AnimationNodeBlend2.new())
	_root.connect_node(&"authored", 0, &"upper")
	_root.connect_node(&"authored", 1, &"ab")
	_root.connect_node(&"output", 0, &"authored")
	tree.tree_root = _root
	model.add_child(tree)
	tree.active = true


## Clip `anim` as a difference from its own first frame, for an Add2 to lay
## on another clip: each bone's rotation and position track rebuilt so that
## its rest stands where the first frame stood (the tree adds a track's
## difference from the bone's rest on `sk`).
static func additive(anim: Animation, sk: Skeleton3D) -> Animation:
	var out: Animation = anim.duplicate(true)
	for t: int in out.get_track_count():
		var bone: int = sk.find_bone(String(out.track_get_path(t).get_concatenated_subnames()))
		var keys: int = out.track_get_key_count(t)
		if bone < 0 or keys == 0:
			continue
		var rest: Transform3D = sk.get_bone_rest(bone)
		match out.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				var first: Quaternion = out.track_get_key_value(t, 0)
				var rest_q: Quaternion = rest.basis.get_rotation_quaternion()
				for k: int in keys:
					var q: Quaternion = out.track_get_key_value(t, k)
					out.track_set_key_value(t, k, (rest_q * (first.inverse() * q)).normalized())
			Animation.TYPE_POSITION_3D:
				var first: Vector3 = out.track_get_key_value(t, 0)
				for k: int in keys:
					out.track_set_key_value(t, k, rest.origin + (out.track_get_key_value(t, k) as Vector3) - first)
	return out


## Adds an animation node `node` playing `anim`, through a seek.
func _add_clip(node: StringName, anim: String) -> void:
	var clip: AnimationNodeAnimation = AnimationNodeAnimation.new()
	clip.animation = anim
	_root.add_node(node, clip)
	_root.add_node(_seek(node), AnimationNodeTimeSeek.new())
	_root.connect_node(_seek(node), 0, node)


func _show(idle_clip: StringName, idle_seconds: float) -> void:
	if idle_clip != _idle_clip:
		_idle_clip = idle_clip
		(_root.get_node(&"idle") as AnimationNodeAnimation).animation = _anim_name(idle_clip)
	var idle: Animation = tree.get_animation(_anim_name(idle_clip))
	var idle_at: float = fposmod(idle_seconds, idle.length) if idle.loop_mode != Animation.LOOP_NONE else minf(idle_seconds, idle.length)
	tree.set("parameters/%s/seek_request" % _seek(&"idle"), idle_at)
	var total: float = shown_idle
	for k: int in SLOTS:
		var amount: float = 0.0
		if k < shown_clips.size():
			var clip: String = shown_clips[k][0]
			var w: float = shown_clips[k][1]
			var node: AnimationNodeAnimation = _root.get_node(StringName("slot_%d" % k))
			if node.animation != StringName(clip):
				node.animation = StringName(clip)
			tree.set("parameters/%s/seek_request" % _seek(StringName("slot_%d" % k)), clip_time(clip, shown_phase))
			total += w
			amount = w / total if total > 0.0 else 0.0
		tree.set("parameters/moving_%d/blend_amount" % k, amount)
	if not turn_clips.is_empty():
		var turn: AnimationNodeAnimation = _root.get_node(&"turn")
		var name: String = turn_clips[0 if turn_left else 1]
		if turn.animation != StringName(name):
			turn.animation = StringName(name)
		var at: float = float(maxi(0, turn_frame)) * 2.0 / float(SimConst.FPS)
		tree.set("parameters/%s/seek_request" % _seek(&"turn"), at)
	tree.set("parameters/legs/add_amount", shown_turn * shown_idle if not turn_clips.is_empty() else 0.0)
	tree.set("parameters/upper/blend_amount", _authored_amount)
	tree.set("parameters/authored/blend_amount", _authored_amount * (1.0 - _legs_free))
	if _authored_amount > 0.0:
		for k: int in AUTHORED_SLOTS.size():
			var slot: StringName = AUTHORED_SLOTS[k]
			var i: int = k % 2
			var node: AnimationNodeAnimation = _root.get_node(slot)
			if node.animation != StringName(_authored[i * 2]):
				node.animation = StringName(_authored[i * 2])
			tree.set("parameters/%s/seek_request" % _seek(slot), _authored[i * 2 + 1])
		tree.set("parameters/ab/blend_amount", _clip_share)
		tree.set("parameters/ab_upper/blend_amount", _clip_share)
	tree.advance(0.0)


## The director's authored clips to show at the next update: a driving (an
## animation name in the tree and its time, s) over b fading out ("" for
## none), share of them a, and amount of them over the legs' blend (0: the
## legs alone). With only b (the legs taking over from a clip), b shows.
## `legs_free` (0 to 1) lets the legs' blend have the legs and hips back
## from the clips, which then show on the upper body alone.
func set_authored(a: String, a_time: float, b: String, b_time: float, share: float, amount: float, legs_free: float = 0.0) -> void:
	_legs_free = clampf(legs_free, 0.0, 1.0)
	if a == "":
		a = b
		a_time = b_time
		share = 1.0
	if b == "":
		b = a
		b_time = a_time
		share = 1.0
	_authored = [a, a_time, b, b_time]
	_clip_share = share
	_authored_amount = amount if a != "" else 0.0


## The skeleton's path in `anim`'s tracks (the part before the bone).
static func _skeleton_path(anim: Animation) -> String:
	for t: int in anim.get_track_count():
		var path: NodePath = anim.track_get_path(t)
		if path.get_subname_count() > 0:
			return String(path.get_concatenated_names())
	return "Skeleton3D"


static func _seek(node: StringName) -> StringName:
	return StringName(String(node) + "_seek")


static func _anim_name(clip: StringName) -> String:
	if String(clip).contains("/"):
		return String(clip)
	return String(FighterModel.LIBRARY) + "/" + String(clip)
