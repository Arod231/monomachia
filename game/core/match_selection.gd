class_name MatchSelection
extends RefCounted
## What the fighter select remembers: one draft per mode (Duel, Training,
## Watch, Versus), each the two sides' fighter, weapon, block abilities and
## computer difficulty (and in Versus each player's device and controls
## profile), whether the Duel opponent's weapon is random, and the arena (an
## id from ArenaScenes.SELECTABLE, or RANDOM). Plain data, saved to
## user://last_select.cfg at lock in, so the last picks return.
##
## The rules for changing a draft live here, so the select only calls them:
## a weapon change resets the side's abilities to the weapon's pair, picking
## an ability the other slot holds swaps the two, and each side wears its
## side's palette (0, then 1), so the second fighter of a mirror match is
## always in the second palette. The palette doubles as the side's colour in
## the views (the ring, the dropped weapon's beam), which is why it follows
## the side rather than the match-up.
##
## lock_in() turns a draft into a MatchConfig: the mode's controllers, and the
## random weapon and arena picked from the match's seed.
##
## File layout: one section per mode, its draft under "draft" as a
## dictionary. A missing or unreadable file, or a mode whose draft doesn't
## make a valid match, gives that mode its default.

const PATH: String = "user://last_select.cfg"
## The arena slot's Random.
const RANDOM: StringName = &"random"


## One mode's picks.
class Draft:
	extends RefCounted
	var mode: StringName = MatchConfig.DUEL
	## [side 0, side 1]: fighter, palette, weapon, abilities, difficulty,
	## device and profile. lock_in() sets the controllers from the mode.
	var sides: Array[MatchSide] = []
	## Per side: the weapon is picked at random at lock in (the Duel
	## opponent only).
	var random_weapon: Array[bool] = [false, false]
	## An id from ArenaScenes.SELECTABLE, or RANDOM.
	var arena: StringName = MatchConfig.DEFAULT_ARENA

	func copy() -> Draft:
		return Draft.from_dict(to_dict())

	func to_dict() -> Dictionary:
		var out_sides: Array[Dictionary] = []
		for s: MatchSide in sides:
			out_sides.append(s.to_dict())
		return {
			"mode": String(mode),
			"sides": out_sides,
			"random_weapon": [random_weapon[0], random_weapon[1]],
			"arena": String(arena),
		}

	static func from_dict(d: Dictionary) -> Draft:
		var out: Draft = Draft.new()
		out.mode = StringName(str(d.get("mode", "")))
		var in_sides: Variant = d.get("sides", [])
		if in_sides is Array:
			for s: Variant in in_sides:
				if s is Dictionary:
					out.sides.append(MatchSide.from_dict(s))
		var rw: Variant = d.get("random_weapon", [])
		if rw is Array and (rw as Array).size() == 2:
			out.random_weapon = [bool(rw[0]), bool(rw[1])]
		out.arena = StringName(str(d.get("arena", String(MatchConfig.DEFAULT_ARENA))))
		return out


var path: String = PATH
## Off, nothing is read or written: the drafts live only as long as this
## object. main.gd turns it off for test and shot runs (GameSettings'
## DEFAULTS_ENV), so a player's saved picks can't change them, nor they the
## player's.
var persist: bool = true
var drafts: Dictionary[StringName, Draft] = {}


func _init(p_path: String = PATH, p_persist: bool = true) -> void:
	path = p_path
	persist = p_persist
	for mode: StringName in MatchConfig.MODES:
		drafts[mode] = default_draft(mode)


## The demo's defaults: Duel is the Rogue with the katana against the Hunter
## with the greatsword (Normal); Training the same against the dummy; Watch
## katana against daggers, both Normal; Versus katana against greatsword, on
## the keyboard and mouse and the first controller. The Moonlit Shrine.
static func default_draft(mode: StringName) -> Draft:
	var d: Draft = Draft.new()
	d.mode = mode
	var weapons: Array[StringName] = [&"katana", &"daggers" if mode == MatchConfig.WATCH else &"greatsword"]
	for i: int in 2:
		var s: MatchSide = MatchSide.new()
		s.fighter_id = &"rogue" if i == 0 else &"hunter"
		s.palette = i
		s.weapon_id = weapons[i]
		s.difficulty = &"normal"
		s.device = InputDevices.ALL
		d.sides.append(s)
	if mode == MatchConfig.VERSUS:
		d.sides[0].device = InputDevices.KBM
		d.sides[1].device = InputDevices.PAD0
	return d


## The live draft for a mode: the select changes it in place.
func draft(mode: StringName) -> Draft:
	return drafts[mode]


# ------------------------------------------------------------------ changes

static func set_fighter(d: Draft, side: int, fighter_id: StringName) -> void:
	d.sides[side].fighter_id = fighter_id
	d.sides[side].palette = side


## A new weapon brings its default block abilities and ends a random pick.
static func set_weapon(d: Draft, side: int, weapon_id: StringName) -> void:
	var s: MatchSide = d.sides[side]
	d.random_weapon[side] = false
	if s.weapon_id == weapon_id:
		return
	s.weapon_id = weapon_id
	s.abilities = (Moves.WEAPONS[weapon_id] as WeaponDef).default_abilities.duplicate()


static func set_random_weapon(d: Draft, side: int, on: bool) -> void:
	d.random_weapon[side] = on


## Puts a block ability in a slot (0 on light, 1 on heavy). Picking the one
## the other slot holds swaps the two.
static func set_ability(d: Draft, side: int, slot: int, ability: StringName) -> void:
	var s: MatchSide = d.sides[side]
	var now: Array[StringName] = s.resolved_abilities()
	var other: int = 1 - slot
	if now[other] == ability:
		now[other] = now[slot]
	now[slot] = ability
	s.abilities = now


static func set_difficulty(d: Draft, side: int, difficulty: StringName) -> void:
	d.sides[side].difficulty = difficulty


static func set_arena(d: Draft, arena: StringName) -> void:
	d.arena = arena


## Versus: the device a player plays with (InputDevices.KBM, KB_ARROWS, PAD0
## or PAD1).
static func set_device(d: Draft, side: int, device: String) -> void:
	d.sides[side].device = device


## Versus: the Controls profile a player plays with (an index into the
## ControlProfiles).
static func set_profile(d: Draft, side: int, index: int) -> void:
	d.sides[side].profile = index


## Versus's default devices, keyboard and mouse against the first
## controller, become keyboard and mouse against the arrow layout when no
## controller is connected (the demo's defaults). Any other pick is kept.
static func fit_devices(d: Draft, input: InputDevices) -> void:
	if d.mode != MatchConfig.VERSUS:
		return
	if d.sides[0].device == InputDevices.KBM and d.sides[1].device == InputDevices.PAD0 and not input.pad_connected(0):
		d.sides[1].device = InputDevices.KB_ARROWS


## Versus: why the players' devices can't start a match now, or "": both on
## one device, or a controller that isn't connected (the owner's choice, Oct
## 5, 2026: nobody starts unable to move).
static func device_problem(d: Draft, input: InputDevices) -> String:
	if d.mode != MatchConfig.VERSUS:
		return ""
	if d.sides[0].device == d.sides[1].device:
		return "Both players are set to the same device. Pick a different one for Player 2."
	for i: int in 2:
		var seat: int = [InputDevices.PAD0, InputDevices.PAD1].find(d.sides[i].device)
		if seat >= 0 and not input.pad_connected(seat):
			return "Controller %d is not connected. Connect it, or pick another device for %s." % [seat + 1, MatchResults.PLAYERS[i]]
	return ""


# ------------------------------------------------------------------ lock in

## The match a draft makes, with the mode's controllers: Duel a human against
## the computer, Training a human against the dummy, Watch two computers,
## Versus two humans on their devices. A random weapon or arena is picked
## from `p_seed`: the same seed gives the same picks.
static func lock_in(d: Draft, p_seed: int) -> MatchConfig:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = p_seed
	var sides: Array[MatchSide] = []
	for i: int in 2:
		var s: MatchSide = MatchSide.from_dict(d.sides[i].to_dict())
		s.palette = i
		s.controller = controller_for(d.mode, i)
		if s.controller != MatchSide.HUMAN:
			s.device = InputDevices.ALL
			s.profile = -1
		elif d.mode != MatchConfig.VERSUS:
			s.device = InputDevices.ALL
		if d.random_weapon[i] and offers_random(d.mode, i):
			s.weapon_id = Moves.PLAYABLE_WEAPONS[rng.randi_range(0, Moves.PLAYABLE_WEAPONS.size() - 1)]
			s.abilities.clear()
		sides.append(s)
	var arena: StringName = d.arena
	if arena == RANDOM or not ArenaScenes.SELECTABLE.has(arena):
		arena = ArenaScenes.SELECTABLE[rng.randi_range(0, ArenaScenes.SELECTABLE.size() - 1)]
	return MatchConfig.make(d.mode, sides[0], sides[1], p_seed, arena)


## Who plays a side in a mode.
static func controller_for(mode: StringName, side: int) -> StringName:
	match mode:
		MatchConfig.DUEL:
			return MatchSide.HUMAN if side == 0 else MatchSide.COMPUTER
		MatchConfig.TRAINING:
			return MatchSide.HUMAN if side == 0 else MatchSide.DUMMY
		MatchConfig.WATCH:
			return MatchSide.COMPUTER
	return MatchSide.HUMAN


## Whether a side may leave its weapon to chance: the Duel opponent only
## (lock_in() picks it).
static func offers_random(mode: StringName, side: int) -> bool:
	return mode == MatchConfig.DUEL and side == 1


## Whether a side picks block abilities: everyone but the training dummy.
static func picks_abilities(mode: StringName, side: int) -> bool:
	return controller_for(mode, side) != MatchSide.DUMMY


## Empty when a draft makes a match, else what is wrong with it.
static func problem(d: Draft) -> String:
	if not MatchConfig.MODES.has(d.mode):
		return "unknown mode %s" % d.mode
	if d.sides.size() != 2:
		return "needs two sides, not %d" % d.sides.size()
	if d.arena != RANDOM and not ArenaScenes.SELECTABLE.has(d.arena):
		return "unknown arena %s" % d.arena
	return lock_in(d, 1).problem()


# ------------------------------------------------------------------ saving

## Writes the drafts (nothing when persist is off).
func save() -> Error:
	if not persist:
		return OK
	var f: ConfigFile = ConfigFile.new()
	for mode: StringName in MatchConfig.MODES:
		f.set_value(String(mode), "draft", drafts[mode].to_dict())
	return f.save(path)


## Reads the saved drafts; a mode whose draft is missing or broken keeps its
## default. Returns whether the file was read.
func load_saved() -> bool:
	for mode: StringName in MatchConfig.MODES:
		drafts[mode] = default_draft(mode)
	if not persist or not FileAccess.file_exists(path):
		return false
	var f: ConfigFile = ConfigFile.new()
	if f.load(path) != OK:
		return false
	for mode: StringName in MatchConfig.MODES:
		var v: Variant = f.get_value(String(mode), "draft", null)
		if not v is Dictionary:
			continue
		var d: Draft = Draft.from_dict(v)
		if d.mode == mode and problem(d) == "":
			for i: int in 2:
				d.sides[i].palette = i
			drafts[mode] = d
	return true
