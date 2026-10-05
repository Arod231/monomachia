class_name FootPhase
extends RefCounted
## Measures a looping locomotion clip's gait on a fighter's skeleton: the way
## and the ground speed it travels, how far the body travels in one cycle
## (the stride), where in the cycle each foot is at mid-stance, passing under
## the body, and where each foot comes down. Locomotion plays every clip from
## one shared step phase with these numbers, so the feet stay in step and
## planted whatever the blend, and the footsteps fall as the feet land.
##
## The clips are in place, so the travel is read off the feet: a planted foot
## slides back under the body, against the way the body travels, at the
## ground speed. The way is the planted feet's slide, reversed (authored-
## animation task 29: the packs' clips run forwards, backwards, sideways and
## on the diagonals). The speed is read at mid-stance, where the foot sweeps
## back through the middle of its range along that way, because the ankle
## lifts early in a running stride (the toes stay down), so a foot's height
## says little about when it is planted; and the mid-stances line the clips
## up, since the moment a foot is furthest ahead comes mid-air in a run but at
## heel strike in a walk.
##
## Run tools/foot_phase.gd to print them for every fighter.

## How many poses a cycle is sampled at.
const SAMPLES: int = 240
## How far (m) above its lowest an ankle counts as down.
const DOWN_HEIGHT: float = 0.03


## One clip's gait on one skeleton.
class Gait:
	## The clip, as named in the model's player ("HumanM/Run01_Forward", or a
	## bare name for the CC0 library's).
	var clip: StringName = &""
	## The clip's length (s).
	var length: float = 0.0
	## The way it travels in the fighter's frame (unit, x to its left, y
	## ahead), and the ground speed (m/s): the feet's speed at mid-stance.
	var way: Vector2 = Vector2(0.0, 1.0)
	var speed: float = 0.0
	## How far the body travels in one cycle (m).
	var stride: float = 0.0
	## Where in the cycle (0..1) the left foot, then the right, is at
	## mid-stance.
	var left_stance: float = 0.0
	var right_stance: float = 0.0
	## Where each foot comes down, in the shared step phase (0..1 from the left
	## foot's mid-stance), left then right.
	var left_contact: float = 0.0
	var right_contact: float = 0.5

	func _to_string() -> String:
		return "%-26s %.3f s  %.2f m/s at %+4.0f°  stride %.2f m  mid-stance: left %.3f, right %.3f  down: left %.2f, right %.2f" % [
			clip, length, speed, rad_to_deg(atan2(way.x, way.y)), stride, left_stance, right_stance, left_contact, right_contact]


## Measures clip `clip` of the model's player on `model`'s skeleton, posed by
## the clip alone (the rig's modifiers don't count): a name with its library
## ("HumanM/Walk01_Forward"), or a bare name for the shared CC0 library's.
## The model's player is left on the clip it was playing.
static func measure(model: FighterModel, clip: StringName) -> Gait:
	var ap: AnimationPlayer = model.animation_player
	var sk: Skeleton3D = model.skeleton
	var anim_name: String = String(clip) if String(clip).contains("/") else String(FighterModel.LIBRARY) + "/" + String(clip)
	var gait: Gait = Gait.new()
	gait.clip = clip
	if not ap.has_animation(anim_name):
		push_error("FootPhase.measure: no clip %s" % clip)
		return gait
	if not model.is_inside_tree():
		push_error("FootPhase.measure: the model must be in the tree for its clips to play")
		return gait
	var anim: Animation = ap.get_animation(anim_name)
	gait.length = anim.length
	var was: String = ap.current_animation
	var was_at: float = ap.current_animation_position if was != "" else 0.0
	var bones: Array[int] = [sk.find_bone("LeftFoot"), sk.find_bone("RightFoot")]
	var feet: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	ap.play(anim_name, 0.0)
	for i: int in SAMPLES:
		ap.seek(anim.length * i / SAMPLES, true)
		for side: int in 2:
			feet[side].append(sk.get_bone_global_pose(bones[side]).origin)
	if was != "":
		ap.play(was, 0.0)
		ap.seek(was_at, true)
	var dt: float = anim.length / SAMPLES
	gait.way = travel_way(feet, dt)
	var along: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	for side: int in 2:
		for p: Vector3 in feet[side]:
			along[side].append(p.x * gait.way.x + p.z * gait.way.y)
	var left: Vector2 = mid_stance(along[0], dt)
	var right: Vector2 = mid_stance(along[1], dt)
	gait.left_stance = left.x
	gait.right_stance = right.x
	gait.speed = (left.y + right.y) / 2.0
	gait.stride = gait.speed * anim.length
	gait.left_contact = fposmod(contact(feet[0]) - gait.left_stance, 1.0)
	gait.right_contact = fposmod(contact(feet[1]) - gait.left_stance, 1.0)
	return gait


## The way a clip travels (unit, x to the fighter's left, y ahead) from both
## feet's positions sampled `dt` apart round its cycle: against the way its
## planted feet slide. Straight ahead when they don't.
static func travel_way(feet: Array[PackedVector3Array], dt: float) -> Vector2:
	var slide: Vector2 = Vector2.ZERO
	for side: int in feet.size():
		var ps: PackedVector3Array = feet[side]
		var n: int = ps.size()
		var lo: float = INF
		for p: Vector3 in ps:
			lo = minf(lo, p.y)
		for i: int in n:
			var a: Vector3 = ps[i]
			var b: Vector3 = ps[(i + 1) % n]
			if a.y < lo + DOWN_HEIGHT and b.y < lo + DOWN_HEIGHT:
				slide += Vector2(b.x - a.x, b.z - a.z) / dt
	if slide.length() < 1e-4:
		return Vector2(0.0, 1.0)
	return -slide.normalized()


## Where in its cycle (0..1) a foot, sampled evenly round it at `ps`, comes
## down: the first sample within DOWN_HEIGHT of its lowest after one above.
static func contact(ps: PackedVector3Array) -> float:
	var n: int = ps.size()
	var lo: float = INF
	for p: Vector3 in ps:
		lo = minf(lo, p.y)
	for i: int in n:
		if ps[i].y < lo + DOWN_HEIGHT and ps[(i - 1 + n) % n].y >= lo + DOWN_HEIGHT:
			return float(i) / n
	return 0.0


## Where a foot, sampled `dt` apart round its cycle at positions `z` along
## the way of travel, sweeps back through the middle of its range, and how
## fast: (phase 0..1, speed in m/s). Of several sweeps back, the fastest.
static func mid_stance(z: PackedFloat32Array, dt: float) -> Vector2:
	var n: int = z.size()
	var lo: float = INF
	var hi: float = -INF
	for v: float in z:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var mid: float = (lo + hi) / 2.0
	var best: Vector2 = Vector2(0.0, -INF)
	for i: int in n:
		var a: float = z[i]
		var b: float = z[(i + 1) % n]
		if a >= mid and b < mid:
			# over the three intervals round the crossing
			var speed: float = (z[(i - 1 + n) % n] - z[(i + 2) % n]) / (3.0 * dt)
			if speed > best.y:
				best = Vector2(fposmod((i + (a - mid) / (a - b)) / n, 1.0), speed)
	return best if best.y > -INF else Vector2.ZERO
