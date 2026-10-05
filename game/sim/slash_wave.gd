class_name SlashWave
extends RefCounted
## Port of the SlashWave class in v0.1-web-mvp:src/sim/world.ts: a Moonsplitter wave in
## flight. s is the distance travelled from (ox, oz) along (dx, dz).
##
## Port note: owner points back at a Fighter, a reference cycle that
## World.dispose() breaks.

var s: float = 0.0
var alive: bool = true
var resolved: bool = false
var owner: Fighter
## &"vertical" | &"horizontal"
var kind: StringName
var ox: float
var oz: float
var dx: float
var dz: float


## Not copied: the owner, which the snapshot holds as a fighter id.
const SNAPSHOT_SKIP: Array[StringName] = [&"owner"]


## A copy of the wave's fields (milestone-1 task 5), its owner as an id.
func snapshot() -> Dictionary:
	var s: Dictionary = SimState.capture(self, SNAPSHOT_SKIP)
	s[&"owner"] = owner.id
	return s


func _init(p_owner: Fighter, p_kind: StringName, p_ox: float, p_oz: float, p_dx: float, p_dz: float) -> void:
	owner = p_owner
	kind = p_kind
	ox = p_ox
	oz = p_oz
	dx = p_dx
	dz = p_dz
