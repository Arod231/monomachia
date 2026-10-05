class_name AnnouncementEntrance
## The centre announcement's entrance and exit (the demo's @keyframes
## announce), which runs 1.3 s (FRAMES rules steps) whatever the call's
## length, as a share t of that: it fades in while shrinking from 1.35 to its
## size over the first 12%, holds, then fades out from 78% while easing to
## 0.98, and stays gone. A call shorter than the run (Fight) is cut off
## where it ends. The demo's blur in is left out. MatchHud feeds t from the
## host's rules steps, so a pause freezes it and slow motion stretches it.

const FRAMES: int = 78

const ENTER: float = 0.12
const LEAVE: float = 0.78
const START_SCALE: float = 1.35
const END_SCALE: float = 0.98


static func alpha(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < ENTER:
		return t / ENTER
	if t <= LEAVE:
		return 1.0
	return 1.0 - (t - LEAVE) / (1.0 - LEAVE)


static func scale(t: float) -> float:
	if t < ENTER:
		return lerpf(START_SCALE, 1.0, maxf(t, 0.0) / ENTER)
	if t <= LEAVE:
		return 1.0
	return lerpf(1.0, END_SCALE, minf((t - LEAVE) / (1.0 - LEAVE), 1.0))
