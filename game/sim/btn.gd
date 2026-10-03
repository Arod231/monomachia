class_name Btn
extends RefCounted
## Port of `enum B`, NUM_BUTTONS and bit() from src/sim/input.ts.
##
## Button indices into RawInput.buttons (bit 1 << index).

const LIGHT: int = 0
const HEAVY: int = 1
const BLOCK: int = 2
const DODGE: int = 3
const JUMP: int = 4
const INTERACT: int = 5
const ULTIMATE: int = 6
const SPRINT: int = 7
## NUM_BUTTONS
const NUM: int = 8


static func bit(b: int) -> int:
	return 1 << b
