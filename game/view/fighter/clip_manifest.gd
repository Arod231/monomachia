class_name ClipManifest
extends RefCounted
## The clip manifest (game/assets/kevin_iglesias/clip_manifest.json): every
## Iglesias clip the game uses, where it comes from in the packs, whether it
## is mirrored, whether it loops, and its four markers in source frames. It
## holds no animation data, so it is committed; the import tool converts the
## clips it names (tools/import_clips.gd).
##
## A clip's file in the packs is
## `<pack>/Animations/<Male|Female>/<dir>/<set>@<source>.fbx`, or, for a
## clip marked `shared` (the masked poses, whose files for both sets sit in
## one folder), `<pack>/Animations/<dir>/<set>@<source>.fbx`.

const PATH: String = "res://assets/kevin_iglesias/clip_manifest.json"
## The markers, in the order they fall.
const MARKERS: Array[String] = ["windup", "contact", "contact_end", "settle"]
## Source clips are keyed at 30 frames a second.
const SOURCE_FPS: float = 30.0
## The catalogue's pages a clip can be on: a weapon's moves, bare hands,
## or the states shared by every weapon (tools/shot_scenes/clip_sheet.gd).
const GROUPS: Array[StringName] = [&"katana", &"greatsword", &"daggers", &"bare", &"states"]


## One clip of the manifest.
class Clip:
	## Its name in the libraries.
	var id: StringName
	var pack: String
	var dir: String
	## The clip's name in its file, after the set's `@`.
	var source: String
	var mirror: bool = false
	var loop: bool = false
	## Its files for every set sit in one folder, not the set's (file()).
	var shared: bool = false
	## Source frame of each marker, by MARKERS name.
	var markers: Dictionary[String, int] = {}
	var provisional: bool = false
	## The catalogue pages it is a candidate on (GROUPS).
	var groups: Array[StringName] = []

	## The clip's file for a set, relative to the Iglesias packs' folder.
	func file(set_name: StringName, set_folder: String) -> String:
		if shared:
			return "%s/Animations/%s/%s@%s.fbx" % [pack, dir, set_name, source]
		return "%s/Animations/%s/%s/%s@%s.fbx" % [pack, set_folder, dir, set_name, source]


## Clip set name -> the packs' folder for it (Male or Female).
var sets: Dictionary[StringName, String] = {}
## By id, in id order.
var clips: Dictionary[StringName, Clip] = {}
## What is wrong with the file, one line each; empty when it read cleanly.
var errors: PackedStringArray = []


static func read(path: String = PATH) -> ClipManifest:
	var m: ClipManifest = ClipManifest.new()
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		m.errors.append("%s is not a JSON object" % path)
		return m
	var sets_data: Variant = (data as Dictionary).get("sets")
	if not sets_data is Dictionary or (sets_data as Dictionary).is_empty():
		m.errors.append("no sets")
	else:
		for key: Variant in sets_data:
			m.sets[StringName(key)] = str(sets_data[key])
	var clips_data: Variant = (data as Dictionary).get("clips")
	if not clips_data is Dictionary:
		m.errors.append("no clips")
		return m
	var ids: Array = (clips_data as Dictionary).keys()
	ids.sort()
	for key: Variant in ids:
		var c: Clip = m._clip(StringName(key), clips_data[key])
		if c != null:
			m.clips[c.id] = c
	return m


## The ids of the clips on a catalogue page, in order.
func in_group(group: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Clip in clips.values():
		if c.groups.has(group):
			out.append(c.id)
	return out


## The clips' ids, in order.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(clips.keys())
	return out


func _clip(id: StringName, d: Variant) -> Clip:
	if not d is Dictionary:
		errors.append("%s: not an object" % id)
		return null
	var c: Clip = Clip.new()
	c.id = id
	for field: String in ["pack", "dir", "source"]:
		if not (d as Dictionary).get(field) is String or str(d[field]) == "":
			errors.append("%s: no %s" % [id, field])
	c.pack = str(d.get("pack", ""))
	c.dir = str(d.get("dir", ""))
	c.source = str(d.get("source", ""))
	c.mirror = d.get("mirror", false) == true
	c.loop = d.get("loop", false) == true
	c.shared = d.get("shared", false) == true
	c.provisional = d.get("provisional", false) == true
	var groups: Variant = d.get("groups", [])
	if not groups is Array or (groups as Array).is_empty():
		errors.append("%s: no groups" % id)
	else:
		for g: Variant in groups:
			if not GROUPS.has(StringName(str(g))):
				errors.append("%s: unknown group %s" % [id, g])
			else:
				c.groups.append(StringName(str(g)))
	var marks: Variant = d.get("markers")
	if not marks is Dictionary:
		errors.append("%s: no markers" % id)
		return c
	var last: int = -1
	for name: String in MARKERS:
		var v: Variant = (marks as Dictionary).get(name)
		if not (v is float or v is int) or float(v) != floorf(float(v)) or float(v) < 0.0:
			errors.append("%s: marker %s missing or not a whole frame" % [id, name])
			continue
		c.markers[name] = int(v)
		if int(v) < last:
			errors.append("%s: marker %s comes before the one ahead of it" % [id, name])
		last = int(v)
	for name: Variant in marks:
		if not MARKERS.has(str(name)):
			errors.append("%s: unknown marker %s" % [id, name])
	return c
