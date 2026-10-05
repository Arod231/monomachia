class_name DroppedWeapon
extends RefCounted
## Port of the DroppedWeapon class in v0.1-web-mvp:src/sim/world.ts (and DroppedWeaponLike in
## worldTypes.ts): a weapon knocked out of a fighter's hands, flying or lying on
## the ground.
##
## Port note: the constructor draws spin magnitude, spin sign and yaw from the
## world's Rng in that order, as the TS does.

var grounded: bool = false
var spin: float
var tumble: float = 0.0
var yaw: float
var rest_frames: int = 0
var owner: int
var weapon_id: StringName
var pos: V3
var vel: V3


func _init(p_owner: int, p_weapon_id: StringName, p_pos: V3, p_vel: V3, rng: Rng) -> void:
	owner = p_owner
	weapon_id = p_weapon_id
	pos = p_pos
	vel = p_vel
	var spin_mag: float = rng.range(10.0, 18.0)
	var spin_sign: float = 1.0 if rng.chance(0.5) else -1.0
	spin = spin_mag * spin_sign
	yaw = rng.range(0.0, PI * 2.0)
