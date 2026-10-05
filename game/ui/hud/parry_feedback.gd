class_name ParryFeedback
extends RefCounted
## Training's parry timing feedback (task 23.4), worked out with no nodes;
## MatchHud pushes what it gives as toasts in Training only. Port of the
## demo's Hud.checkEarly() and Hud.checkLate() (v0.1-web-mvp:src/ui/hud.ts)
## and of the timing subline on its parry toast:
## - your parry's toast says how many frames before impact you pressed and
##   the window you had (timing_line(), from the rules' parry event);
## - "Too early": you are hit, or block, within EARLY_RANGE frames after
##   your last press's parry window closed;
## - "Too late": you press block within LATE_RANGE frames after a hit or a
##   block on you.
## Both read only the rules' state (the press frame and the window it gave),
## so they follow the frame data wherever it comes from. The ranges are the
## demo's, kept on the owner's word (Oct 4, 2026).

## Frames past the window's close that still count as too early.
const EARLY_RANGE: int = 20
## Frames after a hit or block in which a press counts as too late.
const LATE_RANGE: int = 14

## The world frame of the last hit or block on you still watched for a late
## press, or -1.
var _late_from: int = -1


## A parry event's subline: "3 frames before impact · window 9".
static func timing_line(e: Dictionary) -> String:
	return "%s before impact · window %d" % [_frames(int(e["timing"])), int(e["window"])]


## What a rules event gives for `me` (your side), whose fighter is `f`, on
## world frame `frame`: "Too early" for a hit or block on you after a press
## whose window had closed, and a hit or block starts the watch for a late
## press.
func on_event(e: Dictionary, me: int, f: Fighter, frame: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if (e["t"] == &"hit" or e["t"] == &"block") and int(e["target"]) == me:
		var since: int = frame - f.block_press_frame
		var window: int = f.parry_window_at_press if f.parry_window_at_press > 0 else f.moveset().parry_window
		if since > window and since <= window + EARLY_RANGE:
			out.append(_toast("Too early", "Parry pressed %s too early" % _frames(since - window)))
		_late_from = frame
	return out


## After each rules step: "Too late" once for a press made since the hit or
## block watched, within LATE_RANGE frames of it.
func after_step(f: Fighter, frame: int) -> Array[Dictionary]:
	if _late_from < 0:
		return []
	if frame - _late_from > LATE_RANGE:
		_late_from = -1
		return []
	if f.block_press_frame > _late_from:
		var late: int = f.block_press_frame - _late_from
		_late_from = -1
		return [_toast("Too late", "Parry pressed %s after impact" % _frames(late))]
	return []


## Forgets the watch (a new match).
func clear() -> void:
	_late_from = -1


static func _frames(n: int) -> String:
	return "%d frame%s" % [n, "" if n == 1 else "s"]


static func _toast(text: String, sub: String) -> Dictionary:
	return {"text": text, "sub": sub, "tone": HudToasts.Tone.DIM}
