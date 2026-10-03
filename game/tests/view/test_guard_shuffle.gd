extends GutTest
## The guard shuffle step (GuardShuffle): how the feet of a fighter in its
## guard stance move as it walks, in place of the walking clips. The step
## planner on its own, on scripted walks: the lead foot steps first and the
## trailing foot closes, in eight directions; the feet never cross the
## mid-line or pass each other; planted feet stay where they stand on the
## ground, walking, circling and turning; the cadence comes from the speed;
## the feet come back to the stance's spots and angles. Then the fighter in
## the match's view on the real rules: the Katana's guard walk, tap steps and
## the Iai stance shuffle on the posed skeleton with the planted feet under
## 1 cm, unguarded running hands over to the clips and back without a jump,
## and the weapon rides the pelvis's bounce on a spring.

const SIDES: Array[String] = ["Right", "Left"]
## The eight ways to move, in the fighter's own frame (+X its left, +Z
## forward), with the foot that steps first: the one on the side it travels
## to, weighting across over along (the stance is narrower than it is long).
const WAYS: Array = [
	["forward", Vector3(0.0, 0.0, 1.0), "Right"],
	["forward-right", Vector3(-0.7071, 0.0, 0.7071), "Right"],
	["right", Vector3(-1.0, 0.0, 0.0), "Right"],
	["back-right", Vector3(-0.7071, 0.0, -0.7071), "Right"],
	["back", Vector3(0.0, 0.0, -1.0), "Left"],
	["back-left", Vector3(0.7071, 0.0, -0.7071), "Left"],
	["left", Vector3(1.0, 0.0, 0.0), "Left"],
	["forward-left", Vector3(0.7071, 0.0, 0.7071), "Left"],
]
## How far each foot keeps from the mid-line, at least (m).
const MID_LINE_CLEAR: float = 0.02
## How fast the rules speed a walk up and slow it down (m/s²).
const ACCEL: float = SimConst.MOVE_ACCEL
const DECEL: float = SimConst.MOVE_DECEL
## A tap step's speed: 0.55 m in 8 frames.
const TAP_SPEED: float = SimConst.MOVE_STEP_DIST / (SimConst.MOVE_STEP_FRAMES * SimConst.DT)


func after_each() -> void:
	MoveBench.free_all()
	SimHelpers.dispose_all()


## The rules' guard walk (blocking, 60% of the run) the way `way` goes in
## the fighter's frame (m/s).
static func _guard_speed(way: Vector3) -> float:
	var ahead: float = SimConst.MOVE_RUN_FORWARD if way.z >= 0.0 else SimConst.MOVE_RUN_BACK
	return Vector2(way.x * SimConst.MOVE_RUN_STRAFE, way.z * ahead).length() * SimConst.MOVE_BLOCK_SPEED_MULT


## A scripted walk: a fighter facing `yaw` moves the way `way` (its own
## frame) at `speed` for `frames` rules frames from rest, speeding up and
## slowing down as the rules do, then stands for `after`. `shuffle` steps on
## each frame, and `each` is called after it with the frame's index.
func _walk(shuffle: GuardShuffle, way: Vector3, speed: float, frames: int, after: int, each: Callable = Callable(), yaw: float = 0.7) -> void:
	var pos: Vector3 = Vector3(1.0, 0.0, -2.0)
	var v: float = 0.0
	shuffle.reset(pos, yaw)
	for i: int in frames + after:
		var want: float = speed if i < frames else 0.0
		v = move_toward(v, want, (ACCEL if want > v else DECEL) / 60.0)
		pos += Basis(Vector3.UP, yaw) * way.normalized() * v / 60.0
		shuffle.step(pos, yaw, true)
		if each.is_valid():
			each.call(i)


## Where a foot is in the fighter's frame: its spot moved by its offset.
static func _in_frame(foot: GuardShuffle.Foot) -> Vector3:
	return foot.spot + foot.offset


## Which foot lifts on each frame it lifts, in order.
class Lifts:
	var order: Array[String] = []
	var _was: Dictionary[String, bool] = {}

	func see(shuffle: GuardShuffle) -> void:
		for side: String in SIDES:
			var now: bool = shuffle.feet[side].swinging
			if now and not _was.get(side, false):
				order.append(side)
			_was[side] = now


# ------------------------------------------------------------------ the planner

## Standing still, the feet stay planted on the stance's spots, turned as
## the stance turns them.
func test_standing_still_the_feet_stay_on_the_stance() -> void:
	var shuffle: GuardShuffle = GuardShuffle.new()
	_walk(shuffle, Vector3.FORWARD, 0.0, 0, 120, func(_i: int) -> void:
		for side: String in SIDES:
			assert_false(shuffle.feet[side].swinging, "%s foot planted" % side))
	for side: String in SIDES:
		var foot: GuardShuffle.Foot = shuffle.feet[side]
		assert_eq(foot.spot, Vector3(GuardStance.FEET[side].x, 0.0, GuardStance.FEET[side].z), "%s: the stance's spot" % side)
		assert_almost_eq(foot.spot_turn, deg_to_rad(GuardStance.FOOT_YAW[side]), 1e-6, "%s: the stance's angle" % side)
		assert_almost_eq(foot.offset, Vector3.ZERO, Vector3.ONE * 1e-6, "%s: on it" % side)
		assert_eq(foot.steps, 0, "%s: no steps" % side)


## Walking each of the eight ways, the lead foot steps first, the trailing
## foot closes after it, and they take turns; standing again, both are back
## on the stance's spots at its angles.
func test_the_lead_foot_steps_first_and_the_trailing_foot_closes() -> void:
	for way: Array in WAYS:
		var shuffle: GuardShuffle = GuardShuffle.new()
		var lifts: Lifts = Lifts.new()
		_walk(shuffle, way[1], 1.5, 60, 40, func(_i: int) -> void: lifts.see(shuffle))
		gut.p("%s: %s" % [way[0], " ".join(lifts.order.map(func(s: String) -> String: return s.left(1)))])
		assert_gt(lifts.order.size(), 5, "%s: it steps" % way[0])
		assert_eq(lifts.order[0], way[2], "%s: leads with the %s foot" % [way[0], way[2].to_lower()])
		for i: int in range(1, lifts.order.size()):
			assert_ne(lifts.order[i], lifts.order[i - 1], "%s: step %d by the other foot" % [way[0], i + 1])
		for side: String in SIDES:
			var foot: GuardShuffle.Foot = shuffle.feet[side]
			assert_false(foot.swinging, "%s: the %s foot down" % [way[0], side])
			assert_lt(foot.offset.length(), 0.02, "%s: the %s foot back on its spot (%.1f cm off)" % [way[0], side, foot.offset.length() * 100.0])
			assert_lt(absf(rad_to_deg(foot.turn)), 1.0, "%s: the %s foot at the stance's angle" % [way[0], side])


## Walking any way at any guard speed, or a tap step's, each foot stays on
## its own side of the mid-line, clear of it, and the right foot stays in
## front of the left: they never cross or pass.
func test_the_feet_never_cross_the_mid_line_or_pass_each_other() -> void:
	for way: Array in WAYS:
		var walks: Array = [[0.5, 60], [1.2, 60], [_guard_speed(way[1]), 60], [TAP_SPEED, SimConst.MOVE_STEP_FRAMES]]
		for walk: Array in walks:
			var shuffle: GuardShuffle = GuardShuffle.new()
			# the nearest the feet came to the mid-line, and the right foot
			# to being level with the left
			var least: Dictionary[String, float] = {"clear": INF, "apart": INF}
			_walk(shuffle, way[1], walk[0], walk[1], 40, func(_i: int) -> void:
				var right: Vector3 = _in_frame(shuffle.feet["Right"])
				var left: Vector3 = _in_frame(shuffle.feet["Left"])
				least["clear"] = minf(least["clear"], minf(-right.x, left.x))
				least["apart"] = minf(least["apart"], right.z - left.z))
			gut.p("%s at %.2f m/s: %.1f cm clear of the mid-line, the right foot %.1f cm ahead" % [way[0], walk[0], least["clear"] * 100.0, least["apart"] * 100.0])
			assert_gt(least["clear"], MID_LINE_CLEAR, "%s at %.2f m/s: each foot on its own side" % [way[0], walk[0]])
			assert_gt(least["apart"], 0.1, "%s at %.2f m/s: the right foot in front" % [way[0], walk[0]])


## Circling an opponent 2.5 m off at the guard's strafing speed, turning to
## face it, each way: a planted foot stays exactly where it stands on the
## ground and as it was turned, at every rules frame and between them.
func test_planted_feet_stay_put_while_circling() -> void:
	for turn: float in [1.0, -1.0]:
		var shuffle: GuardShuffle = GuardShuffle.new()
		var radius: float = 2.5
		var rate: float = _guard_speed(Vector3.RIGHT) / radius * turn
		var around: float = 0.3
		var place: Callable = func(a: float) -> Array:
			var pos: Vector3 = Vector3(sin(a), 0.0, cos(a)) * radius
			# facing the opponent at the centre
			return [pos, a + PI]
		var at: Array = place.call(around)
		shuffle.reset(at[0], at[1])
		var stood: Dictionary[String, Array] = {}
		var planted_frames: int = 0
		var steps: int = 0
		for i: int in 150:
			around += rate / 60.0 if i < 120 else 0.0
			at = place.call(around)
			shuffle.step(at[0], at[1], true)
			for side: String in SIDES:
				var foot: GuardShuffle.Foot = shuffle.feet[side]
				if foot.swinging:
					stood.erase(side)
					continue
				if not stood.has(side):
					stood[side] = [foot.at, foot.yaw]
					steps += 1
					continue
				planted_frames += 1
				assert_almost_eq(foot.at, stood[side][0], Vector3.ONE * 1e-5, "frame %d: the planted %s foot stays put" % [i, side])
				assert_almost_eq(foot.yaw, stood[side][1], 1e-5, "frame %d: and turned as it was" % i)
				shuffle.show(0.5)
				assert_almost_eq(foot.shown_at, foot.at, Vector3.ONE * 1e-5, "frame %d: and between frames" % i)
		assert_gt(steps, 10, "circling, the feet step")
		assert_gt(planted_frames, 100, "and stand between steps")
		for side: String in SIDES:
			assert_lt(shuffle.feet[side].offset.length(), 0.02, "%s foot back on its spot" % side)
			assert_lt(absf(rad_to_deg(shuffle.feet[side].turn)), 1.0, "%s foot at the stance's angle" % side)


## Turning on the spot, the feet step round with the fighter, one at a time,
## turning as they swing rather than snapping round as they land, and end on
## the stance's spots at its angles.
func test_turning_on_the_spot_steps_the_feet_round() -> void:
	var shuffle: GuardShuffle = GuardShuffle.new()
	var pos: Vector3 = Vector3(0.5, 0.0, 0.5)
	var yaw: float = 0.2
	shuffle.reset(pos, yaw)
	var lifts: Lifts = Lifts.new()
	for i: int in 100:
		yaw += deg_to_rad(90.0) / 60.0 if i < 60 else 0.0
		var was: Dictionary[String, float] = {"Right": shuffle.feet["Right"].yaw, "Left": shuffle.feet["Left"].yaw}
		shuffle.step(pos, yaw, true)
		lifts.see(shuffle)
		for side: String in SIDES:
			var turned: float = rad_to_deg(absf(wrapf(shuffle.feet[side].yaw - was[side], -PI, PI)))
			assert_lt(turned, 6.0, "frame %d: the %s foot turns smoothly (%.1f° in a frame)" % [i, side, turned])
		assert_false(shuffle.feet["Right"].swinging and shuffle.feet["Left"].swinging, "frame %d: one foot at a time" % i)
		for side: String in SIDES:
			assert_lt(absf(rad_to_deg(shuffle.feet[side].turn)), 25.0, "frame %d: the %s foot keeps up" % [i, side])
	assert_gt(lifts.order.size(), 3, "the feet step round")
	for side: String in SIDES:
		assert_lt(shuffle.feet[side].offset.length(), 0.02, "%s foot on its spot" % side)
		assert_lt(absf(rad_to_deg(shuffle.feet[side].turn)), 1.0, "%s foot at the stance's angle" % side)


## The cadence comes from the speed: the faster the walk, the shorter each
## swing and the more steps a second, and the longer each step.
func test_the_cadence_follows_the_speed() -> void:
	var rates: Array[float] = []
	var swings: Array[float] = []
	var lengths: Array[float] = []
	for speed: float in [0.5, 1.0, 1.6, 2.34]:
		var shuffle: GuardShuffle = GuardShuffle.new()
		var lifts: Lifts = Lifts.new()
		# how many frames each swing took, as it lands
		var frames: Array[int] = []
		var was: Dictionary[String, bool] = {}
		_walk(shuffle, Vector3.BACK, speed, 180, 0, func(i: int) -> void:
			if i < 60:
				return
			lifts.see(shuffle)
			for side: String in SIDES:
				var foot: GuardShuffle.Foot = shuffle.feet[side]
				if was.get(side, false) and not foot.swinging:
					frames.append(foot.frames)
				was[side] = foot.swinging)
		var rate: float = float(lifts.order.size()) / 2.0
		var mean: float = 0.0
		for n: int in frames:
			mean += float(n) / float(frames.size())
		rates.append(rate)
		swings.append(mean)
		lengths.append(speed * 2.0 / rate)
		gut.p("%.2f m/s: %.1f steps a second, swings of %.1f frames, each foot %.0f cm a step" % [speed, rate, mean, speed * 2.0 / rate * 100.0])
	for i: int in range(1, rates.size()):
		assert_gt(rates[i], rates[i - 1], "more steps a second at the faster walk")
		assert_lte(swings[i], swings[i - 1], "swings no longer")
		assert_gt(lengths[i], lengths[i - 1], "longer steps")
	assert_between(swings[-1], float(GuardShuffle.SWING_FRAMES_MIN), 8.0, "brisk at the guard's full walk")


## Every step lands at the stance's angle and within reach of its spot, and
## walking straight the planted feet keep the stance's angles.
func test_steps_keep_the_stance_s_angles_and_land_near_their_spots() -> void:
	for way: Array in WAYS:
		var shuffle: GuardShuffle = GuardShuffle.new()
		var was: Dictionary[String, bool] = {"Right": false, "Left": false}
		_walk(shuffle, way[1], _guard_speed(way[1]), 90, 30, func(i: int) -> void:
			for side: String in SIDES:
				var foot: GuardShuffle.Foot = shuffle.feet[side]
				if was[side] and not foot.swinging:
					assert_almost_eq(foot.turn, 0.0, 1e-6, "%s frame %d: the %s foot lands at the stance's angle" % [way[0], i, side])
					assert_lte(foot.offset.length(), GuardShuffle.LEAD_MOST + 1e-4, "%s frame %d: the %s foot lands near its spot" % [way[0], i, side])
				if not foot.swinging:
					assert_almost_eq(foot.turn, 0.0, 1e-5, "%s frame %d: the planted %s foot keeps its angle" % [way[0], i, side])
				was[side] = foot.swinging)


## Walking steadily any way at the guard's speed, the feet stand about their
## spots: each step lands ahead about as far as the foot falls behind before
## it steps again, so the fighter stays over its stance rather than ahead of
## its feet.
func test_walking_the_feet_stand_about_their_spots() -> void:
	for way: Array in WAYS:
		var shuffle: GuardShuffle = GuardShuffle.new()
		var dir: Vector3 = (way[1] as Vector3).normalized()
		# the sum of the planted feet's offsets along the way, and how many
		var sum: Array[float] = [0.0, 0.0]
		_walk(shuffle, way[1], _guard_speed(way[1]), 150, 0, func(i: int) -> void:
			if i < 30:
				return
			for side: String in SIDES:
				var foot: GuardShuffle.Foot = shuffle.feet[side]
				if not foot.swinging:
					sum[0] += foot.offset.dot(dir)
					sum[1] += 1.0)
		var mean: float = sum[0] / sum[1]
		gut.p("%s: the planted feet stand %+.1f cm along the way from their spots, on average" % [way[0], mean * 100.0])
		assert_lt(absf(mean), 0.03, "%s: the feet stand about their spots" % way[0])


## Setting off from rest at the guard's walk, the first step is paced for the
## speed the fighter is reaching, so the other foot, waiting, falls no more
## than 23 cm behind its spot (paced for the first frame's speed, 26).
func test_setting_off_the_waiting_foot_keeps_up() -> void:
	for way: Array in [["forward", Vector3.BACK], ["back", Vector3.FORWARD]]:
		var shuffle: GuardShuffle = GuardShuffle.new()
		var furthest: Array[float] = [0.0]
		_walk(shuffle, way[1], _guard_speed(way[1]), 30, 0, func(_i: int) -> void:
			for side: String in SIDES:
				if not shuffle.feet[side].swinging:
					furthest[0] = maxf(furthest[0], shuffle.feet[side].offset.length()))
		gut.p("setting off %s: a planted foot %.1f cm off its spot at most" % [way[0], furthest[0] * 100.0])
		assert_lt(furthest[0], 0.23, "setting off %s: the waiting foot keeps up" % way[0])


## A step lifts the foot a little, highest halfway, and puts it down on the
## ground.
func test_a_step_lifts_the_foot_low() -> void:
	var shuffle: GuardShuffle = GuardShuffle.new()
	var highest: Array[float] = [0.0]
	_walk(shuffle, Vector3.BACK, 2.0, 60, 30, func(_i: int) -> void:
		for side: String in SIDES:
			var foot: GuardShuffle.Foot = shuffle.feet[side]
			highest[0] = maxf(highest[0], foot.height)
			if not foot.swinging:
				assert_eq(foot.height, 0.0, "a planted foot on the ground"))
	assert_between(highest[0], 0.015, GuardShuffle.LIFT, "a low lift")


## Where the feet can't stand planted (in the air, in an attack, a dodge),
## they ride with the fighter where they are; planted again, they stand.
func test_riding_feet_move_with_the_fighter() -> void:
	var shuffle: GuardShuffle = GuardShuffle.new()
	var pos: Vector3 = Vector3.ZERO
	shuffle.reset(pos, 0.0)
	for i: int in 10:
		pos += Vector3(0.0, 0.05, 0.1)
		shuffle.step(pos, 0.0, false)
		assert_true(shuffle.riding, "riding")
		for side: String in SIDES:
			var foot: GuardShuffle.Foot = shuffle.feet[side]
			assert_false(foot.swinging, "on its spot, it doesn't step")
			assert_almost_eq(foot.at, Vector3(pos.x, 0.0, pos.z) + foot.spot, Vector3.ONE * 1e-5, "the %s foot rides with the fighter" % side)
			assert_almost_eq(foot.height, pos.y, 1e-6, "up with it")
	pos.y = 0.0
	shuffle.step(pos, 0.0, true)
	var stood: Vector3 = shuffle.feet["Right"].at
	shuffle.step(pos + Vector3(0.0, 0.0, 0.01), 0.0, true)
	assert_false(shuffle.riding)
	assert_almost_eq(shuffle.feet["Right"].at, stood, Vector3.ONE * 1e-6, "planted again, it stands")


## The pelvis bobs with the shuffle (lower as the stance opens), and the
## weapon follows the bob on a slight spring: as far, a little later.
func test_the_weapon_follows_the_pelvis_bob_on_a_spring() -> void:
	var shuffle: GuardShuffle = GuardShuffle.new()
	var bob: Array[float] = []
	var weapon: Array[float] = []
	_walk(shuffle, Vector3.BACK, _guard_speed(Vector3.BACK), 180, 0, func(i: int) -> void:
		if i >= 60:
			bob.append(shuffle.bob)
			weapon.append(shuffle.weapon_bob))
	var lo: float = bob.min()
	var hi: float = bob.max()
	gut.p("the pelvis bobs %.1f to %+.1f cm, the weapon %.1f to %+.1f cm" % [lo * 100.0, hi * 100.0, weapon.min() * 100.0, weapon.max() * 100.0])
	assert_between(hi - lo, 0.008, 0.04, "a visible bob, not a bounce")
	var swing: float = weapon.max() - weapon.min()
	assert_between(swing / (hi - lo), 0.6, 1.1, "the weapon follows it")
	# the lag: the shift of the weapon's track that best matches the pelvis's
	var best: int = 0
	var least: float = INF
	for lag: int in range(0, 8):
		var err: float = 0.0
		for i: int in range(8, bob.size()):
			err += absf(weapon[i] - bob[i - lag])
		if err < least:
			least = err
			best = lag
	assert_between(best, 1, 4, "a little later")
	# standing, nothing bobs
	var still: GuardShuffle = GuardShuffle.new()
	_walk(still, Vector3.BACK, 0.0, 0, 30)
	assert_eq(still.bob, 0.0, "standing, the pelvis doesn't bob")
	assert_almost_eq(still.weapon_bob, 0.0, 1e-9, "nor the weapon")


# ------------------------------------------------------------------ on the fighter

## Two fighters `gap` apart, fighter 0 facing +Z toward fighter 1.
func _world(gap: float, weapon: WeaponDef = Moves.KATANA) -> World:
	return SimHelpers.make_world(weapon, Moves.KATANA, gap)


func _view(fighter_id: StringName, weapon: WeaponDef = Moves.KATANA) -> FighterView:
	var v: FighterView = FighterView.new()
	add_child_autofree(v)
	v.setup(fighter_id, 0, weapon.id, 0)
	v.model.skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	return v


static func _pos(f: Fighter) -> Vector3:
	return Vector3(f.pos.x, f.pos.y, f.pos.z)


## The posed feet, toes and their skeleton, after the modifiers.
class Feet:
	var world: Dictionary[String, Vector3] = {}
	var frame: Dictionary[String, Vector3] = {}
	var toes: Dictionary[String, Vector3] = {}


func _feet(v: FighterView) -> Feet:
	var posed: PoseCheck.Frame = await PoseCheck.frame_of(v.model)
	var sk: Skeleton3D = v.model.skeleton
	var out: Feet = Feet.new()
	for side: String in SIDES:
		var foot: Vector3 = posed.bones[sk.find_bone(side + "Foot")].origin
		out.frame[side] = foot
		out.world[side] = sk.global_transform * foot
		out.toes[side] = posed.bones[sk.find_bone(side + "Toes")].origin
	return out


## What a walk measured on the posed skeleton.
class Watch:
	## The furthest a planted foot moved over the ground from where it was
	## put down (m), and over how many planted frames.
	var slide: float = 0.0
	var planted: int = 0
	## How near either foot or its toes came to the mid-line (m).
	var clear: float = INF
	## The most a shown foot moved in a frame (m).
	var jump: float = 0.0
	var steps: int = 0
	## The furthest the legs turned toward travel (radians), and the body
	## leaned (radians).
	var turned: float = 0.0
	var leaned: float = 0.0
	## The least the legs were the guard's.
	var least_guard: float = 1.0
	var _stood: Dictionary[String, Vector3] = {}
	var _last: Dictionary[String, Vector3] = {}
	## Each foot stood planted on the rules frame before.
	var _was: Dictionary[String, bool] = {}


## Plays `inputs` (a RawInput per frame) for fighter 0 from rest, showing it
## each frame at alpha 0.5 between the rules frames and then at 1, and
## watches its posed feet while the shuffle has them (and which foot lifts
## when, into `lifts`).
func _watch(W: World, v: FighterView, inputs: Array[RawInput], lifts: Lifts = null) -> Watch:
	var f: Fighter = W.fighters[0]
	var out: Watch = Watch.new()
	v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
	var shuffle: GuardShuffle = v.locomotion.shuffle
	for input: RawInput in inputs:
		var was_pos: Vector3 = _pos(f)
		var was_yaw: float = f.yaw
		for side: String in SIDES:
			out._was[side] = not shuffle.feet[side].swinging and not shuffle.riding
		W.step([input, SimHelpers.idle()])
		if lifts != null:
			lifts.see(shuffle)
		for alpha: float in [0.5, 1.0]:
			v.update_from(f, was_pos.lerp(_pos(f), alpha), lerp_angle(was_yaw, f.yaw, alpha), alpha, 1.0 / 60.0, 0.0)
			var feet: Feet = await _feet(v)
			out.leaned = maxf(out.leaned, v.locomotion.lean.shown_tilt.length())
			for side: String in SIDES:
				var foot: GuardShuffle.Foot = shuffle.feet[side]
				if out._last.has(side):
					out.jump = maxf(out.jump, feet.world[side].distance_to(out._last[side]))
				out._last[side] = feet.world[side]
				var sign: float = -1.0 if side == "Right" else 1.0
				if v.stance >= 1.0:
					out.clear = minf(out.clear, minf(feet.frame[side].x * sign, feet.toes[side].x * sign))
				# a foot that lands on this frame is still coming down between
				# the frames
				if foot.swinging or shuffle.riding or v.stance < 1.0 or not out._was[side]:
					out._stood.erase(side)
					continue
				if not out._stood.has(side):
					out._stood[side] = feet.world[side]
					out.steps += 1
					continue
				out.planted += 1
				var moved: Vector3 = feet.world[side] - out._stood[side]
				out.slide = maxf(out.slide, Vector2(moved.x, moved.z).length())
		out.turned = maxf(out.turned, absf(v.locomotion.leg_yaw))
		out.least_guard = minf(out.least_guard, v.locomotion.guard)
	return out


static func _inputs(segments: Array) -> Array[RawInput]:
	var out: Array[RawInput] = []
	for s: Array in segments:
		for i: int in int(s[0]):
			out.append(RawInput.make(s[1], s[2], s[3]))
	return out


## Guarding (blocking), the Katana fighter shuffles every way it walks, and
## circles the opponent: the planted feet move under 1 cm over the ground on
## the posed skeleton, between the rules frames too, the feet stay on their
## own sides of the mid-line, and the legs never take the walking clips.
func test_the_guard_walk_shuffles_with_the_planted_feet_under_a_centimetre() -> void:
	var block: int = 1 << Btn.BLOCK
	for id: StringName in FighterLook.IDS:
		for walk: Array in [["forward", 0.0, 1.0, 8.0], ["back", 0.0, -1.0, 8.0], ["left round", -1.0, 0.0, 3.0],
				["right round", 1.0, 0.0, 3.0], ["back-left", -0.7071, -0.7071, 8.0], ["forward-right", 0.7071, 0.7071, 8.0]]:
			var W: World = _world(walk[3])
			var v: FighterView = _view(id)
			var watched: Watch = await _watch(W, v, _inputs([[6, 0.0, 0.0, block], [50, walk[1], walk[2], block], [24, 0.0, 0.0, block]]))
			gut.p("%s guarding %s: %d steps, planted %d frames, slid %.2f cm, %.1f cm clear of the mid-line" % [
				id, walk[0], watched.steps, watched.planted, watched.slide * 100.0, watched.clear * 100.0])
			assert_gt(watched.steps, 6, "%s %s: the feet step" % [id, walk[0]])
			assert_gt(watched.planted, 60, "%s %s: and stand" % [id, walk[0]])
			assert_lt(watched.slide, 0.01, "%s %s: the planted feet slide under 1 cm" % [id, walk[0]])
			assert_gt(watched.clear, MID_LINE_CLEAR, "%s %s: each foot on its own side of the mid-line" % [id, walk[0]])
			assert_eq(v.locomotion.guard, 1.0, "%s %s: the guard's legs" % [id, walk[0]])
			assert_almost_eq(v.model.rig.clip_feet, 0.0, 1e-6, "%s %s: the shuffle's feet, not the clips'" % [id, walk[0]])
			assert_eq(watched.turned, 0.0, "%s %s: the legs never turn toward travel" % [id, walk[0]])


## A tap step from the guard is a shuffle step: the lead foot out, the
## trailing foot after it, the planted feet still and nothing popping (a
## pop into a stride moved the feet half a metre in a frame, a quarter of it
## in half a frame; a 0.55 m tap step swings a foot about 10 cm in half a
## frame at most), and back in the stance.
func test_a_tap_step_is_a_shuffle_step() -> void:
	for tap: Array in [["forward", 0.0, 1.0, "Right"], ["back", 0.0, -1.0, "Left"], ["left", -1.0, 0.0, "Left"], ["right", 1.0, 0.0, "Right"]]:
		var W: World = _world(8.0)
		var v: FighterView = _view(&"rogue")
		var f: Fighter = W.fighters[0]
		var start: Vector3 = _pos(f)
		var lifts: Lifts = Lifts.new()
		# held for the step's 8 frames: let go sooner, the rules keep the
		# distance to the opponent and a step toward or away from it stops
		var watched: Watch = await _watch(W, v, _inputs([[SimConst.MOVE_STEP_FRAMES, tap[1], tap[2], 0], [40, 0.0, 0.0, 0]]), lifts)
		gut.p("tap %s: %s, slid %.2f cm, a foot moves %.1f cm in half a frame at most" % [tap[0], " ".join(lifts.order), watched.slide * 100.0, watched.jump * 100.0])
		assert_gt(_pos(f).distance_to(start), SimConst.MOVE_STEP_DIST, "%s: the rules tap-stepped" % tap[0])
		assert_eq(watched.least_guard, 1.0, "%s: the guard's legs throughout, the stick held to the step's end" % tap[0])
		assert_eq(watched.turned, 0.0, "%s: the legs never turn toward travel" % tap[0])
		assert_gt(lifts.order.size(), 1, "%s: both feet step" % tap[0])
		assert_eq(lifts.order[0], tap[3], "%s: the %s foot first" % [tap[0], tap[3].to_lower()])
		assert_ne(lifts.order[1], tap[3], "%s: then the other closes" % tap[0])
		assert_lt(watched.slide, 0.01, "%s: the planted feet slide under 1 cm" % tap[0])
		assert_lt(watched.jump, 0.15, "%s: nothing pops" % tap[0])
		for side: String in SIDES:
			assert_lt(v.locomotion.shuffle.feet[side].offset.length(), 0.02, "%s: the %s foot back in the stance" % [tap[0], side])


## Running with the guard down hands the legs to the clips, and stopping
## hands them back, each over GUARD_RAMP_FRAMES with no foot jumping.
func test_running_unguarded_hands_over_to_the_clips_and_back() -> void:
	var W: World = _world(26.0)
	var v: FighterView = _view(&"rogue")
	var f: Fighter = W.fighters[0]
	var loco: Locomotion = v.locomotion
	var watched: Watch = await _watch(W, v, _inputs([[40, 0.0, 1.0, 0]]))
	assert_eq(loco.guard, 0.0, "running: the clips' legs")
	assert_almost_eq(v.model.rig.clip_feet, 1.0, 1e-6, "the clips' feet")
	assert_gt(loco.shown[Locomotion.NODES.find(&"jog")], 0.9, "jogging")
	assert_true(loco.shuffle.riding, "the guard's feet ride with the fighter, to stand from its spots")
	for side: String in SIDES:
		assert_lt(loco.shuffle.feet[side].offset.length(), 0.02, "the %s on its spot" % side)
	var jump: float = watched.jump
	watched = await _watch(W, v, _inputs([[40, 0.0, 0.0, 0]]))
	jump = maxf(jump, watched.jump)
	assert_eq(loco.guard, 1.0, "stopped: the guard's legs")
	assert_almost_eq(v.model.rig.clip_feet, 0.0, 1e-6, "on the stance")
	gut.p("a foot moves %.1f cm in half a frame at most" % [jump * 100.0])
	assert_lt(jump, 0.15, "no foot jumps at the hand-overs")
	# blocking at a run takes the guard back too
	await _watch(W, v, _inputs([[30, 0.0, 1.0, 0]]))
	assert_eq(loco.guard, 0.0)
	for i: int in Locomotion.GUARD_RAMP_FRAMES:
		W.step([SimHelpers.move(0.0, 1.0, Btn.BLOCK), SimHelpers.idle()])
		v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		assert_almost_eq(loco.guard, float(i + 1) / float(Locomotion.GUARD_RAMP_FRAMES), 1e-6, "ramping over the guard's frames")


## The Iai stance walks on the shuffle: sheathed, walking and strafing at the
## blocking walk's speed, the feet step and stand, the planted ones under
## 1 cm over the ground, and the body leans into the walk's start.
func test_the_iai_stance_walks_on_the_shuffle() -> void:
	var heavy: int = 1 << Btn.HEAVY
	for walk: Array in [["forward", 0.0, 1.0, 8.0], ["left round", -1.0, 0.0, 3.0]]:
		var W: World = _world(walk[3])
		var v: FighterView = _view(&"rogue")
		var f: Fighter = W.fighters[0]
		var watched: Watch = await _watch(W, v, _inputs([[12, 0.0, 0.0, heavy], [60, walk[1], walk[2], heavy]]))
		assert_true(f.in_stance(), "%s: in the Iai stance" % walk[0])
		assert_gt(Locomotion.ground_speed(f), 1.0, "%s: walking" % walk[0])
		gut.p("Iai stance %s: %d steps, slid %.2f cm" % [walk[0], watched.steps, watched.slide * 100.0])
		assert_eq(v.locomotion.guard, 1.0, "%s: the guard's legs" % walk[0])
		assert_gt(watched.steps, 6, "%s: the feet step" % walk[0])
		assert_lt(watched.slide, 0.01, "%s: the planted feet slide under 1 cm" % walk[0])
		assert_gt(rad_to_deg(watched.leaned), 3.0, "%s: leaning into the walk" % walk[0])


## The shuffle steps on the rules' frames: shown every other frame, as at
## 30 fps, the feet are where they are shown every frame.
func test_the_shuffle_is_the_same_shown_every_other_frame() -> void:
	var views: Array[FighterView] = []
	var worlds: Array[World] = []
	for i: int in 2:
		worlds.append(_world(3.0))
		views.append(_view(&"rogue"))
		var f: Fighter = worlds[i].fighters[0]
		views[i].update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
	for frame: int in 60:
		var input: RawInput = RawInput.make(-1.0 if frame >= 6 else 0.0, 0.0, 1 << Btn.BLOCK)
		for i: int in 2:
			worlds[i].step([input, SimHelpers.idle()])
			var f: Fighter = worlds[i].fighters[0]
			if i == 0 or frame % 2 == 1:
				views[i].update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
	for side: String in SIDES:
		var every: GuardShuffle.Foot = views[0].locomotion.shuffle.feet[side]
		var other: GuardShuffle.Foot = views[1].locomotion.shuffle.feet[side]
		assert_gt(every.steps, 3, "%s foot stepped" % side)
		assert_almost_eq(other.at, every.at, Vector3.ONE * 0.002, "the %s foot in the same place" % side)
		assert_eq(other.swinging, every.swinging, "the %s foot as far through its step" % side)


## When a leg can't reach its planted foot within 97% of its length (the
## rear foot waiting as the shuffle sets off), the pelvis sinks until it can,
## and the weapon goes down with it.
func test_the_pelvis_sinks_to_reach_a_far_foot_and_the_weapon_with_it() -> void:
	for id: StringName in FighterLook.IDS:
		var W: World = _world(8.0)
		var v: FighterView = _view(id)
		var f: Fighter = W.fighters[0]
		var rig: FighterRig = v.model.rig
		var sk: Skeleton3D = v.model.skeleton
		v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		await _feet(v)
		assert_eq(v.sink, 0.0, "%s standing: no sink" % id)
		var hips: float = rig.body.hips_offset.y
		var grip: float = rig.grip_point("Right").y
		# the rear foot left 30 cm further back, shown on the same rules frame
		var foot: GuardShuffle.Foot = v.locomotion.shuffle.feet["Left"]
		var back: Vector3 = GuardShuffle.facing(f.yaw) * Vector3(0.0, 0.0, -0.3)
		foot.at += back
		foot.prev_at += back
		v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		var posed: PoseCheck.Frame = await PoseCheck.frame_of(v.model)
		gut.p("%s: the pelvis sinks %.1f cm" % [id, v.sink * 100.0])
		assert_gt(v.sink, 0.01, "%s: the pelvis sinks" % id)
		assert_almost_eq(rig.body.hips_offset.y, hips - v.sink, 1e-5, "%s: the hips by the sink" % id)
		assert_almost_eq(rig.grip_point("Right").y, grip - v.sink, 0.004, "%s: the weapon with them" % id)
		var hip: Vector3 = posed.bones[sk.find_bone("LeftUpperLeg")].origin
		var ankle: Vector3 = posed.bones[sk.find_bone("LeftFoot")].origin
		assert_almost_eq(ankle, rig.foot_position["Left"], Vector3.ONE * 0.003, "%s: the foot reached" % id)
		assert_almost_eq(hip.distance_to(ankle) / rig.leg_length("Left"), GuardStance.REACH_MOST, 0.01, "%s: at 97%% of the leg" % id)


## The guard's feet are its footsteps: each landing while the guard's legs
## show is a footfall where the foot came down. A tap step's own landing
## makes none (the step has its own scuff), nor does a foot settling while
## the feet ride with the fighter (a dodge), and on the clips' legs, running
## with the guard down, the footsteps come from the stride count instead.
func test_the_shuffle_s_landings_are_its_footfalls() -> void:
	var block: int = 1 << Btn.BLOCK
	for walk: Array in [["a guard walk", [[6, 0.0, 0.0, block], [50, -1.0, 0.0, block], [24, 0.0, 0.0, block]]],
			["a tap step", [[SimConst.MOVE_STEP_FRAMES, 1.0, 0.0, 0], [30, 0.0, 0.0, 0]]],
			["a dodge out of a guard walk", [[6, 0.0, 0.0, block], [20, -1.0, 0.0, block], [1, -1.0, 0.0, 1 << Btn.DODGE], [40, 0.0, 0.0, 0]]]]:
		var W: World = _world(3.0)
		var v: FighterView = _view(&"rogue")
		var f: Fighter = W.fighters[0]
		var shuffle: GuardShuffle = v.locomotion.shuffle
		v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		var landings: Array[Vector3] = []
		var stepping: int = 0
		var riding: int = 0
		var footfalls: Array[Vector3] = []
		var was: Dictionary[String, bool] = {"Right": false, "Left": false}
		for input: RawInput in _inputs(walk[1]):
			W.step([input, SimHelpers.idle()])
			v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
			assert_true(v.locomotion.shuffles(), "%s: the shuffle's landings are the footsteps" % walk[0])
			for side: String in SIDES:
				var foot: GuardShuffle.Foot = shuffle.feet[side]
				if was[side] and not foot.swinging:
					if f.state == &"step":
						stepping += 1
					elif shuffle.riding:
						riding += 1
					else:
						landings.append(foot.at)
				was[side] = foot.swinging
			footfalls.append_array(v.locomotion.footfalls)
		gut.p("%s: %d landings, %d on the tap step itself, %d riding, %d footfalls" % [walk[0], landings.size() + stepping + riding, stepping, riding, footfalls.size()])
		assert_gt(landings.size(), 0, "%s: the feet land" % walk[0])
		assert_eq(footfalls.size(), landings.size(), "%s: a footfall for each landing but the tap step's own" % walk[0])
		for k: int in mini(footfalls.size(), landings.size()):
			assert_almost_eq(footfalls[k], landings[k], Vector3.ONE * 1e-6, "%s: footfall %d where the foot came down" % [walk[0], k])
		if walk[0] == "a tap step":
			assert_gt(stepping, 0, "the lead foot lands while the rules still step")
		if walk[0] == "a dodge out of a guard walk":
			assert_gt(riding, 0, "a foot settles while the feet ride")
	# breaking into a run with the guard down and stopping again: footfalls
	# only while the landings are the footsteps, through both hand-overs
	var W2: World = _world(26.0)
	var v2: FighterView = _view(&"rogue")
	var f2: Fighter = W2.fighters[0]
	v2.update_from(f2, _pos(f2), f2.yaw, 1.0, 1.0 / 60.0, 0.0)
	var counted: Array[int] = [0, 0]
	for input: RawInput in _inputs([[40, 0.0, 1.0, 0], [40, 0.0, 0.0, 0]]):
		W2.step([input, SimHelpers.idle()])
		v2.update_from(f2, _pos(f2), f2.yaw, 1.0, 1.0 / 60.0, 0.0)
		var shuffles: bool = v2.locomotion.shuffles()
		counted[0 if shuffles else 1] += 1
		if not shuffles:
			assert_eq(v2.locomotion.footfalls, [] as Array[Vector3], "frame %d: no footfalls while the stride count steps" % W2.frame)
	assert_gt(counted[1], 20, "running: the stride count's footsteps")
	assert_true(v2.locomotion.shuffles(), "stopped: the shuffle's again")


## A fighter knocked out just after a foot came down doesn't report that
## footfall again as it falls: the fall moves no feet.
func test_a_knocked_out_fighter_reports_no_footfalls() -> void:
	var W: World = _world(3.0)
	var v: FighterView = _view(&"rogue")
	var f: Fighter = W.fighters[0]
	v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
	for i: int in 60:
		W.step([RawInput.make(-1.0, 0.0, 1 << Btn.BLOCK), SimHelpers.idle()])
		v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		if not v.locomotion.footfalls.is_empty():
			break
	assert_false(v.locomotion.footfalls.is_empty(), "a foot came down")
	f.set_state(&"ko")
	for i: int in 3:
		W.step([SimHelpers.idle(), SimHelpers.idle()])
		v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		assert_eq(v.locomotion.footfalls, [] as Array[Vector3], "falling, frame %d: no footfalls" % i)


## In hit-stop and while paused the shuffle holds still.
func test_the_shuffle_holds_in_hit_stop() -> void:
	var W: World = _world(8.0)
	var v: FighterView = _view(&"rogue")
	var f: Fighter = W.fighters[0]
	await _watch(W, v, _inputs([[9, 0.0, 1.0, 1 << Btn.BLOCK]]))
	var shuffle: GuardShuffle = v.locomotion.shuffle
	var before: Feet = await _feet(v)
	W.hitstop = 8
	for i: int in 8:
		W.step([SimHelpers.move(0.0, 1.0, Btn.BLOCK), SimHelpers.idle()])
		v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		var now: Feet = await _feet(v)
		for side: String in SIDES:
			assert_almost_eq(now.world[side], before.world[side], Vector3.ONE * 1e-4, "hit-stop step %d: the %s foot holds" % [i, side])


## The other weapons have no guard stance: their legs keep the clips,
## blocking or not.
func test_the_other_weapons_walk_on_the_clips() -> void:
	for weapon: WeaponDef in [Moves.GREATSWORD, Moves.DAGGERS]:
		var W: World = _world(8.0, weapon)
		var v: FighterView = _view(&"rogue", weapon)
		await _watch(W, v, _inputs([[40, 0.0, 1.0, 1 << Btn.BLOCK]]))
		assert_eq(v.locomotion.guard, 0.0, "%s: the clips' legs" % weapon.id)
		assert_lt(v.locomotion.shown[0], 0.5, "%s: walking on the clips" % weapon.id)


## While the fighter shuffles, its hips bob with the shuffle and the weapon
## rides the bob on its spring.
func test_the_hips_bob_and_the_weapon_rides_it() -> void:
	var W: World = _world(8.0)
	var v: FighterView = _view(&"rogue")
	var f: Fighter = W.fighters[0]
	var shuffle: GuardShuffle = v.locomotion.shuffle
	var rig: FighterRig = v.model.rig
	var walk: RawInput = SimHelpers.move(0.0, -1.0, Btn.BLOCK)
	# at the walk's speed, so the lean has settled
	await _watch(W, v, _inputs([[40, 0.0, -1.0, 1 << Btn.BLOCK]]))
	var grip: float = rig.grip_point("Right").y
	var bob: float = shuffle.shown_weapon_bob
	var bobs: Array[float] = []
	for i: int in 24:
		W.step([walk, SimHelpers.idle()])
		v.update_from(f, _pos(f), f.yaw, 1.0, 1.0 / 60.0, 0.0)
		# the view's clock: the frame shown at alpha 1
		var seconds: float = float(W.frame + 1) / 60.0
		var hips: Vector3 = GuardStance.offset(seconds) + Vector3(0.0, shuffle.shown_bob - v.sink - v.last_pose.crouch - v.locomotion.lean.shown_drop, 0.0)
		assert_almost_eq(rig.body.hips_offset, hips, Vector3.ONE * 1e-5, "frame %d: the hips are the stance's, bobbing, sunk, braced" % i)
		var now: float = rig.grip_point("Right").y
		var sway: float = GuardStance.offset(seconds).y - GuardStance.offset(seconds - 1.0 / 60.0).y
		assert_almost_eq(now - grip, shuffle.shown_weapon_bob - v.sink - bob + sway, 0.003, "frame %d: the grip rides the weapon's bob" % i)
		grip = now
		bob = shuffle.shown_weapon_bob - v.sink
		bobs.append(bob)
	assert_gt(bobs.max() - bobs.min(), 0.005, "and it bobs")


# ------------------------------------------------------------ footwork (14.13)

## A light whose lunge eases over `ls` to `le` (UNSET: to the end of the
## active frames), with startup 11 and 3 active frames.
static func _lunging(ls: int = 0, le: int = 12) -> AttackDef:
	var d: AttackDef = AttackDef.new()
	d.startup = 11
	d.active = 3
	d.recovery = 16
	d.lunge = 0.35
	d.lunge_start = ls
	d.lunge_end = le
	return d


## Straight ahead the front (right) foot lifts so that it lands on the first
## active frame, as far ahead as the lunge has left, and the rear foot lands
## REAR_FRAMES after; it lifts no earlier than the lunge starts, and swings
## STRIKE_SWING_LEAST frames at least.
func test_a_strike_lands_the_front_foot_on_the_first_active_frame() -> void:
	var plan: GuardShuffle.Strike = GuardShuffle.strike_for(_lunging(), 0.35, Vector3.BACK, 1)
	assert_eq(plan.lands["Right"], 12, "the front foot lands on the first active frame")
	assert_eq(plan.lifts["Right"], 12 - GuardShuffle.STRIKE_SWING_MOST, "after a whole swing")
	assert_eq(plan.lifts["Left"], 12, "the rear foot lifts as it lands")
	assert_eq(plan.lands["Left"], 12 + GuardShuffle.REAR_FRAMES)
	assert_almost_eq(plan.ahead["Right"], Vector3.ZERO, Vector3.ONE * 1e-9, "the lunge is over by then: on its spot")
	var late: GuardShuffle.Strike = GuardShuffle.strike_for(_lunging(8, 20), 0.35, Vector3.BACK, 1)
	assert_eq(late.lifts["Right"], 8, "not before the lunge starts")
	assert_gt(late.ahead["Right"].z, 0.1, "ahead by what is left of the lunge")
	assert_almost_eq(late.ahead["Right"].z, minf(0.35 * (1.0 - SimMath.ease_in_out(4.0 / 12.0)), GuardShuffle.STRIKE_AHEAD_MOST), 1e-6,
			"ahead by the lunge left, within STRIKE_AHEAD_MOST")
	var later: GuardShuffle.Strike = GuardShuffle.strike_for(_lunging(10, 20), 0.2, Vector3.BACK, 1)
	assert_almost_eq(later.ahead["Right"].z, 0.2 * (1.0 - SimMath.ease_in_out(2.0 / 10.0)), 1e-6, "eased as the rules ease it")
	assert_lte(late.ahead["Left"].z, GuardShuffle.STRIKE_AHEAD_MOST, "within reach")
	var short: GuardShuffle.Strike = GuardShuffle.strike_for(_lunging(10, 14), 0.35, Vector3.BACK, 1)
	assert_eq(short.lands["Right"] - short.lifts["Right"], GuardShuffle.STRIKE_SWING_LEAST, "a short swing at least")
	assert_true(GuardShuffle.strike_for(_lunging(), 0.0, Vector3.BACK, 1).lifts.is_empty(), "no lunge, no steps")


## A lunge along a dodge to the left leads with the left foot.
func test_a_strike_leads_with_the_foot_on_the_lunges_side() -> void:
	var plan: GuardShuffle.Strike = GuardShuffle.strike_for(_lunging(), 1.2, Vector3.RIGHT, 1)
	assert_eq(plan.lands["Left"], 12, "the left foot (+X) leads a lunge to the left")
	assert_eq(plan.lands["Right"], 12 + GuardShuffle.REAR_FRAMES)


## In a strike the planted feet stand still on the ground while the fighter
## lunges over them, and no step is taken but the strike's.
func test_a_strike_steps_only_its_own_steps() -> void:
	var g: GuardShuffle = GuardShuffle.new()
	g.reset(Vector3.ZERO, 0.0)
	var def: AttackDef = _lunging()
	var lifted: Dictionary[String, int] = {}
	var landed: Dictionary[String, int] = {}
	var was: Dictionary[String, Vector3] = {}
	for frame: int in range(1, 31):
		# the lunge's own ease, 0.35 m by frame 12
		var z: float = 0.35 * SimMath.ease_in_out(clampf(float(frame) / 12.0, 0.0, 1.0))
		for side: String in SIDES:
			was[side] = g.feet[side].at
		g.step(Vector3(0.0, 0.0, z), 0.0, true, GuardShuffle.strike_for(def, 0.35, Vector3.BACK, frame))
		for side: String in SIDES:
			var foot: GuardShuffle.Foot = g.feet[side]
			if foot.swinging and not lifted.has(side):
				lifted[side] = frame
			if g.landed.has(side):
				landed[side] = frame
			if not foot.swinging and not g.landed.has(side):
				assert_lt(foot.at.distance_to(was[side]), 1e-9, "frame %d: the %s foot stands planted" % [frame, side])
	assert_eq(landed, {"Right": 12, "Left": 12 + GuardShuffle.REAR_FRAMES} as Dictionary[String, int], "each lands when planned")
	assert_eq(lifted["Right"], 2, "the front foot lifts on frame 2, swinging the 10 frames to 12")
	assert_almost_eq(g.feet["Right"].at, Vector3(GuardStance.FEET["Right"].x, 0.0, 0.35 + GuardStance.FEET["Right"].z), Vector3.ONE * 1e-6,
			"the front foot on its spot where the lunge ends")
	assert_almost_eq(g.feet["Left"].at, Vector3(GuardStance.FEET["Left"].x, 0.0, 0.35 + GuardStance.FEET["Left"].z), Vector3.ONE * 1e-6,
			"and the rear one")
