class_name Roster
extends RefCounted
## What the menus offer (milestone-1 task 4): during milestone 1 only the
## Hunter and the Katana, with bare hands as the disarmed state; the
## `--full-roster` command-line flag (or `full` set by a test) brings back
## the Rogue, the Greatsword and the Twin Daggers. Their code and tests stay;
## only what can be picked is filtered.
##
## Every place that lists fighters or weapons reads it: the fighter grid, the
## weapon cards, a random weapon at lock in, How to play's tabs, Training's
## drills and weapon-for-drill fallback, the saved picks and the soak. A
## config built by code (a test, a shot scene) may still name a hidden
## fighter or weapon: MatchSide.problem() checks what exists, this what is
## offered.

const FLAG: String = "--full-roster"
## The fighters and playable weapons milestone 1 brings to final quality.
const MILESTONE_FIGHTERS: Array[StringName] = [&"hunter"]
const MILESTONE_WEAPONS: Array[StringName] = [&"katana"]

## Whether the whole roster is offered: the flag on this run's command line,
## or set by a test (put it back with reset()).
static var full: bool = requested(OS.get_cmdline_args() + OS.get_cmdline_user_args())


## Whether a command line asks for the whole roster.
static func requested(args: PackedStringArray) -> bool:
	return args.has(FLAG)


## Back to what this run's command line asked for.
static func reset() -> void:
	full = requested(OS.get_cmdline_args() + OS.get_cmdline_user_args())


## The fighters offered, in the select's order.
static func fighters() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in MatchSide.FIGHTER_NAMES:
		if full or MILESTONE_FIGHTERS.has(id):
			out.append(id)
	return out


## The playable weapons offered, in the select's order (Moves.PLAYABLE_WEAPONS).
static func weapons() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Moves.PLAYABLE_WEAPONS:
		if full or MILESTONE_WEAPONS.has(id):
			out.append(id)
	return out


static func offers_fighter(id: StringName) -> bool:
	return fighters().has(id)


static func offers_weapon(id: StringName) -> bool:
	return weapons().has(id)


## Whether a side's fighter and weapon are both offered.
static func offers_side(s: MatchSide) -> bool:
	return offers_fighter(s.fighter_id) and offers_weapon(s.weapon_id)


## The training dummy's behaviours offered, in TrainingBrain.BEHAVIOURS
## order: those some offered weapon can perform (the Slam drill needs the
## Greatsword, so it goes while the Greatsword is hidden).
static func behaviours() -> Array[StringName]:
	var offered: Array[StringName] = weapons()
	var out: Array[StringName] = []
	for b: StringName in TrainingBrain.BEHAVIOURS:
		for id: StringName in offered:
			if UnblockableRoutes.can_perform(Moves.WEAPONS[id], b):
				out.append(b)
				break
	return out
