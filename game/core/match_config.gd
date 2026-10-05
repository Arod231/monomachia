class_name MatchConfig
extends Resource
## Everything a match is built from: the mode, both sides (fighter, palette,
## loadout, controller), the arena and the world seed. Built by the menus (or a
## test, or a screenshot scene) and handed to MatchHost.start().
##
## It carries the fighter, palette and arena ids from day one, though the
## stand-in view only reads the palette and weapon, so the real fighters and
## the real arena can drop in without changing the host.
##
## A config is data: the host never changes it. Round-trips through
## to_dict()/from_dict() (for saving the last selection) and through
## ResourceSaver (a .tres file).

const DUEL: StringName = &"duel"
const TRAINING: StringName = &"training"
const WATCH: StringName = &"watch"
const VERSUS: StringName = &"versus"
const MODES: Array[StringName] = [DUEL, TRAINING, WATCH, VERSUS]

## The arena a config gets unless it names one (the fighter select's arena
## slot picks from ArenaScenes.SELECTABLE): the Moonlit Shrine.
const DEFAULT_ARENA: StringName = &"moonlit_shrine"

@export var mode: StringName = DUEL
## [side 0, side 1]
@export var sides: Array[MatchSide] = []
## An id from ArenaScenes.
@export var arena_id: StringName = DEFAULT_ARENA
## The rules' random seed (World.new(..., seed)). The computer sides seed their
## brains from it (world_seed + side * 17), as the demo did.
@export var world_seed: int = 1


static func make(
	p_mode: StringName, side0: MatchSide, side1: MatchSide, p_seed: int = 1, p_arena: StringName = DEFAULT_ARENA
) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.mode = p_mode
	c.sides = [side0, side1]
	c.world_seed = p_seed
	c.arena_id = p_arena
	return c


## Duel against the computer, the demo's default: the Rogue with the katana
## (you) against the Hunter with the greatsword (Normal).
static func default_duel(p_seed: int = 1) -> MatchConfig:
	return make(
		DUEL,
		MatchSide.human(&"rogue", &"katana", 0),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"normal"),
		p_seed,
	)


## Training, the demo's default: the Rogue with the katana (you) against the
## Hunter with the greatsword as the training dummy.
static func default_training(p_seed: int = 1) -> MatchConfig:
	var dummy: MatchSide = MatchSide.new()
	dummy.fighter_id = &"hunter"
	dummy.weapon_id = &"greatsword"
	dummy.palette = 1
	dummy.controller = MatchSide.DUMMY
	return make(TRAINING, MatchSide.human(&"rogue", &"katana", 0), dummy, p_seed)


## Computer against computer from the side-on camera, the demo's default:
## katana (Normal) against daggers (Normal).
static func default_watch(p_seed: int = 1) -> MatchConfig:
	return make(
		WATCH,
		MatchSide.computer(&"rogue", &"katana", 0, &"normal"),
		MatchSide.computer(&"hunter", &"daggers", 1, &"normal"),
		p_seed,
	)


## The duel behind the menus: katana against greatsword, both Normal.
static func attract(p_seed: int = 1) -> MatchConfig:
	return make(
		WATCH,
		MatchSide.computer(&"rogue", &"katana", 0, &"normal"),
		MatchSide.computer(&"hunter", &"greatsword", 1, &"normal"),
		p_seed,
	)


## The demo's per-match seed step (a Lehmer-style LCG), for rematches and
## attract restarts: (seed * 1103515245 + 12345) % 2147483647.
static func next_seed(s: int) -> int:
	return posmod(s * 1103515245 + 12345, 2147483647)


## A copy with another world seed (sides are copied too).
func with_seed(p_seed: int) -> MatchConfig:
	var c: MatchConfig = copy()
	c.world_seed = p_seed
	return c


## A deep copy: changing it never changes this config.
func copy() -> MatchConfig:
	return MatchConfig.from_dict(to_dict())


func side(i: int) -> MatchSide:
	return sides[i]


## The first side a human plays, or -1.
func first_human_side() -> int:
	for i: int in sides.size():
		if sides[i].is_human():
			return i
	return -1


## The training dummy's side, or -1 (Training puts it on side 1).
func dummy_side() -> int:
	for i: int in sides.size():
		if sides[i].controller == MatchSide.DUMMY:
			return i
	return -1


func human_count() -> int:
	var n: int = 0
	for s: MatchSide in sides:
		if s.is_human():
			n += 1
	return n


## Empty when the config can start a match, else what is wrong with it.
func problem() -> String:
	if not MODES.has(mode):
		return "unknown mode %s" % mode
	if sides.size() != 2:
		return "needs two sides, not %d" % sides.size()
	for i: int in 2:
		if sides[i] == null:
			return "side %d is missing" % i
		var p: String = sides[i].problem()
		if p != "":
			return "side %d: %s" % [i, p]
	if mode == TRAINING and sides[1].controller != MatchSide.DUMMY:
		return "training needs the dummy on side 1"
	if mode != TRAINING and (sides[0].controller == MatchSide.DUMMY or sides[1].controller == MatchSide.DUMMY):
		return "the dummy only plays in training"
	if mode == VERSUS and human_count() != 2:
		return "versus needs two human sides"
	if mode == VERSUS:
		# each player on a device of their own: not the shared "all", not both
		# on the same one
		for i: int in 2:
			if sides[i].device == InputDevices.ALL:
				return "versus needs a device for each player, not %s" % InputDevices.ALL
		if sides[0].device == sides[1].device:
			return "versus players can't share the device %s" % sides[0].device
	if mode == WATCH and human_count() != 0:
		return "watch has no human sides"
	if String(arena_id) == "":
		return "no arena"
	return ""


func to_dict() -> Dictionary:
	var out_sides: Array[Dictionary] = []
	for s: MatchSide in sides:
		out_sides.append(s.to_dict())
	return {
		"mode": String(mode),
		"sides": out_sides,
		"arena_id": String(arena_id),
		"world_seed": world_seed,
	}


static func from_dict(d: Dictionary) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.mode = StringName(d.get("mode", "duel"))
	var in_sides: Array = d.get("sides", [])
	for s: Variant in in_sides:
		c.sides.append(MatchSide.from_dict(s as Dictionary))
	c.arena_id = StringName(d.get("arena_id", String(DEFAULT_ARENA)))
	c.world_seed = int(d.get("world_seed", 1))
	return c
