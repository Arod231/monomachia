class_name FootPhase
extends RefCounted
## Measures a looping locomotion clip's gait on a fighter's skeleton: the
## ground speed it shows, how far the body travels in one cycle (the
## stride), and where in the cycle each foot is at mid-stance, passing under
## the body. Locomotion plays every clip from one shared step phase with
## these numbers, so the feet stay in step and planted whatever the blend.
##
## The clips are in place, so the travel is read off the feet: a planted foot
## slides back under the body at the ground speed. It is read at mid-stance,
## where the foot sweeps back through the middle of its range, because the
## ankle lifts early in a running stride (the toes stay down), so a foot's
## height says little about when it is planted; and the mid-stances line the
## clips up, since the moment a foot is furthest ahead comes mid-air in a run
## but at heel strike in a walk.
##
## Run tools/foot_phase.gd to print them for every fighter.

## How many poses a cycle is sampled at.
const SAMPLES: int = 240


## One clip's gait on one skeleton.
class Gait:
	var clip: StringName = &""
	## The clip's length (s).
	var length: float = 0.0
	## The ground speed it shows (m/s): the feet's speed at mid-stance.
	var speed: float = 0.0
	## How far the body travels in one cycle (m).
	var stride: float = 0.0
	## Where in the cycle (0..1) the left foot, then the right, is at
	## mid-stance.
	var left_stance: float = 0.0
	var right_stance: float = 0.0

	func _to_string() -> String:
		return "%-8s %.3f s  %.2f m/s  stride %.2f m  mid-stance: left %.3f, right %.3f" % [
			clip, length, speed, stride, left_stance, right_stance]


## Measures clip `clip` of the shared library on `model`'s skeleton, posed
## by the clip alone (the rig's modifiers don't count). The model's player is
## left on the clip it was playing.
static func measure(model: FighterModel, clip: StringName) -> Gait:
	var ap: AnimationPlayer = model.animation_player
	var sk: Skeleton3D = model.skeleton
	var anim_name: String = String(FighterModel.LIBRARY) + "/" + String(clip)
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
	var z: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	ap.play(anim_name, 0.0)
	for i: int in SAMPLES:
		ap.seek(anim.length * i / SAMPLES, true)
		for side: int in 2:
			z[side].append(sk.get_bone_global_pose(bones[side]).origin.z)
	if was != "":
		ap.play(was, 0.0)
		ap.seek(was_at, true)
	var dt: float = anim.length / SAMPLES
	var left: Vector2 = mid_stance(z[0], dt)
	var right: Vector2 = mid_stance(z[1], dt)
	gait.left_stance = left.x
	gait.right_stance = right.x
	gait.speed = (left.y + right.y) / 2.0
	gait.stride = gait.speed * anim.length
	return gait


## Where a foot, sampled `dt` apart round its cycle at forward positions
## `z`, sweeps back through the middle of its range, and how fast:
## (phase 0..1, speed in m/s). Of several sweeps back, the fastest.
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
