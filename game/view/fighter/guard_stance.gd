class_name GuardStance
extends RefCounted
## The grounded guard stance a fighter stands in when its weapon's hold has
## one (WeaponHold.guard: the Katana's), in place of the hold's idle clip:
## the animation spike critique's fix 8 (docs/research/animation-spike). Over
## the relaxed idle clip (CLIP) it puts:
## - the legs on IK, the right foot in front pointing at the opponent and
##   the left behind, turned out (FEET, FOOT_YAW), a stance's width apart so
##   the feet never cross. GuardShuffle plants them there and steps them as
##   the fighter walks; FighterRig bends each knee over its toes;
## - the pelvis lowered (CROUCH) and set over the middle of the stance
##   (FORWARD), its weight shifting slowly between the feet (shift()), on the
##   rules' clock so it holds still in hit-stop and pause, and bobbing with
##   the shuffle;
## - the hips turned toward the rear foot's side, the spine turned back so
##   the chest faces the opponent and bent a little forward over the hips,
##   and the head raised to watch the opponent.
## The weapon's guard (its swings' guard, or StickPose's for a weapon without
## swings: SwingPlayer) rides the pelvis's drop and sway (offset()) and the
## shuffle's bob on its spring. While a swing plays, its body keys take over
## the hips' and the spine's turns, the lean and the lowered pelvis from the
## stance (pose()'s `share`), and the feet stay planted.
##
## The stance shows as far as the legs are the guard's (Locomotion's idle
## weight, which its guard weight holds at 1 unless the fighter runs with its
## guard down): running, the feet are the clips'. Skeleton space is the
## fighter's own frame: +Z forward, +X to the fighter's left, +Y up.

## The clip the stance stands over: the relaxed idle, shoulders square.
const CLIP: StringName = &"Idle"
## Where each ankle stands (m, across and along; its height stays the rest
## pose's), and which way its toes point (degrees from straight ahead,
## positive to the fighter's left): the right foot in front, a little out,
## the left behind, turned out.
const FEET: Dictionary[String, Vector3] = {
	"Right": Vector3(-0.14, 0.0, 0.24),
	"Left": Vector3(0.15, 0.0, -0.25),
}
const FOOT_YAW: Dictionary[String, float] = {"Right": -6.0, "Left": 32.0}
## How far the pelvis is lowered (m), and moved forward over the middle of
## the stance.
const CROUCH: float = 0.09
const FORWARD: float = 0.03
## The weight shift: how far the pelvis sways either way along the line
## between the feet (m), and how long a sway there and back takes (s).
const SHIFT: float = 0.035
const SHIFT_PERIOD: float = 5.0
## The hips turned toward the rear foot's side, the spine turned back and
## bent forward, and the head nodded (degrees; turns are positive to the
## fighter's left, bends forward or down). The relaxed idle looks 14 degrees
## down at the floor, and the spine's bend tips the head 6 more: raised, it
## watches the opponent.
const PELVIS_YAW: float = 15.0
const SPINE_YAW: float = -15.0
const SPINE_PITCH: float = 6.0
const HEAD_PITCH: float = -14.0
## The most of its length a leg stretches to its planted foot: past it the
## pelvis sinks (sink()), as when the shuffle sets off and the rear foot
## waits for the front one to land.
const REACH_MOST: float = 0.97


## How far the weight has shifted toward the front foot `seconds` into the
## rules' clock (m; negative toward the rear foot).
static func sway(seconds: float) -> float:
	return SHIFT * sin(TAU * seconds / SHIFT_PERIOD)


## The weight shift `seconds` into the rules' clock: the pelvis's sway along
## the line from the rear foot to the front one.
static func shift(seconds: float) -> Vector3:
	var line: Vector3 = Vector3(FEET["Right"].x - FEET["Left"].x, 0.0, FEET["Right"].z - FEET["Left"].z).normalized()
	return line * sway(seconds)


## How the stance moves the pelvis, and the weapon with it, `seconds` into
## the rules' clock: lowered, forward and swaying.
static func offset(seconds: float) -> Vector3:
	return Vector3(0.0, -CROUCH, FORWARD) + shift(seconds)


## Lays the stance on `rig` and its body layer, shown `weight` of the way
## (0 to 1), `seconds` into the rules' clock: the foot targets where
## `shuffle` has the feet (for a skeleton turned `spin` from the way the
## fighter faces), how far the feet follow them rather than the clip, and
## the body's turns and offset with the shuffle's bob, on top of what the
## body layer already has (`share` of them: a swing's body takes the rest,
## SwingPlayer.Body), then the pelvis sunk as far as the legs need to reach
## the feet.
## Returns how far it sank (m), for the weapon to ride. Call it between
## updates, while the skeleton holds the clip's pose.
static func pose(rig: FighterRig, weight: float, seconds: float, shuffle: GuardShuffle, spin: float = 0.0, share: float = 1.0) -> float:
	shuffle.place(rig, spin)
	rig.clip_feet = 1.0 - weight
	var body: BodyLayer = rig.body
	# The hips turned from straight ahead, whatever way the clip turns them
	# (the relaxed idle stands turned 13 degrees to the right), and the
	# clip's own twist above them taken out, so the spine's turn is all the
	# stance's.
	var sk: Skeleton3D = rig.skeleton
	var hips: int = sk.find_bone("Hips")
	var clip_turn: float = BodyLayer.heading(sk, hips, sk.get_bone_global_pose(hips))
	var own: float = weight * share
	body.pelvis_yaw += deg_to_rad(PELVIS_YAW) * own - clip_turn * weight
	body.untwist = lerpf(body.untwist, 1.0, weight)
	body.spine_yaw += deg_to_rad(SPINE_YAW) * own
	body.spine_pitch += deg_to_rad(SPINE_PITCH) * own
	body.head_pitch += deg_to_rad(HEAD_PITCH) * own
	body.hips_offset += (offset(seconds) + Vector3(0.0, shuffle.shown_bob, 0.0)) * own
	var down: float = sink(rig) * weight
	body.hips_offset.y -= down
	return down


## How far the pelvis must sink, from where the body layer has it, for each
## leg to reach its foot target within REACH_MOST of its length (m). Call it
## between updates, while the skeleton holds the clip's pose.
static func sink(rig: FighterRig) -> float:
	var sk: Skeleton3D = rig.skeleton
	var hips: Transform3D = rig.body.hips_moved(sk)
	var most: float = 0.0
	for side: String in FighterRig.SIDES:
		var hip: Vector3 = hips * sk.get_bone_global_pose(sk.find_bone(side + "UpperLeg")).origin
		var foot: Vector3 = rig.foot_position[side]
		var reach: float = REACH_MOST * rig.leg_length(side)
		var across: float = Vector2(hip.x - foot.x, hip.z - foot.z).length()
		if across < reach:
			most = maxf(most, hip.y - foot.y - sqrt(reach * reach - across * across))
	return most
