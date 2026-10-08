class_name Gaits
extends RefCounted
## The gaits the rules move a fighter at (milestone-1 task 55, stories 81 and
## 82): the walk, run and sprint clips' own measured speeds, which the
## frame-data table commits ("gaits": FrameDataTable), so the clips play at
## 1.0x and the feet never skate. The view's legs (Locomotion) blend the same
## clips by the same ways, and the bake measures them (FrameDataRows).
##
## - **The ways.** Eight ways round the fighter, every 45° from straight
##   ahead, positive to its left (WAYS): forward, forward-left, left,
##   back-left, back, back-right, right, forward-right. A way between two
##   moves at the two clips' speeds blended by how near each is (speed()).
## - **The clips** (CLIPS, the owner's answers of Oct 8): the packs' Walk01
##   and Run01 ahead and on the diagonals, StrafeWalk01 and StrafeRun01
##   sideways, the right strafes being the left ones mirrored on import so
##   the two sides match, the backward runs re-keyed with a shorter stride
##   (RunBackward*, about 3.9 m/s, slower than the forward run), and the
##   forward five ways sprinting on Sprint01. A sprint held further back turns
##   the body away (Locomotion), so it sprints at the forward sprint's speed.
## - **The tilt.** The stick walks from the dead zone (SimConst.DIR_DEADZONE)
##   to WALK_TILT and blends from the walk into the run between WALK_TILT and
##   full tilt (at_tilt()); the keyboard always tilts fully, so it runs.
##
## The weapon's speed (WeaponDef.speed_mult: the Greatsword and the Daggers
## until milestone 2) and the disarmed ×1.2 (until task 88's disarmed gaits)
## scale these in Fighter, as before.

const WAYS: int = 8
const WAY_STEP: float = PI / 4.0
## The gaits, in blend order.
const GAITS: Array[StringName] = [&"walk", &"run", &"sprint"]
## Each gait's clip for each way (clip-manifest ids; "" for none).
const CLIPS: Dictionary[StringName, Array] = {
	&"walk": ["Walk01_Forward", "Walk01_ForwardLeft", "StrafeWalk01_Left", "Walk01_BackwardLeft",
		"Walk01_Backward", "Walk01_BackwardRight", "StrafeWalk01_Left_Mirror", "Walk01_ForwardRight"],
	&"run": ["Run01_Forward", "Run01_ForwardLeft", "StrafeRun01_Left", "RunBackwardLeft",
		"RunBackward", "RunBackwardLeft_Mirror", "StrafeRun01_Left_Mirror", "Run01_ForwardRight"],
	&"sprint": ["Sprint01_Forward", "Sprint01_ForwardLeft", "Sprint01_Left", "", "", "", "Sprint01_Right", "Sprint01_ForwardRight"],
}
## Below this tilt (past the dead zone) the stick walks; from it to full
## tilt it blends into the run (the owner's answer, Oct 8).
const WALK_TILT: float = 0.7

## Each clip's speed, read from the table once.
static var _speeds: Dictionary = {}


## Every gait clip, each once, in id order.
static func clips() -> Array[StringName]:
	var found: Dictionary[StringName, bool] = {}
	for gait: StringName in GAITS:
		for c: Variant in CLIPS[gait]:
			if str(c) != "":
				found[StringName(str(c))] = true
	var out: Array[StringName] = []
	out.assign(found.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Clip `id`'s measured speed (m/s) from the committed table; 0 for a clip
## the table lacks.
static func clip_speed(id: String) -> float:
	if not _speeds.has(id):
		var row: Variant = FrameDataTable.shared().gaits.get(id)
		_speeds[id] = float(row["speed"]) if row is Dictionary else 0.0
	return _speeds[id]


## The two ways round `way` (radians from straight ahead, positive to the
## left) and the share of the second: (the way before, the way after, its
## share), the ways as indices into WAYS.
static func way_weights(way: float) -> V3:
	var at: float = fposmod(way, TAU) / WAY_STEP
	if absf(at - roundf(at)) < 1e-9:
		at = fposmod(roundf(at), float(WAYS))
	var before: int = floori(at) % WAYS
	return V3.make(before, (before + 1) % WAYS, at - floorf(at))


## Gait `gait`'s speed travelling `way` (radians, positive to the left): its
## two clips round the way blended; a way with no clip at the gait (the
## sprint's back ways) takes the forward clip's.
static func speed(gait: StringName, way: float) -> float:
	var w: V3 = way_weights(way)
	var row: Array = CLIPS[gait]
	return clip_speed(_clip_or_forward(row, int(w.x))) * (1.0 - w.z) + clip_speed(_clip_or_forward(row, int(w.y))) * w.z


## The speed at stick tilt `tilt` (0 to 1, past the dead zone) travelling
## `way`: the walk to WALK_TILT, then blending into the run at full tilt.
static func at_tilt(way: float, tilt: float) -> float:
	var walk: float = speed(&"walk", way)
	if tilt <= WALK_TILT:
		return walk
	var k: float = minf(1.0, (tilt - WALK_TILT) / (1.0 - WALK_TILT))
	return walk + (speed(&"run", way) - walk) * k


## The sprint's speed: the forward sprint clip's, whichever way it is held.
static func sprint_speed() -> float:
	return clip_speed(CLIPS[&"sprint"][0])


static func _clip_or_forward(row: Array, d: int) -> String:
	return str(row[d]) if str(row[d]) != "" else str(row[0])
