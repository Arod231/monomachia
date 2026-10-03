class_name StrikeSegment
extends RefCounted
## What a striking track of a swing sweeps (task 7.5): a segment from `base`
## to `tip`, thickened by `thickness`, in metres in the frame of the part the
## track moves (see Swing):
## - a weapon's blade, in weapon space (see WeaponLook: origin at the main
##   grip, +Y along the blade, +X toward the edge, +Z out of the flat), from
##   where its cutting part starts to its point;
## - bare hands' fist, in the fist's frame, which is the same: across the
##   knuckles, from the little finger's to the index finger's;
## - bare hands' foot, in the foot's frame: along the sole, from the heel to
##   the toe.
## A sweep (task 7.8) tests the segment's path against a capsule grown by half
## the thickness, so the thickness is the blade's own, out of its flat, and
## for a fist or a foot covers the knuckles or the boot. The content tests
## (tests/content/test_strike_segments.gd) keep these numbers to the models.

var base: V3 = V3.make()
var tip: V3 = V3.make()
var thickness: float = 0.0


static func make(p_base: V3, p_tip: V3, p_thickness: float) -> StrikeSegment:
	var s: StrikeSegment = StrikeSegment.new()
	s.base = p_base
	s.tip = p_tip
	s.thickness = p_thickness
	return s
