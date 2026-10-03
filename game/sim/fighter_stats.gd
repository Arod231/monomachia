class_name FighterStats
extends RefCounted
## Port of the FighterStats interface in src/sim/fighter.ts: per-fighter tallies
## for the results screen and the soak run.

var hits_landed: int = 0
var damage_dealt: float = 0.0
var parries: int = 0
var counters: int = 0
var disarms: int = 0
var ultimates: int = 0
var blocks: int = 0
