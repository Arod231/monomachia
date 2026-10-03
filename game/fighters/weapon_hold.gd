class_name WeaponHold
extends Resource
## How a fighter carries one weapon when it isn't attacking: the clip it
## idles in, how the weapon sits in the fist, and which wrists are set
## instead of left to the clip. A fighter's look lists one per weapon.
##
## The grip and wrists are a stand-in for a carried weapon (see FighterRig),
## until the guard poses (plan tasks 14 and 15) place every weapon and the
## hands follow on IK: the clips were made for a one-handed sword in the
## right hand, so left to themselves they point a second blade into the
## fighter's own body and wave a greatsword about like a stick.
##
## The fist's frame is FighterRig.fist()'s (see WeaponLook): +Y out of the
## thumb side, +X out of the knuckles.

## The weapon this hold is for (a WeaponLook id).
@export var weapon: StringName = &""
## The clip to idle in with this weapon; empty for the look's idle clip.
@export var clip: StringName = &""
## In a match, the fighter stands in the grounded guard stance (GuardStance)
## with this weapon instead of idling in `clip`, the weapon posed in its
## guard.
@export var guard: bool = false
## Held with the blade out of the little-finger side of the fist instead of
## the thumb side: the dagger along the forearm, or a greatsword trailing
## from a hanging arm.
@export var reverse_grip: bool = false
## Tilts the blade in the fist toward the knuckles (positive) or the wrist
## (negative), in degrees.
@export_range(-90.0, 90.0, 1.0) var blade_tilt: float = 0.0
## Rolls the weapon about its own blade axis in the fist, in degrees (turns
## the edge).
@export_range(-180.0, 180.0, 1.0) var edge_roll: float = 0.0
## When set, the right wrist takes `right_wrist` instead of the clip's pose.
@export var set_right_wrist: bool = false
## Wrist rotation from straight, in degrees about the hand's own axes:
## X flexes it toward the palm, Y twists it, Z bends it sideways.
@export var right_wrist: Vector3 = Vector3.ZERO
## The same for the left wrist (when it holds a weapon).
@export var set_left_wrist: bool = true
@export var left_wrist: Vector3 = Vector3.ZERO


## The carried weapon's transform in the fist.
func grip_transform() -> Transform3D:
	var t: float = deg_to_rad(blade_tilt)
	var b: Basis = Basis(Vector3.UP, deg_to_rad(edge_roll))
	if reverse_grip:
		b = Basis(Vector3.BACK, t) * Basis(Vector3.RIGHT, PI) * b
	else:
		b = Basis(Vector3.BACK, -t) * b
	return Transform3D(b, Vector3.ZERO)
