class_name Footwork
extends RefCounted
## Starts, stops and pivots (milestone-1 task 57, stories 85-89): short rules
## states (Fighter's &"footwork") that move a fighter exactly as their clips
## travel, as the spec's momentum and gait table says. Each kind's clips (four
## ways each, per class, the owner's answers of Oct 8) share one length and
## one travel, so the rules hold one profile per kind: its forward clip's
## travel, which the bake measures into the frame-data table's clip rows
## (PROFILE_CLIPS). The fighter moves along the way it travelled as the state
## began (backwards along it for a pivot's second half).
##
## - **A guarded start** (6 frames): a blocking fighter setting off from a
##   stand, up to the guarded shuffle's pace.
## - **A guarded stop** (6 frames): letting go of the stick below the run.
## - **A run stop** (14 frames, about 0.5 m): letting go at the run's pace or
##   faster (RUN_SHARE of the run that way). Pushing the same way again
##   (within SAME_WAY of the travel) runs on at once; pushing more than
##   PIVOT_TURN from it turns the stop into a pivot; otherwise it plays out.
## - **A plant-and-reverse pivot** (14 frames, about 0.5 m): the stick swung
##   more than PIVOT_TURN from the travel at the run's pace or faster; the
##   body brakes, plants and sets off back the other way, handing on at the
##   pace it has then. Smaller turns steer through the blend, as before.
## - **A sprint stop** (20 frames, about 1 m): letting go of a sprint, or
##   reversing out of one (which plays the sprint stop first); one, forward,
##   since a sprint held backwards already turns the body away.
##
## Any attack, dodge, backstep, jump, parry or block cuts in at once
## (Fighter._update_footwork). The tap step keeps its instant start and its
## rules (SimConst.MOVE_STEP_DIST over MOVE_STEP_FRAMES); its clips
## (TAP_STEP) only show it. Only movesets with guarded cycles (the Katana,
## bare hands: Gaits.has_guard()) have footwork; the Greatsword and the
## Daggers keep the acceleration and deceleration until milestone 2.

const START: StringName = &"start"
const STOP: StringName = &"stop"
const RUN_STOP: StringName = &"run_stop"
const PIVOT: StringName = &"pivot"
const SPRINT_STOP: StringName = &"sprint_stop"
const KINDS: Array[StringName] = [START, STOP, RUN_STOP, PIVOT, SPRINT_STOP]
## The tap step's clips' kind (its rules are the step state's).
const TAP_STEP: StringName = &"tap_step"
## The four ways a footwork clip goes, from the fighter's facing.
const WAYS: Array[StringName] = [&"forward", &"left", &"back", &"right"]
## Each kind's profile: its forward Katana clip, whose measured travel the
## table holds.
const PROFILE_CLIPS: Dictionary[StringName, StringName] = {
	START: &"KatanaStartForward",
	STOP: &"KatanaStopForward",
	RUN_STOP: &"KatanaRunStopForward",
	PIVOT: &"KatanaPivotForward",
	SPRINT_STOP: &"KatanaSprintStop",
}
## A run stop or a pivot needs this share of the run's speed that way.
const RUN_SHARE: float = 0.85
## A stop needs at least this speed (m/s); slower, the fighter just slows.
const STOP_MIN: float = 0.5
## A stick swung more than this from the travel (radians) pivots.
const PIVOT_TURN: float = 135.0 * PI / 180.0
## Within this of the travel (radians), a push during a stop runs on.
const SAME_WAY: float = 45.0 * PI / 180.0


## Whether moveset `weapon_id` has footwork.
static func applies(weapon_id: StringName) -> bool:
	return Gaits.has_guard(weapon_id)


## Kind `kind`'s length in rules frames: its profile clip's in the table.
static func frames(kind: StringName) -> int:
	var row: Variant = FrameDataTable.shared().clips.get(String(PROFILE_CLIPS[kind]))
	return int(row["frames"]) if row is Dictionary else 0


## How far kind `kind` moves the fighter along its travel on rules frame `f`
## (m, from frame f - 1; negative back the other way).
static func travel_at(kind: StringName, f: int) -> float:
	return float(FrameDataTable.shared().clip_travel_at(PROFILE_CLIPS[kind], f)[0])


## Kind `kind`'s whole travel along the way (m), and its whole path (m, out
## and back for a pivot).
static func distance(kind: StringName) -> float:
	var d: float = 0.0
	for f: int in range(1, frames(kind) + 1):
		d += travel_at(kind, f)
	return d


static func path(kind: StringName) -> float:
	var d: float = 0.0
	for f: int in range(1, frames(kind) + 1):
		d += absf(travel_at(kind, f))
	return d


## The way (WAYS) nearest `way` (radians from the facing, positive to the
## left), four ways round.
static func way_of(way: float) -> StringName:
	return WAYS[roundi(fposmod(way, TAU) / (PI / 2.0)) % 4]
