class_name UltState
extends RefCounted
## Port of the UltKind type and the UltState interface in src/sim/fighter.ts:
## an armed ultimate in progress.
##
## Port notes: kind, phase and variant are StringNames equal to the TS
## literals. Keep it an object (not a Dictionary): the scripted-hit callbacks
## compare the fighter's current ult with the one they were queued for by
## identity.

## UltKind
const KINDS: Array[StringName] = [&"moonsplitter", &"impaler", &"tempest"]

var kind: StringName = &""
var phase: StringName = &""
var pf: int = 0
## &"vertical" | &"horizontal"
var variant: StringName = &"vertical"
var spins: int = 0
var impaled: bool = false
## frames left heaving the Greatsword off the shoulder before the first phase
## runs (authored-animation task 15; see AttackState.lift_left)
var lift_left: int = 0


## { kind, phase, pf, variant, spins, impaled }
static func make(
	p_kind: StringName,
	p_phase: StringName,
	p_pf: int,
	p_variant: StringName,
	p_spins: int,
	p_impaled: bool,
) -> UltState:
	var u: UltState = UltState.new()
	u.kind = p_kind
	u.phase = p_phase
	u.pf = p_pf
	u.variant = p_variant
	u.spins = p_spins
	u.impaled = p_impaled
	return u
