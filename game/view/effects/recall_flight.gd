class_name RecallFlight
extends RefCounted
## The recalled weapon's flight back to the hand (milestone-1 task 99, the
## owner's choice of Oct 7; picture only): through the recall's roar the
## weapon stays stuck, then tears out of the ground, lifting clear, and
## arcs spinning end over end to the open hand, arriving on the rules'
## RECALL_BURST_FRAME, when the rules take it off the floor and put it in
## the hand. MatchView places the dropped weapon by it while its owner
## recalls (at()).

## Rules frames into the recall the weapon starts to tear out, and is out.
const TEAR_FROM: float = 4.0
const TEAR_END: float = 7.0
## How high it lifts as it tears out (m).
const RISE: float = 0.45
## How far the arc rises above the straight line to the hand at its middle (m).
const ARC: float = 0.9
## Turns end over end on the way to the hand.
const SPINS: float = 2.0


## Where the recalled weapon is `t` rules frames into the recall (fractions
## for the frames between), stuck at `from` and flying to `hand` (both world
## points): {"pos": Vector3, "spin": radians it has turned end over end,
## "out": 0 stuck to 1 torn out of the ground}.
static func at(from: Vector3, hand: Vector3, t: float) -> Dictionary:
	var out: float = smoothstep(TEAR_FROM, TEAR_END, t)
	var lifted: Vector3 = from + Vector3(0.0, RISE * out, 0.0)
	var arrive: float = float(SimConst.RECALL_BURST_FRAME)
	if t <= TEAR_END:
		return {"pos": lifted, "spin": 0.0, "out": out}
	var s: float = clampf((t - TEAR_END) / (arrive - TEAR_END), 0.0, 1.0)
	# quick off the ground, slowing into the hand
	var e: float = 1.0 - (1.0 - s) * (1.0 - s)
	var top: Vector3 = from + Vector3(0.0, RISE, 0.0)
	var pos: Vector3 = top.lerp(hand, e) + Vector3(0.0, ARC * 4.0 * e * (1.0 - e), 0.0)
	return {"pos": pos, "spin": TAU * SPINS * e, "out": 1.0}
