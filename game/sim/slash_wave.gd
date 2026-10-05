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


func _init(p_owner: Fighter, p_kind: StringName, p_ox: float, p_oz: float, p_dx: float, p_dz: float) -> void:
	owner = p_owner
	kind = p_kind
	ox = p_ox
	oz = p_oz
	dx = p_dx
	dz = p_dz
