class_name AttackState
extends RefCounted
## Port of the AttackState interface in v0.1-web-mvp:src/sim/fighter.ts: the attack a
## fighter is performing right now.
##
## Port notes:
## - startedBy (B | null) is an int: the Btn that started the move, -1 for null
##   (chained moves and scripted starts).
## - queued (string | null) is a StringName: the queued chain move, &"" for null.
## - pathFrom and pathTo ({ ang, r } | undefined) are PathPoint objects, null
##   when undefined.
## - Keep it an object (not a Dictionary): the AI compares attacks by identity.
## - lunge_dir is the rebuild's (the demo lunged along the facing only).
## - chained_from is the rebuild's (task 7.4): the move this one follows, so
##   its swing enters from that move's hand-off key; null on a fresh start.
## - blades is the rebuild's (task 7.9): see Fighter.place_blades().


## A point of the Shadow Step path: { ang, r } around the opponent.
class PathPoint:
	var ang: float = 0.0
	var r: float = 0.0

	static func make(p_ang: float, p_r: float) -> PathPoint:
		var p: PathPoint = PathPoint.new()
		p.ang = p_ang
		p.r = p_r
		return p


var def: AttackDef
## the move this one follows as its follow-up, or null on a fresh start
var chained_from: AttackDef = null
var frame: int = 0
var hit_done: bool = false
var hits_done: int = 0
var charging: bool = false
var charge_frames: int = 0
var charge_frac: float = 0.0
var queued: StringName = &""
## the hit of a string the queued move plays (Fighter.string_count; KE task
## 5), 0 for a follow-up outside a string
var queued_hit: int = 0
var lunge_total: float = 0.0
## the ground direction the lunge runs along, fixed as the attack starts (a
## lunge along the dodge: Passing Cut); null runs it along the facing
var lunge_dir: V2 = null
var extra_recovery: int = 0
var backstab: bool = false
var started_by: int = -1
## the frames the attack spends heaving the Greatsword off the shoulder before
## its frame 1 (authored-animation task 15): GS_SHOULDER_LIFT_FRAMES for an
## attack started shouldered, the rest of the lift for one started from a
## guard still lifting off the shoulder, 0 otherwise
var lift: int = 0
## the frames of the lift still to come: while above 0 the attack holds its
## frame 0, so everything after it comes that much later
var lift_left: int = 0
var evaded_emitted: bool = false
var whiff_emitted: bool = false
# shadow step path
var path_from: PathPoint = null
var path_to: PathPoint = null
## each striking track of the move's swing in the world, at this tick and the
## last; empty for a move without a swing
var blades: Array[BladeSegment] = []
