class_name StudioLibraries
extends RefCounted
## The clip libraries the Studio plays from, loaded once and shared by every
## tile and the editor, so a gallery of a hundred tiles holds one copy of each
## (docs/specs/animation-studio.md, Catalogue). The Iglesias sets are the
## developer's local libraries (ClipLibraries); the CC0 library and the
## hand-keyed one are committed.

static var _sets: Dictionary[StringName, AnimationLibrary] = {}
static var _keyed: AnimationLibrary = null


## True when every Iglesias set is there (ClipLibraries.available(), so
## `force_missing` plays the Studio as a fresh clone does).
static func available() -> bool:
	return ClipLibraries.available()


## An Iglesias clip set's library (ClipLibraries.SETS), loaded on first use and
## kept; null when the packs are missing.
static func get_set(set_name: StringName) -> AnimationLibrary:
	if not available():
		return null
	return _load_set(set_name)


static func _load_set(set_name: StringName) -> AnimationLibrary:
	if not _sets.has(set_name):
		var lib: AnimationLibrary = ClipLibraries.load_set(set_name)
		if lib == null:
			return null
		_sets[set_name] = lib
	return _sets[set_name]


## Every Iglesias set by name, with one availability check: empty when the
## packs are missing.
static func sets() -> Dictionary[StringName, AnimationLibrary]:
	var out: Dictionary[StringName, AnimationLibrary] = {}
	if not available():
		return out
	for set_name: StringName in ClipLibraries.SETS:
		var lib: AnimationLibrary = _load_set(set_name)
		if lib == null:
			return {}
		out[set_name] = lib
	return out


## The committed CC0 library (FighterModel.LIBRARY, "ual").
static func ual() -> AnimationLibrary:
	return FighterModel.ANIMATION_LIBRARY


## The hand-keyed library (KeyedClips.LIBRARY, "keyed"), loaded on first use
## and kept; null before the builder has written it.
static func keyed() -> AnimationLibrary:
	if _keyed == null:
		_keyed = KeyedClips.load_library()
	return _keyed


## Drops the cached libraries, so the next call loads them again (after the
## keyed library has been rebuilt, say).
static func reset() -> void:
	_sets.clear()
	_keyed = null
