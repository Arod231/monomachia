class_name StateClips
extends RefCounted
## The state-clip table (game/assets/kevin_iglesias/state_clips.json): which
## clips a fighter plays besides a swing's, and the timings that go with
## them. ClipDirector reads it where it once held the values as constants (the
## Animation Studio edits the file, so they are data now). It holds no
## animation data, so it is committed. Clip ids are the clip manifest's, a
## fallback a clip of the committed CC0 library (played without the packs).
##
##   {"idle": {"clips": {"katana": "CombatIdle1H01"}, "fallbacks": {"katana": "Sword_Idle"}},
##    "fades": {"attack": 3, ...},
##    "blends": {"attack": 3, ...},
##    "hit": {"clips": [light, heavy], "fallbacks": [light, heavy], "heavy_hitstun": 20},
##    "guard": {"clips": {"katana": [loop, hit]}, "fallback": "Sword_Block"},
##    "stun": {"clip": "Stun01", "fallback": "Hit_Knockback"},
##    "carry": {"pose": "ObjectGripShoulder02_R"},
##    "ults": {"moonsplitter": {...}, "impaler": {...}, "tempest": {...}},
##    "keyed": {"state": {"stomp": "Mikiri_Stomp"}, "stun": {"stomp": "Mikiri_Pinned"}},
##    "knockdown": {"clips": {"fall": ...}, "fallbacks": {"fall": ...}, "standup_from": 6},
##    "ko": {"clips": {"front": [light, heavy], "behind": [light, heavy]}, "fallback": "Death01"}}
##
## Every group and field is needed, but "own_speed", "transitions" and
## "deflects", and a field it doesn't know is an error, as in MoveClips.
##
## "own_speed" (milestone-1 task 19) lists the clips that play at 1.0 from
## their state's start instead of fitted to it, each "loop" (looping once
## past its end) or "hand_on" (handing on to what comes next): the families
## add each clip they re-key to fit its state (families 2 and 4); none yet,
## so every state clip is still fitted (ClipDirector.fitted_time()). An "about" field may say what the file is. Weapon-keyed
## tables may list any weapon but must have the bare hands' ("fists"), which
## stands in for a weapon without an entry.
##
## "transitions" (milestone-1 task 33) names the keyed transitions between
## a string's moves: "bridges" by the follow-up and the move it follows
## ({"k_l2": {"k_l1": clip}}), played over the follow-up's first frames
## when it follows that move, and "returns" by move ({"k_l1": clip}), each
## light's return to guard after its recovery. Both are picture only, and
## only with the packs.
##
## "deflects" (milestone-1 task 34) names each parried move's deflect pair:
## {"pairs": {"k_l1": {"deflect": clip, "deflect_contact": frame, "recoil":
## clip, "recoil_contact": frame}}}, the parrier's deflect and the attacker's
## recoil, each played from its contact frame (source frames at 30 fps),
## where the blades meet. A parried move without a pair plays the nearest
## light's (ClipDirector.pick_pair()). Picture only, and only with the packs.

const PATH: String = "res://assets/kevin_iglesias/state_clips.json"
const GROUPS: Array[String] = ["idle", "fades", "blends", "hit", "guard", "stun", "carry", "ults", "keyed", "knockdown", "ko"]
## The groups a file may leave out.
const OPTIONAL_GROUPS: Array[String] = ["own_speed", "transitions", "deflects"]
## A deflect pair's fields (deflect_pairs).
const PAIR_FIELDS: Array[String] = ["deflect", "deflect_contact", "recoil", "recoil_contact"]
## What a clip at its own speed does past its end.
const OWN_SPEED_ENDS: Array[String] = ["loop", "hand_on"]
const KNOCKDOWN_PHASES: Array[String] = ["fall", "ground", "standUp"]
const FADE_NAMES: Array[String] = ["attack", "follow_up", "dodge_cancel", "hitstun", "locomotion", "stance", "state", "guard", "rebound"]
const ULT_KINDS: Array[String] = ["moonsplitter", "impaler", "tempest"]
const MOONSPLITTER_FIELDS: Array[String] = ["clips", "fallback", "windup", "release"]
const IMPALER_FIELDS: Array[String] = ["clip", "drawn", "out", "recover", "recover_frames", "fallback", "aim", "dash"]
const TEMPEST_FIELDS: Array[String] = ["spin", "slashes", "flash", "final", "final_from", "final_frames", "recover_frames", "fallback"]

## The clips that play at their own speed (1.0), by clip id: &"loop" or
## &"hand_on" past their end.
var own_speed: Dictionary[StringName, StringName] = {}
## The crossfades' lengths, in rules frames, by what changes (FADE_NAMES).
var fades: Dictionary[StringName, int] = {}
## The inertial blends' lengths, in rules frames, by what hands off
## (FADE_NAMES; milestone-1 task 23): a hand-off shows the new motion whole
## at once and fades what is left of the old pose out over this many frames
## (InertialBlend). Today's crossfades' lengths, the owner's choice (Oct 5),
## but hitstun's, a cut before, 4.
var blends: Dictionary[StringName, int] = {}
## The free state's idle per weapon (a WeaponDef id; bare hands are "fists"),
## and without the packs.
var idle: Dictionary[StringName, StringName] = {}
var fallback_idle: Dictionary[StringName, StringName] = {}
## The rules states that play a hand-keyed clip of their own, by state, and a
## stun's by what caused it (Fighter.stun_cause).
var state_clips: Dictionary[StringName, StringName] = {}
var stun_clips: Dictionary[StringName, StringName] = {}
## Hitstun's recoil, light then heavy, and without the packs; a hitstun longer
## than `heavy_hitstun` frames plays the heavy one.
var hit_clips: Array[StringName] = []
var hit_fallbacks: Array[StringName] = []
var heavy_hitstun: int = 0
## The guard per weapon class: [Parry Loop, Parry Hit]; without the packs the
## one fallback.
var guard_clips: Dictionary[StringName, Array] = {}
var guard_fallback: StringName = &""
## The long stuns' clip, and without the packs.
var stun_clip: StringName = &""
var stun_fallback: StringName = &""
## The Greatsword's shoulder carry pose.
var carry_pose: StringName = &""
## Moonsplitter's clip per variant, [clip id, source frame held at]; its
## fallback and its wind-up and release in rules frames.
var ult_clips: Dictionary[StringName, Array] = {}
var ult_fallback: StringName = &""
var ult_windup: int = 0
var ult_release: int = 0
## Impaler: the clip, the source frames it is drawn back to, thrust out to and
## recovers from, the frames it recovers over, its fallback and the aim's and
## the dash's rules frames.
var impaler_clip: StringName = &""
var impaler_drawn: float = 0.0
var impaler_out: float = 0.0
var impaler_recover: float = 0.0
var impaler_recover_frames: float = 0.0
var impaler_fallback: StringName = &""
var impaler_aim: int = 0
var impaler_dash: int = 0
## Lightning Tempest: the spin's clip, the source frame each of its two slashes
## starts from, the flash's rules frames, the final's clip and the source
## frame it plays from, its and the recovery's rules frames, and the fallback.
var tempest_spin: StringName = &""
var tempest_slashes: Array[float] = []
var tempest_flash: int = 0
var tempest_final: StringName = &""
var tempest_final_from: float = 0.0
var tempest_final_frames: int = 0
var tempest_recover_frames: int = 0
var tempest_fallback: StringName = &""
## Knockdown: Knockdown01's fall timed to the fall's frames (it lands, the
## hips on the floor, on its source frame 20), its ground loop at 1.0, and its
## stand-up from `knockdown_standup_from` (the source frame; the frames before
## lie still) timed to the stand-up's frames. By phase (KNOCKDOWN_PHASES), and
## without the packs.
var knockdown_clips: Dictionary[StringName, StringName] = {}
var knockdown_fallbacks: Dictionary[StringName, StringName] = {}
var knockdown_standup_from: float = 0.0
## The KO's death by the final blow: [from the front, from behind] each
## [light, heavy]; and without the packs. Played at 1.0 from the blow, held
## lying at the end.
var ko_clips: Array[Array] = []
var ko_fallback: StringName = &""
## The string's bridges (milestone-1 task 33): by follow-up, the clip it
## plays over its first frames by the move it follows.
var bridges: Dictionary[StringName, Dictionary] = {}
## Each light's return to guard, by move.
var returns: Dictionary[StringName, StringName] = {}
## The deflect pairs (milestone-1 task 34), by parried move: {&"deflect":
## clip id, &"deflect_contact": source frame, &"recoil": clip id,
## &"recoil_contact": source frame}.
var deflect_pairs: Dictionary[StringName, Dictionary] = {}
## What is wrong with the file, one line each; empty when it read cleanly.
var errors: PackedStringArray = []

static var _shared: StateClips = null


## Reads the table.
static func read(path: String = PATH) -> StateClips:
	var t: StateClips = StateClips.new()
	if not FileAccess.file_exists(path):
		t.errors.append("%s is not there" % path)
		return t
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		t.errors.append("%s is not valid JSON (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return t
	var data: Variant = json.data
	if not data is Dictionary:
		t.errors.append("%s is not a JSON object" % path)
		return t
	var root: Dictionary = t._object(data, "", GROUPS)

	var g: Dictionary = t._object(root.get("idle"), "idle", ["clips", "fallbacks"])
	t.idle = t._id_map(g, "idle", "clips", ["fists"])
	t.fallback_idle = t._id_map(g, "idle", "fallbacks", ["fists"])

	g = t._object(root.get("fades"), "fades", FADE_NAMES)
	for key: String in FADE_NAMES:
		t.fades[StringName(key)] = t._whole(g, "fades", key)
	g = t._object(root.get("blends"), "blends", FADE_NAMES)
	for key: String in FADE_NAMES:
		t.blends[StringName(key)] = t._whole(g, "blends", key)

	g = t._object(root.get("hit"), "hit", ["clips", "fallbacks", "heavy_hitstun"])
	t.hit_clips = t._ids(g, "hit", "clips", 2)
	t.hit_fallbacks = t._ids(g, "hit", "fallbacks", 2)
	t.heavy_hitstun = t._whole(g, "hit", "heavy_hitstun")

	g = t._object(root.get("guard"), "guard", ["clips", "fallback"])
	t.guard_clips = t._guards(g, "guard", "clips")
	t.guard_fallback = t._id(g, "guard", "fallback")

	g = t._object(root.get("stun"), "stun", ["clip", "fallback"])
	t.stun_clip = t._id(g, "stun", "clip")
	t.stun_fallback = t._id(g, "stun", "fallback")

	g = t._object(root.get("carry"), "carry", ["pose"])
	t.carry_pose = t._id(g, "carry", "pose")

	var ults: Dictionary = t._object(root.get("ults"), "ults", ULT_KINDS)
	g = t._object(ults.get("moonsplitter"), "ults.moonsplitter", MOONSPLITTER_FIELDS)
	t.ult_clips = t._ult_clips(g, "ults.moonsplitter", "clips")
	t.ult_fallback = t._id(g, "ults.moonsplitter", "fallback")
	t.ult_windup = t._whole(g, "ults.moonsplitter", "windup")
	t.ult_release = t._whole(g, "ults.moonsplitter", "release")
	g = t._object(ults.get("impaler"), "ults.impaler", IMPALER_FIELDS)
	t.impaler_clip = t._id(g, "ults.impaler", "clip")
	t.impaler_drawn = t._num(g, "ults.impaler", "drawn")
	t.impaler_out = t._num(g, "ults.impaler", "out")
	t.impaler_recover = t._num(g, "ults.impaler", "recover")
	t.impaler_recover_frames = t._num(g, "ults.impaler", "recover_frames")
	t.impaler_fallback = t._id(g, "ults.impaler", "fallback")
	t.impaler_aim = t._whole(g, "ults.impaler", "aim")
	t.impaler_dash = t._whole(g, "ults.impaler", "dash")
	g = t._object(ults.get("tempest"), "ults.tempest", TEMPEST_FIELDS)
	t.tempest_spin = t._id(g, "ults.tempest", "spin")
	t.tempest_slashes = t._nums(g, "ults.tempest", "slashes", 2)
	t.tempest_flash = t._whole(g, "ults.tempest", "flash")
	t.tempest_final = t._id(g, "ults.tempest", "final")
	t.tempest_final_from = t._num(g, "ults.tempest", "final_from")
	t.tempest_final_frames = t._whole(g, "ults.tempest", "final_frames")
	t.tempest_recover_frames = t._whole(g, "ults.tempest", "recover_frames")
	t.tempest_fallback = t._id(g, "ults.tempest", "fallback")

	var keyed: Dictionary = t._object(root.get("keyed"), "keyed", ["state", "stun"])
	t.state_clips = t._id_map(keyed, "keyed", "state", [])
	t.stun_clips = t._id_map(keyed, "keyed", "stun", [])

	g = t._object(root.get("knockdown"), "knockdown", ["clips", "fallbacks", "standup_from"])
	t.knockdown_clips = t._id_map(g, "knockdown", "clips", KNOCKDOWN_PHASES)
	t.knockdown_fallbacks = t._id_map(g, "knockdown", "fallbacks", KNOCKDOWN_PHASES)
	t.knockdown_standup_from = t._num(g, "knockdown", "standup_from")

	g = t._object(root.get("ko"), "ko", ["clips", "fallback"])
	var deaths: Dictionary = t._object(g.get("clips"), "ko.clips", ["front", "behind"])
	t.ko_clips = [t._ids(deaths, "ko.clips", "front", 2), t._ids(deaths, "ko.clips", "behind", 2)]
	t.ko_fallback = t._id(g, "ko", "fallback")

	if root.has("own_speed"):
		var own: Variant = root["own_speed"]
		if not own is Dictionary:
			t.errors.append("own_speed: must be an object")
		else:
			for id: Variant in own:
				if not OWN_SPEED_ENDS.has(str(own[id])):
					t.errors.append("own_speed.%s: must be loop or hand_on" % id)
				else:
					t.own_speed[StringName(str(id))] = StringName(str(own[id]))
	if root.has("transitions"):
		g = t._object(root["transitions"], "transitions", ["bridges", "returns"])
		var bridges: Variant = g.get("bridges", {})
		if not bridges is Dictionary:
			t.errors.append("transitions.bridges: must be an object")
		else:
			for move: Variant in bridges:
				var at: String = "transitions.bridges.%s" % move
				if not bridges[move] is Dictionary:
					t.errors.append("%s: must be an object of clip ids by the move it follows" % at)
					continue
				var by: Dictionary[StringName, StringName] = {}
				for from: Variant in bridges[move]:
					var id: StringName = t._id(bridges[move], at, str(from))
					if id != &"":
						by[StringName(str(from))] = id
				t.bridges[StringName(str(move))] = by
		var returns: Variant = g.get("returns", {})
		if not returns is Dictionary:
			t.errors.append("transitions.returns: must be an object")
		else:
			for move: Variant in returns:
				var id: StringName = t._id(returns, "transitions.returns", str(move))
				if id != &"":
					t.returns[StringName(str(move))] = id
	if root.has("deflects"):
		g = t._object(root["deflects"], "deflects", ["pairs"])
		var pairs: Variant = g.get("pairs", {})
		if not pairs is Dictionary:
			t.errors.append("deflects.pairs: must be an object")
		else:
			for move: Variant in pairs:
				var at: String = "deflects.pairs.%s" % move
				var e: Dictionary = t._object(pairs[move], at, PAIR_FIELDS)
				if e.is_empty():
					continue
				t.deflect_pairs[StringName(str(move))] = {
					&"deflect": t._id(e, at, "deflect"), &"deflect_contact": t._num(e, at, "deflect_contact"),
					&"recoil": t._id(e, at, "recoil"), &"recoil_contact": t._num(e, at, "recoil_contact"),
				}
	return t


## The table the game plays by: read from PATH once and kept, so a test or the
## Studio can swap it (use()). A file that can't be read is reported here.
static func shared() -> StateClips:
	if _shared == null:
		_shared = read()
		for e: String in _shared.errors:
			push_error("state_clips.json: %s" % e)
	return _shared


## Makes `table` what shared() answers; null makes it read PATH again.
static func use(table: StateClips) -> void:
	_shared = table


## `v` as an object whose keys are all `fields` (an "about" at the top aside)
## and which has them all; what it has either way. A mistake is noted in
## `errors` and answers an empty object.
func _object(v: Variant, at: String, fields: Array[String]) -> Dictionary:
	var where: String = at if at != "" else "the file"
	if not v is Dictionary:
		errors.append("%s: not an object" % where)
		return {}
	var d: Dictionary = v
	for key: Variant in d:
		if not (at == "" and (str(key) == "about" or OPTIONAL_GROUPS.has(str(key)))) and not fields.has(str(key)):
			errors.append("%s: unknown field %s" % [where, key])
	for key: String in fields:
		if not d.has(key):
			errors.append("%s: missing %s" % [where, key])
	return d


## A clip or weapon id: a non-empty string; empty if `key` isn't one.
func _id(g: Dictionary, at: String, key: String) -> StringName:
	if not g.has(key):
		return &""
	var v: Variant = g[key]
	if not v is String or (v as String).is_empty():
		errors.append("%s.%s: must be a clip id (a non-empty string)" % [at, key])
		return &""
	return StringName(v)


## A whole number from 0 up: frames.
func _whole(g: Dictionary, at: String, key: String) -> int:
	if not g.has(key):
		return 0
	var v: Variant = g[key]
	if not (v is float or v is int) or float(v) < 0.0 or float(v) != floorf(float(v)):
		errors.append("%s.%s: must be a whole number, 0 or more" % [at, key])
		return 0
	return int(v)


## A number, 0 or more: a source frame or a speed.
func _num(g: Dictionary, at: String, key: String) -> float:
	if not g.has(key):
		return 0.0
	var v: Variant = g[key]
	if not (v is float or v is int) or float(v) < 0.0:
		errors.append("%s.%s: must be a number, 0 or more" % [at, key])
		return 0.0
	return float(v)


## A list of exactly `count` ids.
func _ids(g: Dictionary, at: String, key: String, count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if not g.has(key):
		return out
	var v: Variant = g[key]
	if not v is Array or (v as Array).size() != count or not (v as Array).all(func(x: Variant) -> bool: return x is String and not (x as String).is_empty()):
		errors.append("%s.%s: must be a list of %d clip ids" % [at, key, count])
		return out
	for x: String in v:
		out.append(StringName(x))
	return out


## A list of exactly `count` numbers, 0 or more.
func _nums(g: Dictionary, at: String, key: String, count: int) -> Array[float]:
	var out: Array[float] = []
	if not g.has(key):
		return out
	var v: Variant = g[key]
	if not v is Array or (v as Array).size() != count or not (v as Array).all(func(x: Variant) -> bool: return (x is float or x is int) and float(x) >= 0.0):
		errors.append("%s.%s: must be a list of %d numbers, 0 or more" % [at, key, count])
		return out
	for x: Variant in v:
		out.append(float(x))
	return out


## An object of ids by id (a weapon, a state, a cause) that has the keys in
## `needed`.
func _id_map(g: Dictionary, at: String, key: String, needed: Array[String]) -> Dictionary[StringName, StringName]:
	var out: Dictionary[StringName, StringName] = {}
	if not g.has(key):
		return out
	var v: Variant = g[key]
	if not v is Dictionary:
		errors.append("%s.%s: not an object" % [at, key])
		return out
	for k: Variant in v:
		var id: StringName = _id(v, "%s.%s" % [at, key], str(k))
		if id != &"":
			out[StringName(str(k))] = id
	for k: String in needed:
		if not (v as Dictionary).has(k):
			errors.append("%s.%s: needs %s" % [at, key, k])
	return out


## An object of [loop, hit] pairs by weapon id, with the bare hands'.
func _guards(g: Dictionary, at: String, key: String) -> Dictionary[StringName, Array]:
	var out: Dictionary[StringName, Array] = {}
	if not g.has(key):
		return out
	var v: Variant = g[key]
	if not v is Dictionary:
		errors.append("%s.%s: not an object" % [at, key])
		return out
	for k: Variant in v:
		var pair: Array[StringName] = _ids(v, "%s.%s" % [at, key], str(k), 2)
		if not pair.is_empty():
			out[StringName(str(k))] = pair
	if not (v as Dictionary).has("fists"):
		errors.append("%s.%s: needs fists" % [at, key])
	return out


## Moonsplitter's [clip id, hold frame] by variant, with the vertical's.
func _ult_clips(g: Dictionary, at: String, key: String) -> Dictionary[StringName, Array]:
	var out: Dictionary[StringName, Array] = {}
	if not g.has(key):
		return out
	var v: Variant = g[key]
	if not v is Dictionary:
		errors.append("%s.%s: not an object" % [at, key])
		return out
	for k: Variant in v:
		var pick: Variant = v[k]
		if not pick is Array or (pick as Array).size() != 2 or not pick[0] is String or (pick[0] as String).is_empty() \
				or not (pick[1] is float or pick[1] is int) or float(pick[1]) < 0.0:
			errors.append("%s.%s.%s: must be a clip id and the source frame it holds at" % [at, key, k])
			continue
		out[StringName(str(k))] = [StringName(pick[0]), float(pick[1])]
	if not (v as Dictionary).has("vertical"):
		errors.append("%s.%s: needs vertical" % [at, key])
	return out
