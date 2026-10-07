class_name AnnouncementEntrance
## The centre announcement's entrance and exit, which run 1.3 s (FRAMES
## rules steps) whatever the call's length, as a share t of that. Since
## milestone-1 task 54 the brushed kanji are painted in by a brush-stroke
## wipe over the first WIPE of the run (wipe(), easing out), while the words
## under them fade in over the first 12% (fade_in()); the whole call holds,
## then fades out from 78% while easing to 0.98 (fade_out(), scale()), and
## stays gone. The demo's scale-in from 1.35 is retired. A call shorter than
## the run (Fight) is cut off where it ends. MatchHud feeds t from the host's
## rules steps, so a pause freezes it and slow motion stretches it.

const FRAMES: int = 78

const ENTER: float = 0.12
const LEAVE: float = 0.78
const END_SCALE: float = 0.98
## The brush stroke's share of the run: 12 frames, 0.2 s.
const WIPE: float = 12.0 / FRAMES


## How much of the kanji the brush has painted, 0 to 1.
static func wipe(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= WIPE:
		return 1.0
	var u: float = 1.0 - t / WIPE
	return 1.0 - u * u


## The words' fade in.
static func fade_in(t: float) -> float:
	if t <= 0.0:
		return 0.0
	return minf(t / ENTER, 1.0)


## The whole call's fade out (and gone outside the run).
static func fade_out(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t <= LEAVE:
		return 1.0
	return 1.0 - (t - LEAVE) / (1.0 - LEAVE)


## The words' opacity: faded in, then out.
static func alpha(t: float) -> float:
	return fade_in(t) * fade_out(t)


static func scale(t: float) -> float:
	if t <= LEAVE:
		return 1.0
	return lerpf(1.0, END_SCALE, minf((t - LEAVE) / (1.0 - LEAVE), 1.0))
