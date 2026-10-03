class_name RawInput
extends RefCounted
## Port of the RawInput interface and emptyInput() from src/sim/input.ts.
##
## Device-agnostic input as the simulation sees it.
## Keyboards, gamepads and the AI all produce a RawInput each frame; the
## InputTracker turns that into edges, buffered presses, taps and double-taps.

## strafe axis: +1 = right
var mx: float = 0.0
## forward axis: +1 = toward the opponent
var my: float = 0.0
## bitmask of held buttons (1 << Btn.X)
var buttons: int = 0


## { mx, my, buttons }
static func make(p_mx: float = 0.0, p_my: float = 0.0, p_buttons: int = 0) -> RawInput:
	var r: RawInput = RawInput.new()
	r.mx = p_mx
	r.my = p_my
	r.buttons = p_buttons
	return r


## emptyInput()
static func empty() -> RawInput:
	return make(0.0, 0.0, 0)
