class_name Locomotion
extends RefCounted
## The legs under a fighter in the match: an AnimationTree on its model
## blending idle (the held weapon's hold clip, or the relaxed idle under a
## guard stance: see FighterView), walk, jog and sprint by the
## rules' speed, advanced by the rules' clock. FighterView updates it every
## frame; it never changes the rules.
##
## - The blend is anchored on the rules' speeds: idle at rest, the walk at
##   WALK_SPEED (the walk clip's own pace), the jog at the fighter's running
##   speed and the sprint at its sprinting speed (both scaled by its weapon,
##   and when disarmed), each blending linearly into the next (weights()).
##   A weapon with a guard stance hands the legs to the guard shuffle instead
##   whenever the fighter isn't running with its guard down (see below).
## - Every clip plays from one shared step phase, so the feet stay in step
##   whatever the blend: at phase 0 the left foot is at mid-stance in every
##   clip, and at about 0.5 the right. The phase moves the blended stride per
##   cycle (stride()), so the planted foot keeps pace with the ground.
## - Each fighter's strides and mid-stances are measured from its own clips by
##   FootPhase, once per fighter.
## - The phase moves once per rules frame, by the speed after that frame
##   (ground_speed(): walking and running on the ground only, so a dodge, an
##   attack's lunge or a jump keeps the legs on the hold clip; the Iai stance
##   walks). In between, the shown phase blends from the frame before by the
##   host's alpha, as the position does. The world's frame stands still in
##   hit-stop and while paused, and so do the legs.
## - The hold clip runs on the rules' clock, as before (the time is passed in).
## - The legs turn toward the way the fighter travels, relative to the way
##   it faces (the opponent), by at most LEG_TURN_MAX: the clips only run
##   forwards, so a strafe is a run turned 80°. Travelling more than
##   BACKWARDS_AT from straight ahead, they turn toward the opposite way and
##   the cycle runs backwards (a backpedal). The turn follows on a spring,
##   once per rules frame, and pose_body() puts it on the body: the pelvis and the
##   thighs share it, the spine turns the chest back, and the clip's own twist
##   above the hips comes out as far as the legs move, so the chest faces the
##   opponent whichever way the legs run. The leg IK plants the feet where
##   the turned legs put them (BodyLayer.clip_feet).
## - The body leans into the acceleration and braces when braking (Lean),
##   stepped with the phase, and a weapon held in a guard rides with it
##   (carry()).
## - With a weapon whose hold has a guard stance (update()'s `stance`), the
##   legs are the guard's (guard 1) unless the fighter runs with its guard
##   down (runs_unguarded()) for RUN_AFTER_FRAMES: standing, walking while
##   blocking or in the Iai stance, tap-stepping, braking, attacking. The guard's legs show the idle
##   (the stance's clip, with GuardStance over it), don't turn toward travel,
##   and their feet are GuardShuffle's, stepped on the same rules frames and
##   planted where the fighter can stand (plants()). The hand-over to the
##   clips and back takes GUARD_RAMP_FRAMES.
## - A swing played in the guard (SwingPlayer) is a strike (plan task
##   14.13): the guard's feet stand planted through it and step in time with
##   the rules' lunge (GuardShuffle.strike_for(); strike()), the leading foot
##   landing on the first active frame. Moves without a swing keep the feet
##   riding, as in the stand-in's attacks. A charge holds the steps.
## - While the guard's legs show (shuffles()), the fighter's footsteps fall
##   where the shuffle's feet come down (footfalls), not by the stride count
##   (FootstepCadence).
##
## A KO's fall plays on the model's AnimationPlayer instead: the view stops
## updating the tree, and the player's pose stands.

## The moving clips, in blend order after idle.
const CLIPS: Array[StringName] = [&"Walk", &"Jog_Fwd", &"Sprint"]
## The tree's node for each, after the idle's (see _build()).
const NODES: Array[StringName] = [&"idle", &"walk", &"jog", &"sprint"]
## The speed (m/s) the walk is anchored at: the walk clip's own pace (FootPhase
## measures 0.93-0.97 m/s on the fighters; the spike's 0.98).
const WALK_SPEED: float = 0.98
## The fighter states in which the legs walk and run with the speed (and
## the Iai stance: walks()).
const MOVING_STATES: Array[StringName] = [&"free", &"step"]
## The states in which a guard's feet stand planted on the ground (and the
## Iai stance: plants()); in the others they ride with the fighter.
const PLANTING_STATES: Array[StringName] = [&"free", &"step", &"land", &"parryAnim"]
## How many rules frames the legs take to go over from the clips to the
## guard's, or back.
const GUARD_RAMP_FRAMES: int = 8
## How many rules frames in a row the fighter runs with its guard down
## before its legs go over to the clips: a tap step with the stick held to
## its end runs one, and stays in the guard.
const RUN_AFTER_FRAMES: int = 3
## From how far the legs are the guard's (guard) the shuffle's landings are
## the fighter's footsteps.
const FOOTFALL_GUARD: float = 0.5
## The furthest the legs turn from straight ahead, either way (radians).
const LEG_TURN_MAX: float = 80.0 * PI / 180.0
## Travelling further than this from straight ahead (radians, either way),
## the legs run backwards. The switch has BACKWARDS_HYSTERESIS round it, so a
## way near it doesn't flicker: backwards past 105°, forwards again under 95°.
## A strafe travels at up to about 92° (the rules widen the orbit a little to
## keep the distance), so it runs forwards whatever came before.
const BACKWARDS_AT: float = 100.0 * PI / 180.0
const BACKWARDS_HYSTERESIS: float = 10.0 * PI / 180.0
## How stiff the spring the legs' turn follows is (1/s): critically damped,
## about a third of a second to turn.
const LEG_SPRING: float = 12.0
## How much of the legs' turn the pelvis takes; the thighs take the rest.
const PELVIS_SHARE: float = 0.7
## Below this ground speed (m/s) the travel has no way to it, and the legs
## turn back to straight ahead and run forwards.
const TURN_MIN_SPEED: float = 0.1

## Each fighter's gaits (FighterLook id -> Array of FootPhase.Gait, in CLIPS
## order), measured once.
static var _measured: Dictionary[StringName, Array] = {}

var model: FighterModel
var tree: AnimationTree
## The fighter's gaits for CLIPS.
var gaits: Array[FootPhase.Gait] = []
## The shared step phase (0..1) after the last rules frame, and after the
## one before.
var phase: float = 0.0
var prev_phase: float = 0.0
## The ground speed (m/s) after the last rules frame, and after the one before.
var speed: float = 0.0
var prev_speed: float = 0.0
## The fighter's running and sprinting speeds, the jog's and sprint's anchors.
var run_speed: float = SimConst.MOVE_RUN_FORWARD
var sprint_speed: float = SimConst.MOVE_SPRINT
## The legs run backwards: the step phase runs back.
var backwards: bool = false
## The legs' turn from straight ahead (radians, positive to the fighter's
## left) after the last rules frame and after the one before, and how fast
## it turns (rad/s).
var leg_yaw: float = 0.0
var prev_leg_yaw: float = 0.0
var leg_yaw_rate: float = 0.0
## What was shown last: the phase, the weights of idle, walk, jog and
## sprint, and the legs' turn.
var shown_phase: float = 0.0
var shown: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
var shown_leg_yaw: float = 0.0
## The lean into acceleration and the brace.
var lean: Lean = Lean.new()
## How far the legs are the guard's (1) rather than the clips' (0), after the
## last rules frame and the one before, and as last shown (eased).
var guard: float = 0.0
var prev_guard: float = 0.0
var shown_guard: float = 0.0
## The guard's feet.
var shuffle: GuardShuffle = GuardShuffle.new()
## Where the guard's feet came down on the ground in the rules frames the
## last update() moved on, while their landings were the footsteps
## (shuffles()): the footfalls. A tap step's own landing makes none, since
## the step has its own scuff.
var footfalls: Array[Vector3] = []

var _root: AnimationNodeBlendTree
## The rules frame the phase is at; -1 before the first update.
var _frame: int = -1
## How many rules frames in a row the fighter has run with its guard down.
var _unguarded: int = 0
var _idle_clip: StringName = &""


func _init(p_model: FighterModel, fighter_id: StringName) -> void:
	model = p_model
	gaits = gaits_of(model, fighter_id)
	_build()


## The gaits of fighter `fighter_id` (measured on `p_model` the first time).
static func gaits_of(p_model: FighterModel, fighter_id: StringName) -> Array[FootPhase.Gait]:
	if not _measured.has(fighter_id):
		var measured: Array[FootPhase.Gait] = []
		for clip: StringName in CLIPS:
			measured.append(FootPhase.measure(p_model, clip))
		_measured[fighter_id] = measured
	var out: Array[FootPhase.Gait] = []
	out.assign(_measured[fighter_id])
	return out


## The weights of idle, walk, jog and sprint at `p_speed`: idle at rest, the
## walk at WALK_SPEED, the jog at `run` and the sprint at `sprint` (and past
## it), each blending linearly into the next.
static func weights(p_speed: float, run: float, sprint: float) -> PackedFloat32Array:
	var w: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var anchors: Array[float] = [0.0, WALK_SPEED, run, sprint]
	if p_speed <= 0.0:
		w[0] = 1.0
		return w
	for i: int in 3:
		if p_speed < anchors[i + 1]:
			var t: float = (p_speed - anchors[i]) / (anchors[i + 1] - anchors[i])
			w[i] = 1.0 - t
			w[i + 1] = t
			return w
	w[3] = 1.0
	return w


## How far the body travels per cycle at `p_speed`: the moving clips'
## strides blended by their weights (a walk's below the walk).
func stride(p_speed: float) -> float:
	var w: PackedFloat32Array = weights(maxf(p_speed, WALK_SPEED), run_speed, sprint_speed)
	var s: float = 0.0
	for i: int in 3:
		s += w[i + 1] * gaits[i].stride
	return s


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


## Whether fighter `f` runs with its guard down: moving at will in the free
## state and not blocking. A guard's legs take the clips then.
static func runs_unguarded(f: Fighter) -> bool:
	return f.state == &"free" and f.moving and not f.blocking


## Whether fighter `f`'s feet can stand planted: on the ground, standing,
## walking, stepping or landing, or in the Iai stance (PLANTING_STATES,
## Fighter.in_stance()).
static func plants(f: Fighter) -> bool:
	return (PLANTING_STATES.has(f.state) or f.in_stance()) and not f.airborne()


## The way fighter `f` travels over the ground from the way it faces
## (radians, 0 straight ahead, positive to its left).
static func travel(f: Fighter) -> float:
	return wrapf(atan2(f.vel.x, f.vel.z) - f.yaw, -PI, PI)


## Whether legs travelling `way` (as travel() gives it) run backwards, when
## they ran backwards before (`was`) or not: past BACKWARDS_AT, with the
## hysteresis.
static func runs_backwards(way: float, was: bool) -> bool:
	var at: float = BACKWARDS_AT + BACKWARDS_HYSTERESIS / 2.0 * (-1.0 if was else 1.0)
	return absf(way) > at


## The legs' turn for travelling `way`: toward it, or toward its opposite when
## running backwards (`back`), by at most LEG_TURN_MAX either way.
static func leg_target(way: float, back: bool) -> float:
	var turn: float = wrapf(way - PI, -PI, PI) if back else way
	return clampf(turn, -LEG_TURN_MAX, LEG_TURN_MAX)


## A critically damped spring of stiffness `omega` (1/s) at `x`, moving at
## `rate`, `dt` seconds on toward `target`: (x, rate) then. Exact, so two
## half steps land where one whole step does.
static func spring(x: float, rate: float, target: float, omega: float, dt: float) -> Vector2:
	var d: float = x - target
	var c: float = rate + omega * d
	var e: float = exp(-omega * dt)
	return Vector2(target + (d + c * dt) * e, (rate - omega * c * dt) * e)


## The steps of fighter `f`'s strike at attack frame `attack_frame`: its lunge
## the way it runs (straight ahead, or along the last dodge), in the
## fighter's frame. None while charging, so the feet hold still then.
static func strike(f: Fighter, attack_frame: int) -> GuardShuffle.Strike:
	if f.atk.charging:
		return GuardShuffle.Strike.new()
	var way: Vector3 = Vector3.BACK
	if f.atk.lunge_dir != null:
		way = GuardShuffle.facing(f.yaw).inverse() * Vector3(f.atk.lunge_dir.x, 0.0, f.atk.lunge_dir.z)
	return GuardShuffle.strike_for(f.atk.def, f.atk.lunge_total, way, attack_frame)


## The rules frame the legs were last moved on (-1 before the first update).
func rules_frame() -> int:
	return _frame


## True when the fighter's footsteps fall where the shuffle's feet land
## (footfalls) rather than by the stride count: while its legs are the
## guard's, at least FOOTFALL_GUARD of the way.
func shuffles() -> bool:
	return guard >= FOOTFALL_GUARD


## The clip the idle shows (the one last passed to update()).
func idle_clip() -> StringName:
	return _idle_clip


## Seconds into moving clip `index` (in CLIPS) at shared phase `p`.
func clip_time(index: int, p: float) -> float:
	var g: FootPhase.Gait = gaits[index]
	return fposmod(p + g.left_stance, 1.0) * g.length


## Moves the phase on for each rules frame `f` has stepped since the last
## call, then shows the blend at `alpha` between the last two frames, with the
## hold clip `idle_clip` at `idle_seconds`. `stance`: the held weapon's hold
## has a guard stance, whose legs are the guard's unless the fighter runs
## unguarded.
func update(f: Fighter, idle_clip: StringName, idle_seconds: float, alpha: float, stance: bool = false) -> void:
	var mult: float = f.speed_mult()
	run_speed = SimConst.MOVE_RUN_FORWARD * mult
	sprint_speed = SimConst.MOVE_SPRINT * mult
	var frame: int = f.world.frame if f.world != null else _frame
	var pos: Vector3 = Vector3(f.pos.x, f.pos.y, f.pos.z)
	footfalls.clear()
	var running: bool = runs_unguarded(f)
	if _frame < 0 or frame < _frame:
		_unguarded = RUN_AFTER_FRAMES if running else 0
	elif frame > _frame:
		_unguarded = _unguarded + frame - _frame if running else 0
	var guarded: float = 1.0 if stance and _unguarded < RUN_AFTER_FRAMES else 0.0
	var striking: bool = stance and SwingPlayer.plays(f) and not f.airborne()
	if _frame < 0 or frame < _frame:
		# the first update, or a new world: start from where the legs are
		_frame = frame
		speed = ground_speed(f)
		prev_speed = speed
		prev_phase = phase
		prev_leg_yaw = leg_yaw
		lean.reset(f)
		guard = guarded
		prev_guard = guard
		shuffle.reset(pos, f.yaw)
	elif frame > _frame:
		var from: Vector3 = shuffle.body
		var from_yaw: float = shuffle.body_yaw
		lean.step(f, frame - _frame)
		var s: float = ground_speed(f)
		var target: float = 0.0
		if s > TURN_MIN_SPEED and guarded < 1.0:
			var way: float = travel(f)
			backwards = runs_backwards(way, backwards)
			target = leg_target(way, backwards)
		else:
			backwards = false
		var length: float = stride(s)
		var step: float = s / length / float(SimConst.FPS) if length > 0.0 else 0.0
		if backwards:
			step = -step
		for i: int in frame - _frame:
			prev_phase = phase
			phase = fposmod(phase + step, 1.0)
			prev_leg_yaw = leg_yaw
			var turned: Vector2 = spring(leg_yaw, leg_yaw_rate, target, LEG_SPRING, 1.0 / float(SimConst.FPS))
			leg_yaw = turned.x
			leg_yaw_rate = turned.y
			prev_guard = guard
			guard = move_toward(guard, guarded, 1.0 / float(GUARD_RAMP_FRAMES))
			# the guard's feet stand where they can while the guard's legs
			# show, and ride with the fighter while the clips have them; over
			# frames missed, the fighter moved evenly
			var k: float = float(i + 1) / float(frame - _frame)
			var plan: GuardShuffle.Strike = strike(f, f.atk.frame - (frame - _frame - 1 - i)) if striking else null
			shuffle.step(from.lerp(pos, k), lerp_angle(from_yaw, f.yaw, k), (stance and plants(f) or striking) and guard > 0.0, plan)
			if shuffles() and f.state != &"step":
				for side: String in shuffle.landed:
					footfalls.append(shuffle.feet[side].at)
		prev_speed = speed if frame - _frame == 1 else s
		speed = s
		_frame = frame
	# the short way round: forwards or, running backwards, back
	shown_phase = fposmod(prev_phase + wrapf(phase - prev_phase, -0.5, 0.5) * alpha, 1.0)
	shown_guard = smoothstep(0.0, 1.0, lerpf(prev_guard, guard, alpha))
	shown = weights(lerpf(prev_speed, speed, alpha), run_speed, sprint_speed)
	for i: int in 4:
		shown[i] = lerpf(shown[i], 1.0 if i == 0 else 0.0, shown_guard)
	shown_leg_yaw = lerpf(prev_leg_yaw, leg_yaw, alpha)
	lean.show(alpha)
	shuffle.show(alpha)
	_show(idle_clip, idle_seconds)


## Lays the legs' turn, the lean and the brace, as last shown, on `body`:
## - the pelvis takes PELVIS_SHARE of the legs' turn and the thighs the
##   rest, the spine turns the chest back, and the clip's own twist above the
##   hips comes out as far as the legs move, so the chest keeps facing the
##   way the fighter faces;
## - the whole body tilts by the lean, and the hips drop by the brace on top
##   of whatever offset `body` already has.
func pose_body(body: BodyLayer) -> void:
	body.pelvis_yaw = shown_leg_yaw * PELVIS_SHARE
	body.thigh_yaw = shown_leg_yaw * (1.0 - PELVIS_SHARE)
	body.spine_yaw = -body.pelvis_yaw
	body.untwist = 1.0 - shown[0]
	body.lean = Lean.rotation(lean.shown_tilt)
	body.hips_offset.y -= lean.shown_drop


## How the lean and the brace move the upper body of `model`'s skeleton (see
## Lean.carry()), for a weapon held in a guard to ride with it.
func carry(sk: Skeleton3D) -> Transform3D:
	return lean.carry(sk.get_bone_global_pose(sk.find_bone("Root")).origin)


# ------------------------------------------------------------------ the tree

## idle, walk, jog and sprint, each through a seek, then
## walk_jog = Blend2(walk, jog), to_sprint = Blend2(walk_jog, sprint) and
## move = Blend2(idle, to_sprint).
func _build() -> void:
	tree = AnimationTree.new()
	tree.name = &"Locomotion"
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.add_animation_library(FighterModel.LIBRARY, FighterModel.ANIMATION_LIBRARY)
	_root = AnimationNodeBlendTree.new()
	var clips: Array[StringName] = [model.idle_clip()]
	clips.append_array(CLIPS)
	for i: int in NODES.size():
		var anim: AnimationNodeAnimation = AnimationNodeAnimation.new()
		anim.animation = _anim_name(clips[i])
		_root.add_node(NODES[i], anim)
		_root.add_node(_seek(NODES[i]), AnimationNodeTimeSeek.new())
		_root.connect_node(_seek(NODES[i]), 0, NODES[i])
	_idle_clip = clips[0]
	_root.add_node(&"walk_jog", AnimationNodeBlend2.new())
	_root.connect_node(&"walk_jog", 0, _seek(&"walk"))
	_root.connect_node(&"walk_jog", 1, _seek(&"jog"))
	_root.add_node(&"to_sprint", AnimationNodeBlend2.new())
	_root.connect_node(&"to_sprint", 0, &"walk_jog")
	_root.connect_node(&"to_sprint", 1, _seek(&"sprint"))
	_root.add_node(&"move", AnimationNodeBlend2.new())
	_root.connect_node(&"move", 0, _seek(&"idle"))
	_root.connect_node(&"move", 1, &"to_sprint")
	_root.connect_node(&"output", 0, &"move")
	tree.tree_root = _root
	model.add_child(tree)
	tree.active = true


func _show(idle_clip: StringName, idle_seconds: float) -> void:
	if idle_clip != _idle_clip:
		_idle_clip = idle_clip
		(_root.get_node(&"idle") as AnimationNodeAnimation).animation = _anim_name(idle_clip)
	var idle: Animation = tree.get_animation(_anim_name(idle_clip))
	var idle_at: float = fposmod(idle_seconds, idle.length) if idle.loop_mode != Animation.LOOP_NONE else minf(idle_seconds, idle.length)
	tree.set("parameters/%s/seek_request" % _seek(&"idle"), idle_at)
	for i: int in CLIPS.size():
		tree.set("parameters/%s/seek_request" % _seek(NODES[i + 1]), clip_time(i, shown_phase))
	var w: PackedFloat32Array = shown
	var moving: float = 1.0 - w[0]
	tree.set("parameters/move/blend_amount", moving)
	tree.set("parameters/to_sprint/blend_amount", w[3] / moving if moving > 0.0 else 0.0)
	tree.set("parameters/walk_jog/blend_amount", w[2] / (w[1] + w[2]) if w[1] + w[2] > 0.0 else 1.0)
	tree.advance(0.0)


static func _seek(node: StringName) -> StringName:
	return StringName(String(node) + "_seek")


static func _anim_name(clip: StringName) -> String:
	return String(FighterModel.LIBRARY) + "/" + String(clip)
