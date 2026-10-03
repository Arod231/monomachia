class_name DodgeState
extends RefCounted
## Port of the DodgeState interface in src/sim/fighter.ts: a dodge or backstep
## in progress.

var dir_x: float = 0.0
var dir_z: float = 0.0
var dist: float = 0.0
var frames: int = 0
var iframes: int = 0
var recovery: int = 0
var back: bool = false
var forward: bool = false


## { dirX, dirZ, dist, frames, iframes, recovery, back, forward }
static func make(
	p_dir_x: float,
	p_dir_z: float,
	p_dist: float,
	p_frames: int,
	p_iframes: int,
	p_recovery: int,
	p_back: bool,
	p_forward: bool,
) -> DodgeState:
	var d: DodgeState = DodgeState.new()
	d.dir_x = p_dir_x
	d.dir_z = p_dir_z
	d.dist = p_dist
	d.frames = p_frames
	d.iframes = p_iframes
	d.recovery = p_recovery
	d.back = p_back
	d.forward = p_forward
	return d
