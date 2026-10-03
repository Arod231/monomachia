class_name ControlProfile
extends RefCounted
## A named controls profile: one binding set for keyboard and mouse ("kb") and
## one for controllers ("pad"). Port of Profile in src/input/bindings.ts and the
## binding edits of the Controls screen in src/ui/menus.ts.

## The two tabs of the Controls screen, and the two binding sets.
const KB: String = "kb"
const PAD: String = "pad"

const NAME_MAX: int = 24

var name: String = "Player 1"
## action -> Array of keyboard and mouse tokens
var kb: Dictionary = Bindings.default_kb()
## action -> Array of controller tokens
var pad: Dictionary = Bindings.default_pad()


## A profile with the default bindings (defaultProfile()).
static func create(p_name: String = "Player 1") -> ControlProfile:
	var p: ControlProfile = ControlProfile.new()
	p.name = p_name
	return p


## The binding set of a tab (KB or PAD). Changes to it change the profile.
func binding_set(tab: String) -> Dictionary:
	return pad if tab == PAD else kb


## A copy of an action's tokens on a tab.
func slots(tab: String, action: String) -> Array[String]:
	var out: Array[String] = []
	var list: Array = binding_set(tab).get(action, [])
	for token: String in list:
		out.append(token)
	return out


## Puts token in an action's slot. An input can be bound to only one action,
## so the token is first removed wherever else it is used on this tab. A slot
## past the end of the list appends.
func bind(tab: String, action: String, slot: int, token: String) -> void:
	var bindings: Dictionary = binding_set(tab)
	for a: String in bindings:
		var list: Array = bindings[a]
		while list.has(token):
			list.erase(token)
	if not bindings.has(action):
		bindings[action] = []
	var mine: Array = bindings[action]
	if slot >= 0 and slot < mine.size():
		mine[slot] = token
	else:
		mine.append(token)


## Empties an action's slot (later slots move up).
func clear_slot(tab: String, action: String, slot: int) -> void:
	var list: Array = binding_set(tab).get(action, [])
	if slot >= 0 and slot < list.size():
		list.remove_at(slot)


## "Reset to defaults" for one tab.
func reset_tab(tab: String) -> void:
	if tab == PAD:
		pad = Bindings.default_pad()
	else:
		kb = Bindings.default_kb()


## The "Fight stick layout" preset on the controller tab.
func use_fight_stick_layout() -> void:
	pad = Bindings.fight_stick_pad()


func duplicate_profile() -> ControlProfile:
	var p: ControlProfile = ControlProfile.new()
	p.name = name
	p.kb = kb.duplicate(true)
	p.pad = pad.duplicate(true)
	return p


func to_dict() -> Dictionary:
	return {"name": name, "kb": kb.duplicate(true), "pad": pad.duplicate(true)}


## Reads a saved profile. Actions it lacks are filled from the defaults, tokens
## that are malformed or on the wrong tab are dropped, and each action keeps at
## most Bindings.SLOTS tokens.
static func from_dict(data: Dictionary, fallback_name: String = "Player 1") -> ControlProfile:
	var p: ControlProfile = ControlProfile.new()
	var raw_name: Variant = data.get("name", "")
	var clean: String = clean_name(String(raw_name)) if raw_name is String else ""
	p.name = clean if clean != "" else fallback_name
	p.kb = _read_set(data.get("kb", null), Bindings.default_kb(), false)
	p.pad = _read_set(data.get("pad", null), Bindings.default_pad(), true)
	return p


## A profile name trimmed and cut to NAME_MAX characters.
static func clean_name(text: String) -> String:
	return text.strip_edges().left(NAME_MAX).strip_edges()


static func _read_set(raw: Variant, defaults: Dictionary, joypad: bool) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var out: Dictionary = {}
	for action: String in Bindings.ACTIONS:
		var list: Variant = src.get(action, null)
		if not (list is Array or list is PackedStringArray):
			out[action] = defaults[action]
			continue
		var tokens: Array = []
		for t: Variant in list:
			if not (t is String):
				continue
			var token: String = t
			if not InputToken.is_valid(token) or InputToken.is_joypad(token) != joypad or tokens.has(token):
				continue
			if tokens.size() < Bindings.SLOTS:
				tokens.append(token)
		out[action] = tokens
	return out
