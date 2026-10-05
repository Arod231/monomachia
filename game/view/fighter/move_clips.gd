class_name MoveClips
extends RefCounted
## The move-clip table (game/assets/kevin_iglesias/move_clips.json): for each
## weapon, the clip its swings' guard is read from (its idle) and, for each
## move fitted to a clip, the clip (or the chain of clips, played one after
## another) and the speed it plays at. The bake (tools/bake_swings.gd) bakes
## each move's swing from it; without a speed the bake picks the one whose
## startup lands closest to the move's (SwingBake.pick_speed()). Clip ids
## are the clip manifest's (ClipManifest). It holds no animation data, so it
## is committed.
##
##   {"katana": {"guard": "CombatIdle1H01",
##               "moves": {"k_l1": {"clips": ["Attack1H01_R"], "speed": 1.4,
##                                  "fallback": "Sword_Light_A"}}}}
##
## An "about" field may say what the file is.
##
## A chain's markers are its first clip's wind-up start and its last clip's
## contact, contact end and settle, counted from the chain's start (markers()).
## A move may give its own instead ("marks": all four, in source frames from
## the chain's start), where one clip serves moves of different timings: a
## light started from a heavy clip's wound-up pose, say (task 10). A chain
## entry may be part of a clip ("id@from" or "id@from-to", ClipChain), and a
## chargeable move's marks may add the "hold" its charge holds at
## (ClipTiming). "sheathed" gives the source frames (from the chain's start)
## the blade spends in the saya, from going in to coming out (task 11).
##
## "markers" (milestone-1 task 14) are the markers the move's frame data are
## generated from (tasks 15-17), in source frames from the chain's start
## played at 1.0x, each a whole or half frame: the wind-up start, the active
## frames' start and end, the settle, the dodge-cancel window (its start, and
## an end that defaults to the settle) when the move has one, and a branch
## point for each follow-up ("branch": {move: frame}). On the Katana's and
## bare hands' moves they are stand-ins ("markers_stand_in"): placed to give
## today's frame data exactly, not at the clip's events, until their family
## re-keys them; frame_data() reads them. A stand-in's clip still plays by
## its "marks" and speed, so the two differ.
##
## From milestone-1 task 19 a move with real markers plays its clip at 1.0x
## from its wind-up start, so a Katana or bare-hands move a family re-keys
## has no "speed" (its "marks" may stay, recording where the clip's events
## fall); the Greatsword's, the Daggers' and both Counter Lunges' keep theirs,
## unread, until milestone 2 re-keys them. A
## chargeable move may name the "loop" its held charge plays (a ClipChain
## entry), at 1.0 from when the charge began.

const PATH: String = "res://assets/kevin_iglesias/move_clips.json"
const WEAPON_FIELDS: Array[String] = ["guard", "moves"]
const MOVE_FIELDS: Array[String] = ["clips", "speed", "fallback", "marks", "sheathed", "markers", "markers_stand_in", "loop"]
## The weapons whose moves play at 1.0x once re-keyed (milestone 1's): a
## re-keyed move of theirs has no speed.
const ONE_SPEED_WEAPONS: Array[StringName] = [&"katana", &"fists"]
## A move's markers that every move has, in the order they fall.
const RULES_MARKERS: Array[String] = ["windup", "active_start", "active_end", "settle"]
## The dodge-cancel window's markers, for a move with one: the start, and an
## end that defaults to the settle.
const DODGE_CANCEL_MARKERS: Array[String] = ["dodge_cancel", "dodge_cancel_end"]
## Rules frames per source frame at 1.0x: 60 a second over 30.
const RULES_PER_SOURCE: float = ClipTiming.RULES_FPS / ClipManifest.SOURCE_FPS


## One move fitted to its clips.
class Entry:
	var move: StringName = &""
	## Played one after another: ClipChain entries (a clip id, or part of
	## one).
	var clips: Array[StringName] = []
	## Times the clips' 30 fps; NAN to have the bake pick it.
	var speed: float = NAN
	## The committed CC0 clip (in FighterModel.LIBRARY) played without the
	## Iglesias packs, the clip table's fallback; empty for none.
	var fallback: StringName = &""
	## The move's own markers (ClipManifest.MARKERS, source frames from the
	## chain's start) in place of the manifest's; empty for the manifest's.
	var marks: Dictionary = {}
	## The source frames from the chain's start the blade is in the saya,
	## first and last; empty for never.
	var sheathed: PackedFloat64Array = PackedFloat64Array()
	## The markers the move's frame data are generated from (RULES_MARKERS,
	## DODGE_CANCEL_MARKERS and "branch": {follow-up: frame}), in source
	## frames from the chain's start at 1.0x; empty for none.
	var markers: Dictionary = {}
	## Whether they are stand-ins giving today's frame data, waiting for the
	## move's family to re-key it.
	var markers_stand_in: bool = false
	## The loop a held charge plays (a ClipChain entry); empty for none.
	var loop: StringName = &""


## Weapon id -> the clip its guard is read from.
var guards: Dictionary[StringName, StringName] = {}
## Weapon id -> move id -> its entry, in the file's order.
var moves: Dictionary[StringName, Dictionary] = {}
## What is wrong with the file, one line each; empty when it read cleanly.
var errors: PackedStringArray = []


## Reads the table, checking its weapons and moves against the rules'
## (Moves.WEAPONS) and its clips against `manifest`.
static func read(manifest: ClipManifest, path: String = PATH) -> MoveClips:
	var t: MoveClips = MoveClips.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		t.errors.append("%s is not a JSON object" % path)
		return t
	for wkey: Variant in data:
		if str(wkey) == "about":
			continue
		var wid := StringName(str(wkey))
		if not Moves.WEAPONS.has(wid):
			t.errors.append("%s: not a weapon" % wid)
			continue
		var w: Variant = data[wkey]
		if not w is Dictionary:
			t.errors.append("%s: not an object" % wid)
			continue
		for field: Variant in w:
			if not WEAPON_FIELDS.has(str(field)):
				t.errors.append("%s: unknown field %s" % [wid, field])
		var guard := StringName(str(w.get("guard", "")))
		if not manifest.clips.has(guard):
			t.errors.append("%s: the guard clip %s is not in the clip manifest" % [wid, guard])
		t.guards[wid] = guard
		var entries: Dictionary[StringName, Entry] = {}
		var listed: Variant = w.get("moves", {})
		if not listed is Dictionary:
			t.errors.append("%s: moves must be an object" % wid)
			listed = {}
		for mkey: Variant in listed:
			var e: Entry = t._entry(wid, StringName(str(mkey)), listed[mkey], manifest)
			if e != null:
				entries[e.move] = e
		t.moves[wid] = entries
	return t


## The entries of a weapon's moves (Dictionary[StringName, Entry]), by move.
func of(weapon_id: StringName) -> Dictionary:
	return moves.get(weapon_id, {})


## A move's markers in source frames from its chain's start: its own marks,
## else the first clip's wind-up start and the last clip's other markers, as
## the chain lays them out (`lengths`: each entry's whole clip's length in
## source frames).
static func markers(e: Entry, manifest: ClipManifest, lengths: PackedFloat64Array) -> Dictionary:
	if not e.marks.is_empty():
		return e.marks.duplicate()
	var first: ClipChain.Part = ClipChain.parse(String(e.clips[0]), [] as Array[String])
	var last: ClipChain.Part = ClipChain.parse(String(e.clips[-1]), [] as Array[String])
	# where the last part starts: the parts before it, each to its end or its
	# clip's
	var start: float = 0.0
	for i: int in e.clips.size() - 1:
		var p: ClipChain.Part = ClipChain.parse(String(e.clips[i]), [] as Array[String])
		start += p.hold if p.hold > 0.0 else (lengths[i] if is_nan(p.to) else p.to) - p.from
	var out: Dictionary = {}
	for name: String in ClipManifest.MARKERS:
		if name == "windup":
			out[name] = maxf(0.0, float((manifest.clips[first.id] as ClipManifest.Clip).markers[name]) - first.from)
		else:
			out[name] = start + float((manifest.clips[last.id] as ClipManifest.Clip).markers[name]) - last.from
	return out


## The frame data markers give (an Entry's markers), the clip played at
## 1.0x: startup, active and recovery, "dodge_cancel_from" and
## "dodge_cancel_to" (AttackDef.UNSET without a window) and "branch" (follow-up
## -> the frame it starts on), all in rules frames from the wind-up start.
static func frame_data(m: Dictionary) -> Dictionary:
	var at: Callable = func(x: float) -> int: return roundi((x - float(m["windup"])) * RULES_PER_SOURCE)
	var out: Dictionary = {
		"startup": at.call(m["active_start"]),
		"active": at.call(m["active_end"]) - at.call(m["active_start"]),
		"recovery": at.call(m["settle"]) - at.call(m["active_end"]),
		"dodge_cancel_from": at.call(m["dodge_cancel"]) if m.has("dodge_cancel") else AttackDef.UNSET,
		"dodge_cancel_to": at.call(m.get("dodge_cancel_end", m["settle"])) if m.has("dodge_cancel") else AttackDef.UNSET,
		"branch": {},
	}
	var branch: Dictionary = m.get("branch", {})
	for follow: Variant in branch:
		out["branch"][follow] = at.call(branch[follow])
	return out


func _entry(wid: StringName, id: StringName, d: Variant, manifest: ClipManifest) -> Entry:
	var at: String = "%s.%s" % [wid, id]
	if not (Moves.WEAPONS[wid] as WeaponDef).moves.has(id):
		errors.append("%s: not a move of the %s" % [at, wid])
		return null
	if not d is Dictionary:
		errors.append("%s: not an object" % at)
		return null
	for field: Variant in d:
		if not MOVE_FIELDS.has(str(field)):
			errors.append("%s: unknown field %s" % [at, field])
	var e: Entry = Entry.new()
	e.move = id
	var clips: Variant = (d as Dictionary).get("clips")
	if not clips is Array or (clips as Array).is_empty():
		errors.append("%s: needs clips, a list of clip ids" % at)
		return null
	for c: Variant in clips:
		var why: Array[String] = []
		var part: ClipChain.Part = ClipChain.parse(str(c), why)
		if part == null:
			errors.append("%s: %s" % [at, why[0]])
			return null
		if ClipChain.is_cc0(part.id):
			if not FighterModel.ANIMATION_LIBRARY.has_animation(String(part.id).get_slice("/", 1)):
				errors.append("%s: %s is not in the CC0 library" % [at, part.id])
				return null
		elif not manifest.clips.has(part.id):
			errors.append("%s: %s is not in the clip manifest" % [at, part.id])
			return null
		e.clips.append(StringName(str(c)))
	if (d as Dictionary).has("speed"):
		var s: Variant = d["speed"]
		if not (s is float or s is int) or float(s) < ClipTiming.MIN_SPEED or float(s) > ClipTiming.MAX_SPEED:
			errors.append("%s: speed must be a number from %.1f to %.1f" % [at, ClipTiming.MIN_SPEED, ClipTiming.MAX_SPEED])
			return null
		e.speed = float(s)
	if (d as Dictionary).has("fallback"):
		var fb := StringName(str(d["fallback"]))
		if not FighterModel.ANIMATION_LIBRARY.has_animation(fb):
			errors.append("%s: the fallback %s is not in the CC0 library" % [at, fb])
			return null
		e.fallback = fb
	if (d as Dictionary).has("marks"):
		var m: Variant = d["marks"]
		var names: Array[String] = ClipManifest.MARKERS.duplicate()
		if m is Dictionary and (m as Dictionary).has("hold"):
			names.append("hold")
		var ok: bool = m is Dictionary and (m as Dictionary).size() == names.size()
		if ok:
			for name: String in names:
				var v: Variant = (m as Dictionary).get(name)
				ok = ok and (v is float or v is int) and float(v) >= 0.0
		if not ok:
			errors.append("%s: marks must give %s (and may give a hold), each a frame number" % [at, ", ".join(ClipManifest.MARKERS)])
			return null
		for name: String in names:
			e.marks[name] = float(m[name])
	if e.marks.is_empty() and e.clips.any(func(c: StringName) -> bool: return ClipChain.is_cc0(ClipChain.parse(String(c), [] as Array[String]).id)):
		errors.append("%s: a chain with a CC0 clip needs its own marks (the manifest has none for it)" % at)
		return null
	if (d as Dictionary).has("sheathed"):
		var sh: Variant = d["sheathed"]
		if not sh is Array or (sh as Array).size() != 2 or not (sh as Array).all(func(x: Variant) -> bool: return x is float or x is int) \
				or float(sh[0]) < 0.0 or float(sh[1]) <= float(sh[0]):
			errors.append("%s: sheathed must be two source frames, the first before the second" % at)
			return null
		e.sheathed = PackedFloat64Array([float(sh[0]), float(sh[1])])
	if (d as Dictionary).has("markers"):
		var why: Array[String] = []
		e.markers = _markers(wid, d["markers"], why)
		if not why.is_empty():
			for w: String in why:
				errors.append("%s: %s" % [at, w])
			return null
	var stand_in: Variant = (d as Dictionary).get("markers_stand_in", false)
	if not stand_in is bool or (stand_in and e.markers.is_empty()):
		errors.append("%s: markers_stand_in is true or false, and true only with markers" % at)
		return null
	e.markers_stand_in = stand_in
	var waits: bool = ((Moves.WEAPONS[wid] as WeaponDef).moves[id] as AttackDef).special == &"counterLunge"
	if ONE_SPEED_WEAPONS.has(wid) and not e.markers.is_empty() and not stand_in and not waits and (d as Dictionary).has("speed"):
		errors.append("%s: a move with real markers plays at 1.0x, so it has no speed" % at)
		return null
	if (d as Dictionary).has("loop"):
		if not ((Moves.WEAPONS[wid] as WeaponDef).moves[id] as AttackDef).chargeable:
			errors.append("%s: only a chargeable move has a loop" % at)
			return null
		var why: Array[String] = []
		var part: ClipChain.Part = ClipChain.parse(str(d["loop"]), why)
		if part != null and not ClipChain.is_cc0(part.id) and not manifest.clips.has(part.id):
			why.append("%s is not in the clip manifest" % part.id)
		if not why.is_empty():
			errors.append("%s: the loop: %s" % [at, why[0]])
			return null
		e.loop = StringName(str(d["loop"]))
	return e


## A move's markers read from `m` (see Entry.markers), each mistake pushed
## into `why`.
static func _markers(wid: StringName, m: Variant, why: Array[String]) -> Dictionary:
	if not m is Dictionary:
		why.append("markers must be an object")
		return {}
	var out: Dictionary = {}
	var frame: Callable = func(name: String, v: Variant) -> bool:
		if not (v is float or v is int) or float(v) < 0.0 or float(v) * 2.0 != floorf(float(v) * 2.0):
			why.append("marker %s must be a whole or half source frame" % name)
			return false
		return true
	for name: Variant in m:
		if not (RULES_MARKERS.has(str(name)) or DODGE_CANCEL_MARKERS.has(str(name)) or str(name) == "branch"):
			why.append("unknown marker %s" % name)
	for name: String in RULES_MARKERS + DODGE_CANCEL_MARKERS:
		if not (m as Dictionary).has(name):
			if RULES_MARKERS.has(name):
				why.append("no %s marker" % name)
			continue
		if frame.call(name, m[name]):
			out[name] = float(m[name])
	if not why.is_empty():
		return out
	for i: int in range(1, RULES_MARKERS.size()):
		if out[RULES_MARKERS[i]] <= out[RULES_MARKERS[i - 1]]:
			why.append("marker %s must come after %s" % [RULES_MARKERS[i], RULES_MARKERS[i - 1]])
	if out.has("dodge_cancel_end") and not out.has("dodge_cancel"):
		why.append("dodge_cancel_end needs a dodge_cancel")
	elif out.has("dodge_cancel"):
		var end: float = out.get("dodge_cancel_end", out["settle"])
		if out["dodge_cancel"] < out["active_end"] or out["dodge_cancel"] >= end or end > out["settle"]:
			why.append("the dodge-cancel window must open from active_end and close by the settle")
	var branch: Variant = (m as Dictionary).get("branch", {})
	if not branch is Dictionary:
		why.append("branch must be an object of follow-up moves and frames")
		return out
	var points: Dictionary = {}
	for follow: Variant in branch:
		var move := StringName(str(follow))
		if not (Moves.WEAPONS[wid] as WeaponDef).moves.has(move):
			why.append("branch %s is not a move of the %s" % [move, wid])
		elif frame.call("branch %s" % move, branch[follow]):
			var x: float = float(branch[follow])
			if x <= out["active_start"] or x > out["settle"]:
				why.append("branch %s must come after active_start and by the settle" % move)
			points[move] = x
	out["branch"] = points
	return out
