class_name StudioCatalogue
extends RefCounted
## Every animation the Studio's gallery shows, built at start-up from the data
## the game reads (docs/specs/animation-studio.md, Catalogue):
##
## - the moves of move_clips.json, by weapon, in the table's order;
## - the states and ultimates of state_clips.json (idle per weapon, hit, guard
##   per weapon, stun, rebound, carry, knockdown, KO, the keyed stomp and its
##   pinned stun, and the three ultimates);
## - source clips: the clip manifest's, the committed CC0 library's (the UAL
##   list in tools/build_animation_library.gd) and the keyed library's.
##
## The roll and the locomotion clips (MOVEMENT_CLIPS) are source entries shown in
## the `states` group: the director plays them but no state_clips.json key
## times them, so their timing is view-only. They are listed once, there, and
## not again in the `source` group.
##
## A data file that fails to read (its reader's `errors`) is reported in
## `errors`, each line prefixed with the file, and every entry from that file
## is `read_only`: the Studio never saves over a file it couldn't read.

## The groups an entry is in besides the weapons' (a move's group is its
## weapon: &"katana", &"greatsword", &"daggers" or &"fists").
const GROUP_STATES: StringName = &"states"
const GROUP_ULTS: StringName = &"ults"
const GROUP_SOURCE: StringName = &"source"
## The kinds an entry can be.
const KIND_MOVE: StringName = &"move"
const KIND_STATE: StringName = &"state"
const KIND_ULT: StringName = &"ult"
const KIND_SOURCE: StringName = &"source"
## An entry's badges, all false until something sets them (the fallback and
## provisional ones here; correctives, unsaved edits and a balance change by
## the Studio as the owner works).
const BADGES: Array[StringName] = [&"fallback", &"provisional", &"corrective", &"unsaved", &"balance"]

const MANIFEST_FILE: String = ClipManifest.PATH
const MOVES_FILE: String = MoveClips.PATH
const STATES_FILE: String = StateClips.PATH
## The CC0 library's clip list: its builder's consts.
const UAL_FILE: String = "res://tools/build_animation_library.gd"

## The manifest clips shown as states: the roll and the locomotion, by id.
const MOVEMENT_CLIPS: Dictionary[StringName, String] = {
	&"Roll01": "Roll",
	&"Walk01_Forward": "Walk",
	&"Run01_Forward": "Run",
	&"Sprint01_Forward": "Sprint",
	&"StrafeWalk01_Left": "Strafe walk left",
	&"StrafeWalk01_Right": "Strafe walk right",
	&"StrafeRun01_Left": "Strafe run left",
	&"StrafeRun01_Right": "Strafe run right",
	&"Turn01_Left": "Turn left",
	&"Turn01_Right": "Turn right",
}
## The display names of the states and ultimates that aren't per weapon.
const STATE_NAMES: Dictionary[StringName, String] = {
	&"hit_light": "Hit (light)",
	&"hit_heavy": "Hit (heavy)",
	&"stun": "Stun",
	&"rebound": "Rebound",
	&"carry": "Carry",
	&"knockdown": "Knockdown",
	&"ko_front_light": "KO from the front (light)",
	&"ko_front_heavy": "KO from the front (heavy)",
	&"ko_behind_light": "KO from behind (light)",
	&"ko_behind_heavy": "KO from behind (heavy)",
	&"stomp": "Stomp",
	&"stomp_stun": "Stomped (pinned)",
	&"moonsplitter_vertical": "Moonsplitter (vertical)",
	&"moonsplitter_horizontal": "Moonsplitter (horizontal)",
	&"impaler": "Impaler",
	&"tempest": "Lightning Tempest",
}


## Where an entry's data sits: a file, the key path of the value in it, and its
## line (1-based; 0 when the value couldn't be found).
class Location:
	var path: String = ""
	var key_path: Array[String] = []
	var line: int = 0


## One animation of the catalogue.
class Entry:
	## &"move", &"state", &"ult" or &"source".
	var kind: StringName = &""
	## &"katana", &"greatsword", &"daggers", &"fists", &"states", &"ults" or
	## &"source".
	var group: StringName = &""
	var id: StringName = &""
	var name: String = ""
	## The ClipChain entries it plays, in order (a clip id, "id@from-to",
	## "ual/Name", "keyed/Name"); empty for the rebound, which plays the
	## attack it parries backwards.
	var clips: Array[String] = []
	## What the game plays instead without the packs, as ClipChain entries of
	## the CC0 library ("ual/Name"): one per part of `clips` for a state or ult
	## with several (the knockdown's phases, a guard's loop and hit, the
	## tempest's spin and final); one for anything else, a move's chain
	## included (its fallback is stretched over the whole move); empty for an
	## entry that plays as it is.
	var fallbacks: Array[String] = []
	## Times the clips' 30 fps; NAN where the bake picks it (a move without one).
	var speed: float = 1.0
	## Where its data is: the file, key path and line of each value.
	var source: Array[Location] = []
	## By BADGES. `fallback`: without the packs the game plays the data's
	## fallback clip for it; `provisional`: a clip it plays has provisional
	## markers in the manifest.
	var badges: Dictionary[StringName, bool] = {}
	## True when the file it comes from had read errors.
	var read_only: bool = false

	func _init() -> void:
		for b: StringName in BADGES:
			badges[b] = false


var entries: Array[Entry] = []
## Each reader's errors, prefixed with its file.
var errors: PackedStringArray = []

var _manifest: ClipManifest = null
var _read_only: Dictionary[String, bool] = {}
var _texts: Dictionary[String, String] = {}


## Builds the catalogue from the tables the game reads. `keyed` is the keyed
## library's clip names (StudioLibraries.keyed().get_animation_list()).
static func build(manifest: ClipManifest, table: MoveClips, states: StateClips, keyed: Array[StringName]) -> StudioCatalogue:
	var c: StudioCatalogue = StudioCatalogue.new()
	c._manifest = manifest
	c._take_errors(MANIFEST_FILE, manifest.errors)
	c._take_errors(MOVES_FILE, table.errors)
	c._take_errors(STATES_FILE, states.errors)
	c._add_moves(table)
	c._add_states(states)
	c._add_ults(states)
	c._add_source(keyed)
	return c


## The entries of a group, in order.
func in_group(g: StringName) -> Array[Entry]:
	var out: Array[Entry] = []
	for e: Entry in entries:
		if e.group == g:
			out.append(e)
	return out


## The entry of `kind` and `id`, or null.
func find(kind: StringName, id: StringName) -> Entry:
	for e: Entry in entries:
		if e.kind == kind and e.id == id:
			return e
	return null


func _take_errors(file: String, found: PackedStringArray) -> void:
	_read_only[file] = not found.is_empty()
	for line: String in found:
		errors.append("%s: %s" % [file.get_file(), line])


# --- moves -------------------------------------------------------------------


func _add_moves(table: MoveClips) -> void:
	for wid: StringName in table.moves:
		var def: WeaponDef = Moves.WEAPONS.get(wid)
		for mid: StringName in table.moves[wid]:
			var m: MoveClips.Entry = table.moves[wid][mid]
			var name: String = String(mid)
			if def != null and def.moves.has(mid):
				name = def.moves[mid].name
			var clips: Array[String] = []
			clips.assign(m.clips)
			_add(KIND_MOVE, wid, mid, name, clips, _fallbacks([m.fallback]), m.speed, MOVES_FILE, [[String(wid), "moves", String(mid)]])


# --- states and ultimates ------------------------------------------------------


func _add_states(sc: StateClips) -> void:
	for w: StringName in sc.idle:
		var paths: Array = [["idle", "clips", String(w)]]
		if sc.fallback_idle.has(w):
			paths.append(["idle", "fallbacks", String(w)])
		_add(KIND_STATE, GROUP_STATES, StringName("idle_%s" % w), "Idle (%s)" % _weapon_name(w), _clips([sc.idle[w]]), _fallbacks([sc.fallback_idle.get(w, &"")]), 1.0, STATES_FILE, paths)
	for i: int in 2:
		var id: StringName = &"hit_light" if i == 0 else &"hit_heavy"
		_add(KIND_STATE, GROUP_STATES, id, STATE_NAMES[id], _clips([_at(sc.hit_clips, i)]), _fallbacks([_at(sc.hit_fallbacks, i)]), 1.0, STATES_FILE, [["hit", "clips"], ["hit", "fallbacks"]])
	for w: StringName in sc.guard_clips:
		# the one fallback stands in for the loop and the hit
		_add(KIND_STATE, GROUP_STATES, StringName("guard_%s" % w), "Guard (%s)" % _weapon_name(w), _clips(sc.guard_clips[w]), _fallbacks([sc.guard_fallback, sc.guard_fallback]), 1.0, STATES_FILE, [["guard", "clips", String(w)], ["guard", "fallback"]])
	_add(KIND_STATE, GROUP_STATES, &"stun", STATE_NAMES[&"stun"], _clips([sc.stun_clip]), _fallbacks([sc.stun_fallback]), 1.0, STATES_FILE, [["stun", "clip"], ["stun", "fallback"]])
	_add(KIND_STATE, GROUP_STATES, &"rebound", STATE_NAMES[&"rebound"], _clips([]), _fallbacks([]), sc.rebound_speed, STATES_FILE, [["rebound"]])
	_add(KIND_STATE, GROUP_STATES, &"carry", STATE_NAMES[&"carry"], _clips([sc.carry_pose]), _fallbacks([]), 1.0, STATES_FILE, [["carry", "pose"]])
	var phases: Array = []
	var phase_fallbacks: Array = []
	for phase: String in StateClips.KNOCKDOWN_PHASES:
		var id: StringName = sc.knockdown_clips.get(StringName(phase), &"")
		# the game plays the stand-up from a source frame on (the frames before lie still)
		if phase == "standUp" and id != &"" and sc.knockdown_standup_from > 0.0:
			phases.append("%s@%s" % [id, JsFormat.num(sc.knockdown_standup_from)])
		else:
			phases.append(id)
		phase_fallbacks.append(sc.knockdown_fallbacks.get(StringName(phase), &""))
	_add(KIND_STATE, GROUP_STATES, &"knockdown", STATE_NAMES[&"knockdown"], _clips(phases), _fallbacks(phase_fallbacks), 1.0, STATES_FILE, [["knockdown", "clips"], ["knockdown", "fallbacks"], ["knockdown", "standup_from"]])
	var deaths: Array[StringName] = [&"ko_front_light", &"ko_front_heavy", &"ko_behind_light", &"ko_behind_heavy"]
	for i: int in deaths.size():
		var side: Array = sc.ko_clips[i >> 1] if sc.ko_clips.size() == 2 else []
		var from: String = "front" if i < 2 else "behind"
		_add(KIND_STATE, GROUP_STATES, deaths[i], STATE_NAMES[deaths[i]], _clips([_at(side, i % 2)]), _fallbacks([sc.ko_fallback]), 1.0, STATES_FILE, [["ko", "clips", from], ["ko", "fallback"]])
	_add_movement()
	for cause: StringName in sc.state_clips:
		_add(KIND_STATE, GROUP_STATES, cause, STATE_NAMES.get(cause, String(cause).capitalize()), _clips([KeyedClips.anim_name(sc.state_clips[cause])]), _fallbacks([]), 1.0, STATES_FILE, [["keyed", "state", String(cause)]])
	for cause: StringName in sc.stun_clips:
		var id: StringName = StringName("%s_stun" % cause)
		_add(KIND_STATE, GROUP_STATES, id, STATE_NAMES.get(id, "%s stun" % String(cause).capitalize()), _clips([KeyedClips.anim_name(sc.stun_clips[cause])]), _fallbacks([]), 1.0, STATES_FILE, [["keyed", "stun", String(cause)]])


func _add_ults(sc: StateClips) -> void:
	for variant: StringName in sc.ult_clips:
		var id: StringName = StringName("moonsplitter_%s" % variant)
		_add(KIND_ULT, GROUP_ULTS, id, STATE_NAMES.get(id, "Moonsplitter (%s)" % variant), _clips([_at(sc.ult_clips[variant], 0)]), _fallbacks([sc.ult_fallback]), 1.0, STATES_FILE, [["ults", "moonsplitter", "clips", String(variant)], ["ults", "moonsplitter", "fallback"]])
	_add(KIND_ULT, GROUP_ULTS, &"impaler", STATE_NAMES[&"impaler"], _clips([sc.impaler_clip]), _fallbacks([sc.impaler_fallback]), 1.0, STATES_FILE, [["ults", "impaler"]])
	# one fallback stands in for the spin and the final
	_add(KIND_ULT, GROUP_ULTS, &"tempest", STATE_NAMES[&"tempest"], _clips([sc.tempest_spin, sc.tempest_final]), _fallbacks([sc.tempest_fallback, sc.tempest_fallback]), 1.0, STATES_FILE, [["ults", "tempest"]])


## The roll and the locomotion clips, as source entries of the states group.
func _add_movement() -> void:
	for id: StringName in MOVEMENT_CLIPS:
		if _manifest.clips.has(id):
			var e: Entry = _add(KIND_SOURCE, GROUP_STATES, id, MOVEMENT_CLIPS[id], _clips([id]), _fallbacks([]), 1.0, MANIFEST_FILE, [])
			e.source.append(_manifest_location(id))


# --- source clips ------------------------------------------------------------


func _add_source(keyed: Array[StringName]) -> void:
	for id: StringName in _manifest.clips:
		if not MOVEMENT_CLIPS.has(id):
			var e: Entry = _add(KIND_SOURCE, GROUP_SOURCE, id, String(id), _clips([id]), _fallbacks([]), 1.0, MANIFEST_FILE, [])
			e.source.append(_manifest_location(id))
	var builder: GDScript = load(UAL_FILE) as GDScript
	var looping: Array = builder.get_script_constant_map()["LOOPING"]
	var ual_text: String = _text(UAL_FILE)
	for clip: StringName in builder.call(&"clip_names"):
		var chain: String = "%s/%s" % [FighterModel.LIBRARY, clip]
		var e: Entry = _add(KIND_SOURCE, GROUP_SOURCE, StringName(chain), String(clip), _clips([chain]), _fallbacks([]), 1.0, UAL_FILE, [])
		var loc: Location = Location.new()
		loc.path = UAL_FILE
		loc.key_path = ["LOOPING" if looping.has(clip) else "ONE_SHOT"]
		loc.line = _line_at(ual_text, ual_text.find('&"%s"' % clip))
		e.source.append(loc)
	var keys: Dictionary[StringName, String] = _key_files()
	for clip: StringName in keyed:
		var chain: String = KeyedClips.anim_name(clip)
		var e: Entry = _add(KIND_SOURCE, GROUP_SOURCE, StringName(chain), String(clip), _clips([chain]), _fallbacks([]), 1.0, KeyedClips.PATH, [])
		var loc: Location = Location.new()
		loc.path = keys.get(clip, KeyedClips.PATH)
		loc.line = 1
		e.source.append(loc)


## The key-pose file of each keyed clip, by its clip name.
func _key_files() -> Dictionary[StringName, String]:
	var out: Dictionary[StringName, String] = {}
	for file: String in DirAccess.get_files_at(KeyedClips.KEYS_FOLDER):
		if file.get_extension() != "json":
			continue
		var path: String = KeyedClips.KEYS_FOLDER.path_join(file)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and (data as Dictionary).has("name"):
			out[StringName(str(data["name"]))] = path
	return out


# --- helpers -----------------------------------------------------------------


## Adds an entry and returns it. `key_paths` are the key paths in `file` of the
## values it comes from.
func _add(kind: StringName, group: StringName, id: StringName, name: String, clips: Array[String], fallbacks: Array[String], speed: float, file: String, key_paths: Array) -> Entry:
	var e: Entry = Entry.new()
	e.kind = kind
	e.group = group
	e.id = id
	e.name = name
	e.clips = clips
	e.fallbacks = fallbacks
	e.speed = speed
	e.read_only = _read_only.get(file, false)
	for kp: Array in key_paths:
		e.source.append(_location(file, kp))
	e.badges[&"fallback"] = not fallbacks.is_empty() and not StudioLibraries.available()
	e.badges[&"provisional"] = _provisional(clips)
	entries.append(e)
	return e


## The Location of manifest clip `id`. The manifest is long and has eighty
## clips to place, so its line is found by its key (one per line, as the file
## keeps it) rather than by walking the file for each.
func _manifest_location(id: StringName) -> Location:
	var loc: Location = Location.new()
	loc.path = MANIFEST_FILE
	loc.key_path = ["clips", String(id)]
	var text: String = _text(MANIFEST_FILE)
	var at: int = text.find("\n\t\t\"%s\": {" % id)
	loc.line = _line_at(text, at + 1) if at >= 0 else 0
	return loc


## The Location of the value at `key_path` of `file`.
func _location(file: String, key_path: Array) -> Location:
	var loc: Location = Location.new()
	loc.path = file
	loc.key_path.assign(key_path)
	var text: String = _text(file)
	var span: Vector2i = SourceEdit.find_value(text, loc.key_path)
	if span.x >= 0:
		loc.line = _line_at(text, span.x)
	return loc


func _text(file: String) -> String:
	if not _texts.has(file):
		_texts[file] = FileAccess.get_file_as_string(file)
	return _texts[file]


## The 1-based line of character `offset` of `text`; 0 for no such place.
func _line_at(text: String, offset: int) -> int:
	return 0 if offset < 0 else text.substr(0, offset).count("\n") + 1


## Whether a clip of the chain `clips` has provisional markers in the manifest.
func _provisional(clips: Array[String]) -> bool:
	for entry: String in clips:
		var part: ClipChain.Part = ClipChain.parse(entry, [] as Array[String])
		if part != null and _manifest.clips.has(part.id) and (_manifest.clips[part.id] as ClipManifest.Clip).provisional:
			return true
	return false


## `ids` as CC0 chain entries ("ual/Name"), the fallbacks the game plays
## without the packs; empty ones (a field the file lacks) are left out, and an
## entry with none has no fallback.
func _fallbacks(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in ids:
		if String(id) != "":
			out.append("%s/%s" % [FighterModel.LIBRARY, id])
	return out


## `ids` as chain entries, leaving out the empty ones (a field the file lacks).
func _clips(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in ids:
		if String(id) != "":
			out.append(String(id))
	return out


## Element `i` of `list`, or &"" when it has none (a table that didn't read).
func _at(list: Array, i: int) -> Variant:
	return list[i] if i < list.size() else &""


func _weapon_name(wid: StringName) -> String:
	var def: WeaponDef = Moves.WEAPONS.get(wid)
	return def.name if def != null else String(wid).capitalize()
