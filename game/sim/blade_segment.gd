class_name BladeSegment
extends RefCounted
## A striking track's strike segment in the world (task 7.9): where the part a
## swing strikes with (a weapon's blade, a fist or a foot) is at this tick, and
## where it was at the last, as the attack state keeps them
## (Fighter.blade_segments()). A blade sweep (BladeSweep) runs from the last
## tick's segment to this one.

## the swing's track: right_hand, left_hand, right_foot or left_foot
var part: StringName = &""
var base: V3 = V3.make()
var tip: V3 = V3.make()
## the segment at the last tick: on the attack's first tick, this one
var prev_base: V3 = V3.make()
var prev_tip: V3 = V3.make()
## half the strike segment's thickness, plus SimConst.UNBLOCKABLE_SWEEP_BONUS
## for an unblockable (task 7.12): half the thickness its sweep tests
var half_thickness: float = 0.0


## Half the thickness a sweep of `segment` tests on the move `def`: half the
## segment's own, plus SimConst.UNBLOCKABLE_SWEEP_BONUS for an unblockable
## (task 7.12).
static func half_thickness_for(segment: StrikeSegment, def: AttackDef) -> float:
	return segment.thickness / 2.0 + (SimConst.UNBLOCKABLE_SWEEP_BONUS if def.unblockable else 0.0)
