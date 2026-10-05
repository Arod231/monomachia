class_name TrainingUpkeep
extends RefCounted
## Training's upkeep, in the rules: port of Game.trainingUpkeep() in
## v0.1-web-mvp:src/game.ts. The match host steps it after every rules step of a Training
## match, inside the fixed step, so it stays deterministic; the soak and the
## duel behind the menus never run it.
##
## Each step, for both fighters:
## - a fighter knocked out gets up at once: full HP, posture empty, the
##   ultimate back, free, and the world's K.O. and slow motion cleared (the
##   endless match never ends the round);
## - with refill on, from REFILL_AFTER frames after a fighter was last hurt
##   (its HP fell, or it was in hitstun), its HP refills REFILL_RATE a frame,
##   the dummy's posture drains as fast, and full HP gives the ultimate back;
## - the dummy, disarmed and free, re-arms once it has been disarmed for
##   REARM_AFTER frames and unhurt as long: its dropped weapon goes. (The
##   demo counted from the last hurt alone, so a dummy unhurt for a while
##   re-armed as soon as its disarm stagger ended.) The player picks theirs up.
##
## The frames are the world's (World.frame), so hit-stop doesn't count.
##
## Choosing the dummy's behaviour (task 23.2): weapon_for() gives the weapon
## that performs it, the one picked in the select (picked) whenever it can,
## else the first in the select's order (Moves.PLAYABLE_WEAPONS) that can;
## the unblockable drills need an ability with their counter kind
## (TrainingBrain.weapon_ability_for), so new unblockables count without a
## table. swap_dummy_weapon() changes it cleanly, as Game.swapDummyWeapon()
## did: anything that belongs to the old weapon stops first.

## Frames unhurt before the refill starts.
const REFILL_AFTER: int = 90
## HP gained (and the dummy's posture lost) per frame of refill.
const REFILL_RATE: float = 2.0
## Frames disarmed, and unhurt, before the dummy re-arms.
const REARM_AFTER: int = 240

## Refill health (key 0 on the Training panel).
var refill: bool = true
var world: World
## The dummy's side.
var dummy: int
## The dummy's weapon at the start, picked in the select.
var picked: WeaponDef
## Per side: the world frame it was last hurt, and its HP after the last step.
var _last_hurt: Array[int] = [0, 0]
var _prev_hp: Array[float] = [SimConst.HP_MAX, SimConst.HP_MAX]
## The world frame the dummy was first seen disarmed, or -1 while armed.
var _disarmed_at: int = -1


func _init(p_world: World, p_dummy: int = 1) -> void:
	world = p_world
	dummy = p_dummy
	picked = world.fighters[dummy].weapon
	for i: int in 2:
		_prev_hp[i] = world.fighters[i].hp


## Runs one step's upkeep, after the rules' step.
func step() -> void:
	for i: int in 2:
		var f: Fighter = world.fighters[i]
		if f.hp < _prev_hp[i] or f.state == &"hitstun":
			_last_hurt[i] = world.frame
		_prev_hp[i] = f.hp
		if f.state == &"ko":
			_stand_up(f)
		var unhurt: int = world.frame - _last_hurt[i]
		if refill and unhurt > REFILL_AFTER and (f.hp < SimConst.HP_MAX or (i == dummy and f.posture > 0.0)):
			f.hp = minf(SimConst.HP_MAX, f.hp + REFILL_RATE)
			if i == dummy:
				f.posture = maxf(0.0, f.posture - REFILL_RATE)
			if f.hp >= SimConst.HP_MAX:
				f.ult_used = false
		if i == dummy:
			_upkeep_dummy_weapon(f, unhurt)


## Whether weapon w can perform a dummy behaviour (TrainingBrain.BEHAVIOURS):
## the unblockable drills need an ability with their counter kind.
static func can_perform(w: WeaponDef, behaviour: StringName) -> bool:
	if behaviour == &"thrust" or behaviour == &"sweep" or behaviour == &"slam":
		return TrainingBrain.weapon_ability_for(w, behaviour) != &""
	return true


## The weapon the dummy performs a behaviour with: the picked one when it
## can, else the first in the select's order that can.
func weapon_for(behaviour: StringName) -> WeaponDef:
	if can_perform(picked, behaviour):
		return picked
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		var w: WeaponDef = Moves.WEAPONS[id]
		if can_perform(w, behaviour):
			return w
	return picked


## Hands the dummy weapon w: an impale lets go, a state that belongs to the
## old weapon (an attack, an ultimate, a recall, a pickup, the disarm
## stagger) ends, and the dummy is armed with w's default abilities, its old
## weapon gone from the floor.
func swap_dummy_weapon(w: WeaponDef) -> void:
	var f: Fighter = world.fighters[dummy]
	f.release_if_impaling()
	if [&"attack", &"ult", &"ultChoice", &"recall", &"pickup", &"disarmStagger"].has(f.state):
		f.to_free()
	f.weapon = w
	f.armed = true
	f.abilities = w.default_abilities.duplicate()
	world.remove_dropped_weapon(dummy)
	_disarmed_at = -1


func _upkeep_dummy_weapon(f: Fighter, unhurt: int) -> void:
	if f.armed:
		_disarmed_at = -1
		return
	if _disarmed_at < 0:
		_disarmed_at = world.frame
	if f.state == &"free" and unhurt > REARM_AFTER and world.frame - _disarmed_at > REARM_AFTER:
		world.remove_dropped_weapon(f.id)
		f.armed = true
		_disarmed_at = -1


func _stand_up(f: Fighter) -> void:
	f.hp = SimConst.HP_MAX
	f.posture = 0.0
	f.ult_used = false
	f.ult_announced = false
	f.set_state(&"free")
	world.ko_resolved = false
	world.slowmo_frames = 0
