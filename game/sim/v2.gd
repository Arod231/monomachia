class_name V2
extends RefCounted
## Port of the Vec2 interface in v0.1-web-mvp:src/sim/math.ts: a point or direction on the
## ground plane (XZ).
##
## Port note: a 64-bit float pair instead of Godot's Vector2, which is float32
## and would drift from the TypeScript rules. Like the TS object literals it has
## reference semantics.

var x: float = 0.0
var z: float = 0.0


## v2(x = 0, z = 0)
static func make(px: float = 0.0, pz: float = 0.0) -> V2:
	var v: V2 = V2.new()
	v.x = px
	v.z = pz
	return v


func _to_string() -> String:
	return "(%s, %s)" % [x, z]
