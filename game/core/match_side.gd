class_name MatchSide
extends Resource
## One side of a match: which fighter, in which palette, with which loadout
## (weapon and two block abilities), and who controls them (a human on an
## input device, the computer at a difficulty, or the training dummy).
##
## Part of a MatchConfig. Plain data: the match host turns it into a
## FighterConfig for the rules and a brain or an input device for the inputs.

## A player on an input device (see `device` and `profile`).
const HUMAN: StringName = &"human"
## The computer opponent (AIBrain) at `difficulty`.
const COMPUTER: StringName = &"computer"
## The training dummy (TrainingBrain), Training mode only.
const DUMMY: StringName = &"dummy"
const CONTROLLERS: Array[StringName] = [HUMAN, COMPUTER, DUMMY]

## The fighters this build knows, with their display names. The rebuild ships
## the Rogue and the Hunter (spec, "Fighters"); the fighter lane owns their
## bodies, and only the ids live here.
const FIGHTER_NAMES: Dictionary[StringName, String] = {
	&"rogue": "Rogue",
	&"hunter": "Hunter",
}

@export var fighter_id: StringName = &"hunter"
## Which colour scheme the fighter wears. Side 1 in a mirror match takes
## another one so the two can be told apart.
@export var palette: int = 0
## A weapon id from Moves.PLAYABLE_WEAPONS.
@export var weapon_id: StringName = &"katana"
## The two block abilities [on light, on heavy]; empty means the weapon's
## default pair.
@export var abilities: Array[StringName] = []
## HUMAN, COMPUTER or DUMMY.
@export var controller: StringName = HUMAN
## A human side's device, one of InputDevices.DEVICES ("all" in Duel and
## Training: keyboard, mouse and the first controller together).
@export var device: String = InputDevices.ALL
## A human side's controls profile index in ControlProfiles; -1 is the active
## profile.
@export var profile: int = -1
## A computer side's difficulty: &"easy", &"normal" or &"hard".
@export var difficulty: StringName = &"normal"


static func human(
	p_fighter: StringName, p_weapon: StringName, p_palette: int = 0, p_device: String = InputDevices.ALL
) -> MatchSide:
	var s: MatchSide = MatchSide.new()
	s.fighter_id = p_fighter
	s.weapon_id = p_weapon
	s.palette = p_palette
	s.controller = HUMAN
	s.device = p_device
	return s


static func computer(
	p_fighter: StringName, p_weapon: StringName, p_palette: int = 0, p_difficulty: StringName = &"normal"
) -> MatchSide:
	var s: MatchSide = MatchSide.new()
	s.fighter_id = p_fighter
	s.weapon_id = p_weapon
	s.palette = p_palette
	s.controller = COMPUTER
	s.difficulty = p_difficulty
	return s


func is_human() -> bool:
	return controller == HUMAN


func weapon() -> WeaponDef:
	return Moves.WEAPONS.get(weapon_id, null)


## The block abilities the fighter takes into the match: the chosen pair, or
## the weapon's defaults.
func resolved_abilities() -> Array[StringName]:
	if abilities.size() == 2:
		return abilities.duplicate()
	var w: WeaponDef = weapon()
	var out: Array[StringName] = []
	if w != null:
		out.assign(w.default_abilities)
	return out


func display_name() -> String:
	return FIGHTER_NAMES.get(fighter_id, String(fighter_id).capitalize())


## Empty when the side is usable, else what is wrong with it.
func problem() -> String:
	if not FIGHTER_NAMES.has(fighter_id):
		return "unknown fighter %s" % fighter_id
	if not Moves.PLAYABLE_WEAPONS.has(weapon_id):
		return "unknown weapon %s" % weapon_id
	if not CONTROLLERS.has(controller):
		return "unknown controller %s" % controller
	if abilities.size() != 0:
		if abilities.size() != 2:
			return "needs two block abilities, not %d" % abilities.size()
		for a: StringName in abilities:
			if not weapon().abilities.has(a):
				return "%s is not a %s block ability" % [a, weapon_id]
	if controller == COMPUTER and not AIBrain.DIFFICULTIES.has(difficulty):
		return "unknown difficulty %s" % difficulty
	if controller == HUMAN and not InputDevices.DEVICES.has(device):
		return "unknown device %s" % device
	if palette < 0:
		return "palette must be 0 or more"
	return ""


func to_dict() -> Dictionary:
	var abs_out: Array[String] = []
	for a: StringName in abilities:
		abs_out.append(String(a))
	return {
		"fighter_id": String(fighter_id),
		"palette": palette,
		"weapon_id": String(weapon_id),
		"abilities": abs_out,
		"controller": String(controller),
		"device": device,
		"profile": profile,
		"difficulty": String(difficulty),
	}


static func from_dict(d: Dictionary) -> MatchSide:
	var s: MatchSide = MatchSide.new()
	s.fighter_id = StringName(d.get("fighter_id", "hunter"))
	s.palette = int(d.get("palette", 0))
	s.weapon_id = StringName(d.get("weapon_id", "katana"))
	var abs_in: Array = d.get("abilities", [])
	for a: Variant in abs_in:
		s.abilities.append(StringName(a))
	s.controller = StringName(d.get("controller", "human"))
	s.device = String(d.get("device", InputDevices.ALL))
	s.profile = int(d.get("profile", -1))
	s.difficulty = StringName(d.get("difficulty", "normal"))
	return s
