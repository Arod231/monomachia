class_name MarkerEdits
extends RefCounted
## Marker editing in the Studio (milestone-1 task 26, Studio task 11): turns
## "put this marker on that frame" into the session's edits, refusing what
## the readers would refuse.
##
## - A move's markers (MoveClips: the wind-up, the active start and end, the
##   settle, the dodge-cancel window and each branch point, whole or half
##   source frames from the chain's start) go to the move-clip table at
##   [weapon, "moves", move, "markers", name] (a branch point at
##   [..., "markers", "branch", follow-up]). They must stay in the order
##   MoveClips checks.
## - A clip's markers (ClipManifest: the wind-up, contact, contact end and
##   settle, in order, and a rules-length clip's ready, in-hand, strike and
##   kill, whole source frames) go to the clip manifest at ["clips", clip,
##   "markers", name].
## - A move whose markers are stand-ins (MoveClips.Entry.markers_stand_in)
##   asks first: the edit then replaces them with real markers, dropping
##   "markers_stand_in" in the same step, so undo puts the stand-ins back.
##   A Katana or bare-hands move's "speed" goes in that step too, as one on
##   real markers plays at 1.0x (milestone-1 task 19).
## Foot contacts are measured, never edited here.

const STAND_IN_QUESTION: String = "Replace the stand-ins with real markers?"


## What an edit came to: the edits to make (none when refused or waiting
## for the stand-ins' answer), a refusal, or the question to ask first.
class Result:
	var edits: Array[EditSession.Edit] = []
	var error: String = ""
	var question: String = ""
	var label: String = ""


## A marker's key path under a move's or a clip's "markers": a name, or
## "branch <move>" for a branch point.
static func marker_path(name: String) -> Array[String]:
	if name.begins_with("branch "):
		return ["branch", name.substr(7)] as Array[String]
	return [name] as Array[String]


## Move `id` of weapon `wid`'s markers as the session has them: `base` (the
## entry's, as read) with its pending edits made.
static func move_markers(session: EditSession, file: String, wid: StringName, id: StringName, base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var root: Array[String] = [String(wid), "moves", String(id), "markers"]
	var names: Array[String] = []
	for n: Variant in base:
		if str(n) != "branch":
			names.append(str(n))
	for n: String in MoveClips.RULES_MARKERS + MoveClips.DODGE_CANCEL_MARKERS:
		if not names.has(n):
			names.append(n)
	for n: String in names:
		var v: Variant = session.value(file, _path(root, [n]), out.get(n))
		if v == null:
			out.erase(n)
		else:
			out[n] = float(v)
	# branch points keyed by String, as the key paths name them
	var branch: Dictionary = {}
	for follow: Variant in out.get("branch", {}):
		branch[str(follow)] = float(session.value(file, _path(root, ["branch", str(follow)]), out["branch"][follow]))
	out.erase("branch")
	if not branch.is_empty():
		out["branch"] = branch
	return out


## Whether move `id`'s markers are stand-ins, as the session has them.
static func is_stand_in(session: EditSession, file: String, wid: StringName, id: StringName, read: bool) -> bool:
	return session.value(file, [String(wid), "moves", String(id), "markers_stand_in"] as Array[String], read) == true


## Puts move `id`'s marker `name` at source frame `frame`. `entry` is the
## move as read; `confirmed` answers the stand-in question.
static func set_move_marker(session: EditSession, file: String, wid: StringName, entry: MoveClips.Entry, name: String,
		frame: float, confirmed: bool = false) -> Result:
	var r: Result = Result.new()
	var id: StringName = entry.move
	if frame * 2.0 != floorf(frame * 2.0) or frame < 0.0:
		r.error = "a marker sits on a whole or half source frame"
		return r
	var current: Dictionary = move_markers(session, file, wid, id, entry.markers)
	var candidate: Dictionary = current.duplicate(true)
	var path: Array[String] = marker_path(name)
	if path[0] == "branch":
		if not (current.get("branch", {}) as Dictionary).has(path[1]):
			r.error = "%s has no follow-up %s" % [id, path[1]]
			return r
		candidate["branch"][path[1]] = frame
	elif not (MoveClips.RULES_MARKERS + MoveClips.DODGE_CANCEL_MARKERS + [MoveClips.HOLD_MARKER]).has(name):
		r.error = "%s is not a move's marker" % name
		return r
	else:
		candidate[name] = frame
	var why: Array[String] = []
	MoveClips._markers(wid, id, candidate, why)
	if not why.is_empty():
		r.error = "; ".join(why)
		return r
	var stand_in: bool = is_stand_in(session, file, wid, id, entry.markers_stand_in)
	if stand_in and not confirmed:
		r.question = STAND_IN_QUESTION
		return r
	var root: Array[String] = [String(wid), "moves", String(id)]
	var before: Variant = current.get(name) if path[0] != "branch" else current["branch"][path[1]]
	r.edits.append(EditSession.Edit.make(file, _path(root, ["markers"] + path), _literal(before), _literal(frame)))
	if stand_in:
		r.edits.push_front(EditSession.Edit.make(file, _path(root, ["markers_stand_in"]), true, null))
		# a Katana or bare-hands move on real markers plays at 1.0x, so its
		# retime's speed goes with the stand-ins (milestone-1 task 19)
		var speed: Variant = session.value(file, _path(root, ["speed"]), null if is_nan(entry.speed) else entry.speed)
		if MoveClips.ONE_SPEED_WEAPONS.has(wid) and speed != null:
			r.edits.push_front(EditSession.Edit.make(file, _path(root, ["speed"]), speed, null))
	r.label = "%s %s to %s" % [id, name, _shown(frame)]
	return r


## Clip `id`'s markers as the session has them (`base`, the manifest's).
static func clip_markers(session: EditSession, file: String, id: StringName, base: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for n: Variant in base:
		out[str(n)] = base[n]
	for n: String in ClipManifest.MARKERS + ClipManifest.RULES_LENGTH_MARKERS:
		var v: Variant = session.value(file, ["clips", String(id), "markers", n] as Array[String], out.get(n))
		if v == null:
			out.erase(n)
		else:
			out[n] = int(v)
	return out


## Puts clip `id`'s marker `name` at source frame `frame` (whole frames).
static func set_clip_marker(session: EditSession, file: String, id: StringName, base: Dictionary, name: String, frame: float) -> Result:
	var r: Result = Result.new()
	if not (ClipManifest.MARKERS + ClipManifest.RULES_LENGTH_MARKERS).has(name):
		r.error = "%s is not a clip's marker" % name
		return r
	if frame != floorf(frame) or frame < 0.0:
		r.error = "a clip's marker sits on a whole source frame"
		return r
	var current: Dictionary = clip_markers(session, file, id, base)
	var candidate: Dictionary = current.duplicate()
	candidate[name] = int(frame)
	var last: int = -1
	for n: String in ClipManifest.MARKERS:
		if int(candidate[n]) < last:
			r.error = "marker %s comes before the one ahead of it" % n
			return r
		last = int(candidate[n])
	r.edits.append(EditSession.Edit.make(file, ["clips", String(id), "markers", name] as Array[String], current.get(name), int(frame)))
	r.label = "%s %s to %d" % [id, name, int(frame)]
	return r


## `root` and `more` as one key path.
static func _path(root: Array[String], more: Array) -> Array[String]:
	var out: Array[String] = root.duplicate()
	for k: Variant in more:
		out.append(str(k))
	return out


## A frame as the files write it: whole frames without a decimal.
static func _literal(f: Variant) -> Variant:
	if f == null:
		return null
	return int(f) if float(f) == floorf(float(f)) else float(f)


static func _shown(f: float) -> String:
	return str(int(f)) if f == floorf(f) else str(f)
